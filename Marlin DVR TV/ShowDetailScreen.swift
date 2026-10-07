//
//  ShowDetailScreen.swift
//  Marlin DVR TV
//
//  Show detail, frame 5d (dc:588-646): poster, title, "N episodes · M unwatched · size ·
//  channel" (size = the sum of episode sizes), the resume line and the play buttons, and the
//  episodes newest first with S/E, title, ✓ Watched, description, aired, the duration only
//  when the server already cached the probe (it then sits in `airedLabel`; nothing calls
//  ffprobe), size and tags. Data: GET /api/library/shows/{id}.
//
//  Sweep 4, step 3: click and hold an episode opens EpisodeActionsMenu — Keep, Favorite,
//  Mark unwatched, Delete. The row redraws from the `episodeView` the server returns, and a
//  trashed episode leaves the list (the counts and the size line follow it).
//
//  Pass 103 (inventory item A1): the button that sat inert since Pass 8 is now the airing
//  sheet's series-pass control, reached from a show instead of an airing. The owner's decision
//  (2026-09-16) is that it behaves exactly as the sheet's does — "Record the series" with no
//  pass, "Edit series pass" once there is one, the same route, the same editor and the same
//  result text under the buttons — so the flow here mirrors `AiringSheet.recordSeries()`
//  (`AiringSheet.swift:371-395`) and `AiringSheet`'s editor block (`:137-157`) line for line,
//  and `EditSeriesPassScreen` and `AiringSheet.friendly` are called unchanged. There is no
//  `recordMode: "new"` warning, because the sheet has none (Pass 8 Open Question 3, still open
//  for both screens).
//
//  Two deliberate differences from the sheet, both because a show is not an airing:
//   · **No `onScheduleChanged()`.** The sheet re-reads `GET /api/schedule` after the write to
//     refresh the Guide's ● / ◆ marks and its own first control. This screen draws nothing from
//     the schedule and has no airing state, so there is nothing to refresh and no read is made.
//     The result text is unaffected — `countLabel` comes from the POST's own `passView`.
//   · **The match is on the title alone.** `AiringSheet.matchingPass(in:program:)` needs a
//     `Program`; a show has none. Of the three rules it applies (`:340-350`) only two can bear
//     on a title-only subject — the `"title:<lower>"` id the server derives for a listing with
//     no `seriesId`, and the pass title — and those two are exactly what the server itself
//     applies to fill `ShowResponse.pass` (`library.go:659-664`). So `matchingPass(in:showTitle:)`
//     below is that pair, and `AiringSheet.swift` is not touched.
//
//  Pass 31: that write changes the library the Recordings shelves behind this screen are
//  drawn from, and they had no way of knowing. `onLibraryChanged` tells them, so the owner
//  does not have to leave Recordings and come back to see a deleted recording go.
//
//  Pass 133 (server 1.13.0, contract §15): an episode still being written carries `inProgress`,
//  and its row says "● Recording now". Picking it — the row, Play newest or Resume — opens
//  `WatchChoiceMenu` (end of this file) with the two ways to watch it: the file so far, or the
//  channel live. The row's date line is now the server's own two strings, `dateLabel` (the
//  original air date when the guide gave one) and `airedLabel` (when it was recorded), as the
//  owner chose on 2026-10-06; nothing is formatted from `aired` here any more.
//

import SwiftUI

@Observable
final class ShowDetailModel {
    private let api: APIClient
    let show: ShowSummary
    private(set) var detail: ShowResponse?
    /// The visible episodes: the server's list, kept current by the long-press writes.
    private(set) var episodes: [Episode] = []
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient, show: ShowSummary) {
        self.api = api
        self.show = show
    }

    func load() async {
        do {
            let response = try await api.show(id: show.id)
            detail = response
            episodes = response.episodes
            error = nil
        } catch {
            self.error = "\(error)"
            print("[show] library/shows: \(error)")
        }
        loaded = true
    }

    /// After PUT /api/library/recordings/{id}: the server's updated episode, or nil when the
    /// recording is in the trash and leaves the visible list (library.go:643-694).
    func apply(_ updated: Episode?, to id: String) {
        guard let index = episodes.firstIndex(where: { $0.id == id }) else { return }
        if let updated {
            episodes[index] = updated
        } else {
            episodes.remove(at: index)
        }
        // Pass 120 (REVIEW.md S9): the Player is handed `detail` (`play(_:from:)`), and its
        // next-episode countdown picks from `detail.episodes` (`PlayRequest.nextEpisode`). So the
        // same write lands there too, or a deleted episode is offered — and auto-played — as next.
        if let detail {
            self.detail = ShowResponse(id: detail.id, title: detail.title, episodes: episodes,
                                       count: detail.count, trashCount: detail.trashCount,
                                       showingTrash: detail.showingTrash, art: detail.art,
                                       info: detail.info, pass: detail.pass, rss: detail.rss)
        }
    }

    /// "41 episodes · 3 unwatched · 128 GB · HGTV" — counted from the visible episodes.
    var summaryLine: String? {
        guard detail != nil else { return nil }
        let count = episodes.count
        let unwatched = episodes.filter { !$0.watched }.count
        let bytes = episodes.reduce(0) { $0 + $1.size }
        var parts = ["\(count) episode\(count == 1 ? "" : "s")", "\(unwatched) unwatched", SizeFormat.bytes(bytes)]
        if let channel = commonChannel(episodes) { parts.append(channel) }
        return parts.joined(separator: " · ")
    }

    private func commonChannel(_ episodes: [Episode]) -> String? {
        var counts: [String: Int] = [:]
        for e in episodes where !e.channel.isEmpty { counts[e.channel, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }
}

struct ShowDetailScreen: View {
    let api: APIClient
    let onPlay: (PlayRequest) -> Void
    /// The server accepted a write on one of these episodes, so `GET /api/library` now answers
    /// differently than it did when the shelves behind this screen were read.
    let onLibraryChanged: () -> Void
    @Environment(RemoteHold.self) private var hold
    @State private var model: ShowDetailModel
    @FocusState private var focused: String?
    @State private var resumeTick = 0   // re-read the resume store after the Player closes
    @State private var menuEpisode: Episode?
    /// Pass 133: the recording-now episode whose two ways to watch are being offered, and the
    /// control it was picked from, for the remote to go back to when the menu closes.
    @State private var watchChoice: Episode?
    @State private var watchChoiceFrom: String?
    // Pass 103, the sheet's own four (`AiringSheet.swift:57-61`), minus the airing's `job`.
    @State private var pass: PassView?
    @State private var editingPass: PassView?
    @State private var busy: String?
    @State private var message: String?
    @State private var failed = false

    init(api: APIClient, show: ShowSummary, onPlay: @escaping (PlayRequest) -> Void, onLibraryChanged: @escaping () -> Void) {
        self.api = api
        self.onPlay = onPlay
        self.onLibraryChanged = onLibraryChanged
        _model = State(initialValue: ShowDetailModel(api: api, show: show))
    }

    /// The title the screen draws, which is also the one the server matched to fill
    /// `ShowResponse.pass` and the one `createPass` derives `"title:<lower>"` from.
    private var showTitle: String { model.detail?.title ?? model.show.title }

    /// The most recently saved position among this show's episodes (frame 5d "Resume S9 E11 · 22 min in").
    private var resume: (episode: Episode, entry: ResumeStore.Entry)? {
        _ = resumeTick
        return ResumeStore.latest(among: model.episodes)
    }

    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 64) {
                leftColumn
                episodes
            }
            .disabled(menuEpisode != nil || editingPass != nil || watchChoice != nil)
            if let menuEpisode {
                EpisodeActionsMenu(
                    episode: menuEpisode,
                    api: api,
                    onApplied: { updated in
                        model.apply(updated, to: menuEpisode.id)
                        onLibraryChanged()
                        closeMenu()
                    },
                    onClose: closeMenu
                )
            }
            if let watchChoice {
                WatchChoiceMenu(
                    episode: watchChoice,
                    show: model.detail,
                    api: api,
                    onPlay: { request in
                        let back = watchChoiceFrom
                        self.watchChoice = nil
                        watchChoiceFrom = nil
                        onPlay(request)
                        focusSoon { focused = back ?? model.episodes.first?.id ?? "newest" }
                    },
                    onClose: closeWatchChoice
                )
            }
            // Pass 103: the one editor a pass is reached through from anywhere — the same screen
            // the Guide's "Edit series pass" opens, through the sheet (`AiringSheet.swift:137`),
            // and the same one Manage DVR opens. It carries its own `.onExitCommand`
            // (`EditSeriesPassScreen.swift:134`), so Menu closes it and not this screen, exactly
            // as `EpisodeActionsMenu` above already does.
            if let editingPass {
                EditSeriesPassScreen(
                    pass: editingPass,
                    api: api,
                    onChanged: { updated in
                        pass = updated
                        self.editingPass = updated
                    },
                    onDeleted: {
                        pass = nil
                        self.editingPass = nil
                        message = "Series pass deleted."
                        failed = false
                        focusSoon { focused = "pass" }
                    },
                    onClose: {
                        self.editingPass = nil
                        focusSoon { focused = "pass" }
                    }
                )
            }
        }
        .defaultFocus($focused, resume != nil ? "resume" : "newest")
        .task {
            await model.load()
            focusSoon { focused = resume != nil ? "resume" : "newest" }
            // After `load()`, so the match uses the title the server itself answered with. The
            // button reads "Record the series" until this returns — the sheet's own behaviour
            // (`AiringSheet.swift:161-163`), and a press inside that window is what the 409
            // branch of `recordSeries()` exists to catch.
            await loadPass()
        }
        .onAppear { resumeTick += 1 }
        .onChange(of: hold.holds) { _, _ in handleHold() }
    }

    /// A hold opens the actions menu for the focused episode; anything else is left alone.
    private func handleHold() {
        guard menuEpisode == nil, editingPass == nil, watchChoice == nil, let focus = focused,
              let episode = model.episodes.first(where: { $0.id == focus }) else { return }
        hold.armSwallow()
        menuEpisode = episode
    }

    private func closeMenu() {
        let id = menuEpisode?.id
        menuEpisode = nil
        focusSoon { focused = model.episodes.contains { $0.id == id } ? id : (model.episodes.first?.id ?? "newest") }
    }

    private func play(_ episode: Episode, from start: Double) {
        // Pass 133: a recording still being written is offered its two ways to watch instead of
        // being played straight away (contract §15); the menu reads the saved place itself.
        if episode.inProgress {
            watchChoiceFrom = focused
            watchChoice = episode
            return
        }
        onPlay(.recording(episode: episode, show: model.detail, start: start))
    }

    private func closeWatchChoice() {
        let back = watchChoiceFrom
        watchChoice = nil
        watchChoiceFrom = nil
        focusSoon { focused = back ?? model.episodes.first?.id ?? "newest" }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            ServerImage(path: model.detail?.art ?? model.show.art) {
                ArtPlaceholder()
            }
            .frame(width: 520, height: 472)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(Nocturne.hairline, lineWidth: 1)
            }
            Text(model.detail?.title ?? model.show.title)
                .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                .tracking(-0.015 * Nocturne.TextSize.screenTitle)
                .foregroundStyle(Nocturne.text)
                .lineLimit(2)
            if let line = model.summaryLine {
                Text(line)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
            }
            if let resume {
                let label = "Resume S\(resume.episode.season) E\(resume.episode.episode) · \(ResumeStore.label(for: resume.entry))"
                Button {
                    play(resume.episode, from: resume.entry.position)
                } label: {
                    InertActionButton(title: label, primary: true, focused: focused == "resume", size: Nocturne.TextSize.body)
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: "resume")
                .padding(.top, 6)
            }
            HStack(spacing: 16) {
                Button {
                    if let newest = model.episodes.first {
                        play(newest, from: ResumeStore.entry(for: newest.id)?.position ?? 0)
                    }
                } label: {
                    InertActionButton(title: "Play newest", primary: false, focused: focused == "newest", size: Nocturne.TextSize.secondary)
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: "newest")
                // Pass 103. One control with two labels, not two controls — the sheet's own
                // reason (`AiringSheet.swift:258-259`): swapping the view would drop focus the
                // moment the pass is created.
                action(pass == nil ? "Record the series" : "Edit series pass", id: "pass") {
                    if let pass {
                        editingPass = pass
                    } else {
                        await recordSeries()
                    }
                }
            }
            .padding(.top, 6)
            passFooter
            if let error = model.error {
                ErrorLine(text: error)
            }
        }
        .frame(width: 520, alignment: .topLeading)
        // Without a focus section the engine will not cross from these buttons (low on the
        // screen) to the episode rows (high on the right); the episodes were unreachable.
        .focusSection()
    }

    /// The sheet's button helper (`AiringSheet.swift:285-294`) at this screen's own size: the
    /// row of two in frame 5d is not the sheet's row of three, so `size` stays
    /// `Nocturne.TextSize.secondary` and `flexible` stays off, as "Play newest" beside it is.
    private func action(_ title: String, id: String, run: @escaping () async -> Void) -> some View {
        Button {
            guard busy == nil else { return }
            Task { await run() }
        } label: {
            InertActionButton(title: busy == id ? "Working…" : title,
                              primary: false,
                              focused: focused == id,
                              size: Nocturne.TextSize.secondary)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
    }

    /// The server's answer to the last write, or the pass this show already has — the sheet's
    /// footer (`AiringSheet.swift:298-321`) without its Conflict line, which belongs to an
    /// airing's job and this screen has none. Directly under the buttons, as the sheet has it.
    @ViewBuilder
    private var passFooter: some View {
        if let message {
            Text(message)
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(failed ? Nocturne.neutral200 : Nocturne.accent200)
                .lineLimit(2)
        } else if let pass {
            // `.lineLimit(2)`, where the sheet's same line is `.lineLimit(1)`. The sheet draws it
            // across a 1400 pt card; this column is 520 pt, and the first run on Home Theater
            // photographed it cut to "◆ Series pass · 5 recordings scheduled · all episod…". The
            // text is the sheet's, unchanged — only the room it is given differs, and it matches
            // the message line above, which is already `.lineLimit(2)` in both screens.
            Text("◆ Series pass · \(pass.countLabel) · \(pass.recordMode == "all" ? "all episodes" : "new episodes")")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(GuideMark.gold)
                .lineLimit(2)
        }
    }

    // MARK: The series pass (Pass 103)

    /// Does the server already hold a pass for this show? One `GET /api/passes`, matched on the
    /// title — see the file header for why that is the whole test here, and why
    /// `ShowResponse.pass` (the matching pass *title*, `Models.swift:407`) is not what is used:
    /// opening the editor needs the `PassView` itself, and one read answering both questions
    /// beats two sources for one fact.
    private func loadPass() async {
        do {
            let all = try await api.passes()
            pass = Self.matchingPass(in: all, showTitle: showTitle)
            if let pass {
                print("[show] pass for \"\(showTitle)\": \(pass.id) \(pass.countLabel)")
            }
        } catch {
            print("[show] passes: \(error)")
        }
    }

    static func matchingPass(in passes: [PassView], showTitle: String) -> PassView? {
        let title = showTitle.lowercased()
        let derived = "title:" + title
        return passes.first { $0.seriesId.lowercased() == derived || $0.title.lowercased() == title }
    }

    /// "Record the series" — `AiringSheet.recordSeries()` (`:371-395`) with the show's title in
    /// place of the airing's and no `seriesId` to pass on, which is the case `createPass` already
    /// handles: it sends none and the server derives `"title:<lower>"` from the title
    /// (`ServerWrites.swift:192-197`, passes.go:718-725).
    ///
    /// **`POST /api/passes` is unconfirmed at the running server** — it is a write, so Pass 102
    /// never called it and neither did Pass 103, and the newest source readable is the 1.8.1 clone
    /// (`reports/2026-09-16-pass102-a1-a5-recon.md` §0). The running server answered **1.9.2** on
    /// `GET /api/status` the day this was written, where the notebook still records the 1.9.1 Pass
    /// 101 measured. The app has sent this route from the sheet since Pass 9, which is why the 409
    /// branch is written the way it is — not why the route is trusted.
    private func recordSeries() async {
        busy = "pass"
        failed = false
        message = nil
        do {
            let created = try await api.createPass(title: showTitle, seriesId: nil)
            pass = created
            message = "Series pass created · \(created.countLabel)"
            focused = "pass"
        } catch let error as APIError where error.httpStatus == 409 {
            // Never the raw 409, and never a dead end: reload and say what is true now, so the
            // button is already "Edit series pass" by the time the sentence is read.
            await loadPass()
            failed = false
            message = pass == nil
                ? "This show already has a series pass."
                : "This show already has a series pass — use Edit series pass."
            print("[show] pass 409, reloaded: \(pass?.id ?? "not found")")
        } catch {
            failed = true
            message = AiringSheet.friendly(error, fallback: "The server could not create the series pass.")
            print("[show] pass failed: \(error)")
        }
        busy = nil
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Episodes")
                    .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                    .foregroundStyle(Nocturne.text)
                Spacer(minLength: 0)
                Text("Newest first")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
            }
            if !model.loaded {
                LoadingLine()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(model.episodes) { episode in
                        HoldButton(hold: hold) {
                            play(episode, from: ResumeStore.entry(for: episode.id)?.position ?? 0)   // sweep 3 entry point
                        } label: {
                            EpisodeRow(episode: episode, focused: focused == episode.id, resume: ResumeStore.entry(for: episode.id))
                        }
                        .focused($focused, equals: episode.id)
                    }
                }
                .padding(.vertical, 8)
            }
            Text("Click and hold an episode for Keep and Delete")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral600)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .focusSection()
    }
}

/// One episode row (dc:615-641), with the resume bar and the ✓ Watched / Keep / Favorite flags.
struct EpisodeRow: View {
    let episode: Episode
    let focused: Bool
    var resume: ResumeStore.Entry? = nil

    /// The resume bar on the thumb (dc:617-619): position over the length when both are known.
    private var resumeFraction: Double? {
        guard let resume, resume.duration > 0 else { return nil }
        return min(1, resume.position / resume.duration)
    }

    /// "✓ Watched" and "◆ Keep" — the server's shared flags the app now sets (library.go:68-79).
    private var flagLabels: [String] {
        var out: [String] = []
        if episode.watched { out.append("✓ Watched") }
        if episode.keep { out.append("◆ Keep") }
        return out
    }

    private var seasonEpisode: String? {
        guard episode.season > 0 || episode.episode > 0 else { return nil }
        return "S\(episode.season) E\(episode.episode)"
    }

    /// "September 7th 2026 · recorded Sep 8 at 12:03 AM, 8 min · 225.41 MB" — the server's two
    /// strings as they arrive (owner, 2026-10-06; Pass 133). `dateLabel` is the show's original
    /// air date when the guide gave one, `airedLabel` says when it was recorded and carries the
    /// duration when the server has it, and while the recording is still being written it reads
    /// "started today at 6:00 PM" (server 1.13.0, contract §15). Nothing is formatted from
    /// `aired` here any more.
    private var metaLine: String {
        var parts = [episode.dateLabel]
        if !episode.airedLabel.isEmpty { parts.append(episode.airedLabel) }
        parts.append(episode.sizeLabel)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            ServerImage(path: episode.thumb) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 236, height: 133)
            .overlay(alignment: .bottom) {
                if let fraction = resumeFraction {
                    ProgressBar(fraction: fraction)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    if let seasonEpisode {
                        Text(seasonEpisode)
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.accent300)
                    }
                    Text(episode.episodeTitle.isEmpty ? episode.show : episode.episodeTitle)
                        .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    if episode.inProgress {
                        // Pass 133: the Guide's recording mark, in its green (`GuideMark.green`).
                        Text("● Recording now")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(GuideMark.green)
                    }
                    ForEach(flagLabels, id: \.self) { label in
                        Text(label)
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                    }
                }
                Text(episode.description)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
                HStack(spacing: 16) {
                    Text(metaLine)
                        .fixedSize(horizontal: true, vertical: false)
                    ForEach(episode.tags, id: \.self) { tag in
                        Text(tag)
                            .tracking(0.06 * Nocturne.TextSize.floor)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 8)
                            .overlay {
                                RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous)
                                    .strokeBorder(Nocturne.neutral800, lineWidth: 1)
                            }
                    }
                }
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral500)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}

/// Pass 133 (server 1.13.0, contract §15): the two ways to watch a recording that is still being
/// written, in the overlay treatment of `EpisodeActionsMenu`. **Watch recording** plays the file
/// so far — the Player takes the HLS route for it (`PlayRequest.format`) — from this Apple TV's
/// saved place when it has one. **Watch live** opens the channel the server names on the episode
/// (`liveChannelId`); the channel list is read on the click, because the episode carries only the
/// id and the Player's live request takes a `MergedChannel`.
private struct WatchChoiceMenu: View {
    let episode: Episode
    let show: ShowResponse?
    let api: APIClient
    let onPlay: (PlayRequest) -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?
    @State private var busy = false
    @State private var error: String?

    private var header: String {
        var parts: [String] = []
        if episode.season > 0 || episode.episode > 0 { parts.append("S\(episode.season) E\(episode.episode)") }
        parts.append(episode.episodeTitle.isEmpty ? episode.show : episode.episodeTitle)
        return parts.joined(separator: " · ")
    }

    /// "From 22 min in" when this Apple TV has a saved place, else from the start.
    private var recordingState: String {
        if let entry = ResumeStore.entry(for: episode.id) { return "From \(ResumeStore.label(for: entry))" }
        return "From the start"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.72), Nocturne.bg.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("● Recording now · \(episode.show)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .tracking(0.12 * Nocturne.TextSize.floor)
                        .foregroundStyle(GuideMark.green)
                    Text(header)
                        .font(.nocturne(44, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(2)
                }
                VStack(spacing: 12) {
                    MenuRow(title: "Watch recording", state: recordingState, focused: focused == "recording") {
                        watchRecording()
                    }
                    .focused($focused, equals: "recording")

                    MenuRow(title: busy ? "Working…" : "Watch live", state: "The channel as it airs", focused: focused == "live") {
                        Task { await watchLive() }
                    }
                    .focused($focused, equals: "live")
                }
                Text("The recording plays from its first second while it is still being written. Watch live opens the channel itself.")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
                    .lineLimit(2)
                if let error {
                    Text(error)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral200)
                        .lineLimit(2)
                }
            }
            .padding(44)
            .frame(width: 860, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
        }
        .focusSection()
        .onExitCommand { onClose() }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = "recording"
            }
        }
    }

    private func watchRecording() {
        guard !busy else { return }
        onPlay(.recording(episode: episode, show: show, start: ResumeStore.entry(for: episode.id)?.position ?? 0))
    }

    private func watchLive() async {
        guard !busy else { return }
        guard let channelID = episode.liveChannelId, !channelID.isEmpty else {
            error = "The server did not say which channel this is being recorded from."
            return
        }
        busy = true
        error = nil
        do {
            let channels = try await api.channels()
            guard let channel = channels.first(where: { $0.id == channelID }) else {
                error = "The channel this is being recorded from is not in the channel list."
                busy = false
                return
            }
            busy = false
            onPlay(.live(channel: channel, program: nil))
        } catch {
            self.error = AiringSheet.friendly(error, fallback: "The channel list could not be read.")
            print("[show] watch live: channels failed: \(error)")
            busy = false
        }
    }
}
