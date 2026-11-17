//
//  DiningOpenAlertChip.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Quick-action chip shown on dining hall detail cards to alert when the hall next opens.
struct DiningOpenAlertChip: View {
    let restaurant: Restaurant

    var watchID: String { "diningOpen.\(restaurant.restaurantID)" }

    var isWatching: Bool {
        AlertWatchService.shared.isWatching(kind: .diningOpen, targetID: restaurant.restaurantID)
    }

    var isNotificationsOff: Bool {
        let status = NotificationService.shared.authorizationStatus
        let preferred = NotificationService.shared.isPreferred(.diningUpdates)
        return (status != .notDetermined && !NotificationService.shared.isAuthorized) || !preferred
    }

    private var hasUpcomingOpening: Bool {
        AlertWatchService.nextOpeningDate(for: restaurant.hoursOpen) != nil
    }

    private var isDisabled: Bool {
        isNotificationsOff || (!hasUpcomingOpening && !isWatching)
    }

    var body: some View {
        Button {
            Task {
                guard !isDisabled else { return }
                if isWatching {
                    AlertWatchService.shared.removeWatch(id: watchID)
                } else {
                    let watch = NotificationWatch(
                        id: watchID,
                        kind: .diningOpen,
                        targetID: restaurant.restaurantID,
                        title: restaurant.name,
                        createdAt: Date()
                    )
                    let added = await AlertWatchService.shared.addWatch(watch)
                    if added {
                        await AlertWatchService.shared.refreshDiningOpenWatches(
                            restaurants: [restaurant]
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isWatching ? "bell.fill" : "bell")
                Text(chipTitle)
            }
            .font(.gtHeading5)
            .foregroundStyle(isWatching ? Color.gtNavy : Color.gtPrimaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isWatching {
                    Capsule().fill(Color.gtGold)
                } else {
                    Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel(
            isWatching
                ? "Cancel opening alert for \(restaurant.name)"
                : "Notify me when \(restaurant.name) opens"
        )
        .accessibilityHint(
            isNotificationsOff
                ? "Dining notifications are turned off in Settings"
                : (isWatching
                    ? "Stops the one-time notification when this dining hall opens"
                    : "Sends a one-time notification at \(restaurant.name)'s next opening time")
        )
        .accessibilityAddTraits(isWatching ? .isSelected : [])
    }

    private var chipTitle: String {
        if isNotificationsOff {
            return "Alerts Off"
        }
        return isWatching ? "Alerting at Open" : "Notify When Open"
    }
}
