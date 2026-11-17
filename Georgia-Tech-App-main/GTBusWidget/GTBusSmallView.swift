//
//  GTBusSmallView.swift
//  GTBusWidget
//

import SwiftUI
import WidgetKit

struct GTBusSmallView: View {
    let entry: GTBusEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.stopName)
                .font(.gtHeading3)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            switch entry.state {
            case .arrivals(let rows):
                VStack(spacing: 6) {
                    ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { _, row in
                        arrivalRow(routeName: row.routeName,
                                   minutes: BusArrivalsWidget.minutesText(row.secondsToStop))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

            case .noService:
                statusText("No buses running")

            case .noArrivals:
                statusText("No buses nearby")

            case .checking:
                statusText("Checking…")

            case .notConfigured:
                statusText("Edit widget to pick a stop")

            case .stopGone:
                statusText("Stop no longer available")

            case .fetchFailed:
                statusText("Can't reach GT Buses")
            }

            if case .arrivals = entry.state {
                Text("as of \(entry.fetchedAt.formatted(.dateTime.hour().minute()))")
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtBackground), for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Pieces

    private func arrivalRow(routeName: String, minutes: String) -> some View {
        HStack(spacing: 6) {
            Text(routeName)
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text(minutes)
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(rowFill, in: Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.08), radius: 4, y: 1)
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.gtHeading5)
            .foregroundStyle(Color.gtSecondaryText)
            .lineLimit(3)
            .minimumScaleFactor(0.8)
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private var rowFill: Color {
        colorScheme == .dark ? Color.gtWhite.opacity(0.08) : Color.gtWhite
    }

    private var accessibilityText: String {
        switch entry.state {
        case .arrivals(let rows):
            if let first = rows.first {
                let minutes = max(first.secondsToStop / 60, 1)
                return "\(entry.stopName). \(first.routeName) in about \(minutes) minutes, as of \(entry.fetchedAt.formatted(.dateTime.hour().minute()))."
            }
            return entry.stopName
        case .noService:
            return "\(entry.stopName). No buses running."
        case .noArrivals:
            return "\(entry.stopName). No buses nearby."
        case .checking:
            return "\(entry.stopName). Checking for buses."
        case .notConfigured:
            return "Edit widget to pick a stop."
        case .stopGone:
            return "\(entry.stopName). Stop no longer available."
        case .fetchFailed:
            return "\(entry.stopName). Can't reach GT Buses."
        }
    }
}
