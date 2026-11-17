//
//  DietaryFilter.swift
//  GeorgiaTechApp
//
//  Created by Arshiya Vyas on 4/7/26.
//

import Foundation
import SwiftData

/// Dietary tags with stable filter IDs and bundled asset names as raw values.
enum DietaryTag: String, CaseIterable {
    case beef = "Beef"
    case coconut = "Coconut"
    case containingGluten = "Containing Gluten"
    case corn = "Corn"
    case egg = "Egg"
    case fish = "Fish"
    case milk = "Milk"
    case peanuts = "Peanuts"
    case pork = "Pork"
    case poultry = "Poultry"
    case glutenFriendly = "PrfGluten Friendly"
    case halal = "PrfHalal"
    case kosher = "PrfKosher"
    case vegan = "PrfVegan"
    case vegetarian = "PrfVegetarian"
    case sesame = "Sesame"
    case shellfish = "Shellfish"
    case soy = "Soy"
    case treeNuts = "Tree Nuts"
    case wheat = "Wheat"

    var displayName: String {
        let name = category == .preference ? String(rawValue.dropFirst(3)) : rawValue
        return name.capitalized
    }

    var category: DietaryFilter.Category {
        switch self {
        case .glutenFriendly, .halal, .kosher, .vegan, .vegetarian:
            return .preference
        default:
            return .allergen
        }
    }

    var apiTag: String {
        switch self {
        case .containingGluten: return "Gluten"
        case .egg: return "Eggs Allergen"
        case .fish: return "Fish Allergen"
        case .shellfish: return "Shellfish Allergen"
        case .soy: return "Soy Allergen"
        case .treeNuts: return "Tree Nuts Allergen"
        case .wheat: return "Wheat Allergen"
        default: return displayName
        }
    }
}

@Model final class DietaryFilter: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var img: String
    var categoryRaw: String
    var category: Category { Category(rawValue: categoryRaw) ?? .preference }
    enum Category: String, Codable {
        case preference
        case allergen
    }
    init(id: String, name: String, img: String, categoryRaw: String) {
        self.id = id
        self.name = name
        self.img = img
        self.categoryRaw = categoryRaw
    }

    /// Matches lowercased food tags against this filter's ID, label, or API tag.
    func matches(normalizedTags: Set<String>) -> Bool {
        if normalizedTags.contains(id.lowercased()) || normalizedTags.contains(name.lowercased()) {
            return true
        }
        guard let tag = DietaryTag(rawValue: id) else { return false }
        return normalizedTags.contains(tag.apiTag.lowercased())
    }
}
