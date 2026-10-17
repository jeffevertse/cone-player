import Foundation

/// A saved pointer to a media file that survives relaunches.
///
/// Files outside Movies and Music (Downloads, external drives) can only be
/// reopened by a sandboxed app through a security-scoped bookmark, so one is
/// stored alongside the path. Network streams are stored by their URL string.
struct FileReference: Codable, Hashable, Sendable {
    /// A file path, or a stream's full URL.
    let path: String
    var bookmark: Data?

    /// A path-only reference, for entries saved before bookmarks existed.
    init(path: String) {
        self.path = path
        bookmark = nil
    }

    init(url: URL) {
        guard url.isFileURL else {
            path = url.absoluteString
            bookmark = nil
            return
        }
        path = url.path
        // Creating a security-scoped bookmark needs read access right now.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        // The app only has read-only file access, and macOS refuses a security-scoped
        // bookmark that doesn't say so.
        bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// The file's URL, carrying sandbox access when it came from a bookmark.
    func resolve() -> URL {
        if path.contains("://"), let streamURL = URL(string: path) {
            return streamURL
        }
        if let bookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        return URL(fileURLWithPath: path)
    }
}

/// Resolving bookmarks touches the file system, so resolved items are cached per path.
@MainActor
final class FileReferenceResolver {
    static let shared = FileReferenceResolver()
    private var cache: [String: MediaItem] = [:]

    func item(for reference: FileReference) -> MediaItem? {
        if let cached = cache[reference.path] { return cached }
        let item = MediaItem(url: reference.resolve())
        cache[reference.path] = item
        return item
    }
}
