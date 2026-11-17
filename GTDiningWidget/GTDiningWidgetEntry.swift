//
//  GTDiningWidgetEntry.swift
//  GTCapacityWidget
//

import WidgetKit

/// One restaurant's data as the widget needs it — flat, no SwiftData.
struct DiningPlaceData {
    let name: String
    /// Full status string from DiningHours.statusText — "Open until 9:00PM" / "Closed until 7:00AM" / "Closed".
    let statusText: String
    let isOpen: Bool
    /// Minutes into the day when this place closes — used to sort open places and derive soonestClosingText.
    let closesAtMinutes: Int?
    let opensAtMinutes: Int?
}

struct GTDiningEntry: TimelineEntry {
    let date: Date
    /// When the dining/ fetch completed — shown as "as of X:XX PM" on fetch-failed state.
    let fetchedAt: Date
    let openCount: Int
    /// Up to 4 places: open (sorted by closing time, soonest first) then closed (sorted by name).
    let places: [DiningPlaceData]
    /// Status text of the open place closing soonest, e.g. "Open until 9:00PM". Nil when nothing is open.
    let soonestClosingText: String?
    /// Text for the small widget's "nothing open" state, e.g. "Opens 7:00AM". Nil when something is open.
    let nextOpenText: String?
    let fetchFailed: Bool
}

/// Slim DTO — only the two fields the widget needs. JSONDecoder ignores everything else in the
/// dining/ payload, so the full menu graph is never allocated in the widget process.
struct DiningSlimJSON: Decodable {
    let name: String
    let hoursOpen: [[String]]?

    enum CodingKeys: String, CodingKey {
        case name
        case hoursOpen = "hours_open"
    }
}
