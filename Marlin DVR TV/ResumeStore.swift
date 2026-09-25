//
//  ResumeStore.swift
//  Marlin DVR TV
//
//  Resume positions, kept per Apple TV (DECISIONS.md, design fact): UserDefaults, one
//  entry per recording id, saved every 10 s while playing and on dismiss, cleared when
//  watched-on-end fires. Show detail reads it for "Resume S9 E11 · 22 min in" (frame 5d).
//

import Foundation

enum ResumeStore {
    struct Entry: Codable {
        var position: Double      // seconds into the recording
        var duration: Double      // the recording's length when known (0 otherwise)
        var savedAt: Date
    }

    private static let prefix = "marlinResume."

    static func entry(for recordingID: String) -> Entry? {
        guard let data = UserDefaults.standard.data(forKey: prefix + recordingID) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    static func save(recordingID: String, position: Double, duration: Double) {
        let entry = Entry(position: max(0, position), duration: duration, savedAt: Date())
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: prefix + recordingID)
        }
    }

    static func clear(recordingID: String) {
        UserDefaults.standard.removeObject(forKey: prefix + recordingID)
    }

    /// The most recently saved entry among the given episodes — the one "Resume" offers.
    static func latest(among episodes: [Episode]) -> (episode: Episode, entry: Entry)? {
        var best: (Episode, Entry)?
        for episode in episodes {
            if let entry = entry(for: episode.id), isResumable(entry) {
                if best == nil || entry.savedAt > best!.1.savedAt { best = (episode, entry) }
            }
        }
        return best
    }

    // MARK: Reading the whole store (Pass 91)

    /// Every saved position on this Apple TV, newest first.
    ///
    /// The store has no index and never had one: it is one `UserDefaults` value per recording
    /// under the `marlinResume.` prefix, holding a position, a duration and a save time and
    /// nothing else — no title, no show, no list of the keys in use. So the only way to enumerate
    /// it is to read the standard domain's keys back and filter by that prefix. **This reads the
    /// stored format exactly as `save` writes it and adds nothing to it** (Pass 91's constraint).
    ///
    /// A key whose value will not decode is skipped rather than reported: the store is a cache of
    /// where the owner got to, and a single unreadable entry should cost him one card, not the
    /// shelf.
    static func saved() -> [(id: String, entry: Entry)] {
        let decoder = JSONDecoder()
        var out: [(id: String, entry: Entry)] = []
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() where key.hasPrefix(prefix) {
            guard let data = value as? Data, let entry = try? decoder.decode(Entry.self, from: data) else { continue }
            out.append((id: String(key.dropFirst(prefix.count)), entry: entry))
        }
        return out.sorted { $0.entry.savedAt > $1.entry.savedAt }
    }

    /// Whether an entry counts as a position worth resuming from.
    ///
    /// `latest(among:)` has used `position > 5` since Pass 7 to decide whether frame 5d draws its
    /// "Resume S9 E11 · 22 min in" line, so the same test decides whether the Recordings screen's
    /// Continue watching shelf draws a card. The two agree by construction, which is the point of
    /// naming it here rather than writing the comparison twice.
    static func isResumable(_ entry: Entry) -> Bool { entry.position > 5 }

    /// Whether this Apple TV has finished the recording.
    ///
    /// The store's own record of "finished" is the **absence** of an entry: playing a recording to
    /// its end clears it (`PlayerModel.playedToEnd`), and `saveResume` refuses to write a position
    /// inside the last three seconds. This is the second guard, for an entry left at the very end
    /// by `restart(at:)`, which saves without that test whenever playback has attached (since
    /// Pass 125 it saves nothing when nothing ever attached). It is deliberately the same
    /// three-second test `saveResume` uses.
    ///
    /// It says nothing about the server's `watched` flag, which is shared with the other Apple TV;
    /// a resume position is this Apple TV's alone (DECISIONS.md, 2026-09-05 (design); 2026-09-16
    /// (Pass 91)).
    static func isFinished(_ entry: Entry) -> Bool {
        entry.duration > 0 && entry.position >= entry.duration - 3
    }

    /// "22 min in"
    static func label(for entry: Entry) -> String {
        let minutes = Int(entry.position / 60)
        if minutes < 1 { return "\(Int(entry.position)) s in" }
        return "\(minutes) min in"
    }
}
