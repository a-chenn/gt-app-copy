//
//  PlaceDetailHero.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The place-detail flavor of `GTDetailHero`: same photo-then-heading
/// shape as events and news, plus the open/closed badge and the close
/// control the map sheet needs.
struct PlaceDetailHero: View {
    let place: SearchCardModel
    /// "Open until 9:00PM" — nil for places that have no hours (a bus
    /// stop, a printer), which drop the badge entirely.
    let statusText: String?
    let isOpen: Bool
    let onClose: () -> Void

    /// Only the place's OWN photo. A bus stop or a printer has none, and
    /// a stand-in — the shared building image, or a gradient block — said
    /// nothing except "there should be a picture here". Those places get
    /// their name, plainly.
    private var image: String? {
        PlaceImageView(image: place.image).hasImage ? place.image : nil
    }

    var body: some View {
        GTDetailHero(
            eyebrow: place.category.label,
            title: place.title,
            image: image,
            accessibilityText: accessibilityText
        ) {
            if let statusText {
                HStack(spacing: 8) {
                    Text(isOpen ? "Open" : "Closed")
                        .font(.gtHeading6)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.gtWhite)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(isOpen ? Color.gtTechLawn : Color.gtAzalea, in: .capsule)

                    Text(statusText)
                        .font(.gtHeading6)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    private var accessibilityText: String {
        var parts = [place.title, place.category.label]
        if let statusText { parts.append(statusText) }
        return parts.joined(separator: ", ")
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.gtHeading5)
                .foregroundStyle(Color.gtSecondaryText)
                // 44pt is the HIG minimum; the visible disc is smaller
                // than the tappable frame on purpose.
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.regularMaterial)
                        .padding(5)
                }
                .contentShape(Circle())
        }
        .accessibilityLabel("Close place details")
    }
}
