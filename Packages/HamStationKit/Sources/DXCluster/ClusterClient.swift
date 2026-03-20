import Foundation
import Network
import os

// MARK: - ClusterClient

/// Connects to DX cluster telnet servers and streams parsed spots.
///
/// Supports AR-Cluster, DX Spider, and CC Cluster servers.
/// Common cluster ports: 7300 (DX Spider), 23 (telnet default), 7373, 8000.
public actor ClusterClient {
    // MARK: - Properties

    public let host: String
    public let port: UInt16
    public let callsign: String

    private var connection: NWConnection?
    public private(set) var connectionState: ConnectionState = .disconnected

    private var spotContinuation: AsyncStream<DXSpot>.Continuation?
    public let spotStream: AsyncStream<DXSpot>

    private var rawLineContinuation: AsyncStream<String>.Continuation?
    public let rawLineStream: AsyncStream<String>

    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    /// Buffer for partial TCP data (TCP can split mid-line).
    private var lineBuffer: String = ""

    private let logger = Logger(subsystem: "com.hamstation.kit", category: "ClusterClient")

    /// Maximum reconnect backoff in seconds.
    private static let maxReconnectBackoff: TimeInterval = 30.0

    // MARK: - Initialization

    public init(host: String, port: UInt16, callsign: String) {
        self.host = host
        self.port = port
        self.callsign = callsign

        var spotCont: AsyncStream<DXSpot>.Continuation!
        self.spotStream = AsyncStream<DXSpot> { cont in
            spotCont = cont
        }
        self.spotContinuation = spotCont

        var rawCont: AsyncStream<String>.Continuation!
        self.rawLineStream = AsyncStream<String> { cont in
            rawCont = cont
        }
        self.rawLineContinuation = rawCont
    }

    deinit {
        spotContinuation?.finish()
        rawLineContinuation?.finish()
    }

    // MARK: - Connection

    /// Connect to the DX cluster server.
    public func connect() async throws {
        connectionState = .connecting
        logger.info("Connecting to DX cluster at \(self.host):\(self.port)")

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
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
        logger.info("Connected to DX cluster")

        // Send login callsign
        try await sendCommand(callsign)

        // Install disconnect handler
        setupDisconnectHandler()

        // Start receiving data
        startReceiving()
    }

    /// Disconnect from the DX cluster server.
    public func disconnect() async {
        logger.info("Disconnecting from DX cluster")
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil

        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        lineBuffer = ""
    }

    /// Send a text command to the cluster server.
    public func sendCommand(_ command: String) async throws {
        guard let connection else {
            throw RigControlError.notConnected
        }

        let data = Data((command + "\n").utf8)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: RigControlError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Receiving

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
                        await self.handleReceiveError(error)
                    }
                    break
                }
            }
        }
    }

    private func receiveData() async throws -> Data {
        guard let connection else {
            throw RigControlError.notConnected
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: RigControlError.connectionFailed("No data received"))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func processReceivedText(_ text: String) {
        lineBuffer += text

        // Process complete lines
        while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineIndex])
            lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

            processLine(line)
        }

        // Also handle \r\n (some cluster servers use this)
        while let crIndex = lineBuffer.firstIndex(of: "\r") {
            // Check if there's a \n right after
            let nextIndex = lineBuffer.index(after: crIndex)
            if nextIndex < lineBuffer.endIndex && lineBuffer[nextIndex] == "\n" {
                let line = String(lineBuffer[lineBuffer.startIndex..<crIndex])
                lineBuffer = String(lineBuffer[lineBuffer.index(after: nextIndex)...])
                processLine(line)
            } else {
                break
            }
        }
    }

    private func processLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Always yield to raw line stream for debugging
        rawLineContinuation?.yield(trimmed)

        // Try to parse as a DX spot
        if let spot = DXSpot.parse(line: trimmed) {
            spotContinuation?.yield(spot)
        }
    }

    // MARK: - Error Handling & Reconnection

    private func handleReceiveError(_ error: any Error) {
        logger.warning("Receive error: \(error.localizedDescription)")
        if connectionState == .connected {
            connectionState = .reconnecting
            connection?.cancel()
            connection = nil
            startReconnect()
        }
    }

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
        logger.warning("DX cluster connection lost")
        connectionState = .reconnecting
        receiveTask?.cancel()
        receiveTask = nil
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
                self.logger.info("Attempting DX cluster reconnect in \(backoff)s")

                do {
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }

                do {
                    try await self.connect()
                    self.logger.info("Reconnected to DX cluster")
                    return
                } catch {
                    backoff = min(backoff * 2.0, Self.maxReconnectBackoff)
                }
            }
        }
    }
}
