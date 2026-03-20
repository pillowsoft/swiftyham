// DemoScript.swift — The scripted demo sequence
// Each scene navigates to a sidebar section, populates mock data, and shows narration.

import SwiftUI
import HamStationKit

struct DemoScene: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let section: SidebarSection
    let duration: TimeInterval
    let setupAction: @Sendable @MainActor () async -> Void
}

struct DemoScript {
    @MainActor
    static func scenes(appState: AppState) -> [DemoScene] {
        [
            // Scene 1: Welcome
            DemoScene(
                id: 1,
                title: "Welcome to HamStation Pro",
                subtitle: "The first AI-native amateur radio suite for Mac",
                section: .logbook,
                duration: 6,
                setupAction: {
                    appState.operatorCallsign = "W1AW"
                    appState.gridSquare = "FN31pr"
                    appState.isDemoMode = true
                }
            ),

            // Scene 2: Logbook
            DemoScene(
                id: 2,
                title: "Your Complete Logbook",
                subtitle: "Import from any logger. Search, filter, sort 100,000+ QSOs instantly.",
                section: .logbook,
                duration: 8,
                setupAction: {
                    appState.qsosToday = 47
                    appState.qsoRate = 12
                }
            ),

            // Scene 3: DX Cluster — Spots Arriving
            DemoScene(
                id: 3,
                title: "Live DX Spots",
                subtitle: "Connect to worldwide DX clusters. Spots appear in real time.",
                section: .dxCluster,
                duration: 10,
                setupAction: {
                    await DemoMockData.feedSpots(to: appState)
                }
            ),

            // Scene 4: Band Map
            DemoScene(
                id: 4,
                title: "Visual Band Map",
                subtitle: "See every spot on the band. Click to tune your radio instantly.",
                section: .bandMap,
                duration: 8,
                setupAction: {
                    await DemoMockData.feedBandMapSpots(to: appState)
                }
            ),

            // Scene 5: Globe
            DemoScene(
                id: 5,
                title: "Your Station on the World",
                subtitle: "Watch QSO paths arc across the globe. See the grey line in real time.",
                section: .globe,
                duration: 12,
                setupAction: {
                    // Globe view uses existing spots for arcs
                    // Just ensure spots are present
                }
            ),

            // Scene 6: Rig Control
            DemoScene(
                id: 6,
                title: "Rig Control",
                subtitle: "Connected to 400+ radios via rigctld. Click a spot, your radio tunes.",
                section: .bandMap,
                duration: 8,
                setupAction: {
                    await DemoMockData.simulateRigTuning(to: appState)
                }
            ),

            // Scene 7: FT8 Digital Mode
            DemoScene(
                id: 7,
                title: "FT8 \u{2014} Decode the World",
                subtitle: "Built-in FT8 decoder. See stations calling from around the world.",
                section: .tools,
                duration: 10,
                setupAction: {
                    await DemoMockData.simulateFT8Decodes(to: appState)
                }
            ),

            // Scene 8: Awards Tracking
            DemoScene(
                id: 8,
                title: "Chase Your Awards",
                subtitle: "DXCC, WAS, WAZ \u{2014} see your progress at a glance. Know what you need.",
                section: .awards,
                duration: 8,
                setupAction: {
                    // Awards view reads from database; demo just navigates there
                }
            ),

            // Scene 9: Propagation
            DemoScene(
                id: 9,
                title: "Live Propagation",
                subtitle: "Solar conditions, band forecasts, know when and where to operate.",
                section: .propagation,
                duration: 8,
                setupAction: {
                    DemoMockData.setupPropagation(to: appState)
                }
            ),

            // Scene 10: AI Assistant
            DemoScene(
                id: 10,
                title: "Your AI Radio Partner",
                subtitle: "Ask anything. It knows your station, your log, and the bands.",
                section: .tools,
                duration: 12,
                setupAction: {
                    await DemoMockData.simulateAIChat(to: appState)
                }
            ),

            // Scene 11: SOTA / POTA
            DemoScene(
                id: 11,
                title: "SOTA & POTA",
                subtitle: "Find summits and parks. Log activations. Track your progress.",
                section: .sotaPota,
                duration: 8,
                setupAction: { }
            ),

            // Scene 12: EmComm
            DemoScene(
                id: 12,
                title: "Emergency Communications",
                subtitle: "ICS forms. Net logging. Be ready when it matters.",
                section: .emcomm,
                duration: 6,
                setupAction: { }
            ),

            // Scene 13: CW Training
            DemoScene(
                id: 13,
                title: "Learn CW",
                subtitle: "Koch method trainer. Practice at your pace. Track your progress.",
                section: .cwTraining,
                duration: 6,
                setupAction: { }
            ),

            // Scene 14: Antenna Tools
            DemoScene(
                id: 14,
                title: "Antenna Tools",
                subtitle: "Dipole calculator, SWR analyzer, azimuthal maps \u{2014} all built in.",
                section: .antennaTools,
                duration: 6,
                setupAction: { }
            ),

            // Scene 15: Finale
            DemoScene(
                id: 15,
                title: "HamStation Pro",
                subtitle: "One app. Every mode. Every band. Every award. Built for Mac.",
                section: .globe,
                duration: 10,
                setupAction: {
                    // Return to globe with all data visible for the big finish
                }
            ),
        ]
    }
}
