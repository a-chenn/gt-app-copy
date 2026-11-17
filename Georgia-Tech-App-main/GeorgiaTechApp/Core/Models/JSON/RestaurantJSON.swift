//
//  RestaurantJSON.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 3/27/26.
//

import Foundation

nonisolated struct RestaurantJSON: Decodable, Sendable {
    let _id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let menus: [MenuJSON]
    let restaurantType: String
    let paymentMethodsAccepted: [String]
    let website: String?
    let hoursOpen: [[String]]?
    let img: String?
    let lastUpdated: String?
    enum CodingKeys: String, CodingKey {
        case _id, name, address, menus, website, img, latitude, longitude
        case hoursOpen = "hours_open"
        case restaurantType = "restaurant_type"
        case paymentMethodsAccepted = "payment_methods_accepted"
        case lastUpdated = "last_updated"
    }
}

nonisolated struct MenuJSON: Codable, Sendable {
    let id: Int?  // Integer Id for this document
    let startDate: String  // The start date of the week this menu covers (ISO 8601 format, e.g., '2026-02-09')
    let menuTypeId: Int  // ID referencing the dining location/menu type (e.g., a specific dining hall)
    let days: [MenuDayJSON]  // List of daily menus for the week, typically 7 entries
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
        case menuTypeId = "menu_type_id"
        case days
    }
}

// Represents all menu items served on a single calendar date
nonisolated struct MenuDayJSON: Codable, Sendable {
    let date: String  // ISO 8601 date string for this menu day (e.g., '2026-02-08')
    let menuItems: [MenuItemJSON]  // Ordered list of menu line items (station headers + food entries) for this date
    
    enum CodingKeys: String, CodingKey {
        case date = "date"
        case menuItems = "menu_items"
    }
}

// Represents a single line item on a dining menu.
// May be either a station header (grouping label) or an actual food entry.
nonisolated struct MenuItemJSON: Codable, Sendable {
    let id: Int  // Unique integer ID for this menu line item
    let position: Int  // Display order/position within the day's menu
    let text: String  // Display text for the item (used for station headers; empty for food items)
    let food: RestaurantFoodJSON?  // The associated food item; none when this entry is a station header
    let stationId: Int?  // ID of the dining station this item belongs to
    let isStationHeader: Bool  // True if this row is a section header for a station, not an actual food item
    let category: String?  // Optional category label for the item (e.g., 'other'); may be empty string
    let price: Float?  // Price of the item; typically 0 for included dining hall items
    let servingSize: String?  // Legacy serving size field; usually null; superseded by food.serving_size_info
    let servingSizeAmount: Float?  // Numeric serving size amount at the menu-item level
    let servingSizeUnit: String?  // Unit for serving_size_amount at the menu-item level (e.g., 'slice', 'cup')
    
    enum CodingKeys: String, CodingKey {
        case id
        case position
        case text
        case food
        case stationId = "station_id"
        case isStationHeader = "is_station_header"
        case category
        case price
        case servingSize = "serving_size"
        case servingSizeAmount = "serving_size_amount"
        case servingSizeUnit = "serving_size_unit"
    }
}

// Represents a specific food item in the GT dining system, including its nutritional profile, serving info, dietary tags, and ingredient list.
nonisolated struct RestaurantFoodJSON: Codable, Sendable {
    let id: Int  // Unique integer ID for the food item
    let name: String  // Display name of the food item (e.g., 'Turkey Bacon')
    let roundedNutritionInfo: NutritionJSON  // Rounded nutritional values per serving
    let servingSizeInfo: ServingSizeJSON  // Serving size amount and unit
    let tags: [String]  // Array of dietary tags (e.g., vegan, gluten-free). Often empty
    let ingredients: String?  // Full ingredient string listing all components of the food item
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case roundedNutritionInfo = "rounded_nutrition_info"
        case servingSizeInfo = "serving_size_info"
        case tags
        case ingredients
    }
}

// Rounded nutritional information for a single food item per serving.
// All fields are optional since many values may be null/unreported.
nonisolated struct NutritionJSON: Codable, Sendable {
    let calories: Float?  // Total calories per serving
    let gFat: Float?  // Total fat in grams
    let gSaturatedFat: Float?  // Saturated fat in grams
    let gTransFat: Float?  // Trans fat in grams
    let mgCholesterol: Float?  // Cholesterol in milligrams
    let gCarbs: Float?  // Total carbohydrates in grams
    let gAddedSugar: Float?  // Added sugars in grams
    let gSugar: Float?  // Total sugars in grams
    let mgPotassium: Float?  // Potassium in milligrams
    let mgSodium: Float?  // Sodium in milligrams
    let gFiber: Float?  // Dietary fiber in grams
    let gProtein: Float?  // Protein in grams
    let mgIron: Float?  // Iron in milligrams
    let mgCalcium: Float?  // Calcium in milligrams
    let mgVitaminC: Float?  // Vitamin C in milligrams
    let iuVitaminA: Float?  // Vitamin A in International Units
    let reVitaminA: Float?  // Vitamin A in Retinol Equivalents
    let mcgVitaminA: Float?  // Vitamin A in micrograms
    let mgVitaminD: Float?  // Vitamin D in milligrams
    let mcgVitaminD: Float?  // Vitamin D in micrograms
    
    enum CodingKeys: String, CodingKey {
        case calories
        case gFat = "g_fat"
        case gSaturatedFat = "g_saturated_fat"
        case gTransFat = "g_trans_fat"
        case mgCholesterol = "mg_cholesterol"
        case gCarbs = "g_carbs"
        case gAddedSugar = "g_added_sugar"
        case gSugar = "g_sugar"
        case mgPotassium = "mg_potassium"
        case mgSodium = "mg_sodium"
        case gFiber = "g_fiber"
        case gProtein = "g_protein"
        case mgIron = "mg_iron"
        case mgCalcium = "mg_calcium"
        case mgVitaminC = "mg_vitamin_c"
        case iuVitaminA = "iu_vitamin_a"
        case reVitaminA = "re_vitamin_a"
        case mcgVitaminA = "mcg_vitamin_a"
        case mgVitaminD = "mg_vitamin_d"
        case mcgVitaminD = "mcg_vitamin_d"
    }
}

// Describes the serving size of a food item as a human-readable amount and unit.
nonisolated struct ServingSizeJSON: Codable, Sendable {
    let servingSizeAmount: String?  // Serving size quantity as a string (e.g., '1', '0.5', '2.75')
    let servingSizeUnit: String?  // Unit of the serving size (e.g., 'slice', 'cup', 'oz')
    
    enum CodingKeys: String, CodingKey {
        case servingSizeAmount = "serving_size_amount"
        case servingSizeUnit = "serving_size_unit"
    }
}
