//
//  EventReminders.swift
//  GeorgiaTechApp
//

import Foundation
import UserNotifications

// swiftlint:disable no_notification_center
// That rule bans Foundation's notification bus for state sharing.
// UNUserNotificationCenter is a different API — local user notifications —
// which is the only way to schedule reminders on iOS.

/// Local "starts soon" reminders for campus events.
enum EventReminders {
    static let minutesBefore = 30

    enum ScheduleResult {
        case scheduled
        case permissionDenied
        case startsTooSoon
        case failed
    }

    /// A rescheduled event keeps its pending reminder aimed at the OLD
    /// time — when one is pending, re-issue it against the new start.
    static func rescheduleIfPending(for event: Event) async {
        guard await hasReminder(for: event) else { return }
        cancelReminder(for: event)
        _ = await scheduleReminder(for: event)
    }

    static func hasReminder(for event: Event) async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == identifier(for: event) }
    }

    static func scheduleReminder(for event: Event) async -> ScheduleResult {
        // Check the too-soon case before prompting for permission — no
        // point asking when there's nothing to schedule.
        let fireDate = event.startDate.addingTimeInterval(-Double(minutesBefore * 60))
        guard fireDate.timeIntervalSinceNow > 0 else { return .startsTooSoon }
        
        let authorized = await NotificationService.shared.requestAuthorization()
        guard authorized else { return .permissionDenied }
        
        let body: String
        if let location = event.location, !location.isEmpty {
            body = "Starts in \(minutesBefore) minutes at \(location)."
        } else {
            body = "Starts in \(minutesBefore) minutes."
        }
        
        let result = await NotificationService.shared.schedule(
            id: identifier(for: event),
            title: event.title,
            body: body,
            after: fireDate.timeIntervalSinceNow,
            topic: .campusEvents,
            route: .event(eventID: event.eventID)
        )
        
        // Translate back to this file's public type — EventDetailView switches
        // on EventReminders.ScheduleResult and must not break. Both .notAuthorized
        // and .topicDisabled mean the user can't get this notification, so they
        // collapse to a single .permissionDenied case here.
        switch result {
        case .scheduled: return .scheduled
        case .notAuthorized, .topicDisabled: return .permissionDenied
        case .invalidTime: return .startsTooSoon
        case .failed: return .failed
        }
    }

    static func cancelReminder(for event: Event) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: event)])
    }

    private static func identifier(for event: Event) -> String {
        "event-reminder-\(event.eventID)"
    }
}
// swiftlint:enable no_notification_center
