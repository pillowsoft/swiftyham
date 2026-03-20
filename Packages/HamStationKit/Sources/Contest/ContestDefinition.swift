// ContestDefinition.swift
// HamStationKit — Contest definitions stored as data, not code.

import Foundation

// MARK: - ContestDefinition

/// Defines the rules and scoring for an amateur radio contest.
///
/// Contest definitions are data-driven so new contests can be added
/// without code changes. They specify the exchange format, multiplier
/// rules, scoring formula, and dupe rules.
public struct ContestDefinition: Sendable, Identifiable, Codable, Equatable {
    /// Unique contest identifier (e.g., "CQWW-CW", "ARRL-DX-SSB").
    public let id: String
    /// Human-readable contest name.
    public var name: String
    /// Contest sponsor organization.
    public var sponsor: String
    /// Allowed operating modes.
    public var modes: [String]
    /// Type of exchange sent by the operator.
    public var exchangeSent: ExchangeType
    /// Type of exchange received from the other station.
    public var exchangeReceived: ExchangeType
    /// How multipliers are counted.
    public var multiplierType: MultiplierType
    /// How the final score is calculated.
    public var scoringFormula: ScoringFormula
    /// Rule for determining duplicate contacts.
    public var dupeRule: DupeRule
    /// Allowed amateur bands (e.g., ["160m", "80m", "40m", "20m", "15m", "10m"]).
    public var bands: [String]
    /// Points per QSO (base value; can vary by contest rules).
    public var pointsPerQSO: Int

    public init(
        id: String,
        name: String,
        sponsor: String,
        modes: [String],
        exchangeSent: ExchangeType,
        exchangeReceived: ExchangeType,
        multiplierType: MultiplierType,
        scoringFormula: ScoringFormula,
        dupeRule: DupeRule,
        bands: [String],
        pointsPerQSO: Int = 1
    ) {
        self.id = id
        self.name = name
        self.sponsor = sponsor
        self.modes = modes
        self.exchangeSent = exchangeSent
        self.exchangeReceived = exchangeReceived
        self.multiplierType = multiplierType
        self.scoringFormula = scoringFormula
        self.dupeRule = dupeRule
        self.bands = bands
        self.pointsPerQSO = pointsPerQSO
    }

    // MARK: - Exchange Type

    /// The type of information exchanged during a contest QSO.
    public enum ExchangeType: Codable, Sendable, Equatable {
        /// RST + serial number (e.g., "599 001").
        case rstSerial
        /// RST + US state abbreviation (e.g., "599 CT").
        case rstState
        /// RST + CQ zone number (e.g., "599 05").
        case rstZone
        /// RST + power level (e.g., "599 5W" for QRP contests).
        case rstPower
        /// Maidenhead grid square (e.g., "FN31" for VHF contests).
        case gridSquare
        /// Custom exchange format with description.
        case custom(String)
    }

    // MARK: - Multiplier Type

    /// How multipliers are counted in the contest.
    public enum MultiplierType: Codable, Sendable, Equatable {
        /// Each DXCC entity counts once per band.
        case dxccPerBand
        /// Each DXCC entity counts once per mode.
        case dxccPerMode
        /// Each US state counts once per band.
        case statePerBand
        /// Each CQ zone counts once per band.
        case zonePerBand
        /// Each grid square counts once per band.
        case gridPerBand
        /// No multipliers (score is just QSO points).
        case none
    }

    // MARK: - Scoring Formula

    /// How the final contest score is calculated.
    public enum ScoringFormula: Codable, Sendable, Equatable {
        /// Final score = total QSO points * total multipliers.
        case pointsTimesMults
        /// Final score = total QSO points only.
        case pointsOnly
    }

    // MARK: - Dupe Rule

    /// Rule for determining whether a contact is a duplicate.
    public enum DupeRule: Codable, Sendable, Equatable {
        /// Same station can be worked once per band per mode combination.
        case oncePerBandMode
        /// Same station can be worked once per band (regardless of mode).
        case oncePerBand
        /// Same station can only be worked once in the entire contest.
        case oncePerContest
    }
}

// MARK: - Built-in Contest Definitions

extension ContestDefinition {
    /// All built-in contest definitions.
    public static let builtIn: [ContestDefinition] = [
        .cqwwCW, .cqwwSSB, .arrlDXCW, .arrlDXSSB, .arrlSweepstakes,
        .cqWPXCW, .cqWPXSSB, .iaruHF, .naqpCW, .naqpSSB
    ]

    /// CQ World Wide DX Contest — CW.
    public static let cqwwCW = ContestDefinition(
        id: "CQWW-CW",
        name: "CQ World Wide DX Contest — CW",
        sponsor: "CQ Magazine",
        modes: ["CW"],
        exchangeSent: .rstZone,
        exchangeReceived: .rstZone,
        multiplierType: .zonePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// CQ World Wide DX Contest — SSB.
    public static let cqwwSSB = ContestDefinition(
        id: "CQWW-SSB",
        name: "CQ World Wide DX Contest — SSB",
        sponsor: "CQ Magazine",
        modes: ["SSB"],
        exchangeSent: .rstZone,
        exchangeReceived: .rstZone,
        multiplierType: .zonePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// ARRL DX Contest — CW.
    public static let arrlDXCW = ContestDefinition(
        id: "ARRL-DX-CW",
        name: "ARRL DX Contest — CW",
        sponsor: "ARRL",
        modes: ["CW"],
        exchangeSent: .rstPower,
        exchangeReceived: .rstPower,
        multiplierType: .dxccPerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// ARRL DX Contest — SSB.
    public static let arrlDXSSB = ContestDefinition(
        id: "ARRL-DX-SSB",
        name: "ARRL DX Contest — SSB",
        sponsor: "ARRL",
        modes: ["SSB"],
        exchangeSent: .rstPower,
        exchangeReceived: .rstPower,
        multiplierType: .dxccPerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// ARRL Sweepstakes (CW + SSB weekends).
    public static let arrlSweepstakes = ContestDefinition(
        id: "ARRL-SS",
        name: "ARRL Sweepstakes",
        sponsor: "ARRL",
        modes: ["CW", "SSB"],
        exchangeSent: .custom("NR PREC CK SEC"),
        exchangeReceived: .custom("NR PREC CK SEC"),
        multiplierType: .statePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerContest,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 2
    )

    /// CQ WPX Contest — CW.
    public static let cqWPXCW = ContestDefinition(
        id: "CQ-WPX-CW",
        name: "CQ WPX Contest — CW",
        sponsor: "CQ Magazine",
        modes: ["CW"],
        exchangeSent: .rstSerial,
        exchangeReceived: .rstSerial,
        multiplierType: .none,  // WPX uses prefix multipliers (simplified here)
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// CQ WPX Contest — SSB.
    public static let cqWPXSSB = ContestDefinition(
        id: "CQ-WPX-SSB",
        name: "CQ WPX Contest — SSB",
        sponsor: "CQ Magazine",
        modes: ["SSB"],
        exchangeSent: .rstSerial,
        exchangeReceived: .rstSerial,
        multiplierType: .none,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 3
    )

    /// IARU HF World Championship.
    public static let iaruHF = ContestDefinition(
        id: "IARU-HF",
        name: "IARU HF World Championship",
        sponsor: "IARU",
        modes: ["CW", "SSB"],
        exchangeSent: .rstZone,
        exchangeReceived: .rstZone,
        multiplierType: .zonePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBandMode,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 1
    )

    /// North American QSO Party — CW.
    public static let naqpCW = ContestDefinition(
        id: "NAQP-CW",
        name: "North American QSO Party — CW",
        sponsor: "NCJ",
        modes: ["CW"],
        exchangeSent: .rstState,
        exchangeReceived: .rstState,
        multiplierType: .statePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 1
    )

    /// North American QSO Party — SSB.
    public static let naqpSSB = ContestDefinition(
        id: "NAQP-SSB",
        name: "North American QSO Party — SSB",
        sponsor: "NCJ",
        modes: ["SSB"],
        exchangeSent: .rstState,
        exchangeReceived: .rstState,
        multiplierType: .statePerBand,
        scoringFormula: .pointsTimesMults,
        dupeRule: .oncePerBand,
        bands: ["160m", "80m", "40m", "20m", "15m", "10m"],
        pointsPerQSO: 1
    )
}
