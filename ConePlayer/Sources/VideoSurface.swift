import SwiftUI

/// Hosts the view VLCKit renders video into.
///
/// VLC's video layer can draw outside its view's bounds, so it sits inside a
/// container that clips it; otherwise it covers the top bar.
struct VideoSurface: NSViewRepresentable {
    let player: PlayerController

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        let video = player.videoView
        video.removeFromSuperview()
        video.frame = container.bounds
        video.autoresizingMask = [.width, .height]
        container.addSubview(video)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
