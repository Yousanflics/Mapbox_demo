//
//  MapViewController+Gates.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import UIKit
import MapboxMaps
import CoreLocation

// MARK: - Gate Layer Extension

extension MapViewController {

    // MARK: - Setup Gate Layers

    func setupGateLayers() {
        loadGateData()
        setupGateFillLayer()
        setupGateLineLayer()
        setupGateLabelLayer()
    }

    private func loadGateData() {
        guard let url = Bundle.main.url(forResource: "sfo_gates", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let geojson = try? JSONDecoder().decode(GeoJSONObject.self, from: data) else {
            print("Failed to load gate data from sfo_gates.geojson")
            return
        }

        var source = GeoJSONSource(id: MapConstants.SourceID.gates)
        if case .featureCollection(let fc) = geojson {
            source.data = .featureCollection(fc)
        }
        try? mapView.mapboxMap.addSource(source)
    }

    private func setupGateFillLayer() {
        var layer = FillLayer(id: MapConstants.LayerID.gateFill,
                              source: MapConstants.SourceID.gates)

        // Color based on status
        layer.fillColor = .expression(
            Exp(.match) {
                Exp(.get) { "status" }
                "available"
                UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 0.4)   // Green
                "occupied"
                UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 0.4)   // Blue
                "reserved"
                UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 0.4)   // Orange
                "maintenance"
                UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 0.4) // Gray
                UIColor.gray.withAlphaComponent(0.4)
            }
        )
        layer.fillOpacity = .constant(0.7)

        // Insert below aircraft layers
        try? mapView.mapboxMap.addLayer(layer)
    }

    private func setupGateLineLayer() {
        var layer = LineLayer(id: MapConstants.LayerID.gateLine,
                              source: MapConstants.SourceID.gates)

        // Border color based on status
        layer.lineColor = .expression(
            Exp(.match) {
                Exp(.get) { "status" }
                "available"
                UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)
                "occupied"
                UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
                "reserved"
                UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1.0)
                "maintenance"
                UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1.0)
                UIColor.gray
            }
        )
        layer.lineWidth = .constant(2)

        try? mapView.mapboxMap.addLayer(layer, layerPosition: .above(MapConstants.LayerID.gateFill))
    }

    private func setupGateLabelLayer() {
        var layer = SymbolLayer(id: MapConstants.LayerID.gateLabel,
                                source: MapConstants.SourceID.gates)

        layer.textField = .expression(Exp(.get) { "id" })
        layer.textSize = .constant(11)
        layer.textColor = .constant(StyleColor(.label))
        layer.textHaloColor = .constant(StyleColor(.systemBackground))
        layer.textHaloWidth = .constant(1)
        layer.textAllowOverlap = .constant(true)

        try? mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Update Gate Statuses

    func updateGateStatuses(_ gates: [Gate]) {
        let features = gates.map { $0.toPolygonFeature() }
        let featureCollection = FeatureCollection(features: features)

        try? mapView.mapboxMap.updateGeoJSONSource(
            withId: MapConstants.SourceID.gates,
            geoJSON: .featureCollection(featureCollection)
        )
    }

    // MARK: - Gate Tap Handling

    func handleGateTap(at point: CGPoint, completion: @escaping (String?) -> Void) {
        mapView.mapboxMap.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(
                layerIds: [MapConstants.LayerID.gateFill],
                filter: nil
            )
        ) { result in
            switch result {
            case .success(let features):
                if let feature = features.first?.queriedFeature.feature,
                   let properties = feature.properties,
                   let gateId = properties["id"] {
                    switch gateId {
                    case .string(let id):
                        DispatchQueue.main.async {
                            completion(id)
                        }
                    default:
                        DispatchQueue.main.async {
                            completion(nil)
                        }
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
}
