import SwiftUI

/// Top level of Playlists, styled after the Figma's playlists panel:
/// a "Create playlist" row, then one 32pt row per playlist.
struct PlaylistList: View {
    @Environment(PlaylistStore.self) private var playlists
    @Environment(Navigation.self) private var navigation
    @State private var isCreating = false
    @State private var pendingDelete: Playlist?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button { isCreating = true } label: {
                    row(icon: "plus", title: "Create playlist", color: Theme.textMuted)
                }
                .accessibilityIdentifier("playlists.create")
                .buttonStyle(.plain)
                .focusEffectDisabled()

                ForEach(playlists.playlists) { playlist in
                    HStack(spacing: 10) {
                        Button { navigation.showFolder([playlist.id.uuidString]) } label: {
                            HStack(spacing: 10) {
                                row(icon: "list.triangle", title: playlist.name, color: Theme.textPrimary)
                                Text("^[\(playlist.files.count) item](inflect: true)")
                                    .font(.inter(14))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .accessibilityLabel("Open playlist \(playlist.name)")
                        .accessibilityIdentifier("playlist.\(playlist.name)")

                        PlaylistActions(playlist: playlist) {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .frame(maxWidth: 520)
                    // Rename needs the name sheet, so it lives in the "…" menu only.
                    .contextMenu {
                        Button("Delete Playlist…", role: .destructive) { pendingDelete = playlist }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollIndicators(.never)
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { playlist in
            Button("Delete Playlist", role: .destructive) { playlists.delete(playlist.id) }
        } message: { _ in
            Text("The files themselves aren't deleted.")
        }
        .sheet(isPresented: $isCreating) {
            PlaylistNameSheet(title: "New Playlist", confirmTitle: "Create") { name in
                playlists.create(named: name)
            }
        }
    }

    private func row(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.inter(14))
                .foregroundStyle(color)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 32)
        .contentShape(.rect)
    }
}

/// Rename / Delete for a playlist, as a "…" menu button.
struct PlaylistActions<Label: View>: View {
    let playlist: Playlist
    @ViewBuilder let label: Label
    var onDelete: () -> Void = {}

    @Environment(PlaylistStore.self) private var playlists
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false

    var body: some View {
        Menu {
            Button("Rename…") { isRenaming = true }
            Button("Delete…", role: .destructive) { isConfirmingDelete = true }
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .tint(Theme.textSecondary)
        .fixedSize()
        .accessibilityLabel("Playlist Options")
        .sheet(isPresented: $isRenaming) {
            PlaylistNameSheet(title: "Rename Playlist", confirmTitle: "Rename", initialName: playlist.name) { name in
                playlists.rename(playlist.id, to: name)
            }
        }
        .confirmationDialog("Delete “\(playlist.name)”?", isPresented: $isConfirmingDelete) {
            Button("Delete Playlist", role: .destructive) {
                playlists.delete(playlist.id)
                onDelete()
            }
        } message: {
            Text("The files themselves aren't deleted.")
        }
    }
}

/// Name field dialog for creating or renaming a playlist.
struct PlaylistNameSheet: View {
    let title: String
    let confirmTitle: String
    var initialName = ""
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.inter(16, .medium))
                .foregroundStyle(Theme.textBright)
            TextField("Playlist name", text: $name)
                .accessibilityIdentifier("playlistName.field")
                .textFieldStyle(.plain)
                .font(.inter(14))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Theme.well, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panel))
                .focused($isFocused)
                .onSubmit(confirm)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
                Button(action: confirm) {
                    Text(confirmTitle)
                        .font(.inter(14, .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Theme.accent, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("playlistName.confirm")
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Theme.bar)
        .onAppear {
            name = initialName
            isFocused = true
        }
    }

    private func confirm() {
        onConfirm(name)
        dismiss()
    }
}
