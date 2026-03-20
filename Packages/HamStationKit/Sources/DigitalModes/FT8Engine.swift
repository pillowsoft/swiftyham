// FT8Engine.swift
// HamStationKit — FT8 operating cycle manager.
// Coordinates receive/decode/transmit cycles synchronized to UTC.

import Foundation

/// Manages the FT8 operating cycle: receive, decode, display, and optionally transmit.
///
/// FT8 operates in 15-second cycles synchronized to UTC. Even cycles start at 00, 30
/// seconds; odd cycles start at 15, 45 seconds. The engine accumulates audio samples
/// during the receive window (12.64s), decodes at the end of the window, and optionally
/// transmits a response in the next cycle.
public actor FT8Engine {

    // MARK: - Properties

    private let decoder: FT8Decoder
    private let encoder: FT8Encoder

    /// Whether the engine is currently running.
    public private(set) var isRunning: Bool = false

    /// Current phase of the FT8 cycle.
    public private(set) var currentCycle: CyclePhase = .idle

    /// Active decode/cycle task.
    private var cycleTask: Task<Void, Never>?

    /// Continuation for the message stream.
    private var messageContinuation: AsyncStream<[FT8Message]>.Continuation?

    /// Auto-sequence state (nil when not auto-sequencing).
    public var autoSequence: AutoSequence?

    /// Phase of the FT8 operating cycle.
    public enum CyclePhase: Sendable, Equatable {
        case idle
        case receiving(startTime: Date)
        case decoding
        case transmitting(message: String)
    }

    // MARK: - Init

    /// Create an FT8 engine with optional custom decoder/encoder.
    /// - Parameters:
    ///   - sampleRate: Audio sample rate. Default 12000 Hz.
    public init(sampleRate: Double = FT8Constants.sampleRate) {
        self.decoder = FT8Decoder(sampleRate: sampleRate)
        self.encoder = FT8Encoder(sampleRate: sampleRate)
    }

    // MARK: - Message stream

    /// Stream of decoded FT8 messages, yielded at the end of each receive cycle.
    public var messageStream: AsyncStream<[FT8Message]> {
        AsyncStream { continuation in
            self.messageContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // Cleanup handled by stop()
            }
        }
    }

    // MARK: - Start / Stop

    /// Start the FT8 cycle loop, consuming audio from the given stream.
    ///
    /// The engine will:
    /// 1. Wait for the next UTC 15-second boundary
    /// 2. Accumulate 12.64 seconds of audio
    /// 3. Decode and emit results via `messageStream`
    /// 4. Repeat
    ///
    /// - Parameter audioStream: Async stream of audio sample chunks from the audio engine.
    public func start(audioStream: AsyncStream<[Float]>) {
        guard !isRunning else { return }
        isRunning = true

        cycleTask = Task { [weak self] in
            guard let self else { return }

            // Main cycle loop
            while !Task.isCancelled {
                // 1. Wait for next 15-second boundary
                await self.waitForCycleBoundary()

                guard !Task.isCancelled else { break }

                // 2. Receive phase: accumulate audio samples
                await self.setCyclePhase(.receiving(startTime: Date()))

                let samplesPerSymbol = Int(FT8Constants.sampleRate * FT8Constants.symbolPeriod)
                let targetSamples = FT8Constants.numSymbols * samplesPerSymbol
                var accumulated = [Float]()
                accumulated.reserveCapacity(targetSamples)

                // Collect audio chunks until we have enough
                for await chunk in audioStream {
                    accumulated.append(contentsOf: chunk)
                    if accumulated.count >= targetSamples {
                        break
                    }
                    if Task.isCancelled { break }
                }

                guard !Task.isCancelled else { break }

                // 3. Decode phase
                await self.setCyclePhase(.decoding)

                let samples = Array(accumulated.prefix(targetSamples))
                let messages = await self.performDecode(samples: samples)

                // 4. Emit results
                await self.emitMessages(messages)

                // 5. Auto-sequence: determine next TX message if applicable
                if let nextMessage = await self.processAutoSequence(decoded: messages) {
                    await self.setCyclePhase(.transmitting(message: nextMessage))
                    // Transmit would happen here in the next even/odd cycle
                }

                await self.setCyclePhase(.idle)
            }

            await self.setRunningFalse()
        }
    }

    /// Stop the FT8 engine.
    public func stop() {
        cycleTask?.cancel()
        cycleTask = nil
        isRunning = false
        currentCycle = .idle
        messageContinuation?.finish()
        messageContinuation = nil
    }

    // MARK: - Transmit

    /// Encode a message for transmission.
    ///
    /// - Parameters:
    ///   - message: The message text (e.g., "CQ W1AW FN31").
    ///   - frequency: Audio frequency within the passband in Hz.
    /// - Returns: Audio samples for the 12.64-second transmission.
    /// - Throws: If encoding fails.
    public func transmit(message: String, frequency: Double) throws -> [Float] {
        guard let audio = encoder.encode(message: message, audioFrequency: frequency) else {
            throw FT8EngineError.encodingFailed(message)
        }
        return audio
    }

    // MARK: - Auto-sequence

    /// State machine for automatic QSO sequencing.
    public struct AutoSequence: Sendable, Equatable {
        /// The station we're trying to work.
        public var targetCallsign: String?
        /// Our callsign.
        public var myCallsign: String
        /// Our 4-character grid square.
        public var myGrid: String
        /// Current state in the QSO sequence.
        public var state: SequenceState

        /// States in the FT8 auto-sequence QSO flow.
        public enum SequenceState: String, Sendable, Equatable {
            /// Not sequencing.
            case idle
            /// Calling CQ, waiting for a reply.
            case callingCQ
            /// Sent signal report, waiting for R+report.
            case sentReport
            /// Sent R+report, waiting for RR73.
            case sentRReport
            /// Sent RR73, QSO complete.
            case sentRR73
            /// QSO finished.
            case complete
        }

        public init(
            targetCallsign: String? = nil,
            myCallsign: String,
            myGrid: String,
            state: SequenceState = .idle
        ) {
            self.targetCallsign = targetCallsign
            self.myCallsign = myCallsign
            self.myGrid = myGrid
            self.state = state
        }
    }

    /// Start an auto-sequence (calling CQ or responding to a station).
    ///
    /// - Parameters:
    ///   - targetCallsign: The callsign to work (nil for CQ).
    ///   - myCallsign: Our callsign.
    ///   - myGrid: Our 4-character grid square.
    public func startAutoSequence(
        targetCallsign: String?,
        myCallsign: String,
        myGrid: String
    ) {
        autoSequence = AutoSequence(
            targetCallsign: targetCallsign,
            myCallsign: myCallsign,
            myGrid: myGrid,
            state: targetCallsign == nil ? .callingCQ : .sentReport
        )
    }

    /// Process decoded messages and determine the next auto-sequence action.
    ///
    /// - Parameter decoded: Messages decoded in the current cycle.
    /// - Returns: The next message to transmit, or `nil` if no action needed.
    public func processAutoSequence(decoded: [FT8Message]) -> String? {
        guard var seq = autoSequence else { return nil }

        let myCall = seq.myCallsign
        let myGrid = seq.myGrid

        // Find messages directed at us
        let toMe = decoded.filter { msg in
            msg.callsign2 == myCall || msg.callsign1 == myCall
        }

        switch seq.state {
        case .idle:
            return nil

        case .callingCQ:
            // Look for someone replying to our CQ
            if let reply = toMe.first(where: { $0.type == .reply }) {
                seq.targetCallsign = reply.callsign1
                seq.state = .sentReport
                autoSequence = seq
                // Send signal report
                let target = reply.callsign1
                return "\(target) \(myCall) \(formatReport(reply.snr))"
            }
            // No reply — keep calling CQ
            return "CQ \(myCall) \(myGrid)"

        case .sentReport:
            // Look for R+report from target
            if let rReport = toMe.first(where: {
                $0.type == .rrReport && $0.callsign1 == seq.targetCallsign
            }) {
                seq.state = .sentRR73
                autoSequence = seq
                let target = rReport.callsign1
                return "\(target) \(myCall) RR73"
            }
            // Look for signal report (maybe they didn't get ours)
            if let report = toMe.first(where: {
                $0.type == .report && $0.callsign1 == seq.targetCallsign
            }) {
                // Resend our report with R prefix
                let target = report.callsign1
                return "\(target) \(myCall) R\(formatReport(report.snr))"
            }
            return nil

        case .sentRReport:
            // Look for RR73 or 73 from target
            if let _ = toMe.first(where: {
                ($0.type == .rr73 || $0.type == .seventy3) && $0.callsign1 == seq.targetCallsign
            }) {
                seq.state = .complete
                autoSequence = seq
                return nil // QSO complete
            }
            return nil

        case .sentRR73:
            // QSO essentially complete, but look for 73 confirmation
            seq.state = .complete
            autoSequence = seq
            return nil

        case .complete:
            return nil
        }
    }

    // MARK: - Private helpers

    private func setCyclePhase(_ phase: CyclePhase) {
        currentCycle = phase
    }

    private func setRunningFalse() {
        isRunning = false
        currentCycle = .idle
    }

    private func performDecode(samples: [Float]) -> [FT8Message] {
        decoder.decode(samples: samples)
    }

    private func emitMessages(_ messages: [FT8Message]) {
        messageContinuation?.yield(messages)
    }

    /// Wait until the next UTC 15-second cycle boundary.
    private func waitForCycleBoundary() async {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let second = calendar.component(.second, from: now)
        let nanosecond = calendar.component(.nanosecond, from: now)

        // Next 15-second boundary
        let currentSlot = second / 15
        let nextBoundarySecond = (currentSlot + 1) * 15
        let secondsToWait = Double(nextBoundarySecond - second) - Double(nanosecond) / 1_000_000_000

        if secondsToWait > 0 && secondsToWait <= 15 {
            try? await Task.sleep(for: .milliseconds(Int(secondsToWait * 1000)))
        }
    }

    /// Format an SNR value as an FT8 report string.
    private func formatReport(_ snr: Int) -> String {
        if snr >= 0 {
            return String(format: "+%02d", min(snr, 50))
        } else {
            return String(format: "%03d", max(snr, -24))
        }
    }
}

// MARK: - Errors

/// Errors from FT8 engine operations.
public enum FT8EngineError: Error, Sendable {
    case encodingFailed(String)
    case notRunning
}
