//
//  GeorgiaTechAppApp.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 1/29/26.
//

import Firebase
import FirebaseAuth
import SwiftData
import SwiftUI
import UserNotifications

@main struct GeorgiaTechApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    private var sharedModelContainer: ModelContainer {
        let schema = Schema([
            Appliance.self, Metadata.self, Restaurant.self, RestaurantMenu.self,
            MenuDay.self,
            MenuItem.self, Food.self, BuildingCapacity.self, CampusLocation.self,
            BusRoute.self,
            BusStop.self, Event.self, DietaryFilter.self,
            RecentSearch.self, FavoritePlace.self, FavoriteFood.self, NewsArticle.self,
            GTDate.self
        ])
        
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }
    
    var body: some Scene { WindowGroup { RootView() }.modelContainer(sharedModelContainer) }
}

// swiftlint:disable no_notification_center
// That rule bans Foundation's notification bus for state sharing.
// UNUserNotificationCenter is a different API — local user notifications —
// which is the only way to deliver foreground banners on iOS.

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()
        // Nav titles / tab labels / segmented controls are UIKit-drawn;
        // without this they stay San Francisco (#F7).
        GTAppearance.configure()

#if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#endif
        // Must be set before return so iOS can deliver notifications that
        // arrive during launch — setting it later risks missing them.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear the badge the moment the user opens the app — GT notifications
        // aren't an inbox, so a lingering count would just be misleading.
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    // swiftlint:disable no_completion_handlers
    // UNUserNotificationCenterDelegate requires completion handlers — these are
    // Apple's protocol signatures and cannot be converted to async/await.

    // Without this method, iOS suppresses banners while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request

        if response.actionIdentifier == "SNOOZE" {
            Task {
                await NotificationService.shared.snooze(request: request, by: 10 * 60)
            }
            completionHandler()
            return
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            let route = NotificationService.route(of: request)
            Task { @MainActor in
                NotificationService.shared.pendingRoute = route
            }
        }

        completionHandler()
    }
    // swiftlint:enable no_completion_handlers
}
// swiftlint:enable no_notification_center
