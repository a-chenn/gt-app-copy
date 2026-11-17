//
//  AppShellView.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI
import WidgetKit

/// The app's top-level tab. Home lands first by design — the map is one
/// tap away and Events & News completes the trio; everything else pushes
/// from Home (Settings, Capacities) or from within a tab.
enum AppTab: Hashable {
    case home
    case map
    case events
}

/// The signed-in shell: a three-tab TabView that owns the app-shared live
/// managers. LocationManager and BusLiveManager live HERE (not inside the
/// map) because the home screen's Next Bus card needs the same location
/// fix and the same TransLoc poller — see BusDataInterest for how the two
/// surfaces share one polling loop.
struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var locationManager = LocationManager()
    @State private var busLiveManager = BusLiveManager()
    @State private var selectedTab: AppTab = .home
    /// Set by Home's Next Bus card, consumed by MapView after the switch.
    @State private var pendingMapStop: SearchCardModel?
    /// Incremented by a dining widget tap; passed to MapView → MapSheetView to activate the dining category.
    @State private var diningActivationToken = 0
    /// Set by a capacity notification tap; consumed by HomeView to push CapacitiesView filtered to that building.
    @State private var pendingCapacityID: Int?
    /// Set by an event notification tap; consumed by EventsView to open that event's detail.
    @State private var eventsEventToOpen: Event?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Not displayed — only here so its .onChange fires when sync populates SwiftData,
    /// letting a cold-launch event route retry once data is available.
    @Query(sort: \Event.startDate) private var watchEvents: [Event]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        pendingCapacityID: $pendingCapacityID,
                        onOpenMapPlace: { card in
                            pendingMapStop = card
                            selectedTab = .map
                        },
                        onOpenEvents: { selectedTab = .events },
                        onOpenDining: { selectedTab = .map }
                    )
                }
            }

            Tab("Map", systemImage: "map", value: AppTab.map) {
                NavigationStack {
                    MapView(
                        locationManager: locationManager,
                        busLiveManager: busLiveManager,
                        pendingStop: $pendingMapStop,
                        diningActivationToken: diningActivationToken
                    )
                }
            }

            Tab("Events", systemImage: "calendar", value: AppTab.events) {
                NavigationStack {
                    EventsView(
                        initialEvent: eventsEventToOpen,
                        onOpenHome: { selectedTab = .home }
                    )
                }
            }
        }
        // The system bar, not a hand-built one: Liquid Glass and correct
        // safe-area insets for free. It does NOT collapse to a single
        // button on scroll — a tab bar that shrinks away costs more than
        // the content it uncovers. On the Map tab it sits on top of the
        // map's in-tab bottom sheet (MapBottomSheet).
        .tabBarMinimizeBehavior(.never)
        .environment(locationManager)
        .environment(busLiveManager)
        // GT structure color for the shell: navy selection in light,
        // gold in dark — trait-resolved so forced appearance can't
        // desync it (#R-10).
        .tint(colorScheme == .dark ? Color.gtGold : Color.gtNavy)
        .onOpenURL { url in
            guard url.scheme == "gtapp" else { return }
            if url.host == "capacities" {
                selectedTab = .home
                if let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value,
                   let id = Int(idString) {
                    pendingCapacityID = id
                }
            } else if url.host == "dining" {
                selectedTab = .map
                diningActivationToken += 1
            } else if url.host == "event" {
                // Today on Campus widget. Reuses the notification route, so a tap
                // that lands before events have synced retries the same way.
                if let eventID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value, !eventID.isEmpty {
                    NotificationService.shared.pendingRoute = .event(eventID: eventID)
                } else {
                    selectedTab = .events
                }
            } else if url.host == "busstop" {
                if let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value {
                    pendingMapStop = fetchSearchCard(cardID: "busstop-\(idString)")
                }
                selectedTab = .map
            }
        }
        // Primary: fires when a notification is tapped (or when AppShellView first mounts
        // and pendingRoute is already set from a cold-launch tap).
        .onChange(of: NotificationService.shared.pendingRoute, initial: true) { _, route in
            guard let route else { return }
            if handleRoute(route) {
                NotificationService.shared.pendingRoute = nil
            }
            // If handleRoute returns false, data wasn't ready — pendingRoute stays set
            // so the watchEvents .onChange below can retry once sync completes.
        }
        // Retry: fires whenever SwiftData's event list changes (i.e., sync just populated it).
        // Resolves a pending event route that arrived before data was loaded.
        .onChange(of: watchEvents) { _, _ in
            guard case .event(let eventID) = NotificationService.shared.pendingRoute,
                  let event = fetchEvent(id: eventID)
            else { return }
            eventsEventToOpen = event
            NotificationService.shared.pendingRoute = nil
        }
        // Reload dining widget when the app comes to foreground so a stuck error state clears
        // immediately rather than waiting for the automatic 15-minute retry.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: "GTDiningWidget")
        }
    }

    /// Returns true when the route was fully resolved — caller clears pendingRoute.
    /// Returns false when data wasn't in SwiftData yet — pendingRoute stays set for
    /// the watchEvents retry above. A 30-second safety-net Task clears it if sync
    /// never completes, so a network failure can't leave a route hanging forever.
    @discardableResult
    private func handleRoute(_ route: NotificationRoute) -> Bool {
        switch route {
        case .event(let eventID):
            selectedTab = .events
            if let event = fetchEvent(id: eventID) {
                eventsEventToOpen = event
                return true
            }
            // Event not in SwiftData yet — watchEvents .onChange will retry.
            Task {
                try? await Task.sleep(for: .seconds(30))
                if case .event(let id) = NotificationService.shared.pendingRoute, id == eventID {
                    NotificationService.shared.pendingRoute = nil
                }
            }
            return false

        case .mapPlace(let cardID):
            pendingMapStop = fetchSearchCard(cardID: cardID)
            selectedTab = .map
            return true

        case .capacity(let buildingID):
            // Only push CapacitiesView if the building is in SwiftData;
            // nil pendingCapacityID → HomeView's .onChange guard skips → just opens Home tab.
            if fetchBuilding(id: buildingID) != nil {
                pendingCapacityID = buildingID
            }
            selectedTab = .home
            return true
        }
    }

    private func fetchEvent(id: String) -> Event? {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.eventID == id })
        return try? modelContext.fetch(descriptor).first
    }

    /// cardID format is "busstop-<routeStopID>" (Int). Looks up the BusStop from
    /// SwiftData and converts it — returns nil if the stop no longer exists, which
    /// opens the Map tab with nothing selected (correct per acceptance criteria).
    private func fetchSearchCard(cardID: String) -> SearchCardModel? {
        guard cardID.hasPrefix("busstop-"),
              let part = cardID.split(separator: "-").last,
              let id = Int(part)
        else { return nil }
        let descriptor = FetchDescriptor<BusStop>(predicate: #Predicate { $0.routeStopID == id })
        return try? modelContext.fetch(descriptor).first?.toSearchCard()
    }

    private func fetchBuilding(id: Int) -> BuildingCapacity? {
        let descriptor = FetchDescriptor<BuildingCapacity>(predicate: #Predicate { $0.capacityID == id })
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    AppShellView()
}
