// APRSClient.swift
// HamStationKit — APRS-IS (APRS Internet System) TCP client.

import Foundation
import Network
import os

// MARK: - APRSClient

/// Connects to APRS-IS servers via TCP to send and receive APRS packets.
///
/// APRS-IS login format:
/// ```
/// user CALLSIGN-SSID pass PASSCODE vers HamStationPro 1.0 filter r/LAT/LON/RANGE\r\n
/// ```
public actor APRSClient {

    // MARK: - Properties

    /// The operator's callsign (without SSID).
    public let callsign: String

    /// APRS-IS verification passcode computed from the callsign.
    public let passcode: Int

    private var connection: NWConnection?
    public private(set) var connectionState: ConnectionState = .disconnected

    private var packetContinuation: AsyncStream<APRSPacket>.Continuation?
    /// Stream of received APRS packets.
    public let packetStream: AsyncStream<APRSPacket>

    private var receiveTask: Task<Void, Never>?
    private var lineBuffer: String = ""

    private let logger = Logger(subsystem: "com.hamstation.kit", category: "APRSClient")

    // MARK: - Initialization

    /// Create an APRS-IS client for the given callsign.
    ///
    /// - Parameter callsign: Operator callsign (SSID will be stripped for passcode calculation).
    public init(callsign: String) {
        self.callsign = callsign
        self.passcode = Self.calculatePasscode(callsign: callsign)

        var cont: AsyncStream<APRSPacket>.Continuation!
        self.packetStream = AsyncStream<APRSPacket> { continuation in
            cont = continuation
        }
        self.packetContinuation = cont
    }

    deinit {
        packetContinuation?.finish()
    }

    // MARK: - Connection

    /// Connect to an APRS-IS server.
    ///
    /// - Parameters:
    ///   - server: APRS-IS server hostname (default: rotate.aprs2.net).
    ///   - port: TCP port (default: 14580).
    ///   - filter: Optional APRS-IS filter string (e.g., "r/42.0/-71.0/100" for 100km radius).
    public func connect(
        server: String = "rotate.aprs2.net",
        port: Int = 14580,
        filter: String? = nil
    ) async throws {
        connectionState = .connecting
        logger.info("Connecting to APRS-IS at \(server):\(port)")

        let nwHost = NWEndpoint.Host(server)
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw APRSError.connectionFailed("Invalid port number: \(port)")
        }

        let nwConnection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = nwConnection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            nwConnection.stateUpdateHandler = { [weak nwConnection] state in
                switch state {
                case .ready:
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume(throwing: APRSError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume(throwing: APRSError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            nwConnection.start(queue: .global(qos: .userInitiated))
        }

        connectionState = .connected

        // Send login string
        var loginString = "user \(callsign) pass \(passcode) vers HamStationPro 1.0"
        if let filter {
            loginString += " filter \(filter)"
        }
        loginString += "\r\n"
        try await sendRaw(loginString)
        logger.info("Logged in to APRS-IS as \(self.callsign)")

        // Start receiving
        startReceiving()
    }

    /// Disconnect from the APRS-IS server.
    public func disconnect() async {
        logger.info("Disconnecting from APRS-IS")
        receiveTask?.cancel()
        receiveTask = nil
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        lineBuffer = ""
    }

    // MARK: - Sending

    /// Send a position beacon to APRS-IS.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in decimal degrees.
    ///   - longitude: Longitude in decimal degrees.
    ///   - comment: Optional position comment.
    public func sendPosition(latitude: Double, longitude: Double, comment: String? = nil) async throws {
        let latStr = formatAPRSLatitude(latitude)
        let lonStr = formatAPRSLongitude(longitude)

        // Use "=" for position with messaging, "/" as symbol table, "-" as house symbol
        var packet = "\(callsign)>APRS,TCPIP*:=\(latStr)/\(lonStr)-"
        if let comment {
            packet += comment
        }
        packet += "\r\n"

        try await sendRaw(packet)
    }

    /// Send a message to another station via APRS-IS.
    ///
    /// - Parameters:
    ///   - callsign: Destination callsign.
    ///   - text: Message text.
    public func sendMessage(to callsign: String, text: String) async throws {
        // Pad addressee to 9 characters
        let paddedAddressee = callsign.padding(toLength: 9, withPad: " ", startingAt: 0)
        let packet = "\(self.callsign)>APRS,TCPIP*::\(paddedAddressee):\(text)\r\n"
        try await sendRaw(packet)
    }

    // MARK: - Passcode Calculation

    /// Calculate the APRS-IS verification passcode for a callsign.
    ///
    /// Standard algorithm: XOR pairs of characters from the uppercase callsign (without SSID)
    /// starting with seed 0x73E2.
    ///
    /// - Parameter callsign: The callsign (SSID is stripped if present).
    /// - Returns: The passcode as an integer (0-32767).
    public static func calculatePasscode(callsign: String) -> Int {
        // Strip SSID (everything after and including the dash)
        let baseCall = callsign.split(separator: "-").first.map(String.init) ?? callsign
        let upper = baseCall.uppercased()
        let bytes = Array(upper.utf8)

        var hash: UInt16 = 0x73E2

        var i = 0
        while i < bytes.count {
            hash ^= UInt16(bytes[i]) << 8
            if i + 1 < bytes.count {
                hash ^= UInt16(bytes[i + 1])
            }
            i += 2
        }

        // Mask to positive 15-bit value
        return Int(hash & 0x7FFF)
    }

    // MARK: - Private Helpers

    private func sendRaw(_ text: String) async throws {
        guard let connection else {
            throw APRSError.notConnected
        }

        let data = Data(text.utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: APRSError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    let data = try await self.receiveData()
                    guard let text = String(data: data, encoding: .utf8) else { continue }
                    await self.processReceivedText(text)
                } catch {
                    if !Task.isCancelled {
                        await self.handleDisconnect()
                    }
                    break
                }
            }
        }
    }

    private func receiveData() async throws -> Data {
        guard let connection else {
            throw APRSError.notConnected
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: APRSError.connectionFailed("No data received"))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func processReceivedText(_ text: String) {
        lineBuffer += text

        while let newlineIndex = lineBuffer.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

            guard !line.isEmpty else { continue }

            // Skip server comment lines
            if line.hasPrefix("#") {
                logger.debug("APRS-IS server: \(line)")
                continue
            }

            // Parse as APRS packet
            if let packet = APRSPacket.parse(line: line) {
                packetContinuation?.yield(packet)
            }
        }
    }

    private func handleDisconnect() {
        logger.warning("APRS-IS connection lost")
        connectionState = .disconnected
        connection?.cancel()
        connection = nil
    }

    // MARK: - APRS Coordinate Formatting

    /// Format latitude as APRS DDMM.MMN string.
    func formatAPRSLatitude(_ lat: Double) -> String {
        let hemisphere: Character = lat >= 0 ? "N" : "S"
        let absLat = abs(lat)
        let degrees = Int(absLat)
        let minutes = (absLat - Double(degrees)) * 60.0
        return String(format: "%02d%05.2f%c", degrees, minutes, hemisphere.asciiValue!)
    }

    /// Format longitude as APRS DDDMM.MMW string.
    func formatAPRSLongitude(_ lon: Double) -> String {
        let hemisphere: Character = lon >= 0 ? "E" : "W"
        let absLon = abs(lon)
        let degrees = Int(absLon)
        let minutes = (absLon - Double(degrees)) * 60.0
        return String(format: "%03d%05.2f%c", degrees, minutes, hemisphere.asciiValue!)
    }
}

// MARK: - APRSError

/// Errors that can occur during APRS operations.
public enum APRSError: Error, Sendable {
    case connectionFailed(String)
    case notConnected
    case sendFailed(String)
    case invalidPacket(String)
}
