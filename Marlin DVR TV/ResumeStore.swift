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
            if let entry = entry(for: episode.id), entry.position > 5 {
                if best == nil || entry.savedAt > best!.1.savedAt { best = (episode, entry) }
            }
        }
        return best
    }

    /// "22 min in"
    static func label(for entry: Entry) -> String {
        let minutes = Int(entry.position / 60)
        if minutes < 1 { return "\(Int(entry.position)) s in" }
        return "\(minutes) min in"
    }
}
