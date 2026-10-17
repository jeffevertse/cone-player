import SwiftUI

/// File › Open Network Stream…: a URL field plus recently opened streams.
struct NetworkStreamSheet: View {
    @Environment(PlayerController.self) private var player
    @Environment(PlaybackHistory.self) private var history
    @Environment(Navigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var problem: String?
    @FocusState private var isFocused: Bool

    /// Schemes VLC can open that make sense to type in here.
    private static let schemes: Set<String> = ["http", "https", "rtsp", "rtsps", "rtmp", "rtmps", "rtp", "udp", "mms", "mmsh", "srt", "ftp", "sftp", "smb"]

    private var recentStreams: [MediaItem] {
        history.recentItems.filter(\.isStream)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Open Network Stream")
                .font(.inter(16, .medium))
                .foregroundStyle(Theme.textBright)

            VStack(alignment: .leading, spacing: 8) {
                Text("Network URL")
                    .font(.inter(14))
                    .foregroundStyle(Theme.textSecondary)
                TextField("https://, rtsp://, rtmp://, udp://…", text: $address)
                    .textFieldStyle(.plain)
                    .font(.inter(14))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Theme.well, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(problem == nil ? Theme.panel : Theme.accent))
                    .focused($isFocused)
                    .onSubmit(open)
                    .onChange(of: address) { problem = nil }
                if let problem {
                    Text(problem)
                        .font(.inter(12))
                        .foregroundStyle(Theme.accentText)
                }
            }

            if !recentStreams.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.inter(14))
                        .foregroundStyle(Theme.textMuted)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(recentStreams.prefix(8)) { stream in
                                Button { address = stream.url.absoluteString } label: {
                                    Text(stream.url.absoluteString)
                                        .font(.inter(13))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(height: 30)
                                        .background(Theme.panel, in: .rect(cornerRadius: 4))
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
                Button(action: open) {
                    Text("Open")
                        .font(.inter(14, .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 20)
                        .frame(height: 32)
                        .background(Theme.accent, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Theme.bar)
        .onAppear {
            // Prefill from the clipboard when it holds a stream URL, as VLC does.
            if let text = NSPasteboard.general.string(forType: .string), Self.streamURL(from: text) != nil {
                address = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            isFocused = true
        }
    }

    private func open() {
        guard let url = Self.streamURL(from: address) else {
            problem = "Enter a full address that starts with http://, https://, rtsp:// or similar."
            return
        }
        let item = MediaItem(streamURL: url)
        player.play(item, in: [item])
        navigation.screen = .player
        dismiss()
    }

    static func streamURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme), url.host() != nil || scheme == "udp" || scheme == "rtp" else { return nil }
        return url
    }
}
