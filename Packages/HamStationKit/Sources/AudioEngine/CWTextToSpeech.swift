// CWTextToSpeech.swift
// HamStationKit — Speaks decoded CW/Morse text as it arrives.

import Foundation

/// Speaks decoded CW/Morse text as it arrives.
/// Buffers characters and speaks them as words (on word space) or after a timeout.
@MainActor
public final class CWTextToSpeech: ObservableObject {
    public let speechEngine: SpeechEngine
    private var buffer: String = ""
    private var speakTask: Task<Void, Never>?

    @Published public var isEnabled: Bool = false
    @Published public var speakMode: SpeakMode = .words

    public enum SpeakMode: String, CaseIterable, Sendable {
        case characters
        case words
        case sentences
    }

    public init(speechEngine: SpeechEngine) {
        self.speechEngine = speechEngine
    }

    /// Called by CW decoder when new text is decoded.
    public func onDecodedText(_ text: String) {
        guard isEnabled else { return }

        switch speakMode {
        case .characters:
            for char in text {
                let spoken = Self.natoPhonetic(char) ?? String(char)
                speechEngine.speak(spoken)
            }
        case .words:
            buffer += text
            if buffer.contains(" ") {
                let words = buffer.split(separator: " ")
                for word in words.dropLast() {
                    speechEngine.speak(String(word))
                }
                buffer = String(words.last ?? "")
            }
            resetSpeakTimer()
        case .sentences:
            buffer += text
            resetSpeakTimer()
        }
    }

    public func flush() {
        if !buffer.isEmpty {
            speechEngine.speak(buffer)
            buffer = ""
        }
    }

    private func resetSpeakTimer() {
        speakTask?.cancel()
        speakTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            if !Task.isCancelled && !buffer.isEmpty {
                speechEngine.speak(buffer)
                buffer = ""
            }
        }
    }

    /// NATO phonetic alphabet — standard ham radio practice for clarity.
    public static func natoPhonetic(_ char: Character) -> String? {
        let table: [Character: String] = [
            "A": "Alpha", "B": "Bravo", "C": "Charlie", "D": "Delta",
            "E": "Echo", "F": "Foxtrot", "G": "Golf", "H": "Hotel",
            "I": "India", "J": "Juliet", "K": "Kilo", "L": "Lima",
            "M": "Mike", "N": "November", "O": "Oscar", "P": "Papa",
            "Q": "Quebec", "R": "Romeo", "S": "Sierra", "T": "Tango",
            "U": "Uniform", "V": "Victor", "W": "Whiskey", "X": "X-ray",
            "Y": "Yankee", "Z": "Zulu",
            "0": "Zero", "1": "One", "2": "Two", "3": "Three",
            "4": "Four", "5": "Five", "6": "Six", "7": "Seven",
            "8": "Eight", "9": "Niner",
            "/": "Stroke", ".": "Stop", ",": "Comma", "?": "Question",
        ]
        return table[Character(char.uppercased())]
    }
}
