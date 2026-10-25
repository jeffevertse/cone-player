import SwiftUI

/// The 54pt control bar from the Figma: transport, time, progress, volume and track menus.
struct ControlBar: View {
    @Environment(PlayerController.self) private var player
    @State private var isShowingQueue = false

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                IconButton("backward.end.fill", label: "Previous") { player.previous() }
                IconButton("gobackward.\(player.settings.jumpInterval)", label: "Back \(player.settings.jumpInterval) Seconds") { player.jumpBack() }
                PlayButton()
                IconButton("goforward.\(player.settings.jumpInterval)", label: "Forward \(player.settings.jumpInterval) Seconds") { player.jumpForward() }
                IconButton("forward.end.fill", label: "Next") { player.next() }
                    .disabled(!player.hasNext)
                    .opacity(player.hasNext ? 1 : 0.4)
            }

            HStack(spacing: 8) {
                TimeLabel(text: player.elapsed.clockString)
                ProgressTrack(style: player.current?.kind == .audio ? .waveform : .bar)
                    .frame(height: 28)
                TimeLabel(text: player.duration.clockString)
            }

            HStack(spacing: 8) {
                Button { player.toggleMute() } label: {
                    Image(systemName: player.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .help(player.isMuted ? "Unmute (⌥⌘↓)" : "Mute (⌥⌘↓)")
                .accessibilityLabel(player.isMuted ? "Unmute" : "Mute")
                VolumeWedge()
                    .frame(width: 88, height: 28)
            }

            HStack(spacing: 12) {
                IconButton(
                    player.isRecording ? "record.circle.fill" : "record.circle",
                    label: player.isRecording ? "Stop Recording" : "Start Recording",
                    tint: player.isRecording ? .red : Theme.textSecondary
                ) { player.toggleRecording() }
                trackMenu("waveform", label: "Audio Track", tracks: player.audioTracks, allowsOff: false) {
                    player.selectAudioTrack($0 ?? "")
                }
                trackMenu("captions.bubble", label: "Subtitles", tracks: player.subtitleTracks, allowsOff: true) {
                    player.selectSubtitleTrack($0)
                }
                IconButton("list.bullet", label: "Queue") { isShowingQueue.toggle() }
                    .popover(isPresented: $isShowingQueue, arrowEdge: .top) { QueueList() }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: Theme.controlBarHeight)
        .background(Theme.panel.opacity(0.95))
        .overlay(alignment: .top) { Theme.barStroke.frame(height: 1) }
        .disabled(player.current == nil)
    }

    private func trackMenu(
        _ systemImage: String,
        label: String,
        tracks: [PlayerController.Track],
        allowsOff: Bool,
        select: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            if allowsOff {
                Toggle("Off", isOn: .init(get: { !tracks.contains(where: \.isSelected) }, set: { _ in select(nil) }))
            }
            ForEach(tracks) { track in
                Toggle(track.name, isOn: .init(get: { track.isSelected }, set: { _ in select(track.id) }))
            }
            if tracks.isEmpty {
                Text("No \(label) Tracks")
            }
        } label: {
            Image(systemName: systemImage)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .tint(Theme.textSecondary)
        .fixedSize()
        .frame(width: 30, height: 32)
        .foregroundStyle(Theme.textSecondary)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct TimeLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.inter(15).monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)
            .fixedSize()
    }
}

// MARK: - Progress

/// Seekable progress track. `.bar` and `.compact` fill with dark orange and end in an
/// orange handle; `.waveform` draws bars (decorative, not real audio data) like "Player – Music".
struct ProgressTrack: View {
    enum Style { case bar, compact, waveform }

    let style: Style
    @Environment(PlayerController.self) private var player

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 4
            let x = width * player.position
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Theme.well)
                switch style {
                case .bar, .compact:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accentWell)
                        .frame(width: max(x, style == .bar ? 8 : 0))
                        .padding(2)
                    if style == .bar {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.accent)
                            .frame(width: 8)
                            .padding(.vertical, 2)
                            .offset(x: 2 + max(x - 8, 0))
                    }
                case .waveform:
                    Waveform(progress: player.position)
                        .padding(.horizontal, 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                        .offset(x: 2 + max(x - 4, 0))
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        player.isScrubbing = true
                        player.position = min(max((value.location.x - 2) / width, 0), 1)
                    }
                    .onEnded { _ in player.isScrubbing = false }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Playback Position")
        .accessibilityValue("\(player.elapsed.clockString) of \(player.duration.clockString)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.jumpForward()
            case .decrement: player.jumpBack()
            @unknown default: break
            }
        }
    }
}

private struct Waveform: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 5
            let count = Int(size.width / step)
            for i in 0..<count {
                // Deterministic pseudo-random heights so the shape is stable between frames.
                let seed = sin(Double(i) * 12.9898) * 43758.5453
                let level = abs(seed - seed.rounded(.down))
                let height = max(2, CGFloat(level) * 14 + (i % 3 == 0 ? 0 : 4))
                let rect = CGRect(x: CGFloat(i) * step, y: (size.height - height) / 2, width: 2, height: height)
                let played = Double(i) / Double(max(count, 1)) < progress
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(played ? Theme.accentDim : Theme.separator))
            }
        }
    }
}

// MARK: - Volume

/// VLC's wedge volume control: 0–200%, green → red, drawn as a rising triangle.
private struct VolumeWedge: View {
    @Environment(PlayerController.self) private var player
    @State private var scroll = ScrollWheelMonitor()

    private var maximum: Double { player.settings.maximumVolume }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Theme.well
                Wedge().fill(Theme.wedge)
                // The gradient spans 0…200% whatever the maximum, so red always
                // means amplification; a lower maximum just shows less of it.
                Wedge()
                    .fill(LinearGradient(gradient: Theme.volumeGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * SettingsStore.volumeLimit / maximum)
                    .frame(width: width, alignment: .leading)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * player.volume / maximum)
                    }
            }
            .clipShape(.rect(cornerRadius: 2))
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    player.volume = (min(max(value.location.x / width, 0), 1) * maximum).rounded()
                }
            )
        }
        .onHover { scroll.isActive = $0 }
        .onAppear {
            scroll.onStep = { up in up ? player.volumeUp() : player.volumeDown() }
            scroll.install()
        }
        .onDisappear { scroll.remove() }
        .help("Volume \(Int(player.volume))% (⌘↑ / ⌘↓, or scroll)")
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(player.volume)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.volumeUp()
            case .decrement: player.volumeDown()
            @unknown default: break
            }
        }
    }
}

/// Turns scroll-wheel and trackpad scrolls over the volume wedge into volume steps.
/// Trackpads send many small deltas, so those are added up before each step.
@MainActor
private final class ScrollWheelMonitor {
    var isActive = false
    var onStep: (Bool) -> Void = { _ in }
    private var monitor: Any?
    private var accumulated: CGFloat = 0

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let delta = event.scrollingDeltaY
            let precise = event.hasPreciseScrollingDeltas
            let handled = MainActor.assumeIsolated { self?.handle(delta: delta, precise: precise) ?? false }
            return handled ? nil : event
        }
    }

    func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(delta: CGFloat, precise: Bool) -> Bool {
        guard isActive, delta != 0 else { return false }
        accumulated += precise ? delta / 12 : delta
        while abs(accumulated) >= 1 {
            onStep(accumulated > 0)
            accumulated -= accumulated > 0 ? 1 : -1
        }
        return true
    }
}

private struct Wedge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}

// MARK: - Queue

private struct QueueList: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(player.queue) { item in
                    Button { player.play(item) } label: {
                        Text(item.fileName)
                            .font(.inter(14))
                            .foregroundStyle(item == player.current ? Theme.accentText : Theme.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: min(CGFloat(player.queue.count) * 30 + 16, 420))
        .background(Theme.bar)
    }
}
