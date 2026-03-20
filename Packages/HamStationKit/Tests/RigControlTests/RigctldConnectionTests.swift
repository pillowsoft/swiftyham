import XCTest
import Foundation
import Network
@testable import HamStationKit

// MARK: - Mock TCP Server

private actor MockRigctldServer {
    private var listener: NWListener?
    private var activeConnection: NWConnection?
    let port: UInt16

    var commandHandlers: [String: @Sendable (String) -> String] = [:]
    var responseDelay: TimeInterval = 0
    var silent: Bool = false

    init() {
        self.port = UInt16.random(in: 10000...60000)
    }

    func start() async throws {
        let parameters = NWParameters.tcp
        let nwListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = nwListener

        setupDefaultHandlers()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            nwListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                default:
                    break
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handleConnection(connection)
                }
            }

            nwListener.start(queue: .global(qos: .userInitiated))
        }
    }

    func stop() {
        activeConnection?.cancel()
        activeConnection = nil
        listener?.cancel()
        listener = nil
    }

    private func setupDefaultHandlers() {
        commandHandlers["f"] = { _ in "14074000\n" }
        commandHandlers["F"] = { _ in "RPRT 0\n" }
        commandHandlers["m"] = { _ in "USB\n2400\n" }
        commandHandlers["M"] = { _ in "RPRT 0\n" }
        commandHandlers["t"] = { _ in "0\n" }
        commandHandlers["T"] = { _ in "RPRT 0\n" }
    }

    private func handleConnection(_ connection: NWConnection) {
        self.activeConnection = connection
        connection.start(queue: .global(qos: .userInitiated))
        receiveLoop(connection)
    }

    private nonisolated func receiveLoop(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let data, error == nil,
                  let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            else {
                return
            }

            Task {
                guard let self else { return }
                let silent = await self.silent
                if silent { return }

                let delay = await self.responseDelay
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                let response = await self.processCommand(command)
                let responseData = Data(response.utf8)

                connection.send(content: responseData, completion: .contentProcessed { _ in })

                self.receiveLoop(connection)
            }
        }
    }

    private func processCommand(_ command: String) -> String {
        let prefix = String(command.prefix(1))

        if let handler = commandHandlers[prefix] {
            return handler(command)
        }

        let firstWord = command.split(separator: " ").first.map(String.init) ?? command
        if let handler = commandHandlers[firstWord] {
            return handler(command)
        }

        return "RPRT -1\n"
    }
}

// MARK: - Thread-safe box for capturing in @Sendable closures

private final class CommandBox: @unchecked Sendable {
    var value: String?
}

// MARK: - Tests

class RigctldConnectionTests: XCTestCase {

    func testConnectSuccess() async throws {
        let server = MockRigctldServer()
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        let state = await rig.connectionState
        XCTAssertEqual(state, .connected)

        await rig.disconnect()
    }

    func testGetFrequency() async throws {
        let server = MockRigctldServer()
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        let freq = try await rig.getFrequency()
        XCTAssertEqual(freq, 14_074_000.0)

        await rig.disconnect()
    }

    func testSetFrequency() async throws {
        let server = MockRigctldServer()
        let box = CommandBox()
        await server.setHandler(for: "F") { command in
            box.value = command
            return "RPRT 0\n"
        }
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        try await rig.setFrequency(7_074_000)

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(box.value?.contains("7074000"), true)

        await rig.disconnect()
    }

    func testGetMode() async throws {
        let server = MockRigctldServer()
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        let mode = try await rig.getMode()
        XCTAssertEqual(mode, .usb)

        await rig.disconnect()
    }

    func testSetMode() async throws {
        let server = MockRigctldServer()
        let box = CommandBox()
        await server.setHandler(for: "M") { command in
            box.value = command
            return "RPRT 0\n"
        }
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        try await rig.setMode(.cw)

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(box.value?.contains("CW"), true)

        await rig.disconnect()
    }

    func testGetPTT() async throws {
        let server = MockRigctldServer()
        await server.setHandler(for: "t") { _ in "1\n" }
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        let ptt = try await rig.getPTT()
        XCTAssertEqual(ptt, true)

        await rig.disconnect()
    }

    func testSetPTTOn() async throws {
        let server = MockRigctldServer()
        let box = CommandBox()
        await server.setHandler(for: "T") { command in
            box.value = command
            return "RPRT 0\n"
        }
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        try await rig.setPTT(true)

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(box.value?.contains("1"), true)

        await rig.disconnect()
    }

    func testCommandFailure() async throws {
        let server = MockRigctldServer()
        await server.setHandler(for: "F") { _ in "RPRT -6\n" }
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()

        do {
            try await rig.setFrequency(999_999)
            XCTFail("Expected RigControlError")
        } catch is RigControlError {
            // Expected
        }

        await rig.disconnect()
    }

    func testNotConnected() async throws {
        let rig = RigctldConnection(host: "127.0.0.1", port: 19999)

        do {
            try await rig.setFrequency(14_074_000)
            XCTFail("Expected RigControlError")
        } catch is RigControlError {
            // Expected
        }
    }

    func testDisconnect() async throws {
        let server = MockRigctldServer()
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)
        try await rig.connect()
        await rig.disconnect()

        let state = await rig.connectionState
        XCTAssertEqual(state, .disconnected)
    }

    func testModeMapping() async throws {
        let server = MockRigctldServer()
        try await server.start()
        defer { Task { await server.stop() } }

        let port = await server.port
        let rig = RigctldConnection(host: "127.0.0.1", port: port)

        let usbName = await rig.rigctldModeName(for: .usb)
        XCTAssertEqual(usbName, "USB")

        let lsbName = await rig.rigctldModeName(for: .lsb)
        XCTAssertEqual(lsbName, "LSB")

        let cwName = await rig.rigctldModeName(for: .cw)
        XCTAssertEqual(cwName, "CW")

        let ft8Name = await rig.rigctldModeName(for: .ft8)
        XCTAssertEqual(ft8Name, "PKTUSB")

        let usbMode = await rig.operatingMode(from: "USB")
        XCTAssertEqual(usbMode, .usb)

        let cwMode = await rig.operatingMode(from: "CW")
        XCTAssertEqual(cwMode, .cw)
    }

    func testConnectionFailed() async throws {
        let rig = RigctldConnection(host: "192.0.2.1", port: 65534)

        do {
            try await rig.connect()
            XCTFail("Expected RigControlError")
        } catch is RigControlError {
            // Expected
        }
    }
}

// MARK: - MockRigctldServer Helper Extension

extension MockRigctldServer {
    func setHandler(for command: String, handler: @escaping @Sendable (String) -> String) {
        commandHandlers[command] = handler
    }
}
