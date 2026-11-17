//
//  AuthService.swift
//  GeorgiaTechApp
//

import AuthenticationServices
import FirebaseAuth
import SwiftUI

enum AuthServiceError: LocalizedError {
    case invalidCallbackURL
    case invalidAuthorizationURL
    case invalidVerifyURL
    case invalidHTTPResponse
    case signInCancelled
    case stateMismatch
    case codeVerificationFailed
    case firebaseTokenParseFailed
    case backendError

    var errorDescription: String? {
        switch self {
        case .invalidCallbackURL: return "Invalid callback URL."
        case .invalidAuthorizationURL: return "Failed to construct SSO URL."
        case .invalidVerifyURL: return "Invalid verify URL."
        case .invalidHTTPResponse:
            return "Authentication server returned an invalid response."
        case .signInCancelled: return "Sign in was cancelled."
        case .stateMismatch: return "Sign in could not be verified. Please try again."
        case .codeVerificationFailed: return "Failed to verify GT sign-in."
        case .firebaseTokenParseFailed: return "Failed to parse authentication token."
        case .backendError: return "Authentication server returned an error."
        }
    }
}

/// GT SSO via `ASWebAuthenticationSession` — the RFC 8252 recommendation
/// for native apps: credential entry happens in the isolated system
/// browser (the app never sees the password), and the callback is bound
/// to the session so a forged deep link can't inject an auth code. The
/// OIDC code exchange itself is server-side (the client only forwards the
/// authorization code), so no SSO client secret is bundled in the app.
@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()
    private override init() {}

    private let clientID = "8b5b8452-c01c-4e6c-8b3d-63ed12979168"
    /// The scheme the backend callback redirects to; the auth session
    /// completes when the browser reaches it.
    private let callbackScheme = "gtapp"

    /// Retained for the lifetime of an in-flight authentication.
    private var webAuthSession: ASWebAuthenticationSession?

    // MARK: - Sign in

    func signInWithGTSSO() async throws {
        // A random state ties this request to its callback (CSRF /
        // auth-code-injection defense).
        let state = UUID().uuidString
        let authURL = try makeGTSsoAuthorizationURL(state: state)

        let callbackURL = try await authenticate(url: authURL)

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard items?.first(where: { $0.name == "state" })?.value == state else {
            throw AuthServiceError.stateMismatch
        }
        guard let code = items?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthServiceError.signInCancelled
        }

        // Server-side code exchange → Firebase custom token → sign in.
        let firebaseToken = try await verifyCode(code)
        _ = try await Auth.auth().signIn(withCustomToken: firebaseToken)
#if DEBUG
        print("AuthService: GT SSO sign-in succeeded.")
#endif
    }

    func signInAsGuest() async throws {
        _ = try await Auth.auth().signInAnonymously()
#if DEBUG
        print("AuthService: anonymous sign-in succeeded.")
#endif
    }

    func signOut() throws { try Auth.auth().signOut() }

    // MARK: - Web auth session

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: AuthServiceError.signInCancelled)
                } else {
                    continuation.resume(throwing: error ?? AuthServiceError.codeVerificationFailed)
                }
            }
            session.presentationContextProvider = self
            // Fresh session each time — matches the old non-persistent web
            // view and keeps GT credentials out of a shared cookie jar.
            session.prefersEphemeralWebBrowserSession = true
            self.webAuthSession = session
            if !session.start() {
                continuation.resume(throwing: AuthServiceError.invalidAuthorizationURL)
            }
        }
    }

    private func makeGTSsoAuthorizationURL(state: String) throws -> URL {
        let redirectURI = try callbackURL().absoluteString
        var components = URLComponents(
            string: "https://sso-upgrade.a.iam.gatech.edu/cas/oidc/oidcAuthorize")
        components?.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "state", value: state)
        ]
        guard let url = components?.url else {
            throw AuthServiceError.invalidAuthorizationURL
        }
        return url
    }

    private func callbackURL() throws -> URL {
        do { return try APIUtility.url(for: "auth/gt/callback") } catch {
            throw AuthServiceError.invalidCallbackURL
        }
    }

    // MARK: - Backend verification

    private func verifyCode(_ code: String) async throws -> String {
        guard let verifyURL = try? APIUtility.url(for: "auth/gt/verify/") else {
            throw AuthServiceError.invalidVerifyURL
        }

        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = [
            "code": code,
            "redirect_uri": try callbackURL().absoluteString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try response.validate(orThrow: AuthServiceError.codeVerificationFailed)

        guard
            let verifyJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AuthServiceError.firebaseTokenParseFailed
        }

        if let firebaseToken = verifyJSON["firebase_token"] as? String {
            return firebaseToken
        }
        if let fallbackToken = verifyJSON["token"] as? String { return fallbackToken }
        if verifyJSON["error"] is String { throw AuthServiceError.backendError }
        if verifyJSON["detail"] is String { throw AuthServiceError.backendError }
        throw AuthServiceError.firebaseTokenParseFailed
    }

    // MARK: - Display name

    func currentUserFirstName(defaultName: String = "George") -> String {
        if let displayName = Auth.auth().currentUser?.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName.split(separator: " ").first.map(String.init) ?? defaultName
        }

        let guestName = UserDefaults.standard.string(forKey: "userName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !guestName.isEmpty {
            return guestName.split(separator: " ").first.map(String.init) ?? guestName
        }

        return defaultName
    }
}

// MARK: - Presentation anchor (system browser sheet)

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            // Sign-in is user-initiated from a foreground scene, so one
            // always exists by the time the system asks for an anchor.
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
                ?? scenes.first else {
                preconditionFailure("No window scene available to present GT sign-in")
            }
            return scene.keyWindow ?? UIWindow(windowScene: scene)
        }
    }
}
