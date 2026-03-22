// SystemClock.swift
// HamStationKit — High-precision timing for real-time digital mode operations.
// Uses mach_absolute_time() for sub-microsecond monotonic timing and
// provides UTC cycle boundary synchronization for FT8/FT4.

import Foundation
import Darwin

/// High-precision system clock for real-time digital mode timing.
///
/// FT8 operates in 15-second cycles synchronized to UTC with 160ms symbol periods.
/// Foundation's `Date` and `Calendar` are insufficient for this — `Calendar.component()`
/// loses nanosecond precision and involves locale-dependent overhead. This clock uses
/// `mach_absolute_time()` for monotonic timing and `clock_gettime(CLOCK_REALTIME)` for
/// sub-microsecond UTC alignment.
public struct SystemClock: Sendable {

    /// Cycle duration for FT8 (15 seconds) and FT4 (7.5 seconds).
    public enum CycleDuration: Sendable {
        case ft8  // 15.0 seconds
        case ft4  // 7.5 seconds

        public var seconds: Double {
            switch self {
            case .ft8: return 15.0
            case .ft4: return 7.5
            }
        }

        public var nanoseconds: UInt64 {
            switch self {
            case .ft8: return 15_000_000_000
            case .ft4: return 7_500_000_000
            }
        }
    }

    // MARK: - Mach time base

    /// Cached mach timebase info for converting ticks to nanoseconds.
    @usableFromInline
    static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Convert mach absolute time ticks to nanoseconds.
    @inlinable
    public static func machTicksToNanos(_ ticks: UInt64) -> UInt64 {
        return ticks * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }

    /// Current monotonic time in nanoseconds (not wall-clock).
    @inlinable
    public static func monotonicNanos() -> UInt64 {
        machTicksToNanos(mach_absolute_time())
    }

    // MARK: - UTC wall-clock (sub-microsecond)

    /// Current UTC time as nanoseconds since Unix epoch.
    ///
    /// Uses `clock_gettime(CLOCK_REALTIME)` which provides nanosecond resolution,
    /// unlike `Date()` which internally uses `gettimeofday` (microsecond resolution)
    /// and then adds Calendar overhead when extracting components.
    public static func utcNanosSinceEpoch() -> UInt64 {
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
    }

    /// Current UTC time decomposed into seconds-of-minute and sub-second nanoseconds.
    ///
    /// This avoids `Calendar.component()` entirely — we extract the second directly
    /// from the Unix timestamp using modular arithmetic.
    public static func utcSecondAndNanos() -> (secondOfMinute: Int, nanosecond: UInt64) {
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        let secondOfMinute = ts.tv_sec % 60
        let nanos = UInt64(ts.tv_nsec)
        return (Int(secondOfMinute), nanos)
    }

    // MARK: - Cycle boundary

    /// Calculate nanoseconds until the next FT8/FT4 cycle boundary.
    ///
    /// FT8 cycles start at 0, 15, 30, 45 seconds of each minute.
    /// FT4 cycles start at 0, 7.5, 15, 22.5, 30, 37.5, 45, 52.5 seconds.
    ///
    /// - Parameter cycle: The cycle duration (.ft8 or .ft4).
    /// - Returns: Nanoseconds until the next cycle boundary.
    public static func nanosUntilNextBoundary(cycle: CycleDuration = .ft8) -> UInt64 {
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)

        let secondOfMinute = ts.tv_sec % 60
        let nanos = UInt64(ts.tv_nsec)

        let cycleSeconds = Int(cycle.seconds)

        switch cycle {
        case .ft8:
            // Boundaries at 0, 15, 30, 45
            let currentSlot = Int(secondOfMinute) / cycleSeconds
            let nextBoundarySecond = (currentSlot + 1) * cycleSeconds
            let wholeSecondsToWait = UInt64(nextBoundarySecond - Int(secondOfMinute))
            // Subtract the sub-second portion we've already passed
            if nanos > 0 {
                return wholeSecondsToWait * 1_000_000_000 - nanos
            }
            return wholeSecondsToWait * 1_000_000_000

        case .ft4:
            // Boundaries at 0.0, 7.5, 15.0, 22.5, 30.0, 37.5, 45.0, 52.5
            let totalNanosInMinuteSlot = UInt64(secondOfMinute) * 1_000_000_000 + nanos
            let cycleNanos = cycle.nanoseconds
            let currentSlotNanos = totalNanosInMinuteSlot % cycleNanos
            return cycleNanos - currentSlotNanos
        }
    }

    /// Sleep until the next FT8/FT4 cycle boundary using nanosecond-precision Task.sleep.
    ///
    /// - Parameter cycle: The cycle duration (.ft8 or .ft4).
    public static func sleepUntilNextBoundary(cycle: CycleDuration = .ft8) async throws {
        let waitNanos = nanosUntilNextBoundary(cycle: cycle)
        try await Task.sleep(nanoseconds: waitNanos)
    }

    // MARK: - NTP sync check

    /// Result of an NTP sync check.
    public struct SyncStatus: Sendable, Equatable {
        /// Estimated offset from true UTC in milliseconds (positive = ahead).
        public var offsetMilliseconds: Double
        /// Whether the offset exceeds the acceptable threshold.
        public var isAcceptable: Bool
        /// Human-readable description.
        public var description: String
    }

    /// Check whether the system clock is synchronized closely enough for FT8.
    ///
    /// On macOS, `timed`/`chronyd` keeps the system clock synchronized via NTP.
    /// We run `sntp -S time.apple.com` to query the current offset. If the offset
    /// exceeds 500ms, FT8 decoding will fail because the receive window won't
    /// align with the transmitter's cycle.
    ///
    /// Falls back to "assumed OK" if `sntp` is unavailable or fails, since macOS
    /// normally keeps the clock synced via System Preferences > Date & Time.
    ///
    /// - Parameter thresholdMs: Maximum acceptable offset in milliseconds. Default 500.
    /// - Returns: A `SyncStatus` describing the clock state.
    public static func checkNTPSync(thresholdMs: Double = 500) -> SyncStatus {
        // Use sntp to query NTP offset. This is available on all macOS versions.
        // Output looks like: "+0.003241 +/- 0.024390 time.apple.com ..."
        // The first field is the offset in seconds (+ means local clock is ahead).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sntp")
        process.arguments = ["-S", "time.apple.com"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // discard stderr

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return assumeSynced(thresholdMs: thresholdMs)
            }

            // Parse offset from first field: "+0.003241" or "-0.512000"
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let fields = trimmed.split(separator: " ")
            guard let firstField = fields.first,
                  let offsetSeconds = Double(firstField) else {
                return assumeSynced(thresholdMs: thresholdMs)
            }

            let offsetMs = abs(offsetSeconds) * 1000.0
            let acceptable = offsetMs < thresholdMs
            let desc: String
            if acceptable {
                desc = String(format: "Clock synchronized (%.1fms offset from NTP)", offsetMs)
            } else {
                desc = String(format: "Clock offset %.0fms exceeds %.0fms threshold — FT8 requires accurate time. Check System Preferences > Date & Time.",
                              offsetMs, thresholdMs)
            }

            return SyncStatus(
                offsetMilliseconds: offsetMs,
                isAcceptable: acceptable,
                description: desc
            )
        } catch {
            return assumeSynced(thresholdMs: thresholdMs)
        }
    }

    /// Fallback when sntp is unavailable — assume the clock is synced since
    /// macOS enables NTP by default.
    private static func assumeSynced(thresholdMs: Double) -> SyncStatus {
        SyncStatus(
            offsetMilliseconds: 0,
            isAcceptable: true,
            description: "NTP check unavailable — assuming clock is synchronized. Verify in System Preferences > Date & Time."
        )
    }
}
