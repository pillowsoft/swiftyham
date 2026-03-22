// PropagationTests.swift
// HamStationKit — Tests for PSK Reporter parsing, NOAA X-ray classification, and NL logger fixes.

import XCTest
import Foundation
@testable import HamStationKit

// MARK: - PSK Reporter XML Parsing Tests

class PSKReporterParsingTests: XCTestCase {

    func testParseValidXML() {
        let xml = """
        <?xml version="1.0"?>
        <receptionReports>
            <receptionReport senderCallsign="W1AW" receiverCallsign="JA1ABC"
                frequency="14074000" sNR="-10" mode="FT8"
                senderLocator="FN31" receiverLocator="PM95"
                flowStartSeconds="1711324800"/>
            <receptionReport senderCallsign="DL1ABC" receiverCallsign="JA1ABC"
                frequency="7074000" sNR="5" mode="FT8"
                senderLocator="JO31" flowStartSeconds="1711324860"/>
        </receptionReports>
        """
        let data = Data(xml.utf8)
        let parser = PSKReporterXMLParser(data: data)
        let reports = parser.parse()

        XCTAssertEqual(reports.count, 2)

        let first = reports[0]
        XCTAssertEqual(first.senderCallsign, "W1AW")
        XCTAssertEqual(first.receiverCallsign, "JA1ABC")
        XCTAssertEqual(first.frequency, 14_074_000)
        XCTAssertEqual(first.snr, -10)
        XCTAssertEqual(first.mode, "FT8")
        XCTAssertEqual(first.senderGrid, "FN31")
        XCTAssertEqual(first.receiverGrid, "PM95")

        let second = reports[1]
        XCTAssertEqual(second.senderCallsign, "DL1ABC")
        XCTAssertEqual(second.frequency, 7_074_000)
        XCTAssertEqual(second.snr, 5)
        XCTAssertNil(second.receiverGrid)
    }

    func testParseEmptyXML() {
        let xml = "<?xml version=\"1.0\"?><receptionReports></receptionReports>"
        let data = Data(xml.utf8)
        let parser = PSKReporterXMLParser(data: data)
        let reports = parser.parse()
        XCTAssertEqual(reports.count, 0)
    }

    func testParseMalformedXML() {
        let data = Data("not xml at all".utf8)
        let parser = PSKReporterXMLParser(data: data)
        let reports = parser.parse()
        XCTAssertEqual(reports.count, 0)
    }

    func testPSKReportBandDerivation() {
        let report = PSKReport(
            senderCallsign: "W1AW",
            receiverCallsign: "JA1ABC",
            frequency: 14_074_000,
            mode: "FT8"
        )
        XCTAssertEqual(report.band, "20m")

        let report40 = PSKReport(
            senderCallsign: "W1AW",
            receiverCallsign: "JA1ABC",
            frequency: 7_074_000,
            mode: "FT8"
        )
        XCTAssertEqual(report40.band, "40m")

        let reportUnknown = PSKReport(
            senderCallsign: "W1AW",
            receiverCallsign: "JA1ABC",
            frequency: 999_000,
            mode: "FT8"
        )
        XCTAssertEqual(reportUnknown.band, "?")
    }
}

// MARK: - NL Logger Band Disambiguation Tests

class NLLoggerBandDisambiguationTests: XCTestCase {

    func testBandNotConfusedWithRST() {
        let result = NaturalLanguageLogger.parse(
            "Worked JA1ABC on 40 CW, 599 both ways"
        )
        XCTAssertEqual(result.band, "40m", "40 after 'on' should be parsed as band, not RST")
        XCTAssertEqual(result.rstSent, "599")
        XCTAssertEqual(result.rstReceived, "599")
    }

    func testBandOn20() {
        let result = NaturalLanguageLogger.parse(
            "W1AW on 20 SSB gave me 59"
        )
        XCTAssertEqual(result.band, "20m")
        XCTAssertEqual(result.mode, "SSB")
    }

    func testBandWithMSuffix() {
        let result = NaturalLanguageLogger.parse(
            "W1AW on 40m CW 599"
        )
        XCTAssertEqual(result.band, "40m")
    }

    func testBandWithMetersSuffix() {
        let result = NaturalLanguageLogger.parse(
            "W1AW on fifteen meters SSB"
        )
        XCTAssertEqual(result.band, "15m")
    }
}

// MARK: - NOAA X-ray Classification Tests

class NOAAClassificationTests: XCTestCase {

    func testSolarDataBandConditionsSummary() {
        let data = SolarData(solarFluxIndex: 120, aIndex: 10, kIndex: 2)
        XCTAssertTrue(data.bandConditionsSummary.contains("SFI"))
        XCTAssertTrue(data.bandConditionsSummary.contains("K="))
    }

    func testSolarDataSeverity() {
        XCTAssertEqual(SolarData(kIndex: 1).kIndexSeverity, .quiet)
        XCTAssertEqual(SolarData(kIndex: 4).kIndexSeverity, .unsettled)
        XCTAssertEqual(SolarData(kIndex: 5).kIndexSeverity, .storm)
        XCTAssertEqual(SolarData(kIndex: 7).kIndexSeverity, .severeStorm)
    }
}

// MARK: - FT8 Binary Decode Types 2, 3, 5

class FT8ContestDecodeTests: XCTestCase {

    func testDecodeType2ReturnsMessage() {
        // Type 2: i3 = 010
        var bits = [UInt8](repeating: 0, count: 77)
        // Set CQ token for call1 (packed value 2 in 28 bits)
        bits[26] = 1 // bit 26 = 1 -> value = 2 (CQ)
        bits[74] = 0; bits[75] = 1; bits[76] = 0 // i3 = 2

        // Should attempt to decode (may return nil for all-zero callsigns, but shouldn't crash)
        _ = FT8Message.parse(bits: bits)
    }

    func testDecodeType3ReturnsMessage() {
        // Type 3: i3 = 011
        var bits = [UInt8](repeating: 0, count: 77)
        bits[74] = 0; bits[75] = 1; bits[76] = 1 // i3 = 3
        _ = FT8Message.parse(bits: bits)
    }

    func testDecodeType5ReturnsMessage() {
        // Type 5: i3 = 101
        var bits = [UInt8](repeating: 0, count: 77)
        bits[74] = 1; bits[75] = 0; bits[76] = 1 // i3 = 5
        _ = FT8Message.parse(bits: bits)
    }
}
