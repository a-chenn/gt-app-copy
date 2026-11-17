//
//  SearchVM.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftUI

enum SearchQuery {
    case text(String)
    case category(SearchCategories)
}

struct SearchableData {
    let restaurants: [Restaurant]
    let locations: [CampusLocation]
    let appliances: [Appliance]
    var dietaryFilters: [DietaryFilter] = []
    var busRoutes: [BusRoute] = []
    var liveBuses: [BusLive] = []
    var stopEstimates: [Int: [BusStopEstimate]] = [:]
    var capacities: [BuildingCapacity] = []
    var userLocation: CLLocationCoordinate2D?
}

struct RecentSection: Identifiable {
    let id = UUID()
    let label: String
    let items: [SearchCardModel]
}

@Observable
@MainActor
final class SearchVM {
    private let externalSearchService = ExternalSearchService()
    private let campusSearchService = CampusSearchService()
    
    private(set) var recents: [RecentSection] = []
    
    var topThree: [SearchCardModel] {
        recents.flatMap(\.items).prefix(3).map { $0 }
    }
    
    var query: SearchQuery?
    var campusResults: [SearchCardModel] = []
    var externalResults: [MKMapItem] = []
    var activeCategory: SearchCategories?

    // Increments on every new search/clear so a slow text search that
    // resumes late can't clobber the results of a newer query.
    private var searchGeneration = 0

    var isSearching: Bool {
        query != nil
    }

    // True while a text search's external lookup is still awaiting (#U6):
    // the zero-results state must only render for a COMPLETED search —
    // empty arrays mid-flight mean "searching", not "no results".
    private(set) var isTextSearchInFlight = false

    // MARK: - Search

    func search(_ query: SearchQuery, data: SearchableData) async {
        switch query {
        case .text(let text):
            searchGeneration += 1
            let generation = searchGeneration
            self.query = query
            // Campus data first (#R4-15) — "h" must surface Howey before
            // New Hampshire. Combined cap of 30. Campus matches are
            // synchronous, so they show immediately (#U6) instead of
            // waiting behind the external network round-trip.
            activeCategory = nil
            campusResults = Array(campusSearchService.search(text: text, data: data).prefix(15))
            isTextSearchInFlight = true
            let results = await externalSearchService.search(text, near: data.userLocation)
            guard generation == searchGeneration else { return }
            isTextSearchInFlight = false
            externalResults = Array(results.prefix(30 - campusResults.count))
        case .category(let category):
            showCategory(category, data: data)
        }
    }

    /// Category results come from campus data alone, so they're
    /// synchronous: the sheet fills them in the same update that moves
    /// `MapSelection.activeCategory` (#14), with no empty frame between.
    func showCategory(_ category: SearchCategories, data: SearchableData) {
        searchGeneration += 1
        query = .category(category)
        activeCategory = category
        isTextSearchInFlight = false
        campusResults = campusSearchService.search(category, data: data)
        externalResults = []
    }

    func clearSearch() {
        searchGeneration += 1
        query = nil
        activeCategory = nil
        isTextSearchInFlight = false
        campusResults.removeAll()
        externalResults.removeAll()
    }
    
    // MARK: - Recents
    
    func loadRecents() {
        let items = RecentsService.shared.fetchAllAsCards()
        let calendar = Calendar.current
        let now = Date()
        
        let week = items.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }
        let month = items.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
            && !calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }
        let older = items.filter {
            !calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        
        recents = [
            RecentSection(label: "This Week", items: week),
            RecentSection(label: "This Month", items: month),
            RecentSection(label: "Older", items: older)
        ].filter { !$0.items.isEmpty }
    }
    
    func removeRecent(_ card: SearchCardModel) {
        RecentsService.shared.remove(card.id)
        loadRecents()
    }
    
    func clearSection(_ section: RecentSection) {
        for item in section.items {
            RecentsService.shared.remove(item.id)
        }
        loadRecents()
    }
}
