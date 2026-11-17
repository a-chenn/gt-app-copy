//
//  FavoriteMenuMatches.swift
//  GeorgiaTechApp
//

import Foundation

/// Pure domain logic for matching hearted dishes against today's dining hall menus
/// and computing the daily digest schedule.
enum FavoriteMenuMatches {
    struct Match: Equatable {
        let dishName: String
        let normalizedDishName: String
        let restaurantID: String
        let restaurantName: String
        let mealTitle: String
    }

    struct DigestContent: Equatable {
        let title: String
        let body: String
        let primaryRestaurantID: String
    }

    /// Normalizes a dish name so minor feed variations in case or whitespace
    /// still match the student's hearted dish name.
    ///
    /// Rule: trim surrounding whitespace/newlines, collapse internal runs of
    /// whitespace to a single space, and fold case to lowercase. Punctuation
    /// and full words are preserved so distinct items (e.g. "Cheese Pizza" vs.
    /// "Vegan Cheese Pizza") never false-match.
    nonisolated static func normalizedName(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    /// Extracts the display name of a menu item using the same fallback order
    /// used when storing `FavoriteFood` in `PlaceMenuSection`.
    static func dishName(for item: MenuItem) -> String {
        item.food?.name ?? item.text
    }

    /// Returns today's active/upcoming menu matches for the student's hearted dishes.
    ///
    /// - Walks each restaurant's menus via `DiningMenu.orderedMenus(_:)` and resolves
    ///   today's menu via `DiningMenu.day(in:for:)`.
    /// - Skips meal periods whose cutoff time has already passed on the same day as `now`.
    /// - Deduplicates per dining hall: if the same dish appears in multiple upcoming meal
    ///   periods at the same hall, only the earlier meal is returned.
    static func matches(
        in restaurants: [Restaurant],
        favorites: Set<String>,
        on now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Match] {
        guard !favorites.isEmpty else { return [] }

        let normalizedFavorites = Set(favorites.map { normalizedName($0) }).subtracting([""])
        guard !normalizedFavorites.isEmpty else { return [] }

        let sortedRestaurants = restaurants.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var results: [Match] = []

        for restaurant in sortedRestaurants {
            let menus = DiningMenu.orderedMenus(restaurant.menus)
            var seenInHall = Set<String>()

            for (index, menu) in menus.enumerated() {
                let mealTitle = DiningMenu.mealTitle(at: index, of: menus.count)
                guard !hasMealEnded(mealTitle, at: now, calendar: calendar),
                      let day = DiningMenu.day(in: menu, for: now) else {
                    continue
                }

                for item in day.menuItems {
                    let rawName = dishName(for: item)
                    let normalized = normalizedName(rawName)
                    guard !normalized.isEmpty,
                          normalizedFavorites.contains(normalized),
                          seenInHall.insert(normalized).inserted else {
                        continue
                    }

                    let displayName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                    results.append(
                        Match(
                            dishName: displayName,
                            normalizedDishName: normalized,
                            restaurantID: restaurant.restaurantID,
                            restaurantName: restaurant.name,
                            mealTitle: mealTitle
                        )
                    )
                }
            }
        }

        return results
    }

    /// Formats the single aggregated notification title and body for today's matches.
    static func digestContent(for matches: [Match]) -> DigestContent? {
        guard let first = matches.first else { return nil }
        let extraCount = matches.dropFirst().count

        if extraCount == 0 {
            return DigestContent(
                title: first.dishName,
                body: "At \(first.restaurantName) for \(first.mealTitle) today.",
                primaryRestaurantID: first.restaurantID
            )
        }

        return DigestContent(
            title: first.dishName,
            body: "At \(first.restaurantName) for \(first.mealTitle), and \(extraCount) more of your favorites today.",
            primaryRestaurantID: first.restaurantID
        )
    }

    /// Computes when today's digest notification should fire.
    ///
    /// - Aims for the pre-meal target time of the earliest matched meal.
    /// - Clamps delivery to daytime hours (7:30 AM – 8:00 PM local time).
    /// - If the app is opened after the earliest meal's pre-meal target time has passed
    ///   (while that meal is currently underway), schedules a short 15-second delay so
    ///   the alert never fires the instant the app launches.
    static func fireDate(
        for matches: [Match],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard !matches.isEmpty else { return nil }

        guard let earliestAllowed = date(atHour: 7, minute: 30, on: now, calendar: calendar),
              let latestAllowed = date(atHour: 20, minute: 0, on: now, calendar: calendar),
              now < latestAllowed else {
            return nil
        }

        let targetDates = matches.compactMap { match -> Date? in
            let window = mealWindow(for: match.mealTitle)
            guard let cutoff = date(
                atHour: window.cutoffHour,
                minute: window.cutoffMinute,
                on: now,
                calendar: calendar
            ), now < cutoff else {
                return nil
            }
            return date(
                atHour: window.targetHour,
                minute: window.targetMinute,
                on: now,
                calendar: calendar
            )
        }

        guard let earliestTarget = targetDates.min() else { return nil }

        // If the meal's pre-meal target hasn't arrived yet, fire at that target
        // (clamped to no earlier than 7:30 AM). Otherwise, delay 15s past launch.
        let candidate: Date
        if earliestTarget > now {
            candidate = max(earliestTarget, earliestAllowed)
        } else {
            candidate = max(now.addingTimeInterval(15), earliestAllowed)
        }

        guard candidate <= latestAllowed else { return nil }
        return candidate
    }

    /// Local calendar day key ("YYYY-MM-DD") used to dedupe the daily digest.
    static func dayKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Meal windows

    private struct MealWindow {
        let targetHour: Int
        let targetMinute: Int
        let cutoffHour: Int
        let cutoffMinute: Int
    }

    private static func mealWindow(for mealTitle: String) -> MealWindow {
        let lowered = mealTitle.lowercased()
        if lowered.contains("breakfast") {
            return MealWindow(targetHour: 8, targetMinute: 0, cutoffHour: 10, cutoffMinute: 30)
        }
        if lowered.contains("brunch") {
            return MealWindow(targetHour: 10, targetMinute: 0, cutoffHour: 14, cutoffMinute: 0)
        }
        if lowered.contains("lunch") {
            return MealWindow(targetHour: 11, targetMinute: 30, cutoffHour: 14, cutoffMinute: 30)
        }
        if lowered.contains("late") {
            return MealWindow(targetHour: 19, targetMinute: 30, cutoffHour: 20, cutoffMinute: 0)
        }
        // Dinner, Supper, All Day, or single-menu halls
        return MealWindow(targetHour: 17, targetMinute: 0, cutoffHour: 20, cutoffMinute: 0)
    }

    private static func hasMealEnded(
        _ mealTitle: String,
        at now: Date,
        calendar: Calendar
    ) -> Bool {
        let window = mealWindow(for: mealTitle)
        guard let cutoff = date(
            atHour: window.cutoffHour,
            minute: window.cutoffMinute,
            on: now,
            calendar: calendar
        ) else {
            return false
        }
        return now >= cutoff
    }

    private static func date(
        atHour hour: Int,
        minute: Int,
        on reference: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference)
    }
}
