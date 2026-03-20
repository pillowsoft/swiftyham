// WaterfallRenderer.swift
// HamStationKit — Metal-based GPU-accelerated waterfall spectrogram renderer.
//
// Renders a scrolling spectrogram (waterfall display) using a circular texture buffer.
// New FFT data is written as rows into a Metal texture; a fragment shader maps
// power values through a color palette lookup texture for display at 60fps.

import Metal
import MetalKit
import Accelerate
import simd

/// Uniforms passed to the waterfall fragment shader each frame.
struct WaterfallUniforms {
    var currentRow: Float      // normalized [0,1] — circular buffer write position
    var historyLines: Float    // total texture height (for scrolling math)
    var minDB: Float           // noise floor in dB
    var maxDB: Float           // strong signal ceiling in dB
    var vfoCursorX: Float      // normalized x position of VFO cursor (-1 if none)
    var modeWidthX: Float      // normalized half-width of mode bandwidth overlay
}

/// Metal-based waterfall renderer that displays a scrolling spectrogram.
///
/// `@unchecked Sendable` because Metal objects (`MTLDevice`, `MTLCommandQueue`, etc.)
/// have their own internal thread safety. The renderer is driven by `MTKViewDelegate`
/// callbacks on the main thread, and `updateFFTData` is called from the FFT worker.
/// Shared state (`currentRow`, uniforms) is only written from one thread at a time.
public final class WaterfallRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {

    // MARK: - Metal Objects

    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // MARK: - Textures

    /// Rolling texture: each row is one FFT frame. Width = fftBins, height = historyLines.
    /// Values are R32Float — raw normalized magnitude [0,1].
    private var waterfallTexture: MTLTexture!

    /// 256-wide 1D color lookup texture. Maps normalized magnitude → RGBA color.
    private var paletteTexture: MTLTexture!

    // MARK: - Vertex Buffer

    /// Full-screen quad (two triangles, 6 vertices as float2 position + float2 texcoord).
    private let vertexBuffer: MTLBuffer

    // MARK: - State

    /// Current write row in the circular texture buffer.
    private var currentRow: Int = 0

    /// Number of history lines stored in the waterfall texture.
    public let historyLines: Int

    /// Number of FFT bins (fftSize / 2) — width of the waterfall texture.
    public let fftBins: Int

    // MARK: - Display Configuration

    /// Color palette for waterfall rendering.
    public enum Palette: String, CaseIterable, Sendable {
        case cuteSDR = "CuteSDR"
        case rainbow = "Rainbow"
        case greyscale = "Greyscale"
        case night = "Night"
    }

    /// Currently active color palette.
    public var currentPalette: Palette = .cuteSDR {
        didSet {
            if oldValue != currentPalette {
                paletteTexture = generatePaletteTexture(currentPalette)
            }
        }
    }

    /// Minimum displayed power in dB (noise floor).
    public var minDB: Float = -120

    /// Maximum displayed power in dB (strong signal ceiling).
    public var maxDB: Float = -20

    // MARK: - Frequency Mapping

    /// Center frequency of the displayed bandwidth in Hz.
    public var centerFrequency: Double = 14_074_000

    /// Total displayed bandwidth in Hz (typically equals the sample rate).
    public var bandwidth: Double = 48_000

    // MARK: - Cursor Overlay

    /// Current VFO frequency in Hz. When set, a cursor line is drawn on the waterfall.
    public var vfoFrequency: Double?

    /// Current mode filter bandwidth in Hz. When set, a shaded overlay shows the passband.
    public var modeWidth: Double?

    // MARK: - Initialization

    /// Create a waterfall renderer backed by the given Metal device.
    ///
    /// - Parameters:
    ///   - device: The `MTLDevice` to use for rendering.
    ///   - fftBins: Number of FFT output bins (fftSize / 2). Default is 2048.
    ///   - historyLines: Number of history rows in the scrolling texture. Default is 1024.
    public init(device: MTLDevice, fftBins: Int = 2048, historyLines: Int = 1024) {
        self.device = device
        self.fftBins = fftBins
        self.historyLines = historyLines

        guard let queue = device.makeCommandQueue() else {
            fatalError("WaterfallRenderer: failed to create Metal command queue")
        }
        self.commandQueue = queue

        // Build render pipeline from embedded shader source.
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: WaterfallRenderer.shaderSource, options: nil)
        } catch {
            fatalError("WaterfallRenderer: failed to compile Metal shaders — \(error)")
        }

        guard let vertexFunc = library.makeFunction(name: "waterfall_vertex"),
              let fragmentFunc = library.makeFunction(name: "waterfall_fragment") else {
            fatalError("WaterfallRenderer: shader functions not found in library")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("WaterfallRenderer: failed to create render pipeline state — \(error)")
        }

        // Full-screen quad: 6 vertices (two triangles).
        // Each vertex: float2 position (clip space) + float2 texCoord.
        let quadVertices: [SIMD4<Float>] = [
            // Triangle 1
            SIMD4<Float>(-1, -1, 0, 1),  // bottom-left  pos, uv
            SIMD4<Float>( 1, -1, 1, 1),  // bottom-right
            SIMD4<Float>(-1,  1, 0, 0),  // top-left
            // Triangle 2
            SIMD4<Float>(-1,  1, 0, 0),  // top-left
            SIMD4<Float>( 1, -1, 1, 1),  // bottom-right
            SIMD4<Float>( 1,  1, 1, 0),  // top-right
        ]

        guard let vbuf = device.makeBuffer(
            bytes: quadVertices,
            length: MemoryLayout<SIMD4<Float>>.stride * quadVertices.count,
            options: .storageModeShared
        ) else {
            fatalError("WaterfallRenderer: failed to create vertex buffer")
        }
        self.vertexBuffer = vbuf

        super.init()

        // Create textures.
        self.waterfallTexture = makeWaterfallTexture()
        self.paletteTexture = generatePaletteTexture(currentPalette)
    }

    // MARK: - FFT Data Input

    /// Update the waterfall with a new line of FFT magnitude data.
    ///
    /// Called from the FFT processing thread at ~30-60 Hz. Each call writes one
    /// horizontal row into the circular texture buffer and advances the write cursor.
    ///
    /// - Parameter magnitudes: Array of FFT magnitude values in dB. Length should
    ///   match `fftBins`; shorter arrays are zero-padded, longer arrays are truncated.
    public func updateFFTData(_ magnitudes: [Float]) {
        guard let texture = waterfallTexture else { return }

        // Normalize dB values to [0, 1] range based on min/max display range.
        let range = maxDB - minDB
        let invRange: Float = range > 0 ? 1.0 / range : 1.0

        var normalized = [Float](repeating: 0, count: fftBins)
        let count = min(magnitudes.count, fftBins)
        for i in 0..<count {
            let clamped = min(max(magnitudes[i], minDB), maxDB)
            normalized[i] = (clamped - minDB) * invRange
        }

        // Write one row to the texture at currentRow.
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: currentRow, z: 0),
            size: MTLSize(width: fftBins, height: 1, depth: 1)
        )
        normalized.withUnsafeBufferPointer { ptr in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: MemoryLayout<Float>.stride * fftBins
            )
        }

        currentRow = (currentRow + 1) % historyLines
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No additional setup needed on resize; the quad fills the viewport.
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        encoder.setRenderPipelineState(pipelineState)

        // Vertex buffer
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Fragment textures
        encoder.setFragmentTexture(waterfallTexture, index: 0)
        encoder.setFragmentTexture(paletteTexture, index: 1)

        // Fragment uniforms
        var uniforms = WaterfallUniforms(
            currentRow: Float(currentRow) / Float(historyLines),
            historyLines: Float(historyLines),
            minDB: minDB,
            maxDB: maxDB,
            vfoCursorX: vfoCursorNormalizedX(),
            modeWidthX: modeWidthNormalizedX()
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WaterfallUniforms>.stride, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Click-to-Frequency

    /// Convert a click point in the view to a frequency in Hz.
    ///
    /// Maps the x coordinate linearly across the displayed bandwidth, with the
    /// center frequency at the horizontal midpoint.
    ///
    /// - Parameters:
    ///   - point: The click location in view coordinates.
    ///   - viewSize: The size of the view.
    /// - Returns: The frequency in Hz corresponding to the x position.
    public func frequency(atPoint point: CGPoint, viewSize: CGSize) -> Double {
        guard viewSize.width > 0 else { return centerFrequency }
        let normalizedX = point.x / viewSize.width  // 0 = left, 1 = right
        let freqOffset = (normalizedX - 0.5) * bandwidth
        return centerFrequency + freqOffset
    }

    // MARK: - Palette Management

    /// Switch to a new color palette.
    public func setPalette(_ palette: Palette) {
        currentPalette = palette
    }

    // MARK: - Private Helpers

    private func makeWaterfallTexture() -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: fftBins,
            height: historyLines,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .managed

        guard let texture = device.makeTexture(descriptor: desc) else {
            fatalError("WaterfallRenderer: failed to create waterfall texture")
        }

        // Zero-fill the texture.
        let zeros = [Float](repeating: 0, count: fftBins * historyLines)
        zeros.withUnsafeBufferPointer { ptr in
            texture.replace(
                region: MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: 0),
                    size: MTLSize(width: fftBins, height: historyLines, depth: 1)
                ),
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: MemoryLayout<Float>.stride * fftBins
            )
        }

        return texture
    }

    /// Generate a 256-entry 1D palette texture for the given palette style.
    private func generatePaletteTexture(_ palette: Palette) -> MTLTexture {
        let size = 256
        let desc = MTLTextureDescriptor()
        desc.textureType = .type1D
        desc.pixelFormat = .rgba8Unorm
        desc.width = size
        desc.usage = .shaderRead
        desc.storageMode = .managed

        guard let texture = device.makeTexture(descriptor: desc) else {
            fatalError("WaterfallRenderer: failed to create palette texture")
        }

        var pixels = [UInt8](repeating: 0, count: size * 4)

        for i in 0..<size {
            let t = Float(i) / Float(size - 1)  // 0.0 ... 1.0
            let (r, g, b) = paletteColor(t, palette: palette)
            pixels[i * 4 + 0] = UInt8(clamping: Int(r * 255))
            pixels[i * 4 + 1] = UInt8(clamping: Int(g * 255))
            pixels[i * 4 + 2] = UInt8(clamping: Int(b * 255))
            pixels[i * 4 + 3] = 255
        }

        pixels.withUnsafeBufferPointer { ptr in
            texture.replace(
                region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                  size: MTLSize(width: size, height: 1, depth: 1)),
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: size * 4
            )
        }

        return texture
    }

    /// Compute RGB color for a normalized value `t` in [0,1] using the specified palette.
    private func paletteColor(_ t: Float, palette: Palette) -> (Float, Float, Float) {
        switch palette {
        case .cuteSDR:
            return cuteSDRColor(t)
        case .rainbow:
            return rainbowColor(t)
        case .greyscale:
            return (t, t, t)
        case .night:
            return nightColor(t)
        }
    }

    /// CuteSDR palette: black -> blue -> cyan -> green -> yellow -> red -> white
    private func cuteSDRColor(_ t: Float) -> (Float, Float, Float) {
        // 6 gradient stops at t = 0.0, 0.17, 0.33, 0.50, 0.67, 0.83, 1.0
        let stops: [(Float, Float, Float)] = [
            (0.0, 0.0, 0.0),  // black
            (0.0, 0.0, 1.0),  // blue
            (0.0, 1.0, 1.0),  // cyan
            (0.0, 1.0, 0.0),  // green
            (1.0, 1.0, 0.0),  // yellow
            (1.0, 0.0, 0.0),  // red
            (1.0, 1.0, 1.0),  // white
        ]
        return interpolateStops(stops, at: t)
    }

    /// Rainbow palette: full HSV hue sweep.
    private func rainbowColor(_ t: Float) -> (Float, Float, Float) {
        let hue = t * 300.0 / 360.0  // sweep from red through magenta (skip wrap)
        return hsvToRGB(h: hue, s: 1.0, v: min(t * 3.0, 1.0))
    }

    /// Night palette: black -> dark red -> bright red (preserves dark-adapted vision).
    private func nightColor(_ t: Float) -> (Float, Float, Float) {
        let r = t
        let g = max(0, t - 0.8) * 0.5  // slight orange tint at very top
        let b: Float = 0.0
        return (r, g, b)
    }

    /// Linearly interpolate between evenly-spaced color stops.
    private func interpolateStops(_ stops: [(Float, Float, Float)], at t: Float) -> (Float, Float, Float) {
        let segments = Float(stops.count - 1)
        let scaledT = t * segments
        let index = Int(scaledT)
        let frac = scaledT - Float(index)

        let i0 = min(index, stops.count - 1)
        let i1 = min(index + 1, stops.count - 1)

        let c0 = stops[i0]
        let c1 = stops[i1]

        return (
            c0.0 + (c1.0 - c0.0) * frac,
            c0.1 + (c1.1 - c0.1) * frac,
            c0.2 + (c1.2 - c0.2) * frac
        )
    }

    /// Convert HSV to RGB. All values in [0,1].
    private func hsvToRGB(h: Float, s: Float, v: Float) -> (Float, Float, Float) {
        let c = v * s
        let x = c * (1 - abs(fmod(h * 6.0, 2.0) - 1))
        let m = v - c

        let (r1, g1, b1): (Float, Float, Float)
        let hueSegment = Int(h * 6.0) % 6
        switch hueSegment {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }

        return (r1 + m, g1 + m, b1 + m)
    }

    /// Compute normalized x position of the VFO cursor, or -1 if not set.
    private func vfoCursorNormalizedX() -> Float {
        guard let vfo = vfoFrequency, bandwidth > 0 else { return -1 }
        let offset = vfo - centerFrequency
        let normalized = Float(offset / bandwidth) + 0.5
        if normalized < 0 || normalized > 1 { return -1 }
        return normalized
    }

    /// Compute normalized half-width of the mode bandwidth overlay, or 0 if not set.
    private func modeWidthNormalizedX() -> Float {
        guard let width = modeWidth, bandwidth > 0 else { return 0 }
        return Float(width / bandwidth) * 0.5
    }

    // MARK: - Embedded Shader Source

    /// Metal Shading Language source compiled at runtime.
    /// For production, move to a .metal file compiled into the default library.
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    struct WaterfallUniforms {
        float currentRow;
        float historyLines;
        float minDB;
        float maxDB;
        float vfoCursorX;
        float modeWidthX;
    };

    vertex VertexOut waterfall_vertex(
        uint vertexID [[vertex_id]],
        constant float4 *vertices [[buffer(0)]]
    ) {
        VertexOut out;
        float4 v = vertices[vertexID];
        out.position = float4(v.xy, 0.0, 1.0);
        out.texCoord = v.zw;
        return out;
    }

    fragment float4 waterfall_fragment(
        VertexOut in [[stage_in]],
        texture2d<float> waterfallTex [[texture(0)]],
        texture1d<float> paletteTex [[texture(1)]],
        constant WaterfallUniforms &uniforms [[buffer(0)]]
    ) {
        constexpr sampler nearestSampler(mag_filter::nearest, min_filter::nearest, address::repeat);
        constexpr sampler linearSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

        // Scroll the Y coordinate so the newest data appears at the top.
        float scrolledY = fract(in.texCoord.y + uniforms.currentRow);

        float2 sampleCoord = float2(in.texCoord.x, scrolledY);
        float magnitude = waterfallTex.sample(nearestSampler, sampleCoord).r;

        // Map magnitude [0,1] through the palette LUT.
        float4 color = paletteTex.sample(linearSampler, magnitude);

        // VFO cursor line: bright vertical line at the tuned frequency.
        if (uniforms.vfoCursorX >= 0.0) {
            float dist = abs(in.texCoord.x - uniforms.vfoCursorX);
            float cursorWidth = 0.002;  // normalized width of cursor line
            if (dist < cursorWidth) {
                float alpha = 1.0 - (dist / cursorWidth);
                color = mix(color, float4(1.0, 0.0, 0.0, 1.0), alpha * 0.8);
            }

            // Mode bandwidth overlay: semi-transparent tint around VFO.
            if (uniforms.modeWidthX > 0.0) {
                float halfWidth = uniforms.modeWidthX;
                float fromVFO = abs(in.texCoord.x - uniforms.vfoCursorX);
                if (fromVFO < halfWidth) {
                    color = mix(color, float4(1.0, 1.0, 1.0, 1.0), 0.1);
                }
            }
        }

        return color;
    }
    """
}
