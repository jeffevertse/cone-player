import SwiftUI
import UniformTypeIdentifiers

@main
struct ConePlayerApp: App {
    @State private var settings: SettingsStore
    @State private var player: PlayerController
    @State private var library = MediaLibrary()
    @State private var thumbnails = ThumbnailStore()
    @State private var navigation = Navigation()

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _player = State(initialValue: PlayerController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(library)
                .environment(thumbnails)
                .environment(navigation)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .frame(minWidth: 960, minHeight: 600)
                .fileImporter(isPresented: $navigation.isImporting, allowedContentTypes: [.movie, .audio]) { result in
                    if case .success(let url) = result { open(url) }
                }
                .onOpenURL(perform: open)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File…") { navigation.isImporting = true }
                    .keyboardShortcut("o")
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
                Button("Stop") { player.stop(); navigation.screen = .library }
                    .keyboardShortcut(".")
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }

    private func open(_ url: URL) {
        guard let item = MediaItem(url: url) else { return }
        player.play(item, in: [item])
        navigation.screen = .player
    }
}
