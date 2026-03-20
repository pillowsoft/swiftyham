// RecordingControls.swift — Toolbar recording button + status
// Red record button, elapsed time counter, stop button.

import SwiftUI
import HamStationKit

struct RecordingControls: View {
    @State private var recordingManager = RecordingManager()
    @State private var showingSavePanel = false

    var body: some View {
        HStack(spacing: 6) {
            if recordingManager.isRecording {
                // Recording indicator + timer
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseOpacity)

                Text(recordingManager.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)

                Button {
                    Task { await recordingManager.stopRecording() }
                } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Stop Recording")
            } else {
                Button {
                    showingSavePanel = true
                } label: {
                    Label("Record", systemImage: "record.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Record screen to MP4")
            }
        }
        .onChange(of: showingSavePanel) { _, show in
            if show {
                presentSavePanel()
            }
        }
        .alert("Recording Error", isPresented: .init(
            get: { recordingManager.error != nil },
            set: { if !$0 { recordingManager.error = nil } }
        )) {
            Button("OK") { recordingManager.error = nil }
        } message: {
            Text(recordingManager.error ?? "")
        }
        .onChange(of: recordingManager.outputURL) { _, url in
            if let url {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private var pulseOpacity: Double {
        recordingManager.isRecording ? 0.3 : 1.0
    }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Save Recording"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "HamStation-\(dateString()).mp4"
        panel.canCreateDirectories = true

        panel.begin { response in
            showingSavePanel = false
            if response == .OK, let url = panel.url {
                Task {
                    await recordingManager.startRecording(to: url)
                }
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    RecordingControls()
        .padding()
}
