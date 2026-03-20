// DXCCResolverTests.swift
// HamStationKit — Tests for DXCC callsign-to-entity resolution.

import XCTest
import Foundation
@testable import HamStationKit

class DXCCResolverTests: XCTestCase {

    let resolver = DXCCResolver()

    func testSimpleUSCallsign() {
        XCTAssertEqual(resolver.resolve(callsign: "W1AW"), 291)
    }

    func testSimpleJACallsign() {
        XCTAssertEqual(resolver.resolve(callsign: "JA1ABC"), 339)
    }

    func testSimpleVKCallsign() {
        XCTAssertEqual(resolver.resolve(callsign: "VK2RZA"), 150)
    }

    func testVp2mPrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "VP2MKB"), 96)
    }

    func testVp2ePrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "VP2EAB"), 12)
    }

    func testPortablePrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "OH0/W1AW"), 5)
    }

    func testPortableSuffix() {
        XCTAssertEqual(resolver.resolve(callsign: "W1AW/VP9"), 64)
    }

    func testMaritimeMobile() {
        XCTAssertNil(resolver.resolve(callsign: "W1AW/MM"))
    }

    func testAeronauticalMobile() {
        XCTAssertNil(resolver.resolve(callsign: "W1AW/AM"))
    }

    func testUnknownPrefix() {
        let resolver = DXCCResolver(prefixTable: ["W": 291])
        XCTAssertNil(resolver.resolve(callsign: "XY1ABC"))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(resolver.resolve(callsign: "w1aw"), 291)
    }

    func testGPrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "G3ABC"), 223)
    }

    func testVePrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "VE3ABC"), 1)
    }

    func testTwoLetterPrefix() {
        XCTAssertEqual(resolver.resolve(callsign: "2E0ABC"), 223)
    }

    func testEmptyCallsign() {
        XCTAssertNil(resolver.resolve(callsign: ""))
    }

    func testWhitespaceCallsign() {
        XCTAssertNil(resolver.resolve(callsign: "   "))
    }

    func testCustomEntities() {
        let entity = DXCCEntity(
            id: 999,
            name: "Test Land",
            prefix: "TL",
            continent: "AF",
            cqZone: 36,
            ituZone: 52
        )
        let customResolver = DXCCResolver(entities: [entity])
        XCTAssertEqual(customResolver.resolve(callsign: "TL8ABC"), 999)
    }
}
