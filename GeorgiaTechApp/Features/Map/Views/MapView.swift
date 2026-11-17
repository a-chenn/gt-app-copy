//
//  MapView.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftData
import SwiftUI

struct MapView: View {
    // Shared with the home screen via AppShellView; injected through init
    // because @Environment isn't readable at @State initialization time.
    let busLiveManager: BusLiveManager
    @Binding var pendingStop: SearchCardModel?
    let diningActivationToken: Int
    /// Off when the map is pushed onto another stack (an event's venue),
    /// where the system back button is the way out.
    let isNavigationBarHidden: Bool
    @State private var mapVM: MapVM
    @State private var routeManager = RouteManager()
    @State private var sheetState = MapSheetState()
    @State private var selection = MapSelection()

    init(
        locationManager: LocationManager,
        busLiveManager: BusLiveManager,
        pendingStop: Binding<SearchCardModel?>,
        diningActivationToken: Int = 0,
        isNavigationBarHidden: Bool = true
    ) {
        _mapVM = State(initialValue: MapVM(locationManager: locationManager))
        self.busLiveManager = busLiveManager
        _pendingStop = pendingStop
        self.diningActivationToken = diningActivationToken
        self.isNavigationBarHidden = isNavigationBarHidden
    }

    @Query private var busRoutes: [BusRoute]
    @Query private var restaurants: [Restaurant]
    @Query private var locations: [CampusLocation]
    @Query private var appliances: [Appliance]
    @Query private var dietaryFilters: [DietaryFilter]
    @Query private var capacities: [BuildingCapacity]

    // The sheet is MapBottomSheet, an in-tab view rather than a system
    // `.sheet`, so the system tab bar sits on top of it (Figma "Map").
    // Its detent and live height live on `sheetState`.
    @Namespace private var mapScope
    // Search accessory tap (#20): bumped to open the sheet in search mode.
    @State private var searchActivationToken = 0
    // In-sheet Favorites list, toggled by the rail's heart.
    @State private var isShowingFavorites = false
    // Latest rail category tap, consumed by the sheet.
    @State private var categoryRequest: MapCategoryRequest?
    // Building filter for the capacities deep link (#8).
    @State private var capacitiesFilterID: Int?
    /// Lives on MapSelection so the sheet's bus list can focus a bus too.
    private var selectedBusID: Int? {
        get { selection.focusedBusID }
        nonmutating set { selection.focusedBusID = newValue }
    }
    // Deep link from a building card's capacity strip (#8) — pushes on
    // the Map tab's own stack so the user keeps their map context.
    @State private var isShowingCapacities = false
    // User panned away from the follow camera during navigation.
    @State private var isNavCameraOverridden = false
    // Last real course, held through stops so the camera doesn't north-snap.
    @State private var lastNavigationHeading: Double = 0
    // Route visibility (#6): user-hidden TransLoc route IDs, comma-joined.
    @AppStorage("hiddenBusRouteIDs") private var hiddenBusRouteIDsRaw = ""

    private var hiddenBusRouteIDs: Set<Int> {
        Set(hiddenBusRouteIDsRaw.split(separator: ",").compactMap { Int($0) })
    }

    /// Overlays clear out while planning or navigating so the route is
    /// unmistakable (#9); the bus layer stays only for transit plans.
    private var isRouteFocused: Bool {
        routeManager.isNavigating || routeManager.planningDestination != nil
    }

    private var searchableData: SearchableData {
        SearchableData(
            restaurants: restaurants,
            locations: locations,
            appliances: appliances,
            dietaryFilters: dietaryFilters,
            busRoutes: busRoutes,
            liveBuses: busLiveManager.buses,
            stopEstimates: busLiveManager.stopEstimates,
            capacities: capacities,
            userLocation: mapVM.locationManager.location
        )
    }

    /// Live vehicle data is needed while the bus layer is on, a stop's
    /// departures are showing, or a transit route is active.
    private var isLiveBusDataNeeded: Bool {
        mapVM.showBusRoutes
            || selection.selectedPlace?.category == .busStop
            || routeManager.activeTransitPlan != nil
    }

    /// Default pins for a blank map (#R4-7) — the popular campus anchors,
    /// shown only when nothing is searched or selected.
    private var popularPinCards: [SearchCardModel] {
        PopularPlaces.resolve(from: locations)
    }

    /// What the places layer renders right now: nothing while routing,
    /// the user's own pins when any exist, else the popular defaults.
    private var activePinCards: [SearchCardModel] {
        if isRouteFocused { return [] }
        return selection.mapPlaces.isEmpty ? popularPinCards : selection.mapPlaces
    }

    /// POI suppression keys on the user's OWN pins, not the popular
    /// defaults — default city POIs stay on the resting map (#R4-7);
    /// traffic renders for driving trips only (#R4-16).
    private var currentMapStyle: MapStyle {
        // Muted emphasis (V4): the base map recedes so gold pins, gold
        // route lines, and route-colored buses read as the GT layer.
        selection.mapPlaces.isEmpty
            ? .standard(
                emphasis: .muted, pointsOfInterest: .all,
                showsTraffic: isShowingDrivingTraffic)
            : .standard(
                emphasis: .muted, pointsOfInterest: .excludingAll,
                showsTraffic: isShowingDrivingTraffic)
    }

    /// Traffic (incl. Apple's closure markers) renders for DRIVING trips
    /// only (#R4-16) — the walking-first campus map stays clean.
    private var isShowingDrivingTraffic: Bool {
        (routeManager.isNavigating && routeManager.selectedMode == .driving)
            || (routeManager.planningDestination != nil
                && routeManager.previewTransportMode == .driving)
    }

    /// The open stop card's street address, so the bus layer can hand
    /// that stop to the places layer's black pin.
    private var selectedStopAddressID: Int? {
        guard let place = selection.selectedPlace, place.category == .busStop,
              let idText = place.id.split(separator: "-").last,
              let routeStopID = Int(idText)
        else { return nil }
        return busRoutes.lazy.flatMap(\.stops)
            .first { $0.routeStopID == routeStopID }?.stopAddressID
    }

    /// The tapped bus, re-resolved every poll so the popover stays live.
    private var selectedBus: BusLive? {
        guard let selectedBusID else { return nil }
        return busLiveManager.buses.first { $0.vehicleID == selectedBusID }
    }

    /// Live countdown to the next bus at the boarding stop during an
    /// active transit route, recomputed from shared arrival predictions every poll.
    private var transitChip: (colorHex: String, seconds: Int)? {
        guard let plan = routeManager.activeTransitPlan,
              let route = busRoutes.first(where: { $0.routeID == plan.routeID }),
              let board = route.stops.first(where: { $0.routeStopID == plan.boardRouteStopID }),
              let eta = BusArrivals.etas(to: board, estimates: busLiveManager.stopEstimates).first
        else { return nil }
        return (route.mapColor, eta)
    }

    /// The map's annotation/overlay content, extracted so the compiler
    /// type-checks it separately from `body`.
    @MapContentBuilder
    private var mapContent: some MapContent {
            if mapVM.locationManager.isAuthorized {
                UserAnnotation()
            }

            if (mapVM.showBusRoutes || selection.focusedBusRouteID != nil) && !isRouteFocused {
                MapBusRouteLayer(
                    routes: busRoutes,
                    liveBuses: busLiveManager.buses,
                    hiddenRouteIDs: hiddenBusRouteIDs,
                    // Focus mode (#5): a selected bus clears the noise.
                    focusedRouteID: selectedBus?.routeID ?? selection.focusedBusRouteID,
                    focusedVehicleID: selectedBus?.vehicleID,
                    selectedStopAddressID: selectedStopAddressID,
                    stopEstimates: busLiveManager.stopEstimates,
                    onStopTap: { stop in
                        guard routeManager.stops.isEmpty,
                              routeManager.planningDestination == nil else { return }
                        selectedBusID = nil
                        selection.select(stop.toSearchCard())
                    },
                    onBusTap: { bus in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedBusID = bus.vehicleID
                        }
                    },
                    onDismissBus: {
                        withAnimation { selectedBusID = nil }
                    },
                    onDirectionsToStop: { stop in
                        selectedBusID = nil
                        routeManager.requestDirections(to: stop.toSearchCard())
                    }
                )
            }

            MapRouteOverlay(routes: routeManager.routeSegments)

            if routeManager.planningDestination != nil {
                // Alternates dimmed, selected route full-strength (#21).
                ForEach(Array(routeManager.previewRoutes.enumerated()), id: \.offset) { index, route in
                    if index != routeManager.previewSelectedIndex {
                        MapPolyline(route.polyline)
                            .stroke(Color.gtGold.opacity(0.35), lineWidth: 4)
                    }
                }
                if routeManager.previewRoutes.indices.contains(routeManager.previewSelectedIndex) {
                    MapRouteOverlay(routes: [routeManager.previewRoutes[routeManager.previewSelectedIndex]])
                }
            }

            if let plan = routeManager.activeTransitPlan {
                if let ride = plan.ridePolyline {
                    MapPolyline(ride).stroke(Color(hex: plan.routeColorHex), lineWidth: 5)
                }
                Annotation(plan.boardStopName, coordinate: plan.boardCoordinate) {
                    PlacePin(category: .busStop)
                }
                Annotation(plan.alightStopName, coordinate: plan.alightCoordinate) {
                    PlacePin(category: .busStop)
                }
            }

            MapPlacesLayer(
                places: activePinCards,
                selectedID: selection.selectedPlace?.id,
                spanLatitude: mapVM.visibleSpanLatitude,
                onSelect: { place in
                    // Pin taps are inert while planning or navigating —
                    // the sheet is showing the route, not place details.
                    guard routeManager.stops.isEmpty,
                          routeManager.planningDestination == nil else { return }
                    selection.select(place)
                },
                onClusterTap: { members in
                    mapVM.zoomTo(members)
                }
            )
    }

    var body: some View {
        ZStack {
            Map(position: $mapVM.position, scope: mapScope) {
                mapContent
            }
            // Apple's attribution + our scale placement respond to the
            // MAP's own safe area — inset here, NOT on the container
            // (an outer inset skewed every bottom-anchored overlay).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 124)
            }
            // Clears the chip rail's row, so MapKit lays the
            // scale and compass out BELOW it instead of underneath.
            .safeAreaInset(edge: .top, spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 56)
            }
            // MapKit feeds scale + compass from the camera — external overlays
            // return "0" because they can't access camera data without a shared scope.
            // The compass is placed by hand in the top-right corner;
            // the scale keeps MapKit's own placement for live camera data.
            .mapControls {
                MapScaleView()
            }
            // .automatic hides the scale except mid-zoom, which reads as
            // a control that doesn't work.
            .mapControlVisibility(.visible)
            .mapStyle(currentMapStyle)
            .overlay(alignment: .topTrailing) {
                MapCompass(scope: mapScope)
                    .mapControlVisibility(.automatic)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .mapScope(mapScope)
            .onMapCameraChange(frequency: .onEnd) { context in
                mapVM.visibleSpanLatitude = context.region.span.latitudeDelta
            }
            .onChange(of: isLiveBusDataNeeded) { _, needed in
                busLiveManager.setInterest(.map, active: needed)
            }
            // A bus focused from the sheet's lists comes into view.
            .onChange(of: selection.focusedBusID) { _, busID in
                guard let busID,
                      let bus = busLiveManager.buses.first(where: { $0.vehicleID == busID })
                else { return }
                withAnimation {
                    mapVM.position = .region(MKCoordinateRegion(
                        center: bus.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)))
                }
            }
            .onChange(of: mapVM.showBusRoutes) { _, showing in
                // The popover shouldn't outlive its marker on the map.
                if !showing {
                    selectedBusID = nil
                }
            }
            .onChange(of: mapVM.locationManager.lastLocation?.timestamp) { _, _ in
                guard let location = mapVM.locationManager.lastLocation else { return }
                if routeManager.isNavigating {
                    Task {
                        await routeManager.updateNavigationProgress(
                            location: location,
                            liveBuses: busLiveManager.buses,
                            busRoutes: busRoutes,
                            stopEstimates: busLiveManager.stopEstimates)
                    }
                    if !isNavCameraOverridden {
                        mapVM.followNavigationCamera(at: location)
                    }
                }
            }
            .onChange(of: routeManager.planningDestination?.id) { _, planning in
                guard planning != nil else { return }
                selectedBusID = nil
                withAnimation {
                    sheetState.detent = .medium
                }
            }
            .onChange(of: routeManager.isNavigating) { _, navigating in
                if navigating {
                    selection.select(nil)
                    isNavCameraOverridden = false
                    withAnimation {
                        // The maneuver card lives on the map; the sheet
                        // rests at the ETA bar unless bus legs need room.
                        sheetState.detent = routeManager.activeTransitPlan == nil ? .collapsed : .medium
                    }
                    if let location = mapVM.locationManager.lastLocation {
                        mapVM.followNavigationCamera(at: location)
                    }
                } else {
                    isNavCameraOverridden = false
                    // Route over -> back to rest (tab bar returns).
                    withAnimation {
                        sheetState.detent = .collapsed
                    }
                    withAnimation {
                        mapVM.position = .userLocation(fallback: .automatic)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in
                        if routeManager.isNavigating {
                            isNavCameraOverridden = true
                        }
                    }
            )
            // Interest tracks the view's lifecycle so leaving the Map tab
            // (or sign-out) releases the map's claim on the shared poller;
            // the home card's own interest, if any, keeps it alive.
            .onAppear {
                busLiveManager.setInterest(.map, active: isLiveBusDataNeeded)
                if let card = pendingStop {
                    pendingStop = nil
                    selection.select(card)
                }
            }
            .onDisappear {
                busLiveManager.setInterest(.map, active: false)
            }
            // Home's Next Bus card hands a stop across the tab switch.
            .onChange(of: pendingStop?.id) { _, newValue in
                guard newValue != nil, let card = pendingStop,
                      routeManager.stops.isEmpty,
                      routeManager.planningDestination == nil else { return }
                pendingStop = nil
                // Pop any pushed screen so the stop shows on the MAP,
                // not behind Capacities.
                isShowingCapacities = false
                withAnimation {
                    sheetState.detent = .medium
                }
                // Next runloop so the sheet's onChange observers see it.
                Task { @MainActor in
                    selection.select(card)
                }
            }
            MapTopOverlaysView(
                transitChip: selectedBus == nil ? transitChip : nil
            )
            
            AlertTracker(busLiveManager: busLiveManager, busRoutes: busRoutes)

            // Inside the keyboard-ignoring stack, so the keyboard never
            // resizes the sheet: it rises over the sheet's lower part, as
            // in Apple Maps, and results stay visible above it. Drawn
            // under the rail, the floating buttons and the system tab bar.
            MapBottomSheet(state: sheetState) {
                panelSheetContent
            }
        }
        .ignoresSafeArea(.keyboard)
        // Lives at map level, NOT on the sheet content — a selection made
        // while the sheet is dismissed (pin tap, Home handoff) must still
        // move the camera and record the recent.
        .onChange(of: selection.selectedPlace?.id) { _, newValue in
            guard newValue != nil, let place = selection.selectedPlace,
                  let coordinate = place.coordinate else { return }
            // A selected place takes over the map — drop bus focus mode
            // and its popover so they don't linger behind the card.
            selectedBusID = nil
            RecentsService.shared.record(place)
            withAnimation {
                sheetState.detent = .medium
                mapVM.position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                )
            }
        }
        // Figma map frames: the chip rail pins under the status bar;
        // while a bus is focused, its route capsule takes that spot.
        .overlay(alignment: .top) {
            ZStack(alignment: .topLeading) {
                if let routeID = selectedBus?.routeID ?? selection.focusedBusRouteID,
                   !isRouteFocused {
                    focusedRouteCapsule(routeID: routeID)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if !isRouteFocused {
                    chipRail
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: selectedBus?.routeID ?? selection.focusedBusRouteID)
            .animation(.easeInOut(duration: 0.2), value: isRouteFocused)
            // Steps aside while the keyboard is up, as in Apple Maps.
            .opacity(sheetState.isKeyboardRaised ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: sheetState.isKeyboardRaised)
        }
        // Figma "Navigation": the maneuver card floats over the map top.
        .overlay(alignment: .top) {
            if routeManager.isNavigating {
                NavigationInstructionCard()
                    .environment(routeManager)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: routeManager.isNavigating)
        // Bus and locate buttons stack on the right, riding just above
        // the sheet edge through drags (Figma "Map"); they step aside
        // once the sheet is tall enough to crowd the top rail.
        .overlay(alignment: .bottomTrailing) {
            MapSheetRidingButtons(state: sheetState) {
                floatingMapButtons
                    .padding(.trailing, 16)
            }
            .ignoresSafeArea(.keyboard)
        }
        // No navigation bar over the map (#R4-14): its (transparent) bar
        // inflated the top safe area, doubling MapKit's fade band under
        // the status bar. The hamburger floats instead.
        .toolbar(isNavigationBarHidden ? .hidden : .visible, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingCapacities) {
            CapacitiesView(initialFilterID: capacitiesFilterID)
                // The map hides the bar; pushed screens need theirs back.
                .toolbar(.visible, for: .navigationBar)
        }
    }
    
    private var panelSheetContent: some View {
        MapSheetView(
            sheetDetent: $sheetState.detent,
            isShowingFavorites: $isShowingFavorites,
            categoryRequest: categoryRequest,
            searchableData: searchableData,
            isBusLayerOn: mapVM.showBusRoutes,
            searchActivationToken: searchActivationToken,
            diningActivationToken: diningActivationToken,
            onSearchActivated: { searchActivationToken = 0 },
            onOpenCapacities: { capacityID in
                selection.select(nil)
                capacitiesFilterID = capacityID
                isShowingCapacities = true
            }
        )
        .environment(routeManager)
        .environment(selection)
    }

    private var chipRail: some View {
        MapChipRailView(
            selection: selection,
            isShowingFavorites: isShowingFavoritesList,
            onToggleFavorites: toggleFavoritesList,
            onSelectCategory: { categoryRequest = MapCategoryRequest(category: $0) }
        )
    }

    private var floatingMapButtons: some View {
        VStack(spacing: 10) {
            if !isRouteFocused {
                GTCapsuleButton(
                    icon: "bus.fill",
                    label: mapVM.showBusRoutes ? "Hide bus routes" : "Show bus routes",
                    style: mapVM.showBusRoutes ? .selected : .standard
                ) {
                    withAnimation {
                        mapVM.showBusRoutes.toggle()
                    }
                }
                .accessibilityAddTraits(mapVM.showBusRoutes ? .isSelected : [])
            }

            GTCapsuleButton(
                icon: isFollowingUser ? "location.fill" : "location",
                label: "Center on my location",
                action: locateAction
            )
        }
        .controlSize(.small)
    }

    /// Figma "specific route": the focused bus's route as a capsule in
    /// its own color, top left.
    private func focusedRouteCapsule(routeID: Int) -> some View {
        let route = busRoutes.first { $0.routeID == routeID }
        let tint = route.map { Color(hex: $0.mapColor) } ?? Color.gtNavy
        return Button {
            withAnimation {
                selection.focusedBusID = nil
                selection.focusedBusRouteID = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 14))
                Text("\(route?.name ?? "Bus") Route")
                    .font(.gtHeading5)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.gtWhite)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(tint, in: .capsule)
            .shadow(color: Color.gtOverlay1, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route?.name ?? "Bus") route focused")
        .accessibilityHint("Shows all routes again")
    }

    /// Off while a place card opened from the list covers it.
    private var isShowingFavoritesList: Bool {
        isShowingFavorites && selection.selectedPlace == nil
    }

    private func toggleFavoritesList() {
        withAnimation {
            if isShowingFavoritesList {
                isShowingFavorites = false
            } else if isShowingFavorites {
                // A card is open over the list: go back to it.
                selection.select(nil)
                sheetState.detent = .expanded
            } else {
                isShowingFavorites = true
            }
        }
    }

    private func locateAction() {
        if routeManager.isNavigating {
            isNavCameraOverridden = false
            if let location = mapVM.locationManager.lastLocation {
                mapVM.followNavigationCamera(at: location)
            }
        } else {
            withAnimation {
                mapVM.position = .userLocation(fallback: .automatic)
            }
        }
    }

    /// Filled locate icon = camera locked to the user, either via the
    /// system follow mode or navigation's follow camera.
    private var isFollowingUser: Bool {
        mapVM.position.followsUserLocation
            || (routeManager.isNavigating && !isNavCameraOverridden)
    }
    
    /// A hidden view that isolates the notification tracking logic so MapView compiles cleanly.
    /// Uses the existing 30-second bus poller to fetch capacity data in the background without creating a second loop.
    private struct AlertTracker: View {
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.modelContext) private var modelContext
        @Query private var capacities: [BuildingCapacity]
        @Query private var restaurants: [Restaurant]
        let busLiveManager: BusLiveManager
        let busRoutes: [BusRoute]
        private var hasBusWatches: Bool {
            AlertWatchService.shared.hasBusWatches
        }
        private var hasCapacityWatches: Bool {
            AlertWatchService.shared.hasCapacityWatches
        }
        private var hasAnyWatches: Bool {
            hasBusWatches || hasCapacityWatches
        }

        var body: some View {
            Color.clear
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        evaluateBusWatches()
                        if hasCapacityWatches {
                            Task { await GTDataService.shared.loadCapacities(context: modelContext) }
                        }
                        Task {
                            await AlertWatchService.shared.refreshDiningOpenWatches(restaurants: restaurants)
                            await AlertWatchService.shared.refreshFavoriteMenuDigest(restaurants: restaurants)
                        }
                    }
                }
                // Uses the bus manager's 30-second background tick to fetch capacities
                .onChange(of: busLiveManager.lastUpdated) { _, _ in
                    evaluateBusWatches()
                    if hasCapacityWatches {
                        Task { await GTDataService.shared.loadCapacities(context: modelContext) }
                    }
                }
                // When the network fetch finishes, the @Query updates and triggers evaluation
                .onChange(of: capacities) { _, newCapacities in
                    Task { await AlertWatchService.shared.refreshCapacityWatches(capacities: newCapacities) }
                }
                .onChange(of: hasAnyWatches) { _, active in
                    busLiveManager.setInterest(.alerts, active: active, interval: .seconds(30))
                }
                .onAppear {
                    busLiveManager.setInterest(.alerts, active: hasAnyWatches, interval: .seconds(30))
                }
        }
        private func evaluateBusWatches() {
            Task {
                await AlertWatchService.shared.refreshBusWatches(
                    estimates: busLiveManager.stopEstimates,
                    routes: busRoutes
                )
            }
        }
    }
}
