import SwiftUI

/// Floating player shown over the library while something is playing.
struct Miniplayer: View {
    @Environment(PlayerController.self) private var player
    @Environment(Navigation.self) private var navigation

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 4) {
                Button { navigation.screen = .player } label: {
                    preview
                        .frame(width: 375, height: 210)
                        .background(Theme.preview)
                        .clipShape(.rect(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.well))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show Player")

                ProgressTrack(style: .compact)
                    .frame(height: 16)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(player.displayTitle)
                    .font(.inter(16))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 20) {
                    if let folder = player.current?.folderName {
                        Label(folder, systemImage: "folder")
                            .font(.inter(14))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    PlayButton()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .padding(8)
        .frame(width: 391)
        .background(Theme.bar, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }

    @ViewBuilder private var preview: some View {
        if player.current?.kind == .video {
            VideoSurface(player: player)
        } else if let artwork = player.artwork {
            Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

/// The orange play/pause pill from the Figma control bar (54×28, radius 6).
struct PlayButton: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x161616))
                .frame(width: 54, height: 28)
                .background(Theme.accent, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}
