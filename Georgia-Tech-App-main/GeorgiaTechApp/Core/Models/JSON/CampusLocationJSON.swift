//
//  CampusLocationJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/28/26.
//

import Foundation

nonisolated struct CampusLocationJSON: Decodable, Sendable {
    let _id: String
    let name: String
    let nameAbbreviated: String
    let lat: Double
    let lng: Double
    let img: String?
    let details: String?
    let isMainBuilding: Bool?
    let type: String
}
