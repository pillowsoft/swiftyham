// InspectorView.swift — Right-side inspector panel
// Shows callsign info, DXCC, award status, and solar conditions for selection.

import SwiftUI
import HamStationKit

struct InspectorView: View {
    @Environment(AppState.self) var appState
    @Environment(ServiceContainer.self) var services
    @State private var insights: [SmartLogAnalysis.Insight] = []
    @State private var isAnalyzing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let qsoId = appState.selectedQSOId {
                    callsignSection
                    Divider()
                    dxccSection
                    Divider()
                    awardSection
                    Divider()
                    solarSection
                } else {
                    emptyState
                    Divider()
                    insightsSection
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a QSO")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Click a row in the logbook to see details here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AI Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Log Insights", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isAnalyzing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await analyzeLog() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if insights.isEmpty && !isAnalyzing {
                Text("Click refresh to analyze your log")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(insights.prefix(6)) { insight in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: insightIcon(insight.category))
                        .font(.caption)
                        .foregroundStyle(insightColor(insight.category))
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.caption.bold())
                        Text(insight.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func analyzeLog() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            // Fetch recent QSOs for analysis (last 1000)
            let qsos = try await services.database.fetchQSOs(limit: 1000)
            let progress = try await services.database.fetchAwardProgress(type: "DXCC")
            insights = SmartLogAnalysis.analyze(qsos: qsos, awardProgress: progress)
        } catch {
            // Fall back to empty analysis on error
            insights = SmartLogAnalysis.analyze(qsos: [], awardProgress: [])
        }
    }

    private func insightIcon(_ category: SmartLogAnalysis.InsightCategory) -> String {
        switch category {
        case .awards: return "medal"
        case .operating: return "clock"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .suggestion: return "lightbulb"
        }
    }

    private func insightColor(_ category: SmartLogAnalysis.InsightCategory) -> Color {
        switch category {
        case .awards: return .yellow
        case .operating: return .blue
        case .performance: return .green
        case .suggestion: return .orange
        }
    }

    // MARK: - Callsign Info

    private var callsignSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Callsign")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Placeholder data — will be populated from callsign lookup
            HStack {
                Text("W1AW")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Color(hex: "FF6A00"))
                Spacer()
            }

            LabeledContent("Name") {
                Text("ARRL HQ Station")
            }
            .font(.caption)

            LabeledContent("QTH") {
                Text("Newington, CT")
            }
            .font(.caption)

            LabeledContent("Grid") {
                Text("FN31pr")
                    .font(.system(.caption, design: .monospaced))
            }

            LabeledContent("Country") {
                Text("United States")
            }
            .font(.caption)

            LabeledContent("State") {
                Text("CT")
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }

    // MARK: - DXCC Entity

    private var dxccSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DXCC Entity")
                .font(.headline)
                .foregroundStyle(.secondary)

            LabeledContent("Entity") {
                Text("United States (#291)")
                    .font(.caption)
            }

            LabeledContent("Continent") {
                Text("NA")
                    .font(.system(.caption, design: .monospaced))
            }

            LabeledContent("CQ Zone") {
                Text("5")
                    .font(.system(.caption, design: .monospaced))
            }

            LabeledContent("ITU Zone") {
                Text("8")
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }

    // MARK: - Award Status

    private var awardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Award Status")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("United States (#291)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Band status grid
            let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(bands, id: \.self) { band in
                    HStack(spacing: 4) {
                        Text(band)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                        Circle()
                            .fill(sampleAwardColor(for: band))
                            .frame(width: 8, height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 12) {
                Label("Confirmed", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Label("Worked", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                Label("Needed", systemImage: "circle")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Solar Conditions

    private var solarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Solar Conditions")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let solar = appState.solarData {
                LabeledContent("SFI") {
                    Text("\(solar.solarFluxIndex)")
                        .font(.system(.caption, design: .monospaced).bold())
                }

                LabeledContent("K-index") {
                    Text("\(solar.kIndex)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(kIndexColor(solar.kIndex))
                }

                LabeledContent("A-index") {
                    Text("\(solar.aIndex)")
                        .font(.system(.caption, design: .monospaced).bold())
                }

                LabeledContent("X-ray") {
                    Text(solar.xrayFlux)
                        .font(.system(.caption, design: .monospaced).bold())
                }
            } else {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func sampleAwardColor(for band: String) -> Color {
        switch band {
        case "20m", "40m", "15m": return .green  // confirmed
        case "80m", "17m": return .yellow  // worked
        default: return .gray.opacity(0.3)  // needed
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

#Preview("With Selection") {
    let state = AppState()
    state.selectedQSOId = UUID()
    return InspectorView()
        .frame(width: 300, height: 600)
        .environment(state)
}

#Preview("Empty") {
    InspectorView()
        .frame(width: 300, height: 600)
        .environment(AppState())
}
