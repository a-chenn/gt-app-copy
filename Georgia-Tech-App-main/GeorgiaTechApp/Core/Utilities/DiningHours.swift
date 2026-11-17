//
//  DiningHours.swift
//  GeorgiaTechApp
//

import Foundation

/// Pure helpers for the dining API's hours format:
/// `hoursOpen` is 7 day-entries (Sunday first), each a flat list of
/// open/close time pairs in "H:mm" 24-hour strings. Closing times may
/// exceed 24:00 (e.g. "26:00" = 2 AM the next day).
enum DiningHours {
    enum Status {
        case open(closesAtMinutes: Int)
        case closingSoon(closesAtMinutes: Int)
        case closed
    }

    static func status(for hours: [[String]]?, now: Date = Date(), calendar: Calendar = .current) -> Status {
        guard let hours, hours.count == 7 else { return .closed }

        let day = calendar.component(.weekday, from: now) - 1
        let nowMinutes = minutesIntoDay(now, calendar: calendar)

        var closing = closingTime(in: hours[day], nowMinutes: nowMinutes)
        if closing == nil, day > 0 || !hours.isEmpty {
            // A location that opened yesterday can still be open past midnight.
            let yesterday = (day + 6) % 7
            closing = closingTime(in: hours[yesterday], nowMinutes: nowMinutes + 1440)
                .map { $0 - 1440 }
        }

        guard let closesAt = closing else { return .closed }
        let remaining = closesAt - nowMinutes
        if remaining <= 0 { return .closed }
        return remaining <= 60 ? .closingSoon(closesAtMinutes: closesAt) : .open(closesAtMinutes: closesAt)
    }

    static func statusText(for hours: [[String]]?, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch status(for: hours, now: now, calendar: calendar) {
        case .open(let closesAt), .closingSoon(let closesAt):
            return "Open until \(format(minutes: closesAt))"
        case .closed:
            if let hours, let next = nextOpening(hours: hours, now: now, calendar: calendar) {
                return "Closed until \(next)"
            }
            return "Closed"
        }
    }

    static func isOpenNow(_ hours: [[String]]?) -> Bool {
        if case .closed = status(for: hours) { return false }
        return true
    }

    /// One display row per weekday, Sunday first, e.g. ("Monday", "8:00AM – 9:00PM").
    static func weeklyRows(for hours: [[String]]?) -> [(day: String, text: String)] {
        guard let hours, hours.count == 7 else { return [] }
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return zip(dayNames, hours).map { name, dayHours in
            (day: name, text: rangesText(for: dayHours))
        }
    }

    // MARK: - Internals

    private static func rangesText(for dayHours: [String]) -> String {
        var ranges: [String] = []
        for index in stride(from: 0, to: dayHours.count - 1, by: 2) {
            guard let open = parse(dayHours[index]), let close = parse(dayHours[index + 1]) else { continue }
            ranges.append("\(format(minutes: open)) – \(format(minutes: close))")
        }
        return ranges.isEmpty ? "Closed" : ranges.joined(separator: ", ")
    }

    private static func closingTime(in dayHours: [String], nowMinutes: Int) -> Int? {
        for index in stride(from: 0, to: dayHours.count - 1, by: 2) {
            guard let open = parse(dayHours[index]), let close = parse(dayHours[index + 1]) else { continue }
            if nowMinutes >= open && nowMinutes < close {
                return close
            }
        }
        return nil
    }

    private static func nextOpening(hours: [[String]], now: Date, calendar: Calendar) -> String? {
        guard hours.count == 7 else { return nil }
        let today = calendar.component(.weekday, from: now) - 1
        let nowMinutes = minutesIntoDay(now, calendar: calendar)

        for offset in 0..<7 {
            let day = (today + offset) % 7
            for index in stride(from: 0, to: hours[day].count - 1, by: 2) {
                guard let open = parse(hours[day][index]) else { continue }
                if offset == 0 && open <= nowMinutes { continue }
                return format(minutes: open)
            }
        }
        return nil
    }

    private static func parse(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }

    private static func format(minutes: Int) -> String {
        var total = minutes
        if total >= 1440 { total -= 1440 }
        if total < 0 { total += 1440 }
        let hour = total / 60
        let minute = total % 60
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d%@", displayHour, minute, period)
    }

    private static func minutesIntoDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
