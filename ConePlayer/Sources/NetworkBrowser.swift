import Foundation
import Observation
import VLCKit

/// A server, folder or file found on the local network.
struct NetworkNode: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case server, folder, file }

    let url: URL
    let name: String
    let kind: Kind
    var id: String { url.absoluteString }

    var systemImage: String {
        switch kind {
        case .server: url.scheme == "smb" ? "externaldrive.connected.to.line.below" : "server.rack"
        case .folder: "folder"
        case .file: "film"
        }
    }
}

/// Finds media servers on the local network with VLC's discoverers (UPnP/DLNA,
/// Windows/SMB shares, Bonjour, SAP) and lists their contents by parsing them.
@MainActor
@Observable
final class NetworkBrowser {
    private(set) var servers: [NetworkNode] = []
    private(set) var isDiscovering = false
    /// Contents of each browsed server or folder, keyed by its URL string.
    private(set) var contents: [String: [NetworkNode]] = [:]
    private(set) var loading: Set<String> = []
    private(set) var failed: Set<String> = []
    /// Names of everything seen, for the breadcrumb.
    private(set) var names: [String: String] = [:]

    @ObservationIgnored private var discoverers: [VLCMediaDiscoverer] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let parser = VLCMediaParser(library: VLCLibrary.shared(), timeout: 15_000)
    @ObservationIgnored private var parsing: [String: VLCMedia] = [:]

    /// Starts discovery the first time Network is shown, so macOS only asks for
    /// local network access when it's needed.
    func start() {
        guard discoverers.isEmpty else { return }
        for name in ["upnp", "dsm", "Bonjour", "sap"] {
            let discoverer = VLCMediaDiscoverer(name: name)
            if discoverer.start() == 0 {
                discoverers.append(discoverer)
            }
        }
        isDiscovering = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Lists a server's or folder's contents; results arrive in `contents`.
    func browse(_ url: URL) {
        let key = url.absoluteString
        guard contents[key] == nil, parsing[key] == nil else { return }
        guard let media = VLCMedia(url: url) else { return }
        parsing[key] = media
        loading.insert(key)
        failed.remove(key)
        // VLCMediaParse lists a directory's (or server's) items as subitems.
        parser.queue(media, options: [.parse])
    }

    func reload(_ url: URL) {
        let key = url.absoluteString
        contents[key] = nil
        if let media = parsing.removeValue(forKey: key) { parser.cancelParsing(for: media) }
        browse(url)
    }

    // MARK: - Polling

    /// VLCKit reports discoveries and parse results on its own threads; polling once a
    /// second keeps everything on the main actor.
    private func refresh() {
        var found: [NetworkNode] = []
        for discoverer in discoverers {
            guard let list = discoverer.discoveredMedia else { continue }
            list.lock()
            for index in 0..<list.count {
                if let media = list.media(at: UInt(index)), let node = Self.node(for: media, kind: .server) {
                    found.append(node)
                }
            }
            list.unlock()
        }
        let sorted = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if sorted != servers {
            servers = sorted
            for server in sorted { names[server.id] = server.name }
        }

        for (key, media) in parsing {
            switch media.parsedStatus {
            case .done:
                var children: [NetworkNode] = []
                if let list = media.subitems {
                    list.lock()
                    for index in 0..<list.count {
                        if let child = list.media(at: UInt(index)),
                           let node = Self.node(for: child, kind: child.mediaType == .directory ? .folder : .file) {
                            children.append(node)
                        }
                    }
                    list.unlock()
                }
                contents[key] = children.sorted {
                    if ($0.kind == .folder) != ($1.kind == .folder) { return $0.kind == .folder }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                for child in children { names[child.id] = child.name }
                parsing[key] = nil
                loading.remove(key)
            case .failed, .timeout, .cancelled:
                parsing[key] = nil
                loading.remove(key)
                failed.insert(key)
            default:
                break
            }
        }
    }

    private static func node(for media: VLCMedia, kind: NetworkNode.Kind) -> NetworkNode? {
        guard let url = media.url else { return nil }
        let title = media.metaData.title ?? ""
        let name = title.isEmpty ? (url.lastPathComponent.isEmpty ? (url.host() ?? url.absoluteString) : url.lastPathComponent) : title
        return NetworkNode(url: url, name: name.removingPercentEncoding ?? name, kind: kind)
    }
}
