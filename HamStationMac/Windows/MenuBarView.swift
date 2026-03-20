// MenuBarView.swift — Menu bar extra popup
// Shows solar summary, band conditions, last QSO, and quick actions.

import SwiftUI
import HamStationKit

struct MenuBarView: View {
    @Environment(AppState.self) var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Solar conditions
            Text("Solar Conditions")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let solar = appState.solarData {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("SFI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(solar.solarFluxIndex)")
                            .font(.system(.caption, design: .monospaced).bold())
                    }
                    HStack(spacing: 4) {
                        Text("K")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(solar.kIndex)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(kIndexColor(solar.kIndex))
                    }
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(solar.aIndex)")
                            .font(.system(.caption, design: .monospaced).bold())
                    }
                }
            }

            Divider()

            // Band conditions
            Text("Band Conditions")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let solar = appState.solarData {
                let conditions = solar.bandConditions
                let bandOrder = ["20m", "40m", "15m", "17m", "10m", "80m"]
                ForEach(bandOrder, id: \.self) { band in
                    if let condition = conditions[band] {
                        HStack {
                            Text(band)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 36, alignment: .leading)
                            Text(condition.rawValue)
                                .font(.caption)
                                .foregroundStyle(conditionColor(condition))
                        }
                    }
                }
            }

            Divider()

            // Last QSO
            Text("Last QSO")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("JA1NRH on 20m FT8")
                .font(.system(.caption, design: .monospaced))

            Divider()

            // Actions
            Button {
                openWindow(id: "main")
            } label: {
                Label("Open HamStation Pro", systemImage: "antenna.radiowaves.left.and.right")
            }

            Divider()

            Button("Quit HamStation") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 220)
    }

    private func kIndexColor(_ k: Int) -> Color {
        switch k {
        case 0...2: return .green
        case 3...4: return .yellow
        default: return .red
        }
    }

    private func conditionColor(_ condition: BandCondition) -> Color {
        switch condition {
        case .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        }
    }
}

#Preview {
    MenuBarView()
        .environment(AppState())
}
