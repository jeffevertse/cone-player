import Foundation
import Testing
@testable import ConePlayer

@MainActor
@Suite("Settings")
struct SettingsStoreTests {
    let storage = TemporaryDefaults()

    @Test func defaults() {
        let settings = SettingsStore(defaults: storage.defaults)
        #expect(settings.resumeMode == .ask)
        #expect(settings.playbackRate == 1)
        #expect(settings.jumpInterval == 10)
        #expect(settings.autoPlayNext)
        #expect(settings.appearance == .dark)
        #expect(settings.startScreen == .home)
        #expect(settings.equalizerBands.count == Equalizer.bandCount)
        #expect(!settings.isEqualizerEnabled)
    }

    @Test func persistsChanges() {
        let settings = SettingsStore(defaults: storage.defaults)
        settings.resumeMode = .always
        settings.playbackRate = 1.5
        settings.jumpInterval = 30
        settings.subtitleScale = 1.25
        settings.preferredAudioLanguage = "nl"
        settings.startScreen = .recent
        settings.libraryLayout = .list
        settings.networkCaching = 3000

        let reopened = SettingsStore(defaults: storage.defaults)
        #expect(reopened.resumeMode == .always)
        #expect(reopened.playbackRate == 1.5)
        #expect(reopened.jumpInterval == 30)
        #expect(reopened.subtitleScale == 1.25)
        #expect(reopened.preferredAudioLanguage == "nl")
        #expect(reopened.startScreen == .recent)
        #expect(reopened.libraryLayout == .list)
        #expect(reopened.networkCaching == 3000)
    }

    @Test func notifiesOnChangeButNotWhileLoading() {
        storage.defaults.set(2.0, forKey: "playbackRate")
        var changes = 0
        let settings = SettingsStore(defaults: storage.defaults)
        settings.onChange = { changes += 1 }
        #expect(changes == 0)
        settings.audioDelay = 100
        #expect(changes == 1)
    }

    @Test func presetLoadsVLCValuesAndManualEditLeavesIt() throws {
        let settings = SettingsStore(defaults: storage.defaults)
        let index = try #require(Equalizer.presetNames.firstIndex(of: "Dance"))
        settings.applyEqualizerPreset(index)
        #expect(settings.equalizerPreset == index)
        #expect(settings.equalizerBands.map { Int($0) } == [9, 7, 2, 0, 0, -5, -7, -7, 0, 0])

        settings.setBand(0, to: 3)
        #expect(settings.equalizerPreset == nil)
        #expect(settings.equalizerBands[0] == 3)

        settings.resetEqualizer()
        #expect(settings.equalizerBands.allSatisfy { $0 == 0 })
        #expect(settings.equalizerPreamp == 12)
    }

    @Test func resetColorAdjustments() {
        let settings = SettingsStore(defaults: storage.defaults)
        settings.brightness = 1.4
        settings.hue = 90
        settings.resetColorAdjustments()
        #expect(settings.brightness == 1)
        #expect(settings.hue == 0)
    }
}

@MainActor
@Suite("Navigation")
struct NavigationTests {
    @Test func backAndForwardThroughFolders() {
        let navigation = Navigation()
        navigation.section = .videos
        #expect(!navigation.canGoBack)

        navigation.showFolder(["Shows"])
        navigation.showFolder(["Shows", "S01"])
        #expect(navigation.folderPath == ["Shows", "S01"])

        navigation.goBack()
        #expect(navigation.folderPath == ["Shows"])
        #expect(navigation.canGoForward)

        navigation.goForward()
        #expect(navigation.folderPath == ["Shows", "S01"])
        #expect(!navigation.canGoForward)
    }

    @Test func newFolderClearsForwardHistory() {
        let navigation = Navigation()
        navigation.showFolder(["A"])
        navigation.goBack()
        navigation.showFolder(["B"])
        #expect(!navigation.canGoForward)
    }

    @Test func showingCurrentFolderIsNotHistory() {
        let navigation = Navigation()
        navigation.showFolder(["A"])
        navigation.showFolder(["A"])
        navigation.goBack()
        #expect(navigation.folderPath.isEmpty)
        #expect(!navigation.canGoBack)
    }

    @Test func switchingSectionResets() {
        let navigation = Navigation()
        navigation.showFolder(["A"])
        navigation.section = .music
        #expect(navigation.folderPath.isEmpty)
        #expect(!navigation.canGoBack)
    }
}

@Suite("Network stream addresses")
struct StreamAddressTests {
    @Test(arguments: [
        "https://example.com/video.m3u8",
        "  http://192.168.1.10:8080/stream  ",
        "rtsp://camera.local/live",
        "rtmp://live.example.com/app/key",
        "srt://example.com:9000",
        "udp://@239.0.0.1:1234",
    ])
    func accepts(_ address: String) {
        #expect(NetworkStreamSheet.streamURL(from: address) != nil)
    }

    @Test(arguments: ["", "not a url", "example.com/video.mp4", "file:///Users/me/movie.mp4", "http://", "javascript:alert(1)"])
    func rejects(_ address: String) {
        #expect(NetworkStreamSheet.streamURL(from: address) == nil)
    }
}
