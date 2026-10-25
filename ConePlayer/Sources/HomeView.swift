import SwiftUI

/// Home: Continue Watching, Recently Added and Playlists, as horizontal rows of the
/// library's cards. Shown when the app opens.
struct HomeView: View {
    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @Environment(PlaybackHistory.self) private var history
    @Environment(PlaylistStore.self) private var playlists
    @Environment(Navigation.self) private var navigation

    /// Started but not finished, most recent first.
    private var inProgress: [MediaItem] {
        history.recentItems.filter { item in
            guard let entry = history.entry(for: item) else { return false }
            return !entry.isFinished && entry.seconds >= 10
        }
        .prefix(12).map { $0 }
    }

    private var recentlyAdded: [MediaItem] {
        (library.videos + library.music)
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(12).map { $0 }
    }

    var body: some View {
        if inProgress.isEmpty && recentlyAdded.isEmpty && playlists.playlists.isEmpty {
            welcome
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    if !inProgress.isEmpty {
                        row("Continue Watching", seeAll: .recent, items: inProgress)
                    }
                    if !recentlyAdded.isEmpty {
                        row("Recently Added", seeAll: recentlyAdded.first?.kind == .audio ? .music : .videos, items: recentlyAdded)
                    }
                    if !playlists.playlists.isEmpty {
                        playlistRow
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.never)
            .contentMargins(.bottom, player.current == nil || !player.settings.showsMiniplayer ? 0 : 340, for: .scrollContent)
        }
    }

    private func header(_ title: String, seeAll: LibrarySection) -> some View {
        HStack {
            Text(title)
                .font(.inter(16, .medium))
                .foregroundStyle(Theme.textBright)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("See All") { navigation.section = seeAll }
                .buttonStyle(.plain)
                .font(.inter(14))
                .foregroundStyle(Theme.accentText)
                .focusEffectDisabled()
        }
    }

    private func row(_ title: String, seeAll: LibrarySection, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title, seeAll: seeAll)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 20) {
                    ForEach(items) { item in
                        MediaCard(item: item, isCurrent: item == player.current) {
                            player.play(item, in: items)
                            navigation.screen = .player
                        }
                        .frame(width: 280)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private var playlistRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Playlists", seeAll: .playlists)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(playlists.playlists) { playlist in
                        Button {
                            navigation.section = .playlists
                            navigation.showFolder([playlist.id.uuidString])
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "list.triangle")
                                    .foregroundStyle(Theme.accentText)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.inter(14, .medium))
                                        .foregroundStyle(Theme.textBright)
                                    Text("^[\(playlist.files.count) item](inflect: true)")
                                        .font(.inter(12))
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(Theme.panel, in: .rect(cornerRadius: 10))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .accessibilityLabel("Open playlist \(playlist.name)")
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)
            Text("Welcome to Cone Player")
                .accessibilityIdentifier("home.welcome")
                .font(.inter(24, .medium))
                .foregroundStyle(Theme.textBright)
            Text("Add videos to Movies and music to Music, or open something now.")
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 12) {
                welcomeButton("Open File…", primary: true) { navigation.isImporting = true }
                welcomeButton("Open Network Stream…", primary: false) { navigation.isOpeningStream = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func welcomeButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.inter(14, .semibold))
                .foregroundStyle(primary ? Theme.onAccent : Theme.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(primary ? Theme.accent : Theme.panel, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}
