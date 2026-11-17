//
//  EventModel.swift
//  GeorgiaTechApp
//
//  Created by Jeet Ajmani on 2/26/26.
//

import Foundation
import SwiftData

struct RelatedLink: Codable, Identifiable {
    var id: String { url }
    let title: String
    let url: String
}

@Model final class Event: Identifiable {
    @Attribute(.unique) var eventID: String
    var title: String
    var body: String
    var summary: String
    var location: String?
    var startDate: Date
    var endDate: Date
    var timezone: String
    var invitedAudience: [String]
    var eventCategories: [String]
    var relatedLinks: [RelatedLink]
    var groups: [String]
    var contact: String?
    var createdGMT: String
    var changedGMT: String
    var lastUpdated: String
    var imageName: String = ""
    
    init(
        eventID: String = UUID().uuidString, title: String = "", body: String = "",
        summary: String = "", location: String? = nil, startDate: Date = Date(),
        endDate: Date = Date(),
        timezone: String = "America/New_York", invitedAudience: [String] = [],
        eventCategories: [String] = [], relatedLinks: [RelatedLink] = [],
        groups: [String] = [],
        contact: String? = nil, createdGMT: String = "", changedGMT: String = "",
        lastUpdated: String = "", imageName: String = ""
    ) {
        self.eventID = eventID
        self.title = title
        self.body = body
        self.summary = summary
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.timezone = timezone
        self.invitedAudience = invitedAudience
        self.eventCategories = eventCategories
        self.relatedLinks = relatedLinks
        self.groups = groups
        self.contact = contact
        self.createdGMT = createdGMT
        self.changedGMT = changedGMT
        self.lastUpdated = lastUpdated
        self.imageName = imageName
    }
}
