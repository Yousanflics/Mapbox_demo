//
//  FlightListSheet.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import SwiftUI
import CoreLocation

struct FlightListSheet: View {
    let aircrafts: [Aircraft]
    let onSelectAircraft: (Aircraft) -> Void

    @State private var searchText = ""
    @State private var selectedFilter: FlightFilter = .all

    enum FlightFilter: String, CaseIterable {
        case all = "All"
        case arriving = "Arriving"
        case departing = "Departing"
        case delayed = "Delayed"
    }

    private var filteredAircrafts: [Aircraft] {
        var result = aircrafts

        // Apply status filter
        switch selectedFilter {
        case .arriving:
            result = result.filter { $0.status == .approaching || $0.status == .taxiingIn }
        case .departing:
            result = result.filter { $0.status == .boarding || $0.status == .taxiingOut }
        case .delayed:
            result = result.filter { $0.status == .delayed }
        case .all:
            break
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.flightNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.airline.localizedCaseInsensitiveContains(searchText) ||
                ($0.gate ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by priority (higher priority first)
        return result.sorted { $0.status.priority > $1.status.priority }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.top, 8)

            // Filter tabs
            filterTabs
                .padding(.vertical, 12)

            // Search bar
            searchBar
                .padding(.horizontal)

            // Flight count
            HStack {
                Text("\(filteredAircrafts.count) flights")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Flight list
            List(filteredAircrafts) { aircraft in
                FlightRowView(aircraft: aircraft)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectAircraft(aircraft)
                    }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemBackground))
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)

            // Title
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text("Flight List")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FlightFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        count: countForFilter(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search flights, gates...", text: $searchText)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func countForFilter(_ filter: FlightFilter) -> Int {
        switch filter {
        case .all: return aircrafts.count
        case .arriving: return aircrafts.filter { $0.status == .approaching || $0.status == .taxiingIn }.count
        case .departing: return aircrafts.filter { $0.status == .boarding || $0.status == .taxiingOut }.count
        case .delayed: return aircrafts.filter { $0.status == .delayed }.count
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))")
                    .font(.caption)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    FlightListSheet(
        aircrafts: [
            Aircraft(
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
            ),
            Aircraft(
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
            ),
            Aircraft(
                id: "N11111",
                flightNumber: "DL789",
                aircraftType: "B777-200",
                airline: "Delta Air Lines",
                coordinate: .init(latitude: 37.6213, longitude: -122.3789),
                heading: 180,
                speed: 0,
                altitude: 0,
                status: .boarding,
                gate: "G3",
                etd: Date().addingTimeInterval(900)
            )
        ],
        onSelectAircraft: { _ in }
    )
}
