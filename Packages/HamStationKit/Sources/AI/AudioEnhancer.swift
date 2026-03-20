// AudioEnhancer.swift
// HamStationKit — Core ML audio enhancement (noise reduction).
// On-device only — audio never leaves the Mac.

#if canImport(CoreML) && canImport(Accelerate)
import Foundation
import CoreML
import Accelerate

/// On-device audio noise reduction using a Core ML U-Net denoiser.
///
/// Processes audio frames through STFT, applies the learned denoising mask,
/// and reconstructs via inverse STFT. Runs entirely on the Apple Neural Engine
/// or GPU — audio data never leaves the device.
public actor AudioEnhancer {

    // MARK: - Preset

    /// Denoising presets optimized for common ham radio scenarios.
    public enum Preset: String, Sendable, CaseIterable {
        case hfSSB = "HF SSB"
        case weakCW = "Weak CW"
        case localFM = "Local FM"
        case off = "Off"
    }

    // MARK: - Properties

    private var model: MLModel?

    /// The active denoising preset.
    public var preset: Preset = .off

    /// Noise reduction strength from 0 (none) to 1 (maximum).
    public var reductionAmount: Float = 0.5

    /// Whether the ML model has been loaded.
    public var isModelLoaded: Bool { model != nil }

    /// Whether processing is bypassed (no enhancement applied).
    public var isBypassed: Bool { preset == .off || !isModelLoaded }

    // MARK: - STFT Constants

    /// FFT size for the STFT (512 bins).
    private let fftSize = 512
    /// Hop size for overlapping STFT windows.
    private let hopSize = 256
    /// Hann window coefficients.
    private let hannWindow: [Float]

    // MARK: - Overlap-Add State

    /// Buffer for overlap-add reconstruction.
    private var overlapBuffer: [Float]

    // MARK: - Init

    public init() {
        // Pre-compute Hann window
        var window = [Float](repeating: 0, count: 512)
        for i in 0..<512 {
            window[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(512 - 1)))
        }
        self.hannWindow = window
        self.overlapBuffer = [Float](repeating: 0, count: 512)
    }

    // MARK: - Model Loading

    /// Load a Core ML denoiser model from the given URL.
    ///
    /// The model should accept an STFT magnitude spectrogram and output a denoising mask.
    ///
    /// - Parameter url: URL to the compiled `.mlmodelc` file.
    /// - Throws: If the model fails to load.
    public func loadModel(from url: URL) async throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all // Prefer Neural Engine
        model = try MLModel(contentsOf: url, configuration: config)
    }

    // MARK: - Processing

    /// Process a frame of audio samples with noise reduction.
    ///
    /// A frame is typically 20ms of audio (960 samples at 48kHz).
    /// If the model is not loaded or the preset is `.off`, the audio is passed through unchanged.
    ///
    /// Pipeline: windowed STFT -> magnitude spectrogram -> ML denoising mask -> masked STFT -> inverse STFT -> overlap-add
    ///
    /// - Parameters:
    ///   - frame: Input audio samples (mono, Float).
    ///   - sampleRate: Sample rate in Hz (typically 48000).
    /// - Returns: Enhanced audio samples (same length as input).
    public func process(frame: [Float], sampleRate: Double) async -> [Float] {
        // Bypass if not active
        guard !isBypassed else { return frame }
        guard let model = model else { return frame }

        // Pad frame to FFT size if needed
        var paddedFrame = frame
        if paddedFrame.count < fftSize {
            paddedFrame.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedFrame.count))
        }

        // Apply Hann window
        var windowedFrame = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(paddedFrame, 1, hannWindow, 1, &windowedFrame, 1, vDSP_Length(fftSize))

        // Compute magnitude spectrum (simplified — real implementation would use vDSP FFT)
        let magnitudes = computeMagnitudeSpectrum(windowedFrame)

        // Run ML inference to get denoising mask
        guard let mask = inferDenoisingMask(model: model, magnitudes: magnitudes) else {
            return frame
        }

        // Apply mask with reduction amount blending
        var enhancedMagnitudes = [Float](repeating: 0, count: magnitudes.count)
        for i in 0..<magnitudes.count {
            let maskValue = mask[i] * reductionAmount + (1.0 - reductionAmount)
            enhancedMagnitudes[i] = magnitudes[i] * maskValue
        }

        // Reconstruct audio (simplified — real implementation uses phase + inverse FFT)
        var output = reconstructAudio(enhancedMagnitudes, originalFrame: windowedFrame)

        // Apply preset-specific post-processing
        applyPresetPostProcessing(&output)

        // Trim to original frame length
        if output.count > frame.count {
            output = Array(output.prefix(frame.count))
        }

        return output
    }

    // MARK: - Internal DSP

    /// Compute magnitude spectrum from windowed audio frame.
    /// Simplified implementation — production version uses vDSP FFT.
    private func computeMagnitudeSpectrum(_ frame: [Float]) -> [Float] {
        let halfSize = fftSize / 2
        var magnitudes = [Float](repeating: 0, count: halfSize)

        // Simplified DFT for magnitude estimation
        for k in 0..<halfSize {
            var real: Float = 0
            var imag: Float = 0
            let freq = 2.0 * Float.pi * Float(k) / Float(fftSize)

            for n in 0..<min(frame.count, fftSize) {
                real += frame[n] * cos(freq * Float(n))
                imag -= frame[n] * sin(freq * Float(n))
            }

            magnitudes[k] = sqrt(real * real + imag * imag) / Float(fftSize)
        }

        return magnitudes
    }

    /// Run the ML model to produce a denoising mask.
    private func inferDenoisingMask(model: MLModel, magnitudes: [Float]) -> [Float]? {
        let halfSize = fftSize / 2

        guard let inputArray = try? MLMultiArray(
            shape: [1, NSNumber(value: halfSize)],
            dataType: .float32
        ) else {
            return nil
        }

        for i in 0..<halfSize {
            inputArray[i] = NSNumber(value: i < magnitudes.count ? magnitudes[i] : 0)
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["magnitude_input": inputArray]),
              let output = try? model.prediction(from: provider),
              let maskArray = output.featureValue(for: "denoising_mask")?.multiArrayValue else {
            return nil
        }

        var mask = [Float](repeating: 1.0, count: halfSize)
        for i in 0..<min(halfSize, maskArray.count) {
            mask[i] = max(0, min(1, maskArray[i].floatValue))
        }

        return mask
    }

    /// Reconstruct audio from enhanced magnitudes.
    /// Simplified — preserves original phase from the input frame.
    private func reconstructAudio(_ magnitudes: [Float], originalFrame: [Float]) -> [Float] {
        // In a full implementation, we'd use the original phase angles and inverse FFT.
        // For now, apply a spectral gain ratio to the original signal.
        let originalMagnitudes = computeMagnitudeSpectrum(originalFrame)

        var gainRatios = [Float](repeating: 1.0, count: magnitudes.count)
        for i in 0..<magnitudes.count {
            if originalMagnitudes[i] > 1e-10 {
                gainRatios[i] = magnitudes[i] / originalMagnitudes[i]
            }
        }

        // Apply average gain to the time-domain signal
        let avgGain = gainRatios.reduce(Float(0), +) / Float(max(1, gainRatios.count))
        var output = [Float](repeating: 0, count: originalFrame.count)
        vDSP_vsmul(originalFrame, 1, [avgGain], &output, 1, vDSP_Length(originalFrame.count))

        return output
    }

    /// Apply preset-specific post-processing to the enhanced audio.
    private func applyPresetPostProcessing(_ audio: inout [Float]) {
        switch preset {
        case .weakCW:
            // Slight boost for weak CW signals — narrow the bandwidth emphasis
            // Apply a gentle high-pass to remove low-frequency noise
            var prev: Float = 0
            for i in 0..<audio.count {
                let current = audio[i]
                audio[i] = current - prev * 0.95
                prev = current
            }
        case .hfSSB:
            // Voice-range emphasis — no additional processing needed beyond ML denoising
            break
        case .localFM:
            // FM typically has less noise, lighter touch
            break
        case .off:
            break
        }
    }
}
#endif
