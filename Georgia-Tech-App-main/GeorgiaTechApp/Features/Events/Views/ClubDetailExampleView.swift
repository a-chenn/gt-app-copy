import SwiftUI

struct ClubDetailExampleView: View {
    var organizationName: String?
    var logoImageName: String? = "IOSClubLogo"
    var instagramURL: URL?
    var websiteURL: URL?
    var emailURL: URL?
    var upcomingEvents: [Event] = ClubDetailSample.upcomingEvents
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    clubHeading
                    socialLinks

                    if organizationName == nil {
                        Text(ClubDetailSample.description)
                            .font(.gtBody2)
                            .foregroundStyle(Color.gtPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        VStack(spacing: 10) {
                            EventInfoCard(systemImage: "person", title: "Target Audience",
                                          subtitle: ClubDetailSample.audience, usesClubShadow: true)
                            EventInfoCard(systemImage: "banknote", title: "Dues",
                                          subtitle: ClubDetailSample.dues, usesClubShadow: true)
                            EventInfoCard(systemImage: "calendar.and.person", title: "Meeting Format",
                                          subtitle: ClubDetailSample.meetingFormat, usesClubShadow: true)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)

                upcomingClubEvents
                    .padding(.top, 30)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gtBackground)
            .overlay(alignment: .topLeading) {
                clubLogo
                    .padding(.leading, 16)
                    .offset(y: -36)
                    .accessibilityHidden(true)
            }
            // logo and content is part of foreground layer over the purple background
            .padding(.top, 40)
        }
        .scrollClipDisabled()
        .scrollEdgeEffectHidden(true, for: .top)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollOffset = offset
        }
        .background {
            GeometryReader { geometry in
                Color.gtBackground
                    .ignoresSafeArea()

                // temporary color (don't know what the plan is to change for each club)
                Color(red: 197 / 255.0, green: 107 / 255.0, blue: 207 / 255.0)
                    .frame(height: max(0, geometry.safeAreaInsets.top + 40 - scrollOffset))
                    .offset(y: -geometry.safeAreaInsets.top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarRole(.editor)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Color.gtPrimaryText)
    }

    @ViewBuilder
    private var clubLogo: some View {
        if let logoImageName {
            Image(logoImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 73, height: 73)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.2.fill")
                .font(.gtHeading2)
                .foregroundStyle(Color.gtWhite)
                .frame(width: 73, height: 73)
                .background(Color.gtNavy, in: Circle())
        }
    }

    private var clubHeading: some View {
        HStack(alignment: .center, spacing: 12) {
            clubTitle
                .frame(maxWidth: .infinity, alignment: .leading)
            EventFollowButtonView(organizationName: clubName)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var clubTitle: some View {
        Text(clubName)
            .font(.gtHeading2)
            .foregroundStyle(Color.gtPrimaryText)
            .lineLimit(2)
            .minimumScaleFactor(20.0 / 24.0)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var socialLinks: some View {
        HStack(spacing: 14) {
            socialLink("Instagram", image: Image("ClubInstagramIcon"), url: instagramURL)
            socialLink("Website", image: Image(systemName: "globe.americas.fill"), url: websiteURL)
            socialLink("Email", image: Image(systemName: "envelope"), url: emailURL)
        }
    }

    private func socialLink(_ title: String, image: Image, url: URL?) -> some View {
        ExternalLinkButton(url: url) {
            image
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(clubName) \(title)")
    }

    @ViewBuilder
    private var upcomingClubEvents: some View {
        if !upcomingEvents.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                Text("Upcoming Club Events")
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(upcomingEvents) { event in
                            NavigationLink {
                                EventDetailExampleView(
                                    event: event,
                                    organizationImageName: logoImageName,
                                    locationTitle: organizationName == nil ? ClubDetailSample.buildingName : nil,
                                    locationDetail: organizationName == nil ? "Room \(ClubDetailSample.roomNumber)" : nil
                                )
                            } label: {
                                clubEventCard(event)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(event.title), \(eventDateText(event))")
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var clubName: String { organizationName ?? ClubDetailSample.name }

    // shows event artwork and other event details
    private func clubEventCard(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            eventArtwork(event)
                .frame(height: 146)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(event.title)
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    Text(eventDateText(event))
                    Spacer(minLength: 0)
                    Text(event.location ?? "")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(eventDateText(event))
                    Text(event.location ?? "")
                }
            }
            .font(.gtBody4)
            .foregroundStyle(Color.gtSecondaryText)
        }
        .frame(width: 260, alignment: .leading)
    }

    @ViewBuilder
    private func eventArtwork(_ event: Event) -> some View {
        let artworkName = EventArtwork.imageName(for: event)
        let image = PlaceImageView(image: artworkName)
        if image.hasImage {
            ZStack {
                image
                    .blur(radius: 12)
                Image(artworkName)
                    .resizable()
                    .scaledToFit()
            }
                .clipped()
                .accessibilityLabel("Artwork for \(event.title)")
        } else {
            Color.gtGray1
                .overlay {
                    Image(systemName: "photo")
                        .font(.gtHeading1)
                        .foregroundStyle(Color.gtNavy)
                }
                .accessibilityLabel("Event artwork placeholder")
        }
    }

    // Formats the event date and time
    private func eventDateText(_ event: Event) -> String {
        let day = event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time)"
    }
}

#Preview("Club detail · Light") {
    @Previewable @State var path = [true]

    NavigationStack(path: $path) {
        List { NavigationLink("iOS Club @ GT", value: true) }
            .navigationTitle("Clubs")
            .navigationDestination(for: Bool.self) { _ in ClubDetailExampleView() }
    }
    .preferredColorScheme(.light)
}

#Preview("Club detail · Dark") {
    @Previewable @State var path = [true]

    NavigationStack(path: $path) {
        List { NavigationLink("iOS Club @ GT", value: true) }
            .navigationTitle("Clubs")
            .navigationDestination(for: Bool.self) { _ in ClubDetailExampleView() }
    }
    .preferredColorScheme(.dark)
}
