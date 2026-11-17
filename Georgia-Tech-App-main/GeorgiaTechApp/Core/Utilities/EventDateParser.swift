//
//  EventDateParser.swift
//  GeorgiaTechApp
//

import Foundation

/// The one parser for the events/ feed's date strings. Shared by the app's
/// events sync (`GTDataService+Events`) and the "Today on Campus" widget so
/// the two can never disagree about when an event starts — two parsers
/// drift, and the symptom is a widget that's an hour off twice a year.
nonisolated enum EventDateParser {
    /// The API guarantees ISO8601 UTC timestamps; one lenient fallback is
    /// kept for resilience against upstream drift. Only that fallback needs
    /// `timezone`: a bare "yyyy-MM-dd HH:mm:ss" carries no offset, so it is
    /// read in the event's own zone (America/New_York for campus events).
    static func date(from string: String, timezone: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string) ?? .distantPast
    }
}
