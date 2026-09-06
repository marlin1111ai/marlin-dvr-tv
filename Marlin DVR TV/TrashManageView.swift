//
//  TrashManageView.swift
//  Marlin DVR TV
//
//  Pass 10 step 2d: the recordings the trash flag holds. The library has no trash endpoint of
//  its own, so `ManageModel` assembles the list show by show from
//  `GET /api/library/shows/{id}?trash=1` (library.go:586-640).
//
//    Restore      PUT /api/library/recordings/{id} {"trash": false}   library.go:643-694
//    Empty Trash  POST /api/library/trash/empty                       trash.go:194-222
//
//  Restore is safe and happens on one click. Empty Trash is not: it deletes the files on
//  disk, permanently, for every client at once — so it arms on the first click and says so,
//  and only the second click sends it.
//

import SwiftUI

struct TrashManageView: View {
    let api: APIClient
    let model: ManageModel
    let onLeave: () -> Void

    @FocusState private var focused: String?
    @State private var busy: String?
    @State private var emptyArmed = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ScreenHeader("Trash", subtitle: subtitle) {
                emptyButton
            }
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.accent200)
                    .lineLimit(2)
            }
            if let error {
                Text(error)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral200)
                    .lineLimit(2)
            }
            if model.trash.isEmpty {
                Text("The trash is empty. Deleting a recording from a show's episode list puts it here until the server's trash period expires.")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.vertical, 20)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(model.trash) { episode in
                        Button {
                            Task { await restore(episode) }
                        } label: {
                            TrashRow(episode: episode,
                                     busy: busy == episode.id,
                                     focused: focused == episode.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: episode.id)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 1400, alignment: .leading)
            }
            Text("A restored recording goes straight back into its show. Until then the server removes trashed files on its own when the trash period expires.")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral600)
                .lineLimit(2)
        }
        .onAppear { focusSoon { focused = model.trash.first?.id ?? "empty" } }
        .onExitCommand { onLeave() }
    }

    private var subtitle: String? {
        let n = model.trash.count
        return n == 0 ? "empty" : "\(n) recording\(n == 1 ? "" : "s")"
    }

    /// Top right: the destructive one, behind two clicks.
    private var emptyButton: some View {
        Button {
            Task { await empty() }
        } label: {
            InertActionButton(
                title: busy == "empty" ? "Emptying…" : (emptyArmed ? "Delete them permanently — click again" : "Empty Trash"),
                primary: false,
                focused: focused == "empty",
                size: Nocturne.TextSize.secondary
            )
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: "empty")
        .disabled(model.trash.isEmpty)
        .opacity(model.trash.isEmpty ? 0.4 : 1)
    }

    private func restore(_ episode: Episode) async {
        guard busy == nil else { return }
        busy = episode.id
        error = nil
        message = nil
        do {
            _ = try await api.updateRecording(id: episode.id, flag: .trash(false))
            message = "Restored \(episode.show) to its show."
            await model.refreshTrash()
            focusSoon { focused = model.trash.first?.id ?? "empty" }
        } catch {
            self.error = WriteError.text(error)
            print("[trash] restore failed: \(error)")
        }
        busy = nil
    }

    private func empty() async {
        guard busy == nil, !model.trash.isEmpty else { return }
        guard emptyArmed else {
            emptyArmed = true
            message = "This deletes the files on disk for good — for the web UI and the other Apple TV too."
            return
        }
        busy = "empty"
        error = nil
        do {
            let result = try await api.emptyTrash()
            message = "Emptied the trash · \(result.deleted) deleted · \(result.freed) freed"
                + (result.failed > 0 ? " · \(result.failed) failed" : "")
            emptyArmed = false
            await model.refreshTrash()
            focusSoon { focused = model.trash.first?.id ?? "empty" }
        } catch {
            self.error = WriteError.text(error)
            emptyArmed = false
            print("[trash] empty failed: \(error)")
        }
        busy = nil
    }
}

/// One trashed recording: which show it came from, which episode, and when it aired.
struct TrashRow: View {
    let episode: Episode
    let busy: Bool
    let focused: Bool

    private var episodeLine: String {
        var parts: [String] = []
        if episode.season > 0 || episode.episode > 0 { parts.append("S\(episode.season) E\(episode.episode)") }
        if !episode.episodeTitle.isEmpty { parts.append(episode.episodeTitle) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ServerImage(path: episode.thumb) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(episode.show)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                if !episodeLine.isEmpty {
                    Text(episodeLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                }
                Text("\(episode.dateLabel) · \(episode.sizeLabel)")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(busy ? "Restoring…" : "Restore")
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(focused ? Nocturne.text : Nocturne.neutral400)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}
