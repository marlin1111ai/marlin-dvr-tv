//
//  GuideScreen.swift
//  Marlin DVR TV
//
//  The Guide, frames 3a (comfortable: 8 rows, a 2-hour window in four 30-minute columns)
//  and 3c (paged past midnight). Rows are re-laid from each program's start/end, not the
//  server's 30-minute `span` blocks (Pass 4 §3.4). Forward-only from the current half hour;
//  "+12h" pages ahead, fetching 24 hours (48 slots) per request while the server has
//  listings; when the window crosses midnight the header and the column label name the day.
//  "↩ Now" and Menu snap back to now; Menu at now leaves the Guide. Marks ● (recording now)
//  and ◆ (covered by a series pass) come from joining GET /api/schedule jobs to the grid on
//  channelId + program.start (passes.go:53-77). Selecting a cell opens the airing sheet.
//

import SwiftUI

enum GuideMark {
    case recording, pass

    static let green = Color(hex: 0x57B083)
    static let gold = Color(hex: 0xD6A94E)

    var tag: String {
        switch self {
        case .recording: return "● RECORDING"
        case .pass: return "◆ SERIES PASS"
        }
    }

    var color: Color {
        switch self {
        case .recording: return Self.green
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

    private func mark(for job: Job?) -> GuideMark? {
        guard let job else { return nil }
        if job.status == "Recording" { return .recording }
        if job.passId != "manual" && (job.status == "Queued" || job.status == "Conflict") { return .pass }
        return nil
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
    let onLeave: () -> Void
    @State private var model: GuideModel
    @FocusState private var focused: String?
    @State private var lastCell: String?

    init(api: APIClient, onLeave: @escaping () -> Void) {
        self.onLeave = onLeave
        _model = State(initialValue: GuideModel(api: api))
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
                                focused: $focused,
                                channelColumnWidth: Self.channelColumnWidth,
                                columnGap: Self.columnGap,
                                rowHeight: Self.rowHeight
                            ) { cell in
                                model.sheet = AiringSelection(channel: cell.channel, program: cell.program, job: cell.job)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .disabled(model.sheet != nil)
                legend
                    .padding(.top, 16)
            }
            if let selection = model.sheet {
                AiringSheet(selection: selection)
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
        .onExitCommand {
            print("[guide] menu: sheet=\(model.sheet != nil) atNow=\(model.isAtNow)")
            if model.sheet != nil {
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
                Text("Recording now")
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
    var focused: FocusState<String?>.Binding
    let channelColumnWidth: CGFloat
    let columnGap: CGFloat
    let rowHeight: CGFloat
    let onSelect: (GuideCellItem) -> Void

    var body: some View {
        HStack(spacing: columnGap) {
            HStack(spacing: 18) {
                InitialsTile(initials: row.channel.initials, logoBg: row.channel.logoBg, size: 62, fontSize: Nocturne.TextSize.floor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.channel.name)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    Text(row.channel.number)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral500)
                }
            }
            .frame(width: channelColumnWidth, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(cells) { cell in
                        let frame = Self.frame(for: cell, width: geo.size.width)
                        Button {
                            onSelect(cell)
                        } label: {
                            GuideCellLabel(cell: cell, focused: focused.wrappedValue == cell.id)
                                .frame(width: frame.width, height: rowHeight)
                        }
                        .buttonStyle(BareButtonStyle())
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
