// RTTYTests.swift
// HamStationKit — Tests for RTTY Baudot code and FSK decoder.

import XCTest
import Foundation
@testable import HamStationKit

// MARK: - BaudotCode Tests

class BaudotCodeTests: XCTestCase {

    func testDecodeT() {
        // 'T' is at index 1 in letters table
        var decoder = BaudotCode.Decoder()
        let result = decoder.decode(1)
        XCTAssertEqual(result, "T", "Code 1 in letters shift should be 'T'")
    }

    func testDecodeFiguresShiftNumbers() {
        var decoder = BaudotCode.Decoder()

        // Switch to figures
        let shiftResult = decoder.decode(BaudotCode.FIGURES_SHIFT)
        XCTAssertNil(shiftResult, "Shift code should return nil")
        XCTAssertEqual(decoder.currentShift, .figures)

        // Code 1 in figures = '5'
        let five = decoder.decode(1)
        XCTAssertEqual(five, "5", "Code 1 in figures shift should be '5'")

        // Code 16 in figures = '3'
        let three = decoder.decode(16)
        XCTAssertEqual(three, "3", "Code 16 in figures shift should be '3'")
    }

    func testDecodeLettersShift() {
        var decoder = BaudotCode.Decoder()

        // Start in letters, decode 'H' (code 5)
        let h = decoder.decode(5)
        XCTAssertEqual(h, "H")

        // Switch to figures
        _ = decoder.decode(BaudotCode.FIGURES_SHIFT)
        XCTAssertEqual(decoder.currentShift, .figures)

        // Code 5 in figures = '#'
        let hash = decoder.decode(5)
        XCTAssertEqual(hash, "#")

        // Switch back to letters
        _ = decoder.decode(BaudotCode.LETTERS_SHIFT)
        XCTAssertEqual(decoder.currentShift, .letters)

        // Code 5 should be 'H' again
        let h2 = decoder.decode(5)
        XCTAssertEqual(h2, "H")
    }

    func testShiftBackAndForth() {
        var decoder = BaudotCode.Decoder()

        // Letters: T (1)
        XCTAssertEqual(decoder.decode(1), "T")

        // Switch to figures
        _ = decoder.decode(BaudotCode.FIGURES_SHIFT)

        // Figures: 5 (1)
        XCTAssertEqual(decoder.decode(1), "5")

        // Switch to letters
        _ = decoder.decode(BaudotCode.LETTERS_SHIFT)

        // Letters: T (1)
        XCTAssertEqual(decoder.decode(1), "T")

        // Switch to figures
        _ = decoder.decode(BaudotCode.FIGURES_SHIFT)

        // Figures: 9 (3)
        XCTAssertEqual(decoder.decode(3), "9")
    }

    func testDecodeSpace() {
        var decoder = BaudotCode.Decoder()
        // Space is code 4 in both tables
        let space = decoder.decode(4)
        XCTAssertEqual(space, " ")
    }

    func testEncodeCQCQ() {
        let encoded = BaudotCode.encode("CQ CQ")
        // Should produce a sequence of codes
        XCTAssertFalse(encoded.isEmpty, "Encoding 'CQ CQ' should produce codes")

        // Verify by decoding back
        var decoder = BaudotCode.Decoder()
        var decoded = ""
        for (_, code) in encoded {
            if let ch = decoder.decode(code) {
                decoded.append(ch)
            }
        }
        XCTAssertEqual(decoded, "CQ CQ", "Encode then decode should round-trip 'CQ CQ'")
    }

    func testEncodeWithShiftTransition() {
        // "A1" requires LETTERS for A, then FIGURES for 1
        let encoded = BaudotCode.encode("A1")
        // Should contain a FIGURES_SHIFT code
        let hasShift = encoded.contains { $0.code == BaudotCode.FIGURES_SHIFT }
        XCTAssertTrue(hasShift, "Encoding 'A1' should include a FIGURES shift")
    }

    func testDecodeInvalidCode() {
        var decoder = BaudotCode.Decoder()
        // Code 0 = NUL in both tables (nil)
        let result = decoder.decode(0)
        XCTAssertNil(result, "Code 0 should return nil (NUL)")
    }
}

// MARK: - RTTYDecoder Tests

class RTTYDecoderTests: XCTestCase {

    /// Generate a synthetic RTTY FSK signal for one Baudot character.
    ///
    /// Format: start bit (space) + 5 data bits + 1.5 stop bits (mark)
    private func syntheticRTTYCharacter(
        code: UInt8,
        markFreq: Double = 2125,
        spaceFreq: Double = 2295,
        baudRate: Double = 45.45,
        sampleRate: Double = 48000
    ) -> [Float] {
        let samplesPerBit = Int(sampleRate / baudRate)
        var samples: [Float] = []

        // Helper to generate tone
        func tone(frequency: Double, numSamples: Int, startPhase: inout Double) -> [Float] {
            let omega = 2.0 * Double.pi * frequency / sampleRate
            var result: [Float] = []
            for _ in 0..<numSamples {
                result.append(Float(sin(startPhase)))
                startPhase += omega
            }
            return result
        }

        var phase = 0.0

        // Start bit: space (0)
        samples.append(contentsOf: tone(frequency: spaceFreq, numSamples: samplesPerBit, startPhase: &phase))

        // 5 data bits (LSB first)
        for i in 0..<5 {
            let bit = (code >> i) & 1
            let freq = bit == 1 ? markFreq : spaceFreq
            samples.append(contentsOf: tone(frequency: freq, numSamples: samplesPerBit, startPhase: &phase))
        }

        // 1.5 stop bits: mark
        let stopSamples = Int(Double(samplesPerBit) * 1.5)
        samples.append(contentsOf: tone(frequency: markFreq, numSamples: stopSamples, startPhase: &phase))

        return samples
    }

    /// Generate idle (mark tone) for the given duration.
    private func markIdle(
        duration: Double,
        markFreq: Double = 2125,
        sampleRate: Double = 48000
    ) -> [Float] {
        let numSamples = Int(sampleRate * duration)
        let omega = 2.0 * Double.pi * markFreq / sampleRate
        return (0..<numSamples).map { i in
            Float(sin(omega * Double(i)))
        }
    }

    func testDecodeSyntheticRTTY() async {
        let decoder = RTTYDecoder(sampleRate: 48000)

        // Generate idle + 'T' character (code 1 in letters)
        var signal = markIdle(duration: 0.2)
        signal.append(contentsOf: syntheticRTTYCharacter(code: 1))
        signal.append(contentsOf: markIdle(duration: 0.1))

        let result = await decoder.process(samples: signal)
        let fullText = await decoder.decodedText
        let combined = result + fullText

        XCTAssertTrue(combined.contains("T"),
            "Should decode 'T' from synthetic RTTY signal, got: '\(combined)'")
    }

    func testStartStopBitFraming() async {
        let decoder = RTTYDecoder(sampleRate: 48000)

        // Generate two characters with proper framing
        // 'H' = code 5, 'I' = code 12
        var signal = markIdle(duration: 0.2)
        signal.append(contentsOf: syntheticRTTYCharacter(code: 5))   // H
        signal.append(contentsOf: syntheticRTTYCharacter(code: 12))  // I
        signal.append(contentsOf: markIdle(duration: 0.1))

        let result = await decoder.process(samples: signal)
        let fullText = await decoder.decodedText
        let combined = result + fullText

        XCTAssertTrue(combined.contains("H") || combined.contains("I"),
            "Should decode at least one framed character, got: '\(combined)'")
    }

    func testReversedMode() async {
        let decoder = RTTYDecoder(sampleRate: 48000)

        // In reversed mode, mark and space are swapped
        // So we generate with swapped frequencies
        let markFreq = 2295.0   // normally space
        let spaceFreq = 2125.0  // normally mark

        var signal = markIdle(duration: 0.2, markFreq: markFreq)

        // Generate 'T' (code 1) with swapped frequencies
        let samplesPerBit = Int(48000.0 / 45.45)
        var phase = 0.0
        let omega_space = 2.0 * Double.pi * spaceFreq / 48000.0
        let omega_mark = 2.0 * Double.pi * markFreq / 48000.0

        // Start bit (space = lower freq in reversed mode)
        for _ in 0..<samplesPerBit {
            signal.append(Float(sin(phase)))
            phase += omega_space
        }
        // Bit 0 of code 1 = 1 (mark = higher freq in reversed mode)
        for _ in 0..<samplesPerBit {
            signal.append(Float(sin(phase)))
            phase += omega_mark
        }
        // Bits 1-4 = 0 (space)
        for _ in 0..<(4 * samplesPerBit) {
            signal.append(Float(sin(phase)))
            phase += omega_space
        }
        // Stop bits (mark)
        let stopSamples = Int(Double(samplesPerBit) * 1.5)
        for _ in 0..<stopSamples {
            signal.append(Float(sin(phase)))
            phase += omega_mark
        }
        signal.append(contentsOf: markIdle(duration: 0.1, markFreq: markFreq))

        // Set reversed mode — tells decoder that mark/space are swapped
        await decoder.setReversed(true)
        let result = await decoder.process(samples: signal)
        let fullText = await decoder.decodedText
        let combined = result + fullText

        XCTAssertTrue(combined.contains("T"),
            "Reversed mode should decode 'T', got: '\(combined)'")
    }

    func testReset() async {
        let decoder = RTTYDecoder(sampleRate: 48000)

        var signal = markIdle(duration: 0.1)
        signal.append(contentsOf: syntheticRTTYCharacter(code: 1))
        _ = await decoder.process(samples: signal)

        await decoder.reset()

        let text = await decoder.decodedText
        XCTAssertEqual(text, "", "Decoded text should be empty after reset")
    }

    func testDefaultFrequencies() async {
        let decoder = RTTYDecoder(sampleRate: 48000)
        let mark = await decoder.markFrequency
        let space = await decoder.spaceFrequency
        XCTAssertEqual(mark, 2125, "Default mark frequency should be 2125 Hz")
        XCTAssertEqual(space, 2295, "Default space frequency should be 2295 Hz")
        XCTAssertEqual(space - mark, 170, "Standard shift should be 170 Hz")
    }
}

// MARK: - RTTYDecoder helper for tests

extension RTTYDecoder {
    /// Set reversed mode (for testing).
    func setReversed(_ reversed: Bool) {
        self.isReversed = reversed
    }
}
