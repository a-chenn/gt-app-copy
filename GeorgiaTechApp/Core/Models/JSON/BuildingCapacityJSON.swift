//
//  BuildingCapacityJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/27/26.
//

import Foundation

nonisolated struct BuildingCapacityResponseJSON: Decodable, Sendable {
    let data: [BuildingCapacityJSON]
}

nonisolated struct BuildingCapacityJSON: Decodable, Sendable {
    let id: Int
    let name: String
    let busyness: Int
    let people: Int
    let percentage: Double
    let capacity: Int
    let isAvailable: Bool
    let isOpen: Bool
    let hourSummary: String
    let subLocs: [BuildingSubLocationCapacityJSON]?
}

nonisolated struct BuildingSubLocationCapacityJSON: Codable, Sendable {
    let id: Int
    let name: String
    let busyness: Int
    let people: Int
    let percentage: Double
    let capacity: Int
}

// MARK: - BuildingCapacityJSON helpers

extension BuildingCapacityJSON {
    /// Mirrors BuildingCapacity.shortName in the app's SwiftData model.
    /// Must stay in sync if that property ever changes.
    var shortName: String {
        let lower = name.lowercased()
        if lower.contains("recreation") { return "CRC" }
        if lower.contains("price gilbert") { return "Library" }
        if lower.contains("clough") { return "Clough" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }
}
