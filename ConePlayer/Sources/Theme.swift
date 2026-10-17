import SwiftUI

/// Design tokens taken from the VLC Redesign (Community) Figma file.
enum Theme {
    static let background = Color(red: 0.086, green: 0.086, blue: 0.086)   // #161616
    static let panel = Color(red: 0.118, green: 0.118, blue: 0.118)        // #1E1E1E
    static let panelRaised = Color(red: 0.149, green: 0.149, blue: 0.149)  // #262626
    static let stroke = Color(red: 0.184, green: 0.184, blue: 0.184)       // #2F2F2F
    static let accent = Color(red: 1.0, green: 0.533, blue: 0.0)           // #FF8800
    static let accentSoft = accent.opacity(0.14)

    static let cornerRadius: CGFloat = 10

    /// A deterministic placeholder gradient for media without artwork.
    static func artwork(for seed: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.23, green: 0.08, blue: 0.0), .black],
            [Color(red: 0.04, green: 0.08, blue: 0.15), .black],
            [Color(red: 0.42, green: 0.05, blue: 0.0), .black],
            [Color(red: 0.11, green: 0.06, blue: 0.2), .black],
            [Color(red: 0.06, green: 0.24, blue: 0.14), .black],
        ]
        let index = abs(seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % palettes.count
        return LinearGradient(colors: palettes[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Duration {
    /// Formats as m:ss or h:mm:ss, the way the control bar shows times.
    var playbackString: String {
        let total = Int(components.seconds)
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
