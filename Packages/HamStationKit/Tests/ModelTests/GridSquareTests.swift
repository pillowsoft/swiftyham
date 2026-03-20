// GridSquareTests.swift
// HamStationKit — Tests for Maidenhead grid square utilities.

import XCTest
import Foundation
@testable import HamStationKit

class GridSquareTests: XCTestCase {

    // MARK: - Validation

    func testValid4CharGrid() {
        XCTAssertTrue(GridSquare.isValid("FN31"))
    }

    func testValid6CharGrid() {
        XCTAssertTrue(GridSquare.isValid("FN31pr"))
    }

    func testInvalidGridZZ99() {
        XCTAssertFalse(GridSquare.isValid("ZZ99"))
    }

    func testInvalidLength() {
        XCTAssertFalse(GridSquare.isValid("FN3"))
    }

    func testInvalidLength5() {
        XCTAssertFalse(GridSquare.isValid("FN31p"))
    }

    func testLowercaseFieldLetters() {
        XCTAssertFalse(GridSquare.isValid("fn31"))
    }

    func testUppercaseSubsquare() {
        XCTAssertFalse(GridSquare.isValid("FN31PR"))
    }

    func testSubsquareBeyondX() {
        XCTAssertFalse(GridSquare.isValid("FN31pz"))
    }

    // MARK: - Coordinates from Grid

    func testCoordinatesFromFN31() {
        guard let coords = GridSquare.coordinates(from: "FN31") else {
            XCTFail("Expected coordinates for FN31")
            return
        }
        XCTAssertTrue(coords.latitude > 40.5 && coords.latitude < 42.0)
        XCTAssertTrue(coords.longitude > -74.0 && coords.longitude < -72.0)
    }

    func testCoordinatesFrom6Char() {
        guard let coords4 = GridSquare.coordinates(from: "FN31"),
              let coords6 = GridSquare.coordinates(from: "FN31pr") else {
            XCTFail("Expected coordinates")
            return
        }
        XCTAssertTrue(abs(coords4.latitude - coords6.latitude) < 1.0)
        XCTAssertTrue(abs(coords4.longitude - coords6.longitude) < 2.0)
    }

    func testInvalidGridCoordinates() {
        XCTAssertNil(GridSquare.coordinates(from: "ZZ99"))
    }

    // MARK: - Grid from Coordinates

    func testGridFromCoordinates() {
        let grid = GridSquare.grid(from: 41.0, longitude: -73.0)
        XCTAssertTrue(grid.hasPrefix("FN31"))
    }

    func testGridFromLondon() {
        let grid = GridSquare.grid(from: 51.5, longitude: -0.1)
        XCTAssertTrue(grid.hasPrefix("IO91") || grid.hasPrefix("JO"))
    }

    // MARK: - Distance

    func testDistanceFN31toJO21() {
        guard let distance = GridSquare.distance(from: "FN31", to: "JO21") else {
            XCTFail("Expected distance")
            return
        }
        XCTAssertTrue(distance > 5000 && distance < 6000)
    }

    func testDistanceSameGrid() {
        guard let distance = GridSquare.distance(from: "FN31", to: "FN31") else {
            XCTFail("Expected distance")
            return
        }
        XCTAssertTrue(distance < 1.0)
    }

    func testInvalidGridDistance() {
        XCTAssertNil(GridSquare.distance(from: "ZZZZ", to: "FN31"))
    }

    // MARK: - Bearing

    func testBearingFN31toJO21() {
        guard let bearing = GridSquare.bearing(from: "FN31", to: "JO21") else {
            XCTFail("Expected bearing")
            return
        }
        XCTAssertTrue(bearing > 40 && bearing < 70)
    }

    func testInvalidGridBearing() {
        XCTAssertNil(GridSquare.bearing(from: "ZZZZ", to: "FN31"))
    }

    // MARK: - Round-trip

    func testRoundTrip() {
        let originalLat = 41.0
        let originalLon = -73.0

        let grid = GridSquare.grid(from: originalLat, longitude: originalLon)
        guard let coords = GridSquare.coordinates(from: grid) else {
            XCTFail("Expected coordinates from generated grid")
            return
        }

        XCTAssertTrue(abs(coords.latitude - originalLat) < 0.05)
        XCTAssertTrue(abs(coords.longitude - originalLon) < 0.05)
    }
}
