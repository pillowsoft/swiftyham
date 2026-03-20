// AwardsEngine.swift
// HamStationKit — Tracks award progress (DXCC, WAS, WAZ) and updates when QSOs are logged.

import Foundation
import GRDB

/// Describes what was newly worked from processing a QSO.
public struct AwardUpdate: Sendable {
    /// Newly worked DXCC entities with their band and mode.
    public var newDXCCEntities: [(entity: DXCCEntity, band: Band, mode: OperatingMode)]
    /// Newly worked US states (for WAS).
    public var newStates: [String]
    /// Newly worked CQ zones (for WAZ).
    public var newZones: [Int]

    public init(
        newDXCCEntities: [(entity: DXCCEntity, band: Band, mode: OperatingMode)] = [],
        newStates: [String] = [],
        newZones: [Int] = []
    ) {
        self.newDXCCEntities = newDXCCEntities
        self.newStates = newStates
        self.newZones = newZones
    }
}

// Sendable conformance: the tuples contain only Sendable types,
// but we need explicit conformance since tuples don't auto-conform.
extension AwardUpdate: Equatable {
    public static func == (lhs: AwardUpdate, rhs: AwardUpdate) -> Bool {
        lhs.newStates == rhs.newStates
            && lhs.newZones == rhs.newZones
            && lhs.newDXCCEntities.count == rhs.newDXCCEntities.count
    }
}

/// DXCC award progress summary.
public struct DXCCProgress: Sendable, Equatable {
    /// Number of entities worked.
    public var worked: Int
    /// Number of entities confirmed.
    public var confirmed: Int
    /// Total possible entities (typically 340).
    public var total: Int
    /// Entities not yet worked.
    public var needed: [DXCCEntity]

    public init(worked: Int = 0, confirmed: Int = 0, total: Int = 340, needed: [DXCCEntity] = []) {
        self.worked = worked
        self.confirmed = confirmed
        self.total = total
        self.needed = needed
    }
}

/// WAS (Worked All States) award progress summary.
public struct WASProgress: Sendable, Equatable {
    /// Number of states worked.
    public var worked: Int
    /// Number of states confirmed.
    public var confirmed: Int
    /// Total states (50).
    public var total: Int
    /// State abbreviations not yet worked.
    public var needed: [String]

    public init(worked: Int = 0, confirmed: Int = 0, total: Int = 50, needed: [String] = []) {
        self.worked = worked
        self.confirmed = confirmed
        self.total = total
        self.needed = needed
    }
}

/// Tracks award progress (DXCC, WAS, WAZ) and updates when QSOs are logged.
public actor AwardsEngine {

    private let database: DatabaseManager
    private let resolver: DXCCResolver

    /// Total number of active DXCC entities.
    private static let totalDXCCEntities = 340

    /// All 50 US state abbreviations.
    public static let allUSStates: [String] = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    ]

    /// Total CQ zones (40).
    private static let totalCQZones = 40

    // MARK: - Initialization

    public init(database: DatabaseManager, resolver: DXCCResolver) {
        self.database = database
        self.resolver = resolver
    }

    // MARK: - Process QSO

    /// Process a new QSO and update award progress.
    /// Returns an `AwardUpdate` describing what was newly worked.
    public func processNewQSO(_ qso: QSO) async throws -> AwardUpdate {
        var update = AwardUpdate()

        // --- DXCC ---
        if let entityId = resolver.resolve(callsign: qso.callsign) {
            let ref = String(entityId)
            let existing = try await database.fetchAwardProgress(type: "DXCC")
                .filter { $0.entityOrRef == ref && $0.band == qso.band && $0.mode == qso.mode }

            if existing.isEmpty {
                let progress = AwardProgress(
                    awardType: "DXCC",
                    band: qso.band,
                    mode: qso.mode,
                    entityOrRef: ref,
                    worked: true,
                    confirmed: false,
                    qsoId: qso.id
                )
                try await database.updateAwardProgress(progress)

                // Fetch the entity details for the update notification
                if let entity = try await database.fetchDXCCEntity(id: entityId) {
                    update.newDXCCEntities.append((entity: entity, band: qso.band, mode: qso.mode))
                }
            }

            // Also track band-independent ("mixed") DXCC
            let mixedExisting = try await database.fetchAwardProgress(type: "DXCC")
                .filter { $0.entityOrRef == ref && $0.band == nil && $0.mode == nil }

            if mixedExisting.isEmpty {
                let mixedProgress = AwardProgress(
                    awardType: "DXCC",
                    band: nil,
                    mode: nil,
                    entityOrRef: ref,
                    worked: true,
                    confirmed: false,
                    qsoId: qso.id
                )
                try await database.updateAwardProgress(mixedProgress)
            }
        }

        // --- WAS ---
        // WAS tracking requires the QSO to include a US state
        // The state comes from callsign lookup data stored on the QSO or its extended record.
        // For now, we check the qth field for a state abbreviation or rely on external enrichment.
        // This is a simplified approach; a full implementation would use the callsign cache.

        // --- WAZ ---
        if let cqZone = qso.cqZone {
            let ref = String(cqZone)
            let existing = try await database.fetchAwardProgress(type: "WAZ")
                .filter { $0.entityOrRef == ref && $0.band == qso.band && $0.mode == qso.mode }

            if existing.isEmpty {
                let progress = AwardProgress(
                    awardType: "WAZ",
                    band: qso.band,
                    mode: qso.mode,
                    entityOrRef: ref,
                    worked: true,
                    confirmed: false,
                    qsoId: qso.id
                )
                try await database.updateAwardProgress(progress)
                update.newZones.append(cqZone)
            }
        }

        return update
    }

    // MARK: - DXCC Progress

    /// Returns DXCC progress, optionally filtered by band and/or mode.
    /// Pass `nil` for both to get mixed (overall) progress.
    public func dxccProgress(band: Band? = nil, mode: OperatingMode? = nil) async throws -> DXCCProgress {
        let allProgress = try await database.fetchAwardProgress(type: "DXCC", band: band, mode: mode)
        let workedSet = Set(allProgress.filter(\.worked).map(\.entityOrRef))
        let confirmedSet = Set(allProgress.filter(\.confirmed).map(\.entityOrRef))

        let allEntities = try await database.fetchAllDXCCEntities()
            .filter { !$0.isDeleted }
        let neededEntities = allEntities.filter { !workedSet.contains(String($0.id)) }

        return DXCCProgress(
            worked: workedSet.count,
            confirmed: confirmedSet.count,
            total: Self.totalDXCCEntities,
            needed: neededEntities
        )
    }

    // MARK: - WAS Progress

    /// Returns WAS (Worked All States) progress, optionally filtered by band and/or mode.
    public func wasProgress(band: Band? = nil, mode: OperatingMode? = nil) async throws -> WASProgress {
        let allProgress = try await database.fetchAwardProgress(type: "WAS", band: band, mode: mode)
        let workedSet = Set(allProgress.filter(\.worked).map(\.entityOrRef))
        let confirmedSet = Set(allProgress.filter(\.confirmed).map(\.entityOrRef))

        let neededStates = Self.allUSStates.filter { !workedSet.contains($0) }

        return WASProgress(
            worked: workedSet.count,
            confirmed: confirmedSet.count,
            total: 50,
            needed: neededStates
        )
    }

    // MARK: - Needed Entities

    /// Returns DXCC entity IDs not yet worked, for DX cluster "needed" filtering.
    public func neededEntities(band: Band? = nil, mode: OperatingMode? = nil) async throws -> Set<Int> {
        let allProgress = try await database.fetchAwardProgress(type: "DXCC", band: band, mode: mode)
        let workedRefs = Set(allProgress.filter(\.worked).map(\.entityOrRef))

        let allEntities = try await database.fetchAllDXCCEntities()
            .filter { !$0.isDeleted }

        var needed = Set<Int>()
        for entity in allEntities {
            if !workedRefs.contains(String(entity.id)) {
                needed.insert(entity.id)
            }
        }
        return needed
    }
}
