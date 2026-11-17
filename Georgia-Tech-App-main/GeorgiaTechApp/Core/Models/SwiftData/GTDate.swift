//
//  GTDate.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData

/// One official GT academic date (deadline, break, registration
/// window). Admin-maintained server-side; synced like every other
/// metadata-gated domain.
@Model
final class GTDate {
    @Attribute(.unique) var dateID: String
    var title: String
    /// First day (UTC midnight) — the sort/filter key.
    var date: Date
    /// Display text, e.g. "March 17-21".
    var dateText: String
    var category: String

    init(dateID: String, title: String, date: Date, dateText: String, category: String) {
        self.dateID = dateID
        self.title = title
        self.date = date
        self.dateText = dateText
        self.category = category
    }
}
