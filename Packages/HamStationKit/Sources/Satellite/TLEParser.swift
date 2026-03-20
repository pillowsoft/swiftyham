// TLEParser.swift
// HamStationKit — Two-Line Element set parser for satellite orbit data.

import Foundation

// MARK: - TLE

/// A Two-Line Element set describing a satellite's orbital elements.
///
/// TLE format (from Celestrak):
/// ```
/// Line 0: Satellite Name
/// Line 1: 1 NNNNNC NNNNNAAA NNNNN.NNNNNNNN +.NNNNNNNN +NNNNN-N +NNNNN-N N NNNNN
/// Line 2: 2 NNNNN NNN.NNNN NNN.NNNN NNNNNNN NNN.NNNN NNN.NNNN NN.NNNNNNNNNNNNNN
/// ```
public struct TLE: Sendable, Identifiable, Equatable {
    /// NORAD catalog number.
    public let id: Int
    /// Satellite name from line 0.
    public var name: String
    /// Raw TLE line 1.
    public var line1: String
    /// Raw TLE line 2.
    public var line2: String

    // Parsed orbital elements from line 2:

    /// Orbital inclination in degrees.
    public var inclination: Double
    /// Right ascension of ascending node in degrees.
    public var raan: Double
    /// Orbital eccentricity (dimensionless, 0-1).
    public var eccentricity: Double
    /// Argument of perigee in degrees.
    public var argOfPerigee: Double
    /// Mean anomaly in degrees.
    public var meanAnomaly: Double
    /// Mean motion in revolutions per day.
    public var meanMotion: Double
    /// Epoch year (2-digit in TLE, stored as 4-digit).
    public var epochYear: Int
    /// Epoch day of year (fractional).
    public var epochDay: Double
    /// BSTAR drag term (1/earth radii).
    public var bstar: Double
    /// Revolution number at epoch.
    public var revolutionNumber: Int

    /// The epoch as a `Date`.
    public var epoch: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = epochYear
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let jan1 = calendar.date(from: components) else { return Date.distantPast }
        // epochDay is 1-based fractional day of year
        return jan1.addingTimeInterval((epochDay - 1.0) * 86400.0)
    }
}

// MARK: - TLEParser

/// Parses Two-Line Element set text into `TLE` values.
public struct TLEParser: Sendable {

    /// Parse a multi-satellite TLE file (Celestrak 3-line format).
    ///
    /// Each satellite occupies 3 lines: name, line 1, line 2.
    /// Blank lines and lines starting with `#` are skipped.
    public static func parse(text: String) -> [TLE] {
        let rawLines = text.components(separatedBy: .newlines)
        // Filter out blank lines and comments
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        var results: [TLE] = []
        var index = 0

        while index + 2 < lines.count {
            let candidate0 = lines[index]
            let candidate1 = lines[index + 1]
            let candidate2 = lines[index + 2]

            // Check if candidate1 starts with "1 " and candidate2 starts with "2 "
            if candidate1.hasPrefix("1 ") && candidate2.hasPrefix("2 ") {
                if let tle = parseSingle(name: candidate0, line1: candidate1, line2: candidate2) {
                    results.append(tle)
                }
                index += 3
            } else {
                // Skip malformed entries
                index += 1
            }
        }

        return results
    }

    /// Parse a single TLE from its three components.
    ///
    /// - Parameters:
    ///   - name: Satellite name (line 0).
    ///   - line1: TLE line 1 (starts with "1 ").
    ///   - line2: TLE line 2 (starts with "2 ").
    /// - Returns: A parsed `TLE`, or `nil` if the input is malformed.
    public static func parseSingle(name: String, line1: String, line2: String) -> TLE? {
        // Validate line lengths (standard TLE is 69 chars per line)
        guard line1.count >= 69, line2.count >= 69 else { return nil }
        guard line1.hasPrefix("1 "), line2.hasPrefix("2 ") else { return nil }

        let l1 = Array(line1)
        let l2 = Array(line2)

        // Line 1: NORAD catalog number (columns 3-7)
        guard let catalogNumber = Int(String(l1[2...6]).trimmingCharacters(in: .whitespaces)) else { return nil }

        // Epoch year (columns 19-20) and epoch day (columns 21-32)
        guard let epochYr = Int(String(l1[18...19]).trimmingCharacters(in: .whitespaces)) else { return nil }
        guard let epochDy = Double(String(l1[20...31]).trimmingCharacters(in: .whitespaces)) else { return nil }

        // BSTAR drag term (columns 54-61): format +NNNNN-N means 0.NNNNN * 10^-N
        let bstarStr = String(l1[53...60]).trimmingCharacters(in: .whitespaces)
        let bstar = parseExponentialNotation(bstarStr)

        // Convert 2-digit year to 4-digit
        let fullYear = epochYr < 57 ? 2000 + epochYr : 1900 + epochYr

        // Line 2 parsing
        // Inclination (columns 9-16)
        guard let inclination = Double(String(l2[8...15]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // RAAN (columns 18-25)
        guard let raan = Double(String(l2[17...24]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // Eccentricity (columns 27-33): implied leading decimal point
        guard let eccRaw = Double("0." + String(l2[26...32]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // Argument of perigee (columns 35-42)
        guard let argPerigee = Double(String(l2[34...41]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // Mean anomaly (columns 44-51)
        guard let meanAnomaly = Double(String(l2[43...50]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // Mean motion (columns 53-63)
        guard let meanMotion = Double(String(l2[52...62]).trimmingCharacters(in: .whitespaces)) else { return nil }
        // Revolution number at epoch (columns 64-68)
        let revNumber = Int(String(l2[63...67]).trimmingCharacters(in: .whitespaces)) ?? 0

        return TLE(
            id: catalogNumber,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            line1: line1,
            line2: line2,
            inclination: inclination,
            raan: raan,
            eccentricity: eccRaw,
            argOfPerigee: argPerigee,
            meanAnomaly: meanAnomaly,
            meanMotion: meanMotion,
            epochYear: fullYear,
            epochDay: epochDy,
            bstar: bstar,
            revolutionNumber: revNumber
        )
    }

    // MARK: - Private Helpers

    /// Parse TLE exponential notation like "+12345-6" or "-12345+6" into a Double.
    ///
    /// Format: `±NNNNN±E` where the value is `±0.NNNNN * 10^(±E)`.
    static func parseExponentialNotation(_ str: String) -> Double {
        var s = str.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return 0.0 }

        // Handle leading sign
        var sign: Double = 1.0
        if s.first == "-" {
            sign = -1.0
            s = String(s.dropFirst())
        } else if s.first == "+" || s.first == " " {
            s = String(s.dropFirst())
        }

        // Find the exponent sign (last +/- that's not the first character)
        var mantissaStr = s
        var exponent: Double = 0.0

        // Look for +/- in the remaining string (exponent delimiter)
        if let lastSign = s.lastIndex(where: { $0 == "+" || $0 == "-" }), lastSign > s.startIndex {
            mantissaStr = String(s[s.startIndex..<lastSign])
            let expStr = String(s[lastSign...])
            exponent = Double(expStr) ?? 0.0
        }

        guard let mantissa = Double("0." + mantissaStr) else { return 0.0 }
        return sign * mantissa * pow(10.0, exponent)
    }
}
