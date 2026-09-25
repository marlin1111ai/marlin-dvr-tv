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
//  Pass 116: the Guide redraws when the owner changes a channel or a collection on the server
//  (owner, 2026-09-19: "all i want is when i do something in the server it gets refelcted on the atv
//  right away"). A second `.task` listens to `GET /api/events` through `ServerEvents` for as long as
//  this screen exists; every notice, every connect and every reconnect re-reads `GET /api/collections`
//  and then `GET /api/guide` at the window and the collection already showing, so nothing moves —
//  see `serverRedraw`. The channel cell's number, name, logo and favourite all arrive inside the
//  guide's rows, which is why `GET /api/channels` is not part of it.
//  Pass 122: Left goes back as Right went forward (owner, 2026-09-23: "go back as it did forward").
//  While the window is ahead of the current half hour, a Left press on a row's channel cell — the
//  one press that would take focus out of the grid into the rail — moves the window back one slot
//  instead, and focus stays on that channel cell; at the current half hour Left reaches the rail as
//  it always has. For that one press this supersedes "Forward only" above. Neither `.onMoveCommand`
//  nor a press recognizer on the window can stop the focus engine carrying that press into the rail
//  (measured on Home Theater, Pass 122), so the press is caught by where focus goes — see
//  `backStepCatcher`.
//  Pass 123: a swipe right, and a held ring (owner, 2026-09-24: "I can't swipe right"; "I should be able
//  to hold the right outer ring and keep scrolling"). Measured on Home Theater: a swipe never reaches
//  `.onMoveCommand`, a held ring reaches it once, at release, and while the ring is held the focus
//  engine repeats the focus move on its own, about every 0.27 s after a 0.55 s delay. So Right at a
//  row's last cell is caught the way Pass 122 catches Left — by a strip focus can land on,
//  `forwardStepCatcher` — and every landing, by a swipe, a click or a repeat of the held ring, steps
//  the window forward through Pass 77's `nudge(from:)`. A held Left repeats through `backStepCatcher`
//  the same way and stops at the current half hour: `RingHoldWatch` reports whether Left is still
//  down, and while it is the catcher stays drawn there; a Left pressed on its own at now reaches the
//  rail as before. The back-step catcher itself is now a UIKit focusable view with a focus guide to its
//  left that redirects back to it, because a repeat that fires while the catcher still has focus —
//  the hand-back takes up to 0.5 s while a 202-row grid redraws — went Left from the catcher into the
//  rail (measured). The app adds no timer of its own — the pace is the platform's repeat.
//

import SwiftUI
import UIKit

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

    /// Pass 122: one Left press on a row's channel cell moves the window **back one slot** while it is
    /// ahead of the current half hour (owner, 2026-09-23: "go back as it did forward") — the mirror of
    /// `nudgeForward()`, so the time strip, every row and the header move together for the same reason.
    ///
    /// **Never earlier than the current half hour**, read from the wall clock at the press as
    /// `snapToNow()` reads it, because `now` can be up to a minute behind it; this keeps `tick()`'s
    /// ground truth, that `windowStart` is only ever the current half hour or ahead of it. **The
    /// refetch is the two-sided rule** `tick()` and `snapToNow()` use: the one-sided line
    /// `nudgeForward()` uses can never fire going backward, and a step below `fetchStart` — after the
    /// 45th nudge, a second "+12h", a collection pick or a server notice made while ahead — needs one.
    ///
    /// Returns true when the window actually moved.
    @discardableResult
    func nudgeBack() async -> Bool {
        now = Date()
        let previous = windowStart - Self.slotSeconds
        guard previous >= nowHalfHour else { return false }
        windowStart = previous
        if windowStart < fetchStart || windowEnd > fetchEnd { await fetch(from: windowStart) }
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

    /// Pass 116: the server said its channels or its collections changed. The same in-place
    /// refetch as a collection pick — the window the Guide is already showing, the collection it is
    /// already showing — so nothing moves. **When the rows land, the server's favourite wins**: the
    /// overrides this screen wrote are dropped in the same turn the new rows are stored, not before
    /// it, so a ★ this Apple TV has just set does not blink off while its own notice is answered.
    func reloadForNotice() async {
        await fetch(from: windowStart, serverWins: true)
    }

    func snapToNow() async {
        now = Date()
        let start = nowHalfHour
        windowStart = start
        if start < fetchStart || start + Self.windowSeconds > fetchEnd { await fetch(from: start) }
    }

    private func fetch(from start: Int, serverWins: Bool = false) async {
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
            // Pass 116: see `reloadForNotice()`.
            if serverWins { favouriteOverrides = [:] }
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
    /// Pass 116: a redraw the server asked for is running. A notice that arrives meanwhile does not
    /// start a second one beside it; it is owed, and runs the moment this one ends.
    @State private var redrawing = false
    /// Pass 116: a notice arrived that has not been answered yet — because a redraw was already
    /// running, or because one of this screen's overlays was up. **It is never dropped**: it is
    /// answered when the running redraw ends or the moment the overlay closes.
    @State private var redrawOwed = false
    /// Pass 116: the last cell of the grid that had focus, programme cell or channel cell. It is
    /// where an overlay hands focus back to, so it is what a redraw that waited for that overlay
    /// has to check is still there. (`lastCell` above is programme cells only.)
    @State private var lastGridFocus: String?
    /// Pass 123: true while Left on the ring has been down longer than a click, and after it comes up
    /// until the focus engine has stopped repeating it (`holdQuiet`). It keeps `backStepCatcher` drawn
    /// at the current half hour, so a held Left stops there instead of carrying on into the rail. See
    /// `RingHoldWatch`.
    @State private var leftRingHeld = false
    /// Pass 123: true from Left's press-down to its release, as `RingHoldWatch` reports them.
    @State private var leftRingDown = false
    /// Pass 123: true while `backStepCatcher`'s UIKit view has focus, when this screen's own `focused`
    /// is nil. It stands in for the `"back-step"` focus id the SwiftUI strip had.
    @State private var backStepCatcherFocused = false
    @State private var leftRingTask: Task<Void, Never>?

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
                // Pass 122: outside the `ScrollView`, which would clip it. See `backStepCatcher`.
                .overlay(alignment: .topLeading) { backStepCatcher }
                // Pass 123: its mirror on the right. See `forwardStepCatcher`.
                .overlay(alignment: .topTrailing) { forwardStepCatcher }
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
        // Pass 123: the one thing the catchers cannot tell on their own — whether Left is still down.
        .background {
            RingHoldWatch(shouldWatch: { !overlayOpen && !hold.suspended && focused != nil },
                          pressed: leftRingPressed, released: leftRingReleased)
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
        // Pass 116: the server's change notices. A `.task` of its own, tied to this screen's
        // lifetime exactly as the clock above is: the stream opens when the Guide appears and the
        // cancellation that ends this task when the Guide leaves is what closes it. It waits for
        // the first load to land so that a connect can never race `loadNow()` for the window.
        .task {
            while !model.loaded {
                guard (try? await Task.sleep(for: .milliseconds(50))) != nil else { return }
            }
            for await event in ServerEvents().events() {
                serverSaid(event)
            }
            print("[guide] stopped listening to the server")
        }
        .onChange(of: overlayOpen) { _, open in
            // The moment the sheet, the hold menu or the collections drop-down closes.
            if !open && redrawOwed { serverRedraw("the overlay closed", afterOverlay: true) }
        }
        .onChange(of: focused) { old, new in
            if let new, new.contains("@") { lastCell = new }
            if let new, new.contains("@") || new.hasPrefix("ch:") { lastGridFocus = new }
            // Pass 77: a step rightward inside one row is how a Right press the focus engine
            // consumed is told apart from one it refused. See `gridMoved`.
            if Self.isRightwardStep(from: old, to: new) { engineSteppedRightAt = Date() }
            // Pass 122's back-step catcher reports its landing itself since Pass 123 (`BackStepCatcher`).
            // Pass 123: the focus engine took a Right off a row's last cell on to the forward catcher.
            if new == Self.forwardStepID { forwardStep(from: old) }
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
    ///
    /// Pass 123: a Right the engine carries on to `forwardStepCatcher` is nudged there, and that
    /// landing stamps `engineSteppedRightAt` too, so this stands down for it as for any other press
    /// the engine consumed. What is left for this path is a press the engine refused — which, with the
    /// catcher drawn, is none on the tvOS measured, and every one should a tvOS not choose the strip.
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

    // MARK: Pass 122 — Left at a row's channel cell moves the window back one slot (item G)

    /// True while the catcher is drawn: the window is ahead of the current half hour, a channel cell
    /// has focus — or the catcher itself does, for the moment it takes to hand focus back — and none
    /// of this screen's overlays is up. At the current half hour it is not drawn, so Left from a
    /// channel cell reaches the rail exactly as it always has — **except while Left is still held**
    /// (Pass 123): the focus engine repeats a held press on its own, and without the catcher its next
    /// repeat would carry focus into the rail, so the catcher stays, refuses, and hands focus back
    /// until the ring is let go.
    private var backStepCatcherOn: Bool {
        guard model.loaded, !overlayOpen else { return false }
        guard !model.isAtNow || leftRingHeld else { return false }
        return focused?.hasPrefix("ch:") == true || backStepCatcherFocused
    }

    /// An invisible focusable strip, 16 pt wide, in the gap between the rail and the channel column.
    ///
    /// **Why a strip and not a handler — measured on Home Theater in Pass 122.** Left from a channel
    /// cell reaches the grid's `.onMoveCommand` only **after** focus has landed in the rail and
    /// `ScreenShell.railRestore` has run — 3–12 ms later, on every crossing. A press recognizer on the
    /// window sees the press 16–31 ms **before** focus moves, and neither a tap recognizer nor a
    /// zero-length long press — which began, and took the press away from `.onMoveCommand` — stopped
    /// the focus engine carrying focus into the rail. What the engine does obey is geometry: this
    /// strip is nearer to a channel cell than any rail entry, so the engine lands on it instead, and
    /// `backStep(from:)` hands focus straight back — 7 ms and 13 ms in that run — without the rail
    /// ever having focus.
    ///
    /// **Why it is a UIKit view since Pass 123.** A held ring repeats the Left every 0.27 s, and on a
    /// 202-row grid the hand-back is drawn up to 0.5 s after the landing, so a repeat can fire while
    /// the strip itself still has focus — and Left from the strip went into the rail (measured, once
    /// in three runs). `BackStepCatcher` is the same 16 pt landing with a focus guide 8 pt to its left
    /// that redirects back to the landing, so a Left from it goes nowhere at all, whatever the timing.
    @ViewBuilder
    private var backStepCatcher: some View {
        if backStepCatcherOn {
            BackStepCatcher(onFocus: { has in
                backStepCatcherFocused = has
                if has { backStep(from: lastGridFocus) }
            })
            .frame(width: BackStepCatcherView.width)
            .frame(maxHeight: .infinity)
            .offset(x: -(BackStepCatcherView.width + 12))
        }
    }

    /// Focus landed on the catcher: a Left press on channel cell `old` — the last grid focus, since the
    /// catcher is drawn only while a channel cell has it. Focus goes straight back to that cell — which
    /// a back-step never takes out of the window, so this is Pass 77's rule, "stays while it is in the
    /// window", mirrored — and the window steps back one slot.
    private func backStep(from old: String?) {
        guard let old, old.hasPrefix("ch:") else {
            // Not reachable by design: the catcher is drawn only while a channel cell has focus.
            let landing = lastGridFocus ?? firstCellID ?? "collections"
            print("[guide] back-step: the catcher was reached from \(old ?? "nothing"), not a channel cell — focus to \(landing), window unchanged")
            Task { focused = landing }
            return
        }
        Task {
            focused = old
            if await model.nudgeBack() {
                print("[guide] back-step -> \(model.windowLabel) · fetch=\(model.fetchStart) · focus stays on \(old)")
            } else {
                print("[guide] back-step refused at \(model.windowLabel) — the window is at the current half hour\(leftRingHeld ? "; the held ring stops here" : "")")
                // Pass 123: the ring is up and the engine still repeated it — wait for it to go quiet.
                if leftRingHeld && !leftRingDown { leftRingLetGoWhenQuiet() }
            }
        }
    }

    // MARK: Pass 123 — a swipe right, and a held ring (owner, 2026-09-24)

    /// The focus id of the forward-step catcher: neither a programme cell id nor a channel cell id, so
    /// `lastCell`, `lastGridFocus`, `isRightwardStep`, `handleHold` and the redraw's focus repair all
    /// pass over it.
    static let forwardStepID = "forward-step"

    /// True while the forward catcher is drawn: the focused cell is the last one its row has in the
    /// window — or the catcher itself has focus, for the moment it takes to hand focus back — and
    /// none of this screen's overlays is up.
    private var forwardStepCatcherOn: Bool {
        guard model.loaded, !overlayOpen, let focused else { return false }
        return focused == Self.forwardStepID || lastCellID(inRowOf: focused) == focused
    }

    /// An invisible focusable strip, 16 pt wide, in the trailing margin right of the programme area —
    /// `backStepCatcher`'s mirror.
    ///
    /// **Why a strip here too — measured on Home Theater in Pass 123.** A swipe on the touch surface
    /// never reaches `.onMoveCommand` (the owner's "I can't swipe right"), and a held ring reaches it
    /// once, at release. What both do is move focus — and while the ring is held, the focus engine
    /// repeats that move on its own, about every 0.27 s after a 0.55 s delay, until it is let go. At a
    /// row's last cell there was nothing to the right, so the engine had nowhere to go and the app heard
    /// nothing. Now there is this strip: every move on to it — a swipe, a click, or each repeat of a
    /// held ring — is handed straight back and steps the window forward one slot through Pass 77's
    /// `nudge(from:)`, so its stops and its focus rule are untouched. `gridMoved` still nudges a click
    /// the engine refused, should a tvOS not choose the strip, and stands down when the strip took it.
    @ViewBuilder
    private var forwardStepCatcher: some View {
        if forwardStepCatcherOn {
            Color.clear
                .frame(width: 16)
                .frame(maxHeight: .infinity)
                .focusable()
                .focusEffectDisabled()
                .focused($focused, equals: Self.forwardStepID)
                .offset(x: 28)
        }
    }

    /// Focus landed on the forward catcher: a Right — swiped, clicked, or repeated by a held ring — on
    /// programme cell `old`, the last in its row. Focus goes straight back to it and the window steps
    /// forward by Pass 77's rule, which settles focus itself.
    private func forwardStep(from old: String?) {
        // The engine consumed this press, so `gridMoved` must not nudge it a second time: the same
        // stamp a rightward step inside a row leaves (see `isRightwardStep`).
        engineSteppedRightAt = Date()
        guard let old, Self.cellKey(old) != nil else {
            // Not reachable by design: the catcher is drawn only while a programme cell has focus.
            let landing = lastGridFocus ?? firstCellID ?? "collections"
            print("[guide] forward-step: the catcher was reached from \(old ?? "nothing"), not a programme cell — focus to \(landing), window unchanged")
            Task { focused = landing }
            return
        }
        Task {
            focused = old
            await nudge(from: old)
        }
    }

    /// How long Left has to be down to count as held rather than clicked. Measured in Pass 123: a
    /// click is 128–134 ms from press-down to release, and the engine's first move for a press comes
    /// about 110 ms after press-down, so the catcher at now must not appear before that move has been
    /// made — 350 ms sits clear of both.
    private static let holdThreshold: Duration = .milliseconds(350)
    /// How long the focus engine has to be quiet after Left comes up before the hold is over. Its
    /// last repeat is due up to about 120 ms after the release, but a due timer fires late while the
    /// grid is redrawing (about 0.5 s on 202 rows), and in one run of Pass 123 it fired after a fixed
    /// 350 ms let-go had withdrawn the catcher, and carried focus into the rail. So the let-go is not a
    /// fixed wait: every landing on the catcher after the release starts it again, and the catcher is
    /// withdrawn only once the engine has been quiet this long.
    private static let holdQuiet: Duration = .milliseconds(500)

    /// Left on the ring went down.
    private func leftRingPressed() {
        leftRingDown = true
        leftRingTask?.cancel()
        leftRingTask = Task {
            try? await Task.sleep(for: Self.holdThreshold)
            guard !Task.isCancelled else { return }
            leftRingHeld = true
            print("[guide] left ring held")
        }
    }

    /// Left on the ring came up. A click never set `leftRingHeld`; a hold is honoured until the engine
    /// has been quiet for `holdQuiet`.
    private func leftRingReleased() {
        leftRingDown = false
        leftRingTask?.cancel()
        leftRingTask = nil
        guard leftRingHeld else { return }
        leftRingLetGoWhenQuiet()
    }

    /// Start, or start again, the wait that ends the hold. Called on the release and on every landing on
    /// the catcher after it, so the withdrawal is always ordered after the engine's last repeat.
    private func leftRingLetGoWhenQuiet() {
        leftRingTask?.cancel()
        leftRingTask = Task {
            try? await Task.sleep(for: Self.holdQuiet)
            guard !Task.isCancelled else { return }
            leftRingHeld = false
            print("[guide] left ring let go")
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

    // MARK: Pass 116 — the Guide redraws when the server's channels or collections change

    /// True while the airing sheet, the hold menu or the collections drop-down is up. The three
    /// guards `gridMoved` and `beat` take, as one value, so that its change can be watched.
    private var overlayOpen: Bool { model.sheet != nil || channelMenu != nil || collectionsOpen }

    /// The stream said something. **Every event is answered the same way** (foreman, 2026-09-20):
    /// a `channels` notice, a `collections` notice, the first connect and every reconnect each
    /// re-read `GET /api/collections` and `GET /api/guide`. `GET /api/channels` is never sent — the
    /// Guide does not draw from it (Pass 115 §4.3).
    private func serverSaid(_ event: ServerEvent) {
        switch event {
        case .connected: serverRedraw("connected")
        case .notice(let notice): serverRedraw(notice.rawValue)
        }
    }

    /// Redraw in place, now or as soon as it can be done.
    ///
    /// **No notice is coalesced away.** One that arrives while a re-read is running is owed, and
    /// one more re-read follows the running one — it starts after the notice arrived, so it cannot
    /// miss what the notice was about. **One that arrives under an overlay waits for it**, for the
    /// reason `beat` gives: a change underneath could leave the overlay's own Menu handing focus
    /// back to a cell that no longer exists. A beat can simply skip, because another comes in a
    /// minute; a notice comes once, so it is remembered in `redrawOwed` and answered by the
    /// `.onChange(of: overlayOpen)` in `body` the moment the overlay closes.
    ///
    /// The order inside is fixed: the collections first, because `reconcile()` is what turns a pick
    /// the server has deleted back into All Channels, and the server answers an unknown filter with
    /// every visible channel rather than an error (sources.go:371-373) — read the other way round,
    /// the grid would fill with every channel under a button still naming the dead collection.
    private func serverRedraw(_ reason: String, afterOverlay: Bool = false) {
        if redrawing {
            redrawOwed = true
            print("[guide] server: \(reason) — a re-read is running; one more follows it")
            return
        }
        if overlayOpen {
            redrawOwed = true
            print("[guide] server: \(reason) — an overlay is open; the redraw waits for it to close")
            return
        }
        redrawing = true
        Task {
            var reason = reason
            // An overlay had the focus, so this screen's own `focused` is nil on the way out of
            // one; what it hands focus back to is the grid cell it was opened from.
            var held = focused ?? (afterOverlay ? lastGridFocus : nil)
            repeat {
                redrawOwed = false
                await collections.refresh()
                await model.reloadForNotice()
                print("[guide] server: \(reason) -> re-read · \(collections.buttonLabel) · rows=\(model.rows.count) · \(model.windowLabel)\(model.error.map { " · ERROR: \($0)" } ?? "")")
                settleFocusAfterRedraw(held)
                reason = "a notice that arrived during the re-read"
                held = focused
            } while redrawOwed && !overlayOpen
            redrawing = false
        }
    }

    /// Whether a focus id of the grid still names something drawn. Anything that is not the grid's
    /// — the collections button, a header pill — is never taken away by a redraw.
    private func gridFocusExists(_ id: String) -> Bool {
        if id.hasPrefix("ch:") { return model.rows.contains { Self.channelFocusID($0.channel) == id } }
        guard let key = Self.cellKey(id) else { return true }
        guard let row = model.rows.first(where: { $0.channel.id == key.channel }) else { return false }
        return model.cells(for: row).contains { $0.id == id }
    }

    /// Focus after a redraw (foreman, 2026-09-20): it stays on the same programme when that
    /// survives, and when its row is gone it goes to `firstCellID`, this screen's fallback
    /// everywhere else. A programme that has left a row that is still there goes to that row's
    /// leftmost cell, which is Pass 77's rule and what a roll does.
    ///
    /// **Nothing is written unless something of the grid's lost its view.** With the remote in the
    /// rail this screen's `focused` is nil and `held` was nil, so there is nothing to repair; and
    /// while the Player is up — `hold.suspended`, which `ContentView` sets for exactly that — no
    /// focus is written underneath it at all.
    private func settleFocusAfterRedraw(_ held: String?) {
        guard !hold.suspended else { return }
        let lost: String
        if let now = focused {
            guard !gridFocusExists(now) else { return }
            lost = now
        } else if let held, !gridFocusExists(held) {
            lost = held
        } else {
            return
        }
        let row = (Self.cellKey(lost)?.channel).flatMap { channel in model.rows.first { $0.channel.id == channel } }
        let landing = row.flatMap { model.cells(for: $0).first?.id } ?? firstCellID ?? "collections"
        print("[guide] server: \(lost) is gone from the grid, focus to \(landing)")
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
            // Pass 123: the ahead sentence no longer says "forward only" (owner, 2026-09-24, answer 2a).
            Text(model.isAtNow ? "Starts at the current half hour · forward only" : "Menu snaps back to now · 24 hours per request")
                .foregroundStyle(Nocturne.neutral600)
        }
        .font(.nocturne(Nocturne.TextSize.floor))
        .foregroundStyle(Nocturne.neutral500)
    }
}

// MARK: Pass 123 — the back-step catcher as a UIKit view, with a focus guide that traps Left

/// Pass 122's landing strip, hosted in UIKit so that a focus guide can sit beside it: the guide, 8 pt
/// to the landing's left, names the landing as its preferred focus, so the focus engine's answer to a
/// Left *from* the landing is the landing itself — no movement, and never the rail — while its answer
/// to a Left from a channel cell is still the landing, the nearest thing to the left of the column.
/// `onFocus` reports the landing gaining and losing focus; the screen hands focus back and steps.
struct BackStepCatcher: UIViewRepresentable {
    let onFocus: (Bool) -> Void

    func makeUIView(context: Context) -> BackStepCatcherView { BackStepCatcherView() }

    func updateUIView(_ view: BackStepCatcherView, context: Context) {
        view.onFocus = onFocus
    }
}

final class BackStepCatcherView: UIView {
    /// The guide (16 pt), the gap (8 pt) and the landing (16 pt), left to right.
    static let width: CGFloat = 40

    var onFocus: (Bool) -> Void = { _ in }
    private let landing = BackStepLandingView()
    private let guide = UIFocusGuide()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        landing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(landing)
        addLayoutGuide(guide)
        NSLayoutConstraint.activate([
            landing.trailingAnchor.constraint(equalTo: trailingAnchor),
            landing.widthAnchor.constraint(equalToConstant: 16),
            landing.topAnchor.constraint(equalTo: topAnchor),
            landing.bottomAnchor.constraint(equalTo: bottomAnchor),
            guide.leadingAnchor.constraint(equalTo: leadingAnchor),
            guide.widthAnchor.constraint(equalToConstant: 16),
            guide.topAnchor.constraint(equalTo: topAnchor),
            guide.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        guide.preferredFocusEnvironments = [landing]
        landing.onFocus = { [weak self] has in self?.onFocus(has) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }
}

/// The 16 pt landing itself: focusable, invisible, and no focus effect (a plain `UIView` draws none).
final class BackStepLandingView: UIView {
    var onFocus: (Bool) -> Void = { _ in }

    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView === self {
            onFocus(true)
        } else if context.previouslyFocusedView === self {
            onFocus(false)
        }
    }
}

// MARK: Pass 123 — the window's press recognizer for Left on the ring

/// A zero-size view that installs one press recognizer for Left on the window and reports the press
/// going down and coming up — `RemoteHoldDetector`'s shape (RemoteHold.swift), for Left instead of
/// Select. **It observes only**: `cancelsTouchesInView` is false, so the focus engine and
/// `.onMoveCommand` see the press exactly as they did without it — measured on Home Theater in
/// Pass 123, one move command per press, at release, with it installed. Put in the Guide's background
/// once; it removes its recognizer when it leaves the window, which `ScreenShell.swift`'s
/// `.id(current)` makes happen on every rail visit.
struct RingHoldWatch: UIViewRepresentable {
    let shouldWatch: () -> Bool
    let pressed: () -> Void
    let released: () -> Void

    func makeUIView(context: Context) -> RingHoldWatchView { RingHoldWatchView() }

    func updateUIView(_ view: RingHoldWatchView, context: Context) {
        view.shouldWatch = shouldWatch
        view.pressed = pressed
        view.released = released
    }
}

final class RingHoldWatchView: UIView, UIGestureRecognizerDelegate {
    var shouldWatch: () -> Bool = { false }
    var pressed: () -> Void = {}
    var released: () -> Void = {}
    private var recognizer: UILongPressGestureRecognizer?
    private weak var installedOn: UIWindow?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let installedOn, installedOn !== window, let recognizer {
            installedOn.removeGestureRecognizer(recognizer)
            self.recognizer = nil
            self.installedOn = nil
        }
        guard let window, recognizer == nil else { return }
        let press = UILongPressGestureRecognizer(target: self, action: #selector(changed(_:)))
        press.minimumPressDuration = 0            // begins at press-down; the threshold is the screen's
        press.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        press.allowedTouchTypes = []              // the ring, not the touch surface
        press.cancelsTouchesInView = false        // observe only
        press.delegate = self
        window.addGestureRecognizer(press)
        recognizer = press
        installedOn = window
    }

    @objc private func changed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began: pressed()
        case .ended, .cancelled, .failed: released()
        default: break
        }
    }

    /// Only while the Guide's own grid or header has the remote — never from the rail, under one of
    /// the Guide's overlays, or with the Player on top.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        shouldWatch()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
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
            GuideChannelTile(channel: channel)
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

/// Pass 86: the channel cell's 62 pt tile. A channel with a `logo` draws it, fitted and never
/// cropped, 6 pt inside the tile on a light neutral backing (owner decision 1a, 2026-09-13) —
/// Pass 85 measured the provider's black CBS and FOX artwork at 1.18–1.45:1 on this cell's dark
/// ground. A channel without a `logo` draws the initials tile exactly as before, with no backing.
/// A logo that fails to load or decode draws that same initials tile, through `ServerImage`'s
/// own fallback, and no backing either.
struct GuideChannelTile: View {
    let channel: MergedChannel

    static let size: CGFloat = 62
    static let logoInset: CGFloat = 6

    /// True while `ServerImage` is showing its fallback — until the logo arrives, and for good if
    /// it never does — so the backing is drawn under a logo only, never under the initials. It
    /// starts false so a logo already on screen at the first frame still gets its backing.
    @State private var showingInitials = false

    var body: some View {
        if let path = Self.artFeedPath(for: channel.logo) {
            ZStack {
                if !showingInitials {
                    RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous)
                        .fill(Nocturne.neutral200)
                }
                ServerImage(path: path, contentMode: .fit) {
                    initials
                        // The logo's frame is inset; the fallback tile still fills all 62 pt.
                        .padding(-Self.logoInset)
                        .onAppear { showingInitials = true }
                        .onDisappear { showingInitials = false }
                }
                .padding(Self.logoInset)
            }
            .frame(width: Self.size, height: Self.size)
        } else {
            initials
        }
    }

    private var initials: some View {
        InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: Self.size, fontSize: Nocturne.TextSize.floor)
    }

    /// `/api/art/feed?u=` and the logo URL escaped exactly as the server escapes a radio icon
    /// (`radio.go:72`, Go's `url.QueryEscape`): every byte but `A–Z a–z 0–9 - _ . ~` is
    /// percent-encoded and a space becomes `+`. The provider's URL is never requested directly.
    /// Nil when there is no logo.
    static func artFeedPath(for logo: String) -> String? {
        guard !logo.isEmpty else { return nil }
        var unreserved = CharacterSet()
        unreserved.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~ ")
        guard let escaped = logo.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
        return "/api/art/feed?u=" + escaped.replacingOccurrences(of: " ", with: "+")
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
