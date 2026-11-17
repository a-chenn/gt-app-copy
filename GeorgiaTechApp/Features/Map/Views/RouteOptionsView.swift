//
//  RouteOptionsView.swift
//  GeorgiaTechApp
//

import CoreLocation
import MapKit
import SwiftUI

/// Route planning as main-sheet content (never a second sheet):
/// From/To header, mode selector with live ETAs, then the route options
/// for the chosen mode — Suggested first, alternates below, Go per row.
struct RouteOptionsView: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var routingVM: RoutingVM

    private enum EndpointField {
        case origin
        case destination
    }

    @State private var editingEndpoint: EndpointField?
    @State private var isConfirmingAppleMaps = false

    private let searchableData: SearchableData

    init(destination: SearchCardModel, searchableData: SearchableData) {
        self.searchableData = searchableData
        _routingVM = State(initialValue: RoutingVM(
            destination: destination,
            busRoutes: searchableData.busRoutes,
            userLocation: searchableData.userLocation))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                fromToCard
                header

                if let field = editingEndpoint {
                    RouteEndpointSearchView(
                        isEditingOrigin: field == .origin,
                        showsMyLocation: field == .origin && routingVM.origin != nil,
                        searchableData: searchableData,
                        onChoose: { chooseEndpoint($0) },
                        onCancel: { editingEndpoint = nil }
                    )
                    .id(field)
                }

                modeSelector

                if routingVM.selectedMode == .transit {
                    transitOptionCard
                } else {
                    routeOptionRows
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.2), value: editingEndpoint)
        }
        .alert("Open Apple Maps?", isPresented: $isConfirmingAppleMaps) {
            Button("Open") { routingVM.openInAppleMaps() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This leaves the app and opens Apple Maps.")
        }
        .onChange(of: searchableData.userLocation?.latitude) { _, _ in
            routingVM.refreshUserLocation(searchableData.userLocation)
        }
        .task {
            await routingVM.calculateAllModes()
            publishPreview()
        }
        .onChange(of: routingVM.selectedMode) { _, _ in
            publishPreview()
        }
        .onChange(of: routingVM.selectedRouteIndex) { _, _ in
            publishPreview()
        }
        .onDisappear {
            // Only when planning actually ended (Go/cancel) — the sidebar
            // can hide the sheet mid-planning, and the previewed route
            // must stay on the map behind it. beginNavigation clears its
            // own previews, so navigation never double-strokes.
            if routeManager.planningDestination == nil {
                routeManager.previewRoutes = []
            }
        }
    }

    /// All of the selected mode's routes go on the map — the chosen one
    /// full-strength, alternates dimmed (#21).
    private func publishPreview() {
        routeManager.previewRoutes = routingVM.routeAlternatives[routingVM.selectedMode] ?? []
        routeManager.previewSelectedIndex = routingVM.selectedRouteIndex
        routeManager.previewTransportMode = routingVM.selectedMode
    }

    // MARK: - Header

    /// Figma: "‹ Place name" in Roboto Slab, its address and hours, and
    /// the external-maps arrow.
    private var header: some View {
        let destination = routingVM.destination
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                SheetBackHeader(
                    title: destination.title,
                    onBack: { routeManager.cancelPlanning() }
                )

                VStack(alignment: .leading, spacing: 2) {
                    if let subtitle = destination.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtSecondaryText)
                            .lineLimit(2)
                    }
                    if let hours = destinationHours {
                        Text(DiningHours.statusText(for: hours))
                            .font(.gtHeading6)
                            .foregroundStyle(DiningHours.isOpenNow(hours) ? Color.gtTechLawn : Color.gtRed)
                    }
                }
                .padding(.leading, 34)
            }

            Button {
                isConfirmingAppleMaps = true
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gtPrimaryText)
                    .frame(width: 40, height: 40)
                    .background(colorScheme == .dark ? Color.gtWhite.opacity(0.12) : Color.gtGray1, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open in Apple Maps")
        }
    }

    private var destinationHours: [[String]]? {
        guard routingVM.destination.category == .dining else { return nil }
        return searchableData.restaurants
            .first { $0.restaurantID == routingVM.destination.id }?.hoursOpen
    }

    /// Both endpoints are editable (#10): tap a row to search for a new
    /// place, or swap the two.
    private var fromToCard: some View {
        HStack(spacing: 10) {
            VStack(spacing: 10) {
                endpointRow(.origin)
                Divider()
                endpointRow(.destination)
            }

            Button {
                Task {
                    await routingVM.swapEndpoints()
                    publishPreview()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.gtSecondaryText.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!routingVM.canSwapEndpoints)
            .opacity(routingVM.canSwapEndpoints ? 1 : 0.4)
            .accessibilityLabel("Swap starting point and destination")
        }
        .gtCard(radius: 14, padding: 12)
    }

    private func endpointRow(_ field: EndpointField) -> some View {
        let isOrigin = field == .origin
        let name = isOrigin ? routingVM.originName : routingVM.destination.title

        return Button {
            editingEndpoint = field
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(isOrigin ? Color.gtBrightBlue : Color.gtGold)
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtPrimaryText)
                    // Wrap rather than clip — "The destinati…" reads like
                    // a typo, not a truncation.
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "pencil")
                    .font(.gtBody3)
                    .foregroundStyle(
                        // gtGold on light glass fails contrast — primary
                        // carries the active state in both appearances.
                        editingEndpoint == field ? Color.gtPrimaryText : Color.gtSecondaryText.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(isOrigin ? "Starting point" : "Destination"): \(name)")
        .accessibilityHint("Tap to choose a different place")
    }

    // MARK: - Endpoint search (#10)

    private func chooseEndpoint(_ card: SearchCardModel?) {
        guard let field = editingEndpoint else { return }
        editingEndpoint = nil
        Task {
            switch field {
            case .origin:
                await routingVM.updateOrigin(card?.destination)
            case .destination:
                guard let card else { return }
                await routingVM.updateDestination(card)
            }
            publishPreview()
        }
    }

    // MARK: - Mode selector

    /// Figma segmented control: walk, bus, bike, car in a gray track, the
    /// chosen mode in a white pill. ETAs ride on each route card instead.
    private static let modeOrder: [RouteTransportMode] = [.walking, .transit, .biking, .driving]

    private var modeSelector: some View {
        HStack(spacing: 4) {
            ForEach(Self.modeOrder, id: \.self) { mode in
                modeButton(mode)
            }
        }
        .padding(4)
        .background(colorScheme == .dark ? Color.gtWhite.opacity(0.12) : Color.gtGray1, in: .capsule)
    }

    private func modeButton(_ mode: RouteTransportMode) -> some View {
        let isSelected = routingVM.selectedMode == mode
        let option = routingVM.routeOptions[mode]

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                routingVM.selectedMode = mode
                routingVM.selectedRouteIndex = 0
            }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.gtPrimaryText : Color.gtSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.gtMediumNavy : Color.gtWhite)
                            .shadow(color: Color.gtOverlay1, radius: 3, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(modeAccessibilityLabel(mode, option: option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func modeAccessibilityLabel(_ mode: RouteTransportMode, option: RouteOption?) -> String {
        guard let option else { return "\(mode.label), unavailable" }
        return "\(mode.label), \(RouteNavigation.durationText(seconds: option.time))"
    }

    // MARK: - Route options (walk/bike/drive)

    @ViewBuilder
    private var routeOptionRows: some View {
        let routes = routingVM.routeAlternatives[routingVM.selectedMode] ?? []

        if routes.isEmpty && routingVM.isCalculating {
            ProgressView("Finding routes…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if routes.isEmpty {
            Text("No route available for this mode.")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                    routeRow(route, index: index)
                }
            }
        }
    }

    /// Figma route card: "Suggested" over "13 min · 5:37 PM ETA" and a Go
    /// capsule — navy for the chosen route, gold for the alternates.
    private func routeRow(_ route: MKRoute, index: Int) -> some View {
        let isSelected = index == routingVM.selectedRouteIndex
        let duration = RouteNavigation.durationText(seconds: route.expectedTravelTime)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if index == 0 {
                    Text("Suggested")
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtPrimaryText)
                }
                durationLine(seconds: route.expectedTravelTime)
                Text(DistanceFormat.text(meters: route.distance))
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            }

            Spacer()

            goButton(isPrimary: isSelected, label: "Start this \(duration) route") {
                routingVM.selectedRouteIndex = index
                routingVM.startNavigation(via: routeManager)
            }
        }
        .gtCard(radius: 14, padding: 14)
        .overlay {
            if isSelected && (routingVM.routeAlternatives[routingVM.selectedMode]?.count ?? 0) > 1 {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gtNavy.opacity(colorScheme == .dark ? 0 : 0.35), lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            routingVM.selectedRouteIndex = index
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel("Route option: \(duration), \(DistanceFormat.text(meters: route.distance))")
        .accessibilityAction(named: "Select this route") {
            routingVM.selectedRouteIndex = index
        }
    }

    /// "13 min · 5:37 PM ETA" — the duration in Roboto Slab.
    private func durationLine(seconds: TimeInterval) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(RouteNavigation.durationText(seconds: seconds))
                .font(.gtHeading3)
                .foregroundStyle(Color.gtPrimaryText)
            Text("· \(Date.now.addingTimeInterval(seconds).formatted(date: .omitted, time: .shortened)) ETA")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
        }
    }

    private func goButton(isPrimary: Bool, label: String, action: @escaping () -> Void) -> some View {
        GTCapsuleButton(
            "Go", trailingIcon: "chevron.right",
            style: isPrimary ? .selected : .highlight, action: action
        )
        .controlSize(.small)
        .accessibilityLabel(label)
    }

    // MARK: - Transit option

    @ViewBuilder
    private var transitOptionCard: some View {
        if let plan = routingVM.transitPlan {
            VStack(alignment: .leading, spacing: 10) {
                if routingVM.isWalkingFasterThanBus,
                   let walk = routingVM.routeAlternatives[.walking]?.first {
                    walkingBanner(walkSeconds: walk.expectedTravelTime)
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Suggested")
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtPrimaryText)
                        durationLine(seconds: plan.totalSeconds)
                        transitLegChips(plan)
                    }
                    Spacer(minLength: 0)
                    goButton(isPrimary: true, label: "Start bus route via \(plan.routeName)") {
                        routingVM.startNavigation(via: routeManager)
                    }
                }
                .gtCard(radius: 14, padding: 14)
            }
        } else if routingVM.isCalculating {
            ProgressView("Checking live buses…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if routingVM.isWalkingFasterThanBus,
                  let walk = routingVM.routeAlternatives[.walking]?.first {
            walkingFasterCard(walk)
        } else {
            Text("No bus can serve this trip right now.")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
                .padding(.vertical, 20)
        }
    }

    /// Figma: "🚶 3 min › [🚌 Red • 3 stops] › 🚶 7 min".
    private func transitLegChips(_ plan: TransitPlan) -> some View {
        let tint = Color(hex: plan.routeColorHex)
        let stops = stopCount(plan)
        return HStack(spacing: 4) {
            legChip(icon: "figure.walk", text: BusArrivals.minutesText(Int(plan.walkToStop.expectedTravelTime)),
                    fill: Color.gtSecondaryText.opacity(0.15), foreground: Color.gtPrimaryText)
            chevron
            legChip(icon: "bus.fill",
                    text: stops.map { "\(plan.routeName) • \($0) stop\($0 == 1 ? "" : "s")" } ?? plan.routeName,
                    fill: tint.opacity(0.18), foreground: Color.gtPrimaryText, stroke: tint)
            chevron
            legChip(icon: "figure.walk", text: BusArrivals.minutesText(Int(plan.walkToDestination.expectedTravelTime)),
                    fill: Color.gtSecondaryText.opacity(0.15), foreground: Color.gtPrimaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Walk to \(plan.boardStopName), ride \(plan.routeName) to \(plan.alightStopName), then walk")
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.gtSecondaryText)
    }

    private func legChip(icon: String, text: String, fill: Color, foreground: Color, stroke: Color? = nil) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.gtBody4)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(fill, in: .capsule)
        .overlay {
            if let stroke {
                Capsule().strokeBorder(stroke, lineWidth: 1)
            }
        }
    }

    /// Stops ridden, from the route's stop order.
    private func stopCount(_ plan: TransitPlan) -> Int? {
        guard let route = searchableData.busRoutes.first(where: { $0.routeID == plan.routeID }) else { return nil }
        let stops = route.stops.sorted { $0.stopOrder < $1.stopOrder }
        guard let board = stops.firstIndex(where: { $0.routeStopID == plan.boardRouteStopID }),
              let alight = stops.firstIndex(where: { $0.routeStopID == plan.alightRouteStopID })
        else { return nil }
        let hops = (alight - board + stops.count) % stops.count
        return hops > 0 ? hops : nil
    }

    /// Figma bus banner: "💡 Walking may be faster", gold.
    private func walkingBanner(walkSeconds: TimeInterval) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb")
            Text("Walking may be faster")
            Spacer(minLength: 0)
            Image(systemName: "figure.walk")
            Text(BusArrivals.minutesText(Int(walkSeconds)))
        }
        .font(.gtHeading6)
        .foregroundStyle(Color.gtNavy)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.gtGold, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    /// Bus mode when every bus plan loses to the direct walk (#R3-4):
    /// the banner, then the walk as the one card, one tap to start it.
    private func walkingFasterCard(_ walk: MKRoute) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            walkingBanner(walkSeconds: walk.expectedTravelTime)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk instead")
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtPrimaryText)
                    durationLine(seconds: walk.expectedTravelTime)
                    Text("No bus beats the direct walk right now.")
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                }
                Spacer(minLength: 0)
                goButton(isPrimary: true, label: "Start the walking route instead") {
                    routingVM.startWalkingInstead(via: routeManager)
                }
            }
            .gtCard(radius: 14, padding: 14)
        }
    }
}
