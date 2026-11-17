//
//  EventGameDay.swift
//  GeorgiaTechApp
//

import Foundation

/// The game-day rule as pure logic: an athletics event (matched by an
/// event category containing "athletics", case-insensitive) starting
/// within the next `horizonHours`.
///
/// This is the rule `HomeGameDayBanner` uses. The banner still carries its
/// own inline copy (its private `horizonHours` and `gameDay`), which was
/// left untouched by the widget PR — it should switch to calling this so
/// there is literally one definition. Until then, change both together.
nonisolated enum EventGameDay {
    /// How far ahead counts as "game day". Mirrors HomeGameDayBanner.
    static let horizonHours = 48

    static func isAthletics(_ categories: [String]) -> Bool {
        categories.contains { $0.localizedCaseInsensitiveContains("athletics") }
    }

    /// True when an event with these categories starting at `start` is a
    /// game-day event as of `now`.
    static func isGameDay(
        start: Date, categories: [String], now: Date = Date(), calendar: Calendar = .current
    ) -> Bool {
        guard isAthletics(categories),
              let horizon = calendar.date(byAdding: .hour, value: horizonHours, to: now)
        else { return false }
        return start >= now && start <= horizon
    }
}
