// KochTrainer.swift
// HamStationKit — Koch method CW training.
// Teaches Morse characters in a specific order at full speed,
// adding one new character at a time when accuracy reaches 90%.

import Foundation

/// Koch method CW trainer that progressively unlocks characters.
public actor KochTrainer {

    /// Koch character order — most common first, similar-sounding characters separated.
    public static let kochOrder: [Character] = [
        "K", "M", "R", "S", "U", "A", "P", "T", "L", "O",
        "W", "I", ".", "N", "J", "E", "F", "0", "Y", ",",
        "V", "G", "5", "/", "Q", "9", "Z", "H", "3", "8",
        "B", "?", "4", "2", "7", "C", "1", "D", "6", "X"
    ]

    /// A training session configuration.
    public struct TrainingSession: Sendable, Equatable {
        /// Number of characters unlocked (minimum 2).
        public var level: Int
        /// Speed in words per minute.
        public var speed: Int
        /// Characters per group (default 5).
        public var groupSize: Int
        /// Groups per session (default 20).
        public var groups: Int

        public init(level: Int = 2, speed: Int = 20, groupSize: Int = 5, groups: Int = 20) {
            self.level = max(2, level)
            self.speed = speed
            self.groupSize = groupSize
            self.groups = groups
        }
    }

    /// Result of scoring a training attempt.
    public struct SessionResult: Sendable, Equatable {
        public var totalCharacters: Int
        public var correctCharacters: Int
        /// Accuracy from 0.0 to 1.0.
        public var accuracy: Double
        /// Individual character errors: what was expected vs. what was typed.
        public var errors: [(expected: Character, got: Character?)]
        /// Whether the user should advance to the next level (accuracy >= 90%).
        public var shouldAdvance: Bool

        public init(
            totalCharacters: Int,
            correctCharacters: Int,
            accuracy: Double,
            errors: [(expected: Character, got: Character?)],
            shouldAdvance: Bool
        ) {
            self.totalCharacters = totalCharacters
            self.correctCharacters = correctCharacters
            self.accuracy = accuracy
            self.errors = errors
            self.shouldAdvance = shouldAdvance
        }

        public static func == (lhs: SessionResult, rhs: SessionResult) -> Bool {
            lhs.totalCharacters == rhs.totalCharacters
                && lhs.correctCharacters == rhs.correctCharacters
                && lhs.accuracy == rhs.accuracy
                && lhs.shouldAdvance == rhs.shouldAdvance
                && lhs.errors.count == rhs.errors.count
        }
    }

    /// Current Koch level (number of unlocked characters, minimum 2).
    public var currentLevel: Int = 2

    /// Current speed in WPM.
    public var speed: Int = 20

    public init(level: Int = 2, speed: Int = 20) {
        self.currentLevel = max(2, level)
        self.speed = speed
    }

    // MARK: - Character Access

    /// Characters unlocked at the current level.
    public var unlockedCharacters: [Character] {
        Array(Self.kochOrder.prefix(currentLevel))
    }

    /// The next character to be unlocked, or nil if all are unlocked.
    public var nextCharacter: Character? {
        currentLevel < Self.kochOrder.count ? Self.kochOrder[currentLevel] : nil
    }

    // MARK: - Session Generation

    /// Generate a random training session string.
    ///
    /// Returns random characters from the unlocked set, arranged in groups
    /// separated by spaces.
    public func generateSession(groups: Int = 20, groupSize: Int = 5) -> String {
        let chars = unlockedCharacters
        guard !chars.isEmpty else { return "" }

        var result: [String] = []
        for _ in 0..<groups {
            var group = ""
            for _ in 0..<groupSize {
                let index = Int.random(in: 0..<chars.count)
                group.append(chars[index])
            }
            result.append(group)
        }
        return result.joined(separator: " ")
    }

    // MARK: - Scoring

    /// Score the user's typed response against the expected text.
    ///
    /// Compares character-by-character, ignoring spaces.
    public func scoreAttempt(expected: String, actual: String) -> SessionResult {
        let expectedChars = Array(expected.uppercased().filter { $0 != " " })
        let actualChars = Array(actual.uppercased().filter { $0 != " " })

        var correct = 0
        var errors: [(expected: Character, got: Character?)] = []

        for (i, expectedChar) in expectedChars.enumerated() {
            if i < actualChars.count {
                if actualChars[i] == expectedChar {
                    correct += 1
                } else {
                    errors.append((expected: expectedChar, got: actualChars[i]))
                }
            } else {
                errors.append((expected: expectedChar, got: nil))
            }
        }

        let total = expectedChars.count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0

        return SessionResult(
            totalCharacters: total,
            correctCharacters: correct,
            accuracy: accuracy,
            errors: errors,
            shouldAdvance: accuracy >= 0.9
        )
    }

    // MARK: - Level Advancement

    /// Advance to the next Koch level if the result warrants it.
    public func advanceIfReady(result: SessionResult) {
        if result.shouldAdvance && currentLevel < Self.kochOrder.count {
            currentLevel += 1
        }
    }

    // MARK: - Practice Modes

    /// Generate realistic-looking callsigns for copy practice.
    public func generateCallsignPractice(count: Int = 10) -> [String] {
        let prefixes = ["W", "K", "N", "WA", "KB", "KD", "WB", "AA", "AB", "KG"]
        let suffixes = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        var callsigns: [String] = []
        for _ in 0..<count {
            let prefix = prefixes[Int.random(in: 0..<prefixes.count)]
            let digit = Int.random(in: 0...9)
            let suffixLength = Int.random(in: 2...3)
            var suffix = ""
            for _ in 0..<suffixLength {
                let index = suffixes.index(suffixes.startIndex,
                                           offsetBy: Int.random(in: 0..<suffixes.count))
                suffix.append(suffixes[index])
            }
            callsigns.append("\(prefix)\(digit)\(suffix)")
        }
        return callsigns
    }

    /// Generate a simulated QSO exchange for copy practice.
    public func generateQSOPractice() -> String {
        let myCall = generateCallsignPractice(count: 1).first ?? "W1AW"
        let theirCall = generateCallsignPractice(count: 1).first ?? "K3LR"
        let rst = ["559", "569", "579", "589", "599"].randomElement()!
        let name = ["JOHN", "MARY", "BOB", "ALICE", "TOM", "SARA"].randomElement()!
        let qth = ["NY", "CA", "TX", "FL", "OH", "MI"].randomElement()!

        return """
        \(theirCall) DE \(myCall) \(myCall) K
        \(myCall) DE \(theirCall) GM UR RST \(rst) \(rst) NAME \(name) QTH \(qth) HW? \(myCall) DE \(theirCall) K
        \(theirCall) DE \(myCall) R TNX FER RPT \(name) UR RST 599 599 NAME BOB QTH CT 73 \(theirCall) DE \(myCall) K
        \(myCall) DE \(theirCall) R TNX BOB 73 GL \(myCall) DE \(theirCall) SK
        """
    }
}
