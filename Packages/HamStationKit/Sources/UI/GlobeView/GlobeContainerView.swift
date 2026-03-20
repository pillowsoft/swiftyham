// GlobeContainerView.swift
// HamStationKit — Full globe view with controls and overlays.
//
// Wraps GlobeView with a control bar for toggling overlays, grey line,
// auto-rotation, and showing QSO arcs / DX spots.

import SwiftUI

/// Overlay mode selector for the globe.
public enum GlobeOverlay: String, CaseIterable, Sendable {
    case qsos = "QSO Paths"
    case spots = "DX Spots"
    case awards = "Award Progress"
    case satellites = "Satellites"
}

/// Full-featured globe view with controls and ham radio data overlays.
public struct GlobeContainerView: View {
    @State private var globeScene = GlobeScene()
    @State private var isAutoRotating = true
    @State private var showGreyLine = true
    @State private var showEarthTexture = true
    @State private var earthTextureImage: NSImage?
    @State private var selectedOverlay: GlobeOverlay = .qsos
    @State private var tappedGrid: String?

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Globe
            GlobeView(
                globeScene: globeScene,
                isAutoRotating: $isAutoRotating,
                onLocationTap: { lat, lon in
                    let grid = GridSquare.grid(from: lat, longitude: lon)
                    tappedGrid = "\(grid) (\(String(format: "%.1f", lat)), \(String(format: "%.1f", lon)))"
                }
            )

            // Overlay controls
            VStack(alignment: .trailing, spacing: 8) {
                // Overlay picker
                Picker("Show", selection: $selectedOverlay) {
                    ForEach(GlobeOverlay.allCases, id: \.self) { overlay in
                        Text(overlay.rawValue).tag(overlay)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)

                // Toggle controls
                HStack(spacing: 12) {
                    Toggle("Grey Line", isOn: $showGreyLine)
                    Toggle("Earth Texture", isOn: $showEarthTexture)
                    Toggle("Auto Rotate", isOn: $isAutoRotating)
                }
                .toggleStyle(.button)
                .controlSize(.small)

                // Tapped location display
                if let grid = tappedGrid {
                    Text(grid)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding()

            // Title overlay, bottom-left
            VStack {
                Spacer()
                HStack {
                    Text("3D Globe")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding()
                    Spacer()
                }
            }
        }
        .onAppear { setupGlobe() }
        .onChange(of: showGreyLine) { _, show in
            globeScene.greyLineNode.isHidden = !show
        }
        .onChange(of: showEarthTexture) { _, show in
            globeScene.setEarthTexture(enabled: show, image: earthTextureImage)
        }
        .task {
            if let image = await EarthTextureManager.shared.loadTexture() {
                earthTextureImage = image
                if showEarthTexture {
                    globeScene.applyEarthTexture(image)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupGlobe() {
        globeScene.addContinentOutlines()
        globeScene.updateGreyLine()

        // Demo home station (FN31 — Connecticut)
        globeScene.setHomeStation(latitude: 41.0, longitude: -73.0, callsign: "N0CALL")

        // Demo QSO arcs
        addSampleArcs()

        // Demo DX spots
        addSampleSpots()
    }

    private func addSampleArcs() {
        let home = (lat: 41.0, lon: -73.0)
        let destinations: [(lat: Double, lon: Double, color: NSColor)] = [
            (35.7, 139.7, .orange),         // Japan
            (51.5, -0.1, .orange),           // London
            (-33.9, 151.2, .orange),         // Sydney
            (-34.6, -58.4, .orange),         // Buenos Aires
            (55.8, 37.6, .orange),           // Moscow
            (-26.2, 28.0, .orange),          // Johannesburg
            (28.6, 77.2, .green),            // New Delhi (needed)
            (64.0, -22.0, .green),           // Iceland (needed)
        ]
        for dest in destinations {
            globeScene.addArc(
                from: home,
                to: (lat: dest.lat, lon: dest.lon),
                color: dest.color,
                animated: true
            )
        }
    }

    private func addSampleSpots() {
        globeScene.addSpot(latitude: 35.7, longitude: 139.7, callsign: "JA1ABC", status: .worked)
        globeScene.addSpot(latitude: 51.5, longitude: -0.1, callsign: "G3XYZ", status: .confirmed)
        globeScene.addSpot(latitude: -33.9, longitude: 151.2, callsign: "VK2ABC", status: .needed)
        globeScene.addSpot(latitude: 55.8, longitude: 37.6, callsign: "UA3DEF", status: .needed)
        globeScene.addSpot(latitude: -26.2, longitude: 28.0, callsign: "ZS6GH", status: .worked)
        globeScene.addSpot(latitude: 28.6, longitude: 77.2, callsign: "VU2IJ", status: .needed)
    }
}

#Preview {
    GlobeContainerView()
        .frame(width: 900, height: 700)
}
