//
//  MapSelection.swift
//  GeorgiaTechApp
//

import Foundation

/// Shared state connecting the search sheet, the floating chip rail, and
/// the map surface: which categories' pins are up, and which single place
/// (if any) is selected and showing its detail card.
///
/// Category chips are exclusive (one at a time); scope chips (Popular /
/// Nearby) are additive.
@Observable
@MainActor
final class MapSelection {
    private(set) var selectedPlace: SearchCardModel?
    private(set) var pinCategories: [SearchCategories: [SearchCardModel]] = [:]
    /// Popular / Nearby pins from the chip rail — not a kind of place,
    /// so kept apart from `pinCategories` (see `MapPlaceScope`).
    private(set) var pinScopes: [MapPlaceScope: [SearchCardModel]] = [:]
    /// The rail's single active category (chip highlight + sheet results).
    private(set) var activeCategory: SearchCategories?
    /// The live bus the map and sheet are following (Figma "specific
    /// stop list view"): the map focuses it, the sheet shows its stops.
    var focusedBusID: Int?
    /// A route opened from a stop card (Figma "specific route"): the map
    /// shows only this route until the card goes back.
    var focusedBusRouteID: Int?

    /// Everything that should currently render as a pin. The selected place
    /// is included even when it isn't part of any active category.
    var mapPlaces: [SearchCardModel] {
        var places: [SearchCardModel] = []
        var seen = Set<String>()
        for results in Array(pinCategories.values) + Array(pinScopes.values) {
            for card in results where !seen.contains(card.id) {
                seen.insert(card.id)
                places.append(card)
            }
        }
        if let selectedPlace, !seen.contains(selectedPlace.id) {
            places.append(selectedPlace)
        }
        return places
    }

    func isPinScopeActive(_ scope: MapPlaceScope) -> Bool {
        pinScopes[scope] != nil
    }

    /// A scope turns its own pins on or off and leaves everything else
    /// alone.
    func togglePinScope(_ scope: MapPlaceScope, results: [SearchCardModel]) {
        if pinScopes[scope] != nil {
            pinScopes[scope] = nil
        } else {
            pinScopes[scope] = results.filter { $0.coordinate != nil }
        }
    }

    func select(_ place: SearchCardModel?) {
        selectedPlace = place
    }

    /// Opens a category: its pins replace any other category's, and the
    /// sheet (observing `activeCategory`) shows its results. Re-issuing
    /// the open category with a narrower list is how the sheet's filter
    /// pills keep the pins matching what it shows.
    func showCategory(_ category: SearchCategories, results: [SearchCardModel]) {
        activeCategory = category
        pinCategories = [category: results.filter { $0.coordinate != nil }]
    }

    /// Clears category pins only; scope pins stay up.
    func clearCategory() {
        activeCategory = nil
        pinCategories = [:]
    }

    func clearResults() {
        clearCategory()
        pinScopes = [:]
    }

    func clear() {
        selectedPlace = nil
        focusedBusID = nil
        focusedBusRouteID = nil
        clearResults()
    }
}
