//
//  DiningCardView.swift
//  GeorgiaTechApp
//

import CoreLocation
import SwiftUI

/// The small dining card shown in the Restaurants category grid —
/// photo, name, type, live hours status, and distance.
struct DiningCardView: View {
    let model: SearchCardModel
    let hoursOpen: [[String]]?
    var restaurantType: String?
    var userLocation: CLLocationCoordinate2D?

    // Distance reads in the user's chosen travel mode (#22).
    @AppStorage("defaultTravelMode") private var defaultTravelModeRaw = ""

    private var defaultMode: RouteTransportMode {
        RouteTransportMode(rawValue: defaultTravelModeRaw) ?? .walking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardImage
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .clipped()

            // Reserved title space (#U3, reverses #22): mixed one- and
            // two-line names made neighboring grid cards jagged, which
            // reads worse than a short name's spare line.
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                    .lineLimit(1, reservesSpace: true)
                    .multilineTextAlignment(.leading)

                infoLine

                if hoursOpen != nil {
                    Text(DiningHours.statusText(for: hoursOpen))
                        .font(.gtHeading6)
                        .foregroundStyle(
                            DiningHours.isOpenNow(hoursOpen) ? Color.gtTechLawn : Color.gtAzalea
                        )
                        .lineLimit(1)
                }
            }
            .padding(10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // .clipped() is only visual — without this the overflowing photo
        // extends the tap target over neighboring grid cards.
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    /// One compact line (#22): default-mode icon + distance · campus area.
    @ViewBuilder
    private var infoLine: some View {
        let distanceText = DistanceFormat.text(from: userLocation, to: model.coordinate)
        let area = restaurantType?.isEmpty == false ? restaurantType?.humanized : nil

        if distanceText != nil || area != nil {
            HStack(spacing: 4) {
                if let distanceText {
                    Image(systemName: defaultMode.icon)
                        .font(.gtBody4)
                    Text(distanceText)
                        .font(.gtBody3)
                }
                if let area {
                    if distanceText != nil {
                        Text("·")
                            .font(.gtBody3)
                    }
                    Text(area)
                        .font(.gtBody3)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Color.gtSecondaryText)
        }
    }

    private var accessibilitySummary: String {
        var parts = [model.title]
        if let restaurantType, !restaurantType.isEmpty {
            parts.append(restaurantType.humanized)
        }
        if hoursOpen != nil {
            parts.append(DiningHours.isOpenNow(hoursOpen) ? "Open" : "Closed")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var cardImage: some View {
        let imageView = PlaceImageView(image: model.image)
        if imageView.hasImage {
            imageView
        } else {
            model.category.tint.opacity(0.25)
                .overlay {
                    Image(systemName: model.category.icon)
                        .font(.gtHeading2)
                        .foregroundStyle(model.category.tint)
                }
        }
    }
}
