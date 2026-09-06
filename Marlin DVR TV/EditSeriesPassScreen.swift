//
//  EditSeriesPassScreen.swift
//  Marlin DVR TV
//
//  Pass 9 step 5: the screen behind the airing sheet's "Edit series pass". It shows the
//  settings the server holds for that pass and writes each change straight away with
//  `PUT /api/passes/{id}` (passes.go:740-796; `applyPassReq` takes any subset of the request,
//  :619-700), then redraws from the `passView` the server answers with — so what is on
//  screen is always the server's own state, never a guess.
//
//  The settings:
//    Record        recordMode  "new" | "all"                     passes.go:626-632
//    Start early   padBefore   minutes                           passes.go:641, 176-190
//    Stop late     padAfter    minutes
//    Keep          keepMode + keepLast/keepUnwatched             passes.go:652-681, 193-208
//    Pause         paused      (Pass 10 step 2c)                 passes.go:688-690
//
//  Pass 10 opens this same editor from Manage DVR → Your Passes and from a scheduled
//  airing's "Manage pass", so there is one editor for a pass wherever it is reached from.
//
//  Each row cycles to the next value on a click, which suits a remote with no keyboard, and
//  the row's right-hand side always reads the server's rendered label (`keepLabel`,
//  `padBeforeLabel`, `padAfterLabel`). "Delete this pass" arms first and deletes on the
//  second click, so a stray press cannot drop a pass.
//

import SwiftUI

struct EditSeriesPassScreen: View {
    let pass: PassView
    let api: APIClient
    let onChanged: (PassView) -> Void
    let onDeleted: () -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?
    @State private var busy: String?
    @State private var error: String?
    @State private var deleteArmed = false

    /// The choices each row cycles through.
    static let padChoices = [0, 1, 2, 5, 10, 15, 30]

    /// keepMode plus its number, in the order the row steps through them.
    static let keepChoices: [(mode: String, last: Int, unwatched: Int, label: String)] = [
        ("all", 0, 0, "All"),
        ("unwatched", 0, 0, "Unwatched Only"),
        ("last", 3, 0, "Last 3 Only"),
        ("last", 5, 0, "Last 5 Only"),
        ("last", 10, 0, "Last 10 Only"),
    ]

    private var recordLabel: String {
        pass.recordMode == "all" ? "All episodes" : "New episodes only"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.82), Nocturne.bg.opacity(0.96)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SERIES PASS")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .tracking(0.12 * Nocturne.TextSize.floor)
                        .foregroundStyle(GuideMark.gold)
                    Text(pass.title)
                        .font(.nocturne(48, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    Text("\(pass.countLabel) · \(pass.channel.isEmpty ? "any channel" : pass.channel)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral500)
                }
                VStack(spacing: 10) {
                    MenuRow(title: busy == "record" ? "Working…" : "Record",
                            state: recordLabel,
                            focused: focused == "record") {
                        Task { await cycleRecordMode() }
                    }
                    .focused($focused, equals: "record")

                    MenuRow(title: busy == "before" ? "Working…" : "Start early",
                            state: pass.padBeforeLabel,
                            focused: focused == "before") {
                        Task { await cyclePad(before: true) }
                    }
                    .focused($focused, equals: "before")

                    MenuRow(title: busy == "after" ? "Working…" : "Stop late",
                            state: pass.padAfterLabel,
                            focused: focused == "after") {
                        Task { await cyclePad(before: false) }
                    }
                    .focused($focused, equals: "after")

                    MenuRow(title: busy == "keep" ? "Working…" : "Keep",
                            state: pass.keepLabel,
                            focused: focused == "keep") {
                        Task { await cycleKeep() }
                    }
                    .focused($focused, equals: "keep")

                    MenuRow(title: busy == "paused" ? "Working…" : (pass.paused ? "Resume" : "Pause"),
                            state: pass.paused ? "Paused — nothing is queued" : "Running",
                            focused: focused == "paused") {
                        Task { await send(id: "paused", PassEdit(paused: !pass.paused)) }
                    }
                    .focused($focused, equals: "paused")

                    MenuRow(title: busy == "delete" ? "Deleting…" : (deleteArmed ? "Delete this pass — click again to confirm" : "Delete this pass"),
                            state: deleteArmed ? "This cannot be undone" : "Removes the pass and its queued recordings",
                            focused: focused == "delete") {
                        Task { await deleteTapped() }
                    }
                    .focused($focused, equals: "delete")
                }
                Text("A click steps each setting to its next value and saves it on the server. Nothing already recorded is touched.")
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
            .frame(width: 980, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.7), radius: 40, y: 16)
        }
        .focusSection()
        .onExitCommand { onClose() }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = "record"
            }
        }
    }

    // MARK: The writes

    private func cycleRecordMode() async {
        await send(id: "record", PassEdit(recordMode: pass.recordMode == "all" ? "new" : "all"))
    }

    private func cyclePad(before: Bool) async {
        let current = before ? pass.padBefore : pass.padAfter
        let next = Self.nextChoice(after: current, in: Self.padChoices)
        await send(id: before ? "before" : "after",
                   before ? PassEdit(padBefore: next) : PassEdit(padAfter: next))
    }

    private func cycleKeep() async {
        let index = Self.keepChoices.firstIndex {
            $0.mode == pass.keepMode
                && ($0.mode != "last" || $0.last == pass.keepLast)
                && ($0.mode != "unwatched" || $0.unwatched == pass.keepUnwatched)
        } ?? -1
        let next = Self.keepChoices[(index + 1) % Self.keepChoices.count]
        await send(id: "keep", PassEdit(keepMode: next.mode, keepUnwatched: next.unwatched, keepLast: next.last))
    }

    static func nextChoice(after current: Int, in choices: [Int]) -> Int {
        guard let index = choices.firstIndex(of: current) else { return choices.first ?? 0 }
        return choices[(index + 1) % choices.count]
    }

    private func send(id: String, _ edit: PassEdit) async {
        guard busy == nil else { return }
        busy = id
        error = nil
        do {
            let updated = try await api.updatePass(id: pass.id, body: edit)
            onChanged(updated)
        } catch {
            self.error = WriteError.text(error)
            print("[pass] update failed: \(error)")
        }
        busy = nil
    }

    private func deleteTapped() async {
        guard busy == nil else { return }
        guard deleteArmed else {
            deleteArmed = true
            return
        }
        busy = "delete"
        error = nil
        do {
            try await api.deletePass(id: pass.id)
            onDeleted()
        } catch {
            self.error = WriteError.text(error)
            deleteArmed = false
            print("[pass] delete failed: \(error)")
        }
        busy = nil
    }
}
