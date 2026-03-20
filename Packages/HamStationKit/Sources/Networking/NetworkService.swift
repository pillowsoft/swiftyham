import Foundation
import os

// MARK: - Callsign Lookup Types

/// Source for callsign lookup queries.
public enum CallsignSource: Sendable {
    case hamDB
    case qrz(apiKey: String)
}

/// Result of a callsign lookup from an external service.
public struct CallsignLookupResult: Sendable, Equatable {
    public var callsign: String
    public var name: String?
    public var qth: String?
    public var grid: String?
    public var country: String?
    public var state: String?
    public var county: String?
    public var email: String?
    public var lotwMember: Bool?
    public var source: String
    public var isStale: Bool

    public init(
        callsign: String,
        name: String? = nil,
        qth: String? = nil,
        grid: String? = nil,
        country: String? = nil,
        state: String? = nil,
        county: String? = nil,
        email: String? = nil,
        lotwMember: Bool? = nil,
        source: String = "",
        isStale: Bool = false
    ) {
        self.callsign = callsign
        self.name = name
        self.qth = qth
        self.grid = grid
        self.country = country
        self.state = state
        self.county = county
        self.email = email
        self.lotwMember = lotwMember
        self.source = source
        self.isStale = isStale
    }
}

// MARK: - Solar Data Types

// SolarData is defined in Propagation/SolarData.swift

// MARK: - Network Service Errors

/// Errors specific to NetworkService operations.
public enum NetworkServiceError: Error, Sendable {
    case invalidResponse
    case parseError(String)
    case authenticationFailed
    case callsignNotFound(String)
    case missingAPIKey
}

// MARK: - HamDB JSON Response Models

/// HamDB API response wrapper.
private struct HamDBResponse: Decodable, Sendable {
    let hamdb: HamDBResult
}

private struct HamDBResult: Decodable, Sendable {
    let callsign: HamDBCallsign?
    let messages: HamDBMessages?
}

private struct HamDBCallsign: Decodable, Sendable {
    let call: String?
    let fname: String?
    let name: String?
    let addr1: String?
    let addr2: String?
    let state: String?
    let zip: String?
    let country: String?
    let grid: String?
    let `class`: String?
}

private struct HamDBMessages: Decodable, Sendable {
    let status: String?
}

// MARK: - NetworkService

/// Central actor for all external API communication.
/// Owns a ResilientClient instance and provides typed API methods for each external service.
public actor NetworkService {
    private let client: ResilientClient
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "NetworkService")

    /// QRZ session key, obtained after authentication.
    private var qrzSessionKey: String?

    public init(client: ResilientClient? = nil) {
        self.client = client ?? ResilientClient()
    }

    /// Initialize with a specific URLSession (useful for testing).
    public init(session: URLSession) {
        self.client = ResilientClient(session: session)
    }

    // MARK: - Callsign Lookup

    /// Look up a callsign using the specified source.
    public func lookupCallsign(callsign: String, source: CallsignSource) async throws -> CallsignLookupResult {
        switch source {
        case .hamDB:
            return try await lookupHamDB(callsign: callsign)
        case .qrz(let apiKey):
            return try await lookupQRZ(callsign: callsign, apiKey: apiKey)
        }
    }

    // MARK: - HamDB Lookup

    private func lookupHamDB(callsign: String) async throws -> CallsignLookupResult {
        let sanitized = callsign.uppercased().trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "https://www.hamdb.org/api/v1/\(sanitized)/json/hamstationpro") else {
            throw NetworkServiceError.invalidResponse
        }

        let request = URLRequest(url: url)
        let config = ServiceConfig(
            maxRetries: 3,
            baseDelay: 1.0,
            timeout: 10.0,
            maxRequestsPerMinute: 30,
            staleCacheOK: true
        )

        let response: HamDBResponse = try await client.fetchJSON(request, service: "hamdb", config: config)

        guard let cs = response.hamdb.callsign else {
            if response.hamdb.messages?.status == "NOT_FOUND" {
                throw NetworkServiceError.callsignNotFound(sanitized)
            }
            throw NetworkServiceError.invalidResponse
        }

        // Build full name from first + last
        var fullName: String?
        if let fname = cs.fname, let lname = cs.name {
            let combined = [fname, lname].filter { !$0.isEmpty }.joined(separator: " ")
            fullName = combined.isEmpty ? nil : combined
        }

        // Build QTH from addr2 (city), state
        var qth: String?
        let parts = [cs.addr2, cs.state].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty {
            qth = parts.joined(separator: ", ")
        }

        return CallsignLookupResult(
            callsign: sanitized,
            name: fullName,
            qth: qth,
            grid: cs.grid,
            country: cs.country,
            state: cs.state,
            source: "hamdb"
        )
    }

    // MARK: - QRZ Lookup

    private func lookupQRZ(callsign: String, apiKey: String) async throws -> CallsignLookupResult {
        // Authenticate if we don't have a session key
        if qrzSessionKey == nil {
            try await authenticateQRZ(apiKey: apiKey)
        }

        guard let sessionKey = qrzSessionKey else {
            throw NetworkServiceError.authenticationFailed
        }

        let sanitized = callsign.uppercased().trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "https://xmldata.qrz.com/xml/current/?s=\(sessionKey)&callsign=\(sanitized)") else {
            throw NetworkServiceError.invalidResponse
        }

        let request = URLRequest(url: url)
        let config = ServiceConfig(
            maxRetries: 2,
            baseDelay: 1.0,
            timeout: 10.0,
            maxRequestsPerMinute: 20,
            staleCacheOK: true
        )

        let (data, _) = try await client.fetch(request, service: "qrz", config: config)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NetworkServiceError.invalidResponse
        }

        // Check for session errors (need re-auth)
        if xmlString.contains("<Error>Session Timeout") || xmlString.contains("<Error>Invalid session key") {
            qrzSessionKey = nil
            try await authenticateQRZ(apiKey: apiKey)
            // Retry once with new session
            return try await lookupQRZ(callsign: callsign, apiKey: apiKey)
        }

        return parseQRZResponse(xmlString: xmlString, callsign: sanitized)
    }

    private func authenticateQRZ(apiKey: String) async throws {
        // QRZ uses username;password format in the API key for simplicity
        // The apiKey is expected to be in the format "username:password"
        let components = apiKey.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else {
            throw NetworkServiceError.missingAPIKey
        }

        let username = String(components[0])
        let password = String(components[1])

        guard let url = URL(
            string: "https://xmldata.qrz.com/xml/current/?username=\(username)&password=\(password)"
        ) else {
            throw NetworkServiceError.invalidResponse
        }

        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 2, timeout: 10.0, maxRequestsPerMinute: 10)

        let (data, _) = try await client.fetch(request, service: "qrz-auth", config: config)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NetworkServiceError.invalidResponse
        }

        // Extract session key from XML: <Key>...</Key>
        guard let key = extractXMLValue(from: xmlString, tag: "Key") else {
            if xmlString.contains("<Error>") {
                let errorMsg = extractXMLValue(from: xmlString, tag: "Error") ?? "Unknown error"
                logger.error("QRZ authentication failed: \(errorMsg)")
                throw NetworkServiceError.authenticationFailed
            }
            throw NetworkServiceError.authenticationFailed
        }

        qrzSessionKey = key
        logger.info("QRZ authentication successful.")
    }

    private func parseQRZResponse(xmlString: String, callsign: String) -> CallsignLookupResult {
        let name: String? = {
            let fname = extractXMLValue(from: xmlString, tag: "fname")
            let lname = extractXMLValue(from: xmlString, tag: "name")
            let parts = [fname, lname].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        let qth: String? = {
            let addr2 = extractXMLValue(from: xmlString, tag: "addr2")
            let state = extractXMLValue(from: xmlString, tag: "state")
            let parts = [addr2, state].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }()

        return CallsignLookupResult(
            callsign: callsign,
            name: name,
            qth: qth,
            grid: extractXMLValue(from: xmlString, tag: "grid"),
            country: extractXMLValue(from: xmlString, tag: "country"),
            state: extractXMLValue(from: xmlString, tag: "state"),
            county: extractXMLValue(from: xmlString, tag: "county"),
            email: extractXMLValue(from: xmlString, tag: "email"),
            lotwMember: extractXMLValue(from: xmlString, tag: "lotw").map { $0 == "1" },
            source: "qrz"
        )
    }

    // MARK: - Solar Data

    /// Fetch current solar weather data from NOAA SWPC.
    public func fetchSolarData() async throws -> SolarData {
        let config = ServiceConfig(
            maxRetries: 3,
            baseDelay: 1.0,
            timeout: 15.0,
            maxRequestsPerMinute: 10,
            staleCacheOK: true
        )

        // Fetch SFI
        let sfi = try await fetchSolarFluxIndex(config: config)

        // Fetch K-index (which also provides A-index)
        let (kIndex, aIndex) = try await fetchKIndex(config: config)

        return SolarData(
            solarFluxIndex: sfi,
            aIndex: aIndex,
            kIndex: kIndex,
            xrayFlux: "", // X-ray flux requires separate SWPC endpoint
            updatedAt: Date()
        )
    }

    private func fetchSolarFluxIndex(config: ServiceConfig) async throws -> Int {
        guard let url = URL(string: "https://services.swpc.noaa.gov/json/f107_cm_flux.json") else {
            throw NetworkServiceError.invalidResponse
        }

        let request = URLRequest(url: url)
        let (data, _) = try await client.fetch(request, service: "noaa-sfi", config: config)

        // Response is an array of objects; the last entry is the most recent
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let latest = entries.last,
              let fluxValue = latest["flux"] as? Double
        else {
            throw NetworkServiceError.parseError("Could not parse SFI response")
        }

        return Int(fluxValue)
    }

    private func fetchKIndex(config: ServiceConfig) async throws -> (kIndex: Int, aIndex: Int) {
        guard let url = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json") else {
            throw NetworkServiceError.invalidResponse
        }

        let request = URLRequest(url: url)
        let (data, _) = try await client.fetch(request, service: "noaa-kindex", config: config)

        // Response is an array of arrays; first row is header, last row is most recent
        // Format: [time_tag, Kp, Kp_fraction, a_running, station_count]
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
              entries.count >= 2,
              let lastEntry = entries.last,
              lastEntry.count >= 4
        else {
            throw NetworkServiceError.parseError("Could not parse K-index response")
        }

        let kIndex: Int
        if let kpString = lastEntry[1] as? String, let kp = Double(kpString) {
            kIndex = Int(kp)
        } else if let kp = lastEntry[1] as? Double {
            kIndex = Int(kp)
        } else {
            kIndex = 0
        }

        let aIndex: Int
        if let aString = lastEntry[3] as? String, let a = Double(aString) {
            aIndex = Int(a)
        } else if let a = lastEntry[3] as? Double {
            aIndex = Int(a)
        } else {
            aIndex = 0
        }

        return (kIndex, aIndex)
    }

    // MARK: - XML Helpers

    /// Simple XML value extraction for known single-value tags.
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let openRange = xml.range(of: openTag),
              let closeRange = xml.range(of: closeTag, range: openRange.upperBound..<xml.endIndex)
        else {
            return nil
        }
        let value = String(xml[openRange.upperBound..<closeRange.lowerBound])
        return value.isEmpty ? nil : value
    }
}
