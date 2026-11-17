//
//  EventsVM.swift
//  GeorgiaTechApp
//

import Foundation

enum EventFeedSortOrder: String, CaseIterable {
    case date = "Soonest first"
    case name = "Name A–Z"
}

@Observable
@MainActor
final class EventsVM {
    /// Applies the Events home's name, category, and date filters in the device timezone.
    func filterEvents(
        _ events: [Event], query: String, category: String?, date: Date?, sortOrder: EventFeedSortOrder,
        calendar: Calendar = .current
    ) -> [Event] {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let day = date.flatMap { calendar.dateInterval(of: .day, for: $0) }
        let matches = events.filter { event in
            let matchesDate = day.map { event.startDate < $0.end && event.endDate >= $0.start } ?? true
            return (name.isEmpty || event.title.localizedCaseInsensitiveContains(name))
                && (category == nil || event.eventCategories.contains(category ?? "")) && matchesDate
        }
        switch sortOrder {
        case .date:
            return matches.sorted { $0.startDate < $1.startDate }
        case .name:
            return matches.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    /// Uses the existing feed's categories to rank broad-appeal events, with earlier events winning ties.
    func recommendedEvents(from events: [Event]) -> [Event] {
        func appeal(_ event: Event) -> Int {
            let weights = ["Sports/Athletics": 3, "Arts and Performance": 3,
                           "Student sponsored": 2, "Free": 2, "Training/Workshop": -2,
                           "Seminar/Lecture/Colloquium": -1]
            return Set(event.eventCategories).reduce(0) { $0 + weights[$1, default: 0] }
                + (event.invitedAudience.contains("Public") ? 1 : 0)
        }
        return Array(events.sorted {
            let left = appeal($0)
            let right = appeal($1)
            return left == right ? $0.startDate < $1.startDate : left > right
        }.prefix(12))
    }

    struct DaySection: Identifiable {
        let day: Date
        let events: [Event]
        var id: Date { day }
    }

    /// Upcoming events grouped by calendar day, soonest first. Events
    /// already underway (started but not ended) count as today.
    func daySections(from events: [Event], now: Date = Date(), calendar: Calendar = .current) -> [DaySection] {
        let upcoming = events.filter { $0.endDate >= now }
        let grouped = Dictionary(grouping: upcoming) {
            calendar.startOfDay(for: max($0.startDate, calendar.startOfDay(for: now)))
        }
        return grouped
            .map { DaySection(day: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.day < $1.day }
    }

    func dayTitle(for day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(day, inSameDayAs: tomorrow) { return "Tomorrow" }
        // A list that spans New Year needs the year spelled out (#F2-1):
        // "Monday, Aug 17" is ambiguous when 2027 events are in the feed.
        if calendar.component(.year, from: day) == calendar.component(.year, from: now) {
            return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
    }
}
