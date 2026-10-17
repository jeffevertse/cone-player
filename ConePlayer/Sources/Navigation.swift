import Observation

enum LibrarySection: String, CaseIterable, Identifiable {
    case videos = "Videos"
    case music = "Music"
    case playlists = "Playlists"
    case recent = "Recent"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .videos: "play.rectangle"
        case .music: "music.note"
        case .playlists: "list.triangle"
        case .recent: "clock.arrow.circlepath"
        }
    }

    /// Videos and Music are browsed by folder; Playlists and Recent aren't.
    var hasFolders: Bool { self == .videos || self == .music }
}

/// Which screen the window shows: the library (with the miniplayer) or the full player.
@MainActor
@Observable
final class Navigation {
    enum Screen { case library, player }

    var screen: Screen = .library
    /// Switching section returns to its top level and clears folder history.
    var section: LibrarySection = .videos {
        didSet {
            folderPath = []
            backStack = []
            forwardStack = []
        }
    }
    /// The folder shown in the library, relative to the section's top level.
    private(set) var folderPath: [String] = []
    private var backStack: [[String]] = []
    private var forwardStack: [[String]] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func showFolder(_ path: [String]) {
        guard path != folderPath else { return }
        backStack.append(folderPath)
        forwardStack = []
        folderPath = path
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(folderPath)
        folderPath = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(folderPath)
        folderPath = next
    }
    var isImporting = false
    var isSearchFocused = false
}
