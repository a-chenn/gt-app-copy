//
//  RecentsService.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import SwiftData

@Observable
@MainActor
final class RecentsService {
    static let shared = RecentsService()
    private var modelContext: ModelContext?
    
    private init() {}
    
    func configure(context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Write (single entry point)

    /// Records a place the user engaged with (viewed its detail card or
    /// requested directions) — the source of the Recents list.
    func record(_ model: SearchCardModel) {
        guard let context = modelContext else { return }

        let targetID = model.id
        let targetTitle = model.title
        let targetCategory = model.category.rawValue
        // Title matching (#24) exists ONLY for external results, whose
        // coordinate-suffixed ids differ per search. Campus data has
        // stable ids — and distinct campus places can share a title
        // (paired bus stops, one appliance type across buildings), so a
        // broad title match would silently merge them.
        let allowTitleMatch = model.category == .mapItem

        let descriptor = FetchDescriptor<RecentSearch>(
            predicate: #Predicate {
                $0.id == targetID
                    || (allowTitleMatch && $0.title == targetTitle && $0.category == targetCategory)
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.id = targetID
            existing.date = .now
            existing.subtitle = model.subtitle
            if let coordinate = model.coordinate {
                existing.latitude = coordinate.latitude
                existing.longitude = coordinate.longitude
            }
        } else {
            let recent = RecentSearch(
                id: targetID, title: model.title,
                subtitle: model.subtitle, image: model.image,
                category: model.category,
                latitude: model.coordinate?.latitude,
                longitude: model.coordinate?.longitude
            )
            context.insert(recent)
        }
        
        try? context.save()
        trimIfNeeded(context: context)
    }
    
    // MARK: - Read
    
    func fetchAll() -> [RecentSearch] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func fetchAllAsCards() -> [SearchCardModel] {
        fetchAll().map { $0.toSearchCard() }
    }
    
    // MARK: - Delete
    
    func remove(_ id: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<RecentSearch>(
            predicate: #Predicate { $0.id == id }
        )
        if let match = try? context.fetch(descriptor).first {
            context.delete(match)
            try? context.save()
        }
    }
    
    // MARK: - Trim
    
    private func trimIfNeeded(context: ModelContext, limit: Int = 50) {
        let all = fetchAll()
        guard all.count > limit else { return }
        for item in all.dropFirst(limit) {
            context.delete(item)
        }
        try? context.save()
    }
}
