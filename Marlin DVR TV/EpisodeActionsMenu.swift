//
//  EpisodeActionsMenu.swift
//  Marlin DVR TV
//
//  Sweep 4, step 3: the long-press menu of frame 5d ("Click and hold an episode for Keep,
//  Favorite, Mark unwatched, Delete", dc:643). Each row is one PUT /api/library/recordings/{id}
//  with the matching flag — {keep}, {favorite}, {watched: false}, {trash: true} — and the
//  screen redraws from the `episodeView` the server returns (library.go:643-694). Delete sets
//  the trash flag: the file stays on disk until the server's "Remove Items From Trash After"
//  period expires or the owner empties the trash; this app never empties it. Only when that
//  setting is "Immediately" does the server delete at once and answer {ok, deleted} instead.
//
//  These four flags are global on the server, not per client — the note on frame 5b says so
//  ("Watched and keep flags are shared with the other Apple TV", dc:514; library.go:68-79).
//

import SwiftUI

struct EpisodeActionsMenu: View {
    let episode: Episode
    let api: APIClient
    /// The server's updated episode, or nil when the recording went to the trash.
    let onApplied: (Episode?) -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?
    @State private var busy: String?
    @State private var error: String?

    private var header: String {
        var parts: [String] = []
        if episode.season > 0 || episode.episode > 0 { parts.append("S\(episode.season) E\(episode.episode)") }
        parts.append(episode.episodeTitle.isEmpty ? episode.show : episode.episodeTitle)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.72), Nocturne.bg.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.show)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .tracking(0.12 * Nocturne.TextSize.floor)
                        .foregroundStyle(Nocturne.accent300)
                    Text(header)
                        .font(.nocturne(44, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(2)
                }
                VStack(spacing: 12) {
                    row("Keep", id: "keep", state: episode.keep ? "On" : "Off") {
                        await write(.keep(!episode.keep))
                    }
                    row("Favorite", id: "favorite", state: episode.favorite ? "On" : "Off") {
                        await write(.favorite(!episode.favorite))
                    }
                    row("Mark unwatched", id: "unwatched", state: episode.watched ? "✓ Watched" : "Already unwatched", enabled: episode.watched) {
                        await write(.watched(false))
                    }
                    row("Delete", id: "delete", state: episode.trash ? "In the trash" : "Moves to the trash", destructive: true) {
                        await write(.trash(true))
                    }
                }
                Text("Delete sets the trash flag; the server removes the file when its trash period expires. Keep, Favorite and Watched are shared with the other Apple TV.")
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
                focused = "keep"
            }
        }
    }

    private func row(_ title: String, id: String, state: String, enabled: Bool = true, destructive: Bool = false, run: @escaping () async -> Void) -> some View {
        Button {
            guard enabled, busy == nil else { return }
            Task { await run() }
        } label: {
            HStack(spacing: 20) {
                Text(busy == id ? "Working…" : title)
                    .font(.nocturne(Nocturne.TextSize.body))
                    .foregroundStyle(enabled ? (destructive ? Nocturne.neutral100 : Nocturne.text) : Nocturne.neutral600)
                Spacer(minLength: 0)
                Text(state)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused == id ? Nocturne.accent.opacity(0.18) : Nocturne.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(focused == id ? Nocturne.accent : Nocturne.neutral800, lineWidth: focused == id ? Nocturne.Focus.ringWidth : 1)
            }
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: id)
    }

    private func write(_ flag: RecordingFlag) async {
        busy = flag.menuID
        error = nil
        do {
            let update = try await api.updateRecording(id: episode.id, flag: flag)
            switch update {
            case .episode(let updated):
                // A trashed episode leaves the visible list; every other flag redraws its row.
                onApplied(updated.trash ? nil : updated)
            case .deleted:
                onApplied(nil)
            }
        } catch {
            self.error = WriteError.text(error)
            print("[episode] \(flag.label) failed: \(error)")
        }
        busy = nil
    }
}

private extension RecordingFlag {
    /// Which menu row is working, for the "Working…" label.
    var menuID: String {
        switch self {
        case .keep: return "keep"
        case .favorite: return "favorite"
        case .watched: return "unwatched"
        case .trash: return "delete"
        }
    }
}
