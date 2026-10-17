import SwiftUI

struct LibraryScreen: View {
    enum Layout { case grid, list }
    enum Sort: String, CaseIterable { case name = "Name", dateAdded = "Date Added" }

    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @Environment(Navigation.self) private var navigation
    @Environment(PlaybackHistory.self) private var history
    @Environment(PlaylistStore.self) private var playlists
    @State private var query = ""
    @State private var layout: Layout = .grid
    @State private var sort: Sort = .name
    /// Files waiting to go into a playlist that's being created.
    @State private var newPlaylistItems: [MediaItem]?

    private var section: LibrarySection { navigation.section }

    /// The open playlist, when in Playlists and one is selected.
    private var openPlaylist: Playlist? {
        guard section == .playlists, let id = navigation.folderPath.first.flatMap(UUID.init(uuidString:)) else { return nil }
        return playlists.playlist(id)
    }

    private var sectionItems: [MediaItem] {
        switch section {
        case .videos: library.videos
        case .music: library.music
        case .home: library.videos + library.music
        case .recent: history.recentItems
        case .network: history.recentItems.filter(\.isStream)
        case .playlists: openPlaylist.map { playlists.items(in: $0.id) } ?? []
        }
    }

    /// Files to show: the current folder, Recent or the open playlist, or search matches.
    private var items: [MediaItem] {
        let visible: [MediaItem]
        if !query.isEmpty {
            visible = sectionItems.filter { Self.searchKey($0.fileName).contains(Self.searchKey(query)) }
        } else if section.hasFolders {
            visible = sectionItems.filter { $0.folderPath == navigation.folderPath }
        } else {
            visible = sectionItems
        }
        switch sort {
        case .name: return visible
        case .dateAdded: return visible.sorted { $0.dateAdded > $1.dateAdded }
        }
    }

    /// Subfolders of the current folder (none while searching).
    private var folders: [Folder] {
        guard query.isEmpty, section.hasFolders else { return [] }
        let path = navigation.folderPath
        let nested = sectionItems.filter { $0.folderPath.count > path.count && Array($0.folderPath.prefix(path.count)) == path }
        return Dictionary(grouping: nested) { $0.folderPath[path.count] }
            .map { name, contents in Folder(name: name, path: path + [name], items: contents) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// True for the top level of Playlists, which lists playlists instead of files.
    private var showsPlaylistList: Bool {
        section == .playlists && openPlaylist == nil && query.isEmpty
    }

    /// Home shows its own rows; while searching it searches Videos and Music.
    private var showsHome: Bool {
        section == .home && query.isEmpty
    }

    /// Case-, accent- and separator-insensitive form, so "sync test" finds "sync-test.mp4".
    private static func searchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "[-_.]+", with: " ", options: .regularExpression)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            toolbar
            Rectangle().fill(Theme.panel).frame(height: 1)
            content
        }
        .padding([.horizontal, .top], 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
        .sheet(item: Binding(
            get: { newPlaylistItems.map(PendingPlaylist.init) },
            set: { newPlaylistItems = $0?.items }
        )) { pending in
            PlaylistNameSheet(title: "New Playlist", confirmTitle: "Create") { name in
                playlists.create(named: name, with: pending.items)
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 12) {
                IconButton("arrow.left", label: "Back", tint: navigation.canGoBack ? Theme.textSecondary : Theme.separator) {
                    navigation.goBack()
                }
                .disabled(!navigation.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                IconButton("arrow.right", label: "Forward", tint: navigation.canGoForward ? Theme.textSecondary : Theme.separator) {
                    navigation.goForward()
                }
                .disabled(!navigation.canGoForward)
                .keyboardShortcut("]", modifiers: .command)
            }
            Breadcrumb()
            Spacer()
            if !showsHome {
                Text("^[\(showsPlaylistList ? playlists.playlists.count : items.count + folders.count) item](inflect: true)")
                    .font(.inter(14))
                    .foregroundStyle(Theme.textMuted)
            }

            if let playlist = openPlaylist, !items.isEmpty {
                IconButton("play", label: "Play All") { play(items[0]) }
                playlistMenu(playlist)
            }
            if section == .network {
                IconButton("plus", label: "Open Network Stream") { navigation.isOpeningStream = true }
            }
            if section == .recent && !items.isEmpty {
                Button("Clear") { history.clear() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .focusEffectDisabled()
            }

            if !showsPlaylistList && !showsHome {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text(sortTitle($0)) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .tint(Theme.textSecondary)
                .fixedSize()
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Sort")

                IconButton(layout == .grid ? "list.bullet" : "square.grid.2x2",
                           label: layout == .grid ? "Show as List" : "Show as Grid") {
                    layout = layout == .grid ? .list : .grid
                }
            }
            SearchField(text: $query, isFocused: Bindable(navigation).isSearchFocused)
        }
        .frame(height: 34)
    }

    /// "Name" keeps a playlist's or Recent's own order, so say so.
    private func sortTitle(_ sort: Sort) -> String {
        switch (sort, section) {
        case (.name, .recent): "Recently Played"
        case (.name, .playlists): "Playlist Order"
        default: sort.rawValue
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if showsHome {
            HomeView()
        } else if showsPlaylistList {
            PlaylistList()
        } else if items.isEmpty && folders.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: section.systemImage)
            } description: {
                Text(emptyDescription)
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                switch layout {
                case .grid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 20)], spacing: 40) {
                        ForEach(folders) { folder in FolderCard(folder: folder) { navigation.showFolder(folder.path) } }
                        ForEach(items) { item in
                            MediaCard(item: item, isCurrent: item == player.current) { play(item) }
                                .contextMenu { itemMenu(item) }
                        }
                    }
                    .padding(.vertical, 20)
                case .list:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20, alignment: .leading)], spacing: 10) {
                        ForEach(folders) { folder in FolderRow(folder: folder) { navigation.showFolder(folder.path) } }
                        ForEach(items) { item in
                            MediaRow(item: item, isCurrent: item == player.current) { play(item) }
                                .contextMenu { itemMenu(item) }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .scrollIndicators(.never)
            // Keep the last row clear of the miniplayer.
            .contentMargins(.bottom, player.current == nil ? 0 : 340, for: .scrollContent)
        }
    }

    private var emptyTitle: String {
        if library.isScanning && section.hasFolders { return "Scanning…" }
        if !query.isEmpty { return "No Results" }
        switch section {
        case .home: return "No Results"
        case .recent: return "No Recent Items"
        case .network: return "No Network Streams"
        case .playlists: return "Empty Playlist"
        default: return "No \(section.rawValue)"
        }
    }

    private var emptyDescription: String {
        if !query.isEmpty { return "Nothing matches “\(query)”." }
        switch section {
        case .videos: return "Add files to your Movies folder, drop a file here, or use Add item."
        case .music: return "Add files to your Music folder, drop a file here, or use Add item."
        case .home: return "Nothing matches."
        case .recent: return "Files you play show up here."
        case .network: return "Choose File › Open Network Stream… (⌘N) or the + button to play a URL."
        case .playlists: return "Right-click a file and choose Add to Playlist."
        }
    }

    // MARK: Menus

    @ViewBuilder private func itemMenu(_ item: MediaItem) -> some View {
        Button("Play") { play(item) }
        Menu("Add to Playlist") {
            ForEach(playlists.playlists) { playlist in
                Button(playlist.name) { playlists.add([item], to: playlist.id) }
                    .disabled(playlist.id == openPlaylist?.id)
            }
            if !playlists.playlists.isEmpty { Divider() }
            Button("New Playlist…") { newPlaylistItems = [item] }
        }
        if item.isStream {
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
            }
        } else {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
        if let playlist = openPlaylist {
            Divider()
            Button("Remove from Playlist", role: .destructive) { playlists.remove(item, from: playlist.id) }
        }
        if section == .recent {
            Divider()
            Button("Remove from Recent", role: .destructive) { history.remove(item) }
        }
    }

    private func playlistMenu(_ playlist: Playlist) -> some View {
        PlaylistActions(playlist: playlist) {
            Image(systemName: "ellipsis")
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30, height: 28)
        } onDelete: {
            navigation.showFolder([])
        }
    }

    private func play(_ item: MediaItem) {
        player.play(item, in: items)
        navigation.screen = .player
    }
}

/// Wraps the files for `.sheet(item:)`.
private struct PendingPlaylist: Identifiable {
    let items: [MediaItem]
    var id: [String] { items.map(\.key) }
}

// MARK: - Folders

struct Folder: Identifiable {
    let name: String
    let path: [String]
    /// Everything inside, including nested folders.
    let items: [MediaItem]
    var id: [String] { path }
}

/// "Videos ▶ Shows ▶ The Wand ▶ S01": each step but the last opens that folder.
private struct Breadcrumb: View {
    @Environment(Navigation.self) private var navigation
    @Environment(PlaylistStore.self) private var playlists

    /// Folder names as-is; in Playlists the path holds a playlist id.
    private func title(_ component: String) -> String {
        guard navigation.section == .playlists, let id = UUID(uuidString: component) else { return component }
        return playlists.playlist(id)?.name ?? "Playlist"
    }

    var body: some View {
        let path = navigation.folderPath
        HStack(spacing: 6) {
            crumb(navigation.section.rawValue, isLast: path.isEmpty) { navigation.showFolder([]) }
            ForEach(Array(path.enumerated()), id: \.offset) { index, name in
                Text("▶")
                    .font(.inter(8))
                    .foregroundStyle(Theme.separator)
                    .accessibilityHidden(true)
                crumb(title(name), isLast: index == path.count - 1) { navigation.showFolder(Array(path.prefix(index + 1))) }
            }
        }
        .lineLimit(1)
    }

    private func crumb(_ title: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.inter(16, isLast ? .semibold : .regular))
                .foregroundStyle(isLast ? Theme.textPrimary : Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        // Not .disabled: that would grey out the current folder's name.
        .allowsHitTesting(!isLast)
        .accessibilityAddTraits(isLast ? .isSelected : [])
    }
}

private struct FolderCard: View {
    let folder: Folder
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    if let first = folder.items.first {
                        Thumbnail(item: first)
                            .opacity(0.35)
                    } else {
                        Theme.thumbnail
                    }
                    Image(systemName: "folder.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.textSecondary)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
                HStack {
                    Text(folder.name)
                        .font(.inter(16))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(folder.items.count)")
                        .font(.inter(14))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open folder \(folder.name), \(folder.items.count) items")
    }
}

private struct FolderRow: View {
    let folder: Folder
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20, height: 20)
                Text(folder.name)
                    .font(.inter(14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 22)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open folder \(folder.name)")
    }
}

// MARK: - Search

private struct SearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @FocusState private var focus: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textMuted)
                .accessibilityHidden(true)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.inter(14))
                .foregroundStyle(Theme.textPrimary)
                .focused($focus)
                .onChange(of: isFocused) { _, newValue in focus = newValue }
                .onChange(of: focus) { _, newValue in isFocused = newValue }
                .onAppear { focus = isFocused }
        }
        .padding(.horizontal, 8)
        .frame(width: 325, height: 34)
        .background(Theme.field, in: .rect(cornerRadius: 6))
    }
}

// MARK: - Items

struct Thumbnail: View {
    let item: MediaItem
    var cornerRadius: CGFloat = 12
    @Environment(ThumbnailStore.self) private var thumbnails

    var body: some View {
        ZStack {
            Theme.thumbnail
            if let image = thumbnails.images[item.url] {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: item.isStream ? "dot.radiowaves.left.and.right" : item.kind == .video ? "film" : "music.note")
                    .font(.system(size: cornerRadius > 6 ? 24 : 10))
                    .foregroundStyle(Theme.separator)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        // Streams have no local file for Quick Look to preview.
        .task(id: item.url) { if !item.isStream { await thumbnails.load(item) } }
        .accessibilityHidden(true)
    }
}

/// Name color: orange while playing, dimmed once watched (as in the Figma).
private func nameColor(isCurrent: Bool, entry: PlaybackHistory.Entry?) -> Color {
    if isCurrent { return Theme.accent }
    return entry?.isFinished == true ? Theme.textMuted : Theme.textPrimary
}

struct MediaCard: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovering = false
    @Environment(PlaybackHistory.self) private var history

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                Thumbnail(item: item)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(alignment: .bottomLeading) {
                        if let progress = history.entry(for: item)?.progress, progress > 0 {
                            GeometryReader { proxy in
                                Theme.accent
                                    .frame(width: proxy.size.width * progress, height: 4)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .clipShape(.rect(cornerRadius: 12))
                            .accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        if isHovering {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 28)
                                .background(Theme.accent, in: .rect(cornerRadius: 6))
                        }
                    }
                Text(item.fileName)
                    .font(.inter(16))
                    .foregroundStyle(nameColor(isCurrent: isCurrent, entry: history.entry(for: item)))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Play \(item.title)")
    }
}

private struct MediaRow: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void
    @Environment(PlaybackHistory.self) private var history

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Thumbnail(item: item, cornerRadius: 3)
                    .frame(width: 20, height: 20)
                    .overlay(alignment: .bottomLeading) {
                        if let progress = history.entry(for: item)?.progress, progress > 0 {
                            Theme.accent.frame(width: 20 * progress, height: 2).offset(y: 3)
                        }
                    }
                Text(item.fileName)
                    .font(.inter(14))
                    .foregroundStyle(nameColor(isCurrent: isCurrent, entry: history.entry(for: item)))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .frame(height: 22)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(item.title)")
    }
}
