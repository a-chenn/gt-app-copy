//
//  GTCapacitySmallView.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTCapacitySmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: GTCapacityEntry

    var body: some View {
        Group {
            if let building = entry.crc {
                if building.isOpen {
                    openContent(building)
                } else {
                    closedContent(building)
                }
            } else {
                unavailableContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func openContent(_ building: CapacityTileData) -> some View {
        let level = CapacityLevel(percent: building.percentage * 100)
        return VStack(alignment: .leading, spacing: 0) {
            // Circular progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(level.fill.opacity(0.25), lineWidth: 5)
                    .frame(width: 48, height: 48)

                // Filled arc based on percentage
                Circle()
                    .trim(from: 0, to: building.percentage)
                    .stroke(level.fill, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                // Percentage text
                Text("\(Int(building.percentage * 100))%")
                    .font(.gtHeading4)
                    .foregroundStyle(level.fill)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Int(building.percentage * 100)) percent full, \(level.statusText.lowercased())")

            // Building name - wraps naturally
            Text(building.name)
                .font(.gtHeading2)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)

            Spacer(minLength: 0)

            // Timestamp at bottom
            Text(asOfText)
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private func closedContent(_ building: CapacityTileData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text("Closed")
                .font(.gtHeading2)
                .foregroundStyle(Color.gtPrimaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer()
            Text(building.shortName)
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            Text("—")
                .font(.gtHeading2)
                .foregroundStyle(Color.gtSecondaryText)
            Spacer()
            Text("CRC")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
            Text(entry.fetchFailed ? "Can't reach GT" : asOfText)
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private var asOfText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "as of \(fmt.string(from: entry.fetchedAt))"
    }

    private var accessibilityLabel: String {
        guard let building = entry.crc else {
            return entry.fetchFailed
                ? "Campus Recreation Center, can't reach GT right now"
                : "Campus Recreation Center, data unavailable"
        }
        guard building.isOpen else { return "Campus Recreation Center, closed" }
        let level = CapacityLevel(percent: building.percentage * 100)
        return "Campus Recreation Center, \(level.statusText.lowercased()), "
             + "\(Int(building.percentage * 100)) percent full"
    }
}

#Preview(as: .systemSmall) {
    GTCapacityWidget()
} timeline: {
    GTCapacityEntry(
        date: .now, fetchedAt: .now,
        crc: CapacityTileData(buildingID: 1, name: "Campus Recreation Center",
                              shortName: "CRC", percentage: 0.48, isOpen: true),
        featured: [], fetchFailed: false
    )
    GTCapacityEntry(
        date: .now, fetchedAt: .now,
        crc: CapacityTileData(buildingID: 1, name: "Campus Recreation Center",
                              shortName: "CRC", percentage: 0.48, isOpen: false),
        featured: [], fetchFailed: false
    )
    GTCapacityEntry(
        date: .now, fetchedAt: .now,
        crc: nil, featured: [], fetchFailed: true
    )
}
