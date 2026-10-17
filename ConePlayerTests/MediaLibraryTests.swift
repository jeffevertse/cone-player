import Foundation
import Testing
@testable import ConePlayer

@MainActor
@Suite("Library folders")
struct MediaLibraryTests {
    let storage = TemporaryDefaults()

    /// A real folder with a video in a subfolder and an audio file at the top.
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "LibraryTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appending(path: "Clips"), withIntermediateDirectories: true)
        try Data().write(to: folder.appending(path: "Clips/clip.mp4"))
        try Data().write(to: folder.appending(path: "song.mp3"))
        try Data().write(to: folder.appending(path: "notes.txt"))
        return folder
    }

    @Test func addedFolderIsScannedUnderItsName() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = MediaLibrary(defaults: storage.defaults)
        library.addFolder(folder)
        await library.scan()

        let name = folder.lastPathComponent
        let clip = try #require(library.videos.first { $0.fileName == "clip.mp4" && $0.folderPath.first == name })
        #expect(clip.folderPath == [name, "Clips"])
        let song = try #require(library.music.first { $0.fileName == "song.mp3" && $0.folderPath.first == name })
        #expect(song.folderPath == [name])
        #expect(!library.videos.contains { $0.fileName == "notes.txt" })
    }

    @Test func foldersPersistAndCanBeRemoved() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = MediaLibrary(defaults: storage.defaults)
        library.addFolder(folder)
        library.addFolder(folder)
        #expect(library.customFolders.count == 1)

        let reopened = MediaLibrary(defaults: storage.defaults)
        let saved = try #require(reopened.customFolders.first)
        #expect(MediaLibrary.name(of: saved) == folder.lastPathComponent)

        reopened.removeFolder(saved)
        #expect(MediaLibrary(defaults: storage.defaults).customFolders.isEmpty)
    }

    @Test func inFolderPrefixesThePath() throws {
        let item = try #require(MediaItem(url: testFileURL("a.mp4", folder: "Root/Sub"), root: URL(fileURLWithPath: "/tmp/ConePlayerTests/Root")))
        #expect(item.inFolder("External").folderPath == ["External", "Sub"])
        #expect(item.inFolder("External") == item)
    }
}
