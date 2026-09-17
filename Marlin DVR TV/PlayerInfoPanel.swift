//
//  PlayerInfoPanel.swift
//  Marlin DVR TV
//
//  Pass 108 (owner decisions, 2026-09-16): the Player's own info panel. While a recording or a live
//  channel plays, a swipe down on the remote's touch surface or a click down on its ring opens it
//  over the video (`PlayerHost` catches both), and its buttons take focus while it is up. Menu closes
//  it; Menu again leaves the Player as it always has.
//
//  What it shows: the channel logo, the show's title, the episode name, season and episode, HD and
//  rating tags when the server provides them, and the description. **No channel number** — which is
//  why nothing here uses `PlayRequest.title` or `.subtitle`, both of which carry one.
//
//   · **Live describes and acts on the show airing on the channel now**, not the one that was on
//     when it was tuned — "Just show the current show" (owner). So the panel reads `GET /api/guide/now`
//     every time it opens, and again when that airing ends while it is still up. A channel with
//     nothing in the guide shows the channel and only Favorite / Unfavorite (foreman's call).
//   · **A recording's logo** is the channel whose number and name spell the recording's channel
//     text (`"9001 HISTORY"`), from `GET /api/channels`; nothing matches, no logo (foreman's call).
//     The server gives a recording no channel id (Pass 107 §2.2).
//   · **Tags are HD and rating only** (foreman's call). Live: the channel's `hd`, which is what the
//     airing sheet draws (`AiringSheet.swift:116`), and the programme's `rating`. Recording: `"HD"`
//     from the server's `tags`, and the rating from `meta.rating`, which is the value the server
//     appends to those same `tags` (`library.go:589-591`, marlin-dvr 1.8.1).
//
//  The buttons do what the app's existing control of that kind does, with the same result messages
//  (owner). Each screen's own function is `private`, so each is **mirrored here, not called**, and
//  none of those screens is changed:
//
//    Record (live)              AiringSheet.record()                AiringSheet.swift:352-369
//    ● Recording / ● Scheduled  AiringSheet.airingState, Pass 49    AiringSheet.swift:83-88, 250-257
//    Add to pass / Edit pass    AiringSheet.recordSeries(), editor  AiringSheet.swift:371-395, 137-157
//    Add to season pass / Edit  ShowDetailScreen.recordSeries()     ShowDetailScreen.swift:356-380, 160-180
//    Favorite / Unfavorite      ChannelActionsMenu.apply()          ChannelActionsMenu.swift:83-94
//
//  What is called unchanged: the server calls (`APIClient`), `AiringSheet.matchingPass(in:program:)`,
//  `ShowDetailScreen.matchingPass(in:showTitle:)`, `AiringSheet.friendly`, `WriteError.text`,
//  `StateChip`, `EditSeriesPassScreen` and `GuideChannelTile.artFeedPath`. There is **no "Stop
//  recording"** (foreman's call). The screens underneath show a change made here the next time
//  they are opened; nothing here tells them.
//
//  **Every write route below is unconfirmed at the running server's version** (1.9.3 when Pass 107
//  read it); each rests on the 1.8.1 source: `POST /api/record`, `POST /api/passes`,
//  `PUT` / `DELETE /api/passes/{id}` (inside the editor) and `PUT /api/sources/{id}/lineup/{guid}`.
//
//  **The panel's position and look were chosen by Pass 108, not by the owner** — there is no design
//  for it. It is built to the app's look: the Nocturne surface across the top of the screen at the
//  standard 60 / 80 pt margins, the way the airing sheet and the Player's own HUDs are drawn.
//
//  Pass 109 (owner decision, 2026-09-16): **with the panel up, a swipe up on the touch surface or a
//  click up on the ring closes it, the same as Menu does.** Menu is unchanged. Both reach `onClose`,
//  the one call Menu's `.onExitCommand` makes:
//   · The **click up** is a move command, so `.onMoveCommand` on the card catches it while focus is on
//     one of the panel's own controls. Nothing focusable sits above them, and the Player's container
//     refuses focus back into the video while the panel is up (Pass 108), so an Up here moves nothing.
//   · The **swipe up** gets a `UISwipeGestureRecognizer` of its own, installed on the window only for as
//     long as the panel is on screen (`SwipeUpDetector`, the `RemoteHoldDetector` pattern). It is on the
//     window because the panel's focused button is not inside the Player's container, where Pass 108's
//     swipe-down recognizer lives.
//  **Neither acts while the pass editor is open over the panel.** There Up moves between the editor's
//  rows, as it does wherever the editor is opened, and Menu closes the editor first, as before.
//

import SwiftUI
import UIKit

struct PlayerInfoPanel: View {
    let request: PlayRequest
    let api: APIClient
    let onClose: () -> Void

    @FocusState private var focused: String?

    // Live: what is airing on the channel now, and the channel as that read returned it.
    @State private var loaded = false
    @State private var loadError: String?
    @State private var program: Program?
    @State private var liveChannel: MergedChannel?
    @State private var favourite = false
    @State private var job: Job?
    // Recording: the channel its channel text names, for the logo.
    @State private var recordingChannel: MergedChannel?
    // The sheet's own four (`AiringSheet.swift:57-61`) and its editor.
    @State private var pass: PassView?
    @State private var editingPass: PassView?
    @State private var busy: String?
    @State private var message: String?
    @State private var failed = false

    /// Every control is this wide, so a chip and the buttons beside it line up.
    private static let controlWidth: CGFloat = 340
    private static let logoSize: CGFloat = 140

    private var isLive: Bool { request.channel != nil }

    /// The title show detail matches passes on and creates them with (`ShowDetailScreen.swift:128`):
    /// the show's own title, which the Player carries as `show`, else the recording's.
    private var showTitle: String {
        if case .recording(let episode, let show, _) = request { return show?.title ?? episode.show }
        return ""
    }

    // MARK: The fields

    private var logoChannel: MergedChannel? {
        isLive ? (liveChannel ?? request.channel) : recordingChannel
    }

    private var title: String? {
        isLive ? program?.title : showTitle
    }

    /// "S4 E14 · Who Is D.B. Cooper?" — season and episode, then the episode name.
    private var episodeLine: String? {
        var parts: [String] = []
        if let episode = request.episode {
            // The app's own form for a recording (`PlayRequest.swift:115`, `EpisodeRow`).
            if episode.season > 0 || episode.episode > 0 { parts.append("S\(episode.season) E\(episode.episode)") }
            if !episode.episodeTitle.isEmpty { parts.append(episode.episodeTitle) }
        } else if let program {
            let season = program.season ?? 0, number = program.episode ?? 0
            if season > 0 || number > 0 {
                parts.append("S\(season) E\(number)")
            } else if let n = program.episodeNum, !n.isEmpty {
                parts.append(n)     // a listing with no season and episode, e.g. "E185"
            }
            if let t = program.episodeTitle, !t.isEmpty { parts.append(t) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// HD and rating, and nothing else.
    private var tags: [String] {
        var out: [String] = []
        if let episode = request.episode {
            if episode.tags.contains("HD") { out.append("HD") }
            if let rating = episode.meta?.rating, !rating.isEmpty, rating != "None" { out.append(rating) }
        } else if program != nil {
            if logoChannel?.hd == true { out.append("HD") }
            if let rating = program?.rating, !rating.isEmpty { out.append(rating) }
        }
        return out
    }

    private var descriptionText: String? {
        if let episode = request.episode { return episode.description.isEmpty ? nil : episode.description }
        guard let desc = program?.desc, !desc.isEmpty else { return nil }
        return desc
    }

    // MARK: The airing's own state (live) — `AiringSheet.airingState`, Pass 49

    private enum AiringState { case recording, scheduled, unbooked }

    private var airingState: AiringState {
        guard let job else { return .unbooked }
        if job.status == "Recording" { return .recording }
        if job.status == "Queued" || job.status == "Conflict" { return .scheduled }
        return .unbooked
    }

    /// Where focus goes: the loading line until live has read what is on, then the first control
    /// that can take it — the sheet's own rule (`AiringSheet.swift:185-187`) when there is an airing.
    private var firstFocusID: String {
        if !isLive { return "pass" }
        if !loaded { return "loading" }
        if program == nil { return "favorite" }
        return airingState == .unbooked ? "record" : "series"
    }

    // MARK: The view

    var body: some View {
        ZStack(alignment: .top) {
            card
                .disabled(editingPass != nil)
                // Pass 109: a click up closes the panel. On the card, not the root, so an Up inside the
                // editor — a sibling of the card — stays the editor's own row-to-row move.
                .onMoveCommand { direction in
                    guard direction == .up, editingPass == nil else { return }
                    print("[panel] click up → closed")
                    onClose()
                }
                .padding(.top, Nocturne.Layout.marginVertical)
                .padding(.horizontal, Nocturne.Layout.marginHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The one editor a pass is reached through from anywhere — the airing sheet's
            // (`AiringSheet.swift:137-157`) and show detail's (`ShowDetailScreen.swift:160-180`). It
            // carries its own `.onExitCommand`, so Menu closes it and not this panel.
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
                        if let program { Task { job = await scheduleJob(for: program) ?? job } }
                        focusSoon { focused = isLive ? "series" : "pass" }
                    },
                    onClose: {
                        self.editingPass = nil
                        focusSoon { focused = isLive ? "series" : "pass" }
                    }
                )
            }
        }
        .focusSection()
        .onExitCommand { onClose() }
        // Pass 109: a swipe up closes the panel — but not from inside the editor.
        .background {
            SwipeUpDetector {
                guard editingPass == nil else { return }
                print("[panel] swipe up → closed")
                onClose()
            }
            .frame(width: 1, height: 1)
        }
        .task {
            focusSoon { focused = firstFocusID }
            if isLive {
                await loadLive()
                focusSoon { if focused == nil || focused == "loading" { focused = firstFocusID } }
            } else {
                await loadRecording()
            }
        }
        .task(id: program?.end) { await reloadWhenTheAiringEnds() }
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 44) {
            if let channel = logoChannel {
                PanelChannelLogo(channel: channel, size: Self.logoSize)
            }
            VStack(alignment: .leading, spacing: 0) {
                if isLive && !loaded {
                    LoadingLine()
                        .focusable()
                        .focused($focused, equals: "loading")
                } else {
                    details
                    buttons
                    footer
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(44)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Nocturne.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
    }

    @ViewBuilder
    private var details: some View {
        if let title {
            Text(title)
                .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                .tracking(-0.015 * Nocturne.TextSize.screenTitle)
                .foregroundStyle(Nocturne.text)
                .lineLimit(2)
                .padding(.bottom, 8)
                .accessibilityIdentifier("infoPanel.title")
        }
        if let episodeLine {
            Text(episodeLine)
                .font(.nocturne(Nocturne.TextSize.cardTitle))
                .foregroundStyle(Nocturne.neutral300)
                .lineLimit(1)
                .padding(.bottom, 12)
                .accessibilityIdentifier("infoPanel.episode")
        }
        if !tags.isEmpty {
            HStack(spacing: 12) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(text: tag)
                        .accessibilityIdentifier("infoPanel.tag")
                }
            }
            .padding(.bottom, 16)
        }
        if let loadError {
            ErrorLine(text: loadError)
                .padding(.bottom, 12)
        }
        if let descriptionText {
            Text(descriptionText)
                .font(.nocturne(Nocturne.TextSize.body))
                .foregroundStyle(Nocturne.neutral300)
                .lineSpacing(6)
                .lineLimit(3)
                .padding(.bottom, 26)
                .accessibilityIdentifier("infoPanel.description")
        }
    }

    // MARK: The buttons

    @ViewBuilder
    private var buttons: some View {
        if !isLive {
            // Show detail's control (`ShowDetailScreen.swift:260-266`), under the owner's labels.
            action(pass == nil ? "Add to season pass" : "Edit pass", id: "pass") {
                if let pass {
                    editingPass = pass
                } else {
                    await recordSeriesFromTheShow()
                }
            }
        } else if program == nil {
            favouriteButton
        } else {
            HStack(spacing: 16) {
                // Pass 49: a status where the airing already has one, a button only when it has none.
                switch airingState {
                case .recording:
                    StateChip(text: "● Recording", color: GuideMark.green)
                        .frame(width: Self.controlWidth)
                case .scheduled:
                    StateChip(text: "● Scheduled", detail: job?.status ?? "", color: GuideMark.green)
                        .frame(width: Self.controlWidth)
                case .unbooked:
                    action("Record", id: "record", primary: true) { await record() }
                }
                // One control, not two branches — the sheet's own reason (`AiringSheet.swift:258-259`).
                action(pass == nil ? "Add to pass" : "Edit pass", id: "series") {
                    if let pass {
                        editingPass = pass
                    } else {
                        await recordSeriesFromTheAiring()
                    }
                }
                favouriteButton
            }
        }
    }

    private var favouriteButton: some View {
        action(favourite ? "Unfavorite" : "Favorite", id: "favorite") { await toggleFavourite() }
    }

    /// The sheet's button helper (`AiringSheet.swift:285-294`), every control the same width.
    private func action(_ title: String, id: String, primary: Bool = false, run: @escaping () async -> Void) -> some View {
        Button {
            guard busy == nil else { return }
            Task { await run() }
        } label: {
            InertActionButton(title: busy == id ? "Working…" : title, primary: primary, focused: focused == id, flexible: true)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
        .frame(width: Self.controlWidth)
        .accessibilityIdentifier("infoPanel.\(id)")
    }

    /// The sheet's footer (`AiringSheet.swift:298-321`): the last write's answer, else the pass this
    /// show has, and the airing's Conflict. Show detail's (`ShowDetailScreen.swift:301-318`) is the
    /// same without the Conflict line, which a recording has no airing for.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(failed ? Nocturne.neutral200 : Nocturne.accent200)
                    .lineLimit(2)
                    .accessibilityIdentifier("infoPanel.message")
            } else if let pass {
                Text("◆ Series pass · \(pass.countLabel) · \(pass.recordMode == "all" ? "all episodes" : "new episodes")")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(GuideMark.gold)
                    .lineLimit(1)
                    .accessibilityIdentifier("infoPanel.passLine")
            }
            if isLive, let job, job.status == "Conflict" {
                Text("✕ Conflict: \(job.reason ?? "the server reports a tuner conflict")")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
            }
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Reading

    /// Live: what is airing on this channel now. `GET /api/guide/now` answers for the whole lineup
    /// and takes no channel (`guide.go:726-750`), so the channel is picked out of it here. A channel
    /// that is not in that answer has nothing in the guide, and its favourite flag then comes from
    /// `GET /api/channels`.
    private func loadLive() async {
        guard let tuned = request.channel else { return }
        do {
            let now = try await api.onNow()
            if let item = now.first(where: { $0.channel.id == tuned.id }), let airing = item.program {
                liveChannel = item.channel
                favourite = item.channel.favorite
                program = airing
            } else {
                program = nil
                if let channel = try? await api.channels().first(where: { $0.id == tuned.id }) {
                    liveChannel = channel
                }
                favourite = (liveChannel ?? tuned).favorite
            }
            loadError = nil
        } catch {
            program = nil
            favourite = (liveChannel ?? tuned).favorite
            loadError = "\(error)"
            print("[panel] guide/now: \(error)")
        }
        if let program {
            // The sheet reads the pass and the schedule when it opens (`AiringSheet.swift:161-172`).
            async let passRead: Void = loadAiringPass(program)
            async let jobRead = scheduleJob(for: program)
            job = await jobRead
            await passRead
        } else {
            pass = nil
            job = nil
        }
        loaded = true
        print("[panel] live \(tuned.id): \(program.map { "\"\($0.title)\" \($0.start)-\($0.end)" } ?? "nothing in the guide") · job \(job?.status ?? "none") · pass \(pass?.id ?? "none") · favorite \(favourite)")
    }

    /// Recording: show detail's `loadPass()` and the channel the recording's channel text names.
    private func loadRecording() async {
        async let passRead: Void = loadRecordingPass()
        async let channelRead: Void = loadRecordingChannel()
        _ = await (passRead, channelRead)
        loaded = true
    }

    /// `ShowDetailScreen.loadPass()` (`:327-337`).
    private func loadRecordingPass() async {
        do {
            let all = try await api.passes()
            pass = ShowDetailScreen.matchingPass(in: all, showTitle: showTitle)
            print("[panel] pass for \"\(showTitle)\": \(pass.map { "\($0.id) \($0.countLabel)" } ?? "none")")
        } catch {
            print("[panel] passes: \(error)")
        }
    }

    /// `AiringSheet.loadPass()` (`:328-338`).
    private func loadAiringPass(_ program: Program) async {
        do {
            let all = try await api.passes()
            pass = AiringSheet.matchingPass(in: all, program: program)
            if let pass {
                print("[panel] pass for \"\(program.title)\": \(pass.id) \(pass.countLabel)")
            }
        } catch {
            print("[panel] passes: \(error)")
        }
    }

    /// The channel whose number and name, joined by one space, spell the recording's channel text —
    /// the way the recorder writes it (`recorder.go:301`, `j.Number + " " + j.ChannelName`). No
    /// match, no logo.
    private func loadRecordingChannel() async {
        guard let text = request.episode?.channel, !text.isEmpty else { return }
        do {
            let channels = try await api.channels()
            recordingChannel = channels.first { "\($0.number) \($0.name)" == text }
            print("[panel] recording channel \"\(text)\" → \(recordingChannel?.id ?? "no match, no logo")")
        } catch {
            print("[panel] channels: \(error)")
        }
    }

    /// What the sheet's `onScheduleChanged` is: the Guide's `refreshSchedule()` and
    /// `job(channelId:programStart:)` (`GuideScreen.swift:266-272`, `:249-251`). Nil when there is no
    /// job for the airing or the read fails, and the callers keep what they had, as the sheet does.
    private func scheduleJob(for program: Program) async -> Job? {
        guard let channel = request.channel else { return nil }
        do {
            return try await api.schedule().jobs.first { $0.channelId == channel.id && $0.program.start == program.start }
        } catch {
            print("[panel] schedule: \(error)")
            return nil
        }
    }

    /// "Just show the current show": an airing that ends while the panel is still up is replaced by
    /// the next one. A message about the airing that ended goes with it.
    private func reloadWhenTheAiringEnds() async {
        guard isLive, let end = program?.end else { return }
        let wait = Double(end) - Date().timeIntervalSince1970 + 2
        try? await Task.sleep(for: .seconds(wait > 0 ? wait : 30))
        guard !Task.isCancelled else { return }
        let before = program?.start
        await loadLive()
        if program?.start != before {
            message = nil
            failed = false
        }
        focusSoon { if focused == nil { focused = firstFocusID } }
    }

    // MARK: The writes, each mirroring the control it is named for

    /// "Record" — `AiringSheet.record()` (`:352-369`). `POST /api/record`, unconfirmed at the running
    /// server's version.
    private func record() async {
        guard let program, let channel = request.channel else { return }
        busy = "record"
        failed = false
        message = nil
        do {
            let outcome = try await api.recordNow(channelId: channel.id, start: program.start)
            var line = "Set to record · \(outcome.status)"
            if let reason = outcome.reason, !reason.isEmpty { line += " · \(reason)" }
            message = line
            job = await scheduleJob(for: program) ?? job
            focused = "series"
        } catch {
            failed = true
            message = AiringSheet.friendly(error, fallback: "The server could not set this recording.")
            print("[panel] record failed: \(error)")
        }
        busy = nil
    }

    /// "Add to pass" — `AiringSheet.recordSeries()` (`:371-395`). `POST /api/passes`, unconfirmed at
    /// the running server's version.
    private func recordSeriesFromTheAiring() async {
        guard let program else { return }
        busy = "series"
        failed = false
        message = nil
        do {
            let created = try await api.createPass(title: program.title, seriesId: program.seriesId)
            pass = created
            message = "Series pass created · \(created.countLabel)"
            job = await scheduleJob(for: program) ?? job
            focused = "series"
        } catch let error as APIError where error.httpStatus == 409 {
            await loadAiringPass(program)
            failed = false
            message = pass == nil
                ? "This show already has a series pass."
                : "This show already has a series pass — use Edit series pass."
            print("[panel] pass 409, reloaded: \(pass?.id ?? "not found")")
        } catch {
            failed = true
            message = AiringSheet.friendly(error, fallback: "The server could not create the series pass.")
            print("[panel] pass failed: \(error)")
        }
        busy = nil
    }

    /// "Add to season pass" — `ShowDetailScreen.recordSeries()` (`:356-380`). `POST /api/passes`,
    /// unconfirmed at the running server's version.
    private func recordSeriesFromTheShow() async {
        busy = "pass"
        failed = false
        message = nil
        do {
            let created = try await api.createPass(title: showTitle, seriesId: nil)
            pass = created
            message = "Series pass created · \(created.countLabel)"
            focused = "pass"
        } catch let error as APIError where error.httpStatus == 409 {
            await loadRecordingPass()
            failed = false
            message = pass == nil
                ? "This show already has a series pass."
                : "This show already has a series pass — use Edit series pass."
            print("[panel] pass 409, reloaded: \(pass?.id ?? "not found")")
        } catch {
            failed = true
            message = AiringSheet.friendly(error, fallback: "The server could not create the series pass.")
            print("[panel] pass failed: \(error)")
        }
        busy = nil
    }

    /// "Favorite" / "Unfavorite" — `ChannelActionsMenu.apply()` (`:83-94`), the Guide's hold.
    /// `PUT /api/sources/{sourceId}/lineup/{guid}`, unconfirmed at the running server's version, and
    /// server-wide: the web UI and the other Apple TV see it too.
    private func toggleFavourite() async {
        guard let channel = liveChannel ?? request.channel else { return }
        busy = "favorite"
        failed = false
        message = nil
        do {
            let override = try await api.setChannelFavourite(sourceId: channel.sourceId, guid: channel.guid, favourite: !favourite)
            favourite = override.favorite
        } catch {
            failed = true
            message = WriteError.text(error)
            print("[channel] favourite failed: \(error)")
        }
        busy = nil
    }
}

/// The channel's logo at the panel's size: `GuideChannelTile`'s drawing (`GuideScreen.swift:846-894`,
/// Pass 86) — the logo through `/api/art/feed`, fitted inside a light backing, and the initials tile
/// with no backing when there is no logo or it fails to load.
private struct PanelChannelLogo: View {
    let channel: MergedChannel
    let size: CGFloat

    private var inset: CGFloat { size * GuideChannelTile.logoInset / GuideChannelTile.size }
    @State private var showingInitials = false

    var body: some View {
        Group {
            if let path = GuideChannelTile.artFeedPath(for: channel.logo) {
                ZStack {
                    if !showingInitials {
                        RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous)
                            .fill(Nocturne.neutral200)
                    }
                    ServerImage(path: path, contentMode: .fit) {
                        initials
                            .padding(-inset)
                            .onAppear { showingInitials = true }
                            .onDisappear { showingInitials = false }
                    }
                    .padding(inset)
                }
                .frame(width: size, height: size)
            } else {
                initials
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(channel.name)
        .accessibilityIdentifier("infoPanel.logo")
    }

    private var initials: some View {
        InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: size, fontSize: size * 26 / 82)
    }
}

// MARK: Pass 109 — the swipe up

/// A zero-size view that puts one swipe-up recognizer on the window while it is on screen, and takes it
/// off again when it leaves — `RemoteHoldDetector`'s pattern (`RemoteHold.swift:89-153`). The panel puts
/// it in its background, so the recognizer exists exactly as long as the panel does.
private struct SwipeUpDetector: UIViewRepresentable {
    let onSwipeUp: () -> Void

    func makeUIView(context: Context) -> SwipeUpProbeView {
        SwipeUpProbeView(onSwipeUp: onSwipeUp)
    }

    func updateUIView(_ view: SwipeUpProbeView, context: Context) {
        view.onSwipeUp = onSwipeUp
    }

    static func dismantleUIView(_ view: SwipeUpProbeView, coordinator: ()) {
        view.uninstall()
    }
}

private final class SwipeUpProbeView: UIView, UIGestureRecognizerDelegate {
    var onSwipeUp: () -> Void
    private var recognizer: UISwipeGestureRecognizer?
    private weak var installedOn: UIWindow?

    init(onSwipeUp: @escaping () -> Void) {
        self.onSwipeUp = onSwipeUp
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if installedOn != nil, installedOn !== window { uninstall() }
        guard let window, recognizer == nil else { return }
        // Touches only, no press type: the click up is the card's move command, and this must never
        // claim a press from anything else on the screen.
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
        swipe.direction = .up
        swipe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        swipe.allowedPressTypes = []
        swipe.cancelsTouchesInView = false
        swipe.delaysTouchesBegan = false
        swipe.delaysTouchesEnded = false
        swipe.delegate = self
        window.addGestureRecognizer(swipe)
        recognizer = swipe
        installedOn = window
    }

    func uninstall() {
        if let recognizer { installedOn?.removeGestureRecognizer(recognizer) }
        recognizer = nil
        installedOn = nil
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else { return }
        onSwipeUp()
    }

    /// It only watches: focus movement and every other recognizer keep every touch they would have had.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
