// SolarData.swift
// HamStationKit — Solar weather data for propagation assessment.

import Foundation

/// Solar weather data from NOAA Space Weather Prediction Center.
public struct SolarData: Sendable, Equatable {
    /// Solar Flux Index (10.7cm flux). Higher values generally mean better HF propagation.
    public var solarFluxIndex: Int
    /// 24-hour geomagnetic A-index.
    public var aIndex: Int
    /// 3-hour geomagnetic K-index (0-9).
    public var kIndex: Int
    /// K-index trend direction.
    public var kIndexTrend: Trend
    /// X-ray flux classification (e.g., "B5.2").
    public var xrayFlux: String
    /// Proton flux in particles/cm^2/s, if available.
    public var protonFlux: Double?
    /// When this data was last updated.
    public var updatedAt: Date

    /// Direction of change for a metric.
    public enum Trend: String, Sendable, Equatable {
        case rising
        case falling
        case stable
    }

    /// Geomagnetic severity level based on K-index.
    public enum Severity: String, Sendable, Equatable {
        case quiet
        case unsettled
        case storm
        case severeStorm
    }

    public init(
        solarFluxIndex: Int = 0,
        aIndex: Int = 0,
        kIndex: Int = 0,
        kIndexTrend: Trend = .stable,
        xrayFlux: String = "",
        protonFlux: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.solarFluxIndex = solarFluxIndex
        self.aIndex = aIndex
        self.kIndex = kIndex
        self.kIndexTrend = kIndexTrend
        self.xrayFlux = xrayFlux
        self.protonFlux = protonFlux
        self.updatedAt = updatedAt
    }

    /// Geomagnetic severity derived from K-index.
    public var kIndexSeverity: Severity {
        switch kIndex {
        case 0...3: return .quiet
        case 4: return .unsettled
        case 5: return .storm
        default: return .severeStorm
        }
    }

    /// Brief text summary of band conditions.
    public var bandConditionsSummary: String {
        let condition: String
        switch (solarFluxIndex, kIndex) {
        case (let sfi, let k) where sfi >= 150 && k <= 3:
            condition = "Excellent"
        case (let sfi, let k) where sfi >= 100 && k <= 3:
            condition = "Good"
        case (let sfi, let k) where sfi >= 80 && k <= 4:
            condition = "Fair"
        case (_, let k) where k >= 5:
            condition = "Poor"
        default:
            condition = "Fair"
        }
        return "HF: \(condition) (SFI \(solarFluxIndex), K=\(kIndex))"
    }
}
