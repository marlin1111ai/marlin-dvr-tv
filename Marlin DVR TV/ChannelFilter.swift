//
//  ChannelFilter.swift
//  Marlin DVR TV
//
//  The DRM rule (DECISIONS.md 2026-09-05 (design)): channels with drm = true never appear
//  in any list. The server returns them with the flag set (sources.go:114) and does not
//  hide them itself; the typed endpoint calls below apply the rule so every caller gets
//  playable lists only.
//

import Foundation

extension Array where Element == MergedChannel {
    var playable: [MergedChannel] { filter { !$0.drm } }
}

extension Array where Element == GuideNowItem {
    var playable: [GuideNowItem] { filter { !$0.channel.drm } }
}

extension Array where Element == GuideRow {
    var playable: [GuideRow] { filter { !$0.channel.drm } }
}

extension Array where Element == Job {
    var playable: [Job] { filter { !$0.drm } }
}

/// The endpoints Home and sweep 2 read, with the DRM rule applied.
extension APIClient {
    /// GET /api/channels?source=&filter= (sources.go:1006-1022). Playable channels only.
    func channels(source: String? = nil, filter: String? = nil) async throws -> [MergedChannel] {
        var query: [URLQueryItem] = []
        if let source { query.append(URLQueryItem(name: "source", value: source)) }
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        let response: ChannelsResponse = try await get("/api/channels", query: query)
        return response.channels.playable
    }

    /// GET /api/guide/now (guide.go:667-691). Playable channels only.
    func onNow(source: String? = nil, filter: String? = nil) async throws -> [GuideNowItem] {
        var query: [URLQueryItem] = []
        if let source { query.append(URLQueryItem(name: "source", value: source)) }
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        let response: GuideNowResponse = try await get("/api/guide/now", query: query)
        return response.programs.playable
    }

    /// GET /api/guide?start=&slots= (guide.go:590-664). Rows for playable channels only.
    func guide(start: Int? = nil, slots: Int, source: String? = nil, filter: String? = nil) async throws -> GuideResponse {
        var query = [URLQueryItem(name: "slots", value: String(slots))]
        if let start { query.append(URLQueryItem(name: "start", value: String(start))) }
        if let source { query.append(URLQueryItem(name: "source", value: source)) }
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        var response: GuideResponse = try await get("/api/guide", query: query)
        response.channels = response.channels.playable
        return response
    }

    /// GET /api/guide/later (guide.go:695-754).
    func later() async throws -> LaterResponse {
        try await get("/api/guide/later")
    }

    /// GET /api/schedule (passes.go:855-879). Jobs on playable channels only.
    func schedule() async throws -> ScheduleResponse {
        var response: ScheduleResponse = try await get("/api/schedule")
        response.groups = response.groups.map { group in
            var g = group
            g.items = group.items.playable
            return g
        }
        return response
    }

    /// GET /api/library?limit= (library.go:427-469).
    func library(limit: Int? = nil) async throws -> LibraryResponse {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await get("/api/library", query: query)
    }

    /// GET /api/library/shows/{id}?trash=1 (library.go:586-640). `trash` lists the trashed
    /// episodes of that show instead of the visible ones, with `trashCount` beside them.
    func show(id: String, trash: Bool = false) async throws -> ShowResponse {
        try await get("/api/library/shows/\(id)", query: trash ? [URLQueryItem(name: "trash", value: "1")] : [])
    }

    /// GET /api/system (system.go:257-260) — the Manage DVR storage line (Pass 10 step 2a).
    func system() async throws -> SystemInfo {
        try await get("/api/system")
    }

    /// GET /api/cameras (cameras.go:280-289).
    func cameras() async throws -> CamerasResponse {
        try await get("/api/cameras")
    }
}
