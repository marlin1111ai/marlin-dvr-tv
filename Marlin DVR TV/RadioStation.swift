//
//  RadioStation.swift
//  Marlin DVR TV
//
//  Pass 19 step 1: the station list, `GET /api/radio` (contract §9, HLS-CLIENT-API.md:277-320;
//  handler radio.go:63-88).
//
//  Radio is not the video path and shares none of it. The server "only stores the stations and
//  hands you the list" (:279-282) — it never plays, proxies or transcodes the audio — so there
//  is no play session, no HLS, no playlist, no keep-alive and no tuner behind any of this.
//
//  The handler has no failure path: it reads a slice under RLock and calls writeJSON, so it
//  always answers 200 (Pass 18 §1.6). The two things that can still go wrong are the server
//  being unreachable and the list being empty; the screen says either out loud.
//

import Foundation

/// One station exactly as the server returns it (:293-300). Six keys, every one built from a
/// Go `string` at radio.go:85, so every one always present and never null.
struct RadioStation: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    /// The label the owner typed — "**a hint only**" (:297), "not verified by the server"
    /// (:314). It is empty on both of the owner's stations (Pass 18 §2, measured again this
    /// pass). The app ignores it entirely (owner, 2026-09-06): it is never drawn and, above
    /// all, never handed to AVFoundation — see RadioPlayer.
    let format: String

    /// The stream. Played directly (:307-309: do **not** POST /api/play/sessions for a
    /// station — "that route is for TV/cameras and does not know about radio").
    let url: String

    /// The raw icon link the owner pasted, "for reference" (:299). Never loaded: it points at
    /// Wikipedia and Google, and :317-318 says to use the server's cached copy instead.
    let icon: String

    /// The icon the DVR serves from its own cache — "/api/art/feed?u=<escaped icon>"
    /// (radio.go:72) — resolved against the server base by `ServerConfig.resolve`. Empty when
    /// the server could not fetch the image; the tile draws its own placeholder then (:300).
    let iconUrl: String
}

struct RadioResponse: Decodable {
    let stations: [RadioStation]
    let count: Int
}

extension APIClient {
    /// GET /api/radio (radio.go:63-88).
    ///
    /// The list comes back **in the owner's order** and is rendered in that order (:302).
    /// There is no sort key, no `order` field and no timestamp to sort by, and the app must
    /// not sort — so nothing here reorders it.
    func radio() async throws -> RadioResponse {
        try await get("/api/radio")
    }
}
