//
//  BusJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 2/27/26.
//

import Foundation

nonisolated struct BusLocationJSON: Decodable, Sendable {
    let vehicleID: Int
    let routeID: Int
    let busLatitude: Double
    let busLongitude: Double
    let heading: Int
    let groundSpeed: Double?
    let sourceTimestamp: Date?
    let isDelayed: Bool
    let isOnRoute: Bool
    let name: String?
    
    /// Accepts numeric or string relay fields and validates required vehicle data.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        /// Reads a finite numeric value from a number or numeric string.
        func number(_ key: CodingKeys) -> Double? {
            let value = (try? values.decode(Double.self, forKey: key))
                ?? (try? values.decode(String.self, forKey: key)).flatMap(Double.init)
            return value.flatMap { $0.isFinite ? $0 : nil }
        }
        /// Reads a required integer identifier from a number or numeric string.
        func integer(_ key: CodingKeys) throws -> Int {
            if let value = try? values.decode(Int.self, forKey: key) { return value }
            if let text = try? values.decode(String.self, forKey: key), let value = Int(text) { return value }
            throw DecodingError.dataCorruptedError(forKey: key, in: values, debugDescription: "Missing vehicle identifier")
        }
        guard let latitude = number(.busLatitude), let longitude = number(.busLongitude) else {
            throw DecodingError.dataCorruptedError(forKey: .busLatitude, in: values, debugDescription: "Invalid vehicle coordinate")
        }
        vehicleID = try integer(.vehicleID)
        routeID = try integer(.routeID)
        busLatitude = latitude
        busLongitude = longitude
        heading = try values.decode(Int.self, forKey: .heading)
        groundSpeed = number(.groundSpeed)
        sourceTimestamp = (try? values.decode(String.self, forKey: .sourceTimestamp)).flatMap(Timestamp.parse)
        isDelayed = (try? values.decode(Bool.self, forKey: .isDelayed)) ?? false
        isOnRoute = (try? values.decode(Bool.self, forKey: .isOnRoute)) ?? true
        name = (try? values.decode(String.self, forKey: .name))
            ?? (try? values.decode(Int.self, forKey: .name)).map(String.init)
    }

    enum CodingKeys: String, CodingKey {
        case vehicleID = "VehicleID"
        case routeID = "RouteID"
        case busLatitude = "Latitude"
        case busLongitude = "Longitude"
        case heading = "Heading"
        case groundSpeed = "GroundSpeed"
        case sourceTimestamp = "TimeStamp"
        case isDelayed = "IsDelayed"
        case isOnRoute = "IsOnRoute"
        case name = "Name"
    }
}
