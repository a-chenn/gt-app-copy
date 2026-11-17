//
//  BusStopModel.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/26/26.
//

import CoreLocation
import Foundation
import SwiftData

@Model final class BusStop: Identifiable {
    var stopAddressID: Int
    var id: Int { routeStopID }
    var latitude: Double
    var longitude: Double
    var name: String
    var stopOrder: Int
    var secondsAtStop: Int
    var secondsToNextStop: Int
    @Attribute(.unique) var routeStopID: Int
    var routes: [BusRoute] = []
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    init(
        stopAddressID: Int, latitude: Double, longitude: Double, name: String,
        stopOrder: Int,
        secondAtStop: Int, secondsToNextStop: Int, routeStopID: Int
    ) {
        self.stopAddressID = stopAddressID
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.stopOrder = stopOrder
        self.secondsAtStop = secondAtStop
        self.secondsToNextStop = secondsToNextStop
        self.routeStopID = routeStopID
    }
}
