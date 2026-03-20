import Foundation

// MARK: - DXSpot

/// A DX cluster spot representing a reported station on a specific frequency.
public struct DXSpot: Sendable, Identifiable, Equatable {
    /// Unique identifier for this spot.
    public var id: UUID

    /// Callsign of the station that posted the spot.
    public var spotter: String

    /// The DX station that was spotted.
    public var dxCallsign: String

    /// Frequency in kHz.
    public var frequency: Double

    /// Spotter's comment (e.g., "CW 599", "FT8", "UP 5").
    public var comment: String?

    /// UTC time of the spot.
    public var timestamp: Date

    /// Band resolved from the frequency.
    public var band: Band?

    /// Operating mode guessed from frequency or comment, if possible.
    public var mode: OperatingMode?

    public init(
        id: UUID = UUID(),
        spotter: String,
        dxCallsign: String,
        frequency: Double,
        comment: String? = nil,
        timestamp: Date = Date(),
        band: Band? = nil,
        mode: OperatingMode? = nil
    ) {
        self.id = id
        self.spotter = spotter
        self.dxCallsign = dxCallsign
        self.frequency = frequency
        self.comment = comment
        self.timestamp = timestamp
        self.band = band
        self.mode = mode
    }
}

// MARK: - Spot Parsing

extension DXSpot {
    /// Parse a DX cluster spot line in AR-Cluster or DX Spider format.
    ///
    /// AR-Cluster format:
    /// ```
    /// DX de KA1ABC:     14025.0  W1AW         CW 599                   1234Z
    /// ```
    ///
    /// DX Spider format (similar but may have slightly different spacing):
    /// ```
    /// DX de KA1ABC-#:   14025.0  W1AW         CW 599                   1234Z JN48
    /// ```
    ///
    /// Returns nil for non-spot lines (announcements, commands, login prompts, empty lines).
    public static func parse(line: String) -> DXSpot? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must start with "DX de " (case-insensitive)
        guard trimmed.lowercased().hasPrefix("dx de ") else {
            return nil
        }

        // Minimum viable spot line length
        guard trimmed.count >= 40 else {
            return nil
        }

        // Extract spotter callsign (after "DX de " up to the colon)
        let afterPrefix = String(trimmed.dropFirst(6)) // drop "DX de "
        guard let colonIndex = afterPrefix.firstIndex(of: ":") else {
            return nil
        }

        var spotter = String(afterPrefix[afterPrefix.startIndex..<colonIndex])
            .trimmingCharacters(in: .whitespaces)

        // Remove SSID if present (e.g., "KA1ABC-#" -> "KA1ABC")
        // Keep the full spotter ID including SSID for display
        _ = spotter // preserve the original

        // Rest of the line after the colon
        let afterColon = String(afterPrefix[afterPrefix.index(after: colonIndex)...])
            .trimmingCharacters(in: .whitespaces)

        // Split remaining by whitespace
        let components = afterColon.split(
            separator: " ",
            omittingEmptySubsequences: true
        ).map(String.init)

        // Need at least frequency and DX callsign
        guard components.count >= 2 else {
            return nil
        }

        // First component: frequency in kHz
        guard let frequency = Double(components[0]) else {
            return nil
        }

        // Second component: DX callsign
        let dxCallsign = components[1]

        // Validate DX callsign looks like a callsign (basic check)
        guard dxCallsign.count >= 3,
              dxCallsign.rangeOfCharacter(from: .decimalDigits) != nil,
              dxCallsign.rangeOfCharacter(from: .letters) != nil
        else {
            return nil
        }

        // Remaining components: comment and timestamp
        var comment: String?
        var timestamp = Date()

        if components.count > 2 {
            // Look for timestamp at the end (format: 1234Z or 1234z)
            var commentParts: [String] = []
            var foundTimestamp = false

            for i in 2..<components.count {
                let comp = components[i]
                // Check for UTC timestamp pattern: 4 digits followed by Z
                if !foundTimestamp && comp.count == 5 && comp.uppercased().hasSuffix("Z") {
                    let digits = String(comp.dropLast())
                    if digits.allSatisfy(\.isNumber) && digits.count == 4 {
                        // Parse HHMM timestamp
                        if let parsedTime = parseUTCTimestamp(digits) {
                            timestamp = parsedTime
                            foundTimestamp = true
                            continue
                        }
                    }
                }
                commentParts.append(comp)
            }

            if !commentParts.isEmpty {
                comment = commentParts.joined(separator: " ")
            }
        }

        // Resolve band from frequency (kHz -> Hz for Band lookup)
        let frequencyHz = frequency * 1000.0
        let band = Band.band(forFrequency: frequencyHz)

        // Try to guess mode from comment
        let mode = guessMode(from: comment, frequency: frequency)

        return DXSpot(
            spotter: spotter,
            dxCallsign: dxCallsign,
            frequency: frequency,
            comment: comment,
            timestamp: timestamp,
            band: band,
            mode: mode
        )
    }

    /// Parse a UTC timestamp in HHMM format, returning a Date for today at that time.
    private static func parseUTCTimestamp(_ hhmm: String) -> Date? {
        guard hhmm.count == 4 else { return nil }

        let hourStr = String(hhmm.prefix(2))
        let minuteStr = String(hhmm.suffix(2))

        guard let hour = Int(hourStr), let minute = Int(minuteStr),
              hour >= 0, hour <= 23, minute >= 0, minute <= 59
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }

    /// Attempt to guess the operating mode from a spot comment and frequency.
    private static func guessMode(from comment: String?, frequency: Double) -> OperatingMode? {
        if let comment = comment?.uppercased() {
            // Explicit mode mentions
            if comment.contains("FT8") { return .ft8 }
            if comment.contains("FT4") { return .ft4 }
            if comment.contains("CW") { return .cw }
            if comment.contains("RTTY") { return .rtty }
            if comment.contains("PSK31") { return .psk31 }
            if comment.contains("PSK63") { return .psk63 }
            if comment.contains("SSB") { return .ssb }
            if comment.contains("USB") { return .usb }
            if comment.contains("LSB") { return .lsb }
            if comment.contains("FM") { return .fm }
            if comment.contains("AM") { return .am }
            if comment.contains("JS8") { return .js8 }
            if comment.contains("WSPR") { return .wspr }
            if comment.contains("JT65") { return .jt65 }
            if comment.contains("JT9") { return .jt9 }
            if comment.contains("OLIVIA") { return .olivia }
        }

        // Frequency-based guesses for common digital mode sub-bands (kHz)
        // FT8 frequencies
        let ft8Frequencies: [Double] = [1840, 3573, 5357, 7074, 10136, 14074, 18100, 21074, 24915, 28074, 50313]
        for ft8Freq in ft8Frequencies {
            if abs(frequency - ft8Freq) < 3.0 { return .ft8 }
        }

        return nil
    }
}
