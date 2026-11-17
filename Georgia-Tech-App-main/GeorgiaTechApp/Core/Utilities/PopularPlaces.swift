//
//  PopularPlaces.swift
//  GeorgiaTechApp
//

import Foundation

/// Campus anchors everyone looks for — curated names resolved against the
/// real location data, so only places that actually exist render. Shared
/// by the resting sheet's "Popular on Campus" section and the blank map's
/// default pins (#R4-7).
enum PopularPlaces {
    static let curatedTerms = [
        "bobby dodd", "student center", "library", "campus recreation", "tech green"
    ]

    /// Skips parking decks and prefers the shortest matching name so
    /// "student center" resolves to the building, not its deck.
    static func resolve(
        from locations: [CampusLocation], excluding excludedIDs: Set<String> = []
    ) -> [SearchCardModel] {
        var seen = Set<String>()
        var result: [SearchCardModel] = []
        for term in curatedTerms {
            let match = locations
                .filter {
                    $0.name.lowercased().contains(term)
                        && $0.type.caseInsensitiveCompare("parkingDecks") != .orderedSame
                        && !seen.contains($0.locationId)
                        && !excludedIDs.contains($0.locationId)
                }
                .min { $0.name.count < $1.name.count }
            if let match {
                seen.insert(match.locationId)
                result.append(match.toSearchCard())
            }
        }
        return result
    }
}
