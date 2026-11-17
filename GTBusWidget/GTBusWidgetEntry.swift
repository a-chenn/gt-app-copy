//
//  GTBusWidgetEntry.swift
//  GTBusWidget
//

import WidgetKit
import Foundation

// MARK: - Slim DTOs (widget-side, never shared with the app)

struct BusSlimRouteJSON: Decodable {
    let routeID: Int
    let name: String
    let mapColor: String
    let isRunning: Bool
    let stops: [BusSlimStopJSON]

    enum CodingKeys: String, CodingKey {
        case routeID = "RouteID"
        case name = "Description"
        case mapColor = "MapLineColor"
        case isRunning = "IsRunning"
        case stops = "Stops"
    }
}

struct BusSlimStopJSON: Decodable {
    let routeStopID: Int
    let stopAddressID: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case routeStopID = "RouteStopID"
        case stopAddressID = "AddressID"
        case name = "Description"
    }
}

// MARK: - Widget data types

/// One arrival row in the widget (one route serving this stop).
struct BusArrivalRow {
    let routeName: String
    let mapColor: String       // hex string from TransLoc feed; used as small dot only
    let secondsToStop: Int     // the pre-computed value for this timeline entry's moment
}

enum BusWidgetState {
    case arrivals([BusArrivalRow])   // happy path: 1–3 rows
    case noService                   // routes exist but none is running
    case noArrivals                  // routes running but nothing coming right now
    case checking                    // countdown expired without a fresh fetch
    case notConfigured               // no stop chosen yet (default state)
    case stopGone                    // configured routeStopID no longer in feed
    case fetchFailed(lastFetchedAt: Date?)
}

struct GTBusEntry: TimelineEntry {
    /// The date WidgetKit uses to schedule this entry's display.
    let date: Date
    /// When the estimates fetch completed — shown as "as of H:MM PM".
    let fetchedAt: Date
    /// The configured stop's display name (used across all states so layout is stable).
    let stopName: String
    /// What to actually render.
    let state: BusWidgetState
    /// routeStopID of the configured stop — used to build widgetURL.
    let routeStopID: Int
}
