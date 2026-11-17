//
//  HomeBand.swift
//  GeorgiaTechApp
//

import Foundation

/// The reorderable bands of the Home screen.
///
/// The masthead is deliberately absent — it's the screen's header, not a
/// band, and pinning it keeps the greeting and glance strip where the eye
/// lands first.
enum HomeBand: String, CaseIterable, Identifiable {
    case gameDay
    case rightNow
    case openNow
    case tonight
    case dates
    case quickLinks
    case getHelp

    var id: String { rawValue }

    /// Shown in the reorder sheet. Bands whose heading is time-dependent
    /// ("Open for lunch") get their general name here instead.
    var title: String {
        switch self {
        case .gameDay: return "Game Day"
        case .rightNow: return "Right Now"
        case .openNow: return "Open Now"
        case .tonight: return "Tonight"
        case .dates: return "GT Dates"
        case .quickLinks: return "Campus Links"
        case .getHelp: return "Get Help"
        }
    }

    var subtitle: String {
        switch self {
        case .gameDay: return "Athletics inside 48 hours"
        case .rightNow: return "Live occupancy and the next bus"
        case .openNow: return "Dining serving right now"
        case .tonight: return "Today's remaining events"
        case .dates: return "Academic calendar dates"
        case .quickLinks: return "Your campus shortcuts"
        case .getHelp: return "Safety and support numbers"
        }
    }

    var symbol: String {
        switch self {
        case .gameDay: return "sportscourt"
        case .rightNow: return "chart.bar"
        case .openNow: return "fork.knife"
        case .tonight: return "calendar"
        case .dates: return "graduationcap"
        case .quickLinks: return "link"
        case .getHelp: return "cross.case"
        }
    }

    /// Live and time-bound above static, help last — the order the screen
    /// shipped with, and what "Reset" restores.
    static let defaultOrder: [HomeBand] = allCases
}

/// Order persistence, following the Campus Links precedent: an
/// `@AppStorage` String decoded on read, encoded on write.
///
/// A comma-joined list of raw values is enough here — unlike quick links,
/// this is a closed set with nothing user-authored to carry.
enum HomeBandStore {
    static func decode(_ raw: String) -> [HomeBand] {
        let saved = raw.split(separator: ",").compactMap { HomeBand(rawValue: String($0)) }
        // Append anything missing rather than discarding the user's order
        // wholesale — a band added in a later release should slot in at
        // the end, not reset the screen they arranged.
        let missing = HomeBand.defaultOrder.filter { !saved.contains($0) }
        let merged = saved + missing
        return merged.isEmpty ? HomeBand.defaultOrder : merged
    }

    static func encode(_ bands: [HomeBand]) -> String {
        bands.map(\.rawValue).joined(separator: ",")
    }
}
