//
//  TrashManageView.swift
//  Marlin DVR TV
//
//  Pass 10 step 2d: the recordings the trash flag holds.
//
//    The list    GET  /api/library/trash                              server 1.6.0
//    Restore     PUT  /api/library/recordings/{id} {"trash": false}   library.go:643-694
//    Empty Trash POST /api/library/trash/empty                        trash.go:194-222
//
//  Pass 33 moved the list onto the server's own trash endpoint. It answers every trashed
//  recording, including those whose show has left the library — which the show-by-show walk
//  this screen used before could never reach, and which is most of the owner's trash.
//
//  The listing is thinner than an `Episode`: eight fields, no thumbnail and none of the
//  server's own labels, so the row draws the show's poster (the per-recording thumbnail 404s
//  once a recording is trashed) and makes its own date and size text. Restore is unchanged and
//  keyed by the recording id, which the listing carries and which trashing does not alter.
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
                // Focusable, and holding the "empty" focus id, because it is the only thing left
                // on the screen once the last recording is restored: the rows are gone and the
                // Empty Trash button is disabled, so without this nothing can take focus and the
                // remote's Menu never reaches `.onExitCommand` — it leaves the app instead.
                // Found on the device, Pass 33 (the run at 21:13, report §3).
                Text(model.trashError == nil
                     ? "The trash is empty. Deleting a recording from a show's episode list puts it here until the server's trash period expires."
                     : "The trash could not be read — \(model.trashError!)")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.vertical, 20)
                    .focusable()
                    .focused($focused, equals: "empty")
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(model.trash) { item in
                        Button {
                            Task { await restore(item) }
                        } label: {
                            TrashRow(item: item,
                                     busy: busy == item.id,
                                     focused: focused == item.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: item.id)
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
        guard n > 0 else { return model.trashError == nil ? "empty" : "could not read" }
        return "\(n) recording\(n == 1 ? "" : "s") · \(SizeFormat.serverStyle(model.trashBytes))"
    }

    /// Top right: the destructive one, behind two clicks.
    private var emptyButton: some View {
        Button {
            Task { await empty() }
        } label: {
            InertActionButton(
                title: busy == "empty" ? "Emptying…" : (emptyArmed ? "Delete them permanently — click again" : "Empty Trash"),
                primary: false,
                focused: focused == "empty-trash",
                size: Nocturne.TextSize.secondary
            )
        }
        .buttonStyle(BareButtonStyle())
        .focused($focused, equals: "empty-trash")
        .disabled(model.trash.isEmpty)
        .opacity(model.trash.isEmpty ? 0.4 : 1)
    }

    /// One click, no arming: Restore puts the file back and destroys nothing. The list is then
    /// re-read rather than edited in place (Pass 31's rule), so what the screen shows next is
    /// the server's answer and not this app's guess at it.
    private func restore(_ item: TrashItem) async {
        guard busy == nil else { return }
        busy = item.id
        error = nil
        message = nil
        do {
            let update = try await api.updateRecording(id: item.id, flag: .trash(false))
            switch update {
            case .episode(let episode) where episode.trash:
                // The server answered, but the flag did not come off. Say so rather than
                // claiming a restore the list is about to contradict.
                self.error = "\(item.show) is still in the trash — the server kept the flag."
            case .episode, .deleted:
                message = "Restored \(item.show)\(item.episodeTitle.isEmpty ? "" : " · \(item.episodeTitle)") to its show."
            }
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

/// One trashed recording: which show it came from, which episode, when it aired, how much room
/// it is holding, and when it went into the trash.
///
/// The poster is the show's, not the recording's: `GET /api/library/recordings/{id}/thumb.jpg`
/// answers 404 for every trashed recording (measured, Pass 33 §1), while `GET /api/art/show`
/// answers by title and so still works for a show that has left the library.
struct TrashRow: View {
    let item: TrashItem
    let busy: Bool
    let focused: Bool

    /// "S2 E20 · Surviving the '70s", and whichever half the listing has.
    private var episodeLine: String {
        var parts: [String] = []
        if item.season > 0 || item.episode > 0 { parts.append("S\(item.season) E\(item.episode)") }
        if !item.episodeTitle.isEmpty { parts.append(item.episodeTitle) }
        return parts.joined(separator: " · ")
    }

    /// "Aired Sun Sep 6 · 1.86 GB", falling back to the raw stamp if it will not parse.
    private var airedLine: String {
        let size = SizeFormat.serverStyle(item.size)
        guard let date = ServerTime.date(item.aired) else { return size }
        return "Aired \(TimeFormat.shortDay(date)) · \(size)"
    }

    /// "Trashed today at 11:12 AM" — the one thing the old per-show list could not say.
    private var trashedLine: String {
        guard let date = ServerTime.date(item.trashedAt) else { return "" }
        let day = Calendar.current.isDateInToday(date) ? "today" : TimeFormat.shortDay(date)
        return "Trashed \(day) at \(TimeFormat.clock(date))"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ServerImage(path: item.artPath) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 52, height: 78)      // the design's 2:3 poster, at row height
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.show)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                if !episodeLine.isEmpty {
                    Text(episodeLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                }
                Text(trashedLine.isEmpty ? airedLine : "\(airedLine) · \(trashedLine)")
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
