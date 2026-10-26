//
//  SettingsScreen.swift
//  Marlin DVR TV
//
//  Pass 136: the Settings screen — the first one, built to the Channels app's shape (REA report
//  §2.5, §5.2 item 7): two panes, the groups on the left and the rows of the chosen group on the
//  right, each row with one line of help under its title. The rows of this pass are read-only
//  facts the app already holds, plus one read made here — this Apple TV's name and tvOS version,
//  the server's address and version, the app's version (owner's 4a, 2026-10-26). Manage DVR stays
//  its own sidebar section. Not in the approved design, which parked Settings as a Home tile —
//  built to the app's look, the route Manage DVR, Favorites, the radar and Radio took.
//
//  Pass 137: the two panes are the shared list-plus-detail container and the group row moved to
//  it (`ListDetailPage`, `ListGroupRow` in ScreenContainers.swift); nothing else changed.
//

import SwiftUI

enum SettingsGroup: String, CaseIterable, Identifiable {
    case thisAppleTV, server, app

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisAppleTV: return "This Apple TV"
        case .server: return "Server"
        case .app: return "App"
        }
    }
}

/// One read-only row: its title, its value, and the help line under the title.
struct SettingsRowItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let help: String
}

@MainActor
@Observable
final class SettingsModel {
    private let api: APIClient
    /// `GET /api/status`'s answer; nil until it lands, and nil with `statusError` set when it failed.
    private(set) var status: StatusResponse?
    private(set) var statusError: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            let answer = try await api.status()
            status = answer
            statusError = nil
            print("[settings] status: \(answer.name) \(answer.version)")
        } catch {
            statusError = WriteError.text(error)
            print("[settings] status: \(error)")
        }
    }

    /// The server's version row: the server's own name and version, the failure when the read
    /// failed, and the waiting line until it has answered — never a number it did not give.
    var serverVersion: String {
        if let status { return "\(status.name) \(status.version)" }
        if let statusError { return "could not read — \(statusError)" }
        return "Reading the server…"
    }
}

struct SettingsScreen: View {
    let api: APIClient
    let clientName: String
    let onLeave: () -> Void
    @State private var model: SettingsModel
    @State private var group: SettingsGroup = .thisAppleTV
    @FocusState private var focused: String?

    init(api: APIClient, clientName: String, onLeave: @escaping () -> Void) {
        self.api = api
        self.clientName = clientName
        self.onLeave = onLeave
        _model = State(initialValue: SettingsModel(api: api))
    }

    var body: some View {
        ListDetailPage(title: "Settings") {
            groups
        } detail: {
            rows
        }
        .defaultFocus($focused, Self.groupID(.thisAppleTV))
        // The right pane follows the group under focus, so moving down the list changes it.
        .onChange(of: focused) { _, landed in
            if let landed, landed.hasPrefix("group:"),
               let picked = SettingsGroup(rawValue: String(landed.dropFirst("group:".count))) {
                group = picked
            }
        }
        .task {
            focusSoon { focused = Self.groupID(.thisAppleTV) }
            await model.load()
        }
        // Menu on a row goes back to its group; Menu on a group leaves (the shell opens the sidebar).
        .onExitCommand {
            if let current = focused, current.hasPrefix("row:") {
                focused = Self.groupID(group)
            } else {
                onLeave()
            }
        }
    }

    private static func groupID(_ group: SettingsGroup) -> String { "group:\(group.rawValue)" }

    private func rowID(_ item: SettingsRowItem) -> String { "row:\(group.rawValue).\(item.id)" }

    private var groups: some View {
        VStack(spacing: 12) {
            ForEach(SettingsGroup.allCases) { candidate in
                ListGroupRow(title: candidate.title, active: candidate == group, focused: focused == Self.groupID(candidate))
                    .focused($focused, equals: Self.groupID(candidate))
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 12) {
            ForEach(items(for: group)) { item in
                MenuRow(title: item.title, state: item.value, focused: focused == rowID(item), help: item.help) { }
                    .focused($focused, equals: rowID(item))
            }
        }
    }

    private func items(for group: SettingsGroup) -> [SettingsRowItem] {
        switch group {
        case .thisAppleTV:
            return [
                SettingsRowItem(id: "name", title: "Name", value: clientName,
                                help: "The name this Apple TV registered with the server. Rename it on the server's Clients page."),
                SettingsRowItem(id: "os", title: "tvOS", value: ClientSession.osLabel,
                                help: "The system version this Apple TV is running."),
            ]
        case .server:
            return [
                SettingsRowItem(id: "address", title: "Address", value: ServerConfig.hostLabel,
                                help: "The Marlin DVR server this app talks to."),
                SettingsRowItem(id: "version", title: "Version", value: model.serverVersion,
                                help: "Read from the server when this screen opened."),
            ]
        case .app:
            return [
                SettingsRowItem(id: "version", title: "Version", value: Self.appVersion,
                                help: "Marlin DVR TV, the Apple TV app for the Marlin DVR server."),
            ]
        }
    }

    /// "1.0 (1)" — the marketing version and the build number from the bundle.
    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}

