// StatusBar.swift — Bottom status bar with live stats
// Shows QSO count, rate, solar data, rig/cluster connection status.

import SwiftUI
import HamStationKit

struct StatusBar: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 16) {
            // QSOs today
            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.caption2)
                Text("QSOs today:")
                    .font(.caption2)
                Text("\(appState.qsosToday)")
                    .font(.system(.caption2, design: .monospaced))
                    .bold()
            }

            Divider().frame(height: 12)

            // Rate
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.needle")
                    .font(.caption2)
                Text("Rate:")
                    .font(.caption2)
                Text("\(appState.qsoRate)/hr")
                    .font(.system(.caption2, design: .monospaced))
                    .bold()
            }

            Divider().frame(height: 12)

            // Solar conditions
            if let solar = appState.solarData {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                    Text("K=\(solar.kIndex)")
                        .font(.system(.caption2, design: .monospaced))
                        .bold()
                        .foregroundStyle(kIndexColor(solar.kIndex))
                    Text("SFI=\(solar.solarFluxIndex)")
                        .font(.system(.caption2, design: .monospaced))
                        .bold()
                }
            }

            Spacer()

            // Rig status
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.rigConnectionState == .connected ? .green : .red)
                    .frame(width: 6, height: 6)
                Text(appState.rigConnectionState == .connected ? "Rig \u{2713}" : "No rig")
                    .font(.caption2)
            }

            Divider().frame(height: 12)

            // Cluster status
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.clusterConnectionState == .connected ? .green : .red)
                    .frame(width: 6, height: 6)
                Text(appState.clusterConnectionState == .connected ? "Cluster \u{2713}" : "No cluster")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func kIndexColor(_ k: Int) -> Color {
        switch k {
        case 0...2: return .green
        case 3...4: return .yellow
        default: return .red
        }
    }
}

#Preview {
    VStack {
        Spacer()
        StatusBar()
    }
    .frame(width: 900, height: 100)
    .environment(AppState())
}
