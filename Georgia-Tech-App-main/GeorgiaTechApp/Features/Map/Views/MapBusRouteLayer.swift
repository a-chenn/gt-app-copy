//
//  MapBusRouteLayer.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftData
import SwiftUI

/// The bus layer: route polylines in their real TransLoc colors, stop
/// markers that open the unified detail card, and live heading-rotated
/// vehicle markers that open the transient bus popover.
///
/// Focus mode (#5): while a bus is selected, only its route, its stops,
/// and that bus render — everything else clears out of the way.
struct MapBusRouteLayer: MapContent {
    let routes: [BusRoute]
    var liveBuses: [BusLive] = []
    var hiddenRouteIDs: Set<Int> = []
    var focusedRouteID: Int?
    var focusedVehicleID: Int?
    /// The open stop card's street address — the places layer draws it
    /// as the black pin, so its ring dots step aside.
    var selectedStopAddressID: Int?
    var stopEstimates: [Int: [BusStopEstimate]] = [:]
    var onStopTap: (BusStop) -> Void = { _ in }
    var onBusTap: (BusLive) -> Void = { _ in }
    var onDismissBus: () -> Void = {}
    var onDirectionsToStop: (BusStop) -> Void = { _ in }

    private var visibleRoutes: [BusRoute] {
        routes.filter { route in
            if let focusedRouteID { return route.routeID == focusedRouteID }
            return !hiddenRouteIDs.contains(route.routeID)
        }
    }

    private var visibleBuses: [BusLive] {
        liveBuses.filter { bus in
            guard bus.isOnRoute else { return false }
            if let focusedVehicleID { return bus.vehicleID == focusedVehicleID }
            return !hiddenRouteIDs.contains(bus.routeID)
        }
    }

    var body: some MapContent {
        ForEach(visibleRoutes) { route in
            if let polyline = MKPolyline(encodedString: route.polyline) {
                MapPolyline(polyline).stroke(Color.gtWhite, lineWidth: 7)
                MapPolyline(polyline).stroke(Color(hex: route.mapColor), lineWidth: 4.5)
            }

            ForEach(route.stops) { stop in
                // The open stop draws as the places layer's black pin.
                if stop.stopAddressID != selectedStopAddressID {
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        // White stop with a route-colored ring (Figma
                        // "main bus"), sized to read and tap at campus
                        // zoom. A tap GESTURE, not a Button (#R4-12): the
                        // plain button's pressed tint showed a "color
                        // change" when the map's pan swallowed the touch.
                        Circle()
                            .fill(Color.gtWhite)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle().strokeBorder(Color(hex: route.mapColor), lineWidth: 3.5)
                            }
                            .shadow(color: Color.gtNavy.opacity(0.2), radius: 1.5, y: 0.5)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .onTapGesture {
                                onStopTap(stop)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("\(stop.name) bus stop")
                            .accessibilityHint("Shows the routes serving this stop")
                    }
                    .annotationTitles(.hidden)
                }
            }
        }

        ForEach(visibleBuses) { bus in
            let route = routes.first { $0.routeID == bus.routeID }
            let routePolyline = bus.isStopped
                ? route.flatMap { MKPolyline(encodedString: $0.polyline) }
                : nil
            // Keep the selected card in the vehicle annotation so it tracks
            // each live coordinate update and stays just above its marker.
            Annotation("", coordinate: bus.coordinate, anchor: .bottom) {
                VStack(spacing: 6) {
                    if focusedVehicleID == bus.vehicleID {
                        LiveBusPopover(
                            bus: bus,
                            route: route,
                            stopEstimates: stopEstimates,
                            onDismiss: onDismissBus,
                            onDirectionsToNextStop: onDirectionsToStop
                        )
                        .frame(width: 210)
                    }

                    LiveBusMarker(
                        bus: bus,
                        colorHex: route?.mapColor,
                        routePolyline: routePolyline,
                        isSelected: focusedVehicleID == bus.vehicleID
                    )
                        .contentShape(Circle().inset(by: -8))
                        .onTapGesture {
                            onBusTap(bus)
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(busAccessibilityLabel(bus))
                }
            }
            .annotationTitles(.hidden)
        }
    }

    private func busAccessibilityLabel(_ bus: BusLive) -> String {
        let routeName = routes.first { $0.routeID == bus.routeID }?.name ?? "Bus"
        return "\(routeName) bus, live position"
    }
}

/// Live vehicle marker (Figma "specific route"): a teardrop in the
/// route's color whose point leads in the direction of travel, with a
/// white center so it reads against the route line beneath it.
struct LiveBusMarker: View {
    let bus: BusLive
    let colorHex: String?
    var routePolyline: MKPolyline?
    var isSelected = false

    private var tint: Color {
        colorHex.map { Color(hex: $0) } ?? Color.gtNavy
    }

    private var size: CGFloat { isSelected ? 34 : 28 }

    var body: some View {
        ZStack {
            HeadingTeardrop()
                .fill(tint)
                .overlay {
                    HeadingTeardrop().stroke(Color.gtWhite, lineWidth: 2)
                }
                .shadow(color: Color.gtNavy.opacity(0.3), radius: 2, y: 1)
                .rotationEffect(.degrees(bus.displayHeading(along: routePolyline)))

            Circle()
                .fill(Color.gtWhite)
                .frame(width: size * 0.32, height: size * 0.32)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

/// A circle with a point at the top — rotate it to aim the point. The
/// circle stays centered in the rect so rotation never shifts the
/// marker off the bus's coordinate.
struct HeadingTeardrop: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.36
        let tip = CGPoint(x: center.x, y: rect.minY)
        // Tangent points from the tip to the circle.
        let distance = center.y - tip.y
        let angle = asin(radius / distance)
        var path = Path()
        path.move(to: tip)
        path.addArc(
            center: center, radius: radius,
            startAngle: .radians(-.pi / 2 + (.pi / 2 - angle)),
            endAngle: .radians(-.pi / 2 - (.pi / 2 - angle)),
            clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The selected bus stop (Figma "specific stop"): the same teardrop,
/// point down, in black with a white center. Anchor the annotation at
/// `.bottom` so the point sits on the stop.
struct BusStopSelectedPin: View {
    var body: some View {
        ZStack {
            HeadingTeardrop()
                .fill(Color.gtPrimaryText)
                .overlay {
                    HeadingTeardrop().stroke(Color.gtWhite, lineWidth: 2)
                }
                .rotationEffect(.degrees(180))
            Circle()
                .fill(Color.gtWhite)
                .frame(width: 11, height: 11)
                .offset(y: -1)
        }
        .frame(width: 34, height: 34)
        .shadow(color: Color.gtNavy.opacity(0.3), radius: 2, y: 1)
    }
}
