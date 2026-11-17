//
//  FavoritesService.swift
//  GeorgiaTechApp
//

import CoreLocation
import Foundation
import SwiftData

/// SwiftData-backed favorites, mirroring `RecentsService`'s shape.
/// `favoriteIDs` is observable so heart toggles update instantly.
@Observable
@MainActor
final class FavoritesService {
    static let shared = FavoritesService()
    private var modelContext: ModelContext?

    private(set) var favoriteIDs: Set<String> = []
    /// Hearted menu items, keyed by food name (#23).
    private(set) var favoriteFoodNames: Set<String> = []

    private init() {}

    func configure(context: ModelContext) {
        self.modelContext = context
        reloadIDs()
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    // MARK: - Food favorites (#23)

    func isFoodFavorited(_ name: String) -> Bool {
        favoriteFoodNames.contains(name)
    }

    func toggleFood(_ name: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoriteFood>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            context.insert(FavoriteFood(name: name))
        }
        try? context.save()
        reloadIDs()
    }

    func toggle(_ model: SearchCardModel) {
        guard let context = modelContext else { return }

        let targetID = model.id
        let descriptor = FetchDescriptor<FavoritePlace>(
            predicate: #Predicate { $0.id == targetID }
        )

        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            let favorite = FavoritePlace(
                id: targetID, title: model.title,
                subtitle: model.subtitle, image: model.image,
                category: model.category,
                latitude: model.coordinate?.latitude,
                longitude: model.coordinate?.longitude
            )
            context.insert(favorite)
        }

        try? context.save()
        reloadIDs()
    }

    func remove(_ id: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoritePlace>(
            predicate: #Predicate { $0.id == id }
        )
        if let match = try? context.fetch(descriptor).first {
            context.delete(match)
            try? context.save()
            reloadIDs()
        }
    }

    func fetchAllAsCards() -> [SearchCardModel] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FavoritePlace>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toSearchCard() }
    }

    private func reloadIDs() {
        guard let context = modelContext else { return }
        let all = (try? context.fetch(FetchDescriptor<FavoritePlace>())) ?? []
        favoriteIDs = Set(all.map(\.id))
        let foods = (try? context.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        favoriteFoodNames = Set(foods.map(\.name))
    }
}
