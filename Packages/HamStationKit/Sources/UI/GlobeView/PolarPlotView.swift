// PolarPlotView.swift
// HamStationKit — Polar plot for satellite pass visualization.
//
// 2D Canvas-based polar projection showing azimuth/elevation for a satellite
// pass. North at top, elevation 90 at centre, 0 at the edge.

import SwiftUI

/// A single point in a satellite pass trajectory.
public struct SatellitePassPoint: Identifiable, Sendable {
    public let id: UUID
    public var azimuth: Double    // degrees, 0 = north, 90 = east
    public var elevation: Double  // degrees, 0 = horizon, 90 = zenith
    public var time: Date

    public init(id: UUID = UUID(), azimuth: Double, elevation: Double, time: Date) {
        self.id = id
        self.azimuth = azimuth
        self.elevation = elevation
        self.time = time
    }
}

/// Polar projection plot for satellite pass tracks.
public struct PolarPlotView: View {
    public let passes: [SatellitePassPoint]
    public var currentPosition: SatellitePassPoint?

    public init(passes: [SatellitePassPoint], currentPosition: SatellitePassPoint? = nil) {
        self.passes = passes
        self.currentPosition = currentPosition
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 30

            // --- Background ---
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black)
            )

            // --- Concentric elevation circles (every 30 degrees) ---
            for elev in stride(from: 0, through: 60, by: 30) {
                let r = radius * CGFloat(1.0 - Double(elev) / 90.0)
                let circlePath = Path(ellipseIn: CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                ))
                context.stroke(circlePath, with: .color(.white.opacity(0.15)), lineWidth: 0.5)

                // Elevation label
                if elev > 0 {
                    let label = Text("\(elev)°")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    context.draw(label, at: CGPoint(x: center.x + 4, y: center.y - r + 2), anchor: .topLeading)
                }
            }

            // --- Cardinal direction lines and labels ---
            let cardinals: [(String, Double)] = [
                ("N", 0), ("E", 90), ("S", 180), ("W", 270),
            ]
            for (label, az) in cardinals {
                let angle = az * .pi / 180.0 - .pi / 2  // canvas: 0 = right, we want 0 = top
                let outerPt = CGPoint(
                    x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle))
                )

                var linePath = Path()
                linePath.move(to: center)
                linePath.addLine(to: outerPt)
                context.stroke(linePath, with: .color(.white.opacity(0.1)), lineWidth: 0.5)

                let labelPt = CGPoint(
                    x: center.x + (radius + 14) * CGFloat(cos(angle)),
                    y: center.y + (radius + 14) * CGFloat(sin(angle))
                )
                let text = Text(label)
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundStyle(.white.opacity(0.5))
                context.draw(text, at: labelPt)
            }

            // --- Pass track ---
            guard passes.count >= 2 else { return }

            var trackPath = Path()
            let firstPt = point(azimuth: passes[0].azimuth, elevation: passes[0].elevation, center: center, radius: radius)
            trackPath.move(to: firstPt)

            for i in 1..<passes.count {
                let pt = point(azimuth: passes[i].azimuth, elevation: passes[i].elevation, center: center, radius: radius)
                trackPath.addLine(to: pt)
            }

            // Gradient from green (AOS) to yellow (max el) to red (LOS)
            context.stroke(trackPath, with: .color(.cyan), lineWidth: 2)

            // --- AOS / LOS markers ---
            let aos = passes.first!
            let los = passes.last!
            let aosPt = point(azimuth: aos.azimuth, elevation: aos.elevation, center: center, radius: radius)
            let losPt = point(azimuth: los.azimuth, elevation: los.elevation, center: center, radius: radius)

            // AOS dot (green)
            let aosDot = Path(ellipseIn: CGRect(x: aosPt.x - 4, y: aosPt.y - 4, width: 8, height: 8))
            context.fill(aosDot, with: .color(.green))
            let aosLabel = Text("AOS").font(.system(size: 9, design: .monospaced)).foregroundStyle(.green)
            context.draw(aosLabel, at: CGPoint(x: aosPt.x, y: aosPt.y - 10))

            // LOS dot (red)
            let losDot = Path(ellipseIn: CGRect(x: losPt.x - 4, y: losPt.y - 4, width: 8, height: 8))
            context.fill(losDot, with: .color(.red))
            let losLabel = Text("LOS").font(.system(size: 9, design: .monospaced)).foregroundStyle(.red)
            context.draw(losLabel, at: CGPoint(x: losPt.x, y: losPt.y - 10))

            // --- Current position ---
            if let curr = currentPosition {
                let pt = point(azimuth: curr.azimuth, elevation: curr.elevation, center: center, radius: radius)
                let dotPath = Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12))
                context.fill(dotPath, with: .color(.orange))
                let ring = Path(ellipseIn: CGRect(x: pt.x - 8, y: pt.y - 8, width: 16, height: 16))
                context.stroke(ring, with: .color(.orange.opacity(0.5)), lineWidth: 1)
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }

    // MARK: - Coordinate Conversion

    /// Convert azimuth/elevation to a canvas point.
    ///
    /// Elevation 90 = centre, 0 = edge. Azimuth 0 = north (top), 90 = east (right).
    func point(azimuth: Double, elevation: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let r = radius * CGFloat(1.0 - elevation / 90.0)
        let angle = azimuth * .pi / 180.0 - .pi / 2  // offset so 0 = top
        return CGPoint(
            x: center.x + r * CGFloat(cos(angle)),
            y: center.y + r * CGFloat(sin(angle))
        )
    }
}

// MARK: - Preview

#Preview("Polar Plot — Sample ISS Pass") {
    let now = Date()
    let samplePass: [SatellitePassPoint] = [
        SatellitePassPoint(azimuth: 220, elevation: 0, time: now),
        SatellitePassPoint(azimuth: 230, elevation: 10, time: now.addingTimeInterval(60)),
        SatellitePassPoint(azimuth: 250, elevation: 25, time: now.addingTimeInterval(120)),
        SatellitePassPoint(azimuth: 280, elevation: 45, time: now.addingTimeInterval(180)),
        SatellitePassPoint(azimuth: 320, elevation: 60, time: now.addingTimeInterval(240)),
        SatellitePassPoint(azimuth: 10, elevation: 72, time: now.addingTimeInterval(300)),
        SatellitePassPoint(azimuth: 40, elevation: 55, time: now.addingTimeInterval(360)),
        SatellitePassPoint(azimuth: 55, elevation: 30, time: now.addingTimeInterval(420)),
        SatellitePassPoint(azimuth: 60, elevation: 10, time: now.addingTimeInterval(480)),
        SatellitePassPoint(azimuth: 62, elevation: 0, time: now.addingTimeInterval(540)),
    ]

    PolarPlotView(
        passes: samplePass,
        currentPosition: SatellitePassPoint(azimuth: 320, elevation: 60, time: now.addingTimeInterval(240))
    )
    .frame(width: 300, height: 300)
}
