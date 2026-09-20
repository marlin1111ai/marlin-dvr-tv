//
//  ServerEvents.swift
//  Marlin DVR TV
//
//  Pass 116: the server's change notices. Since 1.10.0 the server announces, live, that the channel
//  list or the collections changed: `GET /api/events` is a server-sent event stream whose every
//  notice is one line, `data: channels` or `data: collections`, and nothing else — no `event:`, no
//  `id:`, no `retry:` (events.go:74-76; contract §12). On connect it writes the comment line
//  `: connected` (events.go:66) and every 15 s the comment line `: keepalive` (events.go:68,
//  :77-79). Nothing is replayed to a client that was not connected, and the server never closes the
//  stream except by stopping, which it does with no goodbye (events.go:72-73; main.go:464-472).
//
//  So this reader does three things and no more: it holds the stream open, it reports each notice,
//  and when the stream is lost it connects again by itself. **Every successful connect is reported
//  as `.connected`, first or not, because a reconnecting client has been told nothing about what it
//  missed** — what to re-read on it is the listener's business (`GuideScreen`), not this file's.
//
//  `APIClient` cannot serve this: it awaits the whole body (ServerAPI.swift:116) and this body never
//  ends. The stream has a `URLSession` of its own, as the file route has
//  (PlaybackSession.swift:46-54), for two reasons: its timeouts are its own and must not be bent by
//  or bend anyone else's, and a stream that never ends should not hold one of the shared session's
//  connections to the server against every other request the app makes.
//
//  **Loud, not quiet.** The reconnect is the only thing this file does silently on the screen, and
//  even that prints. A status other than 200, a body that is not an event stream, and a line that is
//  neither a comment, a blank nor one of the two words are each printed as an ERROR rather than
//  skipped.
//

import Foundation

/// One of the two words the server sends (events.go:16-19).
enum ServerNotice: String {
    case channels
    case collections
}

enum ServerEvent: Equatable {
    /// The stream is open — for the first time or again. Nothing missed is replayed.
    case connected
    case notice(ServerNotice)
}

final class ServerEvents {
    /// The idle timer. The server writes a keep-alive every 15 s, so three of them can go missing
    /// before this fires. It is the only way a dead network is ever noticed: the server sends no
    /// goodbye, and a connection that has simply gone quiet looks exactly like one with no news.
    static let idleTimeout: TimeInterval = 45
    /// A stream this old is cut and reopened. Stated rather than left to the platform's default.
    static let resourceTimeout: TimeInterval = 7 * 24 * 60 * 60
    /// The wait before each attempt after a loss: 2 s, 5 s, 10 s, then 30 s for every attempt after
    /// that. A successful connect starts it again at 2 s.
    static let retryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(30)]
    /// A server older than 1.10.0 answers 404 "no such API route" (main.go:356-358). It will not
    /// grow the route by being asked often.
    static let missingRouteDelay: Duration = .seconds(60)

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = ServerConfig.baseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.idleTimeout
        config.timeoutIntervalForResource = Self.resourceTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    /// The events, for as long as the caller keeps reading them. Ending the read — a cancelled
    /// `.task`, which is what a screen leaving is — cancels the request; the server then sees its
    /// request context end and drops the subscriber (events.go:64-65, :72-73).
    ///
    /// The buffer is unbounded on purpose: no notice is dropped on this side of the wire.
    func events() -> AsyncStream<ServerEvent> {
        AsyncStream { continuation in
            let reader = Task { await self.run(continuation) }
            continuation.onTermination = { _ in reader.cancel() }
        }
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        var retry: Duration?
    }

    private func run(_ continuation: AsyncStream<ServerEvent>.Continuation) async {
        var attempt = 0
        while !Task.isCancelled {
            var wait = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
            let opened = Date()
            var keepAlives = 0, blanks = 0, notices = 0
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("/api/events"))
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw Failure(description: "not an HTTP response")
                }
                guard http.statusCode == 200 else {
                    throw Failure(
                        description: "HTTP \(http.statusCode)" + (http.statusCode == 404 ? " — this server has no GET /api/events; it is older than 1.10.0" : ""),
                        retry: http.statusCode == 404 ? Self.missingRouteDelay : nil
                    )
                }
                let type = http.value(forHTTPHeaderField: "Content-Type") ?? ""
                guard type.hasPrefix("text/event-stream") else {
                    throw Failure(description: "HTTP 200 but Content-Type \u{201C}\(type)\u{201D}, not an event stream")
                }
                attempt = 0
                wait = Self.retryDelays[0]
                print("[events] connected")
                continuation.yield(.connected)
                for try await line in bytes.lines {
                    if line.isEmpty {
                        blanks += 1
                    } else if line.hasPrefix(":") {
                        keepAlives += 1
                    } else if line.hasPrefix("data: "), let notice = ServerNotice(rawValue: String(line.dropFirst(6))) {
                        notices += 1
                        print("[events] \(notice.rawValue)")
                        continuation.yield(.notice(notice))
                    } else {
                        print("[events] ERROR: a line that is neither a comment nor one of the two words: \u{201C}\(line)\u{201D}")
                    }
                }
                guard !Task.isCancelled else {
                    print("[events] closed\(Self.tally(opened, keepAlives, blanks, notices))")
                    break
                }
                print("[events] lost: the server ended the stream\(Self.tally(opened, keepAlives, blanks, notices))")
            } catch {
                guard !Task.isCancelled else {
                    print("[events] closed\(Self.tally(opened, keepAlives, blanks, notices))")
                    break
                }
                if let failure = error as? Failure {
                    if let retry = failure.retry { wait = retry }
                    print("[events] ERROR: GET /api/events: \(failure)")
                } else {
                    print("[events] lost: \(error.localizedDescription)\(Self.tally(opened, keepAlives, blanks, notices))")
                }
            }
            attempt += 1
            print("[events] retry in \(wait)")
            do {
                try await Task.sleep(for: wait)
            } catch {
                break
            }
        }
        continuation.finish()
    }

    /// What one connection carried, for the line that reports its end.
    private static func tally(_ opened: Date, _ keepAlives: Int, _ blanks: Int, _ notices: Int) -> String {
        " after \(Int(Date().timeIntervalSince(opened))) s · \(notices) notice(s) · \(keepAlives) comment line(s) · \(blanks) blank line(s)"
    }
}
