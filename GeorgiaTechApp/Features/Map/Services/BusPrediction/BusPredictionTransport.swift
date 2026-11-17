import Foundation
import CoreFoundation

nonisolated struct Estimate: Sendable {
    let arrival: Date
    let isArriving: Bool
    let stopID: String
}

nonisolated struct LiveResponse: Sendable {
    let body: Data
    let receivedAt: Date
}

nonisolated protocol LiveTransport: Sendable {
    /// Fetches a relay response with its local receipt time.
    func fetch(method: String, parameters: [String: String]) async throws -> LiveResponse
}

nonisolated struct TransLocTransport: LiveTransport {
    /// Fetches a relay response with its local receipt time.
    func fetch(method: String, parameters: [String: String]) async throws -> LiveResponse {
        try await GTDataService.shared.fetchBusResponse(method: method, parameters: parameters)
    }
}

nonisolated enum Timestamp {
    /// Parses relay epoch timestamps or ISO 8601 timestamps.
    static func parse(_ text: String) -> Date? {
        if let match = text.wholeMatch(of: #/\/Date\((-?\d+)(?:[+-]\d{4})?\)\//#),
           let milliseconds = Double(match.1), milliseconds.isFinite {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let result = format.date(from: text) { return result }
        format.formatOptions = [.withInternetDateTime]
        return format.date(from: text)
    }
}

nonisolated enum LiveParser {
    /// Validates that a response contains a top-level array.
    static func list(_ data: Data) throws -> [Any] {
        guard let result = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw ArrivalError.invalidResponse("Expected an array")
        }
        return result
    }

    // Fleet numbers are display metadata. Arrival endpoints use the internal ID.
    /// Maps internal vehicle IDs to display-only fleet labels.
    static func vehicleNames(_ data: Data, routeID: String) throws -> [String: String] {
        var names: [String: String] = [:]
        for case let vehicle as [String: Any] in try list(data) {
            guard identifier(vehicle["RouteID"] ?? vehicle["RouteId"]) == routeID,
                  let id = identifier(vehicle["VehicleID"] ?? vehicle["VehicleId"]),
                  let name = identifier(vehicle["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            names[id] = name
        }
        return names
    }

    /// Validates a non-departed estimate and resolves its absolute arrival time.
    static func entry(_ entry: [String: Any], received: Date) -> Estimate? {
        guard entry["IsDeparted"] as? Bool != true, entry["OnRoute"] as? Bool != false else { return nil }
        let arrival: Date
        if let text = entry["EstimateTime"] as? String, !text.isEmpty {
            guard let parsed = Timestamp.parse(text) else { return nil }
            arrival = parsed
        } else {
            let seconds = (entry["Seconds"] as? NSNumber)?.doubleValue ?? (entry["Seconds"] as? String).flatMap(Double.init)
            guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
            arrival = received.addingTimeInterval(seconds)
        }
        guard arrival.timeIntervalSince1970.isFinite else { return nil }
        let isArriving = entry["IsArriving"] as? Bool == true
        if arrival < received && !isArriving { return nil }
        return Estimate(arrival: max(arrival, received), isArriving: isArriving,
                        stopID: identifier(entry["RouteStopID"] ?? entry["RouteStopId"]) ?? "")
    }

    /// Collects the requested route stop’s estimates by internal vehicle ID.
    static func selected(_ data: Data, routeID: String, stopID: String, received: Date) throws -> [String: [Estimate]] {
        var result: [String: [Estimate]] = [:]
        for case let stop as [String: Any] in try list(data) {
            guard identifier(stop["RouteId"] ?? stop["RouteID"]) == routeID,
                  identifier(stop["RouteStopId"] ?? stop["RouteStopID"]) == stopID else { continue }
            for case let raw as [String: Any] in stop["Times"] as? [Any] ?? [] {
                if let value = entry(raw, received: received), let vehicle = identifier(raw["VehicleId"] ?? raw["VehicleID"]) {
                    result[vehicle, default: []].append(value)
                }
            }
        }
        return result
    }

    /// Validates route membership and groups upcoming stops per vehicle.
    static func upcoming(_ data: Data, route: PredictionRoute, requested: Set<String>, received: Date) throws -> [String: [Estimate]] {
        var result: [String: [Estimate]] = [:]
        var invalid: Set<String> = []
        let knownStops = Set(route.stops.map(\.id))
        for case let vehicle as [String: Any] in try list(data) {
            let id = identifier(vehicle["VehicleID"] ?? vehicle["VehicleId"]) ?? ""
            guard requested.contains(id) else { continue }
            guard identifier(vehicle["RouteID"] ?? vehicle["RouteId"] ?? route.id) == route.id else { invalid.insert(id); continue }
            for case let raw as [String: Any] in vehicle["Estimates"] as? [Any] ?? [] {
                guard let value = entry(raw, received: received) else { continue }
                guard identifier(raw["VehicleId"] ?? raw["VehicleID"] ?? id) == id,
                      identifier(raw["RouteID"] ?? raw["RouteId"] ?? route.id) == route.id,
                      knownStops.contains(value.stopID) else { invalid.insert(id); continue }
                result[id, default: []].append(value)
            }
        }
        for id in invalid { result.removeValue(forKey: id) }
        return result
    }

    /// Normalizes numeric or string identifiers while rejecting booleans.
    static func identifier(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() { return value.stringValue }
        return nil
    }
}
