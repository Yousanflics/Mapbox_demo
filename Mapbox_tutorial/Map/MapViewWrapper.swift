//
//  MapViewWrapper.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI
import MapboxMaps

// MARK: - MapViewWrapper

struct MapViewWrapper: UIViewControllerRepresentable {

    @Binding var selectedAirport: AirportAnnotation?
    @Binding var downloadProgress: Double
    @Binding var downloadStage: String
    @Binding var isDownloading: Bool
    @Binding var downloadComplete: Bool
    @Binding var downloadError: String?

    var showUserLocation: Bool
    var rasterVisible: Bool
    var onMapControllerReady: ((MapViewController) -> Void)?

    func makeUIViewController(context: Context) -> MapViewController {
        let controller = MapViewController()
        controller.delegate = context.coordinator
        context.coordinator.mapController = controller

        // Notify parent when controller is ready (dispatch to avoid state update during view creation)
        DispatchQueue.main.async {
            self.onMapControllerReady?(controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {
        uiViewController.showUserLocation(showUserLocation)
        uiViewController.setRasterVisibility(rasterVisible)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MapViewControllerDelegate {
        var parent: MapViewWrapper
        var mapController: MapViewController?

        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }

        func mapViewController(_ controller: MapViewController, didTapAirport airport: AirportAnnotation) {
            parent.selectedAirport = airport
        }

        func mapViewController(_ controller: MapViewController, didUpdateDownloadProgress progress: Double, stage: String) {
            parent.downloadProgress = progress
            parent.downloadStage = stage
        }

        func mapViewControllerDidCompleteDownload(_ controller: MapViewController, region: TileRegion) {
            parent.isDownloading = false
            parent.downloadComplete = true
            parent.downloadProgress = 1.0
            parent.downloadStage = "Complete!"
        }

        func mapViewController(_ controller: MapViewController, didFailDownloadWithError error: Error) {
            parent.isDownloading = false
            parent.downloadError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewWrapper(
        selectedAirport: .constant(nil),
        downloadProgress: .constant(0),
        downloadStage: .constant(""),
        isDownloading: .constant(false),
        downloadComplete: .constant(false),
        downloadError: .constant(nil),
        showUserLocation: true,
        rasterVisible: true
    )
}
