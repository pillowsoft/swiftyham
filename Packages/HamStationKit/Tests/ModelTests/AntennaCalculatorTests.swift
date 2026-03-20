// AntennaCalculatorTests.swift
// HamStationKit — Tests for AntennaCalculator antenna and RF calculations.

import XCTest
import Foundation
@testable import HamStationKit

class AntennaCalculatorTests: XCTestCase {

    // MARK: - Dipole

    func testDipoleAt14MHz() {
        let length = AntennaCalculator.dipoleLengthFeet(frequencyMHz: 14.074)
        let lengthNoVF = AntennaCalculator.dipoleLengthFeet(frequencyMHz: 14.074, velocityFactor: 1.0)
        XCTAssertTrue(abs(lengthNoVF - 33.26) < 0.1, "Dipole at 14.074 MHz should be ~33.3 feet without VF")
        XCTAssertTrue(length > 30.0 && length < 35.0, "Dipole at 14.074 MHz should be reasonable")
    }

    func testDipoleMetersMatchesFeet() {
        let feet = AntennaCalculator.dipoleLengthFeet(frequencyMHz: 7.0)
        let meters = AntennaCalculator.dipoleLengthMeters(frequencyMHz: 7.0)
        let feetFromMeters = meters / 0.3048
        XCTAssertTrue(abs(feet - feetFromMeters) < 0.5, "Feet and meters should be consistent")
    }

    // MARK: - Quarter Wave Vertical

    func testQuarterWaveAt146MHz() {
        let length = AntennaCalculator.quarterWaveVertical(frequencyMHz: 146.0)
        XCTAssertTrue(abs(length - 1.603) < 0.01, "Quarter wave at 146 MHz should be ~1.6 feet")
    }

    // MARK: - Coax Loss

    func testCoaxLossRG213() {
        let loss = AntennaCalculator.coaxLoss(cableType: .rg213, lengthFeet: 100, frequencyMHz: 14.0)
        XCTAssertTrue(abs(loss - 0.8) < 0.01, "RG-213 loss at 100ft/14MHz should be ~0.8 dB, got \(loss)")
    }

    func testCoaxLossScalesWithLength() {
        let loss50 = AntennaCalculator.coaxLoss(cableType: .rg213, lengthFeet: 50, frequencyMHz: 14.0)
        let loss100 = AntennaCalculator.coaxLoss(cableType: .rg213, lengthFeet: 100, frequencyMHz: 14.0)
        XCTAssertTrue(abs(loss100 - loss50 * 2) < 0.01, "Loss should scale linearly with length")
    }

    func testZeroLengthZeroLoss() {
        let loss = AntennaCalculator.coaxLoss(cableType: .rg58, lengthFeet: 0, frequencyMHz: 14.0)
        XCTAssertEqual(loss, 0)
    }

    // MARK: - SWR

    func testSwrCalculation() {
        let result = AntennaCalculator.swr(forwardPower: 100, reflectedPower: 10)
        XCTAssertTrue(abs(result - 1.925) < 0.01, "SWR should be ~1.92, got \(result)")
    }

    func testSwrOneInfiniteReturnLoss() {
        let rl = AntennaCalculator.returnLoss(swr: 1.0)
        XCTAssertEqual(rl, .infinity, "SWR 1.0 should give infinite return loss")
    }

    func testSwrEqualPowerIsInfinity() {
        let result = AntennaCalculator.swr(forwardPower: 100, reflectedPower: 100)
        XCTAssertEqual(result, .infinity, "Equal forward/reflected should give infinite SWR")
    }

    func testSwrZeroReflected() {
        let result = AntennaCalculator.swr(forwardPower: 100, reflectedPower: 0)
        XCTAssertEqual(result, 1.0, "Zero reflected should give SWR 1.0")
    }

    func testReflectionCoefficientAt2() {
        let rho = AntennaCalculator.reflectionCoefficient(swr: 2.0)
        XCTAssertTrue(abs(rho - 1.0 / 3.0) < 0.001, "Reflection coefficient at SWR 2.0 should be 1/3")
    }

    func testMismatchLossAtSWR1() {
        let ml = AntennaCalculator.mismatchLoss(swr: 1.0)
        XCTAssertTrue(abs(ml) < 0.001, "Mismatch loss at SWR 1.0 should be 0 dB")
    }

    // MARK: - L-Network

    func testLNetwork50to200() {
        let result = AntennaCalculator.lNetwork(sourceZ: 50, loadZ: 200, frequencyMHz: 14.074)
        XCTAssertTrue(result.inductance > 0, "Inductance should be positive")
        XCTAssertTrue(result.capacitance > 0, "Capacitance should be positive")
        XCTAssertEqual(result.topology, "series-L, shunt-C",
                "50->200 should use series-L, shunt-C topology")
    }

    func testLNetworkEqualZ() {
        let result = AntennaCalculator.lNetwork(sourceZ: 50, loadZ: 50, frequencyMHz: 14.0)
        XCTAssertTrue(result.inductance == 0 || result.inductance.isNaN || result.inductance < 0.001,
                "Equal impedances should need minimal matching")
    }

    // MARK: - Yagi Elements

    func testYagiReflectorLonger() {
        let reflector = AntennaCalculator.yagiElement(frequencyMHz: 14.0, elementType: .reflector)
        let driven = AntennaCalculator.yagiElement(frequencyMHz: 14.0, elementType: .drivenElement)
        let director = AntennaCalculator.yagiElement(frequencyMHz: 14.0, elementType: .director)
        XCTAssertTrue(reflector > driven, "Reflector should be longer than driven element")
        XCTAssertTrue(driven > director, "Driven element should be longer than director")
    }
}
