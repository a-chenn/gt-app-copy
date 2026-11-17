import Foundation

nonisolated enum Prediction {
    /// Requires a live response no older than thirty seconds.
    static func isFresh(_ received: Date?, now: Date) -> Bool {
        guard let received else { return false }
        return (0...30).contains(now.timeIntervalSince(received))
    }

    /// Produces sorted hybrid or TransLoc predictions for a single destination.
    static func calculate(data: HistoricalData, route: PredictionRoute, destination: Int,
                          selected: [String: [Estimate]], selectedAt: Date?,
                          upcoming: [String: [Estimate]], upcomingAt: Date?, now: Date,
                          requestedAt: Date? = nil,
                          vehicleNames: [String: String] = [:]) -> [Arrival] {
        guard route.stops.indices.contains(destination), isFresh(selectedAt, now: now) else { return [] }
        let upcoming = isFresh(upcomingAt, now: now) ? upcoming : [:]
        return selected.compactMap { vehicleID, estimates in
            guard let vendor = estimates.min(by: { $0.arrival < $1.arrival }) else { return nil }
            return predict(vehicleID: vehicleID, busNumber: vehicleNames[vehicleID], vendor: vendor,
                           upcoming: upcoming[vehicleID] ?? [], data: data, route: route,
                           destination: destination, now: now, requestedAt: requestedAt ?? now)
        }.sorted {
            $0.predictedArrival == $1.predictedArrival ? $0.vehicleID < $1.vehicleID : $0.predictedArrival < $1.predictedArrival
        }
    }

    /// Anchors one vehicle to its next stop, adds history and applies one offset.
    private static func predict(vehicleID: String, busNumber: String?, vendor: Estimate, upcoming: [Estimate],
                                data: HistoricalData, route: PredictionRoute, destination: Int,
                                now: Date, requestedAt: Date) -> Arrival {
        var result = Arrival(vehicleID: vehicleID, busNumber: busNumber, predictedArrival: max(now, vendor.arrival),
                             translocArrival: vendor.arrival, fetchedAt: now)
        if vendor.isArriving {
            result.source = .arriving
            result.predictedArrival = now
            return result
        }

        let candidates = upcoming.filter { !$0.isArriving && $0.arrival > now }
        guard let next = candidates.min(by: { $0.arrival < $1.arrival }),
              Set(candidates.filter { $0.arrival == next.arrival }.map(\.stopID)).count == 1,
              let origin = route.stops.firstIndex(where: { $0.id == next.stopID }),
              origin == destination || vendor.arrival >= next.arrival else { return result }

        let distance = (destination - origin + route.stops.count) % route.stops.count
        result.anchorStopName = route.stops[origin].name
        result.stopsAway = distance + 1
        guard distance > 0,
              case .seconds(let offset) = data.offsetRule(routeName: route.name, at: requestedAt, stopsAway: result.stopsAway),
              let mean = data.average(routeID: route.id, from: next.stopID, to: route.stops[destination].id,
                                      at: next.arrival) else { return result }

        let unadjusted = max(now, next.arrival.addingTimeInterval(mean))
        result.predictedArrival = max(now, unadjusted.addingTimeInterval(offset))
        result.source = .hybrid
        result.appliedOffsetSeconds = result.predictedArrival.timeIntervalSince(unadjusted)
        return result
    }
}
