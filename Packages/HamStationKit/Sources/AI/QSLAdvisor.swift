// QSLAdvisor.swift
// HamStationKit — Recommends QSL confirmation methods after a QSO.

import Foundation

/// Recommends the best QSL confirmation methods for a given contact,
/// considering electronic options, award needs, and available services.
public struct QSLAdvisor: Sendable {

    // MARK: - Types

    /// A QSL method recommendation with reasoning.
    public struct Recommendation: Sendable, Equatable, Identifiable {
        public let id: UUID
        public var method: QSLMethod
        public var reason: String
        public var priority: Int

        public init(id: UUID = UUID(), method: QSLMethod, reason: String, priority: Int) {
            self.id = id
            self.method = method
            self.reason = reason
            self.priority = priority
        }

        /// Available QSL confirmation methods.
        public enum QSLMethod: String, Sendable, CaseIterable {
            case lotw
            case eqsl
            case directCard
            case bureauCard
            case oqrs
            case clublog
        }
    }

    // MARK: - Recommendation Engine

    /// Generate QSL method recommendations for a given callsign.
    ///
    /// Priority order:
    /// 1. LoTW if they're enrolled (fastest, most widely accepted for awards)
    /// 2. eQSL (easy, electronic)
    /// 3. ClubLog OQRS (if available)
    /// 4. Direct card (if needed for award and no electronic option)
    /// 5. Bureau card (slow but free)
    ///
    /// - Parameters:
    ///   - callsign: The worked station's callsign.
    ///   - isOnLoTW: Whether the station is known to be on LoTW. `nil` if unknown.
    ///   - isNeededForAward: Whether this QSO is needed for an award (DXCC, WAS, etc.).
    ///   - hasQRZProfile: Whether the station has a QRZ.com profile.
    /// - Returns: Recommendations sorted by priority (1 = highest).
    public static func recommend(
        callsign: String,
        isOnLoTW: Bool?,
        isNeededForAward: Bool,
        hasQRZProfile: Bool
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        var currentPriority = 1

        // 1. LoTW — fastest and most widely accepted for ARRL awards
        if isOnLoTW == true {
            recommendations.append(Recommendation(
                method: .lotw,
                reason: "\(callsign) is on LoTW. Upload your log for the fastest confirmation, accepted for all ARRL awards.",
                priority: currentPriority
            ))
            currentPriority += 1
        } else if isOnLoTW == nil {
            recommendations.append(Recommendation(
                method: .lotw,
                reason: "Check if \(callsign) is on LoTW. It's the fastest path to a confirmed QSL for awards.",
                priority: currentPriority
            ))
            currentPriority += 1
        }

        // 2. eQSL — easy electronic option
        recommendations.append(Recommendation(
            method: .eqsl,
            reason: "eQSL is free and easy. Many operators check it. Not accepted for DXCC but good for eAwards.",
            priority: currentPriority
        ))
        currentPriority += 1

        // 3. ClubLog OQRS — convenient for DX
        recommendations.append(Recommendation(
            method: .clublog,
            reason: "Check ClubLog for \(callsign). Many DXpeditions and active DX stations use OQRS for card requests.",
            priority: currentPriority
        ))
        currentPriority += 1

        // 4. Direct card — important for rare entities or award needs
        if isNeededForAward {
            recommendations.append(Recommendation(
                method: .directCard,
                reason: "This QSO is needed for an award. A direct QSL card with SASE/SAE + green stamps is reliable when electronic options aren't available.",
                priority: currentPriority
            ))
            currentPriority += 1
        }

        // 5. Bureau card — slow but free
        recommendations.append(Recommendation(
            method: .bureauCard,
            reason: "Send via the QSL bureau. It's free but can take months to years. Good as a backup to electronic methods.",
            priority: currentPriority
        ))

        // If not needed for award but they're not on LoTW, add direct card at lower priority
        if !isNeededForAward, isOnLoTW != true {
            currentPriority += 1
            recommendations.append(Recommendation(
                method: .directCard,
                reason: "A direct card is optional for this contact since it's not needed for an award.",
                priority: currentPriority
            ))
        }

        return recommendations.sorted { $0.priority < $1.priority }
    }
}
