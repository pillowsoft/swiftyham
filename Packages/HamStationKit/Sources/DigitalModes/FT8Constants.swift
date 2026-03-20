// FT8Constants.swift
// HamStationKit — FT8/FT4 protocol constants.
// Reference: ft8_lib (MIT, https://github.com/kgoba/ft8_lib)

import Foundation

/// Protocol constants for FT8 and FT4 digital modes.
///
/// FT8 uses 8-FSK modulation with 79 symbols per message, transmitted in 15-second
/// cycles synchronized to UTC. The encoding pipeline is:
/// 77-bit message -> CRC-14 -> LDPC(174,91) -> 79 symbols (Costas + data).
public struct FT8Constants: Sendable {

    // MARK: - Modulation parameters

    /// Duration of one symbol in seconds.
    public static let symbolPeriod: Double = 0.160

    /// Frequency spacing between adjacent tones in Hz.
    public static let toneSpacing: Double = 6.25

    /// Number of FSK tones (8-FSK).
    public static let numTones: Int = 8

    /// Bits per symbol (log2 of numTones).
    public static let bitsPerSymbol: Int = 3

    /// Total symbols per FT8 message (7 Costas + 29 data + 7 Costas + 29 data + 7 Costas).
    public static let numSymbols: Int = 79

    /// Number of data-carrying symbols.
    public static let numDataSymbols: Int = 58

    /// Number of Costas synchronization symbols (three groups of 7).
    public static let numCostasSymbols: Int = 21

    // MARK: - Error correction

    /// Payload bits in the FT8 message.
    public static let messageBits: Int = 77

    /// CRC bits appended to the message.
    public static let crcBits: Int = 14

    /// Total LDPC codeword length.
    public static let ldpcBits: Int = 174

    /// Data bits in the LDPC code (message + CRC).
    public static let ldpcDataBits: Int = 91

    /// Parity bits in the LDPC code.
    public static let ldpcParityBits: Int = 83

    // MARK: - Timing

    /// Standard FT8 sample rate in Hz.
    public static let sampleRate: Double = 12000

    /// Duration of one FT8 cycle in seconds.
    public static let cycleDuration: Double = 15.0

    /// Duration of the transmitted signal in seconds (79 * 0.16).
    public static let txDuration: Double = 12.64

    /// Samples per symbol at the standard sample rate.
    public static let samplesPerSymbol: Int = 1920 // 12000 * 0.16

    /// Total samples for one FT8 transmission.
    public static let totalSamples: Int = 151680 // 79 * 1920

    // MARK: - Frequency limits

    /// Bottom of the FT8 audio passband in Hz.
    public static let minFrequency: Double = 200

    /// Top of the FT8 audio passband in Hz.
    public static let maxFrequency: Double = 3000

    // MARK: - Costas synchronization

    /// The 7-element Costas array used for synchronization.
    /// Appears at symbol positions 0-6, 36-42, and 72-78.
    public static let costasPattern: [Int] = [3, 1, 4, 0, 6, 5, 2]

    /// Starting indices of the three Costas sync groups within the 79-symbol sequence.
    public static let costasPositions: [Int] = [0, 36, 72]

    /// Indices of all data symbol positions (non-Costas) within the 79-symbol sequence.
    public static let dataSymbolPositions: [Int] = {
        let costasSet = Set(
            costasPositions.flatMap { start in (start..<start + 7) }
        )
        return (0..<numSymbols).filter { !costasSet.contains($0) }
    }()

    // MARK: - FFT parameters for decoding

    /// FFT size for spectrogram computation.
    /// 1920 samples = one symbol period at 12 kHz, giving 6.25 Hz bin spacing.
    public static let fftSize: Int = 1920

    /// Hop size for the sliding FFT window (half a symbol period).
    public static let fftHop: Int = 960

    // MARK: - FT4 variant constants

    /// FT4 symbol period in seconds (faster than FT8).
    public static let ft4SymbolPeriod: Double = 0.048

    /// FT4 cycle duration in seconds.
    public static let ft4CycleDuration: Double = 7.5

    /// FT4 number of tones (4-FSK).
    public static let ft4NumTones: Int = 4

    /// FT4 tone spacing in Hz.
    public static let ft4ToneSpacing: Double = 20.8333 // 1 / ft4SymbolPeriod

    /// FT4 total symbols per message.
    public static let ft4NumSymbols: Int = 105

    // MARK: - Gray code mapping

    /// Gray code mapping for 3-bit symbols (FT8).
    /// Maps 3-bit binary value to tone index.
    public static let grayCode: [Int] = [0, 1, 3, 2, 5, 6, 4, 7]

    /// Inverse Gray code: maps tone index back to 3-bit binary value.
    public static let grayCodeInverse: [Int] = {
        var inv = [Int](repeating: 0, count: 8)
        for (i, g) in grayCode.enumerated() {
            inv[g] = i
        }
        return inv
    }()
}
