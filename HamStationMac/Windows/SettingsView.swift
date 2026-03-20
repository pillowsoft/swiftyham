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
            AISettingsTab()
                .tabItem { Label("AI", systemImage: "brain") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 380)
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

// MARK: - AI

private struct AISettingsTab: View {
    @State private var aiEnabled: Bool = false
    @State private var includeCallsign: Bool = true
    @State private var includeLocation: Bool = false
    @State private var includeAwardProgress: Bool = false
    @State private var includeRecentQSOs: Bool = false
    @State private var apiKey: String = ""
    @State private var enableNLLogging: Bool = false
    @State private var enableSmartAnalysis: Bool = false

    var body: some View {
        Form {
            Section("AI Assistant") {
                Toggle("Enable AI Assistant", isOn: $aiEnabled)
                    .help("Requires an Anthropic API key. AI context is sent only when you ask a question.")

                if aiEnabled {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .font(.system(.body, design: .monospaced))

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
