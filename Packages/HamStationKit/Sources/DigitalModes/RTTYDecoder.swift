// RTTYDecoder.swift
// HamStationKit — Decodes RTTY (Radioteletype) signals from audio.
// FSK modulation: mark (1) and space (0) tones separated by 170 Hz.
// Standard: 45.45 baud, 5-bit Baudot code.
// Each character: 1 start bit (space) + 5 data bits + 1.5 stop bits (mark).

import Accelerate
import Foundation

/// Decodes RTTY (Radioteletype) audio signals using FSK tone detection.
///
/// Uses the Goertzel algorithm to detect mark and space tones, then
/// frames characters with start/stop bits and decodes via Baudot code.
public actor RTTYDecoder {

    // MARK: - Configuration

    /// Mark tone frequency in Hz (logical "1").
    public var markFrequency: Double = 2125

    /// Space tone frequency in Hz (logical "0").
    public var spaceFrequency: Double = 2295

    /// Baud rate (bits per second). Standard RTTY is 45.45.
    public var baudRate: Double = 45.45

    /// Whether mark and space are reversed (USB vs LSB).
    public var isReversed: Bool = false

    /// Accumulated decoded text.
    public private(set) var decodedText: String = ""

    /// Audio sample rate.
    public let sampleRate: Double

    // MARK: - Internal state

    /// Baudot decoder (tracks LETTERS/FIGURES shift).
    private var baudotDecoder = BaudotCode.Decoder()

    /// Samples per bit period.
    private var samplesPerBit: Int {
        Int(sampleRate / baudRate)
    }

    /// Carry-over samples between process calls.
    private var sampleBuffer: [Float] = []

    /// State machine for character framing.
    private enum FrameState: Sendable {
        case waitingForStart
        case readingData(bitsRead: Int, code: UInt8)
        case waitingForStop
    }

    private var frameState: FrameState = .waitingForStart

    /// Text stream continuation.
    private var textContinuation: AsyncStream<String>.Continuation?

    // MARK: - Init

    /// Create an RTTY decoder.
    /// - Parameter sampleRate: Audio sample rate in Hz. Default 48000.
    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Processing

    /// Process audio samples and return any newly decoded characters.
    ///
    /// Pipeline:
    /// 1. Compute mark and space tone magnitudes using Goertzel algorithm
    /// 2. For each bit period: compare magnitudes to determine bit value
    /// 3. Frame detection: start bit (space), 5 data bits, stop bit(s) (mark)
    /// 4. Feed 5-bit code into Baudot decoder
    ///
    /// - Parameter samples: Mono audio samples (Float).
    /// - Returns: Newly decoded text (may be empty).
    public func process(samples: [Float]) -> String {
        sampleBuffer.append(contentsOf: samples)

        var newText = ""
        let bitLen = samplesPerBit

        while sampleBuffer.count >= bitLen {
            let bitSamples = Array(sampleBuffer.prefix(bitLen))
            sampleBuffer.removeFirst(bitLen)

            // Detect mark vs space using Goertzel
            let bit = detectBit(samples: bitSamples)

            // Frame state machine
            switch frameState {
            case .waitingForStart:
                // Start bit is space (0)
                if bit == 0 {
                    frameState = .readingData(bitsRead: 0, code: 0)
                }
                // else: idle (mark), keep waiting

            case .readingData(let bitsRead, var code):
                // Data bits are LSB first
                if bit == 1 {
                    code |= (1 << bitsRead)
                }
                let newCount = bitsRead + 1
                if newCount >= 5 {
                    // Got all 5 data bits — decode
                    if let ch = baudotDecoder.decode(code) {
                        newText.append(ch)
                        decodedText.append(ch)
                        textContinuation?.yield(decodedText)
                    }
                    frameState = .waitingForStop
                } else {
                    frameState = .readingData(bitsRead: newCount, code: code)
                }

            case .waitingForStop:
                // Stop bit should be mark (1); accept and go back to waiting
                // (We only check one bit period for the stop; the 0.5 extra is absorbed)
                frameState = .waitingForStart
            }
        }

        return newText
    }

    // MARK: - Text stream

    /// Async stream of accumulated decoded text.
    public var textStream: AsyncStream<String> {
        AsyncStream { continuation in
            self.setContinuation(continuation)
        }
    }

    private func setContinuation(_ continuation: AsyncStream<String>.Continuation) {
        self.textContinuation = continuation
    }

    // MARK: - Reset

    /// Reset all decoder state.
    public func reset() {
        sampleBuffer = []
        frameState = .waitingForStart
        baudotDecoder = BaudotCode.Decoder()
        decodedText = ""
    }

    // MARK: - Internal DSP

    /// Detect whether a bit period contains mark (1) or space (0).
    ///
    /// Uses the Goertzel algorithm on both mark and space frequencies,
    /// then compares magnitudes.
    ///
    /// - Parameter samples: One bit period of audio samples.
    /// - Returns: 1 for mark, 0 for space.
    private func detectBit(samples: [Float]) -> UInt8 {
        let markMag = goertzel(samples: samples, frequency: markFrequency)
        let spaceMag = goertzel(samples: samples, frequency: spaceFrequency)

        let isMark: Bool
        if isReversed {
            isMark = spaceMag > markMag
        } else {
            isMark = markMag > spaceMag
        }

        return isMark ? 1 : 0
    }

    /// Goertzel algorithm for single-frequency magnitude detection.
    ///
    /// - Parameters:
    ///   - samples: Audio samples to analyze.
    ///   - frequency: Target frequency in Hz.
    /// - Returns: Magnitude at the target frequency.
    private func goertzel(samples: [Float], frequency: Double) -> Float {
        let n = samples.count
        guard n > 0 else { return 0 }

        let k = Int(0.5 + Double(n) * frequency / sampleRate)
        let w = 2.0 * Double.pi * Double(k) / Double(n)
        let coeff = Float(2.0 * cos(w))

        var s1: Float = 0
        var s2: Float = 0

        for sample in samples {
            let s = sample + coeff * s1 - s2
            s2 = s1
            s1 = s
        }

        let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
        return sqrt(abs(power))
    }
}
