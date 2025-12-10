//
//  AircraftPopupView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import SwiftUI
import CoreLocation

struct AircraftPopupView: View {
    let aircraft: Aircraft
    let onDismiss: () -> Void
    let onViewDetails: (() -> Void)?

    init(aircraft: Aircraft, onDismiss: @escaping () -> Void, onViewDetails: (() -> Void)? = nil) {
        self.aircraft = aircraft
        self.onDismiss = onDismiss
        self.onViewDetails = onViewDetails
    }

    private var statusColor: Color {
        Color(hex: aircraft.status.color) ?? .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Flight number badge
                Text(aircraft.flightNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor)
                    .cornerRadius(8)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Airline and aircraft type
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text("\(aircraft.airline) | \(aircraft.aircraftType)")
                    .font(.subheadline)
            }

            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(aircraft.status.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Gate info (if applicable)
            if let gate = aircraft.gate {
                HStack {
                    Image(systemName: "door.left.hand.open")
                        .foregroundColor(.green)
                    Text("Gate \(gate)")
                        .font(.subheadline)
                }
            }

            // Route: Origin → Destination
            if let origin = aircraft.origin, let destination = aircraft.destination {
                HStack(spacing: 8) {
                    // Origin
                    Text(origin)
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Arrow with plane
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(.blue)

                    // Destination
                    Text(destination)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            }

            // ETA/ETD
            if let eta = aircraft.eta {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("ETA: \(eta.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                }
            }

            if let etd = aircraft.etd {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                    Text("ETD: \(etd.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                }
            }

            // Speed and altitude for approaching/taxiing
            if aircraft.speed > 0 {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.purple)
                    Text("\(Int(aircraft.speed)) kts")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if aircraft.altitude > 0 {
                        Spacer().frame(width: 16)
                        Image(systemName: "arrow.up")
                            .foregroundColor(.purple)
                        Text("\(Int(aircraft.altitude)) ft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Action buttons
            if let onViewDetails = onViewDetails {
                Button(action: onViewDetails) {
                    Text("View Full Details")
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

        AircraftPopupView(
            aircraft: Aircraft(
                id: "N12345",
                flightNumber: "UA123",
                aircraftType: "B737-800",
                airline: "United Airlines",
                coordinate: .init(latitude: 37.6213, longitude: -122.3789),
                heading: 45,
                speed: 15,
                altitude: 0,
                status: .taxiingIn,
                gate: "A12",
                eta: Date().addingTimeInterval(300),
                origin: "LAX"
            ),
            onDismiss: {},
            onViewDetails: {}
        )
    }
}
