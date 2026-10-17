import SwiftUI

/// Hosts the view VLCKit renders video into inside SwiftUI.
struct VideoSurface: NSViewRepresentable {
    let player: PlayerController

    func makeNSView(context: Context) -> NSView {
        player.videoView.removeFromSuperview()
        return player.videoView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
