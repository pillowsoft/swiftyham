// FFTProcessor.swift
// HamStationKit — FFT processor using Accelerate vDSP framework.

import Accelerate
import Foundation

/// Computes magnitude spectra from time-domain audio samples using vDSP.
///
/// Typical usage: 4096-point FFT at 48 kHz sample rate, yielding ~11.7 Hz resolution.
/// Output is fftSize/2 magnitude values in dB (decibels relative to full scale).
public struct FFTProcessor: @unchecked Sendable {

    /// Number of points in the FFT (must be a power of two).
    public let fftSize: Int

    /// Audio sample rate in Hz.
    public let sampleRate: Double

    // vDSP setup (opaque, but Sendable since it's immutable after init)
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]

    /// Frequency resolution in Hz: `sampleRate / fftSize`.
    public var frequencyResolution: Double {
        sampleRate / Double(fftSize)
    }

    /// Create an FFT processor.
    /// - Parameters:
    ///   - fftSize: FFT length in samples. Must be a power of two. Default 4096.
    ///   - sampleRate: Audio sample rate in Hz. Default 48000.
    public init(fftSize: Int = 4096, sampleRate: Double = 48000) {
        precondition(fftSize > 0 && (fftSize & (fftSize - 1)) == 0,
                     "fftSize must be a power of two")

        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.log2n = vDSP_Length(log2(Double(fftSize)))

        guard let setup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup for size \(fftSize)")
        }
        self.fftSetup = setup

        // Pre-compute Hann window
        var win = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&win, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = win
    }

    /// Process time-domain samples into a magnitude spectrum in dB.
    ///
    /// - Parameter samples: Array of Float samples. Must have exactly `fftSize` elements.
    /// - Returns: Array of `fftSize / 2` magnitude values in dB (relative to full scale).
    public func process(_ samples: [Float]) -> [Float] {
        precondition(samples.count == fftSize,
                     "Expected \(fftSize) samples, got \(samples.count)")

        let halfN = fftSize / 2

        // 1. Apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // 2. Pack into split complex format for vDSP_fft_zrip
        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)

        // Deinterleave even/odd samples into real/imag
        windowed.withUnsafeBufferPointer { buf in
            for i in 0..<halfN {
                realPart[i] = buf[2 * i]
                imagPart[i] = buf[2 * i + 1]
            }
        }

        var splitComplex = DSPSplitComplex(
            realp: &realPart,
            imagp: &imagPart
        )

        // 3. In-place FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // 4. Compute squared magnitudes
        var magnitudes = [Float](repeating: 0, count: halfN)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))

        // 5. Normalize: divide by (fftSize/2)^2 to get proper scaling
        let scale = Float(halfN * halfN)
        var scaleFactor = scale
        vDSP_vsdiv(magnitudes, 1, &scaleFactor, &magnitudes, 1, vDSP_Length(halfN))

        // 6. Clamp minimum to avoid log(0) using threshold
        var minVal: Float = 1.0e-20
        vDSP_vthr(magnitudes, 1, &minVal, &magnitudes, 1, vDSP_Length(halfN))

        // 7. Convert to dB: 10 * log10(magnitude)
        var dbValues = [Float](repeating: 0, count: halfN)
        var count = Int32(halfN)
        vvlog10f(&dbValues, &magnitudes, &count)
        var ten: Float = 10.0
        vDSP_vsmul(dbValues, 1, &ten, &dbValues, 1, vDSP_Length(halfN))

        return dbValues
    }

    /// The frequency in Hz corresponding to a given FFT bin index.
    /// - Parameter bin: Bin index (0 ..< fftSize/2).
    /// - Returns: Center frequency of that bin.
    public func frequency(forBin bin: Int) -> Double {
        Double(bin) * sampleRate / Double(fftSize)
    }

    /// The FFT bin index closest to a given frequency.
    /// - Parameter freq: Frequency in Hz.
    /// - Returns: Bin index.
    public func bin(forFrequency freq: Double) -> Int {
        Int(round(freq * Double(fftSize) / sampleRate))
    }
}
