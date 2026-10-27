//
//  NowPlaying.swift
//  Marlin DVR TV
//
//  Pass 140 (owner, 2026-10-26): what the Player publishes to tvOS's Now Playing — the title, subtitle and
//  artwork other devices show (Home Assistant's Apple TV media player, the iPhone's remote) — the way the
//  Channels app does. The Player is Apple's `AVPlayerViewController`, which publishes the item's
//  `externalMetadata` itself, so this is the metadata, not a write to the Now Playing centre.
//
//  Text (`text(for:program:)`):
//   · live: the airing's title from the guide — "Show: Episode" when the guide has an episode title — else
//     the channel's name when the guide has nothing; the subtitle and artist are the channel, "2.1 WMAR-HD";
//     the description is the guide's.
//   · recording: the show's title, "Show: Episode" when the recording has an episode title; the subtitle and
//     artist are the channel it was recorded from, else its "S1 E2" line; the description is the library's.
//   · camera: as before — the camera's name and address.
//
//  Artwork (`artCandidates`, `artwork(from:)`), the first that answers with a JPEG or PNG:
//   · live: the airing's picture by the server's own rule for every tile (`tileArt`, artwork.go:434-459 at
//     5e6c28c) — the guide's own image through `/api/art/feed` when the airing carries one, else the
//     title's poster through `/api/art/show` — then the channel's logo; nothing when neither answers.
//   · recording: the show's poster (`ShowResponse.art`, else `/api/art/show` for its title), then the
//     recording's own thumbnail.
//  Fetched off the Player's path — the text is published first, the picture added when it arrives — and
//  kept in memory by URL, so a flip back to a channel costs no second fetch.
//

import AVFoundation
import CoreMedia
import Foundation

enum NowPlaying {
    struct Text: Equatable {
        let title: String
        let subtitle: String
        let description: String?
    }

    struct Artwork {
        let data: Data
        let dataType: String        // kCMMetadataBaseDataType_JPEG or _PNG
        let url: URL
        var kind: String { dataType == kCMMetadataBaseDataType_PNG as String ? "png" : "jpeg" }
    }

    // MARK: Text

    static func text(for request: PlayRequest, program: Program?) -> Text {
        switch request {
        case .live(let channel, _):
            let channelLine = "\(channel.number) \(channel.name)"
            guard let program else { return Text(title: channel.name, subtitle: channelLine, description: nil) }
            return Text(title: titled(program.title, episode: program.episodeTitle), subtitle: channelLine, description: nonEmpty(program.desc))
        case .recording(let episode, _, _):
            var line = episode.channel
            if line.isEmpty, episode.season > 0 || episode.episode > 0 { line = "S\(episode.season) E\(episode.episode)" }
            return Text(title: titled(episode.show, episode: episode.episodeTitle), subtitle: line, description: nonEmpty(episode.description))
        case .camera:
            return Text(title: request.title, subtitle: request.subtitle, description: nil)
        }
    }

    /// "Show: Episode", or the show alone.
    private static func titled(_ title: String, episode: String?) -> String {
        guard let episode, !episode.isEmpty, episode != title else { return title }
        return "\(title): \(episode)"
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    // MARK: The metadata items

    static func items(_ text: Text, artwork: Artwork?) -> [AVMetadataItem] {
        func item(_ identifier: AVMetadataIdentifier, _ value: NSCopying & NSObjectProtocol, dataType: String? = nil) -> AVMetadataItem {
            let m = AVMutableMetadataItem()
            m.identifier = identifier
            m.value = value
            m.dataType = dataType
            m.extendedLanguageTag = "und"
            return m
        }
        var items = [item(.commonIdentifierTitle, text.title as NSString)]
        if !text.subtitle.isEmpty {
            items.append(item(.iTunesMetadataTrackSubTitle, text.subtitle as NSString))
            items.append(item(.commonIdentifierArtist, text.subtitle as NSString))
        }
        if let description = text.description {
            items.append(item(.commonIdentifierDescription, description as NSString))
        }
        if let artwork {
            items.append(item(.commonIdentifierArtwork, artwork.data as NSData, dataType: artwork.dataType))
        }
        return items
    }

    // MARK: Artwork

    /// The pictures to try, in order. Server-relative paths and the provider's absolute logo URL alike
    /// resolve through `ServerConfig.resolve`.
    static func artCandidates(for request: PlayRequest, program: Program?) -> [URL] {
        var paths: [String] = []
        switch request {
        case .live(let channel, _):
            if let program { paths.append(airingArtPath(program)) }
            paths.append(channel.logo)
        case .recording(let episode, let show, _):
            if let art = show?.art, !art.isEmpty {
                paths.append(art)
            } else {
                paths.append(showArtPath(title: episode.show))
            }
            paths.append(episode.thumb)
        case .camera:
            break
        }
        return paths.compactMap { ServerConfig.resolve($0) }
    }

    /// The server's `tileArt` rule, built here because the Player is handed the airing, not the tile's
    /// `art` string: the guide's own image through the feed proxy (which itself falls back to the title's
    /// poster when the feed URL is dead), else the title's poster.
    static func airingArtPath(_ program: Program) -> String {
        if let icon = program.icon, icon.hasPrefix("http://") || icon.hasPrefix("https://") {
            var components = URLComponents()
            components.path = "/api/art/feed"
            components.setServerQueryItems([URLQueryItem(name: "u", value: icon), URLQueryItem(name: "title", value: program.title)])
            return components.string ?? ""
        }
        return showArtPath(title: program.title)
    }

    static func showArtPath(title: String) -> String {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        var components = URLComponents()
        components.path = "/api/art/show"
        components.setServerQueryItems([URLQueryItem(name: "title", value: title)])
        return components.string ?? ""
    }

    private final class Cached {
        let artwork: Artwork
        init(_ artwork: Artwork) { self.artwork = artwork }
    }

    private static let cache = NSCache<NSURL, Cached>()

    /// The first candidate that answers 200 with a JPEG or PNG; nil when none does. Each answer is kept by
    /// URL; a miss is not, so a poster the server has yet to fetch is tried again next time.
    static func artwork(from candidates: [URL]) async -> Artwork? {
        for url in candidates {
            if let hit = cache.object(forKey: url as NSURL) { return hit.artwork }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200, let dataType = imageDataType(data) else {
                    print("[nowplaying] \(url.path): \(status == 200 ? "not a JPEG or PNG" : "status \(status)") — trying the next picture")
                    continue
                }
                let artwork = Artwork(data: data, dataType: dataType, url: url)
                cache.setObject(Cached(artwork), forKey: url as NSURL)
                return artwork
            } catch {
                print("[nowplaying] \(url.path): \(error.localizedDescription) — trying the next picture")
            }
        }
        return nil
    }

    /// JPEG (FF D8 FF) or PNG (89 50 4E 47) by the first bytes; anything else is not published.
    static func imageDataType(_ data: Data) -> String? {
        guard data.count > 8 else { return nil }
        let head = [UInt8](data.prefix(4))
        if head[0] == 0xFF, head[1] == 0xD8, head[2] == 0xFF { return kCMMetadataBaseDataType_JPEG as String }
        if head == [0x89, 0x50, 0x4E, 0x47] { return kCMMetadataBaseDataType_PNG as String }
        return nil
    }
}
