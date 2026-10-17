import AppKit
import Observation
import QuickLookThumbnailing

/// Loads and caches Quick Look thumbnails for library items.
@MainActor
@Observable
final class ThumbnailStore {
    private(set) var images: [URL: NSImage] = [:]
    @ObservationIgnored private var requested: Set<URL> = []

    func load(_ url: URL) async {
        guard requested.insert(url).inserted else { return }
        // Files reopened from a bookmark (Recent, playlists) need sandbox access to preview.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 316, height: 178),
            scale: 2,
            representationTypes: .thumbnail
        )
        // Files Quick Look can't preview simply keep the placeholder.
        // Only real previews: a generic file-type icon (audio without cover art) looks
        // worse than the placeholder.
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request),
              representation.type == .thumbnail else {
            return
        }
        images[url] = representation.nsImage
    }
}
