import Foundation

// MARK: - Rig Control Errors

/// Errors that can occur during rig control operations.
public enum RigControlError: Error, Sendable {
    /// The connection to the rig control daemon could not be established.
    case connectionFailed(String)
    /// A command sent to the rig returned a non-zero error code.
    case commandFailed(command: String, errorCode: Int)
    /// The rig did not respond within the expected time.
    case timeout
    /// The rig is not currently connected.
    case notConnected
}

// MARK: - RigConnection Protocol

/// Protocol abstraction for rig control.
///
/// Allows different backends: rigctld (TCP), FlexRadio SmartSDR, native Hamlib, etc.
/// All implementations must be actors for thread-safe I/O ownership.
public protocol RigConnection: Actor, Sendable {
    /// Connect to the rig control backend.
    func connect() async throws

    /// Disconnect from the rig control backend.
    func disconnect() async

    /// The current connection state.
    var connectionState: ConnectionState { get }

    /// A stream of rig state updates. Only emits when state changes.
    var stateStream: AsyncStream<RigState> { get }

    /// Set the VFO frequency in Hz.
    func setFrequency(_ hz: Double) async throws

    /// Set the operating mode.
    func setMode(_ mode: OperatingMode) async throws

    /// Set PTT (push-to-talk) state.
    func setPTT(_ on: Bool) async throws
}
