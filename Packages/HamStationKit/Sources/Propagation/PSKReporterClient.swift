// PSKReporterClient.swift
// HamStationKit — Fetches live signal reports from PSK Reporter for propagation analysis.

import Foundation

/// A single signal report from PSK Reporter.
public struct PSKReport: Sendable, Identifiable, Equatable {
    public let id: UUID
    /// Callsign of the transmitting station.
    public var senderCallsign: String
    /// Callsign of the receiving station.
    public var receiverCallsign: String
    /// Frequency in Hz.
    public var frequency: Double
    /// Signal-to-noise ratio in dB.
    public var snr: Int
    /// Operating mode (e.g., "FT8", "CW").
    public var mode: String
    /// Sender's Maidenhead grid square.
    public var senderGrid: String?
    /// Receiver's Maidenhead grid square.
    public var receiverGrid: String?
    /// When the report was received.
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        senderCallsign: String,
        receiverCallsign: String,
        frequency: Double,
        snr: Int = 0,
        mode: String,
        senderGrid: String? = nil,
        receiverGrid: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.senderCallsign = senderCallsign
        self.receiverCallsign = receiverCallsign
        self.frequency = frequency
        self.snr = snr
        self.mode = mode
        self.senderGrid = senderGrid
        self.receiverGrid = receiverGrid
        self.timestamp = timestamp
    }

    /// Band derived from frequency.
    public var band: String {
        switch frequency {
        case 1_800_000...2_000_000: return "160m"
        case 3_500_000...4_000_000: return "80m"
        case 7_000_000...7_300_000: return "40m"
        case 10_100_000...10_150_000: return "30m"
        case 14_000_000...14_350_000: return "20m"
        case 18_068_000...18_168_000: return "17m"
        case 21_000_000...21_450_000: return "15m"
        case 24_890_000...24_990_000: return "12m"
        case 28_000_000...29_700_000: return "10m"
        case 50_000_000...54_000_000: return "6m"
        default: return "?"
        }
    }
}

/// Fetches live signal reports from the PSK Reporter API.
///
/// PSK Reporter aggregates reception reports from digital mode operators worldwide,
/// providing real-time propagation data. The API returns XML with recent spots
/// for a given callsign, band, or grid square.
public actor PSKReporterClient {

    private let resilientClient: ResilientClient
    private static let baseURL = "https://retrieve.pskreporter.info/query"

    public init(resilientClient: ResilientClient) {
        self.resilientClient = resilientClient
    }

    /// Fetch recent reports for a specific receiver callsign.
    ///
    /// - Parameters:
    ///   - callsign: The receiver callsign to query for.
    ///   - lastSeconds: How far back to look (default 900 = 15 minutes).
    /// - Returns: Array of signal reports.
    private static let serviceConfig = ServiceConfig(
        maxRetries: 2,
        baseDelay: 2.0,
        staleCacheOK: true
    )

    public func fetchReports(
        receiverCallsign callsign: String,
        lastSeconds: Int = 900
    ) async throws -> [PSKReport] {
        let query = "senderCallsign=*&receiverCallsign=\(callsign)&flowStartSeconds=-\(lastSeconds)&mode=FT8&mode=FT4&mode=CW"
        guard let url = URL(string: "\(Self.baseURL)?\(query)") else {
            return []
        }
        let request = URLRequest(url: url)
        let (data, _) = try await resilientClient.fetch(request, service: "pskreporter", config: Self.serviceConfig)
        return parseXML(data: data)
    }

    /// Fetch recent reports for a specific sender callsign (who's hearing me?).
    ///
    /// - Parameters:
    ///   - callsign: The sender callsign to query for.
    ///   - lastSeconds: How far back to look (default 900 = 15 minutes).
    /// - Returns: Array of signal reports.
    public func fetchReportsForSender(
        senderCallsign callsign: String,
        lastSeconds: Int = 900
    ) async throws -> [PSKReport] {
        let query = "senderCallsign=\(callsign)&flowStartSeconds=-\(lastSeconds)"
        guard let url = URL(string: "\(Self.baseURL)?\(query)") else {
            return []
        }
        let request = URLRequest(url: url)
        let (data, _) = try await resilientClient.fetch(request, service: "pskreporter", config: Self.serviceConfig)
        return parseXML(data: data)
    }

    // MARK: - XML Parsing

    /// Parse PSK Reporter XML response into PSKReport structs.
    ///
    /// The XML format uses `<receptionReport>` elements with attributes for each field.
    private func parseXML(data: Data) -> [PSKReport] {
        let parser = PSKReporterXMLParser(data: data)
        return parser.parse()
    }
}

// MARK: - XML Parser

/// Lightweight XML parser for PSK Reporter API responses.
final class PSKReporterXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private let data: Data
    private var reports: [PSKReport] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [PSKReport] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return reports
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        guard elementName == "receptionReport" else { return }

        let senderCall = attributes["senderCallsign"] ?? ""
        let receiverCall = attributes["receiverCallsign"] ?? ""
        let freq = Double(attributes["frequency"] ?? "0") ?? 0
        let snr = Int(attributes["sNR"] ?? "0") ?? 0
        let mode = attributes["mode"] ?? ""
        let senderGrid = attributes["senderLocator"]
        let receiverGrid = attributes["receiverLocator"]

        let timestamp: Date
        if let flowStr = attributes["flowStartSeconds"],
           let flowSeconds = TimeInterval(flowStr) {
            timestamp = Date(timeIntervalSince1970: flowSeconds)
        } else {
            timestamp = Date()
        }

        guard !senderCall.isEmpty && !receiverCall.isEmpty && freq > 0 else { return }

        let report = PSKReport(
            senderCallsign: senderCall,
            receiverCallsign: receiverCall,
            frequency: freq,
            snr: snr,
            mode: mode,
            senderGrid: senderGrid,
            receiverGrid: receiverGrid,
            timestamp: timestamp
        )
        reports.append(report)
    }
}
