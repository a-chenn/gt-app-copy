//
//  AuthManager.swift
//  GeorgiaTechApp
//

import FirebaseAuth
import Foundation

/// Observes Firebase auth state so the root view can swap between the
/// login screen and the app. Lives for the app's lifetime.
@Observable
@MainActor
final class AuthManager {
    private(set) var user: User?
    @ObservationIgnored nonisolated(unsafe) private var listenerHandle: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool { user != nil }
    var isGuest: Bool { user?.isAnonymous ?? false }

    init() {
        user = Auth.auth().currentUser
        listenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                self.user = user
            }
        }
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    var displayName: String {
        AuthService.shared.currentUserFirstName()
    }

    func signOut() {
        do {
            try AuthService.shared.signOut()
        } catch {
#if DEBUG
            print("AuthManager: sign out failed: \(error.localizedDescription)")
#endif
        }
    }
}
