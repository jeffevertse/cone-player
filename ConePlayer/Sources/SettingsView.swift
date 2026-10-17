import SwiftUI

/// The Settings window (⌘,), modeled on the Figma's "Settings – …" frames.
struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable, Codable {
        case playback = "Playback"
        case audio = "Audio"
        case subtitles = "Subtitles"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .playback: "play.circle"
            case .audio: "speaker.wave.2"
            case .subtitles: "captions.bubble"
            }
        }
    }

    @AppStorage("settingsPane") private var pane: Pane = .playback

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Pane.allCases) { item in
                    Button { pane = item } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImage)
                                .frame(width: 20)
                                .foregroundStyle(pane == item ? Theme.accent : Theme.textSecondary)
                            Text(item.rawValue)
                                .foregroundStyle(pane == item ? Theme.textBright : Theme.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .font(.inter(14, pane == item ? .medium : .regular))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(pane == item ? Theme.preview.opacity(0.6) : .clear, in: .rect(cornerRadius: 6))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityAddTraits(pane == item ? .isSelected : [])
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 220)
            .frame(maxHeight: .infinity)
            .background(Theme.panel.ignoresSafeArea())

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(pane.rawValue)
                        .font(.inter(20, .semibold))
                        .foregroundStyle(Theme.textBright)
                    switch pane {
                    case .playback: PlaybackPane()
                    case .audio: AudioPane()
                    case .subtitles: SubtitlesPane()
                    }
                }
                .padding(32)
                .padding(.top, -8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .background(Theme.canvas.ignoresSafeArea())
        }
        .frame(width: 820, height: 640)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .font(.inter(14))
        .foregroundStyle(Theme.textPrimary)
    }
}

// MARK: - Panes

private struct PlaybackPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("General") {
            SettingsRow("Playback speed", detail: "Applies to everything you play.") {
                Picker("Playback speed", selection: $settings.playbackRate) {
                    ForEach([0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 4], id: \.self) { rate in
                        Text(rate == 1 ? "Normal" : rate.formatted() + "×").tag(rate)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }
            SettingsRow("Jump interval", detail: "How far the jump buttons and ⌘← / ⌘→ move.") {
                Picker("Jump interval", selection: $settings.jumpInterval) {
                    ForEach([5, 10, 15, 30], id: \.self) { Text("\($0)s").tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            SettingsRow("Play next item automatically", detail: "Continue with the next file in the list when one ends.") {
                Toggle("Play next item automatically", isOn: $settings.autoPlayNext)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}

private struct AudioPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("Sync and Language") {
            SettingsRow("Audio delay", detail: "Positive values play the sound later.") {
                DelayControl(milliseconds: $settings.audioDelay, step: 50, label: "Audio delay")
            }
            SettingsRow("Preferred language", detail: "Used when a file has more than one audio track.") {
                LanguagePicker(code: $settings.preferredAudioLanguage, label: "Preferred audio language")
            }
        }
        SettingsSection("Equalizer") {
            SettingsRow("Enable equalizer") {
                Toggle("Enable equalizer", isOn: $settings.isEqualizerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            SettingsRow("Preset") {
                HStack(spacing: 12) {
                    Picker("Preset", selection: Binding(
                        get: { settings.equalizerPreset ?? -1 },
                        set: { if $0 >= 0 { settings.applyEqualizerPreset($0) } }
                    )) {
                        Text("Custom").tag(-1)
                        ForEach(Array(Equalizer.presetNames.enumerated()), id: \.offset) { index, name in
                            Text(name).tag(index)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    Button("Reset") { settings.resetEqualizer() }
                }
            }
            EqualizerView()
                .disabled(!settings.isEqualizerEnabled)
                .opacity(settings.isEqualizerEnabled ? 1 : 0.4)
        }
    }
}

private struct SubtitlesPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsSection("Appearance and Sync") {
            SettingsRow("Text size", detail: "Relative to VLC's default size.") {
                HStack(spacing: 12) {
                    Slider(value: $settings.subtitleScale, in: 0.5...2, step: 0.1)
                        .frame(width: 160)
                        .accessibilityLabel("Subtitle text size")
                    Text(settings.subtitleScale, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
            SettingsRow("Subtitle delay", detail: "Positive values show subtitles later.") {
                DelayControl(milliseconds: $settings.subtitleDelay, step: 100, label: "Subtitle delay")
            }
            SettingsRow("Preferred language", detail: "Turns on subtitles in this language when a file has them.") {
                LanguagePicker(code: $settings.preferredSubtitleLanguage, label: "Preferred subtitle language")
            }
        }
    }
}

// MARK: - Building blocks

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.inter(11, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textMuted)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(Theme.panel, in: .rect(cornerRadius: 10))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let control: Control

    init(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(Theme.textBright)
                if let detail {
                    Text(detail)
                        .font(.inter(12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { Theme.barStroke.frame(height: 1) }
    }
}

/// − value + control for millisecond delays.
private struct DelayControl: View {
    @Binding var milliseconds: Int
    let step: Int
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Button { milliseconds -= step } label: { Image(systemName: "minus").frame(width: 32, height: 28) }
                .accessibilityLabel("Decrease \(label)")
            Text("\(milliseconds) ms")
                .monospacedDigit()
                .foregroundStyle(milliseconds == 0 ? Theme.textSecondary : Theme.accent)
                .frame(width: 80)
                .onTapGesture(count: 2) { milliseconds = 0 }
                .help("Double-click to reset")
            Button { milliseconds += step } label: { Image(systemName: "plus").frame(width: 32, height: 28) }
                .accessibilityLabel("Increase \(label)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textSecondary)
        .background(Theme.well, in: .rect(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(milliseconds) milliseconds")
    }
}

private struct LanguagePicker: View {
    @Binding var code: String
    let label: String

    private static let codes = ["en", "nl", "de", "fr", "es", "it", "pt", "sv", "da", "no", "fi", "pl", "tr", "ru", "ar", "hi", "ja", "ko", "zh"]

    var body: some View {
        Picker(label, selection: $code) {
            Text("Automatic").tag("")
            Divider()
            ForEach(Self.codes, id: \.self) { code in
                Text(Locale.current.localizedString(forLanguageCode: code) ?? code).tag(code)
            }
        }
        .labelsHidden()
        .frame(width: 160)
    }
}

// MARK: - Equalizer

private struct EqualizerView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        HStack(alignment: .bottom, spacing: 0) {
            band(label: "Preamp", value: $settings.equalizerPreamp)
            Theme.barStroke.frame(width: 1, height: 170).padding(.horizontal, 8)
            ForEach(0..<Equalizer.bandCount, id: \.self) { index in
                band(
                    label: Equalizer.label(for: Equalizer.frequencies[safe: index] ?? 0),
                    value: Binding(get: { settings.equalizerBands[index] }, set: { settings.setBand(index, to: $0) })
                )
            }
        }
        .padding(.vertical, 16)
    }

    private func band(label: String, value: Binding<Float>) -> some View {
        VStack(spacing: 8) {
            Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
                .font(.inter(11).monospacedDigit())
                .foregroundStyle(Theme.textMuted)
            VerticalSlider(value: value, range: -20...20, label: label)
                .frame(width: 28, height: 140)
            Text(label)
                .font(.inter(11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// An orange vertical fader centered on 0 dB.
private struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let y = height * (1 - fraction)
            ZStack(alignment: .top) {
                Capsule().fill(Theme.well).frame(width: 4)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 4, height: abs(y - height / 2))
                    .offset(y: min(y, height / 2))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.textBright)
                    .frame(width: 20, height: 8)
                    .offset(y: y - 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let f = Float(1 - min(max(drag.location.y / height, 0), 1))
                value = (range.lowerBound + f * (range.upperBound - range.lowerBound)).rounded()
            })
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value)) decibels")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
