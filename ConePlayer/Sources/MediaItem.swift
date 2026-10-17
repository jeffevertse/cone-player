import Foundation
import UniformTypeIdentifiers

struct MediaItem: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case video, audio }

    let url: URL
    let kind: Kind
    let dateAdded: Date
    var id: URL { url }
    var fileName: String { url.lastPathComponent }
    var title: String { url.deletingPathExtension().lastPathComponent }
    var folderName: String { url.deletingLastPathComponent().lastPathComponent }

    init?(url: URL) {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            kind = .video
        } else if type.conforms(to: .audio) {
            kind = .audio
        } else {
            return nil
        }
        self.url = url
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        dateAdded = values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
    }
}
