import Foundation
import Testing
@testable import ConePlayer

@Suite("In-app updates")
struct UpdateSettingsTests {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    @Test func feedIsHTTPSOnThePublicReleasesSite() throws {
        let feed = try #require(info["SUFeedURL"] as? String)
        let url = try #require(URL(string: feed))
        #expect(url.scheme == "https")
        #expect(url.host() == "jeffevertse.github.io")
        #expect(url.lastPathComponent == "appcast.xml")
    }

    @Test func updatesAreSignedAndAskFirst() throws {
        let key = try #require(info["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: key)?.count == 32)
        #expect(info["SUAutomaticallyUpdate"] as? Bool == false)
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true)
    }

    @Test @MainActor func updaterIsOffInTests() {
        #expect(!UpdateController().isAvailable)
    }
}
