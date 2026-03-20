// FT8Tests.swift
// HamStationKit — Tests for FT8 protocol implementation.

import XCTest
import Foundation
@testable import HamStationKit

// MARK: - FT8Constants Tests

class FT8ConstantsTests: XCTestCase {

    func testSymbolPeriod() {
        XCTAssertEqual(FT8Constants.symbolPeriod, 0.160)
    }

    func testToneSpacing() {
        XCTAssertEqual(FT8Constants.toneSpacing, 6.25)
    }

    func testCycleDuration() {
        XCTAssertEqual(FT8Constants.cycleDuration, 15.0)
    }

    func testTxDuration() {
        XCTAssertEqual(FT8Constants.txDuration, 12.64)
        XCTAssertEqual(
            Double(FT8Constants.numSymbols) * FT8Constants.symbolPeriod,
            FT8Constants.txDuration,
            accuracy: 0.001
        )
    }

    func testToneCount() {
        XCTAssertEqual(FT8Constants.numTones, 8)
        XCTAssertEqual(FT8Constants.bitsPerSymbol, 3)
    }

    func testSymbolCounts() {
        XCTAssertEqual(FT8Constants.numSymbols, 79)
        XCTAssertEqual(FT8Constants.numDataSymbols, 58)
        XCTAssertEqual(FT8Constants.numCostasSymbols, 21)
        XCTAssertEqual(
            FT8Constants.numDataSymbols + FT8Constants.numCostasSymbols,
            FT8Constants.numSymbols
        )
    }

    func testLDPCDimensions() {
        XCTAssertEqual(FT8Constants.ldpcBits, 174)
        XCTAssertEqual(FT8Constants.ldpcDataBits, 91)
        XCTAssertEqual(
            FT8Constants.messageBits + FT8Constants.crcBits,
            FT8Constants.ldpcDataBits
        )
    }

    func testCostasPattern() {
        XCTAssertEqual(FT8Constants.costasPattern, [3, 1, 4, 0, 6, 5, 2])
    }

    func testDataSymbolPositionsExcludeCostas() {
        let positions = FT8Constants.dataSymbolPositions
        XCTAssertEqual(positions.count, FT8Constants.numDataSymbols)

        let costasSet = Set(FT8Constants.costasPositions.flatMap { start in start..<start + 7 })
        for pos in positions {
            XCTAssertFalse(costasSet.contains(pos), "Data position \(pos) should not be a Costas position")
        }
    }

    func testGrayCodeIsPermutation() {
        XCTAssertEqual(FT8Constants.grayCode.sorted(), [0, 1, 2, 3, 4, 5, 6, 7])
    }

    func testGrayCodeInverse() {
        for i in 0..<8 {
            let encoded = FT8Constants.grayCode[i]
            let decoded = FT8Constants.grayCodeInverse[encoded]
            XCTAssertEqual(decoded, i)
        }
    }

    func testSamplesPerSymbol() {
        XCTAssertEqual(FT8Constants.samplesPerSymbol, 1920)
        XCTAssertEqual(
            FT8Constants.samplesPerSymbol,
            Int(FT8Constants.sampleRate * FT8Constants.symbolPeriod)
        )
    }
}

// MARK: - FT8Message Parsing Tests

class FT8MessageParsingTests: XCTestCase {

    func testParseCQ() {
        let msg = FT8Message.parse(text: "CQ W1AW FN31", frequency: 1500, snr: -10, dt: 0.1)
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .cq)
        XCTAssertEqual(msg?.callsign1, "W1AW")
        XCTAssertEqual(msg?.grid, "FN31")
        XCTAssertEqual(msg?.frequency, 1500)
        XCTAssertEqual(msg?.snr, -10)
        XCTAssertEqual(msg?.timeOffset, 0.1)
    }

    func testParseCQNoGrid() {
        let msg = FT8Message.parse(text: "CQ W1AW")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .cq)
        XCTAssertEqual(msg?.callsign1, "W1AW")
        XCTAssertNil(msg?.grid)
    }

    func testParseCQDirected() {
        let msg = FT8Message.parse(text: "CQ DX W1AW FN31")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .cqDirected)
        XCTAssertEqual(msg?.callsign1, "W1AW")
        XCTAssertEqual(msg?.extra, "DX")
        XCTAssertEqual(msg?.grid, "FN31")
    }

    func testParseCQNA() {
        let msg = FT8Message.parse(text: "CQ NA W1AW FN31")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .cqDirected)
        XCTAssertEqual(msg?.extra, "NA")
    }

    func testParseReport() {
        let msg = FT8Message.parse(text: "JA1ABC W1AW -10")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .report)
        XCTAssertEqual(msg?.callsign1, "JA1ABC")
        XCTAssertEqual(msg?.callsign2, "W1AW")
        XCTAssertEqual(msg?.report, "-10")
    }

    func testParsePositiveReport() {
        let msg = FT8Message.parse(text: "JA1ABC W1AW +05")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .report)
        XCTAssertEqual(msg?.report, "+05")
    }

    func testParseRReport() {
        let msg = FT8Message.parse(text: "W1AW JA1ABC R-08")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .rrReport)
        XCTAssertEqual(msg?.callsign1, "W1AW")
        XCTAssertEqual(msg?.callsign2, "JA1ABC")
        XCTAssertEqual(msg?.report, "R-08")
    }

    func testParseRR73() {
        let msg = FT8Message.parse(text: "JA1ABC W1AW RR73")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .rr73)
        XCTAssertEqual(msg?.callsign1, "JA1ABC")
        XCTAssertEqual(msg?.callsign2, "W1AW")
        XCTAssertEqual(msg?.extra, "RR73")
    }

    func testParse73() {
        let msg = FT8Message.parse(text: "W1AW JA1ABC 73")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .seventy3)
        XCTAssertEqual(msg?.extra, "73")
    }

    func testParseReplyWithGrid() {
        let msg = FT8Message.parse(text: "W1AW JA1ABC PM95")
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.type, .reply)
        XCTAssertEqual(msg?.callsign1, "W1AW")
        XCTAssertEqual(msg?.callsign2, "JA1ABC")
        XCTAssertEqual(msg?.grid, "PM95")
    }

    func testDisplayTextCQ() {
        let msg = FT8Message.parse(text: "CQ W1AW FN31")
        XCTAssertEqual(msg?.displayText, "CQ W1AW FN31")
    }

    func testDisplayTextReport() {
        let msg = FT8Message.parse(text: "JA1ABC W1AW -10")
        XCTAssertEqual(msg?.displayText, "JA1ABC W1AW -10")
    }

    func testParseEmpty() {
        XCTAssertNil(FT8Message.parse(text: ""))
    }

    func testParseSingleWord() {
        XCTAssertNil(FT8Message.parse(text: "HELLO"))
    }

    func testParseBitsWrongCount() {
        let bits = [UInt8](repeating: 0, count: 50)
        XCTAssertNil(FT8Message.parse(bits: bits))
    }
}

// MARK: - FT8Encoder Tests

class FT8EncoderTests: XCTestCase {

    func testEncodeProducesCorrectAudioLength() {
        let encoder = FT8Encoder()
        let symbols = [Int](repeating: 0, count: 79)
        let audio = encoder.encodeSymbols(symbols, audioFrequency: 1500)

        XCTAssertNotNil(audio)
        let expectedSamples = FT8Constants.numSymbols * FT8Constants.samplesPerSymbol
        XCTAssertEqual(audio?.count, expectedSamples)
    }

    func testEncodeRejectsWrongSymbolCount() {
        let encoder = FT8Encoder()
        let symbols = [Int](repeating: 0, count: 50)
        XCTAssertNil(encoder.encodeSymbols(symbols, audioFrequency: 1500))
    }

    func testEncodeRejectsInvalidToneIndex() {
        let encoder = FT8Encoder()
        var symbols = [Int](repeating: 0, count: 79)
        symbols[0] = 9
        XCTAssertNil(encoder.encodeSymbols(symbols, audioFrequency: 1500))
    }

    func testEncodedAudioDuration() {
        let encoder = FT8Encoder()
        let symbols = [Int](repeating: 0, count: 79)
        let audio = encoder.encodeSymbols(symbols, audioFrequency: 1500)!
        let duration = Double(audio.count) / FT8Constants.sampleRate
        XCTAssertEqual(duration, FT8Constants.txDuration, accuracy: 0.001)
    }

    func testCRC14Consistency() {
        let bits1 = [UInt8](repeating: 0, count: 77)
        let crc1a = FT8Encoder.crc14(bits: bits1)
        let crc1b = FT8Encoder.crc14(bits: bits1)
        XCTAssertEqual(crc1a, crc1b)

        var bits2 = [UInt8](repeating: 0, count: 77)
        bits2[0] = 1
        let crc2 = FT8Encoder.crc14(bits: bits2)
        XCTAssertNotEqual(crc1a, crc2)
    }

    func testCRC14Is14Bits() {
        let bits = [UInt8](repeating: 1, count: 77)
        let crc = FT8Encoder.crc14(bits: bits)
        XCTAssertTrue(crc <= 0x3FFF)
    }

    func testEncodeMessageProducesAudio() {
        let encoder = FT8Encoder()
        let audio = encoder.encode(message: "HELLO WORLD", audioFrequency: 1000)
        XCTAssertNotNil(audio)
        if let audio {
            let expectedSamples = FT8Constants.numSymbols * FT8Constants.samplesPerSymbol
            XCTAssertEqual(audio.count, expectedSamples)
        }
    }

    func testAudioAmplitudeInRange() {
        let encoder = FT8Encoder()
        let symbols = (0..<79).map { _ in Int.random(in: 0..<8) }
        let audio = encoder.encodeSymbols(symbols, audioFrequency: 1500)!
        for sample in audio {
            XCTAssertGreaterThanOrEqual(sample, -1.01)
            XCTAssertLessThanOrEqual(sample, 1.01)
        }
    }
}

// MARK: - LDPCCodec Tests

class LDPCCodecTests: XCTestCase {

    func testParityCheckMatrixDimensions() {
        XCTAssertEqual(LDPCCodec.parityCheckMatrix.count, LDPCCodec.numChecks)
        for row in LDPCCodec.parityCheckMatrix {
            XCTAssertEqual(row.count, 7, "Each check should connect to 7 variable nodes")
            for col in row {
                XCTAssertTrue(col >= 0 && col < LDPCCodec.numBits)
            }
        }
    }

    func testEncodeLength() {
        let data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        let codeword = LDPCCodec.encode(data)
        XCTAssertEqual(codeword.count, LDPCCodec.numBits)
    }

    func testEncodeSystematic() {
        var data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        data[0] = 1
        data[5] = 1
        data[90] = 1
        let codeword = LDPCCodec.encode(data)
        for i in 0..<LDPCCodec.numDataBits {
            XCTAssertEqual(codeword[i], data[i], "Bit \(i) should match (systematic)")
        }
    }

    func testEncodeDecodeCycle() {
        var data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        for i in stride(from: 0, to: LDPCCodec.numDataBits, by: 3) {
            data[i] = 1
        }

        let codeword = LDPCCodec.encode(data)
        let decoded = LDPCCodec.decodeHard(codeword)

        XCTAssertNotNil(decoded)
        if let decoded {
            XCTAssertEqual(decoded.count, LDPCCodec.numDataBits)
            XCTAssertEqual(decoded, data)
        }
    }

    func testDecodeWith1BitError() {
        var data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        data[10] = 1
        data[20] = 1
        data[50] = 1

        var codeword = LDPCCodec.encode(data)
        codeword[100] ^= 1

        let decoded = LDPCCodec.decodeHard(codeword)
        XCTAssertNotNil(decoded)
        if let decoded {
            XCTAssertEqual(decoded, data)
        }
    }

    func testDecodeWith2BitErrors() {
        var data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        data[3] = 1
        data[15] = 1
        data[42] = 1

        var codeword = LDPCCodec.encode(data)
        codeword[50] ^= 1
        codeword[120] ^= 1

        let decoded = LDPCCodec.decodeHard(codeword)
        XCTAssertNotNil(decoded)
        if let decoded {
            XCTAssertEqual(decoded, data)
        }
    }

    func testDecodeTooManyErrors() {
        let data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        var codeword = LDPCCodec.encode(data)

        for i in stride(from: 0, to: 174, by: 2) {
            codeword[i] ^= 1
        }

        let decoded = LDPCCodec.decodeHard(codeword, maxIterations: 25)
        XCTAssertNil(decoded)
    }

    func testVerifyValidCodeword() {
        let data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        let codeword = LDPCCodec.encode(data)
        XCTAssertTrue(LDPCCodec.verify(codeword))
    }

    func testVerifyCorruptedCodeword() {
        let data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        var codeword = LDPCCodec.encode(data)
        codeword[0] ^= 1
        XCTAssertFalse(LDPCCodec.verify(codeword))
    }

    func testDecodeWrongLength() {
        let short = [UInt8](repeating: 0, count: 100)
        XCTAssertNil(LDPCCodec.decodeHard(short))
    }

    func testSoftDecodeCleanSignal() {
        var data = [UInt8](repeating: 0, count: LDPCCodec.numDataBits)
        data[0] = 1
        data[10] = 1
        data[45] = 1

        let codeword = LDPCCodec.encode(data)

        let llr = codeword.map { bit -> Float in
            bit == 0 ? 5.0 : -5.0
        }

        let decoded = LDPCCodec.decodeSoft(llr)
        XCTAssertNotNil(decoded)
        if let decoded {
            XCTAssertEqual(decoded, data)
        }
    }
}

// MARK: - FT8Decoder Tests

class FT8DecoderTests: XCTestCase {

    func testDecodeEmptyReturnsNoMessages() {
        let decoder = FT8Decoder()
        let messages = decoder.decode(samples: [])
        XCTAssertTrue(messages.isEmpty)
    }

    func testDecodeTooShortReturnsNoMessages() {
        let decoder = FT8Decoder()
        let samples = [Float](repeating: 0, count: 1000)
        let messages = decoder.decode(samples: samples)
        XCTAssertTrue(messages.isEmpty)
    }

    func testSpectrogramShape() {
        let decoder = FT8Decoder()
        let numSamples = Int(FT8Constants.sampleRate * FT8Constants.txDuration) + 1920
        let samples = [Float](repeating: 0, count: numSamples)

        let spectrogram = decoder.computeSpectrogram(samples: samples)
        XCTAssertFalse(spectrogram.isEmpty)
        let firstBins = spectrogram[0].count
        for slot in spectrogram {
            XCTAssertEqual(slot.count, firstBins)
        }
    }

    func testDecodeSyntheticToneFindsCandidate() {
        let decoder = FT8Decoder(minSignalStrength: -50)
        let sampleRate = FT8Constants.sampleRate
        let numSamples = Int(sampleRate * FT8Constants.txDuration) + 1920

        var samples = [Float](repeating: 0, count: numSamples)
        let baseFreq = 1500.0
        let samplesPerSymbol = Int(sampleRate * FT8Constants.symbolPeriod)

        var phase = 0.0
        for costasStart in FT8Constants.costasPositions {
            for j in 0..<7 {
                let toneIdx = FT8Constants.costasPattern[j]
                let freq = baseFreq + Double(toneIdx) * FT8Constants.toneSpacing
                let angularFreq = 2.0 * Double.pi * freq / sampleRate
                let offset = (costasStart + j) * samplesPerSymbol

                for k in 0..<samplesPerSymbol {
                    guard offset + k < numSamples else { break }
                    samples[offset + k] += Float(sin(phase))
                    phase += angularFreq
                }
            }
        }

        let spectrogram = decoder.computeSpectrogram(samples: samples)
        XCTAssertTrue(spectrogram.count > 0, "Spectrogram should have time slots")
    }

    func testSymbolExtraction() {
        let decoder = FT8Decoder()
        let numBins = 1024
        let numSlots = 200
        var spectrogram = [[Float]](
            repeating: [Float](repeating: -100, count: numBins),
            count: numSlots
        )

        let freqBin = 100
        let timeSlot = 0
        let slotsPerSymbol = 2

        for i in 0..<FT8Constants.numSymbols {
            let slot = timeSlot + i * slotsPerSymbol
            guard slot < numSlots else { break }
            let tone = i % FT8Constants.numTones
            spectrogram[slot][freqBin + tone] = 0
        }

        let symbols = decoder.extractSymbols(
            spectrogram: spectrogram,
            freqBin: freqBin,
            timeSlot: timeSlot
        )

        XCTAssertEqual(symbols.count, FT8Constants.numSymbols)
        for i in 0..<min(FT8Constants.numSymbols, numSlots / slotsPerSymbol) {
            XCTAssertEqual(symbols[i], i % FT8Constants.numTones)
        }
    }
}

// MARK: - AutoSequence Tests

class FT8AutoSequenceTests: XCTestCase {

    func testCQToReply() async {
        let engine = FT8Engine()

        await engine.startAutoSequence(
            targetCallsign: nil,
            myCallsign: "W1AW",
            myGrid: "FN31"
        )

        let seq = await engine.autoSequence
        XCTAssertEqual(seq?.state, .callingCQ)

        let reply = FT8Message(
            type: .reply,
            callsign1: "JA1ABC",
            callsign2: "W1AW",
            grid: "PM95",
            frequency: 1500,
            snr: -10,
            timeOffset: 0.0
        )

        let nextMessage = await engine.processAutoSequence(decoded: [reply])
        XCTAssertNotNil(nextMessage)
        XCTAssertTrue(nextMessage?.contains("JA1ABC") ?? false)
        XCTAssertTrue(nextMessage?.contains("W1AW") ?? false)

        let updatedSeq = await engine.autoSequence
        XCTAssertEqual(updatedSeq?.state, .sentReport)
        XCTAssertEqual(updatedSeq?.targetCallsign, "JA1ABC")
    }

    func testReportToRR73() async {
        let engine = FT8Engine()

        await engine.startAutoSequence(
            targetCallsign: nil,
            myCallsign: "W1AW",
            myGrid: "FN31"
        )

        let reply = FT8Message(
            type: .reply,
            callsign1: "JA1ABC",
            callsign2: "W1AW",
            grid: "PM95",
            frequency: 1500,
            snr: -10,
            timeOffset: 0.0
        )
        _ = await engine.processAutoSequence(decoded: [reply])

        let rReport = FT8Message(
            type: .rrReport,
            callsign1: "JA1ABC",
            callsign2: "W1AW",
            report: "R-08",
            frequency: 1500,
            snr: -8,
            timeOffset: 0.0
        )

        let nextMessage = await engine.processAutoSequence(decoded: [rReport])
        XCTAssertNotNil(nextMessage)
        XCTAssertTrue(nextMessage?.contains("RR73") ?? false)

        let seq = await engine.autoSequence
        XCTAssertEqual(seq?.state, .sentRR73)
    }

    func testCompleteStateReturnsNil() async {
        let engine = FT8Engine()

        await engine.startAutoSequence(
            targetCallsign: nil,
            myCallsign: "W1AW",
            myGrid: "FN31"
        )

        let reply = FT8Message(
            type: .reply, callsign1: "JA1ABC", callsign2: "W1AW",
            grid: "PM95", frequency: 1500, snr: -10, timeOffset: 0.0
        )
        _ = await engine.processAutoSequence(decoded: [reply])

        let rReport = FT8Message(
            type: .rrReport, callsign1: "JA1ABC", callsign2: "W1AW",
            report: "R-08", frequency: 1500, snr: -8, timeOffset: 0.0
        )
        _ = await engine.processAutoSequence(decoded: [rReport])

        // sentRR73 -> complete
        _ = await engine.processAutoSequence(decoded: [])

        let seq = await engine.autoSequence
        XCTAssertEqual(seq?.state, .complete)

        let nextMessage = await engine.processAutoSequence(decoded: [])
        XCTAssertNil(nextMessage)
    }

    func testCQNoReplyKeepsCalling() async {
        let engine = FT8Engine()

        await engine.startAutoSequence(
            targetCallsign: nil,
            myCallsign: "W1AW",
            myGrid: "FN31"
        )

        let nextMessage = await engine.processAutoSequence(decoded: [])
        XCTAssertNotNil(nextMessage)
        XCTAssertTrue(nextMessage?.hasPrefix("CQ") ?? false)
        XCTAssertTrue(nextMessage?.contains("W1AW") ?? false)
    }
}
