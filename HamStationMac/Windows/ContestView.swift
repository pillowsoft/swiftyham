// ContestView.swift — Contest operating view with QSO entry, score, rate, and multiplier tracking.
// Quick-log: Enter fills callsign, Tab to exchange, Enter to log.

import SwiftUI

struct ContestView: View {
    @Environment(AppState.self) var appState
    @State private var selectedContest: String = "CQWW-CW"
    @State private var callsignField: String = ""
    @State private var exchangeField: String = ""
    @State private var isDupeWarning: Bool = false
    @State private var selectedQSOId: UUID? = nil
    @State private var isContestActive: Bool = true
    @FocusState private var focusedField: EntryField?

    enum EntryField: Hashable {
        case callsign
        case exchange
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Contest info bar
            contestInfoBar

            Divider()

            HSplitView {
                // Left: Entry + QSO table
                VStack(spacing: 0) {
                    // QSO entry form
                    entryForm
                        .padding(12)

                    Divider()

                    // Recent QSOs table
                    qsoTable
                }
                .frame(minWidth: 500)

                // Right: Score + multipliers
                scorePanel
                    .frame(minWidth: 250, idealWidth: 280)
            }
        }
        .navigationTitle("Contest: \(selectedContest)")
    }

    // MARK: - Contest Info Bar

    private var contestInfoBar: some View {
        HStack(spacing: 20) {
            // Contest picker
            Picker("Contest", selection: $selectedContest) {
                Text("CQ WW CW").tag("CQWW-CW")
                Text("CQ WW SSB").tag("CQWW-SSB")
                Text("ARRL DX CW").tag("ARRL-DX-CW")
                Text("ARRL DX SSB").tag("ARRL-DX-SSB")
                Text("CQ WPX CW").tag("CQ-WPX-CW")
                Text("NAQP CW").tag("NAQP-CW")
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Divider().frame(height: 20)

            // Score
            VStack(spacing: 2) {
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleScore.score)")
                    .font(.system(.title3, design: .monospaced).bold())
            }

            Divider().frame(height: 20)

            // QSO count
            VStack(spacing: 2) {
                Text("QSOs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleScore.validQSOs)")
                    .font(.system(.body, design: .monospaced))
            }

            // Points
            VStack(spacing: 2) {
                Text("Points")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleScore.points)")
                    .font(.system(.body, design: .monospaced))
            }

            // Multipliers
            VStack(spacing: 2) {
                Text("Mults")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleScore.multipliers)")
                    .font(.system(.body, design: .monospaced))
            }

            Divider().frame(height: 20)

            // Rate
            VStack(spacing: 2) {
                Text("Rate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleRate.lastHour)/hr")
                    .font(.system(.body, design: .monospaced))
            }

            // 10-min rate
            VStack(spacing: 2) {
                Text("10 min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleRate.last10Min)")
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            // Timer
            VStack(spacing: 2) {
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("04:23:15")
                    .font(.system(.body, design: .monospaced))
            }

            // Dupes
            VStack(spacing: 2) {
                Text("Dupes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(ContestView.sampleScore.dupes)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - QSO Entry Form

    private var entryForm: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Band/Mode (from rig)
                HStack(spacing: 8) {
                    Text("20m")
                        .font(.system(.body, design: .monospaced).bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("CW")
                        .font(.system(.body, design: .monospaced).bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Callsign field
                VStack(alignment: .leading, spacing: 2) {
                    Text("Callsign").font(.caption2).foregroundStyle(.secondary)
                    TextField("W1AW", text: $callsignField)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.title3, design: .monospaced).bold())
                        .focused($focusedField, equals: .callsign)
                        .frame(width: 160)
                        .foregroundStyle(isDupeWarning ? .red : .primary)
                        .onSubmit {
                            // Check for dupe, then move to exchange
                            isDupeWarning = false // Reset; real app would check dupe
                            focusedField = .exchange
                        }
                }

                // Exchange field
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exchange").font(.caption2).foregroundStyle(.secondary)
                    TextField("599 05", text: $exchangeField)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.title3, design: .monospaced))
                        .focused($focusedField, equals: .exchange)
                        .frame(width: 160)
                        .onSubmit {
                            logQSO()
                        }
                }

                // Log button
                Button("Log QSO") {
                    logQSO()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(callsignField.isEmpty || exchangeField.isEmpty)

                Spacer()

                // Serial number
                VStack(spacing: 2) {
                    Text("Serial #")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("048")
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Dupe warning bar
            if isDupeWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("DUPE! \(callsignField.uppercased()) already worked on this band.")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - QSO Table

    private var qsoTable: some View {
        Table(ContestView.sampleQSOs, selection: $selectedQSOId) {
            TableColumn("#") { qso in
                Text("\(qso.number)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(30)

            TableColumn("Time") { qso in
                Text(qso.time, format: .dateTime.hour().minute())
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 40, ideal: 50)

            TableColumn("Callsign") { qso in
                Text(qso.callsign)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(qso.isDupe ? .red : .primary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Band") { qso in
                Text(qso.band)
                    .font(.system(.caption, design: .monospaced))
            }
            .width(40)

            TableColumn("Sent") { qso in
                Text(qso.exchangeSent)
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 60, ideal: 80)

            TableColumn("Rcvd") { qso in
                Text(qso.exchangeReceived)
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 60, ideal: 80)

            TableColumn("Pts") { qso in
                Text("\(qso.points)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(qso.points > 0 ? Color.primary : Color.red)
            }
            .width(30)

            TableColumn("Mult") { qso in
                if qso.isMultiplier {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            .width(30)
        }
    }

    // MARK: - Score Panel

    private var scorePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Band breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Band Breakdown")
                        .font(.headline)
                        .padding(.top, 12)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Band").font(.caption.bold()).foregroundStyle(.secondary)
                            Text("QSOs").font(.caption.bold()).foregroundStyle(.secondary)
                            Text("Pts").font(.caption.bold()).foregroundStyle(.secondary)
                            Text("Mults").font(.caption.bold()).foregroundStyle(.secondary)
                        }

                        ForEach(ContestView.sampleBandBreakdown) { band in
                            GridRow {
                                Text(band.band)
                                    .font(.system(.caption, design: .monospaced).bold())
                                Text("\(band.qsos)")
                                    .font(.system(.caption, design: .monospaced))
                                Text("\(band.points)")
                                    .font(.system(.caption, design: .monospaced))
                                Text("\(band.multipliers)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }

                Divider()

                // Multiplier summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multipliers")
                        .font(.headline)

                    // Zone multiplier chips
                    FlowLayout(spacing: 4) {
                        ForEach(ContestView.sampleMultipliers, id: \.self) { mult in
                            Text(mult)
                                .font(.system(.caption2, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Divider()

                // Rate graph placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("QSO Rate")
                        .font(.headline)

                    // Simple rate bars
                    ForEach(ContestView.sampleRateHistory) { entry in
                        HStack(spacing: 8) {
                            Text(entry.label)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(width: 40, alignment: .trailing)
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: CGFloat(entry.rate) * 2, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text("\(entry.rate)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .background(.background)
    }

    // MARK: - Actions

    private func logQSO() {
        guard !callsignField.isEmpty, !exchangeField.isEmpty else { return }
        // In the real app, this would call ContestEngine.logQSO()
        callsignField = ""
        exchangeField = ""
        isDupeWarning = false
        focusedField = .callsign
    }

    // MARK: - Sample Data

    static let sampleScore = SampleContestScore(
        totalQSOs: 47, validQSOs: 45, points: 135, multipliers: 28, score: 3780, dupes: 2
    )

    static let sampleRate = SampleRateInfo(last10Min: 8, lastHour: 42)

    struct SampleContestScore {
        let totalQSOs: Int
        let validQSOs: Int
        let points: Int
        let multipliers: Int
        let score: Int
        let dupes: Int
    }

    struct SampleRateInfo {
        let last10Min: Int
        let lastHour: Int
    }

    struct SampleQSO: Identifiable {
        let id: UUID
        let number: Int
        let callsign: String
        let band: String
        let exchangeSent: String
        let exchangeReceived: String
        let time: Date
        let isDupe: Bool
        let points: Int
        let isMultiplier: Bool
    }

    struct SampleBand: Identifiable {
        let id: String
        let band: String
        let qsos: Int
        let points: Int
        let multipliers: Int
    }

    struct SampleRateEntry: Identifiable {
        let id: String
        let label: String
        let rate: Int
    }

    static let sampleQSOs: [SampleQSO] = {
        let now = Date()
        return [
            SampleQSO(id: UUID(), number: 47, callsign: "PY2ABC", band: "20m", exchangeSent: "599 047", exchangeReceived: "599 11", time: now.addingTimeInterval(-30), isDupe: false, points: 3, isMultiplier: true),
            SampleQSO(id: UUID(), number: 46, callsign: "JA1XYZ", band: "20m", exchangeSent: "599 046", exchangeReceived: "599 25", time: now.addingTimeInterval(-90), isDupe: false, points: 3, isMultiplier: false),
            SampleQSO(id: UUID(), number: 45, callsign: "DL5ABC", band: "20m", exchangeSent: "599 045", exchangeReceived: "599 14", time: now.addingTimeInterval(-150), isDupe: false, points: 3, isMultiplier: false),
            SampleQSO(id: UUID(), number: 44, callsign: "W1AW", band: "20m", exchangeSent: "599 044", exchangeReceived: "599 05", time: now.addingTimeInterval(-210), isDupe: true, points: 0, isMultiplier: false),
            SampleQSO(id: UUID(), number: 43, callsign: "VK3BDX", band: "20m", exchangeSent: "599 043", exchangeReceived: "599 30", time: now.addingTimeInterval(-270), isDupe: false, points: 3, isMultiplier: true),
            SampleQSO(id: UUID(), number: 42, callsign: "UA3ABC", band: "40m", exchangeSent: "599 042", exchangeReceived: "599 16", time: now.addingTimeInterval(-330), isDupe: false, points: 3, isMultiplier: true),
            SampleQSO(id: UUID(), number: 41, callsign: "ZS6BKW", band: "40m", exchangeSent: "599 041", exchangeReceived: "599 38", time: now.addingTimeInterval(-390), isDupe: false, points: 3, isMultiplier: true),
            SampleQSO(id: UUID(), number: 40, callsign: "OH2BH", band: "40m", exchangeSent: "599 040", exchangeReceived: "599 15", time: now.addingTimeInterval(-450), isDupe: false, points: 3, isMultiplier: false),
            SampleQSO(id: UUID(), number: 39, callsign: "LU7YS", band: "40m", exchangeSent: "599 039", exchangeReceived: "599 13", time: now.addingTimeInterval(-510), isDupe: false, points: 3, isMultiplier: true),
            SampleQSO(id: UUID(), number: 38, callsign: "HL5BLI", band: "15m", exchangeSent: "599 038", exchangeReceived: "599 25", time: now.addingTimeInterval(-570), isDupe: false, points: 3, isMultiplier: true),
        ]
    }()

    static let sampleBandBreakdown: [SampleBand] = [
        SampleBand(id: "160m", band: "160m", qsos: 2, points: 6, multipliers: 2),
        SampleBand(id: "80m", band: "80m", qsos: 5, points: 15, multipliers: 4),
        SampleBand(id: "40m", band: "40m", qsos: 12, points: 36, multipliers: 8),
        SampleBand(id: "20m", band: "20m", qsos: 18, points: 54, multipliers: 10),
        SampleBand(id: "15m", band: "15m", qsos: 6, points: 18, multipliers: 3),
        SampleBand(id: "10m", band: "10m", qsos: 2, points: 6, multipliers: 1),
    ]

    static let sampleMultipliers: [String] = [
        "Z03", "Z04", "Z05", "Z08", "Z11", "Z13", "Z14", "Z15", "Z16",
        "Z18", "Z20", "Z22", "Z24", "Z25", "Z26", "Z27", "Z28",
        "Z29", "Z30", "Z31", "Z33", "Z35", "Z37", "Z38", "Z39", "Z40",
    ]

    static let sampleRateHistory: [SampleRateEntry] = [
        SampleRateEntry(id: "h1", label: "1hr", rate: 42),
        SampleRateEntry(id: "h2", label: "2hr", rate: 38),
        SampleRateEntry(id: "h3", label: "3hr", rate: 35),
        SampleRateEntry(id: "h4", label: "4hr", rate: 28),
    ]
}

// MARK: - FlowLayout

/// Simple flow layout for multiplier chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (size: CGSize(width: maxX, height: currentY + lineHeight), offsets: offsets)
    }
}

#Preview {
    ContestView()
        .frame(width: 1000, height: 650)
        .environment(AppState())
}
