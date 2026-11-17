import Foundation

nonisolated struct HistoricalData: Sendable {
    var routes: [String: PredictionRoute] = [:]
    var averages: [JourneyKey: HistoricalAverage] = [:]
    var offsets: [String: [OffsetSchedule]] = [:]

    /// Uses the matching 120-minute bucket regardless of sample coverage.
    /// Missing buckets return nil so predictions retain TransLoc times.
    func average(routeID: String, from origin: String, to destination: String, at date: Date) -> Double? {
        let key = JourneyKey(routeID: routeID, originStopID: origin, destinationStopID: destination,
                             bucketStartMinute: LocalTime.bucket(at: date))
        guard let value = averages[key] else { return nil }
        return value.meanElapsedSeconds
    }

    /// Selects the route, distance band and New York request-time correction.
    func offsetRule(routeName: String, at date: Date, stopsAway: Int? = nil) -> OffsetRule {
        let name = routeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let schedules = offsets[name] else { return .transloc }
        let hour = LocalTime.calendar.component(.hour, from: date)
        guard hour >= 4 else { return .seconds(0) }
        let distance = stopsAway.flatMap { $0 > 0 ? $0 : nil } ?? 4
        guard let schedule = schedules.first(where: { $0.stopsAway.contains(distance) }) else { return .transloc }
        let bucket = (hour - 4) / 2
        return schedule.buckets.indices.contains(bucket) ? schedule.buckets[bucket] : .transloc
    }

    /// Validates and loads bundled route definitions, journey averages and offsets.
    static func load(root: URL) throws -> HistoricalData {
        var data = HistoricalData()
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("routes.json")))
        guard let routes = json as? [[String: Any]] else { throw ArrivalError.invalidData("Invalid routes.json") }
        for raw in routes {
            guard let id = LiveParser.identifier(raw["RouteID"]), let rawStops = raw["Stops"] as? [[String: Any]], !rawStops.isEmpty else { continue }
            let orders = rawStops.compactMap { $0["Order"] as? Int }
            guard orders.count == rawStops.count, Set(orders).count == orders.count else {
                throw ArrivalError.invalidData("Invalid stop order on route \(id)")
            }
            let ordered = rawStops.sorted { ($0["Order"] as? Int ?? 0) < ($1["Order"] as? Int ?? 0) }
            let stops = try ordered.map { stop -> PredictionRouteStop in
                guard let id = LiveParser.identifier(stop["RouteStopID"]) else { throw ArrivalError.invalidData("Missing stop ID") }
                return PredictionRouteStop(id: id, name: stop["Description"] as? String ?? stop["Name"] as? String ?? id)
            }
            guard Set(stops.map(\.id)).count == stops.count else { throw ArrivalError.invalidData("Duplicate stops on route \(id)") }
            data.routes[id] = PredictionRoute(id: id, name: raw["Description"] as? String ?? id, stops: stops)
        }

        let directory = root.appendingPathComponent("route_averages")
        for folder in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !folder.lastPathComponent.hasPrefix(".") {
            let routeID = String(folder.lastPathComponent.split(separator: " ").first ?? "")
            guard let route = data.routes[routeID] else { throw ArrivalError.invalidData("Unknown route \(routeID)") }
            let stopIDs = Set(route.stops.map(\.id))
            for row in try CSV.read(folder.appendingPathComponent("bucketed.csv")) {
                guard row["route_id"] == routeID, let origin = row["origin_route_stop_id"], let destination = row["destination_route_stop_id"],
                      stopIDs.contains(origin), stopIDs.contains(destination),
                      let mean = Double(row["mean_elapsed_seconds"] ?? ""), mean.isFinite, mean > 0,
                      let samples = Int(row["sample_count"] ?? ""), samples > 0,
                      let dates = Int(row["service_date_count"] ?? ""), (1...samples).contains(dates) else {
                    throw ArrivalError.invalidData("Invalid average for route \(routeID)")
                }
                let width = ArrivalConfiguration.bucketDurationMinutes
                guard Int(row["bucket_minutes"] ?? "") == width,
                      let bucket = Int(row["bucket_start_minute"] ?? ""),
                      (0..<1440).contains(bucket), bucket % width == 0 else {
                    throw ArrivalError.invalidData("Expected a valid 120-minute historical bucket")
                }
                let key = JourneyKey(routeID: routeID, originStopID: origin, destinationStopID: destination, bucketStartMinute: bucket)
                data.averages[key] = HistoricalAverage(meanElapsedSeconds: mean, sampleCount: samples, serviceDateCount: dates)
            }
        }
        guard !data.averages.isEmpty else { throw ArrivalError.invalidData("No historical averages") }

        let columns = ["4-6 AM", "6-8 AM", "8-10 AM", "10 AM-12 PM", "12-2 PM", "2-4 PM", "4-6 PM", "6-8 PM", "8-10 PM", "10 PM-12 AM"]
        for row in try CSV.read(root.appendingPathComponent("route_time_offsets.csv")) {
            guard let name = row["route_color"]?.lowercased(), !name.isEmpty,
                  let minimum = Int(row["min_stops_away"] ?? ""), minimum > 0,
                  let maximum = row["max_stops_away"].flatMap({ $0.isEmpty ? Int.max : Int($0) }), maximum >= minimum else {
                throw ArrivalError.invalidData("Invalid offset distance range")
            }
            let range = minimum...maximum
            guard !(data.offsets[name] ?? []).contains(where: { $0.stopsAway.overlaps(range) }) else {
                throw ArrivalError.invalidData("Overlapping offset ranges for \(name)")
            }
            let buckets: [OffsetRule] = try columns.map {
                let cell = row[$0] ?? ""
                if cell == "tl" { return .transloc }
                if cell == "n/a" { return .seconds(0) }
                guard let value = Double(cell), value.isFinite else { throw ArrivalError.invalidData("Invalid offset for \(name)") }
                return .seconds(value)
            }
            data.offsets[name, default: []].append(OffsetSchedule(stopsAway: range, buckets: buckets))
        }
        return data
    }
}

// The bundled CSV files are unquoted numeric tables. Reject other formats explicitly.
nonisolated enum CSV {
    /// Reads the bundled unquoted CSV format and rejects malformed rows.
    static func read(_ url: URL) throws -> [[String: String]] {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard !text.contains("\"") else { throw ArrivalError.invalidData("Quoted CSV fields are unsupported") }
        let rows = text.split(whereSeparator: \.isNewline).map {
            $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }
        guard let header = rows.first, Set(header).count == header.count else { throw ArrivalError.invalidData("Invalid CSV header") }
        return try rows.dropFirst().map {
            guard $0.count == header.count else { throw ArrivalError.invalidData("Invalid CSV row") }
            return Dictionary(uniqueKeysWithValues: zip(header, $0))
        }
    }
}
