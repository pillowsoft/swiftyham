// AIAssistantView.swift — Chat interface for the AI assistant.
// Conversational UI with message bubbles, quick actions, and privacy indicator.

import SwiftUI

struct AIAssistantView: View {
    @Environment(AppState.self) var appState

    @State private var inputText: String = ""
    @State private var messages: [AIMessage] = []
    @State private var isLoading: Bool = false
    @State private var aiEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if !aiEnabled {
                aiFeaturesOffBanner
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
        var shared: [String] = []
        shared.append("callsign")  // Placeholder — would read from AIPrivacySettings
        if shared.isEmpty {
            return "No personal data shared"
        }
        return "Sharing: \(shared.joined(separator: ", "))"
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

        // Simulate AI response — in production, this calls AIAssistant.sendMessage
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let response = AIMessage(
                role: .assistant,
                content: "I'd be happy to help with that! This is a placeholder response. Connect an Anthropic API key in Settings to get real AI assistance."
            )
            messages.append(response)
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
