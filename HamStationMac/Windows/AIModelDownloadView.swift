// AIModelDownloadView.swift — Model download prompt for local AI
// Shown when AI is enabled but no local model is downloaded.
// Recommends models based on system RAM.

import SwiftUI
import HamStationKit

struct AIModelDownloadView: View {
    @Environment(AppState.self) var appState
    @State private var selectedModel: LocalLLMEngine.ModelInfo?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var downloadComplete = false

    private let engine: LocalLLMEngine
    private let onComplete: () -> Void

    init(engine: LocalLLMEngine, onComplete: @escaping () -> Void) {
        self.engine = engine
        self.onComplete = onComplete
    }

    private var recommendedModels: [LocalLLMEngine.ModelInfo] {
        LocalLLMEngine.recommendedModels()
    }

    private var bestModel: LocalLLMEngine.ModelInfo {
        LocalLLMEngine.bestModelForSystem()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 16)

            Divider()

            // Model list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(recommendedModels) { model in
                        modelCard(model)
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            footerSection
                .padding(16)
        }
        .frame(width: 500, height: 480)
        .onAppear {
            selectedModel = bestModel
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Download AI Model")
                .font(.title2.bold())

            Text("HamStation Pro uses a local AI model for band advice, contest strategy, and ham radio questions. Your data never leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.caption)
                Text("Your Mac has \(LocalLLMEngine.systemRAMGB)GB RAM")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Model Cards

    private func modelCard(_ model: LocalLLMEngine.ModelInfo) -> some View {
        let isSelected = selectedModel?.id == model.id
        let isBest = model.id == bestModel.id

        return Button {
            selectedModel = model
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .tertiary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)

                        if isBest {
                            Text("Recommended")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f GB download", model.sizeGB))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            if isDownloading {
                VStack(spacing: 6) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("Downloading \(selectedModel?.displayName ?? "model")...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = downloadError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            if downloadComplete {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Model ready!")
                        .font(.callout.bold())
                }
            }

            HStack {
                Button("Skip for Now") {
                    onComplete()
                }
                .buttonStyle(.bordered)

                Spacer()

                if downloadComplete {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Button("Download") {
                        Task { await downloadSelectedModel() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(selectedModel == nil || isDownloading)
                }
            }
        }
    }

    // MARK: - Download

    private func downloadSelectedModel() async {
        guard let model = selectedModel else { return }

        isDownloading = true
        downloadError = nil
        downloadProgress = 0

        // Poll engine status for progress
        let pollTask = Task {
            while !Task.isCancelled {
                let status = await engine.status
                if case .downloading(let progress) = status {
                    await MainActor.run { downloadProgress = progress }
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }

        do {
            try await engine.loadModel(model)
            pollTask.cancel()
            downloadProgress = 1.0
            downloadComplete = true
        } catch {
            pollTask.cancel()
            downloadError = error.localizedDescription
        }

        isDownloading = false
    }
}

#Preview {
    AIModelDownloadView(engine: LocalLLMEngine()) {}
        .environment(AppState())
}
