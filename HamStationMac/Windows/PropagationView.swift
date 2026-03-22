// PropagationView.swift — Solar/propagation dashboard
// Gauges for SFI, K-index, A-index, X-ray flux, band conditions,
// grey line map, and sunrise/sunset times.

import SwiftUI
import MapKit
import HamStationKit

struct PropagationView: View {
    @Environment(AppState.self) var appState
    @State private var greyLineRefreshToken = UUID()
    @State private var pskReports: [PSKReport] = []
    @State private var isPSKLoading = false

    private let bandOrder = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Solar indices cards
                solarIndicesSection

                Divider()

                // Grey line map + sunrise/sunset
                greyLineSection

                Divider()

                // Band recommendations (AI-powered)
                bandRecommendationsSection

                Divider()

                // Band conditions
                bandConditionsSection

                Divider()

                // PSK Reporter live spots
                pskReporterSection

                // Last updated
                if let solar = appState.solarData {
                    HStack {
                        Spacer()
                        Text("Last updated: \(solar.updatedAt, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if appState.isSolarDataLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Button {
                                Task {
                                    appState.isSolarDataLoading = true
                                    defer { appState.isSolarDataLoading = false }
                                    if let service = appState.networkService {
                                        appState.solarData = try? await service.fetchSolarData()
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Propagation")
        .task {
            // Refresh grey line every 60 seconds
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                greyLineRefreshToken = UUID()
            }
        }
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

    // MARK: - Grey Line Map

    private var greyLineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grey Line")
                .font(.headline)

            HStack(spacing: 16) {
                // Map with grey line overlay
                greyLineMap
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Sunrise/sunset for operator's QTH
                sunTimesPanel
                    .frame(width: 200)
            }
        }
    }

    private var greyLineMap: some View {
        // greyLineRefreshToken dependency triggers recalculation every 60s
        let _ = greyLineRefreshToken
        let greyLine = SunCalculator.greyLinePath()
        let coordinates = greyLine.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        return Map {
            // Draw the grey line as a polyline
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(.orange, lineWidth: 2)
            }

            // Mark operator's QTH if available
            if let grid = appState.gridSquare.isEmpty ? nil : String(appState.gridSquare.prefix(4)),
               let (lat, lon) = gridToCoordinate(grid) {
                Annotation("My QTH", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .mapStyle(.imagery(elevation: .flat))
    }

    private var sunTimesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let grid = appState.gridSquare.isEmpty ? nil : String(appState.gridSquare.prefix(4)),
               let (lat, lon) = gridToCoordinate(grid) {
                let solar = SunCalculator.solarTimes(latitude: lat, longitude: lon)

                Label("My QTH (\(grid))", systemImage: "location.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                if solar.isPolarDay {
                    sunTimeRow(icon: "sun.max.fill", label: "Polar Day", time: nil, color: .yellow)
                } else if solar.isPolarNight {
                    sunTimeRow(icon: "moon.fill", label: "Polar Night", time: nil, color: .indigo)
                } else {
                    sunTimeRow(icon: "sunrise.fill", label: "Sunrise", time: solar.sunrise, color: .orange)
                    sunTimeRow(icon: "sunset.fill", label: "Sunset", time: solar.sunset, color: .red)

                    if let dawn = solar.civilDawn {
                        sunTimeRow(icon: "cloud.sun.fill", label: "Civil Dawn", time: dawn, color: .blue)
                    }
                    if let dusk = solar.civilDusk {
                        sunTimeRow(icon: "cloud.moon.fill", label: "Civil Dusk", time: dusk, color: .indigo)
                    }

                    Divider()

                    HStack {
                        Image(systemName: solar.isDaytime ? "sun.max.fill" : "moon.stars.fill")
                            .foregroundStyle(solar.isDaytime ? .yellow : .indigo)
                        Text(solar.isDaytime ? "Currently daytime" : "Currently nighttime")
                            .font(.caption)
                    }
                }
            } else {
                Text("Set grid square in settings to see sunrise/sunset times")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sunTimeRow(icon: String, label: String, time: Date?, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
            Spacer()
            if let time {
                Text(time, format: .dateTime.hour().minute())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("UTC")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Band Recommendations

    private var bandRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recommended Now", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            let recommendations = BandAdvisor.recommend(
                solarData: appState.solarData,
                neededEntities: [],
                dxccEntities: []
            )

            if recommendations.isEmpty {
                Text("No band recommendations available — check solar data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(recommendations.prefix(5)) { rec in
                    HStack(spacing: 8) {
                        // Priority indicator
                        Circle()
                            .fill(priorityColor(rec.priority))
                            .frame(width: 8, height: 8)

                        Text(rec.band)
                            .font(.system(.body, design: .monospaced).bold())
                            .frame(width: 44, alignment: .leading)

                        Text(rec.mode)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Text(rec.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func priorityColor(_ priority: BandAdvisor.Recommendation.Priority) -> Color {
        switch priority {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
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

            Text(condition.rawValue.capitalized)
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

    // MARK: - PSK Reporter

    private var pskReporterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PSK Reporter")
                    .font(.headline)
                Spacer()
                if isPSKLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Button {
                        Task { await fetchPSKReports() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if pskReports.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No signal reports")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if !appState.operatorCallsign.isEmpty && appState.operatorCallsign != "N0CALL" {
                            Text("Click refresh to fetch reports for \(appState.operatorCallsign)")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                        }
                    }
                    Spacer()
                }
                .frame(minHeight: 60)
            } else {
                // Reports table
                LazyVStack(spacing: 2) {
                    // Header
                    HStack {
                        Text("Callsign").frame(width: 80, alignment: .leading)
                        Text("Band").frame(width: 50, alignment: .leading)
                        Text("Mode").frame(width: 40, alignment: .leading)
                        Text("SNR").frame(width: 40, alignment: .trailing)
                        Text("Grid").frame(width: 50, alignment: .leading)
                        Text("Time").frame(width: 50, alignment: .trailing)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                    ForEach(pskReports.prefix(20)) { report in
                        HStack {
                            Text(report.senderCallsign)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 80, alignment: .leading)
                            Text(report.band)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 50, alignment: .leading)
                            Text(report.mode)
                                .font(.caption)
                                .frame(width: 40, alignment: .leading)
                            Text("\(report.snr) dB")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(report.snr >= 0 ? .green : .orange)
                                .frame(width: 40, alignment: .trailing)
                            Text(report.senderGrid ?? "—")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 50, alignment: .leading)
                            Text(report.timestamp, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("\(pskReports.count) reports")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func fetchPSKReports() async {
        guard let service = appState.networkService else { return }
        let callsign = appState.operatorCallsign
        guard !callsign.isEmpty && callsign != "N0CALL" else { return }

        isPSKLoading = true
        defer { isPSKLoading = false }

        let client = await service.createPSKReporterClient()
        pskReports = (try? await client.fetchReports(receiverCallsign: callsign)) ?? []
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

    // MARK: - Grid Helpers

    /// Convert a 4-character Maidenhead grid to (latitude, longitude).
    private func gridToCoordinate(_ grid: String) -> (Double, Double)? {
        guard grid.count >= 4 else { return nil }
        let chars = Array(grid.uppercased())
        guard let a = chars[0].asciiValue, let b = chars[1].asciiValue,
              let c = chars[2].asciiValue, let d = chars[3].asciiValue else { return nil }

        let lon = Double(a - 65) * 20.0 + Double(c - 48) * 2.0 + 1.0 - 180.0
        let lat = Double(b - 65) * 10.0 + Double(d - 48) * 1.0 + 0.5 - 90.0
        return (lat, lon)
    }
}

#Preview {
    PropagationView()
        .frame(width: 900, height: 700)
        .environment(AppState())
}
