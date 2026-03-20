// ADIFDateFormatter.swift
// HamStationKit — ADIF 3.1 Parser & Exporter
//
// Utility for converting between ADIF date/time strings and Foundation types.

import Foundation

/// Converts between ADIF date/time string formats and Foundation date types.
///
/// ADIF dates use the format `YYYYMMDD` (8 characters).
/// ADIF times use `HHMMSS` (6 characters) or `HHMM` (4 characters).
/// All times are UTC.
public enum ADIFDateFormatter: Sendable {

    // MARK: - Parsing

    /// Parses an ADIF date string (`YYYYMMDD`) into `DateComponents`.
    ///
    /// Returns `nil` if the string is not exactly 8 digits or contains
    /// out-of-range values.
    public static func parseDate(_ string: String) -> DateComponents? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 8, trimmed.allSatisfy(\.isASCIIDigit) else {
            return nil
        }

        let yearStr = trimmed.prefix(4)
        let monthStr = trimmed.dropFirst(4).prefix(2)
        let dayStr = trimmed.dropFirst(6).prefix(2)

        guard let year = Int(yearStr),
              let month = Int(monthStr),
              let day = Int(dayStr) else {
            return nil
        }

        // Basic range validation
        guard (1...12).contains(month), (1...31).contains(day), year >= 1900 else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "UTC")
        components.year = year
        components.month = month
        components.day = day
        return components
    }

    /// Parses an ADIF time string (`HHMMSS` or `HHMM`) into `DateComponents`.
    ///
    /// Returns `nil` if the format is invalid or values are out of range.
    public static func parseTime(_ string: String) -> DateComponents? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 4 || trimmed.count == 6,
              trimmed.allSatisfy(\.isASCIIDigit) else {
            return nil
        }

        let hourStr = trimmed.prefix(2)
        let minuteStr = trimmed.dropFirst(2).prefix(2)

        guard let hour = Int(hourStr),
              let minute = Int(minuteStr) else {
            return nil
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "UTC")
        components.hour = hour
        components.minute = minute

        if trimmed.count == 6 {
            let secondStr = trimmed.dropFirst(4).prefix(2)
            guard let second = Int(secondStr), (0...59).contains(second) else {
                return nil
            }
            components.second = second
        } else {
            components.second = 0
        }

        return components
    }

    /// Parses an ADIF date and time pair into a UTC `Date`.
    ///
    /// - Parameters:
    ///   - date: An ADIF date string (`YYYYMMDD`).
    ///   - time: An ADIF time string (`HHMMSS` or `HHMM`).
    /// - Returns: A `Date` in UTC, or `nil` if either string is invalid.
    public static func parseDateTime(date: String, time: String) -> Date? {
        guard let dateComponents = parseDate(date),
              let timeComponents = parseTime(time) else {
            return nil
        }

        var combined = DateComponents()
        combined.calendar = Calendar(identifier: .gregorian)
        combined.timeZone = TimeZone(identifier: "UTC")
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        return combined.date
    }

    // MARK: - Formatting

    /// Formats a `Date` as an ADIF date string (`YYYYMMDD`) in UTC.
    public static func formatDate(_ date: Date) -> String {
        let cal = calendar
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        return String(format: "%04d%02d%02d", year, month, day)
    }

    /// Formats a `Date` as an ADIF time string in UTC.
    ///
    /// - Parameters:
    ///   - date: The date to format.
    ///   - includeSeconds: If `true` (default), produces `HHMMSS`; otherwise `HHMM`.
    public static func formatTime(_ date: Date, includeSeconds: Bool = true) -> String {
        let cal = calendar
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        if includeSeconds {
            let second = cal.component(.second, from: date)
            return String(format: "%02d%02d%02d", hour, minute, second)
        }
        return String(format: "%02d%02d", hour, minute)
    }

    // MARK: - Private

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
}

// MARK: - Character extension for digit checking

extension Character {
    fileprivate var isASCIIDigit: Bool {
        ("0"..."9").contains(self)
    }
}
