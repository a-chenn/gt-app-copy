//
//  RouteEndpointSearchView.swift
//  GeorgiaTechApp
//

import MapKit
import SwiftUI

/// Inline endpoint picker for the From/To card (#10): campus matches
/// above debounced `MKLocalSearch` results, plus "My Location" to restore
/// the default origin. Content of `RouteOptionsView`, never its own sheet.
struct RouteEndpointSearchView: View {
    let isEditingOrigin: Bool
    /// Offered only when the origin was changed away from the default.
    let showsMyLocation: Bool
    let searchableData: SearchableData
    /// nil means "My Location".
    let onChoose: (SearchCardModel?) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var externalResults: [MKMapItem] = []
    @FocusState private var isFieldFocused: Bool
    private let searchService = ExternalSearchService()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)

                TextField(
                    isEditingOrigin
                        ? "Search for a starting point" : "Search for a destination",
                    text: $query)
                .focused($isFieldFocused)

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gtSecondaryText)
                }
                .accessibilityLabel("Cancel endpoint search")
            }
            .padding(12)

            if showsMyLocation {
                Divider()
                resultRow(icon: "location.fill", tint: Color.gtCampanile, title: "My Location") {
                    onChoose(nil)
                }
            }

            ForEach(campusMatches) { card in
                Divider()
                resultRow(icon: card.category.icon, tint: card.category.tint, title: card.title) {
                    onChoose(card)
                }
            }

            ForEach(externalResults, id: \.self) { item in
                Divider()
                resultRow(icon: "mappin", tint: Color.gtSecondaryText, title: item.name ?? "Unknown Place") {
                    onChoose(item.toSearchCard())
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .task {
            isFieldFocused = true
        }
        .task(id: query) {
            await runExternalSearch()
        }
    }

    private func resultRow(
        icon: String, tint: Color, title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.gtHeading6)
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(title)
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(title)")
    }

    /// Campus places matching the query — checked before spending an
    /// MKLocalSearch, and always listed above external results.
    private var campusMatches: [SearchCardModel] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        let locations = searchableData.locations
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .map { $0.toSearchCard() }
        let dining = searchableData.restaurants
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .map { $0.toSearchCard() }
        return Array((locations + dining).prefix(5))
    }

    private func runExternalSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            externalResults = []
            return
        }
        // Debounce — .task(id:) cancels this sleep on every keystroke.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let results = await searchService.search(trimmed, near: searchableData.userLocation)
        guard !Task.isCancelled else { return }
        externalResults = Array(results.prefix(4))
    }
}
