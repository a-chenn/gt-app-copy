//
//  GTFilterChip.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The Gold Hive filter capsule — one component for every filter row in
/// the app (building filters, event categories, dietary filters), so a
/// selected chip looks the same wherever it appears.
///
/// Selection swaps color by appearance rather than using one fill for
/// both: navy reads as a strong selection on paper, but on a near-black
/// dark-mode background it sinks into the surface, so dark mode takes the
/// bright Buzz fill with navy text instead.
struct GTFilterChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    /// Overrides the label read out by VoiceOver ("Filter to Clough").
    var accessibilityText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.gtHeading6)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(selectedFill)
                    } else {
                        Capsule()
                            .fill((colorScheme == .dark ? Color.gtNavy : Color.gtWhite))
                            .overlay {
                                Capsule().strokeBorder(Color.gtNavy.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedFill: Color {
        colorScheme == .dark ? .gtBuzz : .gtNavy
    }

    private var foreground: Color {
        guard isSelected else { return .gtPrimaryText }
        return colorScheme == .dark ? .gtNavy : .gtWhite
    }
}
