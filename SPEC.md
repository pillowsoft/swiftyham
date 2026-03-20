# HamStation Pro — Technical Specification
## AI-Powered Amateur Radio Suite for Apple Platforms

**Version:** 1.0 Draft  
**Platforms:** macOS 15+, iOS 18+, iPadOS 18+  
**Language:** Swift 6, SwiftUI  
**Architecture:** Multi-platform Swift Package + platform-specific targets

---

## Table of Contents

1. [Vision & Product Overview](#1-vision--product-overview)
2. [Platform Strategy](#2-platform-strategy)
3. [High-Level Architecture](#3-high-level-architecture)
4. [Swift Package Structure](#4-swift-package-structure)
5. [Data Models](#5-data-models)
6. [Feature Modules](#6-feature-modules)
   - 6.1 [Logbook & QSO Management](#61-logbook--qso-management)
   - 6.2 [Rig Control (CAT)](#62-rig-control-cat)
   - 6.3 [Audio Engine & DSP](#63-audio-engine--dsp)
   - 6.4 [Waterfall & Spectrum Display](#64-waterfall--spectrum-display)
   - 6.5 [Digital Modes](#65-digital-modes)
   - 6.6 [CW (Morse Code)](#66-cw-morse-code)
   - 6.7 [AI Director & Assistant](#67-ai-director--assistant)
   - 6.8 [Propagation & Band Conditions](#68-propagation--band-conditions)
   - 6.9 [DX Cluster & Spotting](#69-dx-cluster--spotting)
   - 6.10 [Awards & DXCC Tracking](#610-awards--dxcc-tracking)
   - 6.11 [Satellite Tracking](#611-satellite-tracking)
   - 6.12 [Antenna Modeling & Tools](#612-antenna-modeling--tools)
   - 6.13 [APRS](#613-aprs)
   - 6.14 [Emergency Communications (EmComm)](#614-emergency-communications-emcomm)
   - 6.15 [Contesting](#615-contesting)
   - 6.16 [Repeater Directory](#616-repeater-directory)
7. [AI & Machine Learning Features](#7-ai--machine-learning-features)
8. [Apple Technology Integration](#8-apple-technology-integration)
9. [SwiftUI Architecture & Navigation](#9-swiftui-architecture--navigation)
10. [Persistence & Sync](#10-persistence--sync)
11. [Networking & Protocols](#11-networking--protocols)
12. [Hardware Interfaces](#12-hardware-interfaces)
13. [Accessibility](#13-accessibility)
14. [Privacy & Security](#14-privacy--security)
15. [Testing Strategy](#15-testing-strategy)
16. [Phased Roadmap](#16-phased-roadmap)

---

## 1. Vision & Product Overview

HamStation Pro is a modern, AI-native amateur radio suite built exclusively for Apple platforms. It replaces the fragmented ecosystem of aging, single-purpose ham radio tools with a unified, intelligent application that feels native on every Apple device — from a MacBook Neo in a home shack to an iPhone in a backpack during a SOTA activation.

### Core Differentiators

- **AI-first design**: Neural Engine-accelerated CW decoding, real-time audio enhancement, and an LLM-powered assistant that understands amateur radio context
- **Genuinely native**: SwiftUI throughout, Metal for signal visualization, Core ML for on-device inference — not a web wrapper or Electron port
- **Cross-device continuity**: Full feature set on Mac; intelligent subsets on iPhone and iPad with Handoff, Continuity, and iCloud sync
- **Modern Swift concurrency**: Swift 6 strict concurrency, actors for radio I/O, structured concurrency for signal processing pipelines

### Target Users

- Licensed amateur radio operators (Technician through Extra class)
- Contest operators requiring high-speed logging
- DX chasers tracking award progress
- SOTA/POTA portable operators
- EmComm volunteers needing reliable field tools
- New hams learning the hobby

---

## 2. Platform Strategy

### macOS (Full Feature Set)
The primary platform. Runs in a full multi-window, menu-bar-driven environment. Has access to all hardware interfaces: USB audio, serial/USB CAT control, SDR hardware via local sidecar processes.

**Minimum:** macOS 15 Sequoia  
**Optimized for:** MacBook Neo (A18 Pro), MacBook Air M-series, Mac mini, iMac

### iPadOS (Near-Full Feature Set)
Tablet-optimized layout. Full logbook, digital modes via audio interface (Lightning/USB-C to audio adapter), rig control via USB-C or Bluetooth, all AI features. Missing: multi-window SDR waterfall, complex antenna modeling.

**Minimum:** iPadOS 18  
**Optimized for:** iPad Pro M-series, iPad Air M-series

### iOS / iPhone (Portable Companion)
Focused on portable operation. Logbook, DX cluster alerts, propagation conditions, APRS, SOTA/POTA tools, award tracking, repeater directory, and the AI assistant. Full Handoff with Mac/iPad.

**Minimum:** iOS 18  
**Optimized for:** iPhone 16 / 17 series (Dynamic Island integration)

### Feature Matrix

| Feature | macOS | iPadOS | iOS |
|---|---|---|---|
| Full Logbook | ✅ | ✅ | ✅ |
| CAT Rig Control (USB) | ✅ | ✅ | ❌ |
| CAT Rig Control (Bluetooth) | ✅ | ✅ | ✅ |
| Audio DSP / Digital Modes | ✅ | ✅ | Limited |
| Waterfall / Spectrum | ✅ | ✅ | ❌ |
| CW Keying (low latency) | ✅ | ✅ | ❌ |
| AI Audio Enhancement | ✅ | ✅ | ❌ |
| AI CW Decoder | ✅ | ✅ | Listen only |
| AI Assistant | ✅ | ✅ | ✅ |
| DX Cluster | ✅ | ✅ | ✅ |
| Propagation Tools | ✅ | ✅ | ✅ |
| Awards Tracking | ✅ | ✅ | ✅ |
| Satellite Tracking | ✅ | ✅ | ✅ |
| APRS | ✅ | ✅ | ✅ |
| Contesting | ✅ | ✅ | Log only |
| Repeater Directory | ✅ | ✅ | ✅ |
| EmComm Tools | ✅ | ✅ | ✅ |
| Antenna Modeling | ✅ | Limited | ❌ |

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Layer                        │
│   macOS App  │   iPadOS App  │   iOS App                │
│   (Multi-window, Menu Bar)   │  (Tab Bar, Widgets)       │
└───────────────────┬─────────────────────────────────────┘
                    │  @Observable ViewModels
┌───────────────────▼─────────────────────────────────────┐
│                  HamStationCore (Swift Package)           │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │  Logbook │ │   Rig    │ │  Audio   │ │    AI     │  │
│  │  Module  │ │ Control  │ │  Engine  │ │  Director │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ DX/Prop  │ │ Digital  │ │   CW     │ │ Satellite │  │
│  │  Module  │ │  Modes   │ │  Engine  │ │  Tracker  │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │  Awards  │ │  APRS    │ │ Contest  │ │  EmComm   │  │
│  │ Tracking │ │  Engine  │ │  Engine  │ │   Tools   │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
└───────────────────┬─────────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────────┐
│               Platform & Hardware Layer                   │
│                                                          │
│  AVAudioEngine │ Core ML │ Metal │ IOKit │ Network.fw   │
│  CoreLocation  │ CloudKit│ WCSession │ WidgetKit        │
└─────────────────────────────────────────────────────────┘
```

### Concurrency Model

All radio I/O is modeled as Swift `AsyncSequence` streams. Each hardware interface (audio, serial, network) runs on a dedicated `Actor`. The UI layer observes `@Observable` ViewModels on the `@MainActor`.

```swift
// Example: Audio sample stream
actor AudioInputActor {
    func sampleStream() -> AsyncStream<AVAudioPCMBuffer> { ... }
}

// DSP pipeline using structured concurrency
func processingPipeline() async {
    for await buffer in audioInput.sampleStream() {
        let spectrum = await fftProcessor.compute(buffer)
        let decoded = await digitalModeDecoder.decode(buffer)
        await MainActor.run {
            waterfallViewModel.update(spectrum)
            decodedTextViewModel.append(decoded)
        }
    }
}
```

---

## 4. Swift Package Structure

```
HamStation.xcworkspace
├── HamStationMac/          # macOS app target
├── HamStationPad/          # iPadOS app target  
├── HamStationPhone/        # iOS app target
├── HamStationWidget/       # WidgetKit extension
├── HamStationWatch/        # watchOS companion (future)
└── Packages/
    ├── HamStationCore/     # Shared business logic
    │   ├── Sources/
    │   │   ├── Models/
    │   │   ├── Logbook/
    │   │   ├── RigControl/
    │   │   ├── AudioEngine/
    │   │   ├── DigitalModes/
    │   │   ├── CWEngine/
    │   │   ├── AIDirector/
    │   │   ├── DXCluster/
    │   │   ├── Propagation/
    │   │   ├── Awards/
    │   │   ├── Satellite/
    │   │   ├── APRS/
    │   │   ├── Contest/
    │   │   ├── EmComm/
    │   │   └── Utilities/
    │   └── Tests/
    ├── HamStationUI/       # Shared SwiftUI components
    │   ├── WaterfallView/
    │   ├── LogbookTable/
    │   ├── MapViews/
    │   └── DesignSystem/
    └── HamlibBridge/       # C library Swift wrapper
        ├── hamlib/         # Hamlib C sources (git submodule)
        └── Sources/        # Swift bridging layer
```

---

## 5. Data Models

### Core QSO (Contact) Model

```swift
@Model
final class QSO {
    var id: UUID
    var callsign: String               // Contacted station callsign
    var myCallsign: String             // Operator callsign used
    var band: Band                     // HF/VHF/UHF band
    var frequency: Double              // Exact frequency in Hz
    var mode: OperatingMode            // SSB, CW, FT8, etc.
    var dateTimeOn: Date               // QSO start (UTC)
    var dateTimeOff: Date?             // QSO end
    var rstSent: String                // RST report sent
    var rstReceived: String            // RST report received
    var txPower: Double?               // Watts
    var myGrid: String?                // Maidenhead grid square
    var theirGrid: String?
    var myCounty: String?
    var theirCounty: String?
    var dxccEntity: DXCCEntity?        // Resolved DXCC entity
    var continent: Continent?
    var cqZone: Int?
    var ituZone: Int?
    var propagationMode: PropagationMode?
    var satelliteMode: String?
    var satelliteName: String?
    var contest: ContestRef?           // Contest association
    var sotaRef: String?               // SOTA summit reference
    var potaRef: String?               // POTA park reference
    var wwffRef: String?               // WWFF flora/fauna reference
    var comment: String?
    var name: String?                  // Op name from lookup
    var qth: String?                   // Contacted station QTH
    var qslSent: QSLStatus
    var qslReceived: QSLStatus
    var lotwSent: Bool
    var lotwReceived: Bool
    var eqslSent: Bool
    var eqslReceived: Bool
    var clublogUpload: UploadStatus
    var adifImportSource: String?      // Track import origin
    var isVerified: Bool               // LoTW/EQSL confirmed
    var signalReport: SignalAnalysis?  // AI-generated signal data
    var aiTranscript: String?          // AI-captured QSO notes
    var photos: [QSOPhoto]             // Attached photos
    var attachments: [QSOAttachment]
    var createdAt: Date
    var updatedAt: Date
}

enum Band: String, Codable, CaseIterable {
    case band160m = "160m"
    case band80m  = "80m"
    case band60m  = "60m"
    case band40m  = "40m"
    case band30m  = "30m"
    case band20m  = "20m"
    case band17m  = "17m"
    case band15m  = "15m"
    case band12m  = "12m"
    case band10m  = "10m"
    case band6m   = "6m"
    case band2m   = "2m"
    case band70cm = "70cm"
    case band23cm = "23cm"
    // ... additional bands
    
    var frequencyRange: ClosedRange<Double> { ... }
    var hamlibBand: Int { ... }
}

enum OperatingMode: String, Codable, CaseIterable {
    case ssb, lsb, usb, am, fm, cw, rtty, psk31, psk63
    case ft8, ft4, js8, wspr, jt65, jt9
    case sstv, fax, olivia, contestia, thor
    case dstar, dmr, c4fm, p25
    case sat
}
```

### Rig Model

```swift
@Model
final class Rig {
    var id: UUID
    var name: String                   // User-defined name
    var manufacturer: String
    var model: String
    var hamlibRigID: Int               // Hamlib rig model number
    var connectionType: RigConnectionType  // USB, Serial, Network, Bluetooth
    var connectionConfig: RigConnectionConfig
    var defaultPower: Double
    var isActive: Bool
    var capabilities: RigCapabilities  // What this rig supports
}

enum RigConnectionType {
    case usb(portPath: String, baudRate: Int)
    case serial(portPath: String, baudRate: Int)
    case network(host: String, port: Int)  // rigctld, FlexRadio, etc.
    case bluetooth(peripheralID: UUID)
}
```

---

## 6. Feature Modules

### 6.1 Logbook & QSO Management

The logbook is the centerpiece of the application. It must be fast, reliable, and ADIF-compliant.

#### Core Capabilities
- Full ADIF 3.1+ import and export
- Cabrillo export for contest log submission
- Real-time callsign lookup (QRZ.com, HamDB, local cache)
- Duplicate QSO detection with configurable rules
- Batch operations: re-lookup, re-score, bulk QSL status update
- Multi-logbook support (home, portable, contest, club)
- QSL card printing with custom templates

#### SwiftData Schema
Uses SwiftData with CloudKit sync. The `QSO` model (above) is the primary entity. Relationships: `Logbook → [QSO]`, `QSO → DXCCEntity`, `QSO → ContestRef`.

#### Callsign Lookup Pipeline
```
User inputs callsign
    → Local cache check (SQLite, 30-day TTL)
    → HamDB free lookup (no API key required)
    → QRZ.com XML lookup (requires subscription)
    → LoTW user lookup (is this callsign on LoTW?)
    → AI enhancement: extract name, QTH, grid from bio text
```

#### ADIF Import/Export
Implement a full ADIF 3.1 parser in Swift supporting all standard fields plus custom APP_ tags. Export pipeline respects contest-specific field requirements.

#### macOS Table View
Use `Table` with sortable columns, column visibility controls, and `#Predicate` filtering. Support for 100,000+ QSOs without performance degradation via lazy loading and background fetches.

```swift
struct LogbookTableView: View {
    @Query(sort: \QSO.dateTimeOn, order: .reverse) var qsos: [QSO]
    @State private var selection: Set<QSO.ID> = []
    @State private var sortOrder = [KeyPathComparator(\QSO.dateTimeOn)]
    
    var body: some View {
        Table(qsos, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date/Time", value: \.dateTimeOn) { ... }
            TableColumn("Callsign", value: \.callsign) { ... }
            TableColumn("Band", value: \.band.rawValue) { ... }
            TableColumn("Mode", value: \.mode.rawValue) { ... }
            TableColumn("RST Sent", value: \.rstSent) { ... }
            TableColumn("RST Rcvd", value: \.rstReceived) { ... }
            TableColumn("DXCC", value: \.dxccEntity?.name ?? "") { ... }
            TableColumn("QSL") { qso in QSLStatusCell(qso: qso) }
        }
        .contextMenu(forSelectionType: QSO.ID.self) { ... }
    }
}
```

---

### 6.2 Rig Control (CAT)

Computer-Aided Transceiver control allows the app to read and set frequency, mode, power, and other parameters on connected radios.

#### Hamlib Integration
Hamlib supports 400+ radio models. Integrate via a Swift Package wrapping the Hamlib C library:

```swift
// HamlibBridge Swift actor
actor HamlibRig {
    private var rig: UnsafeMutablePointer<RIG>?
    
    func connect(model: Int, port: RigConnectionConfig) async throws {
        rig = rig_init(rig_model_t(model))
        // configure port parameters
        try HamlibError.check(rig_open(rig))
    }
    
    func setFrequency(_ hz: Double) async throws {
        try HamlibError.check(rig_set_freq(rig, RIG_VFO_CURR, freq_t(hz)))
    }
    
    func frequencyStream() -> AsyncStream<Double> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    var freq: freq_t = 0
                    if rig_get_freq(rig, RIG_VFO_CURR, &freq) == RIG_OK {
                        continuation.yield(Double(freq))
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }
    }
}
```

#### Network Rig Control
Support for rigctld (Hamlib network daemon), FlexRadio SmartSDR API, Icom RS-BA1 network protocol, and Kenwood network interfaces. This enables remote station operation and the iOS app to control a shack radio over Wi-Fi/LAN.

#### Bluetooth Rig Control
Support for rigs with Bluetooth CAT (Icom IC-705, certain Yaesu FT-3D/5D models) via CoreBluetooth. The iOS/iPad app can control a portable radio without cables.

#### Band Map Integration
The rig's current frequency drives band map highlighting in the DX cluster view. Clicking a spot in the cluster tunes the rig. This bidirectional binding is a core workflow.

---

### 6.3 Audio Engine & DSP

The audio engine is built on AVAudioEngine with AudioWorklet-equivalent processing in Swift Audio Units.

#### Architecture

```
USB Audio Interface (SignalLink, etc.)
    → AVAudioInputNode
    → AVAudioMixerNode (monitoring)
    → DSP Chain (AudioUnit graph)
        ├── NoiseReductionAU (Core ML powered)
        ├── NotchFilterAU (adaptive, tracks interference)
        ├── BandpassFilterAU (mode-specific: SSB 300-2700Hz, CW 600-800Hz, etc.)
        ├── AGCAudioUnit (automatic gain control)
        └── DemodulatorAU (mode-specific demodulation)
    → FFTTapNode (feeds waterfall)
    → OutputNode (speaker/headphones)
    
Transmit path:
    Microphone / WSJT-X VAC / CW keyer
    → EncoderAU
    → TxLevelAU
    → USB Audio Interface (PTT via RTS/DTR)
```

#### Low-Latency Audio Configuration
For CW keying, configure AVAudioSession with minimum I/O buffer duration:

```swift
func configureForCW() throws {
    #if os(macOS)
    // Use CoreAudio directly for sub-5ms latency
    var bufferFrames: UInt32 = 64
    AudioUnitSetProperty(audioUnit, kAudioDevicePropertyBufferFrameSize, ...)
    #else
    try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
    #endif
}
```

#### PTT (Push-To-Talk) Control
- RTS/DTR via USB serial (most common)
- VOX (voice-operated) with configurable threshold
- CAT-based PTT via Hamlib
- CM108-style HID PTT for interfaces that support it
- Network PTT for remote operation

---

### 6.4 Waterfall & Spectrum Display

The waterfall is the most visually distinctive element of an SDR or digital mode application. It uses Metal for real-time GPU rendering.

#### Metal Rendering Pipeline

```swift
class WaterfallRenderer: NSObject, MTKViewDelegate {
    // Rolling texture: new FFT line written to circular buffer in texture
    // Fragment shader maps power → color using configurable palette
    // Vertex shader scrolls UV coordinates for smooth scroll effect
    
    var fftTexture: MTLTexture!        // 4096 x 1024 rolling buffer
    var paletteTexture: MTLTexture!    // 256 color gradient (user selectable)
    var currentRow: Int = 0
    
    func updateWaterfall(fftData: [Float]) {
        // Write new FFT line to texture row via MTLBuffer blit
        // GPU handles the rest at 60fps
    }
}
```

#### FFT Processing
Use Metal Performance Shaders `MPSMatrixVectorMultiplication` or Accelerate's `vDSP_fft_zrip` for real-time FFT. For a 4096-point FFT at 48kHz sample rate, this gives ~11Hz frequency resolution — sufficient for SSB, CW, and digital mode visualization.

#### Color Palettes
Implement standard SDR waterfall palettes: CuteSDR, Rainbow, Greyscale, Blue-White, LinLog, and a custom "Night mode" palette optimized for dark rooms during late-night DXing.

#### Features
- Frequency scale with click-to-tune (feeds rig control)
- Mode bandwidth overlay (shaded region showing current filter width)
- Signal annotations: decoded callsigns overlaid on active FT8 signals
- Pan and zoom with smooth gesture handling on iPad/iPhone
- Dual-VFO markers (A/B VFOs shown simultaneously)
- Historical waterfall playback (record audio + FFT, review later)

---

### 6.5 Digital Modes

#### Mode Support (via WASM-free Swift + C implementations)

| Mode | Use Case | Implementation |
|---|---|---|
| FT8 / FT4 | Weak signal DX | WSJT-X protocol library (C → Swift bridge) |
| JS8Call | Resilient keyboard-to-keyboard | JS8 protocol library |
| WSPR | Propagation beacons | WSPR encode/decode library |
| JT65 / JT9 | Weak signal, EME | WSJT-X library |
| PSK31 / PSK63 | Ragchewing | libfldigi bridge |
| RTTY | Contesting | libfldigi bridge |
| Olivia | Robust HF keyboard | libfldigi bridge |
| SSTV | Image transmission | CoreImage-based SSTV codec |
| Winlink | Email over radio | Winlink API / Vara HF protocol |
| AX.25 Packet | Local networking | Native Swift implementation |

#### FT8 Engine
FT8 is the dominant digital mode. The integration requires tight timing (transmit/receive in 15-second cycles synchronized to UTC):

```swift
actor FT8Engine {
    // Synchronize to UTC 15-second boundary
    func synchronizedCycleStream() -> AsyncStream<FT8Cycle> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    let now = Date()
                    let secondsInMinute = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                    let cycleStart = secondsInMinute.truncatingRemainder(dividingBy: 15)
                    let nextCycle = 15 - cycleStart
                    try? await Task.sleep(for: .seconds(nextCycle))
                    
                    let cycle = FT8Cycle(
                        startTime: Date(),
                        rxAudio: await captureRxAudio(),
                        isTransmitCycle: shouldTransmit()
                    )
                    continuation.yield(cycle)
                }
            }
        }
    }
    
    func decode(_ audio: AVAudioPCMBuffer) async -> [FT8Message] {
        // Call libjt9 C library decode function
        // Returns array of decoded messages with frequencies, SNR, callsigns
    }
}
```

#### Auto-Sequence Engine
When the user clicks a callsign in the FT8 decode list, the app auto-sequences through the standard exchange: CQ → Reply → Signal report → RRR → 73. The AI Director monitors the sequence and handles edge cases (no response, pile-up conditions, split operation).

---

### 6.6 CW (Morse Code)

CW support spans both sending and receiving, with AI at the core of the receiving pipeline.

#### CW Sending
- Software keyer (iambic A/B modes) via hardware paddle interface
- Keyboard-to-CW with adjustable speed (WPM)
- Memory keyer: configurable macro buttons for contest exchanges, CQ calls, standard messages
- Straight key emulation
- Ultra-low latency requirement: < 5ms from key closure to RF output
- Farnsworth timing support for slower copying practice

#### CW Receiving — Traditional DSP
- Narrow bandpass filter (100-200Hz) centered on received signal
- Goertzel algorithm for tone detection (more efficient than FFT for single-tone)
- Adaptive threshold with automatic noise floor tracking
- Speed tracking: auto-adjusts expected dit/dah duration based on incoming signal

#### CW Receiving — Core ML Enhancement
The AI decoder (see Section 7) runs in parallel with the traditional DSP decoder. When the traditional decoder is uncertain (QSB, QRM, weak signal), the ML model's prediction takes precedence. On-device inference using the Neural Engine adds zero perceptible latency.

#### CW Training Module
- Koch method trainer
- Callsign copy practice (random callsigns)
- QSO copy practice (simulated QSO audio)
- Progress tracking with spaced repetition scheduling via SwiftData
- Speed progression: auto-advance when user hits target accuracy

---

### 6.7 AI Director & Assistant

The AI Director is the intelligent coordinator of the application. It has full context about the operator's station, goals, and current radio conditions.

#### Conversational Assistant
An always-available chat interface powered by a cloud LLM (Anthropic Claude API, configurable). The assistant is primed with ham radio context:

```swift
struct AIAssistantSystem {
    static var systemPrompt: String {
        """
        You are an experienced amateur radio operator and technical expert 
        assisting a licensed ham. You have deep knowledge of:
        - Amateur radio operating procedures and best practices
        - HF/VHF/UHF propagation
        - Digital modes (FT8, WSPR, PSK, etc.)
        - CW (Morse code) operating
        - Contest operating
        - DXCC, SOTA, POTA, and other award programs
        - Antenna theory and construction
        - Radio regulations (FCC Part 97)
        - Emergency communications (ICS, NIMS, ARES/RACES)
        
        Current operator context:
        - Callsign: \(UserProfile.callsign)
        - License class: \(UserProfile.licenseClass)
        - Location: \(UserProfile.gridSquare) (\(UserProfile.location))
        - Current band: \(rigState.band)
        - Awards in progress: \(awards.summary)
        - Recent QSOs: \(recentQSOs.summary)
        """
    }
}
```

#### Natural Language Logging
The operator can speak or type conversationally to log QSOs:

> "Just worked W1AW on 20 meters FT8, he was minus 10 and I was minus 8"

The AI parses this and pre-populates the QSO form: callsign W1AW, band 20m, mode FT8, RST sent -08, RST received -10.

#### Band Advisor
Combines real-time solar/propagation data with the operator's award goals to suggest operating strategy:

> "K-index is currently 2, SFI 145. 17m is showing good openings to JA/VK right now based on PSK Reporter. You need 3 more JA contacts for your DXCC 100 Mixed. I'd suggest checking 18.100 MHz — there are 4 JA8 spots in the last 10 minutes."

#### Pile-Up Coach
When the operator is attempting to work a rare DX station, the AI monitors the QSO pattern and advises:

> "The DX is working split, listening 5-10 up. He's working through the calls in alphabetical order. You're KD9XYZ — he's around the K's now. Try in about 3 cycles."

#### Smart QSL Routing
After a QSO, the AI recommends QSL methods based on the contacted station's history (LoTW enrollment, OQRS availability, direct QSL manager) and the operator's award needs.

---

### 6.8 Propagation & Band Conditions

#### Data Sources
- **NOAA SWPC**: Solar flux index (SFI), A-index, K-index, geomagnetic storm alerts
- **VOACAP API**: Point-to-point propagation prediction
- **WSPRnet**: Real-world propagation reports from WSPR beacons globally
- **PSK Reporter**: Live signal reports from FT8/PSK operators worldwide
- **DX Maps**: Band opening visualizations
- **RBN (Reverse Beacon Network)**: CW/RTTY skimmer spots

#### Solar Dashboard
Real-time display of:
- Solar Flux Index with trend arrow (10.7cm wavelength indicator)
- A-index (24-hour geomagnetic activity)
- K-index with color coding (green/yellow/red)
- X-ray flux (solar flare activity)
- Proton flux (polar cap absorption risk)
- Aurora forecast (Kp threshold for aurora visibility)

#### Grey Line Map
A real-time map showing the solar terminator (grey line). Enhanced propagation occurs along the terminator due to D-layer absorption disappearing. The map displays:
- Current grey line position
- Long-path and short-path beam headings to any entity
- Sunrise/sunset times for the user's QTH and any target location

#### VOACAP Integration
Generate propagation predictions for a user-configured station (antenna, power, location) to any target zone or specific callsign. Display reliability percentage by hour for each band as a heat map.

#### MapKit Visualization
Use `Map` from SwiftUI with `MapPolyline` for propagation paths, `Annotation` for DX station locations, and a custom `MapOverlay` for the grey line shader.

---

### 6.9 DX Cluster & Spotting

#### Telnet Cluster Connection
Connect to DX telnet clusters (DX Spider, AR-Cluster, CC Cluster) via `Network.framework` NWConnection:

```swift
actor DXClusterConnection {
    private var connection: NWConnection?
    
    func spotStream(host: String, port: Int) -> AsyncThrowingStream<DXSpot, Error> {
        AsyncThrowingStream { continuation in
            connection = NWConnection(host: NWEndpoint.Host(host), 
                                      port: NWEndpoint.Port(rawValue: UInt16(port))!,
                                      using: .tcp)
            // Parse AR-Cluster spot format: 
            // DX de KA1ABC: 14025.0 W1AW CW 59 1234Z
            self.connection?.receive { data, _, _, error in
                if let line = String(data: data, encoding: .utf8) {
                    if let spot = DXSpot(arclusterLine: line) {
                        continuation.yield(spot)
                    }
                }
            }
        }
    }
}
```

#### Spot Filtering Engine
- By band, mode, continent, CQ zone, DXCC entity, callsign prefix
- Needed/worked filter (highlight unworked entities for award progress)
- SNR filter (only show spots above threshold)
- Skimmer filter (exclude automated CW/RTTY skimmer spots, or show only skimmer)
- Age filter (hide spots older than N minutes)

#### Band Map
A frequency-axis display showing active spots on the current band. Spots appear as labeled markers on a frequency ruler. Clicking a spot tunes the rig (via CAT control) and pre-fills the logging form.

#### Push Notifications
Configure alert conditions: "Notify me when a new DXCC entity appears on 40m CW" or "Alert when ZL8 (Kermadec Islands) is spotted on any band." Uses local notifications; no background processing required for basic alerting.

---

### 6.10 Awards & DXCC Tracking

#### Supported Award Programs
- **DXCC** (DX Century Club) — worked/confirmed by band, by mode
- **WAS** (Worked All States) — by band, by mode
- **WAZ** (Worked All Zones) — CQ zones, by band/mode
- **IOTA** (Islands on the Air) — island reference tracking
- **SOTA** (Summits on the Air) — both chaser and activator
- **POTA** (Parks on the Air) — chaser and activator
- **WWFF** (World Wide Flora & Fauna)
- **GridSquare Awards** — VHF/UHF grid hunting
- **County Hunter Awards** — US county tracking
- **Lighthouse Awards** (ILLW, etc.)

#### DXCC Engine
Maintain a current DXCC entity database (updated via background refresh from ARRL). For each QSO, resolve:
1. Callsign prefix → DXCC entity (handle exceptions: maritime mobile, aeronautical, special event)
2. CQ zone and ITU zone from callsign or explicit log data
3. Continent from entity

Display award progress as: needed/worked/confirmed broken down by band and mode. Generate "needed list" for DX cluster filtering.

#### SOTA/POTA Integration
- Pull SOTA summit database (summits.sota.org.uk API)
- Pull POTA park database (api.pota.app)
- Track activations and chaser QSOs separately
- Display activation history on MapKit map
- Alert when a spot appears for a needed summit/park

---

### 6.11 Satellite Tracking

#### TLE Data Management
Download and cache Two-Line Element sets from Celestrak. Update automatically on a schedule. Maintain a curated list of amateur radio satellites:
- AO-91, AO-92 (Fox-1B, Fox-1D)
- SO-50 (Saudi Oscar 50)
- AO-7 (classic Mode A/B linear transponder)
- QO-100 (Es'hail-2 geostationary, first ham satellite in geostationary orbit)
- ISS (International Space Station, NA1SS)
- XW-series (Chinese amateur satellites)

#### Orbit Prediction (SGP4)
Implement SGP4 orbital mechanics in Swift (or wrap a C implementation). Compute:
- Next pass start/end times and maximum elevation
- AOS (Acquisition of Signal) / LOS (Loss of Signal) azimuth and elevation
- Doppler shift at any point in the pass (critical for uplink/downlink frequency correction)

#### Rotor Control
For operators with antenna rotors, output real-time azimuth/elevation commands via:
- Hamlib rotor control (GS-232A/B protocol, Yaesu, SPID, etc.)
- Direct serial via `ORSSerialPort` (macOS)

#### Doppler Correction
Automatically apply Doppler correction to rig frequency in real time during a satellite pass. For a 2m/70cm FM satellite (uplink 145.x, downlink 435.x), the Doppler shift can be ±3.4 kHz — significant enough to lose the signal without correction.

```swift
func dopplerCorrectedFrequency(nominalHz: Double, rangeRate: Double) -> Double {
    let c = 299_792_458.0  // speed of light m/s
    return nominalHz * (1 - rangeRate / c)
}
```

#### iPad/iPhone Pass Alert Widget
A widget showing the next 3 amateur satellite passes with countdown timers.

---

### 6.12 Antenna Modeling & Tools

*(macOS and iPad only)*

#### Antenna Calculator Tools
- Dipole/doublet length calculator (with velocity factor correction for wire type)
- Yagi element spacing and length optimizer
- Vertical radial system calculator
- Coax line loss calculator (with connector losses)
- Impedance matching (L-network, pi-network, T-network)
- Smith chart visualization using Core Graphics
- Transmission line calculator (SWR, reflection coefficient)

#### MININEC / NEC2 Integration (macOS)
Wrap NEC2C (open source Numerical Electromagnetics Code) for antenna pattern modeling:
- Input antenna geometry as wire segments
- Compute radiation pattern (3D)
- Display as polar plot using SwiftCharts or Metal
- Export pattern to standard formats

#### Wire Antenna Generator
Wizard-based antenna design tool: user inputs target band, available space dimensions, feedline type, and the app generates a dimensioned design (dipole, inverted-V, sloper, etc.) with construction notes.

---

### 6.13 APRS

APRS (Automatic Packet Reporting System) combines position reporting, messaging, and telemetry over amateur radio packet.

#### APRS-IS Connection
Connect to the APRS Internet System (APRS-IS) via TCP for receive and filtered transmit:

```swift
actor APRSISClient {
    func connect(server: String = "rotate.aprs2.net", port: Int = 14580) async throws {
        // Login with callsign-SSID and passcode
        // Apply filter: range-based, object, message, WX
    }
    
    func packetStream() -> AsyncThrowingStream<APRSPacket, Error> { ... }
}
```

#### TNC Support (macOS/iPad)
For RF APRS via a radio + TNC (Terminal Node Controller):
- KISS mode TNC via serial or Bluetooth
- Software TNC via audio (AFSK 1200 baud via AVAudioEngine)
- Direwolf integration (run as subprocess)

#### APRS Features
- Live map (MapKit) showing nearby stations, objects, weather stations
- Message inbox/outbox (APRS messaging protocol)
- Position beaconing (stationary or mobile with CoreLocation)
- APRS weather station display
- Object/item creation and transmission
- IGate mode (relay RF packets to APRS-IS)

---

### 6.14 Emergency Communications (EmComm)

#### ICS Forms
Digital versions of FEMA/DHS Incident Command System forms:
- ICS-213 General Message
- ICS-214 Activity Log
- ICS-309 Communications Log
- HICS forms (Hospital Incident Command)

Forms save to SwiftData, export to PDF via PDFKit, and sync via iCloud or local network.

#### Winlink Integration
Winlink is an email-over-radio system critical for EmComm. Integrate with the Winlink web API for:
- Message composition and reading
- Catalog of standard Winlink/RMS stations
- Hybrid mode: Winlink over internet when RF unavailable, seamlessly switching to RF when available

#### Net Logging
Structured logging for HF/VHF nets:
- Net control features: check-in list, traffic handling, member tracking
- Automatic time-stamping of all check-ins
- Export to ARES net reports format
- Voice-to-text check-in entry (using Apple Speech Recognition framework)

#### Offline Operation
All EmComm features must function completely offline. DXCC database, state/county maps, ICS form templates, and Winlink message queue are all stored locally.

---

### 6.15 Contesting

#### Contest Engine
- Support for major contest exchanges: RST+serial, RST+state, RST+CQ zone, etc.
- Real-time dupe checking within the contest log
- Running vs. S&P (Search & Pounce) mode tracking
- Rate display: QSOs per hour (current, last 10 min, last 60 min)
- Score calculation with multiplier tracking
- Cabrillo export for electronic log submission

#### Supported Contests
CQWW, ARRL DX, ARRL Sweepstakes, CQ WPX, IARU HF, NAQP, Sprint, and others. Contest definitions stored as JSON so new contests can be added without app updates.

#### Contest Macros (CW/Digital)
Configurable function key macros for contest exchanges. For CW: `F1 = CQ TEST [CALLSIGN]`, `F2 = [CALLSIGN]`, `F3 = TU [CALLSIGN] 5NN [SERIAL] [SERIAL]`.

#### N+1 Checking
Check callsigns against a reference database to catch busted calls (common in contest operating). Suggest possible corrections.

---

### 6.16 Repeater Directory

#### Data Sources
- RepeaterBook API (comprehensive North American + international database)
- RadioReference.com API
- Local user-defined entries

#### Features
- Current location (CoreLocation) filtered nearby repeaters
- Filtering by band (2m, 70cm, 1.25m, etc.), tone, mode (FM, D-STAR, DMR, C4FM, P25)
- Map view of nearby repeaters
- CTCSS/DCS tone lookup
- Linked repeater system information (IRLP, EchoLink, AllStar node numbers)
- One-tap: send frequency + tone to rig via CAT control
- Siri Shortcut: "Find nearest 2-meter repeater"

---

## 7. AI & Machine Learning Features

### 7.1 CW Decoder (Core ML)

**Model architecture:** 1D Convolutional Neural Network trained on audio spectrograms of Morse code transmissions.

**Training data:** Thousands of hours of real on-air CW recordings at varying speeds (5–50 WPM), fist styles, noise conditions, and QRM levels. Augmented with synthetic data across SNR ranges from +20dB to -10dB.

**Input:** 512-sample audio windows (10.67ms at 48kHz sample rate) extracted from a narrow bandpass filter centered on the CW tone.

**Output:** Probability distribution over {dit, dah, element-space, character-space, word-space, noise}.

**Integration with traditional decoder:** Run both decoders in parallel. When traditional decoder confidence < 0.7 (based on signal SNR estimate), prefer the ML decoder output. Display both decoders' output in split view for comparison.

**On-device inference:** Model converted to Core ML `.mlpackage` format. Inference runs on Apple Neural Engine (all Apple Silicon, A18 Pro on MacBook Neo). Target: < 2ms inference latency.

### 7.2 Audio Enhancement (Core ML / AVAudioUnit)

A custom `AVAudioUnit` (AUv3) wraps a Core ML model performing real-time noise reduction on received SSB/AM audio.

**Architecture:** U-Net style audio spectrogram denoising, similar to Apple's own speech denoising used in FaceTime. Trained on ham radio audio specifically — differentiating between voice signal, CW tones, digital mode tones, static crashes, power line QRM, and intermodulation.

**Processing:** 
- Input: 20ms frames of received audio (960 samples at 48kHz)
- Compute STFT → apply U-Net denoising model → inverse STFT
- Output: Enhanced audio frame
- Total end-to-end latency target: < 25ms (imperceptible for SSB voice)

**User control:** Simple slider (0–100%) for noise reduction amount. Off = bypass. Presets: "HF SSB", "Weak CW", "Local FM".

### 7.3 Callsign Recognition (Speech Recognition + NLP)

Use `SFSpeechRecognizer` for voice input, then apply a custom NLP model to extract ham radio structured data from spoken text:

- Callsign parsing: "Whiskey One Alpha Whiskey" → W1AW
- Signal report parsing: "five nine nine" → 599
- Band/frequency: "on forty meters" → 40m
- Exchange parsing for contests

**Training:** Fine-tune on a dataset of simulated QSO transcripts covering phonetic alphabet usage, callsign structures, and common phrases.

### 7.4 Propagation Prediction (On-Device ML)

A lightweight regression model predicting band opening probability given:
- Solar flux index, K-index, A-index
- Time of day (UTC)
- Season
- Transmitter/receiver geographic coordinates
- Historical opening data for this path

Trained on WSPRnet historical data (millions of propagation reports). Runs entirely on-device, no API call needed for basic predictions. Supplement with live VOACAP API call for detailed reports.

### 7.5 Smart Log Analysis

Periodic background ML analysis of the operator's logbook to surface insights:

- "Your 40m CW performance peaks between 0200-0400 UTC — that's when you have the best chance for JA contacts"
- "You've worked 47 of the 50 DXCC entities you need for 5-Band DXCC on 20m. Your three remaining are: 3Y (Bouvet), VK0 (Heard), and FT5 (Crozet)"
- "Your contest rate drops significantly after 4 hours — you might benefit from scheduled breaks"

---

## 8. Apple Technology Integration

### Core Frameworks

| Framework | Usage |
|---|---|
| **SwiftUI** | All UI across all platforms |
| **SwiftData** | Primary persistence with CloudKit sync |
| **Core ML** | CW decoder, audio enhancement, propagation ML |
| **AVAudioEngine** | Audio I/O, DSP processing graph |
| **Metal / MetalPerformanceShaders** | Waterfall rendering, FFT acceleration |
| **Accelerate (vDSP)** | FFT, FIR filter computation |
| **Network.framework** | Cluster connections, APRS-IS, remote rig |
| **CoreLocation** | Grid square computation, SOTA/POTA proximity |
| **MapKit** | Grey line map, DX map, APRS map, SOTA/POTA map |
| **Swift Charts** | Propagation heat maps, signal history, rate graphs |
| **WidgetKit** | Propagation conditions, next satellite pass, recent spots |
| **SFSpeechRecognizer** | Voice logging, natural language input |
| **PDFKit** | ICS form generation, QSL card printing |
| **UserNotifications** | DX alerts, satellite pass alerts |
| **CloudKit** | Cross-device logbook sync |
| **WatchConnectivity** | (Future) watchOS companion sync |
| **StoreKit 2** | In-app purchases for premium features |
| **ActivityKit** | Live Activity for active satellite pass countdown |

### Dynamic Island (iPhone 16/17+)
During an active satellite pass, display a Live Activity in the Dynamic Island showing:
- Satellite name and current elevation
- Time to LOS (Loss of Signal)
- Current Doppler-corrected uplink/downlink frequencies
- A compact elevation indicator

### Apple Watch Companion (v2 roadmap)
- DX alert glances on wrist
- Propagation condition complication
- Band condition indicator
- Logbook quick entry via dictation

### Siri Shortcuts / App Intents

```swift
struct LogQSOIntent: AppIntent {
    static var title: LocalizedStringResource = "Log QSO"
    
    @Parameter(title: "Callsign") var callsign: String
    @Parameter(title: "Band") var band: Band
    @Parameter(title: "Mode") var mode: OperatingMode
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Log QSO and return confirmation
        let qso = try await LogbookManager.shared.createQSO(...)
        return .result(dialog: "Logged \(callsign) on \(band) \(mode)")
    }
}
```

Expose intents for: Log QSO, Check Band Conditions, Look Up Callsign, Show DX Spots.

### Spotlight Integration
Index callsigns, entities, and logbook entries in CoreSpotlight so operators can find past QSOs directly from Spotlight Search.

### SharePlay / FaceTime Integration
*(Speculative feature for club use)* Shared waterfall and band map during a FaceTime call between club members — real-time collaboration on pile-up strategy or net operations.

---

## 9. SwiftUI Architecture & Navigation

### macOS Navigation — Multi-Window

```swift
@main
struct HamStationApp: App {
    var body: some Scene {
        // Main operating window
        WindowGroup("HamStation Pro", id: "main") {
            MainOperatingView()
        }
        .commands {
            HamStationCommands()
        }
        
        // Waterfall/SDR window (detachable)
        WindowGroup("Waterfall", id: "waterfall") {
            WaterfallWindowView()
        }
        .defaultSize(width: 1200, height: 400)
        
        // Logbook window
        WindowGroup("Logbook", id: "logbook") {
            LogbookWindowView()
        }
        
        // Settings
        Settings {
            SettingsView()
        }
        
        // Menu bar extra (propagation conditions at a glance)
        MenuBarExtra("HamStation", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarView()
        }
    }
}
```

### macOS Main Operating View Layout

```
┌────────────────────────────────────────────────────────────────────┐
│ Toolbar: [Callsign] [Freq: 14.074] [Mode: FT8] [Band: 20m] [PWR] │
├──────────────┬─────────────────────────────┬───────────────────────┤
│              │                             │                       │
│  Navigator   │    Main Content Area        │   Inspector / Info    │
│              │                             │                       │
│  ● Logbook   │  (Context-dependent:        │  Callsign lookup      │
│  ● DX Cluster│   Waterfall, FT8 decodes,   │  DXCC info            │
│  ● Band Map  │   Logbook table,            │  Award status         │
│  ● Awards    │   Contest log, etc.)        │  QRZ.com data         │
│  ● Satellite │                             │  Solar conditions     │
│  ● APRS      │                             │  AI suggestions       │
│  ● Propagation                             │                       │
│  ● Tools     │                             │                       │
│              │                             │                       │
├──────────────┴─────────────────────────────┴───────────────────────┤
│  Status bar: [QSOs today: 23] [Rate: 48/hr] [K=2 SFI=145] [Rig ✓]│
└────────────────────────────────────────────────────────────────────┘
```

### iPad Navigation — Split View

```swift
struct iPadRootView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            ContentListView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### iPhone Navigation — Tab Bar

```swift
struct iPhoneRootView: View {
    var body: some View {
        TabView {
            LogbookView()
                .tabItem { Label("Logbook", systemImage: "book.fill") }
            
            DXClusterView()
                .tabItem { Label("DX Cluster", systemImage: "dot.radiowaves.left.and.right") }
            
            PropagationView()
                .tabItem { Label("Propagation", systemImage: "sun.max.fill") }
            
            AwardsView()
                .tabItem { Label("Awards", systemImage: "trophy.fill") }
            
            AIAssistantView()
                .tabItem { Label("Assistant", systemImage: "sparkles") }
        }
    }
}
```

### Design System

- **Typography:** SF Pro throughout; SF Mono for frequencies, callsigns, and decoded text
- **Color System:** Adaptive light/dark, with a special "Night" theme using deep red (#8B0000) for dark-adapted vision during nighttime operating
- **Accent color:** Ham radio orange (approximate #FF6A00) — visible but not overly bright
- **Iconography:** SF Symbols throughout; custom symbols for ham-specific concepts (antenna, paddle, waterfall)
- **Density:** macOS uses compact layout for information density appropriate to experienced operators; iOS uses standard spacing

---

## 10. Persistence & Sync

### SwiftData + CloudKit

The primary logbook uses SwiftData with a CloudKit container for sync. This provides:
- Automatic sync across all user's devices (Mac, iPhone, iPad)
- Offline operation — all data available locally
- Conflict resolution handled by SwiftData/CloudKit framework

```swift
@main
struct HamStationApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([QSO.self, Rig.self, Logbook.self, Award.self, ...])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.example.hamstationpro")
        )
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
```

### Local Caches (Not Synced)

- DXCC entity database (SQLite via GRDB.swift or FMDB) — large, updated separately
- Callsign lookup cache (SQLite, 30-day TTL)
- Satellite TLE data (flat file, refreshed regularly)
- Repeater database (SQLite, weekly refresh)
- SOTA/POTA reference databases

### Import/Export

- **ADIF**: Full ADIF 3.1 import/export for logbook portability
- **Cabrillo**: Contest log export
- **CSV**: Tabular export for analysis in Numbers/Excel
- **KML/KMZ**: Map data export for Google Earth visualization
- **LoTW TQSL**: Integration with ARRL Logbook of the World upload tool

---

## 11. Networking & Protocols

### Network.framework Usage

All network connections use `Network.framework` (never URLSession for persistent connections):

```swift
// DX Cluster telnet connection with automatic reconnect
actor ClusterConnection {
    private var connection: NWConnection?
    private let endpoint: NWEndpoint
    
    func start() async throws {
        connection = NWConnection(to: endpoint, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleStateChange(state) }
        }
        connection?.start(queue: .global(qos: .userInitiated))
        await withCheckedContinuation { continuation in
            // wait for .ready state
        }
    }
}
```

### Key External APIs & Protocols

| Service | Protocol | Usage |
|---|---|---|
| QRZ.com | XML/HTTPS | Callsign lookup (requires QRZ subscription) |
| HamDB | REST/HTTPS | Free callsign lookup fallback |
| LoTW | HTTPS/TQSL | Award confirmation upload |
| eQSL.cc | HTTPS | Electronic QSL card exchange |
| ClubLog | REST/HTTPS | Log upload, propagation data |
| Hamlog Online | REST/HTTPS | Online logbook sync option |
| DX Cluster | Telnet (AR-Cluster protocol) | DX spots |
| APRS-IS | Telnet (APRS protocol) | APRS position/messaging |
| NOAA SWPC | REST/HTTPS | Solar data |
| WSPRnet | REST/HTTPS | Propagation reports |
| PSK Reporter | REST/HTTPS | Digital mode propagation reports |
| Celestrak | HTTPS | TLE data for satellite tracking |
| SOTA API | REST/HTTPS | Summit database and log upload |
| POTA API | REST/HTTPS | Park database and log upload |
| RepeaterBook | REST/HTTPS | Repeater directory |

---

## 12. Hardware Interfaces

### USB Audio Interface
Hams use USB audio interfaces (Tigertronics SignalLink, RigBlaster, Yaesu SCU-series, Icom USB cable) to connect radio audio to computer. The app must:
- Enumerate available audio devices and allow selection of input/output per logical function (receive audio, transmit audio)
- Support 8kHz, 16kHz, 44.1kHz, 48kHz sample rates
- Handle device plug/unplug gracefully

### Serial / USB CAT Control
Most radios use USB or serial (DB-9 or 3.5mm TRRS) for CAT control. On macOS, access via:
- `ORSSerialPort` (Swift-friendly serial library) for traditional serial
- IOKit for USB devices that enumerate as serial (CDC-ACM class)

### CW Paddle / Straight Key
- USB HID devices (many modern paddles): enumerate and read as HID input
- Audio-keyed input: detect key closure by audio level on a specific input channel
- Serial port RTS/DTR key input (traditional interface method)
- MIDI (some modern keyers expose MIDI interface)

### SDR Hardware
Software Defined Radio dongles (RTL-SDR, SDRplay RSP, Airspy) provide wideband I/Q receive. Integrate via:
- Run `rtl_tcp` or `sdrplay_server` as a subprocess (macOS only)
- Connect to the I/Q stream via TCP socket
- Process I/Q samples in the app's DSP pipeline

### Antenna Analyzer / VNA
Support for popular analyzers (NanoVNA, SARK-110) via USB serial. Read and display SWR sweeps, import to antenna modeling.

---

## 13. Accessibility

- Full VoiceOver support with meaningful accessibility labels and hints on all controls
- Frequency display reads as "14 megahertz 74 kilohertz" (not "14.074")
- Waterfall has accessibility description: "Waterfall display showing [N] signals. Strongest signal at [freq] MHz."
- Dynamic Type support throughout
- Reduce Motion: disable waterfall scroll animation, use discrete line updates
- High Contrast mode: increase waterfall contrast and UI element borders
- Keyboard navigation (macOS): all functions accessible without mouse
- CW keyer accessible to switch control users via Switch Control actions

---

## 14. Privacy & Security

### Data Minimization
- Callsign lookup responses cached locally; no usage analytics sent to lookup services
- No advertising, no telemetry (beyond opt-in crash reporting)
- QRZ.com credentials stored in Keychain, never in plaintext

### Keychain Usage
Store all credentials (QRZ, LoTW, ClubLog, Anthropic API key, etc.) in the iOS/macOS Keychain via `Security.framework` or the Swift `KeychainAccess` package.

### Network Privacy
- All HTTPS connections use modern TLS (1.2+)
- No HTTP cleartext connections except legacy telnet (DX cluster — standard in the ham community, document this to users)
- VPN passthrough: all connections work correctly behind a VPN (important for operators at remote sites)

### App Privacy Report
The app processes audio locally. When Core ML audio enhancement is enabled, audio never leaves the device. Document in App Privacy Report: audio is processed on-device only.

---

## 15. Testing Strategy

### Unit Tests (Swift Testing framework)
- ADIF parser: round-trip parse/export for 100+ sample files
- CW encoder/decoder: verify dit/dah sequences for all characters
- Callsign prefix parsing: comprehensive DXCC entity resolution
- Grid square / distance / bearing calculations
- SOTA/POTA reference validation
- Cabrillo export format compliance

### Integration Tests
- Hamlib bridge: mock rig responses for all supported rig command types
- DX cluster parser: parse sample spot lines from all major cluster software
- APRS packet parser: APRS protocol test vectors
- FT8 decode: decode known test vectors from WSJT-X reference implementation

### UI Tests
- Logbook CRUD operations
- Import/export round-trip
- Contest dupe checking with large logs
- Award progress calculation accuracy

### Performance Tests
- FFT processing: verify < 5ms for 4096-point FFT on iPhone 15
- Logbook query performance: 100,000 QSO table load < 200ms
- Core ML inference: CW decoder < 2ms per inference
- Waterfall render: 60fps sustained with 4096-column waterfall

---

## 16. Phased Roadmap

### Phase 1 — Foundation (Months 1–4)
- [ ] Project setup: SwiftUI multi-platform app, Swift Package structure
- [ ] Design system: colors, typography, component library
- [ ] SwiftData schema and CloudKit sync
- [ ] Core logbook: CRUD, ADIF import/export, callsign lookup
- [ ] Basic rig control: Hamlib bridge, USB serial, frequency/mode/PTT
- [ ] Audio I/O: AVAudioEngine setup, device selection, basic monitoring
- [ ] macOS navigation: sidebar, multi-window, menu bar
- [ ] iOS/iPad navigation: tab bar, split view
- [ ] App Store submission (basic logbook app for early user feedback)

### Phase 2 — Signal Processing (Months 5–8)
- [ ] Metal waterfall: FFT tap, rolling texture, color palettes
- [ ] FT8 engine: C library integration, decode, auto-sequence
- [ ] PSK31/RTTY via libfldigi bridge
- [ ] CW keyer: paddle input, straight key, audio keying, macros
- [ ] Traditional CW decoder (DSP-based)
- [ ] DX cluster: telnet client, spot parsing, filtering, band map
- [ ] Propagation: NOAA SWPC integration, solar dashboard
- [ ] Basic awards tracking: DXCC, WAS

### Phase 3 — AI & Intelligence (Months 9–12)
- [ ] Core ML CW decoder: model training, integration, confidence blending
- [ ] Audio enhancement AU: noise reduction Core ML model
- [ ] AI assistant: Anthropic API integration, ham radio system prompt
- [ ] Natural language logging: speech recognition + NLP extraction
- [ ] Band advisor: propagation + award goal fusion
- [ ] Smart log analysis: background insights generation
- [ ] Propagation ML: on-device prediction model

### Phase 4 — Advanced Features (Months 13–18)
- [ ] Satellite tracking: SGP4 implementation, Doppler correction, rotor control
- [ ] Full SOTA/POTA integration
- [ ] APRS: APRS-IS client, RF via TNC, map view, messaging
- [ ] Contesting: contest engine, Cabrillo export, rate display
- [ ] EmComm tools: ICS forms, net logging, Winlink integration
- [ ] Antenna modeling: NEC2C integration (macOS), calculator suite
- [ ] Repeater directory: RepeaterBook integration, CAT one-tap tune
- [ ] Live Activities / Dynamic Island (satellite pass)
- [ ] Widgets: propagation, spots, satellite pass

### Phase 5 — Polish & Platform (Months 19–24)
- [ ] watchOS companion app
- [ ] Siri Shortcuts and App Intents
- [ ] Spotlight integration
- [ ] Accessibility audit and remediation
- [ ] Performance profiling and optimization
- [ ] Localization: Japanese, German, Spanish (large ham communities)
- [ ] Premium tier: StoreKit 2, QRZ subscription tier, advanced AI features

---

## Appendix A: Key External Libraries

| Library | License | Purpose |
|---|---|---|
| Hamlib | LGPL 2.1 | Rig CAT control (400+ radios) |
| libjt9 / WSJT-X protocol | GPLv3 | FT8/FT4/JT65/WSPR decode/encode |
| libfldigi (core) | GPLv3 | PSK31, RTTY, Olivia, etc. |
| NEC2C | Public Domain | Antenna pattern modeling |
| ORSSerialPort | MIT | macOS serial port access |
| GRDB.swift | MIT | SQLite for local caches |

*Note: GPLv3 libraries (libjt9, libfldigi) may require open-sourcing the bridging layer or app under GPL if statically linked. Evaluate dynamic linking or LGPL alternatives before shipping.*

---

## Appendix B: Hamlib-Supported Rig Families

Hamlib supports: Icom (IC-7300, IC-7610, IC-705, IC-9700, and 80+ others), Yaesu (FT-991A, FTDX10, FTDX101, FT-3D, and 60+ others), Kenwood (TS-890S, TS-590SG, and 40+ others), Elecraft (K3, KX3, K4), FlexRadio (6300, 6600, 6700 via SmartSDR), TenTec, Alinco, and many more.

---

*HamStation Pro — Specification v1.0 Draft*  
*73 de the development team*
