// SpeechEngine.swift
// HamStationKit — Unified TTS: Kokoro (MLX) primary, AVSpeechSynthesizer fallback.

import AVFoundation
import Foundation

/// Unified TTS engine: tries Kokoro (MLX) first, falls back to AVSpeechSynthesizer.
@MainActor
public final class SpeechEngine: NSObject, ObservableObject {

    public enum TTSBackend: String, CaseIterable, Sendable {
        case kokoro = "Kokoro (MLX)"
        case system = "System Voice"
        case auto = "Auto (Best Available)"
    }

    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var activeBackend: TTSBackend = .auto
    @Published public private(set) var kokoroAvailable: Bool = false

    public var preferredBackend: TTSBackend = .auto
    public var kokoroVoice: String = "af_heart"
    public var kokoroSpeed: Float = 1.0
    public var systemVoiceId: String? = nil
    public var volume: Float = 0.8

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechQueue: [String] = []
    private var isProcessingQueue: Bool = false
    private var pythonPath: String = "/usr/bin/python3"  // resolved during availability check
    private var currentTask: Task<Void, Never>?
    private var completionHandler: (@MainActor () -> Void)?

    private let tempDir: URL

    public override init() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("hamstation-tts")
        super.init()
        synthesizer.delegate = self
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        Task { await checkKokoroAvailability() }
    }

    // MARK: - Availability Check

    public func checkKokoroAvailability() async {
        // macOS GUI apps don't inherit shell PATH, so /usr/bin/env won't find conda/brew python.
        // Search common Python locations for one that has mlx_audio installed.
        let candidates = [
            "\(NSHomeDirectory())/miniconda3/bin/python3",
            "\(NSHomeDirectory())/anaconda3/bin/python3",
            "\(NSHomeDirectory())/miniforge3/bin/python3",
            "\(NSHomeDirectory())/.conda/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]

        let found = await Task.detached { () -> String? in
            for path in candidates {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = ["-c", "import mlx_audio; print('ok')"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if process.terminationStatus == 0 && output.contains("ok") {
                        return path
                    }
                } catch {
                    continue
                }
            }
            return nil
        }.value

        if let path = found {
            pythonPath = path
            kokoroAvailable = true
        } else {
            kokoroAvailable = false
        }
    }

    // MARK: - Public API

    /// Speak text using the best available backend.
    public func speak(_ text: String) {
        stop()
        currentTask = Task {
            await speakAsync(text)
        }
    }

    /// Speak with completion callback.
    public func speak(_ text: String, completion: @escaping @MainActor () -> Void) {
        self.completionHandler = completion
        speak(text)
    }

    /// Queue multiple texts to speak in order.
    public func speakSequence(_ texts: [String]) {
        stop()
        speechQueue = texts
        isProcessingQueue = true
        processQueue()
    }

    public func stop() {
        currentTask?.cancel()
        currentTask = nil
        speechQueue.removeAll()
        isProcessingQueue = false
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Internal

    private func speakAsync(_ text: String) async {
        let backend = resolveBackend()
        activeBackend = backend

        switch backend {
        case .kokoro:
            await speakWithKokoro(text)
        case .system:
            speakWithSystem(text)
        case .auto:
            speakWithSystem(text)
        }
    }

    private func resolveBackend() -> TTSBackend {
        switch preferredBackend {
        case .kokoro:
            return kokoroAvailable ? .kokoro : .system
        case .system:
            return .system
        case .auto:
            return kokoroAvailable ? .kokoro : .system
        }
    }

    // MARK: - Kokoro via mlx-audio subprocess

    private func speakWithKokoro(_ text: String) async {
        isSpeaking = true

        let outputFile = tempDir.appendingPathComponent("speech-\(UUID().uuidString).wav")
        let voice = kokoroVoice
        let speed = kokoroSpeed
        let outputPath = outputFile.path

        let python = pythonPath
        let result = await Task.detached { () -> Int32 in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [
                "-m", "mlx_audio.tts.generate",
                "--model", "mlx-community/Kokoro-82M-bf16",
                "--text", text,
                "--voice", voice,
                "--speed", String(speed),
                "--output", outputPath,
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus
            } catch {
                return -1
            }
        }.value

        guard result == 0 else {
            speakWithSystem(text)
            return
        }

        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            speakWithSystem(text)
            return
        }

        do {
            let data = try Data(contentsOf: outputFile)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = volume
            audioPlayer?.delegate = self
            audioPlayer?.play()

            Task {
                try? await Task.sleep(for: .seconds(30))
                try? FileManager.default.removeItem(at: outputFile)
            }
        } catch {
            speakWithSystem(text)
        }
    }

    // MARK: - System voice (AVSpeechSynthesizer) fallback

    private func speakWithSystem(_ text: String) {
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)

        if let voiceId = systemVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            let voices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.starts(with: "en") }
                .sorted { $0.quality.rawValue > $1.quality.rawValue }
            utterance.voice = voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = volume
        utterance.preUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    // MARK: - Queue processing

    private func processQueue() {
        guard isProcessingQueue, !speechQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        let next = speechQueue.removeFirst()
        speak(next) { [weak self] in
            self?.processQueue()
        }
    }

    // MARK: - Voice listing

    public static func availableKokoroVoices() -> [(id: String, name: String, description: String)] {
        [
            ("af_heart", "Heart", "American Female — warm, friendly"),
            ("af_bella", "Bella", "American Female — professional"),
            ("af_nicole", "Nicole", "American Female — conversational"),
            ("af_sarah", "Sarah", "American Female — clear, bright"),
            ("af_sky", "Sky", "American Female — youthful"),
            ("am_adam", "Adam", "American Male — authoritative"),
            ("am_michael", "Michael", "American Male — warm, deep"),
            ("bf_emma", "Emma", "British Female — BBC-style"),
            ("bf_isabella", "Isabella", "British Female — elegant"),
            ("bm_george", "George", "British Male — classic"),
            ("bm_lewis", "Lewis", "British Male — modern"),
        ]
    }

    public static func availableSystemVoices() -> [(id: String, name: String, quality: String)] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
            .map {
                let quality: String
                switch $0.quality {
                case .premium: quality = "Premium"
                case .enhanced: quality = "Enhanced"
                default: quality = "Default"
                }
                return (id: $0.identifier, name: $0.name, quality: quality)
            }
    }

    // MARK: - Completion dispatch

    nonisolated private func handleFinished() {
        Task { @MainActor in
            isSpeaking = false
            completionHandler?()
            completionHandler = nil
        }
    }

    nonisolated private func handleCancelled() {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechEngine: @preconcurrency AVSpeechSynthesizerDelegate {

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        handleFinished()
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        handleCancelled()
    }
}

// MARK: - AVAudioPlayerDelegate

extension SpeechEngine: @preconcurrency AVAudioPlayerDelegate {

    nonisolated public func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        handleFinished()
    }
}
