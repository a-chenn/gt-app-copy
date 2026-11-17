//
//  SearchResultRow.swift
//  GeorgiaTechApp
//

import CoreLocation
import SwiftUI

/// The standard search-result row (Apple Maps style): leading tinted
/// category circle, title, up to two muted subtitle lines, and a trailing
/// directions chip that starts routing without opening the row.
struct SearchResultRow: View {
    let model: SearchCardModel
    let userLocation: CLLocationCoordinate2D?
    let onDirections: () -> Void

    private var distanceText: String? {
        DistanceFormat.text(from: userLocation, to: model.coordinate)
    }

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.gtHeading4)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1)

                if let subtitle = model.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.gtBody2)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(1)
                }

                Text(secondSubtitle)
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if model.destination != nil {
                Button(action: onDirections) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.gtBody2)
                        if let distanceText {
                            Text(distanceText)
                                .font(.gtHeading6)
                        }
                    }
                    .foregroundStyle(Color.gtNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gtGold, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Get directions to \(model.title)")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    private var secondSubtitle: String {
        // Appliance rows carry floor/room in the subtitle; repeating the
        // category label here just crowds out the distance (#22).
        if model.category.isAppliance {
            return distanceText ?? model.category.label
        }
        if let distanceText {
            return "\(model.category.label) · \(distanceText)"
        }
        return model.category.label
    }

    // Real photo when the place has one; category-tinted icon otherwise.
    @ViewBuilder
    private var leadingIcon: some View {
        let imageView = PlaceImageView(image: model.image)
        if imageView.hasImage {
            imageView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Circle()
                .fill(model.category.tint)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: model.category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        // Same contract as the map pin: light gold tints
                        // carry a navy glyph, everything else white.
                        .foregroundStyle(model.category.glyphColor)
                }
        }
    }
}
