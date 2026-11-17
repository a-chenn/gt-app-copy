//
//  GTDataService+Dates.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadDates(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await datesFetcher.load(context: context, forceRefresh: forceRefresh) {
            // Admin-maintained on the API; upcoming-only keeps the local
            // store lean (past dates aren't shown anywhere).
            let response: GTDatesResponseJSON = try await self.fetch("dates/?upcoming=true&limit=500")

            let existing = try context.fetch(FetchDescriptor<GTDate>())

            // Unlike news, an EMPTY dates feed is a legitimate steady
            // state: the domain is admin-maintained and seasonal (every
            // summer the upcoming list can drain to zero, and an admin
            // may clear it). The fetch already threw on HTTP/decode
            // failure, so an empty envelope is authoritative — mirror it.
            guard !response.dates.isEmpty else {
                for date in existing {
                    context.delete(date)
                }
                try context.save()
                return
            }
            let byID = Dictionary(
                existing.map { ($0.dateID, $0) },
                uniquingKeysWith: { first, _ in first })
            var fetchedIDs = Set<String>()

            for json in response.dates {
                fetchedIDs.insert(json.id)
                if let current = byID[json.id] {
                    current.update(from: json)
                } else {
                    context.insert(GTDate(json: json))
                }
            }
            // Server list is authoritative (incl. past dates aging out).
            for date in existing where !fetchedIDs.contains(date.dateID) {
                context.delete(date)
            }
            try context.save()
        }
    }
}

extension GTDate {
    fileprivate convenience init(json: GTDateJSON) {
        self.init(
            dateID: json.id,
            title: json.title,
            date: Self.date(from: json.date),
            dateText: json.dateText,
            category: json.category
        )
    }

    fileprivate func update(from json: GTDateJSON) {
        title = json.title
        date = Self.date(from: json.date)
        dateText = json.dateText
        category = json.category
    }

    /// The API guarantees ISO8601 UTC datetimes.
    private static func date(from string: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: string) ?? .distantPast
    }
}
