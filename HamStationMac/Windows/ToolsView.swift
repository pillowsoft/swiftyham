// ToolsView.swift — Tools listing with navigation to implemented tools
// Implemented tools navigate to their views; others shown as "Coming Soon".

import SwiftUI

struct ToolsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tools")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                Text("Specialized tools for your station.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                activeToolCard(
                    icon: "waveform.badge.mic",
                    title: "CW Trainer",
                    description: "Practice sending and receiving Morse code at adjustable speeds. Includes Koch method trainer and QSO simulator.",
                    section: .cwTraining
                )

                activeToolCard(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    title: "Antenna Calculator",
                    description: "Calculate dipole, vertical, and Yagi dimensions for any frequency. Includes SWR estimator and radiation pattern viewer.",
                    section: .antennaTools
                )

                activeToolCard(
                    icon: "globe.americas",
                    title: "Satellite Tracker",
                    description: "Track amateur radio satellites with live orbital passes. Predict AOS/LOS times and Doppler shift for your QTH.",
                    section: .satellite
                )

                disabledToolCard(
                    icon: "waveform",
                    title: "Audio Spectrum Analyzer",
                    description: "Real-time audio spectrum display for monitoring receiver audio. Includes waterfall and peak hold modes."
                )

                disabledToolCard(
                    icon: "map",
                    title: "Great Circle Map",
                    description: "Azimuthal projection centered on your grid square showing beam headings and distances to DX stations."
                )

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Tools")
    }

    private func activeToolCard(icon: String, title: String, description: String, section: SidebarSection) -> some View {
        Button {
            appState.selectedSection = section
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(Color(hex: "FF6A00"))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "FF6A00").opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func disabledToolCard(icon: String, title: String, description: String) -> some View {
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
                    Text("Coming Soon")
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
