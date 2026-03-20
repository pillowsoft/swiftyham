// RepeaterDirectory.swift
// HamStationKit — Repeater database with search and filtering.

import Foundation

/// Manages a repeater database with location-based and filtered search.
public actor RepeaterDirectory {

    private var repeaters: [RepeaterEntry] = []

    public init() {}

    // MARK: - Data Loading

    /// Load repeaters from JSON data (e.g. cached RepeaterBook export).
    public func loadFromRepeaterBook(data: Data) throws {
        let decoded = try JSONDecoder().decode([RepeaterEntry].self, from: data)
        repeaters = decoded
    }

    /// Add repeaters directly.
    public func addRepeaters(_ entries: [RepeaterEntry]) {
        repeaters.append(contentsOf: entries)
    }

    /// Fetch nearby repeaters from RepeaterBook API.
    /// API: https://www.repeaterbook.com/api/export.php?lat={lat}&lng={lng}&distance={dist}&unit=km
    public func updateFromRepeaterBook(
        latitude: Double,
        longitude: Double,
        distance: Int = 50
    ) async throws {
        var components = URLComponents(string: "https://www.repeaterbook.com/api/export.php")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "distance", value: String(distance)),
            URLQueryItem(name: "unit", value: "km"),
        ]
        guard let url = components.url else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        if let decoded = try? JSONDecoder().decode([RepeaterEntry].self, from: data) {
            repeaters = decoded
        }
    }

    // MARK: - Search

    /// Search repeaters with optional filters.
    public func search(
        near location: (latitude: Double, longitude: Double)? = nil,
        radiusKm: Double = 50,
        band: String? = nil,
        mode: RepeaterEntry.RepeaterMode? = nil,
        toneRequired: Bool = false
    ) -> [RepeaterEntry] {
        var results = repeaters

        // Filter by band
        if let band {
            let range = bandFrequencyRange(band)
            if let range {
                results = results.filter { range.contains($0.frequency) }
            }
        }

        // Filter by mode
        if let mode {
            results = results.filter { $0.mode == mode }
        }

        // Filter by tone requirement
        if toneRequired {
            results = results.filter { $0.tone != nil || $0.dcsCode != nil }
        }

        // Filter by distance
        if let location {
            results = results.filter { repeater in
                haversineDistance(
                    lat1: location.latitude, lon1: location.longitude,
                    lat2: repeater.latitude, lon2: repeater.longitude
                ) <= radiusKm
            }
            // Sort by distance
            results.sort { a, b in
                let distA = haversineDistance(
                    lat1: location.latitude, lon1: location.longitude,
                    lat2: a.latitude, lon2: a.longitude
                )
                let distB = haversineDistance(
                    lat1: location.latitude, lon1: location.longitude,
                    lat2: b.latitude, lon2: b.longitude
                )
                return distA < distB
            }
        }

        return results
    }

    /// All repeaters in the directory.
    public func allRepeaters() -> [RepeaterEntry] {
        repeaters
    }

    /// Number of repeaters in the directory.
    public var count: Int {
        repeaters.count
    }

    // MARK: - Helpers

    /// Map band names to frequency ranges in MHz.
    private func bandFrequencyRange(_ band: String) -> ClosedRange<Double>? {
        switch band.lowercased() {
        case "10m":  return 28.0...29.7
        case "6m":   return 50.0...54.0
        case "2m":   return 144.0...148.0
        case "1.25m", "220":  return 222.0...225.0
        case "70cm": return 420.0...450.0
        case "33cm": return 902.0...928.0
        case "23cm": return 1240.0...1300.0
        default:     return nil
        }
    }

    private func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }
}
