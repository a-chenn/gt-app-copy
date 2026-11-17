//
//  Appliance.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import SwiftData

enum ApplianceType: String, Codable {
    case printer
    case microwave
    case vending
}

@Model final class Appliance: Identifiable {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var building: String
    var floor: [Int]
    var room: String
    var latitude: Double
    var longitude: Double
    var details: String
    var color: Bool?
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    @Transient var type: ApplianceType? {
        get { ApplianceType(rawValue: typeRaw) }
        set { typeRaw = newValue?.rawValue ?? "" }
    }
    init(
        id: String, type: ApplianceType, building: String, floor: [Int], room: String,
        latitude: Double,
        longitude: Double, details: String, color: Bool? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.building = building
        self.floor = floor
        self.room = room
        self.latitude = latitude
        self.longitude = longitude
        self.details = details
        self.color = color
    }
}
