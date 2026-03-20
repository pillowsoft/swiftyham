// GreatCircleMapView.swift — Azimuthal equidistant projection map
// Shows beam headings and distances from operator's QTH to DX stations.

import SwiftUI
import HamStationKit

struct GreatCircleMapView: View {
    @Environment(AppState.self) var appState
    @State private var targetGrid: String = ""
    @State private var bearingResult: Double? = nil
    @State private var distanceResult: Double? = nil
    @State private var selectedContinent: String = "All"

    private let continents = ["All", "NA", "SA", "EU", "AF", "AS", "OC"]

    var body: some View {
        HStack(spacing: 0) {
            // Map
            azimuthalMap
                .layoutPriority(1)

            Divider()

            // Sidebar: heading calculator + reference bearings
            rightPanel
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        }
        .navigationTitle("Great Circle Map")
    }

    // MARK: - Azimuthal Map

    private var azimuthalMap: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 40
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2

            ZStack {
                Color(nsColor: .controlBackgroundColor)

                // Distance rings
                ForEach([5000.0, 10000.0, 15000.0, 20000.0], id: \.self) { km in
                    Circle()
                        .stroke(.quaternary, lineWidth: 0.5)
                        .frame(width: size * CGFloat(km / 20000.0), height: size * CGFloat(km / 20000.0))
                        .position(center)

                    Text("\(Int(km)) km")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .position(
                            x: center.x,
                            y: center.y - CGFloat(km / 20000.0) * radius - 8
                        )
                }

                // Compass lines and labels
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0
                    let rad = angle * .pi / 180.0
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + CGFloat(sin(rad)) * radius,
                            y: center.y - CGFloat(cos(rad)) * radius
                        ))
                    }
                    .stroke(.quaternary, lineWidth: 0.5)

                    Text(compassLabel(angle))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .position(
                            x: center.x + CGFloat(sin(rad)) * (radius + 14),
                            y: center.y - CGFloat(cos(rad)) * (radius + 14)
                        )
                }

                // QTH center marker
                Circle()
                    .fill(Color(hex: "FF6A00"))
                    .frame(width: 8, height: 8)
                    .position(center)

                Text(appState.gridSquare)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Color(hex: "FF6A00"))
                    .position(x: center.x + 30, y: center.y + 10)

                // Reference city markers
                ForEach(filteredCities) { city in
                    if let myCoord = GridSquare.coordinates(from: appState.gridSquare) {
                        let bearing = GridSquare.bearing(
                            from: appState.gridSquare,
                            to: city.grid
                        ) ?? 0
                        let dist = GridSquare.distance(
                            from: appState.gridSquare,
                            to: city.grid
                        ) ?? 0

                        let normalizedDist = min(dist / 20000.0, 1.0)
                        let rad = bearing * .pi / 180.0
                        let markerPos = CGPoint(
                            x: center.x + CGFloat(sin(rad)) * radius * CGFloat(normalizedDist),
                            y: center.y - CGFloat(cos(rad)) * radius * CGFloat(normalizedDist)
                        )

                        Circle()
                            .fill(continentColor(city.continent))
                            .frame(width: 6, height: 6)
                            .position(markerPos)

                        Text(city.name)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(continentColor(city.continent))
                            .position(x: markerPos.x + 20, y: markerPos.y - 8)
                    }
                }

                // Target bearing line
                if let bearing = bearingResult, let distance = distanceResult {
                    let rad = bearing * .pi / 180.0
                    let normalizedDist = min(distance / 20000.0, 1.0)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + CGFloat(sin(rad)) * radius * CGFloat(normalizedDist),
                            y: center.y - CGFloat(cos(rad)) * radius * CGFloat(normalizedDist)
                        ))
                    }
                    .stroke(Color(hex: "FF6A00"), lineWidth: 2)

                    // Target dot
                    Circle()
                        .fill(Color(hex: "FF6A00"))
                        .frame(width: 10, height: 10)
                        .position(
                            x: center.x + CGFloat(sin(rad)) * radius * CGFloat(normalizedDist),
                            y: center.y - CGFloat(cos(rad)) * radius * CGFloat(normalizedDist)
                        )
                }
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Heading calculator
            VStack(alignment: .leading, spacing: 8) {
                Text("Bearing Calculator")
                    .font(.headline)

                HStack {
                    Text("From:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.gridSquare)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(Color(hex: "FF6A00"))
                }

                HStack {
                    Text("To:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Grid or callsign", text: $targetGrid)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 120)
                        .onSubmit { calculateBearing() }

                    Button("Go") { calculateBearing() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(targetGrid.isEmpty)
                }

                if let bearing = bearingResult, let distance = distanceResult {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bearing")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f\u{00B0}", bearing))
                                .font(.system(.title3, design: .monospaced).bold())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f km", distance))
                                .font(.system(.title3, design: .monospaced).bold())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)

            Divider()

            // Filter
            HStack {
                Text("Show:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Continent", selection: $selectedContinent) {
                    ForEach(continents, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Reference bearings list
            List {
                ForEach(filteredCities) { city in
                    HStack {
                        Circle()
                            .fill(continentColor(city.continent))
                            .frame(width: 6, height: 6)

                        Text(city.name)
                            .font(.caption)
                            .frame(width: 90, alignment: .leading)

                        Spacer()

                        if let bearing = GridSquare.bearing(from: appState.gridSquare, to: city.grid) {
                            Text(String(format: "%.0f\u{00B0}", bearing))
                                .font(.system(.caption, design: .monospaced).bold())
                                .frame(width: 40, alignment: .trailing)
                        }

                        if let dist = GridSquare.distance(from: appState.gridSquare, to: city.grid) {
                            Text(String(format: "%.0f km", dist))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Helpers

    private func calculateBearing() {
        let grid = targetGrid.trimmingCharacters(in: .whitespaces)
        guard GridSquare.isValid(grid) else {
            bearingResult = nil
            distanceResult = nil
            return
        }
        bearingResult = GridSquare.bearing(from: appState.gridSquare, to: grid)
        distanceResult = GridSquare.distance(from: appState.gridSquare, to: grid)
    }

    private func compassLabel(_ degrees: Double) -> String {
        let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(degrees / 45.0) % 8
        return labels[index]
    }

    private func continentColor(_ continent: String) -> Color {
        switch continent {
        case "NA": return .blue
        case "SA": return .green
        case "EU": return .purple
        case "AF": return .orange
        case "AS": return .red
        case "OC": return .cyan
        default: return .gray
        }
    }

    private var filteredCities: [ReferenceCity] {
        if selectedContinent == "All" { return Self.referenceCities }
        return Self.referenceCities.filter { $0.continent == selectedContinent }
    }

    // MARK: - Reference Data

    struct ReferenceCity: Identifiable {
        let id = UUID()
        let name: String
        let grid: String
        let continent: String
    }

    static let referenceCities: [ReferenceCity] = [
        ReferenceCity(name: "London", grid: "IO91wm", continent: "EU"),
        ReferenceCity(name: "Paris", grid: "JN18du", continent: "EU"),
        ReferenceCity(name: "Berlin", grid: "JO62ql", continent: "EU"),
        ReferenceCity(name: "Moscow", grid: "KO85ts", continent: "EU"),
        ReferenceCity(name: "Tokyo", grid: "PM95vq", continent: "AS"),
        ReferenceCity(name: "Beijing", grid: "OM89xk", continent: "AS"),
        ReferenceCity(name: "Mumbai", grid: "MK68mv", continent: "AS"),
        ReferenceCity(name: "Sydney", grid: "QF56od", continent: "OC"),
        ReferenceCity(name: "Auckland", grid: "RF82bp", continent: "OC"),
        ReferenceCity(name: "Cape Town", grid: "JF96fb", continent: "AF"),
        ReferenceCity(name: "Nairobi", grid: "KI88kr", continent: "AF"),
        ReferenceCity(name: "Buenos Aires", grid: "GF05tj", continent: "SA"),
        ReferenceCity(name: "Rio", grid: "GG87jc", continent: "SA"),
        ReferenceCity(name: "Los Angeles", grid: "DM04wd", continent: "NA"),
        ReferenceCity(name: "Chicago", grid: "EN61dh", continent: "NA"),
        ReferenceCity(name: "Anchorage", grid: "BP64ag", continent: "NA"),
        ReferenceCity(name: "Honolulu", grid: "BL11ci", continent: "OC"),
    ]
}

#Preview {
    GreatCircleMapView()
        .frame(width: 900, height: 600)
        .environment(AppState())
}
