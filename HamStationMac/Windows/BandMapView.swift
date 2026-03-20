// BandMapView.swift — Frequency-axis band map
// Horizontal frequency ruler with DX spot markers and rig cursor.

import SwiftUI
import HamStationKit

struct BandMapView: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var selectedBand: String = "20m"

    private let hfBands: [(label: String, low: Double, high: Double)] = [
        ("160m", 1_800_000, 2_000_000),
        ("80m", 3_500_000, 4_000_000),
        ("40m", 7_000_000, 7_300_000),
        ("30m", 10_100_000, 10_150_000),
        ("20m", 14_000_000, 14_350_000),
        ("17m", 18_068_000, 18_168_000),
        ("15m", 21_000_000, 21_450_000),
        ("12m", 24_890_000, 24_990_000),
        ("10m", 28_000_000, 29_700_000),
    ]

    private var currentBand: (label: String, low: Double, high: Double) {
        hfBands.first { $0.label == selectedBand } ?? hfBands[4]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Band selector
            bandSelector
            Divider()

            // Band map area
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Background
                    Color(nsColor: .controlBackgroundColor)

                    // Frequency ruler
                    frequencyRuler(in: geometry)

                    // Spot markers
                    ForEach(spotsForBand) { spot in
                        spotMarker(spot, in: geometry)
                    }

                    // Rig cursor
                    if let rigFreq = appState.rigState?.frequency,
                       rigFreq >= currentBand.low && rigFreq <= currentBand.high {
                        rigCursor(frequency: rigFreq, in: geometry)
                    }
                }
            }

            Divider()

            // Legend
            legendBar
        }
        .navigationTitle("Band Map")
    }

    // MARK: - Band Selector

    private var bandSelector: some View {
        HStack(spacing: 4) {
            ForEach(hfBands, id: \.label) { band in
                Button(band.label) {
                    selectedBand = band.label
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(selectedBand == band.label ? Color(hex: "FF6A00") : nil)
            }
            Spacer()
            Text("\(spotsForBand.count) spots on \(selectedBand)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Frequency Ruler

    private func frequencyRuler(in geometry: GeometryProxy) -> some View {
        let band = currentBand
        let range = band.high - band.low
        let tickCount = 10
        let step = range / Double(tickCount)

        return VStack(spacing: 0) {
            // Ruler with tick marks
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
                    .offset(y: 0)

                ForEach(0...tickCount, id: \.self) { i in
                    let freq = band.low + Double(i) * step
                    let x = xPosition(for: freq, in: geometry.size.width)

                    VStack(spacing: 2) {
                        Text(formatRulerFrequency(freq))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(width: 1, height: 8)
                    }
                    .position(x: x, y: 16)
                }
            }
            .frame(height: 36)

            Spacer()
        }
    }

    // MARK: - Spot Markers

    private func spotMarker(_ spot: DisplaySpot, in geometry: GeometryProxy) -> some View {
        let x = xPosition(for: spot.frequency * 1000, in: geometry.size.width)
        let color = spotColor(spot.status)

        return VStack(spacing: 2) {
            Text(spot.dxCallsign)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Rectangle()
                .fill(color)
                .frame(width: 1, height: 20)
        }
        .position(x: x, y: 70)
        .onTapGesture {
            let hz = spot.frequency * 1000
            Task {
                if let rig = services.rigConnection {
                    try? await rig.setFrequency(hz)
                }
                // Optimistic UI update
                if let current = appState.rigState {
                    appState.rigState = HamStationKit.RigState(
                        frequency: hz,
                        mode: current.mode,
                        pttActive: current.pttActive,
                        signalStrength: current.signalStrength
                    )
                }
            }
        }
    }

    // MARK: - Rig Cursor

    private func rigCursor(frequency: Double, in geometry: GeometryProxy) -> some View {
        let x = xPosition(for: frequency, in: geometry.size.width)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "FF6A00"))
                .frame(width: 2, height: geometry.size.height)
        }
        .position(x: x, y: geometry.size.height / 2)
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Needed").font(.caption2)
            }
            HStack(spacing: 4) {
                Circle().fill(.yellow).frame(width: 8, height: 8)
                Text("Worked").font(.caption2)
            }
            HStack(spacing: 4) {
                Circle().fill(.gray).frame(width: 8, height: 8)
                Text("Confirmed").font(.caption2)
            }
            Spacer()
            HStack(spacing: 4) {
                Rectangle().fill(Color(hex: "FF6A00")).frame(width: 12, height: 2)
                Text("Rig VFO").font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func xPosition(for frequency: Double, in width: CGFloat) -> CGFloat {
        let band = currentBand
        let fraction = (frequency - band.low) / (band.high - band.low)
        let clamped = max(0, min(1, fraction))
        let padding: CGFloat = 20
        return padding + CGFloat(clamped) * (width - 2 * padding)
    }

    private func formatRulerFrequency(_ hz: Double) -> String {
        let mhz = hz / 1_000_000.0
        return String(format: "%.3f", mhz)
    }

    private func spotColor(_ status: DisplaySpot.SpotStatus) -> Color {
        switch status {
        case .needed: return .green
        case .worked: return .yellow
        case .confirmed: return .gray
        }
    }

    private var spotsForBand: [DisplaySpot] {
        let band = currentBand
        return appState.recentSpots.filter { spot in
            let hz = spot.frequency * 1000
            return hz >= band.low && hz <= band.high
        }
    }
}

#Preview {
    BandMapView()
        .frame(width: 900, height: 400)
        .environment(AppState())
        .environment(try! ServiceContainer())
}
