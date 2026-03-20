# HamStation Pro — V1 Implementation Spec
## macOS-Only Station Logger + Digital Modes + AI

**Version:** 1.0 (Phase 1-3 Implementation)
**Platform:** macOS 15+ only (iPadOS/iOS deferred to Phase 5)
**Language:** Swift 6, SwiftUI
**Architecture:** Single macOS app + single Swift Package
**Persistence:** GRDB/SQLite (primary), SwiftData (preferences only)
**Rig Control:** Network-first (rigctld TCP), no native Hamlib bridge
**License:** TBD — depends on GPL resolution (see Constraints)

> **Relationship to SPEC.md:** SPEC.md is the long-term vision document covering all platforms and all features. This document (V1-SPEC.md) is the implementation source of truth for Phases 1–3. Where they conflict, V1-SPEC.md wins. CC should read this file, not SPEC.md, during implementation.

---

## Table of Contents

1. [Constraints & Decisions](#1-constraints--decisions)
2. [Project Structure](#2-project-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [Data Models & Persistence](#4-data-models--persistence)
5. [Phase 1: The Station Logger](#5-phase-1-the-station-logger)
6. [Phase 2: The Signal Station](#6-phase-2-the-signal-station)
7. [Phase 3: The AI Station](#7-phase-3-the-ai-station)
8. [Design System](#8-design-system)
9. [Testing Strategy](#9-testing-strategy)
10. [Onboarding & First-Run](#10-onboarding--first-run)
11. [Privacy & Security](#11-privacy--security)
12. [External Dependencies](#12-external-dependencies)

---

## 1. Constraints & Decisions

These were locked during the engineering review on 2026-03-19. Do not revisit without explicit discussion.

### Platform: macOS Only
- No iOS, iPadOS, watchOS, or visionOS targets
- No conditional compilation for other platforms
- Use macOS-only APIs freely: multi-window, menu bar, IOKit serial, NSWindow
- No CloudKit sync — iCloud Drive file-level sync (ADIF export/import) is sufficient
- iPad/iPhone work begins in Phase 5 after macOS app is complete

### Persistence: Single GRDB Database
- **Primary store:** One GRDB/SQLite database (`hamstation.sqlite`) with domain-separated tables
- **SwiftData:** Only for app preferences and rig configurations (lightweight, not logbook)
- **No separate databases** for DXCC cache, callsign cache, etc. — all in one SQLite file
- **TLE data:** Flat files (not relational)
- **CloudKit:** Deferred entirely. Cross-device sync is not a v1 feature

### Rig Control: Network-First
- v1 supports only rigctld TCP protocol (and optionally FlexRadio SmartSDR API)
- No native Hamlib C bridge — users run `rigctld` locally
- This provides 400+ radio support without C library build system complexity
- The `RigConnection` protocol allows adding native Hamlib in a future phase
- No Bluetooth rig control (CoreBluetooth deferred)

### GPL Resolution: Must Decide Before Phase 2
Three options for FT8/digital mode libraries:
1. **Process isolation (recommended):** Run libjt9/libfldigi as separate helper processes. Main app communicates via XPC/Unix socket. Helper is GPL, app is MIT/Apache.
2. **Clean-room Swift implementation:** Implement FT8 encoder/decoder in pure Swift. Higher effort, eliminates dependency entirely.
3. **GPL the whole thing:** Simplest legal path. Distribute via Homebrew/GitHub Releases (not App Store).

**Decision required before writing any Phase 2 code.**

### Package Structure: Single Package
- One Swift Package: `HamStationKit`
- Contains both business logic and reusable SwiftUI components
- Split into `HamStationCore` + `HamStationUI` when multi-platform work begins (Phase 5)
- macOS app target imports `HamStationKit`

---

## 2. Project Structure

```
HamStation.xcworkspace
├── HamStationMac/                 # macOS app target
│   ├── HamStationApp.swift        # @main, WindowGroups, MenuBarExtra
│   ├── Windows/
│   │   ├── MainWindow.swift       # Primary operating window
│   │   ├── WaterfallWindow.swift  # Detachable waterfall (Phase 2)
│   │   └── LogbookWindow.swift    # Detachable logbook
│   ├── Onboarding/
│   │   └── FirstRunWizard.swift   # Setup wizard
│   └── Assets.xcassets
├── Packages/
│   └── HamStationKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── Models/            # GRDB record types
│       │   ├── Database/          # Schema, migrations, DatabaseManager actor
│       │   ├── ADIF/              # Parser, exporter, Cabrillo
│       │   ├── RigControl/        # RigConnection protocol, RigctldClient
│       │   ├── DXCluster/         # Telnet client, spot parser, filters
│       │   ├── CallsignLookup/    # Lookup pipeline, QRZ, HamDB
│       │   ├── Awards/            # DXCC engine, award tracking
│       │   ├── Propagation/       # NOAA client, solar dashboard data
│       │   ├── AudioEngine/       # AVAudioEngine, ring buffers (Phase 2)
│       │   ├── DigitalModes/      # FT8, CW, PSK31 (Phase 2)
│       │   ├── AI/                # Assistant, NL logging, privacy (Phase 3)
│       │   ├── Networking/        # ResilientClient, rate limiter
│       │   ├── UI/                # Shared SwiftUI components
│       │   │   ├── DesignSystem/  # Colors, typography, spacing
│       │   │   ├── LogbookTable/
│       │   │   ├── BandMap/
│       │   │   ├── WaterfallView/ # (Phase 2)
│       │   │   └── MapViews/
│       │   └── Utilities/         # Grid square calc, frequency helpers
│       └── Tests/
│           ├── ADIFTests/
│           │   └── Fixtures/      # Real-world ADIF files from major loggers
│           ├── ModelTests/
│           ├── RigControlTests/
│           ├── DXClusterTests/
│           ├── CallsignLookupTests/
│           └── NetworkingTests/
└── justfile                       # Build, test, lint, run tasks
```

---

## 3. Architecture Overview

### System Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                    macOS App (SwiftUI)                          │
│                                                                │
│  @MainActor ViewModels ──── observe ──── AsyncStream<State>    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐    │
│  │ Logbook  │ │ Cluster  │ │ Band Map │ │   Inspector   │    │
│  │ TableVM  │ │ SpotVM   │ │    VM    │ │   Panel VM    │    │
│  └─────┬────┘ └────┬─────┘ └────┬─────┘ └──────┬────────┘    │
│        │           │            │               │              │
├────────┼───────────┼────────────┼───────────────┼──────────────┤
│        ▼           ▼            ▼               ▼              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               HamStationKit (Swift Package)              │   │
│  │                                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │   │
│  │  │ DatabaseMgr  │  │ ClusterClient│  │ RigController │  │   │
│  │  │   (actor)    │  │   (actor)    │  │   (actor)     │  │   │
│  │  │ GRDB Pool    │  │ NWConnection │  │ NWConnection  │  │   │
│  │  └──────────────┘  └──────────────┘  └───────────────┘  │   │
│  │                                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐                      │   │
│  │  │ NetworkSvc   │  │ AudioEngine  │  (Phase 2)           │   │
│  │  │   (actor)    │  │   (actor)    │                      │   │
│  │  │ URLSession   │  │ AVAudioEng   │                      │   │
│  │  └──────────────┘  └──────────────┘                      │   │
│  └─────────────────────────────────────────────────────────┘   │
├────────────────────────────────────────────────────────────────┤
│  AVAudioEngine │ Metal │ Accelerate │ Network.fw │ MapKit     │
└────────────────────────────────────────────────────────────────┘
```

### Actor Topology

Five core actors, each owning one I/O boundary:

| Actor | Owns | Publishes |
|---|---|---|
| `DatabaseManager` | GRDB `DatabasePool` | `ValueObservation` streams for live queries |
| `RigController` | `NWConnection` to rigctld | `AsyncStream<RigState>` (freq, mode, PTT) |
| `ClusterClient` | `NWConnection` to DX cluster | `AsyncStream<DXSpot>` |
| `NetworkService` | `URLSession` for REST APIs | Per-request async results via `ResilientClient` |
| `AudioEngine` | `AVAudioEngine`, ring buffers | `AsyncStream<FFTData>`, `AsyncStream<DecodedMessage>` (Phase 2) |

### Concurrency Rules
- All ViewModels are `@MainActor` `@Observable` classes
- ViewModels consume actor streams via `Task` in `.task` modifiers
- Actors never touch UI. They only publish state via `AsyncStream`
- No `@Sendable` closures escaping actor isolation — use structured concurrency
- Swift 6 strict concurrency checking enabled from day one

---

## 4. Data Models & Persistence

### Single GRDB Database

All application data lives in `hamstation.sqlite` with domain-separated tables.

### Normalized QSO Schema

```
┌─────────────────────────────────────────────────────┐
│ qso (core — powers the logbook table)               │
│─────────────────────────────────────────────────────│
│ id: UUID (PK)                                       │
│ callsign: TEXT NOT NULL                              │
│ my_callsign: TEXT NOT NULL                           │
│ band: TEXT NOT NULL (Band enum raw value)            │
│ frequency_hz: REAL NOT NULL                          │
│ mode: TEXT NOT NULL (OperatingMode enum raw value)   │
│ datetime_on: TEXT NOT NULL (ISO 8601 UTC)            │
│ datetime_off: TEXT                                   │
│ rst_sent: TEXT NOT NULL                              │
│ rst_received: TEXT NOT NULL                          │
│ tx_power_watts: REAL                                 │
│ my_grid: TEXT                                        │
│ their_grid: TEXT                                     │
│ dxcc_entity_id: INTEGER (FK → dxcc_entity)          │
│ continent: TEXT                                      │
│ cq_zone: INTEGER                                    │
│ itu_zone: INTEGER                                   │
│ name: TEXT                                           │
│ qth: TEXT                                            │
│ comment: TEXT                                        │
│ logbook_id: UUID (FK → logbook)                     │
│ created_at: TEXT NOT NULL                            │
│ updated_at: TEXT NOT NULL                            │
│─────────────────────────────────────────────────────│
│ INDEXES: (datetime_on), (callsign), (band, mode),  │
│          (dxcc_entity_id), (logbook_id)             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ qso_extended (1:1 with qso — less-queried fields)   │
│─────────────────────────────────────────────────────│
│ qso_id: UUID (PK, FK → qso)                        │
│ propagation_mode: TEXT                               │
│ satellite_name: TEXT                                 │
│ satellite_mode: TEXT                                 │
│ contest_id: TEXT                                     │
│ contest_exchange_sent: TEXT                          │
│ contest_exchange_rcvd: TEXT                          │
│ sota_ref: TEXT                                       │
│ pota_ref: TEXT                                       │
│ wwff_ref: TEXT                                       │
│ my_county: TEXT                                      │
│ their_county: TEXT                                   │
│ qsl_sent: TEXT                                       │
│ qsl_received: TEXT                                   │
│ lotw_sent: INTEGER (bool)                            │
│ lotw_received: INTEGER (bool)                        │
│ eqsl_sent: INTEGER (bool)                            │
│ eqsl_received: INTEGER (bool)                        │
│ clublog_status: TEXT                                 │
│ adif_import_source: TEXT                             │
│ is_verified: INTEGER (bool)                          │
│ app_fields: TEXT (JSON — preserves unknown APP_ tags)│
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ qso_ai (1:1 with qso — AI-generated data, Phase 3) │
│─────────────────────────────────────────────────────│
│ qso_id: UUID (PK, FK → qso)                        │
│ ai_transcript: TEXT                                  │
│ signal_analysis_json: TEXT                           │
│ ai_notes: TEXT                                       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ qso_attachment (1:N with qso)                       │
│─────────────────────────────────────────────────────│
│ id: UUID (PK)                                       │
│ qso_id: UUID (FK → qso)                            │
│ file_path: TEXT NOT NULL (relative to app support)  │
│ file_type: TEXT NOT NULL (photo, document, audio)   │
│ caption: TEXT                                        │
│ created_at: TEXT NOT NULL                            │
└─────────────────────────────────────────────────────┘
```

### Reference Tables

```
┌─────────────────────────────────────┐
│ dxcc_entity                         │
│─────────────────────────────────────│
│ id: INTEGER (PK — DXCC entity #)   │
│ name: TEXT NOT NULL                  │
│ prefix: TEXT NOT NULL                │
│ continent: TEXT NOT NULL             │
│ cq_zone: INTEGER NOT NULL            │
│ itu_zone: INTEGER NOT NULL           │
│ latitude: REAL                       │
│ longitude: REAL                      │
│ is_deleted: INTEGER (bool)           │
│ updated_at: TEXT                     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ callsign_cache                      │
│─────────────────────────────────────│
│ callsign: TEXT (PK)                 │
│ name: TEXT                           │
│ qth: TEXT                            │
│ grid: TEXT                           │
│ country: TEXT                        │
│ state: TEXT                          │
│ county: TEXT                         │
│ email: TEXT                          │
│ lotw_member: INTEGER (bool)         │
│ source: TEXT (hamdb, qrz)           │
│ fetched_at: TEXT NOT NULL            │
│ expires_at: TEXT NOT NULL (30-day)  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ logbook                             │
│─────────────────────────────────────│
│ id: UUID (PK)                       │
│ name: TEXT NOT NULL                  │
│ description: TEXT                    │
│ is_default: INTEGER (bool)          │
│ created_at: TEXT NOT NULL            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ award_progress                      │
│─────────────────────────────────────│
│ id: UUID (PK)                       │
│ award_type: TEXT NOT NULL (DXCC,    │
│             WAS, WAZ, etc.)         │
│ band: TEXT                           │
│ mode: TEXT                           │
│ entity_or_ref: TEXT NOT NULL         │
│ worked: INTEGER (bool)              │
│ confirmed: INTEGER (bool)           │
│ qso_id: UUID (FK → qso)            │
│ confirmed_via: TEXT (lotw, eqsl,    │
│                card)                │
└─────────────────────────────────────┘
```

### GRDB Migration Strategy

```swift
var migrator = DatabaseMigrator()

migrator.registerMigration("v1_initial") { db in
    try db.create(table: "logbook") { t in ... }
    try db.create(table: "qso") { t in ... }
    try db.create(table: "qso_extended") { t in ... }
    try db.create(table: "dxcc_entity") { t in ... }
    try db.create(table: "callsign_cache") { t in ... }
    try db.create(table: "award_progress") { t in ... }
}

// Future migrations add tables, never remove columns
migrator.registerMigration("v2_qso_ai") { db in
    try db.create(table: "qso_ai") { t in ... }
}

migrator.registerMigration("v3_attachments") { db in
    try db.create(table: "qso_attachment") { t in ... }
}
```

**Migration safety rules:**
- Never delete columns — only add
- Always test migration from every previous version
- Backup database file before migration
- If migration fails, restore backup and show error to user (never silent corruption)

---

## 5. Phase 1: The Station Logger

### 5.1 ADIF Parser

The most critical code in the application. Imports from HRD, N1MM+, Log4OM, WSJT-X, LoTW.

**Requirements:**
- Full ADIF 3.1 field coverage (~130 standard fields)
- Two modes: strict (reject malformed) and lenient (best-effort with warnings)
- Round-trip fidelity: import → export produces identical output for valid ADIF
- Custom `APP_` field preservation — never drop unknown fields (stored in `qso_extended.app_fields` as JSON)
- Import report: "Imported 12,345 QSOs. 3 warnings: [details]. 0 errors."
- Streaming parser for large files (never load entire file into memory)
- Cabrillo export for contest log submission

**Architecture:**
```swift
// Streaming ADIF parser
struct ADIFParser {
    enum Mode { case strict, lenient }

    func parse(
        fileURL: URL,
        mode: Mode = .lenient
    ) -> AsyncThrowingStream<ADIFRecord, Error>

    struct ADIFRecord {
        var fields: [String: ADIFField]  // Preserves ALL fields including APP_
    }

    struct ADIFField {
        var name: String
        var value: String
        var type: ADIFDataType?
        var length: Int
    }
}

struct ADIFExporter {
    func export(
        qsos: AsyncStream<QSOExportRecord>,
        to url: URL,
        includeHeader: Bool = true
    ) async throws -> ExportReport
}
```

### 5.2 Callsign Lookup Pipeline

```
User inputs callsign
    → Local cache check (callsign_cache table, 30-day TTL)
    → HamDB free lookup (no API key required)
    → QRZ.com XML lookup (requires user's subscription key)
    → LoTW user check (is this callsign on LoTW?)
    → Return merged result

All network calls go through ResilientClient:
    → Exponential backoff retry (3 attempts, 1s/2s/4s)
    → Stale-data-OK: serve expired cache if fresh fetch fails
    → Rate limiter per service
    → Timeout: 10s per request
```

### 5.3 DX Cluster Client

```swift
actor ClusterClient {
    private var connection: NWConnection?

    func connect(host: String, port: Int, callsign: String) async throws

    // Publishes parsed spots
    var spotStream: AsyncStream<DXSpot> { get }

    // Auto-reconnect with exponential backoff on disconnect
    // Parse both AR-Cluster and DX Spider format spot lines
    // Skip malformed lines (log warning, never crash)
}
```

**Spot filtering engine:**
- By band, mode, continent, CQ zone, DXCC entity, callsign prefix
- Needed/worked filter (cross-reference award_progress table)
- Age filter (hide spots older than N minutes)
- Skimmer filter (exclude/include automated spots)

### 5.4 Rig Control (Network-First)

```swift
// Protocol abstraction — allows adding Hamlib native, FlexRadio, etc. later
protocol RigConnection: Actor {
    func connect() async throws
    func disconnect() async

    func setFrequency(_ hz: Double) async throws
    func getFrequency() async throws -> Double
    func setMode(_ mode: OperatingMode) async throws
    func getMode() async throws -> OperatingMode
    func setPTT(_ on: Bool) async throws

    var stateStream: AsyncStream<RigState> { get }
    var connectionState: ConnectionState { get }
}

struct RigState: Sendable {
    var frequency: Double
    var mode: OperatingMode
    var pttActive: Bool
    var signalStrength: Int?
}

// v1 implementation
actor RigctldConnection: RigConnection {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16

    // rigctld text protocol: "F 14074000\n" → set freq
    // "f\n" → get freq, responds "14074000\n"
    // Poll frequency at 10Hz (100ms interval)
    // Auto-reconnect on disconnect with backoff
}
```

### 5.5 macOS UI

```
┌────────────────────────────────────────────────────────────────────┐
│ Toolbar: [Callsign] [Freq: 14.074] [Mode: FT8] [Band: 20m] [PWR] │
├──────────────┬─────────────────────────────┬───────────────────────┤
│              │                             │                       │
│  Navigator   │    Main Content Area        │   Inspector / Info    │
│              │                             │                       │
│  ● Logbook   │  (Context-dependent:        │  Callsign lookup      │
│  ● DX Cluster│   Logbook table,            │  DXCC info            │
│  ● Band Map  │   DX spot list,             │  Award status         │
│  ● Awards    │   Band map,                 │  QRZ.com data         │
│  ● Propagation  Award matrix)             │  Solar conditions     │
│  ● Tools     │                             │                       │
│              │                             │                       │
├──────────────┴─────────────────────────────┴───────────────────────┤
│  Status bar: [QSOs today: 23] [Rate: 48/hr] [K=2 SFI=145] [Rig ✓]│
└────────────────────────────────────────────────────────────────────┘
```

**Table performance:**
- Paginated GRDB fetching: 500 rows per page
- `ValueObservation` for live updates (new QSOs appear automatically)
- Only fetch columns needed for table display (core `qso` table only)
- Inspector panel lazy-fetches full detail (`qso_extended`, `qso_ai`) on selection
- Performance target: 100K rows, sort by date, time-to-first-paint < 200ms

### 5.6 Band Map

Frequency-axis display showing active DX spots on the current band. Spots appear as labeled markers on a frequency ruler.

- Clicking a spot → tunes rig (via `RigController`) and pre-fills logging form
- Current rig frequency shown as a highlighted cursor
- Color coding: needed (green), worked-not-confirmed (yellow), confirmed (grey)
- Zoom and pan on the frequency axis

### 5.7 Awards Tracking (Phase 1 — DXCC + WAS)

- DXCC entity resolution: callsign prefix → entity (handle maritime mobile, special event)
- Worked/confirmed matrix by band and mode
- Generate "needed list" for DX cluster filtering
- Progress display: "87/100 DXCC Mixed, 45/50 WAS"

---

## 6. Phase 2: The Signal Station

**Prerequisite: GPL resolution must be complete before Phase 2 begins.**

### 6.1 Audio Pipeline Architecture

```
Audio Input (real-time thread — NEVER blocks)
    │
    ├── AVAudioEngine Tap
    │   ├── Copy to FFT Ring Buffer ──→ [Ring Buffer] ──→ FFT Worker (async)
    │   │                                                    │
    │   │                                                    ▼
    │   │                                            Waterfall Renderer (GPU)
    │   │
    │   ├── Bandpass Filter → Audio Output (real-time, speaker/headphones)
    │   │
    │   └── Copy to Decode Ring Buffer ──→ [Ring Buffer] ──→ Decoder (async)
    │                                                          │
    │                                                          ├── FT8 Decoder
    │                                                          ├── CW Decoder
    │                                                          └── PSK31 Decoder
    │
    └── (Transmit path)
        Microphone / CW keyer → Encoder → TX Level → Audio Output (USB interface)
```

**Key design rules:**
- Audio callback thread NEVER allocates, locks, or awaits
- Ring buffers between real-time and async stages
- Decoders read from ring buffer; if behind, they skip old data (drop policy)
- Waterfall reads latest available FFT data (no queuing — always show newest)
- Sample rate negotiation on device connect/disconnect
- Graceful handling: device unplug, permission failure, underrun detection

### 6.2 Metal Waterfall Renderer

- 4096-point FFT via Accelerate vDSP
- Rolling texture in Metal (4096 x 1024 circular buffer)
- Fragment shader maps power → color via palette texture
- 60fps target on Apple Silicon
- Palettes: CuteSDR, Rainbow, Greyscale, Night (deep red)
- Click-to-tune: click on waterfall → set rig frequency
- Mode bandwidth overlay (shaded region for current filter width)

### 6.3 FT8 Engine

Implementation depends on GPL resolution:
- **If process isolation:** Run libjt9 as XPC helper. Main app sends audio buffers via XPC, receives decoded messages.
- **If clean-room:** Pure Swift FT8 encoder/decoder. Reference: ft8_lib (C), publicly documented protocol.

**Timing requirements:**
- FT8 operates in 15-second cycles synchronized to UTC
- Use `mach_absolute_time()` (not `Date`) for sub-millisecond timing
- Audio capture window: exactly 12.64 seconds of 48kHz audio per cycle
- Decode budget: < 2 seconds after capture window closes
- PTT turnaround: < 200ms from decode-complete to transmit-start
- NTP sync check: warn user if system clock is off by > 500ms

### 6.4 CW Engine

**Sending:**
- Software iambic keyer (A/B modes) via hardware paddle input
- Keyboard-to-CW with adjustable speed (5-50 WPM)
- Memory keyer: configurable F-key macros
- Low-latency: CoreAudio directly, 64-frame buffer (< 5ms)

**Receiving (traditional DSP):**
- Goertzel algorithm for tone detection (single-frequency, more efficient than FFT)
- Adaptive threshold with noise floor tracking
- Speed tracking: auto-adjusts expected dit/dah duration
- Narrow bandpass filter (100-200Hz) centered on CW tone

### 6.5 Propagation Dashboard

- NOAA SWPC data: SFI, A-index, K-index, X-ray flux, proton flux
- Grey line map via MapKit with custom overlay
- Sunrise/sunset times for operator's QTH and target location
- PSK Reporter integration: live signal reports
- All data fetched via `ResilientClient` with stale-data-OK policy

---

## 7. Phase 3: The AI Station

### 7.1 AI Privacy Model (Mandatory — implement before any AI features)

**Principle: Explicit opt-in with granular consent.**

```
AI Features Settings:
├── [ ] Enable AI Assistant (requires Anthropic API key)
│   ├── [ ] Include my callsign in context
│   ├── [ ] Include my location (grid square)
│   ├── [ ] Include my award progress
│   ├── [ ] Include recent QSO history
│   └── API Key: [stored in Keychain]
├── [ ] Enable natural language logging (on-device speech recognition)
└── [ ] Enable smart log analysis (on-device only, no cloud)
```

**Rules:**
- No AI data sent without user action (never background-send)
- User can see exactly what context will be included before each AI request
- On-device features (speech recognition, Core ML models) never send data to cloud
- Cloud AI features gracefully degrade to "unavailable" when offline
- Anthropic API key stored in macOS Keychain, never in preferences or plaintext

### 7.2 Core ML CW Decoder

- 1D CNN model on audio spectrograms
- Runs on Apple Neural Engine (all Apple Silicon)
- Parallel with traditional DSP decoder; ML takes precedence when DSP confidence < 0.7
- Training data: synthetic CW audio at varying speeds (5-50 WPM), noise levels (-10dB to +20dB SNR), fist styles
- Target: < 2ms inference latency per 512-sample window

### 7.3 AI Assistant

- Claude API with ham radio system prompt
- Context includes only user-consented data (per privacy model)
- Supports: natural language logging, band advice, pile-up coaching, QSL routing, award analysis
- Offline behavior: assistant tab shows "AI unavailable — no network" (no error spam, no retry loop)

### 7.4 Audio Enhancement

- Core ML U-Net denoiser for SSB/CW audio
- Runs as AVAudioUnit in the DSP chain
- On-device only — audio never leaves the device
- User control: 0-100% slider, presets: "HF SSB", "Weak CW", "Local FM"

---

## 8. Design System

### Typography
- **SF Pro:** All UI text
- **SF Mono:** Frequencies, callsigns, decoded text, RST reports, grid squares

### Colors
- **Accent:** Ham radio orange `#FF6A00`
- **Light mode:** Standard macOS light appearance
- **Dark mode:** Standard macOS dark appearance
- **Night mode:** Deep red theme `#8B0000` for dark-adapted vision during nighttime operating. No white or bright elements. All text, borders, and icons use shades of red.

### Layout
- macOS compact spacing (experienced operators want information density)
- Minimum window size: 1200 x 800
- Sidebar: 220pt default width, collapsible
- Inspector: 300pt default width, collapsible

### Iconography
- SF Symbols throughout
- Custom SF Symbols for: antenna, paddle, waterfall (create as SVG → SF Symbol template)

---

## 9. Testing Strategy

### Framework
- Swift Testing (`import Testing`) for all tests
- XCTest only if Swift Testing lacks a needed feature

### ADIF Parser Tests (highest priority)
- `Tests/Fixtures/ADIF/` directory with real-world files from:
  - ADIF 3.1 specification examples
  - WSJT-X exports
  - LoTW downloads
  - Community-contributed files from HRD, N1MM+, Log4OM
- Each fixture has a companion `.expected.json` with field expectations
- Round-trip tests: import → export → re-import = identical
- Fuzz testing: random malformed ADIF to find crash paths
- Performance test: 100K QSO streaming import benchmark
- **Target: 200+ ADIF parser tests**

### Database Tests
- CRUD operations on all tables
- Migration tests: every version → latest
- Backup/restore on migration failure
- 100K row query performance benchmarks
- Concurrent read/write safety

### Rig Control Tests
- Mock rigctld server for protocol testing
- Connect/disconnect/reconnect cycles
- Malformed response handling
- Timeout behavior

### DX Cluster Tests
- Sample spot lines from AR-Cluster, DX Spider, CC Cluster
- Malformed line handling (skip, don't crash)
- Filter engine with various combinations
- Reconnect behavior

### Network Resilience Tests
- `ResilientClient` retry behavior
- Stale-data-OK fallback
- Rate limiter queuing
- Timeout handling
- Offline mode (no network)

### UI Tests
- Logbook table CRUD operations
- First-run wizard flow
- Keyboard navigation (all functions accessible)
- 100K row table performance

---

## 10. Onboarding & First-Run

### First-Run Wizard

The wizard runs on first launch (or when no user profile exists). It is the demo path — the first thing your buddy sees.

**Step 1: Welcome**
- "Welcome to HamStation Pro"
- Brief value proposition (one sentence)

**Step 2: Operator Profile**
- Callsign (required — validates format: 1-2 letter prefix + digit + 1-3 letter suffix)
- License class (Technician / General / Extra — constrains visible bands)
- Grid square (Maidenhead — validates 4 or 6 character format)
- Name (optional)

**Step 3: Import Logbook (optional)**
- "Import from another logger?"
- File picker for ADIF file
- Parse and show preview: "Found 12,345 QSOs from 2019-2024. 3 warnings."
- Confirm import
- Or skip: "Start with an empty logbook"

**Step 4: Rig Setup (optional)**
- "Connect to your radio?"
- Enter rigctld host and port (default: localhost:4532)
- Test connection button → shows rig model + current frequency on success
- Or skip: "I'll set this up later"

**Step 5: DX Cluster (optional)**
- "Connect to a DX cluster?"
- Pre-populated list of popular clusters (with ping times)
- Test connection
- Or skip

**Step 6: Done**
- Summary of what was configured
- "Open HamStation Pro" → main window

---

## 11. Privacy & Security

### Data Classification

| Data type | Storage | Sent to cloud? | User consent? |
|---|---|---|---|
| QSO logbook | Local SQLite | No | N/A |
| Callsign lookup cache | Local SQLite | Lookup query sent to HamDB/QRZ | Implicit (user initiates lookup) |
| QRZ/LoTW credentials | macOS Keychain | Auth only to respective services | User enters credentials |
| AI assistant context | Not stored | Sent to Anthropic API if enabled | Explicit opt-in per data type |
| Audio (for AI enhancement) | Not stored | Never | N/A (on-device Core ML) |
| Rig state | Memory only | No | N/A |
| DX cluster spots | Memory + display | No (received from cluster) | N/A |

### Keychain Usage
All credentials stored in macOS Keychain via `Security.framework`:
- QRZ.com XML API key
- LoTW certificate path / password
- ClubLog API key
- Anthropic API key (for AI assistant)

### Network
- All HTTPS connections use TLS 1.2+
- Telnet connections (DX cluster, rigctld) are plaintext — standard in ham radio, documented to user
- No advertising, no telemetry, no analytics

---

## 12. External Dependencies

### Swift Packages

| Package | License | Purpose |
|---|---|---|
| GRDB.swift | MIT | SQLite persistence (primary database) |

### External Services (via ResilientClient)

| Service | Protocol | Auth | Phase |
|---|---|---|---|
| HamDB | REST/HTTPS | None (free) | 1 |
| QRZ.com | XML/HTTPS | User's API key | 1 |
| LoTW | HTTPS | User's certificate | 1 |
| DX Cluster | Telnet | Callsign login | 1 |
| rigctld | TCP (text protocol) | None (local) | 1 |
| NOAA SWPC | REST/HTTPS | None (public) | 1 |
| PSK Reporter | REST/HTTPS | None (public) | 2 |
| WSPRnet | REST/HTTPS | None (public) | 2 |
| Anthropic API | REST/HTTPS | User's API key | 3 |
| SOTA API | REST/HTTPS | None (public) | 4 |
| POTA API | REST/HTTPS | None (public) | 4 |
| RepeaterBook | REST/HTTPS | None (public) | 4 |
| Celestrak | HTTPS | None (public) | 4 |

### GPL-Licensed Libraries (Phase 2 — requires resolution)

| Library | License | Resolution strategy |
|---|---|---|
| libjt9 (WSJT-X) | GPLv3 | Process isolation (XPC) or clean-room Swift |
| libfldigi | GPLv3 | Process isolation (XPC) or clean-room Swift |
| NEC2C | Public Domain | Direct integration (no license concern) |

### Not Used in V1

| Library | Reason deferred |
|---|---|
| Hamlib (C) | Network-first rig control via rigctld |
| ORSSerialPort | No direct serial in v1 (rigctld handles it) |
| KeychainAccess | Use Security.framework directly |

---

*HamStation Pro V1-SPEC.md — Implementation source of truth for Phases 1-3*
*Locked by /plan-eng-review on 2026-03-19*
*73 de the development team*
