//
//  GTCapacityPhotoWidgetEntry.swift
//  GTCapacityWidget
//

import WidgetKit

/// A single building's data for the photo widget.
struct CapacityPhotoData {
    let buildingID: Int
    let name: String
    let shortName: String
    let percentage: Double
    let isOpen: Bool
}

/// Widget states for the photo widget
enum PhotoWidgetState {
    case loaded(CapacityPhotoData)
    case notConfigured
    case buildingNotFound
    case fetchFailed
}

struct GTCapacityPhotoEntry: TimelineEntry {
    /// The date WidgetKit uses to schedule this entry's display.
    let date: Date
    /// When the capacity/ fetch actually completed — shown as "as of X:XX PM".
    let fetchedAt: Date
    /// The current state of the widget
    let state: PhotoWidgetState
    /// The building ID that was configured
    let buildingID: Int?
}
