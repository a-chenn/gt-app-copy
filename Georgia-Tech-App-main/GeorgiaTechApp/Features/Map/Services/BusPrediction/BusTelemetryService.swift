import Foundation

/// A completed shared refresh. Nil estimates mean the arrival request failed;
/// an empty dictionary means a successful response with no arrivals.
nonisolated struct BusTelemetrySnapshot: Sendable {
    let buses: [BusLive]
    let stopEstimates: [Int: [BusStopEstimate]]?
    let updatedAt: Date
    let warnings: [String]
}

/// Coordinates prediction inputs for Home, Map and routing. All HTTP access
/// goes through GTDataService via LiveTransport; concurrent consumers share work.
actor BusTelemetryService {
    static let shared = BusTelemetryService()

    private let transport: any LiveTransport
    private let arrivals: BusArrivalService
    private var routeResponse: LiveResponse?
    private var inFlight: (id: UUID, task: Task<BusTelemetrySnapshot, Error>)?
    private var dwellManager = BusDwellManager()

    /// Creates the shared snapshot coordinator with injectable prediction dependencies.
    init(transport: any LiveTransport = TransLocTransport(), arrivals: BusArrivalService = .shared) {
        self.transport = transport
        self.arrivals = arrivals
    }

    /// Refreshes once, joining an existing refresh instead of creating another poller.
    func refresh() async throws -> BusTelemetrySnapshot {
        if let inFlight { return try await inFlight.task.value }
        let id = UUID()
        let task = Task {
            do {
                return try await loadSnapshot()
            } catch {
                dwellManager.invalidateObservations()
                throw error
            }
        }
        inFlight = (id, task)
        defer { if inFlight?.id == id { inFlight = nil } }
        return try await task.value
    }

    /// Live route definitions are shared and expire after five minutes.
    private func fetchRoutes() async throws -> LiveResponse {
        if let routeResponse, Date().timeIntervalSince(routeResponse.receivedAt) < 300 {
            return routeResponse
        }
        let response = try await transport.fetch(
            method: "GetRoutesForMapWithScheduleWithEncodedLine", parameters: [:])
        // Never replace a usable route-definition cache with malformed data.
        _ = try JSONDecoder().decode([BusRouteJSON].self, from: response.body)
        routeResponse = response
        return response
    }

    /// Fetches one vehicle list and batched arrival/upcoming responses for all routes.
    private func loadSnapshot() async throws -> BusTelemetrySnapshot {
        let requestedAt = Date()
        async let vehiclesRequest = transport.fetch(method: "GetMapVehiclePoints", parameters: [:])
        async let capacitiesRequest = try? transport.fetch(method: "GetVehicleCapacities", parameters: [:])
        async let routesRequest = try? fetchRoutes()
        let (vehicles, capacities, routesResponse) = try await (vehiclesRequest, capacitiesRequest, routesRequest)
        var warnings: [String] = []
        let decodedLocations = try decodeLocations(vehicles, warnings: &warnings)
        let locations = Dictionary(decodedLocations.map { ($0.vehicleID, $0) }, uniquingKeysWith: { _, last in last })
            .values.sorted { $0.vehicleID < $1.vehicleID }
        let routes = routesResponse.flatMap { try? JSONDecoder().decode([BusRouteJSON].self, from: $0.body) } ?? []
        let dwell = dwellManager.updateObservations(
            locations: locations, routes: routes, receivedAt: vehicles.receivedAt)
        if routesResponse == nil { warnings.append("Live route definitions unavailable; arrival predictions unavailable.") }
        let capacityRows = capacities.flatMap { try? JSONDecoder().decode([BusCapacityJSON].self, from: $0.body) }
        if capacityRows == nil { warnings.append("Vehicle capacities unavailable.") }
        let capacityByID = Dictionary((capacityRows ?? []).map { ($0.vehicleID, $0) }, uniquingKeysWith: { first, _ in first })

        let stopIDs = Array(Set(routes.flatMap(\.stops).map { String($0.routeStopID) })).sorted()
        var selected: LiveResponse?
        if !stopIDs.isEmpty {
            do {
                selected = try await transport.fetch(method: "GetStopArrivalTimes", parameters: [
                    "routeStopIDs": stopIDs.joined(separator: ","), "timesPerStop": "30"
                ])
            } catch {
                warnings.append("Stop arrivals unavailable: \(error.localizedDescription)")
            }
        }

        // Include vehicles mentioned by arrival endpoints even if absent from the map list.
        var vehicleIDs = Set(locations.map { String($0.vehicleID) })
        if let selected, let rows = try? LiveParser.list(selected.body) {
            for case let row as [String: Any] in rows {
                for case let time as [String: Any] in row["Times"] as? [Any] ?? [] {
                    if let id = LiveParser.identifier(time["VehicleId"] ?? time["VehicleID"]) { vehicleIDs.insert(id) }
                }
            }
        }
        var upcoming: LiveResponse?
        if !vehicleIDs.isEmpty {
            do {
                upcoming = try await transport.fetch(method: "GetVehicleRouteStopEstimates", parameters: [
                    "vehicleIdStrings": vehicleIDs.sorted().joined(separator: ","),
                    "quantity": String((routes.map { $0.stops.count }.max() ?? 30) + 1)
                ])
            } catch {
                warnings.append("Upcoming stops unavailable; using TransLoc arrivals.")
            }
        }

        let estimates: [Int: [BusStopEstimate]]?
        if let selected {
            do {
                estimates = try await predictArrivals(routes: routes, vehicles: vehicles, selected: selected,
                                                     upcoming: upcoming, requestedAt: requestedAt, warnings: &warnings)
            } catch {
                estimates = nil
                warnings.append("Arrival predictions unavailable: \(error.localizedDescription)")
            }
        } else {
            estimates = nil
        }
        try Task.checkCancellation()
        return BusTelemetrySnapshot(
            buses: locations.map {
                BusLive(location: $0, capacity: capacityByID[$0.vehicleID], dwell: dwell[$0.vehicleID])
            },
            stopEstimates: estimates, updatedAt: Date(), warnings: warnings)
    }

    /// Rejects only malformed vehicles, retaining the other current positions.
    private func decodeLocations(_ response: LiveResponse, warnings: inout [String]) throws -> [BusLocationJSON] {
        try LiveParser.list(response.body).compactMap { raw in
            guard JSONSerialization.isValidJSONObject(raw),
                  let data = try? JSONSerialization.data(withJSONObject: raw),
                  let location = try? JSONDecoder().decode(BusLocationJSON.self, from: data),
                  (-90...90).contains(location.busLatitude),
                  (-180...180).contains(location.busLongitude) else {
                warnings.append("Vehicle omitted because its position or metadata is invalid.")
                return nil
            }
            return location
        }
    }

    /// Runs the supplied per-stop algorithm against shared live inputs. Missing
    /// history falls back to TransLoc; changed stop sequences never use old averages.
    private func predictArrivals(
        routes: [BusRouteJSON], vehicles: LiveResponse, selected: LiveResponse,
        upcoming: LiveResponse?, requestedAt: Date, warnings: inout [String]
    ) async throws -> [Int: [BusStopEstimate]] {
        var history: HistoricalData
        do {
            history = try await arrivals.loadHistoricalData()
        } catch {
            history = HistoricalData()
            warnings.append("Historical data unavailable; using TransLoc arrivals: \(error.localizedDescription)")
        }
        let now = Date()
        guard Prediction.isFresh(selected.receivedAt, now: now) else {
            throw ArrivalError.invalidResponse("Arrival response expired; refresh again.")
        }
        var result: [Int: [BusStopEstimate]] = [:]
        for json in routes {
            let routeID = String(json.routeID)
            let stops = json.stops.sorted { $0.stopOrder < $1.stopOrder }
            let route = PredictionRoute(id: routeID, name: json.routeDescription, stops: stops.map {
                PredictionRouteStop(id: String($0.routeStopID), name: $0.name)
            })
            var data = history
            if history.routes[routeID]?.stops.map(\.id) != route.stops.map(\.id) {
                data.averages = data.averages.filter { $0.key.routeID != routeID }
                if history.routes[routeID] != nil {
                    warnings.append("Route \(route.name) stop sequence changed; using TransLoc arrivals.")
                }
            }
            let names = try LiveParser.vehicleNames(vehicles.body, routeID: routeID)
            var upcomingEstimates: [String: [Estimate]] = [:]
            if let upcoming {
                do {
                    let requested = Set(try LiveParser.list(upcoming.body).compactMap { raw in
                        (raw as? [String: Any]).flatMap { LiveParser.identifier($0["VehicleID"] ?? $0["VehicleId"]) }
                    })
                    upcomingEstimates = try LiveParser.upcoming(upcoming.body, route: route, requested: requested, received: upcoming.receivedAt)
                } catch {
                    warnings.append("Upcoming stops invalid for \(route.name); using TransLoc arrivals.")
                }
            }
            for (index, stop) in stops.enumerated() {
                let vendor = try LiveParser.selected(selected.body, routeID: routeID,
                                                     stopID: String(stop.routeStopID), received: selected.receivedAt)
                let predictions = Prediction.calculate(
                    data: data, route: route, destination: index, selected: vendor, selectedAt: selected.receivedAt,
                    upcoming: upcomingEstimates, upcomingAt: upcoming?.receivedAt, now: now,
                    requestedAt: requestedAt, vehicleNames: names)
                result[stop.routeStopID] = predictions.compactMap { arrival in
                    guard let vehicleID = Int(arrival.vehicleID) else { return nil }
                    return BusStopEstimate(routeStopID: stop.routeStopID, stopOrder: stop.stopOrder,
                                           vehicleID: vehicleID, secondsToStop: arrival.remainingSeconds,
                                           isOnRoute: true, arrival: arrival)
                }
            }
        }
        return result
    }
}
