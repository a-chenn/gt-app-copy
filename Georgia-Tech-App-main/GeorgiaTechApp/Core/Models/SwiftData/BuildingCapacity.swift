//
//  BuildingCapacity.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/27/26.
//

import Foundation
import SwiftData

@Model final class BuildingCapacity: Identifiable {
    @Attribute(.unique) var capacityID: Int
    var name: String
    var busyness: Int
    var people: Int
    var percentage: Double
    var capacity: Int
    var isAvailable: Bool
    var isOpen: Bool
    var hourSummary: String
    // Storing as an array of structs works in SwiftData if they are Codable.
    // Could make BuildingSubLocationCapacity an @Model too, but we are never just querying specific floors without the building
    @Attribute var subLocs: [BuildingSubLocationCapacity]?
    init(
        capacityID: Int, name: String, busyness: Int, people: Int, percentage: Double,
        capacity: Int,
        isAvailable: Bool, isOpen: Bool, hourSummary: String,
        subLocs: [BuildingSubLocationCapacity]? = nil
    ) {
        self.capacityID = capacityID
        self.name = name
        self.busyness = busyness
        self.people = people
        self.percentage = percentage
        self.capacity = capacity
        self.isAvailable = isAvailable
        self.isOpen = isOpen
        self.hourSummary = hourSummary
        self.subLocs = subLocs
    }
}

struct BuildingSubLocationCapacity: Codable, Identifiable {
    let id: Int
    let name: String
    let busyness: Int
    let people: Int
    let percentage: Double
    let capacity: Int
}

extension BuildingCapacity {
    /// "Clough Undergraduate Learning Commons" doesn't fit a tile caption
    /// or a filter capsule. Known names get the name students actually
    /// use; anything else falls back to its first word.
    var shortName: String {
        let lower = name.lowercased()
        if lower.contains("recreation") { return "CRC" }
        if lower.contains("price gilbert") { return "Library" }
        if lower.contains("clough") { return "Clough" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }
}
