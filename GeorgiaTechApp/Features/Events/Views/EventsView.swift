import SwiftData
import SwiftUI

/// Events home, temporarily using example events for design review.
struct EventsView: View {
    var onOpenHome: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    // Use examples until the live feed is enabled again. Keep them out of the synced store.
    @State private var events = EventsSample.makeEvents()
    @AppStorage("followedEventOrganizations") private var followedOrganizations = "[]"
    @State private var eventsVM = EventsVM()
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var isShowingSearch = false
    @State private var isShowingFilters = false
    @State private var isFilteringDate = false
    @State private var selectedDate = Date.now
    @State private var sortOrder = EventFeedSortOrder.date
    @FocusState private var isSearchFocused: Bool
    @State private var selectedSection: FeedSection = .events
    @State private var selectedEvent: Event?

    init(
        initialEvent: Event? = nil,
        onOpenHome: @escaping () -> Void = {}
    ) {
        self.onOpenHome = onOpenHome
        _selectedEvent = State(initialValue: initialEvent)
    }

    private enum FeedSection: String, CaseIterable {
        case events = "Events"
        case news = "News"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(FeedSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityLabel("Events or News")
            .onChange(of: selectedSection) { _, _ in
                isSearchFocused = false
            }

            if selectedSection == .events {
                eventsContent
            } else {
                NewsHomeView(isEmbedded: true)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .gtScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedEvent) { event in
            EventDetailExampleView(event: event)
                .toolbar(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingFilters) {
            EventsFilterView(isFilteringDate: $isFilteringDate, selectedDate: $selectedDate,
                             sortOrder: $sortOrder) {
                isFilteringDate = false
                selectedCategory = nil
                sortOrder = .date
                searchText = ""
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var eventsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if isShowingSearch { searchField }
                if !organizations.isEmpty {
                    clubRow
                        .padding(.top, 10)
                }
                filters
                    .padding(.top, 15)
                    .padding(.bottom, 20)
                Rectangle()
                    .fill(Color.gtBurdell)
                    .frame(height: 1)

                if !yourEvents.isEmpty {
                    eventCarousel("Your Events", events: yourEvents)
                        .padding(.top, 20)
                } else if !filteredEvents.isEmpty && followedClubs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Your Events")
                        Text("Follow a club above to see its events here.")
                            .font(.gtBody2)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                if !recommendedEvents.isEmpty {
                    eventCarousel("Recommended Events", events: recommendedEvents)
                        .padding(.top, 28)
                }
                Rectangle()
                    .fill(Color.gtBurdell)
                    .frame(height: 1)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 15) {
                    sectionTitle("All Events")
                    if filteredEvents.isEmpty {
                        ContentUnavailableView(
                            hasActiveFilters ? "No Matching Events" : "No Upcoming Events",
                            systemImage: "calendar",
                            description: Text(hasActiveFilters
                                ? "Try another name or remove a filter."
                                : "Campus events will show up here.")
                        )
                    } else {
                        EventsGridView(events: filteredEvents, showsLocation: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 25.51)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                onOpenHome()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back to Home")
            Text("Events")
                .font(.gtHeading1)
                .foregroundStyle(Color.gtPrimaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                isShowingSearch.toggle()
                if !isShowingSearch { searchText = "" }
            } label: {
                Image(systemName: isShowingSearch ? "xmark" : "magnifyingglass")
                    .padding(.horizontal, 14)
                    .frame(width: 44, height: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isShowingSearch ? "Close event search" : "Search events by name")
        }
        .font(.gtHeading3)
        .buttonStyle(.plain)
        .foregroundStyle(Color.gtPrimaryText)
        .padding(.horizontal, 16)
        .padding(.top, 7.88)
    }

    private var searchField: some View {
        TextField("Search events by name", text: $searchText)
            .font(.gtBody1)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isSearchFocused)
            .submitLabel(.search)
            .onSubmit { isSearchFocused = false }
            .onAppear { isSearchFocused = true }
            .padding(12)
            .background(Color.gtOverlay2, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .accessibilityLabel("Search events by name")
    }

    private var clubRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14.11351) {
                ForEach(organizations, id: \.self) { name in
                    NavigationLink {
                        ClubDetailExampleView(
                            organizationName: name,
                            logoImageName: name == ClubDetailSample.name ? "IOSClubLogo" : nil,
                            upcomingEvents: upcomingEvents.filter { $0.groups.contains(name) }
                        )
                    } label: {
                        VStack(spacing: 7) {
                            EventClubAvatarView(name: name, isFollowing: followedClubs.contains(name))
                            Text(name)
                                .font(.custom("Roboto-Regular", size: 14.11351, relativeTo: .subheadline))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.gtPrimaryText)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(width: 76)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(name) club page")
                    .accessibilityHint("Shows this club’s details, Follow button, and upcoming events.")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { isShowingFilters = true } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.gtBody1)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.gtOverlay2, in: Circle())
                        .overlay(alignment: .topTrailing) {
                            if isFilteringDate {
                                Circle().fill(Color.gtDarkGold).frame(width: 7, height: 7)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter events by date and change sorting")
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        selectedCategory = isSelected ? nil : category
                    } label: {
                        Text(category)
                            .font(.gtBody2)
                            .foregroundStyle(isSelected
                                ? (colorScheme == .dark ? Color.gtNavy : Color.gtWhite)
                                : Color.gtPrimaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(isSelected
                                        ? (colorScheme == .dark ? Color.gtBuzz : Color.gtNavy)
                                        : (colorScheme == .dark ? Color.gtNavy : Color.gtWhite))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter: \(category)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Links section headings to their full collection and cards to the live event detail.
    private func eventCarousel(_ title: String, events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                EventsCollectionView(title: title, events: events)
            } label: {
                HStack {
                    sectionTitle(title)
                    Spacer()
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.gtHeading5)
                    }
                    .padding(4)
                    .frame(width: 44, height: 44, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .foregroundStyle(Color.gtPrimaryText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel("See all \(title.lowercased())")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(events.prefix(8)) { event in
                        NavigationLink {
                            EventDetailExampleView(event: event)
                                .toolbar(.visible, for: .navigationBar)
                        } label: {
                            EventsHomeCardView(event: event).frame(width: 260)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.gtHeading3)
            .foregroundStyle(Color.gtPrimaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private var followedClubs: Set<String> {
        guard let data = followedOrganizations.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(names)
    }

    private var upcomingEvents: [Event] { events.filter { $0.endDate >= .now } }

    private var organizations: [String] {
        Set(upcomingEvents.flatMap(\.groups)).union(followedClubs)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                let leftFollowed = followedClubs.contains($0)
                let rightFollowed = followedClubs.contains($1)
                if leftFollowed != rightFollowed { return leftFollowed }
                return $0.localizedStandardCompare($1) == .orderedAscending
            }
    }

    private var categories: [String] {
        Set(upcomingEvents.flatMap(\.eventCategories)).sorted()
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedCategory != nil || isFilteringDate
    }

    private var filteredEvents: [Event] {
        eventsVM.filterEvents(upcomingEvents, query: searchText, category: selectedCategory,
                              date: isFilteringDate ? selectedDate : nil, sortOrder: sortOrder)
    }

    private var yourEvents: [Event] {
        filteredEvents.filter { !followedClubs.isDisjoint(with: $0.groups) }
    }

    private var recommendedEvents: [Event] { eventsVM.recommendedEvents(from: filteredEvents) }
}

/// Initials remain usable when the source supplies no organization logo.
private struct EventClubAvatarView: View {
    let name: String
    var isFollowing = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(initials)
                .font(.gtHeading4)
                .foregroundStyle(Color.gtNavy)
                .frame(width: 58.47026443481445, height: 58.47026443481445)
                .background(Color.gtGray1, in: Circle())
        }
        .padding(.horizontal, 2.52027)
        .padding(.vertical, 2.01622)
        .frame(width: 63.51081, height: 62.5027, alignment: .center)
        .overlay {
            if isFollowing {
                Circle().strokeBorder(highlightGradient, lineWidth: 2.01622)
            } else {
                Circle().strokeBorder(Color.gtSecondaryText.opacity(0.25), lineWidth: 1)
            }
        }
    }

    // Colors sampled from the supplied Yellow → NB5 → B1 gradient reference.
    private var highlightGradient: LinearGradient {
        LinearGradient(colors: [
            Color(red: 255 / 255.0, green: 204 / 255.0, blue: 2 / 255.0),
            Color(red: 213 / 255.0, green: 222 / 255.0, blue: 229 / 255.0),
            Color(red: 31 / 255.0, green: 124 / 255.0, blue: 199 / 255.0)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var initials: String {
        name.split(whereSeparator: \.isWhitespace).prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// Keeps preview fixtures and Follow preferences separate from the running app.
private struct EventsPreviewView: View {
    @State private var locationManager = LocationManager()
    @State private var busLiveManager = BusLiveManager()
    private let container: ModelContainer?
    private let previewDefaults: UserDefaults?

    init() {
        let defaults = UserDefaults(suiteName: "EventsHomePreview")
        defaults?.set("[\"iOS Club @ GT\",\"Arab Student Association\"]", forKey: "followedEventOrganizations")
        previewDefaults = defaults

        do {
            let schema = Schema([
                Appliance.self, Metadata.self, Restaurant.self, RestaurantMenu.self, MenuDay.self,
                MenuItem.self, Food.self, BuildingCapacity.self, CampusLocation.self, BusRoute.self,
                BusStop.self, Event.self, DietaryFilter.self, RecentSearch.self, FavoritePlace.self,
                FavoriteFood.self, NewsArticle.self, GTDate.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            for event in EventsSample.makeEvents() {
                container.mainContext.insert(event)
            }
            try container.mainContext.save()
            self.container = container
        } catch {
            container = nil
        }
    }

    var body: some View {
        if let container, let previewDefaults {
            NavigationStack {
                EventsView()
            }
            .modelContainer(container)
            .defaultAppStorage(previewDefaults)
            .environment(locationManager)
            .environment(busLiveManager)
        } else {
            ContentUnavailableView("Preview Unavailable", systemImage: "exclamationmark.triangle",
                                   description: Text("The preview’s temporary event store could not be created."))
        }
    }
}

#Preview("Events home · Light") {
    EventsPreviewView()
        .preferredColorScheme(.light)
}

#Preview("Events home · Dark") {
    EventsPreviewView()
        .preferredColorScheme(.dark)
}
