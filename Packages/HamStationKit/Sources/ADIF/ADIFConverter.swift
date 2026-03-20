// ADIFConverter.swift
// HamStationKit — ADIF 3.1 Parser & Exporter
//
// Bidirectional conversion between QSO model objects and ADIFRecord.

import Foundation

/// Converts between `QSO` / `QSOExtended` model types and `ADIFRecord`.
///
/// Used by ADIF import/export dialogs. The `qso(from:)` direction mirrors the
/// logic in FirstRunWizard.makeQSO but lives in the shared package so it can
/// be used from any import surface.
public enum ADIFConverter: Sendable {

    // MARK: - ADIF → QSO

    /// Converts an ADIF record into a `QSO`, returning `nil` if the record
    /// lacks a CALL field.
    ///
    /// - Parameters:
    ///   - record: A parsed ADIF record.
    ///   - myCallsign: The operator's callsign (used if STATION_CALLSIGN absent).
    ///   - logbookId: Optional logbook to assign the QSO to.
    /// - Returns: A populated `QSO`, or `nil` if the record is unusable.
    public static func qso(
        from record: ADIFRecord,
        myCallsign: String,
        logbookId: UUID? = nil
    ) -> QSO? {
        guard let callsign = record["CALL"], !callsign.isEmpty else { return nil }

        // Date/time
        let dateStr = record["QSO_DATE"] ?? ""
        let timeStr = record["TIME_ON"] ?? ""
        let datetimeOn: Date
        if let parsed = ADIFDateFormatter.parseDateTime(date: dateStr, time: timeStr) {
            datetimeOn = parsed
        } else if let dateOnly = ADIFDateFormatter.parseDate(dateStr)?.date {
            datetimeOn = dateOnly
        } else {
            datetimeOn = Date()
        }

        var datetimeOff: Date? = nil
        if let dateOffStr = record["QSO_DATE_OFF"], let timeOffStr = record["TIME_OFF"] {
            datetimeOff = ADIFDateFormatter.parseDateTime(date: dateOffStr, time: timeOffStr)
        }

        // Band & mode
        let band = Band(rawValue: record["BAND"] ?? "20m") ?? .band20m
        let mode = OperatingMode(rawValue: record["MODE"] ?? "SSB") ?? .ssb

        // Frequency (ADIF FREQ is in MHz)
        var frequencyHz = band.frequencyRange.lowerBound
        if let freqStr = record["FREQ"], let freqMHz = Double(freqStr) {
            frequencyHz = freqMHz * 1_000_000.0
        }

        let rstSent = record["RST_SENT"] ?? mode.defaultRST
        let rstRcvd = record["RST_RCVD"] ?? mode.defaultRST
        let stationCall = record["STATION_CALLSIGN"] ?? myCallsign

        return QSO(
            callsign: callsign.uppercased(),
            myCallsign: stationCall,
            band: band,
            frequencyHz: frequencyHz,
            mode: mode,
            datetimeOn: datetimeOn,
            datetimeOff: datetimeOff,
            rstSent: rstSent,
            rstReceived: rstRcvd,
            txPowerWatts: record["TX_PWR"].flatMap { Double($0) },
            myGrid: record["MY_GRIDSQUARE"],
            theirGrid: record["GRIDSQUARE"],
            dxccEntityId: record["DXCC"].flatMap { Int($0) },
            continent: record["CONT"],
            cqZone: record["CQ_ZONE"].flatMap { Int($0) },
            ituZone: record["ITUZ"].flatMap { Int($0) },
            name: record["NAME"],
            qth: record["QTH"],
            comment: record["COMMENT"],
            logbookId: logbookId
        )
    }

    /// Extracts extended fields from an ADIF record for a given QSO ID.
    ///
    /// Returns `nil` if no extended fields are present.
    public static func qsoExtended(
        from record: ADIFRecord,
        qsoId: UUID
    ) -> QSOExtended? {
        let propagation = record["PROP_MODE"]
        let satName = record["SAT_NAME"]
        let satMode = record["SAT_MODE"]
        let contestId = record["CONTEST_ID"]
        let stx = record["STX_STRING"] ?? record["STX"]
        let srx = record["SRX_STRING"] ?? record["SRX"]
        let sotaRef = record["SOTA_REF"]
        let potaRef = record["POTA_REF"]
        let wwffRef = record["WWFF_REF"]
        let myCounty = record["MY_CNTY"]
        let theirCounty = record["CNTY"]
        let qslSent = record["QSL_SENT"]
        let qslRcvd = record["QSL_RCVD"]
        let lotwSent = record["LOTW_QSL_SENT"].map { $0 == "Y" }
        let lotwRcvd = record["LOTW_QSL_RCVD"].map { $0 == "Y" }
        let eqslSent = record["EQSL_QSL_SENT"].map { $0 == "Y" }
        let eqslRcvd = record["EQSL_QSL_RCVD"].map { $0 == "Y" }
        let clublog = record["CLUBLOG_QSO_UPLOAD_STATUS"]

        // Collect APP_ fields as JSON
        let appFieldNames = record.allFieldNames.filter { $0.hasPrefix("APP_") }
        var appFieldsJSON: String? = nil
        if !appFieldNames.isEmpty {
            var dict: [String: String] = [:]
            for name in appFieldNames {
                if let val = record[name] { dict[name] = val }
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                appFieldsJSON = json
            }
        }

        // Only create extended if there's something to store
        let hasAnyField = [
            propagation, satName, satMode, contestId, stx, srx,
            sotaRef, potaRef, wwffRef, myCounty, theirCounty,
            qslSent, qslRcvd, clublog, appFieldsJSON
        ].contains(where: { $0 != nil })
        let hasAnyBool = [lotwSent, lotwRcvd, eqslSent, eqslRcvd].contains(where: { $0 != nil })

        guard hasAnyField || hasAnyBool else { return nil }

        return QSOExtended(
            qsoId: qsoId,
            propagationMode: propagation,
            satelliteName: satName,
            satelliteMode: satMode,
            contestId: contestId,
            contestExchangeSent: stx,
            contestExchangeRcvd: srx,
            sotaRef: sotaRef,
            potaRef: potaRef,
            wwffRef: wwffRef,
            myCounty: myCounty,
            theirCounty: theirCounty,
            qslSent: qslSent,
            qslReceived: qslRcvd,
            lotwSent: lotwSent,
            lotwReceived: lotwRcvd,
            eqslSent: eqslSent,
            eqslReceived: eqslRcvd,
            clublogStatus: clublog,
            appFields: appFieldsJSON
        )
    }

    // MARK: - QSO → ADIF

    /// Converts a `QSO` (and optional extended fields) into an `ADIFRecord`.
    public static func adifRecord(
        from qso: QSO,
        extended: QSOExtended? = nil
    ) -> ADIFRecord {
        var record = ADIFRecord()

        record.setField(name: "CALL", value: qso.callsign)
        record.setField(name: "STATION_CALLSIGN", value: qso.myCallsign)
        record.setField(name: "BAND", value: qso.band.rawValue)
        record.setField(name: "MODE", value: qso.mode.rawValue)
        record.setField(name: "FREQ", value: String(format: "%.6f", qso.frequencyHz / 1_000_000.0))
        record.setField(name: "QSO_DATE", value: ADIFDateFormatter.formatDate(qso.datetimeOn))
        record.setField(name: "TIME_ON", value: ADIFDateFormatter.formatTime(qso.datetimeOn))
        record.setField(name: "RST_SENT", value: qso.rstSent)
        record.setField(name: "RST_RCVD", value: qso.rstReceived)

        if let off = qso.datetimeOff {
            record.setField(name: "QSO_DATE_OFF", value: ADIFDateFormatter.formatDate(off))
            record.setField(name: "TIME_OFF", value: ADIFDateFormatter.formatTime(off))
        }
        if let power = qso.txPowerWatts {
            record.setField(name: "TX_PWR", value: String(format: "%.0f", power))
        }
        if let grid = qso.myGrid {
            record.setField(name: "MY_GRIDSQUARE", value: grid)
        }
        if let grid = qso.theirGrid {
            record.setField(name: "GRIDSQUARE", value: grid)
        }
        if let dxcc = qso.dxccEntityId {
            record.setField(name: "DXCC", value: String(dxcc))
        }
        if let cont = qso.continent {
            record.setField(name: "CONT", value: cont)
        }
        if let cq = qso.cqZone {
            record.setField(name: "CQ_ZONE", value: String(cq))
        }
        if let itu = qso.ituZone {
            record.setField(name: "ITUZ", value: String(itu))
        }
        if let name = qso.name {
            record.setField(name: "NAME", value: name)
        }
        if let qth = qso.qth {
            record.setField(name: "QTH", value: qth)
        }
        if let comment = qso.comment {
            record.setField(name: "COMMENT", value: comment)
        }

        // Extended fields
        if let ext = extended {
            if let v = ext.propagationMode { record.setField(name: "PROP_MODE", value: v) }
            if let v = ext.satelliteName { record.setField(name: "SAT_NAME", value: v) }
            if let v = ext.satelliteMode { record.setField(name: "SAT_MODE", value: v) }
            if let v = ext.contestId { record.setField(name: "CONTEST_ID", value: v) }
            if let v = ext.contestExchangeSent { record.setField(name: "STX_STRING", value: v) }
            if let v = ext.contestExchangeRcvd { record.setField(name: "SRX_STRING", value: v) }
            if let v = ext.sotaRef { record.setField(name: "SOTA_REF", value: v) }
            if let v = ext.potaRef { record.setField(name: "POTA_REF", value: v) }
            if let v = ext.wwffRef { record.setField(name: "WWFF_REF", value: v) }
            if let v = ext.myCounty { record.setField(name: "MY_CNTY", value: v) }
            if let v = ext.theirCounty { record.setField(name: "CNTY", value: v) }
            if let v = ext.qslSent { record.setField(name: "QSL_SENT", value: v) }
            if let v = ext.qslReceived { record.setField(name: "QSL_RCVD", value: v) }
            if let v = ext.lotwSent { record.setField(name: "LOTW_QSL_SENT", value: v ? "Y" : "N") }
            if let v = ext.lotwReceived { record.setField(name: "LOTW_QSL_RCVD", value: v ? "Y" : "N") }
            if let v = ext.eqslSent { record.setField(name: "EQSL_QSL_SENT", value: v ? "Y" : "N") }
            if let v = ext.eqslReceived { record.setField(name: "EQSL_QSL_RCVD", value: v ? "Y" : "N") }
            if let v = ext.clublogStatus { record.setField(name: "CLUBLOG_QSO_UPLOAD_STATUS", value: v) }

            // Restore APP_ fields from JSON
            if let json = ext.appFields,
               let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                    record.setField(name: key, value: value)
                }
            }
        }

        return record
    }
}
