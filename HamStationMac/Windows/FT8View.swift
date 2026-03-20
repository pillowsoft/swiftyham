// FT8View.swift — FT8 digital mode decode display
// Placeholder view for the FT8 decoder, navigated from sidebar and demo scene 7.

import SwiftUI
import HamStationKit

struct FT8View: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.demoFT8Decodes.isEmpty {
                ContentUnavailableView {
                    Label("FT8 Decoder", systemImage: "waveform")
                } description: {
                    Text("Connect your radio's audio to decode FT8 signals in real time.")
                }
            } else {
                // Demo decode list
                List {
                    ForEach(appState.demoFT8Decodes, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("FT8")
    }
}
