//
//  CapacitiesView.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// Live building occupancy in the Gold Hive language: filter capsules
/// and a gauge ring per building with its sub-areas broken out as tiles.
struct CapacitiesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BuildingCapacity.name) private var capacities: [BuildingCapacity]
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedBuildingID: Int?

    /// Deep link from a building's detail card (#8): start filtered to it.
    init(initialFilterID: Int? = nil) {
        _selectedBuildingID = State(initialValue: initialFilterID)
    }

    private var openBuildings: [BuildingCapacity] { capacities.filter(\.isOpen) }
    private var closedBuildings: [BuildingCapacity] { capacities.filter { !$0.isOpen } }

    /// A deep-linked building can vanish from the refreshed feed — an
    /// absent filter falls back to the full list, never a blank screen.
    private var effectiveFilterID: Int? {
        guard let selectedBuildingID,
              capacities.contains(where: { $0.capacityID == selectedBuildingID })
        else { return nil }
        return selectedBuildingID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if capacities.count > 1 {
                    buildingFilterChips
                }

                // The open count lives in this header now that the navy
                // summary card is gone — it was the one number that
                // appeared nowhere else on the screen.
                if !capacities.isEmpty && effectiveFilterID == nil {
                    GTSectionHeader("Open") {
                        Text("\(openBuildings.count) of \(capacities.count)")
                            .font(.gtHeading6)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    ForEach(filteredBuildings(openBuildings)) { building in
                        CapacityCardView(building: building)
                    }
                }
                .padding(.horizontal, 16)

                let closed = filteredBuildings(closedBuildings)
                if !closed.isEmpty {
                    GTSectionHeader("Closed")
                        .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(closed) { building in
                            CapacityCardView(building: building)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .gtScreenBackground()
        .navigationTitle("Capacities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await GTDataService.shared.loadCapacities(context: modelContext)
            await AlertWatchService.shared.refreshCapacityWatches(capacities: capacities)
        }
        .refreshable {
            await GTDataService.shared.loadCapacities(context: modelContext, forceRefresh: true)
            await AlertWatchService.shared.refreshCapacityWatches(capacities: capacities)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AlertWatchService.shared.refreshCapacityWatches(capacities: capacities) }
            }
        }
        .overlay {
            if capacities.isEmpty {
                ContentUnavailableView(
                    "No Capacity Data",
                    systemImage: "person.3",
                    description: Text("Live occupancy will show up here.")
                )
            }
        }
    }

    /// Filters are per building, not per category: the feed carries no
    /// building type, and inventing one from names would be a guess.
    private var buildingFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GTFilterChip(
                    title: "All", isSelected: effectiveFilterID == nil,
                    accessibilityText: "Show all buildings"
                ) {
                    selectedBuildingID = nil
                }

                ForEach(capacities) { building in
                    let isSelected = effectiveFilterID == building.capacityID
                    GTFilterChip(
                        title: building.shortName, isSelected: isSelected,
                        accessibilityText: "Filter to \(building.name)"
                    ) {
                        selectedBuildingID = isSelected ? nil : building.capacityID
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filteredBuildings(_ buildings: [BuildingCapacity]) -> [BuildingCapacity] {
        guard let filterID = effectiveFilterID else { return buildings }
        return buildings.filter { $0.capacityID == filterID }
    }
}

// MARK: - Building card

private struct CapacityCardView: View {
    let building: BuildingCapacity

    private var percent: Double { building.percentage * 100 }
    private var level: CapacityLevel { CapacityLevel(percent: percent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                gaugeRing

                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name)
                        .font(.gtHeading4)
                        .foregroundStyle(Color.gtPrimaryText)
                        .lineLimit(2)

                    Text(statusLine)
                        .font(.gtHeading6)
                        .tracking(1.1)
                        .foregroundStyle(building.isOpen ? level.color : Color.gtSecondaryText)
                        .lineLimit(2)
                    
                    // To test when time is not in the building's hours of operations set boolean condition to be true
                    if building.isOpen && (level.statusText == "MODERATE" || level.statusText == "BUSY") {
                        CapacityAlertButton(building: building)
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)
            }

            if building.isOpen, let subLocs = building.subLocs, !subLocs.isEmpty {
                subAreaTiles(subLocs)
            }
        }
        .gtCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Native Gauge, no custom ring math: fill fraction + traffic-light
    /// color say it before any text does.
    private var gaugeRing: some View {
        Gauge(value: building.isOpen ? min(building.percentage, 1) : 0) {
            EmptyView()
        } currentValueLabel: {
            Text(building.isOpen ? "\(Int(percent))" : "—")
                .font(.gtHeading4)
                .foregroundStyle(building.isOpen ? level.color : Color.gtSecondaryText)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(building.isOpen ? level.color : Color.gtSecondaryText)
        .scaleEffect(0.92)
        .frame(width: 56, height: 56)
    }

    /// One tracked micro line: status, heads inside, and where the next
    /// hour is heading — the three things the old three-row card said.
    private var statusLine: String {
        guard building.isOpen else { return "CLOSED" }
        var parts = ["\(level.statusText) · \(Int(percent))%"]
        parts.append("\(building.people.formatted()) inside")
        if let trend = trendText { parts.append(trend) }
        return parts.joined(separator: " · ").uppercased()
    }

    /// The feed's `hourSummary` is not always a forecast — live data has
    /// it carrying plain status words like "Open". Only wording that
    /// clearly describes a direction earns a trend; anything else is
    /// omitted rather than printed as a nonsense "next hr open".
    private var trendText: String? {
        let summary = building.hourSummary.lowercased()
        if summary.contains("increas") || summary.contains("busier") { return "next hr ↑" }
        if summary.contains("decreas") || summary.contains("quieter") { return "next hr ↓" }
        if summary.contains("steady") || summary.contains("same") { return "next hr →" }
        return nil
    }

    private func subAreaTiles(_ subLocs: [BuildingSubLocationCapacity]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(subLocs) { sub in
                let subLevel = CapacityLevel(percent: sub.percentage * 100)
                VStack(spacing: 2) {
                    Text("\(Int(sub.percentage * 100))")
                        .font(.gtHeading4)
                        .foregroundStyle(subLevel.color)
                    Text(sub.name)
                        .font(.gtHeading6)
                        .tracking(0.3)
                        .foregroundStyle(Color.gtSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 58)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    Color.gtNavy.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
    }

    private var accessibilityText: String {
        guard building.isOpen else { return "\(building.name), closed" }
        return "\(building.name), \(level.statusText.lowercased()), \(Int(percent)) percent full, "
            + "\(building.people.formatted()) people inside"
    }
}
