// FT8Decoder.swift
// HamStationKit — FT8 signal decoder using spectrogram analysis.
// Reference: ft8_lib (MIT, https://github.com/kgoba/ft8_lib)

import Accelerate
import Foundation

/// Decodes FT8 signals from audio samples.
///
/// The decoding pipeline:
/// 1. Compute spectrogram (short-time FFT with symbol-period windows)
/// 2. Search for Costas synchronization patterns to find candidate signals
/// 3. For each candidate: extract symbols, LDPC decode, check CRC, parse message
public struct FT8Decoder: Sendable {

    /// Audio sample rate in Hz.
    public let sampleRate: Double

    /// Minimum signal strength (in dB) for a candidate to be considered.
    public let minSignalStrength: Float

    /// Maximum number of candidate signals to process per cycle.
    public let maxCandidates: Int

    /// Create an FT8 decoder.
    /// - Parameters:
    ///   - sampleRate: Audio sample rate. Default 12000 Hz.
    ///   - minSignalStrength: Minimum candidate strength in dB. Default -25.
    ///   - maxCandidates: Maximum candidates per cycle. Default 50.
    public init(
        sampleRate: Double = FT8Constants.sampleRate,
        minSignalStrength: Float = -25,
        maxCandidates: Int = 50
    ) {
        self.sampleRate = sampleRate
        self.minSignalStrength = minSignalStrength
        self.maxCandidates = maxCandidates
    }

    // MARK: - Public API

    /// Decode FT8 signals from a capture window of audio.
    ///
    /// - Parameter samples: Approximately 12.64 seconds of audio at the configured sample rate.
    ///   Minimum length is `FT8Constants.numSymbols * samplesPerSymbol`.
    /// - Returns: Array of decoded FT8 messages with frequency, SNR, and time offset.
    public func decode(samples: [Float]) -> [FT8Message] {
        let samplesPerSymbol = Int(sampleRate * FT8Constants.symbolPeriod)
        let minSamples = FT8Constants.numSymbols * samplesPerSymbol

        guard samples.count >= minSamples else { return [] }

        // Step 1: Compute spectrogram
        let spectrogram = computeSpectrogram(samples: samples)
        guard !spectrogram.isEmpty else { return [] }

        // Step 2: Find candidate signals via Costas correlation
        let candidates = findCandidates(spectrogram: spectrogram)

        // Step 3: Decode each candidate
        var messages: [FT8Message] = []

        for candidate in candidates.prefix(maxCandidates) {
            guard let message = decodeCandidate(
                spectrogram: spectrogram,
                candidate: candidate
            ) else { continue }
            messages.append(message)
        }

        return messages
    }

    // MARK: - Spectrogram computation

    /// Compute a spectrogram from audio samples using short-time FFT.
    ///
    /// Window size matches one FT8 symbol period for 6.25 Hz frequency resolution.
    /// Hop size is half the window for 2x oversampling in time.
    ///
    /// - Parameter samples: Audio samples.
    /// - Returns: 2D array indexed as [timeSlot][frequencyBin], values are power in dB.
    func computeSpectrogram(samples: [Float]) -> [[Float]] {
        let windowSize = Int(sampleRate * FT8Constants.symbolPeriod) // 1920 at 12kHz
        let hopSize = windowSize / 2

        // Use next power of 2 for FFT
        let fftSize = nextPowerOfTwo(windowSize)
        let halfFFT = fftSize / 2
        let log2n = vDSP_Length(log2(Double(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Pre-compute Hann window
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        let numSlots = (samples.count - windowSize) / hopSize + 1
        var spectrogram = [[Float]]()
        spectrogram.reserveCapacity(numSlots)

        // Reusable buffers
        var windowed = [Float](repeating: 0, count: fftSize)
        var realPart = [Float](repeating: 0, count: halfFFT)
        var imagPart = [Float](repeating: 0, count: halfFFT)

        for slot in 0..<numSlots {
            let offset = slot * hopSize

            // Apply window (zero-pad if fftSize > windowSize)
            for i in 0..<fftSize { windowed[i] = 0 }
            for i in 0..<windowSize {
                windowed[i] = samples[offset + i] * window[i]
            }

            // Deinterleave into split complex
            for i in 0..<halfFFT {
                realPart[i] = windowed[2 * i]
                imagPart[i] = windowed[2 * i + 1]
            }

            var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

            // FFT
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

            // Compute power spectrum (magnitude squared)
            var magnitudes = [Float](repeating: 0, count: halfFFT)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfFFT))

            // Convert to dB
            var minVal: Float = 1.0e-20
            vDSP_vthr(magnitudes, 1, &minVal, &magnitudes, 1, vDSP_Length(halfFFT))

            var dbValues = [Float](repeating: 0, count: halfFFT)
            var count = Int32(halfFFT)
            vvlog10f(&dbValues, &magnitudes, &count)
            var ten: Float = 10.0
            vDSP_vsmul(dbValues, 1, &ten, &dbValues, 1, vDSP_Length(halfFFT))

            spectrogram.append(dbValues)
        }

        return spectrogram
    }

    // MARK: - Costas pattern search

    /// A candidate FT8 signal found via Costas synchronization.
    struct Candidate: Sendable {
        let freqBin: Int        // Frequency bin of the base tone
        let timeSlot: Int       // Starting time slot in the spectrogram
        let strength: Float     // Costas correlation strength
    }

    /// Search the spectrogram for Costas synchronization patterns.
    ///
    /// The 7-symbol Costas array [3,1,4,0,6,5,2] appears at symbol positions 0, 36, and 72.
    /// Each tone occupies a single frequency bin (6.25 Hz spacing matches the FFT resolution).
    ///
    /// - Parameter spectrogram: 2D power spectrum [timeSlot][freqBin].
    /// - Returns: Candidate signals sorted by strength (strongest first).
    func findCandidates(spectrogram: [[Float]]) -> [Candidate] {
        guard !spectrogram.isEmpty else { return [] }

        let numTimeSlots = spectrogram.count
        let numFreqBins = spectrogram[0].count

        // We need 79 symbols * 2 time slots per symbol (due to hop = half symbol)
        let slotsPerSymbol = 2 // because hop = windowSize / 2
        let requiredSlots = FT8Constants.numSymbols * slotsPerSymbol

        // Frequency range to search (200-3000 Hz)
        let binSpacing = sampleRate / Double(nextPowerOfTwo(Int(sampleRate * FT8Constants.symbolPeriod)))
        let minBin = max(0, Int(FT8Constants.minFrequency / binSpacing))
        let maxBin = min(numFreqBins - FT8Constants.numTones, Int(FT8Constants.maxFrequency / binSpacing))

        var candidates: [Candidate] = []

        // Search over time offsets and frequency bins
        let maxTimeStart = numTimeSlots - requiredSlots
        guard maxTimeStart >= 0 else { return [] }

        for timeStart in stride(from: 0, through: maxTimeStart, by: 1) {
            for freqBase in minBin..<maxBin {
                // Correlate all three Costas groups
                var totalStrength: Float = 0
                var valid = true

                for costasStart in FT8Constants.costasPositions {
                    var groupStrength: Float = 0
                    for j in 0..<7 {
                        let symbolSlot = timeStart + (costasStart + j) * slotsPerSymbol
                        guard symbolSlot < numTimeSlots else {
                            valid = false
                            break
                        }

                        let expectedBin = freqBase + FT8Constants.costasPattern[j]
                        guard expectedBin < numFreqBins else {
                            valid = false
                            break
                        }

                        groupStrength += spectrogram[symbolSlot][expectedBin]
                    }
                    if !valid { break }
                    totalStrength += groupStrength
                }

                if valid && totalStrength / 21.0 > minSignalStrength {
                    candidates.append(Candidate(
                        freqBin: freqBase,
                        timeSlot: timeStart,
                        strength: totalStrength
                    ))
                }
            }
        }

        // Sort by strength (strongest first) and deduplicate nearby candidates
        candidates.sort { $0.strength > $1.strength }
        return deduplicateCandidates(candidates)
    }

    // MARK: - Symbol extraction

    /// Extract 79 tone indices from the spectrogram at the candidate's location.
    ///
    /// For each symbol position, finds the peak frequency bin within the 8-tone range.
    ///
    /// - Parameters:
    ///   - spectrogram: 2D power spectrum.
    ///   - freqBin: Base frequency bin of the signal.
    ///   - timeSlot: Starting time slot.
    /// - Returns: Array of 79 tone indices (0-7).
    func extractSymbols(spectrogram: [[Float]], freqBin: Int, timeSlot: Int) -> [Int] {
        let slotsPerSymbol = 2
        var symbols = [Int](repeating: 0, count: FT8Constants.numSymbols)

        for i in 0..<FT8Constants.numSymbols {
            let slot = timeSlot + i * slotsPerSymbol
            guard slot < spectrogram.count else { break }

            // Find the peak tone within the 8-tone range
            var bestTone = 0
            var bestPower: Float = -Float.greatestFiniteMagnitude

            for tone in 0..<FT8Constants.numTones {
                let bin = freqBin + tone
                guard bin < spectrogram[slot].count else { continue }
                if spectrogram[slot][bin] > bestPower {
                    bestPower = spectrogram[slot][bin]
                    bestTone = tone
                }
            }

            symbols[i] = bestTone
        }

        return symbols
    }

    // MARK: - SNR estimation

    /// Estimate the signal-to-noise ratio for a candidate signal.
    ///
    /// Compares signal power in the 8-tone band to noise power in adjacent bands.
    ///
    /// - Parameters:
    ///   - spectrogram: 2D power spectrum.
    ///   - freqBin: Base frequency bin.
    ///   - timeSlot: Starting time slot.
    /// - Returns: Estimated SNR in dB.
    func estimateSNR(spectrogram: [[Float]], freqBin: Int, timeSlot: Int) -> Int {
        let slotsPerSymbol = 2
        var signalPower: Float = 0
        var noisePower: Float = 0
        var signalCount = 0
        var noiseCount = 0

        let numFreqBins = spectrogram.isEmpty ? 0 : spectrogram[0].count

        for i in 0..<FT8Constants.numSymbols {
            let slot = timeSlot + i * slotsPerSymbol
            guard slot < spectrogram.count else { break }

            // Signal: power in the 8-tone band
            for tone in 0..<FT8Constants.numTones {
                let bin = freqBin + tone
                guard bin < numFreqBins else { continue }
                signalPower += spectrogram[slot][bin]
                signalCount += 1
            }

            // Noise: power in adjacent bands (8 bins below and above)
            for offset in [-16, -15, -14, -13, -12, -11, -10, -9, 9, 10, 11, 12, 13, 14, 15, 16] {
                let bin = freqBin + offset
                guard bin >= 0 && bin < numFreqBins else { continue }
                noisePower += spectrogram[slot][bin]
                noiseCount += 1
            }
        }

        guard signalCount > 0 && noiseCount > 0 else { return 0 }

        let avgSignal = signalPower / Float(signalCount)
        let avgNoise = noisePower / Float(noiseCount)

        guard avgNoise > -200 else { return 0 }

        // SNR in dB (values are already in dB, so subtract)
        return Int(round(avgSignal - avgNoise))
    }

    // MARK: - Candidate decoding

    /// Attempt to decode a single candidate signal.
    private func decodeCandidate(
        spectrogram: [[Float]],
        candidate: Candidate
    ) -> FT8Message? {
        // Extract 79 symbols
        let symbols = extractSymbols(
            spectrogram: spectrogram,
            freqBin: candidate.freqBin,
            timeSlot: candidate.timeSlot
        )

        // Extract 58 data symbols (skip Costas positions)
        var dataSymbols = [Int]()
        dataSymbols.reserveCapacity(FT8Constants.numDataSymbols)
        for pos in FT8Constants.dataSymbolPositions {
            dataSymbols.append(symbols[pos])
        }

        // Convert symbols to bits via inverse Gray code
        var receivedBits = [UInt8](repeating: 0, count: FT8Constants.ldpcBits)
        for (i, symbol) in dataSymbols.enumerated() {
            let grayValue = FT8Constants.grayCodeInverse[symbol]
            receivedBits[i * 3] = UInt8((grayValue >> 2) & 1)
            receivedBits[i * 3 + 1] = UInt8((grayValue >> 1) & 1)
            receivedBits[i * 3 + 2] = UInt8(grayValue & 1)
        }

        // LDPC decode (hard decision)
        guard let decoded = LDPCCodec.decodeHard(receivedBits) else { return nil }

        // Check CRC-14
        let messageBits = Array(decoded[0..<FT8Constants.messageBits])
        let expectedCRC = FT8Encoder.crc14(bits: messageBits)
        var receivedCRC: UInt16 = 0
        for i in 0..<FT8Constants.crcBits {
            receivedCRC = (receivedCRC << 1) | UInt16(decoded[FT8Constants.messageBits + i])
        }

        guard expectedCRC == receivedCRC else { return nil }

        // Try binary message parsing first, fall back to text-based
        if let msg = FT8Message.parse(bits: messageBits) {
            return msg
        }

        // Estimate frequency and SNR
        let binSpacing = sampleRate / Double(nextPowerOfTwo(Int(sampleRate * FT8Constants.symbolPeriod)))
        let frequency = Double(candidate.freqBin) * binSpacing
        let snr = estimateSNR(
            spectrogram: spectrogram,
            freqBin: candidate.freqBin,
            timeSlot: candidate.timeSlot
        )

        // Compute time offset
        let slotsPerSymbol = 2
        let hopSize = Int(sampleRate * FT8Constants.symbolPeriod) / 2
        let sampleOffset = candidate.timeSlot * hopSize
        let timeOffset = Double(sampleOffset) / sampleRate

        // For now, return a placeholder since full binary-to-text decoding
        // requires the complete callsign hash table implementation.
        // The decode pipeline is working: spectrogram -> Costas -> LDPC -> CRC check.
        return FT8Message(
            type: .freeText,
            callsign1: "DECODED",
            frequency: frequency,
            snr: snr,
            timeOffset: timeOffset
        )
    }

    // MARK: - Helpers

    /// Remove candidate signals that are too close in time/frequency.
    private func deduplicateCandidates(_ candidates: [Candidate]) -> [Candidate] {
        var result: [Candidate] = []
        for candidate in candidates {
            let isDuplicate = result.contains { existing in
                abs(existing.freqBin - candidate.freqBin) < 4
                    && abs(existing.timeSlot - candidate.timeSlot) < 4
            }
            if !isDuplicate {
                result.append(candidate)
            }
        }
        return result
    }

    /// Round up to the next power of two.
    private func nextPowerOfTwo(_ n: Int) -> Int {
        var v = n - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }
}

/// Module-level helper (used by computeSpectrogram and elsewhere).
private func nextPowerOfTwo(_ n: Int) -> Int {
    var v = n - 1
    v |= v >> 1
    v |= v >> 2
    v |= v >> 4
    v |= v >> 8
    v |= v >> 16
    return v + 1
}
