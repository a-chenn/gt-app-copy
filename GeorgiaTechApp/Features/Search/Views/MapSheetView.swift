//
//  MapSheetView.swift
//  GeorgiaTechApp
//

import CoreLocation
import MapKit
import SwiftUI

struct MapSheetView: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(MapSelection.self) private var selection
    // Drives the filter-pill accent (#U5) — gold fails 3:1 in light mode.
    @Environment(\.colorScheme) private var colorScheme
    @Binding var sheetDetent: MapSheetDetent
    /// Shows the Favorites list in place of search. Owned by MapView so
    /// the rail can mirror it.
    @Binding var isShowingFavorites: Bool
    /// Category taps from the floating rail.
    var categoryRequest: MapCategoryRequest?

    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    @State private var searchVM = SearchVM()
    // Category pins are computed at the tap so the map and the sheet
    // move in one update (#14); the same service the rail chips use.
    private let campusSearchService = CampusSearchService()

    /// "View All" recents, shown in place of search (Figma "View all recents").
    @State private var isShowingAllRecents = false
    /// How far the search surface's list has scrolled; the "Where to?"
    /// header rides up with it instead of floating over the content.
    @State private var searchScrollDistance: CGFloat = 0
    /// Drives the search surface's list back to the top on collapse.
    @State private var searchScrollPosition = ScrollPosition(edge: .top)
    @State private var showOpenNowOnly = false
    @State private var isSortedByNearest = false

    let searchableData: SearchableData
    var isBusLayerOn = false
    /// Bumped by the rest-state search pill (#20); consumed via
    /// `onSearchActivated` so a re-presented sheet doesn't re-focus.
    var searchActivationToken = 0
    var diningActivationToken = 0
    var onSearchActivated: () -> Void = {}
    var onOpenCapacities: (Int?) -> Void = { _ in }

    private var parkingLocations: [CampusLocation] {
        searchableData.locations.filter {
            $0.type.caseInsensitiveCompare("parkingDecks") == .orderedSame
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if routeManager.isNavigating {
                    ActiveNavigationView(
                        parkingLocations: parkingLocations,
                        isCollapsed: sheetDetent == .collapsed,
                        onSelectParking: { stop in
                            Task {
                                await routeManager.addIntermediateStop(stop)
                            }
                        }
                    )
                } else if let destination = routeManager.planningDestination {
                    RouteOptionsView(
                        destination: destination,
                        searchableData: searchableData
                    )
                    .id(destination.id)
                } else if let busID = selection.focusedBusID,
                          let bus = searchableData.liveBuses.first(where: { $0.vehicleID == busID }) {
                    BusTimelineView(
                        bus: bus,
                        route: searchableData.busRoutes.first { $0.routeID == bus.routeID },
                        stopEstimates: searchableData.stopEstimates
                    )
                    .id(busID)
                } else if let place = selection.selectedPlace {
                    PlaceDetailView(
                        place: place,
                        searchableData: searchableData,
                        onClose: { selection.select(nil) },
                        onOpenCapacities: onOpenCapacities
                    )
                    // Identity must be set HERE, at the owning node — an
                    // .id inside PlaceDetailView's body can't reset its own
                    // @State (menu picker, dietary filters) between places.
                    .id(place.id)
                } else if isShowingAllRecents {
                    RecentsListView(
                        searchVM: searchVM,
                        onBack: {
                            withAnimation { isShowingAllRecents = false }
                        },
                        onSelect: { card in
                            selection.select(card)
                        }
                    )
                } else if isShowingFavorites {
                    FavoritesListView(
                        onBack: {
                            withAnimation { isShowingFavorites = false }
                        },
                        onSelect: { card in
                            // Closing the card returns to the list.
                            selection.select(card)
                        }
                    )
                } else {
                    searchContent()
                        // Each search state has one vertical scroller.
                        // Moving the header INTO it would remount the
                        // TextField (and drop focus) as states swap, so
                        // the pinned header is offset by the scroll instead.
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.y + geometry.contentInsets.top
                        } action: { _, distance in
                            searchScrollDistance = distance
                        }
                        .scrollPosition($searchScrollPosition)
                        // A swapped-in list starts at the top.
                        .onChange(of: searchVM.activeCategory) { _, _ in
                            searchScrollDistance = 0
                        }
                        .onChange(of: searchText.isEmpty) { _, _ in
                            searchScrollDistance = 0
                        }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !routeManager.isNavigating,
               routeManager.planningDestination == nil,
               selection.selectedPlace == nil,
               selection.focusedBusID == nil,
               !isShowingFavorites,
               !isShowingAllRecents,
               searchVM.activeCategory == nil {
                headerView
                    .offset(y: -searchScrollDistance)
            }
        }
        .animation(.spring(), value: routeManager.isNavigating)
        .animation(.spring(), value: routeManager.planningDestination?.id)
        .animation(.spring(), value: selection.selectedPlace?.id)
        .animation(.spring(), value: selection.focusedBusID)
        .animation(.spring(), value: isShowingFavorites)
        .animation(.spring(), value: isShowingAllRecents)
        // Collapsing tidies the sheet but leaves the map alone: the
        // selected place, the category's pins and the query that drew
        // them (with its filters) all survive, so the pins stay on the
        // map. Routing is exempt too — a live route or a trip being
        // planned survives a collapse.
        .onChange(of: sheetDetent) { _, detent in
            guard detent == .collapsed else { return }
            // The header rides the scroll, so the list returns to the top
            // with the sheet and the search bar sits where it belongs.
            withAnimation(.smooth(duration: 0.35)) {
                searchScrollPosition.scrollTo(edge: .top)
            }
            guard !routeManager.isNavigating,
                  routeManager.planningDestination == nil else { return }
            isFocused = false
            isShowingFavorites = false
            isShowingAllRecents = false
        }
        .onChange(of: isFocused) { _, focused in
            guard focused else { return }
            withAnimation {
                sheetDetent = .expanded
            }
        }
        .onChange(of: categoryRequest) { _, request in
            guard let request else { return }
            toggleCategory(request.category)
        }
        // Favorites opens on a clean surface.
        .onChange(of: isShowingFavorites) { _, showing in
            guard showing else { return }
            isShowingAllRecents = false
            isFocused = false
            searchText = ""
            showOpenNowOnly = false
            isSortedByNearest = false
            searchVM.clearSearch()
            selection.clear()
            withAnimation {
                sheetDetent = .expanded
            }
        }
        .task {
            searchVM.loadRecents()
        }
        .task(id: searchActivationToken) {
            // The rest-state search pill (#20): open large and drop the
            // cursor into the field once the sheet has presented.
            guard searchActivationToken > 0 else { return }
            withAnimation {
                sheetDetent = .expanded
            }
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
            onSearchActivated()
        }
        .task(id: diningActivationToken) {
            guard diningActivationToken > 0 else { return }
            guard !routeManager.isNavigating,
                  routeManager.planningDestination == nil,
                  selection.selectedPlace == nil else { return }
            showOpenNowOnly = false
            isSortedByNearest = false
            searchText = ""
            isFocused = false
            searchVM.clearSearch()
            await searchVM.search(.category(.dining), data: searchableData)
            selection.showCategory(.dining, results: searchVM.campusResults)
            withAnimation {
                sheetDetent = .medium
            }
        }
        .onChange(of: routeManager.planningDestination?.id) { _, planning in
            if planning == nil {
                searchVM.loadRecents()
            }
        }
        .onChange(of: selection.focusedBusID) { _, busID in
            // A focused bus lifts the sheet to show its stops.
            guard busID != nil, sheetDetent == .collapsed else { return }
            withAnimation { sheetDetent = .medium }
        }
        .onChange(of: selection.selectedPlace?.id) { _, newValue in
            // A route opened from a stop card belongs to that card.
            if selection.selectedPlace?.category != .busStop {
                selection.focusedBusRouteID = nil
            }
            // Viewing a place records a Recent; refresh the preview when
            // the detail card closes and the search surface reappears.
            if newValue == nil {
                searchVM.loadRecents()
            }
        }
        .onChange(of: selection.activeCategory) { _, category in
            followSelection(to: category)
        }
    }

    // MARK: - Category seam (#14)

    /// Keeps the sheet in step with the shared selection, whichever
    /// surface changed it: a newly opened category clears any stale text
    /// query, loads its results, and lifts the sheet off the rest detent,
    /// so the pins on the map never show without a list behind them. A
    /// category that's already showing is left alone (the filter pills
    /// re-issue `showCategory` to re-sync pins; that must not reset them).
    private func followSelection(to category: SearchCategories?) {
        guard let category else {
            if searchVM.activeCategory != nil {
                searchVM.clearSearch()
                showOpenNowOnly = false
                isSortedByNearest = false
            }
            return
        }
        guard searchVM.activeCategory != category else { return }
        isFocused = false
        searchText = ""
        showOpenNowOnly = false
        isSortedByNearest = false
        searchVM.showCategory(category, data: searchableData)
        withAnimation {
            // Mid height keeps the map and its new pins visible while
            // browsing (#7).
            sheetDetent = .medium
        }
    }

    // MARK: - Search Content
    
    @ViewBuilder
    private func searchContent() -> some View {
        if let query = searchVM.query, case .text(let queryText) = query {
            if searchVM.campusResults.isEmpty && searchVM.externalResults.isEmpty {
                // Zero matches (#U6): say so instead of a blank list — but
                // only once the search finished; empty arrays mid-flight
                // must not flash a false "No Results".
                if !searchVM.isTextSearchInFlight {
                    ContentUnavailableView.search(text: queryText)
                }
            } else {
                textResultsList
            }
        } else {
            // Nothing typed: an open category's results, or the resting
            // surface (#2). The resting view scrolls itself — wrapped in
            // a ScrollView its List collapses to nothing and the header
            // floats to the sheet's vertical middle.
            if searchVM.activeCategory != nil {
                ScrollView {
                    resultsContent()
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
            } else {
                restingContent
            }
        }
    }

    private var textResultsList: some View {
        List {
            // Campus matches first (#R4-15) — GT data outranks the
            // wider world for on-campus queries.
            if !searchVM.campusResults.isEmpty {
                Section(header: Text("On Campus").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
                    ForEach(searchVM.campusResults) { card in
                        SearchResultRow(
                            model: card,
                            userLocation: searchableData.userLocation,
                            onDirections: {
                                routeManager.requestDirections(to: card)
                            }
                        )
                        .contentShape(Rectangle())
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture {
                            isFocused = false
                            selection.select(card)
                        }
                    }
                }
            }

            if !searchVM.externalResults.isEmpty {
                if searchVM.campusResults.isEmpty {
                    Section {
                        externalResultRows
                    }
                } else {
                    Section(header: Text("Nearby").font(.gtHeading6).foregroundStyle(Color.gtSecondaryText)) {
                        externalResultRows
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // The sheet's material shows through; the grouped list's own
        // gray backdrop clashed with it.
        .scrollContentBackground(.hidden)
        // The keyboard covers the sheet's lower part (it doesn't resize
        // the sheet), so any swipe lowers it to reveal the rest, even
        // when the results are too short to scroll.
        .scrollDismissesKeyboard(.immediately)
        .scrollBounceBehavior(.always)
    }

    private var externalResultRows: some View {
        ForEach(searchVM.externalResults, id: \.self) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown Place")
                    .font(.gtHeading4)

                if let subtitle = item.addressRepresentations?
                    .fullAddress(includingRegion: false, singleLine: true) {
                    Text(subtitle)
                        .font(.gtBody2)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                isFocused = false
                selection.select(item.toSearchCard())
            }
        }
    }

    /// Rail category tap: one category at a time; tapping the active
    /// chip clears it.
    private func toggleCategory(_ category: SearchCategories) {
        showOpenNowOnly = false
        isSortedByNearest = false
        isShowingFavorites = false
        isShowingAllRecents = false
        isFocused = false
        selection.select(nil)

        if searchVM.activeCategory == category {
            closeCategory()
            return
        }

        // Safe: the text observer leaves a category query alone.
        searchText = ""
        Task {
            await searchVM.search(.category(category), data: searchableData)
            selection.showCategory(category, results: searchVM.campusResults)
        }
        withAnimation {
            // Mid height keeps the map and its new pins visible while
            // browsing (#7).
            sheetDetent = .medium
        }
    }

    /// Leaves the open category: its results, filters and map pins.
    private func closeCategory() {
        withAnimation {
            showOpenNowOnly = false
            isSortedByNearest = false
            searchVM.clearSearch()
            selection.clearCategory()
        }
    }

    // MARK: - Resting state (#2): generic, nothing searched yet.

    private var restingContent: some View {
        RestingSheetView(
            searchableData: searchableData,
            searchVM: searchVM,
            isBusLayerOn: isBusLayerOn,
            isSearchFocused: isFocused,
            onShowAllRecents: {
                withAnimation { isShowingAllRecents = true }
            },
            onSelectCategory: { toggleCategory($0) }
        )
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsContent() -> some View {
        // A category (an amenity tile or a rail chip) is a sub-page like
        // Recents: back returns to the main view and takes its pins off.
        if let category = searchVM.activeCategory {
            SheetBackHeader(title: category.title, onBack: closeCategory)
        }

        filterPillsRow

        if searchVM.activeCategory == .dining {
            // Dining renders as a card grid — the one category with photos
            // and hours worth a richer presentation.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                spacing: 12
            ) {
                ForEach(filteredResults(searchVM.campusResults)) { card in
                    Button {
                        selection.select(card)
                    } label: {
                        DiningCardView(
                            model: card,
                            hoursOpen: restaurantHours(for: card),
                            restaurantType: restaurant(for: card)?.restaurantType,
                            userLocation: searchableData.userLocation
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(filteredResults(searchVM.campusResults)) { card in
                    Button {
                        selection.select(card)
                    } label: {
                        SearchResultRow(
                            model: card,
                            userLocation: searchableData.userLocation,
                            onDirections: {
                                routeManager.requestDirections(to: card)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Filter pills (#8: Nearest everywhere, Open Now for dining)

    private var filterPillsRow: some View {
        HStack(spacing: 8) {
            filterPill(
                title: "Nearest",
                icon: "location",
                isOn: isSortedByNearest,
                isEnabled: searchableData.userLocation != nil
            ) {
                isSortedByNearest.toggle()
                syncPinsToFilters()
            }

            if searchVM.activeCategory == .dining {
                filterPill(
                    title: "Open Now",
                    icon: "clock",
                    isOn: showOpenNowOnly,
                    isEnabled: true
                ) {
                    showOpenNowOnly.toggle()
                    syncPinsToFilters()
                }
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    private func filterPill(
        title: String, icon: String, isOn: Bool, isEnabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        } label: {
            // Toggle language, not selection language (#U5): the category
            // chips above own the solid-gold-capsule active state, so an
            // active filter uses an outline + trailing checkmark to keep
            // the two stacked rows visually distinct.
            let accent = (colorScheme == .dark ? Color.gtGold : Color.gtDarkGold)
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.gtBody3)
                Text(title)
                    .font(.gtHeading5)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.gtHeading6)
                        .foregroundStyle(accent)
                }
            }
            .foregroundStyle(Color.gtPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isOn {
                    Capsule().fill(Color.gtGold.opacity(0.18))
                    Capsule().strokeBorder(accent, lineWidth: 1.5)
                } else {
                    Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(title == "Nearest" ? "Sort by distance" : "Filter to places open now")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func syncPinsToFilters() {
        // Keep the map pins matching what the sheet shows.
        if let category = searchVM.activeCategory {
            selection.showCategory(
                category, results: filteredResults(searchVM.campusResults))
        }
    }

    private func filteredResults(_ cards: [SearchCardModel]) -> [SearchCardModel] {
        var results = cards

        if showOpenNowOnly, searchVM.activeCategory == .dining {
            results = results.filter { DiningHours.isOpenNow(restaurantHours(for: $0)) }
        }

        if isSortedByNearest, let user = searchableData.userLocation {
            let origin = CLLocation(latitude: user.latitude, longitude: user.longitude)
            results = results.sorted { a, b in
                guard let ca = a.coordinate else { return false }
                guard let cb = b.coordinate else { return true }
                return origin.distance(from: CLLocation(latitude: ca.latitude, longitude: ca.longitude))
                    < origin.distance(from: CLLocation(latitude: cb.latitude, longitude: cb.longitude))
            }
        }

        return results
    }

    private func restaurant(for card: SearchCardModel) -> Restaurant? {
        searchableData.restaurants.first { $0.restaurantID == card.id }
    }

    private func restaurantHours(for card: SearchCardModel) -> [[String]]? {
        restaurant(for: card)?.hoursOpen
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gtSecondaryText)
                    .padding(.leading, 14)
                
                TextField("Where to?", text: $searchText, prompt: Text("Where to?").foregroundStyle(Color.gtSecondaryText))
                    .font(.gtBody1)
                    .focused($isFocused)
                    .padding(.vertical, 8)
                    .onChange(of: searchText) { _, text in
                        Task {
                            if text.isEmpty {
                                // Don't wipe a category query when a
                                // rail tap clears the text.
                                if case .category = searchVM.query { return }
                                searchVM.clearSearch()
                                selection.clearResults()
                            } else {
                                // Text search replaces any category results,
                                // so their pins come off the map too.
                                selection.clearResults()
                                await searchVM.search(.text(text), data: searchableData)
                            }
                        }
                    }
                
                Spacer()
                if searchText != "" {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtSecondaryText)
                            .frame(width: 24, height: 24)
                            .padding(.trailing, 8)
                    }
                    .accessibilityLabel("Clear search text")
                }

            }
            .frame(minHeight: 44)
            // Figma "Where to?": the GTSearchBar resting fill.
            .background(
                colorScheme == .dark ? Color.gtWhite.opacity(0.12) : Color.gtOverlay1,
                in: .capsule)

            // Stays after the keyboard is swiped away, while there's still a
            // search to back out of.
            if isFocused || !searchText.isEmpty {
                Button {
                    isFocused = false
                    searchText = ""
                    showOpenNowOnly = false
                    searchVM.clearSearch()
                    selection.clear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.gtHeading2)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 44, height: 44)
                        .glassEffect(in: .circle)
                }
                .accessibilityLabel("Cancel search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
    }
}
