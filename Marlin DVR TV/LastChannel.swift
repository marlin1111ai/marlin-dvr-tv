//
//  LastChannel.swift
//  Marlin DVR TV
//
//  Pass 138 (owner, 2026-10-26 — REA report §5.2 item 3, the Channels app's play-pause-or-last-channel,
//  on this remote): the live channel this Apple TV is watching and the one it watched before it, so that
//  a quick double-click on the clickpad centre while live switches back (`PlayerScreen`'s
//  `flipToPreviousChannel`, caught in `PlayerContainerController.pressesBegan`).
//
//  Kept per Apple TV in UserDefaults, as resume positions are, so it survives quitting the app (owner's
//  A1). Only the channel's id and its source id are kept — with its number and name for the console — and
//  the channel itself is read fresh from the server at the flip, so a channel renamed, hidden or removed
//  since is seen as the server has it now.
//
//  A channel is recorded when its Player reaches the playing state — the session created and the stream
//  attached — so a tune that fails never becomes "previous". Playing the channel that is already current
//  changes nothing; any other live channel pushes the current one to "previous". A flip is simply playing
//  the previous channel, so the same rule swaps the two, and a second double-click goes back again.
//

import Foundation

enum LastChannel {
    struct Entry: Codable, Equatable {
        let id: String
        let sourceId: String
        let number: String
        let name: String

        var label: String { "\(number) \(name)" }
    }

    private static let currentKey = "marlinLastChannel.current"
    private static let previousKey = "marlinLastChannel.previous"

    static var current: Entry? { read(currentKey) }
    static var previous: Entry? { read(previousKey) }

    /// A live channel has reached the playing state.
    static func played(_ channel: MergedChannel) {
        let entry = Entry(id: channel.id, sourceId: channel.sourceId, number: channel.number, name: channel.name)
        let was = current
        guard was?.id != entry.id else { return }
        if let was { write(was, previousKey) }
        write(entry, currentKey)
        print("[lastchannel] now \(entry.label); previous \((was ?? previous)?.label ?? "none")")
    }

    /// The previous channel as the server has it now, and what is on it: one `GET /api/guide/now` for its
    /// source (owner's B1). That route lists a channel only while a programme is airing on it
    /// (`guide.go:763-787` at `674a7a7`), so when it does not list this one, one `GET /api/channels` for the
    /// source gives the channel with no programme — the way Favorites starts a favourite with no listing
    /// (`FavoritesScreen.swift:129`). Nil, said so on the console, when neither lists it (hidden, removed, or DRM — both
    /// reads drop DRM channels) or a read fails; the channel that is playing then carries on.
    static func resolve(_ entry: Entry, api: APIClient) async -> (channel: MergedChannel, program: Program?)? {
        do {
            if let item = try await api.onNow(source: entry.sourceId).first(where: { $0.channel.id == entry.id }) {
                return (item.channel, item.program)
            }
            if let channel = try await api.channels(source: entry.sourceId).first(where: { $0.id == entry.id }) {
                print("[lastchannel] \(entry.label) has nothing airing in the guide — starting it with no programme")
                return (channel, nil)
            }
            print("[lastchannel] \(entry.label) is no longer a playable channel on the server — no flip")
            return nil
        } catch {
            print("[lastchannel] could not read \(entry.label) from the server — no flip: \(error)")
            return nil
        }
    }

    private static func read(_ key: String) -> Entry? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    private static func write(_ entry: Entry, _ key: String) {
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
