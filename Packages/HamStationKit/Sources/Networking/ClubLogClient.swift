// ClubLogClient.swift
// HamStationKit — Log Submission Clients
//
// Club Log API client for uploading QSO records via ADIF.

import Foundation
import os

// MARK: - Errors

/// Errors specific to Club Log operations.
public enum ClubLogError: Error, Sendable {
    case authenticationFailed
    case uploadFailed(String)
    case invalidResponse
    case noQSOsProvided
}

// MARK: - ClubLogClient

/// Uploads QSO records to Club Log at `https://clublog.org/putlogs.php`
/// using multipart POST of ADIF data.
public actor ClubLogClient {
    private let client: ResilientClient
    private let logger = Logger(subsystem: "com.hamstation.kit", category: "ClubLog")

    private static let uploadURL = "https://clublog.org/putlogs.php"
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

    /// Uploads QSO records to Club Log as an ADIF payload.
    ///
    /// - Parameters:
    ///   - qsos: The QSO records to upload.
    ///   - email: The Club Log account email.
    ///   - password: The Club Log account password.
    ///   - callsign: The station callsign for this upload.
    /// - Returns: The number of QSOs accepted by Club Log.
    /// - Throws: `ClubLogError` if the upload fails.
    public func submit(
        qsos: [QSO],
        email: String,
        password: String,
        callsign: String
    ) async throws -> Int {
        guard !qsos.isEmpty else {
            throw ClubLogError.noQSOsProvided
        }

        // Convert QSOs to ADIF records and export
        let adifRecords = qsos.map { ADIFConverter.adifRecord(from: $0) }
        let adifString = ADIFExporter.export(records: adifRecords)

        // Build multipart form data
        let boundary = "HamStationPro-\(UUID().uuidString)"
        var body = Data()

        appendFormField(to: &body, boundary: boundary, name: "email", value: email)
        appendFormField(to: &body, boundary: boundary, name: "password", value: password)
        appendFormField(to: &body, boundary: boundary, name: "callsign", value: callsign.uppercased())
        appendFormField(to: &body, boundary: boundary, name: "api", value: "0")

        // ADIF file field
        appendFileField(
            to: &body,
            boundary: boundary,
            name: "file",
            filename: "upload.adi",
            mimeType: "text/plain",
            data: Data(adifString.utf8)
        )

        // Close boundary
        body.append(Data("--\(boundary)--\r\n".utf8))

        guard let url = URL(string: Self.uploadURL) else {
            throw ClubLogError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, _) = try await client.fetch(
            request,
            service: "clublog",
            config: Self.serviceConfig
        )

        let responseString = String(data: data, encoding: .utf8) ?? ""
        logger.debug("Club Log response: \(responseString)")

        return try parseResponse(responseString, expectedCount: qsos.count)
    }

    // MARK: - Response Parsing

    /// Parses the Club Log response to determine how many QSOs were accepted.
    private func parseResponse(_ response: String, expectedCount: Int) throws -> Int {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Club Log returns simple text responses
        if trimmed.lowercased().contains("denied") || trimmed.lowercased().contains("invalid") {
            throw ClubLogError.authenticationFailed
        }

        if trimmed.lowercased().contains("error") || trimmed.lowercased().contains("fail") {
            throw ClubLogError.uploadFailed(trimmed)
        }

        // Try to extract a count from the response (e.g., "12 QSO(s) uploaded")
        if let match = trimmed.range(of: #"\d+"#, options: .regularExpression) {
            let countStr = String(trimmed[match])
            if let count = Int(countStr) {
                logger.info("\(count) QSO(s) uploaded to Club Log.")
                return count
            }
        }

        // If response looks successful but no count, assume all were accepted
        if trimmed.lowercased().contains("ok") || trimmed.lowercased().contains("success") {
            logger.info("\(expectedCount) QSO(s) uploaded to Club Log (assumed).")
            return expectedCount
        }

        // If we can't parse it but it's not an error, assume success
        logger.warning("Unexpected Club Log response: \(trimmed). Assuming \(expectedCount) QSO(s) accepted.")
        return expectedCount
    }

    // MARK: - Multipart Form Helpers

    private func appendFormField(to body: inout Data, boundary: String, name: String, value: String) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n".utf8))
        body.append(Data("\r\n".utf8))
        body.append(Data("\(value)\r\n".utf8))
    }

    private func appendFileField(
        to body: inout Data,
        boundary: String,
        name: String,
        filename: String,
        mimeType: String,
        data: Data
    ) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n".utf8))
        body.append(Data("\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }
}
