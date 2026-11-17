import SwiftUI

/// Shared date/location card used by the event detail screen.
struct EventInfoCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    let subtitle: String
    var usesClubShadow = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.gtHeading2)
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.gtHeading6)
                    .foregroundStyle((colorScheme == .dark ? Color.gtWhite : Color.gtNavy))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.gtBody2)
                        .foregroundStyle(Color.gtPrimaryText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        // Card styling adds another 14 points on each side, for 26 points total.
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .modifier(EventInfoCardStyle(usesClubShadow: usesClubShadow))
        .accessibilityElement(children: .combine)
    }
}

/// Keeps the club example's custom shadow local to event info cards.
private struct EventInfoCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let usesClubShadow: Bool

    func body(content: Content) -> some View {
        if usesClubShadow {
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.gtNavy : Color.gtWhite)
                        .shadow(color: Color.gtOverlay1, radius: 6.8, x: 0, y: 2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.gtNavy.opacity(0.08), lineWidth: 1)
                }
        } else {
            content.gtCard(radius: 20, padding: 14)
        }
    }
}
