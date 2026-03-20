// ContestTests.swift
// HamStationKit — Tests for contest engine, scoring, dupe checking, and Cabrillo export.

import XCTest
import Foundation
@testable import HamStationKit

class ContestTests: XCTestCase {

    // MARK: - QSO Logging

    func testLogQSOSerialIncrement() async {
        let engine = ContestEngine(definition: .cqwwCW)

        let qso1 = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        XCTAssertTrue(qso1.exchangeSent.contains("001"))

        let qso2 = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")
        XCTAssertTrue(qso2.exchangeSent.contains("002"))

        let serial = await engine.serialNumber
        XCTAssertEqual(serial, 3)
    }

    // MARK: - Dupe Checking

    func testLogDupeNoPoints() async {
        let engine = ContestEngine(definition: .cqwwCW)

        let qso1 = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        XCTAssertFalse(qso1.isDupe)
        XCTAssertTrue(qso1.points > 0)

        let qso2 = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        XCTAssertTrue(qso2.isDupe)
        XCTAssertEqual(qso2.points, 0)
    }

    func testDupeOnDifferentBandNotDupe() async {
        let engine = ContestEngine(definition: .cqwwCW)

        let qso1 = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        XCTAssertFalse(qso1.isDupe)

        let qso2 = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "40m", mode: "CW")
        XCTAssertFalse(qso2.isDupe)
        XCTAssertTrue(qso2.points > 0)
    }

    func testOncePerContestDupe() async {
        let engine = ContestEngine(definition: .arrlSweepstakes)

        let qso1 = await engine.logQSO(callsign: "W1AW", exchange: "1 A 74 CT", band: "20m", mode: "CW")
        XCTAssertFalse(qso1.isDupe)

        let qso2 = await engine.logQSO(callsign: "W1AW", exchange: "1 A 74 CT", band: "40m", mode: "CW")
        XCTAssertTrue(qso2.isDupe)
    }

    func testOncePerBandModeDupe() async {
        let engine = ContestEngine(definition: .iaruHF)

        let qso1 = await engine.logQSO(callsign: "W1AW", exchange: "599 08", band: "20m", mode: "CW")
        XCTAssertFalse(qso1.isDupe)

        let qso2 = await engine.logQSO(callsign: "W1AW", exchange: "59 08", band: "20m", mode: "SSB")
        XCTAssertFalse(qso2.isDupe)

        let qso3 = await engine.logQSO(callsign: "W1AW", exchange: "599 08", band: "20m", mode: "CW")
        XCTAssertTrue(qso3.isDupe)
    }

    // MARK: - Score Calculation

    func testScoreCalculation() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "DL1ABC", exchange: "599 14", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "VK2ABC", exchange: "599 30", band: "40m", mode: "CW")

        let score = await engine.score

        XCTAssertEqual(score.totalQSOs, 4)
        XCTAssertEqual(score.validQSOs, 4)
        XCTAssertEqual(score.dupes, 0)
        XCTAssertEqual(score.points, 12)
        XCTAssertEqual(score.multipliers, 4)
        XCTAssertEqual(score.score, 48)
    }

    // MARK: - N+1 Checking

    func testNPlusOneCheck() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "W1AX", exchange: "599 05", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "W1BW", exchange: "599 05", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "K2ABC", exchange: "599 05", band: "20m", mode: "CW")

        let suggestions = await engine.checkCallsign("W1AW")
        XCTAssertTrue(suggestions.contains("W1AX"),
                "W1AX should be suggested for W1AW (distance=1)")
        XCTAssertTrue(suggestions.contains("W1BW"),
                "W1BW should be suggested for W1AW (distance=1)")
        XCTAssertFalse(suggestions.contains("K2ABC"),
                "K2ABC should NOT be suggested for W1AW (distance>1)")
    }

    func testNPlusOneExactMatch() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")

        let suggestions = await engine.checkCallsign("W1AW")
        XCTAssertFalse(suggestions.contains("W1AW"),
                "Exact match should not be in suggestions")
    }

    // MARK: - Cabrillo Export

    func testCabrilloExportValid() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "DL1ABC", exchange: "599 14", band: "20m", mode: "CW")

        let cabrillo = await engine.exportCabrillo(
            operatorCallsign: "W1AW",
            operatorCategory: "SINGLE-OP",
            power: "HIGH"
        )

        XCTAssertTrue(cabrillo.hasPrefix("START-OF-LOG: 3.0"))
        XCTAssertTrue(cabrillo.contains("CONTEST: CQWW-CW"))
        XCTAssertTrue(cabrillo.contains("CALLSIGN: W1AW"))
        XCTAssertTrue(cabrillo.contains("CATEGORY-OPERATOR: SINGLE-OP"))
        XCTAssertTrue(cabrillo.contains("CATEGORY-POWER: HIGH"))
        XCTAssertTrue(cabrillo.contains("END-OF-LOG:"))

        let lines = cabrillo.components(separatedBy: "\n")
        let qsoLines = lines.filter { $0.hasPrefix("QSO:") }
        XCTAssertEqual(qsoLines.count, 2)

        if let firstQSO = qsoLines.first {
            XCTAssertTrue(firstQSO.contains("14000"))
            XCTAssertTrue(firstQSO.contains("CW"))
            XCTAssertTrue(firstQSO.contains("W1AW"))
            XCTAssertTrue(firstQSO.contains("JA1ABC"))
        }
    }

    func testCabrilloExcludesDupes() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")

        let cabrillo = await engine.exportCabrillo(
            operatorCallsign: "W1AW",
            operatorCategory: "SINGLE-OP",
            power: "HIGH"
        )

        let lines = cabrillo.components(separatedBy: "\n")
        let qsoLines = lines.filter { $0.hasPrefix("QSO:") }
        XCTAssertEqual(qsoLines.count, 1, "Cabrillo should only include 1 non-dupe QSO")
    }

    // MARK: - Rate Calculation

    func testRateCalculation() async {
        let engine = ContestEngine(definition: .cqwwCW)

        _ = await engine.logQSO(callsign: "W1AW", exchange: "599 05", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "JA1ABC", exchange: "599 25", band: "20m", mode: "CW")
        _ = await engine.logQSO(callsign: "DL1ABC", exchange: "599 14", band: "20m", mode: "CW")

        let rate = await engine.rate
        XCTAssertEqual(rate.last10Min, 3, "All 3 QSOs should be in last 10 minutes")
        XCTAssertEqual(rate.lastHour, 3, "All 3 QSOs should be in last hour")
        XCTAssertTrue(rate.overall > 0, "Overall rate should be positive")
    }

    // MARK: - Built-in Definitions

    func testBuiltInDefinitions() {
        let definitions = ContestDefinition.builtIn
        XCTAssertEqual(definitions.count, 10)

        for def in definitions {
            XCTAssertFalse(def.id.isEmpty, "Contest ID should not be empty")
            XCTAssertFalse(def.name.isEmpty, "Contest name should not be empty")
            XCTAssertFalse(def.sponsor.isEmpty, "Contest sponsor should not be empty")
            XCTAssertFalse(def.modes.isEmpty, "Contest should have at least one mode")
            XCTAssertFalse(def.bands.isEmpty, "Contest should have at least one band")
            XCTAssertTrue(def.pointsPerQSO > 0, "Points per QSO should be positive")
        }

        let cqww = definitions.first { $0.id == "CQWW-CW" }
        XCTAssertNotNil(cqww, "CQWW-CW should be in built-in definitions")
        XCTAssertEqual(cqww?.modes, ["CW"])
        XCTAssertEqual(cqww?.dupeRule, .oncePerBand)
    }

    // MARK: - Cabrillo Date/Time Formatting

    func testCabrilloDateTimeFormatting() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        components.hour = 14
        components.minute = 30
        let date = calendar.date(from: components)!

        XCTAssertEqual(CabrilloExporter.formatDate(date), "2024-03-15")
        XCTAssertEqual(CabrilloExporter.formatTime(date), "1430")
    }
}
