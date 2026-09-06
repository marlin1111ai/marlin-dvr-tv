//
//  PlayRequest.swift
//  Marlin DVR TV
//
//  What a screen asks the Player to play (sweep 3 entry points, DECISIONS.md 2026-09-06):
//  a live channel from On Now, the Guide or the airing sheet; a recording from show
//  detail; a camera from the Cameras grid. Carries what the overlays of frames 6a–6h show.
//

import Foundation

enum PlayRequest: Identifiable {
    case live(channel: MergedChannel, program: Program?)
    case recording(episode: Episode, show: ShowResponse?, start: Double)
    case camera(Camera)

    var id: String {
        switch self {
        case .live(let channel, _): return "live:\(channel.id)"
        case .recording(let episode, _, let start): return "recording:\(episode.id)@\(Int(start))"
        case .camera(let camera): return "camera:\(camera.id)"
        }
    }

    /// The `kind` of POST /api/play/sessions (contract §2).
    var kind: String {
        switch self {
        case .live: return "live"
        case .recording: return "recording"
        case .camera: return "camera"
        }
    }

    /// The `id` of POST /api/play/sessions (contract §2.1).
    var targetID: String {
        switch self {
        case .live(let channel, _): return channel.id
        case .recording(let episode, _, _): return episode.id
        case .camera(let camera): return camera.id
        }
    }

    /// The `start` for a recording (contract §3); live and camera ignore it.
    var startSeconds: Double {
        if case .recording(_, _, let start) = self { return start }
        return 0
    }

    /// Frame 6a/6b title: "ch13.1 WJZ", the show, or the camera name.
    var title: String {
        switch self {
        case .live(let channel, _): return "ch\(channel.number) \(channel.name)"
        case .recording(let episode, _, _): return episode.show
        case .camera(let camera): return camera.name
        }
    }

    /// Frame 6a/6c subtitle: "Days of Our Lives · until 3:04 PM", "S9 E11 · A House with Good Bones · HGTV", the camera address.
    var subtitle: String {
        switch self {
        case .live(_, let program):
            guard let program else { return "" }
            return "\(program.title) · until \(TimeFormat.clock(unix: program.end))"
        case .recording(let episode, _, _):
            var parts: [String] = []
            if episode.season > 0 || episode.episode > 0 { parts.append("S\(episode.season) E\(episode.episode)") }
            if !episode.episodeTitle.isEmpty { parts.append(episode.episodeTitle) }
            if !episode.channel.isEmpty { parts.append(episode.channel) }
            return parts.joined(separator: " · ")
        case .camera(let camera):
            return camera.address
        }
    }

    /// The channel's initials tile for 6a (live), else nil.
    var channel: MergedChannel? {
        if case .live(let channel, _) = self { return channel }
        return nil
    }

    var episode: Episode? {
        if case .recording(let episode, _, _) = self { return episode }
        return nil
    }

    /// The next-newer episode in the same show (the show's list is newest first, library.go:586-640).
    var nextEpisode: Episode? {
        guard case .recording(let episode, let show, _) = self, let show,
              let index = show.episodes.firstIndex(where: { $0.id == episode.id }), index > 0 else { return nil }
        return show.episodes[index - 1]
    }

    /// The same request pointing at another episode of the show.
    func replacing(episode: Episode, start: Double) -> PlayRequest {
        if case .recording(_, let show, _) = self { return .recording(episode: episode, show: show, start: start) }
        return self
    }

    /// The same request with another start offset (seek by new session, contract §3).
    func withStart(_ start: Double) -> PlayRequest {
        if case .recording(let episode, let show, _) = self { return .recording(episode: episode, show: show, start: start) }
        return self
    }
}
