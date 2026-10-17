import Foundation
import Testing
@testable import ConePlayer

@MainActor
@Suite("Playlists")
struct PlaylistStoreTests {
    let storage = TemporaryDefaults()

    private func items(_ names: String...) throws -> [MediaItem] {
        let folder = UUID().uuidString
        return try names.map { try #require(MediaItem(url: testFileURL($0, folder: folder))) }
    }

    @Test func blankNamesBecomeUntitled() {
        let store = PlaylistStore(defaults: storage.defaults)
        #expect(store.create(named: "   ").name == "Untitled Playlist")
        #expect(store.create(named: "  Road Trip \n").name == "Road Trip")
    }

    @Test func addKeepsOrderAndSkipsDuplicates() throws {
        let store = PlaylistStore(defaults: storage.defaults)
        let files = try items("one.mp4", "two.mp4", "three.mp4")
        let playlist = store.create(named: "Mix", with: [files[0]])
        store.add([files[1], files[0], files[2]], to: playlist.id)
        #expect(store.items(in: playlist.id).map(\.fileName) == ["one.mp4", "two.mp4", "three.mp4"])
    }

    @Test func removeRenameDelete() throws {
        let store = PlaylistStore(defaults: storage.defaults)
        let files = try items("a.mp4", "b.mp4")
        let playlist = store.create(named: "Temp", with: files)
        store.remove(files[0], from: playlist.id)
        #expect(store.items(in: playlist.id) == [files[1]])
        store.rename(playlist.id, to: "Kept")
        #expect(store.playlist(playlist.id)?.name == "Kept")
        store.delete(playlist.id)
        #expect(store.playlist(playlist.id) == nil)
    }

    @Test func persistsAcrossLaunches() throws {
        let files = try items("x.mp4")
        let id = PlaylistStore(defaults: storage.defaults).create(named: "Saved", with: files).id
        let reopened = PlaylistStore(defaults: storage.defaults)
        #expect(reopened.playlist(id)?.name == "Saved")
        #expect(reopened.items(in: id) == files)
    }

    @Test func streamsCanBeInPlaylists() throws {
        let store = PlaylistStore(defaults: storage.defaults)
        let stream = MediaItem(streamURL: try #require(URL(string: "https://example.com/\(UUID()).m3u8")))
        let playlist = store.create(named: "Radio", with: [stream])
        #expect(store.items(in: playlist.id) == [stream])
    }
}
