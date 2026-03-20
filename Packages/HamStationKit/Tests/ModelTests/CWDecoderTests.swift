// CWDecoderTests.swift
// HamStationKit — Tests for CWDecoder Goertzel algorithm and Morse decoding.

import XCTest
import Foundation
@testable import HamStationKit

class CWDecoderTests: XCTestCase {

    // MARK: - Test helpers

    private func sineWave(
        frequency: Double,
        sampleRate: Double = 48000,
        duration: Double,
        amplitude: Float = 1.0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { i in
            amplitude * Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate))
        }
    }

    private func whiteNoise(sampleRate: Double = 48000, duration: Double, amplitude: Float = 0.1) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { _ in
            Float.random(in: -amplitude...amplitude)
        }
    }

    private func cwElement(
        keyed: Bool,
        durationMs: Double,
        frequency: Double = 700,
        sampleRate: Double = 48000,
        amplitude: Float = 0.8
    ) -> [Float] {
        let durationSec = durationMs / 1000.0
        let sampleCount = Int(sampleRate * durationSec)
        if keyed {
            return (0..<sampleCount).map { i in
                amplitude * Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate))
            }
        } else {
            return [Float](repeating: 0.0, count: sampleCount)
        }
    }

    private func syntheticMorse(
        pattern: String,
        wpm: Double = 20,
        frequency: Double = 700,
        sampleRate: Double = 48000
    ) -> [Float] {
        let ditMs = 1200.0 / wpm
        var samples: [Float] = []

        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 5,
                                              frequency: frequency, sampleRate: sampleRate))

        for (i, char) in pattern.enumerated() {
            if i > 0 {
                samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs,
                                                      frequency: frequency, sampleRate: sampleRate))
            }
            switch char {
            case ".":
                samples.append(contentsOf: cwElement(keyed: true, durationMs: ditMs,
                                                      frequency: frequency, sampleRate: sampleRate))
            case "-":
                samples.append(contentsOf: cwElement(keyed: true, durationMs: ditMs * 3,
                                                      frequency: frequency, sampleRate: sampleRate))
            case " ":
                samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 2,
                                                      frequency: frequency, sampleRate: sampleRate))
            case "/":
                samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 6,
                                                      frequency: frequency, sampleRate: sampleRate))
            default:
                break
            }
        }

        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 8,
                                              frequency: frequency, sampleRate: sampleRate))

        return samples
    }

    // MARK: - Goertzel tests

    func testGoertzelDetectsTone() {
        let samples = sineWave(frequency: 700, duration: 0.01)
        let magnitude = CWDecoder.goertzel(
            samples: samples, targetFrequency: 700, sampleRate: 48000)
        XCTAssertTrue(magnitude > 100, "Expected high magnitude for on-frequency tone, got \(magnitude)")
    }

    func testGoertzelNoTone() {
        let samples = [Float](repeating: 0.0, count: 480)
        let magnitude = CWDecoder.goertzel(
            samples: samples, targetFrequency: 700, sampleRate: 48000)
        XCTAssertTrue(magnitude < 1, "Expected near-zero magnitude for silence, got \(magnitude)")
    }

    func testGoertzelToneWithNoise() {
        var samples = sineWave(frequency: 700, duration: 0.01, amplitude: 0.8)
        let noise = whiteNoise(duration: 0.01, amplitude: 0.1)
        for i in 0..<samples.count {
            samples[i] += noise[i]
        }
        let magnitude = CWDecoder.goertzel(
            samples: samples, targetFrequency: 700, sampleRate: 48000)

        let noiseMag = CWDecoder.goertzel(
            samples: whiteNoise(duration: 0.01, amplitude: 0.1),
            targetFrequency: 700, sampleRate: 48000)

        XCTAssertTrue(magnitude > noiseMag * 2,
                "Signal+noise magnitude (\(magnitude)) should be well above noise-only (\(noiseMag))")
    }

    // MARK: - Element detection

    func testDecodeSyntheticDit() async {
        let decoder = CWDecoder()
        let ditMs = 60.0

        var samples: [Float] = []
        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 10))
        samples.append(contentsOf: cwElement(keyed: true, durationMs: ditMs))
        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 10))

        let priming = cwElement(keyed: false, durationMs: 200)
        _ = await decoder.process(samples: priming)

        let primeTone = cwElement(keyed: true, durationMs: ditMs * 3)
        _ = await decoder.process(samples: primeTone)
        let primeSilence = cwElement(keyed: false, durationMs: ditMs * 10)
        _ = await decoder.process(samples: primeSilence)

        let decoded = await decoder.process(samples: samples)
        let chars = decoded.compactMap { element -> Character? in
            if case .character(let ch) = element { return ch }
            return nil
        }
        XCTAssertTrue(chars.contains("E"),
                "Expected 'E' (single dit), got decoded elements: \(decoded)")
    }

    func testDecodeSyntheticDah() async {
        let decoder = CWDecoder()
        let ditMs = 60.0

        let priming = cwElement(keyed: false, durationMs: 200)
        _ = await decoder.process(samples: priming)
        let primeTone = cwElement(keyed: true, durationMs: ditMs * 3)
        _ = await decoder.process(samples: primeTone)
        let primeSilence = cwElement(keyed: false, durationMs: ditMs * 10)
        _ = await decoder.process(samples: primeSilence)
        await decoder.reset()

        var samples: [Float] = []
        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 5))
        samples.append(contentsOf: cwElement(keyed: true, durationMs: ditMs * 3))
        samples.append(contentsOf: cwElement(keyed: false, durationMs: ditMs * 10))

        _ = await decoder.process(samples: cwElement(keyed: false, durationMs: 100))
        _ = await decoder.process(samples: cwElement(keyed: true, durationMs: ditMs * 3))
        _ = await decoder.process(samples: cwElement(keyed: false, durationMs: ditMs * 10))
        await decoder.reset()

        _ = await decoder.process(samples: cwElement(keyed: false, durationMs: 200))
        _ = await decoder.process(samples: cwElement(keyed: true, durationMs: ditMs))
        _ = await decoder.process(samples: cwElement(keyed: false, durationMs: ditMs * 8))

        let decoded = await decoder.process(samples: samples)
        let chars = decoded.compactMap { element -> Character? in
            if case .character(let ch) = element { return ch }
            return nil
        }
        XCTAssertTrue(chars.contains("T"),
                "Expected 'T' (single dah), got decoded elements: \(decoded)")
    }

    func testDecodeSyntheticE() async {
        let decoder = CWDecoder()
        let audio = syntheticMorse(pattern: ".", wpm: 20)
        let decoded = await decoder.process(samples: audio)
        let text = decoded.compactMap { element -> Character? in
            if case .character(let ch) = element { return ch }
            return nil
        }
        XCTAssertTrue(text.contains("E"),
                "Expected character E, got: \(decoded)")
    }

    func testDecodeSyntheticT() async {
        let decoder = CWDecoder()
        let audio = syntheticMorse(pattern: "-", wpm: 20)
        let decoded = await decoder.process(samples: audio)
        let text = decoded.compactMap { element -> Character? in
            if case .character(let ch) = element { return ch }
            return nil
        }
        XCTAssertTrue(text.contains("T"),
                "Expected character T, got: \(decoded)")
    }

    func testDecodeSyntheticSOS() async {
        let decoder = CWDecoder()
        let audio = syntheticMorse(pattern: "... --- ...", wpm: 15)
        let decoded = await decoder.process(samples: audio)
        let text = String(decoded.compactMap { element -> Character? in
            if case .character(let ch) = element { return ch }
            return nil
        })
        XCTAssertEqual(text, "SOS",
                "Expected 'SOS', got '\(text)' from elements: \(decoded)")
    }

    // MARK: - Adaptive threshold

    func testAdaptiveThreshold() async {
        let decoder = CWDecoder()

        let noise = whiteNoise(duration: 0.5, amplitude: 0.01)
        _ = await decoder.process(samples: noise)

        let floor = await decoder.threshold
        XCTAssertTrue(floor >= 0, "Threshold should be non-negative")
        XCTAssertTrue(floor < 1.0, "Threshold should be low for quiet input, got \(floor)")
    }

    // MARK: - Speed tracking

    func testSpeedTracking() async {
        let decoder = CWDecoder()
        let targetWPM = 20.0

        let parisPattern = ".--. .- .-. .. ..."
        let audio = syntheticMorse(pattern: parisPattern, wpm: targetWPM)
        _ = await decoder.process(samples: audio)

        let measuredWPM = await decoder.currentSpeedWPM
        let tolerance = targetWPM * 0.5
        XCTAssertTrue(abs(measuredWPM - targetWPM) < tolerance,
                "Measured speed \(measuredWPM) WPM, expected ~\(targetWPM) WPM (within 50%)")
    }

    // MARK: - Reset

    func testResetClearsState() async {
        let decoder = CWDecoder()

        let audio = syntheticMorse(pattern: "...", wpm: 20)
        _ = await decoder.process(samples: audio)

        await decoder.reset()

        let textAfter = await decoder.decodedText
        let speedAfter = await decoder.currentSpeedWPM
        XCTAssertEqual(textAfter, "", "Decoded text should be empty after reset")
        XCTAssertEqual(speedAfter, 20.0, "Speed should be back to default after reset")
    }
}
