// BandAdvisor.swift
// HamStationKit — Combines propagation data + award goals to suggest operating strategy.

import Foundation

/// Recommends bands and modes based on current solar conditions,
/// time of day, and the operator's award needs.
public struct BandAdvisor: Sendable {

    // MARK: - Types

    /// A band/mode recommendation with reasoning.
    public struct Recommendation: Sendable, Identifiable, Equatable {
        public let id: UUID
        public var band: String
        public var mode: String
        public var reason: String
        public var priority: Priority
        public var targetEntities: [String]

        public init(
            id: UUID = UUID(),
            band: String,
            mode: String,
            reason: String,
            priority: Priority,
            targetEntities: [String] = []
        ) {
            self.id = id
            self.band = band
            self.mode = mode
            self.reason = reason
            self.priority = priority
            self.targetEntities = targetEntities
        }

        public enum Priority: Int, Sendable, Comparable, CaseIterable {
            case low = 1
            case medium = 2
            case high = 3

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    /// Band condition rating based on solar indices and time of day.
    public enum BandCondition: String, Sendable, Equatable, CaseIterable {
        case excellent
        case good
        case fair
        case poor
        case closed
    }

    // MARK: - Recommendation Engine

    /// Generate operating recommendations based on current conditions.
    ///
    /// - Parameters:
    ///   - solarData: Current solar weather data. If `nil`, generic recommendations are provided.
    ///   - neededEntities: Set of DXCC entity IDs the operator still needs.
    ///   - dxccEntities: Reference table of DXCC entities (for names).
    ///   - currentTime: The current time (defaults to now).
    /// - Returns: Recommendations sorted by priority (highest first).
    public static func recommend(
        solarData: SolarData?,
        neededEntities: Set<Int>,
        dxccEntities: [DXCCEntity],
        currentTime: Date = Date()
    ) -> [Recommendation] {
        let utcHour = currentUTCHour(from: currentTime)
        let sfi = solarData?.solarFluxIndex ?? 100
        let kIndex = solarData?.kIndex ?? 3

        var recommendations: [Recommendation] = []

        // Evaluate each HF band
        let hfBands = ["160m", "80m", "60m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]

        for bandName in hfBands {
            let condition = bandCondition(bandString: bandName, sfi: sfi, kIndex: kIndex, utcHour: utcHour)
            guard condition != .closed else { continue }

            let priority: Recommendation.Priority
            switch condition {
            case .excellent: priority = .high
            case .good: priority = .medium
            case .fair: priority = .low
            case .poor, .closed: continue
            }

            // Determine likely mode for this band/time
            let mode = suggestedMode(band: bandName, utcHour: utcHour)

            // Check if needed entities might be reachable
            let targets = likelyTargets(
                band: bandName,
                utcHour: utcHour,
                neededEntities: neededEntities,
                dxccEntities: dxccEntities
            )

            let reason = buildReason(band: bandName, condition: condition, utcHour: utcHour, sfi: sfi, targets: targets)

            // Boost priority if targets are available
            let finalPriority = targets.isEmpty ? priority : max(priority, .medium)

            recommendations.append(Recommendation(
                band: bandName,
                mode: mode,
                reason: reason,
                priority: finalPriority,
                targetEntities: targets
            ))
        }

        // Sort by priority descending
        return recommendations.sorted { $0.priority > $1.priority }
    }

    // MARK: - Band Condition Calculation

    /// Estimate the condition of a given band based on solar indices and time of day.
    ///
    /// Rules:
    /// - SFI > 150: 10m, 12m, 15m excellent
    /// - SFI 100-150: 15m, 17m, 20m good
    /// - SFI 70-100: 20m, 30m, 40m good
    /// - SFI < 70: 40m, 80m, 160m primary
    /// - K > 4: HF degraded, consider VHF
    /// - Time of day affects propagation paths
    public static func bandCondition(band: Band, sfi: Int, kIndex: Int, utcHour: Int) -> BandCondition {
        bandCondition(bandString: band.rawValue, sfi: sfi, kIndex: kIndex, utcHour: utcHour)
    }

    /// Band condition lookup using band string.
    public static func bandCondition(bandString: String, sfi: Int, kIndex: Int, utcHour: Int) -> BandCondition {
        // High K-index degrades everything
        if kIndex > 4 {
            // Low bands are less affected by geomagnetic storms
            switch bandString {
            case "160m", "80m":
                return .fair
            case "40m":
                return .poor
            default:
                return .poor
            }
        }

        let timeScore = timeScore(band: bandString, utcHour: utcHour)
        let sfiScore = sfiScore(band: bandString, sfi: sfi)

        let combined = (timeScore + sfiScore) / 2.0

        switch combined {
        case 0.8...: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .fair
        case 0.2..<0.4: return .poor
        default: return .closed
        }
    }

    // MARK: - Internal Helpers

    /// Score a band 0-1 based on time of day (UTC).
    /// 00-06: 40m, 80m, 160m peak (night path)
    /// 06-12: 20m, 17m, 15m rising (morning openings)
    /// 12-18: 15m, 12m, 10m peak (peak daylight)
    /// 18-24: 20m, 40m good (sunset, grey line)
    private static func timeScore(band: String, utcHour: Int) -> Double {
        switch band {
        case "160m":
            switch utcHour {
            case 0..<6: return 0.9
            case 6..<8: return 0.5
            case 8..<16: return 0.0
            case 16..<20: return 0.2
            default: return 0.7
            }
        case "80m":
            switch utcHour {
            case 0..<6: return 0.9
            case 6..<8: return 0.6
            case 8..<16: return 0.1
            case 16..<20: return 0.3
            default: return 0.8
            }
        case "60m":
            switch utcHour {
            case 0..<6: return 0.7
            case 6..<10: return 0.5
            case 10..<16: return 0.2
            case 16..<20: return 0.4
            default: return 0.6
            }
        case "40m":
            switch utcHour {
            case 0..<6: return 0.9
            case 6..<10: return 0.6
            case 10..<16: return 0.3
            case 16..<20: return 0.7
            default: return 0.8
            }
        case "30m":
            switch utcHour {
            case 0..<6: return 0.7
            case 6..<10: return 0.6
            case 10..<16: return 0.4
            case 16..<20: return 0.6
            default: return 0.7
            }
        case "20m":
            switch utcHour {
            case 0..<6: return 0.4
            case 6..<10: return 0.8
            case 10..<16: return 0.7
            case 16..<20: return 0.8
            default: return 0.5
            }
        case "17m":
            switch utcHour {
            case 0..<6: return 0.2
            case 6..<10: return 0.7
            case 10..<16: return 0.8
            case 16..<20: return 0.6
            default: return 0.3
            }
        case "15m":
            switch utcHour {
            case 0..<6: return 0.1
            case 6..<10: return 0.6
            case 10..<16: return 0.9
            case 16..<20: return 0.5
            default: return 0.2
            }
        case "12m":
            switch utcHour {
            case 0..<6: return 0.0
            case 6..<10: return 0.4
            case 10..<16: return 0.9
            case 16..<20: return 0.3
            default: return 0.1
            }
        case "10m":
            switch utcHour {
            case 0..<6: return 0.0
            case 6..<10: return 0.3
            case 10..<16: return 0.9
            case 16..<20: return 0.2
            default: return 0.0
            }
        default:
            return 0.5
        }
    }

    /// Score a band 0-1 based on Solar Flux Index.
    private static func sfiScore(band: String, sfi: Int) -> Double {
        switch band {
        case "160m":
            // Low bands do better with lower SFI (less absorption)
            if sfi < 100 { return 0.8 }
            if sfi < 150 { return 0.5 }
            return 0.3
        case "80m":
            if sfi < 100 { return 0.8 }
            if sfi < 150 { return 0.6 }
            return 0.4
        case "60m":
            if sfi < 100 { return 0.7 }
            if sfi < 150 { return 0.6 }
            return 0.5
        case "40m":
            if sfi < 70 { return 0.8 }
            if sfi < 100 { return 0.8 }
            if sfi < 150 { return 0.7 }
            return 0.6
        case "30m":
            if sfi < 70 { return 0.6 }
            if sfi < 100 { return 0.7 }
            if sfi < 150 { return 0.7 }
            return 0.6
        case "20m":
            if sfi < 70 { return 0.5 }
            if sfi < 100 { return 0.7 }
            if sfi < 150 { return 0.8 }
            return 0.8
        case "17m":
            if sfi < 70 { return 0.3 }
            if sfi < 100 { return 0.6 }
            if sfi < 150 { return 0.8 }
            return 0.8
        case "15m":
            if sfi < 70 { return 0.2 }
            if sfi < 100 { return 0.5 }
            if sfi < 150 { return 0.8 }
            return 0.9
        case "12m":
            if sfi < 70 { return 0.1 }
            if sfi < 100 { return 0.3 }
            if sfi < 150 { return 0.7 }
            return 0.9
        case "10m":
            if sfi < 70 { return 0.0 }
            if sfi < 100 { return 0.2 }
            if sfi < 150 { return 0.6 }
            return 0.9
        default:
            return 0.5
        }
    }

    /// Suggest the most appropriate mode for a band at the given time.
    private static func suggestedMode(band: String, utcHour: Int) -> String {
        switch band {
        case "160m", "80m":
            return "CW" // Low bands favor CW for weak signal
        case "30m":
            return "FT8" // 30m is digital-heavy
        case "40m":
            return utcHour >= 0 && utcHour < 12 ? "CW" : "SSB"
        case "20m":
            return "SSB" // 20m workhorse, SSB most popular
        case "17m", "15m":
            return "SSB"
        case "12m", "10m":
            return "SSB"
        default:
            return "SSB"
        }
    }

    /// Identify DXCC entities likely reachable on a band at the given time.
    private static func likelyTargets(
        band: String,
        utcHour: Int,
        neededEntities: Set<Int>,
        dxccEntities: [DXCCEntity]
    ) -> [String] {
        guard !neededEntities.isEmpty else { return [] }

        // Determine which continents are likely reachable
        let continents = likelyContinents(band: band, utcHour: utcHour)

        let matches = dxccEntities
            .filter { neededEntities.contains($0.id) && continents.contains($0.continent) && !$0.isDeleted }
            .prefix(5)
            .map(\.name)

        return Array(matches)
    }

    /// Which continents are likely to have propagation on this band at this UTC hour.
    /// Simplified model assuming operator is in North America.
    private static func likelyContinents(band: String, utcHour: Int) -> Set<String> {
        switch (band, utcHour) {
        case (_, 0..<6):
            // Night: Asia/Oceania on high bands at solar max, Europe/South America on low bands
            return ["EU", "AS", "OC", "SA"]
        case (_, 6..<12):
            // Morning: Pacific, Asia, Oceania
            return ["AS", "OC", "EU"]
        case (_, 12..<18):
            // Afternoon: Europe, Africa, South America
            return ["EU", "AF", "SA"]
        default:
            // Evening: Europe, South America
            return ["EU", "SA", "AF"]
        }
    }

    /// Build a human-readable reason string for a recommendation.
    private static func buildReason(
        band: String,
        condition: BandCondition,
        utcHour: Int,
        sfi: Int,
        targets: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("\(band) is \(condition.rawValue)")

        switch utcHour {
        case 0..<6:
            if ["40m", "80m", "160m"].contains(band) {
                parts.append("night path open for long-haul DX")
            }
        case 6..<12:
            if ["20m", "17m", "15m"].contains(band) {
                parts.append("morning opening building")
            }
        case 12..<18:
            if ["15m", "12m", "10m"].contains(band) {
                parts.append("peak daylight propagation")
            }
        case 18..<24:
            if ["20m", "40m"].contains(band) {
                parts.append("grey line / sunset enhancement")
            }
        default:
            break
        }

        if sfi > 150 {
            parts.append("SFI \(sfi) supports high-band openings")
        }

        if !targets.isEmpty {
            let targetList = targets.prefix(3).joined(separator: ", ")
            parts.append("needed: \(targetList)")
        }

        return parts.joined(separator: " — ")
    }

    /// Get the current UTC hour from a date.
    private static func currentUTCHour(from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.component(.hour, from: date)
    }
}
