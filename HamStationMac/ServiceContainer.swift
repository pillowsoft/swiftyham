// ServiceContainer.swift — Dependency injection root
// Creates and owns all HamStationKit backend actors.

import Foundation
import HamStationKit

@MainActor
final class ServiceContainer: Observable {
    let database: DatabaseManager
    let networkService: NetworkService
    let lookupPipeline: CallsignLookupPipeline
    let dxccResolver: DXCCResolver
    let awardsEngine: AwardsEngine
    let propagationDashboard: PropagationDashboard

    // Connected on demand
    private(set) var rigConnection: RigctldConnection?
    private(set) var clusterClient: ClusterClient?

    init() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dbDir = appSupport.appendingPathComponent("HamStationPro", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("hamstation.sqlite").path

        self.database = try DatabaseManager(path: dbPath)
        self.networkService = NetworkService()
        self.lookupPipeline = CallsignLookupPipeline(networkService: networkService)
        self.dxccResolver = DXCCResolver()
        self.awardsEngine = AwardsEngine(database: database, resolver: dxccResolver)
        self.propagationDashboard = PropagationDashboard(networkService: networkService)
    }

    // MARK: - Rig Connection

    func connectRig(host: String, port: UInt16) async throws {
        let connection = RigctldConnection(host: host, port: port)
        try await connection.connect()
        self.rigConnection = connection
    }

    func disconnectRig() async {
        if let rig = rigConnection {
            await rig.disconnect()
        }
        self.rigConnection = nil
    }

    // MARK: - Cluster Connection

    func connectCluster(host: String, port: UInt16, callsign: String) async throws {
        let client = ClusterClient(host: host, port: port, callsign: callsign)
        try await client.connect()
        self.clusterClient = client
    }

    func disconnectCluster() async {
        if let cluster = clusterClient {
            await cluster.disconnect()
        }
        self.clusterClient = nil
    }
}
