// MainWindow.swift — Primary three-column layout
// NavigationSplitView: Sidebar | Content | Inspector

import SwiftUI
import HamStationKit

struct MainWindow: View {
    @Environment(AppState.self) var appState
    @State private var inspectorIsPresented = true
    @State private var demoEngine: DemoEngine?

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView()
        } detail: {
            contentView
                .inspector(isPresented: $inspectorIsPresented) {
                    InspectorView()
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
        }
        .toolbar { HamStationToolbar() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                RecordingControls()
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    if demoEngine?.isRunning == true {
                        demoEngine?.stop()
                        demoEngine = nil
                    } else {
                        startDemo()
                    }
                } label: {
                    Label(
                        demoEngine?.isRunning == true ? "Stop Demo" : "Demo",
                        systemImage: demoEngine?.isRunning == true ? "stop.fill" : "play.fill"
                    )
                }
                .tint(Color(hex: "FF6A00"))
            }
        }
        .overlay(alignment: .bottom) { StatusBar() }
        .overlay {
            if let demoEngine, demoEngine.isRunning {
                DemoOverlay(engine: demoEngine)
            }
        }
        .frame(minWidth: 1400, minHeight: 800)
        .onAppear {
            if appState.isDemoMode && demoEngine == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startDemo()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startDemo)) { _ in
            if demoEngine?.isRunning != true {
                startDemo()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedSection {
        case .logbook:
            LogbookView()
        case .dxCluster:
            DXClusterView()
        case .bandMap:
            BandMapView()
        case .globe:
            GlobeContainerView()
        case .awards:
            AwardsView()
        case .sotaPota:
            SOTAPOTAView()
        case .propagation:
            PropagationView()
        case .repeaters:
            RepeaterView()
        case .emcomm:
            EmCommView()
        case .antennaTools:
            AntennaView()
        case .cwTraining:
            CWTrainingView()
        case .satellite:
            SatelliteView()
        case .ft8:
            FT8View()
        case .aiAssistant:
            AIAssistantView()
        case .tools:
            ToolsView()
        }
    }

    private func startDemo() {
        let engine = DemoEngine(appState: appState)
        demoEngine = engine
        engine.start()
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
}
