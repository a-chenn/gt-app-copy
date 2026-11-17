//
//  HomeFeaturedEventsBanner.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Swipeable featured-event cards. Sample content is intentional for this design ticket.
struct HomeFeaturedEventsBanner: View {
    @State private var selectedPage = 0
    @Environment(\.colorScheme) private var colorScheme

    private let events = FeaturedEvent.samples

    private var paginationColor: Color {
        colorScheme == .dark ? .gtGold : .gtMediumNavy
    }

    var body: some View {
        VStack(spacing: 8) {
            // Measure the tallest card so paging also accommodates wrapped text
            // and Dynamic Type, rather than clipping at a fixed carousel height.
            ZStack {
                ForEach(events) { event in
                    FeaturedEventCard(event: event)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                TabView(selection: $selectedPage) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        FeaturedEventCard(event: event)
                            .tag(index)
                            .accessibilityElement(children: .combine)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityLabel("Featured events")
            }

            HStack(spacing: 8) {
                ForEach(events.indices, id: \.self) { index in
                    Circle()
                        .fill(paginationColor.opacity(index == selectedPage ? 1 : 0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Featured event \(selectedPage + 1) of \(events.count)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selectedPage = min(selectedPage + 1, events.count - 1)
                case .decrement: selectedPage = max(selectedPage - 1, 0)
                @unknown default: break
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

/// Presentation-only dummy data; it does not enter the persisted event feed.
private struct FeaturedEvent: Identifiable {
    let id: Int
    let label: String
    let title: String
    let detail: String

    static let samples = [
        FeaturedEvent(id: 0, label: "Game Day Tomorrow", title: "Georgia Tech vs. UGA",
                      detail: "8:00 PM Bobby Dodd at Hyundai Field"),
        FeaturedEvent(id: 1, label: "This Week on Campus", title: "Fall on Tech Green",
                      detail: "5:00 PM Tech Green"),
        FeaturedEvent(id: 2, label: "Featured Event", title: "Meet the Jackets",
                      detail: "6:00 PM McCamish Pavilion"),
        FeaturedEvent(id: 3, label: "Around Campus", title: "Music at the Ferst",
                      detail: "7:00 PM Ferst Center for the Arts")
    ]
}

private struct FeaturedEventCard: View {
    let event: FeaturedEvent

    @ScaledMetric(relativeTo: .caption) private var labelHeight = 15.6
    @ScaledMetric(relativeTo: .title) private var titleHeight = 31.2
    // Match the handoff's 130% line height rather than the font's intrinsic leading.
    @ScaledMetric(relativeTo: .title) private var titleLineAdjustment = 31.2 - 24 * 1.31884765625
    @ScaledMetric(relativeTo: .subheadline) private var detailHeight = 18.2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(event.label.uppercased())
                    .font(.gtHeading6)
                    .frame(minHeight: labelHeight, alignment: .leading)
                Text(event.title)
                    .font(.gtHeading2)
                    .lineSpacing(titleLineAdjustment)
                    .padding(.vertical, titleLineAdjustment / 2)
                    .frame(minHeight: titleHeight, alignment: .leading)
            }
            Text(event.detail)
                .font(.gtBody2)
                .frame(minHeight: detailHeight, alignment: .leading)
        }
        .foregroundStyle(Color.gtFeaturedEventText)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(Color.gtMediumNavy, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeFeaturedEventsBanner()
        .background(Color.gtBackground)
}
