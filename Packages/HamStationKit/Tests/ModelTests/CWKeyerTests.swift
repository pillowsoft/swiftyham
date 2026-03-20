// CWKeyerTests.swift
// HamStationKit — Tests for CWKeyer Morse encoding, timing, macros, and sidetone.

import XCTest
import Foundation
@testable import HamStationKit

class CWKeyerTests: XCTestCase {

    // MARK: - Morse table completeness

    func testMorseTableHasAllLetters() {
        let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for letter in letters {
            XCTAssertNotNil(CWKeyer.morseTable[letter], "Missing Morse code for \(letter)")
        }
    }

    func testMorseTableHasAllDigits() {
        let digits: [Character] = Array("0123456789")
        for digit in digits {
            XCTAssertNotNil(CWKeyer.morseTable[digit], "Missing Morse code for \(digit)")
        }
    }

    // MARK: - Encoding

    func testEncodeSOS() async {
        let keyer = CWKeyer()
        let elements = await keyer.encode("SOS")

        let expected: [MorseElement] = [
            .dit, .elementSpace, .dit, .elementSpace, .dit,
            .characterSpace,
            .dah, .elementSpace, .dah, .elementSpace, .dah,
            .characterSpace,
            .dit, .elementSpace, .dit, .elementSpace, .dit,
        ]
        XCTAssertEqual(elements, expected)
    }

    func testEncodeCQ() async {
        let keyer = CWKeyer()
        let elements = await keyer.encode("CQ")

        let expected: [MorseElement] = [
            .dah, .elementSpace, .dit, .elementSpace, .dah, .elementSpace, .dit,
            .characterSpace,
            .dah, .elementSpace, .dah, .elementSpace, .dit, .elementSpace, .dah,
        ]
        XCTAssertEqual(elements, expected)
    }

    // MARK: - Timing

    func testDitDuration20WPM() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(20)
        let duration = await keyer.ditDurationMs
        XCTAssertEqual(duration, 60.0)
    }

    func testDitDuration13WPM() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(13)
        let duration = await keyer.ditDurationMs
        XCTAssertTrue(abs(duration - 92.3) < 0.1)
    }

    func testDahIs3xDit() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(20)
        let dit = await keyer.ditDurationMs
        let dah = await keyer.dahDurationMs
        XCTAssertEqual(dah, dit * 3.0)
    }

    func testFarnsworthTiming() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(20)
        await keyer.setFarnsworth(10)

        let normalKeyer = CWKeyer()
        await normalKeyer.setSpeed(20)

        let farnsworthCharSpace = await keyer.characterSpaceMs
        let normalCharSpace = await normalKeyer.characterSpaceMs

        XCTAssertTrue(farnsworthCharSpace > normalCharSpace)
    }

    // MARK: - Macro expansion

    func testMacroExpansionMyCall() async {
        let keyer = CWKeyer()
        let macro = CWMacro(name: "CQ", text: "CQ CQ CQ DE {MYCALL} {MYCALL} K")
        let context = MacroContext(myCallsign: "W1AW")
        let result = await keyer.expandMacro(macro, context: context)
        XCTAssertEqual(result, "CQ CQ CQ DE W1AW W1AW K")
    }

    func testMacroExpansionMultipleVars() async {
        let keyer = CWKeyer()
        let macro = CWMacro(
            name: "Exchange",
            text: "{THEIRCALL} DE {MYCALL} UR RST {RST} NR {NR} K"
        )
        let context = MacroContext(
            myCallsign: "W1AW",
            theirCallsign: "K3LR",
            rst: "599",
            serialNumber: 42
        )
        let result = await keyer.expandMacro(macro, context: context)
        XCTAssertEqual(result, "K3LR DE W1AW UR RST 599 NR 042 K")
    }

    // MARK: - Sidetone generation

    func testSidetoneSampleCount() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(20)
        let elements = await keyer.encode("SOS")
        let samples = await keyer.generateSidetone(elements: elements, sampleRate: 48000)

        let ditMs = 60.0
        var totalMs = 0.0
        for element in elements {
            switch element {
            case .dit: totalMs += ditMs
            case .dah: totalMs += ditMs * 3
            case .elementSpace: totalMs += ditMs
            case .characterSpace: totalMs += ditMs * 3
            case .wordSpace: totalMs += ditMs * 7
            }
        }
        let expectedSamples = Int(totalMs / 1000.0 * 48000)
        XCTAssertTrue(abs(samples.count - expectedSamples) < 10)
        XCTAssertTrue(samples.count > 0)
    }

    func testSidetoneFrequency() async {
        let keyer = CWKeyer()
        await keyer.setSpeed(20)
        await keyer.setPitch(700)
        await keyer.setVolume(1.0)

        let elements: [MorseElement] = [.dah]
        let sampleRate = 48000.0
        let samples = await keyer.generateSidetone(elements: elements, sampleRate: sampleRate)

        let skipSamples = Int(0.005 * sampleRate)
        let analysisSamples = Array(samples[skipSamples..<(samples.count - skipSamples)])

        var zeroCrossings = 0
        for i in 1..<analysisSamples.count {
            if (analysisSamples[i - 1] >= 0 && analysisSamples[i] < 0) ||
               (analysisSamples[i - 1] < 0 && analysisSamples[i] >= 0) {
                zeroCrossings += 1
            }
        }

        let analysisDuration = Double(analysisSamples.count) / sampleRate
        let measuredFreq = Double(zeroCrossings) / 2.0 / analysisDuration

        XCTAssertTrue(abs(measuredFreq - 700.0) < 35.0,
                "Measured frequency \(measuredFreq) Hz, expected ~700 Hz")
    }

    func testSpeedRangeValid() async {
        let keyer = CWKeyer()
        for wpm in stride(from: 5, through: 50, by: 5) {
            await keyer.setSpeed(wpm)
            let dit = await keyer.ditDurationMs
            XCTAssertTrue(dit > 0, "Dit duration must be positive at \(wpm) WPM")
            XCTAssertEqual(dit, 1200.0 / Double(wpm),
                    "Dit duration incorrect at \(wpm) WPM")
        }
    }
}

// MARK: - Helper extensions for tests

extension CWKeyer {
    func setSpeed(_ wpm: Int) {
        self.speedWPM = wpm
    }

    func setFarnsworth(_ wpm: Int?) {
        self.farnsworthWPM = wpm
    }

    func setPitch(_ hz: Double) {
        self.sidetonePitch = hz
    }

    func setVolume(_ vol: Float) {
        self.sidetoneVolume = vol
    }
}
