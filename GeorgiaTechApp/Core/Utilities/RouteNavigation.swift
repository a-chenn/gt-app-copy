//
//  RouteNavigation.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import MapKit

/// One step of an active route. MapKit's convention: a step's instruction
/// is EXECUTED at the START of its polyline; the polyline is the segment
/// driven after the maneuver.
struct NavigationStep: Identifiable, Equatable {
    let id: Int
    let instructions: String
    let distance: CLLocationDistance
    /// Where this step's instruction is executed (polyline start).
    let startCoordinate: CLLocationCoordinate2D
    /// Where this step's segment ends (the next maneuver point).
    let endCoordinate: CLLocationCoordinate2D
    let polyline: MKPolyline

    static func == (lhs: NavigationStep, rhs: NavigationStep) -> Bool {
        lhs.id == rhs.id && lhs.instructions == rhs.instructions
    }

    var icon: String {
        let lower = instructions.lowercased()
        if lower.contains("arrive") || lower.contains("destination") { return "mappin.circle.fill" }
        if lower.contains("u-turn") || lower.contains("uturn") { return "arrow.uturn.left" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("stairs") || lower.contains("steps") { return "figure.stairs" }
        if lower.isEmpty { return "location.fill" }
        return "arrow.up"
    }

    /// "Turn left onto Ferst Dr" → ("Turn left", "Ferst Dr").
    var actionText: String {
        for delimiter in ["onto ", "on ", "toward "] {
            if let range = instructions.range(of: delimiter) {
                return String(instructions[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return instructions
    }

    var streetName: String? {
        for delimiter in ["onto ", "on ", "toward "] {
            if let range = instructions.range(of: delimiter) {
                let street = String(instructions[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return street.isEmpty ? nil : street
            }
        }
        return nil
    }
}

/// Pure navigation math: step extraction, live progress, off-route tests.
/// (The projection geometry follows the old app's proven NavigationDomain.)
enum RouteNavigation {
    static let offRouteThresholdMeters: CLLocationDistance = 45
    static let arrivalThresholdMeters: CLLocationDistance = 20

    /// Flattens one or more route segments into a step list. Empty
    /// "proceed" prologue steps are KEPT — their polylines carry position
    /// while the user walks/drives them; display logic skips their text.
    static func steps(from routes: [MKRoute]) -> [NavigationStep] {
        var result: [NavigationStep] = []
        for route in routes {
            for step in route.steps {
                // MapKit's first step is a zero-length, empty-instruction
                // stub at the origin; keeping it made navigation open on
                // a blank step and visibly "skip" to the real first
                // maneuver one GPS tick later (#F5-directions).
                guard !step.instructions.isEmpty || step.distance > 0 else { continue }
                let coordinates = step.polyline.allCoordinates
                guard let start = coordinates.first, let end = coordinates.last else { continue }
                result.append(NavigationStep(
                    id: result.count,
                    instructions: step.instructions,
                    distance: step.distance,
                    startCoordinate: start,
                    endCoordinate: end,
                    polyline: step.polyline))
            }
        }
        return result
    }

    /// The step whose upcoming instruction the banner should show: the
    /// first step after the on-polyline step that carries text. (The
    /// user is ON step N's segment; the NEXT maneuver is step N+1's
    /// instruction, executed at N+1's polyline start.)
    static func upcomingManeuverIndex(after locationIndex: Int, in steps: [NavigationStep]) -> Int {
        guard !steps.isEmpty else { return 0 }
        var index = min(locationIndex + 1, steps.count - 1)
        while index < steps.count - 1 && steps[index].instructions.isEmpty {
            index += 1
        }
        // If everything ahead is textless, fall back to the last texted step.
        if steps[index].instructions.isEmpty {
            var back = index
            while back > 0 && steps[back].instructions.isEmpty { back -= 1 }
            return back
        }
        return index
    }

    /// The step the user is currently on: the nearest step polyline at or
    /// after the current one — forward-only so a route that loops back near
    /// an earlier street can't yank the banner backwards.
    static func currentStepIndex(
        for coordinate: CLLocationCoordinate2D,
        steps: [NavigationStep],
        startingAt currentIndex: Int
    ) -> Int {
        guard !steps.isEmpty else { return 0 }
        let lowerBound = min(max(currentIndex, 0), steps.count - 1)

        var bestIndex = lowerBound
        var bestDistance = Double.infinity
        // Only look a couple of steps ahead — GPS noise shouldn't skip turns.
        for index in lowerBound..<min(lowerBound + 3, steps.count) {
            if let distance = distance(from: coordinate, to: steps[index].polyline),
               distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        // Crossing a segment boundary advances the step — but only when
        // the next segment is genuinely the closer one, so short steps
        // and GPS wobble near a maneuver can't skip ahead prematurely.
        if bestIndex < steps.count - 1,
           metersBetween(coordinate, steps[bestIndex].endCoordinate) < 15,
           let toNext = distance(from: coordinate, to: steps[bestIndex + 1].polyline),
           let toCurrent = distance(from: coordinate, to: steps[bestIndex].polyline),
           toNext <= toCurrent {
            return bestIndex + 1
        }
        return bestIndex
    }

    static func isOffRoute(_ coordinate: CLLocationCoordinate2D, routePolyline: MKPolyline) -> Bool {
        guard let distance = distance(from: coordinate, to: routePolyline) else { return false }
        return distance > offRouteThresholdMeters
    }

    static func hasArrived(_ coordinate: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> Bool {
        metersBetween(coordinate, destination) < arrivalThresholdMeters
    }

    /// Remaining meters: to the end of the on-polyline step, plus every
    /// later step's full segment.
    static func remainingDistance(
        from coordinate: CLLocationCoordinate2D,
        steps: [NavigationStep],
        currentIndex: Int
    ) -> CLLocationDistance {
        guard currentIndex < steps.count else { return 0 }
        let toSegmentEnd = metersBetween(coordinate, steps[currentIndex].endCoordinate)
        let rest = steps.dropFirst(currentIndex + 1).reduce(0) { $0 + $1.distance }
        return toSegmentEnd + rest
    }

    // MARK: - Formatting

    static func durationText(seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return "< 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }

    static func etaText(durationSeconds: TimeInterval, now: Date = Date()) -> String {
        let arrival = now.addingTimeInterval(durationSeconds)
        return "\(arrival.formatted(date: .omitted, time: .shortened)) arrival"
    }

    static func maneuverDistanceText(_ meters: CLLocationDistance) -> String {
        let feet = meters * 3.28084
        if feet < 500 { return "\(Int((feet / 10).rounded() * 10)) ft" }
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }

    // MARK: - Geometry (local planar projection)

    /// Min distance in meters from a coordinate to a polyline.
    static func distance(from coordinate: CLLocationCoordinate2D, to polyline: MKPolyline) -> CLLocationDistance? {
        let coordinates = polyline.allCoordinates
        guard coordinates.count >= 2 else {
            return coordinates.first.map { metersBetween(coordinate, $0) }
        }

        let origin = coordinate
        let points = coordinates.map { project($0, around: origin) }
        var best = Double.infinity
        for index in 1..<points.count {
            let distance = distanceToSegment(.zero, points[index - 1], points[index])
            if distance < best { best = distance }
        }
        return best
    }

    static func metersBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Equirectangular projection into meters around `origin`.
    private static func project(_ coordinate: CLLocationCoordinate2D, around origin: CLLocationCoordinate2D) -> CGPoint {
        let earthRadius = 6_371_000.0
        let latRad = origin.latitude * .pi / 180
        let x = (coordinate.longitude - origin.longitude) * .pi / 180 * earthRadius * cos(latRad)
        let y = (coordinate.latitude - origin.latitude) * .pi / 180 * earthRadius
        return CGPoint(x: x, y: y)
    }

    /// Distance from point to segment via clamped projection.
    private static func distanceToSegment(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let lengthSquared = abx * abx + aby * aby
        guard lengthSquared > 0 else {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let t = max(0, min(1, ((point.x - a.x) * abx + (point.y - a.y) * aby) / lengthSquared))
        let projX = a.x + t * abx
        let projY = a.y + t * aby
        return hypot(point.x - projX, point.y - projY)
    }
}
