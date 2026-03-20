// QRZLogbookClient.swift
// HamStationKit — Log Submission Clients
//
// QRZ Logbook API client for submitting QSO records.

import Foundation
import os

// MARK: - Types

/// Status information returned by the QRZ Logbook API.
public struct QRZLogbookStatus: Sendable {
    public let callsign: String
    public let count: Int
    public let isValid: Bool

    public init(callsign: String, count: Int, isValid: Bool) {
        self.callsign = callsign
        self.count = count
        self.isValid = isValid
    }
}

/// Errors specific to QRZ Logbook operations.
public enum QRZLogbookError: Error, Sendable {
    case invalidAPIKey
    case submissionFailed(String)
    case invalidResponse
}

// MARK: - QRZLogbookClient

/// Submits QSO records to the QRZ Logbook API at `https://logbook.qrz.com/api`.
public actor QRZLogbookClient {
    private let client: ResilientClient
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "QRZLogbook")

    private static let baseURL = "https://logbook.qrz.com/api"
    private static let serviceConfig = ServiceConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        timeout: 15.0,
        maxRequestsPerMinute: 30,
        staleCacheOK: false
    )

    public init(client: ResilientClient? = nil) {
        self.client = client ?? ResilientClient()
    }

    // MARK: - Submit QSO

    /// Submits a single QSO to the QRZ Logbook.
    ///
    /// - Parameters:
    ///   - qso: The QSO record to submit.
    ///   - apiKey: The QRZ Logbook API key.
    /// - Throws: `QRZLogbookError` if the submission fails.
    public func submit(qso: QSO, apiKey: String) async throws {
        let adifRecord = ADIFConverter.adifRecord(from: qso)
        let adifString = ADIFExporter.export(
            records: [adifRecord],
            options: .init(includeHeader: false)
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "ACTION", value: "INSERT"),
            URLQueryItem(name: "ADIF", value: adifString),
        ]

        var request = URLRequest(url: Self.baseURL.asURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await client.fetch(
            request,
            service: "qrz-logbook",
            config: Self.serviceConfig
        )

        let responseString = String(data: data, encoding: .utf8) ?? ""
        logger.debug("QRZ Logbook response: \(responseString)")

        try parseResponse(responseString)
    }

    // MARK: - Fetch Status

    /// Verifies the API key and retrieves logbook status.
    ///
    /// - Parameter apiKey: The QRZ Logbook API key.
    /// - Returns: A `QRZLogbookStatus` with account info.
    /// - Throws: `QRZLogbookError` if the key is invalid or the request fails.
    public func fetchStatus(apiKey: String) async throws -> QRZLogbookStatus {
        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "ACTION", value: "STATUS"),
        ]

        var request = URLRequest(url: Self.baseURL.asURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await client.fetch(
            request,
            service: "qrz-logbook",
            config: Self.serviceConfig
        )

        let responseString = String(data: data, encoding: .utf8) ?? ""
        logger.debug("QRZ Logbook status response: \(responseString)")

        return try parseStatusResponse(responseString)
    }

    // MARK: - Response Parsing

    /// Parses the QRZ Logbook `&`-delimited response for INSERT actions.
    private func parseResponse(_ response: String) throws {
        let fields = parseQRZFields(response)

        guard let result = fields["RESULT"] else {
            throw QRZLogbookError.invalidResponse
        }

        if result == "OK" {
            logger.info("QSO submitted to QRZ Logbook successfully.")
            return
        }

        let reason = fields["REASON"] ?? "Unknown error"
        logger.error("QRZ Logbook submission failed: \(reason)")
        throw QRZLogbookError.submissionFailed(reason)
    }

    /// Parses the QRZ Logbook response for STATUS actions.
    private func parseStatusResponse(_ response: String) throws -> QRZLogbookStatus {
        let fields = parseQRZFields(response)

        guard let result = fields["RESULT"] else {
            throw QRZLogbookError.invalidResponse
        }

        if result == "FAIL" {
            let reason = fields["REASON"] ?? "Unknown error"
            if reason.lowercased().contains("invalid api key") || reason.lowercased().contains("auth") {
                throw QRZLogbookError.invalidAPIKey
            }
            throw QRZLogbookError.submissionFailed(reason)
        }

        let callsign = fields["CALLSIGN"] ?? ""
        let count = Int(fields["COUNT"] ?? "0") ?? 0

        return QRZLogbookStatus(
            callsign: callsign,
            count: count,
            isValid: result == "OK"
        )
    }

    /// Parses a QRZ Logbook `&`-delimited key=value response string.
    private func parseQRZFields(_ response: String) -> [String: String] {
        var fields: [String: String] = [:]
        let pairs = response.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).trimmingCharacters(in: .whitespaces)
                let value = String(kv[1]).trimmingCharacters(in: .whitespaces)
                fields[key] = value
            }
        }
        return fields
    }
}

// MARK: - String URL Helper

private extension String {
    var asURL: URL {
        URL(string: self)!
    }
}
