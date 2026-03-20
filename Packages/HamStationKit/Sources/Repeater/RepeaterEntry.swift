// RepeaterEntry.swift
// HamStationKit — Repeater database entry and CTCSS tone types.

import Foundation

/// A repeater directory entry.
public struct RepeaterEntry: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public var callsign: String
    /// Output frequency in MHz.
    public var frequency: Double
    /// Input frequency in MHz (offset applied).
    public var inputFrequency: Double
    /// Offset in MHz, e.g. -0.6, +5.0.
    public var offset: Double
    public var tone: CTCSSTone?
    public var dcsCode: String?
    public var mode: RepeaterMode
    public var city: String
    public var state: String
    public var country: String
    public var latitude: Double
    public var longitude: Double
    public var sponsor: String?
    public var notes: String?
    public var isOperational: Bool
    public var lastUpdated: Date?

    /// Repeater operating modes.
    public enum RepeaterMode: String, Codable, Sendable, CaseIterable {
        case fm
        case dstar
        case dmr
        case c4fm
        case p25
        case allstar
        case echolink
    }

    public init(
        id: UUID = UUID(),
        callsign: String,
        frequency: Double,
        inputFrequency: Double,
        offset: Double,
        tone: CTCSSTone? = nil,
        dcsCode: String? = nil,
        mode: RepeaterMode = .fm,
        city: String,
        state: String,
        country: String = "US",
        latitude: Double,
        longitude: Double,
        sponsor: String? = nil,
        notes: String? = nil,
        isOperational: Bool = true,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.callsign = callsign
        self.frequency = frequency
        self.inputFrequency = inputFrequency
        self.offset = offset
        self.tone = tone
        self.dcsCode = dcsCode
        self.mode = mode
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.sponsor = sponsor
        self.notes = notes
        self.isOperational = isOperational
        self.lastUpdated = lastUpdated
    }
}

/// A CTCSS (Continuous Tone-Coded Squelch System) tone.
public struct CTCSSTone: Sendable, Codable, Equatable {
    /// Tone frequency in Hz, e.g. 100.0, 127.3.
    public let frequency: Double

    public init(frequency: Double) {
        self.frequency = frequency
    }

    /// Standard EIA CTCSS tones.
    public static let standardTones: [Double] = [
        67.0, 71.9, 74.4, 77.0, 79.7, 82.5, 85.4, 88.5, 91.5, 94.8,
        97.4, 100.0, 103.5, 107.2, 110.9, 114.8, 118.8, 123.0, 127.3, 131.8,
        136.5, 141.3, 146.2, 151.4, 156.7, 162.2, 167.9, 173.8, 179.9, 186.2,
        192.8, 203.5, 210.7, 218.1, 225.7, 233.6, 241.8, 250.3
    ]
}
