// HamStationCommands.swift — Menu bar commands
// File, View, and Window menu additions with keyboard shortcuts.

import SwiftUI

struct HamStationCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // File menu
        CommandGroup(after: .newItem) {
            Divider()

            Button("Import ADIF...") {
                // TODO: Show ADIF import file picker
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button("Export ADIF...") {
                // TODO: Show ADIF export file picker
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
}
