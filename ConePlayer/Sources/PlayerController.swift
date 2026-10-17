import AppKit
import Observation
import VLCKit

/// Owns the VLCKit media player and publishes its state to SwiftUI.
@MainActor
@Observable
final class PlayerController {
    struct Track: Identifiable, Hashable {
        let id: String
        let name: String
        let isSelected: Bool
    }

    private(set) var current: MediaItem?
    private(set) var queue: [MediaItem] = []
    private(set) var isPlaying = false
    private(set) var elapsed: Duration = .zero
    private(set) var duration: Duration = .zero
    private(set) var errorMessage: String?
    /// Set while the "You've watched till …" banner offers to resume.
    private(set) var resumeOffer: Duration?

    /// "Artist - Title" from the file's metadata, falling back to the file name.
    private(set) var displayTitle = ""
    private(set) var artwork: NSImage?

    /// 0...1 playback position. While scrubbing, setting it seeks.
    var position: Double = 0 {
        didSet {
            guard isScrubbing else { return }
            player.position = position
        }
    }
    var isScrubbing = false

    /// 0...200 like VLC; anything above 100 amplifies.
    var volume: Double = 100 {
        didSet { player.audio?.volume = Int32(volume.rounded()) }
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
    private var hasStarted = false
    /// Set when the last item finishes, so the bar shows 00:00:00 instead of VLC's final position.
    private var isAtEnd = false
    private var loadedArtworkURL: URL?
    /// Elapsed time when progress was last saved, to save every few seconds.
    private var lastSaved: Duration = .zero
    private var terminationObserver: (any NSObjectProtocol)?
    /// The file whose sandbox access we hold; see `beginAccess(to:)`.
    private var accessedURL: URL?

    let settings: SettingsStore
    let history: PlaybackHistory

    init(settings: SettingsStore, history: PlaybackHistory) {
        self.settings = settings
        self.history = history
        player.drawable = videoView
        settings.onChange = { [weak self] in self?.applySettings() }
        startPolling()
        // Save the exact position on quit, not just the last 5-second checkpoint.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveProgress() }
        }
    }

    // MARK: - Commands

    /// Plays `item`; `queue` is the list that previous/next walk through.
    func play(_ item: MediaItem, in queue: [MediaItem]? = nil) {
        saveProgress()
        beginAccess(to: item.url)
        // A file from Recent or a playlist that was saved without a bookmark, or that
        // moved, can't be read; say so instead of showing a silent black screen.
        guard item.isStream || FileManager.default.isReadableFile(atPath: item.url.path) else {
            player.stop()
            if let queue { self.queue = queue }
            current = item
            displayTitle = item.title
            artwork = nil
            isPlaying = false
            position = 0
            elapsed = .zero
            resumeOffer = nil
            errorMessage = "Cone Player can't read “\(item.fileName)”. Open it again with File › Open to give it access."
            return
        }
        if item.isStream { history.touch(item) }
        guard let media = VLCMedia(url: item.url) else {
            errorMessage = "Cone Player can't open \(item.fileName)."
            return
        }
        if let queue { self.queue = queue } else if !self.queue.contains(item) { self.queue = [item] }
        errorMessage = nil
        current = item
        displayTitle = item.title
        artwork = nil
        loadedArtworkURL = nil
        position = 0
        hasStarted = false
        isAtEnd = false
        lastSaved = .zero
        resumeOffer = nil
        if let resumePoint = history.resumePoint(for: item) {
            switch settings.resumeMode {
            case .always:
                media.addOption(":start-time=\(resumePoint.components.seconds)")
            case .ask:
                resumeOffer = resumePoint
            case .never:
                break
            }
        }
        if !settings.preferredAudioLanguage.isEmpty {
            media.addOption(":audio-language=\(settings.preferredAudioLanguage)")
        }
        if !settings.preferredSubtitleLanguage.isEmpty {
            media.addOption(":sub-language=\(settings.preferredSubtitleLanguage)")
        }
        player.media = media
        player.audio?.volume = Int32(volume.rounded())
        player.play()
    }

    func togglePlayPause() {
        guard current != nil else { return }
        if player.isPlaying {
            player.pause()
        } else if player.state != .paused, let current {
            // Finished or stopped: start the item again.
            play(current)
        } else {
            player.play()
        }
    }

    func jumpForward() { skip(by: settings.jumpInterval) }
    func jumpBack() { skip(by: -settings.jumpInterval) }

    func skip(by seconds: Int) {
        guard current != nil else { return }
        let target = max(0, Int(player.time.intValue) + seconds * 1000)
        player.time = VLCTime(int: Int32(clamping: target))
    }

    var hasNext: Bool { index.map { $0 + 1 < queue.count } ?? false }
    var hasPrevious: Bool { index.map { $0 > 0 } ?? false }

    func next() {
        guard let index, index + 1 < queue.count else { return }
        play(queue[index + 1])
    }

    /// Restarts the current item if it has played a few seconds, otherwise goes back one.
    func previous() {
        if elapsed > .seconds(3) || !hasPrevious {
            player.position = 0
        } else if let index {
            play(queue[index - 1])
        }
    }

    /// Jumps to where the file was left off, from the resume banner.
    func acceptResume() {
        guard let offer = resumeOffer else { return }
        player.time = VLCTime(int: Int32(clamping: Int(offer.components.seconds) * 1000))
        resumeOffer = nil
    }

    func dismissResume() {
        resumeOffer = nil
    }

    func stop() {
        saveProgress()
        player.stop()
        beginAccess(to: nil)
        current = nil
        queue = []
    }

    private var index: Int? { current.flatMap { queue.firstIndex(of: $0) } }

    // MARK: - Settings

    /// Pushes the current settings into VLC. Delays and subtitle size only stick
    /// once a file is playing, so this also runs when playback starts.
    private func applySettings() {
        player.rate = Float(settings.playbackRate)
        player.currentAudioPlaybackDelay = settings.audioDelay * 1000
        player.currentVideoSubTitleDelay = settings.subtitleDelay * 1000
        player.currentSubTitleFontScale = Float(settings.subtitleScale)
        player.equalizer = settings.isEqualizerEnabled
            ? Equalizer.make(preamp: settings.equalizerPreamp, bands: settings.equalizerBands)
            : nil
    }

    // MARK: - Tracks

    var audioTracks: [Track] { player.audioTracks.map(Track.init) }
    var subtitleTracks: [Track] { player.textTracks.map(Track.init) }

    func selectAudioTrack(_ id: String) {
        player.audioTracks.first { $0.trackId == id }?.isSelectedExclusively = true
    }

    func selectSubtitleTrack(_ id: String?) {
        guard let id else {
            player.deselectAllTextTracks()
            return
        }
        player.textTracks.first { $0.trackId == id }?.isSelectedExclusively = true
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
        guard current != nil else { return }
        isPlaying = player.isPlaying
        if isPlaying && !hasStarted {
            hasStarted = true
            applySettings()
        }
        duration = .milliseconds(Int(player.media?.length.intValue ?? 0))
        if isAtEnd {
            elapsed = .zero
            position = 0
        } else {
            elapsed = .milliseconds(Int(player.time.intValue))
            if !isScrubbing { position = player.position }
        }
        if isPlaying && (elapsed - lastSaved > .seconds(5) || elapsed < lastSaved) {
            saveProgress()
        }
        // Hide the resume banner after a while, as VLC does.
        if resumeOffer != nil && elapsed > .seconds(10) {
            resumeOffer = nil
        }
        if player.state == .error {
            errorMessage = "Playback failed."
        } else if hasStarted && !isPlaying && player.state != .paused && player.state != .opening {
            hasStarted = false
            // VLC also stops when a file or stream fails part-way. Only a stop near the
            // end (or the end of a live stream, which has no length) counts as finished.
            let reachedEnd = duration == .zero || player.position >= 0.9 || duration - elapsed < .seconds(3)
            if reachedEnd {
                if let current, duration > .zero { history.markFinished(current) }
                if hasNext && settings.autoPlayNext {
                    next()
                } else {
                    isAtEnd = true
                }
            } else {
                errorMessage = "Playback stopped unexpectedly. The file may be damaged or the stream unavailable."
            }
        }
        refreshMetadata()
    }

    /// Files picked in the Open panel or dropped on the window are security-scoped:
    /// the sandbox only lets VLC read them while we hold access. Files in the
    /// Movies/Music library don't need this (startAccessing returns false).
    private func beginAccess(to url: URL?) {
        guard url != accessedURL else { return }
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        if let url, url.startAccessingSecurityScopedResource() {
            accessedURL = url
        }
    }

    private func saveProgress() {
        guard let current, !isAtEnd, elapsed > .zero, duration > .zero else { return }
        lastSaved = elapsed
        history.record(
            current,
            seconds: Double(elapsed.components.seconds),
            progress: elapsed / duration
        )
    }

    private func refreshMetadata() {
        guard let meta = player.media?.metaData, let current else { return }
        if let title = meta.title, !title.isEmpty, title != current.fileName {
            displayTitle = [meta.artist, title].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
        }
        if let url = meta.artworkURL, url != loadedArtworkURL {
            loadedArtworkURL = url
            artwork = NSImage(contentsOf: url)
        }
    }
}

private extension PlayerController.Track {
    init(_ track: VLCMediaPlayer.Track) {
        self.init(id: track.trackId, name: track.trackName, isSelected: track.isSelected)
    }
}
