//
//  GTSearchResultRow.swift
//  GeorgiaTechApp
//

import SwiftUI

/// A search result: icon, title, a path like "Maps > Dining", and a chevron.
///
///     GTSearchResultRow(icon: "fork.knife", title: "Dining", subtitle: "Maps > Dining") { open() }
struct GTSearchResultRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.gtPrimaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.gtHeading4)
                        .foregroundStyle(Color.gtPrimaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.gtBody2)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.gtPrimaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(GTSearchResultRowStyle())
        .accessibilityLabel(spokenLabel)
    }

    // VoiceOver says ">" as "greater than", so read the path with commas.
    private var spokenLabel: String {
        guard let subtitle else { return title }
        return "\(title), " + subtitle.replacingOccurrences(of: " > ", with: ", ")
    }
}

/// Fills the row with gray while it is pressed.
private struct GTSearchResultRowStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(configuration.isPressed ? pressedColor : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var pressedColor: Color {
        colorScheme == .dark ? Color.gtWhite.opacity(0.12) : .gtOverlay1
    }
}

#Preview("Search result row") {
    VStack(spacing: 0) {
        GTSearchResultRow(icon: "fork.knife", title: "Dining", subtitle: "Maps > Dining") {}
        GTSearchResultRow(icon: "printer", title: "Printers", subtitle: "Maps > Printers") {}
    }
    .padding()
    .gtScreenBackground()
}
