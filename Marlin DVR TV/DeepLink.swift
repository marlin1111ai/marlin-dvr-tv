//
//  DeepLink.swift
//  Marlin DVR TV
//
//  Pass 139 (owner, 2026-10-26): the `marlindvr://` links Home Assistant opens on this Apple TV through its
//  Apple TV integration — `media_player.play_media` with content type `app` or `url` hands the link to tvOS
//  as a URL to open (`apple_tv/media_player.py`, home-assistant/core). The Channels app's own local endpoints
//  (`/api/play/channel/{n}`, `/api/navigate/{section}`, `/api/notify`; REA report §2.6, §4 item 15), as URLs.
//
//  Four shapes, nothing else:
//    marlindvr://<section>              one of the twelve sidebar sections (`Destination.rawValue`; case,
//                                       hyphens and underscores ignored); `home` is the Home grid.
//    marlindvr://live/<channel>         the channel's number as the Guide prints it ("7.1"), or its id
//                                       ("<source>:<guid>") — owner's A-a. Started the way an On Now card
//                                       starts it: with what is on it from GET /api/guide/now when that lists
//                                       the channel, else from GET /api/channels with no programme.
//    marlindvr://recording/<id>         a recording's id (twelve hex characters), looked up in the pages of
//                                       GET /api/library/recordings; plays from its saved position, as Show
//                                       Detail does on a plain click.
//    marlindvr://notify?text=<message>  `NotifyBanner` for five seconds; nothing else moves.
//
//  A play link while the Player is up swaps its content in place, the way the Pass 138 flip does
//  (`DeepLinkRouter.PlayerCommand.play`); a section link closes the Player first (owner's B-a). Whatever fails —
//  an unknown section, a channel or recording the server does not have, a read that fails, a link with no
//  text — is said on the banner over whatever is on screen, and nothing else changes (owner's C-a).
//

import Foundation
import Observation

enum DeepLink: Equatable {
    case section(Destination?)      // nil is Home
    case live(String)               // the channel number or id, as written
    case recording(String)
    case notify(String)

    /// What the banner says when a link cannot be followed.
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static let scheme = "marlindvr"

    /// One of the four shapes, or a `Failure` with the banner's wording.
    static func parse(_ url: URL) throws -> DeepLink {
        guard url.scheme?.lowercased() == scheme else {
            throw Failure(description: "Not a Marlin TV link: \(url.absoluteString)")
        }
        let host = (url.host ?? "").lowercased()
        // "/7.1" → "7.1"; "/hdhr:1234" → "hdhr:1234" (percent escapes already undone).
        let rest = url.pathComponents.filter { $0 != "/" }.joined(separator: "/")
        switch host {
        case "":
            throw Failure(description: "Marlin TV link has no section: \(url.absoluteString)")
        case "live":
            guard !rest.isEmpty else { throw Failure(description: "Live link has no channel: \(url.absoluteString)") }
            return .live(rest)
        case "recording":
            guard !rest.isEmpty else { throw Failure(description: "Recording link has no id: \(url.absoluteString)") }
            return .recording(rest)
        case "notify":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let text = (items.first { $0.name == "text" }?.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw Failure(description: "Notify link has no text: \(url.absoluteString)") }
            return .notify(text)
        default:
            guard rest.isEmpty, let destination = Self.section(named: host) else {
                throw Failure(description: "Unknown Marlin TV section “\(host)”")
            }
            return .section(destination == .home ? nil : destination)
        }
    }

    /// "onnow", "on-now", "On_Now" → `.onNow`.
    private static func section(named name: String) -> Destination? {
        func fold(_ s: String) -> String { s.lowercased().filter { $0 != "-" && $0 != "_" } }
        return Destination.allCases.first { fold($0.rawValue) == fold(name) }
    }

    // MARK: Resolving a play link against the server

    /// The request for a `.live` or `.recording` link, read fresh from the server; a `Failure` otherwise.
    func resolvePlay(api: APIClient) async throws -> PlayRequest {
        switch self {
        case .live(let key): return try await Self.resolveLive(key, api: api)
        case .recording(let id): return try await Self.resolveRecording(id, api: api)
        case .section, .notify: preconditionFailure("not a play link")
        }
    }

    /// Owner's A-a: the number as the Guide prints it, else the id. GET /api/guide/now lists a channel only while a
    /// programme airs on it (`LastChannel.resolve`), so when it does not, GET /api/channels gives the channel with
    /// no programme — the way Favorites starts a favourite with no listing. Both reads drop DRM channels.
    private static func resolveLive(_ key: String, api: APIClient) async throws -> PlayRequest {
        func matches(_ channel: MergedChannel) -> Bool { channel.number == key || channel.id == key }
        do {
            if let item = try await api.onNow().first(where: { matches($0.channel) }) {
                return .live(channel: item.channel, program: item.program)
            }
            if let channel = try await api.channels().first(where: matches) {
                print("[deeplink] channel \(key) has nothing airing in the guide — starting it with no programme")
                return .live(channel: channel, program: nil)
            }
        } catch {
            throw Failure(description: "Could not read channel \(key) from the server: \(error)")
        }
        throw Failure(description: "No channel \(key) on this server")
    }

    /// The recording's row from the pages of GET /api/library/recordings (500 a page; trashed recordings are not
    /// listed), then its show for the Player's next-episode card, and the saved position as Show Detail passes it.
    private static func resolveRecording(_ id: String, api: APIClient) async throws -> PlayRequest {
        var found: Episode?
        var offset = 0
        do {
            while found == nil {
                let page = try await api.recordings(offset: offset, limit: 500)
                found = page.items.first { $0.id == id }
                offset += page.items.count
                if page.items.isEmpty || offset >= page.total { break }
            }
            guard let episode = found else { throw Failure(description: "No recording \(id) on this server") }
            let show = try await api.show(id: episode.showId)
            let start = ResumeStore.entry(for: id)?.position ?? 0
            return .recording(episode: show.episodes.first { $0.id == id } ?? episode, show: show, start: start)
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure(description: "Could not read recording \(id) from the server: \(error)")
        }
    }
}

/// Pass 139: what a deep link asks of a Player that is already up. `ContentView` sends; `PlayerScreen` takes.
/// `serial` is what the Player watches — the same command twice is still two commands.
@Observable @MainActor
final class DeepLinkRouter {
    enum PlayerCommand {
        case play(PlayRequest)      // swap the Player's content in place
        case close                  // stop and dismiss — a section link arrived (owner's B-a)
    }

    private(set) var serial = 0
    private var command: PlayerCommand?

    func send(_ command: PlayerCommand) {
        self.command = command
        serial += 1
    }

    func take() -> PlayerCommand? {
        defer { command = nil }
        return command
    }
}
