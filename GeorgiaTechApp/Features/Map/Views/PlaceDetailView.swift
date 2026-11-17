//
//  PlaceDetailView.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftUI

/// The one detail card for every place on the map. Category-specific
/// sections (hours, payments, appliance info) branch on `place.category`
/// — never make a separate detail view for a new place type.
struct PlaceDetailView: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(\.colorScheme) private var colorScheme

    let place: SearchCardModel
    let searchableData: SearchableData
    let onClose: () -> Void
    /// Opens the capacities screen filtered to this building (#8).
    var onOpenCapacities: (Int?) -> Void = { _ in }

    @State private var walkingETA: TimeInterval?
    @State private var selectedMenuIndex = 0
    @State private var selectedMenuDate: Date?
    @State private var selectedFilterIDs: Set<String> = []
    // Quick-action overflow hint (#U4): fade an edge only while more
    // chips are actually off-screen in that direction.
    @State private var actionsOverflowLeading = false
    @State private var actionsOverflowTrailing = false

    private var restaurant: Restaurant? {
        guard place.category == .dining else { return nil }
        return searchableData.restaurants.first { $0.restaurantID == place.id }
    }

    private var campusLocation: CampusLocation? {
        guard place.category == .building || place.category == .parking else { return nil }
        return searchableData.locations.first { $0.locationId == place.id }
    }

    /// Live occupancy for this building, when the capacity feed covers it.
    /// Exact name match, or a single unambiguous feed entry containing the
    /// building's name — never a guess that could show another building's
    /// numbers as this one's.
    private var buildingCapacity: BuildingCapacity? {
        guard place.category == .building else { return nil }
        let name = place.title.lowercased()

        if let exact = searchableData.capacities.first(where: { $0.name.lowercased() == name }) {
            return exact
        }
        let containing = searchableData.capacities.filter {
            $0.name.lowercased().contains(name)
        }
        return containing.count == 1 ? containing.first : nil
    }

    var body: some View {
        ScrollView {
            if let stop = busStop {
                // Figma "specific stop": a stop is its routes and buses,
                // not a photo and quick actions.
                BusStopSection(
                    place: place, stop: stop,
                    searchableData: searchableData, onClose: onClose
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            } else {
                placeContent
            }
        }
        .task(id: place.id) {
            await calculateWalkingETA()
        }
    }

    private var placeContent: some View {
            VStack(alignment: .leading, spacing: 20) {
                PlaceDetailHero(
                    place: place, statusText: heroStatusText,
                    isOpen: isOpenNow, onClose: onClose
                )

                quickActions
                statStrip
                acceptsSection
                capacityLink
                hoursSection
                menuSection
                detailsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
    }

    // MARK: - Open / closed line for the hero

    /// Only places with real hours get a badge — nil keeps the hero from
    /// implying a bus stop or a printer is "closed".
    private var heroStatusText: String? {
        guard let hours = restaurant?.hoursOpen else { return nil }
        return DiningHours.statusText(for: hours)
    }

    private var isOpenNow: Bool {
        guard let hours = restaurant?.hoursOpen else { return false }
        return DiningHours.isOpenNow(hours)
    }

    // MARK: - Capacity link

    @ViewBuilder
    private var capacityLink: some View {
        if let capacity = buildingCapacity {
            Button {
                onOpenCapacities(capacity.capacityID)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .font(.gtBody2)
                        .foregroundStyle(Color.gtPrimaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Occupancy")
                            .font(.gtHeading5)
                            .foregroundStyle(Color.gtPrimaryText)
                        Text(capacity.isOpen
                             ? "\(Int(capacity.percentage * 100))% full right now"
                             : "Closed right now")
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtSecondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtSecondaryText)
                }
                .gtCard(radius: 16, padding: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(capacity.isOpen
                ? "Live occupancy, \(Int(capacity.percentage * 100)) percent full. Opens capacities."
                : "Live occupancy, closed. Opens capacities.")
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                directionsChip

                favoriteChip
                
                if let restaurant { DiningOpenAlertChip(restaurant: restaurant) }

                if let websiteString = restaurant?.website,
                   let url = URL(string: websiteString) {
                    ExternalLinkButton(url: url) {
                        actionChipLabel("Website", systemImage: "safari")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open website for \(place.title)")
                }

                if ReportIssue.isConfigured, let mailURL = ReportIssue.mailURL(for: place) {
                    ExternalLinkButton(url: mailURL) {
                        actionChipLabel("Report an Issue", systemImage: "exclamationmark.bubble")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Report an issue with \(place.title)")
                }
            }
        }
        .mapSheetHorizontalScroll()
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.x + geometry.contentInsets.leading > 4
        } action: { _, canScrollBack in
            withAnimation(.easeInOut(duration: 0.15)) {
                actionsOverflowLeading = canScrollBack
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.x + geometry.containerSize.width
                < geometry.contentSize.width - 4
        } action: { _, canScrollAhead in
            withAnimation(.easeInOut(duration: 0.15)) {
                actionsOverflowTrailing = canScrollAhead
            }
        }
        .mask(actionsFadeMask)
    }

    /// Alpha mask: opaque center, transparent ramp on whichever edge has
    /// off-screen chips — hints the cut-off chip (e.g. Call) instead of
    /// clipping it silently.
    private var actionsFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.gtNavy.opacity(actionsOverflowLeading ? 0 : 1),
                    Color.gtNavy
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 24)
            Color.gtNavy
            LinearGradient(
                colors: [
                    Color.gtNavy,
                    Color.gtNavy.opacity(actionsOverflowTrailing ? 0 : 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 24)
        }
    }

    private var favoriteChip: some View {
        let isFavorite = FavoritesService.shared.isFavorite(place.id)
        return Button {
            FavoritesService.shared.toggle(place)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(colorScheme == .dark ? Color.gtGold : Color.gtDarkGold)
                Text(isFavorite ? "Saved" : "Save")
                    .foregroundStyle(Color.gtPrimaryText)
            }
            .font(.gtHeading5)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove \(place.title) from favorites" : "Save \(place.title) to favorites")
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
    }

    private var directionsChip: some View {
        Button {
            routeManager.requestDirections(to: place)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                if let walkingETA {
                    Text(formattedTime(walkingETA))
                } else {
                    Text("Directions")
                }
            }
            .font(.gtHeading5)
            .foregroundStyle(Color.gtNavy)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.gtGold, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(place.destination == nil)
        .accessibilityLabel("Get directions to \(place.title)")
    }

    private func actionChipLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.gtHeading5)
        .foregroundStyle(Color.gtPrimaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Filter-pill language, not glass — glass draws a drop shadow
        // that reads as a smudge on the light-mode sheet (#R3-5).
        .background {
            Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
        }
    }

    // MARK: - Stat Strip

    private struct StatItem: Identifiable {
        let id: String
        let label: String
        let value: String
        var valueColor: Color = Color.gtPrimaryText
        var lineLimit = 1
    }

    private var statItems: [StatItem] {
        // Open/closed is deliberately absent: the hero badge above owns
        // it, and repeating it here said the same thing twice.
        var items: [StatItem] = []
        if let distanceText {
            items.append(StatItem(id: "distance", label: "Distance", value: distanceText))
        }
        // Capacity deliberately absent — the Live Occupancy row below the
        // chips is the single surface for it (#R4-3).
        if let campusLocation, place.category == .building {
            items.append(StatItem(id: "type", label: "Type", value: campusLocation.type.humanized))
        }
        return items
    }

    // MARK: - Accepted payments (dining) — roomy chips, not a cramped column

    @ViewBuilder
    private var acceptsSection: some View {
        if let restaurant, !restaurant.paymentMethodsAccepted.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                GTSectionHeader("Accepts")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(restaurant.paymentMethodsAccepted, id: \.self) { method in
                            HStack(spacing: 5) {
                                Image(systemName: "creditcard")
                                    .font(.gtBody3)
                                Text(method.humanized)
                                    .font(.gtHeading6)
                            }
                            .foregroundStyle(Color.gtPrimaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.gtGold.opacity(0.18), in: .capsule)
                            .overlay {
                                Capsule().strokeBorder(Color.gtGold.opacity(0.45), lineWidth: 1)
                            }
                        }
                    }
                }
                .mapSheetHorizontalScroll()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Accepts \(restaurant.paymentMethodsAccepted.map(\.humanized).joined(separator: ", "))")
        }
    }

    @ViewBuilder
    private var statStrip: some View {
        let items = statItems
        if !items.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        statDivider
                    }
                    statColumn(
                        label: item.label, value: item.value,
                        valueColor: item.valueColor, lineLimit: item.lineLimit
                    )
                }
            }
            .padding(.vertical, 12)
            .gtCard(radius: 18, padding: 0)
        }
    }

    private func statColumn(
        label: String, value: String, valueColor: Color = Color.gtPrimaryText, lineLimit: Int = 1
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.gtHeading6)
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(Color.gtSecondaryText)
            Text(value)
                .font(.gtHeading4)
                .textCase(.uppercase)
                .foregroundStyle(valueColor)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.gtSecondaryText.opacity(0.25))
            .frame(width: 1, height: 28)
    }

    // MARK: - Hours

    @ViewBuilder
    private var hoursSection: some View {
        if let restaurant, let hours = restaurant.hoursOpen {
            VStack(alignment: .leading, spacing: 8) {
                GTSectionHeader("Hours")

                Text(DiningHours.statusText(for: hours))
                    .font(.gtHeading5)
                    .foregroundStyle(DiningHours.isOpenNow(hours) ? Color.gtTechLawn : Color.gtAzalea)

                DisclosureGroup("Weekly Hours") {
                    VStack(spacing: 6) {
                        ForEach(DiningHours.weeklyRows(for: hours), id: \.day) { row in
                            HStack {
                                Text(row.day)
                                    .foregroundStyle(Color.gtPrimaryText)
                                Spacer()
                                Text(row.text)
                                    .foregroundStyle(Color.gtSecondaryText)
                            }
                            .font(.gtBody2)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.gtBody2)
                .tint(Color.gtSecondaryText)
            }
        }
    }

    // MARK: - Menu (dining only)

    @ViewBuilder
    private var menuSection: some View {
        if let restaurant, !restaurant.menus.isEmpty {
            PlaceMenuSection(
                restaurant: restaurant,
                dietaryFilters: searchableData.dietaryFilters,
                selectedMenuIndex: $selectedMenuIndex,
                selectedFilterIDs: $selectedFilterIDs,
                selectedMenuDate: $selectedMenuDate
            )
        }
    }

    // MARK: - Bus stop (its own section, BusStopSection)

    private var busStop: BusStop? {
        guard place.category == .busStop,
              let idText = place.id.split(separator: "-").last,
              let routeStopID = Int(idText)
        else { return nil }
        return searchableData.busRoutes
            .flatMap(\.stops)
            .first { $0.routeStopID == routeStopID }
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsSection: some View {
        let text = campusLocation?.details ?? (place.category.isAppliance ? place.subtitle : nil)
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                GTSectionHeader("Details")
                Text(text)
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
            }
        }
    }

    // MARK: - Distance / ETA

    private var distanceText: String? {
        DistanceFormat.text(from: searchableData.userLocation, to: place.coordinate)
    }

    private func calculateWalkingETA() async {
        guard let stop = place.destination else { return }
        walkingETA = nil

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = stop.mapItem
        request.transportType = .walking

        let route = try? await MKDirections(request: request).calculate().routes.first
        // .task(id:) cancels this on place change — don't let a stale
        // calculation overwrite the newly selected place's ETA.
        guard !Task.isCancelled else { return }
        walkingETA = route?.expectedTravelTime
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let minutes = max(Int(seconds) / 60, 1)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

extension LocationCategory {
    var isAppliance: Bool {
        self == .printer || self == .microwave || self == .vending
    }
}
