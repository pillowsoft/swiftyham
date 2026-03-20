// SidebarView.swift — Navigation sidebar
// Lists all main sections with SF Symbol icons. Compact macOS styling.

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            List(SidebarSection.allCases, selection: $state.selectedSection) { section in
                Label(section.label, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)

            Divider()

            // Demo button — always visible at bottom of sidebar
            Button {
                NotificationCenter.default.post(name: .startDemo, object: nil)
            } label: {
                Label("Start Demo", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: "FF6A00"))
            .padding(.vertical, 8)
            .padding(.horizontal, 4)

            // Extra padding so the button doesn't get clipped by the status bar overlay
            Spacer().frame(height: 28)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
    }
}

extension Notification.Name {
    static let startDemo = Notification.Name("startDemo")
}

#Preview {
    NavigationSplitView {
        SidebarView()
    } detail: {
        Text("Content")
    }
    .environment(AppState())
}
