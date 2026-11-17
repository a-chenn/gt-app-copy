//
//  GTEventsWidgetEntry.swift
//  GTCapacityWidget
//

import Foundation
import WidgetKit

/// One event as the widget needs it — flat, no SwiftData. Codable so the
/// provider can keep the last good fetch for the offline "as of" state.
struct EventTileData: Codable, Hashable {
    let eventID: String
    let title: String
    /// Optional in the feed. nil (never "TBD") when the feed didn't say.
    let location: String?
    let start: Date
    let end: Date
    let categories: [String]
}

struct GTEventsEntry: TimelineEntry {
    /// The date WidgetKit uses to schedule this entry — one per event start.
    let date: Date
    /// When the events/ fetch completed — shown as "as of X:XX PM".
    let fetchedAt: Date
    /// Today's events that haven't started yet as of `date`, soonest first, up to 3.
    let upcoming: [EventTileData]
    /// The next event after today. Only set when `upcoming` is empty, and always
    /// shown with its day ("Tomorrow") so it never reads as today.
    let nextDay: EventTileData?
    /// True when today had events that have all started — "Nothing else today"
    /// rather than "Nothing scheduled today".
    let hadEventsToday: Bool
    /// True when the latest fetch failed and these events come from the last good fetch.
    let isStale: Bool
    /// True when the fetch failed and there is nothing cached to fall back on.
    let fetchFailed: Bool

    /// The soonest upcoming event today — the widget's headline.
    var headline: EventTileData? { upcoming.first }

    /// The app's game-day rule (EventGameDay), evaluated at this entry's time.
    func isGameDay(_ event: EventTileData) -> Bool {
        EventGameDay.isGameDay(start: event.start, categories: event.categories, now: date)
    }

    /// "Tomorrow", else the weekday ("Wednesday"), else "Wed, Nov 4" a week or more out.
    func dayLabel(for event: EventTileData, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: date)
        let eventDay = calendar.startOfDay(for: event.start)
        let days = calendar.dateComponents([.day], from: today, to: eventDay).day ?? 0
        if days == 1 { return "Tomorrow" }
        if days < 7 { return event.start.formatted(.dateTime.weekday(.wide)) }
        return event.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "as of 3:12 PM", or "as of Mon 3:12 PM" when the data is from another day.
    var asOfText: String {
        let time = fetchedAt.formatted(date: .omitted, time: .shortened)
        guard !Calendar.current.isDate(fetchedAt, inSameDayAs: date) else { return "as of \(time)" }
        return "as of \(fetchedAt.formatted(.dateTime.weekday(.abbreviated))) \(time)"
    }
}

/// Slim DTOs — only the keys the widget uses. JSONDecoder ignores everything
/// else in the events/ payload (body, summary, related links, groups…), so the
/// full event graph is never allocated in the widget process.
/// `EventTimeJSON` and `EventNamedValueJSON` are the app's own DTOs, shared
/// with this target, so the field names can't drift.
struct EventsSlimResponseJSON: Decodable {
    let events: [EventSlimJSON]
}

struct EventSlimJSON: Decodable {
    let id: String
    let title: String
    let location: String?
    let eventTime: EventTimeJSON
    let eventCategories: [EventNamedValueJSON]

    enum CodingKeys: String, CodingKey {
        case id, title, location
        case eventTime = "event_time"
        case eventCategories = "event_categories"
    }
}
