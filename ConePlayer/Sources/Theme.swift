import SwiftUI

/// Design tokens read from the VLC Redesign (Community) Figma file via its API.
enum Theme {
    // MARK: Surfaces
    static let canvas = Color(hex: 0x0E0E0E)        // window and library background
    static let panel = Color(hex: 0x191919)         // sidebar panel, control bar
    static let bar = Color(hex: 0x1B1B1B)           // top bar, miniplayer
    static let barStroke = Color(hex: 0x222222)
    static let field = Color(hex: 0x151515)         // search field
    static let thumbnail = Color(hex: 0x171717)
    static let preview = Color(hex: 0x303030)
    static let well = Color(hex: 0x090909)          // progress and volume tracks
    static let wedge = Color(hex: 0x262626)

    // MARK: Text and icons
    static let textPrimary = Color(hex: 0x969696)
    static let textSecondary = Color(hex: 0x8F8F8F)
    static let textMuted = Color(hex: 0x6B6B6B)
    static let separator = Color(hex: 0x404040)
    static let textBright = Color(hex: 0xC6C6C6)

    // MARK: Accent
    static let accent = Color(hex: 0xD37918)
    static let accentDim = Color(hex: 0xAB6314)     // played waveform bars
    static let accentWell = Color(hex: 0x371F06)    // played part of the progress track

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
