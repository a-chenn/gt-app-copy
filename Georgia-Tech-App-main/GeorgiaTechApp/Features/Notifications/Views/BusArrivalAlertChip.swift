//
//  BusArrivalAlertChip.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Bus detail card row that configures a 0-15 minute arrival alert.
struct BusArrivalAlertChip: View {
    let stop: BusStop
    let stopEstimates: [Int: [BusStopEstimate]]
    @State private var selectedLeadTime = 5
    @State private var hint: String?
    
    var watchID: String { "busArrival.\(stop.routeStopID)" }
    var isWatching: Bool { AlertWatchService.shared.isWatching(kind: .busArrival, targetID: "\(stop.routeStopID)") }
    
    // To test if buses are not running set hasLiveBuses to true
    var hasLiveBuses: Bool {
        !BusArrivals.etas(to: stop, estimates: stopEstimates).isEmpty
    }
    
    var isUnavailable: Bool {
        let status = NotificationService.shared.authorizationStatus
        let preferred = NotificationService.shared.isPreferred(.busArrivals)
        return (status != .notDetermined && !NotificationService.shared.isAuthorized) || !preferred
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    if isUnavailable {
                        hint = "Notifications are disabled in Settings."
                        return
                    }
                    if isWatching {
                        AlertWatchService.shared.removeWatch(id: watchID)
                        hint = nil
                    } else {
                        let success = await AlertWatchService.shared.addWatch(
                            NotificationWatch(
                                id: watchID, kind: .busArrival, targetID: "\(stop.routeStopID)",
                                title: stop.name, createdAt: Date(), leadMinutes: selectedLeadTime
                            )
                        )
                        if !success {
                            hint = "Enable notifications in Settings to get alerts."
                        } else {
                            hint = nil
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isWatching ? "bell.fill" : "bell")
                    Text(isWatching ? "Alerting" : "Notify me")
                }
                .font(.gtHeading5)
                .foregroundStyle(isWatching ? Color.gtNavy : Color.gtPrimaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isWatching {
                        Capsule().fill(Color.gtGold)
                    } else {
                        Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUnavailable)
            .opacity(isUnavailable ? 0.5 : 1.0)
            .accessibilityLabel(isWatching ? "Cancel bus arrival alert for \(stop.name)" : "Alert me when a bus is arriving at \(stop.name)")
            
            if isUnavailable || hint != nil {
                Text(hint ?? "Notifications are disabled in Settings.")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            } else if isWatching {
                if hasLiveBuses {
                    Text("Alerting \(selectedLeadTime) minute\(selectedLeadTime == 1 ? "" : "s") before arrival. Updates while open.")
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0...15, id: \.self) { min in
                                GTFilterChip(
                                    title: "\(min)m",
                                    isSelected: selectedLeadTime == min,
                                    accessibilityText: "Alert \(min) minutes before"
                                ) {
                                    selectedLeadTime = min
                                    Task { await updateWatch(minutes: min) }
                                }
                            }
                        }
                    }
                } else {
                    Text("No buses are running to this stop right now. We'll alert you if one appears.")
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                }
            } else {
                Text("Based on the latest TransLoc estimate — updates while the app is open.")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            }
        }
        .onAppear {
            if let watch = AlertWatchService.shared.watches.first(where: { $0.id == watchID }),
               let minutes = watch.leadMinutes {
                selectedLeadTime = minutes
            }
        }
    }
    
    private func updateWatch(minutes: Int) async {
        let watch = NotificationWatch(
            id: watchID, kind: .busArrival, targetID: "\(stop.routeStopID)",
            title: stop.name, createdAt: Date(), leadMinutes: minutes
        )
        _ = await AlertWatchService.shared.addWatch(watch)
    }
}
