//
//  TransitPlanner.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import MapKit

/// A bus-inclusive route: walk to a stop, ride, walk to the destination.
/// Only produced when a live bus can actually serve the trip — wait times
/// come from the shared arrival predictions, never a made-up headway.
struct TransitPlan {
    let routeID: Int
    let routeName: String
    let routeColorHex: String
    let boardRouteStopID: Int
    let alightRouteStopID: Int
    let boardStopName: String
    let alightStopName: String
    let boardCoordinate: CLLocationCoordinate2D
    let alightCoordinate: CLLocationCoordinate2D
    let walkToStop: MKRoute
    let walkToDestination: MKRoute
    /// Seconds from now until the first CATCHABLE bus reaches the board
    /// stop (always >= the walk time there).
    let busArrivesInSeconds: Int
    let rideSeconds: Int
    let ridePolyline: MKPolyline?
    /// Arrival math in the plan is relative to when it was computed —
    /// live decay measures elapsed time from here, not navigation start.
    let createdDate = Date()

    /// Time spent standing at the stop after walking there.
    var waitSeconds: Int {
        max(busArrivesInSeconds - Int(walkToStop.expectedTravelTime), 0)
    }

    var totalSeconds: TimeInterval {
        // Walking and the bus's approach overlap — the clock to boarding
        // is busArrivesInSeconds, not walk + wait.
        Double(busArrivesInSeconds) + Double(rideSeconds)
            + walkToDestination.expectedTravelTime
    }

    var totalDistance: CLLocationDistance {
        walkToStop.distance + walkToDestination.distance
    }
}

/// Why there's no bus plan matters to the UI: "walking beats the bus"
/// recommends walking; "no service" just says so.
enum TransitPlanResult {
    case plan(TransitPlan)
    case walkingIsFaster
    case unavailable
}

enum TransitPlanner {
    /// Builds the best bus-inclusive plan — walk + wait + ride + walk.
    /// When every candidate loses to simply walking the whole way, the
    /// result says so instead of pretending there's no service (#R3-4).
    @MainActor
    static func plan(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        routes: [BusRoute],
        liveBuses: [BusLive],
        estimates: [Int: [BusStopEstimate]]
    ) async -> TransitPlanResult {
        struct Candidate {
            let route: BusRoute
            let board: BusStop
            let alight: BusStop
            let rideSeconds: Int
            let walkMeters: Double
        }

        let directMeters = distance(origin, destination)
        var candidates: [Candidate] = []
        var sawSlowerThanWalking = false
        var sawMissingEstimates = false

        for route in routes where route.isRunning && !route.stops.isEmpty {
            guard liveBuses.contains(where: { $0.routeID == route.routeID && $0.isOnRoute }) else {
                continue
            }
            guard
                let board = nearestStop(to: origin, on: route),
                let alight = nearestStop(to: destination, on: route),
                board.routeStopID != alight.routeStopID,
                let rideSeconds = BusArrivals.rideSeconds(from: board, to: alight, on: route)
            else { continue }

            let walkMeters = distance(origin, board.coordinate)
                + distance(alight.coordinate, destination)
            // Riding must actually shorten the walk to be worth proposing.
            guard walkMeters < directMeters else {
                sawSlowerThanWalking = true
                continue
            }

            candidates.append(Candidate(
                route: route, board: board, alight: alight,
                rideSeconds: rideSeconds, walkMeters: walkMeters))
        }

        // Walking pace ~80 m/min gives a fair apples-to-apples pre-ranking
        // before spending MKDirections requests on the best candidate.
        let ranked = candidates.sorted {
            ($0.walkMeters / 1.33 + Double($0.rideSeconds))
                < ($1.walkMeters / 1.33 + Double($1.rideSeconds))
        }

        for candidate in ranked.prefix(2) {
            guard
                let walkToStop = await walkingRoute(
                    from: mapItem(at: origin), to: candidate.board.coordinate),
                let walkToDestination = await walkingRoute(
                    from: mapItem(at: candidate.alight.coordinate), to: destination)
            else { continue }

            // Walking-aware wait with cycle-wrapping: a bus that arrives
            // before the rider does rolls to its next loop instead of
            // being discarded.
            let walkSeconds = Int(walkToStop.expectedTravelTime)
            guard let wait = BusArrivals.waitSeconds(
                to: candidate.board, on: candidate.route, estimates: estimates,
                afterWalkingSeconds: walkSeconds)
            else {
                // No prediction for a viable candidate is a DATA gap, not
                // evidence that walking wins.
                sawMissingEstimates = true
                continue
            }
            let catchable = walkSeconds + wait

            // A bus plan slower than simply walking the whole way isn't
            // worth proposing (walking pace ~1.33 m/s).
            let totalSeconds = Double(catchable + candidate.rideSeconds)
                + walkToDestination.expectedTravelTime
            guard totalSeconds < directMeters / 1.33 else {
                sawSlowerThanWalking = true
                continue
            }

            // An intermediate stop pins the rendered arc to the direction
            // the bus actually drives (matters for loop routes).
            let midpoint = BusArrivals.midpointStop(
                from: candidate.board, to: candidate.alight, on: candidate.route)
            let ridePolyline = MKPolyline(encodedString: candidate.route.polyline)?
                .slice(
                    from: candidate.board.coordinate,
                    to: candidate.alight.coordinate,
                    via: midpoint?.coordinate)?
                .used

            return .plan(TransitPlan(
                routeID: candidate.route.routeID,
                routeName: candidate.route.name,
                routeColorHex: candidate.route.mapColor,
                boardRouteStopID: candidate.board.routeStopID,
                alightRouteStopID: candidate.alight.routeStopID,
                boardStopName: candidate.board.name,
                alightStopName: candidate.alight.name,
                boardCoordinate: candidate.board.coordinate,
                alightCoordinate: candidate.alight.coordinate,
                walkToStop: walkToStop,
                walkToDestination: walkToDestination,
                busArrivesInSeconds: catchable,
                rideSeconds: candidate.rideSeconds,
                ridePolyline: ridePolyline))
        }

        return (sawSlowerThanWalking && !sawMissingEstimates) ? .walkingIsFaster : .unavailable
    }

    // MARK: - Helpers

    private static func nearestStop(to coordinate: CLLocationCoordinate2D, on route: BusRoute) -> BusStop? {
        route.stops.min {
            distance(coordinate, $0.coordinate) < distance(coordinate, $1.coordinate)
        }
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil)
    }

    private static func walkingRoute(
        from source: MKMapItem, to destination: CLLocationCoordinate2D
    ) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = source
        request.destination = mapItem(at: destination)
        request.transportType = .walking
        return try? await MKDirections(request: request).calculate().routes.first
    }
}
