// CWDecoder.swift
// HamStationKit — Traditional DSP-based CW decoder using Goertzel algorithm.

import Foundation

// MARK: - Goertzel result

/// Result of a Goertzel single-frequency detection on one audio window.
public struct GoertzelResult: Sendable, Equatable {
    /// Signal magnitude at the target frequency.
    public var magnitude: Float
    /// Whether the magnitude exceeds the detection threshold (key is down).
    public var isKeyDown: Bool
}

// MARK: - Decoded element

/// A decoded element emitted by the CW decoder.
public enum DecodedElement: Sendable, Equatable {
    case character(Character)
    case wordSpace
    case unknown // unrecognized dit/dah pattern
}

// MARK: - CWDecoder actor

/// Decodes CW (Morse code) audio using the Goertzel algorithm for tone detection,
/// adaptive thresholding, and automatic speed tracking.
///
/// Feed it audio chunks from `AudioEngine.decoderAudioStream()`.
/// Decoded text is emitted via `textStream`.
public actor CWDecoder {

    // MARK: - Configuration

    /// Center frequency of the CW tone to detect, in Hz.
    public var centerFrequency: Double = 700

    /// Detection bandwidth in Hz.
    public var bandwidth: Double = 100

    /// Current estimated speed in WPM (auto-tracked).
    public private(set) var currentSpeedWPM: Double = 20

    /// Accumulated decoded text.
    public private(set) var decodedText: String = ""

    // MARK: - Adaptive threshold state

    /// Noise floor estimate (exponential moving average of quiet magnitudes).
    private var noiseFloor: Float = 0

    /// Signal peak estimate (exponential moving average of keyed magnitudes).
    private var signalPeak: Float = 0.001

    /// Detection threshold — midpoint between noise floor and signal peak.
    public var threshold: Float {
        (noiseFloor + signalPeak) / 2.0
    }

    // MARK: - Timing state

    /// Whether the key is currently detected as down.
    private var isKeyDown: Bool = false

    /// Sample count since last key-down/key-up transition.
    private var transitionSamples: Int = 0

    /// Current accumulated dit/dah pattern for the character being received.
    private var currentPattern: String = ""

    /// Rolling window of recent dit durations (in seconds) for adaptive speed.
    private var recentDitDurations: [Double] = []
    private let maxDitHistory = 20

    /// Estimated dit duration in seconds, from median of recent measurements.
    private var estimatedDitDuration: Double {
        guard !recentDitDurations.isEmpty else { return 1.2 / currentSpeedWPM }
        var sorted = recentDitDurations.sorted()
        return sorted[sorted.count / 2]
    }

    // MARK: - Text stream

    private var textContinuation: AsyncStream<String>.Continuation?

    /// AsyncStream that yields accumulated decoded text whenever new characters arrive.
    public var textStream: AsyncStream<String> {
        AsyncStream { continuation in
            self.setContinuation(continuation)
        }
    }

    private func setContinuation(_ continuation: AsyncStream<String>.Continuation) {
        self.textContinuation = continuation
    }

    // MARK: - Goertzel algorithm

    /// Compute the magnitude at a single target frequency using the Goertzel algorithm.
    ///
    /// More efficient than a full FFT when only one frequency bin is needed.
    ///
    /// - Parameters:
    ///   - samples: Audio samples to analyze.
    ///   - targetFrequency: Frequency to detect, in Hz.
    ///   - sampleRate: Sample rate of the audio, in Hz.
    /// - Returns: Magnitude at the target frequency.
    public static func goertzel(
        samples: [Float],
        targetFrequency: Double,
        sampleRate: Double
    ) -> Float {
        let n = samples.count
        guard n > 0 else { return 0 }

        let k = Int(0.5 + Double(n) * targetFrequency / sampleRate)
        let w = 2.0 * Double.pi * Double(k) / Double(n)
        let coeff = Float(2.0 * cos(w))

        var s1: Float = 0
        var s2: Float = 0

        for sample in samples {
            let s = sample + coeff * s1 - s2
            s2 = s1
            s1 = s
        }

        // Power at the target frequency
        let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
        return sqrt(abs(power))
    }

    // MARK: - Processing

    /// Process a chunk of audio samples and return any decoded elements.
    ///
    /// Internally runs Goertzel on overlapping 10ms windows with 5ms hop,
    /// detects key-down/key-up transitions, classifies elements, and looks up characters.
    ///
    /// - Parameters:
    ///   - samples: Audio samples (mono, Float).
    ///   - sampleRate: Sample rate in Hz (default 48000).
    /// - Returns: Array of decoded elements (may be empty if mid-character).
    public func process(samples: [Float], sampleRate: Double = 48000) -> [DecodedElement] {
        var decoded: [DecodedElement] = []

        // Window parameters: 10ms window, 5ms hop
        let windowSamples = Int(sampleRate * 0.010) // 10ms
        let hopSamples = Int(sampleRate * 0.005)     // 5ms

        var offset = 0
        while offset + windowSamples <= samples.count {
            let windowEnd = offset + windowSamples
            let window = Array(samples[offset..<windowEnd])

            let magnitude = Self.goertzel(
                samples: window,
                targetFrequency: centerFrequency,
                sampleRate: sampleRate
            )

            // Update adaptive threshold
            updateThreshold(magnitude: magnitude)

            let keyDown = magnitude > threshold

            if keyDown != isKeyDown {
                // Transition detected
                let durationSec = Double(transitionSamples) / sampleRate

                if isKeyDown {
                    // Key was down, now up → classify the element
                    let ditDur = estimatedDitDuration
                    let boundary = ditDur * 2.0 // midpoint between dit (1x) and dah (3x)

                    if durationSec < boundary {
                        currentPattern.append(".")
                        recordDitDuration(durationSec)
                    } else {
                        currentPattern.append("-")
                    }
                } else {
                    // Key was up, now down → classify the space
                    let ditDur = estimatedDitDuration
                    let charSpaceBoundary = ditDur * 2.0  // between element (1x) and char (3x)
                    let wordSpaceBoundary = ditDur * 5.0  // between char (3x) and word (7x)

                    if durationSec >= wordSpaceBoundary {
                        // Word space: emit current char + word space
                        if let element = decodeCurrentPattern() {
                            decoded.append(element)
                        }
                        decoded.append(.wordSpace)
                    } else if durationSec >= charSpaceBoundary {
                        // Character space: emit current char
                        if let element = decodeCurrentPattern() {
                            decoded.append(element)
                        }
                    }
                    // else: element space (within character), do nothing
                }

                isKeyDown = keyDown
                transitionSamples = hopSamples
            } else {
                transitionSamples += hopSamples
            }

            offset += hopSamples
        }

        // Flush pending character if we've been in silence long enough
        if !isKeyDown && !currentPattern.isEmpty {
            let silenceDuration = Double(transitionSamples) / sampleRate
            let ditDur = estimatedDitDuration
            let charSpaceBoundary = ditDur * 2.0
            let wordSpaceBoundary = ditDur * 5.0

            if silenceDuration >= wordSpaceBoundary {
                if let element = decodeCurrentPattern() {
                    decoded.append(element)
                }
                decoded.append(.wordSpace)
            } else if silenceDuration >= charSpaceBoundary {
                if let element = decodeCurrentPattern() {
                    decoded.append(element)
                }
            }
        }

        // Emit decoded characters to text stream
        for element in decoded {
            switch element {
            case .character(let ch):
                decodedText.append(ch)
                textContinuation?.yield(decodedText)
            case .wordSpace:
                decodedText.append(" ")
                textContinuation?.yield(decodedText)
            case .unknown:
                decodedText.append("\u{FFFD}") // replacement character
                textContinuation?.yield(decodedText)
            }
        }

        return decoded
    }

    // MARK: - Internal helpers

    /// Decode the accumulated dit/dah pattern into a character.
    private func decodeCurrentPattern() -> DecodedElement? {
        guard !currentPattern.isEmpty else { return nil }
        let pattern = currentPattern
        currentPattern = ""

        if let char = CWKeyer.reverseMorseTable[pattern] {
            return .character(char)
        } else {
            return .unknown
        }
    }

    /// Update adaptive noise floor and signal peak estimates.
    private func updateThreshold(magnitude: Float) {
        let alpha: Float = 0.01 // smoothing factor

        if magnitude > threshold {
            // Likely signal — update signal peak
            signalPeak = signalPeak * (1 - alpha) + magnitude * alpha
        } else {
            // Likely noise — update noise floor
            noiseFloor = noiseFloor * (1 - alpha) + magnitude * alpha
        }

        // Ensure signal peak stays above noise floor
        if signalPeak < noiseFloor * 1.5 {
            signalPeak = noiseFloor * 1.5
        }
    }

    /// Record a measured dit duration for adaptive speed tracking.
    private func recordDitDuration(_ duration: Double) {
        recentDitDurations.append(duration)
        if recentDitDurations.count > maxDitHistory {
            recentDitDurations.removeFirst()
        }
        // Update WPM estimate: WPM = 1200 / ditMs
        let ditMs = estimatedDitDuration * 1000.0
        if ditMs > 0 {
            currentSpeedWPM = 1200.0 / ditMs
        }
    }

    /// Reset all decoder state.
    public func reset() {
        isKeyDown = false
        transitionSamples = 0
        currentPattern = ""
        recentDitDurations = []
        noiseFloor = 0
        signalPeak = 0.001
        currentSpeedWPM = 20
        decodedText = ""
    }
}
