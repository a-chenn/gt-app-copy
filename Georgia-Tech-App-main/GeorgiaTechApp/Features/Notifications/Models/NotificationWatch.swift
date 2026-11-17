//
//  NotificationWatch.swift
//  GeorgiaTechApp
//

import Foundation

/// A user-authored watch waiting for a specific condition.
/// Unified model for bus arrivals, building capacities, and dining hall openings.
struct NotificationWatch: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case busArrival, buildingCapacity, diningOpen }
    
    let id: String          // "<kind>.<targetID>" — also the notification identifier
    let kind: Kind
    let targetID: String    // routeStopID for a stop, capacityID for a building, restaurantID for dining
    let title: String       // stop name, building name, or dining hall name
    let createdAt: Date
    
    var leadMinutes: Int?      // busArrival: alert this many minutes before arrival
    var thresholdPercent: Int? // buildingCapacity: alert when occupancy drops below this
    
    /// Tracks when the notification is actually expected to trigger.
    /// Used by the one-shot engine to identify when a watch has effectively fired
    /// and should be removed from the active list.
    var scheduledFireTime: Date?
}

enum NotificationWatchStore {
    static func decode(_ raw: String) -> [NotificationWatch] {
        guard let data = raw.data(using: .utf8),
              let watches = try? JSONDecoder().decode([NotificationWatch].self, from: data) else {
            return []
        }
        return watches
    }
    
    static func encode(_ watches: [NotificationWatch]) -> String {
        guard let data = try? JSONEncoder().encode(watches),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}
