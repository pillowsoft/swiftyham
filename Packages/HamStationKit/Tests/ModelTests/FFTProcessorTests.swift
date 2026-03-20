// FFTProcessorTests.swift
// HamStationKit — Tests for FFTProcessor vDSP-based spectrum analysis.

import XCTest
import Foundation
@testable import HamStationKit

class FFTProcessorTests: XCTestCase {

    // MARK: - Test helpers

    private func sineWave(
        frequency: Double,
        sampleRate: Double = 48000,
        count: Int,
        amplitude: Float = 1.0
    ) -> [Float] {
        (0..<count).map { i in
            amplitude * Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate))
        }
    }

    // MARK: - Peak detection

    func testFftPureSinePeak() {
        let fftSize = 4096
        let sampleRate = 48000.0
        let frequency = 1000.0
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: sampleRate)

        let samples = sineWave(frequency: frequency, sampleRate: sampleRate, count: fftSize)
        let spectrum = processor.process(samples)

        var peakBin = 0
        var peakValue: Float = -Float.infinity
        for (i, val) in spectrum.enumerated() {
            if val > peakValue {
                peakValue = val
                peakBin = i
            }
        }

        let expectedBin = processor.bin(forFrequency: frequency)
        XCTAssertTrue(abs(peakBin - expectedBin) <= 2,
                "Peak at bin \(peakBin), expected near bin \(expectedBin)")
    }

    func testFft1kHzPeak() {
        let fftSize = 4096
        let sampleRate = 48000.0
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: sampleRate)

        let samples = sineWave(frequency: 1000, sampleRate: sampleRate, count: fftSize)
        let spectrum = processor.process(samples)

        var peakBin = 0
        var peakValue: Float = -Float.infinity
        for (i, val) in spectrum.enumerated() {
            if val > peakValue {
                peakValue = val
                peakBin = i
            }
        }

        XCTAssertTrue(abs(peakBin - 85) <= 2,
                "Peak at bin \(peakBin), expected near 85 for 1kHz at 48kHz/4096")
    }

    // MARK: - Silence

    func testFftSilence() {
        let fftSize = 4096
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: 48000)

        let samples = [Float](repeating: 0.0, count: fftSize)
        let spectrum = processor.process(samples)

        for (i, val) in spectrum.enumerated() {
            XCTAssertTrue(val < -60,
                    "Bin \(i) = \(val) dB, expected below -60 dB for silence")
        }
    }

    // MARK: - White noise

    func testFftWhiteNoise() {
        let fftSize = 4096
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: 48000)

        var rng = LCGRandomGenerator(seed: 42)
        let samples = (0..<fftSize).map { _ -> Float in
            Float.random(in: -0.5...0.5, using: &rng)
        }
        let spectrum = processor.process(samples)

        let mean = spectrum.reduce(0, +) / Float(spectrum.count)
        let variance = spectrum.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            / Float(spectrum.count)
        let stdDev = sqrt(variance)

        XCTAssertTrue(stdDev < 20,
                "White noise spectrum std dev (\(stdDev)) should be moderate, indicating flat-ish spectrum")
    }

    // MARK: - Resolution

    func testFrequencyResolution() {
        let processor = FFTProcessor(fftSize: 4096, sampleRate: 48000)
        let expected = 48000.0 / 4096.0
        XCTAssertTrue(abs(processor.frequencyResolution - expected) < 0.001)
    }

    // MARK: - Bin conversion

    func testBinFrequencyInverse() {
        let processor = FFTProcessor(fftSize: 4096, sampleRate: 48000)

        for bin in stride(from: 0, to: 2048, by: 100) {
            let freq = processor.frequency(forBin: bin)
            let recoveredBin = processor.bin(forFrequency: freq)
            XCTAssertEqual(recoveredBin, bin,
                    "bin(\(bin)) -> freq(\(freq)) -> bin(\(recoveredBin)), expected \(bin)")
        }
    }

    // MARK: - Output length

    func testFftOutputLength() {
        let fftSize = 4096
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: 48000)

        let samples = [Float](repeating: 0.0, count: fftSize)
        let spectrum = processor.process(samples)

        XCTAssertEqual(spectrum.count, fftSize / 2,
                "Expected \(fftSize / 2) bins, got \(spectrum.count)")
    }
}

// MARK: - Deterministic RNG for reproducible noise tests

private struct LCGRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
