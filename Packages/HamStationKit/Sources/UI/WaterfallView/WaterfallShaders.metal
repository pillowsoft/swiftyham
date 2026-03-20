// WaterfallShaders.metal
// HamStationKit — Metal shaders for the waterfall spectrogram display.
//
// The waterfall uses a circular texture buffer: new FFT rows are written at
// `currentRow` and the fragment shader scrolls the UV coordinates to keep the
// newest data at the top of the display. Power values are mapped through a
// 1D palette texture for coloring.

#include <metal_stdlib>
using namespace metal;

// MARK: - Data Structures

/// Vertex shader output / fragment shader input.
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

/// Per-frame uniforms controlling scroll position, display range, and overlays.
struct WaterfallUniforms {
    float currentRow;      // Normalized [0,1] write cursor position in circular buffer
    float historyLines;    // Total texture height (number of history rows)
    float minDB;           // Display floor in dB (e.g. -120)
    float maxDB;           // Display ceiling in dB (e.g. -20)
    float vfoCursorX;      // Normalized x of VFO cursor, or -1 if inactive
    float modeWidthX;      // Normalized half-width of mode passband overlay
};

// MARK: - Vertex Shader

/// Pass-through vertex shader for a full-screen quad.
///
/// Expects 6 vertices (two triangles) with layout: float4(posX, posY, texU, texV).
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

// MARK: - Fragment Shader

/// Waterfall fragment shader.
///
/// 1. Computes scrolled Y coordinate using the circular buffer offset.
/// 2. Samples the waterfall texture to get a raw magnitude value [0,1].
/// 3. Maps the magnitude through a 1D palette texture for coloring.
/// 4. Draws a VFO cursor line if `vfoCursorX >= 0`.
/// 5. Draws a semi-transparent mode bandwidth overlay if `modeWidthX > 0`.
fragment float4 waterfall_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> waterfallTex [[texture(0)]],
    texture1d<float> paletteTex [[texture(1)]],
    constant WaterfallUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler nearestSampler(
        mag_filter::nearest,
        min_filter::nearest,
        address::repeat
    );
    constexpr sampler linearSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Scroll Y so the write cursor (newest data) is at the top of the view.
    // fract() wraps around the circular buffer boundary.
    float scrolledY = fract(in.texCoord.y + uniforms.currentRow);

    // Sample the waterfall texture for raw magnitude [0,1].
    float2 sampleCoord = float2(in.texCoord.x, scrolledY);
    float magnitude = waterfallTex.sample(nearestSampler, sampleCoord).r;

    // Map magnitude through the palette lookup texture.
    float4 color = paletteTex.sample(linearSampler, magnitude);

    // Draw VFO cursor line if active.
    if (uniforms.vfoCursorX >= 0.0) {
        float dist = abs(in.texCoord.x - uniforms.vfoCursorX);

        // Cursor line: 2 pixels wide (normalized), red with fade.
        float cursorWidth = 0.002;
        if (dist < cursorWidth) {
            float alpha = 1.0 - (dist / cursorWidth);
            float4 cursorColor = float4(1.0, 0.0, 0.0, 1.0);
            color = mix(color, cursorColor, alpha * 0.8);
        }

        // Mode bandwidth overlay: slight white tint within the passband.
        if (uniforms.modeWidthX > 0.0) {
            float halfWidth = uniforms.modeWidthX;
            float fromVFO = abs(in.texCoord.x - uniforms.vfoCursorX);
            if (fromVFO < halfWidth) {
                float4 overlayColor = float4(1.0, 1.0, 1.0, 1.0);
                color = mix(color, overlayColor, 0.1);
            }
        }
    }

    return color;
}
