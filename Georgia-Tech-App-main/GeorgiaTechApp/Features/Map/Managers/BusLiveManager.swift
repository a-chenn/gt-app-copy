//
//  BusLiveManager.swift
//  GeorgiaTechApp
//

import Foundation

/// A consumer of live bus telemetry. The manager polls while ANY interest
/// is active, at the fastest requested cadence — so the map (6s) and the
/// home screen's Next Bus card (30s) share one TransLoc poller instead of
/// racing two.
enum BusDataInterest: String {
    case map
    case home
    case alerts
}

/// Polls TransLoc for live vehicle positions and capacities while someone
/// is interested. Buses are ephemeral telemetry — they live here, never
/// in SwiftData (see docs/ARCHITECTURE.md).
@Observable
@MainActor
final class BusLiveManager {
    private(set) var buses: [BusLive] = []
    /// Hybrid arrival predictions keyed by routeStopID, with TransLoc fallback.
    private(set) var stopEstimates: [Int: [BusStopEstimate]] = [:]
    private(set) var warnings: [String] = []
    private(set) var error: String?
    private(set) var isLoading = false
    private(set) var updatedAt: Date?
    private var estimatesUpdatedAt: Date?
    private var pollTask: Task<Void, Never>?
    private var interests: [BusDataInterest: Duration] = [:]
    private(set) var lastUpdated = Date()

    /// Register or withdraw a consumer. With no interests left, polling
    /// stops but the LAST SNAPSHOT is kept — returning surfaces (Home's
    /// Next Bus card, the map) render the cached data instantly instead
    /// of blanking and resizing, and the immediate refresh on the next
    /// interest corrects any staleness within a poll.
    func setInterest(
        _ interest: BusDataInterest, active: Bool, interval: Duration = .seconds(6)
    ) {
        let intervalBefore = interests.values.min()
        if active {
            interests[interest] = interval
        } else {
            interests.removeValue(forKey: interest)
        }

        guard let effective = interests.values.min() else {
            stopPolling()
            return
        }
        if pollTask == nil || effective != intervalBefore {
            restartPolling(interval: effective)
        }
    }

    private func restartPolling(interval: Duration) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isLoading = false
    }

    /// Publishes positions and predictions together from the shared pipeline.
    private func refresh() async {
        isLoading = true
        defer { if !Task.isCancelled { isLoading = false } }
        do {
            let snapshot = try await BusTelemetryService.shared.refresh()
            guard !Task.isCancelled else { return }
            buses = snapshot.buses
            warnings = snapshot.warnings
            updatedAt = snapshot.updatedAt
            error = nil
            if let estimates = snapshot.stopEstimates {
                stopEstimates = estimates
                estimatesUpdatedAt = snapshot.updatedAt
            } else if estimatesUpdatedAt.map({ Date().timeIntervalSince($0) > 30 }) ?? true {
                stopEstimates = [:]
            }
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
            for index in buses.indices where buses[index].dwell != nil {
                buses[index].dwell = nil
            }
            if estimatesUpdatedAt.map({ Date().timeIntervalSince($0) > 30 }) ?? true {
                stopEstimates = [:]
            }
        }
        
        lastUpdated = Date()
    }
}
