//
//  CampusSearchService.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import MapKit

final class CampusSearchService {
    func search(_ category: SearchCategories, data: SearchableData) -> [SearchCardModel] {
        switch category {
        case .dining:
            return data.restaurants.map { $0.toSearchCard() }
        case .academicBuildings:
            return locations(ofType: "academic", in: data)
        case .athletics:
            return locations(ofType: "athletics", in: data)
        case .dorms:
            return locations(ofType: "housing", in: data)
        case .parking:
            return locations(ofType: "parkingDecks", in: data)
        case .printers:
            return appliances(ofType: .printer, in: data)
        case .microwaves:
            return appliances(ofType: .microwave, in: data)
        case .vendingMachines:
            return appliances(ofType: .vending, in: data)
        }
    }

    /// Free-text name search across campus data — buildings, dining, and
    /// bus stops (#R4-15). Appliances stay category-driven: N identical
    /// "Clough Commons" printer rows would drown the building itself.
    /// Prefix matches rank first, then shorter names.
    func search(text: String, data: SearchableData) -> [SearchCardModel] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }

        var cards: [SearchCardModel] = []
        cards += data.locations
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map { $0.toSearchCard() }
        cards += data.restaurants
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map { $0.toSearchCard() }

        // The same physical stop repeats across routes — one row each.
        var seenStopNames = Set<String>()
        cards += data.busRoutes
            .filter(\.isRunning)
            .flatMap(\.stops)
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .compactMap { stop in
                seenStopNames.insert(stop.name).inserted ? stop.toSearchCard() : nil
            }

        let lowered = query.lowercased()
        return cards.sorted { a, b in
            let aPrefix = a.title.lowercased().hasPrefix(lowered)
            let bPrefix = b.title.lowercased().hasPrefix(lowered)
            if aPrefix != bPrefix { return aPrefix }
            return a.title.count < b.title.count
        }
    }

    // The backend's `type` values are camelCase ("academic", "parkingDecks");
    // compare case-insensitively so a server-side casing change can't
    // silently empty a category again.
    private func locations(ofType type: String, in data: SearchableData) -> [SearchCardModel] {
        data.locations
            .filter { $0.type.caseInsensitiveCompare(type) == .orderedSame }
            .map { $0.toSearchCard() }
    }

    private func appliances(ofType type: ApplianceType, in data: SearchableData) -> [SearchCardModel] {
        data.appliances
            .filter { $0.type == type }
            .map { $0.toSearchCard() }
    }
}
