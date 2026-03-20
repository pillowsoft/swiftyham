// SatelliteTracker.swift
// HamStationKit — Manages TLE database and provides satellite pass predictions.

import Foundation
import os

// MARK: - SatelliteTracker

/// Manages satellite TLE data and provides pass predictions for amateur radio satellites.
///
/// Maintains a local TLE database, supports fetching updates from Celestrak,
/// and emits pass predictions as an `AsyncStream`.
public actor SatelliteTracker {

    // MARK: - Properties

    /// All loaded satellites.
    private(set) var satellites: [TLE] = []

    /// Observer location: latitude (degrees), longitude (degrees), altitude (km).
    public let observerLocation: (latitude: Double, longitude: Double, altitude: Double)

    private let logger = Logger(subsystem: "com.hamstation.kit", category: "SatelliteTracker")

    private var passContinuation: AsyncStream<SGP4.SatellitePass>.Continuation?

    /// Stream of upcoming satellite passes, emitted as they are computed.
    public let passStream: AsyncStream<SGP4.SatellitePass>

    // MARK: - Curated Satellite List

    /// Well-known amateur radio satellite names for filtering.
    public static let amateurSatellites: [String] = [
        "AO-91", "AO-92", "SO-50", "AO-7", "ISS", "TEVEL", "CAS-4A", "CAS-4B",
        "XW-2A", "XW-2B", "XW-2C", "RS-44", "FO-29", "FO-99"
    ]

    /// Celestrak URL for amateur radio satellite TLEs.
    public static let celestrakAmateurURL = URL(
        string: "https://celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=tle"
    )!

    // MARK: - Initialization

    /// Create a new satellite tracker for the given observer location.
    ///
    /// - Parameter observerLocation: Tuple of (latitude degrees, longitude degrees, altitude km).
    public init(observerLocation: (latitude: Double, longitude: Double, altitude: Double)) {
        self.observerLocation = observerLocation

        var cont: AsyncStream<SGP4.SatellitePass>.Continuation!
        self.passStream = AsyncStream<SGP4.SatellitePass> { continuation in
            cont = continuation
        }
        self.passContinuation = cont
    }

    deinit {
        passContinuation?.finish()
    }

    // MARK: - TLE Loading

    /// Load TLEs from a file URL.
    ///
    /// - Parameter url: Local file URL containing Celestrak 3-line TLE data.
    public func loadTLEs(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SatelliteTrackerError.invalidData("Unable to decode TLE file as UTF-8")
        }
        loadTLEs(from: text)
    }

    /// Parse and store TLEs from a text string.
    ///
    /// - Parameter text: Multi-satellite TLE text in Celestrak 3-line format.
    public func loadTLEs(from text: String) {
        let parsed = TLEParser.parse(text: text)
        logger.info("Parsed \(parsed.count) TLEs")
        satellites = parsed
    }

    /// Fetch and load the latest amateur radio TLEs from Celestrak.
    public func updateFromCelestrak() async throws {
        let (data, response) = try await URLSession.shared.data(from: Self.celestrakAmateurURL)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SatelliteTrackerError.networkError("Celestrak returned HTTP \(httpResponse.statusCode)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw SatelliteTrackerError.invalidData("Unable to decode Celestrak response as UTF-8")
        }

        loadTLEs(from: text)
        logger.info("Updated TLEs from Celestrak: \(self.satellites.count) satellites")
    }

    // MARK: - Pass Prediction

    /// Predict the next passes for all loaded satellites.
    ///
    /// - Parameters:
    ///   - count: Maximum number of passes to return.
    ///   - minElevation: Minimum peak elevation in degrees.
    /// - Returns: Passes sorted by AOS time.
    public func nextPasses(count: Int = 10, minElevation: Double = 5) -> [SGP4.SatellitePass] {
        var allPasses: [SGP4.SatellitePass] = []

        for tle in satellites {
            let passes = SGP4.predictPasses(
                tle: tle,
                observer: observerLocation,
                startDate: Date(),
                days: 7,
                minElevation: minElevation
            )
            allPasses.append(contentsOf: passes)
        }

        // Sort by AOS and take the requested count
        allPasses.sort { $0.aos < $1.aos }
        return Array(allPasses.prefix(count))
    }

    /// Get the current position of a satellite by name.
    ///
    /// - Parameter satelliteName: The satellite name to look up.
    /// - Returns: Current position, or nil if not found or computation fails.
    public func currentPosition(satelliteName: String) -> SGP4.SatellitePosition? {
        guard let tle = satellites.first(where: {
            $0.name.localizedCaseInsensitiveContains(satelliteName)
        }) else {
            return nil
        }
        return SGP4.propagate(tle: tle, date: Date())
    }

    /// Get the Doppler-corrected frequency for a satellite at a specific time.
    ///
    /// - Parameters:
    ///   - nominal: The nominal frequency in Hz.
    ///   - satellite: Satellite name.
    ///   - date: Time for the calculation.
    /// - Returns: Corrected frequency in Hz, or nil if satellite not found.
    public func dopplerCorrectedFrequency(nominal: Double, satellite: String, at date: Date) -> Double? {
        guard let tle = satellites.first(where: {
            $0.name.localizedCaseInsensitiveContains(satellite)
        }) else {
            return nil
        }

        // Compute range rate by finite difference
        let dt: TimeInterval = 1.0  // 1 second
        guard let pos1 = SGP4.propagate(tle: tle, date: date),
              let pos2 = SGP4.propagate(tle: tle, date: date.addingTimeInterval(dt)) else {
            return nil
        }

        let angles1 = SGP4.lookAngles(satellitePosition: pos1, observer: observerLocation)
        let angles2 = SGP4.lookAngles(satellitePosition: pos2, observer: observerLocation)

        // Range rate in km/s
        let rangeRate = (angles2.range - angles1.range) / dt

        return SGP4.dopplerShift(nominalFrequencyHz: nominal, rangeRateKmPerSec: rangeRate)
    }

    /// Start computing and emitting passes on the pass stream.
    public func startPassPrediction() {
        let passes = nextPasses(count: 20, minElevation: 5)
        for pass in passes {
            passContinuation?.yield(pass)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during satellite tracking operations.
public enum SatelliteTrackerError: Error, Sendable {
    case invalidData(String)
    case networkError(String)
    case satelliteNotFound(String)
}
