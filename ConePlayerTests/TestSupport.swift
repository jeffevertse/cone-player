import Foundation

/// A throwaway UserDefaults suite, so tests never touch the app's real preferences.
final class TemporaryDefaults {
    let suiteName = "ConePlayerTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

/// A unique file URL that doesn't need to exist.
func testFileURL(_ name: String, folder: String = UUID().uuidString) -> URL {
    URL(fileURLWithPath: "/tmp/ConePlayerTests/\(folder)/\(name)")
}
