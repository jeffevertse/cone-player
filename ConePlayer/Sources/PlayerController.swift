import AppKit
import Observation
import VLCKit

/// Owns the VLCKit media player and publishes its state to SwiftUI.
@MainActor
@Observable
final class PlayerController {
    private(set) var current: MediaItem?
    private(set) var isPlaying = false
    private(set) var elapsed: Duration = .zero
    private(set) var duration: Duration = .zero
    private(set) var errorMessage: String?

    /// 0...1 playback position. Setting it seeks.
    var position: Double = 0 {
        didSet {
            guard isScrubbing else { return }
            player.position = position
        }
    }
    var isScrubbing = false

    /// 0...100. VLC accepts up to 200, but anything above 100 amplifies.
    var volume: Double = 70 {
        didSet { player.audio?.volume = Int32(volume) }
    }

    /// The view VLC renders video into. There is one for the app's lifetime.
    let videoView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }()

    /// VLC's OpenGL output asserts on recent macOS; the AVSampleBufferDisplayLayer
    /// output is what VLC 4 itself uses on Apple platforms.
    private let player = VLCMediaPlayer(options: ["--vout=samplebufferdisplay"])
    private var pollTask: Task<Void, Never>?

    init() {
        player.drawable = videoView
        startPolling()
    }

    func play(_ item: MediaItem) {
        guard let media = VLCMedia(url: item.url) else {
            errorMessage = "Cone Player can't open \(item.url.lastPathComponent)."
            return
        }
        errorMessage = nil
        current = item
        position = 0
        player.media = media
        player.audio?.volume = Int32(volume)
        player.play()
    }

    func togglePlayPause() {
        guard current != nil else { return }
        player.isPlaying ? player.pause() : player.play()
    }

    func skip(by seconds: Int) {
        guard current != nil else { return }
        let target = max(0, Int(player.time.intValue) + seconds * 1000)
        player.time = VLCTime(int: Int32(clamping: target))
    }

    func stop() {
        player.stop()
        current = nil
    }

    // MARK: - State sync

    /// VLCKit's delegate callbacks arrive off the main thread; polling a few
    /// times a second keeps the UI in sync without crossing isolation domains.
    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func refresh() {
        isPlaying = player.isPlaying
        elapsed = .milliseconds(Int(player.time.intValue))
        duration = .milliseconds(Int(player.media?.length.intValue ?? 0))
        if !isScrubbing {
            position = player.position
        }
        if player.state == .error {
            errorMessage = "Playback failed."
        }
    }
}
