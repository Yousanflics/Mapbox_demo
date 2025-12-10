//
//  ContentView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Map Layer Mode

enum MapLayerMode: String, CaseIterable {
    case pureMap = "Pure Map"
    case withAircraft = "With Aircraft"
    case withTerrain = "With Terrain"

    var icon: String {
        switch self {
        case .pureMap: return "map"
        case .withAircraft: return "airplane"
        case .withTerrain: return "mountain.2"
        }
    }

    var color: Color {
        switch self {
        case .pureMap: return .gray
        case .withAircraft: return .blue
        case .withTerrain: return .green
        }
    }
}

struct ContentView: View {

    // MARK: - State

    @State private var mapController: MapViewController?

    // Aircraft simulator
    @StateObject private var aircraftSimulator = AircraftSimulator()

    // Map controls
    @State private var showUserLocation = true
    @State private var rasterVisible = false
    @State private var aircraftVisible = true
    @State private var selectedRoute: String?
    @State private var mapLayerMode: MapLayerMode = .withAircraft

    // Airport popup
    @State private var selectedAirport: AirportAnnotation?

    // Aircraft popup
    @State private var selectedAircraft: Aircraft?

    // Download state
    @State private var downloadProgress: Double = 0
    @State private var downloadStage: String = ""
    @State private var isDownloading = false
    @State private var downloadComplete = false
    @State private var downloadError: String?

    // Sheets
    @State private var showOfflineRegions = false
    @State private var showFlightList = false
    @State private var showAirportPicker = false

    // Available airports for selection
    private let airports: [(code: String, name: String, coordinate: CLLocationCoordinate2D)] = [
        ("SFO", "San Francisco", CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.3789)),
        ("LAX", "Los Angeles", CLLocationCoordinate2D(latitude: 33.9425, longitude: -118.4081)),
        ("JFK", "New York JFK", CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781)),
        ("ORD", "Chicago O'Hare", CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9073)),
        ("DFW", "Dallas Fort Worth", CLLocationCoordinate2D(latitude: 32.8998, longitude: -97.0403)),
        ("DEN", "Denver", CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737)),
        ("SEA", "Seattle", CLLocationCoordinate2D(latitude: 47.4502, longitude: -122.3088))
    ]

    @State private var selectedAirportCode = "SFO"

    // MARK: - Body

    var body: some View {
        ZStack {
            // Map View
            MapViewWrapper(
                selectedAirport: $selectedAirport,
                selectedAircraft: $selectedAircraft,
                downloadProgress: $downloadProgress,
                downloadStage: $downloadStage,
                isDownloading: $isDownloading,
                downloadComplete: $downloadComplete,
                downloadError: $downloadError,
                aircrafts: aircraftSimulator.aircrafts,
                showUserLocation: showUserLocation,
                rasterVisible: rasterVisible,
                onMapControllerReady: { controller in
                    self.mapController = controller
                    // Fly to SFO and start simulation
                    controller.flyTo(coordinate: MapConstants.Location.sfo, zoom: MapConstants.Location.sfoZoom)
                    aircraftSimulator.startSimulation(aircraftCount: 500)
                }
            )
            .ignoresSafeArea()

            // Map Controls Overlay
            VStack {
                // Top bar - pushed down to avoid compass/scale
                HStack {
                    // Airport picker button
                    Button(action: { showAirportPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "airplane.circle.fill")
                                .foregroundColor(.blue)
                            Text(currentAirportName)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Flight count badge
                    Button(action: { showFlightList = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("\(aircraftSimulator.aircrafts.count)")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 60)  // Push down to avoid compass

                Spacer()

                // Bottom controls with colors
                HStack(spacing: 12) {
                    // Zoom to airport - blue
                    Button(action: {
                        if let airport = airports.first(where: { $0.code == selectedAirportCode }) {
                            mapController?.flyTo(coordinate: airport.coordinate, zoom: 14)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .cornerRadius(22)
                    }

                    // Layer mode menu
                    Menu {
                        ForEach(MapLayerMode.allCases, id: \.self) { mode in
                            Button(action: {
                                mapLayerMode = mode
                                applyMapLayerMode(mode)
                            }) {
                                Label(mode.rawValue, systemImage: mode.icon)
                                if mapLayerMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: mapLayerMode.icon)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(mapLayerMode.color)
                            .cornerRadius(22)
                    }

                    // Offline regions - orange
                    Button(action: { showOfflineRegions = true }) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.orange)
                            .cornerRadius(22)
                    }

                    Spacer()

                    // Flight list button
                    Button(action: { showFlightList = true }) {
                        HStack {
                            Image(systemName: "airplane")
                            Text("Flights")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(22)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }

            // Airport Popup
            if let airport = selectedAirport {
                VStack {
                    Spacer()

                    AirportPopupView(
                        airport: airport,
                        onDismiss: { selectedAirport = nil },
                        onDownloadRegion: {
                            downloadAirportRegion(airport)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 120)
                }
                .animation(.spring(), value: selectedAirport != nil)
            }

            // Aircraft Popup
            if let aircraft = selectedAircraft {
                VStack {
                    Spacer()

                    AircraftPopupView(
                        aircraft: aircraft,
                        onDismiss: { selectedAircraft = nil },
                        onViewDetails: {
                            // Could open a detail view
                            selectedAircraft = nil
                            showFlightList = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 120)
                }
                .animation(.spring(), value: selectedAircraft != nil)
            }

            // Download Progress Overlay
            if isDownloading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack {
                    Spacer()

                    DownloadProgressView(
                        progress: downloadProgress,
                        stage: downloadStage,
                        onCancel: cancelDownload
                    )

                    Spacer()
                }
                .transition(.opacity)
            }

            // Download Complete Overlay
            if downloadComplete {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack {
                    Spacer()

                    DownloadCompleteView {
                        downloadComplete = false
                        resetDownloadState()
                    }

                    Spacer()
                }
                .transition(.opacity)
            }

            // Download Error Overlay
            if let error = downloadError {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack {
                    Spacer()

                    DownloadErrorView(
                        error: error,
                        onRetry: {
                            downloadError = nil
                            startDownload()
                        },
                        onDismiss: {
                            downloadError = nil
                            resetDownloadState()
                        }
                    )

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isDownloading)
        .animation(.easeInOut(duration: 0.25), value: downloadComplete)
        .animation(.easeInOut(duration: 0.25), value: downloadError != nil)
        .sheet(isPresented: $showOfflineRegions) {
            OfflineRegionsView(
                mapController: mapController,
                onRegionSelected: { region in
                    print("Selected region: \(region.name)")
                    print("Region bounds: \(String(describing: region.bounds))")
                    print("mapController: \(mapController != nil ? "exists" : "nil")")
                    if let bounds = region.bounds {
                        print("Flying to bounds: SW(\(bounds.southwest.latitude), \(bounds.southwest.longitude)) NE(\(bounds.northeast.latitude), \(bounds.northeast.longitude))")
                        mapController?.flyToBounds(bounds)
                    } else {
                        print("No bounds available for this region")
                    }
                }
            )
        }
        .sheet(isPresented: $showFlightList) {
            FlightListSheet(
                aircrafts: aircraftSimulator.aircrafts,
                onSelectAircraft: { aircraft in
                    showFlightList = false
                    // Fly to aircraft and show popup
                    mapController?.flyTo(coordinate: aircraft.coordinate, zoom: 16)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedAircraft = aircraft
                    }
                }
            )
            .presentationDetents([.fraction(0.4), .large])
            .presentationDragIndicator(.visible)
        }
        .onDisappear {
            aircraftSimulator.stopSimulation()
        }
        .sheet(isPresented: $showAirportPicker) {
            AirportPickerSheet(
                airports: airports,
                selectedCode: $selectedAirportCode,
                onSelect: { airport in
                    showAirportPicker = false
                    mapController?.flyTo(coordinate: airport.coordinate, zoom: 14)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Computed Properties

    private var currentAirportName: String {
        if let airport = airports.first(where: { $0.code == selectedAirportCode }) {
            return "\(airport.code) - \(airport.name)"
        }
        return selectedAirportCode
    }

    // MARK: - Actions

    private func applyMapLayerMode(_ mode: MapLayerMode) {
        switch mode {
        case .pureMap:
            aircraftVisible = false
            rasterVisible = false
        case .withAircraft:
            aircraftVisible = true
            rasterVisible = false
        case .withTerrain:
            aircraftVisible = true
            rasterVisible = true
        }
        mapController?.setRasterVisibility(rasterVisible)
        mapController?.setAircraftVisibility(aircraftVisible)
    }

    private func focusOnRoute(_ routeId: String) {
        mapController?.focusOnRoute(routeId)
    }

    private func startDownload() {
        guard !isDownloading else { return }

        print("startDownload called, mapController: \(mapController != nil ? "exists" : "nil")")

        isDownloading = true
        downloadProgress = 0
        downloadStage = "Preparing..."

        let regionId = "view-\(UUID().uuidString.prefix(8))"
        mapController?.downloadCurrentViewRegion(regionId: regionId)
    }

    private func downloadAirportRegion(_ airport: AirportAnnotation) {
        guard !isDownloading else { return }

        selectedAirport = nil
        isDownloading = true
        downloadProgress = 0
        downloadStage = "Preparing..."

        // Create bounds around airport (0.3 degree radius)
        let delta = 0.3
        let bounds = CoordinateBounds(
            southwest: CLLocationCoordinate2D(
                latitude: airport.coordinate.latitude - delta,
                longitude: airport.coordinate.longitude - delta
            ),
            northeast: CLLocationCoordinate2D(
                latitude: airport.coordinate.latitude + delta,
                longitude: airport.coordinate.longitude + delta
            )
        )

        let regionId = "airport-\(airport.code.lowercased())"
        mapController?.downloadOfflineRegion(regionId: regionId, bounds: bounds)
    }

    private func cancelDownload() {
        // Note: Mapbox SDK doesn't provide easy cancellation for tile downloads
        // In production, you'd track the download task and cancel it
        isDownloading = false
        resetDownloadState()
    }

    private func resetDownloadState() {
        downloadProgress = 0
        downloadStage = ""
    }
}

// MARK: - Airport Picker Sheet

struct AirportPickerSheet: View {
    let airports: [(code: String, name: String, coordinate: CLLocationCoordinate2D)]
    @Binding var selectedCode: String
    let onSelect: ((code: String, name: String, coordinate: CLLocationCoordinate2D)) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(airports, id: \.code) { airport in
                    Button(action: {
                        selectedCode = airport.code
                        onSelect(airport)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(airport.code)
                                    .font(.headline)
                                Text(airport.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if airport.code == selectedCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Airport")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
