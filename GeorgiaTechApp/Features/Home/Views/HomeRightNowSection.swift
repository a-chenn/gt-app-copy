//
//  HomeRightNowSection.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// "RIGHT NOW" — a row of live occupancy tiles for the buildings people
/// actually ask about, each colored by its own status so the row reads
/// at a glance.
///
/// The whole section hides when the capacity feed has nothing to say.
struct HomeRightNowSection: View {
    @Query private var capacities: [BuildingCapacity]

    var onOpenCapacity: (Int) -> Void = { _ in }

    /// Buildings students ask about first; anything else fills in behind
    /// them, so the row still works if the feed renames or drops one.
    private static let preferredOrder = ["recreation", "price gilbert", "clough", "crosland"]

    private var featuredBuildings: [BuildingCapacity] {
        let open = capacities.filter(\.isOpen)
        let preferred = Self.preferredOrder.compactMap { term in
            open.first { $0.name.lowercased().contains(term) }
        }
        let rest = open
            .filter { building in !preferred.contains { $0.capacityID == building.capacityID } }
            .sorted { $0.name < $1.name }
        return Array((preferred + rest).prefix(4))
    }

    var body: some View {
        if !featuredBuildings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader("Right Now")

                HStack(spacing: 10) {
                    ForEach(featuredBuildings, id: \.capacityID) { building in
                        let level = CapacityLevel(percent: building.percentage * 100)
                        statTile(
                            value: "\(Int(building.percentage * 100))%",
                            caption: building.shortName,
                            fill: level.fill,
                            textColor: level.onFill,
                            label: "\(building.name), \(level.statusText.lowercased())"
                        ) {
                            onOpenCapacity(building.capacityID)
                        }
                    }
                }
                .gtCard()
            }
        }
    }

    private func statTile(
        value: String, caption: String, fill: Color, textColor: Color,
        label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(value)
                    .font(.gtHeading4)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 52, height: 52)
                    .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(caption)
                    .font(.gtHeading6)
                    .tracking(0.4)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}
