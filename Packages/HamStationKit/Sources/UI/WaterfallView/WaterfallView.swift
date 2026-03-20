// WaterfallView.swift
// HamStationKit — SwiftUI wrapper for the Metal waterfall spectrogram.
//
// Bridges the Metal-based WaterfallRenderer into SwiftUI via NSViewRepresentable.
// Handles click-to-tune by converting click coordinates to frequencies.

import SwiftUI
import MetalKit

/// SwiftUI view that displays a Metal-rendered waterfall spectrogram.
///
/// Wraps an `MTKView` driven by a `WaterfallRenderer`. Supports click-to-tune:
/// clicking on the waterfall converts the x coordinate to a frequency and calls
/// the `onFrequencyTap` closure.
public struct WaterfallView: NSViewRepresentable {

    /// The Metal renderer that draws the waterfall spectrogram.
    public let renderer: WaterfallRenderer

    /// Callback invoked when the user clicks on the waterfall.
    /// The parameter is the frequency in Hz at the click position.
    public var onFrequencyTap: ((Double) -> Void)?

    public init(renderer: WaterfallRenderer, onFrequencyTap: ((Double) -> Void)? = nil) {
        self.renderer = renderer
        self.onFrequencyTap = onFrequencyTap
    }

    public func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = renderer.device
        view.delegate = renderer
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false  // continuous rendering at 60fps
        view.isPaused = false

        // Click gesture for tune-to-frequency.
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleClick(_:))
        )
        view.addGestureRecognizer(click)

        return view
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        // The renderer reads its own state each frame; no explicit update needed.
        context.coordinator.parent = self
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    /// Handles click gestures and converts them to frequency tap callbacks.
    public final class Coordinator: NSObject {
        var parent: WaterfallView

        init(parent: WaterfallView) {
            self.parent = parent
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let point = gesture.location(in: view)
            let size = view.bounds.size
            let frequency = parent.renderer.frequency(atPoint: point, viewSize: size)
            parent.onFrequencyTap?(frequency)
        }
    }
}
