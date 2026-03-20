# HamStation Pro — development tasks

# Workaround: Xcode 26.3 swift driver uses JIT mode for manifest compilation.
# SWIFT_EXEC=swiftc forces compile mode so SPM can produce manifest binaries.
export SWIFT_EXEC := "/usr/bin/swiftc"

# Default: list available tasks
default:
    @just --list

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build the macOS app
build-app: generate
    xcodebuild build -project HamStation.xcodeproj -scheme HamStation -destination 'platform=macOS'

# Clean and build the macOS app
build-app-clean: generate
    xcodebuild clean build -project HamStation.xcodeproj -scheme HamStation -destination 'platform=macOS'

# Run the macOS app (clean build to avoid stale binaries)
run: build-app-clean
    #!/usr/bin/env bash
    APP=$(find ~/Library/Developer/Xcode/DerivedData/HamStation-*/Build/Products/Debug/HamStation.app -maxdepth 0 2>/dev/null | head -1)
    if [ -n "$APP" ]; then
        open "$APP"
    else
        echo "ERROR: App not found in DerivedData. Build may have failed."
        exit 1
    fi

# Run without cleaning (faster, uses cached build)
run-fast: build-app
    #!/usr/bin/env bash
    APP=$(find ~/Library/Developer/Xcode/DerivedData/HamStation-*/Build/Products/Debug/HamStation.app -maxdepth 0 2>/dev/null | head -1)
    if [ -n "$APP" ]; then
        open "$APP"
    else
        echo "ERROR: App not found in DerivedData. Build may have failed."
        exit 1
    fi

# Open in Xcode (for running with previews/debugger)
open: generate
    open HamStation.xcodeproj

# Build the HamStationKit package
build:
    cd Packages/HamStationKit && swift build

# Build in release mode
build-release:
    cd Packages/HamStationKit && swift build -c release

# Run all tests
test:
    cd Packages/HamStationKit && swift test

# Run tests with verbose output
test-verbose:
    cd Packages/HamStationKit && swift test --verbose

# Clean build artifacts
clean:
    cd Packages/HamStationKit && swift package clean

# Resolve package dependencies
resolve:
    cd Packages/HamStationKit && swift package resolve

# Lint with SwiftLint (if installed)
lint:
    swiftlint lint Packages/HamStationKit/Sources/

# Run ADIF parser tests only
test-adif:
    cd Packages/HamStationKit && swift test --filter ADIFTests

# Run ADIF parser tests with verbose output
test-adif-verbose:
    cd Packages/HamStationKit && swift test --filter ADIFTests --verbose

# Syntax-check all ADIF source files (Swift 6 strict)
check-adif:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/ADIF/*.swift && echo "ADIF sources: OK"

# Syntax-check all non-GRDB model files (Swift 6 strict)
check-models:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Models/Band.swift Sources/Models/OperatingMode.swift Sources/Models/Continent.swift Sources/Models/RigState.swift Sources/Models/ConnectionState.swift && echo "Model sources: OK"

# Syntax-check all source files that don't need GRDB
check:
    @just check-adif
    @just check-models
    @just check-db
    @just check-networking
    @just check-rigcontrol
    @just check-dxcluster
    @just check-callsign
    @just check-utilities
    @just check-propagation
    @just check-awards
    @just check-audio
    @just check-phase4
    @just check-ai

# Compile ADIF module into a dylib (verifies full compilation, not just parsing)
compile-adif:
    cd Packages/HamStationKit && swiftc -emit-library -module-name HamStationADIF -swift-version 6 Sources/ADIF/*.swift -o /tmp/libHamStationADIF.dylib && echo "ADIF module: compiled OK"

# Run database tests only
test-db:
    cd Packages/HamStationKit && swift test --filter DatabaseTests

# Run database tests with verbose output
test-db-verbose:
    cd Packages/HamStationKit && swift test --filter DatabaseTests --verbose

# Syntax-check database source files (Swift 6 strict)
check-db:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Database/*.swift && echo "Database sources: OK"

# Run rig control tests only
test-rigcontrol:
    cd Packages/HamStationKit && swift test --filter RigControlTests

# Run rig control tests with verbose output
test-rigcontrol-verbose:
    cd Packages/HamStationKit && swift test --filter RigControlTests --verbose

# Run DX cluster tests only
test-dxcluster:
    cd Packages/HamStationKit && swift test --filter DXClusterTests

# Run DX cluster tests with verbose output
test-dxcluster-verbose:
    cd Packages/HamStationKit && swift test --filter DXClusterTests --verbose

# Run networking tests only
test-networking:
    cd Packages/HamStationKit && swift test --filter NetworkingTests

# Run networking tests with verbose output
test-networking-verbose:
    cd Packages/HamStationKit && swift test --filter NetworkingTests --verbose

# Run callsign lookup tests only
test-callsign:
    cd Packages/HamStationKit && swift test --filter CallsignLookupTests

# Syntax-check networking source files (Swift 6 strict)
check-networking:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Networking/*.swift && echo "Networking sources: OK"

# Syntax-check rig control source files (Swift 6 strict)
check-rigcontrol:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/RigControl/*.swift Sources/Models/ConnectionState.swift Sources/Models/RigState.swift Sources/Models/OperatingMode.swift && echo "RigControl sources: OK"

# Syntax-check DX cluster source files (Swift 6 strict)
check-dxcluster:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/DXCluster/*.swift Sources/Models/Band.swift Sources/Models/OperatingMode.swift Sources/RigControl/RigConnection.swift Sources/Models/ConnectionState.swift Sources/Models/RigState.swift && echo "DXCluster sources: OK"

# Syntax-check callsign lookup source files (Swift 6 strict)
check-callsign:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/CallsignLookup/*.swift Sources/Networking/*.swift && echo "CallsignLookup sources: OK"

# Run model tests only (DXCC resolver, grid square, etc.)
test-models:
    cd Packages/HamStationKit && swift test --filter ModelTests

# Run model tests with verbose output
test-models-verbose:
    cd Packages/HamStationKit && swift test --filter ModelTests --verbose

# Syntax-check utility source files (Swift 6 strict)
check-utilities:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Utilities/*.swift && echo "Utility sources: OK"

# Syntax-check propagation source files (Swift 6 strict)
check-propagation:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Propagation/SolarData.swift Sources/Propagation/PropagationDashboard.swift Sources/Networking/*.swift && echo "Propagation sources: OK"

# Syntax-check awards source files (Swift 6 strict)
check-awards:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Awards/DXCCResolver.swift Sources/Models/DXCCEntity.swift && echo "Awards sources: OK"

# Syntax-check macOS app UI files (Swift 6 strict)
check-ui:
    swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Packages/HamStationKit/Sources/UI/DesignSystem/Theme.swift && echo "Theme: OK"
    swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) HamStationMac/AppState.swift && echo "AppState: OK"

# Syntax-check all macOS app SwiftUI view files
check-mac-views:
    @echo "Checking macOS app view files..."
    @for f in HamStationMac/Windows/*.swift HamStationMac/Onboarding/*.swift; do \
        swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) "$$f" && echo "  $$f: OK" || echo "  $$f: FAILED"; \
    done

# List all macOS app UI files
list-ui:
    @echo "=== HamStationMac ==="
    @find HamStationMac -name "*.swift" | sort
    @echo ""
    @echo "=== Design System ==="
    @find Packages/HamStationKit/Sources/UI -name "*.swift" | sort

# Open the Xcode workspace
xcode:
    open HamStation.xcworkspace || open Packages/HamStationKit/Package.swift

# Run waterfall/FFT/ring buffer tests
test-waterfall:
    cd Packages/HamStationKit && swift test --filter "RingBufferTests|FFTProcessorTests"

# Run waterfall tests with verbose output
test-waterfall-verbose:
    cd Packages/HamStationKit && swift test --filter "RingBufferTests|FFTProcessorTests" --verbose

# Syntax-check waterfall UI source files (Swift 6 strict, requires Metal/MetalKit)
check-waterfall:
    @echo "Checking waterfall sources..."
    @for f in Packages/HamStationKit/Sources/UI/WaterfallView/*.swift; do \
        swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) "$$f" && echo "  $$f: OK" || echo "  $$f: FAILED"; \
    done

# Syntax-check audio engine source files (Swift 6 strict)
check-audio:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AudioEngine/*.swift && echo "AudioEngine sources: OK"

# Run CW keyer and decoder tests
test-cw:
    cd Packages/HamStationKit && swift test --filter "CWKeyerTests|CWDecoderTests"

# Run CW tests with verbose output
test-cw-verbose:
    cd Packages/HamStationKit && swift test --filter "CWKeyerTests|CWDecoderTests" --verbose

# Run FFT processor tests
test-fft:
    cd Packages/HamStationKit && swift test --filter FFTProcessorTests

# Run all audio engine tests (FFT, CW, ring buffer)
test-audio:
    cd Packages/HamStationKit && swift test --filter "FFTProcessorTests|CWKeyerTests|CWDecoderTests|RingBufferTests"

# Run all audio engine tests with verbose output
test-audio-verbose:
    cd Packages/HamStationKit && swift test --filter "FFTProcessorTests|CWKeyerTests|CWDecoderTests|RingBufferTests" --verbose

# Syntax-check AI source files (Swift 6 strict)
check-ai:
    @echo "Checking AI sources..."
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/AIPrivacySettings.swift && echo "  AIPrivacySettings: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/AIAssistant.swift Sources/AI/AIPrivacySettings.swift && echo "  AIAssistant: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/NaturalLanguageLogger.swift && echo "  NaturalLanguageLogger: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/SpeechRecognizer.swift && echo "  SpeechRecognizer: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/BandAdvisor.swift Sources/Propagation/SolarData.swift Sources/Models/DXCCEntity.swift Sources/Models/Band.swift && echo "  BandAdvisor: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/SmartLogAnalysis.swift && echo "  SmartLogAnalysis: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/CoreMLCWDecoder.swift Sources/AudioEngine/CWDecoder.swift Sources/AudioEngine/CWKeyer.swift && echo "  CoreMLCWDecoder: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/AudioEnhancer.swift && echo "  AudioEnhancer: OK"
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/AI/QSLAdvisor.swift && echo "  QSLAdvisor: OK"

# Run AI-related tests (NaturalLanguageLogger, BandAdvisor)
test-ai:
    cd Packages/HamStationKit && swift test --filter "NaturalLanguageLogger|BandAdvisor"

# Run AI tests with verbose output
test-ai-verbose:
    cd Packages/HamStationKit && swift test --filter "NaturalLanguageLogger|BandAdvisor" --verbose

# Syntax-check EmComm source files (Swift 6 strict)
check-emcomm:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/EmComm/*.swift && echo "EmComm sources: OK"

# Syntax-check Antenna source files (Swift 6 strict)
check-antenna:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Antenna/*.swift && echo "Antenna sources: OK"

# Syntax-check Repeater source files (Swift 6 strict)
check-repeater:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Repeater/*.swift && echo "Repeater sources: OK"

# Syntax-check CW Training source files (Swift 6 strict)
check-cwtraining:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/CWTraining/*.swift && echo "CWTraining sources: OK"

# Syntax-check SOTA/POTA tracker (Swift 6 strict)
check-sotapota:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Awards/SOTAPOTATracker.swift Sources/Awards/FullAwardsEngine.swift && echo "SOTA/POTA sources: OK"

# Syntax-check satellite source files (Swift 6 strict)
check-satellite:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Satellite/*.swift && echo "Satellite sources: OK"

# Syntax-check APRS source files (Swift 6 strict)
check-aprs:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/APRS/*.swift Sources/Models/ConnectionState.swift && echo "APRS sources: OK"

# Syntax-check contest source files (Swift 6 strict)
check-contest:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 Sources/Contest/*.swift && echo "Contest sources: OK"

# Syntax-check all Phase 4 source files
check-phase4:
    @just check-emcomm
    @just check-antenna
    @just check-repeater
    @just check-cwtraining
    @just check-sotapota
    @just check-satellite
    @just check-aprs
    @just check-contest

# Syntax-check Phase 4 macOS views
check-phase4-views:
    @echo "Checking Phase 4 views..."
    @for f in HamStationMac/Windows/EmCommView.swift HamStationMac/Windows/SOTAPOTAView.swift HamStationMac/Windows/RepeaterView.swift HamStationMac/Windows/AntennaView.swift HamStationMac/Windows/CWTrainingView.swift HamStationMac/Windows/SatelliteView.swift HamStationMac/Windows/APRSView.swift HamStationMac/Windows/ContestView.swift; do \
        swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) "$$f" && echo "  $$f: OK" || echo "  $$f: FAILED"; \
    done

# Run satellite tests only
test-satellite:
    cd Packages/HamStationKit && swift test --filter SatelliteTests

# Run satellite tests with verbose output
test-satellite-verbose:
    cd Packages/HamStationKit && swift test --filter SatelliteTests --verbose

# Run APRS tests only
test-aprs:
    cd Packages/HamStationKit && swift test --filter APRSTests

# Run APRS tests with verbose output
test-aprs-verbose:
    cd Packages/HamStationKit && swift test --filter APRSTests --verbose

# Run contest tests only
test-contest:
    cd Packages/HamStationKit && swift test --filter ContestTests

# Run contest tests with verbose output
test-contest-verbose:
    cd Packages/HamStationKit && swift test --filter ContestTests --verbose

# Run antenna calculator tests only
test-antenna:
    cd Packages/HamStationKit && swift test --filter AntennaCalculatorTests

# Run antenna calculator tests with verbose output
test-antenna-verbose:
    cd Packages/HamStationKit && swift test --filter AntennaCalculatorTests --verbose

# Run Koch trainer tests only
test-koch:
    cd Packages/HamStationKit && swift test --filter KochTrainerTests

# Run Koch trainer tests with verbose output
test-koch-verbose:
    cd Packages/HamStationKit && swift test --filter KochTrainerTests --verbose

# Run all Phase 4 tests
test-phase4:
    cd Packages/HamStationKit && swift test --filter "AntennaCalculatorTests|KochTrainerTests|SatelliteTests|APRSTests|ContestTests"

# Run all Phase 4 tests with verbose output
test-phase4-verbose:
    cd Packages/HamStationKit && swift test --filter "AntennaCalculatorTests|KochTrainerTests|SatelliteTests|APRSTests|ContestTests" --verbose

# Build macOS app and show only errors (quick validation)
build-check: generate
    xcodebuild build -project HamStation.xcodeproj -scheme HamStation -destination 'platform=macOS' 2>&1 | grep "error:" | sort -u; echo "Done."

# Run FT8 tests only
test-ft8:
    cd Packages/HamStationKit && swift test --filter FT8Tests

# Run FT8 tests with verbose output
test-ft8-verbose:
    cd Packages/HamStationKit && swift test --filter FT8Tests --verbose

# Syntax-check DigitalModes source files (Swift 6 strict)
check-digitalmodes:
    cd Packages/HamStationKit && swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) Sources/DigitalModes/*.swift && echo "DigitalModes sources: OK"

# Run PSK31 tests only
test-psk31:
    cd Packages/HamStationKit && swift test --filter "VaricodeTests|PSK31DecoderTests"

# Run PSK31 tests with verbose output
test-psk31-verbose:
    cd Packages/HamStationKit && swift test --filter "VaricodeTests|PSK31DecoderTests" --verbose

# Run RTTY tests only
test-rtty:
    cd Packages/HamStationKit && swift test --filter "BaudotCodeTests|RTTYDecoderTests"

# Run RTTY tests with verbose output
test-rtty-verbose:
    cd Packages/HamStationKit && swift test --filter "BaudotCodeTests|RTTYDecoderTests" --verbose

# Run all digital mode tests (FT8, PSK31, RTTY)
test-digital:
    cd Packages/HamStationKit && swift test --filter "FT8Tests|VaricodeTests|PSK31DecoderTests|BaudotCodeTests|RTTYDecoderTests"

# Run all digital mode tests with verbose output
test-digital-verbose:
    cd Packages/HamStationKit && swift test --filter "FT8Tests|VaricodeTests|PSK31DecoderTests|BaudotCodeTests|RTTYDecoderTests" --verbose

# Syntax-check globe view source files (Swift 6 strict)
check-globe:
    @echo "Checking globe sources..."
    @for f in Packages/HamStationKit/Sources/UI/GlobeView/*.swift; do \
        swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) "$$f" && echo "  $$f: OK" || echo "  $$f: FAILED"; \
    done

# Syntax-check demo mode source files (Swift 6 strict)
check-demo:
    @echo "Checking demo sources..."
    @for f in HamStationMac/Demo/*.swift; do \
        swiftc -parse -swift-version 6 -target arm64-apple-macosx15.0 -sdk $(xcrun --show-sdk-path --sdk macosx) "$$f" && echo "  $$f: OK" || echo "  $$f: FAILED"; \
    done

# Check if Kokoro TTS (mlx-audio) is installed
check-tts:
    @python3 -c "import mlx_audio; print('Kokoro TTS (mlx-audio): Available')" 2>/dev/null || echo "Kokoro TTS: Not installed — run 'pip install mlx-audio'"

# Install Kokoro TTS engine (mlx-audio + all Kokoro dependencies)
install-tts:
    pip install "mlx-audio[kokoro]" misaki num2words phonemizer spacy

# Count lines of code
loc:
    @find Packages/HamStationKit/Sources -name "*.swift" | xargs wc -l | tail -1
    @echo "Test lines:"
    @find Packages/HamStationKit/Tests -name "*.swift" | xargs wc -l | tail -1
    @echo "Mac app lines:"
    @find HamStationMac -name "*.swift" | xargs wc -l | tail -1
