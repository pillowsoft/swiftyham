// EarthTexture.swift
// HamStationKit — Downloads and caches a NASA Blue Marble Earth texture.
//
// NASA imagery is public domain — no license restrictions.
// Uses a 2048x1024 image (~500KB) for reasonable size.

import Foundation
import AppKit

/// Downloads and caches a NASA Blue Marble Earth texture.
public actor EarthTextureManager {
    public static let shared = EarthTextureManager()

    private let cacheDir: URL
    private let textureURL = URL(string: "https://eoimages.gsfc.nasa.gov/images/imagerecords/57000/57752/land_shallow_topo_2048.jpg")!
    private let cachedFileName = "earth_texture_2048.jpg"

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("HamStationPro/textures", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public var cachedPath: URL { cacheDir.appendingPathComponent(cachedFileName) }

    /// Load the Earth texture, returning from cache if available, otherwise downloading from NASA.
    public func loadTexture() async -> NSImage? {
        // Check cache first
        if FileManager.default.fileExists(atPath: cachedPath.path),
           let image = NSImage(contentsOf: cachedPath) {
            return image
        }

        // Download from NASA
        do {
            let (data, _) = try await URLSession.shared.data(from: textureURL)
            try data.write(to: cachedPath)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}
