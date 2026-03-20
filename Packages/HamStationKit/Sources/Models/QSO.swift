import Foundation
import GRDB

/// Core QSO record — the primary logbook entry.
///
/// Maps to the `qso` table in the normalized schema. Contains only the ~20
/// most-queried columns; less-frequently-accessed fields live in `QSOExtended`.
public struct QSO: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var callsign: String
    public var myCallsign: String
    public var band: Band
    public var frequencyHz: Double
    public var mode: OperatingMode
    public var datetimeOn: Date
    public var datetimeOff: Date?
    public var rstSent: String
    public var rstReceived: String
    public var txPowerWatts: Double?
    public var myGrid: String?
    public var theirGrid: String?
    public var dxccEntityId: Int?
    public var continent: String?
    public var cqZone: Int?
    public var ituZone: Int?
    public var name: String?
    public var qth: String?
    public var comment: String?
    public var logbookId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        callsign: String,
        myCallsign: String,
        band: Band,
        frequencyHz: Double,
        mode: OperatingMode,
        datetimeOn: Date,
        datetimeOff: Date? = nil,
        rstSent: String,
        rstReceived: String,
        txPowerWatts: Double? = nil,
        myGrid: String? = nil,
        theirGrid: String? = nil,
        dxccEntityId: Int? = nil,
        continent: String? = nil,
        cqZone: Int? = nil,
        ituZone: Int? = nil,
        name: String? = nil,
        qth: String? = nil,
        comment: String? = nil,
        logbookId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.callsign = callsign
        self.myCallsign = myCallsign
        self.band = band
        self.frequencyHz = frequencyHz
        self.mode = mode
        self.datetimeOn = datetimeOn
        self.datetimeOff = datetimeOff
        self.rstSent = rstSent
        self.rstReceived = rstReceived
        self.txPowerWatts = txPowerWatts
        self.myGrid = myGrid
        self.theirGrid = theirGrid
        self.dxccEntityId = dxccEntityId
        self.continent = continent
        self.cqZone = cqZone
        self.ituZone = ituZone
        self.name = name
        self.qth = qth
        self.comment = comment
        self.logbookId = logbookId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformances

extension QSO: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "qso"

    enum CodingKeys: String, CodingKey {
        case id
        case callsign
        case myCallsign = "my_callsign"
        case band
        case frequencyHz = "frequency_hz"
        case mode
        case datetimeOn = "datetime_on"
        case datetimeOff = "datetime_off"
        case rstSent = "rst_sent"
        case rstReceived = "rst_received"
        case txPowerWatts = "tx_power_watts"
        case myGrid = "my_grid"
        case theirGrid = "their_grid"
        case dxccEntityId = "dxcc_entity_id"
        case continent
        case cqZone = "cq_zone"
        case ituZone = "itu_zone"
        case name
        case qth
        case comment
        case logbookId = "logbook_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
