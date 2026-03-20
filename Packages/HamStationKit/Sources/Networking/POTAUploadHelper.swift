// POTAUploadHelper.swift
// HamStationKit — Log Submission Clients
//
// POTA (Parks on the Air) ADIF formatter for file-based upload.
// POTA does not have a submission API; operators upload ADIF files manually.

import Foundation

/// Formats QSO records as POTA-compatible ADIF for manual upload.
///
/// POTA requires ADIF files with specific fields (`MY_POTA_REF`, `STATION_CALLSIGN`)
/// to be uploaded at <https://pota.app>. This helper generates correctly formatted
/// ADIF strings ready for file export.
public enum POTAUploadHelper: Sendable {

    /// Generates a POTA-compliant ADIF string from the given QSOs.
    ///
    /// Each QSO record will include the required `MY_POTA_REF` and
    /// `STATION_CALLSIGN` fields. Existing ADIF fields from the QSO
    /// are preserved.
    ///
    /// - Parameters:
    ///   - qsos: The QSO records to format.
    ///   - activatorCallsign: The activator's callsign (written to `STATION_CALLSIGN`).
    ///   - parkRef: The POTA park reference (e.g., "US-0001"), written to `MY_POTA_REF`.
    /// - Returns: A complete ADIF string suitable for upload to POTA.
    public static func generateADIF(
        qsos: [QSO],
        activatorCallsign: String,
        parkRef: String
    ) -> String {
        let records = qsos.map { qso -> ADIFRecord in
            var record = ADIFConverter.adifRecord(from: qso)

            // Set POTA-required fields
            record.setField(name: "STATION_CALLSIGN", value: activatorCallsign.uppercased())
            record.setField(name: "MY_POTA_REF", value: parkRef.uppercased())

            return record
        }

        let options = ADIFExporter.ExportOptions(
            includeHeader: true,
            programId: "HamStation Pro",
            programVersion: "1.0"
        )

        return ADIFExporter.export(records: records, options: options)
    }
}
