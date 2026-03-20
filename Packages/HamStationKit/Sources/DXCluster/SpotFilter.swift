import Foundation

// MARK: - SpotFilter

/// Filter criteria for DX cluster spots.
///
/// A nil value for any set-based filter means "all" (no filtering on that dimension).
/// Multiple active filters are combined with AND logic — a spot must pass all active filters.
public struct SpotFilter: Sendable, Equatable {
    /// Filter by bands. Nil means all bands.
    public var bands: Set<Band>?

    /// Filter by modes. Nil means all modes.
    public var modes: Set<OperatingMode>?

    /// Filter by continents (e.g., "EU", "NA", "AS"). Nil means all.
    public var continents: Set<String>?

    /// Filter by callsign prefix (e.g., "JA" to see only Japanese spots).
    public var callsignPrefix: String?

    /// Exclude spots from automated skimmer stations.
    public var excludeSkimmers: Bool

    /// Maximum age of spots in minutes. Spots older than this are filtered out.
    public var maxAgeMinutes: Int

    /// Only show spots for entities/bands/modes the operator still needs.
    /// Requires award progress data to be effective.
    public var neededOnly: Bool

    public init(
        bands: Set<Band>? = nil,
        modes: Set<OperatingMode>? = nil,
        continents: Set<String>? = nil,
        callsignPrefix: String? = nil,
        excludeSkimmers: Bool = false,
        maxAgeMinutes: Int = 30,
        neededOnly: Bool = false
    ) {
        self.bands = bands
        self.modes = modes
        self.continents = continents
        self.callsignPrefix = callsignPrefix
        self.excludeSkimmers = excludeSkimmers
        self.maxAgeMinutes = maxAgeMinutes
        self.neededOnly = neededOnly
    }

    /// Returns true if the given spot matches all active filter criteria.
    public func matches(_ spot: DXSpot) -> Bool {
        // Band filter
        if let bands, !bands.isEmpty {
            guard let spotBand = spot.band, bands.contains(spotBand) else {
                return false
            }
        }

        // Mode filter
        if let modes, !modes.isEmpty {
            guard let spotMode = spot.mode, modes.contains(spotMode) else {
                return false
            }
        }

        // Callsign prefix filter
        if let prefix = callsignPrefix, !prefix.isEmpty {
            guard spot.dxCallsign.uppercased().hasPrefix(prefix.uppercased()) else {
                return false
            }
        }

        // Skimmer exclusion: skimmers typically have "-#" SSID in the spotter callsign
        if excludeSkimmers {
            if spot.spotter.contains("-#") || isKnownSkimmer(spot.spotter) {
                return false
            }
        }

        // Age filter
        let ageMinutes = Date().timeIntervalSince(spot.timestamp) / 60.0
        if ageMinutes > Double(maxAgeMinutes) {
            return false
        }

        // Continent filter (requires DX callsign prefix resolution — basic check here)
        // Note: Full continent resolution would require DXCC prefix database lookup.
        // This is a placeholder that checks if the spot has continent info attached.
        if let continents, !continents.isEmpty {
            // Continent filtering requires external data; spots don't inherently carry continent info.
            // This filter is evaluated externally by the caller who has DXCC data.
            // For now, pass through if we can't determine continent.
        }

        // neededOnly filter requires external award progress data
        // Evaluated externally by the caller who has access to the award progress database.

        return true
    }

    /// Basic heuristic to detect known skimmer stations.
    /// Skimmer callsigns often end with "-#" or are in known skimmer networks.
    private func isKnownSkimmer(_ callsign: String) -> Bool {
        // Common pattern: skimmer SSIDs
        if callsign.hasSuffix("-#") { return true }

        // Some well-known skimmer network indicators
        let upperCallsign = callsign.uppercased()
        let skimmerIndicators = ["-1-#", "-2-#", "-3-#"]
        for indicator in skimmerIndicators {
            if upperCallsign.contains(indicator) { return true }
        }

        return false
    }
}
