import SwiftUI

struct RootView: View {
    @Environment(PlayerController.self) private var player
    @Environment(MediaLibrary.self) private var library
    @Environment(Navigation.self) private var navigation
    @Environment(DialogCenter.self) private var dialogs

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ZStack(alignment: .bottomTrailing) {
                switch navigation.screen {
                case .library:
                    HStack(spacing: 0) {
                        Sidebar()
                        LibraryScreen()
                    }
                    if player.current != nil && player.settings.showsMiniplayer {
                        Miniplayer()
                            .padding(6)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                case .player:
                    PlayerScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .ignoresSafeArea()
        .font(.inter(14))
        .foregroundStyle(Theme.textPrimary)
        .task { await library.scan() }
        .onAppear { SpaceBarMonitor.install(player: player) }
        .onChange(of: player.current) { _, item in
            if item == nil { navigation.screen = .library }
        }
        // Recordings land in Movies, so show them in Videos.
        .onChange(of: player.savedRecording) { _, url in
            if url != nil { library.rescan() }
        }
        .sheet(item: Binding(get: { dialogs.current }, set: { if $0 == nil { dialogs.dismiss() } })) { dialog in
            VLCDialogSheet(dialog: dialog)
        }
        .dropDestination(for: URL.self) { urls, _ in
            let items = urls.compactMap { MediaItem(url: $0) }
            guard let first = items.first else { return false }
            player.play(first, in: items)
            navigation.screen = .player
            return true
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @Environment(PlayerController.self) private var player
    @Environment(Navigation.self) private var navigation

    var body: some View {
        ZStack {
            Text(title)
                .font(.inter(14))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 600)

            HStack(spacing: 7) {
                // Room for the window's traffic-light buttons.
                Color.clear.frame(width: 70, height: 1)
                AppMark()
                // The Figma's "…" app menu is the macOS menu bar here (File › Open, Playback).

                if navigation.screen == .player {
                    IconButton("sidebar.left", label: "Show Library") {
                        navigation.screen = .library
                    }
                    Rectangle().fill(Theme.separator).frame(width: 1, height: 16)
                    if let folder = player.current?.folderName {
                        Label(folder, systemImage: "folder")
                            .labelStyle(.titleAndIcon)
                            .font(.inter(14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                IconButton("arrow.up.left.and.arrow.down.right", label: "Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .padding(.trailing, 14)
            }
        }
        .frame(height: Theme.topBarHeight)
        .background(Theme.bar.opacity(0.95))
    }

    private var title: String {
        guard let current = player.current else { return "Cone Player" }
        return player.displayTitle.isEmpty ? current.title : player.displayTitle
    }
}

/// Cone Player's mark: an orange play glyph (VLC's cone is VideoLAN's trademark).
struct AppMark: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(Theme.onAccent)
            .frame(width: 18, height: 18)
            .background(Theme.accent, in: .rect(cornerRadius: 5))
            .padding(.horizontal, 7)
            .accessibilityHidden(true)
    }
}

/// A 24pt line icon in a 30×28 hit area, as used throughout the Figma.
struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color = Theme.textSecondary
    let action: () -> Void

    init(_ systemName: String, label: String, tint: Color = Theme.textSecondary, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 30, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(LibrarySection.allCases) { section in
                row(section.rawValue, systemImage: section.systemImage, isSelected: navigation.section == section) {
                    navigation.section = section
                }
            }
            row("Add item", systemImage: "plus", isSelected: false) {
                navigation.isImporting = true
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel, in: .rect(cornerRadius: 6))
        .padding(8)
        .frame(width: Theme.sidebarWidth)
    }

    private func row(_ title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Theme.accentText : Theme.textSecondary)
                    .frame(width: 30, height: 32)
                Text(title)
                    .font(.inter(14, isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.textBright : Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Space bar

/// Space toggles play/pause unless a text field is being edited. A menu shortcut
/// can't do this: it would swallow spaces typed into the search field.
@MainActor
enum SpaceBarMonitor {
    private static var monitor: Any?

    static func install(player: PlayerController) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard event.keyCode == 49, modifiers.isEmpty else { return event }
            let handled = MainActor.assumeIsolated {
                guard !(NSApp.keyWindow?.firstResponder is NSText) else { return false }
                player.togglePlayPause()
                return true
            }
            return handled ? nil : event
        }
    }
}
