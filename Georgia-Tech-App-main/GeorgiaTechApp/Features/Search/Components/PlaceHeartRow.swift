//
//  PlaceHeartRow.swift
//  GeorgiaTechApp
//

import SwiftUI

/// One place in a sheet list card (Figma "Recents" / "Suggested" /
/// Favorites): title, address line, and a heart that saves the place.
/// Shared by every place list in the map sheet so they read as one
/// system. `isExpanded` reveals the Figma card's navy Directions button.
struct PlaceHeartRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: SearchCardModel
    let onTap: () -> Void
    var isExpanded = false
    var onDirections: (() -> Void)?

    private var isFavorite: Bool {
        FavoritesService.shared.favoriteIDs.contains(item.id)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.gtHeading5)
                            .foregroundStyle(Color.gtPrimaryText)
                            .lineLimit(1)

                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.gtBody3)
                                .foregroundStyle(Color.gtSecondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(onDirections == nil || isExpanded
                    ? "Opens the place card" : "Shows directions")

                Button {
                    FavoritesService.shared.toggle(item)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.gtBody2)
                        .foregroundStyle(isFavorite
                            ? (colorScheme == .dark ? Color.gtGold : Color.gtDarkGold)
                            : Color.gtSecondaryText)
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite
                    ? "Remove \(item.title) from favorites"
                    : "Save \(item.title) to favorites")
                .accessibilityAddTraits(isFavorite ? .isSelected : [])
            }

            if isExpanded, let onDirections {
                GTCapsuleButton(
                    "Directions", icon: "arrow.triangle.turn.up.right.diamond.fill",
                    style: .selected, isFullWidth: true, action: onDirections
                )
                .controlSize(.small)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .disabled(item.destination == nil)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
    }
}

/// A white list card of `PlaceHeartRow`s with hairline dividers.
struct PlaceHeartCard<Row: View>: View {
    let items: [SearchCardModel]
    @ViewBuilder let row: (SearchCardModel) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                row(item)
                if item.id != items.last?.id {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .gtCard(radius: 14, padding: 0)
    }
}
