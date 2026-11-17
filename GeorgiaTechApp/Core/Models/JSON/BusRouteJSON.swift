//
//  BusRouteJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/27/26.
//

import Foundation

nonisolated struct BusRouteJSON: Decodable, Sendable {
    let routeID: Int
    let busColor: String?
    let routeDescription: String
    let mapColor: String
    let polyline: String
    let isRunning: Bool
    let stops: [BusStopJSON]
    
    enum CodingKeys: String, CodingKey {
        case routeID = "RouteID"
        case busColor = "BusColor"
        case routeDescription = "Description"
        case mapColor = "MapLineColor"
        case polyline = "EncodedPolyline"
        case isRunning = "IsRunning"
        case stops = "Stops"
    }
}
