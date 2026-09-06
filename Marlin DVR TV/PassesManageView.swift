//
//  PassesManageView.swift
//  Marlin DVR TV
//
//  Pass 10 step 2c: every series pass the server holds (`GET /api/passes`, passes.go:575-596),
//  with the number of airings each one has queued. Clicking one opens the Pass 9 Edit series
//  pass screen — record mode, start early, stop late, keep, Pause/Resume (added in this pass)
//  and Delete — so there is one editor, reached from the airing sheet and from here.
//

import SwiftUI

struct PassesManageView: View {
    let api: APIClient
    let model: ManageModel
    let onLeave: () -> Void

    @FocusState private var focused: String?
    @State private var editing: PassView?
    @State private var message: String?

    var body: some View {
        ZStack {
            content
            if let pass = editing {
                EditSeriesPassScreen(
                    pass: pass,
                    api: api,
                    onChanged: { updated in
                        editing = updated
                        Task { await model.refreshPasses(); await model.refreshSchedule() }
                    },
                    onDeleted: {
                        editing = nil
                        message = "Series pass deleted."
                        Task {
                            await model.refreshPasses()
                            await model.refreshSchedule()
                            focusSoon { focused = model.passes.first?.id }
                        }
                    },
                    onClose: {
                        let id = editing?.id
                        editing = nil
                        focusSoon { focused = id }
                    }
                )
            }
        }
        .onAppear { focusSoon { focused = model.passes.first?.id } }
        .onExitCommand {
            if editing != nil {
                let id = editing?.id
                editing = nil
                focusSoon { focused = id }
            } else {
                onLeave()
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            ScreenHeader("Your Passes", subtitle: subtitle) {
                Text("Menu goes back to Manage DVR")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.accent200)
                    .lineLimit(1)
            }
            if model.passes.isEmpty {
                Text("No series passes yet. Open an airing in the Guide and choose Record the series.")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.vertical, 20)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(model.passes) { pass in
                        Button { editing = pass } label: {
                            PassRow(pass: pass, focused: focused == pass.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: pass.id)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 1400, alignment: .leading)
            }
            .disabled(editing != nil)
        }
    }

    private var subtitle: String? {
        let n = model.passes.count
        let jobs = model.passes.reduce(0) { $0 + $1.jobCount }
        return "\(n) pass\(n == 1 ? "" : "es") · \(jobs) airing\(jobs == 1 ? "" : "s") queued"
    }
}

/// One pass: its art, its title, and what it has queued.
struct PassRow: View {
    let pass: PassView
    let focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ServerImage(path: AiringSelection.artPath(for: pass.title)) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 12) {
                    Text(pass.title)
                        .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    if pass.paused {
                        Text("PAUSED")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .tracking(0.1 * Nocturne.TextSize.floor)
                            .foregroundStyle(Nocturne.neutral500)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .overlay { Capsule().strokeBorder(Nocturne.neutral700, lineWidth: 1) }
                    }
                }
                Text("\(pass.countLabel) · \(pass.recordMode == "all" ? "all episodes" : "new episodes") · keep \(pass.keepLabel.lowercased())")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(pass.channel.isEmpty ? "any channel" : pass.channel)
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral500)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}
