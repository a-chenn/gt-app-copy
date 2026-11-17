//
//  GTDiningWidgetProvider.swift
//  GTCapacityWidget
//

import WidgetKit
import Foundation

struct GTDiningWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> GTDiningEntry {
        // Ordered soonest-closing first — the widget's whole point is urgency at a glance.
        GTDiningEntry(
            date: .now, fetchedAt: .now, openCount: 3,
            places: [
                DiningPlaceData(name: "North Ave Dining Hall",
                                statusText: "Open until 7:30PM", isOpen: true,
                                closesAtMinutes: 1170, opensAtMinutes: nil),
                DiningPlaceData(name: "West Village",
                                statusText: "Open until 8:00PM", isOpen: true,
                                closesAtMinutes: 1200, opensAtMinutes: nil),
                DiningPlaceData(name: "Brittain Dining Hall",
                                statusText: "Open until 9:00PM", isOpen: true,
                                closesAtMinutes: 1260, opensAtMinutes: nil),
                DiningPlaceData(name: "Ferst Place",
                                statusText: "Closed", isOpen: false,
                                closesAtMinutes: nil, opensAtMinutes: nil)
            ],
            soonestClosingText: "Open until 7:30PM",
            nextOpenText: nil,
            fetchFailed: false
        )
    }

    // swiftlint:disable no_completion_handlers
    func getSnapshot(in context: Context, completion: @escaping (GTDiningEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GTDiningEntry>) -> Void) {
        Task {
            let timeline = await buildTimeline()
            completion(timeline)
        }
    }
    // swiftlint:enable no_completion_handlers

    // MARK: - Timeline building

    private func buildTimeline(now: Date = Date()) async -> Timeline<GTDiningEntry> {
        let calendar = Calendar.current
        do {
            let restaurants = try await fetchRestaurants()

            // Gather all future transition minutes for today across displayed restaurants.
            let transitionMinutes = futureTransitionMinutes(from: restaurants, after: now, calendar: calendar)

            // Build one entry per transition, plus the current state, capped at 20.
            let startOfDay = calendar.startOfDay(for: now)
            var checkDates: [Date] = [now]
            for mins in transitionMinutes.prefix(19) {
                if let date = calendar.date(byAdding: .minute, value: mins, to: startOfDay) {
                    checkDates.append(date)
                }
            }

            let entries = checkDates.map { date in
                makeEntry(from: restaurants, at: date, fetchedAt: now)
            }

            // Refresh at the next day boundary or 6 hours out, whichever is sooner.
            // Hours are a daily schedule — there's no reason to poll within a day.
            let sixHoursOut = calendar.date(byAdding: .hour, value: 6, to: now) ?? now
            let tomorrow = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            let nextRefresh = min(sixHoursOut, tomorrow)

            return Timeline(entries: entries, policy: .after(nextRefresh))
        } catch {
            let entry = GTDiningEntry(
                date: now, fetchedAt: now, openCount: 0, places: [],
                soonestClosingText: nil, nextOpenText: nil, fetchFailed: true)
            let retryIn = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
            return Timeline(entries: [entry], policy: .after(retryIn))
        }
    }

    private func makeEntry(from restaurants: [DiningSlimJSON], at date: Date, fetchedAt: Date) -> GTDiningEntry {
        let calendar = Calendar.current
        let day = calendar.component(.weekday, from: date) - 1
        let nowMinutes = calendar.component(.hour, from: date) * 60
                       + calendar.component(.minute, from: date)

        let withHours = restaurants.filter { $0.hoursOpen != nil }
        var openPlaces: [DiningPlaceData] = []
        var closedPlaces: [DiningPlaceData] = []

        for r in withHours {
            let status = DiningHours.status(for: r.hoursOpen, now: date)
            let text = DiningHours.statusText(for: r.hoursOpen, now: date)
            switch status {
            case .open(let closesAt), .closingSoon(let closesAt):
                openPlaces.append(DiningPlaceData(
                    name: r.name, statusText: text, isOpen: true,
                    closesAtMinutes: closesAt, opensAtMinutes: nil))
            case .closed:
                let opensAt = nextOpenMinutes(for: r.hoursOpen, after: nowMinutes, day: day)
                closedPlaces.append(DiningPlaceData(
                    name: r.name, statusText: text, isOpen: false,
                    closesAtMinutes: nil, opensAtMinutes: opensAt))
            }
        }

        openPlaces.sort { ($0.closesAtMinutes ?? 0) < ($1.closesAtMinutes ?? 0) }
        closedPlaces.sort { ($0.opensAtMinutes ?? Int.max) < ($1.opensAtMinutes ?? Int.max) }

        let places = Array((openPlaces + closedPlaces).prefix(4))
        let soonestClosingText = openPlaces.first?.statusText

        // Pick the restaurant opening soonest (minimum opensAtMinutes), not the alphabetically first.
        let nextOpenText: String? = openPlaces.isEmpty
            ? closedPlaces
                .min { ($0.opensAtMinutes ?? Int.max) < ($1.opensAtMinutes ?? Int.max) }
                .flatMap {
                    $0.statusText.hasPrefix("Closed until ")
                        ? $0.statusText.replacingOccurrences(of: "Closed until ", with: "Opens ")
                        : nil
                }
            : nil

        return GTDiningEntry(
            date: date, fetchedAt: fetchedAt, openCount: openPlaces.count,
            places: places, soonestClosingText: soonestClosingText,
            nextOpenText: nextOpenText, fetchFailed: false)
    }
    
    /// Collects all unique transition minutes (open and close times) from today's hours
    /// for every restaurant, filtered to those strictly after `now`.
    private func futureTransitionMinutes(
        from restaurants: [DiningSlimJSON],
        after now: Date,
        calendar: Calendar
    ) -> [Int] {
        let day = calendar.component(.weekday, from: now) - 1
        let nowMinutes = calendar.component(.hour, from: now) * 60
                       + calendar.component(.minute, from: now)

        var minutes = Set<Int>()
        for r in restaurants {
            guard let hours = r.hoursOpen, hours.count == 7 else { continue }
            for timeStr in hours[day] {
                if let m = parseMinutes(timeStr), m > nowMinutes, m < 1440 {
                    minutes.insert(m)
                }
            }
        }
        return minutes.sorted()
    }

    /// Mirrors DiningHours's private parse() — needed to extract transition times
    /// for timeline construction. The public DiningHours API doesn't expose raw minutes.
    private func parseMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
    
    /// Minutes into today when `hoursOpen[day]` next opens after `nowMinutes`.
    /// Even indices are open times, odd indices are close times.
    /// Returns tomorrow's first open time + 1440 when nothing is left today, so values
    /// sort correctly against same-day times. Returns nil if hours are unknown.
    private func nextOpenMinutes(for hoursOpen: [[String]]?, after nowMinutes: Int, day: Int) -> Int? {
        guard let hours = hoursOpen, hours.count == 7 else { return nil }
        let todayHours = hours[day]
        var idx = 0
        while idx < todayHours.count {
            if let openMin = parseMinutes(todayHours[idx]), openMin > nowMinutes {
                return openMin
            }
            idx += 2
        }
        let tomorrowHours = hours[(day + 1) % 7]
        if let first = tomorrowHours.first, let m = parseMinutes(first) {
            return m + 1440
        }
        return nil
    }

    // MARK: - Fetch

    private func fetchRestaurants() async throws -> [DiningSlimJSON] {
        let url = try APIUtility.url(for: "dining/")
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        // dining/ returns a flat array — not wrapped in { "data": [...] }.
        return try JSONDecoder().decode([DiningSlimJSON].self, from: data)
    }
}
