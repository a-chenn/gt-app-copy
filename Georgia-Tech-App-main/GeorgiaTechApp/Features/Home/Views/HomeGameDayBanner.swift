//
//  HomeGameDayBanner.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// Gold-sweep banner for an athletics event inside the next 48 hours.
/// Real events only — it renders nothing the rest of the time, so the
/// home screen never shows a hollow "no game" box.
struct HomeGameDayBanner: View {
    @Query(sort: \Event.startDate) private var events: [Event]

    var onOpenEvent: (Event) -> Void = { _ in }

    /// How far ahead the banner looks. A game four days out is not
    /// "game day"; this is the one number, so the comment and the code
    /// cannot drift apart again.
    private static let horizonHours = 48

    /// The soonest athletics event starting within `horizonHours`.
    private var gameDay: Event? {
        let now = Date()
        guard let horizon = Calendar.current.date(byAdding: .hour, value: Self.horizonHours, to: now) else {
            return nil
        }
        return events.first {
            $0.startDate >= now && $0.startDate <= horizon
                && $0.eventCategories.contains { $0.localizedCaseInsensitiveContains("athletics") }
        }
    }

    var body: some View {
        if let event = gameDay {
            Button {
                onOpenEvent(event)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(leadLabel(for: event).uppercased())
                        .font(.gtHeading6)
                        .tracking(1.8)
                        .foregroundStyle(Color.gtNavy.opacity(0.7))

                    Text(event.title)
                        .font(.gtHeading3)
                        .foregroundStyle(Color.gtNavy)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(detailLine(for: event))
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtNavy.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient.gtGoldGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(leadLabel(for: event)). \(event.title). \(detailLine(for: event))")
        }
    }

    private func leadLabel(for event: Event) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(event.startDate) { return "Game day today" }
        if calendar.isDateInTomorrow(event.startDate) { return "Game day tomorrow" }
        return "Game day \(event.startDate.formatted(.dateTime.weekday(.wide)))"
    }

    private func detailLine(for event: Event) -> String {
        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        guard let location = event.location, !location.isEmpty else { return time }
        return "\(time) · \(location)"
    }
}
