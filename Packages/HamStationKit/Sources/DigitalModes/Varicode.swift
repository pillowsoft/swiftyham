// Varicode.swift
// HamStationKit — PSK31 Varicode encoding table.
// Maps ASCII characters to variable-length bit sequences.
// Each character separated by "00" (two zero bits) in the bitstream.
// Most common characters have the shortest codes (Huffman-like).

import Foundation

/// Standard PSK31 Varicode encoding and decoding.
///
/// Each ASCII character (0-127) maps to a variable-length bit pattern.
/// In the transmitted bitstream, characters are separated by two consecutive
/// zero bits ("00"). No valid character code contains "00" internally.
public struct Varicode: Sendable {

    // MARK: - Encoding table

    /// Encoding table indexed by ASCII value 0-127.
    /// Each entry is `(bits, length)` where `bits` holds the pattern MSB-first
    /// in the upper bits of a UInt16, and `length` is the number of valid bits.
    public static let encodeTable: [(bits: UInt16, length: Int)] = [
        // 0x00 NUL
        (0b1010101101, 10),
        // 0x01 SOH
        (0b1011011011, 10),
        // 0x02 STX
        (0b1011101101, 10),
        // 0x03 ETX
        (0b1101110111, 10),
        // 0x04 EOT
        (0b1011101011, 10),
        // 0x05 ENQ
        (0b1101011111, 10),
        // 0x06 ACK
        (0b1011101111, 10),
        // 0x07 BEL
        (0b1011111101, 10),
        // 0x08 BS
        (0b10111111, 8),
        // 0x09 HT
        (0b11101111, 8),
        // 0x0A LF
        (0b11101, 5),
        // 0x0B VT
        (0b1101101111, 10),
        // 0x0C FF
        (0b1011011101, 10),
        // 0x0D CR
        (0b11111, 5),
        // 0x0E SO
        (0b1101110101, 10),
        // 0x0F SI
        (0b1110101011, 10),
        // 0x10 DLE
        (0b1011110111, 10),
        // 0x11 DC1
        (0b1011110101, 10),
        // 0x12 DC2
        (0b1110101101, 10),
        // 0x13 DC3
        (0b1110101111, 10),
        // 0x14 DC4
        (0b1101011011, 10),
        // 0x15 NAK
        (0b1101101011, 10),
        // 0x16 SYN
        (0b1101101101, 10),
        // 0x17 ETB
        (0b1101010111, 10),
        // 0x18 CAN
        (0b1101111011, 10),
        // 0x19 EM
        (0b1101111101, 10),
        // 0x1A SUB
        (0b1110110111, 10),
        // 0x1B ESC
        (0b1101010101, 10),
        // 0x1C FS
        (0b1101011101, 10),
        // 0x1D GS
        (0b1110111011, 10),
        // 0x1E RS
        (0b1011111011, 10),
        // 0x1F US
        (0b1101111111, 10),
        // 0x20 SP (space)
        (0b1, 1),
        // 0x21 !
        (0b111111111, 9),
        // 0x22 "
        (0b101011111, 9),
        // 0x23 #
        (0b111110101, 9),
        // 0x24 $
        (0b111011011, 9),
        // 0x25 %
        (0b1011010101, 10),
        // 0x26 &
        (0b1010111011, 10),
        // 0x27 '
        (0b101111111, 9),
        // 0x28 (
        (0b11111011, 8),
        // 0x29 )
        (0b11110111, 8),
        // 0x2A *
        (0b101101111, 9),
        // 0x2B +
        (0b111011111, 9),
        // 0x2C ,
        (0b1110101, 7),
        // 0x2D -
        (0b110101, 6),
        // 0x2E .
        (0b1010111, 7),
        // 0x2F /
        (0b110101111, 9),
        // 0x30 0
        (0b10110111, 8),
        // 0x31 1
        (0b10111101, 8),
        // 0x32 2
        (0b11101101, 8),
        // 0x33 3
        (0b11111111, 8),
        // 0x34 4
        (0b101110111, 9),
        // 0x35 5
        (0b101011011, 9),
        // 0x36 6
        (0b101101011, 9),
        // 0x37 7
        (0b110101101, 9),
        // 0x38 8
        (0b110101011, 9),
        // 0x39 9
        (0b110110111, 9),
        // 0x3A :
        (0b11110101, 8),
        // 0x3B ;
        (0b110111101, 9),
        // 0x3C <
        (0b111101101, 9),
        // 0x3D =
        (0b1010101, 7),
        // 0x3E >
        (0b111010111, 9),
        // 0x3F ?
        (0b1010101111, 10),
        // 0x40 @
        (0b1010111101, 10),
        // 0x41 A
        (0b1011, 4),
        // 0x42 B
        (0b1011111, 7),
        // 0x43 C
        (0b101111, 6),
        // 0x44 D
        (0b101101, 6),
        // 0x45 E
        (0b11, 2),
        // 0x46 F
        (0b111101, 6),
        // 0x47 G
        (0b1011011, 7),
        // 0x48 H
        (0b101011, 6),
        // 0x49 I
        (0b1101, 4),
        // 0x4A J
        (0b111101011, 9),
        // 0x4B K
        (0b10111111, 8),
        // 0x4C L
        (0b11011, 5),
        // 0x4D M
        (0b111011, 6),
        // 0x4E N
        (0b1111, 4),
        // 0x4F O
        (0b111, 3),
        // 0x50 P
        (0b111111, 6),
        // 0x51 Q
        (0b110111111, 9),
        // 0x52 R
        (0b10101, 5),
        // 0x53 S
        (0b10111, 5),
        // 0x54 T
        (0b101, 3),
        // 0x55 U
        (0b110111, 6),
        // 0x56 V
        (0b1111011, 7),
        // 0x57 W
        (0b1101011, 7),
        // 0x58 X
        (0b11011111, 8),
        // 0x59 Y
        (0b1011101, 7),
        // 0x5A Z
        (0b111010101, 9),
        // 0x5B [
        (0b111110111, 9),
        // 0x5C backslash
        (0b111101111, 9),
        // 0x5D ]
        (0b111111011, 9),
        // 0x5E ^
        (0b1010111111, 10),
        // 0x5F _
        (0b101101101, 9),
        // 0x60 `
        (0b1011011111, 10),
        // 0x61 a
        (0b1011, 4),
        // 0x62 b
        (0b1011111, 7),
        // 0x63 c
        (0b101111, 6),
        // 0x64 d
        (0b101101, 6),
        // 0x65 e
        (0b11, 2),
        // 0x66 f
        (0b111101, 6),
        // 0x67 g
        (0b1011011, 7),
        // 0x68 h
        (0b101011, 6),
        // 0x69 i
        (0b1101, 4),
        // 0x6A j
        (0b111101011, 9),
        // 0x6B k
        (0b10111111, 8),
        // 0x6C l
        (0b11011, 5),
        // 0x6D m
        (0b111011, 6),
        // 0x6E n
        (0b1111, 4),
        // 0x6F o
        (0b111, 3),
        // 0x70 p
        (0b111111, 6),
        // 0x71 q
        (0b110111111, 9),
        // 0x72 r
        (0b10101, 5),
        // 0x73 s
        (0b10111, 5),
        // 0x74 t
        (0b101, 3),
        // 0x75 u
        (0b110111, 6),
        // 0x76 v
        (0b1111011, 7),
        // 0x77 w
        (0b1101011, 7),
        // 0x78 x
        (0b11011111, 8),
        // 0x79 y
        (0b1011101, 7),
        // 0x7A z
        (0b111010101, 9),
        // 0x7B {
        (0b1010110111, 10),
        // 0x7C |
        (0b110111011, 9),
        // 0x7D }
        (0b1010110101, 10),
        // 0x7E ~
        (0b1011010111, 10),
        // 0x7F DEL
        (0b1110110101, 10),
    ]

    // MARK: - Decode table

    /// Reverse lookup: bit pattern (as UInt16) -> ASCII character.
    /// Built from `encodeTable` at initialization.
    public static let decodeTable: [UInt16: Character] = {
        var table: [UInt16: Character] = [:]
        for ascii in 0..<128 {
            let entry = encodeTable[ascii]
            // For lowercase letters (0x61-0x7A), the codes duplicate uppercase.
            // We prefer lowercase for 'a'-'z' to match standard PSK31 convention,
            // but since both map to the same code, decoding is ambiguous.
            // Standard PSK31 decodes as lowercase by default.
            if let scalar = Unicode.Scalar(ascii) {
                table[entry.bits] = Character(scalar)
            }
        }
        // Overwrite uppercase with lowercase for the shared codes (standard convention)
        for ascii in 0x61...0x7A {
            let entry = encodeTable[ascii]
            if let scalar = Unicode.Scalar(ascii) {
                table[entry.bits] = Character(scalar)
            }
        }
        return table
    }()

    // MARK: - Encode

    /// Encode a text string into a PSK31 bit array.
    ///
    /// Each character is encoded to its Varicode pattern, followed by "00" separator.
    /// Returns an array of UInt8 where each element is 0 or 1.
    ///
    /// - Parameter text: The text to encode (ASCII characters only).
    /// - Returns: Bit array (each element is 0 or 1).
    public static func encode(_ text: String) -> [UInt8] {
        var bits: [UInt8] = []
        for char in text {
            guard let ascii = char.asciiValue, ascii < 128 else { continue }
            let entry = encodeTable[Int(ascii)]
            // Output bits MSB first
            for i in stride(from: entry.length - 1, through: 0, by: -1) {
                bits.append(UInt8((entry.bits >> i) & 1))
            }
            // Character separator: two zero bits
            bits.append(0)
            bits.append(0)
        }
        return bits
    }

    // MARK: - Decode

    /// Decode a PSK31 bit array back to text.
    ///
    /// Looks for "00" separators between characters. Accumulates bits
    /// until a separator is found, then looks up the pattern in the decode table.
    /// Varicode codes never contain two consecutive zeros, so "00" always
    /// marks a character boundary.
    ///
    /// - Parameter bits: Bit array (each element is 0 or 1).
    /// - Returns: Decoded text string.
    public static func decode(_ bits: [UInt8]) -> String {
        var result = ""
        var accumulator: UInt16 = 0
        var bitCount = 0
        var lastBitWasZero = false

        for bit in bits {
            if bit == 0 {
                if lastBitWasZero {
                    // Two consecutive zeros — character separator
                    if bitCount > 0 {
                        if let ch = decodeTable[accumulator] {
                            result.append(ch)
                        }
                        accumulator = 0
                        bitCount = 0
                    }
                    lastBitWasZero = false
                } else {
                    lastBitWasZero = true
                }
            } else {
                // A '1' bit
                if lastBitWasZero {
                    // The previous zero was part of the code (single zero between 1s)
                    accumulator = (accumulator << 1) | 0
                    bitCount += 1
                    lastBitWasZero = false
                }
                accumulator = (accumulator << 1) | 1
                bitCount += 1
            }
        }

        return result
    }
}
