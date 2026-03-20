// SatelliteView.swift — Satellite tracking with pass predictions and Doppler display.
// Shows upcoming passes, polar plot for selected pass, and Doppler-corrected frequencies.

import SwiftUI

struct SatelliteView: View {
    @Environment(AppState.self) var appState
    @State private var selectedPassID: UUID? = nil
    @State private var uplinkFrequency: String = "145.990"
    @State private var downlinkFrequency: String = "435.800"
    @State private var isTracking: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Pass table — constrained so it doesn't starve the detail pane
            passTable
                .frame(minWidth: 380, idealWidth: 480, maxWidth: 600)

            Divider()

            // Right: Pass detail + Doppler — gets remaining space
            VStack(spacing: 0) {
                if let selectedPass = selectedPass {
                    passDetailView(selectedPass)
                } else {
                    ContentUnavailableView(
                        "Select a Pass",
                        systemImage: "satellite",
                        description: Text("Select an upcoming satellite pass to see details and Doppler corrections.")
                    )
                }

                Divider()

                dopplerPanel
                    .frame(height: 140)
            }
            .frame(minWidth: 300)
            .layoutPriority(1)
        }
        .navigationTitle("Satellite Tracking")
    }

    // MARK: - Pass Table

    private var passTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Upcoming Passes")
                    .font(.headline)
                Spacer()
                Button {
                    // Refresh TLEs
                } label: {
                    Label("Update TLEs", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Table(SatelliteView.samplePasses, selection: $selectedPassID) {
                TableColumn("Satellite") { pass in
                    Text(pass.name)
                        .font(.system(.body, design: .monospaced).bold())
                }
                .width(min: 80, ideal: 100)

                TableColumn("AOS") { pass in
                    Text(pass.aos, format: .dateTime.hour().minute())
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("LOS") { pass in
                    Text(pass.los, format: .dateTime.hour().minute())
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("Max El") { pass in
                    Text(String(format: "%.0f\u{00B0}", pass.maxElevation))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(elevationColor(pass.maxElevation))
                }
                .width(min: 50, ideal: 60)

                TableColumn("Duration") { pass in
                    Text(formatDuration(pass.aos, pass.los))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 50, ideal: 60)

                TableColumn("AOS Az") { pass in
                    Text(String(format: "%.0f\u{00B0} %@", pass.aosAzimuth, compassDirection(pass.aosAzimuth)))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 60, ideal: 80)
            }
        }
    }

    // MARK: - Pass Detail

    private func passDetailView(_ pass: SamplePass) -> some View {
        VStack(spacing: 12) {
            Text(pass.name)
                .font(.title2.bold())
                .padding(.top, 12)

            // Polar plot placeholder
            ZStack {
                // Outer circle (horizon)
                Circle()
                    .stroke(.quaternary, lineWidth: 1)

                // 30-degree ring
                Circle()
                    .stroke(.quaternary, lineWidth: 0.5)
                    .scaleEffect(2.0 / 3.0)

                // 60-degree ring
                Circle()
                    .stroke(.quaternary, lineWidth: 0.5)
                    .scaleEffect(1.0 / 3.0)

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 0.5, y: 0))
                    path.addLine(to: CGPoint(x: 0.5, y: 1.0))
                    path.move(to: CGPoint(x: 0, y: 0.5))
                    path.addLine(to: CGPoint(x: 1.0, y: 0.5))
                }
                .stroke(.quaternary, lineWidth: 0.5)

                // Cardinal directions
                Text("N").font(.caption2).position(x: 0.5, y: 0.05)
                Text("S").font(.caption2).position(x: 0.5, y: 0.95)
                Text("E").font(.caption2).position(x: 0.95, y: 0.5)
                Text("W").font(.caption2).position(x: 0.05, y: 0.5)

                // Sample pass arc
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .position(
                        x: 0.5 + CGFloat(0.3 * cos(pass.aosAzimuth * .pi / 180)),
                        y: 0.5 - CGFloat(0.3 * sin(pass.aosAzimuth * .pi / 180))
                    )
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 250, maxHeight: 250)
            .padding()

            // Pass info grid
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    Text("AOS:").foregroundStyle(.secondary)
                    Text(pass.aos, format: .dateTime.hour().minute().second())
                        .font(.system(.body, design: .monospaced))
                    Text("Az: \(String(format: "%.0f\u{00B0}", pass.aosAzimuth)) \(compassDirection(pass.aosAzimuth))")
                        .font(.system(.caption, design: .monospaced))
                }
                GridRow {
                    Text("Max El:").foregroundStyle(.secondary)
                    Text(String(format: "%.1f\u{00B0}", pass.maxElevation))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(elevationColor(pass.maxElevation))
                    Text(pass.maxElevationTime, format: .dateTime.hour().minute().second())
                        .font(.system(.caption, design: .monospaced))
                }
                GridRow {
                    Text("LOS:").foregroundStyle(.secondary)
                    Text(pass.los, format: .dateTime.hour().minute().second())
                        .font(.system(.body, design: .monospaced))
                    Text("Az: \(String(format: "%.0f\u{00B0}", pass.losAzimuth)) \(compassDirection(pass.losAzimuth))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - Doppler Panel

    private var dopplerPanel: some View {
        VStack(spacing: 8) {
            Text("Doppler Correction")
                .font(.subheadline.bold())
                .padding(.top, 8)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uplink").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("MHz", text: $uplinkFrequency)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 100)
                        Text("MHz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Corrected: \(uplinkFrequency) MHz")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Downlink").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("MHz", text: $downlinkFrequency)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 100)
                        Text("MHz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Corrected: \(downlinkFrequency) MHz")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                }

                Spacer()

                Button {
                    isTracking.toggle()
                } label: {
                    Label(isTracking ? "Stop Tracking" : "Track Pass", systemImage: isTracking ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(isTracking ? .red : .accentColor)
                .controlSize(.large)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    // MARK: - Helpers

    private var selectedPass: SamplePass? {
        SatelliteView.samplePasses.first { $0.id == selectedPassID }
    }

    private func elevationColor(_ elevation: Double) -> Color {
        if elevation >= 60 { return .green }
        if elevation >= 30 { return .yellow }
        return .orange
    }

    private func formatDuration(_ start: Date, _ end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func compassDirection(_ azimuth: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((azimuth + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return directions[min(index, 15)]
    }

    // MARK: - Sample Data

    struct SamplePass: Identifiable {
        let id: UUID
        let name: String
        let aos: Date
        let los: Date
        let maxElevation: Double
        let maxElevationTime: Date
        let aosAzimuth: Double
        let losAzimuth: Double
    }

    static let samplePasses: [SamplePass] = {
        let now = Date()
        return [
            SamplePass(id: UUID(), name: "ISS", aos: now.addingTimeInterval(1800), los: now.addingTimeInterval(2400), maxElevation: 72.3, maxElevationTime: now.addingTimeInterval(2100), aosAzimuth: 215, losAzimuth: 45),
            SamplePass(id: UUID(), name: "AO-91", aos: now.addingTimeInterval(5400), los: now.addingTimeInterval(6000), maxElevation: 34.1, maxElevationTime: now.addingTimeInterval(5700), aosAzimuth: 310, losAzimuth: 130),
            SamplePass(id: UUID(), name: "SO-50", aos: now.addingTimeInterval(9000), los: now.addingTimeInterval(9600), maxElevation: 52.8, maxElevationTime: now.addingTimeInterval(9300), aosAzimuth: 180, losAzimuth: 355),
            SamplePass(id: UUID(), name: "RS-44", aos: now.addingTimeInterval(14400), los: now.addingTimeInterval(15300), maxElevation: 18.5, maxElevationTime: now.addingTimeInterval(14850), aosAzimuth: 270, losAzimuth: 90),
            SamplePass(id: UUID(), name: "ISS", aos: now.addingTimeInterval(21600), los: now.addingTimeInterval(22200), maxElevation: 45.2, maxElevationTime: now.addingTimeInterval(21900), aosAzimuth: 235, losAzimuth: 25),
            SamplePass(id: UUID(), name: "AO-92", aos: now.addingTimeInterval(28800), los: now.addingTimeInterval(29400), maxElevation: 61.7, maxElevationTime: now.addingTimeInterval(29100), aosAzimuth: 195, losAzimuth: 15),
            SamplePass(id: UUID(), name: "CAS-4A", aos: now.addingTimeInterval(36000), los: now.addingTimeInterval(36600), maxElevation: 25.4, maxElevationTime: now.addingTimeInterval(36300), aosAzimuth: 320, losAzimuth: 140),
            SamplePass(id: UUID(), name: "FO-29", aos: now.addingTimeInterval(43200), los: now.addingTimeInterval(44100), maxElevation: 82.1, maxElevationTime: now.addingTimeInterval(43650), aosAzimuth: 205, losAzimuth: 35),
        ]
    }()
}

#Preview {
    SatelliteView()
        .frame(width: 900, height: 650)
        .environment(AppState())
}
