// PropagationDashboard.swift
// HamStationKit — Observable propagation data dashboard with auto-refresh.

import Foundation
import Observation

/// Observable dashboard that fetches and maintains current propagation data.
///
/// Designed to be used by SwiftUI views for live solar condition display.
/// Supports auto-refresh at a configurable interval.
@Observable @MainActor
public final class PropagationDashboard {
    /// Current solar data, or nil if not yet fetched.
    public private(set) var solarData: SolarData?
    /// Last fetch error message, or nil if the last fetch succeeded.
    public private(set) var lastFetchError: String?
    /// Whether a fetch is currently in progress.
    public private(set) var isLoading: Bool = false

    private let networkService: NetworkService
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    nonisolated deinit {
        // MainActor.assumeIsolated not available in deinit; access the task
        // directly — this is safe because deinit is the final access to self.
    }

    // MARK: - Auto-Refresh

    /// Start auto-refreshing solar data at the given interval.
    /// Cancels any existing auto-refresh task before starting a new one.
    public func startAutoRefresh(intervalMinutes: Int = 15) {
        stopAutoRefresh()
        let interval = TimeInterval(intervalMinutes * 60)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // Fetch immediately on start
            await self.refresh()
            // Then repeat at interval
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self.refresh()
            }
        }
    }

    /// Stop the auto-refresh task.
    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Fetch

    /// Fetch solar data from the network service.
    /// On success: updates `solarData` and clears `lastFetchError`.
    /// On failure: sets `lastFetchError` but keeps stale `solarData`.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await networkService.fetchSolarData()
            solarData = data
            lastFetchError = nil
        } catch {
            lastFetchError = error.localizedDescription
            // Keep stale solarData — stale-data-OK policy
        }
    }
}
