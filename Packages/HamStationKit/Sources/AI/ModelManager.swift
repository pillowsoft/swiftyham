// ModelManager.swift
// HamStationKit — Manages Core ML model discovery, loading, and caching.
// Models are stored in ~/Library/Application Support/HamStationPro/Models/

#if canImport(CoreML)
import Foundation
import CoreML

/// Manages Core ML model files for on-device AI features.
///
/// Models are loaded from (in priority order):
/// 1. App bundle Resources
/// 2. User's Application Support directory (for downloaded/trained models)
///
/// All models run on-device only — no data is sent to cloud services.
public actor ModelManager {

    /// Known model types.
    public enum ModelType: String, Sendable, CaseIterable {
        case cwDecoder = "cw_decoder"
        case audioDenoiser = "audio_denoiser"

        public var displayName: String {
            switch self {
            case .cwDecoder: return "CW Neural Decoder"
            case .audioDenoiser: return "Audio Noise Reducer"
            }
        }

        /// Expected filename for the compiled model.
        var compiledFileName: String { rawValue + ".mlmodelc" }

        /// Expected filename for the model package.
        var packageFileName: String { rawValue + ".mlpackage" }
    }

    /// Status of a model.
    public struct ModelStatus: Sendable, Equatable {
        public var type: ModelType
        public var isAvailable: Bool
        public var isLoaded: Bool
        public var path: String?

        public init(type: ModelType, isAvailable: Bool = false, isLoaded: Bool = false, path: String? = nil) {
            self.type = type
            self.isAvailable = isAvailable
            self.isLoaded = isLoaded
            self.path = path
        }
    }

    // MARK: - Properties

    private var loadedModels: [ModelType: MLModel] = [:]

    /// Models directory in Application Support.
    private static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("HamStationPro/Models", isDirectory: true)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Discovery

    /// Check which models are available (in bundle or Application Support).
    public func availableModels() -> [ModelStatus] {
        ModelType.allCases.map { type in
            let path = findModel(type: type)
            return ModelStatus(
                type: type,
                isAvailable: path != nil,
                isLoaded: loadedModels[type] != nil,
                path: path?.path
            )
        }
    }

    /// Find the path to a model file.
    private func findModel(type: ModelType) -> URL? {
        // Check app bundle first
        if let bundled = Bundle.main.url(forResource: type.rawValue, withExtension: "mlmodelc") {
            return bundled
        }

        // Check Application Support
        let compiledPath = Self.modelsDirectory.appendingPathComponent(type.compiledFileName)
        if FileManager.default.fileExists(atPath: compiledPath.path) {
            return compiledPath
        }

        // Check for uncompiled .mlpackage (compile on first use)
        let packagePath = Self.modelsDirectory.appendingPathComponent(type.packageFileName)
        if FileManager.default.fileExists(atPath: packagePath.path) {
            return packagePath
        }

        return nil
    }

    // MARK: - Loading

    /// Load a model if available. Returns the MLModel or nil.
    public func loadModel(type: ModelType) async throws -> MLModel? {
        if let existing = loadedModels[type] { return existing }

        guard let url = findModel(type: type) else { return nil }

        let config = MLModelConfiguration()
        config.computeUnits = .all // Prefer Neural Engine

        let model: MLModel
        if url.pathExtension == "mlmodelc" {
            model = try MLModel(contentsOf: url, configuration: config)
        } else {
            // Compile .mlpackage to .mlmodelc
            let compiled = try await MLModel.compileModel(at: url)
            // Move compiled model to permanent location
            let destURL = Self.modelsDirectory.appendingPathComponent(type.compiledFileName)
            try? FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: compiled, to: destURL)
            model = try MLModel(contentsOf: destURL, configuration: config)
        }

        loadedModels[type] = model
        return model
    }

    /// Unload a model from memory.
    public func unloadModel(type: ModelType) {
        loadedModels[type] = nil
    }

    /// Ensure the models directory exists.
    public func ensureModelsDirectory() throws {
        try FileManager.default.createDirectory(
            at: Self.modelsDirectory,
            withIntermediateDirectories: true
        )
    }
}
#endif
