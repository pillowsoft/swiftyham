import Foundation
import GRDB

/// DXCC entity reference record.
///
/// Maps to the `dxcc_entity` table. The `id` is the official DXCC entity number.
public struct DXCCEntity: Sendable, Equatable, Identifiable {
    /// The DXCC entity number (primary key).
    public var id: Int
    public var name: String
    public var prefix: String
    public var continent: String
    public var cqZone: Int
    public var ituZone: Int
    public var latitude: Double?
    public var longitude: Double?
    public var isDeleted: Bool
    public var updatedAt: Date?

    public init(
        id: Int,
        name: String,
        prefix: String,
        continent: String,
        cqZone: Int,
        ituZone: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isDeleted: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.prefix = prefix
        self.continent = continent
        self.cqZone = cqZone
        self.ituZone = ituZone
        self.latitude = latitude
        self.longitude = longitude
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformances

extension DXCCEntity: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "dxcc_entity"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case prefix
        case continent
        case cqZone = "cq_zone"
        case ituZone = "itu_zone"
        case latitude
        case longitude
        case isDeleted = "is_deleted"
        case updatedAt = "updated_at"
    }
}
