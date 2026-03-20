// AIAssistant.swift
// HamStationKit — Conversational AI assistant for amateur radio operators.
// Uses Claude API. Only sends data the operator has explicitly consented to share.

import Foundation

// MARK: - Supporting Types

/// Operator context assembled from consented data only.
public struct AssistantContext: Sendable, Equatable {
    public var operatorCallsign: String?
    public var gridSquare: String?
    public var licenseClass: String?
    public var currentBand: String?
    public var currentMode: String?
    public var awardsSummary: String?
    public var recentQSOsSummary: String?
    public var solarConditions: String?

    public init(
        operatorCallsign: String? = nil,
        gridSquare: String? = nil,
        licenseClass: String? = nil,
        currentBand: String? = nil,
        currentMode: String? = nil,
        awardsSummary: String? = nil,
        recentQSOsSummary: String? = nil,
        solarConditions: String? = nil
    ) {
        self.operatorCallsign = operatorCallsign
        self.gridSquare = gridSquare
        self.licenseClass = licenseClass
        self.currentBand = currentBand
        self.currentMode = currentMode
        self.awardsSummary = awardsSummary
        self.recentQSOsSummary = recentQSOsSummary
        self.solarConditions = solarConditions
    }
}

/// A single message in the AI conversation.
public struct ChatMessage: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date

    public enum Role: String, Sendable, Codable {
        case user
        case assistant
        case system
    }

    public init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Errors that can occur during AI assistant operations.
public enum AIAssistantError: Error, Sendable, Equatable {
    case notEnabled
    case noAPIKey
    case requestFailed(String)
    case rateLimited
    case networkError(String)
}

// MARK: - AIAssistant Actor

/// Conversational AI assistant for ham radio.
///
/// Sends requests to the Anthropic Claude API with a ham-radio-expert system prompt.
/// Only includes operator context that the user has explicitly consented to share
/// via ``AIPrivacySettings``.
public actor AIAssistant {

    // MARK: - Properties

    private let privacySettings: AIPrivacySettings
    private var _conversationHistory: [ChatMessage] = []
    private let maxHistoryMessages = 20

    /// The full conversation history.
    public var conversationHistory: [ChatMessage] { _conversationHistory }

    // MARK: - Init

    public init(privacySettings: AIPrivacySettings) {
        self.privacySettings = privacySettings
    }

    // MARK: - System Prompt

    /// Build the system prompt, including only data the user has consented to share.
    public func buildSystemPrompt(context: AssistantContext) -> String {
        var parts: [String] = [
            "You are an expert amateur (ham) radio assistant built into HamStation Pro, a macOS station logger.",
            "You help operators with band conditions, pile-up strategy, QSL routing, award tracking, contest advice, and general ham radio questions.",
            "Be concise and practical. Use standard ham radio terminology. Format callsigns, frequencies, and signal reports in monospace when possible."
        ]

        // Only include consented context
        if privacySettings.includeCallsign, let call = context.operatorCallsign, !call.isEmpty {
            parts.append("The operator's callsign is \(call).")
        }

        if privacySettings.includeLocation, let grid = context.gridSquare, !grid.isEmpty {
            parts.append("The operator is located at grid square \(grid).")
        }

        if let license = context.licenseClass, !license.isEmpty {
            parts.append("License class: \(license).")
        }

        if let band = context.currentBand, !band.isEmpty {
            parts.append("Currently operating on \(band).")
        }

        if let mode = context.currentMode, !mode.isEmpty {
            parts.append("Current mode: \(mode).")
        }

        if privacySettings.includeAwardProgress, let awards = context.awardsSummary, !awards.isEmpty {
            parts.append("Award progress: \(awards)")
        }

        if privacySettings.includeRecentQSOs, let qsos = context.recentQSOsSummary, !qsos.isEmpty {
            parts.append("Recent QSOs: \(qsos)")
        }

        if let solar = context.solarConditions, !solar.isEmpty {
            parts.append("Current solar conditions: \(solar)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Send Message

    /// Send a message to the Claude API and return the assistant's response.
    ///
    /// - Parameters:
    ///   - message: The user's message text.
    ///   - context: Operator context (filtered by privacy settings in system prompt).
    /// - Returns: The assistant's response text.
    /// - Throws: ``AIAssistantError`` if the request fails.
    public func sendMessage(_ message: String, context: AssistantContext) async throws -> String {
        guard privacySettings.aiEnabled else {
            throw AIAssistantError.notEnabled
        }
        guard let apiKey = privacySettings.apiKey, !apiKey.isEmpty else {
            throw AIAssistantError.noAPIKey
        }

        // Append user message to history
        let userMessage = ChatMessage(role: .user, content: message)
        _conversationHistory.append(userMessage)
        trimHistory()

        // Build API request
        let systemPrompt = buildSystemPrompt(context: context)
        let apiMessages = _conversationHistory.compactMap { msg -> [String: String]? in
            switch msg.role {
            case .user: return ["role": "user", "content": msg.content]
            case .assistant: return ["role": "assistant", "content": msg.content]
            case .system: return nil
            }
        }

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": apiMessages
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIAssistantError.networkError("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw AIAssistantError.requestFailed("Failed to serialize request body")
        }
        request.httpBody = httpBody

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIAssistantError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAssistantError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 429 {
            throw AIAssistantError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIAssistantError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIAssistantError.requestFailed("Failed to parse API response")
        }

        // Append assistant response to history
        let assistantMessage = ChatMessage(role: .assistant, content: text)
        _conversationHistory.append(assistantMessage)
        trimHistory()

        return text
    }

    // MARK: - History Management

    /// Clear all conversation history.
    public func clearHistory() {
        _conversationHistory.removeAll()
    }

    private func trimHistory() {
        if _conversationHistory.count > maxHistoryMessages {
            _conversationHistory = Array(_conversationHistory.suffix(maxHistoryMessages))
        }
    }

    // MARK: - Convenience Methods

    /// Ask for band/propagation advice based on current conditions.
    public func askBandAdvice(context: AssistantContext) async throws -> String {
        let prompt = "Based on current conditions, which bands and modes should I try right now? Give me your top 3 recommendations with brief reasons."
        return try await sendMessage(prompt, context: context)
    }

    /// Ask for pile-up operating advice for a specific DX station.
    public func askPileUpAdvice(dxCallsign: String, context: AssistantContext) async throws -> String {
        let prompt = "I'm trying to work \(dxCallsign) in a pile-up. Any tips on timing, split frequency strategy, or operating technique?"
        return try await sendMessage(prompt, context: context)
    }

    /// Ask for QSL confirmation advice for a specific callsign.
    public func askQSLAdvice(callsign: String, context: AssistantContext) async throws -> String {
        let prompt = "What's the best way to get a QSL confirmation from \(callsign)? Should I use LoTW, eQSL, direct card, or bureau?"
        return try await sendMessage(prompt, context: context)
    }
}
