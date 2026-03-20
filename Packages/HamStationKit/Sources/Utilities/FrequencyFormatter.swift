// FrequencyFormatter.swift
// HamStationKit — Utility for displaying frequencies in ham radio conventions.

import Foundation

/// Utility for formatting and parsing radio frequencies.
///
/// Ham radio conventions display frequencies in different units depending on context:
/// - Hz with dot separators for precise display (e.g., "14.074.000")
/// - MHz with 3 decimal places for band references (e.g., "14.074")
/// - kHz with 1 decimal place for VFO displays (e.g., "14074.0")
public struct FrequencyFormatter: Sendable {

    // MARK: - Formatting

    /// Format a frequency in Hz with dot separators.
    ///
    /// Example: `14074000` -> `"14.074.000"`
    public static func format(hz: Double) -> String {
        let intHz = Int(hz.rounded())
        guard intHz > 0 else { return "0" }

        let str = String(intHz)
        var result = ""
        let reversed = Array(str.reversed())
        for (index, char) in reversed.enumerated() {
            if index > 0 && index % 3 == 0 {
                result = "." + result
            }
            result = String(char) + result
        }
        return result
    }

    /// Format a frequency in Hz as MHz with 3 decimal places.
    ///
    /// Example: `14074000` -> `"14.074"`
    public static func formatMHz(hz: Double) -> String {
        let mhz = hz / 1_000_000.0
        return String(format: "%.3f", mhz)
    }

    /// Format a frequency in Hz as kHz with 1 decimal place.
    ///
    /// Example: `14074000` -> `"14074.0"`
    public static func formatKHz(hz: Double) -> String {
        let khz = hz / 1_000.0
        return String(format: "%.1f", khz)
    }

    // MARK: - Parsing

    /// Parse a frequency string to Hz.
    ///
    /// Accepts multiple formats using a simple heuristic:
    /// - Values less than 1,000: interpreted as MHz (e.g., "14.074" -> 14074000 Hz)
    /// - Values between 1,000 and 1,000,000: interpreted as kHz (e.g., "14074" -> 14074000 Hz)
    /// - Values >= 1,000,000: interpreted as Hz (e.g., "14074000" -> 14074000 Hz)
    ///
    /// Also handles dot-separated Hz format by stripping dots if the result makes sense.
    ///
    /// - Returns: Frequency in Hz, or nil if the string cannot be parsed.
    public static func parse(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try stripping dots for the "14.074.000" format
        // Count dots: if more than 1, it's dot-separated Hz
        let dotCount = trimmed.filter { $0 == "." }.count
        if dotCount > 1 {
            let stripped = trimmed.replacingOccurrences(of: ".", with: "")
            if let value = Double(stripped) {
                return value
            }
        }

        // Parse as a number
        guard let value = Double(trimmed) else { return nil }
        guard value > 0 else { return nil }

        if value < 1_000 {
            // Interpret as MHz
            return value * 1_000_000.0
        } else if value < 1_000_000 {
            // Interpret as kHz
            return value * 1_000.0
        } else {
            // Already in Hz
            return value
        }
    }
}
