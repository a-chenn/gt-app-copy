import SwiftUI

struct EventOrganizationView: View {
    let name: String
    var imageName: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            organizationLink
                .frame(maxWidth: .infinity, alignment: .leading)
            EventFollowButtonView(organizationName: name)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var organizationLink: some View {
        NavigationLink {
            ClubDetailExampleView()
        } label: {
            organizationLabel
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(name) club page")
        .accessibilityHint("Shows club details and upcoming events.")
    }

    private var organizationLabel: some View {
        HStack(spacing: 10) {
            Group {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "person.2.circle")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(Circle())
            .accessibilityHidden(true)

            Text(name)
                .font(.gtBody1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.gtPrimaryText)
    }
}

// #Preview {
//    EventOrganizationView(
//        name: "Arab Student Association",
//        imageName: "EventOrganizationLogo"
//    )
//    .padding()
//    .gtScreenBackground()
// }
