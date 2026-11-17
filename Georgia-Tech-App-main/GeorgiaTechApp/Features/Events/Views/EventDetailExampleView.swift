import MapKit
import SwiftData
import SwiftUI

struct EventDetailExampleView: View {
    let event: Event
    var organizationImageName: String?
    var locationTitle: String?
    var locationDetail: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingToCalendar = false
    @State private var isShowingCalendarOptions = false
    @State private var isOpeningMaps = false
    @State private var mapDestination: SearchCardModel?
    @State private var isShowingMap = false
    @State private var actionMessage: String?
    @State private var isShowingEventImage = false
    @Namespace private var eventImageTransition
    @AppStorage("addedCalendarEvents") private var addedCalendarEvents = "[]"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                coverImage

                VStack(alignment: .leading, spacing: 14) {
                    Text(event.title)
                        .font(.gtHeading2)
                        .foregroundStyle(Color.gtPrimaryText)
                        .accessibilityAddTraits(.isHeader)

                    if !event.groups.isEmpty {
                        EventOrganizationView(
                            name: event.groups.joined(separator: ", "),
                            imageName: organizationImageName
                        )
                    }

                    VStack(spacing: 10) {
                        EventInfoCard(systemImage: "calendar", title: dateText, subtitle: timeText)
                        if let location = event.location, !location.isEmpty {
                            EventInfoCard(systemImage: "map", title: locationTitle ?? location,
                                          subtitle: locationDetail ?? "")
                        }
                    }

                    let story = event.body.isEmpty ? event.summary : event.body
                    if !story.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(GTBodyText.paragraphs(in: story).enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(.gtBody2)
                                    .foregroundStyle(Color.gtPrimaryText)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                            .padding(.top, 6)
                            .textSelection(.enabled)
                    }
                    supplementaryDetails
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .gtScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if isShowingCalendarOptions {
                Color.gtOverlay2
                    .contentShape(Rectangle())
                    .onTapGesture { isShowingCalendarOptions = false }
                    .accessibilityLabel("Dismiss calendar options")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionFooter
                .offset(y: 12)
        }
        .navigationDestination(isPresented: $isShowingMap) {
            if let mapDestination {
                EventMapDestinationView(place: mapDestination)
            }
        }
        .alert("Event", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
        .fullScreenCover(isPresented: $isShowingEventImage) {
            EventImageViewerView(imageName: EventArtwork.imageName(for: event), title: event.title)
                .navigationTransition(.zoom(sourceID: event.eventID, in: eventImageTransition))
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        let image = PlaceImageView(image: EventArtwork.imageName(for: event))
        if image.hasImage {
            Button {
                isShowingEventImage = true
            } label: {
                image
                    .aspectRatio(16 / 9, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: event.eventID, in: eventImageTransition)
            .accessibilityLabel("Enlarge image for \(event.title)")
        }
    }

    private var actionFooter: some View {
        HStack(spacing: 10) {
            Button {
                isShowingCalendarOptions.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasAddedToCalendar ? "calendar.badge.checkmark" : "calendar")
                    Text(calendarButtonTitle)
                    Image(systemName: isShowingCalendarOptions ? "chevron.down" : "chevron.up")
                        .font(.gtHeading5)
                }
                .font(.gtHeading5)
                .foregroundStyle((colorScheme == .dark ? Color.gtWhite : Color.gtNavy))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.gtSecondaryText.opacity(0.08)))
                .shadow(color: Color.gtOverlay1, radius: 3, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(calendarButtonTitle)
            .accessibilityHint("Shows Google, Apple, and Outlook calendar options.")
            .disabled(isAddingToCalendar)
            .overlay(alignment: .bottom) {
                if isShowingCalendarOptions {
                    calendarOptions
                        .fixedSize(horizontal: false, vertical: true)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.gtOverlay1, radius: 3, y: 3)
                        .offset(y: -54)
                }
            }

            if let location = event.location, !location.isEmpty {
                Button {
                    isShowingCalendarOptions = false
                    Task { await openMaps() }
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.gtHeading3)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 54, height: 54)
                        .background((colorScheme == .dark ? Color.gtNavy : Color.gtWhite), in: Circle())
                        .overlay(Circle().strokeBorder(Color.gtSecondaryText.opacity(0.08)))
                        .shadow(color: Color.gtOverlay1, radius: 3, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isOpeningMaps)
                .accessibilityLabel(isOpeningMaps ? "Finding event location" : "Show \(location) on the map")
                .accessibilityHint("Opens the event’s location card, where you can choose Directions.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(.regularMaterial)
    }

    private var calendarOptions: some View {
        VStack(spacing: 0) {
            // add to google calendar and outlook calendar, still not implemented for now
            Button {} label: {
                calendarOptionLabel("Add to Google Calendar", imageName: "GoogleCalendarIcon")
            }
            .accessibilityLabel("Add to Google Calendar, unavailable")

            Divider()
                .opacity(0.25)

            Button {
                isShowingCalendarOptions = false
                Task { await addToCalendar() }
            } label: {
                calendarOptionLabel(hasAddedToCalendar ? "Added to Apple Calendar" : "Add to Apple Calendar",
                                    imageName: "AppleCalendarIcon")
            }
            .disabled(hasAddedToCalendar || isAddingToCalendar)
            .accessibilityLabel(hasAddedToCalendar ? "Event already added to Apple Calendar" : "Add to Apple Calendar")

            Divider()
                .opacity(0.25)

            Button {} label: {
                calendarOptionLabel("Add to Outlook Calendar", imageName: "OutlookCalendarIcon")
            }
            .accessibilityLabel("Add to Outlook Calendar, unavailable")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color.gtNavy : Color.gtWhite)
    }

    /// Uses the supplied provider icons and the app's typography for each calendar row.
    private func calendarOptionLabel(_ title: String, imageName: String) -> some View {
        HStack(spacing: 20) {
            Image(imageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.gtHeading5)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.gtPrimaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var supplementaryDetails: some View {
        if let contact = event.contact, !contact.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                GTSectionHeader("Contact")
                Text(contact)
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
                    .textSelection(.enabled)
            }
        }
        if !event.relatedLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader("Links")
                ForEach(event.relatedLinks) { link in
                    if let url = URL(string: link.url) {
                        ExternalLinkButton(url: url) {
                            Text(link.title.isEmpty ? link.url : link.title)
                                .font(.gtBody2)
                        }
                        .accessibilityLabel(link.title.isEmpty ? link.url : link.title)
                    }
                }
            }
        }
    }

    private var dateText: String {
        var format = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        let calendar = Calendar.current
        if calendar.component(.year, from: event.startDate) != calendar.component(.year, from: .now)
            || calendar.component(.year, from: event.endDate) != calendar.component(.year, from: .now) {
            format = format.year(.defaultDigits)
        }
        if calendar.isDate(event.startDate, inSameDayAs: event.endDate) {
            return event.startDate.formatted(format)
        }
        return "\(event.startDate.formatted(format)) – \(event.endDate.formatted(format))"
    }

    private var timeText: String {
        event.startDate.formatted(date: .omitted, time: .shortened)
    }

    private var calendarButtonTitle: String {
        if isAddingToCalendar { return "Adding to Calendar…" }
        return hasAddedToCalendar ? "Added to Calendar" : "Add to Calendar"
    }

    private var calendarSignature: String {
        "\(event.eventID)|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)"
    }

    private var savedCalendarSignatures: [String] {
        guard let data = addedCalendarEvents.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private var hasAddedToCalendar: Bool { savedCalendarSignatures.contains(calendarSignature) }

    /// Saves the event through the calendar service and records successful additions locally.
    @MainActor
    private func addToCalendar() async {
        guard !isAddingToCalendar, !hasAddedToCalendar else { return }
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }

        switch await EventCalendarService.addToCalendar(event) {
        case .added:
            if let data = try? JSONEncoder().encode(savedCalendarSignatures + [calendarSignature]),
               let encoded = String(data: data, encoding: .utf8) {
                addedCalendarEvents = encoded
            }
            actionMessage = "\(event.title) was added to your calendar."
        case .permissionDenied:
            actionMessage = "Allow calendar access for GeorgiaTechApp in Settings to add this event."
        case .failed:
            actionMessage = "Couldn’t add the event. Check that you have a calendar available and try again."
        }
    }

    /// Resolves the venue and opens its location card on the app's existing map.
    @MainActor
    private func openMaps() async {
        // A supplied building title excludes indoor details such as a room number.
        let buildingTitle = locationTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = buildingTitle.flatMap { $0.isEmpty ? nil : $0 } ?? event.location
        guard !isOpeningMaps, let location = venue,
              !EventVenueSearch.terms(in: location).isEmpty else { return }
        isOpeningMaps = true
        defer { isOpeningMaps = false }
        if let locations = try? modelContext.fetch(FetchDescriptor<CampusLocation>()) {
            let matches = EventVenueSearch.preferredMatches(in: locations, venue: location) {
                [$0.name, $0.nameAbbreviated]
            }
            if let place = matches.first {
                showDirections(to: place.toSearchCard())
                return
            }
        }
        let results = await ExternalSearchService().search(EventVenueSearch.query(for: location))
        let matches = EventVenueSearch.preferredMatches(in: results, venue: location) {
            [$0.name ?? ""]
        }
        guard let place = matches.first else {
            actionMessage = "Couldn’t find this venue. Check your connection or search for \(location) on the Map tab."
            return
        }
        showDirections(to: place.toSearchCard())
    }

    /// Opens the destination on the map within the event's navigation stack.
    private func showDirections(to card: SearchCardModel) {
        mapDestination = card
        isShowingMap = true
    }
}

/// Hosts the existing map for the event's venue, including standalone previews.
private struct EventMapDestinationView: View {
    @State private var locationManager = LocationManager()
    @State private var busLiveManager = BusLiveManager()
    @State private var pendingPlace: SearchCardModel?

    init(place: SearchCardModel) {
        _pendingPlace = State(initialValue: place)
    }

    var body: some View {
        MapView(
            locationManager: locationManager,
            busLiveManager: busLiveManager,
            pendingStop: $pendingPlace,
            isNavigationBarHidden: false
        )
        .environment(locationManager)
        .environment(busLiveManager)
    }
}

#Preview("Event detail · Light") {
    @Previewable @State var path = [true]

    NavigationStack(path: $path) {
        List {
            NavigationLink("Sample event", value: true)
        }
        .navigationTitle("Events")
        .navigationDestination(for: Bool.self) { _ in
            EventDetailExampleView(event: EventDetailSample.event,
                            organizationImageName: "EventOrganizationLogo",
                            locationDetail: "Volleyball Courts")
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Event detail · Dark") {
    @Previewable @State var path = [true]

    NavigationStack(path: $path) {
        List {
            NavigationLink("Sample event", value: true)
        }
        .navigationTitle("Events")
        .navigationDestination(for: Bool.self) { _ in
            EventDetailExampleView(event: EventDetailSample.event,
                            organizationImageName: "EventOrganizationLogo",
                            locationDetail: "Volleyball Courts")
        }
    }
    .preferredColorScheme(.dark)
}
