//
//  MapRouteOverlay.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftUI

struct MapRouteOverlay: MapContent {
    let routes: [MKRoute]

    var body: some MapContent {
        // Gold over a navy underlay — readable on both light and dark maps.
        ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
            MapPolyline(route.polyline)
                .stroke(Color.gtNavy, lineWidth: 8)
            MapPolyline(route.polyline)
                .stroke(Color.gtGold, lineWidth: 5)
        }
    }
}
