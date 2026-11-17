//
//  ApplianceJSON.swift
//  GeorgiaTechApp
//

import Foundation

nonisolated struct ApplianceJSON: Codable, Sendable {
    var _id: String
    var building: String
    var floor: [Int]
    var room: String
    var details: String
    let coordinates: CoordinatesJSON
    var color: Bool?
}
