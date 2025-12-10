//
//  AircraftSimulator.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/10/25.
//

import Foundation
import CoreLocation
import Combine

final class AircraftSimulator: ObservableObject {

    @Published private(set) var aircrafts: [Aircraft] = []

    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0  // 1 second updates

    // SFO airport center and runway threshold coordinates
    private let sfoCenter = CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.3790)

    // SFO Runway endpoints
    private let runway28L_threshold = CLLocationCoordinate2D(latitude: 37.6135, longitude: -122.3575)
    private let runway28L_end = CLLocationCoordinate2D(latitude: 37.6280, longitude: -122.3930)
    private let runway28R_threshold = CLLocationCoordinate2D(latitude: 37.6070, longitude: -122.3545)
    private let runway28R_end = CLLocationCoordinate2D(latitude: 37.6215, longitude: -122.3900)

    // Terminal gate areas
    private let terminalACenter = CLLocationCoordinate2D(latitude: 37.6155, longitude: -122.3815)
    private let terminalBCenter = CLLocationCoordinate2D(latitude: 37.6175, longitude: -122.3830)
    private let terminalCCenter = CLLocationCoordinate2D(latitude: 37.6145, longitude: -122.3870)
    private let terminalGCenter = CLLocationCoordinate2D(latitude: 37.6130, longitude: -122.3900)

    // Origin airports with coordinates (major US airports)
    private let originAirports: [(code: String, name: String, coordinate: CLLocationCoordinate2D)] = [
        ("LAX", "Los Angeles", CLLocationCoordinate2D(latitude: 33.9425, longitude: -118.4081)),
        ("JFK", "New York JFK", CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781)),
        ("ORD", "Chicago O'Hare", CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9073)),
        ("DFW", "Dallas Fort Worth", CLLocationCoordinate2D(latitude: 32.8998, longitude: -97.0403)),
        ("DEN", "Denver", CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737)),
        ("SEA", "Seattle", CLLocationCoordinate2D(latitude: 47.4502, longitude: -122.3088)),
        ("PHX", "Phoenix", CLLocationCoordinate2D(latitude: 33.4373, longitude: -112.0078)),
        ("BOS", "Boston", CLLocationCoordinate2D(latitude: 42.3656, longitude: -71.0096)),
        ("ATL", "Atlanta", CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277)),
        ("MIA", "Miami", CLLocationCoordinate2D(latitude: 25.7959, longitude: -80.2870)),
        ("HNL", "Honolulu", CLLocationCoordinate2D(latitude: 21.3187, longitude: -157.9225)),
        ("NRT", "Tokyo Narita", CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929)),
        ("LHR", "London Heathrow", CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543)),
        ("PVG", "Shanghai Pudong", CLLocationCoordinate2D(latitude: 31.1443, longitude: 121.8083)),
        ("SYD", "Sydney", CLLocationCoordinate2D(latitude: -33.9399, longitude: 151.1753))
    ]

    private let airlines = [
        ("UA", "United Airlines"),
        ("AA", "American Airlines"),
        ("DL", "Delta Air Lines"),
        ("WN", "Southwest Airlines"),
        ("AS", "Alaska Airlines"),
        ("B6", "JetBlue Airways"),
        ("NK", "Spirit Airlines"),
        ("F9", "Frontier Airlines")
    ]

    private let aircraftTypes = [
        "B737-800", "B737-900", "A320", "A321",
        "B777-200", "B787-9", "A350-900", "E175"
    ]

    // MARK: - Public Methods

    func startSimulation(aircraftCount: Int = 500) {
        generateInitialAircrafts(count: aircraftCount)
        startUpdateTimer()
    }

    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Route Generation

    /// Create approach route from origin to SFO runway
    private func createApproachRoute(from origin: CLLocationCoordinate2D, originCode: String) -> FlightRoute {
        // Determine approach direction based on origin location
        let approachFromNorth = origin.latitude > sfoCenter.latitude
        let approachFromEast = origin.longitude > sfoCenter.longitude

        // Create waypoints for a realistic approach
        var waypoints: [CLLocationCoordinate2D] = []

        // Start far from airport (simulated final approach segment)
        let distanceFactor = 0.08 // About 5-6 miles out

        // Entry point - coming from the general direction of origin
        let entryPoint: CLLocationCoordinate2D
        if approachFromNorth && !approachFromEast {
            // North approach - coming from Seattle, etc.
            entryPoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude + distanceFactor,
                longitude: sfoCenter.longitude - distanceFactor * 0.5
            )
        } else if approachFromEast {
            // East approach - coming from Denver, Chicago, NYC, etc.
            entryPoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude + distanceFactor * 0.3,
                longitude: sfoCenter.longitude + distanceFactor
            )
        } else {
            // South approach - coming from LA, Phoenix, etc.
            entryPoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude - distanceFactor,
                longitude: sfoCenter.longitude - distanceFactor * 0.3
            )
        }

        waypoints.append(entryPoint)

        // Intermediate waypoint for curved approach
        let midPoint = CLLocationCoordinate2D(
            latitude: (entryPoint.latitude + runway28L_threshold.latitude) / 2 + Double.random(in: -0.01...0.01),
            longitude: (entryPoint.longitude + runway28L_threshold.longitude) / 2 + Double.random(in: -0.01...0.01)
        )
        waypoints.append(midPoint)

        // Final approach point - lined up with runway
        let finalApproach = CLLocationCoordinate2D(
            latitude: runway28L_threshold.latitude - 0.015,
            longitude: runway28L_threshold.longitude + 0.02
        )
        waypoints.append(finalApproach)

        // Runway threshold
        waypoints.append(runway28L_threshold)

        // Touchdown point
        let touchdown = CLLocationCoordinate2D(
            latitude: (runway28L_threshold.latitude + runway28L_end.latitude) / 2,
            longitude: (runway28L_threshold.longitude + runway28L_end.longitude) / 2
        )
        waypoints.append(touchdown)

        // Create route starting at random progress (simulating aircraft at different stages)
        let progress = Double.random(in: 0.0...0.7)

        return FlightRoute(
            originCode: originCode,
            originCoordinate: origin,
            destinationCode: "SFO",
            destinationCoordinate: sfoCenter,
            waypoints: waypoints,
            progress: progress
        )
    }

    /// Create taxiway route from runway to gate
    private func createTaxiInRoute(to gate: String) -> FlightRoute {
        var waypoints: [CLLocationCoordinate2D] = []

        // Start at runway exit
        let runwayExit = CLLocationCoordinate2D(
            latitude: 37.6200,
            longitude: -122.3850
        )
        waypoints.append(runwayExit)

        // Main taxiway intersection
        let taxiwayJunction = CLLocationCoordinate2D(
            latitude: 37.6185,
            longitude: -122.3835
        )
        waypoints.append(taxiwayJunction)

        // Terminal-specific approach
        let terminal = gate.prefix(1)
        let gateCoord: CLLocationCoordinate2D
        switch terminal {
        case "A":
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6165, longitude: -122.3825))
            gateCoord = randomGatePosition(near: terminalACenter)
        case "B":
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6175, longitude: -122.3840))
            gateCoord = randomGatePosition(near: terminalBCenter)
        case "C":
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6155, longitude: -122.3860))
            gateCoord = randomGatePosition(near: terminalCCenter)
        default: // G
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6140, longitude: -122.3880))
            gateCoord = randomGatePosition(near: terminalGCenter)
        }

        waypoints.append(gateCoord)

        let progress = Double.random(in: 0.0...0.8)

        return FlightRoute(
            originCode: "RWY",
            originCoordinate: runwayExit,
            destinationCode: gate,
            destinationCoordinate: gateCoord,
            waypoints: waypoints,
            progress: progress
        )
    }

    /// Create taxiway route from gate to runway for departure
    private func createTaxiOutRoute(from gate: String, to destination: String) -> FlightRoute {
        var waypoints: [CLLocationCoordinate2D] = []

        // Start at gate
        let terminal = gate.prefix(1)
        let gateCoord: CLLocationCoordinate2D
        switch terminal {
        case "A":
            gateCoord = randomGatePosition(near: terminalACenter)
            waypoints.append(gateCoord)
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6165, longitude: -122.3825))
        case "B":
            gateCoord = randomGatePosition(near: terminalBCenter)
            waypoints.append(gateCoord)
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6175, longitude: -122.3840))
        case "C":
            gateCoord = randomGatePosition(near: terminalCCenter)
            waypoints.append(gateCoord)
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6155, longitude: -122.3860))
        default: // G
            gateCoord = randomGatePosition(near: terminalGCenter)
            waypoints.append(gateCoord)
            waypoints.append(CLLocationCoordinate2D(latitude: 37.6140, longitude: -122.3880))
        }

        // Main taxiway
        waypoints.append(CLLocationCoordinate2D(latitude: 37.6170, longitude: -122.3820))

        // Runway hold short
        waypoints.append(CLLocationCoordinate2D(latitude: 37.6110, longitude: -122.3700))

        // Runway entry
        waypoints.append(runway28R_threshold)

        let progress = Double.random(in: 0.0...0.7)

        let destAirport = originAirports.first { $0.code == destination } ?? originAirports[0]

        return FlightRoute(
            originCode: gate,
            originCoordinate: gateCoord,
            destinationCode: destination,
            destinationCoordinate: destAirport.coordinate,
            waypoints: waypoints,
            progress: progress
        )
    }

    /// Create departure route from runway to departure path
    private func createDepartureRoute(to destination: CLLocationCoordinate2D, destinationCode: String) -> FlightRoute {
        var waypoints: [CLLocationCoordinate2D] = []

        // Start on runway
        waypoints.append(runway28R_threshold)

        // Liftoff point
        let liftoff = CLLocationCoordinate2D(
            latitude: (runway28R_threshold.latitude + runway28R_end.latitude) * 0.6 + runway28R_end.latitude * 0.4,
            longitude: (runway28R_threshold.longitude + runway28R_end.longitude) * 0.6 + runway28R_end.longitude * 0.4
        )
        waypoints.append(liftoff)

        // Initial climb - straight out
        let initialClimb = CLLocationCoordinate2D(
            latitude: runway28R_end.latitude + 0.015,
            longitude: runway28R_end.longitude - 0.02
        )
        waypoints.append(initialClimb)

        // Turn towards destination
        let departureFromNorth = destination.latitude > sfoCenter.latitude
        let departureToEast = destination.longitude > sfoCenter.longitude

        let departurePoint: CLLocationCoordinate2D
        if departureFromNorth {
            departurePoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude + 0.08,
                longitude: sfoCenter.longitude - 0.03
            )
        } else if departureToEast {
            departurePoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude + 0.03,
                longitude: sfoCenter.longitude + 0.08
            )
        } else {
            departurePoint = CLLocationCoordinate2D(
                latitude: sfoCenter.latitude - 0.05,
                longitude: sfoCenter.longitude - 0.06
            )
        }
        waypoints.append(departurePoint)

        let progress = Double.random(in: 0.0...0.5)

        return FlightRoute(
            originCode: "SFO",
            originCoordinate: sfoCenter,
            destinationCode: destinationCode,
            destinationCoordinate: destination,
            waypoints: waypoints,
            progress: progress
        )
    }

    private func randomGatePosition(near center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: center.latitude + Double.random(in: -0.001...0.001),
            longitude: center.longitude + Double.random(in: -0.001...0.001)
        )
    }

    // MARK: - Aircraft Generation

    private func generateInitialAircrafts(count: Int) {
        var newAircrafts: [Aircraft] = []

        // Distribution of statuses
        let statusDistribution: [(FlightStatus, Int)] = [
            (.approaching, 15),
            (.taxiingIn, 10),
            (.parked, 40),
            (.boarding, 15),
            (.taxiingOut, 10),
            (.delayed, 8),
            (.cancelled, 2)
        ]

        var statusPool: [FlightStatus] = []
        for (status, percentage) in statusDistribution {
            let statusCount = count * percentage / 100
            statusPool.append(contentsOf: Array(repeating: status, count: statusCount))
        }
        statusPool.shuffle()

        while statusPool.count < count {
            statusPool.append(.parked)
        }

        for i in 0..<count {
            let airline = airlines.randomElement()!
            let flightNumber = "\(airline.0)\(Int.random(in: 100...9999))"
            let status = statusPool[i]
            let originAirport = originAirports.randomElement()!
            let destinationAirport = originAirports.filter { $0.code != originAirport.code }.randomElement()!

            let gate = gateForStatus(status)
            var route: FlightRoute?
            var coordinate: CLLocationCoordinate2D
            var heading: Double
            var speed: Double
            var altitude: Double

            switch status {
            case .approaching:
                route = createApproachRoute(from: originAirport.coordinate, originCode: originAirport.code)
                coordinate = route!.currentPosition()
                heading = route!.currentHeading()
                speed = Double.random(in: 140...180)
                altitude = Double.random(in: 2000...4000)

            case .taxiingIn:
                route = createTaxiInRoute(to: gate!)
                coordinate = route!.currentPosition()
                heading = route!.currentHeading()
                speed = Double.random(in: 10...25)
                altitude = 0

            case .taxiingOut:
                route = createTaxiOutRoute(from: gate!, to: destinationAirport.code)
                coordinate = route!.currentPosition()
                heading = route!.currentHeading()
                speed = Double.random(in: 10...25)
                altitude = 0

            case .departed:
                route = createDepartureRoute(to: destinationAirport.coordinate, destinationCode: destinationAirport.code)
                coordinate = route!.currentPosition()
                heading = route!.currentHeading()
                speed = Double.random(in: 160...200)
                altitude = Double.random(in: 1000...3000)

            case .parked, .boarding, .delayed, .cancelled:
                // Static at gate
                let terminal = gate?.prefix(1) ?? "A"
                let gateCenter: CLLocationCoordinate2D
                switch terminal {
                case "A": gateCenter = terminalACenter
                case "B": gateCenter = terminalBCenter
                case "C": gateCenter = terminalCCenter
                default: gateCenter = terminalGCenter
                }
                coordinate = randomGatePosition(near: gateCenter)
                heading = Double.random(in: 0...360)
                speed = 0
                altitude = 0
                route = nil
            }

            let isArrival = [.approaching, .taxiingIn, .parked].contains(status)

            let aircraft = Aircraft(
                id: "N\(10000 + i)",
                flightNumber: flightNumber,
                aircraftType: aircraftTypes.randomElement()!,
                airline: airline.1,
                coordinate: coordinate,
                heading: heading,
                speed: speed,
                altitude: altitude,
                status: status,
                gate: gate,
                eta: etaForStatus(status),
                etd: etdForStatus(status),
                origin: isArrival ? originAirport.code : "SFO",
                destination: isArrival ? "SFO" : destinationAirport.code,
                route: route
            )
            newAircrafts.append(aircraft)
        }

        aircrafts = newAircrafts
    }

    private func startUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updatePositions()
        }
    }

    private func updatePositions() {
        aircrafts = aircrafts.map { aircraft in
            var updated = aircraft

            // Only move aircraft that have routes and are in motion
            guard var route = aircraft.route else { return updated }

            let isMoving = [.approaching, .taxiingIn, .taxiingOut, .departed].contains(aircraft.status)
            guard isMoving else { return updated }

            // Calculate progress increment based on speed
            // Higher speed = faster progress
            let speedFactor: Double
            switch aircraft.status {
            case .approaching:
                speedFactor = 0.008 // Faster for approach
            case .taxiingIn, .taxiingOut:
                speedFactor = 0.015 // Moderate for taxi
            case .departed:
                speedFactor = 0.012 // Fast for departure
            default:
                speedFactor = 0
            }

            // Update progress
            route.progress = min(1.0, route.progress + speedFactor)

            // If reached end of route, handle status transition
            if route.progress >= 0.95 {
                switch aircraft.status {
                case .approaching:
                    // Transition to taxiing in
                    updated.status = .taxiingIn
                    if let gate = aircraft.gate {
                        let newRoute = createTaxiInRoute(to: gate)
                        updated.route = newRoute
                        updated.coordinate = newRoute.currentPosition()
                        updated.heading = newRoute.currentHeading()
                    }
                    updated.speed = Double.random(in: 10...25)
                    updated.altitude = 0
                case .taxiingIn:
                    // Arrived at gate - stay at final position
                    updated.status = .parked
                    updated.coordinate = route.waypoints.last ?? updated.coordinate
                    updated.route = nil
                    updated.speed = 0
                    updated.heading = Double.random(in: 0...360) // Parked heading
                case .taxiingOut:
                    // Taking off
                    updated.status = .departed
                    if let dest = aircraft.destination,
                       let destAirport = originAirports.first(where: { $0.code == dest }) {
                        let newRoute = createDepartureRoute(to: destAirport.coordinate, destinationCode: dest)
                        updated.route = newRoute
                        updated.coordinate = newRoute.currentPosition()
                        updated.heading = newRoute.currentHeading()
                    }
                    updated.speed = Double.random(in: 160...200)
                    updated.altitude = Double.random(in: 1000...3000)
                case .departed:
                    // Reset to approaching for continuous simulation
                    updated.status = .approaching
                    let origin = originAirports.randomElement()!
                    let newRoute = createApproachRoute(from: origin.coordinate, originCode: origin.code)
                    updated.route = newRoute
                    updated.coordinate = newRoute.currentPosition()
                    updated.heading = newRoute.currentHeading()
                    updated.origin = origin.code
                    updated.destination = "SFO"
                    updated.speed = Double.random(in: 140...180)
                    updated.altitude = Double.random(in: 2000...4000)
                default:
                    break
                }
            } else {
                // Update position and heading based on route
                updated.route = route
                updated.coordinate = route.currentPosition()
                updated.heading = route.currentHeading()
            }

            return updated
        }
    }

    // MARK: - Helper Methods

    private func gateForStatus(_ status: FlightStatus) -> String? {
        switch status {
        case .parked, .boarding, .delayed, .cancelled, .taxiingIn, .taxiingOut:
            let terminal = ["A", "B", "C", "G"].randomElement()!
            let number = Int.random(in: 1...20)
            return "\(terminal)\(number)"
        case .approaching:
            // Will be assigned a gate
            let terminal = ["A", "B", "C", "G"].randomElement()!
            let number = Int.random(in: 1...20)
            return "\(terminal)\(number)"
        default:
            return nil
        }
    }

    private func etaForStatus(_ status: FlightStatus) -> Date? {
        switch status {
        case .approaching:
            return Date().addingTimeInterval(Double.random(in: 300...1200))
        case .taxiingIn:
            return Date().addingTimeInterval(Double.random(in: 60...300))
        case .delayed:
            return Date().addingTimeInterval(Double.random(in: 1800...7200))
        default:
            return nil
        }
    }

    private func etdForStatus(_ status: FlightStatus) -> Date? {
        switch status {
        case .boarding:
            return Date().addingTimeInterval(Double.random(in: 600...1800))
        case .taxiingOut:
            return Date().addingTimeInterval(Double.random(in: 60...300))
        case .delayed:
            return Date().addingTimeInterval(Double.random(in: 1800...7200))
        default:
            return nil
        }
    }
}
