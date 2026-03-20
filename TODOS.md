# TODOS

## High Priority

### ~~Resolve GPL licensing strategy~~ ✅ RESOLVED (2026-03-20)
**Decision:** Use ft8_lib (MIT) for FT8/FT4, liquid-dsp (MIT) for PSK31/RTTY. No GPL dependencies. Whole app licensed MIT/Apache 2.0. Mac App Store compatible.
**Evidence:** ft8_lib already ships in HotPaw FT8 Decoder on iOS App Store. FSF's "intimate communication" test for process isolation is subjective and untested in court — ft8_lib avoids the question entirely.
**Libraries:** ft8_lib (MIT, github.com/kgoba/ft8_lib), liquid-dsp (MIT, github.com/jgaeddert/liquid-dsp), libcorrect (BSD, github.com/quiet/libcorrect)

### Integrate ft8_lib for FT8/FT4 decoding
**What:** Add ft8_lib (MIT, C library) as a Swift Package dependency or git submodule. Create a Swift bridging layer (`FT8Engine`) that calls ft8_lib's encode/decode functions. Wire to the audio engine's decode ring buffer.
**Why:** FT8 is the dominant digital mode. This unblocks the most-requested Phase 2 feature.
**Pros:** MIT license, proven on iOS (HotPaw), small C library (~2K lines), well-documented protocol.
**Cons:** Need to wrap C API in Swift actor. Need precise 15-second timing synchronization.
**Context:** Use mach_absolute_time() for sub-ms timing, not Date/Task.sleep. Audio capture window: 12.64s of 48kHz. Decode budget: <2s.
**Depends on:** AudioEngine (done), ring buffers (done).

### Add disk-full and migration-failure error handling
**What:** DatabaseManager must handle SQLite SQLITE_FULL errors and schema migration failures with backup-before-migrate + restore-on-failure + user alert.
**Why:** Silent database corruption or data loss is the worst possible failure for a logbook app. These are rare but catastrophic.
**Pros:** Prevents the "your buddy loses 10 years of QSOs" scenario.
**Cons:** ~15 min CC time. Tests need to simulate disk-full (mock) and broken migrations.
**Context:** GRDB's migrator supports `eraseDatabaseOnSchemaChange` but that destroys data. The correct pattern is: (1) backup .sqlite file before migration, (2) attempt migration, (3) if it fails, restore backup and show error alert with "Export as ADIF" option. For disk-full: catch SQLITE_FULL, show alert, suggest freeing disk space.
**Depends on:** DatabaseManager actor implementation (done).

## Medium Priority

### Implement PSK31/RTTY using liquid-dsp
**What:** Use liquid-dsp (MIT) for PSK31 and RTTY modulation/demodulation. Create Swift wrappers for BPSK/DBPSK demodulator and Baudot/RTTY decoder.
**Why:** PSK31 and RTTY are popular digital modes, especially for contesting (RTTY) and ragchewing (PSK31).
**Context:** liquid-dsp provides modem objects for PSK. PSK31 uses varicode encoding with DBPSK modulation at 31.25 baud. RTTY uses FSK with Baudot code at 45.45 baud.
**Depends on:** AudioEngine (done), liquid-dsp integration.

### Source real-world ADIF test fixtures
**What:** Collect ADIF export files from HRD, N1MM+, Log4OM, WSJT-X, LoTW, and rumlog. Add to `Tests/Fixtures/ADIF/` with companion `.expected.json` files.
**Why:** Real-world ADIF files have encoding quirks, non-standard fields, and date format variations that synthetic tests miss.
**Depends on:** Nothing — can collect in parallel.

## Low Priority

### Phase 5: iOS/iPad port
**What:** Add iOS and iPadOS targets using NavigationSplitView (iPad) and TabView (iPhone). CloudKit sync for cross-device logbook. Widgets, Live Activities, Siri Shortcuts.
**Depends on:** macOS app stable and feature-complete.
