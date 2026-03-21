// AIAssistantView.swift — Chat interface for the AI assistant.
// Conversational UI with message bubbles, quick actions, and privacy indicator.

import SwiftUI
import HamStationKit

struct AIAssistantView: View {
    @Environment(AppState.self) var appState

    @AppStorage("ai_enabled") private var aiEnabled: Bool = false
    @AppStorage("ai_provider") private var providerRaw: String = AIPrivacySettings.AIProvider.local.rawValue
    @AppStorage("ai_include_callsign") private var includeCallsign: Bool = true
    @AppStorage("ai_include_location") private var includeLocation: Bool = false
    @AppStorage("ai_include_award_progress") private var includeAwardProgress: Bool = false
    @AppStorage("ai_include_recent_qsos") private var includeRecentQSOs: Bool = false

    @State private var inputText: String = ""
    @State private var messages: [AIMessage] = []
    @State private var isLoading: Bool = false
    @State private var aiAssistant: AIAssistant?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if !aiEnabled {
                aiFeaturesOffBanner
            }

            // Error banner
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        self.errorMessage = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Quick action buttons
            quickActions

            Divider()

            // Privacy indicator
            privacyIndicator

            // Input field
            inputBar
        }
        .navigationTitle("AI Assistant")
        .task {
            rebuildAssistant()
        }
        .onChange(of: aiEnabled) { _, _ in rebuildAssistant() }
        .onChange(of: providerRaw) { _, _ in rebuildAssistant() }
        .onChange(of: includeCallsign) { _, _ in rebuildAssistant() }
        .onChange(of: includeLocation) { _, _ in rebuildAssistant() }
        .onChange(of: includeAwardProgress) { _, _ in rebuildAssistant() }
        .onChange(of: includeRecentQSOs) { _, _ in rebuildAssistant() }
    }

    // MARK: - Build AIAssistant from current settings

    private func rebuildAssistant() {
        let provider = AIPrivacySettings.AIProvider(rawValue: providerRaw) ?? .local
        let keychainKey = provider == .openRouter ? "openrouter_api_key" : "anthropic_api_key"
        let apiKey = KeychainHelper.load(key: keychainKey)

        let settings = AIPrivacySettings(
            aiEnabled: aiEnabled,
            includeCallsign: includeCallsign,
            includeLocation: includeLocation,
            includeAwardProgress: includeAwardProgress,
            includeRecentQSOs: includeRecentQSOs,
            apiKey: apiKey,
            provider: provider
        )
        aiAssistant = AIAssistant(privacySettings: settings)
    }

    // MARK: - Build context from AppState

    private func buildContext() -> AssistantContext {
        AssistantContext(
            operatorCallsign: appState.operatorCallsign,
            gridSquare: appState.gridSquare,
            licenseClass: appState.licenseClass,
            currentBand: appState.rigState?.band,
            currentMode: appState.rigState?.modeString
        )
    }

    // MARK: - AI Features Off Banner

    private var aiFeaturesOffBanner: some View {
        HStack {
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
            Text("AI features are off.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Enable in Settings") {
                // TODO: Open AI settings tab
            }
            .font(.callout)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickActionButton(title: "Band advice", icon: "antenna.radiowaves.left.and.right") {
                    sendQuickAction("Based on current conditions, which bands should I try right now?")
                }
                QuickActionButton(title: "QSL advice", icon: "envelope") {
                    sendQuickAction("What's the best way to confirm my recent contacts?")
                }
                QuickActionButton(title: "Analyze log", icon: "chart.bar") {
                    sendQuickAction("Analyze my recent operating patterns and suggest improvements.")
                }
                QuickActionButton(title: "Pile-up tips", icon: "person.3") {
                    sendQuickAction("Give me tips for working pile-ups more effectively.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Privacy Indicator

    private var privacyIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.shield")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(privacySummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var privacySummary: String {
        guard aiEnabled else { return "AI features disabled" }
        let provider = AIPrivacySettings.AIProvider(rawValue: providerRaw) ?? .local
        if provider == .local {
            return "Local model — no data leaves your Mac"
        }
        var shared: [String] = []
        if includeCallsign { shared.append("callsign") }
        if includeLocation { shared.append("grid square") }
        if includeAwardProgress { shared.append("award progress") }
        if includeRecentQSOs { shared.append("recent QSOs") }
        if shared.isEmpty {
            return "No personal data shared • \(provider.displayName)"
        }
        return "Sharing: \(shared.joined(separator: ", ")) • \(provider.displayName)"
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about ham radio...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit { sendMessage() }
                .disabled(!aiEnabled)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.isEmpty || !aiEnabled
                        ? Color.secondary
                        : Color(hex: "FF6A00")
                    )
            }
            .buttonStyle(.borderless)
            .disabled(inputText.isEmpty || !aiEnabled || isLoading)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = AIMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            guard let assistant = aiAssistant else {
                errorMessage = "AI assistant not initialized. Check your settings."
                isLoading = false
                return
            }

            let context = buildContext()
            do {
                let responseText = try await assistant.sendMessage(text, context: context)
                let response = AIMessage(role: .assistant, content: responseText)
                messages.append(response)
            } catch let error as AIAssistantError {
                switch error {
                case .notEnabled:
                    errorMessage = "AI features are disabled. Enable them in Settings."
                case .noAPIKey:
                    errorMessage = "No API key configured. Add one in Settings."
                case .rateLimited:
                    errorMessage = "Rate limited. Please wait a moment and try again."
                case .requestFailed(let msg):
                    errorMessage = "Request failed: \(msg)"
                case .networkError(let msg):
                    errorMessage = "Network error: \(msg)"
                }
            } catch {
                errorMessage = "Unexpected error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func sendQuickAction(_ text: String) {
        inputText = text
        sendMessage()
    }
}

// MARK: - AIMessage

struct AIMessage: Identifiable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Sendable {
        case user
        case assistant
        case system
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: AIMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color(hex: "FF6A00").opacity(0.15))
        } else {
            return AnyShapeStyle(Color.secondary.opacity(0.1))
        }
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Preview

#Preview("AI Assistant — Active") {
    AIAssistantView()
        .environment(AppState())
        .frame(width: 600, height: 500)
}

#Preview("AI Assistant — With Messages") {
    let view = AIAssistantView()
    return view
        .environment(AppState())
        .frame(width: 600, height: 500)
        .onAppear {
            // Preview messages would be injected via the @State property
        }
}
