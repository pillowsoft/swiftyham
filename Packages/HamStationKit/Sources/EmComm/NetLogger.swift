// NetLogger.swift
// HamStationKit — HF/VHF net logging for emergency communications.

import Foundation

/// Manages net sessions and check-in logging for ARES/RACES operations.
public actor NetLogger {

    /// A net session with check-in tracking.
    public struct NetSession: Sendable, Identifiable, Equatable {
        public let id: UUID
        public var netName: String
        public var frequency: String
        public var mode: String
        public var netControlStation: String
        public var startTime: Date
        public var endTime: Date?
        public var checkIns: [CheckIn]

        public init(
            id: UUID = UUID(),
            netName: String,
            frequency: String,
            mode: String,
            netControlStation: String,
            startTime: Date = Date(),
            endTime: Date? = nil,
            checkIns: [CheckIn] = []
        ) {
            self.id = id
            self.netName = netName
            self.frequency = frequency
            self.mode = mode
            self.netControlStation = netControlStation
            self.startTime = startTime
            self.endTime = endTime
            self.checkIns = checkIns
        }
    }

    /// A single check-in to the net.
    public struct CheckIn: Sendable, Identifiable, Equatable {
        public let id: UUID
        public var callsign: String
        public var name: String?
        public var location: String?
        public var time: Date
        public var traffic: TrafficType
        public var remarks: String?

        /// Traffic priority level.
        public enum TrafficType: String, Sendable, CaseIterable {
            case none
            case routine
            case priority
            case emergency
        }

        public init(
            id: UUID = UUID(),
            callsign: String,
            name: String? = nil,
            location: String? = nil,
            time: Date = Date(),
            traffic: TrafficType = .none,
            remarks: String? = nil
        ) {
            self.id = id
            self.callsign = callsign
            self.name = name
            self.location = location
            self.time = time
            self.traffic = traffic
            self.remarks = remarks
        }
    }

    // MARK: - State

    public private(set) var currentSession: NetSession?

    /// History of completed net sessions.
    public private(set) var sessionHistory: [NetSession] = []

    public init() {}

    // MARK: - Net Operations

    /// Start a new net session.
    @discardableResult
    public func startNet(
        name: String,
        frequency: String,
        mode: String,
        ncs: String
    ) -> NetSession {
        let session = NetSession(
            netName: name,
            frequency: frequency,
            mode: mode,
            netControlStation: ncs
        )
        currentSession = session
        return session
    }

    /// Check in a station to the current net.
    public func checkIn(
        callsign: String,
        name: String? = nil,
        location: String? = nil,
        traffic: CheckIn.TrafficType = .none,
        remarks: String? = nil
    ) {
        guard currentSession != nil else { return }

        let entry = CheckIn(
            callsign: callsign.uppercased(),
            name: name,
            location: location,
            traffic: traffic,
            remarks: remarks
        )
        currentSession?.checkIns.append(entry)
    }

    /// End the current net session.
    public func endNet() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        sessionHistory.append(session)
        currentSession = nil
    }

    // MARK: - Export

    /// Export the current or most recent session as an ARES-format report.
    public func exportReport() -> String {
        guard let session = currentSession ?? sessionHistory.last else {
            return "No net session data available."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var lines: [String] = []
        let separator = String(repeating: "=", count: 60)

        lines.append(separator)
        lines.append("ARES/RACES NET REPORT")
        lines.append(separator)
        lines.append("Net Name: \(session.netName)")
        lines.append("Date: \(dateFormatter.string(from: session.startTime))")
        lines.append("Frequency: \(session.frequency)")
        lines.append("Mode: \(session.mode)")
        lines.append("Net Control: \(session.netControlStation)")
        lines.append("Start Time: \(timeFormatter.string(from: session.startTime)) UTC")
        if let endTime = session.endTime {
            lines.append("End Time: \(timeFormatter.string(from: endTime)) UTC")
            let duration = endTime.timeIntervalSince(session.startTime)
            let minutes = Int(duration / 60)
            lines.append("Duration: \(minutes) minutes")
        }
        lines.append("Total Check-Ins: \(session.checkIns.count)")
        lines.append("")
        lines.append(String(repeating: "-", count: 60))
        lines.append(String(format: "%-8s %-6s %-15s %-10s %s",
                            "TIME", "CALL", "NAME", "TRAFFIC", "REMARKS"))
        lines.append(String(repeating: "-", count: 60))

        for checkIn in session.checkIns {
            let time = timeFormatter.string(from: checkIn.time)
            let name = checkIn.name ?? ""
            let traffic = checkIn.traffic.rawValue.uppercased()
            let remarks = checkIn.remarks ?? ""
            lines.append(String(format: "%-8s %-6s %-15s %-10s %s",
                                time, checkIn.callsign, name, traffic, remarks))
        }

        lines.append(separator)
        return lines.joined(separator: "\n")
    }
}
