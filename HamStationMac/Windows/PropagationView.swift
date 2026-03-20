// PropagationView.swift — Solar/propagation dashboard
// Gauges for SFI, K-index, A-index, X-ray flux, and per-band conditions.

import SwiftUI
import HamStationKit

struct PropagationView: View {
    @Environment(AppState.self) var appState

    private let bandOrder = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Solar indices cards
                solarIndicesSection

                Divider()

                // Band conditions
                bandConditionsSection

                // Last updated
                if let solar = appState.solarData {
                    HStack {
                        Spacer()
                        Text("Last updated: \(solar.updatedAt, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button {
                            // TODO: Refresh solar data
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Propagation")
    }

    // MARK: - Solar Indices

    private var solarIndicesSection: some View {
        HStack(spacing: 16) {
            if let solar = appState.solarData {
                solarCard(title: "Solar Flux Index", value: "\(solar.solarFluxIndex)", icon: "sun.max.fill", color: sfiColor(solar.solarFluxIndex))
                solarCard(title: "K-Index", value: "\(solar.kIndex)", icon: "waveform.path.ecg", color: kIndexColor(solar.kIndex))
                solarCard(title: "A-Index", value: "\(solar.aIndex)", icon: "chart.line.uptrend.xyaxis", color: aIndexColor(solar.aIndex))
                solarCard(title: "X-Ray Flux", value: solar.xrayFlux, icon: "bolt.fill", color: .blue)
            } else {
                Text("No solar data available")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private func solarCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title, design: .monospaced).bold())
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Band Conditions

    private var bandConditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Band Conditions")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(bandOrder, id: \.self) { band in
                    let condition = appState.solarData?.bandConditions[band] ?? .poor
                    bandConditionCard(band: band, condition: condition)
                }
            }
        }
    }

    private func bandConditionCard(band: String, condition: BandCondition) -> some View {
        HStack {
            Text(band)
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 44, alignment: .leading)

            Spacer()

            Text(condition.rawValue)
                .font(.caption.bold())
                .foregroundStyle(conditionColor(condition))

            Circle()
                .fill(conditionColor(condition))
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(conditionColor(condition).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(conditionColor(condition).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Color Helpers

    private func sfiColor(_ sfi: Int) -> Color {
        switch sfi {
        case 150...: return .green
        case 100..<150: return .yellow
        default: return .red
        }
    }

    private func kIndexColor(_ k: Int) -> Color {
        switch k {
        case 0...2: return .green
        case 3...4: return .yellow
        default: return .red
        }
    }

    private func aIndexColor(_ a: Int) -> Color {
        switch a {
        case 0...7: return .green
        case 8...15: return .yellow
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
    PropagationView()
        .frame(width: 800, height: 600)
        .environment(AppState())
}
