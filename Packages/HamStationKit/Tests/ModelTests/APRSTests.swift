// APRSTests.swift
// HamStationKit — Tests for APRS packet parsing and APRS-IS passcode calculation.

import XCTest
import Foundation
@testable import HamStationKit

class APRSTests: XCTestCase {

    // MARK: - Position Parsing

    func testParsePositionPacket() {
        let line = "N0CALL>APRS,TCPIP*:=4903.50N/07201.75W-Test comment"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse position packet")
            return
        }

        XCTAssertEqual(packet.source, "N0CALL")
        XCTAssertEqual(packet.destination, "APRS")
        XCTAssertEqual(packet.path, ["TCPIP*"])

        if case .position(let pos) = packet.dataType {
            XCTAssertTrue(abs(pos.latitude - 49.05833) < 0.001)
            XCTAssertTrue(abs(pos.longitude - (-72.02917)) < 0.001)
            XCTAssertEqual(pos.symbol, "/-")
        } else {
            XCTFail("Expected position data type, got \(packet.dataType)")
        }
    }

    func testParsePositionWithPHG() {
        let line = "W1AW>APRS,TCPIP*:=4152.50N/07242.50W-PHG2360/Newington CT"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse PHG packet")
            return
        }

        if case .position(let pos) = packet.dataType {
            XCTAssertEqual(pos.power, 4)
            XCTAssertEqual(pos.height, 80)
            XCTAssertEqual(pos.gain, 6)
            XCTAssertTrue(abs(pos.latitude - 41.875) < 0.001)
        } else {
            XCTFail("Expected position data type")
        }
    }

    // MARK: - Message Parsing

    func testParseMessagePacket() {
        let line = "N0CALL>APRS,TCPIP*::W1AW     :Hello World{123"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse message packet")
            return
        }

        if case .message(let msg) = packet.dataType {
            XCTAssertEqual(msg.addressee, "W1AW")
            XCTAssertEqual(msg.text, "Hello World")
            XCTAssertEqual(msg.messageNumber, "123")
        } else {
            XCTFail("Expected message data type, got \(packet.dataType)")
        }
    }

    func testParseMessageNoNumber() {
        let line = "N0CALL>APRS,TCPIP*::W1AW     :Testing 1 2 3"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse message packet")
            return
        }

        if case .message(let msg) = packet.dataType {
            XCTAssertEqual(msg.addressee, "W1AW")
            XCTAssertEqual(msg.text, "Testing 1 2 3")
            XCTAssertNil(msg.messageNumber)
        } else {
            XCTFail("Expected message data type")
        }
    }

    // MARK: - Weather Parsing

    func testParseWeatherPacket() {
        let line = "WX1AW>APRS,TCPIP*:_c180s005g010t072r001h50b10130"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse weather packet")
            return
        }

        if case .weather(let wx) = packet.dataType {
            XCTAssertEqual(wx.windDirection, 180)
            XCTAssertEqual(wx.windSpeed, 5)
            XCTAssertEqual(wx.windGust, 10)
            XCTAssertEqual(wx.temperature, 72)
            XCTAssertEqual(wx.rainLastHour, 0.01)
            XCTAssertEqual(wx.humidity, 50)
            XCTAssertTrue(abs((wx.pressure ?? 0) - 1013.0) < 0.1)
        } else {
            XCTFail("Expected weather data type, got \(packet.dataType)")
        }
    }

    // MARK: - Object Parsing

    func testParseObjectPacket() {
        let line = "N0CALL>APRS,TCPIP*:;FIRE     *4903.50N/07201.75W-Active fire"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse object packet")
            return
        }

        if case .object(let obj) = packet.dataType {
            XCTAssertEqual(obj.name, "FIRE")
            XCTAssertEqual(obj.isLive, true)
            XCTAssertTrue(abs(obj.position.latitude - 49.05833) < 0.001)
        } else {
            XCTFail("Expected object data type, got \(packet.dataType)")
        }
    }

    func testParseKilledObject() {
        let line = "N0CALL>APRS,TCPIP*:;FIRE     _4903.50N/07201.75W-Fire out"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse killed object packet")
            return
        }

        if case .object(let obj) = packet.dataType {
            XCTAssertEqual(obj.name, "FIRE")
            XCTAssertEqual(obj.isLive, false)
        } else {
            XCTFail("Expected object data type")
        }
    }

    // MARK: - Status Parsing

    func testParseStatusPacket() {
        let line = "N0CALL>APRS,TCPIP*:>Operating from home QTH"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse status packet")
            return
        }

        if case .status(let text) = packet.dataType {
            XCTAssertEqual(text, "Operating from home QTH")
        } else {
            XCTFail("Expected status data type, got \(packet.dataType)")
        }
    }

    // MARK: - Malformed Packets

    func testMalformedPacketReturnsNil() {
        XCTAssertNil(APRSPacket.parse(line: "N0CALL>APRS no data"))
        XCTAssertNil(APRSPacket.parse(line: "N0CALL:data"))
        XCTAssertNil(APRSPacket.parse(line: ">APRS:data"))
        XCTAssertNil(APRSPacket.parse(line: "# javAPRSFilter 1.0"))
        XCTAssertNil(APRSPacket.parse(line: ""))
        XCTAssertNil(APRSPacket.parse(line: "   \n"))
    }

    // MARK: - Passcode Calculation

    func testPasscodeCalculation() {
        let w1aw = APRSClient.calculatePasscode(callsign: "W1AW")
        XCTAssertTrue(w1aw >= 0 && w1aw <= 32767, "Passcode should be 0-32767")

        let w1aw2 = APRSClient.calculatePasscode(callsign: "W1AW")
        XCTAssertEqual(w1aw, w1aw2)

        let w1awSSID = APRSClient.calculatePasscode(callsign: "W1AW-9")
        XCTAssertEqual(w1aw, w1awSSID, "Passcode should be the same regardless of SSID")

        let n0call = APRSClient.calculatePasscode(callsign: "N0CALL")
        XCTAssertTrue(n0call >= 0 && n0call <= 32767)

        let lower = APRSClient.calculatePasscode(callsign: "w1aw")
        XCTAssertEqual(w1aw, lower, "Passcode should be case-insensitive")
    }

    // MARK: - Digipeater Path

    func testDigipeaterPath() {
        let line = "N0CALL>APRS,WIDE1-1,WIDE2-2,qAR,W1AW:>Status test"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse packet with digi path")
            return
        }

        XCTAssertEqual(packet.source, "N0CALL")
        XCTAssertEqual(packet.destination, "APRS")
        XCTAssertEqual(packet.path.count, 4)
        XCTAssertEqual(packet.path[0], "WIDE1-1")
        XCTAssertEqual(packet.path[1], "WIDE2-2")
        XCTAssertEqual(packet.path[2], "qAR")
        XCTAssertEqual(packet.path[3], "W1AW")
    }

    func testNoPath() {
        let line = "N0CALL>APRS:>Simple status"
        guard let packet = APRSPacket.parse(line: line) else {
            XCTFail("Failed to parse packet with no path")
            return
        }

        XCTAssertTrue(packet.path.isEmpty)
        XCTAssertEqual(packet.destination, "APRS")
    }
}
