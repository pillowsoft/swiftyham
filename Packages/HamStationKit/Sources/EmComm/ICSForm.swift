// ICSForm.swift
// HamStationKit — ICS (Incident Command System) digital forms for EmComm operations.

import Foundation

/// A digital ICS form used during emergency communications.
public struct ICSForm: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public var formType: FormType
    public var fields: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    public var incidentName: String?
    public var operationalPeriod: String?
    public var preparedBy: String?

    /// Supported ICS form types.
    public enum FormType: String, Codable, Sendable, CaseIterable {
        case ics213 = "ICS-213"  // General Message
        case ics214 = "ICS-214"  // Activity Log
        case ics309 = "ICS-309"  // Communications Log
    }

    public init(
        id: UUID = UUID(),
        formType: FormType,
        fields: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        incidentName: String? = nil,
        operationalPeriod: String? = nil,
        preparedBy: String? = nil
    ) {
        self.id = id
        self.formType = formType
        self.fields = fields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.incidentName = incidentName
        self.operationalPeriod = operationalPeriod
        self.preparedBy = preparedBy
    }

    // MARK: - ICS-213 Field Keys

    /// Standard field keys for ICS-213 (General Message).
    public enum ICS213Field {
        public static let to = "to"
        public static let from = "from"
        public static let subject = "subject"
        public static let date = "date"
        public static let time = "time"
        public static let message = "message"
        public static let approvedBy = "approved_by"
        public static let reply = "reply"
    }

    /// Standard field keys for ICS-214 (Activity Log).
    public enum ICS214Field {
        public static let incidentName = "incident_name"
        public static let date = "date"
        public static let unitName = "unit_name"
        public static let unitLeader = "unit_leader"
        public static let personnel = "personnel"      // JSON-encoded list
        public static let activityLog = "activity_log"  // JSON-encoded entries
    }

    /// Standard field keys for ICS-309 (Communications Log).
    public enum ICS309Field {
        public static let incidentName = "incident_name"
        public static let date = "date"
        public static let netName = "net_name"
        public static let frequency = "frequency"
        public static let entries = "entries"  // JSON-encoded entries (time, station, message)
    }

    // MARK: - Factory

    /// Create a blank form of the given type with empty default fields.
    public static func blank(type: FormType) -> ICSForm {
        var fields: [String: String] = [:]

        switch type {
        case .ics213:
            fields[ICS213Field.to] = ""
            fields[ICS213Field.from] = ""
            fields[ICS213Field.subject] = ""
            fields[ICS213Field.date] = ""
            fields[ICS213Field.time] = ""
            fields[ICS213Field.message] = ""
            fields[ICS213Field.approvedBy] = ""
            fields[ICS213Field.reply] = ""

        case .ics214:
            fields[ICS214Field.incidentName] = ""
            fields[ICS214Field.date] = ""
            fields[ICS214Field.unitName] = ""
            fields[ICS214Field.unitLeader] = ""
            fields[ICS214Field.personnel] = "[]"
            fields[ICS214Field.activityLog] = "[]"

        case .ics309:
            fields[ICS309Field.incidentName] = ""
            fields[ICS309Field.date] = ""
            fields[ICS309Field.netName] = ""
            fields[ICS309Field.frequency] = ""
            fields[ICS309Field.entries] = "[]"
        }

        return ICSForm(formType: type, fields: fields)
    }

    // MARK: - Export

    /// Export the form as structured text suitable for printing or PDF generation.
    public func exportText() -> String {
        var lines: [String] = []
        let separator = String(repeating: "-", count: 60)

        lines.append(separator)
        lines.append(formType.rawValue)
        lines.append(separator)

        if let incident = incidentName, !incident.isEmpty {
            lines.append("Incident Name: \(incident)")
        }
        if let period = operationalPeriod, !period.isEmpty {
            lines.append("Operational Period: \(period)")
        }
        if let prepared = preparedBy, !prepared.isEmpty {
            lines.append("Prepared By: \(prepared)")
        }

        lines.append("")

        switch formType {
        case .ics213:
            appendField("To", key: ICS213Field.to, to: &lines)
            appendField("From", key: ICS213Field.from, to: &lines)
            appendField("Subject", key: ICS213Field.subject, to: &lines)
            appendField("Date", key: ICS213Field.date, to: &lines)
            appendField("Time", key: ICS213Field.time, to: &lines)
            lines.append("")
            lines.append("MESSAGE:")
            lines.append(fields[ICS213Field.message] ?? "")
            lines.append("")
            appendField("Approved By", key: ICS213Field.approvedBy, to: &lines)
            lines.append("")
            lines.append("REPLY:")
            lines.append(fields[ICS213Field.reply] ?? "")

        case .ics214:
            appendField("Incident Name", key: ICS214Field.incidentName, to: &lines)
            appendField("Date", key: ICS214Field.date, to: &lines)
            appendField("Unit Name", key: ICS214Field.unitName, to: &lines)
            appendField("Unit Leader", key: ICS214Field.unitLeader, to: &lines)
            lines.append("")
            lines.append("PERSONNEL:")
            lines.append(fields[ICS214Field.personnel] ?? "[]")
            lines.append("")
            lines.append("ACTIVITY LOG:")
            lines.append(fields[ICS214Field.activityLog] ?? "[]")

        case .ics309:
            appendField("Incident Name", key: ICS309Field.incidentName, to: &lines)
            appendField("Date", key: ICS309Field.date, to: &lines)
            appendField("Net Name", key: ICS309Field.netName, to: &lines)
            appendField("Frequency", key: ICS309Field.frequency, to: &lines)
            lines.append("")
            lines.append("COMMUNICATIONS LOG ENTRIES:")
            lines.append(fields[ICS309Field.entries] ?? "[]")
        }

        lines.append("")
        lines.append(separator)
        lines.append("Created: \(createdAt)")
        lines.append("Updated: \(updatedAt)")
        lines.append(separator)

        return lines.joined(separator: "\n")
    }

    private func appendField(_ label: String, key: String, to lines: inout [String]) {
        let value = fields[key] ?? ""
        lines.append("\(label): \(value)")
    }
}
