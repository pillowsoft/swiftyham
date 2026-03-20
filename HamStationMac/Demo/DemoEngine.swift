// DemoEngine.swift — Orchestrates the self-running demo
// Manages scene transitions, progress tracking, and auto-advance timing.

import SwiftUI
import HamStationKit

@Observable
@MainActor
final class DemoEngine {
    private(set) var isRunning: Bool = false
    private(set) var currentSceneIndex: Int = 0
    private(set) var currentScene: DemoScene?
    private(set) var progress: Double = 0 // 0...1 within current scene

    private var advanceTask: Task<Void, Never>?
    private var setupTask: Task<Void, Never>?
    private var scenes: [DemoScene] = []

    let appState: AppState
    let speechEngine = SpeechEngine()
    var narrationEnabled: Bool = true

    // Snapshot of pre-demo state so we can restore it
    private var savedCallsign: String = ""
    private var savedGrid: String = ""
    private var savedRigState: RigState?
    private var savedRigConnection: ConnectionState = .disconnected
    private var savedClusterConnection: ConnectionState = .disconnected
    private var savedSolarData: SolarData?
    private var savedSpots: [DisplaySpot] = []

    init(appState: AppState) {
        self.appState = appState
    }

    var sceneCount: Int { scenes.count }
    var isLastScene: Bool { currentSceneIndex >= scenes.count - 1 }

    func start() {
        // Snapshot current state
        savedCallsign = appState.operatorCallsign
        savedGrid = appState.gridSquare
        savedRigState = appState.rigState
        savedRigConnection = appState.rigConnectionState
        savedClusterConnection = appState.clusterConnectionState
        savedSolarData = appState.solarData
        savedSpots = appState.recentSpots

        scenes = DemoScript.scenes(appState: appState)
        isRunning = true
        currentSceneIndex = 0
        appState.isDemoMode = true
        // Never fall back to Apple TTS during demo — silence is better than robotic voice
        speechEngine.suppressSystemFallback = true
        playScene(at: 0)
    }

    func stop() {
        advanceTask?.cancel()
        setupTask?.cancel()
        speechEngine.stop()
        isRunning = false
        currentScene = nil
        progress = 0

        // Restore pre-demo state
        appState.operatorCallsign = savedCallsign
        appState.gridSquare = savedGrid
        appState.rigState = savedRigState
        appState.rigConnectionState = savedRigConnection
        appState.clusterConnectionState = savedClusterConnection
        appState.solarData = savedSolarData
        appState.recentSpots = savedSpots
        appState.demoFT8Decodes = []
        appState.demoChatMessages = []
        appState.isDemoMode = false
    }

    func next() {
        advanceTask?.cancel()
        setupTask?.cancel()
        speechEngine.stop()
        let nextIndex = currentSceneIndex + 1
        if nextIndex < scenes.count {
            playScene(at: nextIndex)
        } else {
            stop()
        }
    }

    func previous() {
        advanceTask?.cancel()
        setupTask?.cancel()
        speechEngine.stop()
        let prevIndex = max(0, currentSceneIndex - 1)
        playScene(at: prevIndex)
    }

    private func playScene(at index: Int) {
        currentSceneIndex = index
        let scene = scenes[index]
        progress = 0

        // Ensure scene has at least 12 seconds for Kokoro TTS to generate + play
        let effectiveDuration = max(scene.duration, 12.0)

        withAnimation(.easeInOut(duration: 0.5)) {
            currentScene = scene
            appState.selectedSection = scene.section
        }

        // Run the scene's setup action (populates mock data)
        setupTask = Task {
            await scene.setupAction()
        }

        // Orchestrate: narrate first, then auto-advance after remaining time
        advanceTask = Task {
            // 1. Wait for animations to settle
            try? await Task.sleep(for: .seconds(1.0))
            if Task.isCancelled { return }

            // 2. Speak narration and wait for it to finish
            let narrationStart = Date()
            if narrationEnabled {
                await speechEngine.speakAndWait("\(scene.title). \(scene.subtitle)")
            }
            if Task.isCancelled { return }

            // 3. Calculate remaining linger time after narration
            let narrationElapsed = Date().timeIntervalSince(narrationStart)
            let lingerTime = max(effectiveDuration - 1.0 - narrationElapsed, 3.0)

            // 4. Animate progress over the linger period
            let steps = 60
            let stepDuration = lingerTime / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(stepDuration))
                if Task.isCancelled { return }
                progress = Double(i) / Double(steps)
            }

            if !Task.isCancelled {
                next()
            }
        }
    }
}
