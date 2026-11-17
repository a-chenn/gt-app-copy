//
//  MapVM.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftUI

@Observable
@MainActor
final class MapVM {
    /// Injected: owned by AppShellView so the home screen shares the same
    /// location source (nearest-stop card, distance sorts).
    let locationManager: LocationManager

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.7759, longitude: -84.3963),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        ))

    var showBusRoutes = false

    // Tracked from onMapCameraChange so pin clustering scales with zoom.
    var visibleSpanLatitude: Double?

    // Last real course, held through stops so the camera doesn't
    // north-snap at every red light.
    private var lastNavigationHeading: Double = 0

    func followNavigationCamera(at location: CLLocation) {
        if let course = locationManager.course {
            lastNavigationHeading = course
        }
        withAnimation(.linear(duration: 1.0)) {
            position = .camera(MapCamera(
                centerCoordinate: location.coordinate,
                distance: 650,
                heading: lastNavigationHeading,
                pitch: 0
            ))
        }
    }

    func zoomTo(_ members: [SearchCardModel]) {
        let coordinates = members.compactMap(\.coordinate)
        guard let minLat = coordinates.map(\.latitude).min(),
              let maxLat = coordinates.map(\.latitude).max(),
              let minLon = coordinates.map(\.longitude).min(),
              let maxLon = coordinates.map(\.longitude).max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.002)
        )
        withAnimation {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}
