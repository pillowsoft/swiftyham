// ToolsView.swift — Placeholder tools listing
// Phase 2+ tools shown as disabled cards with descriptions.

import SwiftUI

struct ToolsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tools")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                Text("Additional tools are planned for future releases.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                toolCard(
                    icon: "waveform.badge.mic",
                    title: "CW Trainer",
                    description: "Practice sending and receiving Morse code at adjustable speeds. Includes Koch method trainer and QSO simulator.",
                    phase: "Phase 2"
                )

                toolCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Antenna Calculator",
                    description: "Calculate dipole, vertical, and Yagi dimensions for any frequency. Includes SWR estimator and radiation pattern viewer.",
                    phase: "Phase 2"
                )

                toolCard(
                    icon: "globe.americas",
                    title: "Satellite Tracker",
                    description: "Track amateur radio satellites with live orbital passes. Predict AOS/LOS times and Doppler shift for your QTH.",
                    phase: "Phase 2"
                )

                toolCard(
                    icon: "waveform",
                    title: "Audio Spectrum Analyzer",
                    description: "Real-time audio spectrum display for monitoring receiver audio. Includes waterfall and peak hold modes.",
                    phase: "Phase 2"
                )

                toolCard(
                    icon: "map",
                    title: "Great Circle Map",
                    description: "Azimuthal projection centered on your grid square showing beam headings and distances to DX stations.",
                    phase: "Phase 2"
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Tools")
    }

    private func toolCard(icon: String, title: String, description: String, phase: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tertiary)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(phase)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.blue)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .opacity(0.6)
    }
}

#Preview {
    ToolsView()
        .frame(width: 700, height: 600)
        .environment(AppState())
}
