// RecordingManager.swift
// HamStationKit — Observable wrapper for ScreenRecorder.

import Foundation
import SwiftUI

/// MainActor-bound observable state for screen recording UI.
@Observable
@MainActor
public final class RecordingManager {
    public private(set) var isRecording: Bool = false
    public private(set) var duration: TimeInterval = 0
    public private(set) var outputURL: URL?
    public var error: String?

    private let recorder = ScreenRecorder()
    private var timerTask: Task<Void, Never>?
    private var recordingStart: Date?

    public init() {}

    public func startRecording(to url: URL, config: ScreenRecorder.RecordingConfig = .init()) async {
        error = nil
        do {
            try await recorder.startRecording(to: url, config: config)
            isRecording = true
            recordingStart = Date()
            duration = 0

            // Update duration every second
            timerTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if let start = recordingStart {
                        duration = Date().timeIntervalSince(start)
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func stopRecording() async {
        timerTask?.cancel()
        timerTask = nil

        do {
            let url = try await recorder.stopRecording()
            outputURL = url
            isRecording = false
        } catch {
            self.error = error.localizedDescription
            isRecording = false
        }
    }

    /// Formatted duration string (MM:SS).
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
