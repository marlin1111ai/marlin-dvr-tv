//
//  EpisodeActionsMenu.swift
//  Marlin DVR TV
//
//  The click-and-hold menu on an episode of frame 5d (dc:643). Pass 8 built the four the
//  design's footer names; after the Home Theater test the owner dropped two of them, so
//  Pass 9 step 6 leaves **Keep** and **Delete**:
//
//    Keep    PUT /api/library/recordings/{id} {"keep": …}    library.go:643-694
//    Delete  PUT /api/library/recordings/{id} {"trash": true}
//
//  Delete sets the trash flag; the file stays on disk until the server's "Remove Items From
//  Trash After" period expires. Only when that setting is "Immediately" does the server
//  delete at once and answer `{ok, deleted}` instead of the episode (library.go:683-691).
//  Both flags are global on the server, not per client (dc:514; library.go:68-79).
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
                    MenuRow(title: busy == "keep" ? "Working…" : "Keep",
                            state: episode.keep ? "On" : "Off",
                            focused: focused == "keep") {
                        Task { await write(.keep(!episode.keep)) }
                    }
                    .focused($focused, equals: "keep")

                    MenuRow(title: busy == "delete" ? "Working…" : "Delete",
                            state: episode.trash ? "In the trash" : "Moves to the trash",
                            focused: focused == "delete") {
                        Task { await write(.trash(true)) }
                    }
                    .focused($focused, equals: "delete")
                }
                Text("Delete sets the trash flag; the server removes the file when its trash period expires. Keep is shared with the other Apple TV.")
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

    private func write(_ flag: RecordingFlag) async {
        guard busy == nil else { return }
        busy = flag.menuID
        error = nil
        do {
            let update = try await api.updateRecording(id: episode.id, flag: flag)
            switch update {
            case .episode(let updated):
                // A trashed episode leaves the visible list; Keep redraws its row.
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
        case .trash: return "delete"
        case .favorite, .watched: return "other"
        }
    }
}
