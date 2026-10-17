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
    var fileName: String { url.lastPathComponent }
    var title: String { url.deletingPathExtension().lastPathComponent }
    var folderName: String { url.deletingLastPathComponent().lastPathComponent }

    /// `root` is the library folder the file was found in; files opened directly have none.
    init?(url: URL, root: URL? = nil) {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            kind = .video
        } else if type.conforms(to: .audio) {
            kind = .audio
        } else {
            return nil
        }
        self.url = url
        if let root {
            let rootCount = root.standardizedFileURL.pathComponents.count
            folderPath = Array(url.standardizedFileURL.deletingLastPathComponent().pathComponents.dropFirst(rootCount))
        } else {
            folderPath = []
        }
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        dateAdded = values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
    }

    // The same file is the same item, whether it came from the library, Recent or a playlist.
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.url.path == rhs.url.path }
    func hash(into hasher: inout Hasher) { hasher.combine(url.path) }
}
