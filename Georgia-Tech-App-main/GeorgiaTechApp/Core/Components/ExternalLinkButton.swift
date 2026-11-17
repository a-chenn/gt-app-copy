//
//  ExternalLinkButton.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The one way the app leaves itself (#R4-11): every web/mail exit goes
/// through this button, which asks before opening. Callers style it from
/// outside (`.buttonStyle` propagates to the inner Button).
struct ExternalLinkButton<Label: View>: View {
    let url: URL?
    @ViewBuilder var label: () -> Label

    @Environment(\.openURL) private var openURL
    @State private var isConfirming = false

    private var isMail: Bool {
        url?.scheme?.lowercased() == "mailto"
    }

    private var isPhone: Bool {
        url?.scheme?.lowercased() == "tel"
    }

    private var destinationName: String {
        if isMail { return "Mail" }
        if isPhone { return "Phone" }
        return url?.host()?.replacingOccurrences(of: "www.", with: "") ?? "your browser"
    }

    private var confirmMessage: String {
        if isMail { return "This leaves the app and opens Mail." }
        if isPhone { return "This starts a phone call." }
        return "This leaves the app and opens \(destinationName)."
    }

    var body: some View {
        Button {
            guard url != nil else { return }
            isConfirming = true
        } label: {
            label()
        }
        .alert(
            isPhone ? "Place this call?" : "Open \(destinationName)?",
            isPresented: $isConfirming
        ) {
            Button(isPhone ? "Call" : "Open") {
                if let url {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }
}
