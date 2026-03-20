// FirstRunWizard.swift — Multi-step onboarding wizard
// Shown on first launch. Collects operator profile, optional logbook import,
// rig setup, and DX cluster configuration.

import SwiftUI
import HamStationKit

struct FirstRunWizard: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var currentStep: WizardStep = .welcome

    enum WizardStep: Int, CaseIterable {
        case welcome = 0
        case profile = 1
        case importLogbook = 2
        case rigSetup = 3
        case done = 4

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .profile: return "Operator Profile"
            case .importLogbook: return "Import Logbook"
            case .rigSetup: return "Rig Setup"
            case .done: return "All Set"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            progressIndicator
                .padding(.top, 24)

            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .profile:
                    profileStep
                case .importLogbook:
                    importStep
                case .rigSetup:
                    rigSetupStep
                case .done:
                    doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            if currentStep != .welcome && currentStep != .done {
                navigationButtons
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(WizardStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color(hex: "FF6A00") : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "FF6A00"))

            Text("Welcome to HamStation Pro")
                .font(.largeTitle.bold())

            Text("The modern amateur radio station for macOS.\nLog contacts, track DX, monitor propagation, and more.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                withAnimation { currentStep = .profile }
            } label: {
                Text("Get Started")
                    .frame(width: 160)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "FF6A00"))
            .controlSize(.large)

            Button {
                // Skip wizard, set demo defaults, and launch demo mode
                appState.operatorCallsign = "W1AW"
                appState.gridSquare = "FN31"
                appState.licenseClass = "Extra"
                appState.isDemoMode = true
                appState.hasCompletedOnboarding = true
                appState.saveToDefaults()
            } label: {
                Text("Try Demo")
                    .frame(width: 160)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Step 2: Operator Profile

    @State private var callsign: String = ""
    @State private var licenseClass: String = "Extra"
    @State private var gridSquare: String = ""
    @State private var operatorName: String = ""
    @State private var callsignError: String? = nil
    @State private var gridError: String? = nil

    private var profileStep: some View {
        VStack(spacing: 24) {
            Text("Operator Profile")
                .font(.title.bold())

            Text("Tell us about your station.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Form {
                TextField("Callsign", text: $callsign, prompt: Text("W1AW"))
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: callsign) { _, newValue in
                        callsign = newValue.uppercased()
                        callsignError = validateCallsign(newValue) ? nil : "Invalid callsign format"
                    }
                if let error = callsignError, !callsign.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Picker("License Class", selection: $licenseClass) {
                    Text("Technician").tag("Technician")
                    Text("General").tag("General")
                    Text("Extra").tag("Extra")
                }

                TextField("Grid Square", text: $gridSquare, prompt: Text("FN31pr"))
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: gridSquare) { _, newValue in
                        gridError = validateGrid(newValue) ? nil : "Must be 4 or 6 character Maidenhead grid"
                    }
                if let error = gridError, !gridSquare.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                TextField("Name (optional)", text: $operatorName, prompt: Text("Your name"))
            }
            .formStyle(.grouped)
            .frame(maxWidth: 400)
        }
        .padding()
    }

    // MARK: - Step 3: Import Logbook

    @State private var importFileURL: URL? = nil
    @State private var importPreview: String? = nil
    @State private var parseResult: ADIFParser.ParseResult? = nil
    @State private var isImporting: Bool = false
    @State private var importProgress: Double = 0.0
    @State private var importError: String? = nil
    @State private var importComplete: Bool = false

    private var importStep: some View {
        VStack(spacing: 24) {
            Text("Import Logbook")
                .font(.title.bold())

            Text("Import contacts from another logger? (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)

                Button("Choose ADIF File...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.init(filenameExtension: "adi")!, .init(filenameExtension: "adif")!]
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        importFileURL = url
                        importError = nil
                        importComplete = false
                        do {
                            let result = try ADIFParser.parse(url: url, mode: .lenient)
                            parseResult = result
                            let warningCount = result.warnings.count
                            importPreview = "Found \(result.records.count) QSOs. \(warningCount) warning\(warningCount == 1 ? "" : "s")."
                        } catch {
                            importPreview = nil
                            importError = "Failed to read file: \(error.localizedDescription)"
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isImporting)

                if let preview = importPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if let error = importError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if parseResult != nil && !importComplete {
                    Button("Import QSOs") {
                        Task { await performImport() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "FF6A00"))
                    .disabled(isImporting)
                }

                if isImporting {
                    VStack(spacing: 4) {
                        ProgressView(value: importProgress)
                            .frame(width: 200)
                        Text("Importing... \(Int(importProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if importComplete {
                    Label("Import complete!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                }

                Button("Skip -- start with an empty logbook") {
                    withAnimation { currentStep = .rigSetup }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                .disabled(isImporting)
            }
        }
        .padding()
    }

    @MainActor
    private func performImport() async {
        guard let result = parseResult else { return }
        isImporting = true
        importProgress = 0.0
        importError = nil

        let myCall = callsign.isEmpty ? "N0CALL" : callsign
        let records = result.records
        let total = records.count
        let batchSize = 100

        do {
            let logbook = try await services.database.defaultLogbook()

            for batchStart in stride(from: 0, to: total, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, total)
                let batch = records[batchStart..<batchEnd]

                for record in batch {
                    if let qso = Self.makeQSO(from: record, myCallsign: myCall, logbookId: logbook.id) {
                        try await services.database.createQSO(qso)
                    }
                }

                importProgress = Double(batchEnd) / Double(total)
            }

            importComplete = true
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }

        isImporting = false
    }

    /// Converts an ADIF record to a QSO model object.
    static func makeQSO(from record: ADIFRecord, myCallsign: String, logbookId: UUID?) -> QSO? {
        guard let callsign = record["CALL"], !callsign.isEmpty else { return nil }

        // Parse date/time
        let dateStr = record["QSO_DATE"] ?? ""
        let timeStr = record["TIME_ON"] ?? ""
        let datetimeOn: Date
        if let parsed = ADIFDateFormatter.parseDateTime(date: dateStr, time: timeStr) {
            datetimeOn = parsed
        } else if let dateOnly = ADIFDateFormatter.parseDate(dateStr)?.date {
            datetimeOn = dateOnly
        } else {
            datetimeOn = Date()
        }

        // Parse optional end time
        var datetimeOff: Date? = nil
        if let dateOffStr = record["QSO_DATE_OFF"], let timeOffStr = record["TIME_OFF"] {
            datetimeOff = ADIFDateFormatter.parseDateTime(date: dateOffStr, time: timeOffStr)
        }

        // Parse band
        let bandStr = record["BAND"] ?? "20m"
        let band = Band(rawValue: bandStr) ?? .band20m

        // Parse mode
        let modeStr = record["MODE"] ?? "SSB"
        let mode = OperatingMode(rawValue: modeStr) ?? .ssb

        // Parse frequency (ADIF FREQ is in MHz)
        var frequencyHz: Double = band.frequencyRange.lowerBound
        if let freqStr = record["FREQ"], let freqMHz = Double(freqStr) {
            frequencyHz = freqMHz * 1_000_000.0
        }

        // RST
        let rstSent = record["RST_SENT"] ?? mode.defaultRST
        let rstRcvd = record["RST_RCVD"] ?? mode.defaultRST

        // Optional fields
        let txPower: Double? = record["TX_PWR"].flatMap { Double($0) }
        let myGrid = record["MY_GRIDSQUARE"]
        let theirGrid = record["GRIDSQUARE"]
        let continent = record["CONT"]
        let cqZone = record["CQ_ZONE"].flatMap { Int($0) }
        let ituZone = record["ITUZ"].flatMap { Int($0) }
        let name = record["NAME"]
        let qth = record["QTH"]
        let comment = record["COMMENT"]
        let dxccId = record["DXCC"].flatMap { Int($0) }
        let stationCall = record["STATION_CALLSIGN"] ?? myCallsign

        return QSO(
            callsign: callsign.uppercased(),
            myCallsign: stationCall,
            band: band,
            frequencyHz: frequencyHz,
            mode: mode,
            datetimeOn: datetimeOn,
            datetimeOff: datetimeOff,
            rstSent: rstSent,
            rstReceived: rstRcvd,
            txPowerWatts: txPower,
            myGrid: myGrid,
            theirGrid: theirGrid,
            dxccEntityId: dxccId,
            continent: continent,
            cqZone: cqZone,
            ituZone: ituZone,
            name: name,
            qth: qth,
            comment: comment,
            logbookId: logbookId
        )
    }

    // MARK: - Step 4: Rig Setup

    @State private var rigHost: String = "localhost"
    @State private var rigPort: String = "4532"
    @State private var rigTestResult: String? = nil
    @State private var rigTesting: Bool = false

    private var rigSetupStep: some View {
        VStack(spacing: 24) {
            Text("Rig Setup")
                .font(.title.bold())

            Text("Connect to your radio via rigctld? (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Form {
                Section("rigctld Connection") {
                    TextField("Host", text: $rigHost)
                        .font(.system(.body, design: .monospaced))
                    TextField("Port", text: $rigPort)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Button("Test Connection") {
                        Task { await testRigConnection() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(rigTesting)

                    if rigTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = rigTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Could not") || result.contains("failed") || result.contains("Error") ? .red : .green)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 400)

            Button("Skip -- I'll set this up later") {
                withAnimation { currentStep = .done }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding()
    }

    @MainActor
    private func testRigConnection() async {
        rigTesting = true
        rigTestResult = nil
        let port = UInt16(rigPort) ?? 4532
        do {
            try await services.connectRig(host: rigHost, port: port)
            rigTestResult = "Connected to rigctld at \(rigHost):\(rigPort)"
            appState.saveRigSettings(host: rigHost, port: port)
            await services.disconnectRig()
        } catch {
            rigTestResult = "Could not connect to rigctld at \(rigHost):\(rigPort)"
        }
        rigTesting = false
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                if !callsign.isEmpty {
                    Label("Callsign: \(callsign)", systemImage: "checkmark.circle")
                        .font(.body)
                }
                if !gridSquare.isEmpty {
                    Label("Grid: \(gridSquare)", systemImage: "checkmark.circle")
                        .font(.body)
                }
                Label("License: \(licenseClass)", systemImage: "checkmark.circle")
                    .font(.body)
                if importComplete {
                    Label("Logbook imported", systemImage: "checkmark.circle")
                        .font(.body)
                }
            }
            .foregroundStyle(.secondary)

            Button {
                appState.operatorCallsign = callsign.isEmpty ? "N0CALL" : callsign
                appState.licenseClass = licenseClass
                appState.gridSquare = gridSquare
                appState.hasCompletedOnboarding = true
                appState.saveToDefaults()
            } label: {
                Text("Open HamStation Pro")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "FF6A00"))
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                withAnimation {
                    if let prev = WizardStep(rawValue: currentStep.rawValue - 1) {
                        currentStep = prev
                    }
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Next") {
                withAnimation {
                    if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
                        currentStep = next
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "FF6A00"))
            .disabled(currentStep == .profile && callsign.isEmpty)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Validation

    private func validateCallsign(_ call: String) -> Bool {
        guard !call.isEmpty else { return true }
        // Basic validation: 1-2 letter prefix + digit + 1-3 letter suffix
        let pattern = #"^[A-Z]{1,2}\d[A-Z]{1,3}$"#
        return call.uppercased().range(of: pattern, options: .regularExpression) != nil
    }

    private func validateGrid(_ grid: String) -> Bool {
        guard !grid.isEmpty else { return true }
        // Maidenhead: 4 chars (AA00) or 6 chars (AA00aa)
        let pattern4 = #"^[A-R]{2}\d{2}$"#
        let pattern6 = #"^[A-R]{2}\d{2}[a-x]{2}$"#
        let upper = grid.count <= 4 ? grid.uppercased() : String(grid.prefix(4)).uppercased() + String(grid.suffix(grid.count - 4)).lowercased()
        return upper.range(of: pattern4, options: .regularExpression) != nil
            || upper.range(of: pattern6, options: .regularExpression) != nil
    }
}

#Preview {
    FirstRunWizard()
        .environment(AppState())
        .environment(try! ServiceContainer())
}
