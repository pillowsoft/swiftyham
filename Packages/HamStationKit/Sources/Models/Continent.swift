import Foundation

/// ITU continent codes used in DXCC and amateur radio.
public enum Continent: String, CaseIterable, Codable, Sendable {
    case af = "AF"
    case an = "AN"
    case `as` = "AS"
    case eu = "EU"
    case na = "NA"
    case oc = "OC"
    case sa = "SA"

    /// Human-readable continent name.
    public var displayName: String {
        switch self {
        case .af: return "Africa"
        case .an: return "Antarctica"
        case .as: return "Asia"
        case .eu: return "Europe"
        case .na: return "North America"
        case .oc: return "Oceania"
        case .sa: return "South America"
        }
    }
}
