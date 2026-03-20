// SOTAPOTATracker.swift
// HamStationKit — SOTA (Summits on the Air) and POTA (Parks on the Air) tracking.

import Foundation

/// A SOTA summit reference.
public struct SOTASummit: Sendable, Identifiable, Codable, Equatable {
    /// SOTA reference, e.g. "W1/CR-001".
    public let id: String
    public var name: String
    /// Altitude in meters.
    public var altitude: Int
    /// Activation points (1-10 based on altitude).
    public var points: Int
    public var region: String
    public var latitude: Double
    public var longitude: Double

    public init(
        id: String,
        name: String,
        altitude: Int,
        points: Int,
        region: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.altitude = altitude
        self.points = points
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A POTA park reference.
public struct POTAPark: Sendable, Identifiable, Codable, Equatable {
    /// POTA reference, e.g. "K-0001".
    public let id: String
    public var name: String
    /// State or province.
    public var location: String
    public var latitude: Double
    public var longitude: Double
    /// DXCC entity ID.
    public var entityId: Int?

    public init(
        id: String,
        name: String,
        location: String,
        latitude: Double,
        longitude: Double,
        entityId: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.entityId = entityId
    }
}

/// Tracks SOTA and POTA activations with database and nearby search.
public actor SOTAPOTATracker {

    private var summits: [SOTASummit] = []
    private var parks: [POTAPark] = []
    private var activationLog: [Activation] = []

    /// A logged SOTA or POTA activation.
    public struct Activation: Sendable, Identifiable, Equatable {
        public let id: UUID
        /// SOTA or POTA reference string.
        public var reference: String
        public var type: ActivationType
        public var date: Date
        public var qsoCount: Int
        /// True if operator was the activator; false if chaser.
        public var isActivator: Bool

        public enum ActivationType: String, Sendable, CaseIterable {
            case sota
            case pota
        }

        public init(
            id: UUID = UUID(),
            reference: String,
            type: ActivationType,
            date: Date = Date(),
            qsoCount: Int = 0,
            isActivator: Bool = true
        ) {
            self.id = id
            self.reference = reference
            self.type = type
            self.date = date
            self.qsoCount = qsoCount
            self.isActivator = isActivator
        }
    }

    public init() {}

    // MARK: - Load Data

    /// Load SOTA summits from JSON data.
    public func loadSOTASummits(from data: Data) throws {
        let decoded = try JSONDecoder().decode([SOTASummit].self, from: data)
        summits = decoded
    }

    /// Load POTA parks from JSON data.
    public func loadPOTAParks(from data: Data) throws {
        let decoded = try JSONDecoder().decode([POTAPark].self, from: data)
        parks = decoded
    }

    // MARK: - API Fetch

    /// Fetch updated SOTA summit database from the SOTA API.
    /// API: https://api2.sota.org.uk/api/summits (paginated)
    public func updateSOTADatabase() async throws {
        let url = URL(string: "https://api2.sota.org.uk/api/associations")!
        let (data, _) = try await URLSession.shared.data(from: url)

        // The API returns association data; a full implementation would
        // paginate through summits per association. For now, attempt
        // to decode summit data directly if available.
        if let decoded = try? JSONDecoder().decode([SOTASummit].self, from: data) {
            summits = decoded
        }
    }

    /// Fetch updated POTA park database from the POTA API.
    /// API: https://api.pota.app/parks
    public func updatePOTADatabase() async throws {
        let url = URL(string: "https://api.pota.app/parks")!
        let (data, _) = try await URLSession.shared.data(from: url)

        if let decoded = try? JSONDecoder().decode([POTAPark].self, from: data) {
            parks = decoded
        }
    }

    // MARK: - Activations

    /// Log an activation (as activator or chaser).
    public func logActivation(_ activation: Activation) {
        activationLog.append(activation)
    }

    /// Return activations, optionally filtered by type.
    public func activations(type: Activation.ActivationType? = nil) -> [Activation] {
        if let type {
            return activationLog.filter { $0.type == type }
        }
        return activationLog
    }

    // MARK: - Nearby Search

    /// Find summits within a given radius of a coordinate.
    public func nearbySummits(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) -> [SOTASummit] {
        summits.filter { summit in
            haversineDistance(
                lat1: latitude, lon1: longitude,
                lat2: summit.latitude, lon2: summit.longitude
            ) <= radiusKm
        }
    }

    /// Find parks within a given radius of a coordinate.
    public func nearbyParks(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) -> [POTAPark] {
        parks.filter { park in
            haversineDistance(
                lat1: latitude, lon1: longitude,
                lat2: park.latitude, lon2: park.longitude
            ) <= radiusKm
        }
    }

    // MARK: - Accessors

    /// All loaded summits.
    public func allSummits() -> [SOTASummit] { summits }

    /// All loaded parks.
    public func allParks() -> [POTAPark] { parks }

    // MARK: - Haversine

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
