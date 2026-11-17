//
//  GTDataService+Transportation.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    func fetchBusLocations() async throws -> [BusLocationJSON] {
        try await fetchAbsolute(
            "https://bus.gatech.edu/Services/JSONPRelay.svc/GetMapVehiclePoints")
    }
    func fetchBusCapacities() async throws -> [BusCapacityJSON] {
        try await fetchAbsolute(
            "https://bus.gatech.edu/Services/JSONPRelay.svc/GetVehicleCapacities")
    }
    func fetchStopEstimates() async throws -> [BusStopEstimateRouteJSON] {
        try await fetchAbsolute(
            "https://bus.gatech.edu/Services/JSONPRelay.svc/GetMapStopEstimates")
    }
    func fetchBusRoutes() async throws -> [BusRouteJSON] {
        try await fetchAbsolute(
            "https://bus.gatech.edu/Services/JSONPRelay.svc/GetRoutesForMapWithScheduleWithEncodedLine"
        )
    }
    /// Routes/stops load, wrapped like the other domains so the fetch
    /// closure is created inside a main-actor function body (an inline
    /// closure at the `async let` site would capture `context` across the
    /// concurrency boundary).
    @discardableResult
    @MainActor func loadBusRoutes(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await routeFetcher.load(context: context, forceRefresh: forceRefresh) {
            try await self.syncBusRoutes(context: context)
        }
    }

    @MainActor func syncBusRoutes(context: ModelContext) async throws {
        let jsonArray = try await fetchBusRoutes()

        // Stops ride along in the same payload — replace both entity sets
        // together so route↔stop relationships stay consistent.
        let existingStops = try context.fetch(FetchDescriptor<BusStop>())
        existingStops.forEach { context.delete($0) }
        let existingRoutes = try context.fetch(FetchDescriptor<BusRoute>())
        existingRoutes.forEach { context.delete($0) }

        for json in jsonArray {
            let route = BusRoute(
                routeID: json.routeID, name: json.routeDescription,
                busColor: json.busColor ?? json.mapColor,
                mapColor: json.mapColor, polyline: json.polyline,
                isRunning: json.isRunning)
            context.insert(route)

            for stopJSON in json.stops {
                let stop = BusStop(
                    stopAddressID: stopJSON.addressID,
                    latitude: stopJSON.latitude, longitude: stopJSON.longitude,
                    name: stopJSON.name, stopOrder: stopJSON.stopOrder,
                    secondAtStop: stopJSON.secondsAtStop,
                    secondsToNextStop: stopJSON.secondsToNextStop,
                    routeStopID: stopJSON.routeStopID)
                stop.routes = [route]
                context.insert(stop)
            }
        }
        try context.save()
    }
}

extension GTDataService {
    /// Parameterized relay access shared by arrival prediction calculations.
    /// Bypasses URL caching because arrival timestamps must describe this refresh.
    func fetchBusResponse(method: String, parameters: [String: String]) async throws -> LiveResponse {
        guard var components = URLComponents(
            string: "https://bus.gatech.edu/Services/JSONPRelay.svc/\(method)"
        ) else { throw URLError(.badURL) }
        components.queryItems = parameters.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("gt-bus-local-arrivals/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        try response.validate()
        return LiveResponse(body: data, receivedAt: Date())
    }
}
