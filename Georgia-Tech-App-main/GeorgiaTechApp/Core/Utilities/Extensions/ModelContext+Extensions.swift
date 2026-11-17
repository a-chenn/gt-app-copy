//
//  ModelContext+Extensions.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData

extension ModelContext {
    /// Replaces all existing persistent models of a specific type with the provided array of models.
    func replaceExisting<ModelType: PersistentModel>(with models: [ModelType]) throws {
        let existing = try self.fetch(FetchDescriptor<ModelType>())
        existing.forEach { self.delete($0) }
        models.forEach { self.insert($0) }
        try self.save()
    }
}
