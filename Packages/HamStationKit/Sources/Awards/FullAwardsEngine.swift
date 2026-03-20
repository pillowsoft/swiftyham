// FullAwardsEngine.swift
// HamStationKit — Extended awards: IOTA, Grid Squares (VUCC), Counties, WAZ.

import Foundation

/// An IOTA (Islands on the Air) reference.
public struct IOTAReference: Sendable, Codable, Identifiable, Equatable {
    /// IOTA reference, e.g. "NA-001".
    public let id: String
    public var name: String
    public var dxccEntity: Int
    public var continent: String

    public init(id: String, name: String, dxccEntity: Int, continent: String) {
        self.id = id
        self.name = name
        self.dxccEntity = dxccEntity
        self.continent = continent
    }
}

/// Grid square award progress (e.g. VUCC).
public struct GridAward: Sendable, Equatable {
    /// 4-character Maidenhead grid squares worked.
    public var gridsWorked: Set<String>
    /// 4-character Maidenhead grid squares confirmed.
    public var gridsConfirmed: Set<String>
    /// Target number of grids for the award (e.g. 100 for VUCC).
    public var target: Int

    public init(gridsWorked: Set<String> = [], gridsConfirmed: Set<String> = [], target: Int = 100) {
        self.gridsWorked = gridsWorked
        self.gridsConfirmed = gridsConfirmed
        self.target = target
    }
}

/// US county award progress (USA-CA / CQ USA Counties Award).
public struct CountyAward: Sendable, Equatable {
    /// Counties worked in "STATE-COUNTY" format, e.g. "CT-HARTFORD".
    public var countiesWorked: Set<String>
    /// Counties confirmed.
    public var countiesConfirmed: Set<String>
    /// Total US counties (3077).
    public var totalCounties: Int

    public init(
        countiesWorked: Set<String> = [],
        countiesConfirmed: Set<String> = [],
        totalCounties: Int = 3077
    ) {
        self.countiesWorked = countiesWorked
        self.countiesConfirmed = countiesConfirmed
        self.totalCounties = totalCounties
    }
}

/// WAZ (Worked All Zones) progress — CQ zones 1-40.
public struct WAZProgress: Sendable, Equatable {
    /// CQ zones worked (1-40).
    public var zonesWorked: Set<Int>
    /// CQ zones confirmed.
    public var zonesConfirmed: Set<Int>
    /// Total CQ zones.
    public var total: Int { 40 }

    public init(zonesWorked: Set<Int> = [], zonesConfirmed: Set<Int> = []) {
        self.zonesWorked = zonesWorked
        self.zonesConfirmed = zonesConfirmed
    }
}

/// Calculates award progress from QSO data.
public struct AwardsCalculator: Sendable {

    public init() {}

    /// Calculate grid square (VUCC) progress from QSO data.
    ///
    /// - Parameter qsos: Array of tuples with optional grid and confirmation status.
    /// - Returns: Grid award progress.
    public static func calculateGridProgress(
        qsos: [(grid: String?, confirmed: Bool)]
    ) -> GridAward {
        var worked = Set<String>()
        var confirmed = Set<String>()

        for qso in qsos {
            guard let grid = qso.grid, grid.count >= 4 else { continue }
            let fourChar = String(grid.prefix(4)).uppercased()
            worked.insert(fourChar)
            if qso.confirmed {
                confirmed.insert(fourChar)
            }
        }

        return GridAward(gridsWorked: worked, gridsConfirmed: confirmed)
    }

    /// Calculate US county award progress from QSO data.
    ///
    /// - Parameter qsos: Array of tuples with optional county ("STATE-COUNTY") and confirmation.
    /// - Returns: County award progress.
    public static func calculateCountyProgress(
        qsos: [(county: String?, confirmed: Bool)]
    ) -> CountyAward {
        var worked = Set<String>()
        var confirmed = Set<String>()

        for qso in qsos {
            guard let county = qso.county, !county.isEmpty else { continue }
            let normalized = county.uppercased()
            worked.insert(normalized)
            if qso.confirmed {
                confirmed.insert(normalized)
            }
        }

        return CountyAward(countiesWorked: worked, countiesConfirmed: confirmed)
    }

    /// Calculate WAZ (Worked All Zones) progress from QSO data.
    ///
    /// - Parameter qsos: Array of tuples with optional CQ zone and confirmation.
    /// - Returns: WAZ progress.
    public static func calculateWAZProgress(
        qsos: [(cqZone: Int?, confirmed: Bool)]
    ) -> WAZProgress {
        var worked = Set<Int>()
        var confirmed = Set<Int>()

        for qso in qsos {
            guard let zone = qso.cqZone, (1...40).contains(zone) else { continue }
            worked.insert(zone)
            if qso.confirmed {
                confirmed.insert(zone)
            }
        }

        return WAZProgress(zonesWorked: worked, zonesConfirmed: confirmed)
    }
}
