//
//  GTDataService+Appliances.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadAppliances(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await applianceFetcher.load(context: context, forceRefresh: forceRefresh) {
            async let printersTask: [ApplianceJSON] = fetch("printer/")
            async let microwavesTask: [ApplianceJSON] = fetch("microwave/")
            async let vendingTask: [ApplianceJSON] = fetch("vending/")
            let (pJSON, mJSON, vJSON) = try await (
                printersTask, microwavesTask, vendingTask
            )
            let printers = pJSON.map { Appliance(json: $0, type: .printer) }
            let microwaves = mJSON.map { Appliance(json: $0, type: .microwave) }
            let vending = vJSON.map { Appliance(json: $0, type: .vending) }
            try context.replaceExisting(with: printers + microwaves + vending)
        }
    }
}

extension Appliance {
    fileprivate convenience init(json: ApplianceJSON, type: ApplianceType) {
        self.init(
            id: json._id, type: type, building: json.building, floor: json.floor,
            room: json.room,
            latitude: json.coordinates.latitude, longitude: json.coordinates.longitude,
            details: json.details, color: json.color)
    }
}
