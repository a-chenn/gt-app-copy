//
//  GTDiningSmallView.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTDiningSmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: GTDiningEntry

    var body: some View {
        Group {
            if entry.fetchFailed {
                failedContent
            } else if entry.openCount > 0 {
                openContent
            } else {
                closedContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var openContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text("\(entry.openCount)")
                .font(.gtHeading1)
                .foregroundStyle(Color.gtTechLawn)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(entry.openCount == 1 ? "place open" : "places open")
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let closing = entry.soonestClosingText {
                pill(closing, isOpen: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private var closedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text("—")
                .font(.gtHeading1)
                .foregroundStyle(Color.gtSecondaryText)
            Text("Nothing open")
                .font(.gtHeading5)
                .foregroundStyle(Color.gtSecondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let next = entry.nextOpenText {
                pill(next, isOpen: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    private var failedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text("—")
                .font(.gtHeading1)
                .foregroundStyle(Color.gtSecondaryText)
            Spacer(minLength: 0)
            Text("Can't reach GT")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    // MARK: - Shared pieces (match the medium widget)

    private var header: some View {
        HStack(spacing: 6) {
            Text("Dining")
                .font(.gtHeading3)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)
            Image(systemName: "fork.knife")
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
        }
    }

    private func pill(_ text: String, isOpen: Bool) -> some View {
        Text(text)
            .font(.gtBody2)
            .foregroundStyle(pillTextColor(isOpen: isOpen))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(pillFill(isOpen: isOpen), in: Capsule())
    }

    private func pillFill(isOpen: Bool) -> Color {
        if isOpen {
            return Color.gtTechLawn.opacity(colorScheme == .dark ? 0.45 : 0.18)
        }
        return colorScheme == .dark ? Color.gtWhite.opacity(0.08) : Color.gtSecondaryText.opacity(0.15)
    }

    private func pillTextColor(isOpen: Bool) -> Color {
        if colorScheme == .dark { return Color.gtWhite }
        return isOpen ? Color.gtTechLawn : Color.gtPrimaryText
    }

    private var asOfText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "as of \(fmt.string(from: entry.fetchedAt))"
    }

    private var accessibilityLabel: String {
        if entry.fetchFailed { return "Dining, can't reach GT right now" }
        if entry.openCount == 0 {
            if let next = entry.nextOpenText {
                return "No dining halls open. \(next)."
            }
            return "No dining halls open right now."
        }
        let placeWord = entry.openCount == 1 ? "place" : "places"
        var label = "\(entry.openCount) dining \(placeWord) open."
        if let closing = entry.soonestClosingText {
            label += " \(closing)."
        }
        return label
    }
}

#Preview(as: .systemSmall) {
    GTDiningWidget()
} timeline: {
    GTDiningEntry(
        date: .now, fetchedAt: .now, openCount: 3,
        places: [],
        soonestClosingText: "Open until 9:00PM",
        nextOpenText: nil, fetchFailed: false
    )
    GTDiningEntry(
        date: .now, fetchedAt: .now, openCount: 0,
        places: [],
        soonestClosingText: nil,
        nextOpenText: "Opens 7:00AM", fetchFailed: false
    )
    GTDiningEntry(
        date: .now, fetchedAt: .now, openCount: 0,
        places: [], soonestClosingText: nil,
        nextOpenText: nil, fetchFailed: true
    )
}
