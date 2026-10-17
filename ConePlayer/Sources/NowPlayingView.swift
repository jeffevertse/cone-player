import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        if let item = player.current {
            switch item.kind {
            case .video:
                VideoSurface(player: player)
                    .background(.black)
            case .audio:
                AudioArtwork(item: item)
            }
        } else {
            ContentUnavailableView("Nothing Playing", systemImage: "play.slash",
                                   description: Text("Pick something from your library."))
        }
    }
}

private struct AudioArtwork: View {
    let item: MediaItem
    @Environment(PlayerController.self) private var player

    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Theme.artwork(for: item.title)
                ForEach([0.32, 0.56, 0.8], id: \.self) { scale in
                    Circle()
                        .strokeBorder(Theme.accent.opacity(1.1 - scale), lineWidth: 2)
                        .scaleEffect(scale)
                }
                Circle().fill(Theme.accent).frame(width: 28)
            }
            .frame(width: 360, height: 360)
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 30)
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 28, weight: .bold))
                Text(item.folderName)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(colors: [Theme.accent.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 520)
        }
    }
}
