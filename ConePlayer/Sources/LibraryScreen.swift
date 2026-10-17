import SwiftUI

struct LibraryScreen: View {
    enum Layout { case grid, list }
    enum Sort: String, CaseIterable { case name = "Name", dateAdded = "Date Added" }

    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @Environment(Navigation.self) private var navigation
    @State private var query = ""
    @State private var layout: Layout = .grid
    @State private var sort: Sort = .name

    private var items: [MediaItem] {
        let all = navigation.section == .videos ? library.videos : library.music
        let matching = query.isEmpty ? all : all.filter { $0.fileName.localizedCaseInsensitiveContains(query) }
        switch sort {
        case .name: return matching
        case .dateAdded: return matching.sorted { $0.dateAdded > $1.dateAdded }
        }
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
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 20) {
            Text(navigation.section.rawValue)
                .font(.inter(16, .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("^[\(items.count) item](inflect: true)")
                .font(.inter(14))
                .foregroundStyle(Theme.textMuted)
            Menu {
                Picker("Sort By", selection: $sort) {
                    ForEach(Sort.allCases, id: \.self) { Text($0.rawValue) }
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
            SearchField(text: $query, isFocused: Bindable(navigation).isSearchFocused)
        }
        .frame(height: 34)
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: navigation.section.systemImage)
            } description: {
                Text(query.isEmpty
                     ? "Add files to your \(navigation.section == .videos ? "Movies" : "Music") folder, drop a file here, or use Add item."
                     : "Nothing matches “\(query)”.")
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                switch layout {
                case .grid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 20)], spacing: 40) {
                        ForEach(items) { item in MediaCard(item: item, isCurrent: item == player.current) { play(item) } }
                    }
                    .padding(.vertical, 20)
                case .list:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20, alignment: .leading)], spacing: 10) {
                        ForEach(items) { item in MediaRow(item: item, isCurrent: item == player.current) { play(item) } }
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
        if library.isScanning { return "Scanning…" }
        return query.isEmpty ? "No \(navigation.section.rawValue)" : "No Results"
    }

    private func play(_ item: MediaItem) {
        player.play(item, in: items)
        navigation.screen = .player
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

private struct Thumbnail: View {
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
                Image(systemName: item.kind == .video ? "film" : "music.note")
                    .font(.system(size: cornerRadius > 6 ? 24 : 10))
                    .foregroundStyle(Theme.separator)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .task(id: item.url) { await thumbnails.load(item.url) }
        .accessibilityHidden(true)
    }
}

private struct MediaCard: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                Thumbnail(item: item)
                    .aspectRatio(16 / 9, contentMode: .fit)
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
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.textPrimary)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Thumbnail(item: item, cornerRadius: 3)
                    .frame(width: 20, height: 20)
                Text(item.fileName)
                    .font(.inter(14))
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.textPrimary)
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
