// NaturalLanguageLoggerTests.swift
// HamStationKit — Tests for natural language QSO parsing.

import XCTest
import Foundation
@testable import HamStationKit

class NaturalLanguageLoggerTests: XCTestCase {

    // MARK: - Full QSO Parsing

    func testParseFullQSODigital() {
        let result = NaturalLanguageLogger.parse(
            "Just worked W1AW on 20 meters FT8, he was minus 10 and I was minus 8"
        )
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertEqual(result.band, "20m")
        XCTAssertEqual(result.mode, "FT8")
        XCTAssertEqual(result.rstSent, "-08")
        XCTAssertEqual(result.rstReceived, "-10")
        XCTAssertTrue(result.confidence > 0.5)
    }

    func testParseFullQSOBothWays() {
        let result = NaturalLanguageLogger.parse(
            "Worked JA1ABC on 40 CW, 599 both ways"
        )
        XCTAssertEqual(result.callsign, "JA1ABC")
        XCTAssertEqual(result.band, "40m")
        XCTAssertEqual(result.mode, "CW")
        XCTAssertEqual(result.rstSent, "599")
        XCTAssertEqual(result.rstReceived, "599")
    }

    func testParseFullQSOSeparateRST() {
        let result = NaturalLanguageLogger.parse(
            "VK2RZA on fifteen meters SSB, 5-9 sent, 5-7 received"
        )
        XCTAssertEqual(result.callsign, "VK2RZA")
        XCTAssertEqual(result.band, "15m")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertEqual(result.rstSent, "59")
        XCTAssertEqual(result.rstReceived, "57")
    }

    func testParsePartialQSO() {
        let result = NaturalLanguageLogger.parse("W1AW on twenty FT8")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertEqual(result.band, "20m")
        XCTAssertEqual(result.mode, "FT8")
        XCTAssertNil(result.rstSent)
        XCTAssertNil(result.rstReceived)
    }

    func testParseCallsignOnly() {
        let result = NaturalLanguageLogger.parse("CQ de W1AW")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertTrue(result.confidence > 0)
        XCTAssertTrue(result.confidence <= 0.3)
    }

    // MARK: - Band Name Parsing

    func testParseBandTen() {
        let result = NaturalLanguageLogger.parse("W1AW on ten meters SSB")
        XCTAssertEqual(result.band, "10m")
    }

    func testParseBandTwelve() {
        let result = NaturalLanguageLogger.parse("W1AW on twelve meters SSB")
        XCTAssertEqual(result.band, "12m")
    }

    func testParseBandFifteen() {
        let result = NaturalLanguageLogger.parse("W1AW on fifteen meters SSB")
        XCTAssertEqual(result.band, "15m")
    }

    func testParseBandSeventeen() {
        let result = NaturalLanguageLogger.parse("W1AW on seventeen meters FT8")
        XCTAssertEqual(result.band, "17m")
    }

    func testParseBandTwenty() {
        let result = NaturalLanguageLogger.parse("W1AW on twenty meters CW")
        XCTAssertEqual(result.band, "20m")
    }

    func testParseBandThirty() {
        let result = NaturalLanguageLogger.parse("W1AW on thirty meters FT8")
        XCTAssertEqual(result.band, "30m")
    }

    func testParseBandForty() {
        let result = NaturalLanguageLogger.parse("W1AW on forty meters CW")
        XCTAssertEqual(result.band, "40m")
    }

    func testParseBandEighty() {
        let result = NaturalLanguageLogger.parse("W1AW on eighty meters CW")
        XCTAssertEqual(result.band, "80m")
    }

    func testParseBandOneSixty() {
        let result = NaturalLanguageLogger.parse("W1AW on one sixty meters CW")
        XCTAssertEqual(result.band, "160m")
    }

    func testParseBandNumeric() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m SSB")
        XCTAssertEqual(result.band, "20m")
    }

    func testParseBandNumericMeters() {
        let result = NaturalLanguageLogger.parse("W1AW on 40 meters CW")
        XCTAssertEqual(result.band, "40m")
    }

    // MARK: - Mode Parsing

    func testParseModePhone() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m phone")
        XCTAssertEqual(result.mode, "SSB")
    }

    func testParseModeDigital() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m digital")
        XCTAssertEqual(result.mode, "FT8")
    }

    func testParseModeCW() {
        let result = NaturalLanguageLogger.parse("W1AW on 40m CW")
        XCTAssertEqual(result.mode, "CW")
    }

    func testParseModeFT8() {
        let result = NaturalLanguageLogger.parse("W1AW on 30m FT8")
        XCTAssertEqual(result.mode, "FT8")
    }

    func testParseModeSSB() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m SSB")
        XCTAssertEqual(result.mode, "SSB")
    }

    // MARK: - RST Parsing

    func testParseRSTDash() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m SSB 5-9 sent 5-7 received")
        XCTAssertEqual(result.rstSent, "59")
        XCTAssertEqual(result.rstReceived, "57")
    }

    func testParseRSTPlain() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m SSB, 59 sent 57 received")
        XCTAssertEqual(result.rstSent, "59")
        XCTAssertEqual(result.rstReceived, "57")
    }

    func testParseRSTSpoken() {
        let result = NaturalLanguageLogger.parse("W1AW on 20m SSB five nine both ways")
        XCTAssertEqual(result.rstSent, "59")
        XCTAssertEqual(result.rstReceived, "59")
    }

    func testParseRSTDigitalMinus() {
        let result = NaturalLanguageLogger.parse(
            "W1AW on 20m FT8 he was minus 10 and I was minus 8"
        )
        XCTAssertEqual(result.rstReceived, "-10")
        XCTAssertEqual(result.rstSent, "-08")
    }

    func testParseRSTDigitalShorthand() {
        let result = NaturalLanguageLogger.parse(
            "W1AW on 20m FT8 he was -10 and I was -8"
        )
        XCTAssertEqual(result.rstReceived, "-10")
        XCTAssertEqual(result.rstSent, "-08")
    }

    func testParseRSTBothWays() {
        let result = NaturalLanguageLogger.parse("JA1ABC on 40 CW, 599 both ways")
        XCTAssertEqual(result.rstSent, result.rstReceived)
        XCTAssertEqual(result.rstSent, "599")
    }

    // MARK: - Edge Cases

    func testNoCallsignLowConfidence() {
        let result = NaturalLanguageLogger.parse("on 20 meters SSB five nine")
        XCTAssertNil(result.callsign)
        XCTAssertTrue(result.confidence <= 0.1)
    }

    func testEmptyInput() {
        let result = NaturalLanguageLogger.parse("")
        XCTAssertNil(result.callsign)
        XCTAssertNil(result.band)
        XCTAssertNil(result.mode)
        XCTAssertNil(result.rstSent)
        XCTAssertNil(result.rstReceived)
        XCTAssertEqual(result.confidence, 0)
    }

    func testWhitespaceInput() {
        let result = NaturalLanguageLogger.parse("   ")
        XCTAssertNil(result.callsign)
        XCTAssertEqual(result.confidence, 0)
    }

    func testRawInputPreserved() {
        let input = "Just worked W1AW on 20 meters FT8"
        let result = NaturalLanguageLogger.parse(input)
        XCTAssertEqual(result.rawInput, input)
    }

    func testParseEuropeanCallsign() {
        let result = NaturalLanguageLogger.parse("Worked DL1ABC on 20m SSB")
        XCTAssertEqual(result.callsign, "DL1ABC")
    }

    func testParseLongSuffixCallsign() {
        let result = NaturalLanguageLogger.parse("Worked K1TTT on 40m CW")
        XCTAssertEqual(result.callsign, "K1TTT")
    }
}
