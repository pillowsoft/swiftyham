// SmartLogAnalysis.swift
// HamStationKit — Background analysis of operator's logbook for insights.
// Runs entirely on-device. No data leaves the Mac.

import Foundation

/// Analyzes QSO history to generate actionable insights about operating patterns,
/// award progress, and band utilization.
public struct SmartLogAnalysis: Sendable {

    // MARK: - Types

    /// An insight generated from log analysis.
    public struct Insight: Sendable, Identifiable, Equatable {
        public let id: UUID
        public var category: Category
        public var title: String
        public var detail: String
        /// Priority: 1 = highest.
        public var priority: Int

        public enum Category: String, Sendable, CaseIterable {
            case awards
            case operating
            case performance
            case suggestion
        }

        public init(
            id: UUID = UUID(),
            category: Category,
            title: String,
            detail: String,
            priority: Int
        ) {
            self.id = id
            self.category = category
            self.title = title
            self.detail = detail
            self.priority = priority
        }
    }

    /// A lightweight QSO record for analysis (avoids depending on full QSO model with GRDB).
    public struct QSOAnalysisRecord: Sendable {
        public var dateTimeOn: Date
        public var band: String
        public var mode: String
        public var dxccEntityId: Int?
        public var continent: String?

        public init(
            dateTimeOn: Date,
            band: String,
            mode: String,
            dxccEntityId: Int? = nil,
            continent: String? = nil
        ) {
            self.dateTimeOn = dateTimeOn
            self.band = band
            self.mode = mode
            self.dxccEntityId = dxccEntityId
            self.continent = continent
        }
    }

    // MARK: - Analysis

    /// Analyze QSOs and generate insights.
    ///
    /// - Parameters:
    ///   - qsos: The operator's QSO records to analyze.
    ///   - dxccProgress: Tuple of (worked, confirmed, total) DXCC entities.
    ///   - wasProgress: Tuple of (worked, total) WAS states.
    /// - Returns: Array of insights sorted by priority (lowest number = highest priority).
    public static func analyze(
        qsos: [QSOAnalysisRecord],
        dxccProgress: (worked: Int, confirmed: Int, total: Int),
        wasProgress: (worked: Int, total: Int)
    ) -> [Insight] {
        var insights: [Insight] = []

        insights.append(contentsOf: awardProximityInsights(dxccProgress: dxccProgress, wasProgress: wasProgress))
        insights.append(contentsOf: peakHoursInsights(qsos: qsos))
        insights.append(contentsOf: bandUtilizationInsights(qsos: qsos))
        insights.append(contentsOf: modeDistributionInsights(qsos: qsos))
        insights.append(contentsOf: continentGapInsights(qsos: qsos))
        insights.append(contentsOf: rateAnalysisInsights(qsos: qsos))

        return insights.sorted { $0.priority < $1.priority }
    }

    // MARK: - Award Proximity

    private static func awardProximityInsights(
        dxccProgress: (worked: Int, confirmed: Int, total: Int),
        wasProgress: (worked: Int, total: Int)
    ) -> [Insight] {
        var insights: [Insight] = []

        // DXCC milestones
        let dxccMilestones = [100, 150, 200, 250, 300]
        for milestone in dxccMilestones {
            let remaining = milestone - dxccProgress.confirmed
            if remaining > 0, remaining <= 10 {
                insights.append(Insight(
                    category: .awards,
                    title: "Close to DXCC \(milestone)",
                    detail: "You need \(remaining) more confirmed entities for DXCC \(milestone). You have \(dxccProgress.confirmed) confirmed of \(dxccProgress.worked) worked.",
                    priority: 1
                ))
                break // Only show the nearest milestone
            }
        }

        // WAS progress
        let wasRemaining = wasProgress.total - wasProgress.worked
        if wasRemaining > 0, wasRemaining <= 10 {
            insights.append(Insight(
                category: .awards,
                title: "Close to WAS",
                detail: "You need \(wasRemaining) more states for Worked All States. Keep an eye on state QSO parties!",
                priority: 1
            ))
        }

        return insights
    }

    // MARK: - Peak Operating Hours

    private static func peakHoursInsights(qsos: [QSOAnalysisRecord]) -> [Insight] {
        guard qsos.count >= 20 else { return [] }

        var insights: [Insight] = []

        // Group QSOs by UTC hour
        var hourCounts: [Int: Int] = [:]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        for qso in qsos {
            let hour = calendar.component(.hour, from: qso.dateTimeOn)
            hourCounts[hour, default: 0] += 1
        }

        // Find peak 2-hour window
        if let peakHour = hourCounts.max(by: { $0.value < $1.value })?.key {
            let nextHour = (peakHour + 1) % 24
            let peakCount = (hourCounts[peakHour] ?? 0) + (hourCounts[nextHour] ?? 0)
            let percentage = Double(peakCount) / Double(qsos.count) * 100

            if percentage > 15 {
                insights.append(Insight(
                    category: .operating,
                    title: "Peak Operating Window",
                    detail: "Your contacts peak between \(String(format: "%02d", peakHour))00-\(String(format: "%02d", (peakHour + 2) % 24))00 UTC (\(Int(percentage))% of QSOs). Good propagation awareness!",
                    priority: 3
                ))
            }
        }

        // Band-specific peak hours
        let bandHours = Dictionary(grouping: qsos) { $0.band }
        for (band, bandQSOs) in bandHours where bandQSOs.count >= 10 {
            var bHourCounts: [Int: Int] = [:]
            for qso in bandQSOs {
                let hour = calendar.component(.hour, from: qso.dateTimeOn)
                bHourCounts[hour, default: 0] += 1
            }
            if let peak = bHourCounts.max(by: { $0.value < $1.value })?.key {
                let peakPct = Double(bHourCounts[peak] ?? 0) / Double(bandQSOs.count) * 100
                if peakPct > 20 {
                    insights.append(Insight(
                        category: .operating,
                        title: "\(band) Peak Hours",
                        detail: "Your \(band) contacts cluster around \(String(format: "%02d", peak))00 UTC. Consider expanding to other time slots for different paths.",
                        priority: 4
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - Band Utilization

    private static func bandUtilizationInsights(qsos: [QSOAnalysisRecord]) -> [Insight] {
        guard qsos.count >= 10 else { return [] }

        var insights: [Insight] = []

        let usedBands = Set(qsos.map(\.band))
        let allHFBands: Set<String> = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]
        let unusedBands = allHFBands.subtracting(usedBands)

        // Check for bands not used recently (last 30 days)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let recentQSOs = qsos.filter { $0.dateTimeOn > thirtyDaysAgo }
        let recentBands = Set(recentQSOs.map(\.band))
        let staleHFBands = usedBands.intersection(allHFBands).subtracting(recentBands)

        if !unusedBands.isEmpty {
            let bandList = unusedBands.sorted().joined(separator: ", ")
            insights.append(Insight(
                category: .suggestion,
                title: "Unexplored Bands",
                detail: "You haven't logged any contacts on \(bandList). These bands may offer new DXCC entities.",
                priority: 3
            ))
        }

        for band in staleHFBands.sorted() {
            insights.append(Insight(
                category: .suggestion,
                title: "\(band) Inactive",
                detail: "You haven't used \(band) in 30 days. Conditions may have changed since you last tried it.",
                priority: 4
            ))
        }

        return insights
    }

    // MARK: - Mode Distribution

    private static func modeDistributionInsights(qsos: [QSOAnalysisRecord]) -> [Insight] {
        guard qsos.count >= 20 else { return [] }

        var insights: [Insight] = []

        let modeCounts = Dictionary(grouping: qsos, by: \.mode).mapValues(\.count)
        let total = Double(qsos.count)

        // Check for mode imbalance
        for (mode, count) in modeCounts {
            let percentage = Double(count) / total * 100
            if percentage > 85 {
                let alternativeModes: String
                switch mode {
                case "FT8", "FT4":
                    alternativeModes = "CW or SSB"
                case "SSB":
                    alternativeModes = "CW or FT8"
                case "CW":
                    alternativeModes = "SSB or FT8"
                default:
                    alternativeModes = "other modes"
                }

                insights.append(Insight(
                    category: .suggestion,
                    title: "Mode Concentration",
                    detail: "\(Int(percentage))% of your contacts are \(mode). Try \(alternativeModes) for variety and additional DXCC/WAS credit on different modes.",
                    priority: 3
                ))
            }
        }

        return insights
    }

    // MARK: - Continent Gaps

    private static func continentGapInsights(qsos: [QSOAnalysisRecord]) -> [Insight] {
        guard qsos.count >= 20 else { return [] }

        var insights: [Insight] = []

        let allContinents: Set<String> = ["NA", "SA", "EU", "AF", "AS", "OC"]
        let workedContinents = Set(qsos.compactMap(\.continent))
        let missingContinents = allContinents.subtracting(workedContinents)

        if !missingContinents.isEmpty {
            let continentNames = missingContinents.sorted().map { continentName($0) }
            insights.append(Insight(
                category: .suggestion,
                title: "Missing Continents",
                detail: "You have no contacts with \(continentNames.joined(separator: ", ")). Check grey-line paths and adjust operating times.",
                priority: 2
            ))
        }

        // Per-band continent gaps
        let bandGroups = Dictionary(grouping: qsos, by: \.band)
        for (band, bandQSOs) in bandGroups where bandQSOs.count >= 10 {
            let bandContinents = Set(bandQSOs.compactMap(\.continent))
            let bandMissing = allContinents.subtracting(bandContinents)

            if let missing = bandMissing.first, bandMissing.count <= 2 {
                let name = continentName(missing)
                let suggestion = continentTimeSuggestion(missing)
                insights.append(Insight(
                    category: .suggestion,
                    title: "No \(name) on \(band)",
                    detail: "You have no \(name) contacts on \(band). \(suggestion)",
                    priority: 3
                ))
            }
        }

        return insights
    }

    // MARK: - Rate Analysis

    private static func rateAnalysisInsights(qsos: [QSOAnalysisRecord]) -> [Insight] {
        guard qsos.count >= 50 else { return [] }

        var insights: [Insight] = []

        // Group QSOs by date to find contest-like days (high volume)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let dayGroups = Dictionary(grouping: qsos) { qso -> String in
            let components = calendar.dateComponents([.year, .month, .day], from: qso.dateTimeOn)
            return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        }

        // Find days with high QSO rates (likely contests)
        let highVolumeDays = dayGroups.filter { $0.value.count >= 20 }

        for (_, dayQSOs) in highVolumeDays {
            // Check for rate drops after sustained operating
            let sorted = dayQSOs.sorted { $0.dateTimeOn < $1.dateTimeOn }
            if sorted.count >= 20 {
                // Compare first half rate vs second half rate
                let mid = sorted.count / 2
                let firstHalf = sorted.prefix(mid)
                let secondHalf = sorted.suffix(from: mid)

                if let firstStart = firstHalf.first?.dateTimeOn,
                   let firstEnd = firstHalf.last?.dateTimeOn,
                   let secondStart = secondHalf.first?.dateTimeOn,
                   let secondEnd = secondHalf.last?.dateTimeOn {
                    let firstDuration = firstEnd.timeIntervalSince(firstStart)
                    let secondDuration = secondEnd.timeIntervalSince(secondStart)

                    if firstDuration > 0, secondDuration > 0 {
                        let firstRate = Double(firstHalf.count) / (firstDuration / 3600)
                        let secondRate = Double(secondHalf.count) / (secondDuration / 3600)

                        if firstRate > 0, secondRate / firstRate < 0.6 {
                            insights.append(Insight(
                                category: .performance,
                                title: "Rate Fatigue Detected",
                                detail: "Your QSO rate drops significantly after sustained operating. Consider taking short breaks to maintain peak performance.",
                                priority: 3
                            ))
                            break // Only one rate insight
                        }
                    }
                }
            }
        }

        return insights
    }

    // MARK: - Helpers

    private static func continentName(_ code: String) -> String {
        switch code {
        case "NA": return "North America"
        case "SA": return "South America"
        case "EU": return "Europe"
        case "AF": return "Africa"
        case "AS": return "Asia"
        case "OC": return "Oceania"
        default: return code
        }
    }

    private static func continentTimeSuggestion(_ continent: String) -> String {
        switch continent {
        case "AF": return "Try 1800-2000 UTC on 20m or 15m."
        case "AS": return "Try 0800-1200 UTC on 20m or 15m."
        case "OC": return "Try 0600-1000 UTC on 20m or 40m."
        case "SA": return "Try 2200-0200 UTC on 20m or 40m."
        case "EU": return "Try 1200-1800 UTC on 20m or 15m."
        case "NA": return "Try any time on 20m or 40m."
        default: return "Check propagation predictions for optimal times."
        }
    }
}
