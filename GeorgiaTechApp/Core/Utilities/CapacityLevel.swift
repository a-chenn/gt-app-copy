//
//  CapacityLevel.swift
//  GeorgiaTechApp
//

import SwiftUI

struct CapacityLevel {
    let statusText: String
    /// Safe as a FOREGROUND (gauge ring, numeral, tiles) on light and
    /// dark surfaces alike.
    let color: Color
    /// Filled-chip pair: a solid tile can carry the brighter brand gold
    /// because dark text sits on top of it (5.6:1) — the case that made
    /// `color` too light to reuse here.
    var fill: Color {
        switch statusText {
        case "NOT BUSY": return .gtTechLawn
        case "MODERATE": return .gtGold
        default: return .gtAzalea
        }
    }

    var onFill: Color {
        statusText == "MODERATE" ? .gtNavy : .gtWhite
    }

    /// Buckets a 0–100 percentage: light <33, moderate <66, busy ≥66.
    init(percent: Double) {
        switch percent {
        case ..<33:
            statusText = "NOT BUSY"
            color = Color.gtTechLawn
        case ..<66:
            statusText = "MODERATE"
            // Dark Gold, deliberately NOT Buzz: this value is not just
            // a badge fill — it also paints the gauge ring, the gauge
            // numeral, and the sub-area tiles, where the color IS the
            // foreground. Buzz (#EAAA00) reads 1.8:1 on a light card and
            // fails every one of those; Dark Gold clears 3:1 in both
            // appearances (4.6 light / 3.8 dark).
            color = Color.gtDarkGold
        default:
            statusText = "BUSY"
            color = Color.gtAzalea
        }
    }
}
