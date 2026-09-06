//
//  AiringSheet.swift
//  Marlin DVR TV
//
//  The airing detail sheet of frame 5c (dc:546-580) over the guide: poster from
//  /api/art/show?title= with the channel's initials tile when the server has no art (404),
//  the flags, "number · name · HD", title, episode line, day and time range, rating,
//  description, and the action buttons.
//
//  Pass 9, from the owner's Home Theater test:
//   · step 2 — the buttons share the sheet's content width and shrink their label rather
//     than running off the screen ("Watch live" had been clipped to "W"), and the status
//     line sits directly under them, so it is always on screen.
//   · step 3 — "Watch live" appears only while the programme is actually on; a live session
//     plays what is on now (stream.go:214-218), so it is meaningless on a future airing.
//   · step 4 — the sheet reads GET /api/passes when it opens and, when this show already
//     has a pass, offers "Edit series pass" instead of "Record the series". The raw 409 is
//     never shown: if the server still refuses (a pass created elsewhere between the read
//     and the write), the sheet reloads, flips to Edit and says so in plain words.
//

import SwiftUI

struct AiringSelection: Identifiable {
    let channel: MergedChannel
    let program: Program
    let job: Job?

    var id: String { "\(channel.id)@\(program.start)" }

    /// "/api/art/show?title=<title>" (artwork.go:362-367); the route answers 404 when there is no art.
    static func artPath(for title: String) -> String? {
        var c = URLComponents()
        c.path = "/api/art/show"
        c.queryItems = [URLQueryItem(name: "title", value: title)]
        return c.string
    }
}

struct AiringSheet: View {
    let selection: AiringSelection
    let api: APIClient
    let onWatchLive: () -> Void
    /// Refetches GET /api/schedule for the guide's marks and hands back this airing's job.
    let onScheduleChanged: () async -> Job?

    @FocusState private var focused: String?
    @State private var job: Job?
    @State private var pass: PassView?
    @State private var editingPass: PassView?
    @State private var busy: String?
    @State private var message: String?
    @State private var failed = false
    @State private var now = Date()

    private var program: Program { selection.program }
    private var channel: MergedChannel { selection.channel }

    /// A Record Now booking on this airing: the manual job the server keeps (passes.go:60).
    private var manualJob: Job? {
        guard let job, job.passId == "manual", job.status != "Skipped" else { return nil }
        return job
    }

    /// Step 3: a live session plays what is on now, so the button only makes sense then.
    private var isAiringNow: Bool {
        let t = Int(now.timeIntervalSince1970)
        return program.start <= t && t < program.end
    }

    private var flags: [String] {
        var out: [String] = []
        if program.new == true { out.append("New") }
        if program.live == true { out.append("Live") }
        if program.premiere == true { out.append("Premiere") }
        if program.finale == true { out.append("Finale") }
        return out
    }

    private var channelLine: String {
        var parts = [channel.number, channel.name]
        if channel.hd { parts.append("HD") }
        return parts.joined(separator: " · ")
    }

    private var episodeLine: String? {
        var parts: [String] = []
        if let t = program.episodeTitle, !t.isEmpty { parts.append(t) }
        if let n = program.episodeNum, !n.isEmpty { parts.append(n) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var whenLine: String {
        var s = "\(TimeFormat.relativeDay(TimeFormat.date(program.start))) \(TimeFormat.timeRange(program.start, program.end))"
        if let r = program.rating, !r.isEmpty { s += " · \(r)" }
        return s
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.72), Nocturne.bg.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            sheetCard
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
                        Task { job = await onScheduleChanged() ?? job }
                        focusSoon { focused = "series" }
                    },
                    onClose: {
                        self.editingPass = nil
                        focusSoon { focused = "series" }
                    }
                )
            }
        }
        .focusSection()
        .task {
            job = selection.job
            await loadPass()
            try? await Task.sleep(for: .milliseconds(60))
            focused = firstFocusID
        }
        .task {
            // Keeps "Watch live" honest if the sheet is left open across the start time.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                now = Date()
            }
        }
    }

    private var firstFocusID: String {
        manualJob == nil ? "record" : "series"
    }

    private var sheetCard: some View {
        HStack(alignment: .top, spacing: 56) {
            ServerImage(path: AiringSelection.artPath(for: program.title)) {
                PosterFallback(initials: channel.initials, logoBg: channel.logoBg)
            }
            .frame(width: 340, height: 474)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    ForEach(flags, id: \.self) { TagChip(text: $0) }
                    Text(channelLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                }
                .padding(.bottom, 14)
                Text(program.title)
                    .font(.nocturne(56, .medium))
                    .tracking(-0.015 * 56)
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(2)
                    .padding(.bottom, 8)
                if let episodeLine {
                    Text(episodeLine)
                        .font(.nocturne(Nocturne.TextSize.cardTitle))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineLimit(1)
                        .padding(.bottom, 6)
                }
                Text(whenLine)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.bottom, 20)
                if let desc = program.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.nocturne(Nocturne.TextSize.body))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineSpacing(6)
                        .lineLimit(3)
                        .padding(.bottom, 26)
                }
                buttons
                footer
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(56)
        .frame(width: 1400, height: 586, alignment: .topLeading)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
    }

    // MARK: The buttons (dc:569-571), sized to the sheet

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 16) {
            if let manualJob {
                StateChip(text: "● Scheduled", detail: manualJob.status, color: GuideMark.green)
            } else {
                action("Record this airing", id: "record", primary: true) { await record() }
            }
            // One control, not two branches: swapping the view would drop focus to the rail
            // the moment the pass is created (seen on the simulator before this fix).
            action(pass == nil ? "Record the series" : "Edit series pass", id: "series", primary: false) {
                if let pass {
                    editingPass = pass
                } else {
                    await recordSeries()
                }
            }
            if isAiringNow {
                Button {
                    onWatchLive()   // the channel, whatever is on now (stream.go:214-218)
                } label: {
                    InertActionButton(title: "Watch live", primary: false, focused: focused == "watch", flexible: true)
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: "watch")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ title: String, id: String, primary: Bool, run: @escaping () async -> Void) -> some View {
        Button {
            guard busy == nil else { return }
            Task { await run() }
        } label: {
            InertActionButton(title: busy == id ? "Working…" : title, primary: primary, focused: focused == id, flexible: true)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
    }

    /// The server's answer to the last write, the pass this show already has, and the
    /// Conflict the schedule reports. Directly under the buttons so it is never off screen.
    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(failed ? Nocturne.neutral200 : Nocturne.accent200)
                    .lineLimit(2)
            } else if let pass {
                Text("◆ Series pass · \(pass.countLabel) · \(pass.recordMode == "all" ? "all episodes" : "new episodes")")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(GuideMark.gold)
                    .lineLimit(1)
            }
            if let job, job.status == "Conflict" {
                Text("✕ Conflict: \(job.reason ?? "the server reports a tuner conflict")")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
            }
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The writes

    /// Step 4: does the server already hold a pass for this show? Matched on the airing's
    /// `seriesId`, then on the "title:<lower>" id the server derives when a listing has none,
    /// then on the pass title — the same three the server itself compares (passes.go:719-726).
    private func loadPass() async {
        do {
            let all = try await api.passes()
            pass = Self.matchingPass(in: all, program: program)
            if let pass {
                print("[sheet] pass for \"\(program.title)\": \(pass.id) \(pass.countLabel)")
            }
        } catch {
            print("[sheet] passes: \(error)")
        }
    }

    static func matchingPass(in passes: [PassView], program: Program) -> PassView? {
        let title = program.title.lowercased()
        let series = (program.seriesId ?? "").lowercased()
        let derived = "title:" + title
        return passes.first { p in
            let ps = p.seriesId.lowercased()
            if !series.isEmpty && ps == series { return true }
            if ps == derived { return true }
            return p.title.lowercased() == title
        }
    }

    private func record() async {
        busy = "record"
        failed = false
        message = nil
        do {
            let outcome = try await api.recordNow(channelId: channel.id, start: program.start)
            var line = "Set to record · \(outcome.status)"
            if let reason = outcome.reason, !reason.isEmpty { line += " · \(reason)" }
            message = line
            job = await onScheduleChanged() ?? job
            focused = "series"
        } catch {
            failed = true
            message = Self.friendly(error, fallback: "The server could not set this recording.")
            print("[sheet] record failed: \(error)")
        }
        busy = nil
    }

    private func recordSeries() async {
        busy = "series"
        failed = false
        message = nil
        do {
            let created = try await api.createPass(title: program.title, seriesId: program.seriesId)
            pass = created
            message = "Series pass created · \(created.countLabel)"
            job = await onScheduleChanged() ?? job
            focused = "series"
        } catch let error as APIError where error.httpStatus == 409 {
            // Step 4: never the raw 409. Someone else made the pass; show what is true now.
            await loadPass()
            failed = false
            message = pass == nil
                ? "This show already has a series pass."
                : "This show already has a series pass — use Edit series pass."
            print("[sheet] pass 409, reloaded: \(pass?.id ?? "not found")")
        } catch {
            failed = true
            message = Self.friendly(error, fallback: "The server could not create the series pass.")
            print("[sheet] pass failed: \(error)")
        }
        busy = nil
    }

    /// The server's plain-text body reads well for the cases the owner can act on; anything
    /// else becomes the fallback sentence. Never a bare status code.
    static func friendly(_ error: Error, fallback: String) -> String {
        guard let api = error as? APIError, let status = api.httpStatus else { return fallback }
        let text = api.message.trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case 400 where text.contains("already ended"): return "That airing has already ended."
        case 404: return "The server has no listing for that airing any more."
        case 409 where text.contains("already set to record"): return "That airing is already set to record."
        default: return text.isEmpty ? fallback : text.prefix(1).uppercased() + text.dropFirst() + "."
        }
    }
}

/// A finished state where a button was: "● Scheduled" with the server's status beside it.
struct StateChip: View {
    let text: String
    var detail: String = ""
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.nocturne(Nocturne.TextSize.body))
                .foregroundStyle(Nocturne.neutral100)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !detail.isEmpty {
                Text(detail)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral300)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, detail.isEmpty ? 18 : 10)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(color.mix(with: Nocturne.surface, by: 0.82), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                .strokeBorder(color, lineWidth: 1)
        }
    }
}

/// The initials tile at poster size, for programs the server has no art for.
struct PosterFallback: View {
    let initials: String
    let logoBg: String

    var body: some View {
        RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
            .fill(Color(hexString: logoBg) ?? Nocturne.neutral800)
            .overlay {
                Text(initials)
                    .font(.nocturne(88, .semibold))
                    .foregroundStyle(Nocturne.neutral100)
            }
    }
}
