//
//  SearchCardModel.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - Search Card UI Model

/// The unified presentation model for every place in the app.
/// Buildings, dining halls, appliances, and bus stops all convert into this
/// one shape so a single pin view, a single detail card, and a single list
/// row can render any of them by branching on `category`.
struct SearchCardModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let destination: RouteStop?
    let image: String?
    let category: LocationCategory
    var date: Date = Date()

    var coordinate: CLLocationCoordinate2D? {
        destination?.mapItem.location.coordinate
    }
}

// MARK: - Categories

enum LocationCategory: String, Codable {
    case building
    case dining
    case printer
    case microwave
    case vending
    case parking
    case busStop
    case event
    case mapItem
    case payment

    var icon: String {
        switch self {
        case .building: return "graduationcap.fill"
        case .dining: return "fork.knife"
        case .printer: return "printer"
        case .microwave: return "microwave"
        case .vending: return "waterbottle.fill"
        case .parking: return "parkingsign"
        case .busStop: return "bus"
        case .event: return "calendar"
        case .mapItem: return "mappin"
        case .payment: return "creditcard"
        }
    }

    var label: String {
        switch self {
        case .building: return "Building"
        case .dining: return "Dining"
        case .printer: return "Printer"
        case .microwave: return "Microwave"
        case .vending: return "Vending Machine"
        case .parking: return "Parking"
        case .busStop: return "Bus Stop"
        case .event: return "Event"
        case .mapItem: return "Place"
        case .payment: return "Payment"
        }
    }

    /// One tint per category so pins, list icons, and chips share a color language.
    var tint: Color {
        switch self {
        case .building: return Color.gtNavy
        case .dining: return Color.gtGold
        case .printer: return Color.gtWhistle
        case .microwave: return Color.gtAzalea
        case .vending: return Color.gtCampanile
        case .parking: return Color.gtNavy
        case .busStop: return Color.gtTechLawn
        case .event: return Color.gtBuzz
        case .mapItem, .payment: return Color.gtSecondaryText
        }
    }

    /// Glyph color that stays legible ON `tint`. The two light golds
    /// only reach ~2–3:1 against white, so they carry navy instead —
    /// everything else is dark enough for a white glyph.
    var glyphColor: Color {
        switch self {
        case .dining, .event: return Color.gtNavy
        default: return Color.gtWhite
        }
    }
}

// MARK: - Campus Models

extension CampusLocation {
    func toSearchCard() -> SearchCardModel {
        let category: LocationCategory =
            type.lowercased().contains("parking") ? .parking : .building
        return SearchCardModel(
            id: locationId, title: name, subtitle: details,
            destination: RouteStop(
                name: name,
                mapItem: MKMapItem(
                    location: CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude),
                    address: nil)), image: img, category: category)
    }
}

extension Restaurant {
    func toSearchCard() -> SearchCardModel {
        SearchCardModel(
            id: restaurantID, title: name, subtitle: address,
            destination: RouteStop(
                name: name,
                mapItem: MKMapItem(
                    location: CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude),
                    address: nil)), image: img, category: .dining)
    }
}

extension Appliance {
    func toSearchCard() -> SearchCardModel {
        let category: LocationCategory
        switch type {
        case .printer: category = .printer
        case .microwave: category = .microwave
        case .vending: category = .vending
        case nil: category = .mapItem
        }

        // Floor first — it's the detail that matters when you're standing
        // in the building looking for the thing (#22).
        var subtitleParts: [String] = []
        if let floorText = floorDescription { subtitleParts.append(floorText) }
        if !room.isEmpty { subtitleParts.append("Room \(room)") }
        let subtitle = subtitleParts.isEmpty ? category.label : subtitleParts.joined(separator: " · ")

        return SearchCardModel(
            id: id, title: building, subtitle: subtitle,
            destination: RouteStop(
                name: building,
                mapItem: MKMapItem(
                    location: CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude),
                    address: nil)), image: nil, category: category)
    }

    private var floorDescription: String? {
        guard !floor.isEmpty else { return nil }
        if floor.count == 1 { return "Floor \(floor[0])" }
        return "Floors \(floor.map(String.init).joined(separator: ", "))"
    }
}

extension BusStop {
    func toSearchCard() -> SearchCardModel {
        SearchCardModel(
            id: "busstop-\(routeStopID)", title: name,
            subtitle: routes.map(\.name).joined(separator: ", "),
            destination: RouteStop(
                name: name,
                mapItem: MKMapItem(
                    location: CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude),
                    address: nil)), image: nil, category: .busStop)
    }
}

// MARK: - Apple Maps Conversion

extension MKMapItem {
    func toSearchCard() -> SearchCardModel {
        let title = name ?? "Unknown Place"
        let subtitle: String? = {
            if let address = addressRepresentations {
                return address.fullAddress(includingRegion: false, singleLine: true)
            }
            return nil
        }()
        let coordinate = location.coordinate
        return SearchCardModel(
            id: "\(title)-\(coordinate.latitude)-\(coordinate.longitude)",
            title: title,
            subtitle: subtitle, destination: RouteStop(name: title, mapItem: self), image: nil,
            category: .mapItem)
    }
}
