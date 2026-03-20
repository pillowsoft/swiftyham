import XCTest
import Foundation
@testable import HamStationKit

class DXSpotParserTests: XCTestCase {

    // MARK: - AR-Cluster Format

    func testParseARClusterSpot() {
        let line = "DX de KA1ABC:     14025.0  W1AW         CW 599                   1234Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.spotter, "KA1ABC")
        XCTAssertEqual(spot?.dxCallsign, "W1AW")
        XCTAssertEqual(spot?.frequency, 14025.0)
        XCTAssertEqual(spot?.band, .band20m)
    }

    func testParseDXSpiderSpot() {
        let line = "DX de W3LPL-#:    21074.0  JA1XYZ       FT8 -12dB               1456Z JN48"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.spotter, "W3LPL-#")
        XCTAssertEqual(spot?.dxCallsign, "JA1XYZ")
        XCTAssertEqual(spot?.frequency, 21074.0)
        XCTAssertEqual(spot?.band, .band15m)
    }

    func testParseSpotWithComment() {
        let line = "DX de N2ABC:      7074.0   DL1ZZZ       FT8 -15 dB from EN91    2345Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertNotNil(spot?.comment)
        XCTAssertEqual(spot?.comment?.contains("FT8"), true)
        XCTAssertEqual(spot?.mode, .ft8)
    }

    func testParseSpotTimestamp() {
        let line = "DX de VE3ABC:     14074.0  G3XYZ        FT8                      0830Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.hour, .minute], from: spot!.timestamp)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 30)
    }

    func testBandResolution20m() {
        let line = "DX de K1ABC:      14250.0  ZL1XX        SSB                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band20m)
    }

    func testBandResolution40m() {
        let line = "DX de K1ABC:       7074.0  DK2XX        FT8                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band40m)
    }

    func testBandResolution80m() {
        let line = "DX de K1ABC:       3573.0  UA3XX        FT8                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band80m)
    }

    func testBandResolution10m() {
        let line = "DX de K1ABC:      28074.0  LU1XX        FT8                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band10m)
    }

    func testBandResolution6m() {
        let line = "DX de K1ABC:      50313.0  VK2XX        FT8                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band6m)
    }

    func testBandResolutionLowerEdge() {
        let line = "DX de K1ABC:      14000.0  W1AW         CW                       1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band20m)
    }

    func testBandResolutionUpperEdge() {
        let line = "DX de K1ABC:      14350.0  W1AW         SSB                      1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band20m)
    }

    func testAnnouncementReturnsNil() {
        let line = "To ALL de W1AW: ARRL Bulletin 123"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }

    func testLoginPromptReturnsNil() {
        let line = "login: Please enter your callsign"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }

    func testWWVReturnsNil() {
        let line = "WWV de VE7CC <18>:   SFI=145, A=7, K=2, Cond=Good"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }

    func testMalformedNoFrequency() {
        let line = "DX de K1ABC:      ABCDE    W1AW         CW 599                   1234Z"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }

    func testEmptyLine() {
        let spot = DXSpot.parse(line: "")
        XCTAssertNil(spot)
    }

    func testWhitespaceLine() {
        let spot = DXSpot.parse(line: "   \t  \n  ")
        XCTAssertNil(spot)
    }

    func testExtraWhitespace() {
        let line = "DX de  KA1ABC:      14025.0   W1AW          CW  599                  1234Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.dxCallsign, "W1AW")
        XCTAssertEqual(spot?.frequency, 14025.0)
    }

    func testModeGuessCW() {
        let line = "DX de K1ABC:      14025.0  W1AW         CW 599                   1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.mode, .cw)
    }

    func testModeGuessFT8Frequency() {
        let line = "DX de K1ABC:      14074.0  W1AW                                  1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.mode, .ft8)
    }

    func testModeGuessRTTY() {
        let line = "DX de K1ABC:      14085.0  W1AW         RTTY contest             1200Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.mode, .rtty)
    }

    func testTooShortLine() {
        let line = "DX de K1ABC: 14025.0"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }

    func testCaseInsensitivePrefix() {
        let line = "dx de KA1ABC:     14025.0  W1AW         CW 599                   1234Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.spotter, "KA1ABC")
    }

    func testBandResolution160m() {
        let line = "DX de K1ABC:       1840.0  W1AW         FT8                      0300Z"
        let spot = DXSpot.parse(line: line)

        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.band, .band160m)
    }

    func testInvalidCallsignNoDigits() {
        let line = "DX de K1ABC:      14025.0  ABCDEF       CW 599                   1234Z"
        let spot = DXSpot.parse(line: line)
        XCTAssertNil(spot)
    }
}
