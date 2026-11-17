//
//  GTDataService+Events.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadEvents(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await eventFetcher.load(context: context, forceRefresh: forceRefresh) {
            // The API accumulates events server-side (the upstream feed
            // rotates; the backend merges) and serves a stable upcoming
            // list — 500 covers the busiest stretch of the semester.
            let response: EventResponseJSON = try await self.fetch("events/?limit=500")

            // A stable accumulated feed never legitimately serves zero
            // events — treat empty as a broken/transitional fetch (e.g.
            // mid-migration) instead of wiping the local cache.
            guard !response.events.isEmpty else {
                throw URLError(.zeroByteResource)
            }

            // Id-based upsert, the CampusLocation pattern: identity
            // survives syncs, so reminders keyed on eventID stay valid
            // (replace-all orphaned them on every refresh).
            let existing = try context.fetch(FetchDescriptor<Event>())
            let byID = Dictionary(
                existing.map { ($0.eventID, $0) },
                uniquingKeysWith: { first, _ in first })
            var fetchedIDs = Set<String>()

            for json in response.events {
                fetchedIDs.insert(json.id)
                if let current = byID[json.id] {
                    let previousStart = current.startDate
                    current.update(from: json)
                    if previousStart != current.startDate {
                        // A pending reminder still points at the OLD time.
                        let moved = current
                        Task { await EventReminders.rescheduleIfPending(for: moved) }
                    }
                } else {
                    context.insert(Event(json: json))
                }
            }
            // The server feed is authoritative: gone there = gone here
            // (it only removes genuinely past events).
            for event in existing where !fetchedIDs.contains(event.eventID) {
                EventReminders.cancelReminder(for: event)
                context.delete(event)
            }
            try context.save()
        }
    }
}

extension Event {
    fileprivate convenience init(json: EventJSON) {
        self.init(
            eventID: json.id,
            title: json.title,
            body: json.body,
            summary: json.summary,
            location: json.location,
            startDate: EventDateParser.date(from: json.eventTime.eventTimeStart, timezone: json.eventTime.timezone),
            endDate: EventDateParser.date(from: json.eventTime.eventTimeEnd, timezone: json.eventTime.timezone),
            timezone: json.eventTime.timezone,
            invitedAudience: json.invitedAudience.map(\.name),
            eventCategories: json.eventCategories.map(\.name),
            relatedLinks: json.relatedLinks.map { RelatedLink(title: $0.title, url: $0.url) },
            groups: json.groups.map(\.name),
            contact: json.contact,
            createdGMT: json.createdGMT,
            changedGMT: json.changedGMT,
            lastUpdated: json.changedGMT
        )
    }

    fileprivate func update(from json: EventJSON) {
        title = json.title
        body = json.body
        summary = json.summary
        location = json.location
        startDate = EventDateParser.date(from: json.eventTime.eventTimeStart, timezone: json.eventTime.timezone)
        endDate = EventDateParser.date(from: json.eventTime.eventTimeEnd, timezone: json.eventTime.timezone)
        timezone = json.eventTime.timezone
        invitedAudience = json.invitedAudience.map(\.name)
        eventCategories = json.eventCategories.map(\.name)
        relatedLinks = json.relatedLinks.map { RelatedLink(title: $0.title, url: $0.url) }
        groups = json.groups.map(\.name)
        contact = json.contact
        createdGMT = json.createdGMT
        changedGMT = json.changedGMT
        lastUpdated = json.changedGMT
    }
}
