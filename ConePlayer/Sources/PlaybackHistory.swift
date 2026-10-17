import Foundation
import Observation

/// Remembers how far each file was played, so playback can resume and the
/// library can show progress. Saved in UserDefaults, keyed by file path.
@MainActor
@Observable
final class PlaybackHistory {
    struct Entry: Codable, Equatable {
        /// Seconds into the file.
        var seconds: Double
        /// 0…1 of the file's length.
        var progress: Double
        var isFinished: Bool
        var lastPlayed: Date
        /// Lets files outside Movies/Music reopen from Recent after a relaunch.
        var reference: FileReference?
    }

    private(set) var entries: [String: Entry] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "playbackHistory"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
    }

    func entry(for item: MediaItem) -> Entry? {
        entries[item.key]
    }

    /// Where to offer resuming, or nil if the file is new, barely started or finished.
    func resumePoint(for item: MediaItem) -> Duration? {
        guard let entry = entry(for: item), !entry.isFinished, entry.seconds >= 10, entry.progress < 0.95 else {
            return nil
        }
        return .seconds(entry.seconds)
    }

    func record(_ item: MediaItem, seconds: Double, progress: Double) {
        entries[item.key] = Entry(
            seconds: seconds,
            progress: min(max(progress, 0), 1),
            isFinished: progress >= 0.95,
            lastPlayed: .now,
            reference: reference(for: item)
        )
        save()
    }

    func markFinished(_ item: MediaItem) {
        let seconds = entries[item.key]?.seconds ?? 0
        entries[item.key] = Entry(
            seconds: seconds, progress: 1, isFinished: true, lastPlayed: .now, reference: reference(for: item)
        )
        save()
    }

    /// Marks an item as just opened. Used for streams, which may be live (no length)
    /// and so never get a progress entry.
    func touch(_ item: MediaItem) {
        var entry = entries[item.key] ?? Entry(seconds: 0, progress: 0, isFinished: false, lastPlayed: .now, reference: nil)
        entry.lastPlayed = .now
        entry.reference = entry.reference ?? FileReference(url: item.url)
        entries[item.key] = entry
        save()
    }

    /// Played files, most recent first.
    var recentItems: [MediaItem] {
        entries
            .sorted { $0.value.lastPlayed > $1.value.lastPlayed }
            .compactMap { path, entry in
                FileReferenceResolver.shared.item(for: entry.reference ?? FileReference(path: path))
            }
    }

    func remove(_ item: MediaItem) {
        entries[item.key] = nil
        save()
    }

    func clear() {
        entries = [:]
        save()
    }

    /// Keeps an existing bookmark; creates one while the file is playing (and so readable)
    /// if there isn't one yet.
    private func reference(for item: MediaItem) -> FileReference {
        if let existing = entries[item.key]?.reference, existing.bookmark != nil {
            return existing
        }
        return FileReference(url: item.url)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
