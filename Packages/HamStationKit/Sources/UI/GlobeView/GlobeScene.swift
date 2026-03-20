// GlobeScene.swift
// HamStationKit — SceneKit 3D globe for amateur radio visualization.
//
// Dark "war room" aesthetic globe with glowing continent outlines, great-circle
// QSO arcs, pulsing DX spot markers, solar terminator (grey line), and grid
// overlays. Uses procedural geometry — no texture images required.

import SceneKit
import Foundation
import AppKit

// MARK: - Spot Marker Status

/// Visual status of a DX spot marker on the globe.
public enum SpotMarkerStatus: Sendable {
    case needed     // pulsing green
    case worked     // steady yellow
    case confirmed  // dim grey
}

// MARK: - GlobeScene

/// Core 3D globe renderer. Owns the SCNScene and provides methods to add
/// QSO arcs, spot markers, grey line, and continent outlines.
@MainActor
public final class GlobeScene: @unchecked Sendable {

    // MARK: Public Nodes

    public let scene: SCNScene
    public let cameraNode: SCNNode
    public let globeNode: SCNNode
    public let atmosphereNode: SCNNode
    public let greyLineNode: SCNNode

    // MARK: Private State

    private var arcNodes: [SCNNode] = []
    private var spotNodes: [SCNNode] = []
    private var homeMarkerNode: SCNNode?
    private var autoRotateAction: SCNAction?
    private var continentNode: SCNNode?

    private let globeRadius: CGFloat = 1.0

    // MARK: - Initialisation

    public init() {
        scene = SCNScene()

        // --- Camera ---
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.fieldOfView = 45
        cameraNode.position = SCNVector3(0, 0, 3.5)
        scene.rootNode.addChildNode(cameraNode)

        // --- Ambient light ---
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.35, alpha: 1)
        scene.rootNode.addChildNode(ambientLight)

        // --- Sun directional light (for terminator shading) ---
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .directional
        sunLight.light?.color = NSColor(white: 0.7, alpha: 1)
        sunLight.light?.castsShadow = false
        sunLight.eulerAngles = SCNVector3(-0.3, 0.5, 0)
        scene.rootNode.addChildNode(sunLight)

        // --- Globe sphere ---
        let sphere = SCNSphere(radius: globeRadius)
        sphere.segmentCount = 96

        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        material.specular.contents = NSColor(white: 0.15, alpha: 1)
        material.shininess = 0.2
        material.lightingModel = .blinn
        sphere.firstMaterial = material

        globeNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(globeNode)

        // --- Grid lines ---
        atmosphereNode = GlobeScene.createGridLines(radius: globeRadius)
        globeNode.addChildNode(atmosphereNode)

        // --- Grey line container ---
        greyLineNode = SCNNode()
        globeNode.addChildNode(greyLineNode)

        // --- Atmosphere glow ring ---
        let glowSphere = SCNSphere(radius: globeRadius * 1.02)
        glowSphere.segmentCount = 64
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(red: 0.15, green: 0.3, blue: 0.7, alpha: 0.06)
        glowMat.isDoubleSided = true
        glowMat.lightingModel = .constant
        glowSphere.firstMaterial = glowMat
        let glowNode = SCNNode(geometry: glowSphere)
        globeNode.addChildNode(glowNode)

        // --- Background ---
        scene.background.contents = NSColor.black
    }

    // MARK: - Coordinate Conversion

    /// Convert latitude/longitude (degrees) to a 3D position on the globe surface.
    public func position(latitude: Double, longitude: Double, altitude: Double = 0) -> SCNVector3 {
        let R = Double(globeRadius) + altitude
        let latRad = latitude * .pi / 180.0
        let lonRad = longitude * .pi / 180.0

        let x = R * cos(latRad) * cos(lonRad)
        let y = R * sin(latRad)
        let z = R * cos(latRad) * sin(lonRad)

        return SCNVector3(Float(x), Float(y), Float(-z))
    }

    // MARK: - Home Station Marker

    /// Place a gold pulsing marker at the home station location.
    public func setHomeStation(latitude: Double, longitude: Double, callsign: String) {
        homeMarkerNode?.removeFromParentNode()

        let container = SCNNode()

        // Marker dot
        let dot = SCNSphere(radius: 0.015)
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1)
        dotMat.lightingModel = .constant
        dotMat.emission.contents = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1)
        dot.firstMaterial = dotMat
        let dotNode = SCNNode(geometry: dot)
        container.addChildNode(dotNode)

        // Pulse animation
        let pulseUp = SCNAction.scale(to: 1.6, duration: 0.8)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SCNAction.scale(to: 1.0, duration: 0.8)
        pulseDown.timingMode = .easeInEaseOut
        dotNode.runAction(.repeatForever(.sequence([pulseUp, pulseDown])))

        // Glow ring
        let ring = SCNTorus(ringRadius: 0.025, pipeRadius: 0.003)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.5)
        ringMat.lightingModel = .constant
        ring.firstMaterial = ringMat
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = .pi / 2
        container.addChildNode(ringNode)

        // Callsign label
        let text = SCNText(string: callsign, extrusionDepth: 0)
        text.font = NSFont.systemFont(ofSize: 0.04, weight: .bold)
        text.flatness = 0.2
        let textMat = SCNMaterial()
        textMat.diffuse.contents = NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        textMat.lightingModel = .constant
        text.firstMaterial = textMat
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(0.02, 0.02, 0)
        textNode.scale = SCNVector3(0.8, 0.8, 0.8)
        // Billboard constraint so text always faces camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        container.addChildNode(textNode)

        let pos = position(latitude: latitude, longitude: longitude, altitude: 0.01)
        container.position = pos

        globeNode.addChildNode(container)
        homeMarkerNode = container
    }

    // MARK: - Great Circle Arcs (QSO Paths)

    /// Draw a great circle arc between two points on the globe.
    public func addArc(
        from: (lat: Double, lon: Double),
        to: (lat: Double, lon: Double),
        color: NSColor,
        animated: Bool = true
    ) {
        let segments = 64
        var positions: [SCNVector3] = []

        // Great circle interpolation
        let lat1 = from.lat * .pi / 180.0
        let lon1 = from.lon * .pi / 180.0
        let lat2 = to.lat * .pi / 180.0
        let lon2 = to.lon * .pi / 180.0

        // Angular distance
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let angularDistance = 2 * atan2(sqrt(a), sqrt(1 - a))

        // Arc altitude proportional to distance (max ~0.15 for antipodal)
        let maxAlt = 0.05 + 0.12 * (angularDistance / .pi)

        for i in 0...segments {
            let t = Double(i) / Double(segments)

            // Spherical linear interpolation
            let sinD = sin(angularDistance)
            guard sinD > 0.0001 else { continue }
            let aCoeff = sin((1 - t) * angularDistance) / sinD
            let bCoeff = sin(t * angularDistance) / sinD

            let x1 = cos(lat1) * cos(lon1)
            let y1 = sin(lat1)
            let z1 = cos(lat1) * sin(lon1)

            let x2 = cos(lat2) * cos(lon2)
            let y2 = sin(lat2)
            let z2 = cos(lat2) * sin(lon2)

            let xi = aCoeff * x1 + bCoeff * x2
            let yi = aCoeff * y1 + bCoeff * y2
            let zi = aCoeff * z1 + bCoeff * z2

            // Normalize and apply altitude (parabolic arc)
            let len = sqrt(xi * xi + yi * yi + zi * zi)
            let parabola = 4.0 * maxAlt * t * (1.0 - t)
            let alt = Double(globeRadius) + 0.005 + parabola

            let nx = Float((xi / len) * alt)
            let ny = Float((yi / len) * alt)
            let nz = Float(-(zi / len) * alt)

            positions.append(SCNVector3(nx, ny, nz))
        }

        guard positions.count >= 2 else { return }

        // Build line geometry from capsule segments for visibility
        let arcContainer = SCNNode()

        for i in 0..<(positions.count - 1) {
            let p1 = positions[i]
            let p2 = positions[i + 1]

            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let dz = p2.z - p1.z
            let dist = sqrt(dx * dx + dy * dy + dz * dz)

            let capsule = SCNCapsule(capRadius: 0.002, height: CGFloat(dist))
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.lightingModel = .constant
            mat.emission.contents = color.withAlphaComponent(0.8)
            capsule.firstMaterial = mat

            let segNode = SCNNode(geometry: capsule)
            segNode.position = SCNVector3(
                (p1.x + p2.x) / 2,
                (p1.y + p2.y) / 2,
                (p1.z + p2.z) / 2
            )

            // Orient capsule along segment direction
            let up = SCNVector3(0, 1, 0)
            let dir = SCNVector3(dx, dy, dz)
            segNode.look(at: SCNVector3(p2.x, p2.y, p2.z),
                         up: scene.rootNode.worldUp,
                         localFront: up)

            arcContainer.addChildNode(segNode)
        }

        // Animated reveal
        if animated {
            arcContainer.opacity = 0
            let fadeIn = SCNAction.fadeIn(duration: 0.8)
            fadeIn.timingMode = .easeOut
            arcContainer.runAction(fadeIn)
        }

        globeNode.addChildNode(arcContainer)
        arcNodes.append(arcContainer)
    }

    /// Remove all QSO arc paths.
    public func clearArcs() {
        for node in arcNodes { node.removeFromParentNode() }
        arcNodes.removeAll()
    }

    // MARK: - DX Spot Markers

    /// Add a DX spot marker at the given location.
    public func addSpot(latitude: Double, longitude: Double, callsign: String, status: SpotMarkerStatus) {
        let container = SCNNode()

        let dotRadius: CGFloat = 0.008
        let dot = SCNSphere(radius: dotRadius)
        let mat = SCNMaterial()
        mat.lightingModel = .constant

        switch status {
        case .needed:
            mat.diffuse.contents = NSColor.green
            mat.emission.contents = NSColor.green
        case .worked:
            mat.diffuse.contents = NSColor.yellow
            mat.emission.contents = NSColor.yellow
        case .confirmed:
            mat.diffuse.contents = NSColor(white: 0.4, alpha: 1)
            mat.emission.contents = NSColor(white: 0.3, alpha: 1)
        }
        dot.firstMaterial = mat

        let dotNode = SCNNode(geometry: dot)
        container.addChildNode(dotNode)

        // Pulse animation for needed spots
        if status == .needed {
            let up = SCNAction.scale(to: 1.5, duration: 0.6)
            up.timingMode = .easeInEaseOut
            let down = SCNAction.scale(to: 1.0, duration: 0.6)
            down.timingMode = .easeInEaseOut
            dotNode.runAction(.repeatForever(.sequence([up, down])))
        }

        // Callsign label (billboard)
        let text = SCNText(string: callsign, extrusionDepth: 0)
        text.font = NSFont.systemFont(ofSize: 0.025, weight: .medium)
        text.flatness = 0.3
        let textMat = SCNMaterial()
        textMat.diffuse.contents = NSColor.white.withAlphaComponent(0.8)
        textMat.lightingModel = .constant
        text.firstMaterial = textMat
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(0.012, 0.01, 0)
        textNode.scale = SCNVector3(0.6, 0.6, 0.6)
        textNode.constraints = [SCNBillboardConstraint()]
        container.addChildNode(textNode)

        container.position = position(latitude: latitude, longitude: longitude, altitude: 0.005)
        globeNode.addChildNode(container)
        spotNodes.append(container)
    }

    /// Remove all spot markers.
    public func clearSpots() {
        for node in spotNodes { node.removeFromParentNode() }
        spotNodes.removeAll()
    }

    // MARK: - Grey Line (Solar Terminator)

    /// Update the grey line (solar terminator) overlay for the given date.
    public func updateGreyLine(date: Date = Date()) {
        greyLineNode.childNodes.forEach { $0.removeFromParentNode() }

        // Compute subsolar point
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)

        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return }
        let hour = Double(components.hour ?? 12)
        let minute = Double(components.minute ?? 0)
        let utcHours = hour + minute / 60.0

        // Solar declination (approximate)
        let declination = -23.44 * cos(2.0 * .pi / 365.0 * (Double(dayOfYear) + 10))
        // Subsolar longitude
        let subsolarLon = (12.0 - utcHours) * 15.0

        // Draw terminator band: a semi-transparent belt where twilight occurs
        let twilightWidth = 9.0 // degrees on each side of terminator
        let steps = 72
        var nightPositions: [SCNVector3] = []
        var dawnPositions: [SCNVector3] = []

        for i in 0...steps {
            let lon = -180.0 + 360.0 * Double(i) / Double(steps)
            // Terminator latitude at this longitude
            let lonDiff = (lon - subsolarLon) * .pi / 180.0
            let decRad = declination * .pi / 180.0
            let terminatorLat = atan2(-cos(lonDiff), tan(decRad)) * 180.0 / .pi

            let dawnLat = terminatorLat + twilightWidth
            let duskLat = terminatorLat - twilightWidth

            dawnPositions.append(position(latitude: dawnLat, longitude: lon, altitude: 0.003))
            nightPositions.append(position(latitude: duskLat, longitude: lon, altitude: 0.003))
        }

        // Draw the terminator as a glowing line
        let terminatorLine = createLineNode(
            positions: dawnPositions,
            color: NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.4),
            lineWidth: 0.003
        )
        greyLineNode.addChildNode(terminatorLine)

        let duskLine = createLineNode(
            positions: nightPositions,
            color: NSColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 0.25),
            lineWidth: 0.002
        )
        greyLineNode.addChildNode(duskLine)
    }

    // MARK: - Grid Lines

    /// Create latitude/longitude grid lines as a node.
    private static func createGridLines(radius: CGFloat) -> SCNNode {
        let container = SCNNode()
        let lineAlt = Double(radius) + 0.001

        // Latitude lines every 30 degrees
        for lat in stride(from: -60, through: 60, by: 30) {
            let isEquator = lat == 0
            let alpha: CGFloat = isEquator ? 0.25 : 0.1
            let color = NSColor(white: 0.7, alpha: alpha)
            let segments = 72
            var positions: [SCNVector3] = []

            for i in 0...segments {
                let lon = -180.0 + 360.0 * Double(i) / Double(segments)
                let latRad = Double(lat) * .pi / 180.0
                let lonRad = lon * .pi / 180.0
                let x = Float(lineAlt * cos(latRad) * cos(lonRad))
                let y = Float(lineAlt * sin(latRad))
                let z = Float(-lineAlt * cos(latRad) * sin(lonRad))
                positions.append(SCNVector3(x, y, z))
            }

            let node = createStaticLineNode(positions: positions, color: color, lineWidth: 0.001)
            container.addChildNode(node)
        }

        // Longitude lines every 30 degrees
        for lonDeg in stride(from: -180, to: 180, by: 30) {
            let segments = 72
            var positions: [SCNVector3] = []
            let color = NSColor(white: 0.7, alpha: 0.1)

            for i in 0...segments {
                let lat = -90.0 + 180.0 * Double(i) / Double(segments)
                let latRad = lat * .pi / 180.0
                let lonRad = Double(lonDeg) * .pi / 180.0
                let x = Float(lineAlt * cos(latRad) * cos(lonRad))
                let y = Float(lineAlt * sin(latRad))
                let z = Float(-lineAlt * cos(latRad) * sin(lonRad))
                positions.append(SCNVector3(x, y, z))
            }

            let node = createStaticLineNode(positions: positions, color: color, lineWidth: 0.001)
            container.addChildNode(node)
        }

        return container
    }

    // MARK: - Continent Outlines

    /// Add stylised continent outlines as glowing lines on the globe surface.
    public func addContinentOutlines() {
        continentNode?.removeFromParentNode()
        let container = SCNNode()

        let outlineColor = NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.65)

        for continent in ContinentData.allContinents {
            guard continent.count >= 3 else { continue }
            var positions: [SCNVector3] = []
            for (lat, lon) in continent {
                positions.append(position(latitude: lat, longitude: lon, altitude: 0.003))
            }
            let lineNode = createLineNode(positions: positions, color: outlineColor, lineWidth: 0.0025)
            container.addChildNode(lineNode)
        }

        globeNode.addChildNode(container)
        continentNode = container
    }

    // MARK: - Animation

    /// Smoothly rotate the globe to centre a location in view.
    public func rotateToLocation(latitude: Double, longitude: Double, duration: TimeInterval = 1.0) {
        let latRad = Float(-latitude * .pi / 180.0)
        let lonRad = Float(-longitude * .pi / 180.0)

        let action = SCNAction.rotateTo(
            x: CGFloat(latRad),
            y: CGFloat(lonRad),
            z: 0,
            duration: duration,
            usesShortestUnitArc: true
        )
        action.timingMode = .easeInEaseOut
        globeNode.runAction(action)
    }

    /// Start a slow continuous rotation.
    public func startAutoRotation(speed: Double = 0.1) {
        stopAutoRotation()
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat(2.0 * .pi), z: 0, duration: 60.0 / speed)
        let forever = SCNAction.repeatForever(rotate)
        globeNode.runAction(forever, forKey: "autoRotate")
    }

    /// Stop continuous rotation.
    public func stopAutoRotation() {
        globeNode.removeAction(forKey: "autoRotate")
    }

    // MARK: - Propagation Overlay

    /// Show semi-transparent coloured regions indicating propagation conditions.
    public func showPropagationOverlay(bandConditions: [(band: String, regions: [(lat: Double, lon: Double, radius: Double)])]) {
        // Each region is a glowing disc on the globe surface
        for condition in bandConditions {
            for region in condition.regions {
                let disc = SCNPlane(width: CGFloat(region.radius) * 0.02, height: CGFloat(region.radius) * 0.02)
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor.green.withAlphaComponent(0.15)
                mat.lightingModel = .constant
                mat.isDoubleSided = true
                disc.firstMaterial = mat
                let discNode = SCNNode(geometry: disc)
                discNode.position = position(latitude: region.lat, longitude: region.lon, altitude: 0.004)
                discNode.constraints = [SCNBillboardConstraint()]
                globeNode.addChildNode(discNode)
            }
        }
    }

    // MARK: - Line Helpers

    /// Create a line node from a series of positions using thin capsule segments.
    private func createLineNode(positions: [SCNVector3], color: NSColor, lineWidth: CGFloat) -> SCNNode {
        GlobeScene.createStaticLineNode(positions: positions, color: color, lineWidth: lineWidth)
    }

    /// Static version used during init.
    private static func createStaticLineNode(positions: [SCNVector3], color: NSColor, lineWidth: CGFloat) -> SCNNode {
        let container = SCNNode()
        guard positions.count >= 2 else { return container }

        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        mat.emission.contents = color

        // Use cylinder segments for each pair of adjacent points
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

            // Orient: SCNCylinder is along Y, we need it along the direction vector
            let direction = simd_normalize(SIMD3<Float>(Float(dx), Float(dy), Float(dz)))
            let yAxis = SIMD3<Float>(0, 1, 0)
            let dotProduct = simd_dot(yAxis, direction)

            if abs(dotProduct + 1.0) < 0.0001 {
                // Anti-parallel: flip 180 around X
                segNode.eulerAngles.x = .pi
            } else if abs(dotProduct - 1.0) > 0.0001 {
                // General case: compute rotation axis and angle
                let axis = simd_normalize(simd_cross(yAxis, direction))
                let angle = acos(min(max(dotProduct, -1), 1))
                segNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
            }

            container.addChildNode(segNode)
        }

        return container
    }
}
