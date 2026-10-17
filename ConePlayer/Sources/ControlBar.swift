import SwiftUI

/// The bottom transport bar: orange progress line, now-playing info, controls and volume.
struct ControlBar: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        @Bindable var player = player

        VStack(spacing: 0) {
            Slider(value: $player.position, in: 0...1) { editing in
                player.isScrubbing = editing
            }
            .controlSize(.mini)
            .disabled(player.current == nil)
            .accessibilityLabel("Playback position")
            .padding(.horizontal, 12)

            HStack {
                nowPlaying
                    .frame(maxWidth: .infinity, alignment: .leading)
                transport
                extras
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .background(Theme.panel)
        .overlay(alignment: .top) { Theme.stroke.frame(height: 1) }
    }

    private var nowPlaying: some View {
        HStack(spacing: 12) {
            Theme.artwork(for: player.current?.title ?? "")
                .overlay {
                    Image(systemName: player.current?.kind == .audio ? "music.note" : "film")
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(player.current?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(player.errorMessage ?? player.current?.folderName ?? "Open a file to start")
                    .font(.system(size: 12))
                    .foregroundStyle(player.errorMessage == nil ? .secondary : Color.red)
                    .lineLimit(1)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Text(player.elapsed.playbackString)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            Button { player.skip(by: -10) } label: { Image(systemName: "gobackward.10") }
                .accessibilityLabel("Back 10 seconds")
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent, in: .circle)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.skip(by: 10) } label: { Image(systemName: "goforward.10") }
                .accessibilityLabel("Forward 10 seconds")
            Text(player.duration.playbackString)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 18))
        .buttonStyle(.plain)
        .disabled(player.current == nil)
    }

    private var extras: some View {
        @Bindable var player = player
        return HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: $player.volume, in: 0...100)
                .controlSize(.mini)
                .frame(width: 100)
                .accessibilityLabel("Volume")
        }
    }
}
