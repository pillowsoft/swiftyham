// DemoOverlay.swift — Narration overlay displayed during demo mode
// A semi-transparent card at the bottom of the main content area with
// scene title, subtitle, navigation controls, and progress indicator.

import SwiftUI

struct DemoOverlay: View {
    let engine: DemoEngine

    var body: some View {
        if engine.isRunning, let scene = engine.currentScene {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    // Scene counter
                    Text("SCENE \(engine.currentSceneIndex + 1) OF \(engine.sceneCount)")
                        .font(.system(.caption2, design: .rounded).bold())
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))

                    // Title
                    Text(scene.title)
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(.white)
                        .id("title-\(scene.id)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    // Subtitle
                    Text(scene.subtitle)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 600)
                        .id("subtitle-\(scene.id)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    // Controls row
                    HStack(spacing: 20) {
                        // Previous
                        Button(action: { engine.previous() }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.currentSceneIndex == 0)
                        .opacity(engine.currentSceneIndex == 0 ? 0.3 : 1.0)

                        // Scene dots
                        HStack(spacing: 5) {
                            ForEach(0..<engine.sceneCount, id: \.self) { i in
                                Circle()
                                    .fill(dotColor(for: i))
                                    .frame(width: i == engine.currentSceneIndex ? 8 : 5,
                                           height: i == engine.currentSceneIndex ? 8 : 5)
                                    .animation(.easeInOut(duration: 0.3), value: engine.currentSceneIndex)
                            }
                        }

                        // Next
                        Button(action: { engine.next() }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        // Narration toggle
                        Button(action: { engine.narrationEnabled.toggle() }) {
                            Image(systemName: engine.narrationEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .help(engine.narrationEnabled ? "Mute narration" : "Enable narration")

                        Divider()
                            .frame(height: 20)
                            .background(.white.opacity(0.3))

                        // Stop
                        Button(action: { engine.stop() }) {
                            Label("End Demo", systemImage: "xmark.circle.fill")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white.opacity(0.9))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.15))
                                .frame(height: 3)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "FF6A00"), Color(hex: "FF9A40")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * engine.progress, height: 3)
                                .animation(.linear(duration: 0.1), value: engine.progress)
                        }
                    }
                    .frame(width: 360, height: 3)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 44)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "FF6A00").opacity(0.25),
                                            Color.black.opacity(0.4),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                .padding(.bottom, 40)
                .padding(.horizontal, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.6, bounce: 0.15), value: scene.id)
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index == engine.currentSceneIndex {
            return .white
        } else if index < engine.currentSceneIndex {
            return .white.opacity(0.6)
        } else {
            return .white.opacity(0.25)
        }
    }
}
