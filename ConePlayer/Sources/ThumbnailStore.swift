import AppKit
import AVFoundation
import Observation
import QuickLookThumbnailing

/// Loads and caches thumbnails for library items: a video frame from Quick Look, or
/// the cover art embedded in an audio file.
@MainActor
@Observable
final class ThumbnailStore {
    private(set) var images: [URL: NSImage] = [:]
    @ObservationIgnored private var requested: Set<URL> = []

    func load(_ item: MediaItem) async {
        let url = item.url
        guard requested.insert(url).inserted else { return }
        // Files reopened from a bookmark (Recent, playlists) need sandbox access to preview.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        switch item.kind {
        case .video:
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 316, height: 178),
                scale: 2,
                representationTypes: .thumbnail
            )
            // Files Quick Look can't preview keep the placeholder.
            if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                images[url] = representation.nsImage
            }
        case .audio:
            // Quick Look draws a generic music icon for audio without art, which looks
            // worse than the placeholder, so only use art that's actually in the file.
            if let artwork = await Self.embeddedArtwork(in: url) {
                images[url] = artwork
            }
        }
    }

    private nonisolated static func embeddedArtwork(in url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        let artworkItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        guard let data = try? await artworkItems.first?.load(.dataValue) else { return nil }
        return NSImage(data: data)
    }
}
