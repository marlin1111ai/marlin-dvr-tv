//
//  ClientSession.swift
//  Marlin DVR TV
//
//  Registration with the server (contract §1; Pass 2 §4; Pass 3 2(b) item 9), as decided
//  in DECISIONS.md 2026-09-05 (sweep 1): the client id persists in UserDefaults; the app
//  registers with name = this Apple TV's device name, app = "Marlin DVR TV" + version,
//  type = "Apple TV", os = the tvOS version; it pings on every launch and re-registers
//  when the ping answers 404 "unknown client; register again" (clients.go:262-266).
//

import SwiftUI
import UIKit

@Observable
final class ClientSession {
    static let defaultsKey = "marlinClientId"

    /// The server's record of this client after a successful ping or register.
    private(set) var client: ClientRecord?
    /// One line for the console and the report: what the last launch did.
    private(set) var status = "not started"

    private let api: APIClient
    private let defaults: UserDefaults

    init(api: APIClient, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
    }

    /// The name this Apple TV registered under (DECISIONS.md, design fact), or the device name until then.
    var displayName: String { client?.name ?? Self.deviceName }

    static var deviceName: String { UIDevice.current.name }

    static var appLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Marlin DVR TV \(version)"
    }

    static let typeLabel = "Apple TV"

    static var osLabel: String { "tvOS \(UIDevice.current.systemVersion)" }

    struct RegisterBody: Encodable {
        let name: String
        let app: String
        let type: String
        let os: String
    }

    /// The ping body is optional on the server (clients.go:262-285); sending it keeps app/os current.
    struct PingBody: Encodable {
        let app: String
        let os: String
        let type: String
    }

    /// Ping with the stored id; register when there is none or the ping answers 404.
    /// A transport failure keeps the stored id and does not register (no retries).
    func start() async {
        if let id = defaults.string(forKey: Self.defaultsKey) {
            do {
                let record: ClientRecord = try await api.post(
                    "/api/clients/\(id)/ping",
                    body: PingBody(app: Self.appLabel, os: Self.osLabel, type: Self.typeLabel)
                )
                client = record
                status = "pinged as \(record.name) (\(record.id))"
                print("[client] ping ok: id=\(record.id) name=\(record.name) app=\(record.app) type=\(record.type) os=\(record.os) ip=\(record.ip)")
                return
            } catch let error as APIError where error.httpStatus == 404 {
                print("[client] ping 404 (\(error.message)) — registering again")
            } catch {
                status = "ping failed: \(error)"
                print("[client] ping failed: \(error)")
                return
            }
        }
        await register()
    }

    private func register() async {
        let body = RegisterBody(name: Self.deviceName, app: Self.appLabel, type: Self.typeLabel, os: Self.osLabel)
        do {
            let record: ClientRecord = try await api.post("/api/clients/register", body: body)
            defaults.set(record.id, forKey: Self.defaultsKey)
            client = record
            status = "registered as \(record.name) (\(record.id))"
            print("[client] registered: id=\(record.id) name=\(record.name) app=\(record.app) type=\(record.type) os=\(record.os) ip=\(record.ip)")
        } catch {
            status = "register failed: \(error)"
            print("[client] register failed: \(error)")
        }
    }
}
