//
//  FlightRowView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import SwiftUI
import CoreLocation

struct FlightRowView: View {
    let aircraft: Aircraft

    private var statusColor: Color {
        Color(hex: aircraft.status.color) ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Flight info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(aircraft.flightNumber)
                        .font(.headline)
                    Text(aircraft.aircraftType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Route: Origin → Destination
                if let origin = aircraft.origin, let destination = aircraft.destination {
                    HStack(spacing: 4) {
                        Text(origin)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(destination)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } else {
                    Text(aircraft.airline)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Gate and time
            VStack(alignment: .trailing, spacing: 4) {
                if let gate = aircraft.gate {
                    Text("Gate \(gate)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if let eta = aircraft.eta {
                    Text("ETA \(eta.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let etd = aircraft.etd {
                    Text("ETD \(etd.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status badge
            Text(aircraft.status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    List {
        FlightRowView(
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
                eta: Date().addingTimeInterval(300)
            )
        )

        FlightRowView(
            aircraft: Aircraft(
                id: "N67890",
                flightNumber: "AA456",
                aircraftType: "A320",
                airline: "American Airlines",
                coordinate: .init(latitude: 37.6213, longitude: -122.3789),
                heading: 0,
                speed: 0,
                altitude: 0,
                status: .delayed,
                gate: "B5",
                etd: Date().addingTimeInterval(3600)
            )
        )
    }
}
