//
//  LoginVM.swift
//  GeorgiaTechApp
//

import Foundation
import Observation

@Observable
@MainActor
final class LoginVM {
    var isSigningIn = false
    var errorMessage: String?

    func startGTSignIn() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                // Presents the system auth sheet; returns on success,
                // cancel, or failure.
                try await AuthService.shared.signInWithGTSSO()
            } catch AuthServiceError.signInCancelled {
                // User backed out — no error banner, just reset.
            } catch let error as AuthServiceError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            isSigningIn = false
        }
    }

    func signInAsGuest() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.signInAsGuest()
            } catch {
                errorMessage = "Guest sign-in failed: \(error.localizedDescription)"
            }
            isSigningIn = false
        }
    }
}
