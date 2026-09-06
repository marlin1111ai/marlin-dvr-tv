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
    private(set) var rows: [GuideRow] = []
    private(set) var jobs: [Job] = []
    private(set) var fetchStart = 0
    private(set) var fetchEnd = 0
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var endOfListings = false
    private(set) var windowStart = 0
    var sheet: AiringSelection?

    init(api: APIClient) {
        self.api = api
    }

    var windowEnd: Int { windowStart + Self.windowSeconds }
    var isAtNow: Bool { windowStart == TimeFormat.currentHalfHour }
    var slotStarts: [Int] { (0..<4).map { windowStart + $0 * Self.slotSeconds } }

    /// True when the window's start and end fall on different days (frame 3c header).
    var crossesMidnight: Bool {
        !TimeFormat.sameDay(TimeFormat.date(windowStart), TimeFormat.date(windowEnd - 1))
    }

    func loadNow() async {
        windowStart = TimeFormat.currentHalfHour
        await fetch(from: windowStart)
    }

    func pageForward() async {
        guard !endOfListings else { return }
        windowStart += Self.pageSeconds
        if windowEnd > fetchEnd { await fetch(from: windowStart) }
    }

    func snapToNow() async {
        let now = TimeFormat.currentHalfHour
        windowStart = now
        if now < fetchStart || now + Self.windowSeconds > fetchEnd { await fetch(from: now) }
    }

    private func fetch(from start: Int) async {
        do {
            async let guide = api.guide(start: start, slots: Self.fetchSlots)
            async let schedule = api.schedule()
            let g = try await guide
            rows = g.channels
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
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @Environment(RemoteHold.self) private var hold
    @State private var model: GuideModel
    @FocusState private var focused: String?
    @State private var lastCell: String?
    @State private var channelMenu: MergedChannel?

    /// The focus id of a channel cell in the left column.
    static func channelFocusID(_ channel: MergedChannel) -> String { "ch:\(channel.id)" }

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.api = api
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: GuideModel(api: api))
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
        guard model.sheet == nil, channelMenu == nil, let focus = focused else { return }
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
                .disabled(model.sheet != nil || channelMenu != nil)
                legend
                    .padding(.top, 16)
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
            focusSoon { focused = firstCellID ?? "page" }
        }
        .onChange(of: focused) { _, new in
            if let new, new.contains("@") { lastCell = new }
        }
        .onChange(of: hold.holds) { _, _ in handleHold() }
        .onExitCommand {
            print("[guide] menu: sheet=\(model.sheet != nil) channelMenu=\(channelMenu != nil) atNow=\(model.isAtNow)")
            if channelMenu != nil {
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
                    focusSoon { focused = firstCellID ?? "page" }
                }
            } else {
                onLeave()
            }
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
        ScreenHeader("Guide", subtitle: model.loaded ? model.windowLabel : nil) {
            HStack(spacing: 14) {
                if model.loaded && !model.isAtNow {
                    Button {
                        Task {
                            await model.snapToNow()
                            focusSoon { focused = firstCellID ?? "page" }
                        }
                    } label: {
                        PillLabel(text: "↩ Now · \(TimeFormat.clock(Date()))", active: true, focused: focused == "now", size: Nocturne.TextSize.floor)
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
        }
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
