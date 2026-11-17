//
//  RestingSheetView.swift
//  GeorgiaTechApp
//

import CoreLocation
import SwiftUI

/// The sheet's default state before any search (Figma "Map swipe up"):
/// Recents with View All, the Amenities tiles, and Suggested places.
/// With the bus layer on it becomes the route list (Figma "Main bus").
/// Owns its own scrolling — never nest it in a ScrollView (the bus
/// route `List` would collapse to zero height).
struct RestingSheetView: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(MapSelection.self) private var selection
    @Environment(\.colorScheme) private var colorScheme

    let searchableData: SearchableData
    let searchVM: SearchVM
    var isBusLayerOn = false
    /// The search field is focused (Figma "Academic building card"):
    /// Suggested replaces the Amenities tiles.
    var isSearchFocused = false
    let onShowAllRecents: () -> Void
    var onSelectCategory: (SearchCategories) -> Void = { _ in }

    /// The recent row showing its Directions button (Figma card state).
    @State private var expandedRecentID: String?
    @State private var isShowingMoreSuggested = false

    var body: some View {
        if isBusLayerOn {
            BusRoutesSheetList(routes: searchableData.busRoutes)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    recentsSection
                    if !isSearchFocused {
                        amenitiesSection
                    }
                    suggestedSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.2), value: expandedRecentID)
                .animation(.easeInOut(duration: 0.2), value: isShowingMoreSuggested)
            }
        }
    }

    // MARK: - Recents

    @ViewBuilder
    private var recentsSection: some View {
        let recents = Array(searchVM.topThree.prefix(2))
        if !recents.isEmpty {
            GTMicroLabel(text: "Recents")
                .padding(.top, 4)

            PlaceHeartCard(items: recents) { item in
                PlaceHeartRow(
                    item: item,
                    onTap: {
                        // First tap reveals Directions; a second opens
                        // the place card.
                        if expandedRecentID == item.id {
                            selection.select(item)
                        } else {
                            expandedRecentID = item.id
                        }
                    },
                    isExpanded: expandedRecentID == item.id,
                    onDirections: { routeManager.requestDirections(to: item) }
                )
                .contextMenu {
                    Button("Remove from Recents", systemImage: "trash", role: .destructive) {
                        searchVM.removeRecent(item)
                    }
                }
            }

            GTCapsuleButton(
                "View All", trailingIcon: "chevron.right", style: .highlight,
                isFullWidth: true, action: onShowAllRecents
            )
            .controlSize(.small)
            .accessibilityLabel("View all recents")
        }
    }

    // MARK: - Amenities

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GTMicroLabel(text: "Amenities")
                .padding(.top, 8)

            HStack(spacing: 12) {
                ForEach(SearchCategories.amenityCategories) { category in
                    Button {
                        onSelectCategory(category)
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorScheme == .dark ? Color.gtWhite.opacity(0.12) : Color.gtGray1)
                                .frame(height: 60)
                                .overlay {
                                    Image(systemName: category.systemImage)
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.gtPrimaryText)
                                }
                            Text(category.title)
                                .font(.gtHeading6)
                                .foregroundStyle(Color.gtPrimaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.title)
                    .accessibilityHint("Shows \(category.title.lowercased()) locations on the map")
                }
            }
        }
    }

    // MARK: - Suggested

    @ViewBuilder
    private var suggestedSection: some View {
        let suggested = suggestedPlaces
        if !suggested.isEmpty {
            GTMicroLabel(text: "Suggested")
                .padding(.top, 8)

            PlaceHeartCard(items: Array(suggested.prefix(isShowingMoreSuggested ? 8 : 2))) { item in
                PlaceHeartRow(item: item, onTap: { selection.select(item) })
            }

            if suggested.count > 2 {
                GTCapsuleButton(
                    isShowingMoreSuggested ? "View Less" : "View More",
                    trailingIcon: isShowingMoreSuggested ? "chevron.up" : "chevron.right",
                    style: .highlight, isFullWidth: true
                ) {
                    isShowingMoreSuggested.toggle()
                }
                .controlSize(.small)
            }
        }
    }

    /// Nearest campus places when location is known, else the popular
    /// anchors, with recents left out so the two lists don't repeat.
    private var suggestedPlaces: [SearchCardModel] {
        let recentIDs = Set(searchVM.topThree.map(\.id))
        let scope: MapPlaceScope = searchableData.userLocation == nil ? .popular : .nearby
        return scope.places(in: searchableData).filter { !recentIDs.contains($0.id) }
    }
}

// MARK: - Bus routes (Figma "Main bus")

/// Every route with its visibility check and drag handle. Hidden and
/// ordered routes persist in the same storage the map layer reads.
struct BusRoutesSheetList: View {
    let routes: [BusRoute]

    @AppStorage("hiddenBusRouteIDs") private var hiddenBusRouteIDsRaw = ""
    @AppStorage("busRouteOrderIDs") private var busRouteOrderIDsRaw = ""

    private var hiddenRouteIDs: Set<Int> {
        Set(hiddenBusRouteIDsRaw.split(separator: ",").compactMap { Int($0) })
    }

    var body: some View {
        let ordered = orderedRoutes
        // Edit mode + right-to-left puts the system drag handles on the
        // LEADING edge, as in the Figma; each row flips back to LTR.
        List {
            Section {
                ForEach(ordered) { route in
                    row(route)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: move)
            } header: {
                GTMicroLabel(
                    text: "\(ordered.filter(\.isRunning).count)/\(ordered.count) routes active")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.top, 4)
            }
        }
        .environment(\.editMode, .constant(.active))
        .environment(\.layoutDirection, .rightToLeft)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ route: BusRoute) -> some View {
        let isVisible = !hiddenRouteIDs.contains(route.routeID)
        let tint = Color(hex: route.mapColor)

        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    setRoute(route.routeID, visible: !isVisible)
                }
            } label: {
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.palette)
                    // An empty circle's only layer is its ring — gray it.
                    .foregroundStyle(isVisible ? Color.gtWhite : Color.gtGray2, isVisible ? tint : Color.gtGray2)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isVisible ? "Hide" : "Show") \(route.name) route")
            .accessibilityHint("Changes whether this route appears on the map")

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.gtHeading5)
                    .foregroundStyle(route.isRunning ? Color.gtPrimaryText : Color.gtSecondaryText)
                    .lineLimit(1)
                Text(route.isRunning ? "Running now" : "Not Running Now")
                    .font(.gtBody4)
                    .foregroundStyle(route.isRunning ? Color.gtSecondaryText : Color.gtRed)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
    }

    /// The user's saved order, then any new routes running-first, A–Z.
    private var orderedRoutes: [BusRoute] {
        let savedOrder = busRouteOrderIDsRaw.split(separator: ",").compactMap { Int($0) }
        let orderIndex = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })

        return routes.sorted { lhs, rhs in
            let leftIndex = orderIndex[lhs.routeID]
            let rightIndex = orderIndex[rhs.routeID]
            if let leftIndex, let rightIndex, leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            if (leftIndex != nil) != (rightIndex != nil) {
                return leftIndex != nil
            }
            if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var routeIDs = orderedRoutes.map(\.routeID)
        routeIDs.move(fromOffsets: source, toOffset: destination)
        busRouteOrderIDsRaw = routeIDs.map(String.init).joined(separator: ",")
    }

    private func setRoute(_ routeID: Int, visible: Bool) {
        var hidden = hiddenRouteIDs
        if visible {
            hidden.remove(routeID)
        } else {
            hidden.insert(routeID)
        }
        hiddenBusRouteIDsRaw = hidden.sorted().map(String.init).joined(separator: ",")
    }
}
