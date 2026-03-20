// CabrilloExporter.swift
// HamStationKit — Cabrillo 3.0 contest log format exporter.

import Foundation

// MARK: - CabrilloExporter

/// Exports contest logs in Cabrillo 3.0 format for electronic submission.
///
/// Cabrillo is the standard format accepted by all major contest sponsors
/// (CQ, ARRL, IARU, etc.) for log submission.
///
/// ```
/// START-OF-LOG: 3.0
/// CONTEST: CQWW-CW
/// CALLSIGN: W1AW
/// CATEGORY-OPERATOR: SINGLE-OP
/// ...
/// QSO: 14000 CW 2024-03-15 1430 W1AW 599 05 JA1ABC 599 25
/// END-OF-LOG:
/// ```
public struct CabrilloExporter: Sendable {

    /// A single QSO in Cabrillo format.
    public struct CabrilloQSO: Sendable, Equatable {
        /// Frequency in kHz.
        public var frequency: Int
        /// Mode: CW, PH (phone/SSB), or RY (digital/RTTY).
        public var mode: String
        /// Date string in YYYY-MM-DD format.
        public var date: String
        /// Time string in HHMM format (UTC).
        public var time: String
        /// Operator's callsign.
        public var sentCall: String
        /// Exchange sent.
        public var sentExchange: String
        /// Worked station's callsign.
        public var rcvdCall: String
        /// Exchange received.
        public var rcvdExchange: String

        public init(
            frequency: Int,
            mode: String,
            date: String,
            time: String,
            sentCall: String,
            sentExchange: String,
            rcvdCall: String,
            rcvdExchange: String
        ) {
            self.frequency = frequency
            self.mode = mode
            self.date = date
            self.time = time
            self.sentCall = sentCall
            self.sentExchange = sentExchange
            self.rcvdCall = rcvdCall
            self.rcvdExchange = rcvdExchange
        }
    }

    /// Export a complete Cabrillo 3.0 log file.
    ///
    /// - Parameters:
    ///   - contest: Contest ID (e.g., "CQWW-CW").
    ///   - callsign: Operator's callsign.
    ///   - category: Operator category (e.g., "SINGLE-OP").
    ///   - power: Power category (e.g., "LOW", "HIGH", "QRP").
    ///   - assisted: Whether operating was assisted.
    ///   - band: Band category ("ALL" or specific band).
    ///   - mode: Mode category ("CW", "SSB", "MIXED").
    ///   - operators: List of operator callsigns.
    ///   - claimedScore: The claimed score.
    ///   - club: Optional club name.
    ///   - location: Optional location (ARRL section or "DX").
    ///   - qsos: Array of QSOs to include.
    /// - Returns: Complete Cabrillo 3.0 formatted string.
    public static func export(
        contest: String,
        callsign: String,
        category: String,
        power: String,
        assisted: Bool,
        band: String?,
        mode: String?,
        operators: [String],
        claimedScore: Int,
        club: String?,
        location: String?,
        qsos: [CabrilloQSO]
    ) -> String {
        var lines: [String] = []

        lines.append("START-OF-LOG: 3.0")
        lines.append("CONTEST: \(contest)")
        lines.append("CALLSIGN: \(callsign)")
        lines.append("CATEGORY-OPERATOR: \(category)")
        lines.append("CATEGORY-ASSISTED: \(assisted ? "ASSISTED" : "NON-ASSISTED")")
        lines.append("CATEGORY-POWER: \(power)")

        if let band {
            lines.append("CATEGORY-BAND: \(band)")
        }
        if let mode {
            lines.append("CATEGORY-MODE: \(mode)")
        }

        lines.append("CLAIMED-SCORE: \(claimedScore)")

        if let club, !club.isEmpty {
            lines.append("CLUB: \(club)")
        }
        if let location, !location.isEmpty {
            lines.append("LOCATION: \(location)")
        }

        lines.append("CREATED-BY: HamStationPro 1.0")

        if !operators.isEmpty {
            lines.append("OPERATORS: \(operators.joined(separator: " "))")
        }

        // QSO lines
        for qso in qsos {
            let qsoLine = formatQSOLine(qso)
            lines.append(qsoLine)
        }

        lines.append("END-OF-LOG:")

        return lines.joined(separator: "\n") + "\n"
    }

    /// Format a single QSO line in Cabrillo format.
    ///
    /// Format: `QSO: freq mode date time sent_call sent_exch rcvd_call rcvd_exch`
    static func formatQSOLine(_ qso: CabrilloQSO) -> String {
        let parts = [
            "QSO:",
            String(format: "%5d", qso.frequency),
            String(format: "%-2s", qso.mode),
            qso.date,
            qso.time,
            String(format: "%-13s", qso.sentCall),
            String(format: "%-6s", qso.sentExchange),
            String(format: "%-13s", qso.rcvdCall),
            qso.rcvdExchange
        ]
        return parts.joined(separator: " ")
    }

    // MARK: - Date/Time Formatting

    /// Format a date as YYYY-MM-DD for Cabrillo.
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Format a date as HHMM (UTC) for Cabrillo.
    public static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
