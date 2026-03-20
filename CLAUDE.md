# HamStation Pro

## Implementation Source of Truth

**Read V1-SPEC.md, not SPEC.md.** SPEC.md is the long-term vision (all platforms, all features). V1-SPEC.md is the implementation spec for the current build (macOS-only, Phases 1-3). Where they conflict, V1-SPEC.md wins.

## Locked Architecture Decisions

These were locked during engineering review on 2026-03-19. Do not change without explicit discussion.

- **macOS only.** No iOS, iPadOS, watchOS targets. No conditional compilation for other platforms. No CloudKit.
- **GRDB/SQLite primary persistence.** Single `hamstation.sqlite` database with domain-separated tables. SwiftData only for app preferences and rig configs.
- **Normalized QSO schema.** `qso` (core fields), `qso_extended` (1:1, less-queried), `qso_ai` (1:1, Phase 3), `qso_attachment` (1:N). See V1-SPEC.md Section 4.
- **Network-first rig control.** rigctld TCP protocol only in v1. No native Hamlib C bridge. `RigConnection` protocol allows future backends.
- **Five core actors:** `DatabaseManager`, `RigController`, `ClusterClient`, `NetworkService`, `AudioEngine` (Phase 2). Each owns one I/O boundary. ViewModels are `@MainActor @Observable`.
- **Split audio pipeline (Phase 2).** Ring buffers between real-time audio thread and async decoders. Audio callback never allocates, locks, or awaits.
- **Single Swift Package.** `HamStationKit` contains all business logic and shared UI. Split into Core + UI when multi-platform starts.
- **ResilientClient** for all external API calls. Retry with backoff, stale-data-OK fallback, rate limiting per service.
- **AI privacy: explicit opt-in** with granular consent per data type. No cloud data sent without user action.
- **GPL resolved: MIT-only stack.** FT8 via ft8_lib (MIT, github.com/kgoba/ft8_lib). PSK31/RTTY via liquid-dsp (MIT). No GPL dependencies. App licensed MIT/Apache 2.0. Mac App Store compatible.

## Swift 6 Strict Concurrency

- `StrictConcurrency` is enabled. All code must compile with Swift 6 strict checking.
- All ViewModels are `@MainActor @Observable`.
- Actors publish state via `AsyncStream`. ViewModels consume in `.task` modifiers.
- No `@Sendable` closures escaping actor isolation — use structured concurrency.

## Testing

- Use XCTest (Swift Testing macros broken on Xcode 26.3 beta).
- ADIF parser is the most tested code: 200+ tests with real-world fixture files in `Tests/Fixtures/ADIF/`.
- All external service interactions tested via `ResilientClient` mock.
- Performance tests for 100K QSO operations.

## Build & Run

Use the justfile for all build/test/run tasks. Keep it updated as new tasks are added.

## Dependencies

- **GRDB.swift** (MIT) — SQLite persistence
- **ft8_lib** (MIT) — FT8/FT4 encoding/decoding (C library, Swift bridge)
- **liquid-dsp** (MIT) — PSK31/RTTY modulation/demodulation (planned)
- External services accessed via REST/telnet through `ResilientClient` / `Network.framework`
- `SWIFT_EXEC=/usr/bin/swiftc` required for SPM on Xcode 26.3 (set in justfile)

## Design System

- SF Pro for text, SF Mono for data (frequencies, callsigns, RST, grids)
- Accent: `#FF6A00` (ham radio orange)
- Night mode: `#8B0000` (deep red for dark-adapted vision)
- macOS compact spacing for information density
