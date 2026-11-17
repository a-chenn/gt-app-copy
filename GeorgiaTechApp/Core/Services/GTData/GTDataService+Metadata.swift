//
//  GTDataService+Metadata.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

/// Which data domains a sync pass successfully brought up to date.
/// Only successful domains get their Metadata timestamp committed, so a
/// failed fetch is retried on the next sync instead of silently skipped.
struct MetadataDomains {
    var dining = false
    var map = false
    var appliances = false
    var capacity = false
    var events = false
    var news = false
    var dates = false
}

/// The per-domain refresh decisions for one sync pass, derived from
/// comparing the server's `metadata/` timestamps against the stored ones.
/// When the metadata fetch fails (offline), nothing force-refreshes and
/// cached data is served as-is.
struct MetadataRefreshPlan {
    let server: MetadataJSON?
    private let stored: MetadataSnapshot?

    struct MetadataSnapshot {
        let map: String
        let capacity: String
        let dining: String
        let microwave: String
        let printer: String
        let vending: String
        let events: String
        let news: String
        let dates: String
    }

    init(server: MetadataJSON?, stored: Metadata?) {
        self.server = server
        self.stored = stored.map {
            MetadataSnapshot(
                map: $0.mapLastUpdated, capacity: $0.capacityLastUpdated,
                dining: $0.diningLastUpdated, microwave: $0.microwaveLastUpdated,
                printer: $0.printerLastUpdated, vending: $0.vendingLastUpdated,
                events: $0.eventsLastUpdated, news: $0.newsLastUpdated,
                dates: $0.datesLastUpdated)
        }
    }

    var shouldRefreshDining: Bool { changed(\.diningLastUpdated, storedValue: stored?.dining) }
    var shouldRefreshMap: Bool { changed(\.mapLastUpdated, storedValue: stored?.map) }
    var shouldRefreshCapacity: Bool { changed(\.capacityLastUpdated, storedValue: stored?.capacity) }
    var shouldRefreshEvents: Bool { changed(\.eventsLastUpdated, storedValue: stored?.events) }
    var shouldRefreshNews: Bool { changed(\.newsLastUpdated, storedValue: stored?.news) }
    var shouldRefreshDates: Bool { changed(\.datesLastUpdated, storedValue: stored?.dates) }
    var shouldRefreshAppliances: Bool {
        changed(\.printerLastUpdated, storedValue: stored?.printer)
            || changed(\.microwaveLastUpdated, storedValue: stored?.microwave)
            || changed(\.vendingLastUpdated, storedValue: stored?.vending)
    }

    /// A domain needs a refresh when the server timestamp differs from the
    /// stored one. A nil/empty server stamp (a partial metadata doc, or a
    /// field the API hasn't shipped yet) means "attempt a refresh" rather
    /// than silently freezing that domain.
    private func changed(_ keyPath: KeyPath<MetadataJSON, String?>, storedValue: String?) -> Bool {
        guard let server else { return false }
        guard let serverStamp = server[keyPath: keyPath], !serverStamp.isEmpty else { return true }
        guard let storedValue, !storedValue.isEmpty else { return true }
        return storedValue != serverStamp
    }
}

extension GTDataService {
    @MainActor func makeRefreshPlan(context: ModelContext) async -> MetadataRefreshPlan {
        let server: MetadataJSON?
        do {
            server = try await fetch("metadata/")
        } catch {
            Logger.dataService.error(
                "Metadata fetch failed, serving cached data: \(error.localizedDescription)")
            server = nil
        }
        return MetadataRefreshPlan(server: server, stored: getStoredMetadata(context: context))
    }

    /// Persists the server timestamps for every domain that synced successfully,
    /// so the next launch can skip fetches for unchanged data.
    @MainActor func commitMetadata(
        plan: MetadataRefreshPlan, context: ModelContext, syncedDomains: MetadataDomains
    ) {
        guard let server = plan.server else { return }

        let stored: Metadata
        if let existing = getStoredMetadata(context: context) {
            stored = existing
        } else {
            stored = Metadata(
                _id: server.id, mapLastUpdated: "", capacityLastUpdated: "",
                diningLastUpdated: "", microwaveLastUpdated: "", printerLastUpdated: "",
                vendingLastUpdated: "", eventsLastUpdated: "")
            context.insert(stored)
        }

        // Only commit a stamp the server actually provided — a domain
        // that synced against a missing/nil server stamp keeps its stored
        // value so it re-attempts next launch instead of storing "".
        if syncedDomains.dining, let v = server.diningLastUpdated { stored.diningLastUpdated = v }
        if syncedDomains.map, let v = server.mapLastUpdated { stored.mapLastUpdated = v }
        if syncedDomains.capacity, let v = server.capacityLastUpdated { stored.capacityLastUpdated = v }
        if syncedDomains.events, let v = server.eventsLastUpdated { stored.eventsLastUpdated = v }
        if syncedDomains.news, let v = server.newsLastUpdated { stored.newsLastUpdated = v }
        if syncedDomains.dates, let v = server.datesLastUpdated { stored.datesLastUpdated = v }
        if syncedDomains.appliances {
            if let v = server.printerLastUpdated { stored.printerLastUpdated = v }
            if let v = server.microwaveLastUpdated { stored.microwaveLastUpdated = v }
            if let v = server.vendingLastUpdated { stored.vendingLastUpdated = v }
        }

        do {
            try context.save()
        } catch {
            Logger.dataService.error(
                "Failed committing metadata: \(error.localizedDescription)")
        }
    }

    @MainActor func getStoredMetadata(context: ModelContext) -> Metadata? {
        try? context.fetch(FetchDescriptor<Metadata>()).first
    }
}
