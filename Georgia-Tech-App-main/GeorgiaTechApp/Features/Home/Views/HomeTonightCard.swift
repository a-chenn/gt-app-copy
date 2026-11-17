//
//  HomeTonightCard.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// What's on later today — a gold time tile per event, then title and
/// location. "See All" hands off to the Events tab; Home never owns the
/// feature. Hidden when nothing is left on today's calendar.
struct HomeTonightCard: View {
    @Query(sort: \Event.startDate) private var events: [Event]

    var onSeeAll: () -> Void = {}

    /// The tile splits the hour from AM/PM so it can stack them; the
    /// format-style API has no "meridiem only" symbol.
    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter
    }()

    private static let meridiemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()

    /// Events still to come today. Anything already underway is skipped
    /// — "tonight" should be things you can still show up to.
    private var tonight: [Event] {
        let now = Date()
        return Array(
            events
                .filter { $0.startDate >= now && Calendar.current.isDateInToday($0.startDate) }
                .prefix(3))
    }

    var body: some View {
        if !tonight.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader("Tonight") {
                    Button("See All", action: onSeeAll)
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtDarkGold)
                        .accessibilityLabel("See all events")
                }

                VStack(spacing: 0) {
                    ForEach(Array(tonight.enumerated()), id: \.element.eventID) { index, event in
                        if index > 0 {
                            Divider()
                                .overlay(Color.gtNavy.opacity(0.08))
                                .padding(.leading, 64)
                        }
                        NavigationLink(destination: EventDetailView(event: event)
                            .toolbar(.visible, for: .navigationBar)) {
                            row(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .gtCard(padding: 0)
            }
        }
    }

    private func row(_ event: Event) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: -1) {
                Text(Self.hourFormatter.string(from: event.startDate))
                    .font(.gtHeading4)
                Text(Self.meridiemFormatter.string(from: event.startDate))
                    .font(.gtHeading6)
                    .tracking(0.5)
            }
            .foregroundStyle(Color.gtDarkGold)
            .frame(width: 38, height: 38)
            .background(
                Color.gtGold.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
