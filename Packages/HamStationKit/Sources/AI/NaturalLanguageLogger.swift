// NaturalLanguageLogger.swift
// HamStationKit — Parses natural language into structured QSO data.
// Runs entirely on-device. No cloud data sent.

import Foundation

/// Parses spoken or typed natural language into structured QSO fields.
///
/// Examples:
/// - "Just worked W1AW on 20 meters FT8, he was minus 10 and I was minus 8"
/// - "Worked JA1ABC on 40 CW, 599 both ways"
/// - "VK2RZA on fifteen meters SSB, 5-9 sent, 5-7 received"
public struct NaturalLanguageLogger: Sendable {

    // MARK: - Parsed QSO

    /// The result of parsing natural language input into QSO fields.
    public struct ParsedQSO: Sendable, Equatable {
        public var callsign: String?
        public var band: String?
        public var mode: String?
        public var rstSent: String?
        public var rstReceived: String?
        public var frequency: Double?
        public var name: String?
        public var comment: String?
        /// How confident the parse is, from 0 (no useful data) to 1 (all fields found).
        public var confidence: Double
        /// The original input text.
        public var rawInput: String

        public init(
            callsign: String? = nil,
            band: String? = nil,
            mode: String? = nil,
            rstSent: String? = nil,
            rstReceived: String? = nil,
            frequency: Double? = nil,
            name: String? = nil,
            comment: String? = nil,
            confidence: Double = 0,
            rawInput: String = ""
        ) {
            self.callsign = callsign
            self.band = band
            self.mode = mode
            self.rstSent = rstSent
            self.rstReceived = rstReceived
            self.frequency = frequency
            self.name = name
            self.comment = comment
            self.confidence = confidence
            self.rawInput = rawInput
        }
    }

    // MARK: - Parse

    /// Parse a natural language string into structured QSO fields.
    ///
    /// - Parameter input: Spoken or typed text describing a QSO.
    /// - Returns: A ``ParsedQSO`` with extracted fields and a confidence score.
    public static func parse(_ input: String) -> ParsedQSO {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ParsedQSO(confidence: 0, rawInput: input)
        }

        let normalized = input.uppercased()

        var result = ParsedQSO(rawInput: input)
        var fieldsFound = 0

        // Extract callsign
        if let callsign = extractCallsign(from: normalized) {
            result.callsign = callsign
            fieldsFound += 1
        }

        // Extract band
        if let band = extractBand(from: normalized) {
            result.band = band
            fieldsFound += 1
        }

        // Extract mode
        if let mode = extractMode(from: normalized) {
            result.mode = mode
            fieldsFound += 1
        }

        // Extract RST reports
        let (sent, received) = extractRST(from: normalized)
        if let s = sent {
            result.rstSent = s
            fieldsFound += 1
        }
        if let r = received {
            result.rstReceived = r
            fieldsFound += 1
        }

        // Extract frequency (e.g., "14.074" or "14074 kHz")
        if let freq = extractFrequency(from: normalized) {
            result.frequency = freq
            fieldsFound += 1
        }

        // Confidence: ratio of fields found to maximum expected fields (5 core fields)
        let maxFields = 5.0
        result.confidence = min(Double(fieldsFound) / maxFields, 1.0)

        // If no callsign found, confidence is very low
        if result.callsign == nil {
            result.confidence = min(result.confidence, 0.1)
        }

        return result
    }

    // MARK: - Callsign Extraction

    /// Extract an amateur radio callsign from the input.
    /// Pattern: 1-3 alphanumeric prefix, 1 digit, 1-4 letter suffix.
    static func extractCallsign(from input: String) -> String? {
        // Amateur callsign pattern: [A-Z0-9]{1,3}[0-9][A-Z]{1,4}
        // Optionally with /portable or /mobile suffixes
        let pattern = #"\b([A-Z]{1,2}[0-9][A-Z0-9]?[0-9][A-Z]{1,4}|[A-Z0-9]{1,3}[0-9][A-Z]{1,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input) else {
            return nil
        }

        let callsign = String(input[range])
        // Filter out things that look like band references (e.g., "20M", "40M")
        if callsign.count <= 3 {
            return nil
        }
        return callsign
    }

    // MARK: - Band Extraction

    /// Band name word-to-meters mapping.
    private static let bandNameMap: [(pattern: String, band: String)] = [
        ("ONE SIXTY", "160m"), ("ONE HUNDRED SIXTY", "160m"), ("160 METER", "160m"), ("160M", "160m"),
        ("EIGHTY", "80m"), ("80 METER", "80m"), ("80M", "80m"),
        ("SIXTY", "60m"), ("60 METER", "60m"), ("60M", "60m"),
        ("FORTY", "40m"), ("40 METER", "40m"), ("40M", "40m"),
        ("THIRTY", "30m"), ("30 METER", "30m"), ("30M", "30m"),
        ("TWENTY", "20m"), ("20 METER", "20m"), ("20M", "20m"),
        ("SEVENTEEN", "17m"), ("17 METER", "17m"), ("17M", "17m"),
        ("FIFTEEN", "15m"), ("15 METER", "15m"), ("15M", "15m"),
        ("TWELVE", "12m"), ("12 METER", "12m"), ("12M", "12m"),
        ("TEN METER", "10m"), ("10 METER", "10m"), ("10M", "10m"),
        ("SIX METER", "6m"), ("6 METER", "6m"), ("6M", "6m"),
        ("TWO METER", "2m"), ("2 METER", "2m"), ("2M", "2m"),
    ]

    /// Extract band from natural language input.
    static func extractBand(from input: String) -> String? {
        // Check word-based names first (longest match first — they're ordered by specificity)
        for entry in bandNameMap {
            if input.contains(entry.pattern) {
                return entry.band
            }
        }

        // Try standalone "TEN" — must be careful not to match in other words
        if matchesWord(input, "TEN") {
            return "10m"
        }

        return nil
    }

    /// Check if a word appears as a standalone word in the input.
    private static func matchesWord(_ input: String, _ word: String) -> Bool {
        let pattern = "\\b\(word)\\b"
        return input.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Mode Extraction

    /// Mode keyword-to-canonical mapping.
    private static let modeMap: [(pattern: String, mode: String)] = [
        ("FT8", "FT8"),
        ("FT4", "FT4"),
        ("JS8", "JS8"),
        ("JT65", "JT65"),
        ("JT9", "JT9"),
        ("WSPR", "WSPR"),
        ("PSK31", "PSK31"),
        ("PSK63", "PSK63"),
        ("RTTY", "RTTY"),
        ("OLIVIA", "OLIVIA"),
        ("SSTV", "SSTV"),
        ("DSTAR", "DSTAR"),
        ("DMR", "DMR"),
        ("C4FM", "C4FM"),
        ("SSB", "SSB"),
        ("USB", "USB"),
        ("LSB", "LSB"),
        ("AM", "AM"),
        ("FM", "FM"),
        ("CW", "CW"),
        ("PHONE", "SSB"),
        ("DIGITAL", "FT8"),
    ]

    /// Extract operating mode from natural language input.
    static func extractMode(from input: String) -> String? {
        for entry in modeMap {
            if matchesWord(input, entry.pattern) {
                return entry.mode
            }
        }
        return nil
    }

    // MARK: - RST Extraction

    /// Spoken number-to-digit mapping for RST reports.
    private static let spokenDigits: [(String, String)] = [
        ("ZERO", "0"), ("ONE", "1"), ("TWO", "2"), ("THREE", "3"),
        ("FOUR", "4"), ("FIVE", "5"), ("SIX", "6"), ("SEVEN", "7"),
        ("EIGHT", "8"), ("NINE", "9"),
    ]

    /// Extract RST sent and received from natural language.
    ///
    /// Handles formats:
    /// - "5-9 sent, 5-7 received"
    /// - "59 sent 57 received"
    /// - "five nine both ways"
    /// - "599 both ways"
    /// - "minus 10" / "-10" (digital signal reports)
    /// - "he was minus 10 and I was minus 8"
    static func extractRST(from input: String) -> (sent: String?, received: String?) {
        var workingInput = input

        // Replace spoken digits with numeric equivalents
        for (word, digit) in spokenDigits {
            workingInput = workingInput.replacingOccurrences(
                of: "\\b\(word)\\b",
                with: digit,
                options: .regularExpression
            )
        }

        // Check for "both ways" / "same" pattern first
        let bothWaysPatterns = ["BOTH WAYS", "BOTH DIRECTIONS", "SAME BOTH", "SAME REPORT"]
        let hasBothWays = bothWaysPatterns.contains { workingInput.contains($0) }

        if hasBothWays {
            // Find the single RST report and apply it both ways
            if let rst = extractSingleRST(from: workingInput) {
                return (rst, rst)
            }
        }

        // "he/she/they was/were X and I was Y" pattern — received first, sent second
        let heIPattern = #"(?:HE|SHE|THEY)\s+(?:WAS|WERE|GAVE ME)\s+(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?)\s+.*?(?:I\s+(?:WAS|GAVE)\s+(?:HIM|HER|THEM)?)\s*(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?)"#
        if let regex = try? NSRegularExpression(pattern: heIPattern),
           let match = regex.firstMatch(in: workingInput, range: NSRange(workingInput.startIndex..., in: workingInput)) {
            let receivedRaw = extractMatchGroup(workingInput, match: match, group: 1)
            let sentRaw = extractMatchGroup(workingInput, match: match, group: 2)
            return (normalizeRST(sentRaw), normalizeRST(receivedRaw))
        }

        // "X sent, Y received" or "X sent Y received" pattern
        let sentRecvPattern = #"(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?)\s*SENT.*?(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?)\s*(?:RECEIVED|RCVD|RECV)"#
        if let regex = try? NSRegularExpression(pattern: sentRecvPattern),
           let match = regex.firstMatch(in: workingInput, range: NSRange(workingInput.startIndex..., in: workingInput)) {
            let sentRaw = extractMatchGroup(workingInput, match: match, group: 1)
            let recvRaw = extractMatchGroup(workingInput, match: match, group: 2)
            return (normalizeRST(sentRaw), normalizeRST(recvRaw))
        }

        // "sent X received Y" pattern
        let sentXRecvYPattern = #"SENT\s*(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?).*?(?:RECEIVED|RCVD|RECV)\s*(MINUS\s*\d+|-\d+|\d[\-\s]?\d(?:[\-\s]?\d)?)"#
        if let regex = try? NSRegularExpression(pattern: sentXRecvYPattern),
           let match = regex.firstMatch(in: workingInput, range: NSRange(workingInput.startIndex..., in: workingInput)) {
            let sentRaw = extractMatchGroup(workingInput, match: match, group: 1)
            let recvRaw = extractMatchGroup(workingInput, match: match, group: 2)
            return (normalizeRST(sentRaw), normalizeRST(recvRaw))
        }

        // If we find exactly two RST-like values, first is sent second is received
        let rstValues = findAllRST(in: workingInput)
        if rstValues.count >= 2 {
            return (normalizeRST(rstValues[0]), normalizeRST(rstValues[1]))
        }

        // Single RST found — can't determine direction
        if rstValues.count == 1 {
            return (normalizeRST(rstValues[0]), nil)
        }

        return (nil, nil)
    }

    /// Extract a single RST value from text.
    private static func extractSingleRST(from input: String) -> String? {
        // Digital report: "minus X" or "-X"
        let digitalPattern = #"(?:MINUS\s*(\d+)|-(\d+))"#
        if let regex = try? NSRegularExpression(pattern: digitalPattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            if let range = Range(match.range(at: 1), in: input) {
                return "-" + String(format: "%02d", Int(input[range]) ?? 0)
            }
            if let range = Range(match.range(at: 2), in: input) {
                return "-" + String(format: "%02d", Int(input[range]) ?? 0)
            }
        }

        // Standard RST: "5-9" / "59" / "599"
        let rstPattern = #"\b(\d)[\-\s]?(\d)(?:[\-\s]?(\d))?\b"#
        if let regex = try? NSRegularExpression(pattern: rstPattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            return normalizeRSTMatch(input, match: match)
        }

        return nil
    }

    /// Find all RST-like values in the input string.
    private static func findAllRST(in input: String) -> [String] {
        var results: [String] = []

        // Digital reports: "MINUS X" or "-X"
        let digitalPattern = #"(?:MINUS\s*(\d+)|-(\d+))"#
        if let regex = try? NSRegularExpression(pattern: digitalPattern) {
            let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            for match in matches {
                if let range = Range(match.range(at: 1), in: input) {
                    results.append("MINUS " + String(input[range]))
                } else if let range = Range(match.range(at: 2), in: input) {
                    results.append("-" + String(input[range]))
                }
            }
        }

        if !results.isEmpty { return results }

        // Standard RST: "5-9", "59", "599"
        let rstPattern = #"\b(\d[\-\s]?\d(?:[\-\s]?\d)?)\b"#
        if let regex = try? NSRegularExpression(pattern: rstPattern) {
            let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            for match in matches {
                if let range = Range(match.range(at: 1), in: input) {
                    let value = String(input[range])
                    // Filter out things that are likely band numbers or frequencies
                    let stripped = value.replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    if stripped.count >= 2, stripped.count <= 3,
                       let first = stripped.first, first >= "1" && first <= "5" {
                        results.append(value)
                    }
                }
            }
        }

        return results
    }

    /// Normalize an RST string to canonical form.
    /// "5-9" → "59", "5 9" → "59", "MINUS 10" → "-10"
    static func normalizeRST(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // Digital report
        if trimmed.hasPrefix("MINUS") {
            let digits = trimmed.replacingOccurrences(of: "MINUS", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let val = Int(digits) {
                return "-" + String(format: "%02d", val)
            }
        }
        if trimmed.hasPrefix("-") {
            let digits = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            if let val = Int(digits) {
                return "-" + String(format: "%02d", val)
            }
        }

        // Standard RST: strip dashes and spaces
        let cleaned = trimmed.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        if cleaned.count >= 2, cleaned.count <= 3, cleaned.allSatisfy(\.isNumber) {
            return cleaned
        }

        return nil
    }

    /// Extract a matched group from an NSTextCheckingResult.
    private static func extractMatchGroup(_ input: String, match: NSTextCheckingResult, group: Int) -> String? {
        guard group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: input) else {
            return nil
        }
        return String(input[range])
    }

    /// Normalize an RST from a regex match with digit groups.
    private static func normalizeRSTMatch(_ input: String, match: NSTextCheckingResult) -> String? {
        var rst = ""
        if let r1 = Range(match.range(at: 1), in: input) { rst += input[r1] }
        if let r2 = Range(match.range(at: 2), in: input) { rst += input[r2] }
        if match.numberOfRanges > 3, let r3 = Range(match.range(at: 3), in: input) { rst += input[r3] }
        return rst.isEmpty ? nil : rst
    }

    // MARK: - Frequency Extraction

    /// Extract a frequency from the input (e.g., "14.074", "14074 kHz").
    static func extractFrequency(from input: String) -> Double? {
        // "14.074 MHz" or just "14.074"
        let mhzPattern = #"(\d{1,3}\.\d{1,6})\s*(?:MHZ|MEGAHERTZ)?"#
        if let regex = try? NSRegularExpression(pattern: mhzPattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           let range = Range(match.range(at: 1), in: input),
           let mhz = Double(input[range]),
           mhz >= 1.8, mhz <= 1300 {
            return mhz
        }

        // "14074 kHz"
        let khzPattern = #"(\d{3,6})\s*KHZ"#
        if let regex = try? NSRegularExpression(pattern: khzPattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           let range = Range(match.range(at: 1), in: input),
           let khz = Double(input[range]) {
            let mhz = khz / 1000.0
            if mhz >= 1.8, mhz <= 1300 {
                return mhz
            }
        }

        return nil
    }
}
