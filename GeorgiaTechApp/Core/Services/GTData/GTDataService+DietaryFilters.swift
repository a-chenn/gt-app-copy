//
//  GTDataService+DietaryFilters.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    /// Seeds the shared dietary tag catalog while preserving existing cached filters.
    @MainActor func loadDietaryFilters(context: ModelContext, forceRefresh: Bool = false) throws {
        let existing = try context.fetch(FetchDescriptor<DietaryFilter>())
        
        guard forceRefresh || existing.isEmpty else { return }
        
        let filters = DietaryTag.allCases.map { tag in
            DietaryFilter(
                id: tag.rawValue, name: tag.displayName, img: tag.rawValue,
                categoryRaw: tag.category.rawValue)
        }
        try context.replaceExisting(with: filters)
    }
}
