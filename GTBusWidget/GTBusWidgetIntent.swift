//
//  GTBusWidgetIntent.swift
//  GTBusWidget
//

import AppIntents
import WidgetKit

// MARK: - Stop entity (one row in the picker)

struct BusStopEntity: AppEntity {
    // Per-physical-stop: id is stopAddressID (Q2 answered: per physical stop)
    let id: Int
    let displayName: String       // e.g. "Student Center"
    let subtitle: String          // e.g. "Blue, Gold" (route names at this stop)

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bus Stop"
    static var defaultQuery = BusStopEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(subtitle)"
        )
    }
}

// MARK: - Entity query (populates the picker)

struct BusStopEntityQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [BusStopEntity] {
        let routes = try await fetchSlimRoutes()
        return buildEntities(from: routes).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [BusStopEntity] {
        let routes = try await fetchSlimRoutes()
        return buildEntities(from: routes)
    }

    func defaultResult() async -> BusStopEntity? {
        // Return nil so the widget shows "Long-press to edit and pick a stop"
        // instead of auto-selecting a stop the user didn't choose.
        nil
    }

    // MARK: Private helpers

    private func fetchSlimRoutes() async throws -> [BusSlimRouteJSON] {
        let url = URL(string: "https://bus.gatech.edu/Services/JSONPRelay.svc/GetRoutesForMapWithScheduleWithEncodedLine")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BusSlimRouteJSON].self, from: data)
    }

    private func buildEntities(from routes: [BusSlimRouteJSON]) -> [BusStopEntity] {
        // Per-physical-stop (Q2 = physical): union stops by stopAddressID
        var stopsByAddress: [Int: (name: String, routes: Set<String>)] = [:]

        for route in routes where route.isRunning {
            for stop in route.stops {
                if var existing = stopsByAddress[stop.stopAddressID] {
                    existing.routes.insert(route.name)
                    stopsByAddress[stop.stopAddressID] = existing
                } else {
                    stopsByAddress[stop.stopAddressID] = (stop.name, [route.name])
                }
            }
        }

        return stopsByAddress.map { addressID, info in
            let routeList = info.routes.sorted().joined(separator: ", ")
            return BusStopEntity(
                id: addressID,
                displayName: info.name,
                subtitle: routeList
            )
        }.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Configuration intent

struct BusStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Bus Stop"
    static var description = IntentDescription("Choose which stop to track.")

    @Parameter(title: "Stop", default: nil)
    var stop: BusStopEntity?
}
