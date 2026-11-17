//
//  GTSearchBar.swift
//  GeorgiaTechApp
//

import SwiftUI

/// A search field. Gray at rest; white with an X and a search button when focused.
///
///     GTSearchBar(text: $query, onSubmit: { runSearch() })
struct GTSearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    @Binding var text: String
    var prompt = "Search"
    var onSubmit: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            if isFocused {
                cancelButton
            }
            field
        }
        .animation(.snappy, value: isFocused)
    }

    private var cancelButton: some View {
        Button {
            text = ""
            isFocused = false
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18))
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Cancel search")
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var field: some View {
        HStack(spacing: 8) {
            if !isFocused {
                magnifier
            }

            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Color.gtSecondaryText))
                .font(.gtBody1)
                .foregroundStyle(Color.gtPrimaryText)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)

            if isFocused {
                Button(action: onSubmit) {
                    magnifier.frame(width: 44, height: 44)
                }
                .accessibilityLabel("Search")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, isFocused ? 4 : 16)
        .frame(minHeight: 50)
        .background {
            Capsule()
                .fill(fillColor)
                .shadow(color: isFocused ? Color.gtOverlay1 : Color.clear, radius: 6, y: 2)
        }
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }

    private var magnifier: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 18))
            .foregroundStyle(isFocused ? Color.gtPrimaryText : Color.gtSecondaryText)
    }

    private var fillColor: Color {
        let isDark = colorScheme == .dark
        if isFocused { return isDark ? .gtNavy : .gtWhite }
        return isDark ? Color.gtWhite.opacity(0.12) : .gtOverlay1
    }
}

#Preview("Search bar") {
    @Previewable @State var text = ""
    VStack(spacing: 20) {
        GTSearchBar(text: $text)
    }
    .padding()
    .gtScreenBackground()
}
