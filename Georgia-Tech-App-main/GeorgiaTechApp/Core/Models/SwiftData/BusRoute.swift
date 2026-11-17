//
//  BusRouteModel.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/26/26.
//

import Foundation
import SwiftData

@Model final class BusRoute: Identifiable {
    @Attribute(.unique) var routeID: Int
    var id: Int { routeID }
    var name: String
    var busColor: String
    var mapColor: String
    var polyline: String
    var isRunning: Bool
    // One route has many route-specific stops. Live vehicles are ephemeral
    // telemetry (BusLive via BusLiveManager) and are never persisted.
    @Relationship(inverse: \BusStop.routes) var stops: [BusStop] = []
    init(
        routeID: Int, name: String, busColor: String, mapColor: String, polyline: String,
        isRunning: Bool
    ) {
        self.routeID = routeID
        self.name = name
        self.busColor = busColor
        self.mapColor = mapColor
        self.polyline = polyline
        self.isRunning = isRunning
    }
}
