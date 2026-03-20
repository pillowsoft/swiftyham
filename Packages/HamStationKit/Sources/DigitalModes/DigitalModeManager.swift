// DigitalModeManager.swift
// HamStationKit — Coordinates all digital mode decoders.
// Routes audio to the active decoder and provides a unified message stream.

import Foundation

/// Coordinates all digital mode decoders (FT8, FT4, PSK31, RTTY, CW).
///
/// Only one mode is active at a time. Audio samples are routed to the active
/// decoder, and decoded messages are emitted via a unified stream.
public actor DigitalModeManager {

    // MARK: - Types

    /// Available digital modes.
    public enum ActiveMode: Sendable, Equatable {
        case ft8
        case ft4
        case psk31
        case rtty
        case cw
        case none
    }

    /// A decoded message from any digital mode.
    public struct DecodedMessage: Sendable, Identifiable {
        public let id: UUID
        public var mode: ActiveMode
        public var text: String
        public var frequency: Double?
        public var snr: Int?
        public var timestamp: Date

        public init(
            id: UUID = UUID(),
            mode: ActiveMode,
            text: String,
            frequency: Double? = nil,
            snr: Int? = nil,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.mode = mode
            self.text = text
            self.frequency = frequency
            self.snr = snr
            self.timestamp = timestamp
        }
    }

    // MARK: - Properties

    /// Currently active digital mode.
    public private(set) var activeMode: ActiveMode = .none

    /// FT8 engine (manages its own cycle timing).
    private var ft8Engine: FT8Engine?

    /// PSK31 decoder.
    private var psk31Decoder: PSK31Decoder?

    /// RTTY decoder.
    private var rttyDecoder: RTTYDecoder?

    /// Audio sample rate.
    public let sampleRate: Double

    /// Message stream continuation.
    private var messageContinuation: AsyncStream<DecodedMessage>.Continuation?

    // MARK: - Init

    /// Create a digital mode manager.
    /// - Parameter sampleRate: Audio sample rate in Hz. Default 48000.
    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Mode control

    /// Switch the active digital mode.
    ///
    /// Stops the current decoder and initializes the new one.
    /// - Parameter mode: The mode to activate.
    public func setMode(_ mode: ActiveMode) async {
        // Stop current decoders
        await ft8Engine?.stop()
        ft8Engine = nil
        psk31Decoder = nil
        rttyDecoder = nil

        activeMode = mode

        switch mode {
        case .ft8, .ft4:
            ft8Engine = FT8Engine(sampleRate: mode == .ft4 ? sampleRate : 12000)
        case .psk31:
            psk31Decoder = PSK31Decoder(sampleRate: sampleRate)
        case .rtty:
            rttyDecoder = RTTYDecoder(sampleRate: sampleRate)
        case .cw:
            // CW decoder is handled by CWDecoder actor (separate)
            break
        case .none:
            break
        }
    }

    // MARK: - Audio processing

    /// Feed audio samples to the active decoder.
    ///
    /// Routes samples to whichever decoder is currently active and returns
    /// any decoded messages.
    ///
    /// - Parameter samples: Mono audio samples (Float).
    /// - Returns: Array of decoded messages (may be empty).
    public func processAudio(_ samples: [Float]) async -> [DecodedMessage] {
        var messages: [DecodedMessage] = []

        switch activeMode {
        case .psk31:
            if let decoder = psk31Decoder {
                let text = await decoder.process(samples: samples)
                if !text.isEmpty {
                    let freq = await decoder.centerFrequency
                    let msg = DecodedMessage(
                        mode: .psk31,
                        text: text,
                        frequency: freq
                    )
                    messages.append(msg)
                    messageContinuation?.yield(msg)
                }
            }

        case .rtty:
            if let decoder = rttyDecoder {
                let text = await decoder.process(samples: samples)
                if !text.isEmpty {
                    let msg = DecodedMessage(
                        mode: .rtty,
                        text: text,
                        frequency: await decoder.markFrequency
                    )
                    messages.append(msg)
                    messageContinuation?.yield(msg)
                }
            }

        case .ft8, .ft4:
            // FT8/FT4 manages its own cycle timing via FT8Engine.start(audioStream:)
            // Direct sample processing is not used here; use the engine's stream API.
            break

        case .cw, .none:
            break
        }

        return messages
    }

    // MARK: - Message stream

    /// Unified async stream of decoded messages from any active mode.
    public var messageStream: AsyncStream<DecodedMessage> {
        AsyncStream { continuation in
            self.setMessageContinuation(continuation)
        }
    }

    private func setMessageContinuation(_ continuation: AsyncStream<DecodedMessage>.Continuation) {
        self.messageContinuation = continuation
    }
}
