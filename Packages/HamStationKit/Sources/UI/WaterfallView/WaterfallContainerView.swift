// WaterfallContainerView.swift
// HamStationKit — Complete waterfall view with palette, dB range, and band controls.
//
// Combines the Metal waterfall renderer, frequency scale overlay, VFO cursor,
// and control bar into a single self-contained view.

import SwiftUI
import MetalKit

/// Complete waterfall view with toolbar controls, frequency scale, and VFO cursor.
///
/// Includes palette picker, dB range sliders, and band selector. When a Metal
/// device is available, renders the live waterfall; otherwise displays a
/// placeholder gradient.
public struct WaterfallContainerView: View {

    @State private var selectedPalette: WaterfallRenderer.Palette = .cuteSDR
    @State private var minDB: Float = -120
    @State private var maxDB: Float = -20
    @State private var selectedBand: Band = .band20m

    /// Callback invoked when the user clicks on the waterfall to tune to a frequency.
    public var onFrequencyTap: ((Double) -> Void)?

    /// Current VFO frequency in Hz. Draws a cursor line on the waterfall when set.
    public var vfoFrequency: Double?

    /// Center frequency of the displayed bandwidth in Hz.
    public var centerFrequency: Double

    /// Total displayed bandwidth in Hz.
    public var bandwidth: Double

    /// Optional Metal renderer. When nil, a placeholder gradient is shown.
    public var renderer: WaterfallRenderer?

    public init(
        centerFrequency: Double = 14_074_000,
        bandwidth: Double = 48_000,
        renderer: WaterfallRenderer? = nil,
        vfoFrequency: Double? = nil,
        onFrequencyTap: ((Double) -> Void)? = nil
    ) {
        self.centerFrequency = centerFrequency
        self.bandwidth = bandwidth
        self.renderer = renderer
        self.vfoFrequency = vfoFrequency
        self.onFrequencyTap = onFrequencyTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Control Bar
            controlBar

            // MARK: - Waterfall Display
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    if let renderer {
                        // Live Metal waterfall
                        WaterfallView(renderer: renderer, onFrequencyTap: onFrequencyTap)
                    } else {
                        // Placeholder gradient simulating a waterfall
                        placeholderWaterfall
                    }

                    // Frequency scale along the bottom
                    FrequencyScale(
                        centerFrequency: centerFrequency,
                        bandwidth: bandwidth,
                        viewWidth: geometry.size.width
                    )

                    // VFO cursor line
                    if let vfo = vfoFrequency {
                        vfoCursorOverlay(vfo: vfo, viewWidth: geometry.size.width)
                    }
                }
            }
            .frame(minHeight: 300)
            .clipped()
        }
        .onChange(of: selectedPalette) { _, newPalette in
            renderer?.setPalette(newPalette)
        }
        .onChange(of: minDB) { _, newValue in
            renderer?.minDB = newValue
        }
        .onChange(of: maxDB) { _, newValue in
            renderer?.maxDB = newValue
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Palette picker
            Picker("Palette", selection: $selectedPalette) {
                ForEach(WaterfallRenderer.Palette.allCases, id: \.self) { palette in
                    Text(palette.rawValue).tag(palette)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            Spacer()

            // Floor dB slider
            HStack(spacing: 4) {
                Text("Floor")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Slider(value: $minDB, in: -140...(-40))
                    .frame(width: 100)
                Text("\(Int(minDB))")
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }

            // Ceiling dB slider
            HStack(spacing: 4) {
                Text("Ceil")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Slider(value: $maxDB, in: -60...0)
                    .frame(width: 100)
                Text("\(Int(maxDB))")
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }

            Spacer()

            // Band selector
            Picker("Band", selection: $selectedBand) {
                ForEach(Band.allCases, id: \.self) { band in
                    Text(band.displayName).tag(band)
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }

    // MARK: - Placeholder

    private var placeholderWaterfall: some View {
        ZStack {
            // Simulate a waterfall with a vertical gradient
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .blue.opacity(0.3), location: 0.2),
                    .init(color: .cyan.opacity(0.2), location: 0.4),
                    .init(color: .green.opacity(0.15), location: 0.6),
                    .init(color: .blue.opacity(0.1), location: 0.8),
                    .init(color: .black, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // "Waterfall View" label
            Text("Waterfall View")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - VFO Cursor Overlay

    private func vfoCursorOverlay(vfo: Double, viewWidth: CGFloat) -> some View {
        let offset = vfo - centerFrequency
        let normalizedX = offset / bandwidth + 0.5
        let xPos = CGFloat(normalizedX) * viewWidth

        return Rectangle()
            .fill(.red.opacity(0.6))
            .frame(width: 2)
            .position(x: xPos, y: 0)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("Waterfall Container") {
    WaterfallContainerView(
        centerFrequency: 14_074_000,
        bandwidth: 48_000,
        vfoFrequency: 14_074_500
    )
    .frame(width: 800, height: 400)
}

#Preview("Waterfall Container - Dark") {
    WaterfallContainerView(
        centerFrequency: 7_074_000,
        bandwidth: 48_000,
        vfoFrequency: 7_076_000
    )
    .frame(width: 800, height: 400)
    .preferredColorScheme(.dark)
}
