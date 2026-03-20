// PSK31Decoder.swift
// HamStationKit — Decodes PSK31 (BPSK31) signals from audio.
// BPSK modulation at 31.25 baud (32ms per symbol).
// Phase reversal = "1", no reversal = "0".
// Characters encoded with Varicode, separated by "00".

import Accelerate
import Foundation

/// Decodes PSK31 (Phase Shift Keying, 31.25 baud) signals from audio samples.
///
/// The decoder uses product detection (multiply by cos/sin at center frequency)
/// to extract I/Q components, then detects phase reversals between consecutive
/// symbols. Phase reversals map to "1" bits, same-phase to "0" bits.
/// Bits are fed to the Varicode decoder to produce text.
public actor PSK31Decoder {

    // MARK: - Configuration

    /// Center frequency of the PSK31 signal in Hz.
    public var centerFrequency: Double = 1000

    /// Detection bandwidth in Hz.
    public var bandwidth: Double = 50

    /// Accumulated decoded text.
    public private(set) var decodedText: String = ""

    /// Audio sample rate.
    public let sampleRate: Double

    // MARK: - Internal state

    /// Samples per symbol at 31.25 baud.
    private var samplesPerSymbol: Int {
        Int(sampleRate / 31.25)
    }

    /// Accumulator for incoming samples (carry-over between process calls).
    private var sampleBuffer: [Float] = []

    /// Previous symbol's I and Q values for phase comparison.
    private var prevI: Float = 0
    private var prevQ: Float = 0

    /// Accumulated bits for Varicode decoding.
    private var bitBuffer: [UInt8] = []

    /// Total sample count for continuous phase reference.
    private var totalSampleCount: Int = 0

    /// Text stream continuation.
    private var textContinuation: AsyncStream<String>.Continuation?

    // MARK: - Init

    /// Create a PSK31 decoder.
    /// - Parameter sampleRate: Audio sample rate in Hz. Default 48000.
    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Processing

    /// Process audio samples and return any newly decoded characters.
    ///
    /// Pipeline:
    /// 1. Multiply signal by cos/sin at center frequency (product detection)
    /// 2. Integrate over one symbol period (32ms) to get I and Q
    /// 3. Compare phase with previous symbol: reversal = "1", same = "0"
    /// 4. Feed bits to Varicode decoder; emit characters on "00" separator
    ///
    /// - Parameter samples: Mono audio samples (Float).
    /// - Returns: Newly decoded text (may be empty if mid-character).
    public func process(samples: [Float]) -> String {
        sampleBuffer.append(contentsOf: samples)

        var newText = ""
        let symbolLen = samplesPerSymbol

        while sampleBuffer.count >= symbolLen {
            let symbolSamples = Array(sampleBuffer.prefix(symbolLen))
            sampleBuffer.removeFirst(symbolLen)

            // Product detection: multiply by cos and sin at center frequency
            let (iVal, qVal) = computeIQ(samples: symbolSamples, startSample: totalSampleCount)
            totalSampleCount += symbolLen

            // Detect phase reversal by comparing with previous symbol
            // dot product of (prevI, prevQ) and (iVal, qVal):
            // positive = same phase (bit 0), negative = reversed (bit 1)
            let dotProduct = prevI * iVal + prevQ * qVal
            let magnitude = sqrt(iVal * iVal + qVal * qVal)

            // Only decode if we have enough signal
            if magnitude > 0.001 && (prevI != 0 || prevQ != 0) {
                let bit: UInt8 = dotProduct < 0 ? 1 : 0
                bitBuffer.append(bit)

                // Check for "00" character separator
                let decoded = decodeVaricodeBits()
                if !decoded.isEmpty {
                    newText += decoded
                    decodedText += decoded
                    textContinuation?.yield(decodedText)
                }
            }

            // AFC: adjust center frequency based on frequency error estimate
            if magnitude > 0.01 {
                updateFrequency(i: iVal, q: qVal)
            }

            prevI = iVal
            prevQ = qVal
        }

        return newText
    }

    // MARK: - Text stream

    /// Async stream of accumulated decoded text, yielded as new characters arrive.
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
        prevI = 0
        prevQ = 0
        bitBuffer = []
        totalSampleCount = 0
        decodedText = ""
    }

    // MARK: - Internal DSP

    /// Compute I (in-phase) and Q (quadrature) components for a symbol.
    ///
    /// Multiplies the signal by cos(2*pi*f*t) and sin(2*pi*f*t) at the
    /// center frequency and integrates (sums) over the symbol period.
    ///
    /// - Parameters:
    ///   - samples: Audio samples for one symbol period.
    ///   - startSample: Absolute sample index for phase continuity.
    private func computeIQ(samples: [Float], startSample: Int) -> (Float, Float) {
        var iSum: Float = 0
        var qSum: Float = 0
        let omega = 2.0 * Double.pi * centerFrequency / sampleRate

        for (idx, sample) in samples.enumerated() {
            let phase = omega * Double(startSample + idx)
            iSum += sample * Float(cos(phase))
            qSum += sample * Float(sin(phase))
        }

        let norm = Float(samples.count)
        return (iSum / norm, qSum / norm)
    }

    /// Decode accumulated bits looking for Varicode "00" separators.
    ///
    /// Returns decoded characters and removes consumed bits from the buffer.
    /// Uses the same decoding logic as `Varicode.decode()`: Varicode codes
    /// never contain two consecutive zeros, so "00" always marks a boundary.
    private func decodeVaricodeBits() -> String {
        // Use the shared Varicode decoder on the full bit buffer
        let decoded = Varicode.decode(bitBuffer)

        if !decoded.isEmpty {
            // Find how many bits were consumed: everything up to and including
            // the last "00" separator that produced a character
            // We'll just re-encode what was decoded to know the consumed count,
            // or we can scan for the last "00" in the buffer.
            var consumed = 0
            var lastBitWasZero = false
            var charCount = 0
            var bitIdx = 0

            while bitIdx < bitBuffer.count && charCount < decoded.count {
                let bit = bitBuffer[bitIdx]
                if bit == 0 {
                    if lastBitWasZero {
                        charCount += 1
                        consumed = bitIdx + 1
                        lastBitWasZero = false
                    } else {
                        lastBitWasZero = true
                    }
                } else {
                    lastBitWasZero = false
                }
                bitIdx += 1
            }

            if consumed > 0 {
                bitBuffer.removeFirst(consumed)
            }
        }

        // Prevent unbounded growth (idle produces continuous zeros)
        if bitBuffer.count > 100 {
            bitBuffer.removeFirst(bitBuffer.count - 50)
        }

        return decoded
    }

    /// Previous phase angle for frequency error estimation.
    private var prevPhaseAngle: Float = 0

    /// Smoothed frequency error estimate.
    private var smoothedFreqError: Double = 0

    /// Automatic frequency control: nudge center frequency based on frequency error.
    ///
    /// Estimates frequency offset from the rate of phase change between symbols,
    /// then applies a very gentle exponential correction.
    private func updateFrequency(i: Float, q: Float) {
        let phase = atan2(q, i)
        // Phase difference between consecutive symbols estimates frequency error
        var phaseDiff = Double(phase - prevPhaseAngle)
        // Wrap to [-pi, pi]
        while phaseDiff > Double.pi { phaseDiff -= 2.0 * Double.pi }
        while phaseDiff < -Double.pi { phaseDiff += 2.0 * Double.pi }
        prevPhaseAngle = phase

        // Convert phase change per symbol to frequency offset
        // freq_error = phaseDiff / (2*pi * symbolPeriod)
        let freqError = phaseDiff / (2.0 * Double.pi * (1.0 / 31.25))

        // Exponential smoothing of frequency error
        smoothedFreqError = smoothedFreqError * 0.95 + freqError * 0.05

        // Only correct if the smoothed error is significant (> 0.5 Hz)
        if abs(smoothedFreqError) > 0.5 {
            let correction = smoothedFreqError * 0.01 // Very gentle: 1% of error per symbol
            let clampedCorrection = max(-0.2, min(0.2, correction))
            centerFrequency += clampedCorrection
        }
    }
}
