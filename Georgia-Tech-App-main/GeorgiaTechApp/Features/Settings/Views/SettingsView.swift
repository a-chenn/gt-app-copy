//
//  SettingsView.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// Standard Settings.app-style grouped list — no profile-card header, so
/// it reads the same for guests and signed-in users (docs/DESIGN_SYSTEM.md).
struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthManager.self) private var authManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("defaultTravelMode") private var defaultTravelMode = RouteTransportMode.walking.rawValue
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    
    #if DEBUG
    @Query(sort: \Event.startDate) private var events: [Event]
    @Query(sort: \BusStop.name) private var busStops: [BusStop]
    @Query(sort: \BuildingCapacity.name) private var buildings: [BuildingCapacity]
    #endif

    var body: some View {
        List {
            accountSection
            preferencesSection
            notificationsSection
            supportSection
            privacySection
            aboutSection

            // Credit footer
            Section {
            } footer: {
                Text("Designed and Developed by iOS Club")
                    .font(.gtHeading6)
                    .italic()
                    .foregroundStyle(Color.gtSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            #if DEBUG
            Section("Debug: Notifications") {
                Button("Fire event notification (10s)") {
                    Task {
                        if let event = fetchAnyEvent() {
                            await NotificationService.shared.schedule(
                                id: "debug-event-\(UUID())",
                                title: event.title,
                                body: "Debug: event reminder",
                                after: 10,
                                topic: .campusEvents,
                                route: .event(eventID: event.eventID)
                            )
                        }
                    }
                }
                Button("Fire map notification (10s)") {
                    Task {
                        if let stop = fetchAnyBusStop() {
                            await NotificationService.shared.schedule(
                                id: "debug-map-\(UUID())",
                                title: stop.name,
                                body: "Debug: bus stop tap",
                                after: 10,
                                topic: .busArrivals,
                                route: .mapPlace(cardID: stop.toSearchCard().id)
                            )
                        }
                    }
                }
                Button("Fire capacity notification (10s)") {
                    Task {
                        if let building = fetchAnyBuilding() {
                            await NotificationService.shared.schedule(
                                id: "debug-capacity-\(UUID())",
                                title: "\(building.shortName): \(Int(building.percentage * 100))% full",
                                body: "Debug: capacity tap",
                                after: 10,
                                topic: .capacityAlerts,
                                route: .capacity(buildingID: building.capacityID)
                            )
                        }
                    }
                }
            }
            .listRowBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite))
            #endif
        }
        // The same fill .gtCard() uses, so Settings' groups read as the
        // app's cards without giving up anything List does for free.
        .listRowBackground((colorScheme == .dark ? Color.gtNavy : Color.gtWhite))
        .listSectionSpacing(18)
        .scrollContentBackground(.hidden)
        .gtScreenBackground()
        .tint(colorScheme == .dark ? Color.gtGold : Color.gtDarkGold)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await NotificationService.shared.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await NotificationService.shared.refreshAuthorizationStatus() }
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section(header: Text("Account").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
            LabeledContent("Signed in as") {
                Text(authManager.isGuest ? "Guest" : authManager.displayName)
                    .foregroundStyle(Color.gtSecondaryText)
            }

            Button(
                authManager.isGuest ? "Sign in with GT Account" : "Sign Out",
                role: authManager.isGuest ? nil : .destructive
            ) {
                // Either way, signing out returns to the login screen,
                // where the GT SSO flow lives.
                authManager.signOut()
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
            Picker("Default travel mode", selection: $defaultTravelMode) {
                ForEach(RouteTransportMode.allCases, id: \.rawValue) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                }
            }

            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
        } header: {
            Text("Preferences")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
        } footer: {
            Text("New routes start with this mode when it's available for the trip.")
                .font(.gtBody3)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            if NotificationService.shared.authorizationStatus == .notDetermined {
                Text("Stay on top of campus and get notified before events, buses, and building capacity changes.")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
                Button("Turn On Notifications") {
                    Task { await NotificationService.shared.requestAuthorization() }
                }
                .accessibilityLabel("Turn on notifications")
            }
            ForEach(NotificationTopic.allCases.filter { $0.isAvailable }, id: \.self) { topic in
                Toggle(isOn: Binding(
                    get: { NotificationService.shared.isPreferred(topic) },
                    set: { NotificationService.shared.setEnabled($0, for: topic) }
                )) {
                    Text(topic.title)
                        .font(.gtBody1)
                }
                .disabled(!NotificationService.shared.isAuthorized)
                .accessibilityLabel(topic.title)
                .accessibilityHint(topic.subtitle)
            }
            Button("Notification Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
            .accessibilityLabel("Open Notification Settings in iOS Settings")
        } header: {
            Text("Notifications")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
        } footer: {
            if NotificationService.shared.authorizationStatus == .denied {
                Text("Enable notifications in iOS Settings to manage these.")
                    .font(.gtBody3)
            }
        }
    }
    
    // MARK: - Privacy

    private var privacySection: some View {
        Section(header: Text("Privacy").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
            Button("Location Permissions") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }

            ExternalLinkButton(url: URL(string: "https://www.gatech.edu/privacy")) {
                Text("Privacy Policy")
            }

            ExternalLinkButton(url: URL(string: "https://www.gatech.edu/legal")) {
                Text("Terms of Service")
            }
        }
    }

    // MARK: - Support (hidden until a report destination is configured)

    @ViewBuilder
    private var supportSection: some View {
        if ReportIssue.isConfigured {
            Section(header: Text("Support").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
                supportRow("Send Feedback", subject: "GT App feedback")
                supportRow("Report Incorrect Information", subject: "GT App incorrect information")
                supportRow("Report a Bug", subject: "GT App bug report")
                supportRow("Feature Request", subject: "GT App feature request")
            }
        }
    }

    private func supportRow(_ title: String, subject: String) -> some View {
        ExternalLinkButton(url: ReportIssue.supportMailURL(subject: subject)) {
            Text(title)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(header: Text("About").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
            LabeledContent("Version", value: appVersion)

            // Roboto's OFL and Roboto Slab's Apache license both require
            // the notice to ship with the app, not just the repo.
            NavigationLink("Font Licenses") {
                FontLicensesView()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    #if DEBUG
    private func fetchAnyEvent() -> Event? {
        events.first { $0.startDate > Date() }
    }

    private func fetchAnyBusStop() -> BusStop? {
        busStops.first
    }

    private func fetchAnyBuilding() -> BuildingCapacity? {
        buildings.first { $0.isOpen } ?? buildings.first
    }
    #endif
}
