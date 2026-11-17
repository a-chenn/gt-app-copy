//
//  GTCapacityWidgetIntent.swift
//  GTCapacityWidget
//

import AppIntents
import WidgetKit

// MARK: - Building entity (one row in the picker)

struct BuildingCapacityEntity: AppEntity {
    let id: Int
    let displayName: String
    let shortName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Building"
    static var defaultQuery = BuildingCapacityEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(shortName)"
        )
    }
}

// MARK: - Entity query (populates the picker)

struct BuildingCapacityEntityQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [BuildingCapacityEntity] {
        let buildings = try await fetchBuildings()
        return buildings.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [BuildingCapacityEntity] {
        try await fetchBuildings()
    }

    func defaultResult() async -> BuildingCapacityEntity? {
        // No default — user must configure.
        nil
    }

    // MARK: Private helpers

    private func fetchBuildings() async throws -> [BuildingCapacityEntity] {
        let url = try APIUtility.url(for: "capacity/")
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        let buildings = try JSONDecoder().decode(BuildingCapacityResponseJSON.self, from: data).data

        return buildings.map { building in
            BuildingCapacityEntity(
                id: building.id,
                displayName: building.name,
                shortName: building.shortName
            )
        }.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Configuration intent

struct BuildingCapacityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Building"
    static var description = IntentDescription("Choose which building to track.")

    @Parameter(title: "Building", default: nil)
    var building: BuildingCapacityEntity?
}
