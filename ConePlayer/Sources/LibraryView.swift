import SwiftUI

struct LibraryView: View {
    let title: String
    let items: [MediaItem]

    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @State private var query = ""

    private var filtered: [MediaItem] {
        query.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label(library.isScanning ? "Scanning…" : "No \(title)", systemImage: "tray")
                } description: {
                    Text("Add files to your \(title == "Music" ? "Music" : "Movies") folder, drop a file here, or choose File › Open.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 20)], spacing: 22) {
                        ForEach(filtered) { item in
                            MediaCard(item: item, isCurrent: item == player.current) {
                                player.play(item)
                            }
                        }
                    }
                    .padding(32)
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $query, placement: .toolbar, prompt: "Search \(title.lowercased())")
    }
}

private struct MediaCard: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Theme.artwork(for: item.title)
                    Image(systemName: item.kind == .video ? "film" : "music.note")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.accent.opacity(0.7))
                    if isHovering {
                        Color.black.opacity(0.35)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 52, height: 52)
                            .background(Theme.accent, in: .circle)
                    }
                }
                .aspectRatio(item.kind == .video ? 16 / 9 : 1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(isCurrent ? Theme.accent : Theme.stroke, lineWidth: isCurrent ? 2 : 1)
                }

                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(item.folderName)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Play \(item.title)")
    }
}
