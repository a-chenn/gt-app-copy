//
//  EventJSON.swift
//  GeorgiaTechApp
//

import Foundation

nonisolated struct EventResponseJSON: Decodable, Sendable {
    let events: [EventJSON]
    let totalCount: Int
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case events
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

nonisolated struct EventJSON: Decodable, Sendable {
    let id: String
    let title: String
    let body: String
    let summary: String
    let location: String?
    let eventTime: EventTimeJSON
    let invitedAudience: [EventNamedValueJSON]
    let eventCategories: [EventNamedValueJSON]
    let relatedLinks: [EventRelatedLinkJSON]
    let groups: [EventNamedValueJSON]
    let contact: String?
    let createdGMT: String
    let changedGMT: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, summary, location, groups, contact
        case eventTime = "event_time"
        case invitedAudience = "invited_audience"
        case eventCategories = "event_categories"
        case relatedLinks = "related_links"
        case createdGMT = "created_gmt"
        case changedGMT = "changed_gmt"
    }
}

nonisolated struct EventTimeJSON: Decodable, Sendable {
    let eventTimeStart: String
    let eventTimeEnd: String
    let timezone: String
    
    enum CodingKeys: String, CodingKey {
        case eventTimeStart = "event_time_start"
        case eventTimeEnd = "event_time_end"
        case timezone
    }
}

nonisolated struct EventNamedValueJSON: Decodable, Sendable {
    let id: String
    let name: String
}

nonisolated struct EventRelatedLinkJSON: Decodable, Sendable {
    let url: String
    let title: String
}
