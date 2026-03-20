// FrequencyScale.swift
// HamStationKit — Frequency scale overlay for the waterfall display.
//
// Draws labeled frequency markers along the bottom of the waterfall,
// adapting marker density based on zoom level and view width.

import SwiftUI

/// Frequency scale overlay that draws tick marks and labels along the waterfall.
///
/// Markers are placed at round kHz intervals and labeled in kHz format
/// (e.g., "14070", "14074", "14078"). Uses monospaced font for alignment.
public struct FrequencyScale: View {

    /// Center frequency of the displayed bandwidth in Hz.
    public let centerFrequency: Double

    /// Total displayed bandwidth in Hz.
    public let bandwidth: Double

    /// Width of the view in points, used to determine marker density.
    public let viewWidth: CGFloat

    public init(centerFrequency: Double, bandwidth: Double, viewWidth: CGFloat) {
        self.centerFrequency = centerFrequency
        self.bandwidth = bandwidth
        self.viewWidth = viewWidth
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let markers = markerFrequencies()

            ZStack(alignment: .bottom) {
                // Background strip
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)

                // Frequency markers
                ForEach(markers, id: \.self) { freq in
                    let normalizedX = normalizedPosition(for: freq)
                    let xPos = normalizedX * width

                    VStack(spacing: 1) {
                        // Tick mark
                        Rectangle()
                            .fill(.white.opacity(0.7))
                            .frame(width: 1, height: 6)

                        // Label in kHz
                        Text(formatFrequency(freq))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .position(x: xPos, y: 10)
                }
            }
            .frame(height: 20)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Marker Calculation

    /// Calculate which frequencies should have labels, based on bandwidth and view width.
    ///
    /// Returns evenly-spaced round-number frequencies within the visible range.
    /// Marker spacing adapts to keep labels readable without overlapping.
    public func markerFrequencies() -> [Double] {
        guard bandwidth > 0, viewWidth > 0 else { return [] }

        let startFreq = centerFrequency - bandwidth / 2.0
        let endFreq = centerFrequency + bandwidth / 2.0

        // Choose a step that gives roughly one marker every 80-120 pixels.
        let targetMarkerCount = max(2, Int(viewWidth / 100))
        let rawStep = bandwidth / Double(targetMarkerCount)

        // Round step to a "nice" interval in Hz.
        let step = niceStep(rawStep)
        guard step > 0 else { return [] }

        // Find the first marker at or after startFreq that's a multiple of step.
        let firstMarker = ceil(startFreq / step) * step

        var markers: [Double] = []
        var freq = firstMarker
        while freq <= endFreq {
            markers.append(freq)
            freq += step
        }

        return markers
    }

    // MARK: - Private Helpers

    /// Compute the normalized [0,1] x position for a given frequency.
    private func normalizedPosition(for frequency: Double) -> CGFloat {
        guard bandwidth > 0 else { return 0.5 }
        let offset = frequency - centerFrequency
        return CGFloat(offset / bandwidth) + 0.5
    }

    /// Format a frequency in Hz as a kHz string (e.g., 14074000 -> "14074").
    private func formatFrequency(_ hz: Double) -> String {
        let khz = hz / 1000.0
        if khz == floor(khz) {
            return String(format: "%.0f", khz)
        } else {
            return String(format: "%.1f", khz)
        }
    }

    /// Round a raw frequency step to a "nice" value for human-readable markers.
    ///
    /// Snaps to 100 Hz, 500 Hz, 1 kHz, 2 kHz, 5 kHz, 10 kHz, etc.
    private func niceStep(_ raw: Double) -> Double {
        let niceValues: [Double] = [
            100, 200, 500,
            1_000, 2_000, 5_000,
            10_000, 20_000, 50_000,
            100_000, 200_000, 500_000,
            1_000_000,
        ]

        // Find the smallest nice value that's >= raw step.
        for nice in niceValues {
            if nice >= raw * 0.8 {
                return nice
            }
        }

        return niceValues.last ?? raw
    }
}
