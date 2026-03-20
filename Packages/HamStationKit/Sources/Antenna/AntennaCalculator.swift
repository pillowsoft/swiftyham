// AntennaCalculator.swift
// HamStationKit — Antenna design and RF calculators.

import Foundation

/// A collection of antenna design and RF calculation tools.
public struct AntennaCalculator: Sendable {

    public init() {}

    // MARK: - Dipole

    /// Calculate total dipole length (tip to tip) in feet.
    ///
    /// Formula: 468 / frequencyMHz * velocityFactor
    /// - Parameters:
    ///   - frequencyMHz: Center frequency in MHz.
    ///   - velocityFactor: Wire velocity factor (default 0.95 for bare copper).
    /// - Returns: Total dipole length in feet.
    public static func dipoleLengthFeet(
        frequencyMHz: Double,
        velocityFactor: Double = 0.95
    ) -> Double {
        guard frequencyMHz > 0 else { return 0 }
        return 468.0 / frequencyMHz * velocityFactor
    }

    /// Calculate total dipole length (tip to tip) in meters.
    ///
    /// Formula: 142.65 / frequencyMHz * velocityFactor
    public static func dipoleLengthMeters(
        frequencyMHz: Double,
        velocityFactor: Double = 0.95
    ) -> Double {
        guard frequencyMHz > 0 else { return 0 }
        return 142.65 / frequencyMHz * velocityFactor
    }

    // MARK: - Quarter-Wave Vertical

    /// Calculate quarter-wave vertical antenna length in feet.
    ///
    /// Formula: 234 / frequencyMHz
    public static func quarterWaveVertical(frequencyMHz: Double) -> Double {
        guard frequencyMHz > 0 else { return 0 }
        return 234.0 / frequencyMHz
    }

    // MARK: - Coax Loss

    /// Coax cable types with loss characteristics.
    public enum CoaxType: String, Sendable, CaseIterable {
        case rg58
        case rg8x
        case rg213
        case lmr400
        case lmr600
        case hardline

        /// Loss per 100 feet at standard frequencies (MHz -> dB/100ft).
        public var lossPerHundredFeet: [Double: Double] {
            switch self {
            case .rg58:
                return [
                    1.0: 0.4, 3.5: 0.8, 7.0: 1.1, 14.0: 1.6, 21.0: 2.0,
                    28.0: 2.3, 50.0: 3.3, 144.0: 5.6, 440.0: 10.3
                ]
            case .rg8x:
                return [
                    1.0: 0.3, 3.5: 0.6, 7.0: 0.9, 14.0: 1.3, 21.0: 1.6,
                    28.0: 1.8, 50.0: 2.5, 144.0: 4.5, 440.0: 8.0
                ]
            case .rg213:
                return [
                    1.0: 0.2, 3.5: 0.4, 7.0: 0.6, 14.0: 0.8, 21.0: 1.0,
                    28.0: 1.2, 50.0: 1.6, 144.0: 2.8, 440.0: 5.1
                ]
            case .lmr400:
                return [
                    1.0: 0.1, 3.5: 0.2, 7.0: 0.3, 14.0: 0.4, 21.0: 0.5,
                    28.0: 0.6, 50.0: 0.8, 144.0: 1.3, 440.0: 2.4
                ]
            case .lmr600:
                return [
                    1.0: 0.07, 3.5: 0.13, 7.0: 0.19, 14.0: 0.27, 21.0: 0.34,
                    28.0: 0.39, 50.0: 0.52, 144.0: 0.9, 440.0: 1.6
                ]
            case .hardline:
                return [
                    1.0: 0.04, 3.5: 0.07, 7.0: 0.10, 14.0: 0.15, 21.0: 0.18,
                    28.0: 0.21, 50.0: 0.28, 144.0: 0.49, 440.0: 0.88
                ]
            }
        }
    }

    /// Calculate coax cable loss in dB.
    ///
    /// Interpolates between known frequency/loss data points.
    /// - Parameters:
    ///   - cableType: Type of coaxial cable.
    ///   - lengthFeet: Cable length in feet.
    ///   - frequencyMHz: Operating frequency in MHz.
    /// - Returns: Estimated loss in dB.
    public static func coaxLoss(
        cableType: CoaxType,
        lengthFeet: Double,
        frequencyMHz: Double
    ) -> Double {
        guard lengthFeet > 0, frequencyMHz > 0 else { return 0 }

        let table = cableType.lossPerHundredFeet
        let sortedFreqs = table.keys.sorted()

        // Find bracketing frequencies for interpolation
        let lossPerHundred: Double
        if let exact = table[frequencyMHz] {
            lossPerHundred = exact
        } else if frequencyMHz <= sortedFreqs.first! {
            lossPerHundred = table[sortedFreqs.first!]!
        } else if frequencyMHz >= sortedFreqs.last! {
            lossPerHundred = table[sortedFreqs.last!]!
        } else {
            // Linear interpolation
            var lower = sortedFreqs.first!
            var upper = sortedFreqs.last!
            for freq in sortedFreqs {
                if freq <= frequencyMHz { lower = freq }
                if freq >= frequencyMHz {
                    upper = freq
                    break
                }
            }
            let lowerLoss = table[lower]!
            let upperLoss = table[upper]!
            let fraction = (frequencyMHz - lower) / (upper - lower)
            lossPerHundred = lowerLoss + (upperLoss - lowerLoss) * fraction
        }

        return lossPerHundred * lengthFeet / 100.0
    }

    // MARK: - SWR Calculations

    /// Calculate SWR from forward and reflected power.
    ///
    /// SWR = (1 + sqrt(Pr/Pf)) / (1 - sqrt(Pr/Pf))
    public static func swr(forwardPower: Double, reflectedPower: Double) -> Double {
        guard forwardPower > 0 else { return .infinity }
        guard reflectedPower >= 0 else { return .infinity }
        guard reflectedPower < forwardPower else { return .infinity }

        let rho = sqrt(reflectedPower / forwardPower)
        if rho >= 1.0 { return .infinity }
        return (1.0 + rho) / (1.0 - rho)
    }

    /// Calculate return loss in dB from SWR.
    ///
    /// Return loss = -20 * log10((SWR - 1) / (SWR + 1))
    public static func returnLoss(swr: Double) -> Double {
        guard swr >= 1.0 else { return .infinity }
        if swr == 1.0 { return .infinity }
        let rho = (swr - 1.0) / (swr + 1.0)
        if rho <= 0 { return .infinity }
        return -20.0 * log10(rho)
    }

    /// Calculate mismatch loss in dB from SWR.
    ///
    /// Mismatch loss = -10 * log10(1 - rho^2)
    public static func mismatchLoss(swr: Double) -> Double {
        guard swr >= 1.0 else { return 0 }
        let rho = (swr - 1.0) / (swr + 1.0)
        let factor = 1.0 - rho * rho
        if factor <= 0 { return .infinity }
        return -10.0 * log10(factor)
    }

    /// Calculate reflection coefficient from SWR.
    ///
    /// rho = (SWR - 1) / (SWR + 1)
    public static func reflectionCoefficient(swr: Double) -> Double {
        guard swr >= 1.0 else { return 0 }
        return (swr - 1.0) / (swr + 1.0)
    }

    // MARK: - L-Network Impedance Matching

    /// Result of an L-network impedance matching calculation.
    public struct LNetworkResult: Sendable, Equatable {
        /// Topology description, e.g. "series-L, shunt-C".
        public var topology: String
        /// Required inductance in microhenries (uH).
        public var inductance: Double
        /// Required capacitance in picofarads (pF).
        public var capacitance: Double

        public init(topology: String, inductance: Double, capacitance: Double) {
            self.topology = topology
            self.inductance = inductance
            self.capacitance = capacitance
        }
    }

    /// Calculate L-network matching components.
    ///
    /// Matches sourceZ to loadZ at the given frequency.
    /// Uses the standard L-network formulas.
    public static func lNetwork(
        sourceZ: Double,
        loadZ: Double,
        frequencyMHz: Double
    ) -> LNetworkResult {
        guard sourceZ > 0, loadZ > 0, frequencyMHz > 0 else {
            return LNetworkResult(topology: "invalid", inductance: 0, capacitance: 0)
        }

        let omega = 2.0 * .pi * frequencyMHz * 1e6  // angular frequency in rad/s

        let rSmall: Double
        let rLarge: Double
        let topology: String

        if sourceZ < loadZ {
            rSmall = sourceZ
            rLarge = loadZ
            topology = "series-L, shunt-C"
        } else {
            rSmall = loadZ
            rLarge = sourceZ
            topology = "shunt-C, series-L"
        }

        // Q factor of the network
        let q = sqrt(rLarge / rSmall - 1.0)

        // Series reactance (inductor): Xs = Q * rSmall
        let xs = q * rSmall
        // Shunt reactance (capacitor): Xp = rLarge / Q
        let xp = rLarge / q

        // Component values
        let inductanceH = xs / omega         // henries
        let inductanceUH = inductanceH * 1e6 // microhenries

        let capacitanceF = 1.0 / (omega * xp)   // farads
        let capacitancePF = capacitanceF * 1e12  // picofarads

        return LNetworkResult(
            topology: topology,
            inductance: inductanceUH,
            capacitance: capacitancePF
        )
    }

    // MARK: - Yagi Elements

    /// Yagi antenna element types.
    public enum YagiElement: Sendable {
        case reflector
        case drivenElement
        case director
    }

    /// Calculate Yagi antenna element length in feet.
    ///
    /// - Parameters:
    ///   - frequencyMHz: Design frequency in MHz.
    ///   - elementType: Type of element (reflector, driven, director).
    ///   - wireDiameterInch: Wire diameter in inches (default #12 AWG = 0.0641").
    /// - Returns: Element length in feet.
    public static func yagiElement(
        frequencyMHz: Double,
        elementType: YagiElement,
        wireDiameterInch: Double = 0.0641
    ) -> Double {
        guard frequencyMHz > 0 else { return 0 }

        // Base half-wave length
        let halfWave = 468.0 / frequencyMHz

        // Correction for element diameter (simplified)
        let wavelengthFeet = 984.0 / frequencyMHz
        let diameterFeet = wireDiameterInch / 12.0
        let correctionFactor = 1.0 - (0.025 * log10(wavelengthFeet / diameterFeet))

        let correctedHalfWave = halfWave * correctionFactor

        switch elementType {
        case .reflector:
            return correctedHalfWave * 1.05  // ~5% longer
        case .drivenElement:
            return correctedHalfWave
        case .director:
            return correctedHalfWave * 0.95  // ~5% shorter
        }
    }
}
