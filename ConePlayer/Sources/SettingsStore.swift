import AppKit
import Observation
import VLCKit

/// User preferences, saved in UserDefaults and applied to the player as they change.
@MainActor
@Observable
final class SettingsStore {
    enum ResumeMode: String, CaseIterable {
        case ask = "Ask"
        case always = "Always"
        case never = "Never"
    }

    enum StartupVolumeMode: String, CaseIterable {
        case remember = "Remember last volume"
        case fixed = "Always starts at"
    }

    /// libVLC caps volume at 200%, so the Figma's 300% top end isn't offered.
    static let volumeLimit: Double = 200

    enum Deinterlace: String, CaseIterable {
        case automatic = "Automatic"
        case on = "On"
        case off = "Off"
    }

    enum VideoFit: String, CaseIterable {
        case fit = "Fit inside window"
        case fill = "Fill window"
        case width = "Fit width"
        case height = "Fit height"
    }

    enum Appearance: String, CaseIterable {
        case system = "System"
        case dark = "Dark"
        case light = "Light"
    }

    enum LibraryLayout: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
    }

    static let aspectRatios = ["", "16:9", "4:3", "16:10", "1:1", "5:4", "2.21:1", "2.35:1", "2.39:1"]

    // MARK: Playback

    /// What to do when opening a file that was stopped part-way.
    var resumeMode: ResumeMode = .ask { didSet { changed("resumeMode", resumeMode.rawValue) } }

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

    // MARK: Video

    var deinterlace: Deinterlace = .automatic { didSet { changed("deinterlace", deinterlace.rawValue) } }
    /// "" for the file's own aspect ratio.
    var aspectRatio = "" { didSet { changed("aspectRatio", aspectRatio) } }
    var videoFit: VideoFit = .fit { didSet { changed("videoFit", videoFit.rawValue) } }
    var isColorAdjustEnabled = false { didSet { changed("isColorAdjustEnabled", isColorAdjustEnabled) } }
    /// VLC's adjust filter ranges: brightness and contrast 0…2, saturation 0…3, hue -180…180, gamma 0.01…10.
    var brightness: Double = 1 { didSet { changed("brightness", brightness) } }
    var contrast: Double = 1 { didSet { changed("contrast", contrast) } }
    var saturation: Double = 1 { didSet { changed("saturation", saturation) } }
    var hue: Double = 0 { didSet { changed("hue", hue) } }
    var gamma: Double = 1 { didSet { changed("gamma", gamma) } }

    func resetColorAdjustments() {
        brightness = 1
        contrast = 1
        saturation = 1
        hue = 0
        gamma = 1
    }

    // MARK: Interface

    /// Dark by default, as designed; Light and System are options.
    var appearance: Appearance = .dark {
        didSet {
            changed("appearance", appearance.rawValue)
            applyAppearance()
        }
    }

    /// Sets the whole app's appearance, including Settings and sheets.
    func applyAppearance() {
        switch appearance {
        case .system: NSApp?.appearance = nil
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        }
    }

    var startScreen: LibrarySection = .home { didSet { changed("startScreen", startScreen.rawValue) } }
    var libraryLayout: LibraryLayout = .grid { didSet { changed("libraryLayout", libraryLayout.rawValue) } }
    var showsMiniplayer = true { didSet { changed("showsMiniplayer", showsMiniplayer) } }

    // MARK: Privacy

    /// Remember positions and recently played items. Off means no Recent, no resume.
    var savesHistory = true { didSet { changed("savesHistory", savesHistory) } }

    // MARK: Performance

    /// Decode video with VideoToolbox (the GPU). Off forces software decoding, which
    /// can help with files the hardware decoder shows glitches on.
    var hardwareDecoding = true { didSet { changed("hardwareDecoding", hardwareDecoding) } }

    // MARK: Network

    /// Milliseconds VLC buffers network streams before playing.
    var networkCaching: Double = 1000 { didSet { changed("networkCaching", networkCaching) } }
    var keepsStreamsInRecent = true { didSet { changed("keepsStreamsInRecent", keepsStreamsInRecent) } }

    // MARK: Volume

    /// Top of the control bar's volume wedge, 100…200%.
    var maximumVolume: Double = 200 { didSet { changed("maximumVolume", maximumVolume) } }
    var startupVolumeMode: StartupVolumeMode = .remember {
        didSet { changed("startupVolumeMode", startupVolumeMode.rawValue) }
    }
    /// Used when `startupVolumeMode` is `.fixed`.
    var startupVolume: Double = 100 { didSet { changed("startupVolume", startupVolume) } }
    /// Percent per ⌘↑ / ⌘↓ or scroll step, 1…25.
    var volumeStep: Int = 5 { didSet { changed("volumeStep", volumeStep) } }
    /// The level when the app last quit. Saved without `onChange`, so dragging the
    /// volume doesn't re-apply every other setting.
    private(set) var lastVolume: Double = 100

    func rememberVolume(_ volume: Double) {
        lastVolume = volume
        defaults.set(volume, forKey: "lastVolume")
    }

    /// The level to start at, from the startup setting, within 0…`maximumVolume`.
    var initialVolume: Double {
        let level = startupVolumeMode == .remember ? lastVolume : startupVolume
        return min(max(level, 0), maximumVolume)
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
        resumeMode = defaults.string(forKey: "resumeMode").flatMap(ResumeMode.init(rawValue:)) ?? .ask
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
        deinterlace = defaults.string(forKey: "deinterlace").flatMap(Deinterlace.init(rawValue:)) ?? .automatic
        aspectRatio = defaults.string(forKey: "aspectRatio") ?? ""
        videoFit = defaults.string(forKey: "videoFit").flatMap(VideoFit.init(rawValue:)) ?? .fit
        isColorAdjustEnabled = defaults.bool(forKey: "isColorAdjustEnabled")
        brightness = defaults.object(forKey: "brightness") as? Double ?? brightness
        contrast = defaults.object(forKey: "contrast") as? Double ?? contrast
        saturation = defaults.object(forKey: "saturation") as? Double ?? saturation
        hue = defaults.object(forKey: "hue") as? Double ?? hue
        gamma = defaults.object(forKey: "gamma") as? Double ?? gamma
        appearance = defaults.string(forKey: "appearance").flatMap(Appearance.init(rawValue:)) ?? .dark
        startScreen = defaults.string(forKey: "startScreen").flatMap(LibrarySection.init(rawValue:)) ?? .home
        libraryLayout = defaults.string(forKey: "libraryLayout").flatMap(LibraryLayout.init(rawValue:)) ?? .grid
        showsMiniplayer = defaults.object(forKey: "showsMiniplayer") as? Bool ?? showsMiniplayer
        networkCaching = defaults.object(forKey: "networkCaching") as? Double ?? networkCaching
        savesHistory = defaults.object(forKey: "savesHistory") as? Bool ?? savesHistory
        hardwareDecoding = defaults.object(forKey: "hardwareDecoding") as? Bool ?? hardwareDecoding
        keepsStreamsInRecent = defaults.object(forKey: "keepsStreamsInRecent") as? Bool ?? keepsStreamsInRecent
        maximumVolume = min(defaults.object(forKey: "maximumVolume") as? Double ?? maximumVolume, Self.volumeLimit)
        startupVolumeMode = defaults.string(forKey: "startupVolumeMode").flatMap(StartupVolumeMode.init(rawValue:)) ?? .remember
        startupVolume = defaults.object(forKey: "startupVolume") as? Double ?? startupVolume
        volumeStep = defaults.object(forKey: "volumeStep") as? Int ?? volumeStep
        lastVolume = defaults.object(forKey: "lastVolume") as? Double ?? lastVolume
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
