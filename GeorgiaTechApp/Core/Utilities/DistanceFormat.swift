//
//  DistanceFormat.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation

enum DistanceFormat {
    /// "350 ft" under a tenth of a mile, "0.4 mi" otherwise.
    static func text(meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 { return "\(Int(meters * 3.28084)) ft" }
        return String(format: "%.1f mi", miles)
    }

    static func text(from user: CLLocationCoordinate2D?, to target: CLLocationCoordinate2D?) -> String? {
        guard let user, let target else { return nil }
        let meters = CLLocation(latitude: user.latitude, longitude: user.longitude)
            .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        return text(meters: meters)
    }
}
