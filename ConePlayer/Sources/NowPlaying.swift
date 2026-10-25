import AppKit
import MediaPlayer

/// Connects Cone Player to macOS's Now Playing system, so the media keys (F7–F9),
/// headphone and AirPods buttons, and Control Center's player control playback, and
/// Control Center shows what's playing.
@MainActor
final class NowPlaying {
    private weak var player: PlayerController?
    private var published: (key: String?, isPlaying: Bool, elapsed: Double, duration: Double, hasArtwork: Bool)?

    init(player: PlayerController) {
        self.player = player
        let commands = MPRemoteCommandCenter.shared()
        register(commands.playCommand) { $0.resume() }
        register(commands.pauseCommand) { $0.pause() }
        register(commands.togglePlayPauseCommand) { $0.togglePlayPause() }
        register(commands.nextTrackCommand) { $0.next() }
        register(commands.previousTrackCommand) { $0.previous() }
        register(commands.skipForwardCommand) { $0.jumpForward() }
        register(commands.skipBackwardCommand) { $0.jumpBack() }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let seconds = event.positionTime
            Task { @MainActor in self?.player?.seek(toSeconds: seconds) }
            return .success
        }
    }

    private func register(_ command: MPRemoteCommand, _ action: @escaping @MainActor (PlayerController) -> Void) {
        // macOS may call these off the main thread, so hop to the main actor rather
        // than assume it.
        command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let player = self?.player, player.current != nil else { return }
                action(player)
            }
            return .success
        }
    }

    /// Publishes the current item. Cheap to call often: it only writes to macOS when the
    /// item, play state, artwork or length changes, or when playback jumps (a seek).
    func update() {
        guard let player, let item = player.current else {
            clear()
            return
        }
        let elapsed = Double(player.elapsed.components.seconds)
        let duration = Double(player.duration.components.seconds)
        let expected = published.map { $0.isPlaying ? $0.elapsed + 0.25 : $0.elapsed } ?? -10
        let changed = published?.key != item.key
            || published?.isPlaying != player.isPlaying
            || published?.duration != duration
            || published?.hasArtwork != (player.artwork != nil)
            || abs(elapsed - expected) > 2
        guard changed || published == nil else {
            published?.elapsed = elapsed
            return
        }
        published = (item.key, player.isPlaying, elapsed, duration, player.artwork != nil)

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: player.displayTitle.isEmpty ? item.title : player.displayTitle,
            MPMediaItemPropertyArtist: item.folderName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? player.settings.playbackRate : 0,
            MPNowPlayingInfoPropertyMediaType: (item.kind == .audio ? MPNowPlayingInfoMediaType.audio : .video).rawValue,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if item.isStream && duration == 0 { info[MPNowPlayingInfoPropertyIsLiveStream] = true }
        if let artwork = player.artwork {
            nonisolated(unsafe) let image = artwork
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = player.isPlaying ? .playing : .paused

        let commands = MPRemoteCommandCenter.shared()
        commands.nextTrackCommand.isEnabled = player.hasNext
        commands.skipForwardCommand.preferredIntervals = [NSNumber(value: player.settings.jumpInterval)]
        commands.skipBackwardCommand.preferredIntervals = [NSNumber(value: player.settings.jumpInterval)]
    }

    func clear() {
        guard published != nil else { return }
        published = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
