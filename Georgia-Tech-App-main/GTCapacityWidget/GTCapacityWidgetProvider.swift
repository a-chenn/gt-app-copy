//
//  GTCapacityWidgetProvider.swift
//  GTCapacityWidget
//

import WidgetKit

struct GTCapacityWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> GTCapacityEntry {
        // Widget gallery and redacted state: structure is real, numbers are representative.
        // Do NOT pass isPlaceholder through to the view and conditionally hide things —
        // WidgetKit applies its own redaction pass on top.
        GTCapacityEntry(
            date: .now,
            fetchedAt: .now,
            crc: CapacityTileData(buildingID: 0, name: "Campus Recreation Center",
                                  shortName: "CRC", percentage: 0.48, isOpen: true),
            featured: [
                CapacityTileData(buildingID: 0, name: "Campus Recreation Center",
                                 shortName: "CRC", percentage: 0.48, isOpen: true),
                CapacityTileData(buildingID: 1, name: "Price Gilbert Library",
                                 shortName: "Library", percentage: 0.31, isOpen: true),
                CapacityTileData(buildingID: 2, name: "Clough Undergraduate Learning Commons",
                                 shortName: "Clough", percentage: 0.72, isOpen: true)
            ],
            fetchFailed: false
        )
    }

    // swiftlint:disable no_completion_handlers
    func getSnapshot(in context: Context, completion: @escaping (GTCapacityEntry) -> Void) {
        // Widget gallery preview — return the placeholder without a network call.
        // The gallery shows this; the installed widget shows getTimeline's entries.
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GTCapacityEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // 30 minutes out — honest ceiling for this feed.
            // Shorter intervals hit the ~40–70 refresh budget and get throttled,
            // which means LESS fresh data, not more.
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
    // swiftlint:enable no_completion_handlers

    // MARK: - Fetch

    private func fetchEntry() async -> GTCapacityEntry {
        let now = Date()
        do {
            let buildings = try await fetchCapacities()
            let crc = firstMatch(term: "recreation", in: buildings)
            let featured = featuredBuildings(from: buildings)
            return GTCapacityEntry(date: now, fetchedAt: now,
                                   crc: crc, featured: featured, fetchFailed: false)
        } catch {
            return GTCapacityEntry(date: now, fetchedAt: now,
                                   crc: nil, featured: [], fetchFailed: true)
        }
    }

    private func fetchCapacities() async throws -> [BuildingCapacityJSON] {
        let url = try APIUtility.url(for: "capacity/")
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        return try JSONDecoder().decode(BuildingCapacityResponseJSON.self, from: data).data
    }

    private func firstMatch(term: String, in buildings: [BuildingCapacityJSON]) -> CapacityTileData? {
        buildings.first { $0.name.lowercased().contains(term) }?.tileData
    }

    /// Mirrors HomeRightNowSection's preferred-order logic so the widget
    /// and the in-app tile row agree on which buildings show first.
    private func featuredBuildings(from buildings: [BuildingCapacityJSON]) -> [CapacityTileData] {
        let preferredTerms = ["recreation", "price gilbert", "clough", "crosland"]
        let open = buildings.filter(\.isOpen)
        var result: [BuildingCapacityJSON] = []
        for term in preferredTerms {
            if let match = open.first(where: { $0.name.lowercased().contains(term) }),
               !result.contains(where: { $0.id == match.id }) {
                result.append(match)
            }
        }
        let rest = open
            .filter { b in !result.contains(where: { $0.id == b.id }) }
            .sorted { $0.name < $1.name }
        return Array((result + rest).prefix(4)).map(\.tileData)
    }
}

// MARK: - BuildingCapacityJSON helpers (widget-side only)

private extension BuildingCapacityJSON {
    var tileData: CapacityTileData {
        CapacityTileData(buildingID: id, name: name,
                         shortName: shortName, percentage: percentage, isOpen: isOpen)
    }
}
