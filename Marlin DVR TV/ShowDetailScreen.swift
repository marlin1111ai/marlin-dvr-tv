//
//  ShowDetailScreen.swift
//  Marlin DVR TV
//
//  Show detail, frame 5d (dc:588-646): poster, title, "N episodes · M unwatched · size ·
//  channel" (size = the sum of episode sizes), the buttons (inert; no resume line until the
//  resume store exists), and the episodes newest first with S/E, title, ✓ Watched,
//  description, aired, the duration only when the server already cached the probe (it then
//  sits in `airedLabel`; nothing calls ffprobe), size and tags. Data: GET /api/library/shows/{id}.
//

import SwiftUI

@Observable
final class ShowDetailModel {
    private let api: APIClient
    let show: ShowSummary
    private(set) var detail: ShowResponse?
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient, show: ShowSummary) {
        self.api = api
        self.show = show
    }

    func load() async {
        do {
            detail = try await api.show(id: show.id)
            error = nil
        } catch {
            self.error = "\(error)"
            print("[show] library/shows: \(error)")
        }
        loaded = true
    }

    /// "41 episodes · 3 unwatched · 128 GB · HGTV"
    var summaryLine: String? {
        guard let d = detail else { return nil }
        let unwatched = d.episodes.filter { !$0.watched }.count
        let bytes = d.episodes.reduce(0) { $0 + $1.size }
        var parts = ["\(d.count) episode\(d.count == 1 ? "" : "s")", "\(unwatched) unwatched", SizeFormat.bytes(bytes)]
        if let channel = commonChannel(d.episodes) { parts.append(channel) }
        return parts.joined(separator: " · ")
    }

    private func commonChannel(_ episodes: [Episode]) -> String? {
        var counts: [String: Int] = [:]
        for e in episodes where !e.channel.isEmpty { counts[e.channel, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }
}

struct ShowDetailScreen: View {
    @State private var model: ShowDetailModel
    @FocusState private var focused: String?

    init(api: APIClient, show: ShowSummary) {
        _model = State(initialValue: ShowDetailModel(api: api, show: show))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 64) {
            leftColumn
            episodes
        }
        .defaultFocus($focused, "newest")
        .task {
            focusSoon { focused = "newest" }
            await model.load()
        }
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
            HStack(spacing: 16) {
                inert("Play newest", id: "newest")
                inert("Series pass", id: "pass")
            }
            .padding(.top, 6)
            if let error = model.error {
                ErrorLine(text: error)
            }
        }
        .frame(width: 520, alignment: .topLeading)
    }

    private func inert(_ title: String, id: String) -> some View {
        Button {
            // Play newest is the Player's (sweep 3); Series pass is a write (sweep 4).
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
                    ForEach(model.detail?.episodes ?? []) { episode in
                        Button {
                            // Playing and the long-press menu are later sweeps'.
                        } label: {
                            EpisodeRow(episode: episode, focused: focused == episode.id)
                        }
                        .buttonStyle(BareButtonStyle())
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
    }
}

/// One episode row (dc:615-641), without the resume bar (sweep 3).
struct EpisodeRow: View {
    let episode: Episode
    let focused: Bool

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
                    if episode.watched {
                        Text("✓ Watched")
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
