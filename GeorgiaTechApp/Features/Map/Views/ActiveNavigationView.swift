//
//  ActiveNavigationView.swift
//  GeorgiaTechApp
//

import CoreLocation
import MapKit
import SwiftUI

/// Navigation's sheet content (Figma "Navigation"): the ETA bar with End,
/// plus transit legs for bus routes and parking suggestions while
/// driving. The maneuver card floats over the map instead.
struct ActiveNavigationView: View {
    @Environment(RouteManager.self) private var routeManager

    var parkingLocations: [CampusLocation] = []
    /// True at the 72pt rest detent — only the ETA bar is visible, so
    /// the card stack hides (its top edge peeked as a white sliver).
    var isCollapsed = false
    var onSelectParking: (RouteStop) -> Void = { _ in }

    var body: some View {
        ScrollView {
            // The maneuver card floats over the map (NavigationInstructionCard).
            VStack(spacing: 14) {
                if let plan = routeManager.activeTransitPlan {
                    transitLegsCard(plan)
                }

                parkingSuggestions
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .opacity(isCollapsed ? 0 : 1)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            etaBar
        }
    }

    // MARK: - Transit legs

    private func transitLegsCard(_ plan: TransitPlan) -> some View {
        VStack(spacing: 0) {
            legRow(
                icon: "figure.walk", tint: Color.gtNavy,
                title: "Walk to \(plan.boardStopName)",
                seconds: Int(plan.walkToStop.expectedTravelTime))
            legRow(
                icon: "clock", tint: Color.gtSecondaryText,
                title: "Wait for \(plan.routeName)",
                seconds: plan.waitSeconds)
            legRow(
                icon: "bus", tint: Color(hex: plan.routeColorHex),
                title: "Ride to \(plan.alightStopName)",
                seconds: plan.rideSeconds)
            legRow(
                icon: "figure.walk", tint: Color.gtNavy,
                title: "Walk to destination",
                seconds: Int(plan.walkToDestination.expectedTravelTime))
        }
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private func legRow(icon: String, tint: Color, title: String, seconds: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtWhite)
                }

            Text(title)
                .font(.gtBody2)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(2)

            Spacer()

            Text(BusArrivals.minutesText(seconds))
                .font(.gtHeading6)
                .foregroundStyle(Color.gtNavy)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gtGold, in: .capsule)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Parking (driving mode)

    private var nearbyParking: [CampusLocation] {
        guard routeManager.selectedMode == .driving, !routeManager.hasArrived,
              let destination = routeManager.stops.last?.mapItem.location.coordinate,
              !parkingLocations.isEmpty
        else { return [] }

        let stopNames = Set(routeManager.stops.map(\.name))
        let target = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return parkingLocations
            .filter { !stopNames.contains($0.name) }
            .sorted {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: target)
                    < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: target)
            }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var parkingSuggestions: some View {
        let decks = nearbyParking
        if !decks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Parking near destination")
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtSecondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(decks) { deck in
                            Button {
                                if let stop = deck.toSearchCard().destination {
                                    onSelectParking(stop)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "parkingsign")
                                    Text(deck.name)
                                        .lineLimit(1)
                                }
                                .font(.gtHeading6)
                                .foregroundStyle(Color.gtPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(.regular, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add parking stop: \(deck.name)")
                        }
                    }
                }
                .mapSheetHorizontalScroll()
            }
        }
    }

    // MARK: - ETA bar

    /// What's left: the countdown to the next maneuver plus every later step.
    private var remainingDistance: Double {
        let later = routeManager.navigationSteps
            .filter { $0.id > routeManager.displayedStepIndex }
            .reduce(0) { $0 + $1.distance }
        return (routeManager.distanceToNextManeuver ?? 0) + later
    }

    /// Figma: "12 min" in Roboto Slab over "0.7 mi · 3:09 PM", navy End.
    private var etaBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(RouteNavigation.durationText(seconds: routeManager.remainingTravelTime))
                        .font(.gtHeading2)
                        .foregroundStyle(Color.gtPrimaryText)
                    if let plan = routeManager.activeTransitPlan {
                        Circle()
                            .fill(Color(hex: plan.routeColorHex))
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }
                }
                Text("\(DistanceFormat.text(meters: remainingDistance)) · \(Date.now.addingTimeInterval(routeManager.remainingTravelTime).formatted(date: .omitted, time: .shortened))")
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            GTCapsuleButton(
                routeManager.hasArrived ? "Done" : "End",
                style: .selected
            ) {
                routeManager.endNavigation()
            }
            .controlSize(.small)
            .accessibilityLabel(routeManager.hasArrived ? "Finish navigation" : "End navigation")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
