//
//  CapacityAlertButton.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Button shown on moderate/busy building cards to monitor for a quiet drop.
struct CapacityAlertButton: View {
    let building: BuildingCapacity
    @State private var hint: String?
    
    var watchID: String { "buildingCapacity.\(building.capacityID)" }
    var isWatching: Bool { AlertWatchService.shared.isWatching(kind: .buildingCapacity, targetID: "\(building.capacityID)") }
    
    var isUnavailable: Bool {
        let status = NotificationService.shared.authorizationStatus
        let preferred = NotificationService.shared.isPreferred(.capacityAlerts)
        return (status != .notDetermined && !NotificationService.shared.isAuthorized) || !preferred
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    if isUnavailable {
                        hint = "Notifications are disabled in Settings."
                        return
                    }
                    if isWatching {
                        AlertWatchService.shared.removeWatch(id: watchID)
                        hint = nil
                    } else {
                        let watch = NotificationWatch(
                            id: watchID, kind: .buildingCapacity, targetID: "\(building.capacityID)",
                            title: building.name, createdAt: Date(), thresholdPercent: 33
                        )
                        let success = await AlertWatchService.shared.addWatch(watch)
                        if !success {
                            hint = "Enable notifications in Settings to get alerts."
                        } else {
                            hint = nil
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isWatching ? "bell.fill" : "bell")
                    Text(isWatching ? "Watching" : "Tell me when it's quiet")
                }
                .font(.gtHeading5)
                .foregroundStyle(isWatching ? Color.gtNavy : Color.gtPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isWatching {
                        Capsule().fill(Color.gtGold)
                    } else {
                        Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUnavailable)
            .opacity(isUnavailable ? 0.5 : 1.0)
            .accessibilityLabel(isWatching ? "Stop watching \(building.name)" : "Alert me when \(building.name) is quiet")
            
            if isUnavailable || hint != nil {
                Text(hint ?? "Notifications are disabled in Settings.")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            } else if isWatching {
                Text("We'll let you know when it drops below 33% full.")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            }
        }
    }
}
