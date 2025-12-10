//
//  Gate.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import Foundation
import CoreLocation
import MapboxMaps

// MARK: - Gate Status

enum GateStatus: String, Codable, CaseIterable {
    case available      // Green - empty, ready
    case occupied       // Blue - aircraft present
    case reserved       // Orange - assigned to incoming
    case maintenance    // Gray - unavailable

    var color: String {
        switch self {
        case .available: return "#34C759"
        case .occupied: return "#007AFF"
        case .reserved: return "#FF9500"
        case .maintenance: return "#8E8E93"
        }
    }

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .occupied: return "Occupied"
        case .reserved: return "Reserved"
        case .maintenance: return "Maintenance"
        }
    }
}

// MARK: - Aircraft Size

enum AircraftSize: String, Codable {
    case small      // Regional jets, turboprops
    case medium     // A320, B737
    case large      // A330, B777
    case heavy      // A380, B747
}

// MARK: - Gate Model

struct Gate: Identifiable, Codable, Equatable {
    let id: String                          // e.g., "A12"
    let terminal: String                    // e.g., "Terminal 1"
    let coordinate: CLLocationCoordinate2D  // Center point
    let polygon: [CLLocationCoordinate2D]   // Gate area boundary
    var status: GateStatus
    var assignedFlight: String?             // Flight number if occupied/reserved
    var nextAvailable: Date?
    let aircraftSizeLimit: AircraftSize

    // Codable conformance for CLLocationCoordinate2D arrays
    enum CodingKeys: String, CodingKey {
        case id, terminal, status, assignedFlight, nextAvailable, aircraftSizeLimit
        case centerLat, centerLon, polygonCoords
    }

    init(id: String, terminal: String, coordinate: CLLocationCoordinate2D,
         polygon: [CLLocationCoordinate2D], status: GateStatus,
         assignedFlight: String? = nil, nextAvailable: Date? = nil,
         aircraftSizeLimit: AircraftSize = .medium) {
        self.id = id
        self.terminal = terminal
        self.coordinate = coordinate
        self.polygon = polygon
        self.status = status
        self.assignedFlight = assignedFlight
        self.nextAvailable = nextAvailable
        self.aircraftSizeLimit = aircraftSizeLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        terminal = try container.decode(String.self, forKey: .terminal)
        let centerLat = try container.decode(Double.self, forKey: .centerLat)
        let centerLon = try container.decode(Double.self, forKey: .centerLon)
        coordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        let coords = try container.decode([[Double]].self, forKey: .polygonCoords)
        polygon = coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }

        status = try container.decode(GateStatus.self, forKey: .status)
        assignedFlight = try container.decodeIfPresent(String.self, forKey: .assignedFlight)
        nextAvailable = try container.decodeIfPresent(Date.self, forKey: .nextAvailable)
        aircraftSizeLimit = try container.decode(AircraftSize.self, forKey: .aircraftSizeLimit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(terminal, forKey: .terminal)
        try container.encode(coordinate.latitude, forKey: .centerLat)
        try container.encode(coordinate.longitude, forKey: .centerLon)
        try container.encode(polygon.map { [$0.latitude, $0.longitude] }, forKey: .polygonCoords)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(assignedFlight, forKey: .assignedFlight)
        try container.encodeIfPresent(nextAvailable, forKey: .nextAvailable)
        try container.encode(aircraftSizeLimit, forKey: .aircraftSizeLimit)
    }

    // Equatable
    static func == (lhs: Gate, rhs: Gate) -> Bool {
        lhs.id == rhs.id
    }

    // Convert to GeoJSON Feature for polygon rendering
    func toPolygonFeature() -> Feature {
        let coordinates = polygon + [polygon.first!] // Close the polygon
        var feature = Feature(geometry: .polygon(Polygon([coordinates])))
        var properties: JSONObject = [
            "id": .string(id),
            "terminal": .string(terminal),
            "status": .string(status.rawValue),
            "color": .string(status.color)
        ]
        if let assignedFlight = assignedFlight {
            properties["assignedFlight"] = .string(assignedFlight)
        }
        feature.properties = properties
        return feature
    }

    // Convert to GeoJSON Feature for label
    func toLabelFeature() -> Feature {
        var feature = Feature(geometry: .point(Point(coordinate)))
        feature.properties = [
            "id": .string(id),
            "label": .string(id),
            "status": .string(status.rawValue)
        ]
        return feature
    }
}
