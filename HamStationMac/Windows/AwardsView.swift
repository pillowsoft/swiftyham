// AwardsView.swift — Award progress dashboard
// DXCC matrix, WAS grid, WAZ grid with worked/confirmed status.

import SwiftUI

struct AwardsView: View {
    @State private var selectedAward: AwardTab = .dxcc

    enum AwardTab: String, CaseIterable {
        case dxcc = "DXCC"
        case was = "WAS"
        case waz = "WAZ"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Award selector
            Picker("Award", selection: $selectedAward) {
                ForEach(AwardTab.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch selectedAward {
            case .dxcc:
                DXCCMatrixView()
            case .was:
                WASGridView()
            case .waz:
                WAZGridView()
            }
        }
        .navigationTitle("Awards")
    }
}

// MARK: - DXCC Matrix

private struct DXCCMatrixView: View {
    private let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m"]

    var body: some View {
        VStack(spacing: 0) {
            // Summary
            HStack(spacing: 24) {
                VStack {
                    Text("87")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))
                    Text("Worked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("/")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                VStack {
                    Text("340")
                        .font(.system(.title, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 40)
                VStack {
                    Text("42")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(.green)
                    Text("Confirmed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                legendView
            }
            .padding()

            Divider()

            // Matrix table
            ScrollView {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("Entity")
                            .font(.caption.bold())
                            .frame(width: 160, alignment: .leading)
                        ForEach(bands, id: \.self) { band in
                            Text(band)
                                .font(.system(.caption2, design: .monospaced).bold())
                                .frame(width: 44)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    ForEach(DXCCMatrixView.sampleEntities, id: \.name) { entity in
                        HStack(spacing: 0) {
                            Text(entity.name)
                                .font(.caption)
                                .frame(width: 160, alignment: .leading)
                                .lineLimit(1)

                            ForEach(bands, id: \.self) { band in
                                let status = entity.bandStatus[band] ?? .needed
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 10, height: 10)
                                    .frame(width: 44)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)

                        if entity.name != DXCCMatrixView.sampleEntities.last?.name {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private var legendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Confirmed").font(.caption2)
            }
            HStack(spacing: 4) {
                Circle().fill(.yellow).frame(width: 8, height: 8)
                Text("Worked").font(.caption2)
            }
            HStack(spacing: 4) {
                Circle().fill(.gray.opacity(0.3)).frame(width: 8, height: 8)
                Text("Needed").font(.caption2)
            }
        }
    }

    private func statusColor(_ status: EntityBandStatus) -> Color {
        switch status {
        case .confirmed: return .green
        case .worked: return .yellow
        case .needed: return .gray.opacity(0.3)
        }
    }

    // MARK: - Sample Data

    enum EntityBandStatus { case confirmed, worked, needed }

    struct DXCCEntity {
        let name: String
        let bandStatus: [String: EntityBandStatus]
    }

    static let sampleEntities: [DXCCEntity] = [
        DXCCEntity(name: "United States", bandStatus: ["160m": .confirmed, "80m": .confirmed, "40m": .confirmed, "30m": .confirmed, "20m": .confirmed, "17m": .confirmed, "15m": .confirmed, "12m": .worked, "10m": .confirmed]),
        DXCCEntity(name: "Canada", bandStatus: ["80m": .confirmed, "40m": .confirmed, "20m": .confirmed, "15m": .worked, "10m": .worked]),
        DXCCEntity(name: "Japan", bandStatus: ["20m": .confirmed, "17m": .worked, "15m": .confirmed]),
        DXCCEntity(name: "Germany", bandStatus: ["40m": .confirmed, "20m": .confirmed, "15m": .confirmed, "10m": .worked]),
        DXCCEntity(name: "England", bandStatus: ["80m": .worked, "40m": .confirmed, "20m": .confirmed, "15m": .worked]),
        DXCCEntity(name: "France", bandStatus: ["20m": .confirmed, "15m": .worked]),
        DXCCEntity(name: "Brazil", bandStatus: ["20m": .worked, "15m": .confirmed, "10m": .worked]),
        DXCCEntity(name: "Australia", bandStatus: ["20m": .confirmed, "17m": .worked]),
        DXCCEntity(name: "South Africa", bandStatus: ["20m": .worked]),
        DXCCEntity(name: "Argentina", bandStatus: ["40m": .worked, "20m": .confirmed]),
        DXCCEntity(name: "Finland", bandStatus: ["80m": .confirmed, "40m": .confirmed, "20m": .confirmed]),
        DXCCEntity(name: "Croatia", bandStatus: ["20m": .worked]),
        DXCCEntity(name: "Greece", bandStatus: ["20m": .worked, "15m": .worked]),
        DXCCEntity(name: "Qatar", bandStatus: ["20m": .confirmed]),
        DXCCEntity(name: "Indonesia", bandStatus: ["15m": .worked]),
        DXCCEntity(name: "Falkland Is.", bandStatus: ["40m": .worked]),
        DXCCEntity(name: "Cyprus", bandStatus: ["40m": .confirmed]),
        DXCCEntity(name: "Iceland", bandStatus: ["40m": .worked]),
        DXCCEntity(name: "South Korea", bandStatus: ["20m": .confirmed]),
        DXCCEntity(name: "Hawaii", bandStatus: ["20m": .confirmed, "15m": .worked]),
    ]
}

// MARK: - WAS Grid

private struct WASGridView: View {
    private let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                VStack {
                    Text("38")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))
                    Text("Worked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("/ 50")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Divider().frame(height: 40)
                VStack {
                    Text("29")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(.green)
                    Text("Confirmed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                    ForEach(states, id: \.self) { state in
                        let status = sampleStateStatus(state)
                        Text(state)
                            .font(.system(.caption, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(stateColor(status))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding()
            }
        }
    }

    private func sampleStateStatus(_ state: String) -> String {
        let confirmed = ["CA", "NY", "TX", "FL", "OH", "IL", "PA", "GA", "NC", "MI",
                         "NJ", "VA", "WA", "AZ", "MA", "TN", "IN", "MO", "MD", "WI",
                         "CO", "MN", "AL", "SC", "LA", "KY", "OR", "OK", "CT", "IA"]
        let worked = ["NV", "NM", "NH", "ME", "HI", "KS", "AR", "MS"]
        if confirmed.contains(state) { return "confirmed" }
        if worked.contains(state) { return "worked" }
        return "needed"
    }

    private func stateColor(_ status: String) -> Color {
        switch status {
        case "confirmed": return .green.opacity(0.3)
        case "worked": return .yellow.opacity(0.3)
        default: return .gray.opacity(0.1)
        }
    }
}

// MARK: - WAZ Grid

private struct WAZGridView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                VStack {
                    Text("28")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))
                    Text("Worked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("/ 40")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Divider().frame(height: 40)
                VStack {
                    Text("19")
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(.green)
                    Text("Confirmed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(1...40, id: \.self) { zone in
                        let status = sampleZoneStatus(zone)
                        VStack(spacing: 2) {
                            Text("Z\(zone)")
                                .font(.system(.caption, design: .monospaced).bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(zoneColor(status))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding()
            }
        }
    }

    private func sampleZoneStatus(_ zone: Int) -> String {
        let confirmed = [1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 20, 25, 27, 28, 33, 34, 35]
        let worked = [10, 11, 12, 13, 17, 21, 22, 26, 37]
        if confirmed.contains(zone) { return "confirmed" }
        if worked.contains(zone) { return "worked" }
        return "needed"
    }

    private func zoneColor(_ status: String) -> Color {
        switch status {
        case "confirmed": return .green.opacity(0.3)
        case "worked": return .yellow.opacity(0.3)
        default: return .gray.opacity(0.1)
        }
    }
}

#Preview {
    AwardsView()
        .frame(width: 900, height: 600)
        .environment(AppState())
}
