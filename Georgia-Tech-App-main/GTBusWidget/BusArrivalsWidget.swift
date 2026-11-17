//
//  BusArrivalsWidget.swift
//  GTBusWidget
//
//  Widget-specific version with only the functions needed by the widget.
//  The full BusArrivals.swift (with BusStop/BusRoute overloads) stays in the main app.

import Foundation

enum BusArrivalsWidget {
    /// All predicted arrivals at a stop, soonest first. Empty when no
    /// vehicle is coming — honest, never guessed.
    static func etas(to routeStopID: Int, estimates: [Int: [BusStopEstimate]]) -> [Int] {
        (estimates[routeStopID] ?? [])
            .filter(\.isOnRoute)
            .map(\.secondsToStop)
            .sorted()
    }

    static func minutesText(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(minutes) min"
    }
}
