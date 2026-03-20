// BackgroundTasks.swift — Background tasks that consume actor streams and update AppState
// Bridges HamStationKit actors to the @Observable AppState for SwiftUI views.

import Foundation
import HamStationKit

/// Manages long-running tasks that bridge backend actors to AppState.
@MainActor
final class BackgroundTaskManager {
    private var rigStateTask: Task<Void, Never>?
    private var spotStreamTask: Task<Void, Never>?
    private var propagationSyncTask: Task<Void, Never>?
    private var qsoCountTask: Task<Void, Never>?

    private let appState: AppState
    private let services: ServiceContainer

    init(appState: AppState, services: ServiceContainer) {
        self.appState = appState
        self.services = services
    }

    // MARK: - Start / Stop

    func startAll() {
        startPropagationSync()
        startQSOCountRefresh()
    }

    func stopAll() {
        rigStateTask?.cancel()
        rigStateTask = nil
        spotStreamTask?.cancel()
        spotStreamTask = nil
        propagationSyncTask?.cancel()
        propagationSyncTask = nil
        qsoCountTask?.cancel()
        qsoCountTask = nil
    }

    // MARK: - Rig State Stream

    /// Starts consuming the rig's stateStream and updating appState.rigState.
    /// Call after connecting rig.
    func startRigStateStream() {
        rigStateTask?.cancel()
        guard let rig = services.rigConnection else { return }

        rigStateTask = Task { [weak self] in
            guard let self else { return }
            let stream = await rig.stateStream
            for await state in stream {
                guard !Task.isCancelled else { break }
                self.appState.rigState = state
            }
        }
    }

    func stopRigStateStream() {
        rigStateTask?.cancel()
        rigStateTask = nil
    }

    // MARK: - Spot Stream

    /// Starts consuming the cluster's spotStream and appending to appState.recentSpots.
    /// Call after connecting cluster.
    func startSpotStream() {
        spotStreamTask?.cancel()
        guard let cluster = services.clusterClient else { return }

        spotStreamTask = Task { [weak self] in
            guard let self else { return }
            let stream = await cluster.spotStream
            for await spot in stream {
                guard !Task.isCancelled else { break }
                let displaySpot = DisplaySpot(from: spot, status: .needed)
                // Prepend new spots; keep at most 200
                self.appState.recentSpots.insert(displaySpot, at: 0)
                if self.appState.recentSpots.count > 200 {
                    self.appState.recentSpots = Array(self.appState.recentSpots.prefix(200))
                }
            }
        }
    }

    func stopSpotStream() {
        spotStreamTask?.cancel()
        spotStreamTask = nil
    }

    // MARK: - Propagation Sync

    /// Syncs PropagationDashboard.solarData into appState.solarData periodically.
    func startPropagationSync() {
        propagationSyncTask?.cancel()
        services.propagationDashboard.startAutoRefresh(intervalMinutes: 15)

        propagationSyncTask = Task { [weak self] in
            guard let self else { return }
            // Poll the dashboard's solarData every 5 seconds
            while !Task.isCancelled {
                let data = self.services.propagationDashboard.solarData
                if data != self.appState.solarData {
                    self.appState.solarData = data
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // MARK: - QSO Count Refresh

    /// Periodically updates the qsosToday count from the database.
    func startQSOCountRefresh() {
        qsoCountTask?.cancel()

        qsoCountTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    let range = startOfDay...endOfDay

                    let qsos = try await self.services.database.fetchQSOs(
                        dateRange: range,
                        limit: 10000
                    )
                    self.appState.qsosToday = qsos.count

                    // Simple rate: QSOs in the last hour
                    let oneHourAgo = Date().addingTimeInterval(-3600)
                    let recentQSOs = qsos.filter { $0.datetimeOn >= oneHourAgo }
                    self.appState.qsoRate = recentQSOs.count
                } catch {
                    // Silently ignore database errors for background stats
                }

                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}
