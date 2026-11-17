//
//  BusStopEstimateJSON.swift
//  GeorgiaTechApp
//

import Foundation

/// One route's stop-arrival predictions from TransLoc's
/// `GetMapStopEstimates` — the relay's only real prediction endpoint
/// (`GetMapVehiclePoints` carries no stop fields at all).
nonisolated struct BusStopEstimateRouteJSON: Decodable, Sendable {
    let routeID: Int
    let routeStops: [RouteStopEstimateJSON]

    enum CodingKeys: String, CodingKey {
        case routeID = "RouteID"
        case routeStops = "RouteStops"
    }
}

nonisolated struct RouteStopEstimateJSON: Decodable, Sendable {
    let routeStopID: Int
    let stopOrder: Int
    let estimates: [StopEstimateJSON]?

    enum CodingKeys: String, CodingKey {
        case routeStopID = "RouteStopID"
        case stopOrder = "StopOrder"
        case estimates = "Estimates"
    }
}

nonisolated struct StopEstimateJSON: Decodable, Sendable {
    let vehicleID: Int
    let secondsToStop: Int
    let onRoute: Bool

    enum CodingKeys: String, CodingKey {
        case vehicleID = "VehicleID"
        case secondsToStop = "SecondsToStop"
        case onRoute = "OnRoute"
    }
}
