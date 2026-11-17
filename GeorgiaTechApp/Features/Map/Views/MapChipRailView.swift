//
//  MapChipRailView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The map's top chip row (Figma "Button Row"): the Favorites heart,
/// then the campus categories. Pinned under the status bar.
/// Category chips are single-select searches run by the sheet. Amenities
/// (printers, microwaves, vending) are tiles in the sheet, and buses are
/// the floating bus button.
struct MapChipRailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let selection: MapSelection
    let isShowingFavorites: Bool
    let onToggleFavorites: () -> Void
    let onSelectCategory: (SearchCategories) -> Void

    var body: some View {
        GTCapsuleScroll {
            GTCapsuleButton(
                icon: "heart.fill", label: "Favorites",
                style: isShowingFavorites ? .selected : .standard,
                iconColor: colorScheme == .dark ? .gtGold : .gtDarkGold,
                action: onToggleFavorites
            )
            .accessibilityHint(isShowingFavorites ? "Closes your saved places" : "Shows your saved places")

            ForEach(SearchCategories.railCategories) { category in
                GTCategoryChip(
                    category.title, icon: category.systemImage,
                    isSelected: selection.activeCategory == category
                ) {
                    onSelectCategory(category)
                }
            }
        }
        .controlSize(.small)
    }
}
