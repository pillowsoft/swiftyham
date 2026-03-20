// ToolbarContent.swift — Toolbar showing rig state
// Displays callsign, frequency, mode, band, power, and connection indicator.

import SwiftUI
import HamStationKit

struct HamStationToolbar: ToolbarContent {
    @Environment(AppState.self) var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Operator callsign
            Text(appState.operatorCallsign)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(Color(hex: "FF6A00"))

            Divider()

            // Frequency
            HStack(spacing: 2) {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                Text(appState.rigState?.formattedFrequency ?? "—.———")
                    .font(.system(.title3, design: .monospaced).monospacedDigit())
                Text("MHz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Mode badge
            Text(appState.rigState?.modeString ?? "—")
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "FF6A00").opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Band badge
            Text(appState.rigState?.band ?? "—")
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Divider()

            // TX Power
            if let rig = appState.rigState {
                Label("100W", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(rig.pttActive ? .red : .secondary)
            }

            Divider()

            // Rig connection indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionColor: Color {
        switch appState.rigConnectionState {
        case .connected: return .green
        case .connecting, .reconnecting: return .yellow
        case .disconnected: return .red
        case .error: return .red
        }
    }

    private var connectionLabel: String {
        switch appState.rigConnectionState {
        case .connected: return "Rig"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "No Rig"
        case .error: return "Rig Error"
        }
    }
}
