//
//  GTDatesListView.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// Every upcoming official GT date, grouped by month — the Home band
/// shows the next three and this is where "See All" lands.
struct GTDatesListView: View {
    @Query(sort: \GTDate.date) private var dates: [GTDate]

    /// Same UTC floor the Home band uses: dates are stored as UTC
    /// midnight of their calendar day, so an Atlanta deadline must not
    /// vanish at local midnight on the day it matters.
    private var upcoming: [GTDate] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let localToday = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let floor = utc.date(from: localToday) else { return [] }
        return dates.filter { $0.date >= floor }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private var months: [(month: String, dates: [GTDate])] {
        var order: [String] = []
        var grouped: [String: [GTDate]] = [:]
        for date in upcoming {
            let key = Self.monthFormatter.string(from: date.date)
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(date)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(months, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        GTSectionHeader(group.month)

                        VStack(spacing: 0) {
                            ForEach(
                                Array(group.dates.enumerated()), id: \.element.dateID
                            ) { index, date in
                                if index > 0 {
                                    Divider()
                                        .overlay(Color.gtNavy.opacity(0.08))
                                        .padding(.leading, 96)
                                }
                                row(date)
                            }
                        }
                        .gtCard(radius: 18, padding: 0)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .gtScreenBackground()
        .navigationTitle("Official GT Dates")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if upcoming.isEmpty {
                ContentUnavailableView(
                    "No Dates Yet",
                    systemImage: "calendar",
                    description: Text("Registrar dates will show up here.")
                )
            }
        }
    }

    private func row(_ date: GTDate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(date.dateText.isEmpty
                     ? Self.dayFormatter.string(from: date.date)
                     : date.dateText)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtDarkGold)
                Text(date.category)
                    .font(.gtBody4)
                    .foregroundStyle(Color.gtSecondaryText)
            }
            .frame(width: 96, alignment: .leading)

            Text(date.title)
                .font(.gtBody2)
                .foregroundStyle(Color.gtPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}
