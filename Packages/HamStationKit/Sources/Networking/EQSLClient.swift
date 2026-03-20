// EQSLClient.swift
// HamStationKit — Log Submission Clients
//
// eQSL API client for uploading QSO records via ADIF.

import Foundation
import os

// MARK: - Types

/// Result of an eQSL ADIF upload.
public struct EQSLUploadResult: Sendable {
    public let accepted: Int
    public let rejected: Int
    public let message: String

    public init(accepted: Int, rejected: Int, message: String) {
        self.accepted = accepted
        self.rejected = rejected
        self.message = message
    }
}

/// Errors specific to eQSL operations.
public enum EQSLError: Error, Sendable {
    case authenticationFailed
    case uploadFailed(String)
    case invalidResponse
    case noQSOsProvided
}

// MARK: - EQSLClient

/// Uploads QSO records to eQSL at `https://www.eqsl.cc/qslcard/ImportADIF.cfm`.
public actor EQSLClient {
    private let client: ResilientClient
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "eQSL")

    private static let uploadURL = "https://www.eqsl.cc/qslcard/ImportADIF.cfm"
    private static let serviceConfig = ServiceConfig(
        maxRetries: 3,
        baseDelay: 2.0,
        timeout: 30.0,
        maxRequestsPerMinute: 10,
        staleCacheOK: false
    )

    public init(client: ResilientClient? = nil) {
        self.client = client ?? ResilientClient()
    }

    // MARK: - Submit QSOs

    /// Uploads QSO records to eQSL as ADIF data.
    ///
    /// - Parameters:
    ///   - qsos: The QSO records to upload.
    ///   - username: The eQSL username.
    ///   - password: The eQSL password.
    /// - Returns: An `EQSLUploadResult` with accepted/rejected counts.
    /// - Throws: `EQSLError` if the upload fails.
    public func submit(
        qsos: [QSO],
        username: String,
        password: String
    ) async throws -> EQSLUploadResult {
        guard !qsos.isEmpty else {
            throw EQSLError.noQSOsProvided
        }

        // Convert QSOs to ADIF records and export
        let adifRecords = qsos.map { ADIFConverter.adifRecord(from: $0) }
        let adifString = ADIFExporter.export(records: adifRecords)

        // Build form-encoded POST body
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "eqsl_user", value: username),
            URLQueryItem(name: "eqsl_pswd", value: password),
            URLQueryItem(name: "ADIFData", value: adifString),
        ]

        guard let url = URL(string: Self.uploadURL) else {
            throw EQSLError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await client.fetch(
            request,
            service: "eqsl",
            config: Self.serviceConfig
        )

        let responseString = String(data: data, encoding: .utf8) ?? ""
        logger.debug("eQSL response: \(responseString)")

        return try parseResponse(responseString, totalCount: qsos.count)
    }

    // MARK: - Response Parsing

    /// Parses the eQSL HTML response to extract accepted/rejected counts.
    private func parseResponse(_ response: String, totalCount: Int) throws -> EQSLUploadResult {
        let lowered = response.lowercased()

        // Check for authentication failures
        if lowered.contains("password incorrect") || lowered.contains("no such user") ||
            lowered.contains("not logged in") {
            throw EQSLError.authenticationFailed
        }

        // Check for general errors
        if lowered.contains("error") && !lowered.contains("0 error") {
            let message = extractMessage(from: response)
            throw EQSLError.uploadFailed(message)
        }

        // Try to extract counts from response HTML
        // eQSL typically returns "Result: N of M records added" or similar
        var accepted = 0
        var rejected = 0

        if let addedRange = response.range(of: #"(\d+)\s+(of\s+\d+\s+)?record"#, options: .regularExpression) {
            let matched = String(response[addedRange])
            if let countMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                accepted = Int(String(matched[countMatch])) ?? totalCount
            }
        } else {
            // If we can't parse but no error, assume all accepted
            accepted = totalCount
        }

        rejected = totalCount - accepted
        let message = extractMessage(from: response)

        logger.info("eQSL upload: \(accepted) accepted, \(rejected) rejected.")
        return EQSLUploadResult(accepted: accepted, rejected: rejected, message: message)
    }

    /// Extracts a readable message from the eQSL HTML response.
    private func extractMessage(from response: String) -> String {
        // Try to find a meaningful message between common HTML patterns
        // Strip HTML tags for a cleaner message
        let stripped = response
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Limit to a reasonable length
        if stripped.count > 200 {
            return String(stripped.prefix(200)) + "..."
        }
        return stripped.isEmpty ? "No details available" : stripped
    }
}
