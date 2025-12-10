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

    // Map controls
    @State private var showUserLocation = true
    @State private var rasterVisible = true
    @State private var selectedRoute: String?

    // Airport popup
    @State private var selectedAirport: AirportAnnotation?

    // Download state
    @State private var downloadProgress: Double = 0
    @State private var downloadStage: String = ""
    @State private var isDownloading = false
    @State private var downloadComplete = false
    @State private var downloadError: String?

    // Sheets
    @State private var showOfflineRegions = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Map View
            MapViewWrapper(
                selectedAirport: $selectedAirport,
                downloadProgress: $downloadProgress,
                downloadStage: $downloadStage,
                isDownloading: $isDownloading,
                downloadComplete: $downloadComplete,
                downloadError: $downloadError,
                showUserLocation: showUserLocation,
                rasterVisible: rasterVisible,
                onMapControllerReady: { controller in
                    self.mapController = controller
                }
            )
            .ignoresSafeArea()

            // Map Controls Overlay
            MapControlsView(
                showUserLocation: $showUserLocation,
                rasterVisible: $rasterVisible,
                selectedRoute: $selectedRoute,
                onDownloadCurrentView: startDownload,
                onShowOfflineRegions: { showOfflineRegions = true },
                onFocusRoute: focusOnRoute
            )

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
