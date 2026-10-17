import SwiftUI
import UniformTypeIdentifiers

@main
struct ConePlayerApp: App {
    @State private var player = PlayerController()
    @State private var library = MediaLibrary()
    @State private var isImporting = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(player)
                .environment(library)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .frame(minWidth: 960, minHeight: 600)
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie, .audio]) { result in
                    if case .success(let url) = result, let item = MediaItem(url: url) {
                        player.play(item)
                    }
                }
                .onOpenURL { url in
                    if let item = MediaItem(url: url) { player.play(item) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File…") { isImporting = true }
                    .keyboardShortcut("o")
            }
            CommandMenu("Playback") {
                Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Jump Forward 10s") { player.skip(by: 10) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Jump Back 10s") { player.skip(by: -10) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Divider()
                Button("Stop") { player.stop() }
                    .keyboardShortcut(".")
            }
        }
    }
}
