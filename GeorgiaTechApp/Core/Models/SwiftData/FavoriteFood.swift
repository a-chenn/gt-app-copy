//
//  FavoriteFood.swift
//  GeorgiaTechApp
//

import Foundation
import SwiftData

/// A hearted menu item (#23). Keyed by food NAME, not menu-item id —
/// menus regenerate daily, so the name is the only stable identity a
/// dish has across days and dining halls.
@Model
final class FavoriteFood {
    @Attribute(.unique) var name: String
    var date: Date

    init(name: String, date: Date = .now) {
        self.name = name
        self.date = date
    }
}
