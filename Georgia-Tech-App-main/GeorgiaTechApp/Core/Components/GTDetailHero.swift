//
//  GTDetailHero.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The Gold Hive detail header, shared by every "opened thing" in the app
/// — a place on the map, an event, a news article.
///
/// The photo carries ONE thing (the date, or whatever short caption the
/// caller passes); the title and its eyebrow sit BELOW it on the page.
/// Type over a photograph is only as legible as that photograph allows,
/// and a long title over a busy image was the worst case.
///
/// Without artwork there is no decorative block at all — just the
/// heading. A subject with no photo (an event, a bus stop) gets a clean
/// title rather than a gradient standing in for one.
struct GTDetailHero<Meta: View>: View {
    /// Category or kicker line above the title.
    var eyebrow: String?
    let title: String
    /// Asset name or remote URL string — `PlaceImageView` resolves both.
    var image: String?
    /// The one line that sits ON the photo, typically a date.
    var imageCaption: String?
    var accessibilityText: String?
    @ViewBuilder var meta: () -> Meta

    /// Roughly the 1.85:1 the feed's 740px art is cut to, so the common
    /// case is barely cropped at all.
    private static var aspectRatio: CGFloat { 1.85 }

    private var photo: PlaceImageView? {
        let view = PlaceImageView(image: image)
        return view.hasImage ? view : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let photo {
                photo
                    // An aspect ratio rather than a fixed height: the
                    // frame then matches the shape of the art instead of
                    // forcing every photo through one rectangle, which
                    // is what made some of them crop oddly.
                    .aspectRatio(Self.aspectRatio, contentMode: .fit)
                    .overlay(alignment: .bottomLeading) { imageCaptionLabel }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)
            }

            heading
        }
    }

    @ViewBuilder
    private var imageCaptionLabel: some View {
        if let imageCaption, !imageCaption.isEmpty {
            Text(imageCaption)
                .font(.gtHeading6)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.gtWhite)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gtNavy.opacity(0.55), in: .capsule)
                .padding(12)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(.gtHeading6)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.gtDarkGold)
                    .lineLimit(1)
            }

            Text(title)
                .font(.gtHeading2)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Color.gtPrimaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            meta()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText ?? title)
    }
}

extension GTDetailHero where Meta == EmptyView {
    init(
        eyebrow: String? = nil, title: String, image: String? = nil,
        imageCaption: String? = nil, accessibilityText: String? = nil
    ) {
        self.init(
            eyebrow: eyebrow, title: title, image: image,
            imageCaption: imageCaption, accessibilityText: accessibilityText,
            meta: { EmptyView() })
    }
}
