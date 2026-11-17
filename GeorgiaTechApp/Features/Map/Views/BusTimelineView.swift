//
//  BusTimelineView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// One live bus's stops as main-sheet content (Figma "specific stop list
/// view"): the stop it just left, its next stop marked with a pin, then
/// every stop after it with live ETAs, on a line in the route's color.
/// A row's arrow opens that stop.
struct BusTimelineView: View {
    @Environment(MapSelection.self) private var selection

    let bus: BusLive
    let route: BusRoute?
    let stopEstimates: [Int: [BusStopEstimate]]

    private var tint: Color {
        route.map { Color(hex: $0.mapColor) } ?? Color.gtNavy
    }

    /// Live seconds-to-stop for this vehicle, keyed by routeStopID.
    private var secondsByStop: [Int: Int] {
        var result: [Int: Int] = [:]
        for estimate in stopEstimates.values.joined()
        where estimate.vehicleID == bus.vehicleID && estimate.isOnRoute {
            result[estimate.routeStopID] = min(result[estimate.routeStopID] ?? .max, estimate.secondsToStop)
        }
        return result
    }

    private struct Entry: Identifiable {
        let stop: BusStop
        let seconds: Int?
        let isPrevious: Bool
        let isNext: Bool
        var id: Int { stop.routeStopID }
    }

    /// Route stops in loop order, starting at the stop behind the bus.
    private var entries: [Entry] {
        let stops = (route?.stops ?? []).sorted { $0.stopOrder < $1.stopOrder }
        guard !stops.isEmpty else { return [] }
        let seconds = secondsByStop
        let nextIndex = stops.indices
            .filter { seconds[stops[$0].routeStopID] != nil }
            .min { seconds[stops[$0].routeStopID]! < seconds[stops[$1].routeStopID]! }
            ?? 0
        let start = (nextIndex - 1 + stops.count) % stops.count
        return (0..<stops.count).map { offset in
            let index = (start + offset) % stops.count
            return Entry(
                stop: stops[index],
                seconds: offset == 0 ? nil : seconds[stops[index].routeStopID],
                isPrevious: offset == 0 && stops.count > 1,
                isNext: index == nextIndex)
        }
    }

    var body: some View {
        let entries = entries
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    SheetBackHeader(
                        title: "\(route?.name ?? "GT") Bus \(bus.displayName)",
                        onBack: { withAnimation { selection.focusedBusID = nil } }
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            row(entry, isFirst: index == 0, isLast: index == entries.count - 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
    }

    private func row(_ entry: Entry, isFirst: Bool, isLast: Bool) -> some View {
        Button {
            withAnimation {
                selection.focusedBusID = nil
                selection.select(entry.stop.toSearchCard())
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                timelineMarker(entry, isFirst: isFirst, isLast: isLast)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.stop.name)
                        .font(entry.isNext ? .gtHeading5 : .gtBody2)
                        .foregroundStyle(entry.isPrevious ? Color.gtSecondaryText : Color.gtPrimaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let detail = detailText(entry) {
                        Text(detail)
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                }
                .padding(.vertical, entry.isNext ? 12 : 8)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this stop")
    }

    private func detailText(_ entry: Entry) -> String? {
        if entry.isNext {
            guard let seconds = entry.seconds else { return "Next stop" }
            return "Next stop · \(arrivalText(seconds))"
        }
        return entry.seconds.map(arrivalText)
    }

    /// "12:34 PM (4 min)"
    private func arrivalText(_ seconds: Int) -> String {
        let time = Date.now.addingTimeInterval(TimeInterval(seconds))
            .formatted(date: .omitted, time: .shortened)
        return "\(time) (\(BusArrivals.minutesText(seconds)))"
    }

    private func timelineMarker(_ entry: Entry, isFirst: Bool, isLast: Bool) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : tint.opacity(entry.isNext ? 1 : (entry.isPrevious ? 0.4 : 1)))
                    .frame(width: 3)
                Rectangle()
                    .fill(isLast ? Color.clear : tint.opacity(entry.isPrevious ? 0.4 : 1))
                    .frame(width: 3)
            }

            if entry.isNext {
                ZStack {
                    HeadingTeardrop()
                        .fill(tint)
                        .rotationEffect(.degrees(180))
                    Circle()
                        .fill(Color.gtWhite)
                        .frame(width: 8, height: 8)
                        .offset(y: -1)
                }
                .frame(width: 26, height: 26)
                .offset(y: -6)
            } else {
                Circle()
                    .fill(Color.gtWhite)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle().strokeBorder(tint.opacity(entry.isPrevious ? 0.4 : 1), lineWidth: 2.5)
                    }
            }
        }
        .frame(width: 26)
        .frame(maxHeight: .infinity)
    }
}
