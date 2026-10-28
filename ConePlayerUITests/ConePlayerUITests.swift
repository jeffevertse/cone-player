import XCTest

/// Clicks through the app the way a person would. The app is launched with
/// `-UITesting`, so it starts from empty preferences and doesn't scan Movies/Music.
final class ConePlayerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "YES", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    func testStartsOnHomeWithWelcome() {
        XCTAssertTrue(element("home.welcome").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open File…"].exists)
        XCTAssertTrue(app.buttons["Open Network Stream…"].exists)
    }

    @MainActor
    func testSidebarSwitchesSections() {
        XCTAssertTrue(element("home.welcome").waitForExistence(timeout: 10))
        for section in ["Videos", "Music", "Recent", "Playlists"] {
            element("sidebar.\(section)").click()
            let breadcrumb = element("breadcrumb.current")
            XCTAssertTrue(breadcrumb.waitForExistence(timeout: 5), "No breadcrumb for \(section)")
            XCTAssertEqual(breadcrumb.label, section)
        }
    }

    @MainActor
    func testCreatePlaylist() {
        element("sidebar.Playlists").click()
        element("playlists.create").click()

        let field = element("playlistName.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("UI Test Mix")
        element("playlistName.confirm").click()

        let playlist = element("playlist.UI Test Mix")
        XCTAssertTrue(playlist.waitForExistence(timeout: 5))
        playlist.click()
        XCTAssertEqual(element("breadcrumb.current").label, "UI Test Mix")
    }

    @MainActor
    func testNetworkStreamRejectsBadAddress() {
        XCTAssertTrue(element("home.welcome").waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)

        let field = element("stream.url")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("not a url\r")
        XCTAssertTrue(element("stream.problem").waitForExistence(timeout: 3))

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(field.waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsOpensAndSwitchesPanes() {
        XCTAssertTrue(element("home.welcome").waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)

        let title = element("settings.title")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        for (pane, expected) in [("Audio", "Audio Defaults"), ("Video", "Video Defaults"), ("Controls", "Keyboard Shortcuts")] {
            element("settings.\(pane)").click()
            // A SwiftUI Text exposes its string as the accessibility value.
            XCTAssertEqual(title.value as? String ?? title.label, expected)
        }

        element("settings.Audio").click()
        XCTAssertTrue(element("settings.volume.follows").waitForExistence(timeout: 3), "Volume section missing in Audio")

        // Updates has its own pane; the updater is off in UI tests.
        element("settings.Updates").click()
        XCTAssertEqual(title.value as? String ?? title.label, "Updates")
        XCTAssertTrue(element("settings.updates.off").waitForExistence(timeout: 3), "Updates pane missing")
    }
}
