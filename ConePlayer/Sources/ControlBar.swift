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
/// The Figma's volume component: a tapered dark track with the same taper filled by
/// VLC's green → red ramp. Drawn to the component's 88×28 geometry and fill scale.
private struct VolumeWedge: View {
    @Environment(PlayerController.self) private var player
    @State private var scroll = ScrollWheelMonitor()

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = width * VolumeScale.fraction(for: player.volume)
            ZStack(alignment: .leading) {
                VolumeTrack().fill(Theme.well)
                ZStack {
                    // The Figma's full green → red ramp spans the bar, so the Mac at 100%
                    // ends in red, like the component's top state.
                    VolumeFill().fill(
                        LinearGradient(gradient: Theme.volumeGradient,
                                       startPoint: UnitPoint(x: -0.03, y: 0.5),
                                       endPoint: UnitPoint(x: 1.02, y: 0.5))
                    )
                    VolumeFill().fill(Color.black.opacity(0.2))
                }
                .mask(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 1,
                                           bottomTrailingRadius: 2, topTrailingRadius: 2)
                        .frame(width: max(filled, 1))
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let fraction = min(max(value.location.x / width, 0), 1)
                    player.volume = VolumeScale.volume(for: fraction).rounded()
                }
            )
        }
        .onHover { scroll.isActive = $0 }
        .onAppear {
            scroll.onStep = { up in up ? player.volumeUp() : player.volumeDown() }
            scroll.install()
        }
        .onDisappear { scroll.remove() }
        .disabled(!player.canChangeVolume)
        .opacity(player.canChangeVolume ? 1 : 0.5)
        .help(player.canChangeVolume
              ? "Mac volume \(Int(player.volume))% (volume keys, ⌘↑ / ⌘↓, or scroll)"
              : "This output's volume can't be changed from the Mac")
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

/// How far the volume fill reaches for the Mac's volume (0…100%). Uses the Figma
/// component's 0–100% states (fill width at 0, 10 … 100% out of its 88 pt), stretched
/// so 100% fills the whole taper.
enum VolumeScale {
    private static let points: [(volume: Double, width: Double)] = [
        (0, 1), (10, 7), (20, 14), (30, 20), (40, 26), (50, 33), (60, 41),
        (70, 48), (80, 53), (90, 58), (100, 63),
    ]
    /// The Figma's 100% fill width; it becomes the full width here.
    private static let fullWidth = 63.0

    /// 0…1 of the control's width for a volume of 0…100%.
    static func fraction(for volume: Double) -> Double {
        let v = min(max(volume, 0), 100)
        guard v > 0 else { return 0 }
        return interpolate(v, from: \.volume, to: \.width) / fullWidth
    }

    /// The volume for a point 0…1 across the control (the inverse of `fraction`).
    static func volume(for fraction: Double) -> Double {
        let width = min(max(fraction, 0), 1) * fullWidth
        guard width > points[0].width else { return 0 }
        return interpolate(width, from: \.width, to: \.volume)
    }

    private static func interpolate(_ x: Double, from input: KeyPath<(volume: Double, width: Double), Double>,
                                    to output: KeyPath<(volume: Double, width: Double), Double>) -> Double {
        for (a, b) in zip(points, points.dropFirst()) where x <= b[keyPath: input] {
            let t = (x - a[keyPath: input]) / (b[keyPath: input] - a[keyPath: input])
            return a[keyPath: output] + t * (b[keyPath: output] - a[keyPath: output])
        }
        return points.last![keyPath: output]
    }
}

/// The component's track outline (Figma path, 89×28), scaled to the frame.
private struct VolumeTrack: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 89, sy = rect.height / 28
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(3.59756, 19.3638))
        path.addCurve(to: p(0, 15.3841), control1: p(1.55468, 19.1572), control2: p(0, 17.4374))
        path.addLine(to: p(0, 12.6159))
        path.addCurve(to: p(3.59756, 8.6362), control1: p(0, 10.5626), control2: p(1.55467, 8.84279))
        path.addLine(to: p(85.6982, 0.333893))
        path.addCurve(to: p(89, 3.31867), control1: p(87.4654, 0.155189), control2: p(89, 1.54247))
        path.addLine(to: p(89, 24.6813))
        path.addCurve(to: p(85.6982, 27.6661), control1: p(89, 26.4575), control2: p(87.4654, 27.8448))
        path.closeSubpath()
        return path
    }
}

/// The component's fill shape: the track inset by 1.5 pt (Figma path, 86×25 at 1.5, 1.5).
private struct VolumeFill: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 89, sy = rect.height / 28
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + (x + 1.5) * sx, y: rect.minY + (y + 1.5) * sy) }
        var path = Path()
        path.move(to: p(1.79183, 16.1875))
        path.addCurve(to: p(0, 14.1984), control1: p(0.773415, 16.0809), control2: p(0, 15.2223))
        path.addLine(to: p(0, 10.8016))
        path.addCurve(to: p(1.79183, 8.81246), control1: p(0, 9.77762), control2: p(0.773416, 8.91904))
        path.addLine(to: p(83.7918, 0.231086))
        path.addCurve(to: p(86, 2.22022), control1: p(84.9723, 0.107549), control2: p(86, 1.03331))
        path.addLine(to: p(86, 22.7798))
        path.addCurve(to: p(83.7918, 24.7689), control1: p(86, 23.9667), control2: p(84.9723, 24.8924))
        path.closeSubpath()
        return path
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
