// DemoMockData.swift — Mock data generators for demo scenes
// Each function populates AppState with realistic-looking data that appears live.

import SwiftUI
import HamStationKit

@MainActor
struct DemoMockData {

    // MARK: - DX Cluster Spots (arrive one at a time)

    static func feedSpots(to appState: AppState) async {
        let spots: [(call: String, freq: Double, spotter: String, comment: String, status: DisplaySpot.SpotStatus)] = [
            ("JA1NRH",  14_074.0, "W3LPL",  "FT8 -10 dB",           .needed),
            ("VK2RZA",  14_074.0, "KM3T",   "FT8 -14 dB",           .worked),
            ("ZS6BKW",  21_074.0, "N2IC",   "FT8 -08 dB",           .confirmed),
            ("VP8LP",    7_012.0, "OH2BH",  "CW 599 UP 2",          .needed),
            ("3Y0J",    14_025.0, "W1AW",   "CW 559 HUGE PILEUP",   .needed),
            ("A71A",    14_200.0, "EA8BVP", "SSB 59 CONTEST",        .worked),
            ("KH6LC",   21_295.0, "K1TTT",  "SSB 59",               .confirmed),
            ("TF3ML",    7_074.0, "DJ5AV",  "FT8 -11 dB",           .needed),
            ("PY2SEX",  28_074.0, "W4DR",   "FT8 -06 dB 10m OPEN!", .needed),
            ("SV9CVY",  18_100.0, "IK4WMH", "SSB 57 17m",           .worked),
        ]

        appState.clusterConnectionState = .connected
        for spot in spots {
            try? await Task.sleep(for: .seconds(0.8))
            if Task.isCancelled { return }
            let dxSpot = HamStationKit.DXSpot(
                spotter: spot.spotter,
                dxCallsign: spot.call,
                frequency: spot.freq,
                comment: spot.comment,
                timestamp: Date()
            )
            let displaySpot = DisplaySpot(from: dxSpot, status: spot.status)
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.recentSpots.insert(displaySpot, at: 0)
            }
        }
    }

    // MARK: - Band Map Spots (populate a spread across 20m)

    static func feedBandMapSpots(to appState: AppState) async {
        let bandSpots: [(call: String, freq: Double, comment: String, status: DisplaySpot.SpotStatus)] = [
            ("W3LPL",   14_002.0, "CW 599",          .confirmed),
            ("K1TTT",   14_025.0, "CW 599",          .confirmed),
            ("OH2BH",   14_040.0, "CW 579",          .worked),
            ("JA1NRH",  14_074.0, "FT8 -10 dB",      .needed),
            ("VK2RZA",  14_074.5, "FT8 -14 dB",      .worked),
            ("3Y0J",    14_025.0, "CW 559 UP 2",      .needed),
            ("LU1FAM",  14_195.0, "SSB 59",           .confirmed),
            ("A71A",    14_200.0, "SSB 59+20",         .worked),
            ("ZS6BKW",  14_250.0, "SSB 57",           .needed),
            ("UA3TCJ",  14_180.0, "SSB 59",           .worked),
        ]

        for spot in bandSpots {
            try? await Task.sleep(for: .seconds(0.4))
            if Task.isCancelled { return }
            let dxSpot = HamStationKit.DXSpot(
                spotter: "W1AW",
                dxCallsign: spot.call,
                frequency: spot.freq,
                comment: spot.comment,
                timestamp: Date()
            )
            let displaySpot = DisplaySpot(from: dxSpot, status: spot.status)
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.recentSpots.insert(displaySpot, at: 0)
            }
        }
    }

    // MARK: - Rig Tuning Simulation

    static func simulateRigTuning(to appState: AppState) async {
        let frequencies: [(Double, OperatingMode)] = [
            (14_074_000, .ft8),
            (14_025_000, .cw),
            (14_200_000, .usb),
            ( 7_074_000, .ft8),
            (21_074_000, .ft8),
        ]

        appState.rigConnectionState = .connected
        for (freq, mode) in frequencies {
            try? await Task.sleep(for: .seconds(1.5))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.rigState = RigState(
                    frequency: freq,
                    mode: mode,
                    pttActive: false,
                    signalStrength: Int.random(in: 3...9)
                )
            }
        }
    }

    // MARK: - FT8 Decodes

    static func simulateFT8Decodes(to appState: AppState) async {
        let decodes = [
            "0.3  CQ JA1ABC PM95           -10",
            "1.2  CQ VK2RZA QF56           -14",
            "2.1  W1AW JA1ABC PM95          -08",
            "3.0  JA1ABC W1AW FN31         R-10",
            "3.8  CQ DX OH2BH KP20          -05",
            "4.7  CQ 5B4ALX KM64            -12",
            "5.5  W1AW JA1ABC RR73            00",
            "6.4  CQ TEST A71A LL55          +03",
            "7.2  CQ NA K1TTT FN31           -07",
            "8.1  CQ VE3NEA FN03             -09",
        ]

        appState.demoFT8Decodes = []
        for decode in decodes {
            try? await Task.sleep(for: .seconds(1.0))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.demoFT8Decodes.append(decode)
            }
        }
    }

    // MARK: - AI Chat Simulation (word by word)

    static func simulateAIChat(to appState: AppState) async {
        let question = "Where should I look for ZL8 tonight?"
        let answer = "ZL8 (Kermadec Islands) has been spotted on 40m CW at 7.005 MHz recently. With your location in FN31 and current conditions (SFI 145, K=2), I'd recommend monitoring 7.005\u{2013}7.015 MHz between 0300\u{2013}0500 UTC. That's your best grey line window to the South Pacific. The pileup will be massive \u{2014} try calling 1\u{2013}2 kHz up from his listening frequency."

        appState.demoChatMessages = []

        // User message appears instantly
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.demoChatMessages.append(DemoChatMessage(role: "user", text: question))
        }

        try? await Task.sleep(for: .seconds(0.8))
        if Task.isCancelled { return }

        // AI response appears word by word
        let words = answer.split(separator: " ")
        var partialText = ""
        appState.demoChatMessages.append(DemoChatMessage(role: "assistant", text: ""))

        for (i, word) in words.enumerated() {
            try? await Task.sleep(for: .seconds(0.05))
            if Task.isCancelled { return }
            if i > 0 { partialText += " " }
            partialText += word
            appState.demoChatMessages[1] = DemoChatMessage(role: "assistant", text: partialText)
        }
    }

    // MARK: - Propagation Data

    static func setupPropagation(to appState: AppState) {
        appState.solarData = SolarData(
            solarFluxIndex: 145,
            aIndex: 8,
            kIndex: 2,
            kIndexTrend: .stable,
            xrayFlux: "B5.2",
            protonFlux: 0.5,
            updatedAt: Date()
        )
    }
}
