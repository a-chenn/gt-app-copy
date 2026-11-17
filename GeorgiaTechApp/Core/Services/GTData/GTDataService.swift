//
//  GTDataService.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

// MARK: - Logger
extension Logger {
    static let dataService = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.gtapp", category: "GTDataService")
}

// MARK: - Generic Data Fetcher
@MainActor final class DataFetcher<ModelType: PersistentModel> {
    private var isLoading = false
    private var hasLoaded = false

    /// Runs `fetchAction` unless local data is already usable.
    /// Returns `true` when local data is up to date afterwards (either the
    /// fetch succeeded or nothing needed refreshing), `false` on failure —
    /// callers use this to decide whether to commit new Metadata timestamps.
    @discardableResult
    func load(context: ModelContext, forceRefresh: Bool = false, fetchAction: () async throws -> Void) async -> Bool {
        guard !isLoading else { return false }
        if !forceRefresh && (hasLoaded || hasCachedModels(context: context)) {
            hasLoaded = true
            return true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await fetchAction()
            hasLoaded = true
            return true
        } catch {
            Logger.dataService.error(
                "Failed loading \(String(describing: ModelType.self)) data: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func hasCachedModels(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<ModelType>()
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor).isEmpty) == false)
    }
}

// MARK: - Data Service
final class GTDataService: Sendable {
    static let shared = GTDataService()
    private init() {}
    
    // Trackers isolated to MainActor for safe UI caching
    @MainActor let capacityFetcher = DataFetcher<BuildingCapacity>()
    @MainActor let applianceFetcher = DataFetcher<Appliance>()
    @MainActor let locationFetcher = DataFetcher<CampusLocation>()
    @MainActor let restaurantFetcher = DataFetcher<Restaurant>()
    @MainActor let routeFetcher = DataFetcher<BusRoute>()
    @MainActor let eventFetcher = DataFetcher<Event>()
    @MainActor let newsFetcher = DataFetcher<NewsArticle>()
    @MainActor let datesFetcher = DataFetcher<GTDate>()
    
    func fetch<T: Decodable & Sendable>(_ endpoint: String) async throws -> T {
        let url = try APIUtility.url(for: endpoint)
        return try await fetch(url: url)
    }
    
    // Used for Bus APIs
    func fetchAbsolute<T: Decodable & Sendable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        return try await fetch(url: url)
    }
    
    private func fetch<T: Decodable & Sendable>(url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        try response.validate()
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    @MainActor func syncAndReplace<JSONType: Decodable & Sendable, ModelType: PersistentModel>(
        endpoint: String, context: ModelContext,
        transform: @Sendable (JSONType) -> ModelType
    ) async throws {
        let jsonArray: [JSONType] = try await fetch(endpoint)
        try context.replaceExisting(with: jsonArray.map(transform))
    }
    
    @MainActor
    func syncAndReplace<ResponseType: Decodable & Sendable, ModelType: PersistentModel>(
        endpoint: String, context: ModelContext,
        extract: @Sendable (ResponseType) -> [ModelType]
    ) async throws {
        let response: ResponseType = try await fetch(endpoint)
        try context.replaceExisting(with: extract(response))
    }
    
    @MainActor func syncAll(context: ModelContext) async {
        // Local seed data, no network — safe to run every launch.
        try? loadDietaryFilters(context: context)

        // One metadata fetch decides which domains actually changed server-side;
        // unchanged domains skip their fetch entirely and serve cached data.
        let plan = await makeRefreshPlan(context: context)

        // TransLoc has no metadata timestamp, and isRunning changes during
        // the day — refresh routes/stops on every sync (once per launch).
        async let routesDone: Bool = loadBusRoutes(context: context, forceRefresh: true)
        async let diningDone: Bool = loadRestaurants(
            context: context, forceRefresh: plan.shouldRefreshDining)
        async let mapDone: Bool = loadCampusLocations(
            context: context, forceRefresh: plan.shouldRefreshMap)
        async let appliancesDone: Bool = loadAppliances(
            context: context, forceRefresh: plan.shouldRefreshAppliances)
        async let eventsDone: Bool = loadEvents(
            context: context, forceRefresh: plan.shouldRefreshEvents)
        async let newsDone: Bool = loadNews(
            context: context, forceRefresh: plan.shouldRefreshNews)
        async let datesDone: Bool = loadDates(
            context: context, forceRefresh: plan.shouldRefreshDates)
        async let capacityDone: Bool = loadCapacities(
            context: context, forceRefresh: plan.shouldRefreshCapacity)

        let (_, dining, map, appliances, events, news, dates, capacity) = await (
            routesDone, diningDone, mapDone, appliancesDone, eventsDone, newsDone,
            datesDone, capacityDone)

        commitMetadata(
            plan: plan, context: context,
            syncedDomains: MetadataDomains(
                dining: dining, map: map, appliances: appliances,
                capacity: capacity, events: events, news: news, dates: dates))
    }
}
