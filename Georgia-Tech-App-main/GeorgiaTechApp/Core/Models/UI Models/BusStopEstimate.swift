//
//  BusStopEstimate.swift
//  GeorgiaTechApp
//

import Foundation

/// One vehicle's system-computed arrival prediction for one route stop.
/// Ephemeral telemetry like `BusLive` — polled, never persisted.
nonisolated struct BusStopEstimate: Sendable {
    let routeStopID: Int
    let stopOrder: Int
    let vehicleID: Int
    let secondsToStop: Int
    let isOnRoute: Bool
    /// Original and adjusted predictions retained for diagnostics and future presentation.
    var arrival: Arrival?

    /// Flattens the relay payload into a lookup keyed by `routeStopID`,
    /// each stop's estimates soonest-first.
    static func byStop(_ routes: [BusStopEstimateRouteJSON]) -> [Int: [BusStopEstimate]] {
        var result: [Int: [BusStopEstimate]] = [:]
        for route in routes {
            for stop in route.routeStops {
                let entries = (stop.estimates ?? []).map { estimate in
                    BusStopEstimate(
                        routeStopID: stop.routeStopID,
                        stopOrder: stop.stopOrder,
                        vehicleID: estimate.vehicleID,
                        secondsToStop: estimate.secondsToStop,
                        isOnRoute: estimate.onRoute)
                }
                if !entries.isEmpty {
                    result[stop.routeStopID, default: []] += entries
                }
            }
        }
        for key in result.keys {
            result[key]?.sort { $0.secondsToStop < $1.secondsToStop }
        }
        return result
    }
}
