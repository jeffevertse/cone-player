import Foundation
import Observation
import Sparkle

/// In-app updates with Sparkle. The feed is set in Info.plist (`SUFeedURL`, signed with
/// `SUPublicEDKey`); Sparkle checks daily and asks before installing.
@MainActor
@Observable
final class UpdateController {
    /// False while a check is already running (or when updates are off, e.g. in tests).
    private(set) var canCheckForUpdates = false
    private(set) var lastUpdateCheckDate: Date?
    private(set) var isAvailable: Bool

    /// Sparkle's own "check automatically" setting, which it stores itself.
    var automaticallyChecksForUpdates: Bool {
        get { checksAutomatically }
        set {
            controller?.updater.automaticallyChecksForUpdates = newValue
            checksAutomatically = newValue
        }
    }
    private var checksAutomatically = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    /// Updates stay off in UI tests and unit tests, so tests never contact the feed.
    init(enabled: Bool = !UITesting.isEnabled && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil) {
        isAvailable = enabled
        guard enabled else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        let updater = controller.updater
        checksAutomatically = updater.automaticallyChecksForUpdates

        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                let value = updater.canCheckForUpdates
                Task { @MainActor in self?.canCheckForUpdates = value }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
                let value = updater.lastUpdateCheckDate
                Task { @MainActor in self?.lastUpdateCheckDate = value }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.new]) { [weak self] updater, _ in
                let value = updater.automaticallyChecksForUpdates
                Task { @MainActor in self?.checksAutomatically = value }
            },
        ]
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// "0.2.0 (6)".
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
