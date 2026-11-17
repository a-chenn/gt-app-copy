//
//  GTCapacityWidgetEntry.swift
//  GTCapacityWidget
//

import WidgetKit

/// A single building's data as the widget needs it — flat, no SwiftData.
struct CapacityTileData {
    let buildingID: Int
    let name: String
    let shortName: String
    let percentage: Double
    let isOpen: Bool
}

struct GTCapacityEntry: TimelineEntry {
    /// The date WidgetKit uses to schedule this entry's display.
    let date: Date
    /// When the capacity/ fetch actually completed — shown as "as of X:XX PM".
    let fetchedAt: Date
    /// The CRC tile for the small widget. nil if the building wasn't in the feed.
    let crc: CapacityTileData?
    /// Up to 4 featured buildings for the medium widget.
    let featured: [CapacityTileData]
    /// True when the fetch threw (network down, API unreachable, Secrets.plist missing).
    let fetchFailed: Bool
}
