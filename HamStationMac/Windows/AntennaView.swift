// AntennaView.swift — Antenna tools and calculators view
// Dipole, coax loss, SWR, and L-network calculators with live updates.

import SwiftUI

struct AntennaView: View {
    @State private var selectedCalculator: CalculatorTab = .dipole

    enum CalculatorTab: String, CaseIterable {
        case dipole = "Dipole"
        case coaxLoss = "Coax Loss"
        case swr = "SWR"
        case lNetwork = "L-Network"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Calculator", selection: $selectedCalculator) {
                ForEach(CalculatorTab.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                switch selectedCalculator {
                case .dipole:
                    DipoleCalculatorView()
                case .coaxLoss:
                    CoaxLossCalculatorView()
                case .swr:
                    SWRCalculatorView()
                case .lNetwork:
                    LNetworkCalculatorView()
                }
            }
            .padding()
        }
        .navigationTitle("Antenna Tools")
    }
}

// MARK: - Dipole Calculator

private struct DipoleCalculatorView: View {
    @State private var frequencyMHz: Double = 14.074
    @State private var velocityFactor: Double = 0.95

    private var dipoleFeet: Double {
        guard frequencyMHz > 0 else { return 0 }
        return 468.0 / frequencyMHz * velocityFactor
    }
    private var dipoleMeters: Double {
        guard frequencyMHz > 0 else { return 0 }
        return 142.65 / frequencyMHz * velocityFactor
    }
    private var quarterWaveFeet: Double {
        guard frequencyMHz > 0 else { return 0 }
        return 234.0 / frequencyMHz
    }
    private var eachLegFeet: Double { dipoleFeet / 2.0 }
    private var eachLegMeters: Double { dipoleMeters / 2.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dipole & Vertical Calculator")
                .font(.title2.bold())

            Form {
                Section("Input") {
                    HStack {
                        Text("Frequency (MHz)")
                        Spacer()
                        TextField("MHz", value: $frequencyMHz, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Velocity Factor")
                        Spacer()
                        TextField("VF", value: $velocityFactor, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Half-Wave Dipole") {
                    resultRow("Total Length", feet: dipoleFeet, meters: dipoleMeters)
                    resultRow("Each Leg", feet: eachLegFeet, meters: eachLegMeters)
                }

                Section("Quarter-Wave Vertical") {
                    resultRow("Element Length", feet: quarterWaveFeet, meters: quarterWaveFeet * 0.3048)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func resultRow(_ label: String, feet: Double, meters: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.2f ft", feet))
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(Color(hex: "FF6A00"))
            Text("|")
                .foregroundStyle(.tertiary)
            Text(String(format: "%.2f m", meters))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Coax Loss Calculator

private struct CoaxLossCalculatorView: View {
    @State private var cableType = "RG-213"
    @State private var lengthFeet: Double = 100
    @State private var frequencyMHz: Double = 14.074

    private let cableTypes = ["RG-58", "RG-8X", "RG-213", "LMR-400", "LMR-600", "Hardline"]

    private var lossDB: Double {
        // Simplified lookup for display
        let baseLoss: Double
        switch cableType {
        case "RG-58":   baseLoss = 1.6
        case "RG-8X":   baseLoss = 1.3
        case "RG-213":  baseLoss = 0.8
        case "LMR-400": baseLoss = 0.4
        case "LMR-600": baseLoss = 0.27
        case "Hardline": baseLoss = 0.15
        default:         baseLoss = 1.0
        }
        // Scale roughly by frequency (sqrt approximation)
        let freqFactor = sqrt(frequencyMHz / 14.0)
        return baseLoss * freqFactor * lengthFeet / 100.0
    }

    private var powerLossPercent: Double {
        guard lossDB > 0 else { return 0 }
        return (1.0 - pow(10, -lossDB / 10.0)) * 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coax Cable Loss Calculator")
                .font(.title2.bold())

            Form {
                Section("Input") {
                    Picker("Cable Type", selection: $cableType) {
                        ForEach(cableTypes, id: \.self) { Text($0) }
                    }
                    HStack {
                        Text("Length (feet)")
                        Spacer()
                        TextField("feet", value: $lengthFeet, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Frequency (MHz)")
                        Spacer()
                        TextField("MHz", value: $frequencyMHz, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Results") {
                    HStack {
                        Text("Total Loss")
                        Spacer()
                        Text(String(format: "%.2f dB", lossDB))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(lossColor)
                    }
                    HStack {
                        Text("Power Lost")
                        Spacer()
                        Text(String(format: "%.1f%%", powerLossPercent))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var lossColor: Color {
        switch lossDB {
        case ..<1.0: return .green
        case 1.0..<3.0: return .yellow
        default: return .red
        }
    }
}

// MARK: - SWR Calculator

private struct SWRCalculatorView: View {
    @State private var forwardPower: Double = 100
    @State private var reflectedPower: Double = 10

    private var swr: Double {
        guard forwardPower > 0, reflectedPower >= 0, reflectedPower < forwardPower else {
            return .infinity
        }
        let rho = sqrt(reflectedPower / forwardPower)
        if rho >= 1.0 { return .infinity }
        return (1.0 + rho) / (1.0 - rho)
    }

    private var returnLoss: Double {
        guard swr > 1.0, swr.isFinite else { return swr == 1.0 ? .infinity : 0 }
        let rho = (swr - 1.0) / (swr + 1.0)
        if rho <= 0 { return .infinity }
        return -20.0 * log10(rho)
    }

    private var mismatchLoss: Double {
        guard swr >= 1.0, swr.isFinite else { return 0 }
        let rho = (swr - 1.0) / (swr + 1.0)
        let factor = 1.0 - rho * rho
        if factor <= 0 { return .infinity }
        return -10.0 * log10(factor)
    }

    private var reflectionCoef: Double {
        guard swr >= 1.0, swr.isFinite else { return 0 }
        return (swr - 1.0) / (swr + 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SWR Calculator")
                .font(.title2.bold())

            Form {
                Section("Input") {
                    HStack {
                        Text("Forward Power (W)")
                        Spacer()
                        TextField("W", value: $forwardPower, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Reflected Power (W)")
                        Spacer()
                        TextField("W", value: $reflectedPower, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Results") {
                    HStack {
                        Text("SWR")
                        Spacer()
                        Text(swr.isFinite ? String(format: "%.2f : 1", swr) : "Infinite")
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(swrColor)
                    }
                    HStack {
                        Text("Return Loss")
                        Spacer()
                        Text(returnLoss.isFinite ? String(format: "%.1f dB", returnLoss) : "Infinite")
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Mismatch Loss")
                        Spacer()
                        Text(mismatchLoss.isFinite ? String(format: "%.2f dB", mismatchLoss) : "0.00 dB")
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Reflection Coefficient")
                        Spacer()
                        Text(String(format: "%.3f", reflectionCoef))
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var swrColor: Color {
        guard swr.isFinite else { return .red }
        switch swr {
        case ..<1.5: return .green
        case 1.5..<3.0: return .yellow
        default: return .red
        }
    }
}

// MARK: - L-Network Calculator

private struct LNetworkCalculatorView: View {
    @State private var sourceZ: Double = 50
    @State private var loadZ: Double = 200
    @State private var frequencyMHz: Double = 14.074

    private var result: (topology: String, inductance: Double, capacitance: Double) {
        guard sourceZ > 0, loadZ > 0, frequencyMHz > 0 else {
            return ("invalid", 0, 0)
        }
        let omega = 2.0 * .pi * frequencyMHz * 1e6
        let rSmall = min(sourceZ, loadZ)
        let rLarge = max(sourceZ, loadZ)
        let topology = sourceZ < loadZ ? "Series-L, Shunt-C" : "Shunt-C, Series-L"
        let q = sqrt(rLarge / rSmall - 1.0)
        let xs = q * rSmall
        let xp = rLarge / q
        let inductanceUH = (xs / omega) * 1e6
        let capacitancePF = (1.0 / (omega * xp)) * 1e12
        return (topology, inductanceUH, capacitancePF)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("L-Network Impedance Match")
                .font(.title2.bold())

            Form {
                Section("Input") {
                    HStack {
                        Text("Source Impedance (ohm)")
                        Spacer()
                        TextField("ohm", value: $sourceZ, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Load Impedance (ohm)")
                        Spacer()
                        TextField("ohm", value: $loadZ, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Frequency (MHz)")
                        Spacer()
                        TextField("MHz", value: $frequencyMHz, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Results") {
                    HStack {
                        Text("Topology")
                        Spacer()
                        Text(result.topology)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Inductance")
                        Spacer()
                        Text(String(format: "%.3f uH", result.inductance))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(Color(hex: "FF6A00"))
                    }
                    HStack {
                        Text("Capacitance")
                        Spacer()
                        Text(String(format: "%.1f pF", result.capacitance))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(Color(hex: "FF6A00"))
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    AntennaView()
        .frame(width: 700, height: 600)
        .environment(AppState())
}
