import XCTest
import Foundation
import GRDB
@testable import HamStationKit

// MARK: - Helpers

private func makeManager() throws -> DatabaseManager {
    try DatabaseManager(inMemory: true)
}

private func makeSampleQSO(
    callsign: String = "W1AW",
    band: Band = .band20m,
    mode: OperatingMode = .ssb,
    datetimeOn: Date = Date(),
    logbookId: UUID? = nil
) -> QSO {
    QSO(
        callsign: callsign,
        myCallsign: "N0CALL",
        band: band,
        frequencyHz: 14_074_000,
        mode: mode,
        datetimeOn: datetimeOn,
        rstSent: "59",
        rstReceived: "59",
        logbookId: logbookId
    )
}

private func makeSampleExtended(qsoId: UUID) -> QSOExtended {
    QSOExtended(
        qsoId: qsoId,
        propagationMode: "F2",
        contestId: "CQ-WW-SSB",
        sotaRef: "W4C/CM-001",
        lotwSent: true,
        lotwReceived: false
    )
}

// MARK: - QSO CRUD Tests

class QSOCRUDTests: XCTestCase {

    func testCreateAndFetchQSO() async throws {
        let db = try makeManager()
        let qso = makeSampleQSO()

        try await db.createQSO(qso)
        let fetched = try await db.fetchQSO(id: qso.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.callsign, "W1AW")
        XCTAssertEqual(fetched?.band, .band20m)
        XCTAssertEqual(fetched?.mode, .ssb)
    }

    func testCreateQSOWithExtended() async throws {
        let db = try makeManager()
        let qso = makeSampleQSO()
        let ext = makeSampleExtended(qsoId: qso.id)

        try await db.createQSO(qso, extended: ext)
        let result = try await db.fetchQSOWithExtended(id: qso.id)

        XCTAssertNotNil(result)
        let (fetchedQSO, fetchedExt) = result!
        XCTAssertEqual(fetchedQSO.callsign, "W1AW")
        XCTAssertNotNil(fetchedExt)
        XCTAssertEqual(fetchedExt?.propagationMode, "F2")
        XCTAssertEqual(fetchedExt?.contestId, "CQ-WW-SSB")
        XCTAssertEqual(fetchedExt?.sotaRef, "W4C/CM-001")
        XCTAssertEqual(fetchedExt?.lotwSent, true)
    }

    func testUpdateQSO() async throws {
        let db = try makeManager()
        var qso = makeSampleQSO()
        try await db.createQSO(qso)

        qso.rstSent = "57"
        qso.comment = "Updated"
        try await db.updateQSO(qso)

        let fetched = try await db.fetchQSO(id: qso.id)
        XCTAssertEqual(fetched?.rstSent, "57")
        XCTAssertEqual(fetched?.comment, "Updated")
    }

    func testDeleteSingleQSOCascades() async throws {
        let db = try makeManager()
        let qso = makeSampleQSO()
        let ext = makeSampleExtended(qsoId: qso.id)
        try await db.createQSO(qso, extended: ext)

        try await db.deleteQSO(id: qso.id)

        let fetchedQSO = try await db.fetchQSO(id: qso.id)
        let fetchedPair = try await db.fetchQSOWithExtended(id: qso.id)
        XCTAssertNil(fetchedQSO)
        XCTAssertNil(fetchedPair)
    }

    func testDeleteMultipleQSOs() async throws {
        let db = try makeManager()
        let qso1 = makeSampleQSO(callsign: "AA1AA")
        let qso2 = makeSampleQSO(callsign: "BB2BB")
        let qso3 = makeSampleQSO(callsign: "CC3CC")
        try await db.createQSO(qso1)
        try await db.createQSO(qso2)
        try await db.createQSO(qso3)

        try await db.deleteQSOs(ids: [qso1.id, qso2.id])

        let count = try await db.countQSOs()
        XCTAssertEqual(count, 1)
        let remaining = try await db.fetchQSO(id: qso3.id)
        XCTAssertNotNil(remaining)
    }

    func testFetchNonExistentQSO() async throws {
        let db = try makeManager()
        let result = try await db.fetchQSO(id: UUID())
        XCTAssertNil(result)
    }
}

// MARK: - Query / Filter Tests

class QSOQueryTests: XCTestCase {

    func testFilterByBand() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "A1A", band: .band20m))
        try await db.createQSO(makeSampleQSO(callsign: "B2B", band: .band40m))
        try await db.createQSO(makeSampleQSO(callsign: "C3C", band: .band20m))

        let results = try await db.fetchQSOs(band: .band20m)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.band == .band20m })
    }

    func testFilterByMode() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "A1A", mode: .ft8))
        try await db.createQSO(makeSampleQSO(callsign: "B2B", mode: .ssb))

        let results = try await db.fetchQSOs(mode: .ft8)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].callsign, "A1A")
    }

    func testFilterByCallsign() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "W1AW"))
        try await db.createQSO(makeSampleQSO(callsign: "K1ABC"))
        try await db.createQSO(makeSampleQSO(callsign: "W1XYZ"))

        let results = try await db.fetchQSOs(callsignContains: "W1")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterByDateRange() async throws {
        let db = try makeManager()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        let threeDaysAgo = now.addingTimeInterval(-259200)

        try await db.createQSO(makeSampleQSO(callsign: "OLD", datetimeOn: threeDaysAgo))
        try await db.createQSO(makeSampleQSO(callsign: "MID", datetimeOn: yesterday))
        try await db.createQSO(makeSampleQSO(callsign: "NEW", datetimeOn: now))

        let results = try await db.fetchQSOs(dateRange: twoDaysAgo...now)
        XCTAssertEqual(results.count, 2)
    }

    func testSortByCallsignAscending() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "ZZ9ZZ"))
        try await db.createQSO(makeSampleQSO(callsign: "AA1AA"))
        try await db.createQSO(makeSampleQSO(callsign: "MM5MM"))

        let results = try await db.fetchQSOs(sortBy: .callsign, ascending: true)
        XCTAssertEqual(results[0].callsign, "AA1AA")
        XCTAssertEqual(results[1].callsign, "MM5MM")
        XCTAssertEqual(results[2].callsign, "ZZ9ZZ")
    }

    func testSortByDateDescending() async throws {
        let db = try makeManager()
        let now = Date()
        try await db.createQSO(makeSampleQSO(callsign: "OLD", datetimeOn: now.addingTimeInterval(-100)))
        try await db.createQSO(makeSampleQSO(callsign: "NEW", datetimeOn: now))

        let results = try await db.fetchQSOs(sortBy: .datetimeOn, ascending: false)
        XCTAssertEqual(results[0].callsign, "NEW")
        XCTAssertEqual(results[1].callsign, "OLD")
    }

    func testSortByBand() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "A", band: .band40m))
        try await db.createQSO(makeSampleQSO(callsign: "B", band: .band20m))
        try await db.createQSO(makeSampleQSO(callsign: "C", band: .band80m))

        let results = try await db.fetchQSOs(sortBy: .band, ascending: true)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].band, .band20m)
        XCTAssertEqual(results[1].band, .band40m)
        XCTAssertEqual(results[2].band, .band80m)
    }

    func testSortByMode() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "A", mode: .ssb))
        try await db.createQSO(makeSampleQSO(callsign: "B", mode: .cw))
        try await db.createQSO(makeSampleQSO(callsign: "C", mode: .ft8))

        let results = try await db.fetchQSOs(sortBy: .mode, ascending: true)
        XCTAssertEqual(results[0].mode, .cw)
        XCTAssertEqual(results[1].mode, .ft8)
        XCTAssertEqual(results[2].mode, .ssb)
    }

    func testPagination() async throws {
        let db = try makeManager()
        for i in 0..<10 {
            let date = Date().addingTimeInterval(Double(i) * 60)
            try await db.createQSO(makeSampleQSO(callsign: "CALL\(i)", datetimeOn: date))
        }

        let page1 = try await db.fetchQSOs(sortBy: .datetimeOn, ascending: true, limit: 3, offset: 0)
        let page2 = try await db.fetchQSOs(sortBy: .datetimeOn, ascending: true, limit: 3, offset: 3)

        XCTAssertEqual(page1.count, 3)
        XCTAssertEqual(page2.count, 3)
        XCTAssertEqual(page1[0].callsign, "CALL0")
        XCTAssertEqual(page2[0].callsign, "CALL3")
    }

    func testCountQSOs() async throws {
        let db = try makeManager()
        try await db.createQSO(makeSampleQSO(callsign: "A"))
        try await db.createQSO(makeSampleQSO(callsign: "B"))
        try await db.createQSO(makeSampleQSO(callsign: "C"))

        let count = try await db.countQSOs()
        XCTAssertEqual(count, 3)
    }

    func testFilterByLogbook() async throws {
        let db = try makeManager()
        let logbook = Logbook(name: "Contest")
        try await db.createLogbook(logbook)

        try await db.createQSO(makeSampleQSO(callsign: "A", logbookId: logbook.id))
        try await db.createQSO(makeSampleQSO(callsign: "B", logbookId: logbook.id))
        try await db.createQSO(makeSampleQSO(callsign: "C"))

        let results = try await db.fetchQSOs(logbookId: logbook.id)
        XCTAssertEqual(results.count, 2)
    }
}

// MARK: - Dupe Checking Tests

class DupeCheckTests: XCTestCase {

    func testDupeFound() async throws {
        let db = try makeManager()
        let now = Date()
        let qso = makeSampleQSO(callsign: "W1AW", band: .band20m, mode: .ssb, datetimeOn: now)
        try await db.createQSO(qso)

        let dupe = try await db.checkDuplicate(
            callsign: "W1AW",
            band: .band20m,
            mode: .ssb,
            date: now.addingTimeInterval(600)
        )
        XCTAssertNotNil(dupe)
        XCTAssertEqual(dupe?.id, qso.id)
    }

    func testNoDupeDifferentBand() async throws {
        let db = try makeManager()
        let now = Date()
        try await db.createQSO(makeSampleQSO(callsign: "W1AW", band: .band20m, mode: .ssb, datetimeOn: now))

        let dupe = try await db.checkDuplicate(
            callsign: "W1AW",
            band: .band40m,
            mode: .ssb,
            date: now
        )
        XCTAssertNil(dupe)
    }

    func testNoDupeOutsideWindow() async throws {
        let db = try makeManager()
        let now = Date()
        try await db.createQSO(makeSampleQSO(callsign: "W1AW", band: .band20m, mode: .ssb, datetimeOn: now))

        let dupe = try await db.checkDuplicate(
            callsign: "W1AW",
            band: .band20m,
            mode: .ssb,
            date: now.addingTimeInterval(3600),
            windowMinutes: 30
        )
        XCTAssertNil(dupe)
    }

    func testNoDupeDifferentMode() async throws {
        let db = try makeManager()
        let now = Date()
        try await db.createQSO(makeSampleQSO(callsign: "W1AW", band: .band20m, mode: .ssb, datetimeOn: now))

        let dupe = try await db.checkDuplicate(
            callsign: "W1AW",
            band: .band20m,
            mode: .cw,
            date: now
        )
        XCTAssertNil(dupe)
    }
}

// MARK: - Callsign Cache Tests

class CallsignCacheTests: XCTestCase {

    func testStoreAndRetrieve() async throws {
        let db = try makeManager()
        let cache = CallsignCache(
            callsign: "W1AW",
            name: "ARRL HQ",
            country: "United States",
            source: "hamdb"
        )
        try await db.cacheCallsign(cache)

        let fetched = try await db.fetchCachedCallsign("W1AW")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "ARRL HQ")
        XCTAssertEqual(fetched?.country, "United States")
        XCTAssertEqual(fetched?.source, "hamdb")
    }

    func testExpiredEntry() async throws {
        let db = try makeManager()
        let cache = CallsignCache(
            callsign: "VK3ABC",
            source: "qrz",
            fetchedAt: Date().addingTimeInterval(-86400 * 60),
            expiresAt: Date().addingTimeInterval(-86400)
        )
        try await db.cacheCallsign(cache)

        let fetched = try await db.fetchCachedCallsign("VK3ABC")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.isExpired, true)
    }

    func testPruneExpired() async throws {
        let db = try makeManager()

        let expired = CallsignCache(
            callsign: "OLD1",
            source: "hamdb",
            expiresAt: Date().addingTimeInterval(-86400)
        )
        let valid = CallsignCache(
            callsign: "NEW1",
            source: "hamdb",
            expiresAt: Date().addingTimeInterval(86400)
        )
        try await db.cacheCallsign(expired)
        try await db.cacheCallsign(valid)

        let pruned = try await db.pruneExpiredCache()
        XCTAssertEqual(pruned, 1)

        let remaining = try await db.fetchCachedCallsign("NEW1")
        XCTAssertNotNil(remaining)
        let gone = try await db.fetchCachedCallsign("OLD1")
        XCTAssertNil(gone)
    }
}

// MARK: - DXCC Tests

class DXCCTests: XCTestCase {

    func testUpsertAndFetch() async throws {
        let db = try makeManager()
        let entity = DXCCEntity(
            id: 291,
            name: "United States",
            prefix: "K",
            continent: "NA",
            cqZone: 5,
            ituZone: 8,
            latitude: 37.0,
            longitude: -95.0
        )
        try await db.upsertDXCCEntities([entity])

        let fetched = try await db.fetchDXCCEntity(id: 291)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "United States")
        XCTAssertEqual(fetched?.prefix, "K")
    }

    func testUpsertUpdatesExisting() async throws {
        let db = try makeManager()
        var entity = DXCCEntity(
            id: 100,
            name: "Argentina",
            prefix: "LU",
            continent: "SA",
            cqZone: 13,
            ituZone: 14
        )
        try await db.upsertDXCCEntities([entity])

        entity.name = "Argentine Republic"
        try await db.upsertDXCCEntities([entity])

        let fetched = try await db.fetchDXCCEntity(id: 100)
        XCTAssertEqual(fetched?.name, "Argentine Republic")
    }

    func testFetchAll() async throws {
        let db = try makeManager()
        let entities = [
            DXCCEntity(id: 1, name: "Canada", prefix: "VE", continent: "NA", cqZone: 5, ituZone: 2),
            DXCCEntity(id: 2, name: "Japan", prefix: "JA", continent: "AS", cqZone: 25, ituZone: 45),
        ]
        try await db.upsertDXCCEntities(entities)

        let all = try await db.fetchAllDXCCEntities()
        XCTAssertEqual(all.count, 2)
    }
}

// MARK: - Award Progress Tests

class AwardProgressTests: XCTestCase {

    func testCreateAndQueryByType() async throws {
        let db = try makeManager()
        let progress = AwardProgress(
            awardType: "DXCC",
            entityOrRef: "291",
            worked: true,
            confirmed: false
        )
        try await db.updateAwardProgress(progress)

        let results = try await db.fetchAwardProgress(type: "DXCC")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].entityOrRef, "291")
        XCTAssertEqual(results[0].worked, true)
    }

    func testFilterByBandAndMode() async throws {
        let db = try makeManager()
        let p1 = AwardProgress(awardType: "DXCC", band: .band20m, mode: .ssb, entityOrRef: "291", worked: true)
        let p2 = AwardProgress(awardType: "DXCC", band: .band20m, mode: .cw, entityOrRef: "291", worked: true)
        let p3 = AwardProgress(awardType: "DXCC", band: .band40m, mode: .ssb, entityOrRef: "291", worked: true)
        try await db.updateAwardProgress(p1)
        try await db.updateAwardProgress(p2)
        try await db.updateAwardProgress(p3)

        let results = try await db.fetchAwardProgress(type: "DXCC", band: .band20m, mode: .ssb)
        XCTAssertEqual(results.count, 1)
    }
}

// MARK: - Logbook Tests

class LogbookTests: XCTestCase {

    func testCreateAndFetch() async throws {
        let db = try makeManager()
        let logbook = Logbook(name: "Field Day 2025")
        try await db.createLogbook(logbook)

        let all = try await db.fetchLogbooks()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].name, "Field Day 2025")
    }

    func testDefaultLogbookCreated() async throws {
        let db = try makeManager()
        let def = try await db.defaultLogbook()
        XCTAssertEqual(def.name, "General")
        XCTAssertEqual(def.isDefault, true)
    }

    func testDefaultLogbookReturnsExisting() async throws {
        let db = try makeManager()
        let custom = Logbook(name: "My Default", isDefault: true)
        try await db.createLogbook(custom)

        let def = try await db.defaultLogbook()
        XCTAssertEqual(def.id, custom.id)
        XCTAssertEqual(def.name, "My Default")
    }
}

// MARK: - Migration Tests

class MigrationTests: XCTestCase {

    func testV1CreatesAllTables() async throws {
        let db = try makeManager()
        let tables: [String] = try await db.dbPool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'grdb_migrations' ORDER BY name"
            )
        }

        XCTAssertTrue(tables.contains("logbook"))
        XCTAssertTrue(tables.contains("qso"))
        XCTAssertTrue(tables.contains("qso_extended"))
        XCTAssertTrue(tables.contains("dxcc_entity"))
        XCTAssertTrue(tables.contains("callsign_cache"))
        XCTAssertTrue(tables.contains("award_progress"))
    }

    func testV1CreatesAllIndexes() async throws {
        let db = try makeManager()
        let indexes: [String] = try await db.dbPool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name"
            )
        }

        XCTAssertTrue(indexes.contains("idx_qso_datetime_on"))
        XCTAssertTrue(indexes.contains("idx_qso_callsign"))
        XCTAssertTrue(indexes.contains("idx_qso_band_mode"))
        XCTAssertTrue(indexes.contains("idx_qso_dxcc_entity_id"))
        XCTAssertTrue(indexes.contains("idx_qso_logbook_id"))
        XCTAssertTrue(indexes.contains("idx_callsign_cache_expires_at"))
        XCTAssertTrue(indexes.contains("idx_award_progress_type_band_mode"))
    }

    func testBackupCreatedDuringMigration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.sqlite").path
        FileManager.default.createFile(atPath: dbPath, contents: nil)

        let _ = try DatabaseManager(path: dbPath)

        let backupExists = FileManager.default.fileExists(atPath: dbPath + ".backup")
        XCTAssertEqual(backupExists, true)
    }
}

// MARK: - Concurrency & Performance Tests

class ConcurrencyTests: XCTestCase {

    func testConcurrentReads() async throws {
        let db = try makeManager()
        for i in 0..<5 {
            try await db.createQSO(makeSampleQSO(callsign: "READ\(i)"))
        }

        async let count1 = db.countQSOs()
        async let count2 = db.countQSOs()
        async let fetch1 = db.fetchQSOs(limit: 10)

        let (c1, c2, f1) = try await (count1, count2, fetch1)
        XCTAssertEqual(c1, 5)
        XCTAssertEqual(c2, 5)
        XCTAssertEqual(f1.count, 5)
    }

    func testBulkInsertPerformance() async throws {
        let db = try makeManager()
        let baseDate = Date()

        for i in 0..<1000 {
            let qso = QSO(
                callsign: "PERF\(i)",
                myCallsign: "N0CALL",
                band: Band.allCases[i % Band.allCases.count],
                frequencyHz: 14_074_000,
                mode: .ft8,
                datetimeOn: baseDate.addingTimeInterval(Double(i)),
                rstSent: "-10",
                rstReceived: "-12"
            )
            try await db.createQSO(qso)
        }

        let count = try await db.countQSOs()
        XCTAssertEqual(count, 1000)
    }
}

// MARK: - Observation Tests

class ObservationTests: XCTestCase {

    func testObserveEmitsUpdates() async throws {
        let db = try makeManager()

        let stream = await db.observeQSOs(sortBy: .datetimeOn, ascending: true, limit: 100)
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertNotNil(initial)
        XCTAssertEqual(initial?.isEmpty, true)

        try await db.createQSO(makeSampleQSO(callsign: "OBS1"))

        let updated = await iterator.next()
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.count, 1)
        XCTAssertEqual(updated?[0].callsign, "OBS1")
    }
}
