//
//  NotificationService.swift
//  GeorgiaTechApp
//

import Foundation
import Observation
import UserNotifications

// swiftlint:disable no_notification_center
// DO NOT DELETE THIS WRAPPER. That rule bans Foundation's notification
// bus for state sharing; UNUserNotificationCenter is an unrelated API —
// local user notifications — and is the only way to schedule a
// notification on iOS. Its name merely contains the banned substring, so
// removing this pair fails the build. EventReminders.swift carries the
// same wrapper for the same reason.

/// The app's one notification path: system authorization, the user's
/// per-topic preferences, and scheduling.
///
/// Everything that wants to notify goes through here rather than talking
/// to the user-notification center itself, so there is exactly one answer
/// to "is the app allowed to send this, and did the user ask for it?"
///
/// **Local notifications only.** The app links FirebaseAuth/AppCheck but
/// NOT FirebaseMessaging — there is no APNs backend and no server that
/// can reach the device. Everything here is scheduled on-device.
@Observable
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    /// The iOS-level permission state. Observable, so a settings screen
    /// re-renders the moment it changes — but it is a SNAPSHOT: the user
    /// can change permission in iOS Settings while the app is running,
    /// so refresh it whenever the app becomes active.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Topics the user has silenced. Observable so toggles update
    /// instantly, mirroring `FavoritesService.favoriteIDs`.
    private(set) var disabledTopics: Set<NotificationTopic> = []

    private let defaults = UserDefaults.standard
    private var center: UNUserNotificationCenter { .current() }

    private init() {
        loadPreferences()
        registerCategories()
    }

    // MARK: - Authorization

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Re-reads the system permission state. Call it when a
    /// notification-related screen appears and when the app returns to
    /// the foreground — the user can revoke permission in iOS Settings
    /// behind the app's back, and a stale toggle is worse than none.
    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Prompts for permission if it hasn't been asked yet, and returns
    /// whether the app is authorized afterwards.
    ///
    /// Safe to call repeatedly: iOS shows its prompt only once per
    /// install, and an already-denied state returns false without
    /// re-asking (there is no way to re-ask — the user has to go to
    /// iOS Settings).
    func requestAuthorization() async -> Bool {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return isAuthorized }

        let granted = (try? await center.requestAuthorization(
            options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }
    
    // MARK: - Routing
    
    /// Set by the notification delegate on tap; consumed once by AppShellView.
    /// Lives here — not on a view — so it survives cold launch before AppShellView exists.
    var pendingRoute: NotificationRoute?

    // Stored in userInfo, which iOS writes to disk — never rename this key or
    // notifications already scheduled will silently fail to decode their route.
    private static let routeKey = "notificationRoute"

    /// Encodes a route as a JSON string into a notification's userInfo.
    /// String rather than Data because userInfo must be plist-serializable for iOS to persist it.
    static func encode(_ route: NotificationRoute, into content: UNMutableNotificationContent) {
        if let data = try? JSONEncoder().encode(route),
           let string = String(data: data, encoding: .utf8) {
            content.userInfo[routeKey] = string
        }
    }

    /// Decodes the route a notification carries, or nil if it has none.
    /// Notifications scheduled before this change carry no route key — that's expected, not a bug.
    static func route(of request: UNNotificationRequest) -> NotificationRoute? {
        guard let string = request.content.userInfo[routeKey] as? String,
              let data = string.data(using: .utf8),
              let route = try? JSONDecoder().decode(NotificationRoute.self, from: data)
        else { return nil }
        return route
    }

    // MARK: - Preferences

    /// The one question every sender asks: should this go out?
    ///
    /// True only when the app is authorized, the topic has a real sender
    /// behind it, and the user hasn't silenced it.
    func isEnabled(_ topic: NotificationTopic) -> Bool {
        isAuthorized && topic.isAvailable && !disabledTopics.contains(topic)
    }

    /// The user's stored preference on its own, ignoring system
    /// authorization — what a Settings toggle should render, so the
    /// switch keeps showing their choice while permission is off.
    func isPreferred(_ topic: NotificationTopic) -> Bool {
        !disabledTopics.contains(topic)
    }

    /// Records the user's choice. Turning a topic OFF also cancels
    /// anything it has already scheduled — a silenced topic that still
    /// fires tonight's pending notification would read as a bug.
    func setEnabled(_ isOn: Bool, for topic: NotificationTopic) {
        if isOn {
            disabledTopics.remove(topic)
        } else {
            disabledTopics.insert(topic)
        }
        defaults.set(isOn, forKey: topic.rawValue)

        guard !isOn else { return }
        Task { await cancelAll(for: topic) }
    }

    /// A missing key means "never answered", which must fall back to the
    /// topic's default rather than `UserDefaults`' bare `false` — that
    /// difference is the whole opt-out model.
    private func loadPreferences() {
        disabledTopics = Set(NotificationTopic.allCases.filter { topic in
            guard defaults.object(forKey: topic.rawValue) != nil else {
                return !topic.isOnByDefault
            }
            return !defaults.bool(forKey: topic.rawValue)
        })
    }

    // MARK: - Scheduling

    enum ScheduleResult {
        case scheduled
        /// The system hasn't granted permission.
        case notAuthorized
        /// The user silenced this topic, or nothing sends it yet.
        case topicDisabled
        /// The requested fire time has already passed.
        case invalidTime
        case failed
    }

    /// Schedules one local notification.
    ///
    /// `id` is the notification's identifier AND its replace key: adding
    /// a request with an id that is already pending REPLACES it rather
    /// than stacking a second one. Callers re-arming a moving target
    /// (a bus ETA that drifts) rely on exactly that — pass a stable id
    /// per watched thing, not a fresh UUID.
    ///
    /// `after` is seconds from now; anything under a second is clamped up
    /// so the trigger stays valid. Interval triggers are used rather than
    /// calendar ones so a timezone change between scheduling and delivery
    /// can't shift the fire time.
    @discardableResult
    func schedule(
        id: String,
        title: String,
        body: String,
        after interval: TimeInterval,
        topic: NotificationTopic,
        route: NotificationRoute? = nil
    ) async -> ScheduleResult {
        guard isAuthorized else { return .notAuthorized }
        guard isEnabled(topic) else { return .topicDisabled }
        guard interval.isFinite, interval > 0 else { return .invalidTime }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Carried so cancelAll/pendingRequests can group by topic without
        // constraining identifier formats — EventReminders' existing
        // "event-reminder-<id>" keeps working untouched.
        content.userInfo[Self.topicKey] = topic.rawValue
        
        // Encode the tap destination so didReceive can route to the right screen.
        if let route {
            NotificationService.encode(route, into: content)
        }

        // Must match the category registered in registerCategories() exactly —
        // this is what causes the Snooze action button to appear on the notification.
        if topic == .campusEvents {
            content.categoryIdentifier = "EVENT_REMINDER"
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(interval, 1), repeats: false)

        do {
            try await center.add(
                UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return .scheduled
        } catch {
            return .failed
        }
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Cancels every pending notification belonging to one topic.
    func cancelAll(for topic: NotificationTopic) async {
        let ids = await pendingRequests()
            .filter { Self.topic(of: $0) == topic }
            .map(\.identifier)
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Everything currently scheduled — what Settings shows the user so
    /// a pending notification is something they can see and take back.
    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
    
    // Must be called before any notification is delivered — iOS needs categories
    // registered at launch so lock-screen actions are available immediately.
    private func registerCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 10 min",
            options: []
        )
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([eventCategory])
    }
    
    func snooze(request: UNNotificationRequest, by seconds: TimeInterval) async {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let newRequest = UNNotificationRequest(
            identifier: request.identifier + "-snoozed",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(newRequest)
    }

    // MARK: - Topic tagging

    private static let topicKey = "gtNotificationTopic"

    /// The topic a scheduled request belongs to, when it carries one.
    /// Requests scheduled before this tagging existed return nil.
    static func topic(of request: UNNotificationRequest) -> NotificationTopic? {
        guard let raw = request.content.userInfo[topicKey] as? String else { return nil }
        return NotificationTopic(rawValue: raw)
    }
}
// swiftlint:enable no_notification_center
