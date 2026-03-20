// SidebarView.swift — Navigation sidebar
// Lists all main sections with SF Symbol icons. Compact macOS styling.

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState

        List(SidebarSection.allCases, selection: $state.selectedSection) { section in
            Label(section.label, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
    } detail: {
        Text("Content")
    }
    .environment(AppState())
}
