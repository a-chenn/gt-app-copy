import Foundation

actor BusArrivalService {
    static let shared = BusArrivalService()
    private var loadTask: Task<HistoricalData, Error>?
    private let loader: @Sendable () throws -> HistoricalData
    private let transport: any LiveTransport
    private let clock: @Sendable () -> Date

    /// Creates the arrival service with injectable transport, clock and bundled-data loader.
    init(transport: any LiveTransport = TransLocTransport(),
         clock: @escaping @Sendable () -> Date = { Date() },
         loader: @escaping @Sendable () throws -> HistoricalData = {
             guard let root = Bundle.main.resourceURL?.appendingPathComponent("live-arrival-times") else {
                 throw ArrivalError.invalidData("Missing bundled data")
             }
             return try HistoricalData.load(root: root)
         }) {
        self.transport = transport
        self.clock = clock
        self.loader = loader
    }

    /// Loads bundled historical data once off the UI actor.
    func loadHistoricalData() async throws -> HistoricalData {
        if let loadTask { return try await loadTask.value }
        let loader = self.loader
        let task = Task.detached(priority: .utility) { try loader() }
        loadTask = task
        return try await task.value
    }

    /// Returns bundled route choices in name order.
    func loadRoutes() async throws -> [PredictionRoute] {
        try await loadHistoricalData().routes.values.sorted { $0.name < $1.name }
    }

    /// Fetches optional display labels without failing the prediction request.
    private func fetchVehicleNames(for routeID: String) async -> [String: String] {
        guard let response = try? await transport.fetch(method: "GetMapVehiclePoints", parameters: ["routeID": routeID]) else { return [:] }
        return (try? LiveParser.vehicleNames(response.body, routeID: routeID)) ?? [:]
    }

    /// Fetches a single-stop prediction with immutable request-time settings.
    func fetchSnapshot(for stopID: String, settings: PredictionSettings = PredictionSettings(), requestedAt: Date? = nil) async throws -> ArrivalSnapshot {
        let requestedAt = requestedAt ?? clock()
        let data = try await loadHistoricalData()
        guard let route = data.routes[settings.routeID] else { throw ArrivalError.invalidData("Unknown route") }
        guard let destination = route.stops.firstIndex(where: { $0.id == stopID }) else { throw ArrivalError.invalidStop(stopID) }
        try Task.checkCancellation()
        async let namesRequest = fetchVehicleNames(for: route.id)
        let selectedResponse = try await transport.fetch(method: "GetStopArrivalTimes", parameters: ["routeStopIDs": stopID, "timesPerStop": "30"])
        let selected = try LiveParser.selected(selectedResponse.body, routeID: route.id, stopID: stopID, received: selectedResponse.receivedAt)
        var upcoming: [String: [Estimate]] = [:]
        var upcomingAt: Date?
        var warnings: [String] = []
        if !selected.isEmpty {
            do {
                let response = try await transport.fetch(method: "GetVehicleRouteStopEstimates", parameters: [
                    "vehicleIdStrings": selected.keys.sorted().joined(separator: ","), "quantity": String(route.stops.count + 1)
                ])
                upcoming = try LiveParser.upcoming(response.body, route: route, requested: Set(selected.keys), received: response.receivedAt)
                upcomingAt = response.receivedAt
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                warnings.append("Upcoming stops unavailable; using TransLoc estimates.")
            }
        }
        let names = await namesRequest
        try Task.checkCancellation()
        let now = clock()
        guard Prediction.isFresh(selectedResponse.receivedAt, now: now) else { throw ArrivalError.invalidResponse("Response expired; refresh again.") }
        let arrivals = Prediction.calculate(data: data, route: route, destination: destination,
                                           selected: selected, selectedAt: selectedResponse.receivedAt,
                                           upcoming: upcoming, upcomingAt: upcomingAt, now: now,
                                           requestedAt: requestedAt, vehicleNames: names)
        return ArrivalSnapshot(updatedAt: now, routeID: route.id, routeName: route.name, stopID: stopID,
                               stopName: route.stops[destination].name, arrivals: arrivals, warnings: warnings)
    }
}
