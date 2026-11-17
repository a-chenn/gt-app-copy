//
//  String+Display.swift
//  GeorgiaTechApp
//

import Foundation

extension String {
    /// Turns backend identifiers into display text:
    /// "dining_dollars" → "Dining Dollars", "parkingDecks" → "Parking Decks",
    /// "academic" → "Academic".
    var humanized: String {
        // Split snake_case, then split camelCase humps within each part.
        let words = split(separator: "_").flatMap { part -> [String] in
            var result: [String] = []
            var current = ""
            for character in part {
                if character.isUppercase && !current.isEmpty {
                    result.append(current)
                    current = String(character)
                } else {
                    current.append(character)
                }
            }
            if !current.isEmpty { result.append(current) }
            return result
        }
        return words
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
