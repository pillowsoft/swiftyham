import Foundation
import os

// MARK: - Error Types

/// Errors produced by ResilientClient.
public enum ResilientClientError: Error, Sendable {
    case timeout
    case rateLimited
    case allRetriesFailed([any Error])
    case networkUnavailable
}

// MARK: - Service Configuration

/// Per-service configuration for resilient network requests.
public struct ServiceConfig: Sendable {
    public var maxRetries: Int
    public var baseDelay: TimeInterval
    public var timeout: TimeInterval
    public var maxRequestsPerMinute: Int
    public var staleCacheOK: Bool

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        timeout: TimeInterval = 10.0,
        maxRequestsPerMinute: Int = 60,
        staleCacheOK: Bool = true
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.timeout = timeout
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.staleCacheOK = staleCacheOK
    }
}

// MARK: - Cache Entry

/// An in-memory cache entry holding the last successful response for a URL.
private struct CacheEntry: Sendable {
    let data: Data
    let response: URLResponse
    let timestamp: Date
}

// MARK: - Rate Limiter

/// A simple token-bucket rate limiter that tracks timestamps of recent requests per service.
private struct TokenBucket: Sendable {
    let maxRequestsPerMinute: Int
    var timestamps: [Date]

    init(maxRequestsPerMinute: Int) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.timestamps = []
    }

    /// Prunes timestamps older than 60 seconds.
    mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-60.0)
        timestamps.removeAll { $0 < cutoff }
    }

    /// Returns how long to wait before a token is available, or nil if a token is available now.
    mutating func waitDuration(now: Date) -> TimeInterval? {
        prune(now: now)
        if timestamps.count < maxRequestsPerMinute {
            return nil
        }
        // Need to wait until the oldest timestamp expires from the window
        guard let oldest = timestamps.first else { return nil }
        let availableAt = oldest.addingTimeInterval(60.0)
        let wait = availableAt.timeIntervalSince(now)
        return wait > 0 ? wait : nil
    }

    /// Records a request at the given time.
    mutating func record(now: Date) {
        timestamps.append(now)
    }
}

// MARK: - ResilientClient

/// A wrapper around URLSession that provides retry with exponential backoff,
/// per-service rate limiting, and stale-data caching for all external REST API calls.
public actor ResilientClient {
    private let session: URLSession
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "ResilientClient")

    /// In-memory stale-data cache keyed by URL string.
    private var cache: [String: CacheEntry] = [:]

    /// Per-service token buckets for rate limiting.
    private var rateLimiters: [String: TokenBucket] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetch data for a request with retry, rate limiting, and stale-data fallback.
    public func fetch(
        _ request: URLRequest,
        service: String,
        config: ServiceConfig = ServiceConfig()
    ) async throws -> (Data, URLResponse) {
        // Rate limiting: wait if bucket is empty
        try await waitForRateLimit(service: service, config: config)

        var collectedErrors: [any Error] = []

        for attempt in 0..<config.maxRetries {
            do {
                let (data, response) = try await performRequest(request, timeout: config.timeout)

                // Record successful request for rate limiting
                recordRequest(service: service, config: config)

                // Cache the successful response
                if let urlString = request.url?.absoluteString {
                    cache[urlString] = CacheEntry(
                        data: data,
                        response: response,
                        timestamp: Date()
                    )
                }

                return (data, response)
            } catch {
                collectedErrors.append(error)

                if attempt < config.maxRetries - 1 {
                    let delay = config.baseDelay * pow(2.0, Double(attempt))
                    logger.warning(
                        "Request failed (attempt \(attempt + 1)/\(config.maxRetries)) for \(service): \(error.localizedDescription). Retrying in \(delay)s."
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries failed — try stale cache
        if config.staleCacheOK, let urlString = request.url?.absoluteString, let cached = cache[urlString] {
            logger.warning("All retries failed for \(service). Returning stale cached response.")
            return (cached.data, cached.response)
        }

        throw ResilientClientError.allRetriesFailed(collectedErrors)
    }

    /// Fetch and decode JSON for a request with retry, rate limiting, and stale-data fallback.
    public func fetchJSON<T: Decodable & Sendable>(
        _ request: URLRequest,
        service: String,
        config: ServiceConfig = ServiceConfig(),
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, _) = try await fetch(request, service: service, config: config)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private Helpers

    /// Perform a single URLSession request with a timeout.
    private func performRequest(_ request: URLRequest, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        var timedRequest = request
        timedRequest.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: timedRequest)
            return (data, response)
        } catch let error as URLError where error.code == .timedOut {
            throw ResilientClientError.timeout
        } catch let error as URLError where error.code == .notConnectedToInternet
            || error.code == .networkConnectionLost
        {
            throw ResilientClientError.networkUnavailable
        }
    }

    /// Wait until a rate limit token is available for the given service.
    private func waitForRateLimit(service: String, config: ServiceConfig) async throws {
        let now = Date()

        if rateLimiters[service] == nil {
            rateLimiters[service] = TokenBucket(maxRequestsPerMinute: config.maxRequestsPerMinute)
        }

        if let wait = rateLimiters[service]?.waitDuration(now: now) {
            logger.warning("Rate limited for \(service). Waiting \(wait)s.")
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }

    /// Record that a request was made for rate limiting purposes.
    private func recordRequest(service: String, config: ServiceConfig) {
        let now = Date()
        if rateLimiters[service] == nil {
            rateLimiters[service] = TokenBucket(maxRequestsPerMinute: config.maxRequestsPerMinute)
        }
        rateLimiters[service]?.record(now: now)
    }
}
