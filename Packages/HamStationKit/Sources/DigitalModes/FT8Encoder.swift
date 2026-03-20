// FT8Encoder.swift
// HamStationKit — FT8 message encoder and audio waveform generator.
// Reference: ft8_lib (MIT, https://github.com/kgoba/ft8_lib)

import Accelerate
import Foundation

/// Encodes FT8 messages into audio waveforms for transmission.
///
/// The encoding pipeline is:
/// 1. Pack message text into 77 bits
/// 2. Append CRC-14 to get 91 bits
/// 3. LDPC encode to get 174 bits
/// 4. Map to 58 data symbols via Gray code (3 bits -> tone index 0-7)
/// 5. Insert Costas synchronization symbols
/// 6. Generate GFSK audio at the specified frequency
public struct FT8Encoder: Sendable {

    /// Audio sample rate in Hz.
    public let sampleRate: Double

    /// Create an FT8 encoder.
    /// - Parameter sampleRate: Sample rate for generated audio. Default 12000 Hz.
    public init(sampleRate: Double = FT8Constants.sampleRate) {
        self.sampleRate = sampleRate
    }

    // MARK: - Public API

    /// Encode a message text into FT8 audio waveform samples.
    ///
    /// - Parameters:
    ///   - message: The message text (e.g., "CQ W1AW FN31"). Max 13 characters for free text.
    ///   - audioFrequency: Center frequency of the FT8 signal in Hz within the audio passband.
    /// - Returns: Audio samples for the 12.64-second transmission, or `nil` if encoding fails.
    public func encode(message: String, audioFrequency: Double) -> [Float]? {
        // Step 1: Pack message into 77 bits
        guard let messageBits = packMessage(message) else { return nil }

        // Step 2: Add CRC-14
        let crc = Self.crc14(bits: messageBits)
        var dataBits = messageBits
        for i in (0..<FT8Constants.crcBits).reversed() {
            dataBits.append(UInt8((crc >> i) & 1))
        }

        // Step 3: LDPC encode (91 -> 174 bits)
        let codeword = LDPCCodec.encode(dataBits)

        // Step 4: Map to symbols
        let symbols = mapToSymbols(codeword: codeword)

        // Step 5 & 6: Generate audio
        return generateAudio(symbols: symbols, audioFrequency: audioFrequency)
    }

    /// Encode pre-built symbols (79 tone indices) into audio.
    ///
    /// Useful for testing or when symbols are constructed externally.
    ///
    /// - Parameters:
    ///   - symbols: Array of 79 tone indices (0-7).
    ///   - audioFrequency: Center frequency in Hz.
    /// - Returns: Audio samples.
    public func encodeSymbols(_ symbols: [Int], audioFrequency: Double) -> [Float]? {
        guard symbols.count == FT8Constants.numSymbols else { return nil }
        guard symbols.allSatisfy({ $0 >= 0 && $0 < FT8Constants.numTones }) else { return nil }
        return generateAudio(symbols: symbols, audioFrequency: audioFrequency)
    }

    // MARK: - CRC-14

    /// Compute the 14-bit CRC for a 77-bit FT8 message.
    ///
    /// Uses the CRC polynomial from the FT8 specification: x^14 + x + 1 (0x4003).
    ///
    /// - Parameter bits: Array of 77 UInt8 values (0 or 1).
    /// - Returns: 14-bit CRC value.
    public static func crc14(bits: [UInt8]) -> UInt16 {
        let poly: UInt16 = 0x2757 // FT8 CRC-14 polynomial (reversed)
        var crc: UInt16 = 0

        for bit in bits {
            let feedback = ((crc >> 13) ^ UInt16(bit & 1)) & 1
            crc = (crc << 1) & 0x3FFF // Keep 14 bits
            if feedback != 0 {
                crc ^= poly
            }
        }

        return crc & 0x3FFF
    }

    // MARK: - Message packing

    /// Pack a message string into 77 bits.
    ///
    /// Currently supports free-text encoding (13 characters from the FT8 character set).
    /// Full structured message packing (callsign hashing, grid encoding) can be added later.
    ///
    /// - Parameter message: The message text.
    /// - Returns: Array of 77 UInt8 values (0 or 1), or `nil` if encoding fails.
    private func packMessage(_ message: String) -> [UInt8]? {
        // FT8 character set for free text: " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-./?\"
        let charset = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-./?".map { $0 }

        let normalized = message.uppercased()
        var text = normalized.prefix(13)
        // Pad to 13 characters with spaces
        while text.count < 13 {
            text.append(" ")
        }

        // Encode each character as an index into the 42-character FT8 charset.
        // FT8 free text uses 71 bits for 13 characters packed in base-42.
        // 42^13 ~ 1.4e21 which exceeds UInt64 max (~1.8e19), so we use
        // a byte-array big integer for the packing arithmetic.

        // Collect character indices
        var charIndices = [Int]()
        for ch in text {
            guard let idx = charset.firstIndex(of: ch) else { return nil }
            charIndices.append(charset.distance(from: charset.startIndex, to: idx))
        }

        // Pack into 71 bits using base-42 arithmetic.
        // Use a 9-byte (72-bit) big integer, little-endian byte order.
        let numBytes = 9
        var bigInt = [UInt16](repeating: 0, count: numBytes) // Use UInt16 to hold carry

        for charIdx in charIndices {
            // Multiply by 42
            var carry: UInt16 = 0
            for b in 0..<numBytes {
                let val = bigInt[b] * 42 + carry
                bigInt[b] = val & 0xFF
                carry = val >> 8
            }
            // Add character index
            var add = UInt16(charIdx)
            for b in 0..<numBytes {
                let val = bigInt[b] + add
                bigInt[b] = val & 0xFF
                add = val >> 8
                if add == 0 { break }
            }
        }

        // Extract 71 bits from the big integer (MSB first into bits[0..70])
        var bits = [UInt8](repeating: 0, count: FT8Constants.messageBits)
        for i in 0..<71 {
            let bitPos = 70 - i // Bit position in the big integer (0 = LSB)
            let byteIdx = bitPos / 8
            let bitIdx = bitPos % 8
            bits[i] = UInt8((bigInt[byteIdx] >> bitIdx) & 1)
        }

        return bits
    }

    // MARK: - Symbol mapping

    /// Map a 174-bit LDPC codeword to 79 FT8 symbols.
    ///
    /// - Parameter codeword: 174-bit LDPC codeword.
    /// - Returns: Array of 79 tone indices (0-7).
    private func mapToSymbols(codeword: [UInt8]) -> [Int] {
        // Extract 58 data symbols from 174 bits (3 bits per symbol)
        var dataSymbols = [Int]()
        dataSymbols.reserveCapacity(FT8Constants.numDataSymbols)

        for i in 0..<FT8Constants.numDataSymbols {
            let bitOffset = i * FT8Constants.bitsPerSymbol
            let value = Int(codeword[bitOffset]) << 2
                | Int(codeword[bitOffset + 1]) << 1
                | Int(codeword[bitOffset + 2])
            // Apply Gray code mapping
            dataSymbols.append(FT8Constants.grayCode[value])
        }

        // Build 79-symbol sequence: Costas + data + Costas + data + Costas
        var symbols = [Int](repeating: 0, count: FT8Constants.numSymbols)

        // Insert Costas sync patterns at positions 0-6, 36-42, 72-78
        for start in FT8Constants.costasPositions {
            for j in 0..<7 {
                symbols[start + j] = FT8Constants.costasPattern[j]
            }
        }

        // Insert data symbols at non-Costas positions
        for (dataIdx, symPos) in FT8Constants.dataSymbolPositions.enumerated() {
            symbols[symPos] = dataSymbols[dataIdx]
        }

        return symbols
    }

    // MARK: - Audio generation

    /// Generate GFSK audio waveform from a symbol sequence.
    ///
    /// Each symbol is a tone at (audioFrequency + toneIndex * 6.25) Hz.
    /// Phase is continuous between symbols (GFSK with smooth transitions).
    ///
    /// - Parameters:
    ///   - symbols: Array of 79 tone indices (0-7).
    ///   - audioFrequency: Base audio frequency in Hz.
    /// - Returns: Audio samples for the complete transmission.
    private func generateAudio(symbols: [Int], audioFrequency: Double) -> [Float] {
        let samplesPerSymbol = Int(sampleRate * FT8Constants.symbolPeriod)
        let totalSamples = symbols.count * samplesPerSymbol

        var audio = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0

        for (symbolIdx, toneIndex) in symbols.enumerated() {
            let frequency = audioFrequency + Double(toneIndex) * FT8Constants.toneSpacing
            let angularFreq = 2.0 * Double.pi * frequency / sampleRate

            let offset = symbolIdx * samplesPerSymbol
            for j in 0..<samplesPerSymbol {
                audio[offset + j] = Float(sin(phase))
                phase += angularFreq
            }
        }

        // Keep phase in reasonable range to avoid floating point drift
        // (This is cosmetic; sin handles large values fine)

        return audio
    }
}
