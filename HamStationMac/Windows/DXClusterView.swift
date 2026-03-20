// DXClusterView.swift — DX spot list with filtering
// Table with color-coded spots: green=needed, yellow=worked, gray=confirmed.

import SwiftUI
import HamStationKit

struct DXClusterView: View {
    @Environment(AppState.self) var appState
    @State private var selectedSpot: UUID? = nil
    @State private var bandFilter: String = "All"
    @State private var modeFilter: String = "All"
    @State private var neededOnly: Bool = false

    private let bands = ["All", "160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m"]
    private let modes = ["All", "CW", "SSB", "FT8", "FT4", "RTTY"]

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar
            Divider()

            // Connection state banner
            if appState.clusterConnectionState != .connected {
                connectionBanner
            }

            // Spot table
            Table(filteredSpots, selection: $selectedSpot) {
                TableColumn("Time") { spot in
                    Text(spot.time, format: .dateTime.hour().minute())
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("DX Call") { spot in
                    Text(spot.dxCallsign)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(spotColor(spot.status))
                }
                .width(min: 70, ideal: 90)

                TableColumn("Frequency") { spot in
                    Text(String(format: "%.1f", spot.frequency))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 60, ideal: 80)

                TableColumn("Spotter") { spot in
                    Text(spot.spotter)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 60, ideal: 80)

                TableColumn("Comment") { spot in
                    Text(spot.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 200)
            }
        }
        .navigationTitle("DX Cluster")
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Band", selection: $bandFilter) {
                ForEach(bands, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Picker("Mode", selection: $modeFilter) {
                ForEach(modes, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Toggle("Needed only", isOn: $neededOnly)
                .toggleStyle(.checkbox)

            Spacer()

            Text("\(filteredSpots.count) spots")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Connection Banner

    private var connectionBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text(appState.clusterConnectionState == .connecting ? "Connecting to cluster..." : "Not connected to DX cluster")
                .font(.caption)
            Spacer()
            if appState.clusterConnectionState == .disconnected {
                Button("Connect") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.1))
    }

    // MARK: - Filtering

    private var filteredSpots: [DisplaySpot] {
        var spots = appState.recentSpots
        if neededOnly {
            spots = spots.filter { $0.status == .needed }
        }
        return spots
    }

    private func spotColor(_ status: DisplaySpot.SpotStatus) -> Color {
        switch status {
        case .needed: return .green
        case .worked: return .yellow
        case .confirmed: return .gray
        }
    }
}

#Preview {
    DXClusterView()
        .frame(width: 800, height: 500)
        .environment(AppState())
}
