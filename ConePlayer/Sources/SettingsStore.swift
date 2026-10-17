import Foundation
import Observation
import VLCKit

/// User preferences, saved in UserDefaults and applied to the player as they change.
@MainActor
@Observable
final class SettingsStore {
    // MARK: Playback

    /// Playback speed, 0.25×–4×.
    var playbackRate: Double = 1 { didSet { changed("playbackRate", playbackRate) } }
    /// Seconds the ±jump buttons and ⌘← / ⌘→ move.
    var jumpInterval: Int = 10 { didSet { changed("jumpInterval", jumpInterval) } }
    /// Play the next item in the list when one finishes.
    var autoPlayNext = true { didSet { changed("autoPlayNext", autoPlayNext) } }

    // MARK: Audio

    /// Milliseconds; positive delays the audio.
    var audioDelay: Int = 0 { didSet { changed("audioDelay", audioDelay) } }
    /// ISO 639 code such as "en", or empty for the file's default.
    var preferredAudioLanguage = "" { didSet { changed("preferredAudioLanguage", preferredAudioLanguage) } }
    var isEqualizerEnabled = false { didSet { changed("isEqualizerEnabled", isEqualizerEnabled) } }
    /// Index into `Equalizer.presetNames`, or nil once the bands are edited by hand.
    var equalizerPreset: Int? { didSet { changed("equalizerPreset", equalizerPreset ?? -1) } }
    /// -20…20 dB.
    var equalizerPreamp: Float = 12 { didSet { changed("equalizerPreamp", equalizerPreamp) } }
    /// Ten bands, -20…20 dB each.
    var equalizerBands: [Float] = Array(repeating: 0, count: Equalizer.bandCount) {
        didSet { changed("equalizerBands", equalizerBands) }
    }

    // MARK: Subtitles

    /// Milliseconds; positive shows subtitles later.
    var subtitleDelay: Int = 0 { didSet { changed("subtitleDelay", subtitleDelay) } }
    /// 0.5×–2× of VLC's default subtitle size.
    var subtitleScale: Double = 1 { didSet { changed("subtitleScale", subtitleScale) } }
    var preferredSubtitleLanguage = "" { didSet { changed("preferredSubtitleLanguage", preferredSubtitleLanguage) } }

    /// Called after any setting changes; the player re-applies them.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLoading = true
        defer { isLoading = false }
        playbackRate = defaults.object(forKey: "playbackRate") as? Double ?? playbackRate
        jumpInterval = defaults.object(forKey: "jumpInterval") as? Int ?? jumpInterval
        autoPlayNext = defaults.object(forKey: "autoPlayNext") as? Bool ?? autoPlayNext
        audioDelay = defaults.object(forKey: "audioDelay") as? Int ?? audioDelay
        preferredAudioLanguage = defaults.string(forKey: "preferredAudioLanguage") ?? ""
        isEqualizerEnabled = defaults.bool(forKey: "isEqualizerEnabled")
        let preset = defaults.object(forKey: "equalizerPreset") as? Int ?? -1
        equalizerPreset = preset >= 0 ? preset : nil
        equalizerPreamp = defaults.object(forKey: "equalizerPreamp") as? Float ?? equalizerPreamp
        if let bands = defaults.array(forKey: "equalizerBands") as? [Float], bands.count == Equalizer.bandCount {
            equalizerBands = bands
        }
        subtitleDelay = defaults.object(forKey: "subtitleDelay") as? Int ?? subtitleDelay
        subtitleScale = defaults.object(forKey: "subtitleScale") as? Double ?? subtitleScale
        preferredSubtitleLanguage = defaults.string(forKey: "preferredSubtitleLanguage") ?? ""
    }

    /// Loads a VLC equalizer preset into the bands.
    func applyEqualizerPreset(_ index: Int) {
        guard let preset = Equalizer.preset(at: index) else { return }
        equalizerPreamp = preset.preamp
        equalizerBands = preset.bands
        equalizerPreset = index
    }

    /// Sets one band by hand, which leaves any preset.
    func setBand(_ index: Int, to value: Float) {
        equalizerBands[index] = value
        equalizerPreset = nil
    }

    func resetEqualizer() {
        equalizerPreamp = 12
        equalizerBands = Array(repeating: 0, count: Equalizer.bandCount)
        equalizerPreset = nil
    }

    private func changed(_ key: String, _ value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
        onChange?()
    }
}

/// VLC's 10-band equalizer: band frequencies and built-in presets.
enum Equalizer {
    static let bandCount = 10
    static let frequencies: [Float] = VLCAudioEqualizer().bands.map(\.frequency)
    static let presetNames: [String] = VLCAudioEqualizer.presets.map(\.name)

    static func preset(at index: Int) -> (preamp: Float, bands: [Float])? {
        guard VLCAudioEqualizer.presets.indices.contains(index) else { return nil }
        let equalizer = VLCAudioEqualizer(preset: VLCAudioEqualizer.presets[index])
        return (equalizer.preAmplification, equalizer.bands.map(\.amplification))
    }

    /// A VLCKit equalizer holding these values.
    static func make(preamp: Float, bands: [Float]) -> VLCAudioEqualizer {
        let equalizer = VLCAudioEqualizer()
        equalizer.preAmplification = preamp
        for (band, value) in zip(equalizer.bands, bands) {
            band.amplification = value
        }
        return equalizer
    }

    static func label(for frequency: Float) -> String {
        frequency >= 1000 ? "\(Int(frequency / 1000)) KHz" : "\(Int(frequency)) Hz"
    }
}
