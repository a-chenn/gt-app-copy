//
//  HomeGTDatesCard.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// The next few official GT dates (deadlines, breaks, registration
/// windows) — synced live from the API's admin-maintained feed. The
/// band renders nothing until the dates domain is seeded server-side,
/// so it ships dark and lights up on deploy.
struct HomeGTDatesCard: View {
    @Query(sort: \GTDate.date) private var dates: [GTDate]
    @Environment(\.colorScheme) private var colorScheme

    /// Opens the full list — the band only ever shows the next three.
    var onSeeAll: () -> Void = {}

    /// Dates are stored as UTC midnight of their CALENDAR day; the
    /// floor must be UTC midnight of TODAY'S LOCAL day, or an Atlanta
    /// deadline vanishes at local midnight — the day it matters (#R).
    private var upcoming: [GTDate] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let localToday = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let floor = utc.date(from: localToday) else { return [] }
        return Array(dates.filter { $0.date >= floor }.prefix(3))
    }

    /// Renders the stored UTC-midnight day WITHOUT local conversion
    /// (local formatting shows the previous evening in the Americas).
    private static let utcDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    var body: some View {
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader("Official GT Dates") {
                    Button(action: onSeeAll) {
                        HStack(spacing: 3) {
                            Text("See All")
                                .font(.gtHeading6)
                            Image(systemName: "chevron.right")
                                .font(.gtHeading6)
                        }
                        .foregroundStyle(Color.gtSecondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("See all official GT dates")
                }

                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.dateID) { index, date in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 14)
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(date.dateText.isEmpty
                                     ? Self.utcDayFormatter.string(from: date.date)
                                     : date.dateText)
                                    .font(.gtHeading6)
                                    .foregroundStyle((colorScheme == .dark ? Color.gtGold : Color.gtDarkGold))
                                Text(date.category)
                                    .font(.gtBody4)
                                    .foregroundStyle(Color.gtSecondaryText)
                            }
                            .frame(width: 88, alignment: .leading)

                            Text(date.title)
                                .font(.gtBody2)
                                .foregroundStyle(Color.gtPrimaryText)
                                .lineLimit(2)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
        .padding(.vertical, 9)
                        .accessibilityElement(children: .combine)
                    }
                }
                .gtCard(padding: 0)
            }
        }
    }
}
