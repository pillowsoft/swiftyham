import Foundation

/// Current state of the connected rig, published via AsyncStream from RigConnection.
public struct RigState: Sendable, Equatable {
    /// Current VFO frequency in Hz.
    public var frequency: Double

    /// Current operating mode.
    public var mode: OperatingMode

    /// Whether PTT (push-to-talk) is currently active.
    public var pttActive: Bool

    /// Signal strength in dB (S-meter reading), if available.
    public var signalStrength: Int?

    public init(
        frequency: Double,
        mode: OperatingMode,
        pttActive: Bool,
        signalStrength: Int? = nil
    ) {
        self.frequency = frequency
        self.mode = mode
        self.pttActive = pttActive
        self.signalStrength = signalStrength
    }
}
