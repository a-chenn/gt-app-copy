//
//  RecentsViews.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Every recent place, as main-sheet content (Figma "View all recents"):
/// "< Recents" header over one list card. Never a second sheet.
struct RecentsListView: View {
    let searchVM: SearchVM
    let onBack: () -> Void
    let onSelect: (SearchCardModel) -> Void

    private var items: [SearchCardModel] {
        searchVM.recents.flatMap(\.items)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SheetBackHeader(title: "Recents", onBack: onBack)

                if items.isEmpty {
                    ContentUnavailableView(
                        "No Recents",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Places you view will show up here.")
                    )
                    .padding(.top, 24)
                } else {
                    PlaceHeartCard(items: items) { item in
                        PlaceHeartRow(item: item, onTap: { onSelect(item) })
                            .contextMenu {
                                Button("Remove from Recents", systemImage: "trash", role: .destructive) {
                                    searchVM.removeRecent(item)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}

/// "‹ Title" — the back header every in-sheet sub-page uses (Recents,
/// Favorites, a bus stop, a bus), with an optional trailing control.
struct SheetBackHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.gtPrimaryText)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.gtHeading3)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.gtBody3)
                        .foregroundStyle(Color.gtSecondaryText)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
    }
}

extension SheetBackHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}
