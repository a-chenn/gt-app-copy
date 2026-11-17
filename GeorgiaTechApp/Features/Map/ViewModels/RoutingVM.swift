//
//  RoutingVM.swift
//  GeorgiaTechApp
//

import CoreLocation
import MapKit

@Observable
@MainActor
final class RoutingVM {
    /// Where the trip starts — nil means the user's current location.
    private(set) var origin: RouteStop?
    private(set) var destination: SearchCardModel
    private let busRoutes: [BusRoute]
    private var userLocation: CLLocationCoordinate2D?

    var selectedMode: RouteTransportMode
    var routeOptions: [RouteTransportMode: RouteOption] = [:]
    /// All routes per mode — index 0 is MapKit's suggested route.
    var routeAlternatives: [RouteTransportMode: [MKRoute]] = [:]
    var selectedRouteIndex = 0
    var transitPlan: TransitPlan?
    /// Bus mode's honest answer when every plan loses to walking (#R3-4).
    var isWalkingFasterThanBus = false
    var isCalculating = false

    // Editing an endpoint re-runs the calculation; the token keeps a slow
    // superseded run from writing stale routes over the new endpoints.
    private var calculationGeneration = 0

    var selectedRoute: MKRoute? {
        guard let routes = routeAlternatives[selectedMode],
              routes.indices.contains(selectedRouteIndex) else { return nil }
        return routes[selectedRouteIndex]
    }

    var originName: String {
        origin?.name ?? "My Location"
    }

    init(
        destination: SearchCardModel,
        busRoutes: [BusRoute] = [],
        userLocation: CLLocationCoordinate2D? = nil
    ) {
        self.destination = destination
        self.busRoutes = busRoutes
        self.userLocation = userLocation
        self.selectedMode = RouteTransportMode(
            rawValue: UserDefaults.standard.string(forKey: "defaultTravelMode") ?? ""
        ) ?? .walking
    }

    /// The options screen can stay open while the user walks — swap and
    /// transit math must use where they are NOW, not where planning began.
    func refreshUserLocation(_ coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            userLocation = coordinate
        }
    }

    // MARK: - Endpoint editing (#10)

    func updateOrigin(_ stop: RouteStop?) async {
        origin = stop
        await recalculate()
    }

    func updateDestination(_ card: SearchCardModel) async {
        guard card.destination != nil else { return }
        destination = card
        await recalculate()
    }

    /// With the default "My Location" origin, swapping routes from the
    /// destination back to where the user is standing.
    var canSwapEndpoints: Bool {
        destination.destination != nil && (origin != nil || userLocation != nil)
    }

    func swapEndpoints() async {
        guard let newOrigin = destination.destination else { return }

        if let origin {
            destination = origin.toSearchCard()
        } else if let userLocation {
            destination = SearchCardModel(
                id: "my-location",
                title: "My Location",
                subtitle: nil,
                destination: RouteStop(
                    name: "My Location",
                    mapItem: MKMapItem(
                        location: CLLocation(
                            latitude: userLocation.latitude,
                            longitude: userLocation.longitude),
                        address: nil)),
                image: nil,
                category: .mapItem)
        } else {
            return
        }

        origin = newOrigin
        await recalculate()
    }

    private func recalculate() async {
        routeOptions = [:]
        routeAlternatives = [:]
        transitPlan = nil
        isWalkingFasterThanBus = false
        selectedRouteIndex = 0
        await calculateAllModes()
    }

    // MARK: - Calculate all modes concurrently

    func calculateAllModes() async {
        guard let stop = destination.destination else { return }
        calculationGeneration += 1
        let generation = calculationGeneration
        isCalculating = true

        let source = origin?.mapItem ?? MKMapItem.forCurrentLocation()
        let destinationItem = stop.mapItem

        // Transit runs concurrently with the MKDirections modes — one
        // unified calculation, different data sources per mode.
        async let transitResult = calculateTransit()

        var alternatives: [RouteTransportMode: [MKRoute]] = [:]
        await withTaskGroup(of: (RouteTransportMode, [MKRoute]).self) { group in
            for mode in RouteTransportMode.allCases {
                guard let transportType = mode.mapKitTransportType else { continue }
                group.addTask {
                    let request = MKDirections.Request()
                    request.source = source
                    request.destination = destinationItem
                    request.transportType = transportType
                    request.requestsAlternateRoutes = true

                    let directions = MKDirections(request: request)
                    do {
                        let response = try await directions.calculate()
                        return (mode, response.routes)
                    } catch {
                        print("Route calc failed for \(mode):", error.localizedDescription)
                    }
                    return (mode, [])
                }
            }

            for await (mode, routes) in group where !routes.isEmpty {
                alternatives[mode] = routes
            }
        }

        let transit = await transitResult

        // A newer calculation superseded this one — drop its results.
        guard generation == calculationGeneration else { return }

        for (mode, routes) in alternatives {
            guard let suggested = routes.first else { continue }
            routeAlternatives[mode] = routes
            routeOptions[mode] = RouteOption(
                distance: suggested.distance, time: suggested.expectedTravelTime)
        }

        switch transit {
        case .plan(let plan):
            transitPlan = plan
            isWalkingFasterThanBus = false
            routeOptions[.transit] = RouteOption(
                distance: plan.totalDistance, time: plan.totalSeconds)
        case .walkingIsFaster:
            isWalkingFasterThanBus = true
        case .unavailable:
            isWalkingFasterThanBus = false
        }

        // The saved default might not be routable for this trip (e.g. no
        // live bus) — fall back to the fastest available mode.
        if routeOptions[selectedMode] == nil,
           let fastest = routeOptions.min(by: { $0.value.time < $1.value.time })?.key {
            selectedMode = fastest
        }

        isCalculating = false
    }

    /// Transit is a mode of the same unified calculation, computed from
    /// GT bus data (live snapshot) rather than MKDirections.
    private func calculateTransit() async -> TransitPlanResult {
        let start = origin?.mapItem.location.coordinate ?? userLocation
        guard let start,
              let target = destination.coordinate,
              !busRoutes.isEmpty else { return .unavailable }

        guard let snapshot = try? await BusTelemetryService.shared.refresh(),
              !snapshot.buses.isEmpty, let estimates = snapshot.stopEstimates else { return .unavailable }

        return await TransitPlanner.plan(
            from: start, to: target, routes: busRoutes, liveBuses: snapshot.buses,
            estimates: estimates)
    }

    /// Bus mode's "walking is faster" recommendation — commits the
    /// suggested walking route instead.
    func startWalkingInstead(via routeManager: RouteManager) {
        guard let stop = destination.destination,
              let route = routeAlternatives[.walking]?.first else { return }
        routeManager.startRoute(route, mode: .walking, from: origin, to: stop)
    }

    // MARK: - Start navigation

    func startNavigation(via routeManager: RouteManager) {
        guard let stop = destination.destination else { return }

        if selectedMode == .transit, let transitPlan {
            routeManager.startTransitRoute(transitPlan, from: origin, to: stop)
            return
        }

        guard let route = selectedRoute else { return }
        routeManager.startRoute(route, mode: selectedMode, from: origin, to: stop)
    }

    // MARK: - Open in Apple Maps

    func openInAppleMaps() {
        guard let stop = destination.destination else { return }
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: selectedMode == .driving
            ? MKLaunchOptionsDirectionsModeDriving
            : MKLaunchOptionsDirectionsModeWalking
        ]
        stop.mapItem.openInMaps(launchOptions: launchOptions)
    }
}

extension RouteStop {
    /// Endpoint edits can move a stop back into the destination slot,
    /// which the rest of the app models as a card.
    func toSearchCard() -> SearchCardModel {
        let coordinate = mapItem.location.coordinate
        return SearchCardModel(
            id: "endpoint-\(coordinate.latitude)-\(coordinate.longitude)",
            title: name, subtitle: nil, destination: self,
            image: nil, category: .mapItem)
    }
}
