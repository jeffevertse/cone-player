import SwiftUI
import VLCKit
import UniformTypeIdentifiers

@main
struct ConePlayerApp: App {
    @State private var settings: SettingsStore
    @State private var player: PlayerController
    @State private var history: PlaybackHistory
    @State private var playlists: PlaylistStore
    @State private var networkBrowser = NetworkBrowser()
    @State private var dialogs = DialogCenter()
    @State private var library: MediaLibrary
    @State private var thumbnails = ThumbnailStore()
    @State private var navigation: Navigation

    init() {
        let defaults = UITesting.isEnabled ? UITesting.freshDefaults() : .standard
        let settings = SettingsStore(defaults: defaults)
        _settings = State(initialValue: settings)
        _playlists = State(initialValue: PlaylistStore(defaults: defaults))
        _library = State(initialValue: MediaLibrary(defaults: defaults, includesStandardFolders: !UITesting.isEnabled))
        let navigation = Navigation()
        navigation.section = settings.startScreen
        _navigation = State(initialValue: navigation)
        let history = PlaybackHistory(defaults: defaults)
        _history = State(initialValue: history)
        _player = State(initialValue: PlayerController(settings: settings, history: history))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(library)
                .environment(thumbnails)
                .environment(navigation)
                .environment(history)
                .environment(playlists)
                .environment(settings)
                .environment(networkBrowser)
                .environment(dialogs)
                .task {
                    settings.applyAppearance()
                    dialogs.attach(to: [player.vlcLibrary, VLCLibrary.shared()])
                }
                .tint(Theme.accent)
                .frame(minWidth: 960, minHeight: 600)
                .fileImporter(
                    isPresented: $navigation.isImporting,
                    allowedContentTypes: [.movie, .audio],
                    allowsMultipleSelection: true
                ) { result in
                    if case .success(let urls) = result { open(urls) }
                }
                .onOpenURL { open([$0]) }
                .sheet(isPresented: $navigation.isOpeningStream) {
                    NetworkStreamSheet()
                        .environment(player)
                        .environment(history)
                        .environment(navigation)
                }
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File…") { navigation.isImporting = true }
                    .keyboardShortcut("o")
                Button("Open Network Stream…") { navigation.isOpeningStream = true }
                    .keyboardShortcut("n")
            }
            CommandGroup(before: .sidebar) {
                Button("Show Library") { navigation.screen = .library }
                    .keyboardShortcut("1")
                Button("Show Player") { navigation.screen = .player }
                    .keyboardShortcut("2")
                    .disabled(player.current == nil)
                Divider()
            }
            CommandGroup(after: .textEditing) {
                Button("Find") {
                    navigation.screen = .library
                    navigation.isSearchFocused = true
                }
                .keyboardShortcut("f")
            }
            CommandMenu("Playback") {
                // Space is handled by SpaceBarMonitor so it still types spaces in text fields.
                Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                Button("Next") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("Previous") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                Button("Jump Forward \(settings.jumpInterval)s") { player.jumpForward() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Jump Back \(settings.jumpInterval)s") { player.jumpBack() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Divider()
                Button(player.isRecording ? "Stop Recording" : "Start Recording") { player.toggleRecording() }
                    .keyboardShortcut("r")
                    .disabled(player.current == nil)
                Divider()
                Button("Stop") { player.stop(); navigation.screen = .library }
                    .keyboardShortcut(".")
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
                .environment(library)
                .environment(history)
                .environment(playlists)
        }
    }

    /// Plays the first file and queues the rest.
    private func open(_ urls: [URL]) {
        let items = urls.compactMap { MediaItem(url: $0) }
        guard let first = items.first else { return }
        player.play(first, in: items)
        navigation.screen = .player
    }
}

/// UI tests launch the app with `-UITesting`: it then starts from empty preferences of
/// its own and skips Movies/Music, so tests are repeatable and never touch real data.
enum UITesting {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-UITesting")

    static func freshDefaults() -> UserDefaults {
        let suite = "com.jeffevertse.ConePlayer.UITesting"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }
}
