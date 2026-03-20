// AIPrivacySettings.swift
// HamStationKit — Granular consent model for AI features.
// All AI data sharing is explicit opt-in per data type.

import Foundation

/// Privacy settings controlling what data the AI assistant may access and send to cloud APIs.
///
/// Every field defaults to off or minimal. The operator must explicitly enable AI features
/// and individually consent to each data type before it leaves the device.
public struct AIPrivacySettings: Codable, Sendable, Equatable {

    /// Master switch — no AI features operate until this is `true`.
    public var aiEnabled: Bool

    /// Include the operator's callsign in AI context.
    public var includeCallsign: Bool

    /// Include the operator's grid square (location) in AI context.
    public var includeLocation: Bool

    /// Include award progress summary (DXCC, WAS, etc.) in AI context.
    public var includeAwardProgress: Bool

    /// Include recent QSO history in AI context.
    public var includeRecentQSOs: Bool

    /// Anthropic API key. In production, stored in macOS Keychain —
    /// represented here for the model layer.
    public var apiKey: String?

    /// Which AI provider to use for cloud requests.
    public var provider: AIProvider

    /// Enable on-device natural language logging (Speech framework, no cloud).
    public var enableNaturalLanguageLogging: Bool

    /// Enable on-device smart log analysis (no cloud).
    public var enableSmartLogAnalysis: Bool

    public init(
        aiEnabled: Bool = false,
        includeCallsign: Bool = true,
        includeLocation: Bool = false,
        includeAwardProgress: Bool = false,
        includeRecentQSOs: Bool = false,
        apiKey: String? = nil,
        provider: AIProvider = .anthropic,
        enableNaturalLanguageLogging: Bool = false,
        enableSmartLogAnalysis: Bool = false
    ) {
        self.aiEnabled = aiEnabled
        self.includeCallsign = includeCallsign
        self.includeLocation = includeLocation
        self.includeAwardProgress = includeAwardProgress
        self.includeRecentQSOs = includeRecentQSOs
        self.apiKey = apiKey
        self.provider = provider
        self.enableNaturalLanguageLogging = enableNaturalLanguageLogging
        self.enableSmartLogAnalysis = enableSmartLogAnalysis
    }

    /// Supported AI service providers.
    public enum AIProvider: String, Codable, Sendable, CaseIterable {
        case local      // Qwen3 via MLX (preferred when RAM available)
        case openRouter  // Claude via OpenRouter API
        case anthropic   // Direct Anthropic API (legacy)

        public var displayName: String {
            switch self {
            case .local: return "Local (Qwen3)"
            case .openRouter: return "OpenRouter (Claude)"
            case .anthropic: return "Anthropic (Direct)"
            }
        }
    }

    /// A human-readable summary of what context will be shared in the next AI request.
    /// Displayed in the UI so the operator knows exactly what is being sent.
    public var contextSummary: String {
        guard aiEnabled else { return "AI features are disabled." }

        var shared: [String] = []
        if includeCallsign { shared.append("callsign") }
        if includeLocation { shared.append("grid square") }
        if includeAwardProgress { shared.append("award progress") }
        if includeRecentQSOs { shared.append("recent QSOs") }

        if shared.isEmpty {
            return "No personal data will be shared with AI."
        }
        return "Sharing: \(shared.joined(separator: ", "))"
    }
}
