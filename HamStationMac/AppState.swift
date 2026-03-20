// AppState.swift — Central observable state for the macOS app
// @Observable @MainActor — consumed by all views via @Environment

import SwiftUI
import HamStationKit

// MARK: - Display Adapters

/// Wraps a HamStationKit.DXSpot with award status for view display.
struct DisplaySpot: Identifiable, Sendable {
    let id: UUID
    let time: Date
    let dxCallsign: String
    let frequency: Double
    let spotter: String
    let comment: String
    let status: SpotStatus

    enum SpotStatus: String, Sendable {
        case needed, worked, confirmed
    }

    init(from spot: HamStationKit.DXSpot, status: SpotStatus = .needed) {
        self.id = spot.id
        self.time = spot.timestamp
        self.dxCallsign = spot.dxCallsign
        self.frequency = spot.frequency
        self.spotter = spot.spotter
        self.comment = spot.comment ?? ""
        self.status = status
    }
}

/// A single message in the demo AI chat simulation.
struct DemoChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    var text: String
}

// MARK: - HamStationKit Extensions for Views

extension HamStationKit.RigState {
    /// Band name derived from the frequency.
    var band: String {
        Band.band(forFrequency: frequency)?.rawValue ?? "?"
    }

    /// Frequency formatted as MHz with 3 decimal places.
    var formattedFrequency: String {
        FrequencyFormatter.formatMHz(hz: frequency)
    }

    /// Mode as a display string.
    var modeString: String {
        mode.rawValue
    }
}

/// Maps HamStationKit.ConnectionState to a display-friendly string.
extension HamStationKit.ConnectionState {
    /// A simple label suitable for status bar display.
    var displayLabel: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reconnecting: return "reconnecting"
        case .error(let msg): return "error: \(msg)"
        }
    }

    /// Whether this represents an error state (with or without message).
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Band Conditions (derived from solar data)

enum BandCondition: String, Sendable {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

extension HamStationKit.SolarData {
    /// Estimated band conditions derived from SFI and K-index.
    var bandConditions: [String: BandCondition] {
        let highBandsOpen = solarFluxIndex >= 100 && kIndex <= 3
        let midBandsOpen = solarFluxIndex >= 80 && kIndex <= 4
        let lowBandsOpen = kIndex <= 4

        return [
            "160m": lowBandsOpen ? .fair : .poor,
            "80m": lowBandsOpen ? .fair : .poor,
            "40m": lowBandsOpen ? (midBandsOpen ? .good : .fair) : .poor,
            "30m": midBandsOpen ? .good : .fair,
            "20m": midBandsOpen ? .good : .fair,
            "17m": highBandsOpen ? .good : (midBandsOpen ? .fair : .poor),
            "15m": highBandsOpen ? .good : (midBandsOpen ? .fair : .poor),
            "12m": highBandsOpen ? .fair : .poor,
            "10m": (solarFluxIndex >= 150 && kIndex <= 2) ? .good : (highBandsOpen ? .fair : .poor),
        ]
    }
}

// MARK: - Sidebar Sections

enum SidebarSection: String, CaseIterable, Identifiable {
    case logbook
    case dxCluster
    case bandMap
    case globe
    case awards
    case sotaPota
    case propagation
    case repeaters
    case emcomm
    case antennaTools
    case cwTraining
    case satellite
    case ft8
    case aiAssistant
    case audioSpectrum
    case greatCircleMap
    case tools

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logbook: return "Logbook"
        case .dxCluster: return "DX Cluster"
        case .bandMap: return "Band Map"
        case .globe: return "Globe"
        case .awards: return "Awards"
        case .sotaPota: return "SOTA / POTA"
        case .propagation: return "Propagation"
        case .repeaters: return "Repeaters"
        case .emcomm: return "EmComm"
        case .antennaTools: return "Antenna Tools"
        case .cwTraining: return "CW Training"
        case .satellite: return "Satellites"
        case .ft8: return "FT8"
        case .aiAssistant: return "AI Assistant"
        case .audioSpectrum: return "Spectrum"
        case .greatCircleMap: return "Great Circle"
        case .tools: return "Tools"
        }
    }

    var icon: String {
        switch self {
        case .logbook: return "book.closed"
        case .dxCluster: return "globe"
        case .bandMap: return "waveform.path.ecg"
        case .globe: return "globe.americas.fill"
        case .awards: return "medal"
        case .sotaPota: return "mountain.2"
        case .propagation: return "sun.max"
        case .repeaters: return "antenna.radiowaves.left.and.right"
        case .emcomm: return "staroflife"
        case .antennaTools: return "antenna.radiowaves.left.and.right.slash"
        case .cwTraining: return "waveform.badge.mic"
        case .satellite: return "globe.americas"
        case .ft8: return "waveform"
        case .aiAssistant: return "brain.head.profile"
        case .audioSpectrum: return "waveform.path"
        case .greatCircleMap: return "map"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - AppState

@Observable
@MainActor
final class AppState {
    // Navigation
    var selectedSection: SidebarSection = .logbook
    var selectedQSOId: UUID? = nil

    // Rig state (from HamStationKit)
    var rigState: HamStationKit.RigState? = nil
    var rigConnectionState: HamStationKit.ConnectionState = .disconnected

    // Cluster state
    var clusterConnectionState: HamStationKit.ConnectionState = .disconnected
    var recentSpots: [DisplaySpot] = []

    // Solar / propagation (uses HamStationKit.SolarData via PropagationDashboard)
    var solarData: HamStationKit.SolarData? = nil

    // User profile (from first-run wizard / UserDefaults)
    var operatorCallsign: String = "N0CALL"
    var operatorName: String = ""
    var licenseClass: String = "Extra"
    var gridSquare: String = "FN31pr"

    // Stats
    var qsosToday: Int = 0
    var qsoRate: Int = 0

    // Night mode
    var isNightMode: Bool = false

    // Demo mode
    var isDemoMode: Bool = false
    var demoFT8Decodes: [String] = []
    var demoChatMessages: [DemoChatMessage] = []

    // Speech settings
    var narrationEnabled: Bool = true
    var cwReadbackEnabled: Bool = false
    var cwReadbackMode: String = "words"
    var ttsBackend: String = "auto"
    var kokoroVoice: String = "af_heart"

    // First-run
    var hasCompletedOnboarding: Bool = false

    // MARK: - Persistence via UserDefaults

    private static let callsignKey = "operatorCallsign"
    private static let nameKey = "operatorName"
    private static let licenseKey = "licenseClass"
    private static let gridKey = "gridSquare"
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let nightModeKey = "isNightMode"
    private static let rigHostKey = "rigHost"
    private static let rigPortKey = "rigPort"
    private static let clusterHostKey = "clusterHost"
    private static let clusterPortKey = "clusterPort"

    func loadFromDefaults() {
        let defaults = UserDefaults.standard
        if let call = defaults.string(forKey: Self.callsignKey), !call.isEmpty {
            operatorCallsign = call
        }
        if let name = defaults.string(forKey: Self.nameKey), !name.isEmpty {
            operatorName = name
        }
        if let lic = defaults.string(forKey: Self.licenseKey), !lic.isEmpty {
            licenseClass = lic
        }
        if let grid = defaults.string(forKey: Self.gridKey), !grid.isEmpty {
            gridSquare = grid
        }
        hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
        isNightMode = defaults.bool(forKey: Self.nightModeKey)
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(operatorCallsign, forKey: Self.callsignKey)
        defaults.set(operatorName, forKey: Self.nameKey)
        defaults.set(licenseClass, forKey: Self.licenseKey)
        defaults.set(gridSquare, forKey: Self.gridKey)
        defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        defaults.set(isNightMode, forKey: Self.nightModeKey)
    }

    // MARK: - Saved Connection Settings

    var savedRigHost: String {
        UserDefaults.standard.string(forKey: Self.rigHostKey) ?? "localhost"
    }

    var savedRigPort: UInt16 {
        let val = UserDefaults.standard.integer(forKey: Self.rigPortKey)
        return val > 0 ? UInt16(val) : 4532
    }

    var savedClusterHost: String {
        UserDefaults.standard.string(forKey: Self.clusterHostKey) ?? "dxc.nc7j.com"
    }

    var savedClusterPort: UInt16 {
        let val = UserDefaults.standard.integer(forKey: Self.clusterPortKey)
        return val > 0 ? UInt16(val) : 7373
    }

    func saveRigSettings(host: String, port: UInt16) {
        UserDefaults.standard.set(host, forKey: Self.rigHostKey)
        UserDefaults.standard.set(Int(port), forKey: Self.rigPortKey)
    }

    func saveClusterSettings(host: String, port: UInt16) {
        UserDefaults.standard.set(host, forKey: Self.clusterHostKey)
        UserDefaults.standard.set(Int(port), forKey: Self.clusterPortKey)
    }
}
