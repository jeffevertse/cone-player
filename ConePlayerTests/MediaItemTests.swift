import Foundation
import Testing
@testable import ConePlayer

@Suite("Media items")
struct MediaItemTests {
    @Test func detectsVideoAndAudio() throws {
        #expect(try #require(MediaItem(url: testFileURL("movie.mp4"))).kind == .video)
        #expect(try #require(MediaItem(url: testFileURL("Movie.MKV"))).kind == .video)
        #expect(try #require(MediaItem(url: testFileURL("song.flac"))).kind == .audio)
    }

    @Test func rejectsNonMediaFiles() {
        #expect(MediaItem(url: testFileURL("notes.txt")) == nil)
        #expect(MediaItem(url: testFileURL("README")) == nil)
    }

    @Test func folderPathIsRelativeToLibraryRoot() throws {
        let root = URL(fileURLWithPath: "/tmp/ConePlayerTests/Movies")
        let file = root.appending(path: "Shows/The Wand/S01/episode.mp4")
        let item = try #require(MediaItem(url: file, root: root))
        #expect(item.folderPath == ["Shows", "The Wand", "S01"])
        #expect(try #require(MediaItem(url: root.appending(path: "top.mp4"), root: root)).folderPath.isEmpty)
    }

    @Test func streamsAreKeyedByFullURL() throws {
        let url = try #require(URL(string: "https://example.com/live/stream.m3u8?token=1"))
        let item = MediaItem(streamURL: url)
        #expect(item.isStream)
        #expect(item.key == url.absoluteString)
        #expect(item.title == "stream")
        #expect(item.folderName == "example.com")
    }

    @Test func streamWithoutPathIsTitledByHost() throws {
        let item = MediaItem(streamURL: try #require(URL(string: "rtsp://camera.local")))
        #expect(item.title == "camera.local")
    }

    @Test func nonFileURLsBecomeStreams() throws {
        let url = try #require(URL(string: "http://example.com/a.mp4"))
        let item = try #require(MediaItem(url: url))
        #expect(item.isStream)
    }

    @Test func sameFileIsEqualWhateverItsRoot() throws {
        let file = testFileURL("same.mp4", folder: "Movies/Sub")
        let fromLibrary = try #require(MediaItem(url: file, root: URL(fileURLWithPath: "/tmp/ConePlayerTests/Movies")))
        let opened = try #require(MediaItem(url: file))
        #expect(fromLibrary == opened)
        #expect(Set([fromLibrary, opened]).count == 1)
    }
}

@Suite("Formatting")
struct FormattingTests {
    @Test(arguments: [
        (Duration.zero, "00:00:00"),
        (.seconds(59), "00:00:59"),
        (.seconds(3725), "01:02:05"),
        (.seconds(-5), "00:00:00"),
    ])
    func clockString(_ duration: Duration, _ expected: String) {
        #expect(duration.clockString == expected)
    }

    @Test(arguments: [
        (Float(60), "60 Hz"),
        (Float(1000), "1 KHz"),
        (Float(16000), "16 KHz"),
    ])
    func equalizerLabels(_ frequency: Float, _ expected: String) {
        #expect(Equalizer.label(for: frequency) == expected)
    }

    @Test func searchIgnoresCaseAccentsAndSeparators() {
        let file = LibraryScreen.searchKey("Sync-Test_Café.mp4")
        #expect(file.contains(LibraryScreen.searchKey("sync test")))
        #expect(file.contains(LibraryScreen.searchKey("CAFE")))
        #expect(!file.contains(LibraryScreen.searchKey("sunflower")))
    }
}

@Suite("File references")
struct FileReferenceTests {
    @Test func streamReferenceRoundTrips() throws {
        let url = try #require(URL(string: "rtmp://example.com/live/key"))
        let reference = FileReference(url: url)
        #expect(reference.bookmark == nil)
        #expect(reference.resolve() == url)
    }

    @Test func pathOnlyReferenceResolvesToFileURL() {
        let reference = FileReference(path: "/tmp/ConePlayerTests/x.mp4")
        #expect(reference.resolve() == URL(fileURLWithPath: "/tmp/ConePlayerTests/x.mp4"))
    }

    @Test func survivesEncoding() throws {
        let reference = FileReference(path: "/tmp/ConePlayerTests/y.mkv")
        let decoded = try JSONDecoder().decode(FileReference.self, from: JSONEncoder().encode(reference))
        #expect(decoded == reference)
    }
}
