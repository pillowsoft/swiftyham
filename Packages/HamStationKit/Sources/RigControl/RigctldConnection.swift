import Foundation
import Network
import os

// MARK: - RigctldConnection

/// Rig control implementation via the rigctld TCP text protocol.
///
/// rigctld is the Hamlib network daemon that exposes radio control over TCP.
/// Protocol is newline-delimited text commands and responses.
///
/// Commands:
/// - Set frequency: `F 14074000\n` -> `RPRT 0\n`
/// - Get frequency: `f\n` -> `14074000\n`
/// - Set mode: `M USB 2400\n` -> `RPRT 0\n`
/// - Get mode: `m\n` -> `USB\n2400\n`
/// - Set PTT: `T 1\n` / `T 0\n` -> `RPRT 0\n`
/// - Get PTT: `t\n` -> `0\n` / `1\n`
public actor RigctldConnection: RigConnection {
    // MARK: - Properties

    public let host: String
    public let port: UInt16

    private var connection: NWConnection?
    private var pollTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    public private(set) var connectionState: ConnectionState = .disconnected

    private var stateContinuation: AsyncStream<RigState>.Continuation?
    public let stateStream: AsyncStream<RigState>

    /// The most recent known rig state, used to detect changes.
    private var lastState: RigState?

    private let logger = Logger(subsystem: "com.hamstation.kit", category: "RigctldConnection")

    /// Poll interval in nanoseconds (100ms).
    private static let pollInterval: UInt64 = 100_000_000

    /// Maximum reconnect backoff in seconds.
    private static let maxReconnectBackoff: TimeInterval = 30.0

    // MARK: - Initialization

    public init(host: String = "localhost", port: UInt16 = 4532) {
        self.host = host
        self.port = port

        var continuation: AsyncStream<RigState>.Continuation!
        self.stateStream = AsyncStream<RigState> { cont in
            continuation = cont
        }
        self.stateContinuation = continuation
    }

    deinit {
        stateContinuation?.finish()
    }

    // MARK: - RigConnection Protocol

    public func connect() async throws {
        connectionState = .connecting
        logger.info("Connecting to rigctld at \(self.host):\(self.port)")

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let nwConnection = NWConnection(host: nwHost, port: nwPort, using: .tcp)

        self.connection = nwConnection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            nwConnection.stateUpdateHandler = { [weak nwConnection] state in
                switch state {
                case .ready:
                    // Remove the one-shot handler
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume(throwing: RigControlError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    nwConnection?.stateUpdateHandler = nil
                    continuation.resume(throwing: RigControlError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            nwConnection.start(queue: .global(qos: .userInitiated))
        }

        connectionState = .connected
        logger.info("Connected to rigctld")

        // Install persistent state handler for disconnect detection
        setupDisconnectHandler()

        // Start polling loop
        startPolling()
    }

    public func disconnect() async {
        logger.info("Disconnecting from rigctld")
        pollTask?.cancel()
        pollTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil

        connection?.cancel()
        connection = nil
        connectionState = .disconnected
    }

    public func setFrequency(_ hz: Double) async throws {
        let command = "F \(Int(hz))"
        try await sendCommandExpectingRPRT(command)
    }

    public func setMode(_ mode: OperatingMode) async throws {
        let rigctldMode = rigctldModeName(for: mode)
        let command = "M \(rigctldMode) 0"
        try await sendCommandExpectingRPRT(command)
    }

    public func setPTT(_ on: Bool) async throws {
        let command = "T \(on ? 1 : 0)"
        try await sendCommandExpectingRPRT(command)
    }

    // MARK: - Query Methods

    /// Get the current VFO frequency in Hz.
    func getFrequency() async throws -> Double {
        let response = try await sendCommand("f")
        guard let freq = Double(response.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw RigControlError.commandFailed(command: "f", errorCode: -1)
        }
        return freq
    }

    /// Get the current operating mode.
    func getMode() async throws -> OperatingMode {
        let response = try await sendCommand("m")
        // Response is two lines: mode name and passband width
        let lines = response.split(separator: "\n", omittingEmptySubsequences: true)
        guard let modeLine = lines.first else {
            throw RigControlError.commandFailed(command: "m", errorCode: -1)
        }
        let modeName = String(modeLine).trimmingCharacters(in: .whitespacesAndNewlines)
        return operatingMode(from: modeName)
    }

    /// Get the current PTT state.
    func getPTT() async throws -> Bool {
        let response = try await sendCommand("t")
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "1"
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.pollInterval)
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }

                do {
                    let frequency = try await self.getFrequency()
                    let mode = try await self.getMode()
                    let ptt = try await self.getPTT()

                    let newState = RigState(frequency: frequency, mode: mode, pttActive: ptt)

                    let lastKnown = await self.lastState
                    if lastKnown != newState {
                        await self.updateState(newState)
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.handlePollError(error)
                    }
                }
            }
        }
    }

    private func updateState(_ state: RigState) {
        lastState = state
        stateContinuation?.yield(state)
    }

    private func handlePollError(_ error: any Error) {
        logger.warning("Poll error: \(error.localizedDescription)")
        // Connection may have dropped — start reconnect
        if connectionState == .connected {
            connectionState = .reconnecting
            startReconnect()
        }
    }

    // MARK: - Reconnection

    private func setupDisconnectHandler() {
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task {
                switch state {
                case .failed, .cancelled:
                    await self.handleDisconnect()
                default:
                    break
                }
            }
        }
    }

    private func handleDisconnect() {
        guard connectionState == .connected else { return }
        logger.warning("Connection to rigctld lost")
        connectionState = .reconnecting
        pollTask?.cancel()
        pollTask = nil
        connection?.cancel()
        connection = nil
        startReconnect()
    }

    private func startReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            var backoff: TimeInterval = 1.0

            while !Task.isCancelled {
                await self.logReconnectAttempt(backoff: backoff)

                do {
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }

                do {
                    try await self.connect()
                    await self.logReconnectSuccess()
                    return
                } catch {
                    backoff = min(backoff * 2.0, Self.maxReconnectBackoff)
                }
            }
        }
    }

    private func logReconnectAttempt(backoff: TimeInterval) {
        logger.info("Attempting reconnect in \(backoff)s")
    }

    private func logReconnectSuccess() {
        logger.info("Reconnected to rigctld")
    }

    // MARK: - TCP Communication

    /// Send a command and return the raw response string.
    private func sendCommand(_ command: String) async throws -> String {
        guard let connection else {
            throw RigControlError.notConnected
        }

        let commandData = Data((command + "\n").utf8)

        // Send
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: commandData, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: RigControlError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }

        // Receive response
        let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, any Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: RigControlError.connectionFailed(error.localizedDescription))
                    return
                }
                guard let data, let responseString = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: RigControlError.timeout)
                    return
                }
                continuation.resume(returning: responseString)
            }
        }

        return response
    }

    /// Send a command that expects an "RPRT 0" success response.
    private func sendCommandExpectingRPRT(_ command: String) async throws {
        let response = try await sendCommand(command)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("RPRT") {
            let parts = trimmed.split(separator: " ")
            if parts.count >= 2, let code = Int(parts[1]), code != 0 {
                throw RigControlError.commandFailed(command: command, errorCode: code)
            }
        }
    }

    // MARK: - Mode Mapping

    /// Map from OperatingMode to rigctld mode string.
    func rigctldModeName(for mode: OperatingMode) -> String {
        switch mode {
        case .usb: return "USB"
        case .lsb: return "LSB"
        case .ssb: return "USB" // Default SSB to USB
        case .cw: return "CW"
        case .am: return "AM"
        case .fm: return "FM"
        case .rtty: return "RTTY"
        case .ft8, .ft4, .js8, .wspr, .jt65, .jt9:
            return "PKTUSB" // Digital modes use packet USB
        case .psk31, .psk63, .olivia, .contestia, .thor:
            return "PKTUSB"
        case .sstv, .fax:
            return "USB"
        case .dstar, .dmr, .c4fm, .p25:
            return "FM" // Digital voice modes use FM
        case .sat:
            return "USB" // Satellite defaults to USB
        }
    }

    /// Map from rigctld mode string to OperatingMode.
    func operatingMode(from rigctldMode: String) -> OperatingMode {
        switch rigctldMode.uppercased() {
        case "USB": return .usb
        case "LSB": return .lsb
        case "CW", "CWR": return .cw
        case "AM": return .am
        case "FM", "WFM": return .fm
        case "RTTY", "RTTYR": return .rtty
        case "PKTUSB", "PKTLSB": return .ft8 // Default packet mode to FT8
        default:
            logger.warning("Unknown rigctld mode: \(rigctldMode), defaulting to USB")
            return .usb
        }
    }
}
