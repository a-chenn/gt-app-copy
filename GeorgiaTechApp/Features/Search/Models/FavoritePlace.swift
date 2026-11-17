//
//  FavoritePlace.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import MapKit
import SwiftData

@Model
final class FavoritePlace {
    @Attribute(.unique) var id: String
    var title: String
    var subtitle: String?
    var image: String?
    var category: String
    var latitude: Double?
    var longitude: Double?
    var date: Date

    init(
        id: String, title: String, subtitle: String?, image: String?,
        category: LocationCategory, latitude: Double? = nil, longitude: Double? = nil,
        date: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.category = category.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
    }
}

// MARK: - Mapping
extension FavoritePlace {
    func toSearchCard() -> SearchCardModel {
        var destination: RouteStop?
        if let latitude, let longitude {
            destination = RouteStop(
                name: title,
                mapItem: MKMapItem(
                    location: CLLocation(latitude: latitude, longitude: longitude),
                    address: nil))
        }
        return SearchCardModel(
            id: id, title: title, subtitle: subtitle,
            destination: destination, image: image,
            category: LocationCategory(rawValue: category) ?? .mapItem,
            date: date
        )
    }
}
