//
//  DiningMenu.swift
//  GeorgiaTechApp
//

import Foundation

/// Pure helpers for the dining API's menu format: a restaurant has one
/// menu per meal period, each with per-day item lists where station
/// headers and foods are interleaved by `position`.
enum DiningMenu {
    struct StationSection: Identifiable {
        let id: String
        let name: String
        var items: [MenuItem]
    }

    /// Groups a day's items into station sections, preserving API order.
    static func stationSections(from menuItems: [MenuItem]) -> [StationSection] {
        let sorted = menuItems.sorted { $0.position < $1.position }
        var sections: [StationSection] = []

        for item in sorted {
            if item.isStationHeader {
                let name = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                sections.append(StationSection(id: "station-\(item.itemID)", name: name, items: []))
                continue
            }

            let name = (item.food?.name ?? item.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            if sections.isEmpty {
                sections.append(StationSection(id: "station-default", name: "Menu", items: []))
            }
            sections[sections.count - 1].items.append(item)
        }

        return sections.filter { !$0.items.isEmpty }
    }

    /// The menu day matching a calendar date (dates arrive as "yyyy-MM-dd…").
    /// Keyed off the local calendar — ISO8601 formatting would use UTC and
    /// serve tomorrow's menu every evening after 8 PM Atlanta time.
    static func day(
        in menu: RestaurantMenu, for date: Date = Date(), calendar: Calendar = .current
    ) -> MenuDay? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return menu.days.first { String($0.date.prefix(10)) == key }
    }

    /// Every distinct date any of the restaurant's menus covers, sorted —
    /// the range the day arrows can rotate through.
    static func availableDates(
        in menus: [RestaurantMenu], calendar: Calendar = .current
    ) -> [Date] {
        let keys = Set(menus.flatMap { menu in menu.days.map { String($0.date.prefix(10)) } })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return keys.compactMap { formatter.date(from: $0) }.sorted()
    }

    /// "Today"/"Tomorrow"/"Yesterday", else "Wed, Jul 22".
    static func dayTitle(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Menus in a stable meal-period order. SwiftData to-many relationship
    /// arrays don't guarantee order, so index-based meal titles must always
    /// go through this (sorted by the API's menuTypeId, then menuID).
    static func orderedMenus(_ menus: [RestaurantMenu]) -> [RestaurantMenu] {
        menus.sorted {
            if $0.menuTypeId != $1.menuTypeId { return $0.menuTypeId < $1.menuTypeId }
            return ($0.menuID ?? 0) < ($1.menuID ?? 0)
        }
    }

    /// Meal-period titles inferred from how many menus a restaurant has.
    static func mealTitle(at index: Int, of count: Int) -> String {
        switch count {
        case 1: return "All Day"
        case 2: return ["Day", "Night"][index]
        case 3: return ["Breakfast", "Lunch", "Dinner"][index]
        case 4: return ["Breakfast", "Lunch", "Dinner", "Overnight"][index]
        default: return "Menu \(index + 1)"
        }
    }

    /// Applies dietary filters: preference filters (Vegan, Halal, …) keep
    /// only items tagged with every selected preference; allergen filters
    /// hide items tagged with any selected allergen. Items with no food/tag
    /// data are hidden while any filter is active — the safe direction when
    /// someone is filtering for an allergy.
    static func filteredItems(
        _ items: [MenuItem], selectedFilters: [DietaryFilter]
    ) -> [MenuItem] {
        guard !selectedFilters.isEmpty else { return items }

        let preferences = selectedFilters.filter { $0.category == .preference }
        let allergens = selectedFilters.filter { $0.category == .allergen }

        return items.filter { item in
            // No food record OR an empty tag list both mean "unknown
            // ingredients" — hidden while filtering, never shown as safe.
            guard let tags = item.food?.tags, !tags.isEmpty else { return false }
            let normalized = Set(tags.map { $0.lowercased() })

            let matchesPreferences = preferences.allSatisfy {
                $0.matches(normalizedTags: normalized)
            }
            let containsAllergen = allergens.contains {
                $0.matches(normalizedTags: normalized)
            }
            return matchesPreferences && !containsAllergen
        }
    }
}
