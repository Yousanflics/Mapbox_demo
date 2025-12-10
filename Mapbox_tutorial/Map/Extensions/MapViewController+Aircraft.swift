//
//  MapViewController+Aircraft.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import UIKit
import MapboxMaps
import CoreLocation

// MARK: - Aircraft Layer Extension

extension MapViewController {

    // MARK: - Setup Aircraft Layers

    func setupAircraftLayers() {
        loadAircraftIcons()
        setupRouteSource()
        setupRouteLayer()
        setupAircraftSource()
        setupAircraftSymbolLayer()
        setupAircraftClusterLayers()
    }

    private func loadAircraftIcons() {
        // Create aircraft icons for each status using SF Symbols
        let iconConfigs: [(String, String, UIColor)] = [
            ("aircraft-approaching", "airplane", .systemBlue),
            ("aircraft-taxiing", "airplane", .systemGreen),
            ("aircraft-parked", "airplane", .systemGray),
            ("aircraft-boarding", "airplane", .systemGreen),
            ("aircraft-departed", "airplane", .systemGray),
            ("aircraft-delayed", "airplane", .systemRed),
            ("aircraft-cancelled", "airplane", .systemGray)
        ]

        for (iconName, sfSymbol, color) in iconConfigs {
            if let image = createAircraftIcon(sfSymbol: sfSymbol, color: color, size: 32) {
                try? mapView.mapboxMap.addImage(image, id: iconName, sdf: false)
                print("Added icon: \(iconName)")
            } else {
                print("Failed to create icon: \(iconName)")
            }
        }
    }

    private func createAircraftIcon(sfSymbol: String, color: UIColor, size: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        guard let symbolImage = UIImage(systemName: sfSymbol, withConfiguration: config) else {
            return nil
        }

        // SF Symbol airplane points RIGHT (east) by default
        // We need to rotate it -90 degrees so it points UP (north)
        // Then Mapbox iconRotate with heading will work correctly
        let canvasSize = size * 1.5
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize))
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Move to center, rotate -90 degrees (counterclockwise), then draw
            cgContext.translateBy(x: canvasSize / 2, y: canvasSize / 2)
            cgContext.rotate(by: -.pi / 2)  // -90 degrees to point UP
            cgContext.translateBy(x: -canvasSize / 2, y: -canvasSize / 2)

            // Draw the symbol centered
            let rect = CGRect(x: (canvasSize - symbolImage.size.width) / 2,
                              y: (canvasSize - symbolImage.size.height) / 2,
                              width: symbolImage.size.width,
                              height: symbolImage.size.height)
            symbolImage.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: rect)
        }

        return image
    }

    // MARK: - Route Layer Setup

    private func setupRouteSource() {
        // All aircraft routes (dimmed)
        var source = GeoJSONSource(id: MapConstants.SourceID.aircraftRoutes)
        source.data = .featureCollection(FeatureCollection(features: []))
        try? mapView.mapboxMap.addSource(source)

        // Selected aircraft route (highlighted)
        var selectedSource = GeoJSONSource(id: MapConstants.SourceID.selectedRoute)
        selectedSource.data = .featureCollection(FeatureCollection(features: []))
        try? mapView.mapboxMap.addSource(selectedSource)
    }

    private func setupRouteLayer() {
        // Remaining path layer (dashed line - shows where aircraft will go)
        var remainingLayer = LineLayer(id: MapConstants.LayerID.routeRemaining,
                                       source: MapConstants.SourceID.aircraftRoutes)
        remainingLayer.filter = Exp(.eq) {
            Exp(.get) { "type" }
            "remaining"
        }
        remainingLayer.lineColor = .expression(
            Exp(.match) {
                Exp(.get) { "status" }
                "approaching"
                UIColor.systemBlue.withAlphaComponent(0.3)
                "taxiingIn"
                UIColor.systemGreen.withAlphaComponent(0.3)
                "taxiingOut"
                UIColor.systemOrange.withAlphaComponent(0.3)
                "departed"
                UIColor.systemGray.withAlphaComponent(0.3)
                UIColor.systemGray.withAlphaComponent(0.2)
            }
        )
        remainingLayer.lineWidth = .constant(1.5)
        remainingLayer.lineDasharray = .constant([4, 4])

        // Traveled path layer (solid line - shows where aircraft has been)
        var traveledLayer = LineLayer(id: MapConstants.LayerID.routeTraveled,
                                      source: MapConstants.SourceID.aircraftRoutes)
        traveledLayer.filter = Exp(.eq) {
            Exp(.get) { "type" }
            "traveled"
        }
        traveledLayer.lineColor = .expression(
            Exp(.match) {
                Exp(.get) { "status" }
                "approaching"
                UIColor.systemBlue.withAlphaComponent(0.5)
                "taxiingIn"
                UIColor.systemGreen.withAlphaComponent(0.5)
                "taxiingOut"
                UIColor.systemOrange.withAlphaComponent(0.5)
                "departed"
                UIColor.systemGray.withAlphaComponent(0.5)
                UIColor.systemGray.withAlphaComponent(0.3)
            }
        )
        traveledLayer.lineWidth = .constant(2)
        traveledLayer.lineCap = .constant(.round)
        traveledLayer.lineJoin = .constant(.round)

        // Selected route layer (highlighted, on top)
        var selectedLayer = LineLayer(id: MapConstants.LayerID.selectedRoute,
                                      source: MapConstants.SourceID.selectedRoute)
        selectedLayer.lineColor = .expression(
            Exp(.match) {
                Exp(.get) { "status" }
                "approaching"
                UIColor.systemBlue
                "taxiingIn"
                UIColor.systemGreen
                "taxiingOut"
                UIColor.systemOrange
                "departed"
                UIColor.systemPurple
                UIColor.systemBlue
            }
        )
        selectedLayer.lineWidth = .constant(4)
        selectedLayer.lineCap = .constant(.round)
        selectedLayer.lineJoin = .constant(.round)

        try? mapView.mapboxMap.addLayer(remainingLayer)
        try? mapView.mapboxMap.addLayer(traveledLayer)
        try? mapView.mapboxMap.addLayer(selectedLayer)
    }

    private func setupAircraftSource() {
        var source = GeoJSONSource(id: MapConstants.SourceID.aircraft)
        source.data = .featureCollection(FeatureCollection(features: []))

        // Enable clustering for performance (only at very low zoom levels)
        source.cluster = true
        source.clusterRadius = 50
        source.clusterMaxZoom = 10  // Only cluster when zoom < 10

        try? mapView.mapboxMap.addSource(source)
    }

    private func setupAircraftSymbolLayer() {
        var layer = SymbolLayer(id: MapConstants.LayerID.aircraftSymbol,
                                source: MapConstants.SourceID.aircraft)

        // Only show unclustered points
        layer.filter = Exp(.not) { Exp(.has) { "point_count" } }

        // Icon configuration - larger size for visibility
        layer.iconImage = .expression(Exp(.get) { "icon" })
        // Dynamic icon size based on zoom level
        layer.iconSize = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                8; 0.3    // zoom 8: very small
                10; 0.4   // zoom 10: small
                14; 0.6   // zoom 14: medium
                18; 1.0   // zoom 18: full size
            }
        )
        layer.iconRotate = .expression(Exp(.get) { "heading" })
        layer.iconRotationAlignment = .constant(.map)
        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconAnchor = .constant(.center)

        // Text label (flight number) - below icon
        layer.textField = .expression(Exp(.get) { "flightNumber" })
        layer.textSize = .constant(11)
        layer.textOffset = .constant([0, 2.0])
        layer.textAnchor = .constant(.top)
        layer.textColor = .constant(StyleColor(.label))
        layer.textHaloColor = .constant(StyleColor(.systemBackground))
        layer.textHaloWidth = .constant(1)
        layer.textOptional = .constant(true)

        try? mapView.mapboxMap.addLayer(layer)
    }

    private func setupAircraftClusterLayers() {
        // Cluster circle layer
        var clusterLayer = CircleLayer(id: MapConstants.LayerID.aircraftCluster,
                                       source: MapConstants.SourceID.aircraft)
        clusterLayer.filter = Exp(.has) { "point_count" }
        clusterLayer.circleColor = .expression(
            Exp(.step) {
                Exp(.get) { "point_count" }
                UIColor.systemBlue
                10
                UIColor.systemOrange
                50
                UIColor.systemRed
            }
        )
        clusterLayer.circleRadius = .expression(
            Exp(.step) {
                Exp(.get) { "point_count" }
                15
                10
                20
                50
                25
            }
        )
        clusterLayer.circleStrokeWidth = .constant(2)
        clusterLayer.circleStrokeColor = .constant(StyleColor(.white))

        // Cluster count label
        var countLayer = SymbolLayer(id: MapConstants.LayerID.aircraftClusterCount,
                                     source: MapConstants.SourceID.aircraft)
        countLayer.filter = Exp(.has) { "point_count" }
        countLayer.textField = .expression(Exp(.get) { "point_count" })
        countLayer.textSize = .constant(12)
        countLayer.textColor = .constant(StyleColor(.white))

        try? mapView.mapboxMap.addLayer(clusterLayer)
        try? mapView.mapboxMap.addLayer(countLayer)
    }

    // MARK: - Update Aircraft Positions

    func updateAircraftPositions(_ aircrafts: [Aircraft]) {
        // Update aircraft positions
        let aircraftFeatures = aircrafts.map { $0.toFeature() }
        let aircraftCollection = FeatureCollection(features: aircraftFeatures)

        try? mapView.mapboxMap.updateGeoJSONSource(
            withId: MapConstants.SourceID.aircraft,
            geoJSON: .featureCollection(aircraftCollection)
        )

        // Update route lines
        updateRouteLines(for: aircrafts)
    }

    private func updateRouteLines(for aircrafts: [Aircraft]) {
        var routeFeatures: [Feature] = []

        for aircraft in aircrafts {
            guard let route = aircraft.route else { continue }

            // Only show routes for moving aircraft
            guard [.approaching, .taxiingIn, .taxiingOut, .departed].contains(aircraft.status) else {
                continue
            }

            // Remaining path (dashed line)
            let remainingPath = route.remainingPath()
            if remainingPath.count >= 2 {
                var remainingFeature = Feature(geometry: .lineString(LineString(remainingPath)))
                remainingFeature.properties = [
                    "id": .string(aircraft.id),
                    "flightNumber": .string(aircraft.flightNumber),
                    "status": .string(aircraft.status.rawValue),
                    "type": .string("remaining")
                ]
                routeFeatures.append(remainingFeature)
            }

            // Traveled path (solid line)
            let traveledPath = route.traveledPath()
            if traveledPath.count >= 2 {
                var traveledFeature = Feature(geometry: .lineString(LineString(traveledPath)))
                traveledFeature.properties = [
                    "id": .string(aircraft.id),
                    "flightNumber": .string(aircraft.flightNumber),
                    "status": .string(aircraft.status.rawValue),
                    "type": .string("traveled")
                ]
                routeFeatures.append(traveledFeature)
            }
        }

        let routeCollection = FeatureCollection(features: routeFeatures)

        try? mapView.mapboxMap.updateGeoJSONSource(
            withId: MapConstants.SourceID.aircraftRoutes,
            geoJSON: .featureCollection(routeCollection)
        )
    }

    // MARK: - Route Highlighting

    func highlightAircraftRoute(_ aircraft: Aircraft?) {
        guard let aircraft = aircraft, let route = aircraft.route else {
            // Clear highlighted route
            try? mapView.mapboxMap.updateGeoJSONSource(
                withId: MapConstants.SourceID.selectedRoute,
                geoJSON: .featureCollection(FeatureCollection(features: []))
            )
            return
        }

        var features: [Feature] = []

        // Full route line
        let lineString = LineString(route.waypoints)
        var feature = Feature(geometry: .lineString(lineString))
        feature.properties = [
            "id": .string(aircraft.id),
            "flightNumber": .string(aircraft.flightNumber),
            "status": .string(aircraft.status.rawValue)
        ]
        features.append(feature)

        try? mapView.mapboxMap.updateGeoJSONSource(
            withId: MapConstants.SourceID.selectedRoute,
            geoJSON: .featureCollection(FeatureCollection(features: features))
        )
    }

    // MARK: - Tap Handling

    func handleAircraftTap(at point: CGPoint, completion: @escaping (Aircraft?) -> Void) {
        // First check if we tapped on a cluster
        mapView.mapboxMap.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(
                layerIds: [MapConstants.LayerID.aircraftCluster],
                filter: nil
            )
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let features):
                if let feature = features.first?.queriedFeature.feature,
                   let properties = feature.properties,
                   properties["point_count"] != nil,
                   case .point(let point) = feature.geometry {
                    // Tapped on cluster - zoom in
                    let cameraOptions = CameraOptions(
                        center: point.coordinates,
                        zoom: self.mapView.mapboxMap.cameraState.zoom + 2
                    )
                    self.mapView.camera.fly(to: cameraOptions, duration: 0.5)
                    completion(nil)
                    return
                }
            case .failure:
                break
            }

            // Check for individual aircraft
            self.queryAircraftFeature(at: point, completion: completion)
        }
    }

    private func queryAircraftFeature(at point: CGPoint, completion: @escaping (Aircraft?) -> Void) {
        mapView.mapboxMap.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(
                layerIds: [MapConstants.LayerID.aircraftSymbol],
                filter: nil
            )
        ) { [weak self] result in
            switch result {
            case .success(let features):
                if let feature = features.first?.queriedFeature.feature,
                   let properties = feature.properties,
                   case .point(let pointGeom) = feature.geometry {
                    let aircraft = self?.parseAircraftFromFeature(properties, coordinate: pointGeom.coordinates)
                    DispatchQueue.main.async {
                        completion(aircraft)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func parseAircraftFromFeature(_ properties: JSONObject, coordinate: CLLocationCoordinate2D) -> Aircraft? {
        guard let id = stringValue(from: properties, key: "id"),
              let flightNumber = stringValue(from: properties, key: "flightNumber"),
              let aircraftType = stringValue(from: properties, key: "aircraftType"),
              let airline = stringValue(from: properties, key: "airline"),
              let heading = doubleValue(from: properties, key: "heading"),
              let speed = doubleValue(from: properties, key: "speed"),
              let altitude = doubleValue(from: properties, key: "altitude"),
              let statusRaw = stringValue(from: properties, key: "status"),
              let status = FlightStatus(rawValue: statusRaw) else {
            return nil
        }

        return Aircraft(
            id: id,
            flightNumber: flightNumber,
            aircraftType: aircraftType,
            airline: airline,
            coordinate: coordinate,
            heading: heading,
            speed: speed,
            altitude: altitude,
            status: status,
            gate: stringValue(from: properties, key: "gate"),
            origin: stringValue(from: properties, key: "origin"),
            destination: stringValue(from: properties, key: "destination")
        )
    }

    private func stringValue(from properties: JSONObject, key: String) -> String? {
        if let value = properties[key] {
            switch value {
            case .string(let str):
                return str
            case .number(let num):
                return "\(num)"
            default:
                return nil
            }
        }
        return nil
    }

    private func doubleValue(from properties: JSONObject, key: String) -> Double? {
        if let value = properties[key] {
            switch value {
            case .number(let num):
                return num
            case .string(let str):
                return Double(str)
            default:
                return nil
            }
        }
        return nil
    }
}
