// SatelliteGlobeOverlay.swift
// HamStationKit — Satellite orbit tracks and footprints on the 3D globe.

import SceneKit
import AppKit

extension GlobeScene {

    // MARK: - Satellite Track

    /// Add a satellite ground track as a coloured line on the globe surface.
    ///
    /// - Parameters:
    ///   - positions: Array of (lat, lon, altitude_km) positions along the orbit.
    ///   - color: Track colour (default cyan).
    public func addSatelliteTrack(
        positions: [(lat: Double, lon: Double, alt: Double)],
        color: NSColor = .cyan
    ) {
        guard positions.count >= 2 else { return }

        let container = SCNNode()

        // Ground track line
        var groundPositions: [SCNVector3] = []
        for pos in positions {
            groundPositions.append(position(latitude: pos.lat, longitude: pos.lon, altitude: 0.005))
        }

        let trackNode = createTrackLine(positions: groundPositions, color: color.withAlphaComponent(0.6), lineWidth: 0.002)
        container.addChildNode(trackNode)

        // Current position marker (first position assumed current)
        if let current = positions.first {
            let dot = SCNSphere(radius: 0.012)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.lightingModel = .constant
            mat.emission.contents = color
            dot.firstMaterial = mat
            let dotNode = SCNNode(geometry: dot)
            dotNode.position = position(latitude: current.lat, longitude: current.lon, altitude: 0.008)

            // Pulsing animation
            let pulseUp = SCNAction.scale(to: 1.4, duration: 0.5)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.5)
            pulseDown.timingMode = .easeInEaseOut
            dotNode.runAction(.repeatForever(.sequence([pulseUp, pulseDown])))

            container.addChildNode(dotNode)
        }

        globeNode.addChildNode(container)
    }

    // MARK: - Satellite Footprint

    /// Draw a semi-transparent circle on the globe showing the satellite's radio horizon.
    ///
    /// - Parameters:
    ///   - center: Subsatellite point (lat, lon).
    ///   - radiusKm: Footprint radius in kilometres.
    public func addSatelliteFootprint(center: (lat: Double, lon: Double), radiusKm: Double) {
        let earthRadiusKm = 6371.0
        let angularRadius = radiusKm / earthRadiusKm  // radians
        let segments = 48
        var positions: [SCNVector3] = []

        let centerLatRad = center.lat * .pi / 180.0
        let centerLonRad = center.lon * .pi / 180.0

        for i in 0...segments {
            let bearing = 2.0 * .pi * Double(i) / Double(segments)

            // Great circle destination formula
            let lat2 = asin(
                sin(centerLatRad) * cos(angularRadius) +
                cos(centerLatRad) * sin(angularRadius) * cos(bearing)
            )
            let lon2 = centerLonRad + atan2(
                sin(bearing) * sin(angularRadius) * cos(centerLatRad),
                cos(angularRadius) - sin(centerLatRad) * sin(lat2)
            )

            let latDeg = lat2 * 180.0 / .pi
            let lonDeg = lon2 * 180.0 / .pi
            positions.append(position(latitude: latDeg, longitude: lonDeg, altitude: 0.003))
        }

        let footprintNode = createTrackLine(
            positions: positions,
            color: NSColor.cyan.withAlphaComponent(0.3),
            lineWidth: 0.0015
        )
        globeNode.addChildNode(footprintNode)
    }

    // MARK: - Private

    private func createTrackLine(positions: [SCNVector3], color: NSColor, lineWidth: CGFloat) -> SCNNode {
        let container = SCNNode()
        guard positions.count >= 2 else { return container }

        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        mat.emission.contents = color

        for i in 0..<(positions.count - 1) {
            let p1 = positions[i]
            let p2 = positions[i + 1]

            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let dz = p2.z - p1.z
            let dist = sqrt(dx * dx + dy * dy + dz * dz)
            guard dist > 0.0001 else { continue }

            let cyl = SCNCylinder(radius: lineWidth, height: CGFloat(dist))
            cyl.firstMaterial = mat

            let segNode = SCNNode(geometry: cyl)
            segNode.position = SCNVector3(
                (p1.x + p2.x) / 2,
                (p1.y + p2.y) / 2,
                (p1.z + p2.z) / 2
            )

            let direction = simd_normalize(SIMD3<Float>(Float(dx), Float(dy), Float(dz)))
            let yAxis = SIMD3<Float>(0, 1, 0)
            let dotProduct = simd_dot(yAxis, direction)

            if abs(dotProduct + 1.0) < 0.0001 {
                segNode.eulerAngles.x = .pi
            } else if abs(dotProduct - 1.0) > 0.0001 {
                let axis = simd_normalize(simd_cross(yAxis, direction))
                let angle = acos(min(max(dotProduct, -1), 1))
                segNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
            }

            container.addChildNode(segNode)
        }

        return container
    }
}
