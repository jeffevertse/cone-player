import AppKit
import SwiftUI

/// Design tokens for Cone Player.
enum Theme {
    // Dark values are from the VLC Redesign (Community) Figma; light values are
    // derived from them, keeping text at 4.5:1 or better on its background.

    // MARK: Surfaces
    static let canvas = Color(light: 0xF2F2F2, dark: 0x0E0E0E)        // window and library background
    static let panel = Color(light: 0xFFFFFF, dark: 0x191919)         // sidebar panel, control bar
    static let bar = Color(light: 0xFAFAFA, dark: 0x1B1B1B)           // top bar, miniplayer
    static let barStroke = Color(light: 0xE0E0E0, dark: 0x222222)
    static let field = Color(light: 0xE8E8E8, dark: 0x151515)         // search field
    static let thumbnail = Color(light: 0xE4E4E4, dark: 0x171717)
    static let preview = Color(light: 0xD6D6D6, dark: 0x303030)
    static let well = Color(light: 0xE6E6E6, dark: 0x090909)          // progress and volume tracks
    static let wedge = Color(light: 0xCFCFCF, dark: 0x262626)
    static let selectedFill = Color(light: 0xEDEDED, dark: 0x222222)  // selected settings category

    // MARK: Text and icons
    static let textPrimary = Color(light: 0x333333, dark: 0x969696)
    static let textSecondary = Color(light: 0x555555, dark: 0x8F8F8F)
    static let textMuted = Color(light: 0x6E6E6E, dark: 0x6B6B6B)
    static let separator = Color(light: 0xB8B8B8, dark: 0x404040)
    static let textBright = Color(light: 0x1A1A1A, dark: 0xC6C6C6)
    static let selectedText = Color(light: 0x111111, dark: 0xEAEAEA)

    // MARK: Accent
    static let accent = Color(hex: 0xD37918)
    /// Orange for text and small icons: darker in light mode so it stays readable (4.5:1).
    static let accentText = Color(light: 0x9A4F00, dark: 0xD37918)
    static let accentDim = Color(hex: 0xAB6314)                       // played waveform bars, thumbs
    static let accentWell = Color(light: 0xF5DDC2, dark: 0x371F06)    // played part of the progress track
    /// Text and glyphs on an orange button.
    static let onAccent = Color(hex: 0x161616)

    /// VLC's volume ramp: green → yellow → orange → red (amplified).
    static let volumeGradient = Gradient(stops: [
        .init(color: Color(hex: 0x95D318), location: 0),
        .init(color: Color(hex: 0xB2A918), location: 0.58),
        .init(color: Color(hex: 0xD37918), location: 0.79),
        .init(color: Color(hex: 0xFF3737), location: 1),
    ])

    // MARK: Metrics
    static let topBarHeight: CGFloat = 40
    static let controlBarHeight: CGFloat = 54
    static let sidebarWidth: CGFloat = 217
}

extension Color {
    /// A color that follows the window's light or dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Inter, bundled in Resources/Fonts, matching the Figma typography.
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }
}

extension Duration {
    /// Formats as 00:02:10, the way the Figma control bar shows times.
    var clockString: String {
        let total = max(0, Int(components.seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
