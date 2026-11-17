//
//  MapTopOverlaysView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The floating next-bus chip shown during an active transit route.
struct MapTopOverlaysView: View {
    let transitChip: (colorHex: String, seconds: Int)?

    var body: some View {
        if let chip = transitChip {
            VStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: chip.colorHex))
                        .frame(width: 10, height: 10)
                    Image(systemName: "bus.fill")
                        .font(.gtBody3)
                    // "Next bus", not "your bus" — the soonest arrival
                    // at the boarding stop, which may precede the
                    // planned (catchable) departure.
                    Text("Next bus in \(BusArrivals.minutesText(chip.seconds))")
                        .font(.gtHeading5)
                }
                .foregroundStyle(Color.gtPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next bus at your stop in \(BusArrivals.minutesText(chip.seconds))")

                Spacer()
            }
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
