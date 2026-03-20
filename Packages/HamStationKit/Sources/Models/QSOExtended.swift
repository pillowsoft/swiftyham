import Foundation
import GRDB

/// Extended QSO fields stored in a 1:1 relationship with the core `QSO` record.
///
/// Maps to the `qso_extended` table. Contains contest, SOTA/POTA, QSL status,
/// and preserved APP_ fields (as a JSON string) that are less frequently queried.
public struct QSOExtended: Sendable, Equatable, Identifiable {
    /// The primary key, which is also the foreign key to `qso.id`.
    public var id: UUID { qsoId }

    public var qsoId: UUID
    public var propagationMode: String?
    public var satelliteName: String?
    public var satelliteMode: String?
    public var contestId: String?
    public var contestExchangeSent: String?
    public var contestExchangeRcvd: String?
    public var sotaRef: String?
    public var potaRef: String?
    public var wwffRef: String?
    public var myCounty: String?
    public var theirCounty: String?
    public var qslSent: String?
    public var qslReceived: String?
    public var lotwSent: Bool?
    public var lotwReceived: Bool?
    public var eqslSent: Bool?
    public var eqslReceived: Bool?
    public var clublogStatus: String?
    public var adifImportSource: String?
    public var isVerified: Bool?
    /// JSON string preserving unknown ADIF APP_ fields.
    public var appFields: String?

    public init(
        qsoId: UUID,
        propagationMode: String? = nil,
        satelliteName: String? = nil,
        satelliteMode: String? = nil,
        contestId: String? = nil,
        contestExchangeSent: String? = nil,
        contestExchangeRcvd: String? = nil,
        sotaRef: String? = nil,
        potaRef: String? = nil,
        wwffRef: String? = nil,
        myCounty: String? = nil,
        theirCounty: String? = nil,
        qslSent: String? = nil,
        qslReceived: String? = nil,
        lotwSent: Bool? = nil,
        lotwReceived: Bool? = nil,
        eqslSent: Bool? = nil,
        eqslReceived: Bool? = nil,
        clublogStatus: String? = nil,
        adifImportSource: String? = nil,
        isVerified: Bool? = nil,
        appFields: String? = nil
    ) {
        self.qsoId = qsoId
        self.propagationMode = propagationMode
        self.satelliteName = satelliteName
        self.satelliteMode = satelliteMode
        self.contestId = contestId
        self.contestExchangeSent = contestExchangeSent
        self.contestExchangeRcvd = contestExchangeRcvd
        self.sotaRef = sotaRef
        self.potaRef = potaRef
        self.wwffRef = wwffRef
        self.myCounty = myCounty
        self.theirCounty = theirCounty
        self.qslSent = qslSent
        self.qslReceived = qslReceived
        self.lotwSent = lotwSent
        self.lotwReceived = lotwReceived
        self.eqslSent = eqslSent
        self.eqslReceived = eqslReceived
        self.clublogStatus = clublogStatus
        self.adifImportSource = adifImportSource
        self.isVerified = isVerified
        self.appFields = appFields
    }
}

// MARK: - GRDB Conformances

extension QSOExtended: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "qso_extended"

    enum CodingKeys: String, CodingKey {
        case qsoId = "qso_id"
        case propagationMode = "propagation_mode"
        case satelliteName = "satellite_name"
        case satelliteMode = "satellite_mode"
        case contestId = "contest_id"
        case contestExchangeSent = "contest_exchange_sent"
        case contestExchangeRcvd = "contest_exchange_rcvd"
        case sotaRef = "sota_ref"
        case potaRef = "pota_ref"
        case wwffRef = "wwff_ref"
        case myCounty = "my_county"
        case theirCounty = "their_county"
        case qslSent = "qsl_sent"
        case qslReceived = "qsl_received"
        case lotwSent = "lotw_sent"
        case lotwReceived = "lotw_received"
        case eqslSent = "eqsl_sent"
        case eqslReceived = "eqsl_received"
        case clublogStatus = "clublog_status"
        case adifImportSource = "adif_import_source"
        case isVerified = "is_verified"
        case appFields = "app_fields"
    }
}
