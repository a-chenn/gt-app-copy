import SwiftUI

/// Shared local follow control for event organizations and club design examples.
struct EventFollowButtonView: View {
    let organizationName: String

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("followedEventOrganizations") private var followedOrganizations = "[]"

    private var organizations: [String] {
        guard let data = followedOrganizations.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private var isFollowing: Bool { organizations.contains(organizationName) }

    var body: some View {
        Button {
            var updated = organizations
            if isFollowing {
                updated.removeAll { $0 == organizationName }
            } else {
                updated.append(organizationName)
            }
            if let data = try? JSONEncoder().encode(updated),
               let encoded = String(data: data, encoding: .utf8) {
                followedOrganizations = encoded
            }
        } label: {
            ZStack {
                // Reserve the longer label's width so toggling doesn't move the layout.
                Text("FOLLOWING").hidden()
                Text(isFollowing ? "FOLLOWING" : "FOLLOW")
                    .contentTransition(.identity)
            }
            .font(.gtHeading6)
            .foregroundStyle(Color.gtPrimaryText)
            .padding(.horizontal, 24)
            .frame(minWidth: 112, minHeight: 32)
            .background(colorScheme == .dark ? Color.gtNavy : Color.gtWhite, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.08)))
            .shadow(color: Color.gtOverlay1, radius: 2, y: 2)
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityLabel("\(isFollowing ? "Unfollow" : "Follow") \(organizationName)")
        .accessibilityHint("Saves your organization preference on this device.")
        .accessibilityAddTraits(isFollowing ? .isSelected : [])
    }
}
