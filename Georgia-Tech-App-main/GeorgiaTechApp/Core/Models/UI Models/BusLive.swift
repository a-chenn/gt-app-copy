//
//  BusLiveModel.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/27/26.
//

import CoreLocation
import Foundation
import MapKit

/// Elapsed time since an observed arrival, confirmed by the most recent GPS fix.
nonisolated struct BusDwell: Sendable {
    let stopName: String
    let seconds: Int
    let expiresAt: Date
}

nonisolated struct BusLive: Identifiable, Sendable {
    let vehicleID: Int
    var id: Int { vehicleID }
    let routeID: Int
    let currentOccupation: Int
    let capacityPercentage: Double?
    let latitude: Double
    let longitude: Double
    let heading: Int
    let groundSpeed: Float
    let isDelayed: Bool
    let isOnRoute: Bool
    /// TransLoc's vehicle name — the number painted on the bus ("2203").
    let name: String?
    var dwell: BusDwell?

    /// "2203", or the vehicle ID when TransLoc sends no name.
    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "\(vehicleID)"
    }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Transloc reports heading 0 (north) when bus is stopped
    var isStopped: Bool { groundSpeed < 1 }

    func displayHeading(along polyline: MKPolyline?) -> Double {
        guard isStopped,
              let next = polyline?.nextCoordinate(after: coordinate)
        else { return Double(heading) }
        return coordinate.bearing(to: next)
    }

    /// Combines a vehicle's latest position with available capacity and dwell data.
    init(location: BusLocationJSON, capacity: BusCapacityJSON?, dwell: BusDwell? = nil) {
        self.vehicleID = location.vehicleID
        self.routeID = location.routeID
        self.currentOccupation = capacity?.currentOccupation ?? 0
        // Derived locally from the two integer fields — the feed's own
        // `Percentage` value has no documented scale.
        if let capacity, capacity.capacity > 0 {
            self.capacityPercentage =
                Double(capacity.currentOccupation) / Double(capacity.capacity) * 100
        } else {
            self.capacityPercentage = nil
        }
        self.latitude = location.busLatitude
        self.longitude = location.busLongitude
        self.groundSpeed = Float(location.groundSpeed ?? 0)
        self.heading = location.heading
        self.isDelayed = location.isDelayed
        self.isOnRoute = location.isOnRoute
        self.name = location.name
        self.dwell = dwell
    }
}

extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
