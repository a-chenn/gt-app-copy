//
//  NotificationRoute.swift
//  GeorgiaTechApp
//

/// The destination a notification tap should open.
///
/// Senders encode a route into `userInfo` via `NotificationService.encode(_:into:)`.
/// Each case maps to one navigation destination in AppShellView:
///
/// - `.event(eventID:)`      → Events tab, that event open
/// - `.mapPlace(cardID:)`    → Map tab, pendingMapStop set (cardID format: "busstop-<routeStopID>")
/// - `.capacity(buildingID:)` → Home tab, CapacitiesView(initialFilterID:) pushed
///
/// A notification with no route (or an unrecognized route) simply opens the app.
enum NotificationRoute: Codable, Equatable {
    case event(eventID: String)
    case mapPlace(cardID: String)
    case capacity(buildingID: Int)
}
