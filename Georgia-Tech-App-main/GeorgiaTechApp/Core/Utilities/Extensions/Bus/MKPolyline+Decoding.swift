//
//  MKPolyline+Decoding.swift
//  GeorgiaTechApp
//
//  Created by Eesh Majithia on 3/15/26.
//

import MapKit

extension MKPolyline {
    convenience init?(encodedString: String) {
        let bytes = Array(encodedString.utf8)
        var coordinates: [CLLocationCoordinate2D] = []
        
        var index = 0
        var lat: Int = 0
        var lng: Int = 0
        
        while index < bytes.count {
            var shift = 0
            var result: Int = 0
            var byte: Int
            
            repeat {
                if index >= bytes.count { return nil }
                byte = Int(bytes[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            
            let dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dlat
            
            shift = 0
            result = 0
            
            if index >= bytes.count { break }
            
            repeat {
                if index >= bytes.count { return nil }
                byte = Int(bytes[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            
            let dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dlng
            
            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 100_000.0,
                longitude: Double(lng) / 100_000.0)
            coordinates.append(coordinate)
        }
        
        self.init(coordinates: coordinates, count: coordinates.count)
    }
    static var empty: MKPolyline {
        let coords: [CLLocationCoordinate2D] = []
        return MKPolyline(coordinates: coords, count: 0)
    }
}
