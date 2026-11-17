//
//  GTCapacityPhotoMediumView.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTCapacityPhotoMediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: GTCapacityPhotoEntry

    var body: some View {
        switch entry.state {
        case .loaded(let building):
            loadedContent(building)
        case .notConfigured:
            instructionContent("Long-press to edit and pick a building")
        case .buildingNotFound:
            instructionContent("Building not found")
        case .fetchFailed:
            instructionContent("Can't reach GT right now")
        }
    }

    @ViewBuilder
    private func loadedContent(_ building: CapacityPhotoData) -> some View {
        let imageName = buildingImageName(for: building.shortName)

        // Content overlay
        HStack(alignment: .center, spacing: 20) {
            // Circular progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gtWhite.opacity(0.3), lineWidth: 10)

                // Filled arc based on percentage
                Circle()
                    .trim(from: 0, to: building.percentage)
                    .stroke(Color.gtWhite, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Percentage text
                Text("\(Int(building.percentage * 100))%")
                    .font(.gtHeading1)
                    .foregroundStyle(Color.gtWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 14)
            }
            .frame(width: 96, height: 96)

            // Building name and time
            VStack(alignment: .leading, spacing: 4) {
                Text(building.name)
                    .font(.gtHeading2)
                    .foregroundStyle(Color.gtWhite)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

                Text(asOfText)
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtWhite.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            // Background image — fills the whole widget, edge to edge
            Image(imageName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.3)
                .overlay(
                    Color.gtNavy.opacity(0.65)
                )
        }
        .widgetURL(URL(string: "gtapp://capacities?id=\(building.buildingID)"))
    }

    @ViewBuilder
    private func instructionContent(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.gtBody3)
                .foregroundStyle(Color.gtSecondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private var asOfText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "as of \(fmt.string(from: entry.fetchedAt))"
    }

    private func buildingImageName(for shortName: String) -> String {
        switch shortName {
        case "CRC":
            return "crcImage"
        case "Library":
            return "priceGilbertImage"
        case "Clough":
            return "cloughCommonsImage"
        case "Crosland":
            return "croslandTowerImage"
        default:
            return "buildingDefaultImage"
        }
    }
}

#Preview(as: .systemMedium) {
    GTCapacityPhotoWidget()
} timeline: {
    GTCapacityPhotoEntry(
        date: .now, fetchedAt: .now,
        state: .loaded(CapacityPhotoData(
            buildingID: 1,
            name: "Price Gilbert Library",
            shortName: "Library",
            percentage: 0.95,
            isOpen: true
        )),
        buildingID: 1
    )
    GTCapacityPhotoEntry(
        date: .now, fetchedAt: .now,
        state: .notConfigured,
        buildingID: nil
    )
    GTCapacityPhotoEntry(
        date: .now, fetchedAt: .now,
        state: .fetchFailed,
        buildingID: 1
    )
}
