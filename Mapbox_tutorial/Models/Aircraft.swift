//
//  Aircraft.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import Foundation
import CoreLocation
import MapboxMaps
import SwiftUI

// MARK: - Flight Status

enum FlightStatus: String, Codable, CaseIterable {
    case approaching    // Blue - incoming
    case taxiingIn      // Green with trail
    case parked         // Gray static
    case boarding       // Green pulsing
    case taxiingOut     // Orange
    case departed       // Hidden or faded
    case delayed        // Red with warning
    case cancelled      // Gray with X

    var iconName: String {
        switch self {
        case .approaching: return "aircraft-approaching"
        case .taxiingIn: return "aircraft-taxiing"
        case .parked: return "aircraft-parked"
        case .boarding: return "aircraft-boarding"
        case .taxiingOut: return "aircraft-taxiing"
        case .departed: return "aircraft-departed"
        case .delayed: return "aircraft-delayed"
        case .cancelled: return "aircraft-cancelled"
        }
    }

    var color: String {
        switch self {
        case .approaching: return "#007AFF"   // Blue
        case .taxiingIn: return "#34C759"     // Green
        case .parked: return "#8E8E93"        // Gray
        case .boarding: return "#34C759"      // Green
        case .taxiingOut: return "#FF9500"    // Orange
        case .departed: return "#8E8E93"      // Gray
        case .delayed: return "#FF3B30"       // Red
        case .cancelled: return "#8E8E93"     // Gray
        }
    }

    var priority: Int {
        switch self {
        case .delayed: return 100
        case .boarding, .taxiingIn, .taxiingOut: return 80
        case .approaching: return 60
        case .parked: return 40
        case .departed, .cancelled: return 20
        }
    }

    var displayName: String {
        switch self {
        case .approaching: return "Approaching"
        case .taxiingIn: return "Taxiing In"
        case .parked: return "Parked"
        case .boarding: return "Boarding"
        case .taxiingOut: return "Taxiing Out"
        case .departed: return "Departed"
        case .delayed: return "Delayed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Flight Route

struct FlightRoute {
    let originCode: String
    let originCoordinate: CLLocationCoordinate2D
    let destinationCode: String
    let destinationCoordinate: CLLocationCoordinate2D
    let waypoints: [CLLocationCoordinate2D]  // Full route path including origin and destination
    var progress: Double  // 0.0 to 1.0 - current position along the route

    // Get current position on route based on progress
    func currentPosition() -> CLLocationCoordinate2D {
        guard waypoints.count >= 2 else {
            return waypoints.first ?? originCoordinate
        }

        let totalSegments = waypoints.count - 1
        let exactPosition = progress * Double(totalSegments)
        let segmentIndex = min(Int(exactPosition), totalSegments - 1)
        let segmentProgress = exactPosition - Double(segmentIndex)

        let start = waypoints[segmentIndex]
        let end = waypoints[min(segmentIndex + 1, waypoints.count - 1)]

        return CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * segmentProgress,
            longitude: start.longitude + (end.longitude - start.longitude) * segmentProgress
        )
    }

    // Get heading at current position
    func currentHeading() -> Double {
        guard waypoints.count >= 2 else { return 0 }

        let totalSegments = waypoints.count - 1
        let exactPosition = progress * Double(totalSegments)
        let segmentIndex = min(Int(exactPosition), totalSegments - 1)

        let start = waypoints[segmentIndex]
        let end = waypoints[min(segmentIndex + 1, waypoints.count - 1)]

        return calculateBearing(from: start, to: end)
    }

    // Calculate bearing between two coordinates
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        var bearing = atan2(x, y) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }
        return bearing
    }

    // Get the traveled path (for drawing the route line)
    func traveledPath() -> [CLLocationCoordinate2D] {
        guard waypoints.count >= 2 else { return [] }

        let totalSegments = waypoints.count - 1
        let exactPosition = progress * Double(totalSegments)
        let segmentIndex = min(Int(exactPosition), totalSegments - 1)

        var path = Array(waypoints.prefix(segmentIndex + 1))
        path.append(currentPosition())
        return path
    }

    // Get the remaining path
    func remainingPath() -> [CLLocationCoordinate2D] {
        guard waypoints.count >= 2 else { return [] }

        let totalSegments = waypoints.count - 1
        let exactPosition = progress * Double(totalSegments)
        let segmentIndex = min(Int(exactPosition), totalSegments - 1)

        var path = [currentPosition()]
        path.append(contentsOf: waypoints.suffix(from: segmentIndex + 1))
        return path
    }
}

// MARK: - Aircraft Model

struct Aircraft: Identifiable, Equatable {
    let id: String                          // Unique ID (e.g., "N12345")
    let flightNumber: String                // e.g., "UA123"
    let aircraftType: String                // e.g., "B737-800"
    let airline: String                     // e.g., "United Airlines"
    var coordinate: CLLocationCoordinate2D
    var heading: Double                     // 0-360 degrees
    var speed: Double                       // Ground speed in knots
    var altitude: Double                    // Feet (0 when on ground)
    var status: FlightStatus
    var gate: String?                       // Assigned gate (e.g., "A12")
    var eta: Date?                          // Estimated time of arrival
    var etd: Date?                          // Estimated time of departure
    var origin: String?                     // Origin airport code
    var destination: String?                // Destination airport code
    var route: FlightRoute?                 // Flight route with waypoints

    init(id: String, flightNumber: String, aircraftType: String, airline: String,
         coordinate: CLLocationCoordinate2D, heading: Double, speed: Double,
         altitude: Double, status: FlightStatus, gate: String? = nil,
         eta: Date? = nil, etd: Date? = nil, origin: String? = nil,
         destination: String? = nil, route: FlightRoute? = nil) {
        self.id = id
        self.flightNumber = flightNumber
        self.aircraftType = aircraftType
        self.airline = airline
        self.coordinate = coordinate
        self.heading = heading
        self.speed = speed
        self.altitude = altitude
        self.status = status
        self.gate = gate
        self.eta = eta
        self.etd = etd
        self.origin = origin
        self.destination = destination
        self.route = route
    }

    // Equatable conformance
    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool {
        lhs.id == rhs.id
    }

    // Convert to GeoJSON Feature for Mapbox
    func toFeature() -> Feature {
        var feature = Feature(geometry: .point(Point(coordinate)))
        var properties: JSONObject = [
            "id": .string(id),
            "flightNumber": .string(flightNumber),
            "aircraftType": .string(aircraftType),
            "airline": .string(airline),
            "heading": .number(heading),
            "speed": .number(speed),
            "altitude": .number(altitude),
            "status": .string(status.rawValue),
            "icon": .string(status.iconName),
            "priority": .number(Double(status.priority)),
            "color": .string(status.color)
        ]
        if let gate = gate {
            properties["gate"] = .string(gate)
        }
        if let origin = origin {
            properties["origin"] = .string(origin)
        }
        if let destination = destination {
            properties["destination"] = .string(destination)
        }
        feature.properties = properties
        return feature
    }

    // Convert route to GeoJSON LineString Feature
    func routeToFeature() -> Feature? {
        guard let route = route else { return nil }

        // Full route line
        let lineString = LineString(route.waypoints)
        var feature = Feature(geometry: .lineString(lineString))
        feature.properties = [
            "id": .string(id),
            "flightNumber": .string(flightNumber),
            "status": .string(status.rawValue),
            "color": .string(status.color)
        ]
        return feature
    }

    // Convert traveled path to GeoJSON LineString Feature
    func traveledPathToFeature() -> Feature? {
        guard let route = route else { return nil }
        let traveledPath = route.traveledPath()
        guard traveledPath.count >= 2 else { return nil }

        let lineString = LineString(traveledPath)
        var feature = Feature(geometry: .lineString(lineString))
        feature.properties = [
            "id": .string(id),
            "flightNumber": .string(flightNumber),
            "type": .string("traveled")
        ]
        return feature
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
