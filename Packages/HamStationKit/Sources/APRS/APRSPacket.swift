// APRSPacket.swift
// HamStationKit — APRS packet parser.
//
// APRS format: SOURCE>DESTINATION,PATH:DATA
// Example: "N0CALL>APRS,TCPIP*:=4903.50N/07201.75W-PHG2360/Hello"

import Foundation

// MARK: - APRSPacket

/// A parsed APRS (Automatic Packet Reporting System) packet.
public struct APRSPacket: Sendable, Identifiable, Equatable {
    public let id: UUID
    /// Source callsign with optional SSID (e.g., "N0CALL-9").
    public var source: String
    /// Destination address.
    public var destination: String
    /// Digipeater path components.
    public var path: [String]
    /// Parsed data type and payload.
    public var dataType: DataType
    /// Raw data field (everything after the colon).
    public var rawData: String
    /// Timestamp of when the packet was received/parsed.
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        source: String,
        destination: String,
        path: [String],
        dataType: DataType,
        rawData: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.path = path
        self.dataType = dataType
        self.rawData = rawData
        self.timestamp = timestamp
    }

    /// The type of data carried in the APRS packet.
    public enum DataType: Sendable, Equatable {
        case position(APRSPosition)
        case message(APRSMessage)
        case weather(APRSWeather)
        case telemetry(String)
        case status(String)
        case object(APRSObject)
        case unknown(String)
    }
}

// MARK: - APRSPosition

/// An APRS position report with optional course/speed/PHG data.
public struct APRSPosition: Sendable, Equatable {
    /// Latitude in decimal degrees.
    public var latitude: Double
    /// Longitude in decimal degrees.
    public var longitude: Double
    /// APRS symbol (table character + symbol character, e.g., "/>" for car).
    public var symbol: String
    /// Position comment text.
    public var comment: String?
    /// Course in degrees (0-360).
    public var course: Double?
    /// Speed in knots.
    public var speed: Double?
    /// Altitude in feet.
    public var altitude: Double?
    /// Transmitter power in watts (from PHG).
    public var power: Int?
    /// Antenna gain in dB (from PHG).
    public var gain: Int?
    /// Antenna height in feet above average terrain (from PHG).
    public var height: Int?

    public init(
        latitude: Double,
        longitude: Double,
        symbol: String,
        comment: String? = nil,
        course: Double? = nil,
        speed: Double? = nil,
        altitude: Double? = nil,
        power: Int? = nil,
        gain: Int? = nil,
        height: Int? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.symbol = symbol
        self.comment = comment
        self.course = course
        self.speed = speed
        self.altitude = altitude
        self.power = power
        self.gain = gain
        self.height = height
    }
}

// MARK: - APRSMessage

/// An APRS message (person-to-person or group).
public struct APRSMessage: Sendable, Equatable {
    /// Addressee callsign (padded to 9 chars in protocol, trimmed here).
    public var addressee: String
    /// Message text.
    public var text: String
    /// Message number for acknowledgement (e.g., "123").
    public var messageNumber: String?

    public init(addressee: String, text: String, messageNumber: String? = nil) {
        self.addressee = addressee
        self.text = text
        self.messageNumber = messageNumber
    }
}

// MARK: - APRSWeather

/// APRS weather station report data.
public struct APRSWeather: Sendable, Equatable {
    /// Wind direction in degrees (0-360).
    public var windDirection: Int?
    /// Wind speed in mph.
    public var windSpeed: Int?
    /// Wind gust in mph.
    public var windGust: Int?
    /// Temperature in Fahrenheit.
    public var temperature: Int?
    /// Rain in the last hour in hundredths of an inch.
    public var rainLastHour: Double?
    /// Humidity percentage (0-100).
    public var humidity: Int?
    /// Barometric pressure in tenths of millibars.
    public var pressure: Double?

    public init(
        windDirection: Int? = nil,
        windSpeed: Int? = nil,
        windGust: Int? = nil,
        temperature: Int? = nil,
        rainLastHour: Double? = nil,
        humidity: Int? = nil,
        pressure: Double? = nil
    ) {
        self.windDirection = windDirection
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.temperature = temperature
        self.rainLastHour = rainLastHour
        self.humidity = humidity
        self.pressure = pressure
    }
}

// MARK: - APRSObject

/// An APRS object or item with position.
public struct APRSObject: Sendable, Equatable {
    /// Object name (up to 9 characters).
    public var name: String
    /// Whether the object is live (true) or killed/deleted (false).
    public var isLive: Bool
    /// Object's position.
    public var position: APRSPosition

    public init(name: String, isLive: Bool, position: APRSPosition) {
        self.name = name
        self.isLive = isLive
        self.position = position
    }
}

// MARK: - Packet Parsing

extension APRSPacket {

    /// Parse an APRS packet from a raw text line.
    ///
    /// Format: `SOURCE>DESTINATION,PATH1,PATH2:DATA`
    ///
    /// - Parameter line: Raw APRS-IS or TNC packet string.
    /// - Returns: Parsed packet, or `nil` if the line is malformed.
    public static func parse(line: String) -> APRSPacket? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // Skip server comments (lines starting with #)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

        // Split header from data at first ":"
        guard let colonIndex = trimmed.firstIndex(of: ":") else { return nil }
        let header = String(trimmed[trimmed.startIndex..<colonIndex])
        let data = String(trimmed[trimmed.index(after: colonIndex)...])

        guard !data.isEmpty else { return nil }

        // Parse header: SOURCE>DESTINATION,PATH1,PATH2,...
        guard let gtIndex = header.firstIndex(of: ">") else { return nil }
        let source = String(header[header.startIndex..<gtIndex])
        let rest = String(header[header.index(after: gtIndex)...])

        guard !source.isEmpty else { return nil }

        // Split destination and path
        let pathComponents = rest.split(separator: ",").map(String.init)
        guard !pathComponents.isEmpty else { return nil }

        let destination = pathComponents[0]
        let path = Array(pathComponents.dropFirst())

        // Parse data type from the first character(s)
        let dataType = parseDataType(data: data)

        return APRSPacket(
            source: source,
            destination: destination,
            path: path,
            dataType: dataType,
            rawData: data
        )
    }

    /// Determine the APRS data type and parse accordingly.
    private static func parseDataType(data: String) -> DataType {
        guard let firstChar = data.first else { return .unknown(data) }

        switch firstChar {
        case "!", "=":
            // Position without timestamp (! = no messaging, = = with messaging)
            if let position = parsePosition(data: String(data.dropFirst())) {
                return .position(position)
            }
            return .unknown(data)

        case "/", "@":
            // Position with timestamp (/ = no messaging, @ = with messaging)
            // Skip 7-char timestamp, then parse position
            let afterTimestamp = String(data.dropFirst(8))
            if let position = parsePosition(data: afterTimestamp) {
                return .position(position)
            }
            return .unknown(data)

        case ":":
            // Message, bulletin, or announcement
            if let message = parseMessage(data: data) {
                return .message(message)
            }
            return .unknown(data)

        case ";":
            // Object
            if let object = parseObject(data: data) {
                return .object(object)
            }
            return .unknown(data)

        case "_":
            // Positionless weather report
            if let weather = parseWeatherData(data: String(data.dropFirst())) {
                return .weather(weather)
            }
            return .unknown(data)

        case ">":
            // Status
            return .status(String(data.dropFirst()))

        case "T":
            // Telemetry
            return .telemetry(String(data.dropFirst()))

        default:
            return .unknown(data)
        }
    }

    // MARK: - Position Parsing

    /// Parse APRS position data from the data field (after data type indicator).
    ///
    /// Format: `DDMM.MMN/DDDMM.MMW` (symbol table char between lat/lon)
    /// PHG: `PHGphgd` after position
    static func parsePosition(data: String) -> APRSPosition? {
        // Need at least 19 chars: 8 lat + 1 symbol table + 9 lon + 1 symbol code
        guard data.count >= 19 else { return nil }

        let chars = Array(data)

        // Parse latitude: DDMM.MMN (8 chars)
        let latStr = String(chars[0..<7])
        let latHemisphere = chars[7]
        guard let lat = parseLatitude(latStr, hemisphere: latHemisphere) else { return nil }

        // Symbol table character
        let symbolTable = chars[8]

        // Parse longitude: DDDMM.MMW (9 chars)
        let lonStr = String(chars[9..<17])
        let lonHemisphere = chars[17]
        guard let lon = parseLongitude(lonStr, hemisphere: lonHemisphere) else { return nil }

        // Symbol code
        let symbolCode = chars[18]
        let symbol = String([symbolTable, symbolCode])

        // Parse remaining comment/extension data
        let remaining = data.count > 19 ? String(chars[19...]) : ""

        var course: Double?
        var speed: Double?
        var altitude: Double?
        var power: Int?
        var gain: Int?
        var height: Int?
        var comment: String? = remaining.isEmpty ? nil : remaining

        // Check for course/speed extension (CSE/SPD): "NNN/NNN"
        if remaining.count >= 7, remaining[remaining.index(remaining.startIndex, offsetBy: 3)] == "/" {
            let cseStr = String(remaining.prefix(3))
            let spdStr = String(remaining[remaining.index(remaining.startIndex, offsetBy: 4)...].prefix(3))
            if let cse = Double(cseStr), let spd = Double(spdStr) {
                course = cse
                speed = spd
                comment = remaining.count > 7 ? String(remaining.dropFirst(7)) : nil
            }
        }

        // Check for PHG data in comment
        if let phgRange = remaining.range(of: "PHG") {
            let afterPHG = String(remaining[phgRange.upperBound...])
            if afterPHG.count >= 4 {
                let phgChars = Array(afterPHG.prefix(4))
                // PHG: Power, Height, Gain, Directivity (single digits)
                if let p = phgChars[0].wholeNumberValue,
                   let h = phgChars[1].wholeNumberValue,
                   let g = phgChars[2].wholeNumberValue {
                    // Power = p^2 watts
                    power = p * p
                    // Height = 10 * 2^h feet
                    height = 10 * (1 << h)
                    // Gain = g dB
                    gain = g
                }
                // Keep comment after PHG
                let afterPHGData = String(afterPHG.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if remaining.hasPrefix("PHG") {
                    comment = afterPHGData.isEmpty ? nil : afterPHGData
                }
            }
        }

        // Check for altitude in comment: /A=NNNNNN
        if let altRange = remaining.range(of: "/A=") {
            let afterAlt = String(remaining[altRange.upperBound...])
            let altDigits = String(afterAlt.prefix(6))
            if let alt = Double(altDigits) {
                altitude = alt
            }
        }

        return APRSPosition(
            latitude: lat,
            longitude: lon,
            symbol: symbol,
            comment: comment?.trimmingCharacters(in: .whitespaces),
            course: course,
            speed: speed,
            altitude: altitude,
            power: power,
            gain: gain,
            height: height
        )
    }

    /// Parse APRS latitude string "DDMM.MM" with hemisphere N/S.
    static func parseLatitude(_ str: String, hemisphere: Character) -> Double? {
        guard str.count >= 7 else { return nil }
        guard let degrees = Double(str.prefix(2)),
              let minutes = Double(str.dropFirst(2)) else { return nil }
        var lat = degrees + minutes / 60.0
        if hemisphere == "S" || hemisphere == "s" { lat = -lat }
        guard lat >= -90 && lat <= 90 else { return nil }
        return lat
    }

    /// Parse APRS longitude string "DDDMM.MM" with hemisphere E/W.
    static func parseLongitude(_ str: String, hemisphere: Character) -> Double? {
        guard str.count >= 8 else { return nil }
        guard let degrees = Double(str.prefix(3)),
              let minutes = Double(str.dropFirst(3)) else { return nil }
        var lon = degrees + minutes / 60.0
        if hemisphere == "W" || hemisphere == "w" { lon = -lon }
        guard lon >= -180 && lon <= 180 else { return nil }
        return lon
    }

    // MARK: - Message Parsing

    /// Parse an APRS message from the data field.
    ///
    /// Format: `:ADDRESSEE :text{NNN`
    static func parseMessage(data: String) -> APRSMessage? {
        // Data starts with ":"
        guard data.hasPrefix(":") else { return nil }
        let content = String(data.dropFirst())

        // Addressee is 9 characters (padded with spaces), followed by ":"
        guard content.count >= 10 else { return nil }
        let addressee = String(content.prefix(9)).trimmingCharacters(in: .whitespaces)

        // Check for ":" after addressee
        let afterAddressee = content[content.index(content.startIndex, offsetBy: 9)...]
        guard afterAddressee.first == ":" else { return nil }

        let messageContent = String(afterAddressee.dropFirst())

        // Check for message number: text{NNN
        var text = messageContent
        var messageNumber: String?

        if let braceIndex = messageContent.lastIndex(of: "{") {
            text = String(messageContent[messageContent.startIndex..<braceIndex])
            messageNumber = String(messageContent[messageContent.index(after: braceIndex)...])
        }

        guard !addressee.isEmpty else { return nil }

        return APRSMessage(addressee: addressee, text: text, messageNumber: messageNumber)
    }

    // MARK: - Object Parsing

    /// Parse an APRS object from the data field.
    ///
    /// Format: `;NAME_____*DDMM.MMN/DDDMM.MMWc...` (* = live, _ = killed)
    static func parseObject(data: String) -> APRSObject? {
        guard data.hasPrefix(";"), data.count >= 31 else { return nil }
        let content = String(data.dropFirst())

        // Object name is 9 characters
        let name = String(content.prefix(9)).trimmingCharacters(in: .whitespaces)

        // Live/killed indicator
        let indicator = content[content.index(content.startIndex, offsetBy: 9)]
        let isLive = indicator == "*"

        // Position data follows
        let positionData = String(content.dropFirst(10))
        // Skip optional timestamp (7 chars if present)
        // Timestamps end with 'z', 'h', or '/' — e.g., "092345z" or "234517h"
        var posData = positionData
        if positionData.count > 7 {
            let seventh = positionData[positionData.index(positionData.startIndex, offsetBy: 6)]
            if seventh == "z" || seventh == "h" || seventh == "/" {
                posData = String(positionData.dropFirst(7))
            }
        }

        guard let position = parsePosition(data: posData) else { return nil }

        return APRSObject(name: name, isLive: isLive, position: position)
    }

    // MARK: - Weather Parsing

    /// Parse APRS weather data from positionless weather format.
    ///
    /// Weather data uses single-character field identifiers:
    /// `c` = wind direction, `s` = wind speed, `g` = gust, `t` = temperature,
    /// `r` = rain 1hr, `h` = humidity, `b` = pressure
    static func parseWeatherData(data: String) -> APRSWeather? {
        var weather = APRSWeather()
        var remaining = data
        var foundAny = false

        while !remaining.isEmpty {
            guard let field = remaining.first else { break }
            remaining = String(remaining.dropFirst())

            switch field {
            case "c":
                // Wind direction: 3 digits
                let val = extractDigits(&remaining, count: 3)
                if let v = val { weather.windDirection = v; foundAny = true }
            case "s":
                // Wind speed: 3 digits
                let val = extractDigits(&remaining, count: 3)
                if let v = val { weather.windSpeed = v; foundAny = true }
            case "g":
                // Wind gust: 3 digits
                let val = extractDigits(&remaining, count: 3)
                if let v = val { weather.windGust = v; foundAny = true }
            case "t":
                // Temperature: 3 digits (can be negative with leading -)
                if remaining.first == "-" {
                    remaining = String(remaining.dropFirst())
                    if let val = extractDigits(&remaining, count: 2) {
                        weather.temperature = -val
                        foundAny = true
                    }
                } else {
                    let val = extractDigits(&remaining, count: 3)
                    if let v = val { weather.temperature = v; foundAny = true }
                }
            case "r":
                // Rain last hour: 3 digits (hundredths of inch)
                if let val = extractDigits(&remaining, count: 3) {
                    weather.rainLastHour = Double(val) / 100.0
                    foundAny = true
                }
            case "h":
                // Humidity: 2 digits (00 = 100%)
                if let val = extractDigits(&remaining, count: 2) {
                    weather.humidity = val == 0 ? 100 : val
                    foundAny = true
                }
            case "b":
                // Pressure: 5 digits (tenths of millibars)
                if let val = extractDigits(&remaining, count: 5) {
                    weather.pressure = Double(val) / 10.0
                    foundAny = true
                }
            default:
                // Unknown field — skip
                continue
            }
        }

        return foundAny ? weather : nil
    }

    /// Extract a fixed number of digit characters from the front of a string.
    private static func extractDigits(_ str: inout String, count: Int) -> Int? {
        guard str.count >= count else { return nil }
        let digits = String(str.prefix(count))
        str = String(str.dropFirst(count))
        // Allow spaces in place of digits (treated as missing data)
        let cleaned = digits.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }
}
