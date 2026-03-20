// AudioSpectrumView.swift — Audio spectrum analyzer with waterfall display
// Real-time spectrum + waterfall using WaterfallContainerView from HamStationKit.

import SwiftUI
import HamStationKit

struct AudioSpectrumView: View {
    @Environment(AppState.self) var appState
    @State private var isRunning = false
    @State private var selectedMode: SpectrumMode = .waterfall
    @State private var peakHold = false
    @State private var spectrumData: [Float] = Array(repeating: -120, count: 2048)

    enum SpectrumMode: String, CaseIterable {
        case spectrum = "Spectrum"
        case waterfall = "Waterfall"
        case both = "Both"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Control bar
            controlBar

            Divider()

            // Display area
            switch selectedMode {
            case .spectrum:
                spectrumView
            case .waterfall:
                waterfallView
            case .both:
                VStack(spacing: 0) {
                    spectrumView
                        .frame(minHeight: 150, idealHeight: 200)
                    Divider()
                    waterfallView
                }
            }
        }
        .navigationTitle("Audio Spectrum")
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button {
                isRunning.toggle()
            } label: {
                Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .accentColor)
            .controlSize(.small)

            Divider().frame(height: 20)

            Picker("Mode", selection: $selectedMode) {
                ForEach(SpectrumMode.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 250)

            Divider().frame(height: 20)

            Toggle("Peak Hold", isOn: $peakHold)
                .toggleStyle(.checkbox)
                .font(.caption)

            Spacer()

            if isRunning {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Audio In")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No audio input")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Spectrum View

    private var spectrumView: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .controlBackgroundColor)

                if isRunning {
                    // Live spectrum placeholder — animated noise
                    spectrumTrace(in: geometry.size)
                } else {
                    // Static display
                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Press Start to begin audio capture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // dB scale on left
                dbScale(height: geometry.size.height)

                // Frequency scale on bottom
                frequencyScale(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func spectrumTrace(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let binCount = spectrumData.count
            let binWidth = canvasSize.width / CGFloat(binCount)
            let dbRange: CGFloat = 100 // -120 to -20 dB
            let dbFloor: CGFloat = -120

            var path = Path()
            path.move(to: CGPoint(x: 0, y: canvasSize.height))

            for i in 0..<binCount {
                let x = CGFloat(i) * binWidth
                let db = CGFloat(spectrumData[i])
                let normalized = (db - dbFloor) / dbRange
                let y = canvasSize.height * (1 - min(max(normalized, 0), 1))
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(.green), lineWidth: 1)

            // Fill under the curve
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
            fillPath.addLine(to: CGPoint(x: 0, y: canvasSize.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(.green.opacity(0.1)))
        }
        .onAppear { generateSampleSpectrum() }
    }

    private func dbScale(height: CGFloat) -> some View {
        HStack {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach([-20, -40, -60, -80, -100, -120], id: \.self) { db in
                    Text("\(db)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if db != -120 { Spacer() }
                }
            }
            .frame(width: 30)
            .padding(.vertical, 4)
            Spacer()
        }
    }

    private func frequencyScale(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18, 24], id: \.self) { khz in
                    Text("\(khz) kHz")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if khz != 24 { Spacer() }
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Waterfall View

    private var waterfallView: some View {
        WaterfallContainerView(
            centerFrequency: appState.rigState?.frequency ?? 14_074_000,
            bandwidth: 48_000,
            vfoFrequency: appState.rigState?.frequency
        )
    }

    // MARK: - Helpers

    private func generateSampleSpectrum() {
        // Generate a realistic-looking noise floor with a few peaks
        var data = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            data[i] = -100 + Float.random(in: -10...10)
        }
        // Add some signal peaks
        let peaks = [200, 512, 800, 1024, 1400]
        for peak in peaks {
            let height = Float.random(in: -50...(-30))
            for j in max(0, peak-8)..<min(2048, peak+8) {
                let dist = abs(j - peak)
                data[j] = max(data[j], height + Float(dist) * (-3))
            }
        }
        spectrumData = data
    }
}

#Preview {
    AudioSpectrumView()
        .frame(width: 800, height: 500)
        .environment(AppState())
}
