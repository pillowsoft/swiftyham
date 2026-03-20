// HamStationApp.swift — macOS app entry point
// Creates ServiceContainer and BackgroundTaskManager on launch.
// Passes AppState and ServiceContainer to all views via environment.

import SwiftUI
import HamStationKit

@main
struct HamStationApp: App {
    @State private var appState = AppState()
    @State private var services: ServiceContainer?
    @State private var backgroundTasks: BackgroundTaskManager?
    @State private var initError: String?

    var body: some Scene {
        WindowGroup("HamStation Pro", id: "main") {
            Group {
                if let error = initError {
                    errorView(error)
                } else if let services {
                    Group {
                        if appState.hasCompletedOnboarding {
                            MainWindow()
                        } else {
                            FirstRunWizard()
                        }
                    }
                    .environment(services)
                } else {
                    ProgressView("Starting up...")
                }
            }
            .environment(appState)
            .task {
                await bootstrap()
            }
        }
        .defaultSize(width: 1400, height: 900)
        .commands { HamStationCommands(appState: appState) }

        WindowGroup("Logbook", id: "logbook") {
            Group {
                if let services {
                    LogbookWindowView()
                        .environment(services)
                } else {
                    ProgressView()
                }
            }
            .environment(appState)
        }

        Settings {
            Group {
                if let services {
                    SettingsView()
                        .environment(services)
                } else {
                    ProgressView()
                }
            }
            .environment(appState)
        }

        MenuBarExtra("HamStation", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarView()
                .environment(appState)
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        // Load saved user preferences
        appState.loadFromDefaults()

        // Initialize services
        do {
            let container = try ServiceContainer()
            self.services = container

            let tasks = BackgroundTaskManager(appState: appState, services: container)
            self.backgroundTasks = tasks
            tasks.startAll()
        } catch {
            initError = "Failed to initialize database: \(error.localizedDescription)"
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Startup Error")
                .font(.title.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
