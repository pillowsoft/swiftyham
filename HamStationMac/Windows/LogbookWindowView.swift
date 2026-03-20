// LogbookWindowView.swift — Detachable logbook window
// Wraps LogbookView with its own toolbar for independent operation.

import SwiftUI
import HamStationKit

struct LogbookWindowView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        LogbookView()
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Text(appState.operatorCallsign)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))

                    Spacer()

                    Button {
                        // TODO: New QSO
                    } label: {
                        Label("New QSO", systemImage: "plus")
                    }

                    Button {
                        // TODO: Import ADIF
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        // TODO: Export ADIF
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .frame(minWidth: 800, minHeight: 400)
    }
}

#Preview {
    LogbookWindowView()
        .frame(width: 1000, height: 500)
        .environment(AppState())
        .environment(try! ServiceContainer())
}
