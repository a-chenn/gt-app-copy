//
//  GTCapacityMediumView.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTCapacityMediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: GTCapacityEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("RIGHT NOW")
                    .font(.gtHeading6)
                    .tracking(0.8)
                    .foregroundStyle(Color.gtSecondaryText)
                Spacer()
                Text(asOfText)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)
            }

            if entry.fetchFailed {
                Spacer()
                Text("Can't reach GT right now")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
                Spacer()
            } else if entry.featured.isEmpty {
                Spacer()
                Text("All buildings closed")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
                Spacer()
            } else {
                HStack(spacing: 10) {
                    ForEach(entry.featured, id: \.buildingID) { building in
                        Link(destination: URL(string: "gtapp://capacities?id=\(building.buildingID)") ?? URL(string: "gtapp://capacities")!) {
                            tileView(building)
                        }
                        .accessibilityLabel(tileLabel(building))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    @ViewBuilder
    private func tileView(_ building: CapacityTileData) -> some View {
        let level = CapacityLevel(percent: building.percentage * 100)
        VStack(spacing: 6) {
            if building.isOpen {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(level.fill.opacity(0.25), lineWidth: 5)

                    // Filled arc based on percentage
                    Circle()
                        .trim(from: 0, to: building.percentage)
                        .stroke(level.fill, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    // Percentage text
                    Text("\(Int(building.percentage * 100))%")
                        .font(.gtHeading4)
                        .foregroundStyle(level.fill)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                }
                .frame(width: 52, height: 52)
            } else {
                ZStack {
                    // Empty faded circle
                    Circle()
                        .stroke(Color.gtSecondaryText.opacity(0.25), lineWidth: 5)

                    Text("—")
                        .font(.gtHeading4)
                        .foregroundStyle(Color.gtSecondaryText)
                }
                .frame(width: 52, height: 52)
            }
            Text(building.shortName)
                .font(.gtHeading6)
                .tracking(0.4)
                .foregroundStyle(Color.gtSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func tileLabel(_ building: CapacityTileData) -> String {
        guard building.isOpen else { return "\(building.name), closed" }
        let level = CapacityLevel(percent: building.percentage * 100)
        return "\(building.name), \(level.statusText.lowercased()), "
             + "\(Int(building.percentage * 100)) percent full"
    }

    private var asOfText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "as of \(fmt.string(from: entry.fetchedAt))"
    }
}

#Preview(as: .systemMedium) {
    GTCapacityWidget()
} timeline: {
    GTCapacityEntry(
        date: .now, fetchedAt: .now,
        crc: CapacityTileData(buildingID: 1, name: "Campus Recreation Center",
                              shortName: "CRC", percentage: 0.48, isOpen: true),
        featured: [
            CapacityTileData(buildingID: 1, name: "Campus Recreation Center",
                             shortName: "CRC", percentage: 0.48, isOpen: true),
            CapacityTileData(buildingID: 2, name: "Price Gilbert Library",
                             shortName: "Library", percentage: 0.31, isOpen: true),
            CapacityTileData(buildingID: 3, name: "Clough Undergraduate Learning Commons",
                             shortName: "Clough", percentage: 0.72, isOpen: true)
        ],
        fetchFailed: false
    )
    GTCapacityEntry(
        date: .now, fetchedAt: .now,
        crc: nil, featured: [], fetchFailed: true
    )
}
