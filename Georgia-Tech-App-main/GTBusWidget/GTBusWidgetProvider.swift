//
//  GTBusWidgetProvider.swift
//  GTBusWidget
//

import WidgetKit
import Foundation

// Helper for ETA collection (avoids large_tuple violation)
private struct ETAInfo {
    let seconds: Int
    let routeName: String
    let mapColor: String
}

struct GTBusWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = GTBusEntry
    typealias Intent = BusStopIntent

    // MARK: - Required conformance

    func placeholder(in context: Context) -> GTBusEntry {
        GTBusEntry(
            date: .now, fetchedAt: .now,
            stopName: "Student Center",
            state: .arrivals([
                BusArrivalRow(routeName: "Blue Route", mapColor: "#003057", secondsToStop: 420),
                BusArrivalRow(routeName: "Gold Route", mapColor: "#B3A369", secondsToStop: 900)
            ]),
            routeStopID: 0
        )
    }

    func snapshot(
        for configuration: BusStopIntent,
        in context: Context
    ) async -> GTBusEntry {
        placeholder(in: context)
    }

    func timeline(
        for configuration: BusStopIntent,
        in context: Context
    ) async -> Timeline<GTBusEntry> {
        await buildTimeline(for: configuration)
    }

    // MARK: - Timeline building

    private func buildTimeline(for configuration: BusStopIntent) async -> Timeline<GTBusEntry> {
        let now = Date()
        let tenMinutesOut = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now

        guard let stop = configuration.stop else {
            let entry = GTBusEntry(date: now, fetchedAt: now,
                                   stopName: "No stop selected", state: .notConfigured, routeStopID: 0)
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }

        do {
            let (routes, rawEstimates) = try await fetchBothEndpoints()
            return makeTimeline(
                stop: stop, routes: routes, rawEstimates: rawEstimates, now: now)
        } catch {
            let entry = GTBusEntry(date: now, fetchedAt: now,
                                   stopName: stop.displayName,
                                   state: .fetchFailed(lastFetchedAt: nil),
                                   routeStopID: stop.id)
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }
    }

    private func fetchBothEndpoints() async throws -> ([BusSlimRouteJSON], [BusStopEstimateRouteJSON]) {
        async let routes = fetchRoutes()
        async let estimates = fetchEstimates()
        return try await (routes, estimates)
    }

    private func fetchRoutes() async throws -> [BusSlimRouteJSON] {
        let url = URL(string: "https://bus.gatech.edu/Services/JSONPRelay.svc/GetRoutesForMapWithScheduleWithEncodedLine")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BusSlimRouteJSON].self, from: data)
    }

    private func fetchEstimates() async throws -> [BusStopEstimateRouteJSON] {
        let url = URL(string: "https://bus.gatech.edu/Services/JSONPRelay.svc/GetMapStopEstimates")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BusStopEstimateRouteJSON].self, from: data)
    }

    private func makeTimeline(
        stop: BusStopEntity,
        routes: [BusSlimRouteJSON],
        rawEstimates: [BusStopEstimateRouteJSON],
        now: Date
    ) -> Timeline<GTBusEntry> {
        let tenMinutesOut = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now
        let estimates = BusStopEstimate.byStop(rawEstimates)

        // Per-physical-stop: check if any routeStopID with this stopAddressID exists
        let allStopsAtAddress = routes.flatMap { $0.stops }.filter { $0.stopAddressID == stop.id }
        guard !allStopsAtAddress.isEmpty else {
            let entry = GTBusEntry(date: now, fetchedAt: now,
                                   stopName: stop.displayName, state: .stopGone,
                                   routeStopID: stop.id)
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }

        // Gather running routes serving this physical stop
        let servingRoutes = routes.filter { route in
            route.isRunning && route.stops.contains { $0.stopAddressID == stop.id }
        }
        guard !servingRoutes.isEmpty else {
            let entry = GTBusEntry(date: now, fetchedAt: now,
                                   stopName: stop.displayName, state: .noService,
                                   routeStopID: stop.id)
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }

        // Gather all ETAs across all running routes at this physical stop
        // Each route may have a different routeStopID at this address
        let allETAs: [ETAInfo] = servingRoutes.flatMap { route -> [ETAInfo] in
            // Find the routeStopID for this route at this address
            guard let routeStop = route.stops.first(where: { $0.stopAddressID == stop.id }) else {
                return []
            }
            return BusArrivalsWidget.etas(to: routeStop.routeStopID, estimates: estimates).map {
                ETAInfo(seconds: $0, routeName: route.name, mapColor: route.mapColor)
            }
        }.sorted { $0.seconds < $1.seconds }

        guard !allETAs.isEmpty else {
            let entry = GTBusEntry(date: now, fetchedAt: now,
                                   stopName: stop.displayName, state: .noArrivals,
                                   routeStopID: stop.id)
            return Timeline(entries: [entry], policy: .after(tenMinutesOut))
        }

        // Build countdown entries
        // COUNTDOWN_HORIZON: 20 minutes (Q3 answered)
        let countdownHorizonSeconds = 20 * 60
        var entries: [GTBusEntry] = []

        if let soonest = allETAs.first, soonest.seconds <= countdownHorizonSeconds {
            // Emit one entry per minute from now until the soonest bus arrives
            let minuteCount = min(soonest.seconds / 60, 20)
            for minute in 0...minuteCount {
                let entryDate = Calendar.current.date(byAdding: .second, value: minute * 60, to: now) ?? now
                // Each entry shows ETAs as they'll be AT that moment (subtract elapsed seconds)
                let rows = allETAs.prefix(3).compactMap { eta -> BusArrivalRow? in
                    let remaining = eta.seconds - (minute * 60)
                    guard remaining >= 0 else { return nil }
                    return BusArrivalRow(routeName: eta.routeName, mapColor: eta.mapColor, secondsToStop: remaining)
                }
                let state: BusWidgetState = rows.isEmpty ? .checking : .arrivals(rows)
                entries.append(GTBusEntry(date: entryDate, fetchedAt: now,
                                          stopName: stop.displayName, state: state,
                                          routeStopID: stop.id))
            }
            // After countdown, one "checking" entry until the next refresh
            let checkingDate = Calendar.current.date(byAdding: .second, value: soonest.seconds + 60, to: now) ?? now
            entries.append(GTBusEntry(date: checkingDate, fetchedAt: now,
                                      stopName: stop.displayName, state: .checking,
                                      routeStopID: stop.id))
        } else {
            // Beyond the horizon — one honest static entry
            entries.append(GTBusEntry(date: now, fetchedAt: now,
                                      stopName: stop.displayName,
                                      state: .arrivals(allETAs.prefix(3).map {
                                          BusArrivalRow(routeName: $0.routeName,
                                                        mapColor: $0.mapColor,
                                                        secondsToStop: $0.seconds)
                                      }),
                                      routeStopID: stop.id))
        }

        return Timeline(entries: entries, policy: .after(tenMinutesOut))
    }
}
