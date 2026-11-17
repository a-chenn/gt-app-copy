//
//  GTDiningMediumView.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTDiningMediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: GTDiningEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Dining Open Near You")
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "fork.knife")
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                Spacer(minLength: 4)
                Text(asOfText)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
            }

            if entry.fetchFailed {
                Spacer(minLength: 0)
                Text("Can't reach GT right now")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
                Spacer(minLength: 0)
            } else if entry.places.isEmpty {
                Spacer(minLength: 0)
                Text("No dining options open right now...")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let next = entry.nextOpenText {
                    HStack {
                        Spacer(minLength: 0)
                        pill(next, isOpen: false)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(rowFill.opacity(0.6), in: Capsule())
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(entry.places.prefix(2).enumerated()), id: \.offset) { _, place in
                        placeRow(place)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), for: .widget)
    }

    // MARK: - Row

    private func placeRow(_ place: DiningPlaceData) -> some View {
        HStack(spacing: 8) {
            Text(place.name)
                .font(.gtHeading5)
                .foregroundStyle(place.isOpen ? Color.gtPrimaryText : Color.gtSecondaryText.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            pill(pillText(for: place), isOpen: place.isOpen)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity)
        .background(rowFill, in: Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.08), radius: 4, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.name), \(place.statusText)")
    }

    // MARK: - Pill

    private func pill(_ text: String, isOpen: Bool) -> some View {
        Text(text)
            .font(.gtBody2)
            .foregroundStyle(pillTextColor(isOpen: isOpen))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(pillFill(isOpen: isOpen), in: Capsule())
    }

    private func pillFill(isOpen: Bool) -> Color {
        if isOpen {
            return Color.gtTechLawn.opacity(colorScheme == .dark ? 0.45 : 0.18)
        }
        return colorScheme == .dark ? Color.gtNavy : Color.gtSecondaryText.opacity(0.15)
    }

    private func pillTextColor(isOpen: Bool) -> Color {
        if colorScheme == .dark { return Color.gtWhite }
        return isOpen ? Color.gtTechLawn : Color.gtPrimaryText
    }

    private var rowFill: Color {
        colorScheme == .dark ? Color.gtWhite.opacity(0.08) : Color.gtWhite
    }

    // MARK: - Display text

    /// Open places show just the closing time ("2 AM", "7:30 PM");
    /// everything else falls back to the existing statusText.
    private func pillText(for place: DiningPlaceData) -> String {
        guard place.isOpen, let minutes = place.closesAtMinutes else { return place.statusText }
        let m = minutes % 1440
        let hour24 = m / 60
        let minute = m % 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let suffix = hour24 < 12 ? "AM" : "PM"
        return minute == 0
            ? "\(hour12) \(suffix)"
            : "\(hour12):\(String(format: "%02d", minute)) \(suffix)"
    }

    private var asOfText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "as of \(fmt.string(from: entry.fetchedAt))"
    }
}

#Preview(as: .systemMedium) {
    GTDiningWidget()
} timeline: {
    GTDiningEntry(
        date: .now, fetchedAt: .now, openCount: 3,
        places: [
            DiningPlaceData(name: "North Ave Dining Hall",
                            statusText: "Open until 7:30PM", isOpen: true,
                            closesAtMinutes: 1170, opensAtMinutes: nil),
            DiningPlaceData(name: "West Village",
                            statusText: "Open until 8:00PM", isOpen: true,
                            closesAtMinutes: 1200, opensAtMinutes: nil),
            DiningPlaceData(name: "Brittain Dining Hall",
                            statusText: "Open until 9:00PM", isOpen: true,
                            closesAtMinutes: 1260, opensAtMinutes: nil),
            DiningPlaceData(name: "Ferst Place",
                            statusText: "Closed", isOpen: false,
                            closesAtMinutes: nil, opensAtMinutes: nil)
        ],
        soonestClosingText: "Open until 7:30PM",
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
