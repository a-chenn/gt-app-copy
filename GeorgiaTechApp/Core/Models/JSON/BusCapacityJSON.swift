//
//  BusStopJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/27/26.
//

import Foundation

nonisolated struct BusCapacityJSON: Decodable, Sendable {
    let vehicleID: Int
    let capacity: Int
    let currentOccupation: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case vehicleID = "VehicleID"
        case capacity = "Capacity"
        case currentOccupation = "CurrentOccupation"
        case percentage = "Percentage"
    }
}
