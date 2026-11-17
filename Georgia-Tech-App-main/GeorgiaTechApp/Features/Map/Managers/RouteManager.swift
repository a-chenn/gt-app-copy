//
//  RouteManager.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import MapKit

enum RouteTransportMode: String, Hashable, CaseIterable {
    case walking
    case biking
    case driving
    case transit

    var label: String {
        switch self {
        case .walking: return "Walk"
        case .biking: return "Bike"
        case .driving: return "Drive"
        case .transit: return "Bus"
        }
    }

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .biking: return "bicycle"
        case .driving: return "car"
        case .transit: return "bus"
        }
    }

    /// Transit is computed by `TransitPlanner` (GT bus data), not MKDirections.
    var mapKitTransportType: MKDirectionsTransportType? {
        switch self {
        case .walking: return .walking
        case .biking: return .cycling
        case .driving: return .automobile
        case .transit: return nil
        }
    }
}

struct RouteStop: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var mapItem: MKMapItem
    
    static func currentLocation() -> RouteStop {
        RouteStop(name: "Current Location", mapItem: MKMapItem.forCurrentLocation())
    }
}

struct RouteOption {
    let distance: CLLocationDistance
    let time: TimeInterval
}

@Observable
@MainActor
final class RouteManager {
    // MARK: - Route state
    var stops: [RouteStop] = []
    var routeSegments: [MKRoute] = []
    var routeDistance: CLLocationDistance = 0
    var estimatedTravelTime: TimeInterval = 0
    var selectedMode: RouteTransportMode = defaultMode
    var isCalculating = false
    var error: Error?

    /// The bus leg of an active transit route; walk legs live in
    /// `routeSegments` like every other mode.
    var activeTransitPlan: TransitPlan?

    private static var defaultMode: RouteTransportMode {
        RouteTransportMode(
            rawValue: UserDefaults.standard.string(forKey: "defaultTravelMode") ?? ""
        ) ?? .walking
    }
    
    // MARK: - Route planning state (options shown as main-sheet content)
    var planningDestination: SearchCardModel?
    /// The routes shown on the map while choosing (#21): all of the
    /// selected mode's options, with `previewSelectedIndex` full-strength
    /// and the rest dimmed — cleared when planning ends.
    var previewRoutes: [MKRoute] = []
    var previewSelectedIndex = 0
    /// The mode being previewed while choosing — drives the driving-only
    /// traffic layer (#R4-16).
    var previewTransportMode: RouteTransportMode?

    // MARK: - Active navigation state
    var isNavigating = false
    var navigationSteps: [NavigationStep] = []
    /// The step whose polyline the user is currently on.
    var currentStepIndex = 0
    /// The step whose instruction the banner shows — the UPCOMING maneuver
    /// (MapKit executes a step's instruction at its polyline START, so the
    /// next turn is the next step's text).
    var displayedStepIndex = 0
    var distanceToNextManeuver: CLLocationDistance?
    var remainingTravelTime: TimeInterval = 0
    var hasArrived = false

    private var destinationCoordinate: CLLocationCoordinate2D?
    private var lastRerouteDate: Date?
    /// For transit: how many of navigationSteps belong to the first walk leg.
    private var transitFirstLegStepCount = 0
    // Transit trip-phase latches — see updateTransitPhase.
    private var hasReachedBoardStop = false
    private var isRidingBus = false
    private var hasAlightedBus = false

    // MARK: - Single entry point for directions

    func requestDirections(to card: SearchCardModel) {
        guard card.destination != nil else { return }
        RecentsService.shared.record(card)
        planningDestination = card
    }

    func cancelPlanning() {
        planningDestination = nil
        previewRoutes = []
        previewSelectedIndex = 0
        previewTransportMode = nil
    }

    // MARK: - Route calculation

    /// Starts a transit route computed by `TransitPlanner` — same stop
    /// list and segment rendering as every other mode, plus the bus leg.
    func startTransitRoute(_ plan: TransitPlan, from origin: RouteStop? = nil, to destination: RouteStop) {
        stops = [origin ?? .currentLocation(), destination]
        selectedMode = .transit
        activeTransitPlan = plan
        routeSegments = [plan.walkToStop, plan.walkToDestination]
        routeDistance = plan.totalDistance
        estimatedTravelTime = plan.totalSeconds
        error = nil
        planningDestination = nil
        transitFirstLegStepCount = RouteNavigation.steps(from: [plan.walkToStop]).count
        beginNavigation()
    }

    /// Commits a specific chosen route (from the options list) and enters
    /// active navigation.
    func startRoute(
        _ route: MKRoute, mode: RouteTransportMode,
        from origin: RouteStop? = nil, to destination: RouteStop
    ) {
        stops = [origin ?? .currentLocation(), destination]
        selectedMode = mode
        activeTransitPlan = nil
        routeSegments = [route]
        routeDistance = route.distance
        estimatedTravelTime = route.expectedTravelTime
        error = nil
        planningDestination = nil
        transitFirstLegStepCount = 0
        beginNavigation()
    }

    // MARK: - Active navigation

    private func beginNavigation() {
        navigationSteps = RouteNavigation.steps(from: routeSegments)
        resetStepTracking()
        hasArrived = false
        destinationCoordinate = stops.last?.mapItem.location.coordinate
        lastRerouteDate = nil
        hasReachedBoardStop = false
        isRidingBus = false
        hasAlightedBus = false
        previewRoutes = []
        previewSelectedIndex = 0
        previewTransportMode = nil
        isNavigating = true
    }

    private func resetStepTracking() {
        currentStepIndex = 0
        displayedStepIndex = RouteNavigation.upcomingManeuverIndex(
            after: -1, in: navigationSteps)
        distanceToNextManeuver = navigationSteps.first?.distance
        remainingTravelTime = estimatedTravelTime
    }

    /// Adds a stop before the destination mid-navigation (e.g. a parking
    /// deck while driving) and rebuilds the live step list. Failure to
    /// recompute keeps the current route intact.
    func addIntermediateStop(_ stop: RouteStop) async {
        guard isNavigating, stops.count >= 2,
              !stops.contains(where: { $0.name == stop.name }) else { return }
        let backup = (stops, routeSegments, routeDistance, estimatedTravelTime)
        stops.insert(stop, at: stops.count - 1)
        await updateRoutes()
        guard !routeSegments.isEmpty else {
            (stops, routeSegments, routeDistance, estimatedTravelTime) = backup
            return
        }
        navigationSteps = RouteNavigation.steps(from: routeSegments)
        resetStepTracking()
    }

    /// Called on every location update while navigating: advances the
    /// current step, updates live distances, detects arrival, reroutes.
    /// Live bus data (when polling) drives real transit ride decay.
    func updateNavigationProgress(
        location: CLLocation, liveBuses: [BusLive] = [], busRoutes: [BusRoute] = [],
        stopEstimates: [Int: [BusStopEstimate]] = [:]
    ) async {
        self.liveBuses = liveBuses
        self.busRoutes = busRoutes
        self.stopEstimates = stopEstimates
        await updateNavigationProgressCore(location: location)
    }

    private var liveBuses: [BusLive] = []
    private var busRoutes: [BusRoute] = []
    private var stopEstimates: [Int: [BusStopEstimate]] = [:]

    private func updateNavigationProgressCore(location: CLLocation) async {
        guard isNavigating, !navigationSteps.isEmpty else { return }
        // Arrival latches — no bouncing back to guidance on the next fix.
        guard !hasArrived else { return }
        let coordinate = location.coordinate

        // Arrival needs a decent fix AND real route progress — a drive-by
        // on a looping approach or a GPS spike must not end guidance.
        if let destination = destinationCoordinate,
           location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 35,
           RouteNavigation.hasArrived(coordinate, destination: destination),
           currentStepIndex >= navigationSteps.count - 2 {
            hasArrived = true
            distanceToNextManeuver = 0
            remainingTravelTime = 0
            currentStepIndex = navigationSteps.count - 1
            displayedStepIndex = currentStepIndex
            return
        }

        currentStepIndex = RouteNavigation.currentStepIndex(
            for: coordinate, steps: navigationSteps, startingAt: currentStepIndex)
        displayedStepIndex = RouteNavigation.upcomingManeuverIndex(
            after: currentStepIndex, in: navigationSteps)

        // Distance counts down to where the upcoming instruction executes.
        distanceToNextManeuver = RouteNavigation.metersBetween(
            coordinate, navigationSteps[displayedStepIndex].startCoordinate)

        updateRemainingTime(from: coordinate)
        await rerouteIfNeeded(from: location)
    }

    private func updateRemainingTime(from coordinate: CLLocationCoordinate2D) {
        let remainingMeters = RouteNavigation.remainingDistance(
            from: coordinate, steps: navigationSteps, currentIndex: currentStepIndex)

        if let plan = activeTransitPlan {
            updateTransitRemainingTime(from: coordinate, plan: plan, remainingMeters: remainingMeters)
            return
        }

        if routeDistance > 0 {
            remainingTravelTime = estimatedTravelTime * (remainingMeters / routeDistance)
        }
    }

    /// Transit's steps are only the walk legs; the wait + ride live
    /// between them. Phases are LATCHED (approach → wait → ride → final
    /// walk) — raw bus proximity alone misfires at every boundary: a bus
    /// passing the rider mid-walk, or the just-exited bus lingering within
    /// range after alighting.
    private func updateTransitRemainingTime(
        from coordinate: CLLocationCoordinate2D, plan: TransitPlan, remainingMeters: Double
    ) {
        let walkPace = 1.33 // m/s
        let route = busRoutes.first { $0.routeID == plan.routeID }
        updateTransitPhase(at: coordinate, plan: plan)

        // Final walk: nothing left but distance.
        if hasAlightedBus {
            remainingTravelTime = remainingMeters / walkPace
            return
        }

        if isRidingBus {
            // Decay from the system's own prediction for the alight stop —
            // prefer the vehicle riding alongside; hold the last estimate
            // through a poll gap rather than guessing.
            // Only the identified riding vehicle's estimate counts — the
            // soonest bus at the alight stop may be a DIFFERENT vehicle
            // behind the rider. No match → hold the last value.
            let alightEstimates = (stopEstimates[plan.alightRouteStopID] ?? []).filter(\.isOnRoute)
            let ridingVehicleID = liveBuses.first(where: { bus in
                bus.routeID == plan.routeID && bus.isOnRoute
                    && RouteNavigation.metersBetween(bus.coordinate, coordinate) < 120
            })?.vehicleID
            if let rideRemaining = alightEstimates.first(where: { $0.vehicleID == ridingVehicleID }) {
                remainingTravelTime = Double(rideRemaining.secondsToStop)
                    + plan.walkToDestination.expectedTravelTime
            }
            return
        }

        // Approaching or waiting at the board stop: live wait when data is
        // polling, otherwise the plan's schedule estimate decayed from when
        // it was computed.
        let firstLegSteps = Array(navigationSteps.prefix(transitFirstLegStepCount))
        let firstLegRemaining = RouteNavigation.remainingDistance(
            from: coordinate, steps: firstLegSteps,
            currentIndex: min(currentStepIndex, max(transitFirstLegStepCount - 1, 0))) / walkPace

        let waitRemaining: Double
        if let route,
           let boardStop = route.stops.first(where: { $0.routeStopID == plan.boardRouteStopID }),
           let liveWait = BusArrivals.waitSeconds(
               to: boardStop, on: route, estimates: stopEstimates,
               afterWalkingSeconds: Int(firstLegRemaining)) {
            waitRemaining = firstLegRemaining + Double(liveWait)
        } else {
            let elapsed = Date().timeIntervalSince(plan.createdDate)
            waitRemaining = max(Double(plan.busArrivesInSeconds) - elapsed, 0)
        }

        remainingTravelTime = max(firstLegRemaining, waitRemaining)
            + Double(plan.rideSeconds)
            + plan.walkToDestination.expectedTravelTime
    }

    /// Latches the transit trip phase from real movement: reaching the
    /// board stop, leaving it alongside a route bus (boarded), and
    /// reaching the alight stop. Latches only move forward.
    private func updateTransitPhase(at coordinate: CLLocationCoordinate2D, plan: TransitPlan) {
        if !hasReachedBoardStop,
           RouteNavigation.metersBetween(coordinate, plan.boardCoordinate) < 50 {
            hasReachedBoardStop = true
        }
        if hasReachedBoardStop, !isRidingBus,
           RouteNavigation.metersBetween(coordinate, plan.boardCoordinate) > 60,
           liveBuses.contains(where: { bus in
               bus.routeID == plan.routeID && bus.isOnRoute
                   && RouteNavigation.metersBetween(bus.coordinate, coordinate) < 80
           }) {
            isRidingBus = true
        }
        if isRidingBus, !hasAlightedBus,
           RouteNavigation.metersBetween(coordinate, plan.alightCoordinate) < 40 {
            hasAlightedBus = true
        }
    }

    /// Off-route reroute for walk/bike/drive (transit plans don't reroute —
    /// the bus leg is fixed). 45 m threshold, ≥15 s apart, decent GPS only.
    /// A failed recompute keeps the existing route so guidance never dies.
    private func rerouteIfNeeded(from location: CLLocation) async {
        guard selectedMode != .transit, !routeSegments.isEmpty,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65
        else { return }
        // Off-route means off ALL segments (multi-stop routes included).
        let isOffAll = routeSegments.allSatisfy {
            RouteNavigation.isOffRoute(location.coordinate, routePolyline: $0.polyline)
        }
        guard isOffAll else { return }
        if let lastRerouteDate, Date().timeIntervalSince(lastRerouteDate) < 15 { return }
        lastRerouteDate = Date()

        // A custom planning origin (#10) only shapes the initial route —
        // reroutes always start from where the user actually is, otherwise
        // an off-route rider re-routes back to the old origin forever.
        if let first = stops.first, !first.mapItem.isCurrentLocation {
            stops[0] = .currentLocation()
        }

        let backup = (routeSegments, routeDistance, estimatedTravelTime)
        await updateRoutes()
        guard !routeSegments.isEmpty else {
            (routeSegments, routeDistance, estimatedTravelTime) = backup
            return
        }
        navigationSteps = RouteNavigation.steps(from: routeSegments)
        resetStepTracking()
    }

    func endNavigation() {
        isNavigating = false
        navigationSteps = []
        currentStepIndex = 0
        displayedStepIndex = 0
        distanceToNextManeuver = nil
        remainingTravelTime = 0
        hasArrived = false
        destinationCoordinate = nil
        lastRerouteDate = nil
        hasReachedBoardStop = false
        isRidingBus = false
        hasAlightedBus = false
        transitFirstLegStepCount = 0
        clearRoute()
    }

    func updateRoutes() async {
        guard stops.count >= 2 else {
            clearRoute()
            return
        }

        // Switching away from transit drops the bus leg; transit itself is
        // recomputed only through TransitPlanner, never MKDirections.
        activeTransitPlan = nil
        guard let transportType = selectedMode.mapKitTransportType else { return }

        isCalculating = true
        error = nil

        var newSegments: [MKRoute] = []
        var totalDistance: CLLocationDistance = 0
        var totalTime: TimeInterval = 0

        do {
            for i in 0..<(stops.count - 1) {
                let source = stops[i].mapItem
                let dest = stops[i + 1].mapItem

                let request = MKDirections.Request()
                request.source = source
                request.destination = dest
                request.transportType = transportType

                let directions = MKDirections(request: request)
                let response = try await directions.calculate()

                guard let route = response.routes.first else {
                    throw NSError(
                        domain: "RouteManager", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No route found between stops."])
                }

                newSegments.append(route)
                totalDistance += route.distance
                totalTime += route.expectedTravelTime
            }

            self.routeSegments = newSegments
            self.routeDistance = totalDistance
            self.estimatedTravelTime = totalTime
        } catch {
            self.error = error
            self.routeSegments = []
            self.routeDistance = 0
            self.estimatedTravelTime = 0
            print("Route calculation failed:", error.localizedDescription)
        }

        isCalculating = false
    }

    func clearRoute() {
        stops = []
        routeSegments = []
        routeDistance = 0
        estimatedTravelTime = 0
        error = nil
        activeTransitPlan = nil
        planningDestination = nil
    }
}
