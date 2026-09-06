//
//  ServerWrites.swift
//  Marlin DVR TV
//
//  Sweep 4 (Pass 4 report §4): the five server writes this app makes, and the shapes the
//  server answers them with. Each call is one request, no retries; the server's plain-text
//  error body arrives as `APIError.message` with its status (409 "that airing is already
//  set to record", 409 "a pass for this series already exists: …", 409 "that airing is not
//  recording"), which the screens show verbatim.
//
//    Record this airing   POST /api/record                        recorder.go:776-848
//    Record the series    POST /api/passes                        passes.go:705-737
//    Episode flags        PUT  /api/library/recordings/{id}       library.go:643-694
//    Hide this channel    PUT  /api/sources/{id}/lineup/{guid}    sources.go:960-1004
//    Stop the recording   POST /api/schedule/jobs/{id}/stop       recorder.go:686-693
//
//  Pass 9 adds three more: the same lineup endpoint with `favorite` (step 7), and
//  PUT / DELETE /api/passes/{id} behind the Edit series pass screen (step 5), plus the read
//  GET /api/passes the airing sheet needs to know a pass already exists (step 4).
//

import Foundation

// MARK: Response shapes

/// POST /api/record answers the computed `Job`, or `{id, status: "Queued"}` when the job is
/// not in this tick's list yet (recorder.go:845-847) — only these three fields are common.
struct RecordOutcome: Decodable {
    let id: String
    let status: String      // Queued | Skipped | Conflict | Recording | COMPLETED | FAILED | STOPPED
    let reason: String?
}

/// `passView` (passes.go:535-547): the `Pass` itself plus the server's rendered labels.
/// GET /api/passes, POST /api/passes and PUT /api/passes/{id} all answer with it.
struct PassView: Decodable, Identifiable {
    let id: String
    let title: String
    let seriesId: String
    let channel: String             // "" = any channel
    let recordMode: String          // new | all
    let padBefore: Int              // minutes
    let padAfter: Int
    let keepMode: String            // all | unwatched | last
    let keepUnwatched: Int
    let keepLast: Int
    let paused: Bool
    let jobCount: Int
    let countLabel: String          // "3 recordings scheduled"
    let padBeforeLabel: String      // "5 mins before" | "none"
    let padAfterLabel: String
    let keepLabel: String           // "All" | "Unwatched Only" | "Last 3 Only" | "Unwatched + 2 Watched"
    let showId: String
}

struct PassesResponse: Decodable {
    let passes: [PassView]
    let count: Int
    let jobs: Int
}

struct OKResponse: Decodable {
    let ok: Bool
}

/// The subset of `passReq` (passes.go:598-618) the Edit series pass screen sends. Optional
/// fields the encoder omits when nil, and the server leaves whatever it is not given.
struct PassEdit: Encodable {
    var recordMode: String?         // "new" | "all"
    var padBefore: Int?
    var padAfter: Int?
    var keepMode: String?           // "all" | "unwatched" | "last"
    var keepUnwatched: Int?
    var keepLast: Int?
    var paused: Bool?               // Pass 10: Pause / Resume a pass
}

/// PUT /api/schedule/jobs/{id} answers this (passes.go:966). `removed` is true when the job
/// was a one-off Record Now: the server drops it outright rather than flagging it, and the
/// airing becomes free to record again. A pass's job only gets the flag; the pass continues.
struct JobCancelResult: Decodable {
    let ok: Bool
    let skipped: Bool
    let removed: Bool
}

/// POST /api/library/trash/empty answers this (trash.go:214). `freed` is already formatted.
struct EmptyTrashResult: Decodable {
    let deleted: Int
    let freed: String
    let failed: Int
    let errors: [String]
}

/// PUT /api/library/recordings/{id} answers the updated `episodeView`, or `{ok, deleted}`
/// when "Remove Items From Trash After" is "Immediately" and the trash flag removed the file
/// at once (library.go:683-691). Both are decoded; the caller handles each.
enum RecordingUpdate: Decodable {
    case episode(Episode)
    case deleted

    init(from decoder: Decoder) throws {
        if let episode = try? Episode(from: decoder) {
            self = .episode(episode)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decodeIfPresent(Bool.self, forKey: .deleted) == true {
            self = .deleted
            return
        }
        throw APIError(kind: .decoding, message: "neither an episode nor {deleted: true}", path: "/api/library/recordings")
    }

    private enum CodingKeys: String, CodingKey { case deleted }
}

/// PUT /api/sources/{id}/lineup/{guid} answers the stored `Override` (sources.go:1028).
struct LineupOverride: Decodable {
    let number: String?
    let name: String?
    let hidden: Bool
    let favorite: Bool
}

/// POST /api/schedule/jobs/{id}/stop answers the persisted `RecordingState` (recorder.go:45-66);
/// the fields the Player shows. 409 "that airing is not recording" when the job is not running.
struct StopOutcome: Decodable {
    let jobId: String
    let status: String      // STOPPED after this call
    let reason: String?
    let title: String
    let channel: String
    let file: String?
    let bytes: Int
}

/// One flag of PUT /api/library/recordings/{id}; the server takes any subset (library.go:650-655).
enum RecordingFlag {
    case keep(Bool)
    case favorite(Bool)
    case watched(Bool)
    case trash(Bool)

    var body: [String: Bool] {
        switch self {
        case .keep(let v): return ["keep": v]
        case .favorite(let v): return ["favorite": v]
        case .watched(let v): return ["watched": v]
        case .trash(let v): return ["trash": v]
        }
    }

    /// One console line per write, for the pass evidence.
    var label: String {
        switch self {
        case .keep(let v): return "keep=\(v)"
        case .favorite(let v): return "favorite=\(v)"
        case .watched(let v): return "watched=\(v)"
        case .trash(let v): return "trash=\(v)"
        }
    }
}

// MARK: The calls

extension APIClient {
    private struct RecordNowBody: Encodable {
        let channelId: String
        let start: Int
    }

    private struct PassBody: Encodable {
        let title: String
        let seriesId: String?
    }

    private struct EmptyBody: Encodable {}

    /// "Record this airing" (frame 5c). `start` is the airing's own `program.start`; the server
    /// matches it against the listing and answers 404 (no listing), 400 (already ended) or
    /// 409 (already set to record) — recorder.go:790-834.
    func recordNow(channelId: String, start: Int) async throws -> RecordOutcome {
        let outcome: RecordOutcome = try await post("/api/record", body: RecordNowBody(channelId: channelId, start: start))
        print("[write] record \(channelId)@\(start) → \(outcome.id) \(outcome.status) \(outcome.reason ?? "")")
        return outcome
    }

    /// "Record the series" (frame 5c). The server fills recordMode "new", keepMode "all" and the
    /// padding defaults, and derives `seriesId` as "title:<lower>" when the listing has none
    /// (passes.go:715-722). 409 when a pass for the same series and channel already exists.
    func createPass(title: String, seriesId: String?) async throws -> PassView {
        let series = (seriesId?.isEmpty == false) ? seriesId : nil
        let pass: PassView = try await post("/api/passes", body: PassBody(title: title, seriesId: series))
        print("[write] pass \"\(title)\" series=\(series ?? "-") → \(pass.id) \(pass.countLabel)")
        return pass
    }

    /// Keep / Favorite / Mark unwatched / Delete on one episode (frame 5d long press).
    func updateRecording(id: String, flag: RecordingFlag) async throws -> RecordingUpdate {
        let update: RecordingUpdate = try await put("/api/library/recordings/\(id)", body: flag.body)
        switch update {
        case .episode(let e):
            print("[write] recording \(id) \(flag.label) → watched=\(e.watched) favorite=\(e.favorite) keep=\(e.keep) trash=\(e.trash)")
        case .deleted:
            print("[write] recording \(id) \(flag.label) → deleted (trash period is Immediately)")
        }
        return update
    }

    /// "Hide this channel" (frame 6f). The lineup override hides it for the web UI and every
    /// client, not only this Apple TV (sources.go:1013-1029; Pass 4 Open Question 8).
    func setChannelHidden(sourceId: String, guid: String, hidden: Bool) async throws -> LineupOverride {
        let override: LineupOverride = try await put("/api/sources/\(sourceId)/lineup/\(guid)", body: ["hidden": hidden])
        print("[write] lineup \(sourceId)/\(guid) hidden=\(hidden) → hidden=\(override.hidden) favorite=\(override.favorite)")
        return override
    }

    /// Pass 9 step 7: favourite or unfavourite a channel from the Guide's left column. Same
    /// endpoint and the same server-wide reach as the hidden flag.
    func setChannelFavourite(sourceId: String, guid: String, favourite: Bool) async throws -> LineupOverride {
        let override: LineupOverride = try await put("/api/sources/\(sourceId)/lineup/\(guid)", body: ["favorite": favourite])
        print("[write] lineup \(sourceId)/\(guid) favorite=\(favourite) → hidden=\(override.hidden) favorite=\(override.favorite)")
        return override
    }

    /// Pass 9 step 4: the passes the server holds, so the sheet knows whether this show
    /// already has one before it offers to create another (passes.go:575-596).
    func passes() async throws -> [PassView] {
        let response: PassesResponse = try await get("/api/passes")
        return response.passes
    }

    /// Pass 9 step 5: change one pass. `applyPassReq` takes any subset (passes.go:619-700).
    func updatePass(id: String, body: PassEdit) async throws -> PassView {
        let pass: PassView = try await put("/api/passes/\(id)", body: body)
        print("[write] pass \(id) → recordMode=\(pass.recordMode) pad=\(pass.padBefore)/\(pass.padAfter) keep=\(pass.keepLabel) · \(pass.countLabel)")
        return pass
    }

    /// Pass 9 step 5: "Delete this pass" (passes.go:799-824).
    func deletePass(id: String) async throws {
        let _: OKResponse = try await delete("/api/passes/\(id)")
        print("[write] pass \(id) deleted")
    }

    /// Pass 10 step 2b: "Cancel recording" on a scheduled airing (passes.go:927-967).
    func cancelJob(id: String) async throws -> JobCancelResult {
        let result: JobCancelResult = try await put("/api/schedule/jobs/\(id)", body: ["skipped": true])
        print("[write] job \(id) cancelled → skipped=\(result.skipped) removed=\(result.removed)")
        return result
    }

    /// Pass 10 step 2d: "Empty Trash" (trash.go:218-222). Deletes the files on disk.
    func emptyTrash() async throws -> EmptyTrashResult {
        let result: EmptyTrashResult = try await post("/api/library/trash/empty", body: [String: String]())
        print("[write] empty trash → deleted=\(result.deleted) freed=\(result.freed) failed=\(result.failed)")
        return result
    }

    /// "Stop the recording and watch" (frame 6g). The server closes the stream and waits for the
    /// recorder to finish before answering, so the tuner is free when this returns (recorder.go:660-684).
    func stopJob(id: String) async throws -> StopOutcome {
        let outcome: StopOutcome = try await post("/api/schedule/jobs/\(id)/stop", body: EmptyBody())
        print("[write] stop job \(id) → \(outcome.status) \(outcome.title) \(outcome.reason ?? "")")
        return outcome
    }
}

/// One line for a failed write, in the server's own words: "409 · that airing is already set to record".
enum WriteError {
    static func text(_ error: Error) -> String {
        guard let api = error as? APIError else { return "\(error)" }
        if let status = api.httpStatus {
            return api.message.isEmpty ? "\(status) · the server refused the change" : "\(status) · \(api.message)"
        }
        return api.message
    }
}
