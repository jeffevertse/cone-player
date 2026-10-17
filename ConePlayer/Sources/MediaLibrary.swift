import Foundation
import Observation

/// Finds playable files in the user's Movies and Music folders.
@MainActor
@Observable
final class MediaLibrary {
    private(set) var videos: [MediaItem] = []
    private(set) var music: [MediaItem] = []
    private(set) var isScanning = false

    func scan() async {
        isScanning = true
        defer { isScanning = false }

        let folders: [FileManager.SearchPathDirectory] = [.moviesDirectory, .musicDirectory]
        let roots = folders.compactMap {
            FileManager.default.urls(for: $0, in: .userDomainMask).first?.resolvingSymlinksInPath()
        }
        videos = []
        music = []
        // Scan one folder at a time so Videos appears even while macOS is still
        // asking for permission to read the Music folder.
        for root in roots {
            let found = await Task.detached(priority: .utility) { Self.files(in: root) }.value
            videos = (videos + found.filter { $0.kind == .video }).sorted { $0.title < $1.title }
            music = (music + found.filter { $0.kind == .audio }).sorted { $0.title < $1.title }
        }
    }

    private nonisolated static func files(in root: URL) -> [MediaItem] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        return enumerator.compactMap { ($0 as? URL).flatMap { MediaItem(url: $0, root: root) } }
    }
}
