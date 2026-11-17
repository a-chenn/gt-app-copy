//
//  GTCapacityPhotoWidgetProvider.swift
//  GTCapacityWidget
//

import WidgetKit
import Foundation

struct GTCapacityPhotoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = GTCapacityPhotoEntry
    typealias Intent = BuildingCapacityIntent

    // MARK: - Required conformance

    func placeholder(in context: Context) -> GTCapacityPhotoEntry {
        GTCapacityPhotoEntry(
            date: .now,
            fetchedAt: .now,
            state: .loaded(CapacityPhotoData(
                buildingID: 0,
                name: "Campus Recreation Center",
                shortName: "CRC",
                percentage: 0.48,
                isOpen: true
            )),
            buildingID: 0
        )
    }

    func snapshot(
        for configuration: BuildingCapacityIntent,
        in context: Context
    ) async -> GTCapacityPhotoEntry {
        placeholder(in: context)
    }

    func timeline(
        for configuration: BuildingCapacityIntent,
        in context: Context
    ) async -> Timeline<GTCapacityPhotoEntry> {
        await buildTimeline(for: configuration)
    }

    // MARK: - Timeline building

    private func buildTimeline(for configuration: BuildingCapacityIntent) async -> Timeline<GTCapacityPhotoEntry> {
        let now = Date()
        let tenMinutesOut = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now

        guard let building = configuration.building else {
            let entry = GTCapacityPhotoEntry(
                date: now, fetchedAt: now,
                state: .notConfigured,
                buildingID: nil
            )
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }

        do {
            let buildings = try await fetchCapacities()
            guard let matchedBuilding = buildings.first(where: { $0.id == building.id }) else {
                let entry = GTCapacityPhotoEntry(
                    date: now, fetchedAt: now,
                    state: .buildingNotFound,
                    buildingID: building.id
                )
                return Timeline(entries: [entry], policy: .after(tenMinutesOut))
            }

            let photoData = CapacityPhotoData(
                buildingID: matchedBuilding.id,
                name: matchedBuilding.name,
                shortName: matchedBuilding.shortName,
                percentage: matchedBuilding.percentage,
                isOpen: matchedBuilding.isOpen
            )

            let entry = GTCapacityPhotoEntry(
                date: now, fetchedAt: now,
                state: .loaded(photoData),
                buildingID: building.id
            )
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        } catch {
            let entry = GTCapacityPhotoEntry(
                date: now, fetchedAt: now,
                state: .fetchFailed,
                buildingID: building.id
            )
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }
    }

    private func fetchCapacities() async throws -> [BuildingCapacityJSON] {
        let url = try APIUtility.url(for: "capacity/")
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        return try JSONDecoder().decode(BuildingCapacityResponseJSON.self, from: data).data
    }
}
