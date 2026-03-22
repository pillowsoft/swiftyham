// SunCalculatorTests.swift
// HamStationKit — Tests for sunrise/sunset and grey line calculations.

import XCTest
import Foundation
@testable import HamStationKit

class SunCalculatorTests: XCTestCase {

    // MARK: - Sunrise/Sunset

    func testSolarTimesForNewYork() {
        // New York: 40.7°N, 74.0°W — should have sunrise and sunset on any equinox-ish date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 20, hour: 12)
        let date = calendar.date(from: components)!

        let times = SunCalculator.solarTimes(latitude: 40.7, longitude: -74.0, date: date)

        XCTAssertNotNil(times.sunrise, "New York should have a sunrise")
        XCTAssertNotNil(times.sunset, "New York should have a sunset")
        XCTAssertFalse(times.isPolarDay)
        XCTAssertFalse(times.isPolarNight)

        // Sunrise should be before sunset
        if let rise = times.sunrise, let set = times.sunset {
            XCTAssertTrue(rise < set, "Sunrise should be before sunset")
        }
    }

    func testSolarTimesForEquator() {
        // Equator: ~12 hours of daylight year-round
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 6, day: 21, hour: 12)
        let date = calendar.date(from: components)!

        let times = SunCalculator.solarTimes(latitude: 0.0, longitude: 0.0, date: date)

        XCTAssertNotNil(times.sunrise)
        XCTAssertNotNil(times.sunset)

        if let rise = times.sunrise, let set = times.sunset {
            let dayLength = set.timeIntervalSince(rise)
            // Equator daylight should be ~12 hours (±30 min)
            XCTAssertEqual(dayLength, 12 * 3600, accuracy: 1800)
        }
    }

    func testSolarTimesForArctic() {
        // Svalbard: 78°N — polar day in June
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 6, day: 21, hour: 12)
        let date = calendar.date(from: components)!

        let times = SunCalculator.solarTimes(latitude: 78.0, longitude: 15.0, date: date)

        XCTAssertTrue(times.isPolarDay, "Svalbard should have polar day in June")
        XCTAssertNil(times.sunrise)
        XCTAssertNil(times.sunset)
    }

    func testCivilTwilightExists() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 20, hour: 12)
        let date = calendar.date(from: components)!

        let times = SunCalculator.solarTimes(latitude: 40.7, longitude: -74.0, date: date)

        XCTAssertNotNil(times.civilDawn, "Should have civil dawn")
        XCTAssertNotNil(times.civilDusk, "Should have civil dusk")

        // Civil dawn should be before sunrise
        if let dawn = times.civilDawn, let rise = times.sunrise {
            XCTAssertTrue(dawn < rise, "Civil dawn should be before sunrise")
        }

        // Civil dusk should be after sunset
        if let dusk = times.civilDusk, let set = times.sunset {
            XCTAssertTrue(dusk > set, "Civil dusk should be after sunset")
        }
    }

    // MARK: - Grey Line

    func testGreyLinePathHasPoints() {
        let path = SunCalculator.greyLinePath()
        XCTAssertGreaterThan(path.count, 100, "Grey line should have many points")
    }

    func testGreyLinePointsInValidRange() {
        let path = SunCalculator.greyLinePath()

        for point in path {
            XCTAssertGreaterThanOrEqual(point.latitude, -90)
            XCTAssertLessThanOrEqual(point.latitude, 90)
            XCTAssertGreaterThanOrEqual(point.longitude, -180)
            XCTAssertLessThanOrEqual(point.longitude, 180)
        }
    }

    func testGreyLineCoversLongitudeRange() {
        let path = SunCalculator.greyLinePath()
        let lons = path.map(\.longitude)

        XCTAssertLessThanOrEqual(lons.min()!, -170, "Should cover western longitudes")
        XCTAssertGreaterThanOrEqual(lons.max()!, 170, "Should cover eastern longitudes")
    }

    // MARK: - Julian Day

    func testJulianDayForKnownDate() {
        // J2000.0 = 2000-01-01 12:00 UTC = JD 2451545.0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2000, month: 1, day: 1, hour: 12)
        let date = calendar.date(from: components)!

        let jd = SunCalculator.julianDay(from: date)
        XCTAssertEqual(jd, 2451545.0, accuracy: 0.001)
    }
}
