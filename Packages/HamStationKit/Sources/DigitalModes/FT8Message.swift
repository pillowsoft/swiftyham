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
    /// Parse a decoded 77-bit message into structured fields.
    ///
    /// Implements the FT8 message packing format from WSJT-X.
    /// Reference: Steven Franke K9AN, Bill Somerville G4WJS — "The FT4 and FT8 Communication Protocols"
    ///
    /// - Parameter bits: Array of 77 UInt8 values (0 or 1).
    /// - Returns: A parsed `FT8Message`, or `nil` if decoding fails.
    public static func parse(bits: [UInt8]) -> FT8Message? {
        guard bits.count == FT8Constants.messageBits else { return nil }

        // Extract the 3-bit message type indicator (i3) from bits 74-76
        let i3 = Int(bits[74]) << 2 | Int(bits[75]) << 1 | Int(bits[76])

        // Also extract n3 (bits 71-73) for i3=0 subtypes
        let n3 = Int(bits[71]) << 2 | Int(bits[72]) << 1 | Int(bits[73])

        switch i3 {
        case 1:
            // Type 1: Standard message — two 28-bit callsigns + R flag + 15-bit grid/report
            return parseType1(bits: bits)
        case 0 where n3 == 0:
            // Type 0.0: Free text (71 bits -> 13 characters)
            return parseFreeText(bits: bits)
        case 4:
            // Type 4: Non-standard callsign (one hashed 12-bit, one 58-bit)
            return parseType4(bits: bits)
        default:
            // Types 2, 3, 5 (contest formats) and other subtypes not yet implemented
            return nil
        }
    }

    // MARK: - Type 1: Standard message

    /// Parse i3=1: Two packed callsigns + grid/report.
    /// Bit layout: c28a(28) + c28b(28) + R(1) + g15(15) + reserved(2) + i3(3) = 77
    private static func parseType1(bits: [UInt8]) -> FT8Message? {
        let c28a = extractBits(bits, start: 0, length: 28)
        let c28b = extractBits(bits, start: 28, length: 28)
        let rFlag = bits[56] == 1
        let g15 = extractBits(bits, start: 57, length: 15)

        guard let call1 = unpackCallsign28(c28a),
              let call2 = unpackCallsign28(c28b) else {
            return nil
        }

        // Decode g15 field
        let (msgType, grid, report, extra) = unpackGrid15(g15, rFlag: rFlag)

        return FT8Message(
            type: msgType,
            callsign1: call1,
            callsign2: call2,
            grid: grid,
            report: report,
            extra: extra,
            frequency: 0,
            snr: 0,
            timeOffset: 0
        )
    }

    // MARK: - Type 0.0: Free text

    /// Parse i3=0, n3=0: Free text (71 bits -> 13 characters from 42-char alphabet).
    private static func parseFreeText(bits: [UInt8]) -> FT8Message? {
        // 71 bits encode up to 13 characters from: " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-./?"
        let freeTextChars = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-./?"
        let charArray = Array(freeTextChars)
        let base = UInt64(charArray.count) // 42

        // Extract 71-bit value
        var value: UInt64 = 0
        for i in 0..<71 {
            value = (value << 1) | UInt64(bits[i])
        }

        // Decode 13 characters (least significant first)
        var text = ""
        var remaining = value
        for _ in 0..<13 {
            let idx = Int(remaining % base)
            remaining /= base
            text = String(charArray[idx]) + text
        }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try to parse as a standard message first
        if let parsed = parse(text: trimmed) {
            return parsed
        }

        return FT8Message(
            type: .freeText,
            callsign1: trimmed,
            frequency: 0,
            snr: 0,
            timeOffset: 0
        )
    }

    // MARK: - Type 4: Non-standard callsign

    /// Parse i3=4: One hashed callsign (12-bit) + one full callsign (58-bit).
    private static func parseType4(bits: [UInt8]) -> FT8Message? {
        // Layout: h12(12) + c58(58) + h1(1) + r2(2) + c1(1) + i3(3) = 77
        // c58 encodes up to 11 characters; h12 is a 12-bit hash of the other callsign
        // Without a hash table we can decode c58 but not resolve h12
        let c58 = extractBitsWide(bits, start: 12, length: 58)

        guard let callsign = unpackCallsign58(c58) else { return nil }

        return FT8Message(
            type: .cq, // Non-standard callsigns are often CQ
            callsign1: callsign,
            frequency: 0,
            snr: 0,
            timeOffset: 0
        )
    }

    // MARK: - Bit Extraction

    /// Extract N bits starting at position `start` as a UInt32.
    private static func extractBits(_ bits: [UInt8], start: Int, length: Int) -> UInt32 {
        var value: UInt32 = 0
        for i in 0..<length {
            value = (value << 1) | UInt32(bits[start + i])
        }
        return value
    }

    /// Extract N bits as a UInt64 (for fields > 32 bits).
    private static func extractBitsWide(_ bits: [UInt8], start: Int, length: Int) -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<length {
            value = (value << 1) | UInt64(bits[start + i])
        }
        return value
    }

    // MARK: - Callsign Packing (28-bit)

    /// The FT8 callsign alphabet: space + A-Z + 0-9 (37 characters).
    /// Callsigns are normalized to 6 characters, then packed as a base-37 number.
    /// Special values: 0 = DE, 1 = QRZ, 2 = CQ, 3-5 = CQ nnn (directed CQ)
    private static let callAlphabet = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    /// Unpack a 28-bit packed callsign to a string.
    ///
    /// FT8 callsign encoding uses mixed-radix packing with the digit forced to position 2:
    /// ```
    /// value = c[0]*36*10*27*27*27 + c[1]*10*27*27*27 + c[2]*27*27*27 + c[3]*27*27 + c[4]*27 + c[5]
    /// ```
    /// where:
    /// - c[0]: " A-Z0-9" (37 values, but space+A-Z+0-9 = 37 → index into `callAlphabet`)
    /// - c[1]: "A-Z0-9" (36 values, no space)
    /// - c[2]: "0-9" (10 values)
    /// - c[3..5]: " A-Z" (27 values)
    ///
    /// Special values < NTOKENS (= 2063592) encode CQ, DE, QRZ, and CQ directed.
    private static func unpackCallsign28(_ packed: UInt32) -> String? {
        let cqToken: UInt32 = 2
        let deToken: UInt32 = 0
        let qrzToken: UInt32 = 1
        let cqDirectedBase: UInt32 = 3

        if packed == deToken { return "DE" }
        if packed == qrzToken { return "QRZ" }
        if packed == cqToken { return "CQ" }

        // CQ directed: 3 to 3 + 999 encodes CQ with 3-digit suffix
        if packed >= cqDirectedBase && packed < cqDirectedBase + 1000 {
            let suffix = packed - cqDirectedBase
            return "CQ \(suffix)"
        }

        let nTokens: UInt32 = 2063592
        let maxCallValue: UInt32 = nTokens + 37 * 36 * 10 * 27 * 27 * 27 - 1
        guard packed >= nTokens && packed <= maxCallValue else { return nil }

        let callValue = packed - nTokens
        var remaining = callValue

        // Unpack right to left using mixed radix: 37, 36, 10, 27, 27, 27
        let c5 = Int(remaining % 27); remaining /= 27
        let c4 = Int(remaining % 27); remaining /= 27
        let c3 = Int(remaining % 27); remaining /= 27
        let c2 = Int(remaining % 10); remaining /= 10
        let c1 = Int(remaining % 36); remaining /= 36
        let c0 = Int(remaining)

        // Character sets per position
        let set0 = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") // 37
        let set1 = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")  // 36
        let set2 = Array("0123456789")                            // 10
        let set35 = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ")          // 27

        guard c0 < set0.count, c1 < set1.count, c2 < set2.count,
              c3 < set35.count, c4 < set35.count, c5 < set35.count else {
            return nil
        }

        let result = String([set0[c0], set1[c1], set2[c2], set35[c3], set35[c4], set35[c5]])
        let callsign = result.trimmingCharacters(in: .whitespaces)
        return callsign.isEmpty ? nil : callsign
    }

    // MARK: - Callsign Packing (58-bit, non-standard)

    /// Unpack a 58-bit packed non-standard callsign (up to 11 characters from base-38).
    private static func unpackCallsign58(_ packed: UInt64) -> String? {
        let chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/"
        let charArray = Array(chars)
        let base: UInt64 = 38

        var remaining = packed
        var result = [Character]()

        for _ in 0..<11 {
            let idx = Int(remaining % base)
            remaining /= base
            result.insert(charArray[idx], at: 0)
        }

        let callsign = String(result).trimmingCharacters(in: .whitespaces)
        return callsign.isEmpty ? nil : callsign
    }

    // MARK: - Grid/Report Packing (15-bit)

    /// Unpack the 15-bit grid/report field.
    ///
    /// The g15 field encodes one of:
    /// - Maidenhead grid (4-char): values 2-32400 (180*180 grid squares)
    /// - Signal report: values 32401+ encode -30 to +30 dB
    /// - RR73/RRR/73: special values
    ///
    /// - Parameters:
    ///   - g15: The 15-bit field value (0-32767).
    ///   - rFlag: The R (roger) flag bit.
    /// - Returns: Tuple of (messageType, grid?, report?, extra?).
    private static func unpackGrid15(
        _ g15: UInt32,
        rFlag: Bool
    ) -> (MessageType, String?, String?, String?) {

        // Special tokens
        if g15 == 1 {
            return (.rr73, nil, nil, "RR73")
        }
        if g15 == 2 {
            return (.rr73, nil, nil, "RRR")
        }
        if g15 == 3 {
            return (.seventy3, nil, nil, "73")
        }

        // Grid square: 4 <= g15 <= 32400+3
        if g15 >= 4 && g15 <= 32403 {
            let gridVal = Int(g15) - 4
            let lonIdx = gridVal / 180
            let latIdx = gridVal % 180

            let lonField = Character(UnicodeScalar(65 + lonIdx / 10)!)
            let latField = Character(UnicodeScalar(65 + latIdx / 10)!)
            let lonSquare = lonIdx % 10
            let latSquare = latIdx % 10

            let grid = "\(lonField)\(latField)\(lonSquare)\(latSquare)"

            if rFlag {
                return (.rrReport, nil, "R\(grid)", nil)
            }
            return (.reply, grid, nil, nil)
        }

        // Signal report: g15 >= 32404
        if g15 >= 32404 {
            let reportVal = Int(g15) - 32404 - 30 // -30 to +30
            let reportStr: String
            if reportVal >= 0 {
                reportStr = String(format: "+%02d", reportVal)
            } else {
                reportStr = String(format: "%03d", reportVal)
            }

            if rFlag {
                return (.rrReport, nil, "R\(reportStr)", nil)
            }
            return (.report, nil, reportStr, nil)
        }

        // g15 == 0: blank/unknown
        return (.reply, nil, nil, nil)
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
