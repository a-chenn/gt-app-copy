//
//  GTDataService+CampusLocations.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadCampusLocations(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await locationFetcher.load(context: context, forceRefresh: forceRefresh) {
            let results: [CampusLocationJSON] = try await fetch("map/")
            let existing = try context.fetch(FetchDescriptor<CampusLocation>())
            let byID = Dictionary(
                uniqueKeysWithValues: existing.map { ($0.locationId, $0) })
            let fetchedIDs = Set(results.map(\._id))
            
            for json in results {
                if let loc = byID[json._id] {
                    loc.update(from: json)
                } else {
                    let loc = CampusLocation(json: json)
                    context.insert(loc)
                }
            }
            for loc in existing where !fetchedIDs.contains(loc.locationId) {
                context.delete(loc)
            }
            try context.save()
        }
    }
}

extension CampusLocation {
    fileprivate convenience init(json: CampusLocationJSON) {
        self.init(
            locationId: json._id, name: json.name,
            nameAbbreviated: json.nameAbbreviated,
            latitude: json.lat, longitude: json.lng, img: json.img ?? "",
            details: json.details,
            isMainBuilding: json.isMainBuilding ?? false, type: json.type)
    }
    fileprivate func update(from json: CampusLocationJSON) {
        self.name = json.name
        self.nameAbbreviated = json.nameAbbreviated
        self.latitude = json.lat
        self.longitude = json.lng
        self.img = json.img ?? ""
        self.details = json.details
        self.isMainBuilding = json.isMainBuilding ?? false
        self.type = json.type
    }
}
