import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case nowPlaying, videos, music
}

struct ContentView: View {
    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @State private var selection: SidebarItem = .videos

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                Sidebar(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 300)
            } detail: {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
            ControlBar()
        }
        .background(Theme.background)
        .task { await library.scan() }
        .onChange(of: player.current) { _, item in
            if item != nil { selection = .nowPlaying }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let item = urls.lazy.compactMap(MediaItem.init(url:)).first else { return false }
            player.play(item)
            return true
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .nowPlaying: NowPlayingView()
        case .videos: LibraryView(title: "Videos", items: library.videos)
        case .music: LibraryView(title: "Music", items: library.music)
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: SidebarItem
    @Environment(MediaLibrary.self) private var library
    @Environment(PlayerController.self) private var player

    var body: some View {
        List(selection: $selection) {
            if player.current != nil {
                Label("Now Playing", systemImage: "play.circle")
                    .tag(SidebarItem.nowPlaying)
            }
            Section("Library") {
                Label("Videos", systemImage: "play.rectangle")
                    .badge(library.videos.count)
                    .tag(SidebarItem.videos)
                Label("Music", systemImage: "music.note")
                    .badge(library.music.count)
                    .tag(SidebarItem.music)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 26, height: 26)
                    .background(Theme.accent, in: .rect(cornerRadius: 7))
                Text("Cone Player").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
        }
    }
}
