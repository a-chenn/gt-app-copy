//
//  GTDataService+BuildingCapacity.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadCapacities(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await capacityFetcher.load(context: context, forceRefresh: forceRefresh) {
            try await syncAndReplace(endpoint: "capacity/", context: context) { (res: BuildingCapacityResponseJSON) in
                res.data.map { BuildingCapacity(json: $0) }
            }
        }
    }
}

extension BuildingCapacity {
    fileprivate convenience init(json: BuildingCapacityJSON) {
        self.init(
            capacityID: json.id, name: json.name, busyness: json.busyness,
            people: json.people,
            percentage: json.percentage, capacity: json.capacity,
            isAvailable: json.isAvailable,
            isOpen: json.isOpen, hourSummary: json.hourSummary,
            subLocs: json.subLocs?.map { BuildingSubLocationCapacity(json: $0) })
    }
}

extension BuildingSubLocationCapacity {
    fileprivate init(json: BuildingSubLocationCapacityJSON) {
        self.init(
            id: json.id, name: json.name, busyness: json.busyness, people: json.people,
            percentage: json.percentage, capacity: json.capacity)
    }
}
