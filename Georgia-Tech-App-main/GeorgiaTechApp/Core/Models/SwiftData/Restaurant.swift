//
//  Restaurant.swift
//  GeorgiaTechApp
//
//  Created by Adam Ress on 2/10/26.
//

import CoreLocation
import Foundation
import SwiftData

@Model final class Restaurant: Identifiable {
    @Attribute(.unique) var restaurantID: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    @Attribute var hoursOpen: [[String]]?
    
    @Relationship(deleteRule: .cascade) var menus: [RestaurantMenu]
    var restaurantType: String
    var paymentMethodsAccepted: [String]
    var website: String?
    var img: String?
    var lastUpdated: String?
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    init(
        restaurantID: String, name: String, address: String, latitude: Double,
        longitude: Double,
        hoursOpen: [[String]]?, restaurantType: String, paymentMethodsAccepted: [String],
        website: String? = nil, img: String? = nil, lastUpdated: String? = nil,
        menus: [RestaurantMenu] = []
    ) {
        self.restaurantID = restaurantID
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.hoursOpen = hoursOpen
        self.menus = menus
        self.restaurantType = restaurantType
        self.paymentMethodsAccepted = paymentMethodsAccepted
        self.website = website
        self.img = img
        self.lastUpdated = lastUpdated
    }
}

@Model final class RestaurantMenu {
    @Attribute(.unique) var id: UUID = UUID()
    var menuID: Int?
    var startDate: String
    var menuTypeId: Int
    @Relationship(deleteRule: .cascade) var days: [MenuDay]
    @Relationship(inverse: \Restaurant.menus) var restaurant: Restaurant?
    init(menuID: Int?, startDate: String, menuTypeId: Int, days: [MenuDay] = []) {
        self.menuID = menuID
        self.startDate = startDate
        self.menuTypeId = menuTypeId
        self.days = days
    }
}

@Model final class MenuDay {
    var date: String
    @Relationship(deleteRule: .cascade) var menuItems: [MenuItem]
    @Relationship(inverse: \RestaurantMenu.days) var menu: RestaurantMenu?
    init(date: String, menuItems: [MenuItem] = []) {
        self.date = date
        self.menuItems = menuItems
    }
}

@Model final class MenuItem {
    @Attribute(.unique) var itemID: Int
    var position: Int
    var text: String
    var stationId: Int?
    var isStationHeader: Bool
    var category: String?
    var price: Float?
    var servingSize: String?
    var servingSizeAmount: Float?
    var servingSizeUnit: String?
    @Relationship(deleteRule: .cascade) var food: Food?
    @Relationship(inverse: \MenuDay.menuItems) var menuDay: MenuDay?
    init(
        itemID: Int, position: Int, text: String, stationId: Int?, isStationHeader: Bool,
        category: String?, price: Float?, servingSize: String?, servingSizeAmount: Float?,
        servingSizeUnit: String?, food: Food? = nil
    ) {
        self.itemID = itemID
        self.position = position
        self.text = text
        self.stationId = stationId
        self.isStationHeader = isStationHeader
        self.category = category
        self.price = price
        self.servingSize = servingSize
        self.servingSizeAmount = servingSizeAmount
        self.servingSizeUnit = servingSizeUnit
        self.food = food
    }
}

@Model final class Food {
    @Attribute(.unique) var id: UUID = UUID()
    var foodID: Int?
    var name: String
    @Attribute var tags: [String]
    var ingredients: String?
    @Attribute var nutrition: NutritionInfo?
    @Attribute var servingSize: ServingSizeInfo?
    @Relationship(inverse: \MenuItem.food) var menuItem: MenuItem?
    init(
        foodID: Int, name: String, tags: [String], ingredients: String?,
        nutrition: NutritionInfo?,
        servingSize: ServingSizeInfo?
    ) {
        self.foodID = foodID
        self.name = name
        self.tags = tags
        self.ingredients = ingredients
        self.nutrition = nutrition
        self.servingSize = servingSize
    }
}

// These can be simple Codable structs since they are strictly 1:1 with Food and don't need independent querying
struct NutritionInfo: Codable {
    var calories: Float?
    var gFat: Float?
    var gSaturatedFat: Float?
    var gTransFat: Float?
    var mgCholesterol: Float?
    var gCarbs: Float?
    var gAddedSugar: Float?
    var gSugar: Float?
    var mgPotassium: Float?
    var mgSodium: Float?
    var gFiber: Float?
    var gProtein: Float?
    var mgIron: Float?
    var mgCalcium: Float?
    var mgVitaminC: Float?
    var iuVitaminA: Float?
    var reVitaminA: Float?
    var mcgVitaminA: Float?
    var mgVitaminD: Float?
    var mcgVitaminD: Float?
}

struct ServingSizeInfo: Codable {
    var servingSizeAmount: String?
    var servingSizeUnit: String?
}
