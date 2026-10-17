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
            .overlay(alignment: .bottom) {
                if let message = player.errorMessage {
                    MessageBanner(text: message)
                        .padding(.bottom, 24)
                } else if let offer = player.resumeOffer {
                    ResumeBanner(time: offer)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: player.resumeOffer)

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

/// The Figma's "You've watched till …" banner, shown when a file was stopped part-way.
private struct ResumeBanner: View {
    let time: Duration
    @Environment(PlayerController.self) private var player

    var body: some View {
        HStack(spacing: 24) {
            Text("You’ve watched till \(time.clockString) already.")
                .font(.inter(16))
                .foregroundStyle(Theme.textBright)
            Button { player.acceptResume() } label: {
                Text("Continue Watching")
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color(hex: 0x161616))
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Theme.accent, in: .rect(cornerRadius: 6))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .keyboardShortcut(.defaultAction)
            Button { player.dismissResume() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 20, height: 20)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel("Start from the Beginning")
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(Theme.panel.opacity(0.95), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }
}

/// Same pill as the resume banner, for messages without an action.
private struct MessageBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.inter(15))
            .foregroundStyle(Theme.textBright)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.panel.opacity(0.95), in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            .padding(.horizontal, 40)
    }
}
