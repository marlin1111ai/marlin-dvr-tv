//
//  CommercialSegments.swift
//  Marlin DVR TV
//
//  Pass 38 step 1: the response of `GET /api/library/recordings/{id}/commercials`
//  (contract §10, HLS-CLIENT-API.md:341-509; route main.go:317, handler
//  commercials.go:110), and the one call that fetches it.
//
//  The server detects and never skips — "Pass 9 decision 1b is detection only … The app
//  does the skipping" (:356-358). This file only reads the markers; the skipping lives in
//  PlayerModel.
//
//  Two decoding rules come straight from §10 and are the reason this type is not the
//  plain strict struct the rest of the app uses:
//
//  1. `edl` is **absent** when there is no markers file — "`omitempty`, commercials.go:87"
//     (:397) — and §10.5 says that is the ordinary case, since "no stored record and no
//     markers file either … always accompanies `state: "unknown"`" (:453). A non-optional
//     `String` would throw `keyNotFound` on most of the library, so it is optional and a
//     missing `edl` is not an error.
//
//  2. `state` is decoded as a **String**, never as a Swift enum. §10.3 says "Switch on
//     exactly these four and treat anything else as `"unknown"`" (:410) — a `Decodable`
//     enum would instead throw on a fifth value from a future server, which is the exact
//     opposite instruction. `CommercialState(rawValue:)` maps it and falls through to
//     `.unknown`, so a value nobody has seen yet behaves like a value we cannot interpret.
//
//  Everything else follows §10.2's table, where `id`, `state`, `ranges`, `count`, `from`,
//  `source` and `detail` are all "always present" (:389-398) and `ranges` is "`[]` when
//  there are none (commercials.go:119)" (:393).
//

import Foundation

/// One break. `startSeconds` / `endSeconds` are **seconds from the first frame of the
/// recording file** — not the programme's scheduled start, not wall clock (§10.4,
/// :428-436). They match the position AVPlayer reports for a session started with `start`
/// absent or 0; with a `start` offset the rule is `edlTime = playerPosition + start`
/// (:437-441), which is what `PlayerModel.tick()` already computes into `position`.
struct CommercialRange: Decodable, Equatable {
    let startSeconds: Double
    let endSeconds: Double
}

/// Which of the owner's sources recorded this (§10.6). "Always present; all three fields
/// are `""` when it cannot be established" (:396), and `""` means "source unknown", **not**
/// "antenna" (:486).
struct CommercialSource: Decodable, Equatable {
    let id: String
    let name: String
    /// `"m3u"`, `"hdhomerun"` or `""` (:470).
    let type: String
}

/// The four values of §10.3 (:402-408), plus the fall-through the same section demands.
enum CommercialState {
    /// "commercials were found; `ranges` holds them"
    case detected
    /// "detection RAN AND FOUND NONE. This is an answer, not an absence"
    case noneFound
    /// "detection is queued or under way; ask again later"
    case running
    /// "NO ANSWER — never ran, was turned off, failed, was interrupted, the recording is
    /// still being written, or the markers file is gone" — and anything unrecognised.
    case unknown

    /// §10.3: "Switch on exactly these four and treat anything else as `"unknown"`" (:410).
    /// Note the Swift name for `"none"` is `noneFound`, to keep it clear of `Optional.none`.
    init(_ raw: String) {
        switch raw {
        case "detected": self = .detected
        case "none": self = .noneFound
        case "running": self = .running
        case "unknown": self = .unknown
        default: self = .unknown
        }
    }
}

/// What this playback should do with the answer — Pass 38 step 3.
///
/// `playThrough` and `dontKnow` produce the **same** thing on screen: no prompt, ever, for
/// this playback. They are kept apart because they are different facts and the console line
/// should not claim one when it means the other.
enum CommercialPlan: Equatable {
    /// `state: "detected"` — arm the prompt on these ranges.
    case arm([CommercialRange])
    /// `state: "none"` from an `m3u` source: a real answer (§10.6, :479 — "a `"none"` from
    /// `type: "m3u"` is worth acting on"). Play straight through; no prompt will ever show.
    case playThrough
    /// Everything else: `unknown`, `running`, an unrecognised state, and a `"none"` from a
    /// source that is not `m3u` — §10.6 (:476-482) says comskip exits 1 with its clean
    /// "Commercials were not found" on the owner's 720p HDHomeRun recordings, so that
    /// `"none"` "is worth treating like `"unknown"` until antenna detection is fixed".
    /// A `""` source type is "source unknown, not antenna" (:486) and is not believed either.
    case dontKnow
}

struct CommercialsResponse: Decodable {
    let id: String
    /// A raw string on purpose — see rule 2 in the file header. Read it through `state`.
    let stateRaw: String
    let ranges: [CommercialRange]
    let count: Int
    /// `"state"`, `"edl"` or `"none"` (§10.5). "Treat `"edl"` and `"state"` as equally
    /// authoritative; `from` is there so you can tell them apart, not so you can prefer
    /// one" (:460-462) — so nothing in this app branches on it.
    let from: String
    let source: CommercialSource
    /// Absent when there is no markers file (`omitempty`, :397). Optional for that reason
    /// and for no other; a missing `edl` is not an error.
    let edl: String?
    /// "one English sentence for a log or a debug screen. **Do not parse it.** Its wording
    /// is not part of the contract" (:398). Printed to the console, never shown or parsed.
    let detail: String

    private enum CodingKeys: String, CodingKey {
        case id, ranges, count, from, source, edl, detail
        case stateRaw = "state"
    }

    var state: CommercialState { CommercialState(stateRaw) }

    /// Step 3, in one place.
    var plan: CommercialPlan {
        switch state {
        case .detected:
            return .arm(ranges)
        case .noneFound:
            return source.type == "m3u" ? .playThrough : .dontKnow
        case .running, .unknown:
            return .dontKnow
        }
    }
}

/// The break the on-screen prompt is currently offering to skip (Pass 38 steps 4-7).
/// `index` is the range's place in the answer, so a range can be prompted at most once per
/// playback; `endSeconds` is where a skip lands, before it is clamped.
struct CommercialPrompt: Equatable {
    let index: Int
    let endSeconds: Double
}

extension APIClient {
    /// GET /api/library/recordings/{id}/commercials (§10.1, :362-364).
    ///
    /// `{id}` is the ordinary recording id — `episodes[].id` from
    /// `GET /api/library/shows/{showId}` (:366-368), which is exactly what
    /// `PlayRequest.episode?.id` holds. An id the library does not know answers 404
    /// (:368-369) and no authentication is involved (§8).
    func commercials(recordingID: String) async throws -> CommercialsResponse {
        try await get("/api/library/recordings/\(recordingID)/commercials")
    }
}
