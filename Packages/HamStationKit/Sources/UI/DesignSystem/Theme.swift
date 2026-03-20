// Theme.swift — HamStation Pro Design System
// SF Pro for text, SF Mono for data. Orange accent, deep red night mode.

import SwiftUI

// MARK: - HamTheme

public enum HamTheme {

    // MARK: Colors

    public enum Colors {
        /// Primary accent — ham radio orange
        public static let accent = Color(hex: "FF6A00")

        /// Night mode base — deep red for dark-adapted vision
        public static let nightMode = Color(hex: "8B0000")
        public static let nightBackground = Color(hex: "1A0000")
        public static let nightText = Color(hex: "CC3333")
        public static let nightBorder = Color(hex: "661111")

        /// DX spot status colors
        public static let spotNeeded = Color.green
        public static let spotWorked = Color.yellow
        public static let spotConfirmed = Color.gray

        /// Band condition colors
        public static let bandGood = Color.green
        public static let bandFair = Color.yellow
        public static let bandPoor = Color.red

        /// K-index severity
        public static func kIndexColor(_ k: Int) -> Color {
            switch k {
            case 0...2: return .green
            case 3...4: return .yellow
            default: return .red
            }
        }

        /// Connection state
        public static let connected = Color.green
        public static let disconnected = Color.red
    }

    // MARK: Fonts

    public enum Fonts {
        /// Monospaced frequency display (e.g. "14.074.000")
        public static let frequency = Font.system(.body, design: .monospaced)
        /// Bold monospaced callsign (e.g. "W1AW")
        public static let callsign = Font.system(.body, design: .monospaced).bold()
        /// Small monospaced for data cells (RST, grid, etc.)
        public static let data = Font.system(.caption, design: .monospaced)
        /// Section header in sidebar/inspector
        public static let sectionHeader = Font.headline
        /// Large monospaced for toolbar frequency
        public static let toolbarFrequency = Font.system(.title3, design: .monospaced).monospacedDigit()
        /// Small monospaced for status bar
        public static let statusBar = Font.system(.caption2, design: .monospaced)
    }

    // MARK: Spacing

    public enum Spacing {
        /// 4pt — tightest spacing for dense data
        public static let compact: CGFloat = 4
        /// 8pt — standard element spacing
        public static let standard: CGFloat = 8
        /// 16pt — section/group spacing
        public static let section: CGFloat = 16
    }

    // MARK: Layout

    public enum Layout {
        public static let sidebarWidth: CGFloat = 220
        public static let inspectorWidth: CGFloat = 300
        public static let minWindowWidth: CGFloat = 1200
        public static let minWindowHeight: CGFloat = 800
        public static let statusBarHeight: CGFloat = 28
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    /// Create a Color from a hex string (e.g. "FF6A00" or "#FF6A00").
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6: // RGB
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8: // ARGB
            a = Double((int >> 24) & 0xFF) / 255.0
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
