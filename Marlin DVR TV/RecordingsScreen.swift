//
//  RecordingsScreen.swift
//  Marlin DVR TV
//
//  Recordings, frame 5b (dc:500-538) with the 4a poster cards (dc:375-394): the header
//  counts from GET /api/library (shows, recordings; the TB figure is omitted — no endpoint
//  supplies it, Pass 4 §3.7), the three shelves of the response, six cards per row, the
//  unwatched badge. Selecting a show opens show detail; Menu returns to the shelves.
//
//  Pass 10 briefly put a "Manage DVR" row above the shelves; Pass 10B moved that entry to
//  the rail (owner, 2026-09-06), so this screen is frame 5b again with nothing added.
//
//  Pass 31: the shelves used to be read once, by the `.task` below, and opening show detail
//  does not end that task — so a recording deleted in the detail screen left the shelves
//  drawn from the library as it was before the delete, until the owner left Recordings
//  altogether and `ScreenShell`'s `.id(current)` built the screen again. `onLibraryChanged`
//  now re-reads `GET /api/library` the moment a write in show detail changes it.
//
//  Pass 91: the server's first shelf, "Recently Watched", is no longer drawn. In its place and
//  in its position the screen draws **Continue watching** — the recordings THIS Apple TV has an
//  unfinished saved position on, newest position first, from `ResumeStore` (owner, 2026-09-16).
//  The two shelves answer different questions: "Recently Watched" is a server fact, shared with
//  the other Apple TV and counted per show; a resume position is local to one Apple TV and
//  belongs to one recording. The two Apple TVs therefore show different cards here, deliberately.
//  The other two shelves — "Recently Updated" and "Recently Added" — are the server's, untouched.
//

import SwiftUI

/// One card on the Continue watching shelf: a recording this Apple TV has an unfinished saved
/// position on, carrying the show it belongs to so that selecting it opens show detail exactly
/// as the other shelves' cards do.
struct ContinueItem: Identifiable {
    let episode: Episode
    let show: ShowSummary
    let entry: ResumeStore.Entry
    var id: String { episode.id }

    /// The line under the title, where a server shelf's card carries "4 episodes". One recording
    /// has no episode count, so it names the recording and how far into it this Apple TV is —
    /// the same words frame 5d's "Resume S9 E11 · 22 min in" uses, from the same store.
    var line: String {
        let position = ResumeStore.label(for: entry)
        if episode.season > 0, episode.episode > 0 {
            return "S\(episode.season) E\(episode.episode) · \(position)"
        }
        if !episode.episodeTitle.isEmpty { return "\(episode.episodeTitle) · \(position)" }
        return position
    }
}

@Observable
final class RecordingsModel {
    private let api: APIClient
    private(set) var library: LibraryResponse?
    /// The Continue watching shelf's cards, newest saved position first. Empty means the shelf
    /// is not drawn at all (Pass 91).
    private(set) var continueWatching: [ContinueItem] = []
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            library = try await api.library(limit: 6)
            error = nil
        } catch {
            self.error = "\(error)"
            print("[recordings] library: \(error)")
        }
        await loadContinueWatching()
        loaded = true
    }

    /// Resolve this Apple TV's saved positions into cards.
    ///
    /// **Why this needs the show reads.** `ResumeStore` is keyed by recording id and stores a
    /// position, a duration and a save time — no show, no title, no art. `GET /api/library`
    /// answers shows and never recording ids, and the server has no per-recording read: the app
    /// measured `GET /api/library/recordings/{id}` and three neighbouring spellings at 404 on
    /// 1.8.2 (Pass 91 §2). So the only route from a saved position to the recording it belongs to
    /// is `GET /api/library/shows/{id}` — the read show detail already makes — over the shows the
    /// library answered with. No new route, and nothing new stored.
    ///
    /// It costs nothing when there is nothing to resolve: with no unfinished saved position on
    /// this Apple TV it makes no request at all, and it stops as soon as every saved position has
    /// been placed rather than walking the rest of the library.
    ///
    /// A recording that is trashed, or whose show is past the `limit: 6` the shelves are read at,
    /// is not found and simply does not appear — the shelf never invents a card.
    private func loadContinueWatching() async {
        var wanted = Dictionary(uniqueKeysWithValues:
            ResumeStore.saved()
                .filter { ResumeStore.isResumable($0.entry) && !ResumeStore.isFinished($0.entry) }
                .map { ($0.id, $0.entry) })
        guard !wanted.isEmpty, let library else {
            continueWatching = []
            return
        }
        var found: [ContinueItem] = []
        for show in Self.distinctShows(in: library) {
            if wanted.isEmpty { break }
            let response: ShowResponse
            do {
                response = try await api.show(id: show.id)
            } catch {
                print("[recordings] continue watching, \(show.id): \(error)")
                continue
            }
            for episode in response.episodes {
                guard let entry = wanted.removeValue(forKey: episode.id) else { continue }
                found.append(ContinueItem(episode: episode, show: show, entry: entry))
            }
        }
        // The shelf's order is the store's, not the server's: newest saved position first.
        continueWatching = found.sorted { $0.entry.savedAt > $1.entry.savedAt }
    }

    /// The shows `GET /api/library` answered with, each once, in the order its sections list them.
    /// A show is normally in more than one section.
    private static func distinctShows(in library: LibraryResponse) -> [ShowSummary] {
        var seen = Set<String>()
        return library.sections.flatMap(\.items).filter { seen.insert($0.id).inserted }
    }
}

struct RecordingsScreen: View {
    let api: APIClient
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @State private var model: RecordingsModel
    @State private var selected: ShowSummary?
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.api = api
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: RecordingsModel(api: api))
    }

    var body: some View {
        Group {
            if let selected {
                ShowDetailScreen(api: api, show: selected, onPlay: onPlay, onLibraryChanged: reloadShelves)
            } else {
                shelves
            }
        }
        .task {
            await model.load()
            let id = firstCardID
            focusSoon { focused = id ?? "loading" }
        }
        .onExitCommand {
            if selected != nil {
                selected = nil
                let id = firstCardID
                focusSoon { focused = id ?? "loading" }
            } else {
                onLeave()
            }
        }
    }

    private var subtitle: String? {
        guard let lib = model.library else { return nil }
        return "\(lib.shows) shows · \(lib.recordings) recordings"
    }

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 38) {
            ScreenHeader("Recordings", subtitle: subtitle) {
                Text("Watched and keep flags are shared with the other Apple TV")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if let error = model.error, model.library == nil {
                ErrorLine(text: error)
            } else if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // Continue watching, in the place and the order the server's "Recently
                    // Watched" held. With no cards it is not drawn at all — no heading, no
                    // "Nothing yet." line, no empty row — and the two server shelves below it
                    // close up (Pass 91 step 4).
                    if !model.continueWatching.isEmpty { continueShelf }
                    ForEach(serverSections, id: \.key) { section in
                        VStack(alignment: .leading, spacing: 18) {
                            Text(section.label)
                                .font(.nocturne(34, .medium))
                                .foregroundStyle(Nocturne.text)
                            if section.items.isEmpty {
                                Text("Nothing yet.")
                                    .font(.nocturne(Nocturne.TextSize.floor))
                                    .foregroundStyle(Nocturne.neutral600)
                                    .frame(height: 60)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 30) {
                                        ForEach(section.items) { show in
                                            let id = "\(section.key):\(show.id)"
                                            Button {
                                                selected = show
                                            } label: {
                                                PosterCard(show: show, focused: focused == id)
                                            }
                                            .buttonStyle(BareButtonStyle())
                                            .focused($focused, equals: id)
                                        }
                                    }
                                    .padding(.vertical, 44)
                                    .padding(.horizontal, 40)
                                }
                            }
                        }
                    }
                }
            }
        }
        .defaultFocus($focused, firstCardID ?? "loading")
    }

    /// The server's shelves as they are drawn: its own, minus "Recently Watched", whose place
    /// Continue watching has taken (DECISIONS.md, 2026-09-16 (Pass 91)). The match is on the
    /// server's `key` (`Models.swift:335`) and never on `label`, which is display text.
    private var serverSections: [LibrarySection] {
        (model.library?.sections ?? []).filter { $0.key != Self.recentlyWatchedKey }
    }

    /// Continue watching — this Apple TV's own shelf. Its cards are recordings, so the line under
    /// the title names the recording instead of counting episodes and there is no "n new" badge;
    /// everything else about the card is the shelf card Pass 47 settled, because it is the same
    /// `PosterCard`.
    ///
    /// Selecting a card opens show detail for the recording's show — the same destination the
    /// other shelves' cards have, and the screen that then offers "Resume S9 E11 · 22 min in"
    /// from this same store.
    private var continueShelf: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Continue watching")
                .font(.nocturne(34, .medium))
                .foregroundStyle(Nocturne.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 30) {
                    ForEach(model.continueWatching) { item in
                        let id = "\(Self.continueKey):\(item.id)"
                        Button {
                            selected = item.show
                        } label: {
                            PosterCard(show: item.show, focused: focused == id, subtitle: item.line, badge: false)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: id)
                    }
                }
                .padding(.vertical, 44)
                .padding(.horizontal, 40)
            }
        }
    }

    /// The server's key for the shelf Continue watching replaces, and the app's own key for it —
    /// which cannot collide with a server section key, and is per recording rather than per show.
    private static let recentlyWatchedKey = "recently-watched"
    private static let continueKey = "continue"

    private var firstCardID: String? {
        if let first = model.continueWatching.first { return "\(Self.continueKey):\(first.id)" }
        guard let section = serverSections.first(where: { !$0.items.isEmpty }), let show = section.items.first else { return nil }
        return "\(section.key):\(show.id)"
    }

    /// Every card id currently on the shelves — the ids the cards focus on. Continue watching's
    /// are keyed by recording, the server shelves' by "section:show". A card on the undrawn
    /// "Recently Watched" section is deliberately not in here: focus can never be on it.
    private var cardIDs: Set<String> {
        var ids = Set(model.continueWatching.map { "\(Self.continueKey):\($0.id)" })
        for section in serverSections {
            ids.formUnion(section.items.map { "\(section.key):\($0.id)" })
        }
        return ids
    }

    /// A write inside show detail has changed the library these shelves are drawn from — a
    /// deleted recording above all. Re-read it straight away, while the detail screen is still
    /// on top, so the shelves are already right the moment Menu comes back to them.
    ///
    /// It is a re-read and not a local edit on purpose: an episode count, the unwatched badge,
    /// which shelves a show sits on and the header's own totals are all the server's, and the
    /// `limit: 6` means one delete can pull a seventh show into view. Nothing here can be
    /// computed from the episode the server just answered with.
    private func reloadShelves() {
        Task {
            await model.load()
            // The card that had focus may be gone now. Repair that, and only that: if the
            // remote is in the rail `focused` is nil and is left alone, so a reload cannot
            // pull focus out of the rail (the property Pass 25 measured for the timed reloads).
            guard selected == nil, let current = focused, current != "loading",
                  !cardIDs.contains(current) else { return }
            focusSoon { focused = firstCardID ?? "loading" }
        }
    }
}

/// The 4a poster card (dc:381-392): 2:3 art, the unwatched badge, title and count below;
/// focused = larger, lifted 22 pt, 4 pt ring, ambient shadow (dc:1273-1275).
///
/// **The focused card grows its real layout box, it does not scale.** `dc:1273` gives the two
/// states as sizes — `w: 296 : 252, h: 404 : 344, lift: -22 : 0` — and `dc:382-383` applies them
/// as the container's `width` and the art's `height`, with only `translateY(-22px)` moving it.
/// A `scaleEffect` was used here until Pass 47 and had to go: it is a render transform, so it
/// changed nothing about layout and grew the card about its centre, throwing ~38 pt upward on
/// top of the 22 pt lift. That overflowed the shelf's 44 pt of top padding and the horizontal
/// `ScrollView` clipped the card's top edge (Pass 46). Growing the box instead means the only
/// thing above the card is the lift the design asks for.
///
/// Two consequences, both deliberate and both the design's own behaviour: the row **reflows** —
/// cards after the focused one shift right by 44 pt, and the shelf grows 60 pt taller while it
/// holds focus — and the **title and count do not change size**, because `dc:389-390` fix them
/// at 26 pt and 23 pt in both states. The scale used to enlarge them too.
struct PosterCard: View {
    let show: ShowSummary
    let focused: Bool
    /// Pass 91: Continue watching's cards are recordings, not shows. `subtitle` replaces the
    /// episode count under the title and `badge: false` drops the "n new" count, which belongs
    /// to a show. Both default to the card exactly as Pass 47 left it, so the server's shelves
    /// draw unchanged.
    var subtitle: String? = nil
    var badge: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ServerImage(path: show.art) {
                ArtPlaceholder()
            }
            .frame(width: focused ? 296 : 252, height: focused ? 404 : 344)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if badge, show.unwatched > 0 {
                    Text("\(show.unwatched) new")
                        .font(.nocturne(Nocturne.TextSize.floor, .semibold))
                        .foregroundStyle(Nocturne.bg)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Nocturne.accent, in: Capsule())
                        .padding(14)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : Nocturne.neutral900, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
            .shadow(color: focused ? Nocturne.Focus.shadowColor : .clear, radius: Nocturne.Focus.shadowRadius, y: Nocturne.Focus.shadowY)
            Text(show.title)
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(Nocturne.text)
                .lineLimit(2)
            Text(subtitle ?? "\(show.count) episode\(show.count == 1 ? "" : "s")")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral500)
        }
        .frame(width: focused ? 296 : 252, alignment: .leading)
        .offset(y: focused ? -22 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}
