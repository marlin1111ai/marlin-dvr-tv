//
//  GuideSearchScreen.swift
//  Marlin DVR TV
//
//  Search — the eleventh rail entry, directly under Radio (owner, 2026-09-11). Not in the
//  approved design, which draws no search frame anywhere and says so in its own header
//  ("No search", dc:38), so it is built to the app's look — the same route Manage DVR,
//  Favorites, the radar, Radio and the commercial-skip prompt each took.
//
//  What it reads, and why it takes more than one call (Pass 62 §2):
//
//   · `GET /api/guide/find?q=` answers the typing. It matches a case-insensitive substring
//     against the programme **title only**, over every airing whose end is still in the
//     future, and returns at most 20 thin display rows with the true total in `count`.
//   · Clicking a row reconstitutes the airing from `GET /api/guide/search?title=` (owner,
//     2026-09-11), never from `GET /api/guide`. `/api/guide`'s block builder rounds to whole
//     half hours and silently drops listings that end inside a slot already consumed
//     (guide.go:679, :699, :705) — about 3 % of the marlin-dvr project's own measurement — and
//     an airing it drops is one the Guide screen cannot show either, so search would be the
//     only route to it and the one route that failed. `/api/guide/search` walks the stored
//     guide directly and has no such hole. It is whole-title equality, which is exactly right
//     when the title being asked with is the row's own.
//   · `GET /api/channels` supplies the `MergedChannel`; `find` gives only `channelLabel`,
//     which is `"<number> <name>"` joined by one space and cannot be split back reliably.
//   · `GET /api/schedule` supplies the `Job` seed and, more importantly, backs the sheet's
//     `onScheduleChanged` — without the re-read plus the re-join the sheet's writes would
//     leave it holding a stale job (AiringSheet.swift:417-420).
//
//  What the input is, and why (Pass 63 step 1 and Pass 64, both measured on the Apple TV):
//
//   · **The keyboard a plain `TextField` summons is a full-screen takeover.** The screen
//     behind it is blurred out of sight, so the results cannot be seen while typing, and
//     pinning the field to the top of the screen changes nothing — Pass 64 tried exactly that
//     and photographed the same takeover. No layout here could move for it either: every
//     keyboard notification and `UIKeyboardLayoutGuide` is unavailable on tvOS.
//   · **`.searchable` is a different mechanism, and it is the one this screen uses** (owner,
//     2026-09-11, after the Pass 64 probe). tvOS draws a field and a one-row alphabet strip
//     at the top of the screen, ~66 pt tall, and everything below stays visible and
//     reachable: the remote goes down into the results and back up to the strip without the
//     keyboard ever being dismissed.
//   · **The binding updates letter by letter.** So the search is debounced off the binding
//     rather than waiting for a submit. `.onSubmit` is deliberately not relied on: it was not
//     observed firing, and nothing needs it.
//
//  The model is owned above `ScreenShell`, like `HomeModel` and `WeatherModel`, because
//  `ScreenShell.swift:51` puts `.id(current)` on the content and rebuilds the screen from
//  scratch on every visit. A query and its results survive a trip to the rail and back
//  (owner, 2026-09-11); they could not if the model lived in the view.
//

import SwiftUI

@Observable
final class GuideSearchModel {
    enum Phase { case idle, loading, results, empty, failed }

    private let api: APIClient

    /// Bound to the text field. Everything else on this screen is derived from it.
    var query = ""

    private(set) var phase: Phase = .idle
    private(set) var rows: [FindRow] = []
    /// What the server sent before this app's DRM filter — the "20" of "the first 20 of 716".
    private(set) var returned = 0
    /// The server's own `count`: the total before its 20-row cap (guide.go:899-903).
    private(set) var total = 0
    /// The query the rows on screen actually answer, so the empty state can quote it.
    private(set) var searchedFor = ""
    private(set) var error: String?

    var sheet: AiringSelection?
    /// The row being reconstituted, so its line can say so while the reads run.
    private(set) var opening: String?
    private(set) var openError: String?
    /// The row the remote was on, kept across a rail round trip with everything else.
    var lastFocus: String?

    private var channels: [MergedChannel] = []
    private var jobs: [Job] = []
    private var searchTask: Task<Void, Never>?

    init(api: APIClient) {
        self.api = api
    }

    // MARK: The search

    /// A keystroke. The previous search is cancelled and a new one is scheduled behind a short
    /// delay, so walking the on-screen keyboard does not fire a request per letter.
    func queryChanged() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            rows = []
            returned = 0
            total = 0
            searchedFor = ""
            error = nil
            openError = nil
            phase = .idle
            return
        }
        phase = .loading
        openError = nil
        searchTask = Task { [self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(q)
        }
    }

    private func search(_ q: String) async {
        do {
            let answer = try await api.guideFind(q: q)
            guard !Task.isCancelled else { return }
            rows = answer.rows
            returned = answer.returned
            total = answer.count
            searchedFor = q
            error = nil
            phase = rows.isEmpty ? .empty : .results
            print("[search] q=«\(q)» count=\(total) returned=\(returned) playable=\(rows.count)")
        } catch {
            guard !Task.isCancelled else { return }
            rows = []
            returned = 0
            total = 0
            searchedFor = q
            self.error = "\(error)"
            phase = .failed
            print("[search] find failed: \(error)")
        }
    }

    // MARK: Opening a result

    /// Turn a `find` row back into the `AiringSelection` the sheet is built on. Three reads at
    /// worst, one of them cached: the airing, the channel, the schedule.
    func open(_ row: FindRow) async {
        opening = row.id
        openError = nil
        defer { opening = nil }
        do {
            let matches = try await api.guideSearch(title: row.title)
            guard let match = matches.first(where: { $0.channelId == row.channelId && $0.program.start == row.start }) else {
                openError = "The server no longer lists that airing."
                print("[search] no /api/guide/search match for \(row.id) among \(matches.count)")
                return
            }
            // The list is re-read only when the id is not in the copy already held — a channel
            // added or renamed since the screen opened.
            if channels.first(where: { $0.id == row.channelId }) == nil {
                channels = try await api.channels()
            }
            guard let channel = channels.first(where: { $0.id == row.channelId }) else {
                openError = "That airing's channel is not in the channel list."
                print("[search] no channel for \(row.channelId)")
                return
            }
            await refreshSchedule()
            sheet = AiringSelection(channel: channel, program: match.program, job: job(channelId: row.channelId, programStart: row.start))
            print("[search] opened \(row.id) · \(match.program.title) · end=\(match.program.end) seriesId=\(match.program.seriesId ?? "nil")")
        } catch {
            openError = AiringSheet.friendly(error, fallback: "The server could not open that airing.")
            print("[search] open failed: \(error)")
        }
    }

    /// The Guide's own pair (`GuideScreen.swift:145-147`, `:162-168`), which is what the
    /// sheet's `onScheduleChanged` needs on the other side of a write.
    func refreshSchedule() async {
        do {
            jobs = try await api.schedule().jobs
        } catch {
            print("[search] schedule: \(error)")
        }
    }

    func job(channelId: String, programStart: Int) -> Job? {
        jobs.first { $0.channelId == channelId && $0.program.start == programStart }
    }

    // MARK: What the screen draws

    /// The one status line under the field. It never invents a number: `returned` and `total`
    /// are both the server's own, taken before the DRM filter.
    var statusText: String? {
        if let openError { return openError }
        if let row = rows.first(where: { $0.id == opening }) { return "Opening \u{201C}\(row.title)\u{201D}…" }
        switch phase {
        case .idle: return "Type a title. Search matches the title only, from now forward."
        case .loading: return "Searching…"
        case .failed: return nil    // the error line draws instead
        case .empty:
            return total > 0
                ? "No airings match \u{201C}\(searchedFor)\u{201D} on a channel this app can play."
                : "No airings match \u{201C}\(searchedFor)\u{201D}."
        case .results:
            if total > returned {
                return "Showing the first \(returned) of \(total) matches · type more of the title to narrow it"
            }
            return total == 1 ? "1 match" : "\(total) matches"
        }
    }

    /// Where focus should land when the screen is (re)built. The rows survive a rail round
    /// trip, so the remote comes back to the row it left rather than to the top of the list.
    ///
    /// **Nil when there is no row to land on.** Pass 65: the search field is `.searchable`'s
    /// now, drawn and owned by tvOS, so this app has no `@FocusState` binding for it and
    /// cannot send the remote there. With no results the only focusable things on the screen
    /// are the system's own search field and keyboard strip, and the focus engine picks
    /// between them.
    var restoreFocusID: String? {
        if let lastFocus, rows.contains(where: { GuideSearchScreen.rowFocusID($0) == lastFocus }) { return lastFocus }
        if let first = rows.first { return GuideSearchScreen.rowFocusID(first) }
        return nil
    }
}

struct GuideSearchScreen: View {
    @Bindable var model: GuideSearchModel
    let api: APIClient
    let onLeave: () -> Void
    @FocusState private var focused: String?
    /// Bumped when the sheet closes, to rebuild the content and re-run its `.task`. See
    /// `restoreFocusAfterSheet`.
    @State private var generation = 0

    static func rowFocusID(_ row: FindRow) -> String { "row:\(row.id)" }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 26) {
                ScreenHeader("Search", subtitle: "Programme titles in the guide")
                status
                results
                Spacer(minLength: 0)
            }
            // Pass 65, the owner's decision after the Pass 64 probe: the input is tvOS's own
            // inline search — a field and a one-row alphabet strip pinned to the top of the
            // screen, with everything below it still on screen and still reachable. The
            // keyboard a plain `TextField` summons is a full-screen takeover that hides the
            // results (Pass 63 step 1, re-measured in Pass 64 with the field pinned to the
            // top: the container's frame makes no difference).
            //
            // `.automatic` is the only placement tvOS has — `.toolbar`, `.sidebar` and the
            // rest are all `@available(tvOS, unavailable)` — so where the chrome lands is
            // SwiftUI's decision and not this app's. No `NavigationStack` is needed: Pass 64
            // ran that as a control and it drew pixel-for-pixel the same.
            .searchable(text: $model.query, placement: .automatic, prompt: "Type a title")
            .id(generation)
            .task(id: generation) {
                focusSoon { if let id = model.restoreFocusID { focused = id } }
            }

            if let selection = model.sheet {
                AiringSheet(
                    selection: selection,
                    api: api,
                    onWatchLive: {
                        // A live session plays what is on now, and this screen has no Player of
                        // its own to hand it to; closing the sheet is all there is to do here.
                        model.sheet = nil
                        restoreFocusAfterSheet()
                    },
                    onScheduleChanged: {
                        await model.refreshSchedule()
                        return model.job(channelId: selection.channel.id, programStart: selection.program.start)
                    }
                )
            }
        }
        .onChange(of: model.query) { _, _ in model.queryChanged() }
        .onChange(of: focused) { _, new in
            if let new, new.hasPrefix("row:") { model.lastFocus = new }
        }
        .onExitCommand {
            // `AiringSheet` has no Menu handling of its own — the host closes it, and puts the
            // remote back on the row it was opened from (the Guide does the same at
            // `GuideScreen.swift:318-323`). Only when there is no sheet does Menu leave.
            print("[search] menu: sheet=\(model.sheet != nil) focused=\(focused ?? "nil") lastFocus=\(model.lastFocus ?? "nil")")
            if model.sheet != nil {
                model.sheet = nil
                restoreFocusAfterSheet()
            } else {
                onLeave()
            }
        }
    }

    /// Put the remote back on the row the sheet was opened from.
    ///
    /// **This is a rebuild, not an assignment, and the reason is measured.** Writing the row's
    /// id straight into `@FocusState` after the sheet closes does not move focus: on the Apple
    /// TV the run ended with nothing at all focused (`FOCUSALL[after-sheet] []`), and a single
    /// Down press then landed on the *second* row — so SwiftUI held the value while the focus
    /// engine held nothing. Raising the delay did not help. Bumping `generation` re-creates the
    /// content subtree, which is the one mechanism in this app that reliably re-focuses: it is
    /// why a rail round trip comes back on the right row, `ScreenShell.swift:51` doing the same
    /// thing with `.id(current)`. The `.task(id: generation)` on that subtree then asks
    /// `model.restoreFocusID` where to land, exactly as a fresh visit does.
    ///
    /// **Pass 65 re-measured this rather than assuming it, because `.searchable` changed the
    /// focus topology — the keyboard strip is now a sibling above the list.** It changed
    /// nothing here: with the rebuild taken out and the plain assignment put back (clearing
    /// to nil first, then setting the row id behind `focusSoon`), closing the sheet on the
    /// Apple TV left `focused=[]` again — nothing on the screen focused at all. The rebuild
    /// went back in and focus returned to the exact row. Do not remove it a third time
    /// without the device saying so.
    private func restoreFocusAfterSheet() {
        print("[search] closing the sheet, restoring focus to \(model.restoreFocusID ?? "nothing")")
        generation += 1
    }

    @ViewBuilder
    private var status: some View {
        if model.phase == .failed, let error = model.error {
            ErrorLine(text: error)
        } else if let text = model.statusText {
            Text(text)
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(model.openError == nil ? Nocturne.neutral500 : Nocturne.neutral200)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var results: some View {
        if model.rows.isEmpty {
            EmptyView()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    ForEach(model.rows) { row in
                        let id = Self.rowFocusID(row)
                        Button {
                            Task { await model.open(row) }
                        } label: {
                            SearchResultRow(row: row, focused: focused == id, opening: model.opening == row.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .disabled(model.sheet != nil)
        }
    }
}

/// One result, drawn from exactly what `GET /api/guide/find` returns: the title, the episode
/// title it calls `subtitle`, and the channel, time and length it has already formatted.
/// `channelId` is identity rather than display, and `drm` never reaches here — a DRM row is
/// filtered out before the list is built (`ChannelFilter.swift`).
struct SearchResultRow: View {
    let row: FindRow
    let focused: Bool
    let opening: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(row.title)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                }
                Text("\(row.channelLabel) · \(row.when) · \(row.duration)")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if opening {
                Text("Opening…")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.accent200)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .overlay { Capsule().strokeBorder(Nocturne.accent600, lineWidth: 1) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 22)
        .background(focused ? Nocturne.accent.mix(with: Nocturne.surface, by: 0.9) : Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused)
    }
}
