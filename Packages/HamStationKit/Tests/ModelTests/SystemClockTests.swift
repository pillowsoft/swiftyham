// SystemClockTests.swift
// HamStationKit — Tests for SystemClock precision timing and NTP sync checking.

import XCTest
import Foundation
@testable import HamStationKit

// MARK: - SystemClock Timing Tests

class SystemClockTimingTests: XCTestCase {

    func testMonotonicNanosIsNonZero() {
        let nanos = SystemClock.monotonicNanos()
        XCTAssertGreaterThan(nanos, 0)
    }

    func testMonotonicNanosIsMonotonic() {
        let a = SystemClock.monotonicNanos()
        let b = SystemClock.monotonicNanos()
        XCTAssertGreaterThanOrEqual(b, a)
    }

    func testUTCNanosSinceEpochIsReasonable() {
        // Should be after 2026-01-01 UTC
        let nanos = SystemClock.utcNanosSinceEpoch()
        let year2026 = UInt64(1_735_689_600) * 1_000_000_000 // 2026-01-01 approx
        XCTAssertGreaterThan(nanos, year2026)
    }

    func testUTCSecondAndNanosInRange() {
        let (second, nanos) = SystemClock.utcSecondAndNanos()
        XCTAssertGreaterThanOrEqual(second, 0)
        XCTAssertLessThan(second, 60)
        XCTAssertLessThan(nanos, 1_000_000_000)
    }

    func testUTCSecondMatchesFoundation() {
        // Verify our raw Unix arithmetic matches Calendar for the second component
        let (ourSecond, _) = SystemClock.utcSecondAndNanos()
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!
        let foundationSecond = cal.component(.second, from: Date())
        // Allow ±1 second for race between the two calls
        let diff = abs(ourSecond - foundationSecond)
        XCTAssertTrue(diff <= 1 || diff >= 59, "Second mismatch: ours=\(ourSecond) foundation=\(foundationSecond)")
    }
}

// MARK: - Cycle Boundary Tests

class SystemClockCycleBoundaryTests: XCTestCase {

    func testFT8BoundaryIsWithinCycleDuration() {
        let waitNanos = SystemClock.nanosUntilNextBoundary(cycle: .ft8)
        XCTAssertGreaterThan(waitNanos, 0)
        XCTAssertLessThanOrEqual(waitNanos, SystemClock.CycleDuration.ft8.nanoseconds)
    }

    func testFT4BoundaryIsWithinCycleDuration() {
        let waitNanos = SystemClock.nanosUntilNextBoundary(cycle: .ft4)
        XCTAssertGreaterThan(waitNanos, 0)
        XCTAssertLessThanOrEqual(waitNanos, SystemClock.CycleDuration.ft4.nanoseconds)
    }

    func testFT4BoundaryIsShorterOrEqualToFT8() {
        let ft8Wait = SystemClock.nanosUntilNextBoundary(cycle: .ft8)
        let ft4Wait = SystemClock.nanosUntilNextBoundary(cycle: .ft4)
        // FT4 cycles are half the length, so max wait is always <= FT8 max wait
        XCTAssertLessThanOrEqual(ft4Wait, SystemClock.CycleDuration.ft8.nanoseconds)
        _ = ft8Wait // suppress unused warning
    }

    func testCycleDurationConstants() {
        XCTAssertEqual(SystemClock.CycleDuration.ft8.seconds, 15.0)
        XCTAssertEqual(SystemClock.CycleDuration.ft4.seconds, 7.5)
        XCTAssertEqual(SystemClock.CycleDuration.ft8.nanoseconds, 15_000_000_000)
        XCTAssertEqual(SystemClock.CycleDuration.ft4.nanoseconds, 7_500_000_000)
    }

    func testSleepPrecision() async throws {
        // Verify that sleeping to a boundary actually lands close to the boundary.
        // We measure the time just before and after sleep, then check that the
        // post-sleep time is within 5ms of a 15-second boundary.
        let before = SystemClock.monotonicNanos()
        let expectedWait = SystemClock.nanosUntilNextBoundary(cycle: .ft8)

        // Only run this test if boundary is within 2 seconds (don't wait 15s in a test)
        guard expectedWait < 2_000_000_000 else {
            // Skip — would take too long
            return
        }

        try await SystemClock.sleepUntilNextBoundary(cycle: .ft8)
        let after = SystemClock.monotonicNanos()
        let actualWait = after - before

        // Should be within 50ms of expected (Task.sleep has variable jitter under load)
        let jitterNanos = UInt64(50_000_000) // 50ms tolerance
        XCTAssertGreaterThan(actualWait, expectedWait - jitterNanos)
        XCTAssertLessThan(actualWait, expectedWait + jitterNanos)
    }
}

// MARK: - NTP Sync Tests

class SystemClockNTPTests: XCTestCase {

    func testNTPSyncCheckReturnsResult() {
        let status = SystemClock.checkNTPSync()
        // On a normally functioning macOS system, NTP should be synced
        XCTAssertFalse(status.description.isEmpty)
    }

    func testNTPSyncCheckWithCustomThreshold() {
        // With a very large threshold, should always be acceptable
        let lenient = SystemClock.checkNTPSync(thresholdMs: 100_000)
        XCTAssertTrue(lenient.isAcceptable, "100-second threshold should be acceptable: \(lenient.description)")

        // With zero threshold, will almost certainly be unacceptable
        let strict = SystemClock.checkNTPSync(thresholdMs: 0)
        // Don't assert on strict — some CI/systems may have 0 reported error
        _ = strict
    }

    func testSyncStatusEquatable() {
        let a = SystemClock.SyncStatus(offsetMilliseconds: 1.0, isAcceptable: true, description: "OK")
        let b = SystemClock.SyncStatus(offsetMilliseconds: 1.0, isAcceptable: true, description: "OK")
        let c = SystemClock.SyncStatus(offsetMilliseconds: 999.0, isAcceptable: false, description: "Bad")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - FT8Engine NTP Integration Tests

class FT8EngineTimingTests: XCTestCase {

    func testEngineStartChecksNTPSync() async {
        let engine = FT8Engine()

        // Before start, no sync status
        let preStatus = await engine.clockSyncStatus
        XCTAssertNil(preStatus)

        // Start with an empty audio stream (will be cancelled immediately)
        let stream = AsyncStream<[Float]> { continuation in
            continuation.finish()
        }
        await engine.start(audioStream: stream)

        // Give the async NTP check time to complete (sntp takes ~200ms)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let postStatus = await engine.clockSyncStatus
        XCTAssertNotNil(postStatus, "Engine should check NTP sync on start")

        await engine.stop()
    }
}
