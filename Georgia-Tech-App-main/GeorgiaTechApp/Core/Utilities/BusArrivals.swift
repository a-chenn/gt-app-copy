//
//  BusArrivals.swift
//  GeorgiaTechApp
//

import Foundation

/// Reads shared hybrid arrival predictions with TransLoc fallback. Historical
/// averages and offsets are applied upstream; route schedules are used here
/// only for ride durations and the loop-cycle wrap, never position-based ETAs.
enum BusArrivals {

    // MARK: - Arrivals (live estimates)

    /// Overload for callers (widgets, previews) that hold only a routeStopID
    /// rather than a full BusStop SwiftData model.
    static func etas(to routeStopID: Int, estimates: [Int: [BusStopEstimate]]) -> [Int] {
        (estimates[routeStopID] ?? [])
            .filter(\.isOnRoute)
            .map(\.secondsToStop)
            .sorted()
    }

    /// All predicted arrivals at a stop, soonest first. Empty when no
    /// vehicle is coming — honest, never guessed.
    static func etas(to targetStop: BusStop, estimates: [Int: [BusStopEstimate]]) -> [Int] {
        etas(to: targetStop.routeStopID, estimates: estimates)
    }

    /// Seconds the rider will actually wait at the stop, given they need
    /// `afterWalkingSeconds` to get there. A bus is catchable until it
    /// DEPARTS (arrival + board dwell) — `rideSeconds` models the rider
    /// aboard from bus arrival, so wrapping on bare arrival would discard
    /// catchable buses. A missed departure rolls as many loops as the
    /// walk requires, never silently clamping to zero.
    static func waitSeconds(
        to targetStop: BusStop, on route: BusRoute,
        estimates: [Int: [BusStopEstimate]], afterWalkingSeconds: Int
    ) -> Int? {
        let arrivals = etas(to: targetStop, estimates: estimates)
        guard !arrivals.isEmpty else { return nil }

        let cycle = max(routeCycleSeconds(route), 60)
        let dwell = max(targetStop.secondsAtStop, 0)
        let waits = arrivals.map { arrival -> Int in
            var next = arrival
            while next + dwell < afterWalkingSeconds {
                next += cycle
            }
            return max(next - afterWalkingSeconds, 0)
        }
        return waits.min()
    }

    /// The next stops ahead of one live vehicle, soonest first — the
    /// popover's "next 3 stops" (#5).
    static func upcomingStops(
        for vehicleID: Int, on route: BusRoute,
        estimates: [Int: [BusStopEstimate]], count: Int = 3
    ) -> [(stop: BusStop, seconds: Int)] {
        let stopsByID = Dictionary(
            route.stops.map { ($0.routeStopID, $0) },
            uniquingKeysWith: { first, _ in first })

        return estimates.values
            .flatMap { $0 }
            .filter { $0.vehicleID == vehicleID && $0.isOnRoute }
            .compactMap { estimate in
                stopsByID[estimate.routeStopID].map { ($0, estimate.secondsToStop) }
            }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Schedule-derived durations

    /// One full loop of the route in seconds (dwell + leg for every stop) —
    /// used only to roll a missed bus to its next pass.
    static func routeCycleSeconds(_ route: BusRoute) -> Int {
        route.stops.reduce(0) { $0 + max($1.secondsAtStop, 0) + max($1.secondsToNextStop, 0) }
    }

    /// Ride time between two stops on a route, following stop order and
    /// wrapping around the loop. Starts at bus ARRIVAL at the board stop
    /// (matching where `etas` ends), so the board-stop dwell is included;
    /// the alight-stop dwell is not — the rider is off by then.
    static func rideSeconds(from board: BusStop, to alight: BusStop, on route: BusRoute) -> Int? {
        let stops = route.stops.sorted { $0.stopOrder < $1.stopOrder }
        guard !stops.isEmpty,
              var index = stops.firstIndex(where: { $0.routeStopID == board.routeStopID }),
              let alightIndex = stops.firstIndex(where: { $0.routeStopID == alight.routeStopID }),
              index != alightIndex
        else { return nil }

        var seconds = stops[index].secondsAtStop
        var hops = 0
        while index != alightIndex {
            seconds += stops[index].secondsToNextStop
            index = (index + 1) % stops.count
            if index != alightIndex {
                seconds += stops[index].secondsAtStop
            }
            hops += 1
            if hops > stops.count { return nil }
        }
        return seconds
    }

    /// The intermediate stop roughly halfway through a ride — used to pick
    /// the correct polyline arc for rendering the bus leg.
    static func midpointStop(from board: BusStop, to alight: BusStop, on route: BusRoute) -> BusStop? {
        let stops = route.stops.sorted { $0.stopOrder < $1.stopOrder }
        guard stops.count > 2,
              let boardIndex = stops.firstIndex(where: { $0.routeStopID == board.routeStopID }),
              let alightIndex = stops.firstIndex(where: { $0.routeStopID == alight.routeStopID }),
              boardIndex != alightIndex
        else { return nil }

        let hops = (alightIndex - boardIndex + stops.count) % stops.count
        guard hops >= 2 else { return nil }
        return stops[(boardIndex + hops / 2) % stops.count]
    }

    static func minutesText(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(minutes) min"
    }
}
