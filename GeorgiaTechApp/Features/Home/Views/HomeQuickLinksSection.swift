//
//  HomeQuickLinksSection.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The user's pinned campus links (cap 6) as a two-column grid, with an
/// edit affordance. Selection + order persist as comma-joined IDs.
struct HomeQuickLinksSection: View {
    @AppStorage("homeQuickLinksV2") private var pinnedRaw = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false

    private var pinned: [CampusQuickLink] {
        QuickLinkStore.decode(pinnedRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GTSectionHeader("Campus Links")
                Spacer()
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtPrimaryText)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle().strokeBorder(Color.gtSecondaryText.opacity(0.35), lineWidth: 1)
                        }
                }
                .accessibilityLabel("Edit campus links")
            }

            if pinned.isEmpty {
                // The one allowed empty state: the user removed them all.
                Button("Add campus links") { isEditing = true }
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(pinned) { link in
                        ExternalLinkButton(url: URL(string: link.urlString)) {
                            HStack(spacing: 6) {
                                Image(systemName: link.icon)
                                    .font(.gtBody3)
                                    .foregroundStyle((colorScheme == .dark ? Color.gtGold : Color.gtDarkGold))
                                Text(link.title)
                                    .font(.gtHeading6)
                                    .foregroundStyle(Color.gtPrimaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill((colorScheme == .dark ? Color.gtNavy : Color.gtWhite))
                                    .shadow(color: Color.gtNavy.opacity(0.06), radius: 6, y: 2)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.gtSecondaryText.opacity(0.25), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(link.title) website")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            QuickLinksEditSheet(pinnedRaw: $pinnedRaw)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
