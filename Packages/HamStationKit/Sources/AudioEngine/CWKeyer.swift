// CWKeyer.swift
// HamStationKit — CW (Morse Code) keyer for transmitting.

import Foundation

// MARK: - Morse element

/// A single element in a Morse code sequence.
public enum MorseElement: Sendable, Equatable {
    case dit
    case dah
    case elementSpace    // between dits/dahs within a character
    case characterSpace  // between characters
    case wordSpace       // between words
}

// MARK: - Keyer mode

/// Keying mode for CW operation.
public enum KeyerMode: Sendable, Equatable {
    case iambicA
    case iambicB
    case straightKey
    case keyboard
}

// MARK: - Macro

/// A CW macro that expands variables and sends predefined text.
public struct CWMacro: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String       // e.g., "CQ"
    public var text: String       // e.g., "CQ CQ CQ DE {MYCALL} {MYCALL} K"
    public var functionKey: Int?  // F1-F12

    public init(id: UUID = UUID(), name: String, text: String, functionKey: Int? = nil) {
        self.id = id
        self.name = name
        self.text = text
        self.functionKey = functionKey
    }
}

/// Context for expanding macro variables.
public struct MacroContext: Sendable, Equatable {
    public var myCallsign: String
    public var theirCallsign: String?
    public var rst: String?
    public var serialNumber: Int?

    public init(
        myCallsign: String,
        theirCallsign: String? = nil,
        rst: String? = nil,
        serialNumber: Int? = nil
    ) {
        self.myCallsign = myCallsign
        self.theirCallsign = theirCallsign
        self.rst = rst
        self.serialNumber = serialNumber
    }
}

// MARK: - CWKeyer actor

/// CW keyer that encodes text to Morse, expands macros, and generates sidetone audio.
public actor CWKeyer {

    // MARK: - Configuration

    public var mode: KeyerMode = .iambicA
    public var speedWPM: Int = 20
    public var sidetonePitch: Double = 700     // Hz
    public var sidetoneVolume: Float = 0.5
    public var farnsworthWPM: Int?             // nil = same as speedWPM

    /// Macros (F-key memories).
    public var macros: [CWMacro] = []

    // MARK: - Timing

    /// Duration of one dit in milliseconds, derived from WPM.
    /// Standard PARIS timing: dit = 1200 / WPM ms.
    public var ditDurationMs: Double {
        1200.0 / Double(speedWPM)
    }

    /// Duration of one dah in milliseconds (3x dit).
    public var dahDurationMs: Double {
        ditDurationMs * 3.0
    }

    /// Element space duration in ms (1x dit).
    public var elementSpaceMs: Double {
        ditDurationMs
    }

    /// Character space duration in ms.
    /// If Farnsworth spacing is set and slower than character speed, use Farnsworth timing.
    public var characterSpaceMs: Double {
        if let fw = farnsworthWPM, fw < speedWPM {
            // Farnsworth: stretch inter-character space
            // Total word time at Farnsworth WPM, minus intra-character time at full speed.
            let totalWordMs = 60000.0 / Double(fw) // ms per word at Farnsworth rate
            let charElementsMs = 31.0 * ditDurationMs // PARIS = 31 dit units of elements
            let totalSpaceMs = totalWordMs - charElementsMs
            // Distribute: 4 char spaces + 1 word space in PARIS = 4*3 + 7 = 19 space units
            // Character space gets 3/19 of total spacing time
            return totalSpaceMs * 3.0 / 19.0
        }
        return ditDurationMs * 3.0
    }

    /// Word space duration in ms.
    public var wordSpaceMs: Double {
        if let fw = farnsworthWPM, fw < speedWPM {
            let totalWordMs = 60000.0 / Double(fw)
            let charElementsMs = 31.0 * ditDurationMs
            let totalSpaceMs = totalWordMs - charElementsMs
            return totalSpaceMs * 7.0 / 19.0
        }
        return ditDurationMs * 7.0
    }

    // MARK: - Morse table

    /// Standard ITU Morse code table. "." = dit, "-" = dah.
    public static let morseTable: [Character: String] = [
        // Letters
        "A": ".-",      "B": "-...",    "C": "-.-.",    "D": "-..",
        "E": ".",       "F": "..-.",    "G": "--.",     "H": "....",
        "I": "..",      "J": ".---",    "K": "-.-",     "L": ".-..",
        "M": "--",      "N": "-.",      "O": "---",     "P": ".--.",
        "Q": "--.-",    "R": ".-.",     "S": "...",     "T": "-",
        "U": "..-",     "V": "...-",    "W": ".--",     "X": "-..-",
        "Y": "-.--",    "Z": "--..",

        // Digits
        "0": "-----",   "1": ".----",   "2": "..---",   "3": "...--",
        "4": "....-",   "5": ".....",   "6": "-....",   "7": "--...",
        "8": "---..",   "9": "----.",

        // Punctuation
        ".": ".-.-.-",  ",": "--..--",  "?": "..--..",  "/": "-..-.",
        "=": "-...-",   "+": ".-.-.",   "-": "-....-",  "@": ".--.-.",
        "(": "-.--.",   ")": "-.--.-",  "'": ".----.",  "!": "-.-.--",
        ":": "---...",  ";": "-.-.-.",  "&": ".-...",   "\"": ".-..-.",
    ]

    /// Reverse table for decoding: Morse pattern -> Character.
    public static let reverseMorseTable: [String: Character] = {
        var table: [String: Character] = [:]
        for (char, code) in morseTable {
            table[code] = char
        }
        return table
    }()

    // MARK: - Encoding

    /// Encode a text string into a sequence of Morse elements.
    ///
    /// Letters are uppercased. Unknown characters are skipped.
    /// Spaces become word spaces. Element and character spaces are inserted automatically.
    public func encode(_ text: String) -> [MorseElement] {
        var elements: [MorseElement] = []
        let uppercased = text.uppercased()
        var isFirstChar = true

        for char in uppercased {
            if char == " " {
                // Remove trailing element/character space if present, add word space.
                while let last = elements.last,
                      last == .elementSpace || last == .characterSpace {
                    elements.removeLast()
                }
                if !elements.isEmpty {
                    elements.append(.wordSpace)
                }
                isFirstChar = true
                continue
            }

            guard let morse = Self.morseTable[char] else { continue }

            // Insert character space between characters (not before first).
            if !isFirstChar {
                // Remove trailing element space from previous character, replace with char space.
                if elements.last == .elementSpace {
                    elements.removeLast()
                }
                elements.append(.characterSpace)
            }
            isFirstChar = false

            // Encode each dit/dah with element spaces between.
            for (i, symbol) in morse.enumerated() {
                if i > 0 {
                    elements.append(.elementSpace)
                }
                switch symbol {
                case ".": elements.append(.dit)
                case "-": elements.append(.dah)
                default: break
                }
            }
        }

        // Clean trailing spaces
        while let last = elements.last,
              last == .elementSpace || last == .characterSpace || last == .wordSpace {
            elements.removeLast()
        }

        return elements
    }

    // MARK: - Macro expansion

    /// Expand macro variables in text.
    ///
    /// Supported variables:
    /// - `{MYCALL}` — operator's callsign
    /// - `{THEIRCALL}` — other station's callsign (or "?" if unknown)
    /// - `{RST}` — signal report (or default for mode)
    /// - `{NR}` — serial number (zero-padded to 3 digits)
    public func expandMacro(_ macro: CWMacro, context: MacroContext) -> String {
        var result = macro.text
        result = result.replacingOccurrences(of: "{MYCALL}", with: context.myCallsign)
        result = result.replacingOccurrences(
            of: "{THEIRCALL}", with: context.theirCallsign ?? "?")
        result = result.replacingOccurrences(of: "{RST}", with: context.rst ?? "599")
        if let nr = context.serialNumber {
            result = result.replacingOccurrences(
                of: "{NR}", with: String(format: "%03d", nr))
        }
        return result
    }

    // MARK: - Sidetone generation

    /// Generate PCM audio samples for a sequence of Morse elements.
    ///
    /// Produces a sine wave at `sidetonePitch` Hz during key-down (dit/dah),
    /// silence during spaces. Applies 5ms raised-cosine rise/fall to avoid clicks.
    ///
    /// - Parameters:
    ///   - elements: Morse element sequence from `encode(_:)`.
    ///   - sampleRate: Audio sample rate. Default 48000 Hz.
    /// - Returns: Array of Float PCM samples in [-1, 1].
    public func generateSidetone(elements: [MorseElement], sampleRate: Double = 48000) -> [Float] {
        var samples: [Float] = []
        let riseTimeSec = 0.005 // 5ms rise/fall
        let riseSamples = Int(riseTimeSec * sampleRate)

        for element in elements {
            let durationMs: Double
            let keyed: Bool

            switch element {
            case .dit:
                durationMs = ditDurationMs
                keyed = true
            case .dah:
                durationMs = dahDurationMs
                keyed = true
            case .elementSpace:
                durationMs = elementSpaceMs
                keyed = false
            case .characterSpace:
                durationMs = characterSpaceMs
                keyed = false
            case .wordSpace:
                durationMs = wordSpaceMs
                keyed = false
            }

            let durationSec = durationMs / 1000.0
            let sampleCount = Int(durationSec * sampleRate)

            if keyed {
                let phase0 = samples.isEmpty ? 0.0 : Double(samples.count)
                for i in 0..<sampleCount {
                    let t = Double(i)
                    let phase = 2.0 * Double.pi * sidetonePitch * (phase0 + t) / sampleRate
                    var sample = Float(sin(phase)) * sidetoneVolume

                    // Raised-cosine envelope for rise/fall
                    if i < riseSamples {
                        let envelope = Float(0.5 * (1.0 - cos(Double.pi * Double(i) / Double(riseSamples))))
                        sample *= envelope
                    } else if i >= sampleCount - riseSamples {
                        let remaining = sampleCount - 1 - i
                        let envelope = Float(0.5 * (1.0 - cos(Double.pi * Double(remaining) / Double(riseSamples))))
                        sample *= envelope
                    }

                    samples.append(sample)
                }
            } else {
                // Silence
                samples.append(contentsOf: [Float](repeating: 0.0, count: sampleCount))
            }
        }

        return samples
    }
}
