import CoreLocation
import Foundation

/// Tracks observed arrivals from consecutive vehicle fixes, independently of ETA estimates.
nonisolated struct BusDwellManager {
    private static let stopRadiusMeters = 15.0
    private static let stoppedSpeed = 1.0
    private static let maximumFixGap: TimeInterval = 30

    private struct Fix: Equatable {
        let timestamp: Date
        let routeID: Int
        let latitude: Double
        let longitude: Double
        let speed: Double

        /// Creates a fix only when the feed can establish whether the bus is stopped.
        init?(_ location: BusLocationJSON) {
            guard location.isOnRoute, let timestamp = location.sourceTimestamp,
                  let speed = location.groundSpeed, speed >= 0 else { return nil }
            self.timestamp = timestamp
            routeID = location.routeID
            latitude = location.busLatitude
            longitude = location.busLongitude
            self.speed = speed
        }
    }

    private struct Observation {
        let fix: Fix
        let receivedAt: Date
        let stop: BusStopJSON?
        let arrival: Date?
        var isContinuous = true

        var dwell: BusDwell? {
            guard isContinuous, let stop, let arrival else { return nil }
            return BusDwell(
                stopName: stop.name,
                seconds: Int(fix.timestamp.timeIntervalSince(arrival)),
                expiresAt: receivedAt.addingTimeInterval(BusDwellManager.maximumFixGap))
        }
    }

    private var observations: [Int: Observation] = [:]

    /// Breaks tracking continuity while retaining timestamps to recognize repeated fixes.
    mutating func invalidateObservations() {
        for vehicleID in observations.keys {
            observations[vehicleID]?.isContinuous = false
        }
    }

    /// Applies the latest fleet response and returns dwell for arrivals observed across fresh fixes.
    mutating func updateObservations(
        locations: [BusLocationJSON], routes: [BusRouteJSON], receivedAt: Date
    ) -> [Int: BusDwell] {
        let stopsByRoute = Dictionary(routes.map { ($0.routeID, $0.stops) }, uniquingKeysWith: { first, _ in first })
        let vehicleIDs = Set(locations.map(\.vehicleID))
        for (vehicleID, previous) in observations where !vehicleIDs.contains(vehicleID) {
            if receivedAt.timeIntervalSince(previous.receivedAt) > Self.maximumFixGap {
                observations.removeValue(forKey: vehicleID)
            } else {
                observations[vehicleID]?.isContinuous = false
            }
        }

        var result: [Int: BusDwell] = [:]
        for location in locations {
            let vehicleID = location.vehicleID
            guard let fix = Fix(location), let stops = stopsByRoute[fix.routeID], !stops.isEmpty else {
                observations[vehicleID]?.isContinuous = false
                continue
            }
            let previous = observations[vehicleID]
            let continuous = previous.flatMap { previous -> Observation? in
                guard previous.isContinuous, previous.fix.routeID == fix.routeID,
                      (0...Self.maximumFixGap).contains(receivedAt.timeIntervalSince(previous.receivedAt)),
                      (0...Self.maximumFixGap).contains(fix.timestamp.timeIntervalSince(previous.fix.timestamp))
                else { return nil }
                return previous
            }

            // A cached fix can't restart tracking after continuity was lost.
            if let previous, fix.timestamp <= previous.fix.timestamp {
                if let continuous, fix == continuous.fix {
                    result[vehicleID] = continuous.dwell
                } else {
                    observations[vehicleID]?.isContinuous = false
                }
                continue
            }

            let stop = findStop(for: fix, in: stops, preferredStopID: continuous?.stop?.routeStopID)
            var arrival: Date?
            if let stop, let continuous {
                if continuous.stop == nil {
                    arrival = fix.timestamp
                } else if continuous.stop?.routeStopID == stop.routeStopID {
                    arrival = continuous.arrival
                }
            }
            let observation = Observation(fix: fix, receivedAt: receivedAt, stop: stop, arrival: arrival)
            observations[vehicleID] = observation
            result[vehicleID] = observation.dwell
        }
        return result
    }

    /// Finds a nearby stop for a stationary bus, retaining its current stop through GPS drift.
    private func findStop(for fix: Fix, in stops: [BusStopJSON], preferredStopID: Int?) -> BusStopJSON? {
        guard fix.speed < Self.stoppedSpeed else { return nil }
        let position = CLLocation(latitude: fix.latitude, longitude: fix.longitude)
        var closest: BusStopJSON?
        var closestDistance = Double.infinity
        for stop in stops {
            let distance = position.distance(from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
            guard distance <= Self.stopRadiusMeters else { continue }
            if stop.routeStopID == preferredStopID { return stop }
            if distance < closestDistance {
                closest = stop
                closestDistance = distance
            }
        }
        return closest
    }
}
