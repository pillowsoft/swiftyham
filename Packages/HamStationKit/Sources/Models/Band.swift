import Foundation

/// Amateur radio frequency bands from 160 meters through 23 centimeters.
public enum Band: String, CaseIterable, Codable, Sendable {
    case band160m = "160m"
    case band80m = "80m"
    case band60m = "60m"
    case band40m = "40m"
    case band30m = "30m"
    case band20m = "20m"
    case band17m = "17m"
    case band15m = "15m"
    case band12m = "12m"
    case band10m = "10m"
    case band6m = "6m"
    case band2m = "2m"
    case band70cm = "70cm"
    case band23cm = "23cm"

    /// The frequency range of this band in Hz.
    public var frequencyRange: ClosedRange<Double> {
        switch self {
        case .band160m: return 1_800_000...2_000_000
        case .band80m:  return 3_500_000...4_000_000
        case .band60m:  return 5_330_500...5_405_000
        case .band40m:  return 7_000_000...7_300_000
        case .band30m:  return 10_100_000...10_150_000
        case .band20m:  return 14_000_000...14_350_000
        case .band17m:  return 18_068_000...18_168_000
        case .band15m:  return 21_000_000...21_450_000
        case .band12m:  return 24_890_000...24_990_000
        case .band10m:  return 28_000_000...29_700_000
        case .band6m:   return 50_000_000...54_000_000
        case .band2m:   return 144_000_000...148_000_000
        case .band70cm: return 420_000_000...450_000_000
        case .band23cm: return 1_240_000_000...1_300_000_000
        }
    }

    /// Human-readable display name for the band.
    public var displayName: String {
        rawValue
    }

    /// Returns the band that contains the given frequency in Hz, if any.
    public static func band(forFrequency hz: Double) -> Band? {
        allCases.first { $0.frequencyRange.contains(hz) }
    }
}
