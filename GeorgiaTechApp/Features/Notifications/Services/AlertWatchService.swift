//
//  AlertWatchService.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData
import SwiftUI

/// Evaluates active watches against live data and schedules corresponding local notifications.
/// Watches are device-local, user-authored state persisted in AppStorage.
@Observable @MainActor final class AlertWatchService {
    static let shared = AlertWatchService()
    private let defaults = UserDefaults.standard
    
    private(set) var watches: [NotificationWatch] = []
    
    /// Held in memory to prevent rewriting identical notification requests on every 6-second poll.
    private var lastScheduledFireTimes: [String: Date] = [:]
    
    private init() {
        let raw = defaults.string(forKey: "notificationWatches") ?? ""
        watches = NotificationWatchStore.decode(raw)
    }
    
    var hasBusWatches: Bool {
        watches.contains { $0.kind == .busArrival }
    }
    
    var hasCapacityWatches: Bool {
        watches.contains { $0.kind == .buildingCapacity }
    }
    
    var hasDiningWatches: Bool {
        watches.contains { $0.kind == .diningOpen }
    }
    
    func isWatching(kind: NotificationWatch.Kind, targetID: String) -> Bool {
        watches.contains { $0.id == "\(kind.rawValue).\(targetID)" }
    }
    
    /// Adds or updates a watch, requesting permission if needed.
    func addWatch(_ watch: NotificationWatch) async -> Bool {
        let authorized = await NotificationService.shared.requestAuthorization()
        guard authorized else { return false }
        
        watches.removeAll { $0.id == watch.id }
        watches.append(watch)
        save()
        return true
    }
    
    /// Removes a watch and its pending notification, if any.
    func removeWatch(id: String) {
        watches.removeAll { $0.id == id }
        NotificationService.shared.cancel(id: id)
        lastScheduledFireTimes.removeValue(forKey: id)
        save()
    }
    
    /// Removes a watch from the active list AFTER it has fired, without cancelling the notification itself.
    private func markAsFired(id: String) {
        watches.removeAll { $0.id == id }
        lastScheduledFireTimes.removeValue(forKey: id)
        save()
    }
    
    private func save() {
        let raw = NotificationWatchStore.encode(watches)
        defaults.set(raw, forKey: "notificationWatches")
    }
    
    // MARK: - Bus Engine
    
    /// Evaluates active bus watches. Safely replaces pending requests when ETAs drift.
    func refreshBusWatches(estimates: [Int: [BusStopEstimate]], routes: [BusRoute]) async {
        guard NotificationService.shared.isEnabled(.busArrivals) else { return }
        
        // Reverse iterate to safely remove elements
        for index in watches.indices.reversed() {
            let watch = watches[index]
            guard watch.kind == .busArrival else { continue }
            
            // One-shot evaluation: if the system clock passed our target fire time, it fired.
            if let scheduled = watch.scheduledFireTime, scheduled <= Date() {
                markAsFired(id: watch.id)
                continue
            }
            
            guard let targetID = Int(watch.targetID),
                  let stop = routes.flatMap(\.stops).first(where: { $0.routeStopID == targetID }) else {
                continue
            }
            
            // To test if buses are not running, edit etas to be [300] (5 minutes)
            let etas = BusArrivals.etas(to: stop, estimates: estimates)
            if etas.isEmpty {
                // Honest "no live buses" — pull the pending notification but keep the watch
                NotificationService.shared.cancel(id: watch.id)
                lastScheduledFireTimes.removeValue(forKey: watch.id)
                watches[index].scheduledFireTime = nil
                save()
                continue
            }
            
            let leadMinutes = watch.leadMinutes ?? 5
            let leadSeconds = leadMinutes * 60
            
            /// Grace period: If we already scheduled a notification for a bus, allow it to
            /// dip up to 60s inside the lead time without being skipped. This prevents ETA
            /// jitter (e.g., jumping from 15.1m to 14.8m) from skipping to the next bus.
            let grace = (watch.scheduledFireTime != nil) ? 60 : 0
            
            guard let targetETA = etas.first(where: { $0 >= (leadSeconds - grace) }) else {
                // All current buses are too close (already past the user's requested warning time)
                // Cancel any pending notifications and wait for the NEXT bus to appear
                NotificationService.shared.cancel(id: watch.id)
                lastScheduledFireTimes.removeValue(forKey: watch.id)
                watches[index].scheduledFireTime = nil
                save()
                continue
            }
            
            let fireInSeconds = Double(targetETA - leadSeconds)
            let fireTime = Date().addingTimeInterval(fireInSeconds)
            let routeName = routes.first(where: { $0.stops.contains(where: { $0.routeStopID == targetID }) })?.name ?? "GT Bus"
            let bodyText = "Arriving in about \(leadMinutes) minute\(leadMinutes == 1 ? "" : "s")."
            
            // The ETA drifted inside the lead time — alert now, and clear the watch
            if fireInSeconds <= 0 {
                _ = await NotificationService.shared.schedule(
                    id: watch.id,
                    title: "\(routeName) — \(watch.title)",
                    body: bodyText,
                    after: 1, // Clamp to minimum interval
                    topic: .busArrivals,
                    route: .mapPlace(cardID: "busstop-\(watch.targetID)")
                )
                markAsFired(id: watch.id)
                continue
            }
            
            // Re-arm threshold: skip re-writing the request if the drift is under 30 seconds
            if let lastFire = lastScheduledFireTimes[watch.id], abs(lastFire.timeIntervalSince(fireTime)) < 30 {
                continue
            }
            
            let result = await NotificationService.shared.schedule(
                id: watch.id,
                title: "\(routeName) — \(watch.title)",
                body: bodyText,
                after: fireInSeconds,
                topic: .busArrivals,
                route: .mapPlace(cardID: "busstop-\(watch.targetID)")
            )
            
            if result == .scheduled {
                lastScheduledFireTimes[watch.id] = fireTime
                watches[index].scheduledFireTime = fireTime
                save()
            }
        }
    }
    
    // MARK: - Capacity Engine
    
    /// Evaluates capacity limits against the newest feed fetch.
    func refreshCapacityWatches(capacities: [BuildingCapacity]) async {
        guard NotificationService.shared.isEnabled(.capacityAlerts) else { return }
        
        for watch in watches where watch.kind == .buildingCapacity {
            guard let targetID = Int(watch.targetID),
                  let building = capacities.first(where: { $0.capacityID == targetID }) else { continue }

            // To test when time is not in the building's hours of operations set boolean condition to be true
            if building.isOpen, let threshold = watch.thresholdPercent, Int(building.percentage * 100) <= threshold {
                let percent = Int(building.percentage * 100)
                _ = await NotificationService.shared.schedule(
                    id: watch.id,
                    title: building.name,
                    body: "It's quieter now — about \(percent)% full.",
                    after: 1, // Send "now"
                    topic: .capacityAlerts,
                    route: .capacity(buildingID: targetID)
                )
                // One-shot: clear the watch after we fire
                markAsFired(id: watch.id)
            }
        }
    }
    
    // MARK: - Dining Digest Engine

    private static let diningDigestNotificationID = "diningUpdates.dailyDigest"
    private static let diningDigestStorageKey = "favoriteMenuDigest"

    /// Convenience overload so `RootView` can trigger dining evaluations in one line after sync.
    func refreshFavoriteMenuDigest(context: ModelContext, now: Date = Date()) async {
        let restaurants = (try? context.fetch(FetchDescriptor<Restaurant>())) ?? []
        await refreshFavoriteMenuDigest(restaurants: restaurants, now: now)
        await refreshDiningOpenWatches(restaurants: restaurants, now: now)
    }

    /// Called when the student toggles a heart on a menu item. Requests notification
    /// permission on first heart (when `.diningUpdates` is preferred) and updates the digest.
    func handleFavoriteFoodToggled(restaurants: [Restaurant], now: Date = Date()) async {
        if !FavoritesService.shared.favoriteFoodNames.isEmpty,
           NotificationService.shared.isPreferred(.diningUpdates),
           NotificationService.shared.authorizationStatus == .notDetermined {
            _ = await NotificationService.shared.requestAuthorization()
        }
        await refreshFavoriteMenuDigest(restaurants: restaurants, now: now)
    }

    /// Evaluates today's menus against hearted dishes and schedules at most one daily digest.
    ///
    /// Deduplication & mid-day hearting rule (Option A):
    /// - At most one digest notification is delivered per calendar day.
    /// - If today's digest has already fired (`now >= existing.scheduledFireTime`), any dish
    ///   hearted later in the day waits until tomorrow's digest.
    /// - If today's digest is still pending (`now < existing.scheduledFireTime`), changes to
    ///   hearted dishes replace the pending notification in-place via its stable ID.
    func refreshFavoriteMenuDigest(restaurants: [Restaurant], now: Date = Date()) async {
        await NotificationService.shared.refreshAuthorizationStatus()
        guard NotificationService.shared.isEnabled(.diningUpdates) else { return }

        let todayKey = FavoriteMenuMatches.dayKey(for: now)
        let rawState = defaults.string(forKey: Self.diningDigestStorageKey) ?? ""
        let existingState = FavoriteDigestStore.decode(rawState)

        // If today's digest already went out, do not send a second notification today.
        if let existingState,
           existingState.dayKey == todayKey,
           now >= existingState.scheduledFireTime {
            return
        }

        let matches = FavoriteMenuMatches.matches(
            in: restaurants,
            favorites: FavoritesService.shared.favoriteFoodNames,
            on: now
        )

        guard let content = FavoriteMenuMatches.digestContent(for: matches),
              let fireTime = FavoriteMenuMatches.fireDate(for: matches, now: now) else {
            // If a digest was still pending for today but all matched dishes were unhearted,
            // cancel the pending request and clear today's record.
            if let existingState, existingState.dayKey == todayKey {
                NotificationService.shared.cancel(id: Self.diningDigestNotificationID)
                defaults.removeObject(forKey: Self.diningDigestStorageKey)
            }
            return
        }

        let currentDishes = matches.map(\.normalizedDishName)

        // Relaunching with the exact same pending match set must not reschedule or drift.
        if let existingState,
           existingState.dayKey == todayKey,
           existingState.dishNames == currentDishes {
            return
        }

        let interval = max(fireTime.timeIntervalSince(now), 1)
        let result = await NotificationService.shared.schedule(
            id: Self.diningDigestNotificationID,
            title: content.title,
            body: content.body,
            after: interval,
            topic: .diningUpdates,
            route: .mapPlace(cardID: content.primaryRestaurantID)
        )

        if result == .scheduled {
            let newState = FavoriteDigestState(
                dayKey: todayKey,
                scheduledFireTime: fireTime,
                dishNames: currentDishes
            )
            defaults.set(FavoriteDigestStore.encode(newState), forKey: Self.diningDigestStorageKey)
        }
    }
    
    // MARK: - Dining Open Engine

    /// Evaluates active `.diningOpen` watches against `DiningHours` and
    /// schedules a one-shot notification for the exact upcoming opening time.
    func refreshDiningOpenWatches(
        restaurants: [Restaurant],
        now: Date = Date()
    ) async {
        guard NotificationService.shared.isEnabled(.diningUpdates) else { return }

        for index in watches.indices.reversed() {
            let watch = watches[index]
            guard watch.kind == .diningOpen else { continue }

            // One-shot cleanup: if the scheduled opening time has already passed, clear the watch.
            if let scheduled = watch.scheduledFireTime, scheduled <= now {
                markAsFired(id: watch.id)
                continue
            }

            guard let restaurant = restaurants.first(where: { $0.restaurantID == watch.targetID }) else {
                continue
            }

            // If the watch was created while the hall was closed and it is now open, fire immediately.
            if !Self.isHallOpen(restaurant.hoursOpen, at: watch.createdAt) &&
               Self.isHallOpen(restaurant.hoursOpen, at: now) {
                let statusLine = DiningHours.statusText(for: restaurant.hoursOpen)
                _ = await NotificationService.shared.schedule(
                    id: watch.id,
                    title: restaurant.name,
                    body: "Now open — \(statusLine.lowercased()).",
                    after: 1,
                    topic: .diningUpdates,
                    route: .mapPlace(cardID: restaurant.restaurantID)
                )
                markAsFired(id: watch.id)
                continue
            }

            guard let openDate = Self.nextOpeningDate(
                for: restaurant.hoursOpen,
                after: now
            ) else {
                NotificationService.shared.cancel(id: watch.id)
                lastScheduledFireTimes.removeValue(forKey: watch.id)
                watches[index].scheduledFireTime = nil
                save()
                continue
            }

            if let lastFire = lastScheduledFireTimes[watch.id],
               abs(lastFire.timeIntervalSince(openDate)) < 30 {
                continue
            }

            let interval = max(openDate.timeIntervalSince(now), 1)
            let result = await NotificationService.shared.schedule(
                id: watch.id,
                title: restaurant.name,
                body: "Now open.",
                after: interval,
                topic: .diningUpdates,
                route: .mapPlace(cardID: restaurant.restaurantID)
            )

            if result == .scheduled {
                lastScheduledFireTimes[watch.id] = openDate
                watches[index].scheduledFireTime = openDate
                save()
            }
        }
    }

    private static func isHallOpen(_ hoursOpen: [[String]]?, at now: Date) -> Bool {
        if case .open = DiningHours.status(for: hoursOpen, now: now) {
            return true
        }
        return false
    }

    /// Computes the next opening `Date` from `Restaurant.hoursOpen` by finding
    /// the next closed-to-open transition (if currently open, it first waits until
    /// the current open period ends, then finds the next opening).
    static func nextOpeningDate(
        for hoursOpen: [[String]]?,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let hoursOpen, !hoursOpen.isEmpty else { return nil }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let currentMinute = calendar.date(from: components) else { return nil }

        let maxMinutes = 7 * 24 * 60
        var offset = 15
        var hasSeenClosed = !isHallOpen(hoursOpen, at: now)

        while offset <= maxMinutes {
            guard let probe = calendar.date(byAdding: .minute, value: offset, to: currentMinute) else {
                break
            }
            let openAtProbe = isHallOpen(hoursOpen, at: probe)

            if !hasSeenClosed {
                if !openAtProbe {
                    hasSeenClosed = true
                }
            } else if openAtProbe {
                let startMinute = max(1, offset - 14)
                var prevOpen = isHallOpen(
                    hoursOpen,
                    at: calendar.date(byAdding: .minute, value: startMinute - 1, to: currentMinute) ?? currentMinute
                )
                for exactOffset in startMinute...offset {
                    guard let exactDate = calendar.date(byAdding: .minute, value: exactOffset, to: currentMinute) else {
                        continue
                    }
                    let currOpen = isHallOpen(hoursOpen, at: exactDate)
                    if !prevOpen && currOpen {
                        return exactDate
                    }
                    prevOpen = currOpen
                }
                return probe
            }
            offset += 15
        }
        return nil
    }
    
    /// Persisted record of the last scheduled favorite-dish digest for per-day deduplication.
    struct FavoriteDigestState: Codable, Equatable {
        let dayKey: String
        let scheduledFireTime: Date
        let dishNames: [String]
    }

    enum FavoriteDigestStore {
        static func decode(_ raw: String) -> FavoriteDigestState? {
            guard let data = raw.data(using: .utf8),
                  let state = try? JSONDecoder().decode(FavoriteDigestState.self, from: data) else {
                return nil
            }
            return state
        }

        static func encode(_ state: FavoriteDigestState) -> String {
            guard let data = try? JSONEncoder().encode(state),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        }
    }
}
