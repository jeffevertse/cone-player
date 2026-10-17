import SwiftUI

/// The Settings window (⌘,), built to the Figma's "Settings – …" frames.
struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable, Codable {
        case playback = "Playback"
        case audio = "Audio"
        case subtitles = "Subtitles"

        var id: Self { self }

        var title: String {
            switch self {
            case .playback: "Playback Preferences"
            case .audio: "Audio Defaults"
            case .subtitles: "Subtitle Defaults"
            }
        }

        var systemImage: String {
            switch self {
            case .playback: "play"
            case .audio: "waveform"
            case .subtitles: "captions.bubble"
            }
        }
    }

    @AppStorage("settingsPane") private var pane: Pane = .playback

    var body: some View {
        VStack(spacing: 0) {
            // Header: traffic lights sit over the left part, page title over the content.
            HStack(spacing: 0) {
                Color.clear.frame(width: 216)
                Text(pane.title)
                    .font(.inter(16))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 24)
                Spacer()
            }
            .frame(height: 50)
            .background(Theme.well)

            HStack(spacing: 0) {
                sidebar
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch pane {
                        case .playback: PlaybackPane()
                        case .audio: AudioPane()
                        case .subtitles: SubtitlesPane()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: 1048)
        .frame(minHeight: 760, maxHeight: .infinity)
        .background(Theme.canvas)
        .ignoresSafeArea()
        .containerBackground(Theme.canvas, for: .window)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .font(.inter(14))
        .foregroundStyle(Theme.textSecondary)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Media")
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 10)
                .frame(height: 33, alignment: .center)
            ForEach(Pane.allCases) { item in
                let isSelected = pane == item
                Button { pane = item } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                            .frame(width: 32, height: 32)
                        Text(item.rawValue)
                            .foregroundStyle(isSelected ? Color(hex: 0xEAEAEA) : Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(4)
                    .background(isSelected ? Color(hex: 0x222222) : .clear, in: .rect(cornerRadius: 2))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel.opacity(0.95), in: .rect(cornerRadius: 6))
        .padding(8)
        .frame(width: 216)
    }
}

// MARK: - Panes

private struct PlaybackPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("Startup") {
            SettingsRow("Default playback speed", info: "Applies to everything you play.") {
                NotchedSlider(
                    value: $settings.playbackRate,
                    stops: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2],
                    label: { $0.formatted() },
                    accessibilityLabel: "Default playback speed"
                )
            }
        }
        SettingsSection("Seeking") {
            SettingsRow("Jump interval", info: "How far the jump buttons and ⌘← / ⌘→ move.") {
                SegmentedValues(selection: $settings.jumpInterval, options: [5, 10, 15, 30]) { "\($0)s" }
            }
        }
        SettingsSection("Order") {
            SettingsRow("Play next item when one finishes", info: "Continue with the next file in the list.") {
                OnOffToggle(isOn: $settings.autoPlayNext, label: "Play next item when one finishes")
            }
        }
    }
}

private struct AudioPane: View {
    @Environment(SettingsStore.self) private var settings
    @State private var isEqualizerOpen = true

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("Tracks & Languages") {
            SettingsRow("Preferred language", info: "Used when a file has more than one audio track.") {
                LanguageDropdown(code: $settings.preferredAudioLanguage, label: "Preferred audio language")
            }
        }
        SettingsSection("Sync") {
            SettingsRow("Audio delay", info: "Positive values play the sound later.") {
                DelayField(milliseconds: $settings.audioDelay, step: 50, label: "Audio delay")
            }
        }
        SettingsSection("Effects") {
            SettingsRow("Equalizer", info: "VLC's 10-band equalizer.") {
                OnOffToggle(isOn: $settings.isEqualizerEnabled, label: "Equalizer")
            }
            SettingsRow("Equalizer preset", info: "Loads one of VLC's presets into the bands.") {
                Dropdown(
                    selection: Binding(
                        get: { settings.equalizerPreset ?? -1 },
                        set: { if $0 >= 0 { settings.applyEqualizerPreset($0) } else { settings.resetEqualizer() } }
                    ),
                    options: [(-1, "None")] + Equalizer.presetNames.enumerated().map { ($0.offset, $0.element) },
                    label: "Equalizer preset"
                )
            }
            EqualizerPanel(isOpen: $isEqualizerOpen)
                .padding(.top, 5)
                .disabled(!settings.isEqualizerEnabled)
                .opacity(settings.isEqualizerEnabled ? 1 : 0.5)
        }
    }
}

private struct SubtitlesPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("Tracks & Languages") {
            SettingsRow("Preferred language", info: "Turns on subtitles in this language when a file has them.") {
                LanguageDropdown(code: $settings.preferredSubtitleLanguage, label: "Preferred subtitle language")
            }
        }
        SettingsSection("Appearance") {
            SettingsRow("Font size", info: "Relative to VLC's default subtitle size.") {
                NotchedSlider(
                    value: $settings.subtitleScale,
                    stops: [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2],
                    label: { $0.formatted(.percent) },
                    accessibilityLabel: "Subtitle font size"
                )
            }
        }
        SettingsSection("Sync") {
            SettingsRow("Subtitle delay", info: "Positive values show subtitles later.") {
                DelayField(milliseconds: $settings.subtitleDelay, step: 100, label: "Subtitle delay")
            }
        }
    }
}

// MARK: - Layout

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.inter(16, .medium))
                .foregroundStyle(Theme.textBright)
                .padding(.top, 10)
                .frame(height: 39, alignment: .center)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// Label with an ⓘ hint on the left, a 320pt control on the right.
private struct SettingsRow<Control: View>: View {
    let title: String
    let info: String
    @ViewBuilder let control: Control

    init(_ title: String, info: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.info = info
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(title)
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.separator)
                    .help(info)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(info)
            Spacer(minLength: 16)
            control
                .frame(width: 320, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .frame(minHeight: 42)
    }
}

// MARK: - Controls

/// The Figma's ON/OFF block toggle (68×32).
private struct OnOffToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 3) {
                if isOn {
                    Text("ON")
                        .font(.inter(12))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 33, height: 26)
                        .background(Theme.accentWell, in: .rect(cornerRadius: 3))
                    RoundedRectangle(cornerRadius: 3).fill(Theme.accentDim).frame(width: 26, height: 26)
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.separator).frame(width: 26, height: 26)
                    Text("OFF")
                        .font(.inter(12))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 33, height: 26)
                }
            }
            .padding(3)
            .background(Theme.well, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
            .animation(.snappy(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityRepresentation { Toggle(label, isOn: $isOn) }
    }
}

/// The Figma's dropdown: a 320×36 well with the current option and a chevron.
private struct Dropdown<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    let label: String
    @State private var isOpen = false

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack {
                Text(options.first { $0.0 == selection }?.1 ?? "")
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Theme.panel, in: .rect(cornerRadius: 4))
            .padding(2)
            .background(Theme.well, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(label)
        .accessibilityValue(options.first { $0.0 == selection }?.1 ?? "")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(options, id: \.0) { value, title in
                        Button {
                            selection = value
                            isOpen = false
                        } label: {
                            Text(title)
                                .foregroundStyle(value == selection ? Theme.accent : Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(value == selection ? Theme.accentWell : Theme.panel, in: .rect(cornerRadius: 4))
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
            .font(.inter(14))
            .frame(width: 316, height: min(CGFloat(options.count) * 34 + 4, 360))
            .background(Theme.well)
        }
    }
}

private struct LanguageDropdown: View {
    @Binding var code: String
    let label: String

    private static let codes = ["en", "nl", "de", "fr", "es", "it", "pt", "sv", "da", "no", "fi", "pl", "tr", "ru", "ar", "hi", "ja", "ko", "zh"]

    var body: some View {
        Dropdown(
            selection: $code,
            options: [("", "Automatic")] + Self.codes.map { ($0, Locale.current.localizedString(forLanguageCode: $0) ?? $0) },
            label: label
        )
    }
}

/// Notched slider from the Figma: dark well, dark-orange fill, tick marks, 8×24 thumb, stop labels.
private struct NotchedSlider: View {
    @Binding var value: Double
    let stops: [Double]
    let label: (Double) -> String
    let accessibilityLabel: String

    private var index: Int {
        stops.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width - 4
                let step = width / CGFloat(stops.count - 1)
                let x = 2 + step * CGFloat(index)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.well).frame(height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accentWell)
                        .frame(width: max(x - 2, 0), height: 12)
                        .offset(x: 2)
                    ForEach(1..<stops.count - 1, id: \.self) { i in
                        Rectangle()
                            .fill(i < index ? Theme.accentDim.opacity(0.6) : Theme.separator)
                            .frame(width: 1, height: 6)
                            .offset(x: 2 + step * CGFloat(i))
                    }
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accentDim)
                        .frame(width: 8, height: 24)
                        .offset(x: min(max(x - 4, 0), proxy.size.width - 8))
                }
                .frame(height: 24)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let i = Int(((drag.location.x - 2) / step).rounded())
                    value = stops[min(max(i, 0), stops.count - 1)]
                })
            }
            .frame(height: 24)

            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                    Text(label(stop))
                        .font(.inter(12))
                        .foregroundStyle(i == index ? Theme.textSecondary : Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : i == stops.count - 1 ? .trailing : .center)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = stops[min(index + 1, stops.count - 1)]
            case .decrement: value = stops[max(index - 1, 0)]
            @unknown default: break
            }
        }
    }
}

/// Side-by-side choices like the Figma's "Relative / Pixels" control.
private struct SegmentedValues<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(isSelected ? Theme.accentWell : Theme.panel, in: .rect(cornerRadius: 4))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.well, in: .rect(cornerRadius: 6))
    }
}

/// Text-field-style well with − and + for millisecond delays.
private struct DelayField: View {
    @Binding var milliseconds: Int
    let step: Int
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Button { milliseconds -= step } label: {
                Image(systemName: "minus").frame(width: 40, height: 36).contentShape(.rect)
            }
            .accessibilityLabel("Decrease \(label)")
            Text("\(milliseconds) ms")
                .monospacedDigit()
                .foregroundStyle(milliseconds == 0 ? Theme.textSecondary : Theme.accent)
                .frame(maxWidth: .infinity)
                .onTapGesture(count: 2) { milliseconds = 0 }
                .help("Double-click to reset")
            Button { milliseconds += step } label: {
                Image(systemName: "plus").frame(width: 40, height: 36).contentShape(.rect)
            }
            .accessibilityLabel("Increase \(label)")
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .foregroundStyle(Theme.textSecondary)
        .background(Theme.well, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panel))
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(milliseconds) milliseconds")
    }
}

// MARK: - Equalizer

/// The Figma's collapsible equalizer: "Open/Close Equalizer" bar, tall faders, dB chips.
private struct EqualizerPanel: View {
    @Binding var isOpen: Bool
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            Button { isOpen.toggle() } label: {
                HStack(spacing: 10) {
                    Text(isOpen ? "Close Equalizer" : "Open Equalizer")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            if isOpen {
                HStack(alignment: .top, spacing: 8) {
                    band("Preamp", value: $settings.equalizerPreamp)
                    ForEach(0..<Equalizer.bandCount, id: \.self) { index in
                        band(
                            Equalizer.label(for: Equalizer.frequencies.indices.contains(index) ? Equalizer.frequencies[index] : 0),
                            value: Binding(get: { settings.equalizerBands[index] }, set: { settings.setBand(index, to: $0) })
                        )
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
        }
        .background(isOpen ? Theme.panel : Theme.well, in: .rect(cornerRadius: 2))
    }

    private func band(_ label: String, value: Binding<Float>) -> some View {
        VStack(spacing: 0) {
            Fader(value: value, label: label)
                .frame(width: 24, height: 240)
            Text(label)
                .font(.inter(13))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .fixedSize()
                .padding(.top, 26)
            Text("\(value.wrappedValue, specifier: "%.1f") dB")
                .font(.inter(12).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 60, height: 32)
                .background(Theme.well, in: .rect(cornerRadius: 6))
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Vertical EQ fader: dark well filled dark-orange from the bottom, orange 24×8 thumb.
private struct Fader: View {
    @Binding var value: Float
    let label: String
    private let range: ClosedRange<Float> = -20...20

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let y = (height - 8) * (1 - fraction) + 4
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6).fill(Theme.well).frame(width: 16)
                RoundedRectangle(cornerRadius: 4).fill(Theme.accentWell)
                    .frame(width: 12, height: max(height - y - 2, 0))
                    .offset(y: y)
                RoundedRectangle(cornerRadius: 4).fill(Theme.accentDim)
                    .frame(width: 24, height: 8)
                    .offset(y: y - 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let f = Float(1 - min(max((drag.location.y - 4) / (height - 8), 0), 1))
                // Snap to 0.5 dB steps.
                value = ((range.lowerBound + f * (range.upperBound - range.lowerBound)) * 2).rounded() / 2
            })
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(value.formatted()) decibels")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}
