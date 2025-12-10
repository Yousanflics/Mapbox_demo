//
//  MapControlsView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI

struct MapControlsView: View {
    @Binding var showUserLocation: Bool
    @Binding var rasterVisible: Bool
    @Binding var selectedRoute: String?

    var onDownloadCurrentView: () -> Void
    var onShowOfflineRegions: () -> Void
    var onFocusRoute: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top Controls
            HStack {
                Spacer()

                VStack(spacing: 8) {
                    // Location Toggle
                    ControlButton(
                        icon: showUserLocation ? "location.fill" : "location",
                        color: showUserLocation ? .blue : .secondary
                    ) {
                        showUserLocation.toggle()
                    }

                    // Raster Toggle
                    ControlButton(
                        icon: rasterVisible ? "square.3.layers.3d.top.filled" : "square.3.layers.3d",
                        color: rasterVisible ? .green : .secondary
                    ) {
                        rasterVisible.toggle()
                    }

                    // Offline Regions
                    ControlButton(
                        icon: "arrow.down.circle",
                        color: .orange
                    ) {
                        onShowOfflineRegions()
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 60)

            Spacer()

            // Bottom Controls
            VStack(spacing: 12) {
                // Route Selector
                RouteSelector(
                    selectedRoute: $selectedRoute,
                    onSelect: onFocusRoute
                )

                // Download Button
                Button(action: onDownloadCurrentView) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Download Current View")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Route Selector

struct RouteSelector: View {
    @Binding var selectedRoute: String?
    var onSelect: (String) -> Void

    private let routes = [
        ("sfo-msn", "SFO → MSN", Color.blue),
        ("sfo-ord", "SFO → ORD", Color.orange)
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(routes, id: \.0) { route in
                RouteChip(
                    label: route.1,
                    color: route.2,
                    isSelected: selectedRoute == route.0
                ) {
                    selectedRoute = route.0
                    onSelect(route.0)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Route Chip

struct RouteChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.15) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        MapControlsView(
            showUserLocation: .constant(true),
            rasterVisible: .constant(true),
            selectedRoute: .constant("sfo-msn"),
            onDownloadCurrentView: {},
            onShowOfflineRegions: {},
            onFocusRoute: { _ in }
        )
    }
}
