//
//  GTBusMediumView.swift
//  GTBusWidget
//

import SwiftUI
import WidgetKit

struct GTBusMediumView: View {
    let entry: GTBusEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.stopName)
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                if case .arrivals = entry.state {
                    Text("as of \(entry.fetchedAt.formatted(.dateTime.hour().minute()))")
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)

            switch entry.state {
            case .arrivals(let rows):
                VStack(spacing: 6) {
                    ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { _, row in
                        arrivalRow(row)
                    }
                }
                // Center the pills in the space below the header
                .frame(maxHeight: .infinity, alignment: .center)

            case .noService:
                statusText("No buses running right now")

            case .noArrivals:
                statusText("No buses nearby right now")

            case .checking:
                statusText("Checking…")

            case .notConfigured:
                statusText("Long-press to edit and pick a stop")

            case .stopGone:
                statusText("This stop is no longer available — long-press to re-pick")

            case .fetchFailed:
                statusText("Can't reach GT Buses right now")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtBackground), for: .widget)
    }

    private func arrivalRow(_ row: BusArrivalRow) -> some View {
        HStack(spacing: 8) {
            // Route color as small dot only — not a text color or fill.
            // In tinted mode the dot loses its color; the row must still be readable.
            Circle()
                .fill(Color(hex: row.mapColor))
                .frame(width: 10, height: 10)
                .overlay {
                    if colorScheme == .dark {
                        Circle().strokeBorder(Color.gtWhite, lineWidth: 1.5)
                    }
                }

            Text(row.routeName)
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text(BusArrivalsWidget.minutesText(row.secondsToStop))
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(rowFill, in: Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.08), radius: 4, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.routeName), \(max(row.secondsToStop / 60, 1)) minutes")
    }

    private func statusText(_ message: String) -> some View {
        Text(message)
            .font(.gtHeading5)
            .foregroundStyle(Color.gtSecondaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxHeight: .infinity, alignment: .center)
            .accessibilityLabel(message)
    }

    private var rowFill: Color {
        colorScheme == .dark ? Color.gtWhite.opacity(0.08) : Color.gtWhite
    }
}
