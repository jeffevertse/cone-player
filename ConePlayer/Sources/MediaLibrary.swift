import Foundation
import Observation

/// Finds playable files in Movies, Music and any folders the user adds in
/// Settings › Library.
@MainActor
@Observable
final class MediaLibrary {
    private(set) var videos: [MediaItem] = []
    private(set) var music: [MediaItem] = []
    private(set) var isScanning = false
    /// Folders added in Settings › Library, kept reachable with security-scoped bookmarks.
    private(set) var customFolders: [FileReference] = []

    @ObservationIgnored private let defaults: UserDefaults
    /// Custom folders whose sandbox access is held for the session, so files inside
    /// can be scanned, previewed and played.
    @ObservationIgnored private var accessedFolders: [String: URL] = [:]
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    private static let foldersKey = "libraryFolders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.foldersKey),
           let saved = try? JSONDecoder().decode([FileReference].self, from: data) {
            customFolders = saved
        }
    }

    /// The display name of a custom folder (its last path component).
    static func name(of folder: FileReference) -> String {
        URL(fileURLWithPath: folder.path).lastPathComponent
    }

    func addFolder(_ url: URL) {
        let reference = FileReference(url: url)
        guard !customFolders.contains(where: { $0.path == reference.path }) else { return }
        customFolders.append(reference)
        saveFolders()
        rescan()
    }

    func removeFolder(_ folder: FileReference) {
        customFolders.removeAll { $0.path == folder.path }
        accessedFolders.removeValue(forKey: folder.path)?.stopAccessingSecurityScopedResource()
        saveFolders()
        rescan()
    }

    func rescan() {
        scanTask?.cancel()
        scanTask = Task { await scan() }
    }

    func scan() async {
        isScanning = true
        defer { isScanning = false }

        let standard: [FileManager.SearchPathDirectory] = [.moviesDirectory, .musicDirectory]
        var roots: [(url: URL, prefix: String?)] = standard.compactMap {
            FileManager.default.urls(for: $0, in: .userDomainMask).first.map { ($0.resolvingSymlinksInPath(), nil) }
        }
        for folder in customFolders {
            roots.append((accessibleURL(for: folder), Self.name(of: folder)))
        }

        var foundVideos: [MediaItem] = []
        var foundMusic: [MediaItem] = []
        videos = []
        music = []
        // Scan one folder at a time so results appear even while macOS is still
        // asking for permission to read another one.
        for root in roots {
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .utility) {
                Self.files(in: root.url).map { item in root.prefix.map { item.inFolder($0) } ?? item }
            }.value
            foundVideos += found.filter { $0.kind == .video }
            foundMusic += found.filter { $0.kind == .audio }
            videos = foundVideos.sorted { $0.title < $1.title }
            music = foundMusic.sorted { $0.title < $1.title }
        }
    }

    /// Resolves a custom folder's bookmark and starts (once) holding its access.
    private func accessibleURL(for folder: FileReference) -> URL {
        if let url = accessedFolders[folder.path] { return url }
        let url = folder.resolve()
        if url.startAccessingSecurityScopedResource() {
            accessedFolders[folder.path] = url
        }
        return url
    }

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(customFolders) {
            defaults.set(data, forKey: Self.foldersKey)
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
