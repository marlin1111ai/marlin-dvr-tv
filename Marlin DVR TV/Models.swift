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

// MARK: Channel collections (collections.go:12-17, 63-67; GET /api/collections, collections.go:90-99)

/// One of the owner's channel collections: a named, ordered list of channel ids curated on
/// the server's admin page. The response also carries `icon`, the resolved `channels` and a
/// `count`; the Guide reads neither — it asks the server to filter and draws the rows that
/// come back — so only the two fields this app uses are decoded.
struct ChannelCollection: Decodable, Identifiable, Hashable {
    let id: String          // "col-<unix milliseconds>"
    let name: String
}

struct CollectionsResponse: Decodable {
    let collections: [ChannelCollection]
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

// MARK: Guide search (GET /api/guide/find, GET /api/guide/search) — Pass 63

/// One row of `GET /api/guide/find?q=` (guide.go:862-871).
///
/// A deliberately thin **display** row, shaped by the server for its own top-bar dropdown: it
/// carries what a result line shows plus the airing's identity (`channelId` + `start`), and
/// nothing that could rebuild a `Program` or a `MergedChannel`. That is why clicking one costs
/// a second read (Pass 62 §2.2).
///
/// Strict on all eight, because all eight are always there: **no field carries `omitempty`**
/// (guide.go:863-870), so the server answers `""`, `0` or `false` rather than omitting a key.
struct FindRow: Decodable, Identifiable {
    let channelId: String   // "<sourceId>:<guid>" (sources.go:319)
    let start: Int          // the programme's true unix start, unrounded
    let title: String
    let subtitle: String    // the raw episode title, "" when the listing has none
    let when: String        // "Mon 3:04 PM", server-local, no date
    let duration: String    // "30m" / "1h 0m", rounded to the minute
    let channelLabel: String // "<number> <name>" — one space, and the reverse of /api/guide/search's
    let drm: Bool

    /// The same identity `AiringSelection.id` uses, so a row and the sheet it opens agree.
    var id: String { "\(channelId)@\(start)" }
}

/// `{"matches": [...], "count": N}`. **`count` is the total before the 20-row cap**
/// (guide.go:899-903), not the length of `matches`.
struct FindResponse: Decodable {
    let count: Int
    let matches: [FindRow]

    /// Lenient on the array only, the way `TrashResponse` is: the handler initialises `out` to
    /// `[]row{}` at guide.go:872 so it should never be `null`, but an absent or null array is
    /// "no matches" rather than a screen-wide failure. Every row inside it decodes strictly.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matches = try container.decodeIfPresent([FindRow].self, forKey: .matches) ?? []
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? matches.count
    }

    private enum CodingKeys: String, CodingKey { case count, matches }
}

/// One match of `GET /api/guide/search?title=` (guide.go:818-829) — the read that reconstitutes
/// a clicked search result into something `AiringSheet` can be given (owner, 2026-09-11).
///
/// The Go type **embeds `Program`**, so the programme's whole field set is flattened into the
/// same JSON object as the nine display fields beside it. That is the shape `GuideNowItem` and
/// `GuideRow` already decode, and this follows them: `Program` is decoded from the *same*
/// container, then the nine siblings from a keyed one.
///
/// Strict throughout, which is this app's habit and is what the shape supports:
/// `Program.channel/start/end/title` have no `omitempty` (guide.go:19-22) and neither does any
/// of the nine (guide.go:820-828), so every key below is always present. Everything optional in
/// `Program` is optional here for the same reason it is there.
struct GuideSearchMatch: Decodable, Identifiable {
    let program: Program
    let channelId: String
    let channelLabel: String    // "<name> <number>" — the reverse of `find`'s (guide.go:837)
    let initials: String
    let logoBg: String
    let when: String
    let duration: String
    let scheduled: Bool
    let drm: Bool
    let art: String

    var id: String { "\(channelId)@\(program.start)" }

    private enum CodingKeys: String, CodingKey {
        case channelId, channelLabel, initials, logoBg, when, duration, scheduled, drm, art
    }

    init(from decoder: Decoder) throws {
        program = try Program(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        channelId = try c.decode(String.self, forKey: .channelId)
        channelLabel = try c.decode(String.self, forKey: .channelLabel)
        initials = try c.decode(String.self, forKey: .initials)
        logoBg = try c.decode(String.self, forKey: .logoBg)
        when = try c.decode(String.self, forKey: .when)
        duration = try c.decode(String.self, forKey: .duration)
        scheduled = try c.decode(Bool.self, forKey: .scheduled)
        drm = try c.decode(Bool.self, forKey: .drm)
        art = try c.decode(String.self, forKey: .art)
    }
}

/// `{"matches": [...], "count": N}` again, and here `count` **is** the array's own length —
/// this route has no cap (guide.go:843).
struct GuideSearchResponse: Decodable {
    let count: Int
    let matches: [GuideSearchMatch]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matches = try container.decodeIfPresent([GuideSearchMatch].self, forKey: .matches) ?? []
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? matches.count
    }

    private enum CodingKeys: String, CodingKey { case count, matches }
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

// MARK: Trash (GET /api/library/trash — server 1.6.0; Pass 33)

/// One trashed recording as the trash listing hands it over.
///
/// Deliberately its own type and not `Episode`. The listing answers eight fields and no more
/// (measured against 1.6.0 on 2026-09-07, Pass 33 §1): there is no `showId`, no `file`, no
/// `thumb`, no `exists`, and none of the server-made labels. It has to be that thin, because a
/// recording in here may belong to a show that has left the library altogether — which is the
/// whole reason the endpoint exists (Pass 32 §B.3).
///
/// Decoding is strict on purpose: if the server's shape moves, the read should fail loudly
/// rather than draw a screen of blank rows.
struct TrashItem: Decodable, Identifiable {
    let id: String              // the recording id — the same one the library used (Pass 33 §5)
    let show: String            // the show's title, not its slug
    let episodeTitle: String    // "" when the listing has none
    let season: Int             // 0 when unknown
    let episode: Int            // 0 when unknown
    let aired: String           // RFC 3339 with the server's offset, "2026-09-06T21:00:00-04:00"
    let trashedAt: String       // RFC 3339, nanosecond precision — see `ServerTime.date`
    let size: Int               // bytes

    /// The show's poster. The per-recording thumbnail 404s once a recording is trashed
    /// (measured, Pass 33 §1), and this one answers for a show that has left the library,
    /// so it is what the row can actually draw.
    var artPath: String {
        var components = URLComponents()
        components.path = "/api/art/show"
        components.queryItems = [URLQueryItem(name: "title", value: show)]
        return components.string ?? ""
    }
}

struct TrashResponse: Decodable {
    let count: Int
    let recordings: [TrashItem]

    /// `recordings` is taken leniently for one reason only: the empty trash could not be
    /// measured without emptying the owner's (out of scope this pass), and Go marshals an
    /// empty slice as `null` about as often as `[]`. Either answer, and a missing key, read
    /// as no recordings. `count` is always present in every response measured.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordings = try container.decodeIfPresent([TrashItem].self, forKey: .recordings) ?? []
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? recordings.count
    }

    private enum CodingKeys: String, CodingKey { case count, recordings }
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

// MARK: System (system.go:16-46, 191-248; GET /api/system) — Pass 10 storage line

/// Only the disk fields the Manage DVR storage line needs. Every one of them is a string the
/// server has already formatted except the percentage (Pass 2 §2.1).
struct SystemInfo: Decodable {
    let diskUsedPercent: Int
    let diskLabel: String       // "10.68 TB available on the recordings volume"
    let diskFree: String        // "10.68 TB"
    let diskTotal: String       // "10.91 TB"
    let diskUsed: String        // "228.63 GB"
    let diskVolume: String      // "recordings volume"
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
