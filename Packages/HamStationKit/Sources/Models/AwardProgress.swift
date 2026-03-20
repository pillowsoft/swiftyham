import Foundation
import GRDB

/// Tracks progress toward amateur radio awards (DXCC, WAS, WAZ, etc.).
///
/// Maps to the `award_progress` table. Each row represents one entity/reference
/// toward a specific award, optionally scoped to a band and mode.
public struct AwardProgress: Sendable, Equatable, Identifiable {
    public var id: UUID
    /// The award type identifier (e.g., "DXCC", "WAS", "WAZ", "VUCC").
    public var awardType: String
    /// Optional band filter for band-specific endorsements.
    public var band: Band?
    /// Optional mode filter for mode-specific endorsements.
    public var mode: OperatingMode?
    /// The entity or reference being tracked (e.g., DXCC entity number, US state abbreviation).
    public var entityOrRef: String
    /// Whether this entity has been worked.
    public var worked: Bool
    /// Whether this entity has been confirmed.
    public var confirmed: Bool
    /// The QSO that satisfies this award requirement, if any.
    public var qsoId: UUID?
    /// How this was confirmed (e.g., "lotw", "eqsl", "card").
    public var confirmedVia: String?

    public init(
        id: UUID = UUID(),
        awardType: String,
        band: Band? = nil,
        mode: OperatingMode? = nil,
        entityOrRef: String,
        worked: Bool = false,
        confirmed: Bool = false,
        qsoId: UUID? = nil,
        confirmedVia: String? = nil
    ) {
        self.id = id
        self.awardType = awardType
        self.band = band
        self.mode = mode
        self.entityOrRef = entityOrRef
        self.worked = worked
        self.confirmed = confirmed
        self.qsoId = qsoId
        self.confirmedVia = confirmedVia
    }
}

// MARK: - GRDB Conformances

extension AwardProgress: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "award_progress"

    enum CodingKeys: String, CodingKey {
        case id
        case awardType = "award_type"
        case band
        case mode
        case entityOrRef = "entity_or_ref"
        case worked
        case confirmed
        case qsoId = "qso_id"
        case confirmedVia = "confirmed_via"
    }
}
