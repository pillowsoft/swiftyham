import Foundation
import GRDB

/// A logbook container for organizing QSOs. Supports multiple logbooks.
///
/// Maps to the `logbook` table. One logbook should have `isDefault` set to true.
public struct Logbook: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var description: String?
    public var isDefault: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

// MARK: - GRDB Conformances

extension Logbook: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "logbook"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isDefault = "is_default"
        case createdAt = "created_at"
    }
}
