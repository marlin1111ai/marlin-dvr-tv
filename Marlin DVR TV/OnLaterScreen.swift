//
//  OnLaterScreen.swift
//  Marlin DVR TV
//
//  On Later, rebuilt in Pass 82 to the owner's decisions of 2026-09-12. It takes On Now's page
//  layout — the header, a pill row beneath it built the same way, and a three-column card grid —
//  and lists **every** upcoming airing on the channels his collections hold. Nothing narrows it
//  to "notable" airings any more, and it no longer reads `GET /api/guide/later` at all.
//
//  Why that route is gone (Pass 81, and Pass 82 §1 of its report): it takes **no parameters**,
//  caps each of its two sections at **24 items** (`guide.go:806-811`), keeps only airings the
//  server judges notable (`:779-784`), and de-duplicates by `seriesId` across **both** sections
//  with one shared map (`:770`, `:785-788`) — so an airing on tonight can be suppressed by a
//  later-in-the-week showing of the same series. None of that is switchable off.
//
//  **The premiere flag is never set on this server**, measured in Pass 81: `program.premiere` is
//  true on 0 of 16,121 airings. XMLTV's `<premiere>` is parsed as a presence-only element that
//  discards its own text (`guide.go:147`, `:240`) and neither of the owner's providers emits one,
//  and the HDHomeRun cloud path never assigns `Premiere` at all (`guide.go:435-451`). So the
//  Premieres pill runs the owner's **derived** rule — `isPremiere(_:)` below — with the flag kept
//  as its first clause so the pill starts working by itself if the server ever sets it.
//
//  The three pills do not persist and are not meant to: `ScreenShell.swift:57` puts `.id(current)`
//  on the content and destroys this screen on every rail visit, so it opens on On Today each time,
//  which is what the owner asked for. The week is fetched once per visit and the pills filter what
//  is already in hand — no pill press makes a request.
//

import SwiftUI

/// The three pills (owner, 2026-09-12). Exactly these, in this order, and no channel filters.
enum LaterPill: String, CaseIterable, Hashable {
    case today, week, premieres

    var label: String {
        switch self {
        case .today: return "On Today"
        case .week: return "On This Week"
        case .premieres: return "Premieres"
        }
    }
}

/// One upcoming airing on a collection channel: the channel the guide row carried and the
/// programme the block carried, kept together.
///
/// `id` is `"<channel id>@<programme start>"` — deliberately the same identity
/// `AiringSelection.id` uses (`AiringSheet.swift:37`) and the same shape the Guide's cells use,
/// so a card and the sheet it opens agree about which airing they are.
struct LaterAiring: Identifiable {
    let channel: MergedChannel
    let program: Program

    var id: String { "\(channel.id)@\(program.start)" }

    /// "S9 E11 · A House with Good Bones", and whichever half the listing has. The same pair and
    /// the same order as the On Now card's episode line (`OnNowScreen.swift:225-231`).
    var episodeLine: String? {
        var parts: [String] = []
        if let n = program.episodeNum, !n.isEmpty { parts.append(n) }
        if let t = program.episodeTitle, !t.isEmpty { parts.append(t) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Today 8:00 – 10:00 PM", "Tomorrow …", "Wednesday …" — the airing sheet's own `whenLine`
    /// shape (`AiringSheet.swift:127-131`), so a card and its sheet read the same.
    var whenLine: String {
        "\(TimeFormat.relativeDay(TimeFormat.date(program.start))) \(TimeFormat.timeRange(program.start, program.end))"
    }

    /// The art the server itself would have handed over for this programme, built the same way
    /// `tileArt` does (`artwork.go:380-403`): the programme's own feed image when the listing
    /// carries an absolute one, otherwise the show poster by title. `/api/guide` gives the icon
    /// but no art string, so this is built here rather than read.
    var artPath: String? {
        if let icon = program.icon, icon.hasPrefix("http://") || icon.hasPrefix("https://") {
            var c = URLComponents()
            c.path = "/api/art/feed"
            c.queryItems = [URLQueryItem(name: "u", value: icon), URLQueryItem(name: "title", value: program.title)]
            return c.string
        }
        return AiringSelection.artPath(for: program.title)
    }
}

@Observable
final class OnLaterModel {
    /// One `/api/guide` request covers at most 24 hours: the server clamps `slots` to 48 and
    /// falls back to 13 outside 1…48 (`guide.go:652-655`). Seven of them is therefore the floor
    /// for a week, whatever else changes.
    static let days = 7
    static let slotsPerDay = 48
    static let daySeconds = 86_400

    private let api: APIClient

    /// The week, bucketed once after the fetch so a pill press is a switch and not a re-sort.
    private(set) var today: [LaterAiring] = []
    private(set) var week: [LaterAiring] = []
    private(set) var premieres: [LaterAiring] = []
    private(set) var jobs: [Job] = []

    /// How many distinct channels the collections actually put on screen. Zero means the union is
    /// empty, which is a different thing from the week being empty and gets its own line.
    private(set) var collectionChannelCount = 0
    /// How many `/api/guide` requests the last load made, for the console and the report.
    private(set) var requestCount = 0

    private(set) var loaded = false
    private(set) var error: String?
    /// The last attempt to open a card said this. Nil when there is nothing to say.
    private(set) var openError: String?
    private var opening = false

    var pill: LaterPill = .today
    var sheet: AiringSelection?

    init(api: APIClient) {
        self.api = api
    }

    var visible: [LaterAiring] {
        switch pill {
        case .today: return today
        case .week: return week
        case .premieres: return premieres
        }
    }

    var unionIsEmpty: Bool { collectionChannelCount == 0 }

    // MARK: The owner's rules

    /// **Premieres, as the owner defined them on 2026-09-12.** The flag first, so this starts
    /// answering by itself if marlin-dvr ever sets it; then the three derived clauses.
    nonisolated static func isPremiere(_ p: Program) -> Bool {
        if p.premiere == true { return true }
        if p.new == true && p.episode == 1 { return true }
        if p.season == 1 && p.episode == 1 { return true }
        for text in [p.title, p.episodeTitle, p.desc] {
            if let text, text.range(of: "premiere", options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    /// Start time, then channel number. The number is compared the way the server compares it —
    /// `numberKey` is a `ParseFloat` with a very large value for anything unparseable
    /// (`sources.go:296-302`) — so "2.1" sorts before "11.1" rather than after it.
    nonisolated static func before(_ a: LaterAiring, _ b: LaterAiring) -> Bool {
        if a.program.start != b.program.start { return a.program.start < b.program.start }
        let na = Double(a.channel.number) ?? .greatestFiniteMagnitude
        let nb = Double(b.channel.number) ?? .greatestFiniteMagnitude
        if na != nb { return na < nb }
        return a.channel.number < b.channel.number
    }

    // MARK: The read

    /// One visit's worth of data: the collections, then a week of guide for each of them, then the
    /// schedule for the ● Scheduled marks.
    ///
    /// **The route choice is `GET /api/guide?filter=<collection id>`** and it is the only one that
    /// carries what these rules need. `/api/guide/later` cannot be parameterised at all;
    /// `/api/guide/find` carries none of the flags (`guide.go:862-871`); `/api/guide/search` needs a
    /// title; and `/export/guide.xml` — the one genuinely complete route for a range — **drops the
    /// premiere flag**, `seriesId` and `rating` on the way out (`export.go:95-111`), which would
    /// make the first clause of the owner's own premiere rule permanently unevaluable.
    ///
    /// The server does the channel selection: `filterChannels` keeps only the collection's members
    /// and returns them in the owner's stored order (`sources.go:358-406`). The **union** of the
    /// collections is therefore whatever distinct channels come back across all of them, which is
    /// also exactly the set this screen can draw — hidden channels are already gone
    /// (`sources.go:359`) and DRM channels are dropped by `ChannelFilter.swift:67`.
    func load() async {
        error = nil
        openError = nil
        var found: [String: LaterAiring] = [:]
        var requests = 0
        var failures = 0

        let collections: [ChannelCollection]
        do {
            collections = try await api.collections()
        } catch {
            self.error = "\(error)"
            print("[later] collections: \(error)")
            loaded = true
            return
        }

        // Day 0 starts at the current half hour because that is what the server truncates `start`
        // to anyway (`guide.go:657-664`), so the seven windows tile exactly with no overlap and no
        // gap. The far edge is therefore the current half hour plus seven days, which is up to
        // 30 minutes short of "now plus seven days"; the near edge is exact.
        let fetchStart = TimeFormat.currentHalfHour

        // The union the owner's empty rule turns on, and the reason a collection with no members
        // costs nothing: asking the server to filter the guide by an empty collection returns an
        // empty envelope seven times over (measured in Pass 73), so it is skipped outright.
        var union: Set<String> = []
        for collection in collections { union.formUnion(collection.channelIds) }
        collectionChannelCount = union.count

        for collection in collections where !collection.channelIds.isEmpty {
            for day in 0..<Self.days {
                requests += 1
                do {
                    let response = try await api.guide(start: fetchStart + day * Self.daySeconds,
                                                       slots: Self.slotsPerDay,
                                                       filter: collection.id)
                    for row in response.channels {
                        for block in row.blocks {
                            guard let program = block.program else { continue }
                            let airing = LaterAiring(channel: row.channel, program: program)
                            // A channel in two collections, and a programme spanning several
                            // half-hour blocks, both arrive more than once. Keyed by identity, so
                            // each airing is held exactly once.
                            found[airing.id] = airing
                        }
                    }
                } catch {
                    failures += 1
                    print("[later] guide day \(day) of \(collection.name): \(error)")
                }
            }
        }

        requestCount = requests

        // Every request failing is a failure to report; some failing is a short week, which the
        // counts on screen already show.
        if requests > 0 && failures == requests {
            error = "The guide could not be read for your collections."
            loaded = true
            return
        }

        do {
            jobs = try await api.schedule().jobs
        } catch {
            jobs = []
            print("[later] schedule: \(error)")
        }

        bucket(Array(found.values), fetchStart: fetchStart)
        loaded = true
        print("[later] \(collections.count) collection(s), \(requests) guide request(s), "
              + "\(collectionChannelCount) channel(s), \(found.count) airing(s) → "
              + "today \(today.count) · week \(week.count) · premieres \(premieres.count)")
    }

    /// The three buckets, from the owner's definitions.
    ///
    /// * **On Today** — from now to local midnight. Midnight is the start of tomorrow as the
    ///   calendar computes it, not `now + 86400`, so the boundary is right across a DST change.
    /// * **On This Week** — from now through the next seven days.
    /// * **Premieres** — the week, narrowed by `isPremiere(_:)`.
    private func bucket(_ all: [LaterAiring], fetchStart: Int) {
        let now = Int(Date().timeIntervalSince1970)
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            .map { Int($0.timeIntervalSince1970) } ?? now
        let weekEnd = fetchStart + Self.days * Self.daySeconds

        let upcoming = all
            .filter { $0.program.start > now && $0.program.start <= weekEnd }
            .sorted(by: Self.before)

        week = upcoming
        today = upcoming.filter { $0.program.start < midnight }
        premieres = upcoming.filter { Self.isPremiere($0.program) }
    }

    // MARK: The schedule join, and the sheet

    /// The Guide's own join, on channel id and the programme's true start
    /// (`GuideScreen.swift:249-251`).
    func job(channelId: String, programStart: Int) -> Job? {
        jobs.first { $0.channelId == channelId && $0.program.start == programStart }
    }

    /// "● Scheduled" on a card. A future airing's job is Queued, Conflict or Skipped, so
    /// "anything but Skipped" is the same test the server's own `scheduledSet` makes
    /// (`guide.go:907-915`) — which is what the old On Later row displayed.
    func isScheduled(_ airing: LaterAiring) -> Bool {
        guard let job = job(channelId: airing.channel.id, programStart: airing.program.start) else { return false }
        return job.status != "Skipped"
    }

    func refreshSchedule() async {
        do {
            jobs = try await api.schedule().jobs
        } catch {
            print("[later] schedule refresh: \(error)")
        }
    }

    /// Open a card's airing in `AiringSheet`, reconstituted the way the Search screen does it
    /// (`GuideSearchScreen.swift:140-168`, owner's decision).
    ///
    /// **The programme is re-read from `GET /api/guide/search?title=`, never taken from the
    /// `/api/guide` row this card was built from.** That route walks the stored guide directly
    /// (`guide.go:834-840`) while `/api/guide` lays its listings out into rounded half-hour blocks
    /// and drops the ones that will not fit (`guide.go:679`, `:699`, `:705`).
    ///
    /// The **channel** is the one this card already holds, and no second `/api/channels` read is
    /// made for it. Search needs that read because a `FindRow` carries no channel at all; a guide
    /// row embeds the server's own `MergedChannel` (`Models.swift:119-132`), which is the identical
    /// type from the identical record. The **schedule** is re-read, because the sheet's controls
    /// turn on the job's current status and this screen's copy is as old as the visit.
    func open(_ airing: LaterAiring) async {
        guard !opening else { return }
        opening = true
        openError = nil
        defer { opening = false }
        do {
            let matches = try await api.guideSearch(title: airing.program.title)
            guard let match = matches.first(where: {
                $0.channelId == airing.channel.id && $0.program.start == airing.program.start
            }) else {
                openError = "The server no longer lists that airing."
                print("[later] no /api/guide/search match for \(airing.id) among \(matches.count)")
                return
            }
            await refreshSchedule()
            sheet = AiringSelection(channel: airing.channel,
                                    program: match.program,
                                    job: job(channelId: airing.channel.id, programStart: airing.program.start))
            print("[later] opened \(airing.id) · \(match.program.title)")
        } catch {
            openError = AiringSheet.friendly(error, fallback: "The server could not open that airing.")
            print("[later] open failed: \(error)")
        }
    }
}

struct OnLaterScreen: View {
    let api: APIClient
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @State private var model: OnLaterModel
    @FocusState private var focused: String?
    /// The card the sheet was opened from, so Menu puts the remote back on it — the Guide's own
    /// mechanism (`GuideScreen.swift:455`, `:467-472`).
    @State private var lastCard: String?

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.api = api
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: OnLaterModel(api: api))
    }

    /// On Now's grid, unchanged: three flexible columns, 28 across and 30 down
    /// (`OnNowScreen.swift:130`, `:143`).
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 3)

    private static func pillID(_ pill: LaterPill) -> String { "pill:\(pill.label)" }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 34) {
                ScreenHeader("On Later", subtitle: subtitle) {
                    TimelineView(.everyMinute) { context in
                        Text("\(TimeFormat.shortDay(context.date)) · \(TimeFormat.clock(context.date))")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                    }
                }
                pills
                if let openError = model.openError {
                    ErrorLine(text: openError)
                }
                content
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
        .defaultFocus($focused, Self.pillID(.today))
        .task {
            await model.load()
            let id = model.visible.first?.id
            focusSoon { focused = id ?? Self.pillID(.today) }
        }
        .onChange(of: focused) { _, new in
            if let new, new.contains("@") { lastCard = new }
        }
        .onExitCommand {
            print("[later] menu: sheet=\(model.sheet != nil) pill=\(model.pill.label)")
            if model.sheet != nil {
                model.sheet = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    focused = lastCard
                }
            } else {
                onLeave()
            }
        }
    }

    /// "12 airings · 5 collection channels" — both numbers counted from what is on screen, so the
    /// header never claims more than the grid holds.
    private var subtitle: String? {
        guard model.loaded, model.error == nil else { return nil }
        let airings = model.visible.count
        let channels = model.collectionChannelCount
        return "\(airings) airing\(airings == 1 ? "" : "s") · \(channels) collection channel\(channels == 1 ? "" : "s")"
    }

    /// The pill row, built the same way On Now's chips are (`OnNowScreen.swift:197-211`): one
    /// `HStack` of `PillLabel` buttons in their own focus section. A press only switches which
    /// bucket is drawn — the week is already in hand, so nothing is fetched.
    private var pills: some View {
        HStack(spacing: 14) {
            ForEach(LaterPill.allCases, id: \.self) { pill in
                Button {
                    model.pill = pill
                } label: {
                    PillLabel(text: pill.label,
                              active: model.pill == pill,
                              focused: focused == Self.pillID(pill))
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: Self.pillID(pill))
            }
        }
        .focusSection()
    }

    @ViewBuilder
    private var content: some View {
        if let error = model.error {
            ErrorLine(text: error)
        } else if !model.loaded {
            LoadingLine()
        } else if model.unionIsEmpty {
            emptyLine("No collection channels")
        } else if model.visible.isEmpty {
            emptyLine("Nothing on \(model.pill.label) for your collections")
        } else {
            grid
        }
    }

    /// Deliberately not focusable. The pill row above is always drawn and always focusable, so the
    /// remote is never stranded and Menu always reaches `.onExitCommand` — the failure
    /// `TrashManageView.swift:58-62` and `RadarScreen.swift:202-203` both record from the device.
    /// The owner's rule for both empty states is that focus stays on the pills.
    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.nocturne(Nocturne.TextSize.secondary))
            .foregroundStyle(Nocturne.neutral500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var grid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: Self.columns, spacing: 30) {
                ForEach(model.visible) { airing in
                    Button {
                        Task { await model.open(airing) }
                    } label: {
                        LaterCard(airing: airing,
                                  scheduled: model.isScheduled(airing),
                                  focused: focused == airing.id)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($focused, equals: airing.id)
                }
            }
            .padding(.vertical, 10)
        }
        .disabled(model.sheet != nil)
    }
}

/// One On Later card: the On Now card's shape (`OnNowScreen.swift:243-276`) with the programme's
/// art where the channel logo sits, the day and time where "ends 3:04 PM" sits, and no progress
/// bar — every airing here is in the future, so there is no progress to draw.
struct LaterCard: View {
    let airing: LaterAiring
    let scheduled: Bool
    let focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ServerImage(path: airing.artPath) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text("\(airing.channel.number) · \(airing.channel.name)")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(1)
                Text(airing.program.title)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(2)
                if let episodeLine = airing.episodeLine {
                    Text(episodeLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineLimit(1)
                }
                Text(airing.whenLine)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
                if scheduled {
                    // The capsule the old On Later row drew, kept exactly (frame 5a, dc:465-467).
                    Text("● Scheduled")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.accent200)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .overlay { Capsule().strokeBorder(Nocturne.accent600, lineWidth: 1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 26)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}
