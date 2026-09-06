//
//  PlaybackSession.swift
//  Marlin DVR TV
//
//  The HLS session client of contract §2, §5, §6, §7 and the two calls around it that
//  sweep 3 may make: create with `format: "hls"` and the persisted client id; the first
//  playlist fetch with a 25-second timeout (the server blocks up to 20 s, contract §7);
//  the keep-alive fetch every 10 s with `Range: bytes=0-0` (every fetch stamps the
//  session, contract §6); DELETE to stop; the session log; and PUT watched:true when a
//  recording plays to its end (library.go:643-694). Raw URLSession calls, no retries.
//

import Foundation

struct PlaylistProbe {
    let status: Int          // 0 = transport failure
    let text: String         // the server's plain-text body on an error, or the transport error
}

final class PlaybackSessionClient {
    private let baseURL: URL
    private let session: URLSession
    private let defaults: UserDefaults

    /// Timeouts: the first playlist blocks up to 20 s on the server (contract §7); 25 s here.
    static let firstPlaylistTimeout: TimeInterval = 25
    static let keepAliveInterval: Duration = .seconds(10)

    init(baseURL: URL = ServerConfig.baseURL, defaults: UserDefaults = .standard) {
        self.baseURL = baseURL
        self.defaults = defaults
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.firstPlaylistTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    /// The client id Pass 5 persisted (ClientSession.defaultsKey); the server labels the session with it.
    var clientID: String? { defaults.string(forKey: ClientSession.defaultsKey) }

    private struct CreateBody: Encodable {
        let kind: String
        let id: String
        let format: String
        let client: String
        let start: Double
    }

    /// POST /api/play/sessions — ffmpeg (and for live the tuner) is held from the 200 (contract §2.2).
    func create(_ request: PlayRequest) async throws -> PlaySession {
        let body = CreateBody(kind: request.kind, id: request.targetID, format: "hls", client: clientID ?? "", start: request.startSeconds)
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/play/sessions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await data(for: req, path: "/api/play/sessions")
        try Self.check(response, data: data, path: "/api/play/sessions")
        do {
            return try JSONDecoder().decode(PlaySession.self, from: data)
        } catch {
            throw APIError(kind: .decoding, message: "\(error)", path: "/api/play/sessions")
        }
    }

    /// GET the playlist once, in full, before AVPlayer sees it (standing call).
    func firstPlaylist(_ url: URL) async -> PlaylistProbe {
        var req = URLRequest(url: url)
        req.timeoutInterval = Self.firstPlaylistTimeout
        do {
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let text = status == 200 ? "" : (String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            return PlaylistProbe(status: status, text: text)
        } catch {
            return PlaylistProbe(status: 0, text: error.localizedDescription)
        }
    }

    /// One keep-alive fetch: `Range: bytes=0-0` on the playlist; returns the HTTP status (410 = session ended).
    func keepAlive(_ url: URL) async -> Int? {
        var req = URLRequest(url: url)
        req.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        req.timeoutInterval = 20
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            print("[session] keep-alive failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// DELETE /api/play/sessions/{id} (contract §5). Errors are logged, never thrown: stopping must not fail.
    func stop(id: String) async {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/play/sessions/\(id)"))
        req.httpMethod = "DELETE"
        req.timeoutInterval = 15
        do {
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[session] DELETE \(id) → \(status) \(String(data: data, encoding: .utf8) ?? "")")
        } catch {
            print("[session] DELETE \(id) failed: \(error.localizedDescription)")
        }
    }

    /// GET /api/play/sessions/{id}/log — the ffmpeg log, plain text (contract §7). Nil on failure.
    func log(id: String) async -> String? {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/play/sessions/\(id)/log"))
        req.timeoutInterval = 15
        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// PUT /api/library/recordings/{id} {watched: true} — only when a recording played to its end.
    func markWatched(recordingID: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/library/recordings/\(recordingID)"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["watched": true])
        req.timeoutInterval = 15
        let (data, response) = try await data(for: req, path: "/api/library/recordings/\(recordingID)")
        try Self.check(response, data: data, path: "/api/library/recordings/\(recordingID)")
        print("[session] watched:true → \(recordingID)")
    }

    private func data(for request: URLRequest, path: String) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError(kind: .transport, message: error.localizedDescription, path: path)
        }
    }

    private static func check(_ response: URLResponse, data: Data, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError(kind: .badResponse, message: "not an HTTP response", path: path)
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw APIError(kind: .http(status: http.statusCode), message: text, path: path)
        }
    }
}
