//
//  MKPolyline+Slicing.swift
//  GeorgiaTechApp
//
//  Created by Eesh Majithia on 4/20/26.
//

import CoreLocation
import MapKit

struct SlicedPolyline {
    let used: MKPolyline
    let unused: MKPolyline?
    let distance: Double
}

extension MKPolyline {
    var allCoordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
    
    func nearestVertexIndex(to coordinate: CLLocationCoordinate2D) -> Int? {
        let coords = allCoordinates
        guard !coords.isEmpty else { return nil }
        let targetPoint = MKMapPoint(coordinate)
        var bestIndex = 0
        var bestDist = Double.infinity
        for (i, c) in coords.enumerated() {
            let point = MKMapPoint(c)
            let d = point.distance(to: targetPoint)
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }
        return bestIndex
    }
    
    // Slice between two coords on a route polyline. For a closed-loop
    // route there are always two possible arcs between any two vertices
    // (forward and wrap-around). Which arc the bus actually drives depends
    // on stop order, not geometry — a ride spanning more than half the
    // loop legitimately takes the LONGER arc. When the caller knows a
    // point the ride passes through (an intermediate stop), pass it as
    // `via` and the arc containing it wins; with no `via`, the shorter
    // arc is the best available guess.
    func slice(
        from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
        via: CLLocationCoordinate2D? = nil
    ) -> SlicedPolyline? {
        guard let startIdx = nearestVertexIndex(to: from),
              let endIdx = nearestVertexIndex(to: to)
        else { return nil }
        let coords = allCoordinates
        guard !coords.isEmpty, startIdx != endIdx else { return nil }

        let lo = min(startIdx, endIdx)
        let hi = max(startIdx, endIdx)
        let directArc = Array(coords[lo...hi])
        let wrapArc = Array(coords[hi..<coords.count]) + Array(coords[0...lo])

        let directLen = pathLength(directArc)
        let wrapLen = pathLength(wrapArc)

        let useDirect: Bool
        if let via {
            useDirect = distance(from: via, toPath: directArc) <= distance(from: via, toPath: wrapArc)
        } else {
            useDirect = directLen <= wrapLen
        }

        let usedCoords = useDirect ? directArc : wrapArc
        let unusedCoords = useDirect ? wrapArc : directArc

        guard usedCoords.count >= 2 else { return nil }

        let used = MKPolyline(coordinates: usedCoords, count: usedCoords.count)
        let unused =
        unusedCoords.count >= 2
        ? MKPolyline(coordinates: unusedCoords, count: unusedCoords.count) : nil

        return SlicedPolyline(used: used, unused: unused, distance: useDirect ? directLen : wrapLen)
    }

    /// First vertex at least `minimumDistance` meters ahead of `coordinate` in the
    /// polyline's drawn direction, wrapping on closed loops.
    func nextCoordinate(
        after coordinate: CLLocationCoordinate2D, minimumDistance: Double = 3
    ) -> CLLocationCoordinate2D? {
        let coords = allCoordinates
        guard coords.count >= 2 else { return nil }
        let point = MKMapPoint(coordinate)

        var bestSegment = 0
        var bestDist = Double.infinity
        for i in 0..<(coords.count - 1) {
            let d = Self.distance(from: point, toSegment: MKMapPoint(coords[i]), MKMapPoint(coords[i + 1]))
            if d < bestDist {
                bestDist = d
                bestSegment = i
            }
        }

        let isClosed = MKMapPoint(coords[0]).distance(to: MKMapPoint(coords[coords.count - 1])) < 1
        let count = isClosed ? coords.count - 1 : coords.count
        var index = bestSegment + 1
        for _ in 0..<count {
            let candidate = coords[index % count]
            if MKMapPoint(candidate).distance(to: point) >= minimumDistance { return candidate }
            if !isClosed && index >= count - 1 { return candidate }
            index += 1
        }
        return nil
    }

    private static func distance(from p: MKMapPoint, toSegment a: MKMapPoint, _ b: MKMapPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return p.distance(to: MKMapPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    private func distance(from coordinate: CLLocationCoordinate2D, toPath path: [CLLocationCoordinate2D]) -> Double {
        let point = MKMapPoint(coordinate)
        return path.map { MKMapPoint($0).distance(to: point) }.min() ?? .infinity
    }
    
    private func pathLength(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<coords.count {
            let a = MKMapPoint(coords[i - 1])
            let b = MKMapPoint(coords[i])
            total += a.distance(to: b)
        }
        return total
    }
}
