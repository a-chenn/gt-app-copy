//
//  CampusLocation.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/28/26.
//

import CoreLocation
import Foundation
import SwiftData

@Model final class CampusLocation: Identifiable {
    @Attribute(.unique) var locationId: String
    var name: String
    var nameAbbreviated: String
    var latitude: Double
    var longitude: Double
    var img: String?
    var details: String?
    var isMainBuilding: Bool
    var type: String
    var isFavorite: Bool = false
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(
        locationId: String, name: String, nameAbbreviated: String, latitude: Double,
        longitude: Double,
        img: String?, details: String?, isMainBuilding: Bool, type: String
    ) {
        self.locationId = locationId
        self.name = name
        self.nameAbbreviated = nameAbbreviated
        self.latitude = latitude
        self.longitude = longitude
        self.img = img
        self.details = details
        self.isMainBuilding = isMainBuilding
        self.type = type
    }
}
