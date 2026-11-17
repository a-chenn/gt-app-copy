//
//  GTEventsWidgetProvider.swift
//  GTCapacityWidget
//

import Foundation
import WidgetKit

struct GTEventsWidgetProvider: TimelineProvider {

    /// WidgetKit's cap on useful entries — far more than any one day's events.
    private static let maxEntries = 30

    func placeholder(in context: Context) -> GTEventsEntry {
        // Gallery and redacted state: structure is real, events are representative.
        GTEventsEntry.sample()
    }

    // swiftlint:disable no_completion_handlers
    func getSnapshot(in context: Context, completion: @escaping (GTEventsEntry) -> Void) {
        // Widget gallery preview — return the placeholder without a network call.
        // The gallery shows this; the installed widget shows getTimeline's entries.
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GTEventsEntry>) -> Void) {
        Task {
            let timeline = await buildTimeline()
            completion(timeline)
        }
    }
    // swiftlint:enable no_completion_handlers

    // MARK: - Timeline building

    private func buildTimeline(now: Date = Date()) async -> Timeline<GTEventsEntry> {
        let calendar = Calendar.current
        do {
            let events = try await fetchEvents()
            GTEventsCache.save(events, fetchedAt: now)
            let entries = Self.makeEntries(
                from: events, fetchedAt: now, isStale: false, now: now, calendar: calendar)
            return Timeline(entries: entries, policy: .after(Self.nextRefresh(after: now, calendar: calendar)))
        } catch {
            // Events don't change minute to minute, so the last good fetch (labeled
            // "as of") beats a blank tile. Retry soon either way.
            let retryIn = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
            if let cached = GTEventsCache.load() {
                let entries = Self.makeEntries(
                    from: cached.events, fetchedAt: cached.fetchedAt, isStale: true, now: now, calendar: calendar)
                return Timeline(entries: entries, policy: .after(retryIn))
            }
            let entry = GTEventsEntry(
                date: now, fetchedAt: now, upcoming: [], nextDay: nil,
                hadEventsToday: false, isStale: false, fetchFailed: true)
            return Timeline(entries: [entry], policy: .after(retryIn))
        }
    }

    /// Pure: one fetch → the whole day's timeline. An entry now, one at each
    /// remaining event start today (so "next" rolls over at the exact minute
    /// with no refresh spent), and one at midnight so the day flips correctly
    /// even if WidgetKit runs the next refresh late. The entry at the last
    /// event's start is the "nothing left today" entry.
    ///
    /// "Today" is the user's calendar (`calendar`, default `.current`) — never
    /// UTC formatting, which flips to tomorrow at 8 PM Atlanta time (see
    /// DiningMenu.day(in:for:)). Takes `now` so the 6:55 PM timeline can be
    /// built at lunchtime and checked.
    static func makeEntries(
        from events: [EventTileData],
        fetchedAt: Date,
        isStale: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [GTEventsEntry] {
        let sorted = events.sorted { $0.start < $1.start }
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        let rollovers = Set(sorted.map(\.start).filter { $0 > now && $0 < startOfTomorrow }).sorted()
        let entryDates = Array(([now] + rollovers + [startOfTomorrow]).prefix(maxEntries))

        return entryDates.map { date in
            let dayStart = calendar.startOfDay(for: date)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            let today = sorted.filter { calendar.isDate($0.start, inSameDayAs: date) }
            let upcoming = today.filter { $0.start > date }
            return GTEventsEntry(
                date: date,
                fetchedAt: fetchedAt,
                upcoming: Array(upcoming.prefix(3)),
                nextDay: upcoming.isEmpty ? sorted.first(where: { $0.start >= nextDayStart }) : nil,
                hadEventsToday: today.contains { $0.start <= date },
                isStale: isStale,
                fetchFailed: false)
        }
    }

    /// Early tomorrow or ~5 hours out, whichever is sooner. The feed is a stable
    /// accumulated list — the per-start entries do the rolling, not polling.
    static func nextRefresh(after now: Date, calendar: Calendar = .current) -> Date {
        let fiveHoursOut = calendar.date(byAdding: .hour, value: 5, to: now) ?? now
        let tomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return min(fiveHoursOut, tomorrow)
    }

    // MARK: - Fetch

    private func fetchEvents() async throws -> [EventTileData] {
        // The app asks for 500 with full bodies; the widget needs today's handful.
        // 40 covers the busiest day and keeps the extension under its memory ceiling.
        let url = try APIUtility.url(for: "events/?limit=40")
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        let decoded = try JSONDecoder().decode(EventsSlimResponseJSON.self, from: data)
        // Same rule as the app's sync: the accumulated feed never legitimately
        // serves zero events, so empty is a broken fetch — fall back to the cache.
        guard !decoded.events.isEmpty else { throw URLError(.zeroByteResource) }
        return decoded.events.map(\.tileData)
    }
}

// MARK: - Last good fetch

/// The last successful fetch, kept in the widget's own defaults. Only the widget
/// writes and reads it, so no App Group is needed.
enum GTEventsCache {
    private static let key = "GTEventsWidget.lastGoodFetch"

    private struct Payload: Codable {
        let fetchedAt: Date
        let events: [EventTileData]
    }

    static func save(_ events: [EventTileData], fetchedAt: Date) {
        guard let data = try? JSONEncoder().encode(Payload(fetchedAt: fetchedAt, events: events)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> (events: [EventTileData], fetchedAt: Date)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return (payload.events, payload.fetchedAt)
    }
}

// MARK: - EventSlimJSON helpers (widget-side only)

private extension EventSlimJSON {
    var tileData: EventTileData {
        let trimmed = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        return EventTileData(
            eventID: id,
            title: title,
            location: (trimmed?.isEmpty ?? true) ? nil : trimmed,
            start: EventDateParser.date(from: eventTime.eventTimeStart, timezone: eventTime.timezone),
            end: EventDateParser.date(from: eventTime.eventTimeEnd, timezone: eventTime.timezone),
            categories: eventCategories.map(\.name))
    }
}

// MARK: - Placeholder / preview data

extension GTEventsEntry {
    /// Representative entry for the gallery placeholder and #Previews.
    /// `gameDay` puts a GT athletics event first to exercise the gold treatment.
    static func sample(now: Date = .now, gameDay: Bool = false) -> GTEventsEntry {
        let hour: TimeInterval = 3600
        let fair = EventTileData(
            eventID: "sample-fair", title: "Career Fair: Engineering & Computing",
            location: "Exhibition Hall", start: now + 2 * hour, end: now + 5 * hour,
            categories: ["Career/Professional development"])
        let game = EventTileData(
            eventID: "sample-game", title: "Volleyball vs. Duke",
            location: "O'Keefe Gymnasium", start: now + (gameDay ? 1 : 4) * hour,
            end: now + 6 * hour, categories: ["Athletics"])
        let concert = EventTileData(
            eventID: "sample-concert", title: "Jazz Ensemble Fall Concert",
            location: "Ferst Center for the Arts", start: now + 5 * hour, end: now + 7 * hour,
            categories: ["Arts and Performance"])
        let upcoming = gameDay ? [game, fair, concert] : [fair, concert]
        return GTEventsEntry(
            date: now, fetchedAt: now, upcoming: upcoming, nextDay: nil,
            hadEventsToday: false, isStale: false, fetchFailed: false)
    }
}
