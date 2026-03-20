import Foundation
import GRDB

/// Cached callsign lookup result with a 30-day TTL.
///
/// Maps to the `callsign_cache` table. The callsign is the primary key.
public struct CallsignCache: Sendable, Equatable, Identifiable {
    public var id: String { callsign }

    /// The callsign (primary key).
    public var callsign: String
    public var name: String?
    public var qth: String?
    public var grid: String?
    public var country: String?
    public var state: String?
    public var county: String?
    public var email: String?
    public var lotwMember: Bool?
    /// The lookup source (e.g., "hamdb", "qrz").
    public var source: String
    public var fetchedAt: Date
    public var expiresAt: Date

    public init(
        callsign: String,
        name: String? = nil,
        qth: String? = nil,
        grid: String? = nil,
        country: String? = nil,
        state: String? = nil,
        county: String? = nil,
        email: String? = nil,
        lotwMember: Bool? = nil,
        source: String,
        fetchedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    ) {
        self.callsign = callsign
        self.name = name
        self.qth = qth
        self.grid = grid
        self.country = country
        self.state = state
        self.county = county
        self.email = email
        self.lotwMember = lotwMember
        self.source = source
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
    }

    /// Whether this cache entry has expired.
    public var isExpired: Bool {
        Date() > expiresAt
    }
}

// MARK: - GRDB Conformances

extension CallsignCache: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "callsign_cache"

    // Use callsign as the primary key (not an auto-generated column).
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace
    )

    enum CodingKeys: String, CodingKey {
        case callsign
        case name
        case qth
        case grid
        case country
        case state
        case county
        case email
        case lotwMember = "lotw_member"
        case source
        case fetchedAt = "fetched_at"
        case expiresAt = "expires_at"
    }
}
