// MainWindow.swift — Primary three-column layout
// NavigationSplitView: Sidebar | Content | Inspector

import SwiftUI
import HamStationKit

struct MainWindow: View {
    @Environment(AppState.self) var appState
    @State private var inspectorIsPresented = true

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
        .overlay(alignment: .bottom) { StatusBar() }
        .frame(minWidth: 1200, minHeight: 800)
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
        case .tools:
            ToolsView()
        }
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
}
