// CWTrainingView.swift — CW training view
// Koch trainer, callsign practice, QSO practice, and progress tracking.

import SwiftUI

struct CWTrainingView: View {
    @State private var selectedMode: TrainingMode = .koch

    enum TrainingMode: String, CaseIterable {
        case koch = "Koch Trainer"
        case callsign = "Callsign Practice"
        case qso = "QSO Practice"
        case progress = "Progress"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(TrainingMode.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch selectedMode {
            case .koch:
                KochTrainerSection()
            case .callsign:
                CallsignPracticeSection()
            case .qso:
                QSOPracticeSection()
            case .progress:
                ProgressSection()
            }
        }
        .navigationTitle("CW Training")
    }
}

// MARK: - Koch Trainer

private struct KochTrainerSection: View {
    @State private var currentLevel = 5
    @State private var speed = 20
    @State private var isPlaying = false
    @State private var sessionText = "KMSUA RSKMU AKSRM UMSAK RKMUS"
    @State private var userInput = ""
    @State private var showResult = false
    @State private var accuracy: Double = 0
    @State private var farnsworthSpeed = 15

    private let kochOrder: [Character] = [
        "K", "M", "R", "S", "U", "A", "P", "T", "L", "O",
        "W", "I", ".", "N", "J", "E", "F", "0", "Y", ",",
        "V", "G", "5", "/", "Q", "9", "Z", "H", "3", "8",
        "B", "?", "4", "2", "7", "C", "1", "D", "6", "X"
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Level & speed controls
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(currentLevel)")
                        .font(.title2.bold())
                    Text("Characters: \(String(kochOrder.prefix(currentLevel)))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if currentLevel < kochOrder.count {
                        Text("Next: \(String(kochOrder[currentLevel]))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider().frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(speed) },
                            set: { speed = Int($0) }
                        ), in: 5...40, step: 1)
                        Text("\(speed) WPM")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 70)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Farnsworth")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(farnsworthSpeed) },
                            set: { farnsworthSpeed = Int($0) }
                        ), in: 5...40, step: 1)
                        Text("\(farnsworthSpeed) WPM")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 70)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Play controls
            HStack(spacing: 16) {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "FF6A00"))
                }
                .buttonStyle(.plain)

                Button("New Session") {
                    showResult = false
                    userInput = ""
                    // Generate new session text
                    let chars = Array(kochOrder.prefix(currentLevel))
                    var groups: [String] = []
                    for _ in 0..<5 {
                        var group = ""
                        for _ in 0..<5 {
                            group.append(chars.randomElement()!)
                        }
                        groups.append(group)
                    }
                    sessionText = groups.joined(separator: " ")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal)

            // Input area
            VStack(alignment: .leading, spacing: 4) {
                Text("Type what you hear:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextEditor(text: $userInput)
                    .font(.system(.title3, design: .monospaced))
                    .frame(minHeight: 80)
                    .border(Color(nsColor: .separatorColor))
            }
            .padding(.horizontal)

            // Score button
            HStack {
                Button("Score") {
                    let expected = sessionText.uppercased().filter { $0 != " " }
                    let actual = userInput.uppercased().filter { $0 != " " }
                    var correct = 0
                    for (i, ch) in expected.enumerated() {
                        if i < actual.count && actual[actual.index(actual.startIndex, offsetBy: i)] == ch {
                            correct += 1
                        }
                    }
                    accuracy = expected.isEmpty ? 0 : Double(correct) / Double(expected.count) * 100
                    showResult = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(userInput.isEmpty)

                if showResult {
                    HStack(spacing: 8) {
                        Text(String(format: "%.0f%%", accuracy))
                            .font(.system(.title, design: .monospaced).bold())
                            .foregroundStyle(accuracy >= 90 ? .green : (accuracy >= 70 ? .yellow : .red))
                        if accuracy >= 90 {
                            Text("Advance to level \(currentLevel + 1)!")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal)

            // Reveal
            if showResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sent:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(sessionText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}

// MARK: - Callsign Practice

private struct CallsignPracticeSection: View {
    @State private var callsigns = ["W1AW", "K3LR", "N5DX", "WB2JKJ", "AA1QD",
                                     "KD2OGR", "W4BFB", "N0AX", "VE3KI", "JA1NUT"]
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var score = 0
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Callsign Copy Practice")
                .font(.title2.bold())
                .padding(.top, 8)

            Text("Listen to the callsign and type it below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Callsign \(currentIndex + 1) of \(callsigns.count)")
                    .font(.headline)

                Spacer()

                Text("Score: \(score)/\(attempts)")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(Color(hex: "FF6A00"))
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    // Play callsign audio
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "FF6A00"))
                }
                .buttonStyle(.plain)

                TextField("Type callsign...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.title2, design: .monospaced))
                    .frame(maxWidth: 200)
                    .onSubmit { checkAnswer() }

                Button("Check") { checkAnswer() }
                    .buttonStyle(.borderedProminent)
                    .disabled(userInput.isEmpty)

                Button("Skip") {
                    currentIndex = (currentIndex + 1) % callsigns.count
                    userInput = ""
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func checkAnswer() {
        attempts += 1
        if userInput.uppercased() == callsigns[currentIndex] {
            score += 1
        }
        currentIndex = (currentIndex + 1) % callsigns.count
        userInput = ""
    }
}

// MARK: - QSO Practice

private struct QSOPracticeSection: View {
    @State private var isPlaying = false
    @State private var userTranscript = ""

    private let sampleQSO = """
    K3LR DE W1AW W1AW K
    W1AW DE K3LR GM UR RST 599 599 NAME JOHN QTH PA HW? W1AW DE K3LR K
    K3LR DE W1AW R TNX JOHN UR RST 589 589 NAME BOB QTH CT 73 K3LR DE W1AW K
    W1AW DE K3LR R TNX BOB 73 GL W1AW DE K3LR SK
    """

    var body: some View {
        VStack(spacing: 16) {
            Text("QSO Copy Practice")
                .font(.title2.bold())
                .padding(.top, 8)

            Text("Listen to the simulated QSO and transcribe it below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "FF6A00"))
                }
                .buttonStyle(.plain)

                Button("New QSO") {
                    userTranscript = ""
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Transcription:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextEditor(text: $userTranscript)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .border(Color(nsColor: .separatorColor))
            }
            .padding(.horizontal)

            HStack {
                Button("Reveal Answer") {
                    userTranscript = sampleQSO
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - Progress

private struct ProgressSection: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Training Progress")
                .font(.title2.bold())
                .padding(.top, 8)

            // Level progress bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Koch Level Progress")
                    .font(.headline)

                HStack {
                    Text("Level 5 of 40")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("12.5%")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6A00"))
                }

                ProgressView(value: 5, total: 40)
                    .tint(Color(hex: "FF6A00"))

                Text("Unlocked: K M R S U")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            // Session history (sample)
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Sessions")
                    .font(.headline)

                ForEach(sampleSessions, id: \.date) { session in
                    HStack {
                        Text(session.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Level \(session.level)")
                            .font(.caption.bold())
                        Text("\(session.speed) WPM")
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text(String(format: "%.0f%%", session.accuracy))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(session.accuracy >= 90 ? .green : (session.accuracy >= 70 ? .yellow : .red))
                    }
                    Divider()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            Spacer()
        }
    }

    struct SampleSession {
        let date: String
        let level: Int
        let speed: Int
        let accuracy: Double
    }

    private var sampleSessions: [SampleSession] {
        [
            SampleSession(date: "2026-03-19", level: 5, speed: 20, accuracy: 92),
            SampleSession(date: "2026-03-18", level: 5, speed: 20, accuracy: 85),
            SampleSession(date: "2026-03-17", level: 4, speed: 18, accuracy: 94),
            SampleSession(date: "2026-03-16", level: 4, speed: 18, accuracy: 88),
            SampleSession(date: "2026-03-15", level: 3, speed: 15, accuracy: 91),
        ]
    }
}

#Preview {
    CWTrainingView()
        .frame(width: 800, height: 600)
        .environment(AppState())
}
