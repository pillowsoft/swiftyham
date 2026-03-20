import Foundation

/// The connection state of a rig or network service.
public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}
