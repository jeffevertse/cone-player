import Observation

enum LibrarySection: String, CaseIterable, Identifiable {
    case videos = "Videos"
    case music = "Music"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .videos: "play.rectangle"
        case .music: "music.note.list"
        }
    }
}

/// Which screen the window shows: the library (with the miniplayer) or the full player.
@MainActor
@Observable
final class Navigation {
    enum Screen { case library, player }

    var screen: Screen = .library
    var section: LibrarySection = .videos
    var isImporting = false
    var isSearchFocused = false
}
