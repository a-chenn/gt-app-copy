//
//  FavoritesListView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Saved places as main-sheet content, opened from the rail's heart.
/// Same "‹ Title" header and list card as Recents. Un-hearting a row
/// keeps it visible until the list reopens, so a mis-tap can be undone.
struct FavoritesListView: View {
    let onBack: () -> Void
    let onSelect: (SearchCardModel) -> Void

    @State private var items: [SearchCardModel] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SheetBackHeader(title: "Favorites", onBack: onBack)

                if items.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "heart",
                        description: Text("Tap the heart on a place to save it here.")
                    )
                    .padding(.top, 24)
                } else {
                    PlaceHeartCard(items: items) { item in
                        PlaceHeartRow(item: item, onTap: { onSelect(item) })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .onAppear {
            items = FavoritesService.shared.fetchAllAsCards()
        }
    }
}
