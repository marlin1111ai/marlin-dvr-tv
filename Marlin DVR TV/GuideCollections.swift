//
//  GuideCollections.swift
//  Marlin DVR TV
//
//  Pass 72: the Guide's channel collections. A collection is the owner's named, ordered list
//  of channel ids, curated on the server's admin page (GET /api/collections,
//  collections.go:90-99). The Guide's header carries a button that opens the overlay below;
//  picking a collection reloads the grid through GET /api/guide?filter=<id>, and the server
//  returns that collection's members in the owner's own order — `filterChannels` re-sorts its
//  result back into collection order, overriding the channel-number sort, with the comment
//  "collection order wins" (sources.go:389-401).
//
//  **The filter value is the id, never the name** (owner, 2026-09-11). `findCollection`
//  accepts either (collections.go:50-60), but four built-in filter words — "All Channels",
//  "Favorites", "HD", "Non-HD" — shadow a collection of the same name (sources.go:362), and
//  duplicate names resolve to the first in the file. An id has neither trap.
//
//  The model is owned above `ScreenShell` for the same reason Search's is
//  (ScreenShell.swift:27-30): `.id(current)` rebuilds the content on every rail visit, so a
//  selection held inside `GuideScreen` would not survive one trip to the rail. It is also
//  written to `UserDefaults`, so the choice survives a relaunch.
//

import SwiftUI

@Observable
final class GuideCollectionsModel {
    /// The one new key this pass adds. It holds the chosen collection's **id** — what the
    /// filter carries — and its **name** beside it, so the header button can read "Local" on
    /// the first frame after a relaunch: the collections read happens when the overlay opens,
    /// which may never happen, and a button reading "All Channels" over a filtered grid would
    /// be a lie. The value is JSON, the same shape `marlinWeatherFix` uses for its one key.
    static let defaultsKey = "marlinGuideCollection"

    private struct Saved: Codable {
        let id: String
        let name: String
    }

    private let api: APIClient
    private let defaults: UserDefaults

    /// The chosen collection's id, or nil for All Channels. This is the `filter=` value.
    private(set) var selectedId: String?
    /// The chosen collection's name, as the server last gave it. Nil for All Channels.
    private(set) var selectedName: String?

    /// What the overlay lists, in the server's order. Read when the overlay opens.
    private(set) var collections: [ChannelCollection] = []
    private(set) var loading = false
    /// The read failed. The overlay then offers All Channels alone and says so.
    private(set) var failed = false

    init(api: APIClient, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            selectedId = saved.id
            selectedName = saved.name
            print("[collections] restored \(saved.id) \u{201C}\(saved.name)\u{201D}")
        }
    }

    /// What the header button reads.
    var buttonLabel: String { selectedName ?? "All Channels" }

    /// The owner picked a row. Nil is All Channels, which sends no filter at all.
    func select(_ collection: ChannelCollection?) {
        selectedId = collection?.id
        selectedName = collection?.name
        if let collection, let data = try? JSONEncoder().encode(Saved(id: collection.id, name: collection.name)) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }

    /// Read the collections. Called when the overlay opens.
    func load() async {
        loading = true
        failed = false
        do {
            collections = try await api.collections()
            reconcile()
        } catch {
            failed = true
            print("[collections] read: \(error)")
        }
        loading = false
    }

    /// A saved id the server no longer has reverts to All Channels silently, and the key is
    /// cleared. This matters more than it looks: the server answers an **unknown** filter by
    /// applying no predicate at all and returning every visible channel, not an error and not
    /// an empty list (sources.go:362-364, measured live in Pass 71 §3.2 and again in Pass 72).
    /// A collection deleted on the admin page would otherwise leave this Apple TV showing the
    /// whole lineup under a button still reading the old name.
    private func reconcile() {
        guard let id = selectedId else { return }
        guard let match = collections.first(where: { $0.id == id }) else {
            print("[collections] saved collection \(id) is gone from the server; back to All Channels")
            select(nil)
            return
        }
        if match.name != selectedName { select(match) }
    }
}

/// The drop-down: the app's own overlay of buttons, the same mechanism as
/// `ChannelActionsMenu` (owner, 2026-09-11) — a dimmed backdrop under a surface card of
/// `MenuRow`s, its own focus section, Menu closing it with no change. It lists "All Channels"
/// and then every collection the server returns, in the server's order, showing the `name`
/// only. A collection with no members is listed like any other.
struct CollectionsMenu: View {
    let model: GuideCollectionsModel
    /// The row that was chosen: nil for All Channels.
    let onPick: (ChannelCollection?) -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?

    private static let allRow = "coll:all"
    private static let unavailableRow = "coll:unavailable"
    private static func rowID(_ id: String) -> String { "coll:\(id)" }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.72), Nocturne.bg.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHANNELS")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .tracking(0.12 * Nocturne.TextSize.floor)
                        .foregroundStyle(Nocturne.accent300)
                    Text("Show in the Guide")
                        .font(.nocturne(44, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                }
                MenuRow(
                    title: "All Channels",
                    state: model.selectedId == nil ? "Showing" : "",
                    focused: focused == Self.allRow
                ) {
                    onPick(nil)
                }
                .focused($focused, equals: Self.allRow)
                if model.failed {
                    // Focusable, and it does nothing: without something focusable beside it
                    // the remote's Menu never reaches `.onExitCommand` and leaves the app
                    // instead (measured in Pass 33, TrashManageView.swift:58-62). The
                    // All Channels row above already satisfies that; this row is here so the
                    // failure is spoken rather than drawn as an empty card.
                    MenuRow(title: "Collections unavailable", state: "", focused: focused == Self.unavailableRow) { }
                        .focused($focused, equals: Self.unavailableRow)
                } else if model.loading {
                    LoadingLine()
                } else {
                    ForEach(model.collections) { collection in
                        MenuRow(
                            title: collection.name,
                            state: model.selectedId == collection.id ? "Showing" : "",
                            focused: focused == Self.rowID(collection.id)
                        ) {
                            onPick(collection)
                        }
                        .focused($focused, equals: Self.rowID(collection.id))
                    }
                }
            }
            .padding(44)
            .frame(width: 860, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
        }
        .focusSection()
        .onExitCommand { onClose() }
        // One task, in order, rather than an `.onAppear` racing the read: the All Channels row
        // is drawn from the first frame and takes focus, so nothing is ever unfocused here;
        // then the read lands and focus moves to the current selection if it has a row.
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            focused = Self.allRow
            await model.load()
            guard let id = model.selectedId, model.collections.contains(where: { $0.id == id }) else { return }
            try? await Task.sleep(for: .milliseconds(60))
            focused = Self.rowID(id)
        }
    }
}
