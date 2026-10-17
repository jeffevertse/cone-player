import SwiftUI

/// Network section top level: servers on the local network, then streams you've opened.
struct NetworkHome: View {
    let streams: [MediaItem]
    let play: (MediaItem, [MediaItem]) -> Void

    @Environment(NetworkBrowser.self) private var browser
    @Environment(Navigation.self) private var navigation
    @Environment(PlayerController.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Local Network")
                    if browser.servers.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Looking for media servers and shared folders…")
                                .foregroundStyle(Theme.textMuted)
                        }
                        .font(.inter(14))
                    } else {
                        NodeGrid(nodes: browser.servers) { node in
                            navigation.showFolder([node.id])
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        sectionHeader("Streams")
                        Spacer()
                        Button("Open Network Stream…") { navigation.isOpeningStream = true }
                            .buttonStyle(.plain)
                            .font(.inter(14))
                            .foregroundStyle(Theme.accent)
                            .focusEffectDisabled()
                    }
                    if streams.isEmpty {
                        Text("Streams you open with ⌘N show up here.")
                            .font(.inter(14))
                            .foregroundStyle(Theme.textMuted)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 20)], spacing: 40) {
                            ForEach(streams) { item in
                                MediaCard(item: item, isCurrent: item == player.current) { play(item, streams) }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollIndicators(.never)
        .contentMargins(.bottom, player.current == nil || !player.settings.showsMiniplayer ? 0 : 340, for: .scrollContent)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.inter(16, .medium))
            .foregroundStyle(Theme.textBright)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Contents of a server or folder on the local network.
struct NetworkFolder: View {
    let url: URL
    let play: (MediaItem, [MediaItem]) -> Void

    @Environment(NetworkBrowser.self) private var browser
    @Environment(Navigation.self) private var navigation
    @Environment(PlayerController.self) private var player

    private var key: String { url.absoluteString }

    var body: some View {
        Group {
            if let nodes = browser.contents[key] {
                if nodes.isEmpty {
                    ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("Nothing playable here."))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        NodeGrid(nodes: nodes) { node in open(node, in: nodes) }
                            .padding(.vertical, 20)
                    }
                    .scrollIndicators(.never)
                    .contentMargins(.bottom, player.current == nil || !player.settings.showsMiniplayer ? 0 : 340, for: .scrollContent)
                }
            } else if browser.failed.contains(key) {
                ContentUnavailableView {
                    Label("Couldn't Open", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("The server didn't respond, or needs a user name and password (not supported yet).")
                } actions: {
                    Button("Try Again") { browser.reload(url) }
                }
                .foregroundStyle(Theme.textSecondary)
            } else {
                ProgressView("Loading…")
                    .controlSize(.small)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: key) { browser.browse(url) }
    }

    private func open(_ node: NetworkNode, in nodes: [NetworkNode]) {
        switch node.kind {
        case .server, .folder:
            navigation.showFolder(navigation.folderPath + [node.id])
        case .file:
            let files = nodes.filter { $0.kind == .file }.map { MediaItem(streamURL: $0.url) }
            play(MediaItem(streamURL: node.url), files)
        }
    }
}

/// Grid of servers, folders and files, styled like the library's folder cards.
private struct NodeGrid: View {
    let nodes: [NetworkNode]
    let open: (NetworkNode) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 28) {
            ForEach(nodes) { node in
                Button { open(node) } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        ZStack {
                            Theme.thumbnail
                            Image(systemName: node.systemImage)
                                .font(.system(size: 30))
                                .foregroundStyle(node.kind == .file ? Theme.separator : Theme.textSecondary)
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                        Text(node.name)
                            .font(.inter(15))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel(node.kind == .file ? "Play \(node.name)" : "Open \(node.name)")
            }
        }
    }
}
