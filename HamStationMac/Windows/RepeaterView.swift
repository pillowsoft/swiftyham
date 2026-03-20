// RepeaterView.swift — Repeater directory with map and searchable list.
// Map pins color-coded by mode, filter bar, detail panel.

import SwiftUI
import MapKit

struct RepeaterView: View {
    @State private var searchText = ""
    @State private var selectedBand = "All"
    @State private var selectedMode = "All"
    @State private var selectedRepeaterId: UUID?

    private let bands = ["All", "2m", "70cm", "1.25m", "6m", "10m"]
    private let modes = ["All", "FM", "D-STAR", "DMR", "C4FM", "P25"]

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search repeaters...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 200)

                Divider().frame(height: 20)

                Picker("Band", selection: $selectedBand) {
                    ForEach(bands, id: \.self) { Text($0) }
                }
                .frame(width: 100)

                Picker("Mode", selection: $selectedMode) {
                    ForEach(modes, id: \.self) { Text($0) }
                }
                .frame(width: 110)

                Spacer()

                Button {
                    // Refresh from API
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)

                Text("\(filteredRepeaters.count) repeaters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HSplitView {
                // Map
                Map {
                    ForEach(filteredRepeaters) { repeater in
                        Marker(
                            repeater.callsign,
                            systemImage: "antenna.radiowaves.left.and.right",
                            coordinate: CLLocationCoordinate2D(
                                latitude: repeater.lat,
                                longitude: repeater.lon
                            )
                        )
                        .tint(modeColor(repeater.mode))
                    }
                }
                .frame(minWidth: 400)

                // List + detail
                VStack(spacing: 0) {
                    List(filteredRepeaters, selection: $selectedRepeaterId) { repeater in
                        repeaterRow(repeater)
                            .tag(repeater.id)
                    }
                    .listStyle(.inset)

                    if let id = selectedRepeaterId,
                       let repeater = sampleRepeaters.first(where: { $0.id == id }) {
                        Divider()
                        repeaterDetail(repeater)
                    }
                }
                .frame(minWidth: 280, idealWidth: 320)
            }
        }
        .navigationTitle("Repeater Directory")
    }

    // MARK: - Row

    private func repeaterRow(_ repeater: SampleRepeater) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(repeater.callsign)
                    .font(.system(.body, design: .monospaced).bold())
                Spacer()
                Text(repeater.mode)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(modeColor(repeater.mode).opacity(0.15))
                    .foregroundStyle(modeColor(repeater.mode))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            HStack {
                Text(String(format: "%.4f MHz", repeater.frequency))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6A00"))
                Text(String(format: "%+.1f", repeater.offset))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let tone = repeater.tone {
                    Text(String(format: "%.1f Hz", tone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(repeater.city), \(repeater.state)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    private func repeaterDetail(_ repeater: SampleRepeater) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(repeater.callsign)
                    .font(.headline)
                Spacer()
                Button("Tune") {
                    // Send frequency to rig
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(spacing: 16) {
                detailField("Output", String(format: "%.4f MHz", repeater.frequency))
                detailField("Input", String(format: "%.4f MHz", repeater.frequency + repeater.offset))
                detailField("Offset", String(format: "%+.1f MHz", repeater.offset))
            }

            HStack(spacing: 16) {
                if let tone = repeater.tone {
                    detailField("CTCSS", String(format: "%.1f Hz", tone))
                }
                detailField("Mode", repeater.mode)
                detailField("Location", "\(repeater.city), \(repeater.state)")
            }

            if let notes = repeater.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func detailField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }

    // MARK: - Helpers

    private func modeColor(_ mode: String) -> Color {
        switch mode.lowercased() {
        case "fm":      return .blue
        case "d-star":  return .green
        case "dmr":     return .orange
        case "c4fm":    return .purple
        case "p25":     return .red
        default:        return .gray
        }
    }

    private var filteredRepeaters: [SampleRepeater] {
        sampleRepeaters.filter { repeater in
            let matchesSearch = searchText.isEmpty
                || repeater.callsign.localizedCaseInsensitiveContains(searchText)
                || repeater.city.localizedCaseInsensitiveContains(searchText)
            let matchesBand = selectedBand == "All" || repeater.band == selectedBand
            let matchesMode = selectedMode == "All" || repeater.mode == selectedMode
            return matchesSearch && matchesBand && matchesMode
        }
    }

    // MARK: - Sample Data

    struct SampleRepeater: Identifiable {
        let id = UUID()
        let callsign: String
        let frequency: Double
        let offset: Double
        let tone: Double?
        let mode: String
        let band: String
        let city: String
        let state: String
        let lat: Double
        let lon: Double
        let notes: String?
    }

    private var sampleRepeaters: [SampleRepeater] {
        [
            SampleRepeater(callsign: "W1HDN", frequency: 146.760, offset: -0.6, tone: 100.0, mode: "FM", band: "2m", city: "Hartford", state: "CT", lat: 41.763, lon: -72.685, notes: "Hartford County ARES"),
            SampleRepeater(callsign: "N1MUF", frequency: 145.290, offset: -0.6, tone: 127.3, mode: "FM", band: "2m", city: "Meriden", state: "CT", lat: 41.536, lon: -72.807, notes: nil),
            SampleRepeater(callsign: "W1TOM", frequency: 147.300, offset: +0.6, tone: 77.0, mode: "FM", band: "2m", city: "Thomaston", state: "CT", lat: 41.673, lon: -73.073, notes: "Linked to W1NRG"),
            SampleRepeater(callsign: "KB1AEV", frequency: 442.250, offset: +5.0, tone: 100.0, mode: "DMR", band: "70cm", city: "Glastonbury", state: "CT", lat: 41.712, lon: -72.608, notes: "Brandmeister CC1"),
            SampleRepeater(callsign: "W1YSM", frequency: 145.150, offset: -0.6, tone: nil, mode: "D-STAR", band: "2m", city: "New Haven", state: "CT", lat: 41.308, lon: -72.928, notes: "REF030C linked"),
            SampleRepeater(callsign: "N1FD", frequency: 441.800, offset: +5.0, tone: 100.0, mode: "C4FM", band: "70cm", city: "Fairfield", state: "CT", lat: 41.141, lon: -73.264, notes: "System Fusion"),
            SampleRepeater(callsign: "W1NRG", frequency: 448.575, offset: -5.0, tone: 107.2, mode: "FM", band: "70cm", city: "Prospect", state: "CT", lat: 41.502, lon: -72.979, notes: nil),
            SampleRepeater(callsign: "WA1DEF", frequency: 146.985, offset: -0.6, tone: 162.2, mode: "FM", band: "2m", city: "Norwich", state: "CT", lat: 41.524, lon: -72.076, notes: "EchoLink node"),
        ]
    }
}

#Preview {
    RepeaterView()
        .frame(width: 1000, height: 650)
        .environment(AppState())
}
