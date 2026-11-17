//
//  MetadataJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/29/26.
//

import Foundation

nonisolated struct MetadataJSON: Decodable, Sendable {
    let id: String
    // All timestamps are OPTIONAL: a single missing key must not fail the
    // whole metadata decode (which would set server=nil and freeze EVERY
    // domain's sync). A nil stamp is treated as "attempt a refresh".
    let mapLastUpdated: String?
    let capacityLastUpdated: String?
    let diningLastUpdated: String?
    let microwaveLastUpdated: String?
    let printerLastUpdated: String?
    let vendingLastUpdated: String?
    let eventsLastUpdated: String?
    let newsLastUpdated: String?
    let datesLastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case mapLastUpdated, capacityLastUpdated
        case diningLastUpdated, microwaveLastUpdated, printerLastUpdated,
             vendingLastUpdated,
             eventsLastUpdated, newsLastUpdated, datesLastUpdated
    }
}
