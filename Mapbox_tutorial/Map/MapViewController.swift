//
//  MapViewController.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import UIKit
import MapboxMaps
import Combine

// MARK: - Constants

enum MapConstants {
    enum SourceID {
        static let routes = "routes-source"
        static let raster = "terrain-raster-source"
        // Aircraft tracking
        static let aircraft = "aircraft-source"
        static let aircraftRoutes = "aircraft-routes-source"  // Flight paths
        static let selectedRoute = "selected-route-source"    // Highlighted selected aircraft route
        static let gates = "gates-source"
        static let gateLabels = "gate-labels-source"
    }

    enum LayerID {
        static let routeLine = "route-line-layer"
        static let routeLineSFOMSN = "route-line-sfo-msn"
        static let routeLineSFOORD = "route-line-sfo-ord"
        static let airportCircle = "airport-circle-layer"
        static let airportLabel = "airport-label-layer"
        static let raster = "terrain-raster-layer"
        // Aircraft tracking
        static let aircraftSymbol = "aircraft-symbol-layer"
        static let aircraftCluster = "aircraft-cluster-layer"
        static let aircraftClusterCount = "aircraft-cluster-count-layer"
        static let routeTraveled = "route-traveled-layer"     // Solid line - traveled path
        static let routeRemaining = "route-remaining-layer"   // Dashed line - remaining path
        static let selectedRoute = "selected-route-layer"     // Highlighted route for selected aircraft
        static let gateFill = "gate-fill-layer"
        static let gateLine = "gate-line-layer"
        static let gateLabel = "gate-label-layer"
    }

    enum Location {
        static let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        static let sfo = CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.3789)
        static let sfoZoom: CGFloat = 14.0  // Default zoom for airport view
    }
}

// MARK: - Delegate Protocol

protocol MapViewControllerDelegate: AnyObject {
    func mapViewController(_ controller: MapViewController, didTapAirport airport: AirportAnnotation)
    func mapViewController(_ controller: MapViewController, didTapAircraft aircraft: Aircraft)
    func mapViewController(_ controller: MapViewController, didUpdateDownloadProgress progress: Double, stage: String)
    func mapViewControllerDidCompleteDownload(_ controller: MapViewController, region: TileRegion)
    func mapViewController(_ controller: MapViewController, didFailDownloadWithError error: Error)
}

// MARK: - Airport Annotation Model

struct AirportAnnotation {
    let id: String
    let name: String
    let code: String
    let city: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - MapViewController

final class MapViewController: UIViewController {

    // MARK: - Properties

    private(set) var mapView: MapView!
    private var cancellables = Set<AnyCancellable>()

    weak var delegate: MapViewControllerDelegate?

    private var isRasterVisible = true
    private var isMapLoaded = false
    private var pointAnnotationManager: PointAnnotationManager?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        bindMapEvents()
    }

    // MARK: - Setup

    private func setupMapView() {
        let cameraOptions = CameraOptions(
            center: MapConstants.Location.sanFrancisco,
            zoom: 4,
            bearing: 0,
            pitch: 0
        )

        // Configure TileStore for offline tiles
        let tileStore = TileStore.default
        MapboxMapsOptions.tileStore = tileStore
        MapboxMapsOptions.tileStoreUsageMode = .readAndUpdate

        let mapInitOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: .standard
        )

        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        // Enable user location
        mapView.location.options.puckType = .puck2D()
    }

    private func bindMapEvents() {
        mapView.mapboxMap.onMapLoaded.observe { [weak self] _ in
            self?.onMapLoaded()
        }.store(in: &cancellables)
    }

    private func onMapLoaded() {
        print("Map loaded successfully")
        isMapLoaded = true
        addVectorRoutes()
        addRasterOverlay()
        setupTapGesture()

        // Setup GeoSpatio layers
        //setupGateLayers()
        setupAircraftLayers()
    }

    // MARK: - Public Methods

    func showUserLocation(_ show: Bool) {
        mapView.location.options.puckType = show ? .puck2D() : nil
    }

    func flyTo(coordinate: CLLocationCoordinate2D, zoom: CGFloat = 10) {
        let cameraOptions = CameraOptions(center: coordinate, zoom: zoom)
        mapView.camera.fly(to: cameraOptions, duration: 2.0)
    }

    func flyToBounds(_ bounds: CoordinateBounds, padding: UIEdgeInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)) {
        let coordinates = [
            bounds.southwest,
            CLLocationCoordinate2D(latitude: bounds.southwest.latitude, longitude: bounds.northeast.longitude),
            bounds.northeast,
            CLLocationCoordinate2D(latitude: bounds.northeast.latitude, longitude: bounds.southwest.longitude),
            bounds.southwest
        ]
        let cameraOptions = mapView.mapboxMap.camera(
            for: .polygon(Polygon([coordinates])),
            padding: padding,
            bearing: 0,
            pitch: 0
        )
        mapView.camera.fly(to: cameraOptions, duration: 1.5)
    }

    func setRasterVisibility(_ visible: Bool) {
        isRasterVisible = visible
        guard isMapLoaded else { return }
        do {
            try mapView.mapboxMap.updateLayer(
                withId: MapConstants.LayerID.raster,
                type: RasterLayer.self
            ) { layer in
                layer.visibility = .constant(visible ? .visible : .none)
            }
        } catch {
            print("Error toggling raster visibility: \(error)")
        }
    }

    func focusOnRoute(_ routeId: String) {
        let coordinates: [CLLocationCoordinate2D]

        switch routeId {
        case "sfo-msn":
            coordinates = [
                MapConstants.Location.sfo,
                CLLocationCoordinate2D(latitude: 43.1399, longitude: -89.3375)
            ]
        case "sfo-ord":
            coordinates = [
                MapConstants.Location.sfo,
                CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9048)
            ]
        default:
            return
        }

        let bounds = coordinateBounds(from: coordinates)
        let cameraOptions = mapView.mapboxMap.camera(
            for: .polygon(Polygon([coordinates + [coordinates[0]]])),
            padding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
            bearing: 0,
            pitch: 0
        )
        mapView.camera.fly(to: cameraOptions, duration: 1.5)
    }

    private func coordinateBounds(from coordinates: [CLLocationCoordinate2D]) -> CoordinateBounds {
        var minLat = CLLocationDegrees.greatestFiniteMagnitude
        var maxLat = -CLLocationDegrees.greatestFiniteMagnitude
        var minLon = CLLocationDegrees.greatestFiniteMagnitude
        var maxLon = -CLLocationDegrees.greatestFiniteMagnitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return CoordinateBounds(
            southwest: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            northeast: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        )
    }
}

// MARK: - Vector Layers

extension MapViewController {

    private func addVectorRoutes() {
        guard let url = Bundle.main.url(forResource: "routes", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let geojsonObject = try? JSONDecoder().decode(GeoJSONObject.self, from: data) else {
            print("Error: Cannot load routes.geojson")
            return
        }

        do {
            // Add GeoJSON Source
            var source = GeoJSONSource(id: MapConstants.SourceID.routes)
            source.data = .geometry(geojsonObject.geometry ?? .point(Point(CLLocationCoordinate2D())))

            // Try parsing as feature collection
            if case .featureCollection(let fc) = geojsonObject {
                source.data = .featureCollection(fc)
            } else if case .feature(let f) = geojsonObject {
                source.data = .feature(f)
            }

            try mapView.mapboxMap.addSource(source)

            // Add Line Layer for SFO-MSN route (Blue)
            var lineLayerMSN = LineLayer(id: MapConstants.LayerID.routeLineSFOMSN, source: MapConstants.SourceID.routes)
            lineLayerMSN.filter = Exp(.eq) {
                Exp(.get) { "id" }
                "sfo-msn"
            }
            lineLayerMSN.lineColor = .constant(StyleColor(.systemBlue))
            lineLayerMSN.lineWidth = .constant(3.0)
            lineLayerMSN.lineCap = .constant(.round)
            lineLayerMSN.lineJoin = .constant(.round)
            try mapView.mapboxMap.addLayer(lineLayerMSN)

            // Add Line Layer for SFO-ORD route (Orange)
            var lineLayerORD = LineLayer(id: MapConstants.LayerID.routeLineSFOORD, source: MapConstants.SourceID.routes)
            lineLayerORD.filter = Exp(.eq) {
                Exp(.get) { "id" }
                "sfo-ord"
            }
            lineLayerORD.lineColor = .constant(StyleColor(.systemOrange))
            lineLayerORD.lineWidth = .constant(3.0)
            lineLayerORD.lineCap = .constant(.round)
            lineLayerORD.lineJoin = .constant(.round)
            try mapView.mapboxMap.addLayer(lineLayerORD)

            // Add Circle Layer for airports
            var circleLayer = CircleLayer(id: MapConstants.LayerID.airportCircle, source: MapConstants.SourceID.routes)
            circleLayer.filter = Exp(.eq) {
                Exp(.get) { "type" }
                "airport"
            }
            circleLayer.circleRadius = .constant(10.0)
            circleLayer.circleColor = .constant(StyleColor(.systemRed))
            circleLayer.circleStrokeWidth = .constant(2.0)
            circleLayer.circleStrokeColor = .constant(StyleColor(.white))
            try mapView.mapboxMap.addLayer(circleLayer)

            // Add Symbol Layer for airport labels
            var symbolLayer = SymbolLayer(id: MapConstants.LayerID.airportLabel, source: MapConstants.SourceID.routes)
            symbolLayer.filter = Exp(.eq) {
                Exp(.get) { "type" }
                "airport"
            }
            symbolLayer.textField = .expression(Exp(.get) { "code" })
            symbolLayer.textSize = .constant(12)
            symbolLayer.textColor = .constant(StyleColor(.white))
            symbolLayer.textHaloColor = .constant(StyleColor(.black))
            symbolLayer.textHaloWidth = .constant(1)
            symbolLayer.textOffset = .constant([0, 2])
            symbolLayer.textAnchor = .constant(.top)
            try mapView.mapboxMap.addLayer(symbolLayer)

            print("Vector routes added successfully")

        } catch {
            print("Error adding vector layers: \(error)")
        }
    }
}

// MARK: - Raster Layer

extension MapViewController {

    private func addRasterOverlay() {
        do {
            var rasterSource = RasterSource(id: MapConstants.SourceID.raster)
            // Use OpenStreetMap tiles (free, reliable)
            rasterSource.tiles = [
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            ]
            rasterSource.tileSize = 256
            rasterSource.minzoom = 0
            rasterSource.maxzoom = 19
            rasterSource.attribution = "© OpenStreetMap contributors"

            try mapView.mapboxMap.addSource(rasterSource)

            var rasterLayer = RasterLayer(id: MapConstants.LayerID.raster, source: MapConstants.SourceID.raster)
            rasterLayer.rasterOpacity = .constant(0.5)
            rasterLayer.rasterFadeDuration = .constant(0.3)

            // Insert below route lines
            try mapView.mapboxMap.addLayer(rasterLayer, layerPosition: .below(MapConstants.LayerID.routeLineSFOMSN))

            print("Raster overlay added successfully")

        } catch {
            print("Error adding raster layer: \(error)")
        }
    }
}

// MARK: - Tap Gesture for Annotations

extension MapViewController {

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)

        // First check for aircraft tap
        handleAircraftTap(at: point) { [weak self] aircraft in
            guard let self = self else { return }

            if let aircraft = aircraft {
                self.delegate?.mapViewController(self, didTapAircraft: aircraft)
                return
            }

            // Then check for airport tap
            self.queryAirportFeatures(at: point)
        }
    }

    private func queryAirportFeatures(at point: CGPoint) {
        mapView.mapboxMap.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(layerIds: [MapConstants.LayerID.airportCircle], filter: nil)
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let features):
                if let feature = features.first?.queriedFeature.feature,
                   let properties = feature.properties,
                   case .point(let pointGeom) = feature.geometry {

                    let id = self.stringValue(from: properties, key: "id")
                    let name = self.stringValue(from: properties, key: "name")
                    let code = self.stringValue(from: properties, key: "code")
                    let city = self.stringValue(from: properties, key: "city")

                    let airport = AirportAnnotation(
                        id: id,
                        name: name,
                        code: code,
                        city: city,
                        coordinate: pointGeom.coordinates
                    )

                    DispatchQueue.main.async {
                        self.delegate?.mapViewController(self, didTapAirport: airport)
                    }
                }

            case .failure(let error):
                print("Query error: \(error)")
            }
        }
    }

    private func stringValue(from properties: JSONObject, key: String) -> String {
        if let value = properties[key] {
            switch value {
            case .string(let str):
                return str
            case .number(let num):
                return "\(num)"
            default:
                return ""
            }
        }
        return ""
    }
}

// MARK: - Offline Download

extension MapViewController {

    func downloadOfflineRegion(regionId: String, bounds: CoordinateBounds, zoomRange: ClosedRange<UInt8> = 0...14) {
        print("Starting offline region download: \(regionId)")
        print("Bounds: SW(\(bounds.southwest.latitude), \(bounds.southwest.longitude)) NE(\(bounds.northeast.latitude), \(bounds.northeast.longitude))")
        print("Zoom range: \(zoomRange)")

        let offlineManager = OfflineManager()
        let tileStore = TileStore.default

        // Step 1: Download StylePack
        downloadStylePack(offlineManager: offlineManager) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                // Step 2: Download TileRegion
                self.downloadTileRegion(
                    regionId: regionId,
                    bounds: bounds,
                    zoomRange: zoomRange,
                    offlineManager: offlineManager,
                    tileStore: tileStore
                )
            case .failure(let error):
                DispatchQueue.main.async {
                    self.delegate?.mapViewController(self, didFailDownloadWithError: error)
                }
            }
        }
    }

    func downloadCurrentViewRegion(regionId: String) {
        // Get actual visible bounds from the map view
        let bounds = mapView.mapboxMap.coordinateBounds(for: mapView.bounds)
        let center = mapView.mapboxMap.cameraState.center

        // Calculate zoom range: from current-2 down to current+4, capped at 0-20
        // This ensures smooth zooming in/out from current view
        let currentZoom = UInt8(min(max(mapView.mapboxMap.cameraState.zoom, 0), 22))
        let minZoom = max(currentZoom > 4 ? currentZoom - 4 : 0, 0)
        let maxZoom = min(currentZoom + 4, 20)

        print("Current zoom: \(currentZoom), downloading range: \(minZoom)...\(maxZoom)")

        // Reverse geocode to get location name
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            var friendlyName: String
            if let placemark = placemarks?.first {
                // Priority: POI/Street > Neighborhood > City
                // Try to get the most specific location name
                if let name = placemark.name,
                   name != placemark.locality,
                   name != placemark.administrativeArea {
                    // POI or street name (e.g., "SFO Airport", "Market Street")
                    friendlyName = name
                } else if let thoroughfare = placemark.thoroughfare {
                    // Street name (e.g., "Market St")
                    friendlyName = thoroughfare
                    if let subLocality = placemark.subLocality {
                        friendlyName += ", \(subLocality)"
                    }
                } else if let subLocality = placemark.subLocality {
                    // Neighborhood (e.g., "SoMa", "Mission District")
                    friendlyName = subLocality
                } else if let locality = placemark.locality {
                    // City as fallback
                    friendlyName = locality
                } else if let area = placemark.administrativeArea {
                    friendlyName = area
                } else {
                    friendlyName = "Region \(regionId.suffix(8))"
                }
            } else {
                // Fallback to coordinates
                friendlyName = String(format: "%.2f, %.2f", center.latitude, center.longitude)
            }

            // Add zoom info
            let finalName = "\(friendlyName) z\(currentZoom)"
            print("Region name: \(finalName)")

            self.downloadOfflineRegion(regionId: finalName, bounds: bounds, zoomRange: minZoom...maxZoom)
        }
    }

    private func downloadStylePack(
        offlineManager: OfflineManager,
        completion: @escaping (Result<StylePack, Error>) -> Void
    ) {
        print("Starting style pack download...")

        guard let options = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally,
            metadata: ["name": "standard-style"]
        ) else {
            print("Failed to create StylePackLoadOptions")
            let error = NSError(domain: "MapViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create StylePackLoadOptions"])
            completion(.failure(error))
            return
        }

        _ = offlineManager.loadStylePack(
            for: .standard,
            loadOptions: options,
            progress: { [weak self] progress in
                guard let self = self else { return }
                print("Style pack progress: \(progress.completedResourceCount)/\(progress.requiredResourceCount)")
                let percent = Double(progress.completedResourceCount) /
                              Double(max(progress.requiredResourceCount, 1))
                DispatchQueue.main.async {
                    self.delegate?.mapViewController(self, didUpdateDownloadProgress: percent * 0.3, stage: "Downloading style...")
                }
            },
            completion: { result in
                print("Style pack download result: \(result)")
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        )
    }

    private func downloadTileRegion(
        regionId: String,
        bounds: CoordinateBounds,
        zoomRange: ClosedRange<UInt8>,
        offlineManager: OfflineManager,
        tileStore: TileStore
    ) {
        // Create polygon from bounds
        let sw = bounds.southwest
        let ne = bounds.northeast

        let polygon = Polygon([[
            sw,
            CLLocationCoordinate2D(latitude: sw.latitude, longitude: ne.longitude),
            ne,
            CLLocationCoordinate2D(latitude: ne.latitude, longitude: sw.longitude),
            sw
        ]])

        // Create TilesetDescriptor - let SDK determine required tilesets from style
        let descriptorOptions = TilesetDescriptorOptions(
            styleURI: .standard,
            zoomRange: zoomRange,
            tilesets: nil
        )
        let tilesetDescriptor = offlineManager.createTilesetDescriptor(for: descriptorOptions)

        // Configure load options with bounds in metadata for later navigation
        guard let loadOptions = TileRegionLoadOptions(
            geometry: .polygon(polygon),
            descriptors: [tilesetDescriptor],
            metadata: [
                "name": regionId,
                "created": ISO8601DateFormatter().string(from: Date()),
                "swLat": sw.latitude,
                "swLng": sw.longitude,
                "neLat": ne.latitude,
                "neLng": ne.longitude
            ],
            acceptExpired: false,
            networkRestriction: .none,
            averageBytesPerSecond: nil
        ) else {
            DispatchQueue.main.async {
                self.delegate?.mapViewController(self, didFailDownloadWithError: NSError(domain: "MapViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create load options"]))
            }
            return
        }

        // Start download
        print("Starting tile region download: \(regionId)")
        _ = tileStore.loadTileRegion(
            forId: regionId,
            loadOptions: loadOptions) { [weak self] progress in
                guard let self = self else { return }
                print("Tile download progress: \(progress.completedResourceCount)/\(progress.requiredResourceCount)")
                let percent = Double(progress.completedResourceCount) /
                              Double(max(progress.requiredResourceCount, 1))
                DispatchQueue.main.async {
                    self.delegate?.mapViewController(self, didUpdateDownloadProgress: 0.3 + percent * 0.7, stage: "Downloading tiles...")
                }
            } completion: { [weak self] result in
                guard let self = self else { return }
                print("Tile download result: \(result)")
                DispatchQueue.main.async {
                    switch result {
                    case .success(let region):
                        self.delegate?.mapViewControllerDidCompleteDownload(self, region: region)
                    case .failure(let error):
                        self.delegate?.mapViewController(self, didFailDownloadWithError: error)
                    }
                }
            }
    }
}

// MARK: - Offline Region Management

extension MapViewController {

    func listOfflineRegions(completion: @escaping ([TileRegion]) -> Void) {
        let tileStore = TileStore.default

        tileStore.allTileRegions { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let regions):
                    completion(regions)
                case .failure(let error):
                    print("Error listing regions: \(error)")
                    completion([])
                }
            }
        }
    }

    func deleteOfflineRegion(id: String, completion: @escaping (Bool) -> Void) {
        let tileStore = TileStore.default

        tileStore.removeTileRegion(forId: id)
        // The removeTileRegion doesn't have a completion handler in v11
        // Just assume success and call completion
        DispatchQueue.main.async {
            completion(true)
        }
    }
}
