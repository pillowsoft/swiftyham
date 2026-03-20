import Foundation
import GRDB

/// Sort fields available for QSO queries.
public enum QSOSortField: String, Sendable {
    case datetimeOn = "datetime_on"
    case callsign = "callsign"
    case band = "band"
    case mode = "mode"
    case frequency = "frequency_hz"
}

/// Errors specific to database operations.
public enum DatabaseManagerError: Error, Sendable {
    case migrationFailed(underlying: Error)
    case backupFailed(underlying: Error)
    case restoreFailed(underlying: Error)
    case noDefaultLogbook
}

/// The core database actor. Owns a GRDB `DatabasePool` for hamstation.sqlite.
///
/// All database access is isolated to this actor, ensuring thread-safe reads and
/// writes with Swift 6 strict concurrency.
public actor DatabaseManager {

    /// The GRDB database pool (read/write).
    public let dbPool: DatabasePool

    /// The file path of the database, or nil for in-memory databases.
    private let databasePath: String?

    // MARK: - Initialization

    /// Opens or creates a database at the given file path.
    /// Runs migrations on init; backs up the file before migrating.
    public init(path: String) throws {
        self.databasePath = path
        self.dbPool = try DatabasePool(path: path)
        try Self.migrateWithBackup(dbPool: dbPool, path: path)
    }

    /// Creates an in-memory database for testing.
    /// Uses a temporary file because GRDB 7.x requires WAL mode for DatabasePool,
    /// which is not supported by literal `:memory:` databases.
    public init(inMemory: Bool = true) throws {
        let tempPath = NSTemporaryDirectory() + UUID().uuidString + ".sqlite"
        self.databasePath = tempPath
        self.dbPool = try DatabasePool(path: tempPath)
        try Self.migrateInPlace(dbPool: dbPool)
    }

    // MARK: - Migration

    private static func migrateWithBackup(dbPool: DatabasePool, path: String) throws {
        let backupPath = path + ".backup"
        let fm = FileManager.default

        // Create backup before migration
        do {
            if fm.fileExists(atPath: backupPath) {
                try fm.removeItem(atPath: backupPath)
            }
            if fm.fileExists(atPath: path) {
                try fm.copyItem(atPath: path, toPath: backupPath)
            }
        } catch {
            throw DatabaseManagerError.backupFailed(underlying: error)
        }

        // Run migrations
        do {
            var migrator = DatabaseMigrator()
            DatabaseMigrations.registerMigrations(&migrator)
            try migrator.migrate(dbPool)
        } catch {
            // Restore from backup on failure
            do {
                if fm.fileExists(atPath: backupPath) {
                    if fm.fileExists(atPath: path) {
                        try fm.removeItem(atPath: path)
                    }
                    try fm.copyItem(atPath: backupPath, toPath: path)
                }
            } catch let restoreError {
                throw DatabaseManagerError.restoreFailed(underlying: restoreError)
            }
            throw DatabaseManagerError.migrationFailed(underlying: error)
        }
    }

    private static func migrateInPlace(dbPool: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
    }

    // MARK: - Logbook CRUD

    /// Creates a QSO record, optionally with extended fields.
    public func createQSO(_ qso: QSO, extended: QSOExtended? = nil) async throws {
        try await dbPool.write { db in
            try qso.insert(db)
            if let extended {
                try extended.insert(db)
            }
        }
    }

    /// Updates an existing QSO record.
    public func updateQSO(_ qso: QSO) async throws {
        try await dbPool.write { db in
            try qso.update(db)
        }
    }

    /// Deletes a QSO by its ID. Cascading delete removes qso_extended.
    public func deleteQSO(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try QSO.deleteOne(db, id: id)
        }
    }

    /// Deletes multiple QSOs by their IDs.
    public func deleteQSOs(ids: [UUID]) async throws {
        try await dbPool.write { db in
            _ = try QSO.deleteAll(db, ids: ids)
        }
    }

    /// Fetches a single QSO by ID.
    public func fetchQSO(id: UUID) async throws -> QSO? {
        try await dbPool.read { db in
            try QSO.fetchOne(db, id: id)
        }
    }

    /// Fetches a QSO and its extended record.
    public func fetchQSOWithExtended(id: UUID) async throws -> (QSO, QSOExtended?)? {
        try await dbPool.read { db in
            guard let qso = try QSO.fetchOne(db, id: id) else { return nil }
            let extended = try QSOExtended.fetchOne(db, key: ["qso_id": id])
            return (qso, extended)
        }
    }

    // MARK: - Query Methods

    /// Fetches QSOs with optional filtering, sorting, and pagination.
    public func fetchQSOs(
        logbookId: UUID? = nil,
        band: Band? = nil,
        mode: OperatingMode? = nil,
        callsignContains: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        sortBy: QSOSortField = .datetimeOn,
        ascending: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [QSO] {
        try await dbPool.read { db in
            var request = QSO.all()

            if let logbookId {
                request = request.filter(Column("logbook_id") == logbookId)
            }
            if let band {
                request = request.filter(Column("band") == band.rawValue)
            }
            if let mode {
                request = request.filter(Column("mode") == mode.rawValue)
            }
            if let callsignContains, !callsignContains.isEmpty {
                request = request.filter(Column("callsign").like("%\(callsignContains)%"))
            }
            if let dateRange {
                request = request.filter(
                    Column("datetime_on") >= dateRange.lowerBound
                    && Column("datetime_on") <= dateRange.upperBound
                )
            }

            let ordering: SQLOrderingTerm = ascending
                ? Column(sortBy.rawValue).asc
                : Column(sortBy.rawValue).desc

            return try request
                .order(ordering)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    /// Counts QSOs, optionally scoped to a logbook.
    public func countQSOs(logbookId: UUID? = nil) async throws -> Int {
        try await dbPool.read { db in
            var request = QSO.all()
            if let logbookId {
                request = request.filter(Column("logbook_id") == logbookId)
            }
            return try request.fetchCount(db)
        }
    }

    // MARK: - Dupe Checking

    /// Checks for a duplicate QSO matching the given callsign, band, mode, and time window.
    /// Returns the existing QSO if a duplicate is found, otherwise nil.
    public func checkDuplicate(
        callsign: String,
        band: Band,
        mode: OperatingMode,
        date: Date,
        windowMinutes: Int = 30
    ) async throws -> QSO? {
        let windowStart = date.addingTimeInterval(-Double(windowMinutes) * 60)
        let windowEnd = date.addingTimeInterval(Double(windowMinutes) * 60)

        return try await dbPool.read { db in
            try QSO
                .filter(Column("callsign") == callsign)
                .filter(Column("band") == band.rawValue)
                .filter(Column("mode") == mode.rawValue)
                .filter(Column("datetime_on") >= windowStart)
                .filter(Column("datetime_on") <= windowEnd)
                .fetchOne(db)
        }
    }

    // MARK: - Callsign Cache

    /// Caches a callsign lookup result (insert or replace).
    public func cacheCallsign(_ cache: CallsignCache) async throws {
        try await dbPool.write { db in
            try cache.save(db)
        }
    }

    /// Fetches a cached callsign record. Returns nil if not found.
    public func fetchCachedCallsign(_ callsign: String) async throws -> CallsignCache? {
        try await dbPool.read { db in
            try CallsignCache.fetchOne(db, id: callsign)
        }
    }

    /// Prunes expired callsign cache entries. Returns the number of deleted rows.
    @discardableResult
    public func pruneExpiredCache() async throws -> Int {
        try await dbPool.write { db in
            try CallsignCache
                .filter(Column("expires_at") < Date())
                .deleteAll(db)
        }
    }

    // MARK: - DXCC

    /// Fetches a DXCC entity by its entity number.
    public func fetchDXCCEntity(id: Int) async throws -> DXCCEntity? {
        try await dbPool.read { db in
            try DXCCEntity.fetchOne(db, id: id)
        }
    }

    /// Fetches all DXCC entities.
    public func fetchAllDXCCEntities() async throws -> [DXCCEntity] {
        try await dbPool.read { db in
            try DXCCEntity.fetchAll(db)
        }
    }

    /// Upserts (insert or update) a batch of DXCC entities.
    public func upsertDXCCEntities(_ entities: [DXCCEntity]) async throws {
        try await dbPool.write { db in
            for entity in entities {
                try entity.save(db)
            }
        }
    }

    // MARK: - Awards

    /// Fetches award progress filtered by type, and optionally band and mode.
    public func fetchAwardProgress(
        type: String,
        band: Band? = nil,
        mode: OperatingMode? = nil
    ) async throws -> [AwardProgress] {
        try await dbPool.read { db in
            var request = AwardProgress.filter(Column("award_type") == type)
            if let band {
                request = request.filter(Column("band") == band.rawValue)
            }
            if let mode {
                request = request.filter(Column("mode") == mode.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    /// Updates (insert or replace) an award progress record.
    public func updateAwardProgress(_ progress: AwardProgress) async throws {
        try await dbPool.write { db in
            try progress.save(db)
        }
    }

    // MARK: - Logbook Management

    /// Creates a new logbook.
    public func createLogbook(_ logbook: Logbook) async throws {
        try await dbPool.write { db in
            try logbook.insert(db)
        }
    }

    /// Fetches all logbooks.
    public func fetchLogbooks() async throws -> [Logbook] {
        try await dbPool.read { db in
            try Logbook.fetchAll(db)
        }
    }

    /// Returns the default logbook. If none exists, creates one named "General".
    public func defaultLogbook() async throws -> Logbook {
        try await dbPool.write { db in
            if let existing = try Logbook.filter(Column("is_default") == true).fetchOne(db) {
                return existing
            }
            let logbook = Logbook(name: "General", isDefault: true)
            try logbook.insert(db)
            return logbook
        }
    }

    // MARK: - Observation

    /// Returns an `AsyncStream` that emits arrays of QSOs whenever the qso table changes.
    /// Supports the same filtering as `fetchQSOs`.
    public func observeQSOs(
        logbookId: UUID? = nil,
        band: Band? = nil,
        mode: OperatingMode? = nil,
        callsignContains: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        sortBy: QSOSortField = .datetimeOn,
        ascending: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) -> AsyncStream<[QSO]> {
        let pool = dbPool
        return AsyncStream { continuation in
            let observation = ValueObservation.tracking { db -> [QSO] in
                var request = QSO.all()

                if let logbookId {
                    request = request.filter(Column("logbook_id") == logbookId)
                }
                if let band {
                    request = request.filter(Column("band") == band.rawValue)
                }
                if let mode {
                    request = request.filter(Column("mode") == mode.rawValue)
                }
                if let callsignContains, !callsignContains.isEmpty {
                    request = request.filter(Column("callsign").like("%\(callsignContains)%"))
                }
                if let dateRange {
                    request = request.filter(
                        Column("datetime_on") >= dateRange.lowerBound
                        && Column("datetime_on") <= dateRange.upperBound
                    )
                }

                let ordering: SQLOrderingTerm = ascending
                    ? Column(sortBy.rawValue).asc
                    : Column(sortBy.rawValue).desc

                return try request
                    .order(ordering)
                    .limit(limit, offset: offset)
                    .fetchAll(db)
            }

            let cancellable = observation.start(
                in: pool,
                onError: { _ in continuation.finish() },
                onChange: { qsos in continuation.yield(qsos) }
            )

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
