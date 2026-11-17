//
//  MapPlacesLayer.swift
//  GeorgiaTechApp
//

import CoreLocation
import MapKit
import SwiftUI

/// Renders the unified pins for whatever places are currently active
/// (category search results plus the selected place). One layer for
/// all categories — branching happens inside `PlacePin`, not here.
///
/// Nearby pins collapse into count clusters based on the camera span
/// (appliances especially sit close together); tapping a cluster zooms in.
struct MapPlacesLayer: MapContent {
    let places: [SearchCardModel]
    let selectedID: String?
    var spanLatitude: Double?
    let onSelect: (SearchCardModel) -> Void
    var onClusterTap: ([SearchCardModel]) -> Void = { _ in }

    var body: some MapContent {
        ForEach(clusters) { cluster in
            if cluster.members.count == 1, let place = cluster.members.first {
                if place.category == .busStop && place.id == selectedID {
                    // Figma "specific stop": the open stop is a black pin
                    // standing on its coordinate.
                    Annotation(place.title, coordinate: cluster.coordinate, anchor: .bottom) {
                        BusStopSelectedPin()
                            .accessibilityLabel("\(place.title), bus stop, selected")
                    }
                    .annotationTitles(.hidden)
                } else {
                    Annotation(place.title, coordinate: cluster.coordinate) {
                        Button {
                            onSelect(place)
                        } label: {
                            PlacePin(
                                category: place.category,
                                isSelected: place.id == selectedID
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(place.title), \(place.category.label)")
                        .accessibilityHint("Shows details for this place")
                    }
                }
            } else {
                Annotation("", coordinate: cluster.coordinate) {
                    Button {
                        onClusterTap(cluster.members)
                    } label: {
                        clusterPin(count: cluster.members.count)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(cluster.members.count) places")
                    .accessibilityHint("Zooms in to show them individually")
                }
            }
        }
    }

    private func clusterPin(count: Int) -> some View {
        ZStack {
            Circle().fill(Color.gtNavy)
            Text("\(count)")
                .font(.gtHeading6)
                .foregroundStyle(Color.gtWhite)
        }
        .frame(width: 32, height: 32)
        .overlay {
            Circle().strokeBorder(Color.gtWhite, lineWidth: 2)
        }
        .shadow(color: Color.gtNavy.opacity(0.25), radius: 3, y: 1)
    }

    // MARK: - Clustering

    private struct PlaceCluster: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let members: [SearchCardModel]
    }

    private var clusters: [PlaceCluster] {
        let positioned = places.filter { $0.coordinate != nil }

        // The selected place always renders as its own pin.
        let selected = positioned.filter { $0.id == selectedID }
        let clusterable = positioned.filter { $0.id != selectedID }

        var result: [PlaceCluster] = selected.compactMap { place in
            place.coordinate.map { PlaceCluster(id: place.id, coordinate: $0, members: [place]) }
        }

        guard let spanLatitude, spanLatitude > 0, clusterable.count > 1 else {
            result += clusterable.compactMap { place in
                place.coordinate.map { PlaceCluster(id: place.id, coordinate: $0, members: [place]) }
            }
            return result
        }

        // Quantize the span to power-of-two zoom buckets so panning (and
        // camera jitter) never regroups pins — only real zoom changes do (#23).
        let bucketedSpan = pow(2, log2(spanLatitude).rounded())
        let cellSize = bucketedSpan / 20
        var buckets: [String: [SearchCardModel]] = [:]
        for place in clusterable {
            guard let coordinate = place.coordinate else { continue }
            let row = Int((coordinate.latitude / cellSize).rounded(.down))
            let column = Int((coordinate.longitude / cellSize).rounded(.down))
            buckets["\(row):\(column)", default: []].append(place)
        }

        for (key, members) in buckets {
            if members.count == 1, let place = members.first, let coordinate = place.coordinate {
                result.append(PlaceCluster(id: place.id, coordinate: coordinate, members: members))
            } else {
                let coordinates = members.compactMap(\.coordinate)
                let centroid = CLLocationCoordinate2D(
                    latitude: coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count),
                    longitude: coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
                )
                result.append(PlaceCluster(id: "cluster-\(key)", coordinate: centroid, members: members))
            }
        }

        return result
    }
}
