//
//  GTDateJSON.swift
//  GeorgiaTechApp
//

import Foundation

nonisolated struct GTDatesResponseJSON: Decodable, Sendable {
    let dates: [GTDateJSON]
    let totalCount: Int
    let lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case dates
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

nonisolated struct GTDateJSON: Decodable, Sendable {
    let id: String
    let title: String
    /// ISO8601 UTC midnight of the (first) day.
    let date: String
    /// Human display text, e.g. "March 17-21".
    let dateText: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, title, date, category
        case dateText = "date_text"
    }
}
