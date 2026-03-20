// SettingsView.swift — macOS Settings window
// Tabs: General, Rig, Cluster, Callsign Lookup, AI, About

import SwiftUI
import HamStationKit

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            RigSettingsTab()
                .tabItem { Label("Rig", systemImage: "antenna.radiowaves.left.and.right") }
            ClusterSettingsTab()
                .tabItem { Label("Cluster", systemImage: "globe") }
            CallsignLookupSettingsTab()
                .tabItem { Label("Callsign Lookup", systemImage: "person.text.rectangle") }
            LogSubmissionSettingsTab()
                .tabItem { Label("Log Upload", systemImage: "arrow.up.doc") }
            VoiceSettingsTab()
                .tabItem { Label("Voice", systemImage: "waveform") }
            RecordingSettingsTab()
                .tabItem { Label("Recording", systemImage: "record.circle") }
            AISettingsTab()
                .tabItem { Label("AI", systemImage: "brain") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState

        Form {
            TextField("Operator Callsign", text: $state.operatorCallsign)
                .font(.system(.body, design: .monospaced))
                .onChange(of: appState.operatorCallsign) { _, _ in
                    appState.saveToDefaults()
                }

            Picker("License Class", selection: $state.licenseClass) {
                Text("Technician").tag("Technician")
                Text("General").tag("General")
                Text("Extra").tag("Extra")
            }
            .onChange(of: appState.licenseClass) { _, _ in
                appState.saveToDefaults()
            }

            TextField("Grid Square", text: $state.gridSquare)
                .font(.system(.body, design: .monospaced))
                .onChange(of: appState.gridSquare) { _, _ in
                    appState.saveToDefaults()
                }

            Divider()

            Toggle("Night Mode", isOn: $state.isNightMode)
                .help("Deep red theme for dark-adapted vision during nighttime operating.")
                .onChange(of: appState.isNightMode) { _, _ in
                    appState.saveToDefaults()
                }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Rig

private struct RigSettingsTab: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var rigHost: String = ""
    @State private var rigPort: String = ""
    @State private var testResult: String? = nil
    @State private var isTesting: Bool = false

    var body: some View {
        Form {
            Section("rigctld Connection") {
                TextField("Host", text: $rigHost)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: rigHost) { _, newValue in
                        let port = UInt16(rigPort) ?? 4532
                        appState.saveRigSettings(host: newValue, port: port)
                    }
                TextField("Port", text: $rigPort)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: rigPort) { _, newValue in
                        let port = UInt16(newValue) ?? 4532
                        appState.saveRigSettings(host: rigHost, port: port)
                    }

                HStack {
                    Button("Test Connection") {
                        Task { await testRigConnection() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("failed") || result.contains("Error") || result.contains("Could not") ? .red : .green)
                    }
                }
            }

            Section {
                Text("HamStation connects to your radio via rigctld (part of Hamlib). Install Hamlib and run rigctld for your radio model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            rigHost = appState.savedRigHost
            rigPort = String(appState.savedRigPort)
        }
    }

    @MainActor
    private func testRigConnection() async {
        isTesting = true
        testResult = nil
        let port = UInt16(rigPort) ?? 4532
        do {
            try await services.connectRig(host: rigHost, port: port)
            testResult = "Connected successfully!"
            await services.disconnectRig()
        } catch {
            testResult = "Connection failed -- \(error.localizedDescription)"
        }
        isTesting = false
    }
}

// MARK: - Cluster

private struct ClusterSettingsTab: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var clusterHost: String = ""
    @State private var clusterPort: String = ""
    @State private var testResult: String? = nil
    @State private var isTesting: Bool = false

    var body: some View {
        Form {
            Section("DX Cluster Connection") {
                TextField("Host", text: $clusterHost)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: clusterHost) { _, newValue in
                        let port = UInt16(clusterPort) ?? 7373
                        appState.saveClusterSettings(host: newValue, port: port)
                    }
                TextField("Port", text: $clusterPort)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: clusterPort) { _, newValue in
                        let port = UInt16(newValue) ?? 7373
                        appState.saveClusterSettings(host: clusterHost, port: port)
                    }

                HStack {
                    Button("Test Connection") {
                        Task { await testClusterConnection() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("failed") || result.contains("Error") || result.contains("Could not") ? .red : .green)
                    }
                }
            }

            Section {
                Text("Popular DX clusters: dxc.nc7j.com:7373, dxc.k3lr.com:7373, skimmer.telnet.dx-is.cz:7300")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            clusterHost = appState.savedClusterHost
            clusterPort = String(appState.savedClusterPort)
        }
    }

    @MainActor
    private func testClusterConnection() async {
        isTesting = true
        testResult = nil
        let port = UInt16(clusterPort) ?? 7373
        do {
            try await services.connectCluster(
                host: clusterHost,
                port: port,
                callsign: appState.operatorCallsign
            )
            testResult = "Connected successfully!"
            await services.disconnectCluster()
        } catch {
            testResult = "Connection failed -- \(error.localizedDescription)"
        }
        isTesting = false
    }
}

// MARK: - Callsign Lookup

private struct CallsignLookupSettingsTab: View {
    @State private var qrzApiKey: String = ""
    @State private var hamdbEnabled: Bool = true

    var body: some View {
        Form {
            Section("QRZ.com") {
                SecureField("API Key", text: $qrzApiKey)
                    .font(.system(.body, design: .monospaced))
                Text("Requires a QRZ.com XML subscription. Get yours at qrz.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("HamDB") {
                Toggle("Enable HamDB lookups", isOn: $hamdbEnabled)
                Text("HamDB provides free US callsign lookups. No API key required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Log Submission

private struct LogSubmissionSettingsTab: View {
    @State private var qrzLogbookKey: String = ""
    @State private var clubLogEmail: String = ""
    @State private var clubLogPassword: String = ""
    @State private var clubLogCallsign: String = ""
    @State private var eqslUsername: String = ""
    @State private var eqslPassword: String = ""
    @State private var autoUploadEnabled: Bool = false

    var body: some View {
        Form {
            Section("QRZ Logbook") {
                SecureField("API Key", text: $qrzLogbookKey)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: qrzLogbookKey) { _, val in
                        try? KeychainHelper.save(key: "qrz_logbook_key", value: val)
                    }
                Text("Upload QSOs to your QRZ.com logbook. Get your API key from qrz.com/page/logbook_api.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Club Log") {
                TextField("Email", text: $clubLogEmail)
                    .onChange(of: clubLogEmail) { _, val in
                        try? KeychainHelper.save(key: "clublog_email", value: val)
                    }
                SecureField("Password", text: $clubLogPassword)
                    .onChange(of: clubLogPassword) { _, val in
                        try? KeychainHelper.save(key: "clublog_password", value: val)
                    }
                TextField("Callsign", text: $clubLogCallsign)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: clubLogCallsign) { _, val in
                        try? KeychainHelper.save(key: "clublog_callsign", value: val)
                    }
                Text("Upload QSOs to clublog.org for DXCC and OQRS matching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("eQSL") {
                TextField("Username", text: $eqslUsername)
                    .onChange(of: eqslUsername) { _, val in
                        try? KeychainHelper.save(key: "eqsl_username", value: val)
                    }
                SecureField("Password", text: $eqslPassword)
                    .onChange(of: eqslPassword) { _, val in
                        try? KeychainHelper.save(key: "eqsl_password", value: val)
                    }
                Text("Send electronic QSL cards via eqsl.cc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            qrzLogbookKey = KeychainHelper.load(key: "qrz_logbook_key") ?? ""
            clubLogEmail = KeychainHelper.load(key: "clublog_email") ?? ""
            clubLogPassword = KeychainHelper.load(key: "clublog_password") ?? ""
            clubLogCallsign = KeychainHelper.load(key: "clublog_callsign") ?? ""
            eqslUsername = KeychainHelper.load(key: "eqsl_username") ?? ""
            eqslPassword = KeychainHelper.load(key: "eqsl_password") ?? ""
        }
    }
}

// MARK: - AI

private struct AISettingsTab: View {
    @State private var aiEnabled: Bool = false
    @State private var provider: AIPrivacySettings.AIProvider = .local
    @State private var includeCallsign: Bool = true
    @State private var includeLocation: Bool = false
    @State private var includeAwardProgress: Bool = false
    @State private var includeRecentQSOs: Bool = false
    @State private var apiKey: String = ""
    @State private var enableNLLogging: Bool = false
    @State private var enableSmartAnalysis: Bool = false
    @State private var availableRAM: String = ""

    var body: some View {
        Form {
            Section("AI Assistant") {
                Toggle("Enable AI Assistant", isOn: $aiEnabled)

                if aiEnabled {
                    Picker("Backend", selection: $provider) {
                        ForEach(AIPrivacySettings.AIProvider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    switch provider {
                    case .local:
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Qwen3 via MLX — runs entirely on your Mac")
                                    .font(.caption)
                                Text("Available RAM: \(availableRAM)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("Requires ~8 GB free RAM for the 4B model. No data leaves your Mac.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                    case .openRouter:
                        SecureField("OpenRouter API Key", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: apiKey) { _, val in
                                try? KeychainHelper.save(key: "openrouter_api_key", value: val)
                            }
                        Text("Uses Claude via openrouter.ai. Get your key at openrouter.ai/keys.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .anthropic:
                        SecureField("Anthropic API Key", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: apiKey) { _, val in
                                try? KeychainHelper.save(key: "anthropic_api_key", value: val)
                            }
                        Text("Direct Anthropic API. Get your key at console.anthropic.com.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Text("Data shared with AI (per request):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Include my callsign", isOn: $includeCallsign)
                        .padding(.leading, 16)
                    Toggle("Include my grid square", isOn: $includeLocation)
                        .padding(.leading, 16)
                    Toggle("Include award progress", isOn: $includeAwardProgress)
                        .padding(.leading, 16)
                    Toggle("Include recent QSO history", isOn: $includeRecentQSOs)
                        .padding(.leading, 16)
                }
            }

            Section("On-Device Features") {
                Toggle("Natural language logging (speech)", isOn: $enableNLLogging)
                    .help("Uses Apple Speech framework on-device. No audio data is sent to the cloud.")
                Toggle("Smart log analysis", isOn: $enableSmartAnalysis)
                    .help("Analyzes your logbook locally for operating insights. No data leaves your Mac.")

                Text("On-device features use Apple frameworks and Core ML. No data is sent to any cloud service.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            let ram = ProcessInfo.processInfo.physicalMemory
            availableRAM = String(format: "%.0f GB", Double(ram) / 1_073_741_824)
            // Default to local if enough RAM, otherwise suggest OpenRouter
            if ram < 16_000_000_000 && provider == .local {
                provider = .openRouter
            }
            apiKey = KeychainHelper.load(key: provider == .openRouter ? "openrouter_api_key" : "anthropic_api_key") ?? ""
        }
    }
}

// MARK: - Voice

private struct VoiceSettingsTab: View {
    @Environment(AppState.self) var appState
    @StateObject private var speechEngine = SpeechEngine()

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Text-to-Speech Engine") {
                Picker("Backend", selection: $state.ttsBackend) {
                    Text("Auto (Best Available)").tag("auto")
                    Text("Kokoro (MLX)").tag("kokoro")
                    Text("System Voice").tag("system")
                }
                .onChange(of: appState.ttsBackend) { _, newValue in
                    switch newValue {
                    case "kokoro": speechEngine.preferredBackend = .kokoro
                    case "system": speechEngine.preferredBackend = .system
                    default: speechEngine.preferredBackend = .auto
                    }
                }

                HStack {
                    Image(systemName: speechEngine.kokoroAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(speechEngine.kokoroAvailable ? .green : .orange)
                    if speechEngine.kokoroAvailable {
                        Text("Kokoro: Available")
                            .font(.caption)
                    } else {
                        Text("Kokoro: Not installed — run `pip install mlx-audio`")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Kokoro Voice", selection: $state.kokoroVoice) {
                    ForEach(SpeechEngine.availableKokoroVoices(), id: \.id) { voice in
                        Text("\(voice.name) — \(voice.description)")
                            .tag(voice.id)
                    }
                }
                .disabled(!speechEngine.kokoroAvailable && appState.ttsBackend != "system")
                .onChange(of: appState.kokoroVoice) { _, newValue in
                    speechEngine.kokoroVoice = newValue
                }

                Button("Test Voice") {
                    speechEngine.kokoroVoice = appState.kokoroVoice
                    speechEngine.speak("CQ CQ CQ, this is HamStation Pro, testing voice output.")
                }
                .buttonStyle(.bordered)
            }

            Section("Demo Narration") {
                Toggle("Enable narration during demo", isOn: $state.narrationEnabled)
            }

            Section("CW Readback") {
                Toggle("Enable CW decoded text readback", isOn: $state.cwReadbackEnabled)

                Picker("Readback Mode", selection: $state.cwReadbackMode) {
                    Text("Characters (NATO phonetic)").tag("characters")
                    Text("Words").tag("words")
                    Text("Sentences").tag("sentences")
                }
                .disabled(!appState.cwReadbackEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Recording

private struct RecordingSettingsTab: View {
    @AppStorage("recordingCodec") private var useHEVC: Bool = false
    @AppStorage("recordingFrameRate") private var frameRate: Int = 30
    @AppStorage("recordingScale") private var scaleFactor: Double = 1.0

    var body: some View {
        Form {
            Section("Video Codec") {
                Picker("Codec", selection: $useHEVC) {
                    Text("H.264 (compatible)").tag(false)
                    Text("HEVC / H.265 (smaller files)").tag(true)
                }
            }

            Section("Quality") {
                Picker("Frame Rate", selection: $frameRate) {
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }

                Picker("Resolution Scale", selection: $scaleFactor) {
                    Text("1x (window size)").tag(1.0)
                    Text("0.75x (smaller file)").tag(0.75)
                    Text("0.5x (compact)").tag(0.5)
                }
            }

            Section {
                Text("Recording captures the HamStation window with all audio (including Kokoro TTS). ScreenCaptureKit will prompt for permission on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("For live streaming, we recommend OBS Studio which can capture this window natively.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "FF6A00"))

            Text("HamStation Pro")
                .font(.title.bold())

            Text("Version 1.0.0 (Build 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("The modern amateur radio station for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Text("73 de the development team")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(try! ServiceContainer())
}
