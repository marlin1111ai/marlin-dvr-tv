//
//  AiringSheet.swift
//  Marlin DVR TV
//
//  The airing detail sheet of frame 5c (dc:546-580) over the guide: poster from
//  /api/art/show?title= with the channel's initials tile when the server has no art (404),
//  the flags, "number · name · HD", title, episode line, day and time range, rating,
//  description, the three buttons (inert until sweeps 3 and 4), and the server's Conflict
//  status for this airing's job when /api/schedule reports one. No conflict is predicted.
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
    let onWatchLive: () -> Void
    @FocusState private var focused: String?

    private var program: Program { selection.program }
    private var channel: MergedChannel { selection.channel }

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
                            .lineLimit(5)
                            .frame(maxWidth: 820, alignment: .leading)
                            .padding(.bottom, 34)
                    }
                    HStack(spacing: 20) {
                        inert("Record this airing", id: "record", primary: true)
                        inert("Record the series", id: "series", primary: false)
                        Button {
                            onWatchLive()   // sweep 3 entry point: the channel, whatever is on now (stream.go:214-218)
                        } label: {
                            InertActionButton(title: "Watch live", primary: false, focused: focused == "watch")
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: "watch")
                    }
                    Spacer(minLength: 0)
                    if let job = selection.job, job.status == "Conflict" {
                        HStack(spacing: 14) {
                            Text("✕").foregroundStyle(Nocturne.neutral200)
                            Text("Conflict: \(job.reason ?? "the server reports a tuner conflict")")
                        }
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .padding(.top, 30)
                    }
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
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = "record"
            }
        }
    }

    private func inert(_ title: String, id: String, primary: Bool) -> some View {
        Button {
            // Owned by sweep 3 (Watch live) and sweep 4 (Record this airing, Record the series).
        } label: {
            InertActionButton(title: title, primary: primary, focused: focused == id)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
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
