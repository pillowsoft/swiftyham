// LocalLLMEngine.swift
// HamStationKit — On-device LLM inference via MLX Swift.
// All inference runs locally on Apple Silicon — no data leaves the Mac.

import Foundation
import MLXLMCommon
import MLXLLM

/// On-device LLM engine using Apple's MLX framework.
///
/// Downloads models from Hugging Face on first use, caches them locally,
/// and runs inference entirely on the Apple Silicon GPU. No API keys needed,
/// no data leaves the device.
public actor LocalLLMEngine {

    // MARK: - Model Catalog

    /// A downloadable model with metadata for UI display.
    public struct ModelInfo: Sendable, Identifiable, Equatable {
        public let id: String
        /// Hugging Face model ID (e.g., "mlx-community/Qwen3-4B-4bit").
        public let huggingFaceID: String
        /// Human-readable name.
        public let displayName: String
        /// Approximate download size in GB.
        public let sizeGB: Double
        /// Minimum recommended RAM in GB.
        public let minRAMGB: Int
        /// Brief description.
        public let description: String

        public init(id: String, huggingFaceID: String, displayName: String,
                    sizeGB: Double, minRAMGB: Int, description: String) {
            self.id = id
            self.huggingFaceID = huggingFaceID
            self.displayName = displayName
            self.sizeGB = sizeGB
            self.minRAMGB = minRAMGB
            self.description = description
        }
    }

    /// Recommended models by system RAM tier.
    public static let modelCatalog: [ModelInfo] = [
        ModelInfo(
            id: "qwen3-0.6b",
            huggingFaceID: "mlx-community/Qwen3-0.6B-4bit",
            displayName: "Qwen3 0.6B (Tiny)",
            sizeGB: 0.5,
            minRAMGB: 8,
            description: "Fast responses, basic ham radio knowledge. Best for 8GB Macs."
        ),
        ModelInfo(
            id: "qwen3-4b",
            huggingFaceID: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen3 4B (Recommended)",
            sizeGB: 2.3,
            minRAMGB: 8,
            description: "Good balance of speed and quality. Works well on most Macs."
        ),
        ModelInfo(
            id: "qwen3-8b",
            huggingFaceID: "mlx-community/Qwen3-8B-4bit",
            displayName: "Qwen3 8B (Quality)",
            sizeGB: 4.5,
            minRAMGB: 16,
            description: "Best quality for band advice, contest strategy, and technical questions."
        ),
    ]

    // MARK: - State

    /// Current engine status.
    public enum Status: Sendable, Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready
        case generating
        case error(String)
    }

    public private(set) var status: Status = .idle

    /// The currently loaded model info, or nil.
    public private(set) var loadedModelInfo: ModelInfo?

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    // MARK: - Init

    public init() {}

    // MARK: - Model Recommendation

    /// Recommend models based on system RAM.
    public static func recommendedModels() -> [ModelInfo] {
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        return modelCatalog.filter { $0.minRAMGB <= ramGB }
    }

    /// The single best model for this Mac's RAM.
    public static func bestModelForSystem() -> ModelInfo {
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        if ramGB >= 16 {
            return modelCatalog.first { $0.id == "qwen3-8b" } ?? modelCatalog[1]
        } else if ramGB >= 8 {
            return modelCatalog.first { $0.id == "qwen3-4b" } ?? modelCatalog[0]
        } else {
            return modelCatalog[0]
        }
    }

    /// System RAM in GB.
    public static var systemRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
    }

    // MARK: - Download & Load

    /// Download and load a model. Reports progress via status updates.
    ///
    /// Models are cached by the Hugging Face Hub client.
    /// Subsequent loads skip the download.
    ///
    /// - Parameter model: The model to download and load.
    public func loadModel(_ model: ModelInfo) async throws {
        status = .downloading(progress: 0)
        loadedModelInfo = model

        let configuration = ModelConfiguration(id: model.huggingFaceID)

        do {
            let container = try await loadModelContainer(
                configuration: configuration
            ) { [weak self] progress in
                Task { [weak self] in
                    await self?.updateDownloadProgress(progress.fractionCompleted)
                }
            }

            self.modelContainer = container
            self.chatSession = nil // Reset session for new model
            status = .ready
        } catch {
            status = .error("Failed to load model: \(error.localizedDescription)")
            loadedModelInfo = nil
            throw error
        }
    }

    private func updateDownloadProgress(_ fraction: Double) {
        if case .downloading = status {
            status = .downloading(progress: fraction)
        }
    }

    /// Unload the current model to free memory.
    public func unloadModel() {
        modelContainer = nil
        chatSession = nil
        loadedModelInfo = nil
        status = .idle
    }

    /// Whether a model is loaded and ready for inference.
    public var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    // MARK: - Chat Inference

    /// Generate a response to a conversation using ChatSession.
    ///
    /// - Parameters:
    ///   - systemPrompt: The system prompt (ham radio expert context).
    ///   - messages: Conversation history as (role, content) pairs.
    /// - Returns: The assistant's response text.
    public func chat(
        systemPrompt: String,
        messages: [(role: String, content: String)]
    ) async throws -> String {
        guard let container = modelContainer else {
            throw LocalLLMError.modelNotLoaded
        }

        status = .generating

        // Find the last user message
        guard let lastUserMessage = messages.last(where: { $0.role == "user" })?.content else {
            throw LocalLLMError.generationFailed("No user message provided")
        }

        do {
            // Create a fresh session per request to avoid Sendable issues.
            // The ModelContainer handles caching internally.
            let session = ChatSession(
                container,
                instructions: systemPrompt,
                generateParameters: .init(temperature: 0.7, topP: 0.9)
            )
            let response = try await session.respond(to: lastUserMessage)
            status = .ready
            return response
        } catch {
            status = .ready
            throw LocalLLMError.generationFailed(error.localizedDescription)
        }
    }

    /// Clear conversation history.
    public func clearHistory() async {
        chatSession = nil
    }

    private func setStatus(_ newStatus: Status) {
        status = newStatus
    }
}

// MARK: - Errors

public enum LocalLLMError: Error, Sendable {
    case modelNotLoaded
    case generationFailed(String)
    case downloadFailed(String)
}
