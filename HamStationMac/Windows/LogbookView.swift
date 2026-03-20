// LogbookView.swift — Main logbook table
// SwiftUI Table with sortable columns, backed by DatabaseManager.

import SwiftUI
import HamStationKit

// MARK: - LogbookRow

struct LogbookRow: Identifiable, Sendable {
    let id: UUID
    let dateTime: Date
    let callsign: String
    let band: String
    let mode: String
    let frequency: String
    let rstSent: String
    let rstRcvd: String
    let dxcc: String
    let name: String
    let comment: String

    init(
        id: UUID,
        dateTime: Date,
        callsign: String,
        band: String,
        mode: String,
        frequency: String,
        rstSent: String,
        rstRcvd: String,
        dxcc: String,
        name: String,
        comment: String
    ) {
        self.id = id
        self.dateTime = dateTime
        self.callsign = callsign
        self.band = band
        self.mode = mode
        self.frequency = frequency
        self.rstSent = rstSent
        self.rstRcvd = rstRcvd
        self.dxcc = dxcc
        self.name = name
        self.comment = comment
    }

    init(from qso: QSO) {
        self.id = qso.id
        self.dateTime = qso.datetimeOn
        self.callsign = qso.callsign
        self.band = qso.band.rawValue
        self.mode = qso.mode.rawValue
        self.frequency = FrequencyFormatter.formatMHz(hz: qso.frequencyHz)
        self.rstSent = qso.rstSent
        self.rstRcvd = qso.rstReceived
        self.dxcc = ""
        self.name = qso.name ?? ""
        self.comment = qso.comment ?? ""
    }
}

// MARK: - LogbookViewModel

@Observable @MainActor
class LogbookViewModel {
    var rows: [LogbookRow] = []
    var totalCount: Int = 0
    var isLoading: Bool = false
    var sortField: QSOSortField = .datetimeOn
    var ascending: Bool = false
    var filterBand: Band? = nil
    var filterMode: OperatingMode? = nil
    var searchText: String = ""
    var usingSampleData: Bool = false

    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func loadQSOs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let qsos = try await database.fetchQSOs(
                logbookId: nil,
                band: filterBand,
                mode: filterMode,
                callsignContains: searchText.isEmpty ? nil : searchText,
                dateRange: nil,
                sortBy: sortField,
                ascending: ascending,
                limit: 500,
                offset: 0
            )
            if qsos.isEmpty && searchText.isEmpty && filterBand == nil && filterMode == nil {
                self.rows = LogbookView.sampleData
                self.totalCount = 0
                self.usingSampleData = true
            } else {
                self.rows = qsos.map { LogbookRow(from: $0) }
                self.totalCount = try await database.countQSOs(logbookId: nil)
                self.usingSampleData = false
            }
        } catch {
            print("Failed to load QSOs: \(error)")
            self.rows = LogbookView.sampleData
            self.usingSampleData = true
        }
    }

    func deleteQSO(id: UUID) async {
        do {
            try await database.deleteQSO(id: id)
            await loadQSOs()
        } catch {
            print("Failed to delete QSO: \(error)")
        }
    }
}

// MARK: - LogbookView

struct LogbookView: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var viewModel: LogbookViewModel?
    @State private var selection: UUID? = nil
    @State private var sortOrder = [KeyPathComparator(\LogbookRow.dateTime, order: .reverse)]
    @State private var searchText: String = ""
    @State private var showFilterPopover: Bool = false
    @State private var filterBand: Band? = nil
    @State private var filterMode: OperatingMode? = nil
    @State private var showNewQSOSheet: Bool = false
    @State private var editingQSOId: UUID? = nil

    private var displayRows: [LogbookRow] {
        if let vm = viewModel {
            return vm.rows.sorted(using: sortOrder)
        }
        return LogbookView.sampleData.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel, vm.usingSampleData {
                sampleDataBanner
            }

            Table(displayRows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Date/Time", value: \.dateTime) { row in
                    Text(row.dateTime, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 100, ideal: 130)

                TableColumn("Callsign", value: \.callsign) { row in
                    Text(row.callsign)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))
                }
                .width(min: 70, ideal: 90)

                TableColumn("Band", value: \.band) { row in
                    Text(row.band)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 40, ideal: 50)

                TableColumn("Mode", value: \.mode) { row in
                    Text(row.mode)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 40, ideal: 50)

                TableColumn("Frequency", value: \.frequency) { row in
                    Text(row.frequency)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 70, ideal: 90)

                TableColumn("RST Sent", value: \.rstSent) { row in
                    Text(row.rstSent)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("RST Rcvd", value: \.rstRcvd) { row in
                    Text(row.rstRcvd)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("DXCC", value: \.dxcc) { row in
                    Text(row.dxcc)
                        .font(.caption)
                }
                .width(min: 60, ideal: 80)

                TableColumn("Name", value: \.name) { row in
                    Text(row.name)
                        .font(.caption)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Comment", value: \.comment) { row in
                    Text(row.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 150)
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let selectedId = ids.first {
                    Button("Edit QSO") {
                        editingQSOId = selectedId
                    }
                    Button("Look Up Callsign") {
                        if let row = displayRows.first(where: { $0.id == selectedId }) {
                            Task {
                                let _ = await services.lookupPipeline.lookup(
                                    callsign: row.callsign, qrzApiKey: nil
                                )
                            }
                        }
                    }
                    Divider()
                    Button("Upload to QRZ Logbook") {
                        Task { await uploadToQRZ(qsoId: selectedId) }
                    }
                    Button("Upload to eQSL") {
                        Task { await uploadToEQSL(qsoId: selectedId) }
                    }
                    Button("Upload to Club Log") {
                        Task { await uploadToClubLog(qsoId: selectedId) }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        if let vm = viewModel {
                            Task { await vm.deleteQSO(id: selectedId) }
                        }
                    }
                }
            } primaryAction: { ids in
                if let selectedId = ids.first {
                    editingQSOId = selectedId
                }
            }
        }
        .overlay {
            if viewModel?.isLoading == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .searchable(text: $searchText, prompt: "Search callsigns...")
        .onChange(of: searchText) { _, newValue in
            if let vm = viewModel {
                vm.searchText = newValue
                Task { await vm.loadQSOs() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showNewQSOSheet = true
                } label: {
                    Label("New QSO", systemImage: "plus")
                }
                .keyboardShortcut("n")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showFilterPopover.toggle()
                } label: {
                    Label("Filter", systemImage: filterBand != nil || filterMode != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $showFilterPopover) {
                    filterPopoverContent
                }
            }

            ToolbarItem(placement: .automatic) {
                if let vm = viewModel, !vm.usingSampleData, vm.totalCount > 0 {
                    Text("\(vm.totalCount) QSOs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showNewQSOSheet) {
            if let vm = viewModel { Task { await vm.loadQSOs() } }
        } content: {
            QSOEntryView(viewModel: QSOEntryViewModel(
                database: services.database,
                lookupPipeline: services.lookupPipeline,
                myCallsign: appState.operatorCallsign,
                myGrid: appState.gridSquare
            ))
        }
        .sheet(item: $editingQSOId) { qsoId in
            QSOEditSheetLoader(
                qsoId: qsoId,
                services: services,
                appState: appState,
                onDismiss: {
                    editingQSOId = nil
                    if let vm = viewModel { Task { await vm.loadQSOs() } }
                }
            )
        }
        .onChange(of: selection) { _, newValue in
            appState.selectedQSOId = newValue
        }
        .task {
            let vm = LogbookViewModel(database: services.database)
            self.viewModel = vm
            await vm.loadQSOs()
        }
        .navigationTitle("Logbook")
    }

    // MARK: - Sample Data Banner

    private var sampleDataBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
            Text("Sample data -- import your logbook to get started")
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .foregroundStyle(.secondary)
    }

    // MARK: - Log Submission

    private func uploadToQRZ(qsoId: UUID) async {
        guard let apiKey = KeychainHelper.load(key: "qrz_logbook_key"), !apiKey.isEmpty else { return }
        guard let qso = try? await services.database.fetchQSO(id: qsoId) else { return }
        do {
            try await services.qrzLogbook.submit(qso: qso, apiKey: apiKey)
        } catch {
            print("QRZ upload failed: \(error)")
        }
    }

    private func uploadToEQSL(qsoId: UUID) async {
        guard let username = KeychainHelper.load(key: "eqsl_username"), !username.isEmpty,
              let password = KeychainHelper.load(key: "eqsl_password"), !password.isEmpty else { return }
        guard let qso = try? await services.database.fetchQSO(id: qsoId) else { return }
        do {
            let _ = try await services.eqsl.submit(qsos: [qso], username: username, password: password)
        } catch {
            print("eQSL upload failed: \(error)")
        }
    }

    private func uploadToClubLog(qsoId: UUID) async {
        guard let email = KeychainHelper.load(key: "clublog_email"), !email.isEmpty,
              let password = KeychainHelper.load(key: "clublog_password"), !password.isEmpty,
              let callsign = KeychainHelper.load(key: "clublog_callsign"), !callsign.isEmpty else { return }
        guard let qso = try? await services.database.fetchQSO(id: qsoId) else { return }
        do {
            let _ = try await services.clubLog.submit(qsos: [qso], email: email, password: password, callsign: callsign)
        } catch {
            print("Club Log upload failed: \(error)")
        }
    }

    // MARK: - Filter Popover

    private var filterPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter QSOs")
                .font(.headline)

            Picker("Band", selection: $filterBand) {
                Text("All Bands").tag(Band?.none)
                ForEach(Band.allCases, id: \.self) { band in
                    Text(band.rawValue).tag(Band?.some(band))
                }
            }

            Picker("Mode", selection: $filterMode) {
                Text("All Modes").tag(OperatingMode?.none)
                ForEach(OperatingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(OperatingMode?.some(mode))
                }
            }

            HStack {
                Spacer()
                Button("Clear Filters") {
                    filterBand = nil
                    filterMode = nil
                }
                .buttonStyle(.bordered)
                .disabled(filterBand == nil && filterMode == nil)

                Button("Apply") {
                    showFilterPopover = false
                    if let vm = viewModel {
                        vm.filterBand = filterBand
                        vm.filterMode = filterMode
                        Task { await vm.loadQSOs() }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 250)
    }

    // MARK: - Sample Data

    static let sampleData: [LogbookRow] = {
        let cal = Calendar.current
        let now = Date()

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.day! -= daysAgo
            comps.hour = hour
            comps.minute = minute
            return cal.date(from: comps) ?? now
        }

        return [
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 14, minute: 23), callsign: "JA1NRH", band: "20m", mode: "FT8", frequency: "14.074", rstSent: "-10", rstRcvd: "-14", dxcc: "Japan", name: "Taro", comment: "Nice signal from Tokyo"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 14, minute: 5), callsign: "G3ABC", band: "20m", mode: "FT8", frequency: "14.074", rstSent: "-07", rstRcvd: "-12", dxcc: "England", name: "John", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 13, minute: 45), callsign: "DL1SBF", band: "20m", mode: "SSB", frequency: "14.225", rstSent: "59", rstRcvd: "57", dxcc: "Germany", name: "Stefan", comment: "QSL via bureau"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 13, minute: 22), callsign: "VK3BDX", band: "20m", mode: "FT8", frequency: "14.074", rstSent: "-15", rstRcvd: "-18", dxcc: "Australia", name: "Bruce", comment: "Long path"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 12, minute: 58), callsign: "W1AW", band: "20m", mode: "CW", frequency: "14.047", rstSent: "599", rstRcvd: "599", dxcc: "United States", name: "ARRL HQ", comment: "Bulletin practice"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 12, minute: 30), callsign: "PY2SEX", band: "15m", mode: "FT8", frequency: "21.074", rstSent: "-12", rstRcvd: "-08", dxcc: "Brazil", name: "Carlos", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 11, minute: 15), callsign: "ZS6BKW", band: "17m", mode: "SSB", frequency: "18.135", rstSent: "55", rstRcvd: "57", dxcc: "South Africa", name: "Brian", comment: "First ZS on 17m"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 0, hour: 10, minute: 42), callsign: "HL5BLI", band: "20m", mode: "FT8", frequency: "14.074", rstSent: "-09", rstRcvd: "-11", dxcc: "South Korea", name: "Lee", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 1, hour: 23, minute: 15), callsign: "VP8LP", band: "40m", mode: "CW", frequency: "7.012", rstSent: "559", rstRcvd: "579", dxcc: "Falkland Is.", name: "Lars", comment: "Rare one!"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 1, hour: 22, minute: 40), callsign: "5B4ALX", band: "40m", mode: "SSB", frequency: "7.178", rstSent: "57", rstRcvd: "59", dxcc: "Cyprus", name: "Alex", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 1, hour: 21, minute: 55), callsign: "LU7YS", band: "40m", mode: "FT8", frequency: "7.074", rstSent: "-13", rstRcvd: "-16", dxcc: "Argentina", name: "Martin", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 1, hour: 20, minute: 30), callsign: "OH2BH", band: "80m", mode: "CW", frequency: "3.530", rstSent: "599", rstRcvd: "599", dxcc: "Finland", name: "Martti", comment: "Legend!"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 1, hour: 19, minute: 10), callsign: "VE3NEA", band: "30m", mode: "CW", frequency: "10.118", rstSent: "579", rstRcvd: "589", dxcc: "Canada", name: "Alex", comment: "Morse Runner author"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 2, hour: 15, minute: 0), callsign: "UA3DJY", band: "20m", mode: "SSB", frequency: "14.200", rstSent: "59", rstRcvd: "59", dxcc: "Russia", name: "Dmitry", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 2, hour: 14, minute: 22), callsign: "9A2GA", band: "20m", mode: "FT8", frequency: "14.074", rstSent: "-06", rstRcvd: "-10", dxcc: "Croatia", name: "Goran", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 2, hour: 13, minute: 45), callsign: "SV1IW", band: "15m", mode: "SSB", frequency: "21.295", rstSent: "57", rstRcvd: "55", dxcc: "Greece", name: "Spiros", comment: "Weak but readable"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 3, hour: 16, minute: 30), callsign: "A71A", band: "20m", mode: "CW", frequency: "14.025", rstSent: "599", rstRcvd: "599", dxcc: "Qatar", name: "Ali", comment: "Contest"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 3, hour: 15, minute: 11), callsign: "YB0ECT", band: "15m", mode: "FT8", frequency: "21.074", rstSent: "-17", rstRcvd: "-19", dxcc: "Indonesia", name: "Edi", comment: ""),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 4, hour: 12, minute: 0), callsign: "KH6LC", band: "20m", mode: "SSB", frequency: "14.195", rstSent: "59", rstRcvd: "59", dxcc: "Hawaii", name: "Lloyd", comment: "Aloha!"),
            LogbookRow(id: UUID(), dateTime: date(daysAgo: 5, hour: 8, minute: 30), callsign: "TF3ML", band: "40m", mode: "FT8", frequency: "7.074", rstSent: "-11", rstRcvd: "-13", dxcc: "Iceland", name: "Magnus", comment: "Grey line path"),
        ]
    }()
}

// MARK: - Edit Sheet Loader

/// Loads a QSO by ID and presents the edit sheet. This handles the async
/// fetch so the .sheet(item:) call stays synchronous.
private struct QSOEditSheetLoader: View {
    let qsoId: UUID
    let services: ServiceContainer
    let appState: AppState
    let onDismiss: () -> Void

    @State private var loadedQSO: QSO? = nil

    var body: some View {
        Group {
            if let qso = loadedQSO {
                let vm = QSOEntryViewModel(
                    database: services.database,
                    lookupPipeline: services.lookupPipeline,
                    myCallsign: appState.operatorCallsign,
                    myGrid: appState.gridSquare
                )
                QSOEntryView(viewModel: vm)
                    .onAppear { vm.loadForEdit(qso) }
            } else {
                ProgressView("Loading...")
                    .frame(width: 480, height: 560)
            }
        }
        .task {
            loadedQSO = try? await services.database.fetchQSO(id: qsoId)
        }
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

#Preview {
    LogbookView()
        .frame(width: 1000, height: 500)
        .environment(AppState())
        .environment(try! ServiceContainer())
}
