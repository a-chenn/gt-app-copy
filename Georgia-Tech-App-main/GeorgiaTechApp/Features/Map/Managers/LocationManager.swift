//
//  LocationManager.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// Full latest fix — navigation needs accuracy and course, not just
    /// the coordinate.
    var lastLocation: CLLocation?
    var isAuthorized: Bool = false

    var location: CLLocationCoordinate2D? {
        lastLocation?.coordinate
    }

    /// Direction of travel in degrees, when moving with a valid course.
    var course: Double? {
        guard let lastLocation, lastLocation.course >= 0, lastLocation.speed > 0.5 else { return nil }
        return lastLocation.course
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
}
