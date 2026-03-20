// BaudotCode.swift
// HamStationKit — Baudot (ITA2) code for RTTY.
// 5-bit code with LETTERS and FIGURES shift modes.
// US ITA2 standard.

import Foundation

/// Baudot / ITA2 code used in RTTY (Radioteletype) communications.
///
/// Each character is represented by a 5-bit code. Two shift characters
/// (LETTERS and FIGURES) toggle between alphabetic and numeric/punctuation modes,
/// similar to Caps Lock.
public struct BaudotCode: Sendable {

    /// The current shift mode of the Baudot decoder.
    public enum Shift: Sendable, Equatable {
        case letters
        case figures
    }

    /// Code value that triggers switch to FIGURES shift.
    public static let FIGURES_SHIFT: UInt8 = 27

    /// Code value that triggers switch to LETTERS shift.
    public static let LETTERS_SHIFT: UInt8 = 31

    // MARK: - Character tables

    /// Letters shift table: 5-bit code (0-31) -> character.
    /// `nil` entries are non-printing or shift codes.
    public static let lettersTable: [Character?] = [
        nil,   "T", "\r", "O", " ", "H", "N", "M",     // 0-7
        "\n",  "L", "R",  "G", "I", "P", "C", "V",     // 8-15
        "E",   "Z", "D",  "B", "S", "Y", "F", "X",     // 16-23
        "A",   "W", "J",  nil, "U", "Q", "K", nil       // 24-31
    ]
    // Index 27 = FIGURES shift, Index 31 = LETTERS shift

    /// Figures shift table: 5-bit code (0-31) -> character.
    /// US ITA2 standard.
    public static let figuresTable: [Character?] = [
        nil,   "5", "\r", "9", " ", "#", ",", ".",      // 0-7
        "\n",  ")", "4",  "&", "8", "0", ":", ";",      // 8-15
        "3",   "\"", "$", "?", nil, "6", "!", "/",      // 16-23
        "-",   "2", "'",  nil, "7", "1", "(", nil        // 24-31
    ]
    // Index 20 = BELL in some variants (nil here), Index 27 = FIGURES, Index 31 = LETTERS

    // MARK: - Decoder

    /// Stateful Baudot decoder that tracks the current shift mode.
    public struct Decoder: Sendable {
        /// Current shift mode (letters or figures).
        public var currentShift: Shift = .letters

        public init(currentShift: Shift = .letters) {
            self.currentShift = currentShift
        }

        /// Decode a single 5-bit Baudot code.
        ///
        /// If the code is a shift character, the mode is changed and `nil` is returned.
        /// Otherwise, the character is looked up in the current shift table.
        ///
        /// - Parameter code: 5-bit Baudot code (0-31).
        /// - Returns: The decoded character, or `nil` for shift codes and non-printing characters.
        public mutating func decode(_ code: UInt8) -> Character? {
            guard code < 32 else { return nil }

            if code == BaudotCode.FIGURES_SHIFT {
                currentShift = .figures
                return nil
            }
            if code == BaudotCode.LETTERS_SHIFT {
                currentShift = .letters
                return nil
            }

            switch currentShift {
            case .letters:
                return lettersTable[Int(code)]
            case .figures:
                return figuresTable[Int(code)]
            }
        }
    }

    // MARK: - Reverse lookup tables (for encoding)

    /// Reverse letters table: character -> 5-bit code.
    private static let reverseLetters: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (i, ch) in lettersTable.enumerated() {
            if let ch = ch {
                table[ch] = UInt8(i)
            }
        }
        return table
    }()

    /// Reverse figures table: character -> 5-bit code.
    private static let reverseFigures: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (i, ch) in figuresTable.enumerated() {
            if let ch = ch {
                table[ch] = UInt8(i)
            }
        }
        return table
    }()

    // MARK: - Encode

    /// Encode text to an array of Baudot codes with shift indicators.
    ///
    /// Inserts shift codes (LETTERS/FIGURES) as needed when transitioning
    /// between alphabetic and numeric/punctuation characters.
    ///
    /// - Parameter text: The text to encode (uppercase letters, digits, punctuation).
    /// - Returns: Array of `(shift, code)` pairs. The shift indicates which mode
    ///   is active when the code is sent.
    public static func encode(_ text: String) -> [(shift: Shift, code: UInt8)] {
        var result: [(shift: Shift, code: UInt8)] = []
        var currentShift: Shift = .letters

        for char in text.uppercased() {
            let ch = Character(String(char))

            // Check if character is in current shift table
            if currentShift == .letters, let code = reverseLetters[ch] {
                result.append((shift: .letters, code: code))
            } else if currentShift == .figures, let code = reverseFigures[ch] {
                result.append((shift: .figures, code: code))
            } else if let code = reverseLetters[ch] {
                // Need to switch to letters
                result.append((shift: .letters, code: LETTERS_SHIFT))
                currentShift = .letters
                result.append((shift: .letters, code: code))
            } else if let code = reverseFigures[ch] {
                // Need to switch to figures
                result.append((shift: .figures, code: FIGURES_SHIFT))
                currentShift = .figures
                result.append((shift: .figures, code: code))
            }
            // Characters not in either table are silently dropped
        }

        return result
    }
}
