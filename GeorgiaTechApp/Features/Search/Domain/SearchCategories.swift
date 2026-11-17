//
//  SearchCategories.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import Foundation

enum SearchCategories: String, CaseIterable, Identifiable {
    case dining
    case academicBuildings
    case athletics
    case dorms
    case parking
    case printers
    case microwaves
    case vendingMachines
    
    var id: Self { self }

    /// The map's top chip rail (Figma "Button Row"). Printers, microwaves
    /// and vending live in the sheet's Amenities tiles instead.
    static let railCategories: [SearchCategories] = [
        .dining, .academicBuildings, .athletics, .dorms, .parking
    ]

    /// The sheet's Amenities tiles (Figma "Map swipe up").
    static let amenityCategories: [SearchCategories] = [
        .printers, .microwaves, .vendingMachines
    ]
}

extension SearchCategories {
    var title: String {
        switch self {
        case .dining: "Dining"
        case .academicBuildings: "Academic Buildings"
        case .athletics: "Athletics"
        case .dorms: "Housing"
        case .parking: "Parking"
        case .printers: "Printers"
        case .microwaves: "Microwave"
        case .vendingMachines: "Vending"
        }
    }
    
    var systemImage: String {
        switch self {
        case .dining: "fork.knife"
        case .academicBuildings: "building.columns.fill"
        case .athletics: "figure.run"
        case .dorms: "house.fill"
        case .parking: "parkingsign.circle.fill"
        case .printers: "printer"
        case .microwaves: "microwave"
        case .vendingMachines: "waterbottle.fill"
        }
    }
}
