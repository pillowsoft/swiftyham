// SatelliteTests.swift
// HamStationKit — Tests for TLE parsing, SGP4 propagation, and satellite tracking.

import XCTest
import Foundation
@testable import HamStationKit

class SatelliteTests: XCTestCase {

    // MARK: - TLE Parser Tests

    static let issTLE = """
    ISS (ZARYA)
    1 25544U 98067A   24079.50000000  .00016717  00000-0  10270-3 0  9003
    2 25544  51.6400 247.4627 0006703  30.5360 325.0288 15.49815700  1234
    """

    func testParseSingleISSTLE() {
        let tles = TLEParser.parse(text: SatelliteTests.issTLE)
        XCTAssertEqual(tles.count, 1)

        let iss = tles[0]
        XCTAssertEqual(iss.name, "ISS (ZARYA)")
        XCTAssertEqual(iss.id, 25544)
        XCTAssertTrue(abs(iss.inclination - 51.64) < 0.01)
        XCTAssertTrue(abs(iss.raan - 247.4627) < 0.001)
        XCTAssertTrue(abs(iss.eccentricity - 0.0006703) < 0.0000001)
        XCTAssertTrue(abs(iss.argOfPerigee - 30.536) < 0.001)
        XCTAssertTrue(abs(iss.meanAnomaly - 325.0288) < 0.001)
        XCTAssertTrue(abs(iss.meanMotion - 15.498157) < 0.001)
        XCTAssertEqual(iss.epochYear, 2024)
        XCTAssertTrue(abs(iss.epochDay - 79.5) < 0.001)
    }

    static let multiTLE = """
    ISS (ZARYA)
    1 25544U 98067A   24079.50000000  .00016717  00000-0  10270-3 0  9003
    2 25544  51.6400 247.4627 0006703  30.5360 325.0288 15.49815700  1234
    AO-91 (FOX-1B)
    1 43017U 17073E   24079.50000000  .00001234  00000-0  56789-4 0  9001
    2 43017  97.5200 120.3400 0012345  45.6789 314.5678 14.95432100  5678
    SO-50
    1 27607U 02058C   24079.50000000  .00000567  00000-0  34567-4 0  9002
    2 27607  64.5500  89.1234 0045678  12.3456 347.8765 14.75432100  9876
    """

    func testParseMultiSatelliteTLE() {
        let tles = TLEParser.parse(text: SatelliteTests.multiTLE)
        XCTAssertEqual(tles.count, 3)
        XCTAssertEqual(tles[0].name, "ISS (ZARYA)")
        XCTAssertEqual(tles[0].id, 25544)
        XCTAssertEqual(tles[1].name, "AO-91 (FOX-1B)")
        XCTAssertEqual(tles[1].id, 43017)
        XCTAssertEqual(tles[2].name, "SO-50")
        XCTAssertEqual(tles[2].id, 27607)
    }

    func testRejectMalformedTLE() {
        let result1 = TLEParser.parseSingle(name: "TEST", line1: "1 12345", line2: "2 12345")
        XCTAssertNil(result1)

        let result2 = TLEParser.parseSingle(
            name: "TEST",
            line1: "2 25544U 98067A   24079.50000000  .00016717  00000-0  10270-3 0  9003",
            line2: "1 25544  51.6400 247.4627 0006703  30.5360 325.0288 15.49815700  1234"
        )
        XCTAssertNil(result2)

        let empty = TLEParser.parse(text: "")
        XCTAssertTrue(empty.isEmpty)

        let gibberish = TLEParser.parse(text: "Hello World\nThis is not a TLE\nNot at all")
        XCTAssertTrue(gibberish.isEmpty)
    }

    func testParseExponentialNotation() {
        let val1 = TLEParser.parseExponentialNotation("+12345-6")
        XCTAssertTrue(abs(val1 - 0.12345e-6) < 1e-12)

        let val2 = TLEParser.parseExponentialNotation("-67890-5")
        XCTAssertTrue(abs(val2 - (-0.67890e-5)) < 1e-12)

        let val3 = TLEParser.parseExponentialNotation("10270-3")
        XCTAssertTrue(abs(val3 - 0.10270e-3) < 1e-12)
    }

    // MARK: - SGP4 Propagation Tests

    func testSgp4ISSPosition() {
        let tles = TLEParser.parse(text: SatelliteTests.issTLE)
        guard let iss = tles.first else {
            XCTFail("Failed to parse ISS TLE")
            return
        }

        guard let position = SGP4.propagate(tle: iss, date: iss.epoch) else {
            XCTFail("SGP4 propagation returned nil")
            return
        }

        XCTAssertTrue(position.altitude > 350 && position.altitude < 450,
                "ISS altitude \(position.altitude) km should be 350-450 km")
        XCTAssertTrue(position.latitude > -55 && position.latitude < 55,
                "ISS latitude \(position.latitude) should be within +/-55 degrees")
        XCTAssertTrue(position.longitude >= -180 && position.longitude <= 180,
                "ISS longitude \(position.longitude) should be -180 to 180")
        XCTAssertTrue(position.velocity > 7.0 && position.velocity < 8.5,
                "ISS velocity \(position.velocity) km/s should be ~7.6 km/s")
    }

    func testDopplerShiftCalculation() {
        let nominal = 145_800_000.0
        let rangeRate = 6.0

        let corrected = SGP4.dopplerShift(nominalFrequencyHz: nominal, rangeRateKmPerSec: rangeRate)

        XCTAssertTrue(corrected < nominal)

        let shift = abs(nominal - corrected)
        XCTAssertTrue(shift > 2800 && shift < 3100,
                "Doppler shift \(shift) Hz should be ~2918 Hz for 145.8 MHz at 6 km/s")

        let correctedApproaching = SGP4.dopplerShift(nominalFrequencyHz: nominal, rangeRateKmPerSec: -6.0)
        XCTAssertTrue(correctedApproaching > nominal)
    }

    func testLookAnglesCalculation() {
        let satPos = SGP4.SatellitePosition(
            latitude: 42.0, longitude: -72.0, altitude: 400.0, velocity: 7.6
        )
        let observer = (latitude: 42.0, longitude: -72.0, altitude: 0.0)

        let angles = SGP4.lookAngles(satellitePosition: satPos, observer: observer)

        XCTAssertTrue(angles.elevation > 80,
                "Elevation \(angles.elevation) should be near 90 for overhead satellite")
        XCTAssertTrue(abs(angles.range - 400.0) < 50,
                "Range \(angles.range) km should be near 400 km for overhead satellite")
    }

    func testLookAnglesHorizon() {
        let satPos = SGP4.SatellitePosition(
            latitude: 42.0, longitude: -50.0, altitude: 400.0, velocity: 7.6
        )
        let observer = (latitude: 42.0, longitude: -72.0, altitude: 0.0)

        let angles = SGP4.lookAngles(satellitePosition: satPos, observer: observer)

        XCTAssertTrue(angles.elevation < 10,
                "Elevation \(angles.elevation) should be low for distant satellite")
    }

    func testPassPredicationISS() {
        let tles = TLEParser.parse(text: SatelliteTests.issTLE)
        guard let iss = tles.first else {
            XCTFail("Failed to parse ISS TLE")
            return
        }

        let observer = (latitude: 41.5, longitude: -72.8, altitude: 0.05)
        let passes = SGP4.predictPasses(
            tle: iss,
            observer: observer,
            startDate: iss.epoch,
            days: 7,
            minElevation: 5
        )

        XCTAssertTrue(passes.count > 0,
                "ISS should have at least one pass over Connecticut in 7 days")

        if let firstPass = passes.first {
            XCTAssertTrue(firstPass.aos < firstPass.los, "AOS should be before LOS")
            XCTAssertTrue(firstPass.maxElevation >= 5, "Max elevation should meet minimum threshold")
            XCTAssertTrue(firstPass.maxElevationTime >= firstPass.aos, "Max elevation time should be during pass")
            XCTAssertTrue(firstPass.maxElevationTime <= firstPass.los, "Max elevation time should be during pass")
            XCTAssertTrue(firstPass.aosAzimuth >= 0 && firstPass.aosAzimuth < 360, "AOS azimuth should be 0-360")
            XCTAssertTrue(firstPass.losAzimuth >= 0 && firstPass.losAzimuth < 360, "LOS azimuth should be 0-360")
        }
    }

    // MARK: - Julian Date

    func testJulianDateConversion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 12
        let j2000 = calendar.date(from: components)!

        let jd = SGP4.julianDate(from: j2000)
        XCTAssertTrue(abs(jd - 2451545.0) < 0.001,
                "J2000.0 should be JD 2451545.0, got \(jd)")
    }
}
