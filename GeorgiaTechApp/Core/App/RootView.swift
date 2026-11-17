//
//  RootView.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthManager()
    @State private var dataService = DataService()
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if authManager.isSignedIn {
                if hasSeenOnboarding {
                    AppShellView()
                        .task {
                            RecentsService.shared.configure(context: modelContext)
                            FavoritesService.shared.configure(context: modelContext)
                            await dataService.sync(context: modelContext)
                        }
                } else {
                    OnboardingView { hasSeenOnboarding = true }
                }
            } else {
                LoginView()
            }
        }
        // Default for any Text/Label that never sets one explicitly —
        // otherwise SwiftUI falls back to San Francisco (#F7).
        .font(.gtBody1)
        .environment(authManager)
        .animation(.easeInOut(duration: 0.3), value: authManager.isSignedIn)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
}

/// The user's app-wide appearance choice (Settings → Appearance).
enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
