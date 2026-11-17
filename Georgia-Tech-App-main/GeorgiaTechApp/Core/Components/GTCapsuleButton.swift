//
//  GTCapsuleButton.swift
//  GeorgiaTechApp
//

import SwiftUI

enum GTCapsuleStyle {
    case standard   // white
    case selected   // navy
    case highlight  // gold
}

/// A capsule button with a title, an icon, or both. An icon on its own makes a circle.
///
///     GTCapsuleButton("Done", icon: "checkmark") { save() }
///     GTCapsuleButton(icon: "heart.fill", label: "Favorites", iconColor: .gtAzalea) { toggle() }
struct GTCapsuleButton: View {
    @Environment(\.controlSize) private var controlSize
    let title: String?
    let icon: String?
    let trailingIcon: String?
    let style: GTCapsuleStyle
    let iconColor: Color?
    let label: String
    /// Stretches the capsule across its container (Figma "View All").
    var isFullWidth = false
    let action: () -> Void

    /// A button with a title.
    init(
        _ title: String, icon: String? = nil, trailingIcon: String? = nil,
        style: GTCapsuleStyle = .standard, isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isFullWidth = isFullWidth
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.style = style
        self.iconColor = nil
        self.label = title
        self.action = action
    }

    /// A circle button with just an icon. `label` is what VoiceOver reads.
    /// `iconColor` only applies in the `.standard` style.
    init(icon: String, label: String, style: GTCapsuleStyle = .standard, iconColor: Color? = nil, action: @escaping () -> Void) {
        self.title = nil
        self.icon = icon
        self.trailingIcon = nil
        self.style = style
        self.iconColor = iconColor
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { iconView(icon) }
                if let title {
                    Text(title)
                        .font(controlSize.isCompact ? .gtHeading5 : .gtHeading4)
                        .lineLimit(1)
                }
                if let trailingIcon { iconView(trailingIcon) }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
        }
        .buttonStyle(GTCapsuleButtonStyle(style: style))
        .accessibilityLabel(label)
        .accessibilityAddTraits(style == .selected ? .isSelected : [])
    }

    private var iconSize: CGFloat {
        switch (controlSize.isCompact, title == nil) {
        case (true, true): 16
        case (true, false): 14
        case (false, true): 22
        case (false, false): 18
        }
    }

    @ViewBuilder
    private func iconView(_ name: String) -> some View {
        let image = Image(systemName: name)
            .font(.system(size: iconSize))
        if let iconColor, style == .standard {
            image.foregroundStyle(iconColor)
        } else {
            image
        }
    }
}

/// The capsule look shared by `GTCapsuleButton` and `GTCategoryChip`.
/// `.controlSize(.small)` gives the compact map-rail size from the
/// Figma "Button Row" (36pt); the default stays the 50pt board size.
struct GTCapsuleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlSize) private var controlSize
    let style: GTCapsuleStyle

    func makeBody(configuration: Configuration) -> some View {
        let side: CGFloat = controlSize.isCompact ? 36 : 50
        return configuration.label
            .foregroundStyle(textColor)
            .padding(.horizontal, controlSize.isCompact ? 12 : 14)
            .frame(minWidth: side, minHeight: side)
            .background {
                Capsule()
                    .fill(fillColor)
                    .shadow(color: style == .standard ? Color.gtOverlay2 : Color.clear, radius: 4, y: 1)
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var isDark: Bool { colorScheme == .dark }

    // Dark mode: navy would vanish on black, so selected uses Buzz instead.
    private var fillColor: Color {
        switch style {
        case .standard: isDark ? .gtMediumNavy : .gtWhite
        case .selected: isDark ? .gtGold : .gtNavy
        case .highlight: .gtGold
        }
    }

    // Gold gets navy text because white on gold is too low contrast to read.
    private var textColor: Color {
        switch style {
        case .standard: .gtPrimaryText
        case .selected: isDark ? .gtNavy : .gtWhite
        case .highlight: .gtNavy
        }
    }
}

extension ControlSize {
    /// `.small` and `.mini` both mean the compact rail size.
    var isCompact: Bool { self == .small || self == .mini }
}

#Preview("Capsule buttons") {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            GTCapsuleButton(icon: "checkmark", label: "Done") {}
            GTCapsuleButton(icon: "checkmark", label: "Done", style: .selected) {}
            GTCapsuleButton(icon: "checkmark", label: "Done", style: .highlight) {}
        }
        GTCapsuleButton("Text", icon: "checkmark", trailingIcon: "checkmark") {}
        GTCapsuleButton("Text", icon: "checkmark", trailingIcon: "checkmark", style: .selected) {}
        GTCapsuleButton("Text", icon: "checkmark", trailingIcon: "checkmark", style: .highlight) {}
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .gtScreenBackground()
}
