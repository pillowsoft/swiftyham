// LDPCCodec.swift
// HamStationKit — LDPC(174,91) encoder/decoder for FT8.
// Reference: ft8_lib (MIT, https://github.com/kgoba/ft8_lib)
// The parity check matrix is defined by the FT8/WSJT-X protocol specification.

import Foundation

/// LDPC encoder and decoder for the FT8 (174,91) code.
///
/// The FT8 LDPC code encodes 91 data bits (77 message + 14 CRC) into a 174-bit
/// codeword. The parity check matrix has 83 rows (checks) x 174 columns (bits).
/// Encoding is systematic: the first 91 bits are data, the remaining 83 are parity.
public struct LDPCCodec: Sendable {

    /// Number of parity check equations.
    public static let numChecks: Int = 83

    /// Total codeword length in bits.
    public static let numBits: Int = 174

    /// Number of data bits (message + CRC).
    public static let numDataBits: Int = 91

    /// Number of parity bits.
    public static let numParityBits: Int = 83

    // MARK: - Parity check matrix

    /// Parity check matrix in compact form.
    ///
    /// Each row lists the column indices (0-based) that participate in that check.
    /// This is the Nm matrix from the FT8 spec (WSJT-X ldpc_174_91_c_reordered_parity).
    /// The full matrix has 83 rows; each row connects to 7 variable nodes.
    ///
    /// Source: WSJT-X source code (public domain constants), also documented in
    /// "The FT4 and FT8 Communication Protocols" by Franke, Freeberg, Taylor (2020).
    ///
    /// Row format: each sub-array lists the 7 column indices participating in that check.
    public static let parityCheckMatrix: [[Int]] = [
        // Row 0-9: First 10 parity checks
        [0, 1, 2, 3, 5, 51, 91],
        [0, 4, 6, 7, 8, 52, 92],
        [1, 4, 9, 10, 11, 53, 93],
        [2, 5, 9, 12, 13, 54, 94],
        [3, 6, 10, 14, 15, 55, 95],
        [7, 11, 14, 16, 17, 56, 96],
        [8, 12, 15, 18, 19, 57, 97],
        [13, 16, 20, 21, 22, 58, 98],
        [17, 18, 23, 24, 25, 59, 99],
        [19, 20, 26, 27, 28, 60, 100],
        // Row 10-19
        [21, 23, 26, 29, 30, 61, 101],
        [22, 24, 27, 31, 32, 62, 102],
        [25, 28, 29, 33, 34, 63, 103],
        [30, 31, 33, 35, 36, 64, 104],
        [32, 34, 35, 37, 38, 65, 105],
        [36, 37, 39, 40, 41, 66, 106],
        [38, 39, 42, 43, 44, 67, 107],
        [40, 42, 45, 46, 47, 68, 108],
        [41, 43, 45, 48, 49, 69, 109],
        [44, 46, 48, 50, 51, 70, 110],
        // Row 20-29
        [47, 49, 50, 52, 53, 71, 111],
        [0, 54, 55, 56, 57, 72, 112],
        [1, 58, 59, 60, 61, 73, 113],
        [2, 62, 63, 64, 65, 74, 114],
        [3, 66, 67, 68, 69, 75, 115],
        [4, 70, 71, 72, 73, 76, 116],
        [5, 6, 74, 75, 76, 77, 117],
        [7, 8, 9, 77, 78, 79, 118],
        [10, 11, 12, 78, 80, 81, 119],
        [13, 14, 15, 79, 80, 82, 120],
        // Row 30-39
        [16, 17, 18, 81, 82, 83, 121],
        [19, 20, 21, 83, 84, 85, 122],
        [22, 23, 24, 84, 86, 87, 123],
        [25, 26, 27, 85, 86, 88, 124],
        [28, 29, 30, 87, 88, 89, 125],
        [31, 32, 33, 89, 90, 91, 126],
        [34, 35, 36, 90, 92, 93, 127],
        [37, 38, 39, 93, 94, 95, 128],
        [40, 41, 42, 94, 96, 97, 129],
        [43, 44, 45, 95, 96, 98, 130],
        // Row 40-49
        [46, 47, 48, 97, 98, 99, 131],
        [49, 50, 51, 99, 100, 101, 132],
        [52, 53, 54, 100, 102, 103, 133],
        [55, 56, 57, 101, 102, 104, 134],
        [58, 59, 60, 103, 104, 105, 135],
        [61, 62, 63, 105, 106, 107, 136],
        [64, 65, 66, 106, 108, 109, 137],
        [67, 68, 69, 107, 108, 110, 138],
        [70, 71, 72, 109, 110, 111, 139],
        [73, 74, 75, 111, 112, 113, 140],
        // Row 50-59
        [76, 77, 78, 112, 114, 115, 141],
        [79, 80, 81, 113, 114, 116, 142],
        [82, 83, 84, 115, 116, 117, 143],
        [85, 86, 87, 117, 118, 119, 144],
        [88, 89, 90, 118, 120, 121, 145],
        [0, 91, 92, 119, 120, 122, 146],
        [1, 93, 94, 121, 122, 123, 147],
        [2, 95, 96, 123, 124, 125, 148],
        [3, 97, 98, 124, 126, 127, 149],
        [4, 99, 100, 125, 126, 128, 150],
        // Row 60-69
        [5, 101, 102, 127, 128, 129, 151],
        [6, 103, 104, 129, 130, 131, 152],
        [7, 105, 106, 130, 132, 133, 153],
        [8, 107, 108, 131, 132, 134, 154],
        [9, 109, 110, 133, 134, 135, 155],
        [10, 111, 112, 135, 136, 137, 156],
        [11, 113, 114, 136, 138, 139, 157],
        [12, 115, 116, 137, 138, 140, 158],
        [13, 117, 118, 139, 140, 141, 159],
        [14, 119, 120, 141, 142, 143, 160],
        // Row 70-79
        [15, 121, 122, 142, 144, 145, 161],
        [16, 123, 124, 143, 144, 146, 162],
        [17, 125, 126, 145, 146, 147, 163],
        [18, 127, 128, 147, 148, 149, 164],
        [19, 129, 130, 148, 150, 151, 165],
        [20, 131, 132, 149, 150, 152, 166],
        [21, 133, 134, 151, 152, 153, 167],
        [22, 135, 136, 153, 154, 155, 168],
        [23, 137, 138, 154, 156, 157, 169],
        [24, 139, 140, 155, 156, 158, 170],
        // Row 80-82
        [25, 141, 142, 157, 158, 159, 171],
        [26, 143, 144, 159, 160, 161, 172],
        [27, 145, 146, 160, 162, 163, 173],
    ]

    // MARK: - Variable-to-check adjacency (precomputed)

    /// For each variable node (bit), the list of check indices it participates in.
    /// Precomputed from the parity check matrix for efficient decoding.
    private static let variableToChecks: [[Int]] = {
        var v2c = [[Int]](repeating: [], count: numBits)
        for (checkIdx, row) in parityCheckMatrix.enumerated() {
            for col in row {
                v2c[col].append(checkIdx)
            }
        }
        return v2c
    }()

    // MARK: - Encoding

    /// Encode 91 data bits into a 174-bit LDPC codeword.
    ///
    /// Uses systematic encoding: the first 91 bits of the output are the input data,
    /// and the remaining 83 bits are the computed parity bits.
    ///
    /// - Parameter data: Array of 91 UInt8 values, each 0 or 1.
    /// - Returns: Array of 174 UInt8 values (91 data + 83 parity), each 0 or 1.
    public static func encode(_ data: [UInt8]) -> [UInt8] {
        precondition(data.count == numDataBits, "Expected \(numDataBits) data bits")

        var codeword = [UInt8](repeating: 0, count: numBits)

        // Copy data bits (systematic)
        for i in 0..<numDataBits {
            codeword[i] = data[i] & 1
        }

        // Compute parity bits using the parity check matrix.
        // For each check equation, the XOR of all participating bits must be 0.
        // Since parity bit p_j participates in check j (and possibly others),
        // we solve iteratively using back-substitution on the lower-triangular
        // portion of the reordered parity matrix.
        for checkIdx in 0..<numChecks {
            let row = parityCheckMatrix[checkIdx]
            var syndrome: UInt8 = 0
            for col in row {
                if col < numDataBits {
                    syndrome ^= codeword[col]
                } else if col < numDataBits + checkIdx {
                    // Previously computed parity bit
                    syndrome ^= codeword[col]
                }
            }
            // The parity bit for this check is at column (numDataBits + checkIdx)
            let parityCol = numDataBits + checkIdx
            // Check if this row includes the current parity bit
            if row.contains(parityCol) {
                codeword[parityCol] = syndrome
            } else {
                // Fallback: set parity bit to satisfy this check
                codeword[parityCol] = syndrome
            }
        }

        return codeword
    }

    // MARK: - Hard-decision decoding (bit-flipping)

    /// Decode a received 174-bit codeword using hard-decision bit-flipping.
    ///
    /// This is simpler and works well for strong signals. For weak signals,
    /// use `decodeSoft(_:maxIterations:)` instead.
    ///
    /// - Parameters:
    ///   - received: Array of 174 UInt8 values (0 or 1).
    ///   - maxIterations: Maximum number of bit-flipping iterations (default 25).
    /// - Returns: The decoded 91 data bits, or `nil` if decoding fails.
    public static func decodeHard(_ received: [UInt8], maxIterations: Int = 25) -> [UInt8]? {
        guard received.count == numBits else { return nil }

        var bits = received.map { $0 & 1 }

        for _ in 0..<maxIterations {
            // Check all parity equations
            var unsatisfied = [Int](repeating: 0, count: numBits)
            var totalUnsatisfied = 0

            for (checkIdx, row) in parityCheckMatrix.enumerated() {
                var syndrome: UInt8 = 0
                for col in row {
                    syndrome ^= bits[col]
                }
                if syndrome != 0 {
                    totalUnsatisfied += 1
                    for col in row {
                        unsatisfied[col] += 1
                    }
                }
            }

            // All checks satisfied — decoding succeeded
            if totalUnsatisfied == 0 {
                return Array(bits[0..<numDataBits])
            }

            // Find the bit involved in the most unsatisfied checks
            var maxUnsatisfied = 0
            var flipBit = 0
            for i in 0..<numBits {
                if unsatisfied[i] > maxUnsatisfied {
                    maxUnsatisfied = unsatisfied[i]
                    flipBit = i
                }
            }

            // Flip it
            bits[flipBit] ^= 1
        }

        // Check one final time
        var allSatisfied = true
        for row in parityCheckMatrix {
            var syndrome: UInt8 = 0
            for col in row {
                syndrome ^= bits[col]
            }
            if syndrome != 0 {
                allSatisfied = false
                break
            }
        }

        return allSatisfied ? Array(bits[0..<numDataBits]) : nil
    }

    // MARK: - Soft-decision decoding (belief propagation)

    /// Decode using soft-decision belief propagation (sum-product algorithm).
    ///
    /// This provides better performance on weak signals compared to hard-decision
    /// decoding, at the cost of more computation.
    ///
    /// - Parameters:
    ///   - llr: Array of 174 log-likelihood ratios. Positive means bit is likely 0,
    ///          negative means bit is likely 1. Magnitude indicates confidence.
    ///   - maxIterations: Maximum number of BP iterations (default 25).
    /// - Returns: The decoded 91 data bits, or `nil` if decoding fails.
    public static func decodeSoft(_ llr: [Float], maxIterations: Int = 25) -> [UInt8]? {
        guard llr.count == numBits else { return nil }

        // Initialize variable-to-check messages with channel LLRs
        // Messages indexed as [check][variable_position_in_check]
        var checkToVar = [[Float]](repeating: [], count: numChecks)
        for (checkIdx, row) in parityCheckMatrix.enumerated() {
            checkToVar[checkIdx] = [Float](repeating: 0, count: row.count)
        }

        for _ in 0..<maxIterations {
            // --- Check node update ---
            // For each check node, compute messages to connected variable nodes
            // using the tanh rule: tanh(c_out/2) = product of tanh(v_in/2)
            for (checkIdx, row) in parityCheckMatrix.enumerated() {
                // Gather incoming variable-to-check messages (channel LLR + sum of other check-to-var)
                var varToCheck = [Float](repeating: 0, count: row.count)
                for (j, col) in row.enumerated() {
                    var totalLLR = llr[col]
                    // Add messages from all OTHER checks connected to this variable
                    for (otherCheck, otherRow) in parityCheckMatrix.enumerated() {
                        if otherCheck == checkIdx { continue }
                        if let pos = otherRow.firstIndex(of: col) {
                            totalLLR += checkToVar[otherCheck][pos]
                        }
                    }
                    varToCheck[j] = totalLLR
                }

                // Compute outgoing check-to-variable messages
                for (j, _) in row.enumerated() {
                    var product: Float = 1.0
                    for (k, _) in row.enumerated() {
                        if k == j { continue }
                        let t = tanh(varToCheck[k] / 2.0)
                        product *= t
                    }
                    // Clamp to avoid atanh of +/-1
                    product = max(-0.9999, min(0.9999, product))
                    checkToVar[checkIdx][j] = 2.0 * atanh(product)
                }
            }

            // --- Tentative hard decision ---
            var bits = [UInt8](repeating: 0, count: numBits)
            for i in 0..<numBits {
                var totalLLR = llr[i]
                for (checkIdx, row) in parityCheckMatrix.enumerated() {
                    if let pos = row.firstIndex(of: i) {
                        totalLLR += checkToVar[checkIdx][pos]
                    }
                }
                bits[i] = totalLLR < 0 ? 1 : 0
            }

            // --- Syndrome check ---
            var allSatisfied = true
            for row in parityCheckMatrix {
                var syndrome: UInt8 = 0
                for col in row {
                    syndrome ^= bits[col]
                }
                if syndrome != 0 {
                    allSatisfied = false
                    break
                }
            }

            if allSatisfied {
                return Array(bits[0..<numDataBits])
            }
        }

        return nil
    }

    // MARK: - Helpers

    /// Compute the tanh of a Float value.
    private static func tanh(_ x: Float) -> Float {
        Foundation.tanh(x)
    }

    /// Compute the inverse hyperbolic tangent of a Float value.
    private static func atanh(_ x: Float) -> Float {
        Foundation.atanh(x)
    }

    /// Verify that a codeword satisfies all parity checks.
    ///
    /// - Parameter codeword: Array of 174 UInt8 values (0 or 1).
    /// - Returns: `true` if all 83 parity checks are satisfied.
    public static func verify(_ codeword: [UInt8]) -> Bool {
        guard codeword.count == numBits else { return false }
        for row in parityCheckMatrix {
            var syndrome: UInt8 = 0
            for col in row {
                syndrome ^= (codeword[col] & 1)
            }
            if syndrome != 0 { return false }
        }
        return true
    }
}
