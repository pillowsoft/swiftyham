// GlobeView.swift
// HamStationKit — SwiftUI wrapper for the SceneKit 3D globe.
//
// Provides camera orbit controls, click-to-locate, and auto-rotation toggle.

import SwiftUI
import SceneKit

/// SwiftUI-wrapped SceneKit globe with interactive controls.
public struct GlobeView: NSViewRepresentable {
    public let globeScene: GlobeScene
    @Binding public var isAutoRotating: Bool
    public var onLocationTap: ((Double, Double) -> Void)?

    public init(
        globeScene: GlobeScene,
        isAutoRotating: Binding<Bool>,
        onLocationTap: ((Double, Double) -> Void)? = nil
    ) {
        self.globeScene = globeScene
        self._isAutoRotating = isAutoRotating
        self.onLocationTap = onLocationTap
    }

    public func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = globeScene.scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.pointOfView = globeScene.cameraNode

        // Click gesture for location lookup
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleClick(_:))
        )
        view.addGestureRecognizer(click)

        return view
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        if isAutoRotating {
            globeScene.startAutoRotation()
        } else {
            globeScene.stopAutoRotation()
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        let parent: GlobeView

        init(parent: GlobeView) {
            self.parent = parent
        }

        @MainActor
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
            ])

            for hit in hits {
                if hit.node == parent.globeScene.globeNode || hit.node.parent == parent.globeScene.globeNode {
                    let pos = hit.localCoordinates
                    let radius = CGFloat(1.0)
                    let lat = asin(pos.y / radius) * 180.0 / .pi
                    let lon = atan2(-pos.z, pos.x) * 180.0 / .pi
                    parent.onLocationTap?(Double(lat), Double(lon))
                    return
                }
            }
        }
    }
}
