//
//  BusStopSection.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The bus-stop branch of `PlaceDetailView` (Figma "specific stop" and
/// "specific route medium"). At rest it lists every route serving the
/// stop; opening a route focuses it on the map and lists that route's
/// live buses with their ETA here. A bus row opens its stop timeline.
struct BusStopSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(RouteManager.self) private var routeManager
    @Environment(MapSelection.self) private var selection

    let place: SearchCardModel
    let stop: BusStop
    let searchableData: SearchableData
    let onClose: () -> Void

    /// TransLoc models a shared physical stop as one row per route
    /// (unique routeStopID), so routes are unioned by street address.
    private var routeStops: [(route: BusRoute, stop: BusStop)] {
        searchableData.busRoutes
            .flatMap(\.stops)
            .filter { $0.stopAddressID == stop.stopAddressID }
            .flatMap { related in related.routes.map { (route: $0, stop: related) } }
            .sorted { lhs, rhs in
                if lhs.route.isRunning != rhs.route.isRunning { return lhs.route.isRunning }
                return lhs.route.name.localizedCaseInsensitiveCompare(rhs.route.name) == .orderedAscending
            }
    }

    private var focusedPair: (route: BusRoute, stop: BusStop)? {
        guard let routeID = selection.focusedBusRouteID else { return nil }
        return routeStops.first { $0.route.routeID == routeID }
    }

    private var distanceSubtitle: String? {
        DistanceFormat.text(from: searchableData.userLocation, to: place.coordinate)
            .map { "\($0) away" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetBackHeader(title: stop.name, subtitle: distanceSubtitle, onBack: goBack) {
                Button {
                    routeManager.requestDirections(to: place)
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 40, height: 40)
                        .background(colorScheme == .dark ? Color.gtWhite.opacity(0.12) : Color.gtGray1, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(place.destination == nil)
                .accessibilityLabel("Directions to \(stop.name)")
            }

            if let pair = focusedPair {
                busesList(route: pair.route, at: pair.stop)
            } else {
                routesList
            }

            BusArrivalAlertChip(stop: stop, stopEstimates: searchableData.stopEstimates)
                .padding(.top, 4)

            Text("Transit data from GT Buses (TransLoc)")
                .font(.gtBody4)
                .foregroundStyle(Color.gtSecondaryText)
        }
        .animation(.easeInOut(duration: 0.2), value: selection.focusedBusRouteID)
    }

    private func goBack() {
        withAnimation {
            if selection.focusedBusRouteID != nil {
                selection.focusedBusRouteID = nil
            } else {
                onClose()
            }
        }
    }

    // MARK: - Routes at this stop

    @ViewBuilder
    private var routesList: some View {
        let pairs = routeStops
        GTMicroLabel(text: "\(pairs.filter(\.route.isRunning).count)/\(pairs.count) routes active")

        VStack(spacing: 0) {
            ForEach(pairs, id: \.stop.routeStopID) { pair in
                routeRow(pair.route, at: pair.stop)
                if pair.stop.routeStopID != pairs.last?.stop.routeStopID {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .gtCard(radius: 14, padding: 0)
    }

    private func routeRow(_ route: BusRoute, at routeStop: BusStop) -> some View {
        let etas = BusArrivals.etas(to: routeStop, estimates: searchableData.stopEstimates)
        let tint = Color(hex: route.mapColor)

        return Button {
            withAnimation { selection.focusedBusRouteID = route.routeID }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: route.isRunning ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.palette)
                    // An empty circle's only layer is its ring — gray it.
                    .foregroundStyle(route.isRunning ? Color.gtWhite : Color.gtGray2, route.isRunning ? tint : Color.gtGray2)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name)
                        .font(.gtHeading5)
                        .foregroundStyle(route.isRunning ? Color.gtPrimaryText : Color.gtSecondaryText)
                        .lineLimit(1)
                    Text(routeStatus(route, etas: etas))
                        .font(.gtBody4)
                        .foregroundStyle(route.isRunning ? Color.gtSecondaryText : Color.gtRed)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.name) route, \(routeStatus(route, etas: etas))")
        .accessibilityHint("Shows this route's buses")
    }

    private func routeStatus(_ route: BusRoute, etas: [Int]) -> String {
        guard route.isRunning else { return "Not Running Now" }
        guard !etas.isEmpty else { return "No live buses" }
        return "Next in " + etas.prefix(2).map { BusArrivals.minutesText($0) }.joined(separator: ", ")
    }

    // MARK: - Buses on the focused route

    @ViewBuilder
    private func busesList(route: BusRoute, at routeStop: BusStop) -> some View {
        let buses = liveBuses(on: route, toward: routeStop)
        GTMicroLabel(text: "\(route.name) Route")

        if buses.isEmpty {
            Text(route.isRunning ? "No live buses on this route right now." : "This route isn't running right now.")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ForEach(buses, id: \.bus.vehicleID) { entry in
                    busRow(entry.bus, seconds: entry.seconds)
                    if entry.bus.vehicleID != buses.last?.bus.vehicleID {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .gtCard(radius: 14, padding: 0)
        }
    }

    /// The route's live buses, soonest to this stop first.
    private func liveBuses(on route: BusRoute, toward routeStop: BusStop) -> [(bus: BusLive, seconds: Int?)] {
        let estimates = searchableData.stopEstimates[routeStop.routeStopID] ?? []
        return searchableData.liveBuses
            .filter { $0.routeID == route.routeID && $0.isOnRoute }
            .map { bus in
                (bus: bus, seconds: estimates.first { $0.vehicleID == bus.vehicleID }?.secondsToStop)
            }
            .sorted { ($0.seconds ?? .max) < ($1.seconds ?? .max) }
    }

    private func busRow(_ bus: BusLive, seconds: Int?) -> some View {
        Button {
            withAnimation { selection.focusedBusID = bus.vehicleID }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.gtSecondaryText)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bus.displayName)
                        .font(.gtHeading5)
                        .foregroundStyle(Color.gtPrimaryText)
                    if let percentage = bus.capacityPercentage {
                        Text("Capacity: \(Int(percentage))% full")
                            .font(.gtBody3)
                            .foregroundStyle(Color.gtSecondaryText)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if let seconds {
                        Text(BusArrivals.minutesText(seconds))
                            .font(.gtHeading5)
                            .foregroundStyle(Color.gtPrimaryText)
                    }
                    if let dwell = bus.dwell {
                        BusIdleBadge(seconds: dwell.seconds)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows this bus's upcoming stops")
    }
}

/// "Idle for 3 min" (Figma "specific route medium"): Buzz gold for a
/// short stop, Azalea once the bus has sat long enough to matter.
struct BusIdleBadge: View {
    let seconds: Int

    private var isLong: Bool { seconds >= 5 * 60 }

    var body: some View {
        Text("Idle for \(BusArrivals.minutesText(seconds))")
            .font(.gtBody4)
            // gtBuzz is fill-only: dark text on it, white on Azalea.
            .foregroundStyle(isLong ? Color.gtWhite : Color.gtNavy)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isLong ? Color.gtAzalea : Color.gtBuzz, in: .capsule)
    }
}
