//
//  ExternalSearchService.swift
//  GeorgiaTechApp
//

import MapKit

final class ExternalSearchService {
    /// Campus center fallback used when the user's location is unavailable.
    private static let campusCenter = CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)

    func search(_ text: String, near center: CLLocationCoordinate2D? = nil) async -> [MKMapItem] {
        guard !text.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: center ?? Self.campusCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }
}
