import SwiftUI

struct PlayerScreen: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch player.current?.kind {
                case .video:
                    VideoSurface(player: player)
                case .audio:
                    MusicView()
                case nil:
                    Color.black
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)

            ControlBar()
        }
    }
}

/// "Player – Music": blurred artwork behind a large rounded cover and the track title.
private struct MusicView: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.height - 240, proxy.size.width - 120, 738)
            ZStack {
                Theme.bar
                cover
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 60)
                    .opacity(0.45)
                    .clipped()

                VStack(spacing: 0) {
                    Spacer(minLength: 40)
                    cover
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: max(side, 160), height: max(side, 160))
                        .background(Color(hex: 0x090909))
                        .clipShape(.rect(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
                    Spacer(minLength: 40)
                    Text(player.displayTitle)
                        .font(.inter(24, .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 40)
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var cover: some View {
        if let artwork = player.artwork {
            Image(nsImage: artwork).resizable()
        } else {
            ZStack {
                Color(hex: 0x090909)
                ForEach([0.3, 0.5, 0.7], id: \.self) { scale in
                    Circle()
                        .strokeBorder(Theme.separator.opacity(1.2 - scale), lineWidth: 1.5)
                        .scaleEffect(scale)
                }
            }
        }
    }
}
