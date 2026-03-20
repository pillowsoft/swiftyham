// ScreenRecorder.swift
// HamStationKit — ScreenCaptureKit + AVAssetWriter to MP4.

import AVFoundation
import ScreenCaptureKit
import os.log

/// Captures an app window (video + audio) to MP4 via ScreenCaptureKit.
@MainActor
public final class ScreenRecorder {

    private static let logger = Logger(subsystem: "com.hamstation", category: "ScreenRecorder")

    public enum RecorderError: Error, LocalizedError, Sendable {
        case noWindowFound
        case alreadyRecording
        case notRecording
        case writerSetupFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noWindowFound: return "Could not find the HamStation window to record."
            case .alreadyRecording: return "Recording is already in progress."
            case .notRecording: return "No recording in progress."
            case .writerSetupFailed(let reason): return "Failed to set up recorder: \(reason)"
            }
        }
    }

    public struct RecordingConfig: Sendable {
        public var frameRate: Int
        public var useHEVC: Bool
        public var scaleFactor: CGFloat

        public init(frameRate: Int = 30, useHEVC: Bool = false, scaleFactor: CGFloat = 1.0) {
            self.frameRate = frameRate
            self.useHEVC = useHEVC
            self.scaleFactor = scaleFactor
        }
    }

    private var stream: SCStream?
    private var outputURL: URL?
    private(set) var isActive: Bool = false
    private var streamOutput: RecorderStreamOutput?

    public init() {}

    // MARK: - Public API

    public func startRecording(to url: URL, config: RecordingConfig = RecordingConfig()) async throws {
        guard !isActive else { throw RecorderError.alreadyRecording }

        Self.logger.info("Starting screen recording to \(url.path)")

        // Find the HamStation window
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let appWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        guard let targetWindow = appWindows.first else {
            throw RecorderError.noWindowFound
        }

        let width = Int(CGFloat(targetWindow.frame.width) * config.scaleFactor)
        let height = Int(CGFloat(targetWindow.frame.height) * config.scaleFactor)

        // Set up content filter for single window
        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = width
        streamConfig.height = height
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.frameRate))
        streamConfig.capturesAudio = true
        streamConfig.sampleRate = 48000
        streamConfig.channelCount = 2

        // Set up AVAssetWriter
        let videoCodec: AVVideoCodecType = config.useHEVC ? .hevc : .h264
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(vInput), writer.canAdd(aInput) else {
            throw RecorderError.writerSetupFailed("Cannot add inputs to asset writer")
        }
        writer.add(vInput)
        writer.add(aInput)

        guard writer.startWriting() else {
            throw RecorderError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown error")
        }

        self.outputURL = url

        // Create stream output handler — owns the writer, processes samples on its queue
        let output = RecorderStreamOutput(writer: writer, videoInput: vInput, audioInput: aInput)
        self.streamOutput = output

        let scStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        try scStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
        try scStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue)

        try await scStream.startCapture()
        self.stream = scStream
        self.isActive = true

        Self.logger.info("Screen recording started: \(width)x\(height) @ \(config.frameRate)fps")
    }

    public func stopRecording() async throws -> URL {
        guard isActive, let output = streamOutput, let url = outputURL else {
            throw RecorderError.notRecording
        }

        Self.logger.info("Stopping screen recording...")

        // Stop the capture stream
        if let stream = self.stream {
            try await stream.stopCapture()
        }

        // Finalize the asset writer on the output's queue
        await output.finalize()

        // Clean up
        self.stream = nil
        self.streamOutput = nil
        self.isActive = false

        Self.logger.info("Screen recording saved to \(url.path)")
        return url
    }
}

// MARK: - Stream Output Delegate

/// Handles sample buffer processing synchronously on a dedicated serial queue.
/// This avoids sending CMSampleBuffer across isolation boundaries.
private final class RecorderStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.hamstation.screen-recorder", qos: .userInitiated)

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private var sessionStarted = false

    init(writer: AVAssetWriter, videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput) {
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Already on self.queue — process synchronously
        guard writer.status == .writing else { return }

        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        switch type {
        case .screen:
            if videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        case .audio:
            if audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        @unknown default:
            break
        }
    }

    func finalize() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [self] in
                videoInput.markAsFinished()
                audioInput.markAsFinished()
                writer.finishWriting {
                    continuation.resume()
                }
            }
        }
    }
}
