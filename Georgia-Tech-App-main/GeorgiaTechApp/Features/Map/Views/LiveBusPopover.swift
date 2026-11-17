//
//  LiveBusPopover.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Transient card for a tapped live bus. A moving bus is telemetry, not a
/// place — it gets this lightweight popover, never the unified detail card
/// (see docs/ARCHITECTURE.md).
struct LiveBusPopover: View {
    let bus: BusLive
    let route: BusRoute?
    var stopEstimates: [Int: [BusStopEstimate]] = [:]
    let onDismiss: () -> Void
    let onDirectionsToNextStop: (BusStop) -> Void

    /// This vehicle's predicted next stops (system estimates).
    private var upcoming: [(stop: BusStop, seconds: Int)] {
        guard let route else { return [] }
        return BusArrivals.upcomingStops(
            for: bus.vehicleID, on: route, estimates: stopEstimates)
    }

    private var nextStop: BusStop? {
        upcoming.first?.stop
    }

    private var nextSeconds: Int? {
        upcoming.first?.seconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(route.map { Color(hex: $0.mapColor) } ?? Color.gtNavy)
                    .frame(width: 10, height: 10)

                Text("\(route?.name ?? "GT") Bus")
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(bus.displayName)
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtPrimaryText)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.gtSecondaryText)
                        .frame(width: 24, height: 24)
                        .background(Color.gtGray1, in: .circle)
                }
                .accessibilityLabel("Dismiss bus details")
            }

            if let nextSeconds, let nextStop {
                Label {
                    Text("\(BusArrivals.minutesText(nextSeconds)) to \(nextStop.name)")
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.gtBody3)
                .foregroundStyle(Color.gtPrimaryText)
            }

            if let dwell = bus.dwell {
                BusIdleBadge(seconds: dwell.seconds)
            }

            if let percentage = bus.capacityPercentage {
                Label("Capacity: \(Int(percentage))%", systemImage: "chart.bar.fill")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtPrimaryText)
            }

            if bus.isDelayed {
                Label("Delayed", systemImage: "exclamationmark.triangle.fill")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtRed)
            }

            if let nextStop {
                Button {
                    onDirectionsToNextStop(nextStop)
                } label: {
                    HStack(spacing: 4) {
                        Text("Routing")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtPrimaryText)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Get walking directions to \(nextStop.name) to catch this bus")
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gtWhite)
                .shadow(color: Color.gtOverlay1, radius: 8, y: 2)
        }
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }
}
