//
//  Metadate.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/27/26.
//

import Foundation
import SwiftData

@Model final class Metadata {
    @Attribute(.unique) var _id: String
    var mapLastUpdated: String
    var capacityLastUpdated: String
    var diningLastUpdated: String
    var microwaveLastUpdated: String
    var printerLastUpdated: String
    var vendingLastUpdated: String
    var eventsLastUpdated: String
    var newsLastUpdated: String = ""
    var datesLastUpdated: String = ""
    
    init(
        _id: String, mapLastUpdated: String, capacityLastUpdated: String,
        diningLastUpdated: String,
        microwaveLastUpdated: String, printerLastUpdated: String,
        vendingLastUpdated: String,
        eventsLastUpdated: String
    ) {
        self._id = _id
        self.mapLastUpdated = mapLastUpdated
        self.capacityLastUpdated = capacityLastUpdated
        self.diningLastUpdated = diningLastUpdated
        self.microwaveLastUpdated = microwaveLastUpdated
        self.printerLastUpdated = printerLastUpdated
        self.vendingLastUpdated = vendingLastUpdated
        self.eventsLastUpdated = eventsLastUpdated
    }
}
