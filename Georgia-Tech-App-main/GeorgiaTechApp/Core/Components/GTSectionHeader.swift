//
//  GTSectionHeader.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The Gold Hive section header: uppercase collegiate display type with
/// a short gold rule beside it. One component so every band on every
/// screen shares the same rhythm.
struct GTSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    /// Set when the header sits on a navy fill *inside* a light-mode
    /// screen. Dark mode is handled automatically — navy type on a
    /// dark-mode background is unreadable, so the label follows the
    /// appearance rather than being pinned to the brand color.
    var onDark = false
    /// Optional trailing control ("See All").
    var trailing: AnyView?

    init(_ title: String, onDark: Bool = false) {
        self.title = title
        self.onDark = onDark
        self.trailing = nil
    }

    init<Trailing: View>(
        _ title: String, onDark: Bool = false, @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onDark = onDark
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.gtHeading5)
                .tracking(1.6)
                .foregroundStyle(isReversed ? Color.gtWhite : Color.gtNavy)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isReversed ? Color.gtBuzz : Color.gtGold)
                .frame(width: 26, height: 3)

            Spacer(minLength: 0)

            if let trailing {
                trailing
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var isReversed: Bool { onDark || colorScheme == .dark }
}

/// The small uppercase caption used above rows and inside tiles.
struct GTMicroLabel: View {
    let text: String
    var color: Color = .gtSecondaryText

    var body: some View {
        Text(text.uppercased())
            .font(.gtHeading6)
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

extension View {
    /// Gold Hive card chrome: white (navy in dark mode), hairline navy
    /// border, soft navy shadow. Radius 20 for list cards.
    func gtCard(radius: CGFloat = 20, padding: CGFloat = 14) -> some View {
        modifier(GTCard(radius: radius, padding: padding))
    }
}

private struct GTCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let radius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.gtNavy : Color.gtWhite)
                    .shadow(color: Color.gtNavy.opacity(0.05), radius: 8, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.gtNavy.opacity(0.08), lineWidth: 1)
            }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        GTSectionHeader("Right Now")
        GTSectionHeader("Tonight") {
            Text("See All")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtDarkGold)
        }
        GTMicroLabel(text: "Next Bus")
        Text("Card").gtCard()
    }
    .padding()
    .gtScreenBackground()
}
