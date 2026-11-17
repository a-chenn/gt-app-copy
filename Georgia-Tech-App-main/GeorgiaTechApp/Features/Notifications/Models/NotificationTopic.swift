//
//  NotificationTopic.swift
//  GeorgiaTechApp
//

import Foundation

/// Everything the app is allowed to notify about, and the user's
/// preference for each one.
///
/// Notifications are opt-OUT here: every topic starts on, and the safety
/// net is iOS itself — nothing can be delivered until system
/// authorization is granted, so "on by default" never means a surprise
/// notification. The user's real choice is which topics to silence, made
/// in Settings → Notifications rather than by hunting down a feature and
/// opting into it.
///
/// The raw value IS the `UserDefaults` key, and the three pre-existing
/// keys are preserved verbatim so no one's saved setting is lost.
enum NotificationTopic: String, CaseIterable, Identifiable {
    case campusEvents = "notifyCampusEvents"
    case busArrivals = "notifyBusArrivals"
    case capacityAlerts = "notifyCapacityAlerts"
    case diningUpdates = "notifyDiningUpdates"
    case campusNotices = "notifyCampusNotices"

    var id: String { rawValue }

    /// Row title in Settings → Notifications.
    var title: String {
        switch self {
        case .campusEvents: return "Event reminders"
        case .busArrivals: return "Bus arrivals"
        case .capacityAlerts: return "Building capacity"
        case .diningUpdates: return "Dining updates"
        case .campusNotices: return "Important campus notices"
        }
    }

    /// One line describing what this topic actually sends. Keep it
    /// literally true — a topic that can't describe itself honestly
    /// shouldn't be switchable (see `isAvailable`).
    var subtitle: String {
        switch self {
        case .campusEvents:
            return "A reminder before an event you saved starts."
        case .busArrivals:
            return "A heads-up before your bus reaches a stop you're watching."
        case .capacityAlerts:
            return "When a building you're watching gets quiet."
        case .diningUpdates:
            return "When a dish you've hearted is on a menu today."
        case .campusNotices:
            return "Campus-wide announcements."
        }
    }

    var symbol: String {
        switch self {
        case .campusEvents: return "calendar"
        case .busArrivals: return "bus"
        case .capacityAlerts: return "person.3"
        case .diningUpdates: return "fork.knife"
        case .campusNotices: return "exclamationmark.bubble"
        }
    }

    /// Opt-out, not opt-in — see the type's note. A topic that should
    /// ever ship silent overrides this with a `switch`.
    var isOnByDefault: Bool { true }

    /// Whether anything in the app actually sends this today.
    ///
    /// This is the honest-copy gate: an unavailable topic must never be
    /// presented as a working switch, because this app doesn't ship UI
    /// that pretends to do something (see CLAUDE.md). Dining and campus
    /// notices have no feed behind them at all — there is no data source
    /// to notify FROM, so they stay false until one exists.
    ///
    /// Bus arrivals and capacity alerts are true on the assumption their
    /// senders ship alongside the notification settings screen. If that
    /// work slips, flip them back to false rather than shipping a switch
    /// that promises something nothing sends.
    var isAvailable: Bool {
        switch self {
        case .campusEvents, .busArrivals, .capacityAlerts, .diningUpdates: return true
        case .campusNotices: return false
        }
    }
}
