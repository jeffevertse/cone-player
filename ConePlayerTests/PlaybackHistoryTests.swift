import Foundation
import Testing
@testable import ConePlayer

@MainActor
@Suite("Playback history and resume")
struct PlaybackHistoryTests {
    let storage = TemporaryDefaults()

    private func item(_ name: String = "film.mp4") throws -> MediaItem {
        try #require(MediaItem(url: testFileURL(name)))
    }

    @Test func noResumeForNewOrBarelyStartedFiles() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let film = try item()
        #expect(history.resumePoint(for: film) == nil)
        history.record(film, seconds: 8, progress: 0.01)
        #expect(history.resumePoint(for: film) == nil)
    }

    @Test func offersResumeForPartWatchedFiles() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let film = try item()
        history.record(film, seconds: 125, progress: 0.4)
        #expect(history.resumePoint(for: film) == .seconds(125))
    }

    @Test func nearlyFinishedCountsAsWatched() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let film = try item()
        history.record(film, seconds: 950, progress: 0.96)
        #expect(history.entry(for: film)?.isFinished == true)
        #expect(history.resumePoint(for: film) == nil)
    }

    @Test func markFinishedFillsProgress() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let film = try item()
        history.record(film, seconds: 30, progress: 0.3)
        history.markFinished(film)
        let entry = try #require(history.entry(for: film))
        #expect(entry.isFinished)
        #expect(entry.progress == 1)
    }

    @Test func progressIsClamped() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let film = try item()
        history.record(film, seconds: 10, progress: 1.7)
        #expect(history.entry(for: film)?.progress == 1)
    }

    @Test func persistsAcrossLaunches() throws {
        let film = try item()
        PlaybackHistory(defaults: storage.defaults).record(film, seconds: 60, progress: 0.5)
        let reopened = PlaybackHistory(defaults: storage.defaults)
        #expect(reopened.resumePoint(for: film) == .seconds(60))
    }

    @Test func recentIsNewestFirst() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let first = try item("first.mp4"), second = try item("second.mp4")
        history.record(first, seconds: 20, progress: 0.2)
        history.record(second, seconds: 20, progress: 0.2)
        #expect(history.recentItems.map(\.fileName) == ["second.mp4", "first.mp4"])
        history.record(first, seconds: 25, progress: 0.25)
        #expect(history.recentItems.first?.fileName == "first.mp4")
    }

    @Test func streamsAreRememberedWhenOpened() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let stream = MediaItem(streamURL: try #require(URL(string: "https://example.com/live-\(UUID()).m3u8")))
        history.touch(stream)
        #expect(history.recentItems.contains(stream))
        #expect(history.resumePoint(for: stream) == nil)
    }

    @Test func removeAndClear() throws {
        let history = PlaybackHistory(defaults: storage.defaults)
        let a = try item("a.mp4"), b = try item("b.mp4")
        history.record(a, seconds: 20, progress: 0.2)
        history.record(b, seconds: 20, progress: 0.2)
        history.remove(a)
        #expect(history.entry(for: a) == nil)
        #expect(history.entry(for: b) != nil)
        history.clear()
        #expect(history.recentItems.isEmpty)
        #expect(PlaybackHistory(defaults: storage.defaults).recentItems.isEmpty)
    }
}
