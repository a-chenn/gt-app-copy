//
//  GTDataService+Dining.swift
//  GeorgiaTechApp
//

import Foundation
import OSLog
import SwiftData

extension GTDataService {
    @discardableResult
    @MainActor func loadRestaurants(context: ModelContext, forceRefresh: Bool = false) async -> Bool {
        await restaurantFetcher.load(context: context, forceRefresh: forceRefresh) {
            try await syncAndReplace(endpoint: "dining/", context: context) { (json: RestaurantJSON) in
                Restaurant(json: json)
            }
        }
    }
}

extension Restaurant {
    fileprivate convenience init(json: RestaurantJSON) {
        self.init(
            restaurantID: json._id, name: json.name, address: json.address,
            latitude: json.latitude,
            longitude: json.longitude, hoursOpen: json.hoursOpen,
            restaurantType: json.restaurantType,
            paymentMethodsAccepted: json.paymentMethodsAccepted, website: json.website,
            img: json.img,
            lastUpdated: json.lastUpdated)
        self.menus = json.menus.map { RestaurantMenu(json: $0) }
    }
}

extension RestaurantMenu {
    fileprivate convenience init(json: MenuJSON) {
        self.init(
            menuID: json.id ?? 0, startDate: json.startDate, menuTypeId: json.menuTypeId
        )
        self.days = json.days.map { MenuDay(json: $0) }
    }
}

extension MenuDay {
    fileprivate convenience init(json: MenuDayJSON) {
        self.init(date: json.date)
        self.menuItems = json.menuItems.map { MenuItem(json: $0) }
    }
}

extension MenuItem {
    fileprivate convenience init(json: MenuItemJSON) {
        self.init(
            itemID: json.id, position: json.position, text: json.text,
            stationId: json.stationId,
            isStationHeader: json.isStationHeader, category: json.category,
            price: json.price,
            servingSize: json.servingSize, servingSizeAmount: json.servingSizeAmount,
            servingSizeUnit: json.servingSizeUnit)
        if let fJSON = json.food { self.food = Food(json: fJSON) }
    }
}

extension Food {
    fileprivate convenience init(json: RestaurantFoodJSON) {
        let nut = json.roundedNutritionInfo
        let nutrition = NutritionInfo(
            calories: nut.calories, gFat: nut.gFat, gSaturatedFat: nut.gSaturatedFat,
            gTransFat: nut.gTransFat, mgCholesterol: nut.mgCholesterol,
            gCarbs: nut.gCarbs,
            gAddedSugar: nut.gAddedSugar, gSugar: nut.gSugar,
            mgPotassium: nut.mgPotassium,
            mgSodium: nut.mgSodium, gFiber: nut.gFiber, gProtein: nut.gProtein,
            mgIron: nut.mgIron,
            mgCalcium: nut.mgCalcium, mgVitaminC: nut.mgVitaminC,
            iuVitaminA: nut.iuVitaminA,
            reVitaminA: nut.reVitaminA, mcgVitaminA: nut.mcgVitaminA,
            mgVitaminD: nut.mgVitaminD,
            mcgVitaminD: nut.mcgVitaminD)
        let serving = ServingSizeInfo(
            servingSizeAmount: json.servingSizeInfo.servingSizeAmount,
            servingSizeUnit: json.servingSizeInfo.servingSizeUnit)
        self.init(
            foodID: json.id, name: json.name, tags: json.tags,
            ingredients: json.ingredients,
            nutrition: nutrition, servingSize: serving)
    }
}
