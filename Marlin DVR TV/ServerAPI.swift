//
//  ServerAPI.swift
//  Marlin DVR TV
//
//  The Marlin DVR server: one base URL (owner decision, DECISIONS.md 2026-09-05 sweep 1),
//  a thin JSON client, and the server's plain-text error bodies surfaced as errors.
//  No retries, no caching beyond URLSession's defaults. Every URL the server returns is
//  server-relative (Pass 2 §5 item 3); `ServerConfig.resolve` turns one into an absolute URL.
//

import Foundation

enum ServerConfig {
    /// http://192.168.1.250:8090 — the Unraid host port that maps to the container (contract lines 8-9).
    static let baseURL = URL(string: "http://192.168.1.250:8090")!

    /// What the rail footer shows (frame 1b, dc:71).
    static let hostLabel = "192.168.1.250:8090"

    /// Resolves a server-relative path ("/api/art/show?title=…", "/api/library/recordings/x/thumb.jpg")
    /// or an absolute URL (a provider channel logo) against the base. Empty means no image.
    static func resolve(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}

/// A failed request. `message` is the server's plain-text body for an HTTP error
/// (the server answers errors with `http.Error`, never JSON — Pass 2 "How the inventory was made").
struct APIError: Error, LocalizedError, CustomStringConvertible {
    enum Kind: Equatable {
        case http(status: Int)
        case transport
        case decoding
        case badResponse
    }

    let kind: Kind
    let message: String
    let path: String

    var httpStatus: Int? {
        if case .http(let status) = kind { return status }
        return nil
    }

    var errorDescription: String? { description }

    var description: String {
        switch kind {
        case .http(let status): return "HTTP \(status) on \(path): \(message)"
        case .transport: return "transport error on \(path): \(message)"
        case .decoding: return "decoding error on \(path): \(message)"
        case .badResponse: return "bad response on \(path): \(message)"
        }
    }
}

/// GET and POST JSON against the base URL.
final class APIClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL = ServerConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: try url(path, query: query))
        request.httpMethod = "GET"
        return try await send(request, path: path)
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: try url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request, path: path)
    }

    private func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError(kind: .badResponse, message: "cannot build URL", path: path)
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw APIError(kind: .badResponse, message: "cannot build URL", path: path)
        }
        return url
    }

    private func send<T: Decodable>(_ request: URLRequest, path: String) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError(kind: .transport, message: error.localizedDescription, path: path)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(kind: .badResponse, message: "not an HTTP response", path: path)
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw APIError(kind: .http(status: http.statusCode), message: text, path: path)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(kind: .decoding, message: "\(error)", path: path)
        }
    }
}
