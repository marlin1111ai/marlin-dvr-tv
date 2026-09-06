//
//  AiringSheet.swift
//  Marlin DVR TV
//
//  The airing detail sheet of frame 5c (dc:546-580) over the guide: poster from
//  /api/art/show?title= with the channel's initials tile when the server has no art (404),
//  the flags, "number · name · HD", title, episode line, day and time range, rating,
//  description, and the three buttons. Sweep 4 wires the two writes: "Record this airing"
//  → POST /api/record and "Record the series" → POST /api/passes. After either, the guide's
//  schedule is refetched, the sheet redraws from the job the server now reports, and the
//  server's own words are shown — the returned `Job.status`/`reason`, or the plain-text
//  error of a 400/404/409. No conflict is predicted before booking (Pass 4 Open Question 6).
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
    @State private var passTitle: String?
    @State private var busy: String?
    @State private var message: String?
    @State private var failed = false

    private var program: Program { selection.program }
    private var channel: MergedChannel { selection.channel }

    /// A Record Now booking on this airing: the manual job the server keeps (passes.go:60).
    private var manualJob: Job? {
        guard let job, job.passId == "manual", job.status != "Skipped" else { return nil }
        return job
    }

    /// A series pass covering this airing, either found on the schedule or just created here.
    private var passLine: String? {
        if let passTitle { return passTitle }
        guard let job, job.passId != "manual", job.status != "Skipped" else { return nil }
        return job.passTitle
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
                    .padding(.bottom, 16)
                    Text(program.title)
                        .font(.nocturne(60, .medium))
                        .tracking(-0.015 * 60)
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(2)
                        .padding(.bottom, 10)
                    if let episodeLine {
                        Text(episodeLine)
                            .font(.nocturne(Nocturne.TextSize.cardTitle))
                            .foregroundStyle(Nocturne.neutral300)
                            .lineLimit(1)
                            .padding(.bottom, 8)
                    }
                    Text(whenLine)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                        .padding(.bottom, 26)
                    if let desc = program.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.nocturne(Nocturne.TextSize.body))
                            .foregroundStyle(Nocturne.neutral300)
                            .lineSpacing(6)
                            .lineLimit(4)
                            .frame(maxWidth: 820, alignment: .leading)
                            .padding(.bottom, 30)
                    }
                    buttons
                    Spacer(minLength: 0)
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(56)
            .frame(width: 1400, height: 586, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
        }
        .focusSection()
        .onAppear {
            job = selection.job
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = manualJob != nil ? "series" : "record"
            }
        }
    }

    // MARK: The three buttons (dc:569-571)

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 20) {
            if let manualJob {
                StateChip(text: "● Scheduled · \(manualJob.status)", color: GuideMark.green)
            } else {
                action("Record this airing", id: "record", primary: true) { await record() }
            }
            if let passLine {
                StateChip(text: "◆ Series pass · \(passLine)", color: GuideMark.gold)
            } else {
                action("Record the series", id: "series", primary: false) { await recordSeries() }
            }
            Button {
                onWatchLive()   // the channel, whatever is on now (stream.go:214-218)
            } label: {
                InertActionButton(title: "Watch live", primary: false, focused: focused == "watch")
            }
            .buttonStyle(BareButtonStyle())
            .focused($focused, equals: "watch")
        }
    }

    private func action(_ title: String, id: String, primary: Bool, run: @escaping () async -> Void) -> some View {
        Button {
            guard busy == nil else { return }
            Task { await run() }
        } label: {
            InertActionButton(title: busy == id ? "Working…" : title, primary: primary, focused: focused == id)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
    }

    /// The server's answer to the last write, or the Conflict the schedule already reports.
    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(failed ? Nocturne.neutral200 : Nocturne.accent200)
                    .lineLimit(2)
            }
            if let job, job.status == "Conflict" {
                Text("✕ Conflict: \(job.reason ?? "the server reports a tuner conflict")")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
            }
        }
        .padding(.top, 26)
    }

    // MARK: The two writes

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
            // The button is replaced by the state chip, so hand focus on rather than lose it.
            focused = passLine == nil ? "series" : "watch"
        } catch {
            failed = true
            message = WriteError.text(error)
            print("[sheet] record failed: \(error)")
        }
        busy = nil
    }

    private func recordSeries() async {
        busy = "series"
        failed = false
        message = nil
        do {
            let pass = try await api.createPass(title: program.title, seriesId: program.seriesId)
            passTitle = pass.title
            message = "Series pass created · \(pass.countLabel)"
            job = await onScheduleChanged() ?? job
            focused = "watch"
        } catch {
            failed = true
            message = WriteError.text(error)
            print("[sheet] pass failed: \(error)")
        }
        busy = nil
    }
}

/// A finished state where a button was: "● Scheduled · Queued", "◆ Series pass · Forged in Fire".
struct StateChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.nocturne(Nocturne.TextSize.body))
            .foregroundStyle(Nocturne.neutral100)
            .padding(.vertical, 18)
            .padding(.horizontal, 36)
            .background(color.mix(with: Nocturne.surface, by: 0.82), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(color, lineWidth: 1)
            }
            .lineLimit(1)
            .fixedSize()
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
