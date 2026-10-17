import Foundation
import UniformTypeIdentifiers

struct MediaItem: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case video, audio }

    let url: URL
    let kind: Kind
    let dateAdded: Date
    /// Folders between the library root (Movies or Music) and the file.
    let folderPath: [String]
    var id: URL { url }
    /// Identifies the item in history and playlists: the path for files, the full URL for streams.
    var key: String { url.isFileURL ? url.path : url.absoluteString }
    var isStream: Bool { !url.isFileURL }
    var fileName: String { isStream ? url.absoluteString : url.lastPathComponent }
    var title: String {
        guard isStream else { return url.deletingPathExtension().lastPathComponent }
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty || name == "/" ? (url.host() ?? url.absoluteString) : name
    }
    var folderName: String { isStream ? (url.host() ?? "Network") : url.deletingLastPathComponent().lastPathComponent }

    /// A network stream (http, rtsp, …). Treated as video; VLC works out what it really is.
    init(streamURL: URL) {
        self.init(url: streamURL, kind: .video, dateAdded: .now, folderPath: [])
    }

    /// `root` is the library folder the file was found in; files opened directly have none.
    /// Non-file URLs become streams.
    init?(url: URL, root: URL? = nil) {
        guard url.isFileURL else {
            self.init(streamURL: url)
            return
        }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        let kind: Kind
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            kind = .video
        } else if type.conforms(to: .audio) {
            kind = .audio
        } else {
            return nil
        }
        var folderPath: [String] = []
        if let root {
            let rootCount = root.standardizedFileURL.pathComponents.count
            folderPath = Array(url.standardizedFileURL.deletingLastPathComponent().pathComponents.dropFirst(rootCount))
        }
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        let dateAdded = values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
        self.init(url: url, kind: kind, dateAdded: dateAdded, folderPath: folderPath)
    }

    /// The same item shown inside a top-level library folder (a folder added in Settings).
    func inFolder(_ name: String) -> MediaItem {
        MediaItem(url: url, kind: kind, dateAdded: dateAdded, folderPath: [name] + folderPath)
    }

    private init(url: URL, kind: Kind, dateAdded: Date, folderPath: [String]) {
        self.url = url
        self.kind = kind
        self.dateAdded = dateAdded
        self.folderPath = folderPath
    }

    // The same file is the same item, whether it came from the library, Recent or a playlist.
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}
