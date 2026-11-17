//
//  PlaceMenuSection.swift
//  GeorgiaTechApp
//

import SwiftData
import SwiftUI

/// The dining branch of the unified detail card: today's menu with a meal
/// picker, dietary filter chips, and station sections. A subcomponent of
/// `PlaceDetailView`, not a separate per-type card.
struct PlaceMenuSection: View {
    @Query private var restaurants: [Restaurant]
    @Environment(\.colorScheme) private var colorScheme
    let restaurant: Restaurant
    let dietaryFilters: [DietaryFilter]
    @Binding var selectedMenuIndex: Int
    @Binding var selectedFilterIDs: Set<String>
    /// nil = today. Stepped by the day arrows through every date the
    /// API's menu payload covers (#S-1).
    @Binding var selectedMenuDate: Date?

    private var displayedDate: Date {
        selectedMenuDate ?? Date()
    }

    var body: some View {
        let menus = DiningMenu.orderedMenus(restaurant.menus)
        let menuIndex = min(selectedMenuIndex, menus.count - 1)
        let dates = DiningMenu.availableDates(in: restaurant.menus)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GTSectionHeader("Today's Menu")

                dayNavigator(dates: dates)
            }

            if menus.count > 1 {
                Picker("Meal", selection: $selectedMenuIndex) {
                    ForEach(0..<menus.count, id: \.self) { index in
                        Text(DiningMenu.mealTitle(at: index, of: menus.count)).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Only offer dietary filters when this restaurant has tagged foods.
            if hasDietaryTagData {
                dietaryFilterChips
            }
            
            if NotificationService.shared.isEnabled(.diningUpdates) {
                Text("Heart a dish to pin it here and get a daily alert when it's on a menu.")
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            }

            if let day = DiningMenu.day(in: menus[menuIndex], for: displayedDate) {
                stationList(for: day)
            } else {
                Text("No menu posted for this day.")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)
            }
        }
    }

    // MARK: - Day rotation (#S-1)

    private func dayNavigator(dates: [Date]) -> some View {
        let calendar = Calendar.current
        let previous = dates.last { $0 < calendar.startOfDay(for: displayedDate) }
        let next = dates.first {
            $0 > displayedDate && !calendar.isDate($0, inSameDayAs: displayedDate)
        }

        return HStack(spacing: 2) {
            Button {
                selectedMenuDate = previous
            } label: {
                Image(systemName: "chevron.left")
                    .font(.gtHeading5)
                    .foregroundStyle(previous == nil ? Color.gtSecondaryText.opacity(0.35) : Color.gtPrimaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(previous == nil)
            .accessibilityLabel("Previous day's menu")

            Text(DiningMenu.dayTitle(for: displayedDate))
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .frame(minWidth: 92)
                .accessibilityLabel("Showing menu for \(DiningMenu.dayTitle(for: displayedDate))")

            Button {
                selectedMenuDate = next
            } label: {
                Image(systemName: "chevron.right")
                    .font(.gtHeading5)
                    .foregroundStyle(next == nil ? Color.gtSecondaryText.opacity(0.35) : Color.gtPrimaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(next == nil)
            .accessibilityLabel("Next day's menu")
        }
    }

    private var hasDietaryTagData: Bool {
        restaurant.menus.contains { menu in
            menu.days.contains { day in
                day.menuItems.contains { !($0.food?.tags.isEmpty ?? true) }
            }
        }
    }

    private var dietaryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedDietaryFilters) { filter in
                    let isSelected = selectedFilterIDs.contains(filter.id)
                    GTFilterChip(
                        title: filter.name, isSelected: isSelected,
                        accessibilityText: accessibilityText(for: filter, isSelected: isSelected)
                    ) {
                        if isSelected {
                            selectedFilterIDs.remove(filter.id)
                        } else {
                            selectedFilterIDs.insert(filter.id)
                        }
                    }
                }
            }
        }
        .mapSheetHorizontalScroll()
    }

    // Preferences (filter in) come before allergens (filter out).
    private var sortedDietaryFilters: [DietaryFilter] {
        dietaryFilters.sorted {
            if $0.category != $1.category { return $0.category == .preference }
            return $0.name < $1.name
        }
    }

    private func accessibilityText(for filter: DietaryFilter, isSelected: Bool) -> String {
        switch filter.category {
        case .preference: return "Show only \(filter.name) items"
        case .allergen: return "Hide items containing \(filter.name)"
        }
    }

    @ViewBuilder
    private func stationList(for day: MenuDay) -> some View {
        let selectedFilters = dietaryFilters.filter { selectedFilterIDs.contains($0.id) }
        let sections = DiningMenu.stationSections(from: day.menuItems)
            .map { section in
                var filtered = section
                filtered.items = DiningMenu.filteredItems(section.items, selectedFilters: selectedFilters)
                return filtered
            }
            .filter { !$0.items.isEmpty }

        if sections.isEmpty {
            // Blaming the filters when none are set sent people hunting
            // for a filter to clear that was never there.
            Text(selectedFilters.isEmpty
                 ? "No menu items posted for this day."
                 : "No menu items match the selected filters.")
                .font(.gtBody2)
                .foregroundStyle(Color.gtSecondaryText)
        } else {
            // Stations as separated cards (#23) — the flat list read as
            // one undifferentiated wall of text.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sections) { section in
                    stationCard(section)
                }
            }
        }
    }

    private func stationCard(_ section: DiningMenu.StationSection) -> some View {
        let items = itemsWithFavoritesFirst(section.items)

        return VStack(alignment: .leading, spacing: 0) {
            GTMicroLabel(text: section.name, color: .gtDarkGold)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(Array(items.enumerated()), id: \.element.itemID) { index, item in
                if index > 0 {
                    Divider()
                        .padding(.leading, 12)
                }
                menuItemRow(item)
            }
        }
        .padding(.bottom, 6)
        .gtCard(radius: 16, padding: 0)
    }

    /// Hearted dishes float to the top of their station (#23).
    private func itemsWithFavoritesFirst(_ items: [MenuItem]) -> [MenuItem] {
        let favorites = items.filter { isDishFavorited(foodName($0)) }
        let rest = items.filter { !isDishFavorited(foodName($0)) }
        return favorites + rest
    }

    private func isDishFavorited(_ name: String) -> Bool {
        if FavoritesService.shared.isFoodFavorited(name) { return true }
        let target = FavoriteMenuMatches.normalizedName(name)
        return FavoritesService.shared.favoriteFoodNames.contains {
            FavoriteMenuMatches.normalizedName($0) == target
        }
    }

    private func foodName(_ item: MenuItem) -> String {
        item.food?.name ?? item.text
    }

    private func menuItemRow(_ item: MenuItem) -> some View {
        let name = foodName(item)
        let isFavorite = isDishFavorited(name)
        return HStack(spacing: 8) {
            Text(name)
                .font(.gtBody2)
                .foregroundStyle(Color.gtPrimaryText)
            dietaryIcons(for: item)
            Spacer()
            Button {
                let target = FavoriteMenuMatches.normalizedName(name)
                let storedName = FavoritesService.shared.favoriteFoodNames.first {
                    FavoriteMenuMatches.normalizedName($0) == target
                } ?? name
                FavoritesService.shared.toggleFood(storedName)
                Task {
                    await AlertWatchService.shared.handleFavoriteFoodToggled(restaurants: restaurants)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.gtBody2)
                    .foregroundStyle(isFavorite
                        ? (colorScheme == .dark ? Color.gtGold : Color.gtDarkGold)
                        : Color.gtSecondaryText.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove \(name) from favorites" : "Favorite \(name)")
            .accessibilityHint(
                isFavorite
                    ? "Removes this dish from the top of the station and stops daily menu alerts for it"
                    : "Pins this dish to the top of the station and alerts you on days it's served"
            )
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
    }

    /// Per-item allergens use the bundled DietaryFilters artwork.
    /// Preferences remain available through the dietary filter chips.
    @ViewBuilder
    private func dietaryIcons(for item: MenuItem) -> some View {
        // PlaceImageView normalizes the API's `img` value to an asset name
        // and renders nothing when the art isn't bundled.
        let matches = allergenFilters(for: item)
            .filter { PlaceImageView(image: $0.img).hasImage }
        if !matches.isEmpty {
            WrappingHStack(spacing: 3, maxWidth: 159) {
                ForEach(matches) { filter in
                    PlaceImageView(image: filter.img, contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel(filter.name)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// Returns the allergens identified by the menu item's dietary tags.
    private func allergenFilters(for item: MenuItem) -> [DietaryFilter] {
        guard let tags = item.food?.tags, !tags.isEmpty else { return [] }
        let normalized = Set(tags.map { $0.lowercased() })
        return sortedDietaryFilters.filter { filter in
            filter.category == .allergen && filter.matches(normalizedTags: normalized)
        }
    }
}
