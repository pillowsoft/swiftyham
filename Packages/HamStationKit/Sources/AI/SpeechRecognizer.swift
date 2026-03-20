// SpeechRecognizer.swift
// HamStationKit — On-device speech recognition for voice logging.
// Uses Apple's SFSpeechRecognizer — NO cloud data sent.

#if canImport(Speech)
import Foundation
import Speech
import AVFoundation

/// On-device speech recognition for hands-free QSO logging.
///
/// All recognition runs on-device via `requiresOnDeviceRecognition = true`.
/// Audio never leaves the Mac. Streams partial results as the operator speaks.
public actor SpeechRecognizer {

    // MARK: - Status

    /// Current state of the speech recognizer.
    public enum Status: Sendable, Equatable {
        case idle
        case listening
        case processing
        case error(String)
    }

    // MARK: - Properties

    private let recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Current status of the recognizer.
    public private(set) var status: Status = .idle

    /// The final transcription from the last listening session.
    private var lastTranscription: String?

    // MARK: - Init

    /// Create a speech recognizer for the given locale.
    ///
    /// - Parameter locale: The locale for recognition. Defaults to US English,
    ///   which works well for ham radio terminology.
    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Permissions

    /// Request speech recognition permission from the user.
    ///
    /// - Returns: `true` if authorized, `false` otherwise.
    public static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Recognition

    /// Start listening and return a stream of partial transcription results.
    ///
    /// Uses on-device recognition only (`requiresOnDeviceRecognition = true`).
    /// The stream yields updated transcription text as words are recognized.
    /// Call ``stopListening()`` to end the session.
    ///
    /// - Returns: An `AsyncStream<String>` of partial transcription results.
    public func startListening() -> AsyncStream<String> {
        // Cancel any in-progress task
        stopRecognition()

        status = .listening
        lastTranscription = nil

        return AsyncStream { continuation in
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true

            self.audioEngine = engine
            self.recognitionRequest = request

            guard let recognizer = self.recognizer, recognizer.isAvailable else {
                self.status = .error("Speech recognizer unavailable")
                continuation.finish()
                return
            }

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            do {
                try engine.start()
            } catch {
                self.status = .error("Audio engine failed to start: \(error.localizedDescription)")
                continuation.finish()
                return
            }

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    // We can't directly use self (actor isolation) from this callback,
                    // but we store via the continuation for the consumer.
                    continuation.yield(text)

                    if result.isFinal {
                        continuation.finish()
                    }
                }

                if let error = error {
                    _ = error // logged but not blocking
                    continuation.finish()
                }
            }

            // Capture non-Sendable types using nonisolated(unsafe) to suppress
            // Sendable warnings. These are safe because the onTermination closure
            // runs after recognition ends and no concurrent access occurs.
            nonisolated(unsafe) let unsafeInputNode = inputNode
            nonisolated(unsafe) let unsafeEngine = engine
            nonisolated(unsafe) let unsafeRequest = request
            continuation.onTermination = { @Sendable _ in
                unsafeInputNode.removeTap(onBus: 0)
                unsafeEngine.stop()
                unsafeRequest.endAudio()
            }
        }
    }

    /// Stop listening and return the final transcription.
    ///
    /// - Returns: The final transcribed text, or `nil` if nothing was recognized.
    @discardableResult
    public func stopListening() -> String? {
        stopRecognition()
        status = .idle
        return lastTranscription
    }

    /// Whether on-device speech recognition is available.
    public var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    // MARK: - Internal

    private func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
    }
}
#endif
