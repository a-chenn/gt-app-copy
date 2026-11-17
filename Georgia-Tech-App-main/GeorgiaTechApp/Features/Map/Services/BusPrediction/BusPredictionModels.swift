import Foundation

nonisolated enum ArrivalConfiguration {
    static let routeID = "20"
    static let bucketDurationMinutes = 120
}

nonisolated struct PredictionSettings: Sendable {
    var routeID = ArrivalConfiguration.routeID
}

nonisolated struct JourneyKey: Hashable, Sendable {
    let routeID: String
    let originStopID: String
    let destinationStopID: String
    let bucketStartMinute: Int
}

nonisolated struct HistoricalAverage: Sendable {
    let meanElapsedSeconds: Double
    let sampleCount: Int
    let serviceDateCount: Int
}

nonisolated enum OffsetRule: Equatable, Sendable {
    case seconds(Double)
    case transloc
}

nonisolated struct OffsetSchedule: Sendable {
    let stopsAway: ClosedRange<Int>
    let buckets: [OffsetRule]
}

nonisolated struct ArrivalSnapshot: Sendable {
    let updatedAt: Date
    let routeID: String
    let routeName: String
    let stopID: String
    let stopName: String
    let arrivals: [Arrival]
    let warnings: [String]
}

nonisolated struct Arrival: Identifiable, Sendable {
    var id: String { vehicleID }
    let vehicleID: String
    let busNumber: String?
    var displayName: String { busNumber.map { "Bus \($0)" } ?? "Vehicle \(vehicleID)" }
    var predictedArrival: Date
    let translocArrival: Date
    let fetchedAt: Date
    var remainingSeconds: Int { seconds(until: predictedArrival) }
    var translocSeconds: Int { seconds(until: translocArrival) }
    var source: Source = .transloc
    var anchorStopName: String?
    /// The selected stop being next means one stop away.
    var stopsAway: Int?
    var appliedOffsetSeconds: Double = 0

    nonisolated enum Source: String, Sendable {
        case hybrid, transloc, arriving
    }

    /// Returns the fixed countdown relative to the snapshot fetch time.
    private func seconds(until date: Date) -> Int {
        let value = max(0, date.timeIntervalSince(fetchedAt)).rounded(.toNearestOrEven)
        return value >= Double(Int.max) ? Int.max : Int(value)
    }
}

nonisolated enum ArrivalError: LocalizedError {
    case invalidData(String)
    case invalidStop(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidData(let detail): return "Historical data: \(detail)"
        case .invalidStop(let id): return "Stop \(id) is not on the selected route."
        case .invalidResponse(let detail): return "TransLoc: \(detail)"
        }
    }
}

nonisolated struct PredictionRouteStop: Sendable {
    let id: String
    let name: String
}

nonisolated struct PredictionRoute: Sendable {
    let id: String
    let name: String
    let stops: [PredictionRouteStop]
}

nonisolated enum LocalTime {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    static func bucket(at date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes / ArrivalConfiguration.bucketDurationMinutes * ArrivalConfiguration.bucketDurationMinutes
    }
}
