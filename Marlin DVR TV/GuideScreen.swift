//
//  GuideScreen.swift
//  Marlin DVR TV
//
//  The Guide, frames 3a (comfortable: 8 rows, a 2-hour window in four 30-minute columns)
//  and 3c (paged past midnight). Rows are re-laid from each program's start/end, not the
//  server's 30-minute `span` blocks (Pass 4 §3.4). Forward-only from the current half hour;
//  "+12h" pages ahead, fetching 24 hours (48 slots) per request while the server has
//  listings; when the window crosses midnight the header and the column label name the day.
//  "↩ Now" and Menu snap back to now; Menu at now leaves the Guide. Marks ● (recording or
//  set to record) and ◆ (covered by a series pass) come from joining GET /api/schedule jobs
//  to the grid on channelId + program.start (passes.go:53-77). Selecting a cell opens the
//  airing sheet, whose two writes (sweep 4) refetch the schedule so the marks redraw.
//  Pass 9: a click-and-hold is delivered by `RemoteHold` (window press recognizer) and acted
//  on here against whatever this screen has focused — a programme cell opens the sheet, a
//  channel cell in the left column opens the channel's Favorite menu.
//  Pass 72: the header carries a collections button between "Guide" and the date range. It
//  opens `CollectionsMenu`; picking a collection re-runs the fetch with `filter=<id>`, and the
//  server returns that collection's members in the owner's own order (sources.go:389-401).
//  The selection itself lives in `GuideCollectionsModel`, above the shell, because this
//  screen is rebuilt on every rail visit (ScreenShell.swift:55).
//  Pass 77: Right on the last visible cell of a row moves the window forward one slot (30 min) —
//  the time strip, every row and the header move together because all three are derived from
//  `GuideModel.windowStart` and nothing else. Forward only; Left, Menu, "↩ Now" and "+12h" are
//  untouched. The press is received through `.onMoveCommand` on the grid's own `ScrollView`, which
//  is where Pass 76 measured it arriving, and the edge is read from the settled focus because the
//  focus write and the command delivery race (see `gridMoved`).
//  Pass 79: the Guide keeps up with the clock. A once-a-minute beat on this screen's own `.task`
//  republishes `GuideModel.now` — which is what makes `isAtNow`, the footer, the strip's "· now"
//  and the "↩ Now · 10:47" pill tell the truth as the clock passes, because a `Date()` read inside
//  a view body is observed by nothing and so redraws nothing — and, while the window is sitting at
//  a half hour the clock has already left, advances it to the new current half hour with the same
//  single write to `windowStart` that "+12h", "↩ Now" and a Pass 77 nudge use. A window scrolled
//  ahead is never moved. The beat is a `.task` on this screen, so it stops when the screen does.
//

import SwiftUI

enum GuideMark {
    /// ● while the recorder is running, ● for a Record Now booking that has not started,
    /// ◆ for an airing a series pass covers. The design draws two colours (dc:1183-1189):
    /// green for the recording mark, gold for the pass mark.
    case recording, scheduled, pass

    static let green = Color(hex: 0x57B083)
    static let gold = Color(hex: 0xD6A94E)

    var tag: String {
        switch self {
        case .recording: return "● RECORDING"
        case .scheduled: return "● SCHEDULED"
        case .pass: return "◆ SERIES PASS"
        }
    }

    var color: Color {
        switch self {
        case .recording, .scheduled: return Self.green
        case .pass: return Self.gold
        }
    }
}

struct GuideCellItem: Identifiable {
    let channel: MergedChannel
    let program: Program
    let mark: GuideMark?
    let job: Job?
    let windowStart: Int
    let windowEnd: Int

    var id: String { "\(channel.id)@\(program.start)" }

    /// Start and end of this program as fractions of the window, clipped to it.
    var startFraction: CGFloat { CGFloat(max(program.start, windowStart) - windowStart) / CGFloat(windowEnd - windowStart) }
    var endFraction: CGFloat { CGFloat(min(program.end, windowEnd) - windowStart) / CGFloat(windowEnd - windowStart) }
}

@Observable
final class GuideModel {
    static let windowSeconds = 7200
    static let pageSeconds = 43200
    static let fetchSlots = 48
    static let slotSeconds = 1800

    private let api: APIClient
    /// Pass 72: the chosen collection, owned above the shell. Every fetch reads the filter
    /// from here, so all three callers of `fetch(from:)` carry the selection by construction.
    private let collections: GuideCollectionsModel
    private(set) var rows: [GuideRow] = []
    private(set) var jobs: [Job] = []
    private(set) var fetchStart = 0
    private(set) var fetchEnd = 0
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var endOfListings = false
    private(set) var windowStart = 0
    var sheet: AiringSelection?

    init(api: APIClient, collections: GuideCollectionsModel) {
        self.api = api
        self.collections = collections
    }

    var windowEnd: Int { windowStart + Self.windowSeconds }
    var slotStarts: [Int] { (0..<4).map { windowStart + $0 * Self.slotSeconds } }

    /// Pass 79: the wall clock as this screen last read it, republished by every beat of `tick()`.
    /// Everything the Guide derives from "now" is derived from **this** and never from `Date()`:
    /// a `Date()` read inside a view body is observed by nothing, so nothing redraws when the clock
    /// moves — which is the whole of the defect the owner reported on 2026-09-12.
    private(set) var now = Date()

    /// The half hour `now` falls in. The same truncation the server performs (guide.go:659-663) and
    /// the same arithmetic as `TimeFormat.currentHalfHour`, over the observed clock above rather
    /// than over `Date()`, so that `isAtNow` — and the footer, the strip's "· now" and the two
    /// header pills that turn on it — re-evaluate when a beat moves the clock.
    var nowHalfHour: Int { Int(now.timeIntervalSince1970 / 1800) * 1800 }

    var isAtNow: Bool { windowStart == nowHalfHour }

    /// True when the window's start and end fall on different days (frame 3c header).
    var crossesMidnight: Bool {
        !TimeFormat.sameDay(TimeFormat.date(windowStart), TimeFormat.date(windowEnd - 1))
    }

    func loadNow() async {
        now = Date()
        windowStart = nowHalfHour
        await fetch(from: windowStart)
    }

    func pageForward() async {
        guard !endOfListings else { return }
        windowStart += Self.pageSeconds
        if windowEnd > fetchEnd { await fetch(from: windowStart) }
    }

    /// Pass 77: the start of the last slot in the fetched range that has a listing in it — the point
    /// the window may not advance past. It reads the same thing `endOfListings` reads, a block's
    /// `program`, so the two can never disagree: nil here is exactly `endOfListings == true`.
    var lastListedSlot: Int? {
        var latest = 0
        for row in rows {
            for block in row.blocks {
                if let end = block.program?.end, end > latest { latest = end }
            }
        }
        guard latest > 0 else { return nil }
        return (latest - 1) / Self.slotSeconds * Self.slotSeconds
    }

    /// Pass 77: one Right press at a row's right-hand edge moves the window forward **one slot**
    /// (owner, 2026-09-12). Forward only, never past `lastListedSlot`, and it refetches by the same
    /// rule `pageForward()` uses — so the time strip, every row and the header all move together,
    /// because all three are derived from `windowStart` and nothing else.
    ///
    /// Returns true when the window actually moved, which is the caller's signal to settle focus.
    @discardableResult
    func nudgeForward() async -> Bool {
        guard let limit = lastListedSlot else { return false }
        let next = windowStart + Self.slotSeconds
        guard next <= limit else { return false }
        windowStart = next
        if windowEnd > fetchEnd { await fetch(from: windowStart) }
        return true
    }

    /// Pass 79: one beat of the screen's clock, once a minute while the Guide is on screen
    /// (owner, 2026-09-12).
    ///
    /// It **always** republishes `now`, which is what makes `isAtNow`, the footer, the strip's
    /// "· now" and the "↩ Now · 10:47" pill tell the truth as the clock passes. It advances the
    /// window **only when the clock has already left the half hour the window is sitting at**:
    /// `windowStart` is only ever set to the current half hour or advanced past it, so
    /// `windowStart < nowHalfHour` is exactly "the window was at now and the clock has moved on".
    /// A window the owner has scrolled ahead is therefore never moved, and neither is one the clock
    /// has merely caught up with — that one simply becomes `isAtNow` again.
    ///
    /// The roll is one write to `windowStart`, so the time strip, every row, the header's date
    /// range and the "· now" marker move together: all of them are derived from it and from nothing
    /// else. **The refetch is the existing rule** — the same line `snapToNow()` and
    /// `nudgeForward()` use — so a beat inside the fetched 24 hours makes no request at all.
    ///
    /// Returns true when the window actually moved, which is the caller's signal to settle focus.
    @discardableResult
    func tick() async -> Bool {
        now = Date()
        guard windowStart < nowHalfHour else { return false }
        windowStart = nowHalfHour
        if windowStart < fetchStart || windowEnd > fetchEnd { await fetch(from: windowStart) }
        return true
    }

    /// Pass 72: a collection was chosen or cleared. Re-run the fetch at the window the Guide
    /// is already showing, so the pick does not move the clock.
    func reloadForCollection() async {
        await fetch(from: windowStart)
    }

    func snapToNow() async {
        now = Date()
        let start = nowHalfHour
        windowStart = start
        if start < fetchStart || start + Self.windowSeconds > fetchEnd { await fetch(from: start) }
    }

    private func fetch(from start: Int) async {
        do {
            async let guide = api.guide(start: start, slots: Self.fetchSlots, filter: collections.selectedId)
            async let schedule = api.schedule()
            let g = try await guide
            // Pass 72: the server validates nothing a collection stores, so a member id held
            // twice comes back as two rows carrying the same channel (sources.go:396-400).
            // `GuideRow.id` is the channel id and the grid is a plain `Identifiable` ForEach,
            // which duplicate ids break: keep the first occurrence and drop the rest.
            var seen = Set<String>()
            rows = g.channels.filter { seen.insert($0.id).inserted }
            fetchStart = g.start
            fetchEnd = g.start + g.slots * Self.slotSeconds
            endOfListings = !rows.contains { $0.blocks.contains { $0.program != nil } }
            do {
                jobs = try await schedule.jobs
            } catch {
                jobs = []
                print("[guide] schedule: \(error)")
            }
            error = nil
        } catch {
            self.error = "\(error)"
            print("[guide] guide: \(error)")
        }
        loaded = true
    }

    /// The programs of one row that overlap the window, once each, with their marks.
    func cells(for row: GuideRow) -> [GuideCellItem] {
        var seen = Set<Int>()
        var out: [GuideCellItem] = []
        for block in row.blocks {
            guard let p = block.program, p.end > windowStart, p.start < windowEnd, !seen.contains(p.start) else { continue }
            seen.insert(p.start)
            let job = job(channelId: row.channel.id, programStart: p.start)
            out.append(GuideCellItem(channel: row.channel, program: p, mark: mark(for: job), job: job, windowStart: windowStart, windowEnd: windowEnd))
        }
        return out
    }

    func job(channelId: String, programStart: Int) -> Job? {
        jobs.first { $0.channelId == channelId && $0.program.start == programStart }
    }

    /// Pass 9: a channel whose favourite flag this screen changed, until the next fetch.
    private var favouriteOverrides: [String: Bool] = [:]

    func favourite(_ channel: MergedChannel) -> Bool {
        favouriteOverrides[channel.id] ?? channel.favorite
    }

    func setFavourite(_ value: Bool, for channel: MergedChannel) {
        favouriteOverrides[channel.id] = value
    }

    /// Sweep 4: after "Record this airing" or "Record the series", the marks and the sheet
    /// redraw from the schedule the server now computes (passes.go:331-493).
    func refreshSchedule() async {
        do {
            jobs = try await api.schedule().jobs
        } catch {
            print("[guide] schedule refresh: \(error)")
        }
    }

    /// ● RECORDING while the recorder runs, ● SCHEDULED for a Record Now booking that has
    /// not started (the manual job the sheet's write creates, passes.go:60), ◆ SERIES PASS
    /// for an airing a pass covers.
    private func mark(for job: Job?) -> GuideMark? {
        guard let job else { return nil }
        if job.status == "Recording" { return .recording }
        guard job.status == "Queued" || job.status == "Conflict" else { return nil }
        return job.passId == "manual" ? .scheduled : .pass
    }

    /// "Sat Sep 5 · 11:30 PM – 1:30 AM", or with the next day named when the window crosses midnight.
    var windowLabel: String {
        let s = TimeFormat.date(windowStart), e = TimeFormat.date(windowEnd)
        if crossesMidnight {
            return "\(TimeFormat.shortDay(s)) · \(TimeFormat.clock(s)) → \(TimeFormat.shortDay(e)) · \(TimeFormat.clock(e))"
        }
        return "\(TimeFormat.shortDay(s)) · \(TimeFormat.timeRange(windowStart, windowEnd))"
    }
}

struct GuideScreen: View {
    let api: APIClient
    /// Pass 72: the chosen collection. Owned above the shell so it survives a rail visit.
    let collections: GuideCollectionsModel
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @Environment(RemoteHold.self) private var hold
    @State private var model: GuideModel
    @FocusState private var focused: String?
    @State private var lastCell: String?
    @State private var channelMenu: MergedChannel?
    @State private var collectionsOpen = false
    /// Pass 77: when the focus engine last stepped focus rightward inside a row. `gridMoved` reads
    /// it to tell a Right press the engine consumed from one it refused.
    @State private var engineSteppedRightAt = Date.distantPast

    /// The focus id of a channel cell in the left column.
    static func channelFocusID(_ channel: MergedChannel) -> String { "ch:\(channel.id)" }

    init(api: APIClient, collections: GuideCollectionsModel, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.api = api
        self.collections = collections
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: GuideModel(api: api, collections: collections))
    }

    /// DECISIONS.md 2026-09-06: a click on a program airing now plays it; a click on a
    /// future airing opens the sheet; press-and-hold on a current cell opens the sheet.
    private func select(_ cell: GuideCellItem) {
        let now = Int(Date().timeIntervalSince1970)
        if cell.program.start <= now && now < cell.program.end {
            onPlay(.live(channel: cell.channel, program: cell.program))
        } else {
            model.sheet = AiringSelection(channel: cell.channel, program: cell.program, job: cell.job)
        }
    }

    /// A hold: open the sheet for the focused programme cell, or the Favorite menu for the
    /// focused channel cell. Anything else focused is left alone.
    private func handleHold() {
        guard model.sheet == nil, channelMenu == nil, !collectionsOpen, let focus = focused else { return }
        if focus.hasPrefix("ch:") {
            guard let row = model.rows.first(where: { Self.channelFocusID($0.channel) == focus }) else { return }
            hold.armSwallow()
            channelMenu = row.channel
            return
        }
        for row in model.rows {
            if let cell = model.cells(for: row).first(where: { $0.id == focus }) {
                hold.armSwallow()
                model.sheet = AiringSelection(channel: cell.channel, program: cell.program, job: cell.job)
                return
            }
        }
    }

    private static let channelColumnWidth: CGFloat = 300
    private static let columnGap: CGFloat = 18
    private static let rowHeight: CGFloat = 82

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 34)
                columnHeader
                    .padding(.bottom, 16)
                if let error = model.error, model.rows.isEmpty {
                    ErrorLine(text: error)
                } else if !model.loaded {
                    LoadingLine().focusable().focused($focused, equals: "loading")
                } else if model.rows.isEmpty, let name = collections.selectedName {
                    // Pass 72 step 5. Non-interactive on purpose: the remote is not stranded
                    // by it, because the reload puts focus on the collections button above
                    // (`focused = firstCellID ?? "collections"`), which is drawn whatever the
                    // grid holds.
                    Text("Nothing in \(name) right now")
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(model.rows) { row in
                            GuideRowView(
                                row: row,
                                cells: model.cells(for: row),
                                favourite: model.favourite(row.channel),
                                hold: hold,
                                focused: $focused,
                                channelColumnWidth: Self.channelColumnWidth,
                                columnGap: Self.columnGap,
                                rowHeight: Self.rowHeight,
                                onSelect: { cell in select(cell) }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
                .disabled(model.sheet != nil || channelMenu != nil || collectionsOpen)
                // Pass 77: the grid's own `ScrollView` is the attachment point, and that is
                // measured rather than chosen — Pass 76 put one instance here and one on this
                // screen's root `ZStack` and found all 22 move commands arrived at this one and
                // none at the root. A handler on the root sees nothing.
                .onMoveCommand { direction in gridMoved(direction) }
                legend
                    .padding(.top, 16)
            }
            if collectionsOpen {
                CollectionsMenu(
                    model: collections,
                    onPick: { pick($0) },
                    onClose: closeCollections
                )
            }
            if let channel = channelMenu {
                ChannelActionsMenu(
                    channel: channel,
                    isFavourite: model.favourite(channel),
                    api: api,
                    onApplied: { value in
                        model.setFavourite(value, for: channel)
                        closeChannelMenu()
                    },
                    onClose: closeChannelMenu
                )
            }
            if let selection = model.sheet {
                AiringSheet(
                    selection: selection,
                    api: api,
                    onWatchLive: {
                        model.sheet = nil
                        onPlay(.live(channel: selection.channel, program: selection.program))
                    },
                    onScheduleChanged: {
                        await model.refreshSchedule()
                        return model.job(channelId: selection.channel.id, programStart: selection.program.start)
                    }
                )
            }
        }
        .defaultFocus($focused, "loading")
        .task {
            await model.loadNow()
            focusSoon { focused = firstCellID ?? "collections" }
            // Pass 79: the clock. It is a `.task` on this screen and nothing else, which is what
            // ties it to the screen's own lifetime: `ScreenShell.swift:57` puts `.id(current)` on
            // the content and destroys the Guide on every rail visit, and SwiftUI cancels a
            // destroyed view's `.task`, so no beat can outlive the screen as an orphan. The count
            // is printed when the loop ends, which is the evidence that it ended.
            var beats = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.secondsToNextMinute()))
                guard !Task.isCancelled else { break }
                beats += 1
                await beat()
            }
            print("[guide] clock stopped after \(beats) beat(s)")
        }
        .onChange(of: focused) { old, new in
            if let new, new.contains("@") { lastCell = new }
            // Pass 77: a step rightward inside one row is how a Right press the focus engine
            // consumed is told apart from one it refused. See `gridMoved`.
            if Self.isRightwardStep(from: old, to: new) { engineSteppedRightAt = Date() }
        }
        .onChange(of: hold.holds) { _, _ in handleHold() }
        .onExitCommand {
            print("[guide] menu: sheet=\(model.sheet != nil) channelMenu=\(channelMenu != nil) collections=\(collectionsOpen) atNow=\(model.isAtNow)")
            if collectionsOpen {
                closeCollections()
            } else if channelMenu != nil {
                closeChannelMenu()
            } else if model.sheet != nil {
                model.sheet = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    focused = lastCell
                }
            } else if !model.isAtNow {
                Task {
                    await model.snapToNow()
                    focusSoon { focused = firstCellID ?? "collections" }
                }
            } else {
                onLeave()
            }
        }
    }

    // MARK: Pass 77 — Right at a row's right-hand edge moves the window forward one slot

    /// How long the focus engine is given to settle before the edge is read. Pass 76 measured that
    /// the `@FocusState` write and the `.onMoveCommand` delivery race and arrive in either order, so
    /// the edge cannot be read at receipt; it is read here instead.
    private static let nudgeSettle: Duration = .milliseconds(150)
    /// How close to a press a rightward step has to be to count as that press's own work. Pass 76
    /// measured the gap between the focus write and the command at a few milliseconds in either
    /// direction, so this is generous by an order of magnitude.
    private static let nudgeGrace: TimeInterval = 0.15

    /// `"<channel id>@<program start>"` split back into its halves. A channel id is
    /// `"<sourceId>:<guid>"` (sources.go:319) and never contains `"@"`, so the last `"@"` is the
    /// separator. Nil for anything that is not a programme cell id — a channel cell, `"collections"`,
    /// `"loading"`, `"now"`, `"page"`.
    static func cellKey(_ id: String) -> (channel: String, start: Int)? {
        guard let at = id.lastIndex(of: "@"), let start = Int(id[id.index(after: at)...]) else { return nil }
        return (String(id[..<at]), start)
    }

    /// True when a focus change is the engine walking **right inside one row**: either on to a later
    /// programme on the same channel, or that row's channel cell handing over to its first programme
    /// cell. Nothing else on this screen produces one — a Left step goes to an earlier start, Up and
    /// Down change channel, and a nudge's own landing is the leftmost cell, which is earlier than the
    /// cell it came from. That is what makes this a safe test for "the engine took this press".
    static func isRightwardStep(from old: String?, to new: String?) -> Bool {
        guard let old, let new, let n = cellKey(new) else { return false }
        if let o = cellKey(old) { return o.channel == n.channel && n.start > o.start }
        return old == "ch:\(n.channel)"
    }

    /// The grid received a directional command. **Only `.right` does anything**, and only when the
    /// focused cell is the last one its own row has inside the window.
    ///
    /// **Why the edge is read after a delay and not at receipt.** Pass 76 measured on Home Theater
    /// that the `@FocusState` write and the `.onMoveCommand` delivery race: of seven presses the
    /// engine acted on, **six delivered the command after the focus write** and one before it. So at
    /// receipt `focused` is sometimes the cell the engine has just arrived at — and reading the edge
    /// there would make the press that walks *on to* the last cell nudge the window as well. One
    /// press, two actions, which is Pass 29's defect in another costume. The edge is therefore read
    /// from the settled value, and a press the engine consumed is recognised by the rightward step
    /// it made rather than by any before/after comparison of `focused`.
    private func gridMoved(_ direction: MoveCommandDirection) {
        guard direction == .right, model.sheet == nil, channelMenu == nil, !collectionsOpen else { return }
        let pressedAt = Date()
        Task {
            try? await Task.sleep(for: Self.nudgeSettle)
            guard engineSteppedRightAt < pressedAt.addingTimeInterval(-Self.nudgeGrace) else { return }
            guard let id = focused, id == lastCellID(inRowOf: id) else { return }
            await nudge(from: id)
        }
    }

    /// The id of the last cell the focused cell's own row has in the window, or nil when the focused
    /// view is not a programme cell at all.
    private func lastCellID(inRowOf id: String) -> String? {
        guard let key = Self.cellKey(id),
              let row = model.rows.first(where: { $0.channel.id == key.channel }) else { return nil }
        return model.cells(for: row).last?.id
    }

    /// Step the window, then settle focus by the owner's rule: it stays on the same programme while
    /// that programme is still in the window, and goes to the leftmost cell its row still has when
    /// the programme has left it.
    private func nudge(from id: String) async {
        guard await model.nudgeForward() else {
            print("[guide] nudge refused at \(model.windowLabel) — no later slot has a listing")
            return
        }
        let cells = model.rows
            .first { $0.channel.id == Self.cellKey(id)?.channel }
            .map { model.cells(for: $0) } ?? []
        if cells.contains(where: { $0.id == id }) {
            print("[guide] nudge -> \(model.windowLabel) · fetch=\(model.fetchStart) · focus stays on \(id)")
        } else {
            let landing = cells.first?.id ?? firstCellID ?? "collections"
            print("[guide] nudge -> \(model.windowLabel) · fetch=\(model.fetchStart) · \(id) left the window, focus to \(landing)")
            focusSoon { focused = landing }
        }
    }

    // MARK: Pass 79 — the Guide keeps up with the clock

    /// Pass 79: the beat is aligned to the wall clock's next whole minute rather than spaced a fixed
    /// 60 s apart, so a roll lands within a moment of the half hour it belongs to and the
    /// "↩ Now · 10:47" clock changes on the minute it names.
    private static func secondsToNextMinute() -> Double {
        60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
    }

    /// One beat. `GuideModel.tick()` republishes the clock and rolls the window if the clock has
    /// left it behind; this settles focus afterwards by Pass 77's rule.
    ///
    /// **While one of this screen's own overlays is up the beat does nothing at all**, which is the
    /// guard `gridMoved` takes and for the same reason: the airing sheet, the channel menu and the
    /// collections drop-down each own the remote and disable the grid, so a roll underneath one of
    /// them would move the grid and could leave the sheet's own Menu restoring focus to a cell that
    /// no longer exists. The next beat rolls once the overlay closes.
    private func beat() async {
        guard model.sheet == nil, channelMenu == nil, !collectionsOpen else { return }
        let held = focused
        guard await model.tick() else { return }
        print("[guide] roll -> \(model.windowLabel) · fetch=\(model.fetchStart)")
        settleFocusAfterRoll(held)
    }

    /// Pass 77's focus rule, after a roll rather than after a nudge: focus stays on the same
    /// programme while that programme is still in the window, and goes to the leftmost cell its row
    /// still has when the programme has left it. A row with no cell at all in the new window falls
    /// back to `firstCellID` — this screen's existing convention, and the third case Pass 77 open
    /// question 1 records.
    ///
    /// Anything that is not a programme cell is left exactly where it is: a channel cell, the
    /// collections button, a header pill, or the rail, where this screen's `focused` is nil.
    private func settleFocusAfterRoll(_ held: String?) {
        guard let held, let key = Self.cellKey(held),
              let row = model.rows.first(where: { $0.channel.id == key.channel }) else { return }
        let cells = model.cells(for: row)
        if cells.contains(where: { $0.id == held }) {
            print("[guide] roll · focus stays on \(held)")
            return
        }
        let landing = cells.first?.id ?? firstCellID ?? "collections"
        print("[guide] roll · \(held) left the window, focus to \(landing)")
        focusSoon { focused = landing }
    }

    /// Menu on the overlay: it closes and nothing changes.
    private func closeCollections() {
        collectionsOpen = false
        focusSoon { focused = "collections" }
    }

    /// A row was chosen. The selection is stored (and persisted), then the Guide re-fetches at
    /// the window it is already showing.
    ///
    /// Pass 72 step 7: this is the Guide's existing mechanism — a plain `@FocusState`
    /// assignment behind `focusSoon` — tried first and measured on the Apple TV, rather than
    /// the `.id(generation)` rebuild the Search screen needed (GuideSearchScreen.swift:295-311).
    /// The reload replaces every row, which is the case that screen's plain assignment failed.
    private func pick(_ collection: ChannelCollection?) {
        collectionsOpen = false
        collections.select(collection)
        Task {
            await model.reloadForCollection()
            print("[guide] collection \(collection?.name ?? "All Channels") rows=\(model.rows.count) refocus=\(firstCellID ?? "collections")")
            focusSoon { focused = firstCellID ?? "collections" }
        }
    }

    private func closeChannelMenu() {
        let id = channelMenu.map(Self.channelFocusID)
        channelMenu = nil
        focusSoon { focused = id }
    }

    private var firstCellID: String? {
        for row in model.rows {
            if let cell = model.cells(for: row).first { return cell.id }
        }
        return nil
    }

    private var header: some View {
        ScreenHeader("Guide", subtitle: model.loaded ? model.windowLabel : nil, accessory: {
            // Pass 72: the collections button, in `ScreenHeader`'s slot between the title and
            // the date range. It is drawn whatever the grid holds — before the first fetch, on
            // an error, and on an empty collection — so the screen always has something the
            // remote can reach. Same pill, same focus section, same `BareButtonStyle` as
            // "↩ Now" and "+12h"; `active` marks that a filter is on.
            Button {
                collectionsOpen = true
            } label: {
                PillLabel(text: collections.buttonLabel,
                          active: collections.selectedId != nil,
                          focused: focused == "collections",
                          size: Nocturne.TextSize.floor)
            }
            .buttonStyle(BareButtonStyle())
            .focused($focused, equals: "collections")
        }, trailing: {
            HStack(spacing: 14) {
                if model.loaded && !model.isAtNow {
                    Button {
                        Task {
                            await model.snapToNow()
                            focusSoon { focused = firstCellID ?? "collections" }
                        }
                    } label: {
                        // Pass 79: the observed clock, not `Date()` — a `Date()` read here is not
                        // observed by anything, so the pill kept the time the screen opened at.
                        PillLabel(text: "↩ Now · \(TimeFormat.clock(model.now))", active: true, focused: focused == "now", size: Nocturne.TextSize.floor)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($focused, equals: "now")
                }
                if model.loaded && !model.endOfListings {
                    Button {
                        Task {
                            await model.pageForward()
                            if let id = firstCellID { focusSoon { focused = id } }
                        }
                    } label: {
                        PillLabel(text: "+12h", focused: focused == "page", size: Nocturne.TextSize.floor)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($focused, equals: "page")
                }
            }
        })
        .focusSection()
    }

    /// "CHANNEL" and the four half-hour labels; the first of a new day is named (dc:196-201, 321-327).
    private var columnHeader: some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            Text("CHANNEL")
                .font(.nocturne(Nocturne.TextSize.floor))
                .tracking(0.14 * Nocturne.TextSize.floor)
                .foregroundStyle(Nocturne.neutral600)
                .frame(width: Self.channelColumnWidth, alignment: .leading)
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(model.slotStarts.enumerated()), id: \.offset) { index, start in
                    let newDay = TimeFormat.isMidnight(unix: start)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slotLabel(start: start, index: index, newDay: newDay))
                            .font(.nocturne(Nocturne.TextSize.secondary))
                            .foregroundStyle(newDay ? Nocturne.accent200 : Nocturne.neutral400)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(newDay ? Nocturne.accent : Color.clear)
                            .frame(width: 40, height: 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Nocturne.divider).frame(height: 1) }
    }

    private func slotLabel(start: Int, index: Int, newDay: Bool) -> String {
        let date = TimeFormat.date(start)
        var label = TimeFormat.clock(date)
        if newDay { label = "\(TimeFormat.weekday(date)) · \(label)" }
        if index == 0 && model.isAtNow { label += " · now" }
        return label
    }

    private var legend: some View {
        HStack(spacing: 34) {
            HStack(spacing: 10) {
                Text("●").foregroundStyle(GuideMark.green)
                Text("Recording or set to record")
            }
            HStack(spacing: 10) {
                Text("◆").foregroundStyle(GuideMark.gold)
                Text("Covered by a series pass")
            }
            Spacer(minLength: 0)
            Text(model.isAtNow ? "Starts at the current half hour · forward only" : "Menu snaps back to now · forward only, 24 hours per request")
                .foregroundStyle(Nocturne.neutral600)
        }
        .font(.nocturne(Nocturne.TextSize.floor))
        .foregroundStyle(Nocturne.neutral500)
    }
}

/// One channel row: the channel cell, then the programs placed by start/end across the window.
struct GuideRowView: View {
    let row: GuideRow
    let cells: [GuideCellItem]
    let favourite: Bool
    let hold: RemoteHold
    var focused: FocusState<String?>.Binding
    let channelColumnWidth: CGFloat
    let columnGap: CGFloat
    let rowHeight: CGFloat
    let onSelect: (GuideCellItem) -> Void

    private var channelFocusID: String { GuideScreen.channelFocusID(row.channel) }

    var body: some View {
        HStack(spacing: columnGap) {
            // Pass 9 step 7: the channel cell takes focus so a click-and-hold can favourite
            // the channel. A plain click is not in Pass 9's steps and does nothing.
            HoldButton(hold: hold) {
            } label: {
                ChannelCell(channel: row.channel, favourite: favourite, focused: focused.wrappedValue == channelFocusID)
                    .frame(width: channelColumnWidth, height: rowHeight, alignment: .leading)
            }
            .focused(focused, equals: channelFocusID)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(cells) { cell in
                        let frame = Self.frame(for: cell, width: geo.size.width)
                        HoldButton(hold: hold) {
                            onSelect(cell)
                        } label: {
                            GuideCellLabel(cell: cell, focused: focused.wrappedValue == cell.id)
                                .frame(width: frame.width, height: rowHeight)
                        }
                        .focused(focused, equals: cell.id)
                        .offset(x: frame.x)
                    }
                }
            }
        }
        .frame(height: rowHeight)
    }

    /// Where a cell sits: clipped to the window, proportional, with a 12 pt gap between cells.
    static func frame(for cell: GuideCellItem, width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let start = cell.startFraction, end = cell.endFraction
        let x = start * width + (start > 0 ? 6 : 0)
        let right = end * width - (end < 1 ? 6 : 0)
        return (x, max(right - x, 24))
    }
}

/// The left column's channel cell (dc:205-211), focusable since Pass 9 so a click-and-hold
/// can favourite the channel; a ★ shows when it is one.
struct ChannelCell: View {
    let channel: MergedChannel
    let favourite: Bool
    let focused: Bool

    var body: some View {
        HStack(spacing: 18) {
            InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: 62, fontSize: Nocturne.TextSize.floor)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(channel.name)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    if favourite {
                        Text("★").foregroundStyle(GuideMark.gold)
                            .font(.nocturne(Nocturne.TextSize.floor))
                    }
                }
                Text(channel.number)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(focused ? Nocturne.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                .strokeBorder(focused ? Nocturne.accent : .clear, lineWidth: focused ? Nocturne.Focus.ringWidth : 0)
        }
    }
}

/// The title and the mark tag (dc:215-219); tinted 20% green or gold when marked (dc:1191-1194).
struct GuideCellLabel: View {
    let cell: GuideCellItem
    let focused: Bool

    private var fill: Color {
        if let mark = cell.mark { return mark.color.mix(with: Nocturne.surface, by: 0.8) }
        return Nocturne.surface
    }

    private var border: Color {
        if let mark = cell.mark { return mark.color }
        return Nocturne.neutral900
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cell.program.title)
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(cell.mark == nil ? Nocturne.text : Nocturne.neutral100)
                .lineLimit(1)
            if let mark = cell.mark {
                Text(mark.tag)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .tracking(0.1 * Nocturne.TextSize.floor)
                    .foregroundStyle(mark.color)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .clipped()
        .overlay {
            RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                .strokeBorder(focused ? Nocturne.accent : border, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
        }
        .shadow(color: focused ? Nocturne.Focus.shadowColor : .clear, radius: Nocturne.Focus.shadowRadius, y: Nocturne.Focus.shadowY)
    }
}
