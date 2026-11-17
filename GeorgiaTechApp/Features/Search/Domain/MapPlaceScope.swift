//
//  MapPlaceScope.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation

/// Place sets that aren't a *type* of place — they're a relationship to
/// the user: what's close, what they saved, what everyone goes to.
///
/// Deliberately NOT cases of `SearchCategories`: that enum answers "what
/// kind of thing is this" and drives an exhaustive search switch keyed on
/// the location `type` field. These three are computed from user state
/// and location instead, so they get their own type and their own slot in
/// `MapSelection`. One definition serves both surfaces that show them —
/// the resting sheet's sections and the map's floating chip rail.
enum MapPlaceScope: String, CaseIterable, Identifiable {
    case popular
    case nearby
    case favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .popular: "Popular"
        case .nearby: "Nearby"
        case .favorites: "Favorites"
        }
    }

    /// The sheet has room for the full phrase; the rail chip doesn't.
    var sectionTitle: String {
        switch self {
        case .popular: "Popular on Campus"
        case .nearby: "Nearby"
        case .favorites: "Favorites"
        }
    }

    var systemImage: String {
        switch self {
        case .popular: "star"
        case .nearby: "location"
        case .favorites: "heart"
        }
    }

    /// How many the sheet previews before its "see all" affordance.
    static let nearbyLimit = 5

    func places(in data: SearchableData) -> [SearchCardModel] {
        switch self {
        case .popular:
            // Stacked under Nearby in the sheet, so anchors the user is
            // already standing next to don't get listed twice.
            return PopularPlaces.resolve(
                from: data.locations,
                excluding: Set(Self.nearby.places(in: data).map(\.id)))
        case .nearby:
            return Self.nearestPlaces(in: data)
        case .favorites:
            return FavoritesService.shared.fetchAllAsCards()
        }
    }

    /// Closest buildings + dining to the user — real distances only, so
    /// this is empty until there's a location fix.
    private static func nearestPlaces(in data: SearchableData) -> [SearchCardModel] {
        guard let user = data.userLocation else { return [] }
        let origin = CLLocation(latitude: user.latitude, longitude: user.longitude)

        let candidates = data.locations.map { $0.toSearchCard() }
            + data.restaurants.map { $0.toSearchCard() }
        return candidates
            .compactMap { card -> (SearchCardModel, CLLocationDistance)? in
                guard let coordinate = card.coordinate else { return nil }
                return (card, origin.distance(
                    from: CLLocation(
                        latitude: coordinate.latitude, longitude: coordinate.longitude)))
            }
            .sorted { $0.1 < $1.1 }
            .prefix(nearbyLimit)
            .map(\.0)
    }
}
