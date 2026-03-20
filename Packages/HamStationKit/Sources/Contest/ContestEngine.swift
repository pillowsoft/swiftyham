// ContestEngine.swift
// HamStationKit — Manages an active contest session with scoring and dupe checking.

import Foundation

// MARK: - ContestQSO

/// A single QSO within a contest session.
public struct ContestQSO: Sendable, Identifiable, Equatable {
    public let id: UUID
    /// Callsign of the station worked.
    public var callsign: String
    /// Band the QSO was made on (e.g., "20m").
    public var band: String
    /// Mode used (e.g., "CW", "SSB").
    public var mode: String
    /// Exchange sent to the other station.
    public var exchangeSent: String
    /// Exchange received from the other station.
    public var exchangeReceived: String
    /// Timestamp of the QSO.
    public var timestamp: Date
    /// Whether this QSO is a duplicate.
    public var isDupe: Bool
    /// Points earned for this QSO (0 if dupe).
    public var points: Int
    /// Whether this QSO is a new multiplier.
    public var isMultiplier: Bool

    public init(
        id: UUID = UUID(),
        callsign: String,
        band: String,
        mode: String,
        exchangeSent: String,
        exchangeReceived: String,
        timestamp: Date = Date(),
        isDupe: Bool = false,
        points: Int = 0,
        isMultiplier: Bool = false
    ) {
        self.id = id
        self.callsign = callsign
        self.band = band
        self.mode = mode
        self.exchangeSent = exchangeSent
        self.exchangeReceived = exchangeReceived
        self.timestamp = timestamp
        self.isDupe = isDupe
        self.points = points
        self.isMultiplier = isMultiplier
    }
}

// MARK: - ContestScore

/// Current contest score summary.
public struct ContestScore: Sendable, Equatable {
    /// Total number of QSOs logged (including dupes).
    public var totalQSOs: Int
    /// Valid QSOs (excluding dupes).
    public var validQSOs: Int
    /// Total QSO points.
    public var points: Int
    /// Total multipliers.
    public var multipliers: Int
    /// Final score (typically points * multipliers).
    public var score: Int
    /// Number of duplicate QSOs.
    public var dupes: Int

    public init(totalQSOs: Int = 0, validQSOs: Int = 0, points: Int = 0,
                multipliers: Int = 0, score: Int = 0, dupes: Int = 0) {
        self.totalQSOs = totalQSOs
        self.validQSOs = validQSOs
        self.points = points
        self.multipliers = multipliers
        self.score = score
        self.dupes = dupes
    }
}

// MARK: - RateInfo

/// QSO rate information for contest operating.
public struct RateInfo: Sendable, Equatable {
    /// QSOs in the last 10 minutes.
    public var last10Min: Int
    /// QSOs in the last hour.
    public var lastHour: Int
    /// Overall QSO rate (QSOs per hour average).
    public var overall: Double

    public init(last10Min: Int = 0, lastHour: Int = 0, overall: Double = 0) {
        self.last10Min = last10Min
        self.lastHour = lastHour
        self.overall = overall
    }
}

// MARK: - ContestEngine

/// Manages an active contest session including QSO logging, dupe checking, and scoring.
public actor ContestEngine {

    // MARK: - Properties

    /// The contest rules being used.
    public let definition: ContestDefinition

    /// All logged QSOs in chronological order.
    public private(set) var qsos: [ContestQSO] = []

    /// Current serial number (auto-incremented).
    public private(set) var serialNumber: Int = 1

    /// Current contest score.
    public private(set) var score: ContestScore = ContestScore()

    /// Set of worked callsign+band+mode combinations for fast dupe checking.
    private var workedSet: Set<String> = []

    /// Set of earned multipliers for tracking.
    private var multiplierSet: Set<String> = []

    // MARK: - Initialization

    /// Create a new contest engine with the given contest definition.
    ///
    /// - Parameter definition: The contest rules to use.
    public init(definition: ContestDefinition) {
        self.definition = definition
    }

    // MARK: - QSO Logging

    /// Log a new QSO in the contest.
    ///
    /// Automatically checks for duplicates, assigns a serial number,
    /// calculates points, and checks for new multipliers.
    ///
    /// - Parameters:
    ///   - callsign: Callsign of the station worked.
    ///   - exchange: Exchange received from the other station.
    ///   - band: Band the QSO was made on.
    ///   - mode: Mode used.
    /// - Returns: The logged `ContestQSO` with all fields populated.
    public func logQSO(callsign: String, exchange: String, band: String, mode: String) -> ContestQSO {
        let upperCall = callsign.uppercased()
        let dupe = isDupe(callsign: upperCall, band: band, mode: mode)

        // Build exchange sent (with serial number if applicable)
        let exchangeSent: String
        switch definition.exchangeSent {
        case .rstSerial:
            exchangeSent = "599 \(String(format: "%03d", serialNumber))"
        case .rstZone:
            exchangeSent = "599 05"  // placeholder — real app would use operator's zone
        case .rstState:
            exchangeSent = "599 CT"  // placeholder
        case .rstPower:
            exchangeSent = "599 100W"  // placeholder
        case .gridSquare:
            exchangeSent = "FN31"  // placeholder
        case .custom(let desc):
            exchangeSent = desc
        }

        // Calculate points
        let points = dupe ? 0 : definition.pointsPerQSO

        // Check for new multiplier
        let multKey = multiplierKey(exchange: exchange, band: band, mode: mode)
        let isNewMultiplier: Bool
        if dupe || multKey == nil {
            isNewMultiplier = false
        } else {
            isNewMultiplier = !multiplierSet.contains(multKey!)
        }

        let qso = ContestQSO(
            callsign: upperCall,
            band: band,
            mode: mode,
            exchangeSent: exchangeSent,
            exchangeReceived: exchange,
            isDupe: dupe,
            points: points,
            isMultiplier: isNewMultiplier
        )

        // Update state
        qsos.append(qso)

        if !dupe {
            let dupeKey = self.dupeKey(callsign: upperCall, band: band, mode: mode)
            workedSet.insert(dupeKey)
            serialNumber += 1

            if isNewMultiplier, let multKey {
                multiplierSet.insert(multKey)
            }
        }

        recalculateScore()

        return qso
    }

    // MARK: - Dupe Checking

    /// Check if a contact would be a duplicate.
    ///
    /// - Parameters:
    ///   - callsign: Callsign to check.
    ///   - band: Band to check.
    ///   - mode: Mode to check.
    /// - Returns: `true` if the contact would be a dupe.
    public func isDupe(callsign: String, band: String, mode: String) -> Bool {
        let key = dupeKey(callsign: callsign.uppercased(), band: band, mode: mode)
        return workedSet.contains(key)
    }

    /// Generate a dupe-check key based on the contest's dupe rule.
    private func dupeKey(callsign: String, band: String, mode: String) -> String {
        switch definition.dupeRule {
        case .oncePerBandMode:
            return "\(callsign)|\(band)|\(mode)"
        case .oncePerBand:
            return "\(callsign)|\(band)"
        case .oncePerContest:
            return callsign
        }
    }

    // MARK: - N+1 Checking

    /// Check a callsign against the log and suggest similar callsigns.
    ///
    /// Uses Levenshtein distance <= 1 to find potential matches (N+1 check).
    /// This helps catch busted callsigns during contest operation.
    ///
    /// - Parameter callsign: The callsign to check.
    /// - Returns: Array of similar callsigns already in the log.
    public func checkCallsign(_ callsign: String) -> [String] {
        let upper = callsign.uppercased()
        let loggedCalls = Set(qsos.map(\.callsign))

        return loggedCalls.filter { logged in
            logged != upper && levenshteinDistance(logged, upper) <= 1
        }.sorted()
    }

    // MARK: - Rate

    /// Current QSO rate information.
    public var rate: RateInfo {
        let now = Date()
        let tenMinAgo = now.addingTimeInterval(-600)
        let oneHourAgo = now.addingTimeInterval(-3600)

        let validQSOs = qsos.filter { !$0.isDupe }

        let last10 = validQSOs.filter { $0.timestamp > tenMinAgo }.count
        let lastHr = validQSOs.filter { $0.timestamp > oneHourAgo }.count

        let overall: Double
        if let first = validQSOs.first {
            let hours = now.timeIntervalSince(first.timestamp) / 3600.0
            overall = hours > 0 ? Double(validQSOs.count) / hours : 0
        } else {
            overall = 0
        }

        return RateInfo(last10Min: last10, lastHour: lastHr, overall: overall)
    }

    // MARK: - Cabrillo Export

    /// Export the contest log in Cabrillo 3.0 format.
    ///
    /// - Parameters:
    ///   - operatorCallsign: The operator's callsign.
    ///   - operatorCategory: Category (e.g., "SINGLE-OP", "MULTI-SINGLE").
    ///   - power: Power category (e.g., "LOW", "HIGH", "QRP").
    /// - Returns: Complete Cabrillo 3.0 format log as a string.
    public func exportCabrillo(
        operatorCallsign: String,
        operatorCategory: String,
        power: String
    ) -> String {
        let exporter = CabrilloExporter()
        let cabrilloQSOs = qsos.filter { !$0.isDupe }.map { qso in
            CabrilloExporter.CabrilloQSO(
                frequency: frequencyKHz(for: qso.band),
                mode: cabrilloMode(for: qso.mode),
                date: CabrilloExporter.formatDate(qso.timestamp),
                time: CabrilloExporter.formatTime(qso.timestamp),
                sentCall: operatorCallsign,
                sentExchange: qso.exchangeSent,
                rcvdCall: qso.callsign,
                rcvdExchange: qso.exchangeReceived
            )
        }

        return CabrilloExporter.export(
            contest: definition.id,
            callsign: operatorCallsign,
            category: operatorCategory,
            power: power,
            assisted: false,
            band: "ALL",
            mode: definition.modes.count == 1 ? definition.modes[0] : "MIXED",
            operators: [operatorCallsign],
            claimedScore: score.score,
            club: nil,
            location: nil,
            qsos: cabrilloQSOs
        )
    }

    // MARK: - Private Helpers

    private func recalculateScore() {
        let validQSOs = qsos.filter { !$0.isDupe }
        let totalPoints = validQSOs.reduce(0) { $0 + $1.points }
        let totalMults = multiplierSet.count

        let finalScore: Int
        switch definition.scoringFormula {
        case .pointsTimesMults:
            finalScore = totalPoints * max(totalMults, 1)
        case .pointsOnly:
            finalScore = totalPoints
        }

        score = ContestScore(
            totalQSOs: qsos.count,
            validQSOs: validQSOs.count,
            points: totalPoints,
            multipliers: totalMults,
            score: finalScore,
            dupes: qsos.count - validQSOs.count
        )
    }

    /// Generate a multiplier key based on the contest's multiplier type.
    private func multiplierKey(exchange: String, band: String, mode: String) -> String? {
        let exchangeUpper = exchange.uppercased().trimmingCharacters(in: .whitespaces)

        switch definition.multiplierType {
        case .zonePerBand:
            // Extract zone number from exchange
            let zone = exchangeUpper.components(separatedBy: " ").last ?? exchangeUpper
            return "zone:\(zone)|\(band)"
        case .dxccPerBand:
            return "dxcc:\(exchangeUpper)|\(band)"
        case .dxccPerMode:
            return "dxcc:\(exchangeUpper)|\(mode)"
        case .statePerBand:
            let state = exchangeUpper.components(separatedBy: " ").last ?? exchangeUpper
            return "state:\(state)|\(band)"
        case .gridPerBand:
            return "grid:\(exchangeUpper)|\(band)"
        case .none:
            return nil
        }
    }

    /// Levenshtein distance between two strings (for N+1 checking).
    private func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let sChars = Array(s)
        let tChars = Array(t)
        let m = sChars.count
        let n = tChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = sChars[i - 1] == tChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,       // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            prev = curr
        }

        return curr[n]
    }

    /// Convert a band string to a representative frequency in kHz.
    private func frequencyKHz(for band: String) -> Int {
        switch band {
        case "160m": return 1800
        case "80m": return 3500
        case "40m": return 7000
        case "20m": return 14000
        case "15m": return 21000
        case "10m": return 28000
        case "6m": return 50000
        case "2m": return 144000
        default: return 14000
        }
    }

    /// Convert a mode string to Cabrillo mode code.
    private func cabrilloMode(for mode: String) -> String {
        switch mode.uppercased() {
        case "CW": return "CW"
        case "SSB", "USB", "LSB": return "PH"
        case "RTTY", "FT8", "FT4", "PSK31": return "RY"
        default: return "PH"
        }
    }
}
