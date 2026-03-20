// CoreMLCWDecoder.swift
// HamStationKit — Core ML wrapper for neural CW decoder (Phase 3).
// On-device inference only — audio never leaves the Mac.

#if canImport(CoreML)
import Foundation
import CoreML

/// Neural network CW decoder that supplements the traditional DSP-based ``CWDecoder``.
///
/// Uses a Core ML model trained on synthetic CW audio at varying speeds (5-50 WPM),
/// noise levels (-10dB to +20dB SNR), and fist styles. Runs on the Apple Neural Engine
/// for sub-2ms inference per 512-sample window.
///
/// When the ML model's confidence exceeds ``useMLWhenConfidenceAbove``, its predictions
/// take precedence over the traditional DSP decoder. Otherwise, the traditional decoder's
/// output is used as a fallback.
public actor CoreMLCWDecoder {

    // MARK: - Types

    /// A single prediction from the neural network.
    public struct Prediction: Sendable, Equatable {
        public var element: CWElement
        public var confidence: Float

        public init(element: CWElement, confidence: Float) {
            self.element = element
            self.confidence = confidence
        }

        /// The possible CW elements the model can classify.
        public enum CWElement: String, Sendable, CaseIterable {
            case dit
            case dah
            case elementSpace
            case characterSpace
            case wordSpace
            case noise
        }
    }

    // MARK: - Properties

    private var model: MLModel?
    private let traditionalDecoder: CWDecoder

    /// Minimum confidence threshold for using ML predictions over traditional DSP.
    public var useMLWhenConfidenceAbove: Float = 0.7

    /// Whether a Core ML model has been loaded.
    public var isModelLoaded: Bool { model != nil }

    // MARK: - Init

    /// Create a CoreML CW decoder with a traditional DSP decoder as fallback.
    ///
    /// - Parameter traditionalDecoder: The ``CWDecoder`` to use when ML confidence is low
    ///   or the model is not loaded.
    public init(traditionalDecoder: CWDecoder) {
        self.traditionalDecoder = traditionalDecoder
    }

    // MARK: - Model Loading

    /// Load a Core ML model from the given URL.
    ///
    /// The model should accept 512-sample audio windows (10.67ms at 48kHz) and output
    /// a probability distribution over ``Prediction/CWElement`` cases.
    ///
    /// - Parameter url: URL to the compiled `.mlmodelc` file.
    /// - Throws: If the model fails to load.
    public func loadModel(from url: URL) async throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all // Prefer Neural Engine
        model = try MLModel(contentsOf: url, configuration: config)
    }

    // MARK: - Processing

    /// Process audio samples and return decoded CW elements.
    ///
    /// If the ML model is loaded and its confidence exceeds the threshold, ML predictions
    /// are used. Otherwise, the traditional DSP decoder processes the audio.
    ///
    /// - Parameters:
    ///   - samples: Mono audio samples (Float).
    ///   - sampleRate: Sample rate in Hz (typically 48000).
    /// - Returns: Array of decoded elements.
    public func process(samples: [Float], sampleRate: Double) async -> [DecodedElement] {
        // If model is loaded, try ML inference on 512-sample windows
        if let model = model {
            let windowSize = 512
            var mlPredictions: [Prediction] = []

            var offset = 0
            while offset + windowSize <= samples.count {
                let window = Array(samples[offset..<(offset + windowSize)])
                if let prediction = predict(model: model, window: window) {
                    mlPredictions.append(prediction)
                }
                offset += windowSize
            }

            // Check if ML confidence is high enough
            let avgConfidence = mlPredictions.isEmpty ? 0 :
                mlPredictions.reduce(Float(0)) { $0 + $1.confidence } / Float(mlPredictions.count)

            if avgConfidence > useMLWhenConfidenceAbove {
                return convertPredictionsToElements(mlPredictions)
            }
        }

        // Fall back to traditional DSP decoder
        return await traditionalDecoder.process(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - Internal

    /// Run inference on a single 512-sample window.
    private func predict(model: MLModel, window: [Float]) -> Prediction? {
        // Create MLMultiArray input from audio samples
        guard let inputArray = try? MLMultiArray(shape: [1, NSNumber(value: window.count)], dataType: .float32) else {
            return nil
        }

        for (i, sample) in window.enumerated() {
            inputArray[i] = NSNumber(value: sample)
        }

        let featureProvider = try? MLDictionaryFeatureProvider(dictionary: ["audio_input": inputArray])
        guard let provider = featureProvider,
              let output = try? model.prediction(from: provider) else {
            return nil
        }

        // Parse output probabilities
        guard let probabilities = output.featureValue(for: "probabilities")?.multiArrayValue else {
            return nil
        }

        // Find the element with highest probability
        let elements: [Prediction.CWElement] = [.dit, .dah, .elementSpace, .characterSpace, .wordSpace, .noise]
        var bestIdx = 0
        var bestProb: Float = 0

        for i in 0..<min(elements.count, probabilities.count) {
            let prob = probabilities[i].floatValue
            if prob > bestProb {
                bestProb = prob
                bestIdx = i
            }
        }

        guard bestIdx < elements.count else { return nil }
        return Prediction(element: elements[bestIdx], confidence: bestProb)
    }

    /// Convert a sequence of ML predictions into decoded elements.
    private func convertPredictionsToElements(_ predictions: [Prediction]) -> [DecodedElement] {
        var elements: [DecodedElement] = []
        var currentPattern = ""

        for prediction in predictions {
            switch prediction.element {
            case .dit:
                currentPattern.append(".")
            case .dah:
                currentPattern.append("-")
            case .elementSpace:
                // Within a character, do nothing
                break
            case .characterSpace:
                if let decoded = decodeMorsePattern(currentPattern) {
                    elements.append(.character(decoded))
                } else if !currentPattern.isEmpty {
                    elements.append(.unknown)
                }
                currentPattern = ""
            case .wordSpace:
                if let decoded = decodeMorsePattern(currentPattern) {
                    elements.append(.character(decoded))
                } else if !currentPattern.isEmpty {
                    elements.append(.unknown)
                }
                currentPattern = ""
                elements.append(.wordSpace)
            case .noise:
                break
            }
        }

        // Emit any remaining pattern
        if !currentPattern.isEmpty {
            if let decoded = decodeMorsePattern(currentPattern) {
                elements.append(.character(decoded))
            } else {
                elements.append(.unknown)
            }
        }

        return elements
    }

    /// Decode a dit/dah pattern string to a character using the Morse table.
    private func decodeMorsePattern(_ pattern: String) -> Character? {
        // Reverse lookup in the Morse table
        CWKeyer.reverseMorseTable[pattern]
    }
}
#endif
