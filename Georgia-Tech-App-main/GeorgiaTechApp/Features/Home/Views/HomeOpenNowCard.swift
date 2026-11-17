//
//  HomeOpenNowCard.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// Photo-forward dining rows for whatever is serving right now, headed
/// by the meal actually in progress ("Open for lunch" / "…for dinner").
/// Favorites float to the top. Hides entirely when nothing is open.
struct HomeOpenNowCard: View {
    @Query private var restaurants: [Restaurant]

    var onOpenPlace: (SearchCardModel) -> Void = { _ in }

    private var openRestaurants: [Restaurant] {
        restaurants
            .filter { DiningHours.isOpenNow($0.hoursOpen) }
            .sorted { first, second in
                let firstFav = FavoritesService.shared.isFavorite(first.toSearchCard().id)
                let secondFav = FavoritesService.shared.isFavorite(second.toSearchCard().id)
                if firstFav != secondFav { return firstFav }
                return first.name < second.name
            }
    }

    /// The meal the clock is actually in, so the header isn't lying at
    /// 9pm about lunch.
    private var mealTitle: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<11: return "Open for breakfast"
        case ..<16: return "Open for lunch"
        case ..<22: return "Open for dinner"
        default: return "Open late"
        }
    }

    var body: some View {
        if !openRestaurants.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GTSectionHeader(mealTitle)

                VStack(spacing: 0) {
                    ForEach(Array(openRestaurants.prefix(3).enumerated()),
                            id: \.element.restaurantID) { index, restaurant in
                        if index > 0 {
                            Divider()
                                .overlay(Color.gtNavy.opacity(0.08))
                                .padding(.leading, 68)
                        }
                        Button {
                            onOpenPlace(restaurant.toSearchCard())
                        } label: {
                            row(restaurant)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .gtCard(padding: 0)
            }
        }
    }

    private func row(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            PlaceImageView(image: restaurant.img)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(restaurant.name)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                Text(DiningHours.statusText(for: restaurant.hoursOpen))
                    .font(.gtHeading6)
                    .foregroundStyle(Color.gtTechLawn)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtSecondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(restaurant.name), \(DiningHours.statusText(for: restaurant.hoursOpen)), shows it on the map")
    }
}
