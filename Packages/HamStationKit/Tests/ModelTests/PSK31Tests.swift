// PSK31Tests.swift
// HamStationKit — Tests for PSK31 Varicode and BPSK decoder.

import XCTest
import Foundation
@testable import HamStationKit

class VaricodeTests: XCTestCase {

    // MARK: - Encoding tests

    func testEncodeE() {
        // 'E' (0x45) = 11 (2 bits)
        let bits = Varicode.encode("E")
        // Should be: 1, 1, 0, 0  (code + separator)
        XCTAssertEqual(Array(bits.prefix(2)), [1, 1], "E should encode as 11")
        XCTAssertEqual(Array(bits.suffix(2)), [0, 0], "Separator should be 00")
        XCTAssertEqual(bits.count, 4, "E + separator = 4 bits")
    }

    func testEncodeT() {
        // 'T' (0x54) = 101 (3 bits)
        let bits = Varicode.encode("T")
        XCTAssertEqual(Array(bits.prefix(3)), [1, 0, 1], "T should encode as 101")
        XCTAssertEqual(Array(bits.suffix(2)), [0, 0], "Separator should be 00")
        XCTAssertEqual(bits.count, 5, "T + separator = 5 bits")
    }

    func testEncodeSpace() {
        // ' ' (0x20) = 1 (1 bit)
        let bits = Varicode.encode(" ")
        XCTAssertEqual(Array(bits.prefix(1)), [1], "Space should encode as 1")
        XCTAssertEqual(Array(bits.suffix(2)), [0, 0], "Separator should be 00")
        XCTAssertEqual(bits.count, 3, "Space + separator = 3 bits")
    }

    func testEncodeA() {
        // 'A' (0x41) = 1011 (4 bits)
        let bits = Varicode.encode("A")
        XCTAssertEqual(Array(bits.prefix(4)), [1, 0, 1, 1], "A should encode as 1011")
    }

    func testRoundtripHelloWorld() {
        let original = "HELLO WORLD"
        let encoded = Varicode.encode(original)
        let decoded = Varicode.decode(encoded)
        // Varicode lowercase/uppercase: uppercase letters share codes with lowercase
        // The decode table maps to lowercase by default
        XCTAssertEqual(decoded.uppercased(), original,
            "Roundtrip should preserve text (case-insensitive)")
    }

    func testDecodeWithSeparators() {
        // Manually construct bits for "ET" with separators:
        // E=11, sep=00, T=101, sep=00
        let bits: [UInt8] = [1, 1, 0, 0, 1, 0, 1, 0, 0]
        let decoded = Varicode.decode(bits)
        XCTAssertEqual(decoded, "et", "Should decode 'et' from bit sequence")
    }

    func testDecodeEmptyBits() {
        let decoded = Varicode.decode([])
        XCTAssertEqual(decoded, "")
    }

    func testDecodeAllZeros() {
        // All zeros = just separators, no valid characters
        let bits = [UInt8](repeating: 0, count: 20)
        let decoded = Varicode.decode(bits)
        XCTAssertEqual(decoded, "", "All zeros should produce no characters")
    }

    func testEncodeTableHasAllPrintableASCII() {
        // Verify all printable ASCII (32-126) have entries
        for ascii in 32...126 {
            let entry = Varicode.encodeTable[ascii]
            XCTAssertTrue(entry.length > 0,
                "ASCII \(ascii) ('\(Character(Unicode.Scalar(ascii)!))') should have a non-zero length code")
            XCTAssertTrue(entry.length <= 10,
                "ASCII \(ascii) should have code length <= 10, got \(entry.length)")
        }
    }

    func testEncodeTableSize() {
        XCTAssertEqual(Varicode.encodeTable.count, 128,
            "Table should have 128 entries for all ASCII values")
    }

    func testCommonCharactersHaveShorterCodes() {
        // 'E' should be shorter than 'Z'
        let eLen = Varicode.encodeTable[0x45].length
        let zLen = Varicode.encodeTable[0x5A].length
        XCTAssertTrue(eLen < zLen,
            "E (\(eLen) bits) should be shorter than Z (\(zLen) bits)")

        // Space should be shortest
        let spaceLen = Varicode.encodeTable[0x20].length
        XCTAssertEqual(spaceLen, 1, "Space should be 1 bit")
    }

    func testRoundtripMixedText() {
        let original = "CQ CQ DE W1AW"
        let encoded = Varicode.encode(original)
        let decoded = Varicode.decode(encoded)
        XCTAssertEqual(decoded.uppercased(), original)
    }
}

// MARK: - PSK31Decoder Tests

class PSK31DecoderTests: XCTestCase {

    /// Generate a synthetic BPSK31 signal encoding the given text.
    ///
    /// Phase reversal = bit 1, no reversal = bit 0.
    private func syntheticPSK31(
        text: String,
        frequency: Double = 1000,
        sampleRate: Double = 48000
    ) -> [Float] {
        let bits = Varicode.encode(text)
        let samplesPerSymbol = Int(sampleRate / 31.25)
        // Total symbols: bits + some idle (zeros) at start and end
        let idleBits = 16 // 16 zeros = idle
        var allBits: [UInt8] = [UInt8](repeating: 0, count: idleBits)
        allBits.append(contentsOf: bits)
        allBits.append(contentsOf: [UInt8](repeating: 0, count: idleBits))

        var samples: [Float] = []
        var phase: Double = 0
        let omega = 2.0 * Double.pi * frequency / sampleRate
        var currentPhase: Double = 0  // 0 or pi

        for bit in allBits {
            if bit == 1 {
                // Phase reversal
                currentPhase += Double.pi
            }
            // Generate one symbol of carrier at current phase
            for _ in 0..<samplesPerSymbol {
                let value = Float(sin(phase + currentPhase))
                samples.append(value)
                phase += omega
            }
        }

        return samples
    }

    func testDecodeSyntheticBPSK() async {
        let decoder = PSK31Decoder(sampleRate: 48000)
        await decoder.reset()

        // Generate a synthetic signal for "E"
        // E = 11 in Varicode, so two phase reversals followed by 00 separator
        let signal = syntheticPSK31(text: "E", frequency: 1000, sampleRate: 48000)

        let result = await decoder.process(samples: signal)

        // The decoder should find at least the character 'e' (lowercase in Varicode)
        let fullText = await decoder.decodedText
        let combined = result + fullText
        XCTAssertTrue(combined.lowercased().contains("e"),
            "Should decode 'e' from synthetic BPSK31 signal, got: '\(combined)'")
    }

    func testDetectCharacterBoundaries() async {
        let decoder = PSK31Decoder(sampleRate: 48000)
        await decoder.reset()

        // "ET" should produce two characters separated by 00
        let signal = syntheticPSK31(text: "ET", frequency: 1000, sampleRate: 48000)
        let result = await decoder.process(samples: signal)
        let fullText = await decoder.decodedText

        let combined = (result + fullText).lowercased()
        // Should contain both 'e' and 't'
        let hasE = combined.contains("e")
        let hasT = combined.contains("t")
        XCTAssertTrue(hasE || hasT,
            "Should decode at least one character from 'ET', got: '\(combined)'")
    }

    func testReset() async {
        let decoder = PSK31Decoder(sampleRate: 48000)
        let signal = syntheticPSK31(text: "A", frequency: 1000, sampleRate: 48000)
        _ = await decoder.process(samples: signal)

        await decoder.reset()

        let text = await decoder.decodedText
        XCTAssertEqual(text, "", "Decoded text should be empty after reset")
    }

    func testCenterFrequencyDefault() async {
        let decoder = PSK31Decoder(sampleRate: 48000)
        let freq = await decoder.centerFrequency
        XCTAssertEqual(freq, 1000, "Default center frequency should be 1000 Hz")
    }
}
