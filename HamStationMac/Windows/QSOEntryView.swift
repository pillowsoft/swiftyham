// QSOEntryView.swift — New / Edit QSO sheet
// Presented from LogbookView for creating and editing QSO records.

import SwiftUI
import HamStationKit

// MARK: - ViewModel

@Observable @MainActor
final class QSOEntryViewModel {
    // Form fields
    var callsign: String = ""
    var band: Band = .band20m
    var mode: OperatingMode = .ssb
    var frequencyText: String = ""
    var rstSent: String = "59"
    var rstReceived: String = "59"
    var name: String = ""
    var qth: String = ""
    var theirGrid: String = ""
    var comment: String = ""
    var powerText: String = ""
    var datetimeOn: Date = Date()

    // State
    var isDuplicateWarning: Bool = false
    var duplicateQSO: QSO? = nil
    var lookupResult: CallsignLookupResult?
    var isLookingUp: Bool = false
    var isSaving: Bool = false
    var errorMessage: String? = nil

    // Editing an existing QSO
    private(set) var editingQSO: QSO? = nil

    var isEditing: Bool { editingQSO != nil }
    var sheetTitle: String { isEditing ? "Edit QSO" : "New QSO" }
    var saveButtonTitle: String { isEditing ? "Save" : "Log QSO" }

    var isValid: Bool {
        !callsign.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let database: DatabaseManager
    private let lookupPipeline: CallsignLookupPipeline?
    private let myCallsign: String
    private let myGrid: String?

    init(
        database: DatabaseManager,
        lookupPipeline: CallsignLookupPipeline? = nil,
        myCallsign: String,
        myGrid: String?
    ) {
        self.database = database
        self.lookupPipeline = lookupPipeline
        self.myCallsign = myCallsign
        self.myGrid = myGrid
    }

    /// Populates the form for editing an existing QSO.
    func loadForEdit(_ qso: QSO) {
        editingQSO = qso
        callsign = qso.callsign
        band = qso.band
        mode = qso.mode
        frequencyText = FrequencyFormatter.formatMHz(hz: qso.frequencyHz)
        rstSent = qso.rstSent
        rstReceived = qso.rstReceived
        name = qso.name ?? ""
        qth = qso.qth ?? ""
        theirGrid = qso.theirGrid ?? ""
        comment = qso.comment ?? ""
        powerText = qso.txPowerWatts.map { String(format: "%.0f", $0) } ?? ""
        datetimeOn = qso.datetimeOn
    }

    /// Auto-selects band when frequency changes.
    func frequencyChanged() {
        if let hz = FrequencyFormatter.parse(frequencyText),
           let detectedBand = Band.band(forFrequency: hz) {
            band = detectedBand
        }
    }

    /// Updates default RST when mode changes.
    func modeChanged() {
        // Only update if the RST is still a default value
        let oldDefaults = ["59", "599", "-10"]
        if oldDefaults.contains(rstSent) {
            rstSent = mode.defaultRST
        }
        if oldDefaults.contains(rstReceived) {
            rstReceived = mode.defaultRST
        }
    }

    /// Looks up the callsign via the pipeline.
    func lookupCallsign() async {
        guard let pipeline = lookupPipeline else { return }
        let call = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !call.isEmpty else { return }

        isLookingUp = true
        defer { isLookingUp = false }

        let result = await pipeline.lookup(callsign: call, qrzApiKey: nil)
        lookupResult = result
        if name.isEmpty, let n = result.name { name = n }
        if qth.isEmpty, let q = result.qth { qth = q }
        if theirGrid.isEmpty, let g = result.grid { theirGrid = g }
    }

    /// Checks for duplicate QSOs.
    func checkDuplicate() async {
        let call = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !call.isEmpty else { return }

        do {
            if let dupe = try await database.checkDuplicate(
                callsign: call, band: band, mode: mode, date: datetimeOn
            ) {
                duplicateQSO = dupe
                isDuplicateWarning = true
            } else {
                duplicateQSO = nil
                isDuplicateWarning = false
            }
        } catch {
            // Silently ignore dupe check failures
        }
    }

    /// Saves the QSO (create or update).
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let call = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !call.isEmpty else {
            errorMessage = "Callsign is required."
            return false
        }

        let freqHz: Double
        if let parsed = FrequencyFormatter.parse(frequencyText) {
            freqHz = parsed
        } else {
            freqHz = band.frequencyRange.lowerBound
        }

        let power = Double(powerText)

        if var existing = editingQSO {
            // Update
            existing.callsign = call
            existing.band = band
            existing.mode = mode
            existing.frequencyHz = freqHz
            existing.rstSent = rstSent
            existing.rstReceived = rstReceived
            existing.name = name.isEmpty ? nil : name
            existing.qth = qth.isEmpty ? nil : qth
            existing.theirGrid = theirGrid.isEmpty ? nil : theirGrid
            existing.comment = comment.isEmpty ? nil : comment
            existing.txPowerWatts = power
            existing.datetimeOn = datetimeOn
            existing.updatedAt = Date()

            do {
                try await database.updateQSO(existing)
                return true
            } catch {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                return false
            }
        } else {
            // Create
            let qso = QSO(
                callsign: call,
                myCallsign: myCallsign,
                band: band,
                frequencyHz: freqHz,
                mode: mode,
                datetimeOn: datetimeOn,
                rstSent: rstSent,
                rstReceived: rstReceived,
                txPowerWatts: power,
                myGrid: myGrid,
                theirGrid: theirGrid.isEmpty ? nil : theirGrid,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                comment: comment.isEmpty ? nil : comment
            )

            do {
                try await database.createQSO(qso)
                return true
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                return false
            }
        }
    }
}

// MARK: - View

struct QSOEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: QSOEntryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.sheetTitle)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                callsignSection
                frequencySection
                rstSection
                contactInfoSection
                notesSection
            }
            .formStyle(.grouped)

            // Dupe warning
            if viewModel.isDuplicateWarning {
                dupeWarningBanner
            }

            // Error
            if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            // Footer
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button(viewModel.saveButtonTitle) {
                    Task {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid || viewModel.isSaving)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - Sections

    private var callsignSection: some View {
        Section {
            HStack {
                TextField("Callsign", text: Bindable(viewModel).callsign)
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Color(hex: "FF6A00"))
                    .textCase(.uppercase)
                    .onSubmit {
                        Task {
                            await viewModel.lookupCallsign()
                            await viewModel.checkDuplicate()
                        }
                    }

                if viewModel.isLookingUp {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await viewModel.lookupCallsign() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(viewModel.callsign.isEmpty)
                }
            }

            DatePicker("Date/Time (UTC)", selection: Bindable(viewModel).datetimeOn)
        }
    }

    private var frequencySection: some View {
        Section("Frequency") {
            HStack(spacing: 12) {
                Picker("Band", selection: Bindable(viewModel).band) {
                    ForEach(Band.allCases, id: \.self) { band in
                        Text(band.rawValue).tag(band)
                    }
                }
                .frame(width: 100)

                Picker("Mode", selection: Bindable(viewModel).mode) {
                    ForEach(OperatingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 100)
                .onChange(of: viewModel.mode) {
                    viewModel.modeChanged()
                }

                TextField("Frequency (MHz)", text: Bindable(viewModel).frequencyText)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 120)
                    .onChange(of: viewModel.frequencyText) {
                        viewModel.frequencyChanged()
                    }
            }

            if !viewModel.powerText.isEmpty || !viewModel.isEditing {
                TextField("Power (watts)", text: Bindable(viewModel).powerText)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 100)
            }
        }
    }

    private var rstSection: some View {
        Section("Signal Reports") {
            HStack(spacing: 16) {
                HStack {
                    Text("RST Sent")
                        .frame(width: 70, alignment: .trailing)
                    TextField("RST", text: Bindable(viewModel).rstSent)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 60)
                }
                HStack {
                    Text("RST Rcvd")
                        .frame(width: 70, alignment: .trailing)
                    TextField("RST", text: Bindable(viewModel).rstReceived)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 60)
                }
            }
        }
    }

    private var contactInfoSection: some View {
        Section("Contact Info") {
            TextField("Name", text: Bindable(viewModel).name)
            TextField("QTH", text: Bindable(viewModel).qth)
            TextField("Grid", text: Bindable(viewModel).theirGrid)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Comment", text: Bindable(viewModel).comment, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var dupeWarningBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Possible duplicate — \(viewModel.callsign) on \(viewModel.band.rawValue) \(viewModel.mode.rawValue)")
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.1))
    }
}
