//
//  BusStopJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/20/26.
//

import Foundation

nonisolated struct BusStopJSON: Decodable, Sendable {
    let addressID: Int
    let routeStopID: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let secondsAtStop: Int
    let secondsToNextStop: Int
    let stopOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case addressID = "AddressID"
        case routeStopID = "RouteStopID"
        case name = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case secondsAtStop = "SecondsAtStop"
        case secondsToNextStop = "SecondsToNextStop"
        case stopOrder = "Order"
    }
}
