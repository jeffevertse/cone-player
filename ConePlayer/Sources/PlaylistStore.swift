import Foundation
import Observation

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var files: [FileReference]
}

/// The user's playlists, saved in UserDefaults.
@MainActor
@Observable
final class PlaylistStore {
    private(set) var playlists: [Playlist] = []
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "playlists"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = saved
        }
    }

    func playlist(_ id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    /// The playlist's files that still exist, in order.
    func items(in id: UUID) -> [MediaItem] {
        playlist(id)?.files.compactMap { FileReferenceResolver.shared.item(for: $0) } ?? []
    }

    @discardableResult
    func create(named name: String, with items: [MediaItem] = []) -> Playlist {
        let playlist = Playlist(id: UUID(), name: Self.cleaned(name), files: items.map { FileReference(url: $0.url) })
        playlists.append(playlist)
        save()
        return playlist
    }

    func rename(_ id: UUID, to name: String) {
        update(id) { $0.name = Self.cleaned(name) }
    }

    func delete(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    /// Appends files that aren't already in the playlist.
    func add(_ items: [MediaItem], to id: UUID) {
        update(id) { playlist in
            let existing = Set(playlist.files.map(\.path))
            playlist.files += items.filter { !existing.contains($0.key) }.map { FileReference(url: $0.url) }
        }
    }

    func remove(_ item: MediaItem, from id: UUID) {
        update(id) { $0.files.removeAll { $0.path == item.key } }
    }

    private func update(_ id: UUID, _ change: (inout Playlist) -> Void) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        change(&playlists[index])
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private static func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Playlist" : trimmed
    }
}
