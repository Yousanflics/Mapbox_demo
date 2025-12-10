//
//  ContentView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct ContentView: View {

    // MARK: - State

    @State private var mapController: MapViewController?

    // Aircraft simulator
    @StateObject private var aircraftSimulator = AircraftSimulator()

    // Map controls
    @State private var showUserLocation = true
    @State private var rasterVisible = false  // Start with raster hidden for cleaner view
    @State private var selectedRoute: String?

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
                // Top bar
                HStack {
                    // Airport info badge
                    HStack(spacing: 8) {
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                        Text("SFO - San Francisco")
                            .font(.headline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)

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
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                HStack(spacing: 12) {
                    // Zoom to SFO
                    Button(action: {
                        mapController?.flyTo(coordinate: MapConstants.Location.sfo, zoom: MapConstants.Location.sfoZoom)
                    }) {
                        Image(systemName: "location.fill")
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .cornerRadius(22)
                    }

                    // Toggle raster
                    Button(action: { rasterVisible.toggle() }) {
                        Image(systemName: rasterVisible ? "map.fill" : "map")
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .cornerRadius(22)
                    }

                    // Offline regions
                    Button(action: { showOfflineRegions = true }) {
                        Image(systemName: "arrow.down.circle")
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
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
    }

    // MARK: - Actions

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

// MARK: - Preview

#Preview {
    ContentView()
}
