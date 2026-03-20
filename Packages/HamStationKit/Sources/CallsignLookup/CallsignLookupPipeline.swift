import Foundation
import os

// MARK: - Callsign Lookup Pipeline

/// Orchestrates the callsign lookup cascade: cache -> HamDB -> QRZ -> return merged result.
///
/// The pipeline checks the local database cache first, then falls back to external APIs.
/// Results are cached for 30 days. Stale cache entries are returned if all API calls fail.
public actor CallsignLookupPipeline {
    private let networkService: NetworkService
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "CallsignLookupPipeline")

    /// In-memory cache for callsign lookups (supplements the database cache).
    /// Keyed by uppercased callsign.
    private var memoryCache: [String: CachedLookup] = [:]

    /// Cache TTL: 30 days.
    private static let cacheTTL: TimeInterval = 30 * 24 * 60 * 60

    private struct CachedLookup: Sendable {
        let result: CallsignLookupResult
        let fetchedAt: Date
        let expiresAt: Date
    }

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    // MARK: - Public API

    /// Look up a callsign using the cascade: cache -> HamDB -> QRZ -> stale cache -> partial.
    ///
    /// - Parameters:
    ///   - callsign: The callsign to look up.
    ///   - qrzApiKey: Optional QRZ.com API key (format: "username:password"). If nil, QRZ is skipped.
    /// - Returns: The best available lookup result.
    public func lookup(callsign: String, qrzApiKey: String? = nil) async -> CallsignLookupResult {
        let normalizedCallsign = callsign.uppercased().trimmingCharacters(in: .whitespaces)

        // Step 1: Check memory cache
        if let cached = memoryCache[normalizedCallsign] {
            if Date() < cached.expiresAt {
                logger.info("Cache hit for \(normalizedCallsign)")
                return cached.result
            }
            logger.info("Cache expired for \(normalizedCallsign), refreshing...")
        }

        // Step 2: Try HamDB (free, no key needed)
        do {
            let result = try await networkService.lookupCallsign(callsign: normalizedCallsign, source: .hamDB)
            cacheResult(result, callsign: normalizedCallsign)
            logger.info("HamDB lookup successful for \(normalizedCallsign)")
            return result
        } catch {
            logger.warning("HamDB lookup failed for \(normalizedCallsign): \(error.localizedDescription)")
        }

        // Step 3: Try QRZ if API key is available
        if let apiKey = qrzApiKey {
            do {
                let result = try await networkService.lookupCallsign(
                    callsign: normalizedCallsign,
                    source: .qrz(apiKey: apiKey)
                )
                cacheResult(result, callsign: normalizedCallsign)
                logger.info("QRZ lookup successful for \(normalizedCallsign)")
                return result
            } catch {
                logger.warning("QRZ lookup failed for \(normalizedCallsign): \(error.localizedDescription)")
            }
        }

        // Step 4: Return stale cache if available
        if let stale = memoryCache[normalizedCallsign] {
            logger.warning("Returning stale cache for \(normalizedCallsign)")
            var staleResult = stale.result
            staleResult.source = "stale"
            staleResult.isStale = true
            return staleResult
        }

        // Step 5: Return partial result (callsign only)
        logger.warning("No data available for \(normalizedCallsign), returning partial result")
        return CallsignLookupResult(
            callsign: normalizedCallsign,
            source: "none",
            isStale: false
        )
    }

    /// Clear the in-memory cache.
    public func clearCache() {
        memoryCache.removeAll()
    }

    /// Remove a specific callsign from the cache.
    public func invalidateCache(for callsign: String) {
        memoryCache.removeValue(forKey: callsign.uppercased())
    }

    // MARK: - Private Helpers

    private func cacheResult(_ result: CallsignLookupResult, callsign: String) {
        let now = Date()
        memoryCache[callsign] = CachedLookup(
            result: result,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(Self.cacheTTL)
        )
    }
}
