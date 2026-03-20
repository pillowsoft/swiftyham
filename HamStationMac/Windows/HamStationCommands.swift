// HamStationCommands.swift — Menu bar commands
// File, View, and Window menu additions with keyboard shortcuts.

import SwiftUI
import HamStationKit
import UniformTypeIdentifiers

struct HamStationCommands: Commands {
    let appState: AppState
    let services: ServiceContainer

    var body: some Commands {
        // File menu
        CommandGroup(after: .newItem) {
            Divider()

            Button("Import ADIF...") {
                Task { @MainActor in
                    await importADIF()
                }
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button("Export ADIF...") {
                Task { @MainActor in
                    await exportADIF()
                }
            }
            .keyboardShortcut("e", modifiers: [.command])

            Divider()

            Button("New Logbook...") {
                // TODO: Create new logbook
            }
        }

        // View menu
        CommandGroup(after: .sidebar) {
            Divider()

            Button("Toggle Night Mode") {
                Task { @MainActor in
                    appState.isNightMode.toggle()
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        // Window menu
        CommandGroup(after: .windowArrangement) {
            Divider()

            Button("Open Logbook Window") {
                // TODO: Open detachable logbook window
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
        }
    }

    // MARK: - ADIF Import

    @MainActor
    private func importADIF() async {
        let panel = NSOpenPanel()
        panel.title = "Import ADIF Logbook"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "adi") ?? .data,
            UTType(filenameExtension: "adif") ?? .data,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let result = ADIFParser.parse(string: try String(contentsOf: url, encoding: .utf8))
            let myCall = appState.operatorCallsign

            var pairs: [(QSO, QSOExtended?)] = []
            for record in result.records {
                guard let qso = ADIFConverter.qso(from: record, myCallsign: myCall) else { continue }
                let extended = ADIFConverter.qsoExtended(from: record, qsoId: qso.id)
                pairs.append((qso, extended))
            }

            guard !pairs.isEmpty else {
                let alert = NSAlert()
                alert.messageText = "No QSOs Found"
                alert.informativeText = "The selected file did not contain any valid QSO records."
                alert.runModal()
                return
            }

            let count = try await services.database.batchCreateQSOs(pairs)

            let alert = NSAlert()
            alert.messageText = "Import Complete"
            alert.informativeText = "Imported \(count) QSOs from \(url.lastPathComponent)."
            if !result.warnings.isEmpty {
                alert.informativeText += " (\(result.warnings.count) warnings)"
            }
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Import Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - ADIF Export

    @MainActor
    private func exportADIF() async {
        let panel = NSSavePanel()
        panel.title = "Export ADIF Logbook"
        panel.allowedContentTypes = [UTType(filenameExtension: "adi") ?? .data]
        panel.nameFieldStringValue = "hamstation_export.adi"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let qsos = try await services.database.fetchQSOs(
                limit: 1_000_000, offset: 0
            )

            var records: [ADIFRecord] = []
            records.reserveCapacity(qsos.count)
            for qso in qsos {
                let pair = try await services.database.fetchQSOWithExtended(id: qso.id)
                let extended = pair?.1
                records.append(ADIFConverter.adifRecord(from: qso, extended: extended))
            }

            try ADIFExporter.export(records: records, to: url)

            let alert = NSAlert()
            alert.messageText = "Export Complete"
            alert.informativeText = "Exported \(records.count) QSOs to \(url.lastPathComponent)."
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
