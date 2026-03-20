// FT8Message.swift
// HamStationKit — FT8 message types, parsing, and formatting.
// Reference: ft8_lib (MIT, https://github.com/kgoba/ft8_lib)

import Foundation

/// A decoded or composed FT8 message with metadata.
///
/// FT8 messages carry 77 bits of payload, encoding structured information
/// such as callsigns, grid squares, and signal reports. This type represents
/// both decoded received messages and messages to be transmitted.
public struct FT8Message: Sendable, Identifiable, Equatable {

    public let id: UUID

    /// The type of message (CQ, reply, report, etc.).
    public var type: MessageType

    /// The calling station callsign, or "CQ" / "CQ DX" / "CQ NA" etc.
    public var callsign1: String

    /// The responding station callsign (nil for CQ messages without a target).
    public var callsign2: String?

    /// 4-character Maidenhead grid square (e.g., "FN31").
    public var grid: String?

    /// Signal report in dB (e.g., "-10", "+05", "R-08").
    public var report: String?

    /// Exchange completion tokens: "73", "RR73", "RRR".
    public var extra: String?

    /// Audio frequency of the signal within the passband, in Hz.
    public var frequency: Double

    /// Signal-to-noise ratio in dB (typically -24 to +50).
    public var snr: Int

    /// Time offset from the cycle boundary in seconds (DT).
    public var timeOffset: Double

    /// When this message was decoded or created.
    public var timestamp: Date

    /// FT8 message type classification.
    public enum MessageType: String, Sendable, CaseIterable {
        /// "CQ W1AW FN31"
        case cq
        /// "CQ NA W1AW FN31" (directed CQ)
        case cqDirected
        /// "W1AW JA1ABC PM95" (initial reply with grid)
        case reply
        /// "JA1ABC W1AW -10" (signal report)
        case report
        /// "W1AW JA1ABC R-08" (roger + report)
        case rrReport
        /// "JA1ABC W1AW RR73" (roger roger 73)
        case rr73
        /// "W1AW JA1ABC 73" (end of QSO)
        case seventy3
        /// Arbitrary 13-character free text
        case freeText
    }

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        type: MessageType,
        callsign1: String,
        callsign2: String? = nil,
        grid: String? = nil,
        report: String? = nil,
        extra: String? = nil,
        frequency: Double = 1000,
        snr: Int = 0,
        timeOffset: Double = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.callsign1 = callsign1
        self.callsign2 = callsign2
        self.grid = grid
        self.report = report
        self.extra = extra
        self.frequency = frequency
        self.snr = snr
        self.timeOffset = timeOffset
        self.timestamp = timestamp
    }
}

// MARK: - Parsing

extension FT8Message {

    // Regex patterns for FT8 message formats.
    // Callsign: 1-2 letter/digit prefix, digit, 1-4 letter suffix (with optional /P etc.)
    private static let callsignPattern = "[A-Z0-9]{1,3}[0-9][A-Z0-9]{0,4}(?:/[A-Z0-9]{1,4})?"
    private static let gridPattern = "[A-R]{2}[0-9]{2}"
    private static let reportPattern = "[+-][0-9]{2}"

    /// Parse an FT8 message from its standard text representation.
    ///
    /// - Parameters:
    ///   - text: The decoded message string (e.g., "CQ W1AW FN31").
    ///   - frequency: Audio frequency in Hz within the passband.
    ///   - snr: Signal-to-noise ratio in dB.
    ///   - dt: Time offset from cycle boundary in seconds.
    /// - Returns: A parsed `FT8Message`, or `nil` if the text doesn't match any known format.
    public static func parse(
        text: String,
        frequency: Double = 1000,
        snr: Int = 0,
        dt: Double = 0
    ) -> FT8Message? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).uppercased()
        let parts = trimmed.split(separator: " ").map(String.init)

        guard parts.count >= 2 else { return nil }

        // CQ messages: "CQ [DIR] CALL [GRID]"
        if parts[0] == "CQ" {
            return parseCQ(parts: parts, frequency: frequency, snr: snr, dt: dt)
        }

        // Two-callsign messages: "CALL1 CALL2 ..."
        guard parts.count >= 2,
              isCallsign(parts[0]),
              isCallsign(parts[1]) else {
            // Free text fallback
            return FT8Message(
                type: .freeText,
                callsign1: trimmed,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        let call1 = parts[0]
        let call2 = parts[1]

        if parts.count == 2 {
            // "CALL1 CALL2" — minimal exchange
            return FT8Message(
                type: .reply,
                callsign1: call1,
                callsign2: call2,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        let field3 = parts[2]

        // "CALL1 CALL2 RR73"
        if field3 == "RR73" {
            return FT8Message(
                type: .rr73,
                callsign1: call1,
                callsign2: call2,
                extra: "RR73",
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // "CALL1 CALL2 RRR"
        if field3 == "RRR" {
            return FT8Message(
                type: .rr73,
                callsign1: call1,
                callsign2: call2,
                extra: "RRR",
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // "CALL1 CALL2 73"
        if field3 == "73" {
            return FT8Message(
                type: .seventy3,
                callsign1: call1,
                callsign2: call2,
                extra: "73",
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // "CALL1 CALL2 R+/-NN" (roger + report)
        if field3.hasPrefix("R") && field3.count >= 3 {
            let afterR = String(field3.dropFirst())
            if isReport(afterR) {
                return FT8Message(
                    type: .rrReport,
                    callsign1: call1,
                    callsign2: call2,
                    report: field3,
                    frequency: frequency,
                    snr: snr,
                    timeOffset: dt
                )
            }
        }

        // "CALL1 CALL2 +/-NN" (signal report)
        if isReport(field3) {
            return FT8Message(
                type: .report,
                callsign1: call1,
                callsign2: call2,
                report: field3,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // "CALL1 CALL2 GRID" (reply with grid)
        if isGrid(field3) {
            return FT8Message(
                type: .reply,
                callsign1: call1,
                callsign2: call2,
                grid: field3,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // Unrecognized third field — treat as free text
        return FT8Message(
            type: .freeText,
            callsign1: trimmed,
            frequency: frequency,
            snr: snr,
            timeOffset: dt
        )
    }

    /// Parse a decoded 77-bit message into structured fields.
    ///
    /// This is a placeholder for full binary message decoding. The 77-bit payload
    /// encodes message type, packed callsigns (28 bits each), grid/report (various
    /// bit widths), and free text (71 bits for 13 chars).
    ///
    /// - Parameter bits: Array of 77 UInt8 values (0 or 1).
    /// - Returns: A parsed `FT8Message`, or `nil` if decoding fails.
    public static func parse(bits: [UInt8]) -> FT8Message? {
        guard bits.count == FT8Constants.messageBits else { return nil }

        // Extract the 3-bit message type indicator (i3) from bits 74-76
        let i3 = Int(bits[74]) << 2 | Int(bits[75]) << 1 | Int(bits[76])

        // Type 1 (i3=1): Standard message with two callsigns + grid/report
        // Type 0 (i3=0): Free text or other special formats
        // Type 2 (i3=2): EU VHF contest
        // Type 3 (i3=3): ARRL RTTY Roundup
        // Type 4 (i3=4): Non-standard callsigns
        // Type 5 (i3=5): EU VHF contest with 6-char grid
        //
        // Full decoding of packed callsigns requires the 28-bit hash table and
        // base-37 encoding. For now, return nil to indicate binary decoding
        // is not yet implemented — callers should use parse(text:) instead.
        _ = i3

        return nil
    }

    // MARK: - Display

    /// Format the message for display in the waterfall/decode list.
    public var displayText: String {
        switch type {
        case .cq:
            let gridPart = grid.map { " \($0)" } ?? ""
            return "CQ \(callsign1)\(gridPart)"

        case .cqDirected:
            let dir = extra ?? ""
            let gridPart = grid.map { " \($0)" } ?? ""
            return "CQ \(dir) \(callsign1)\(gridPart)"

        case .reply:
            let gridPart = grid.map { " \($0)" } ?? ""
            return "\(callsign1) \(callsign2 ?? "")\(gridPart)"

        case .report:
            return "\(callsign1) \(callsign2 ?? "") \(report ?? "")"

        case .rrReport:
            return "\(callsign1) \(callsign2 ?? "") \(report ?? "")"

        case .rr73:
            return "\(callsign1) \(callsign2 ?? "") \(extra ?? "RR73")"

        case .seventy3:
            return "\(callsign1) \(callsign2 ?? "") 73"

        case .freeText:
            return callsign1
        }
    }

    // MARK: - Private helpers

    private static func parseCQ(
        parts: [String],
        frequency: Double,
        snr: Int,
        dt: Double
    ) -> FT8Message? {
        // "CQ CALL"
        // "CQ CALL GRID"
        // "CQ DIR CALL"
        // "CQ DIR CALL GRID"

        guard parts.count >= 2 else { return nil }

        if parts.count == 2 {
            // "CQ CALL"
            guard isCallsign(parts[1]) else { return nil }
            return FT8Message(
                type: .cq,
                callsign1: parts[1],
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }

        // Check if parts[1] is a directive (DX, NA, EU, etc.) or a callsign
        if isCallsign(parts[1]) {
            // "CQ CALL GRID" or "CQ CALL ???"
            let gridValue = parts.count >= 3 && isGrid(parts[2]) ? parts[2] : nil
            return FT8Message(
                type: .cq,
                callsign1: parts[1],
                grid: gridValue,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        } else {
            // "CQ DIR CALL [GRID]"
            let directive = parts[1]
            guard parts.count >= 3, isCallsign(parts[2]) else { return nil }
            let gridValue = parts.count >= 4 && isGrid(parts[3]) ? parts[3] : nil
            return FT8Message(
                type: .cqDirected,
                callsign1: parts[2],
                grid: gridValue,
                extra: directive,
                frequency: frequency,
                snr: snr,
                timeOffset: dt
            )
        }
    }

    /// Check if a string looks like a ham radio callsign.
    private static func isCallsign(_ s: String) -> Bool {
        // Basic check: 3-10 chars, contains at least one digit and one letter
        guard s.count >= 3 && s.count <= 10 else { return false }
        let hasDigit = s.contains(where: \.isNumber)
        let hasLetter = s.contains(where: \.isLetter)
        return hasDigit && hasLetter
    }

    /// Check if a string is a 4-character Maidenhead grid square.
    private static func isGrid(_ s: String) -> Bool {
        guard s.count == 4 else { return false }
        let chars = Array(s)
        return chars[0].isLetter && chars[1].isLetter
            && chars[2].isNumber && chars[3].isNumber
            && chars[0].asciiValue! >= Character("A").asciiValue!
            && chars[0].asciiValue! <= Character("R").asciiValue!
            && chars[1].asciiValue! >= Character("A").asciiValue!
            && chars[1].asciiValue! <= Character("R").asciiValue!
    }

    /// Check if a string is a signal report (+/-NN format).
    private static func isReport(_ s: String) -> Bool {
        guard s.count == 3 else { return false }
        let first = s.first!
        guard first == "+" || first == "-" else { return false }
        return s.dropFirst().allSatisfy(\.isNumber)
    }
}
