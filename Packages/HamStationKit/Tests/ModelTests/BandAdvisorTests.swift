// BandAdvisorTests.swift
// HamStationKit — Tests for BandAdvisor propagation recommendations.

import XCTest
import Foundation
@testable import HamStationKit

class BandAdvisorTests: XCTestCase {

    // MARK: - Band Condition Tests

    func testHighSFIHighBands() {
        let cond10m = BandAdvisor.bandCondition(band: .band10m, sfi: 160, kIndex: 2, utcHour: 14)
        let cond15m = BandAdvisor.bandCondition(band: .band15m, sfi: 160, kIndex: 2, utcHour: 14)

        XCTAssertEqual(cond10m, .excellent)
        XCTAssertEqual(cond15m, .excellent)
    }

    func testLowSFILowBands() {
        let cond40m = BandAdvisor.bandCondition(band: .band40m, sfi: 65, kIndex: 2, utcHour: 2)
        let cond80m = BandAdvisor.bandCondition(band: .band80m, sfi: 65, kIndex: 2, utcHour: 2)
        let cond10m = BandAdvisor.bandCondition(band: .band10m, sfi: 65, kIndex: 2, utcHour: 2)

        XCTAssertTrue(cond40m == .excellent || cond40m == .good)
        XCTAssertTrue(cond80m == .excellent || cond80m == .good)
        XCTAssertTrue(cond10m == .poor || cond10m == .closed)
    }

    func testHighKIndexDegrades() {
        let cond20m = BandAdvisor.bandCondition(band: .band20m, sfi: 150, kIndex: 5, utcHour: 14)
        let cond15m = BandAdvisor.bandCondition(band: .band15m, sfi: 150, kIndex: 5, utcHour: 14)

        XCTAssertTrue(cond20m == .poor || cond20m == .fair)
        XCTAssertTrue(cond15m == .poor || cond15m == .fair)
    }

    func testNightFavorsLowBands() {
        let cond40m = BandAdvisor.bandCondition(band: .band40m, sfi: 100, kIndex: 2, utcHour: 3)
        let cond80m = BandAdvisor.bandCondition(band: .band80m, sfi: 100, kIndex: 2, utcHour: 3)
        let cond10m = BandAdvisor.bandCondition(band: .band10m, sfi: 100, kIndex: 2, utcHour: 3)

        XCTAssertTrue(cond40m.numericRank > cond10m.numericRank)
        XCTAssertTrue(cond80m.numericRank > cond10m.numericRank)
    }

    func testDayFavorsHighBands() {
        let cond15m = BandAdvisor.bandCondition(band: .band15m, sfi: 130, kIndex: 2, utcHour: 14)
        let cond160m = BandAdvisor.bandCondition(band: .band160m, sfi: 130, kIndex: 2, utcHour: 14)

        XCTAssertTrue(cond15m.numericRank > cond160m.numericRank)
    }

    // MARK: - Recommendation Tests

    func testRecommendationsIncludeTargets() {
        let entities = [
            DXCCEntity(id: 281, name: "Germany", prefix: "DL", continent: "EU", cqZone: 14, ituZone: 28),
            DXCCEntity(id: 339, name: "Japan", prefix: "JA", continent: "AS", cqZone: 25, ituZone: 45),
        ]
        let needed: Set<Int> = [281, 339]

        let recs = BandAdvisor.recommend(
            solarData: SolarData(solarFluxIndex: 120, kIndex: 2),
            neededEntities: needed,
            dxccEntities: entities
        )

        XCTAssertFalse(recs.isEmpty)
        let hasTargets = recs.contains { !$0.targetEntities.isEmpty }
        XCTAssertTrue(hasTargets)
    }

    func testNoSolarDataGenericRecommendations() {
        let recs = BandAdvisor.recommend(
            solarData: nil,
            neededEntities: [],
            dxccEntities: []
        )

        XCTAssertFalse(recs.isEmpty)
    }

    func testRecommendationsSortedByPriority() {
        let recs = BandAdvisor.recommend(
            solarData: SolarData(solarFluxIndex: 130, kIndex: 2),
            neededEntities: [],
            dxccEntities: []
        )

        guard recs.count >= 2 else { return }

        for i in 0..<(recs.count - 1) {
            XCTAssertTrue(recs[i].priority >= recs[i + 1].priority)
        }
    }

    func testBandConditionCoversAllBands() {
        let hfBands: [Band] = [.band160m, .band80m, .band60m, .band40m, .band30m,
                                .band20m, .band17m, .band15m, .band12m, .band10m]

        for band in hfBands {
            let condition = BandAdvisor.bandCondition(band: band, sfi: 100, kIndex: 2, utcHour: 12)
            XCTAssertTrue(BandAdvisor.BandCondition.allCases.contains(condition),
                    "Band \(band.rawValue) returned valid condition")
        }
    }

    func testModerateSFIMidBands() {
        let cond20m = BandAdvisor.bandCondition(band: .band20m, sfi: 120, kIndex: 2, utcHour: 12)
        let cond17m = BandAdvisor.bandCondition(band: .band17m, sfi: 120, kIndex: 2, utcHour: 12)

        XCTAssertTrue(cond20m == .good || cond20m == .excellent)
        XCTAssertTrue(cond17m == .good || cond17m == .excellent)
    }

    func testRecommendationsHaveReasons() {
        let recs = BandAdvisor.recommend(
            solarData: SolarData(solarFluxIndex: 100, kIndex: 2),
            neededEntities: [],
            dxccEntities: []
        )

        for rec in recs {
            XCTAssertFalse(rec.reason.isEmpty)
            XCTAssertFalse(rec.band.isEmpty)
            XCTAssertFalse(rec.mode.isEmpty)
        }
    }
}

// MARK: - Helpers for Tests

extension BandAdvisor.BandCondition {
    /// Numeric rank for comparison (higher = better).
    var numericRank: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .closed: return 0
        }
    }
}
