//
//  OfflineRegionsView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Offline Region Model

struct OfflineRegionItem: Identifiable {
    let id: String
    let name: String
    let createdDate: Date?
    let completedSize: UInt64
    let requiredCount: UInt64
    let completedCount: UInt64
    let bounds: CoordinateBounds?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(completedSize), countStyle: .file)
    }

    var isComplete: Bool {
        completedCount >= requiredCount
    }

    var progressPercent: Double {
        guard requiredCount > 0 else { return 1.0 }
        return Double(completedCount) / Double(requiredCount)
    }

    init(from region: TileRegion, metadata: [String: Any]? = nil) {
        self.id = region.id
        self.completedSize = region.completedResourceSize
        self.requiredCount = region.requiredResourceCount
        self.completedCount = region.completedResourceCount

        // Parse metadata if available
        if let meta = metadata {
            self.name = meta["name"] as? String ?? region.id

            if let created = meta["created"] as? String {
                let formatter = ISO8601DateFormatter()
                self.createdDate = formatter.date(from: created)
            } else {
                self.createdDate = Date()
            }

            // Parse bounds from metadata
            if let swLat = meta["swLat"] as? Double,
               let swLng = meta["swLng"] as? Double,
               let neLat = meta["neLat"] as? Double,
               let neLng = meta["neLng"] as? Double {
                self.bounds = CoordinateBounds(
                    southwest: CLLocationCoordinate2D(latitude: swLat, longitude: swLng),
                    northeast: CLLocationCoordinate2D(latitude: neLat, longitude: neLng)
                )
            } else {
                self.bounds = nil
            }
        } else {
            self.name = region.id
            self.createdDate = Date()
            self.bounds = nil
        }
    }
}

// MARK: - Offline Regions View

struct OfflineRegionsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var regions: [OfflineRegionItem] = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var regionToDelete: OfflineRegionItem?

    var mapController: MapViewController?
    var onRegionSelected: ((OfflineRegionItem) -> Void)?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading regions...")
                } else if regions.isEmpty {
                    emptyStateView
                } else {
                    regionListView
                }
            }
            .navigationTitle("Offline Regions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadRegions) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            loadRegions()
        }
        .alert("Delete Region?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let region = regionToDelete {
                    deleteRegion(region)
                }
            }
        } message: {
            Text("This will remove the offline data for \"\(regionToDelete?.name ?? "")\".")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Offline Regions")
                .font(.headline)

            Text("Download a region to access maps offline.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var regionListView: some View {
        List {
            ForEach(regions) { region in
                OfflineRegionRow(region: region)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onRegionSelected?(region)
                        dismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            regionToDelete = region
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func loadRegions() {
        isLoading = true

        let tileStore = TileStore.default
        tileStore.allTileRegions { result in
            switch result {
            case .success(let tileRegions):
                // Fetch metadata for each region
                let group = DispatchGroup()
                var items: [OfflineRegionItem] = []
                let lock = NSLock()

                for region in tileRegions {
                    group.enter()
                    tileStore.tileRegionMetadata(forId: region.id) { metaResult in
                        var metadata: [String: Any]? = nil
                        if case .success(let value) = metaResult {
                            print("Raw metadata for \(region.id): \(value)")
                            metadata = value as? [String: Any]
                        }
                        let item = OfflineRegionItem(from: region, metadata: metadata)
                        lock.lock()
                        items.append(item)
                        lock.unlock()
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.regions = items.sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
                    self.isLoading = false
                }

            case .failure:
                DispatchQueue.main.async {
                    self.regions = []
                    self.isLoading = false
                }
            }
        }
    }

    private func deleteRegion(_ region: OfflineRegionItem) {
        if let controller = mapController {
            controller.deleteOfflineRegion(id: region.id) { success in
                if success {
                    self.regions.removeAll { $0.id == region.id }
                }
            }
        } else {
            let tileStore = TileStore.default
            tileStore.removeTileRegion(forId: region.id)
            DispatchQueue.main.async {
                self.regions.removeAll { $0.id == region.id }
            }
        }
    }
}

// MARK: - Region Row

struct OfflineRegionRow: View {
    let region: OfflineRegionItem

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(region.name)
                    .font(.headline)

                Spacer()

                if region.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(region.progressPercent * 100))%")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Label(region.sizeFormatted, systemImage: "externaldrive.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let date = region.createdDate {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !region.isComplete {
                ProgressView(value: region.progressPercent, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    OfflineRegionsView()
}
