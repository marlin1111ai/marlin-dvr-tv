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
//  trashed episode leaves the list (the counts and the size line follow it). "Series pass"
//  stays inert: this pass wires the airing sheet's series pass only (Pass 8 scope lock).
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
    @State private var model: ShowDetailModel
    @FocusState private var focused: String?
    @State private var resumeTick = 0   // re-read the resume store after the Player closes
    @State private var menuEpisode: Episode?

    init(api: APIClient, show: ShowSummary, onPlay: @escaping (PlayRequest) -> Void) {
        self.api = api
        self.onPlay = onPlay
        _model = State(initialValue: ShowDetailModel(api: api, show: show))
    }

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
            .disabled(menuEpisode != nil)
            if let menuEpisode {
                EpisodeActionsMenu(
                    episode: menuEpisode,
                    api: api,
                    onApplied: { updated in
                        model.apply(updated, to: menuEpisode.id)
                        closeMenu()
                    },
                    onClose: closeMenu
                )
            }
        }
        .defaultFocus($focused, resume != nil ? "resume" : "newest")
        .task {
            await model.load()
            focusSoon { focused = resume != nil ? "resume" : "newest" }
        }
        .onAppear { resumeTick += 1 }
    }

    private func closeMenu() {
        let id = menuEpisode?.id
        menuEpisode = nil
        focusSoon { focused = model.episodes.contains { $0.id == id } ? id : (model.episodes.first?.id ?? "newest") }
    }

    private func play(_ episode: Episode, from start: Double) {
        onPlay(.recording(episode: episode, show: model.detail, start: start))
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
                inert("Series pass", id: "pass")
            }
            .padding(.top, 6)
            if let error = model.error {
                ErrorLine(text: error)
            }
        }
        .frame(width: 520, alignment: .topLeading)
        // Without a focus section the engine will not cross from these buttons (low on the
        // screen) to the episode rows (high on the right); the episodes were unreachable.
        .focusSection()
    }

    private func inert(_ title: String, id: String) -> some View {
        Button {
            // "Series pass" here is not in Pass 8's steps (the airing sheet's is); it stays inert.
        } label: {
            InertActionButton(title: title, primary: false, focused: focused == id, size: Nocturne.TextSize.secondary)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
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
                        HoldButton {
                            play(episode, from: ResumeStore.entry(for: episode.id)?.position ?? 0)   // sweep 3 entry point
                        } onHold: {
                            menuEpisode = episode        // frame 5d, dc:643
                        } label: {
                            EpisodeRow(episode: episode, focused: focused == episode.id, resume: ResumeStore.entry(for: episode.id))
                        }
                        .focused($focused, equals: episode.id)
                    }
                }
                .padding(.vertical, 8)
            }
            Text("Click and hold an episode for Keep, Favorite, Mark unwatched, Delete")
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

    /// "✓ Watched", "★ Favorite", "◆ Keep" — the server's shared flags (library.go:68-79).
    private var flagLabels: [String] {
        var out: [String] = []
        if episode.watched { out.append("✓ Watched") }
        if episode.favorite { out.append("★ Favorite") }
        if episode.keep { out.append("◆ Keep") }
        return out
    }

    private var seasonEpisode: String? {
        guard episode.season > 0 || episode.episode > 0 else { return nil }
        return "S\(episode.season) E\(episode.episode)"
    }

    private var airedLine: String {
        let date = ISO8601DateFormatter().date(from: episode.aired)
        if let date { return "Aired \(date.formatted(.dateTime.month(.abbreviated).day().year()))" }
        return episode.dateLabel
    }

    /// "Aired Sep 5, 2026 · 16 min · 579.35 MB" — the duration only when the server had it cached.
    private var metaLine: String {
        var parts = [airedLine]
        if let duration = episode.airedLabel.cachedDurationSuffix { parts.append(duration) }
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
