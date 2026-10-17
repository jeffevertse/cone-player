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
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 316, height: 178),
            scale: 2,
            representationTypes: .thumbnail
        )
        // Files Quick Look can't preview simply keep the placeholder.
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return
        }
        images[url] = representation.nsImage
    }
}
