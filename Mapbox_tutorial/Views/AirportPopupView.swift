//
//  AirportPopupView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI
import CoreLocation

struct AirportPopupView: View {
    let airport: AirportAnnotation
    let onDismiss: () -> Void
    let onDownloadRegion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss button
            HStack {
                // Airport Code Badge
                Text(airport.code)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Airport Name
            Text(airport.name)
                .font(.headline)
                .lineLimit(2)

            // City
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                Text(airport.city)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Coordinates
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.green)
                Text(String(format: "%.4f, %.4f", airport.coordinate.latitude, airport.coordinate.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onDownloadRegion) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download Area")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        AirportPopupView(
            airport: AirportAnnotation(
                id: "sfo",
                name: "San Francisco International Airport",
                code: "SFO",
                city: "San Francisco, CA",
                coordinate: .init(latitude: 37.6213, longitude: -122.3789)
            ),
            onDismiss: {},
            onDownloadRegion: {}
        )
    }
}
