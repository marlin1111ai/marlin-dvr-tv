//
//  Models.swift
//  Marlin DVR TV
//
//  Decodable shapes of the endpoints Home and sweep 2 read, per the Pass 4 report §4
//  sweep 1. Field names follow the server's JSON tags (cmd/marlin-dvr at HEAD eef49e8;
//  Pass 2 §2). Go `time.Time` values arrive as RFC 3339 strings and are kept as strings.
//  Two server types embed MergedChannel so its fields are flattened into the item
//  (guide.go:561, :672); those decode the channel from the same container.
//

import Foundation

// MARK: Channels (sources.go:103-122; GET /api/channels, sources.go:1006-1022)

struct MergedChannel: Decodable, Identifiable, Hashable {
    let id: String          // "<sourceId>:<guid>"
    let sourceId: String
    let source: String      // the source's name
    let guid: String
    let number: String
    let name: String
    let origNumber: String
    let origName: String
    let logo: String        // provider's absolute URL or ""
    let hd: Bool
    let drm: Bool
    let hidden: Bool
    let favorite: Bool
    let initials: String
    let logoBg: String      // CSS hex
    let tvgId: String?
}

struct ChannelsResponse: Decodable {
    let channels: [MergedChannel]
    let count: Int
    let sources: [String]
}

// MARK: Guide (guide.go:18-38, 550-563, 590-664, 667-691, 695-754)

struct Program: Decodable, Hashable {
    let channel: String     // guid within the source
    let start: Int          // unix seconds
    let end: Int
    let title: String
    let episodeTitle: String?
    let desc: String?
    let season: Int?
    let episode: Int?
    let episodeNum: String?
    let categories: [String]?
    let icon: String?
    let new: Bool?
    let live: Bool?
    let premiere: Bool?
    let finale: Bool?
    let seriesId: String?
    let rating: String?
    let originalAirDate: String?
    let video: String?
}

/// One item of GET /api/guide/now: a MergedChannel flattened, plus the program on now.
struct GuideNowItem: Decodable, Identifiable {
    let channel: MergedChannel
    let program: Program?
    let title: String
    let endsIn: String      // server-formatted, e.g. "ends 3:04 PM"
    let art: String

    var id: String { channel.id }

    private enum CodingKeys: String, CodingKey { case program, title, endsIn, art }

    init(from decoder: Decoder) throws {
        channel = try MergedChannel(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        program = try c.decodeIfPresent(Program.self, forKey: .program)
        title = try c.decode(String.self, forKey: .title)
        endsIn = try c.decode(String.self, forKey: .endsIn)
        art = try c.decode(String.self, forKey: .art)
    }
}

struct GuideNowResponse: Decodable {
    let programs: [GuideNowItem]
    let count: Int
    let at: Int
}

struct GuideBlock: Decodable {
    let title: String
    let subtitle: String
    let span: Int
    let isLive: Bool
    let program: Program?
    let channelId: String
    let empty: Bool?
}

/// One row of GET /api/guide: a MergedChannel flattened, plus its blocks.
struct GuideRow: Decodable, Identifiable {
    let channel: MergedChannel
    let blocks: [GuideBlock]

    var id: String { channel.id }

    private enum CodingKeys: String, CodingKey { case blocks }

    init(from decoder: Decoder) throws {
        channel = try MergedChannel(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try c.decode([GuideBlock].self, forKey: .blocks)
    }
}

struct GuideTimeSlot: Decodable {
    let label: String
    let start: Int
}

struct GuideResponse: Decodable {
    let start: Int
    let slots: Int
    let timeSlots: [GuideTimeSlot]
    var channels: [GuideRow]
    let nowIndex: Double
    let dayLabel: String
    let channelCount: Int
}

/// One item of GET /api/guide/later.
struct LaterItem: Decodable {
    let title: String
    let subtitle: String
    let channel: String     // "2.1 · WMAR"
    let channelId: String
    let start: Int
    let when: String
    let scheduled: Bool
    let program: Program?
    let art: String
}

struct LaterSection: Decodable {
    let label: String       // "On Today" | "On This Week"
    let items: [LaterItem]
}

struct LaterResponse: Decodable {
    let sections: [LaterSection]
}

// MARK: Schedule (passes.go:53-77, 855-879; GET /api/schedule)

struct Job: Decodable, Identifiable {
    let id: String
    let passId: String      // "manual" for Record Now
    let passTitle: String
    let channelId: String
    let number: String
    let channelName: String
    let initials: String
    let logoBg: String
    let program: Program
    let start: Int          // padded
    let end: Int
    let status: String      // Queued | Skipped | Conflict | Recording | COMPLETED | FAILED | STOPPED
    let reason: String?
    let episodeLine: String
    let badge: String
    let time: String
    let duration: String
    let dateLabel: String
    let timeRange: String
    let art: String
    let drm: Bool
    let sourceId: String
}

struct ScheduleGroup: Decodable {
    let label: String       // Today | Tomorrow | <weekday> | <date>
    var items: [Job]
}

struct ScheduleResponse: Decodable {
    var groups: [ScheduleGroup]
    let count: Int
    let passes: Int

    var jobs: [Job] { groups.flatMap(\.items) }
}

// MARK: Library (library.go:369-378, 427-469, 486-500, 586-640)

struct ShowSummary: Decodable, Identifiable {
    let id: String
    let title: String
    let count: Int
    let unwatched: Int
    let art: String
    let lastAdded: String
    let lastUpdated: String
    let lastWatched: String
}

struct LibrarySection: Decodable {
    let key: String         // recently-watched | recently-updated | recently-added
    let label: String
    let items: [ShowSummary]
    let total: Int
}

struct LibraryRoot: Decodable {
    let path: String
    let exists: Bool
    let readable: Bool
    let files: Int
    let error: String?
}

struct LibraryResponse: Decodable {
    let sections: [LibrarySection]
    let shows: Int
    let recordings: Int
    let roots: [LibraryRoot]
    let scannedAt: String
    let scanning: Bool
    let configured: Bool
}

/// The server's `episodeView`: Recording + RecState + the display fields.
struct Episode: Decodable, Identifiable {
    let id: String
    let file: String
    let root: String
    let show: String
    let showId: String
    let episodeTitle: String
    let season: Int
    let episode: Int
    let aired: String
    let size: Int
    let modTime: String
    let ext: String
    let watched: Bool
    let favorite: Bool
    let keep: Bool
    let trash: Bool
    let watchedAt: String?
    let dateLabel: String
    let airedLabel: String
    let description: String
    let tags: [String]
    let channel: String
    let channelAbbr: String
    let sizeLabel: String
    let thumb: String
    let playUrl: String
    let fileLabel: String
    let exists: Bool
}

struct ShowInfo: Decodable {
    let found: Bool
    let genres: [String]
    let overview: String
    let name: String?
}

struct ShowResponse: Decodable {
    let id: String
    let title: String
    let episodes: [Episode]
    let count: Int
    let trashCount: Int
    let showingTrash: Bool
    let art: String
    let info: ShowInfo
    let pass: String        // the matching pass title or ""
    let rss: String
}

// MARK: Cameras (cameras.go:23-39, 280-289)

struct Camera: Decodable, Identifiable {
    let id: String
    let name: String
    let address: String
    let streamPath: String
    let username: String
    let password: String    // always "" from the server
    let hidden: Bool
    let createdAt: String
    let hasCredentials: Bool
    let online: Bool
    let lastCheck: String
    let lastError: String
    let codec: String
}

struct CamerasResponse: Decodable {
    let cameras: [Camera]
    let count: Int
    let online: Int
}

// MARK: Clients (clients.go:14-27, 179-203; the server's `clientView`)

struct ClientRecord: Decodable, Identifiable {
    let id: String
    let name: String
    let app: String
    let type: String
    let os: String
    let ip: String
    let createdAt: String
    let lastSeen: String
    let online: Bool
    let location: String
    let locIcon: String
    let lastSeenLabel: String
    let watching: String
    let watchingIcon: String
}

// MARK: Playback shapes (stream.go:295, 455-491; contract §2.2) — models only in sweep 1

struct PlaySession: Decodable {
    let id: String
    let url: String         // "/api/play/hls/<id>/index.m3u8"
    let title: String
    let sub: String
    let kind: String
    let mode: String        // copy | transcode
    let duration: Double    // recordings only
    let start: Double
    let format: String
}

struct PlayInfo: Decodable {
    let kind: String
    let id: String
    let title: String
    let sub: String
    let art: String
    let drm: Bool?          // live only
    let duration: Double?   // recording only
    let showId: String?
    let watched: Bool?
}
