//
//  ScheduleManageView.swift
//  Marlin DVR TV
//
//  Pass 10 step 2b: everything the server has queued, grouped the way `GET /api/schedule`
//  groups it (Today / Tomorrow / a weekday / a date — passes.go:838-879). Clicking a row
//  opens the airing, with two actions:
//
//    Cancel recording   PUT /api/schedule/jobs/{id} {"skipped": true}   passes.go:927-967
//    Manage pass        the Pass 9 Edit series pass screen for that job's pass
//
//  The two kinds of job behave differently on the server and the confirm copy says so: a
//  one-off Record Now is **removed** and its airing becomes free to record again, while a
//  pass's airing is only skipped and the pass carries on. "Manage pass" is hidden for a
//  Record Now job — `passId` is the literal "manual" and there is nothing to open.
//
//  There is no per-airing padding here: the server keeps padding on the pass and on the
//  Record Now booking at the moment it is made, and exposes no per-airing control
//  (passes.go:53-77 has no padding field on `Job`). Nothing is faked.
//

import SwiftUI

struct ScheduleManageView: View {
    let api: APIClient
    let model: ManageModel
    let onLeave: () -> Void

    @FocusState private var focused: String?
    @State private var selected: Job?
    @State private var editingPass: PassView?
    @State private var message: String?

    private var groups: [ScheduleGroup] { model.schedule?.groups ?? [] }

    var body: some View {
        ZStack {
            content
            if let job = selected, editingPass == nil {
                ScheduledJobDetail(
                    job: job,
                    pass: model.pass(for: job),
                    api: api,
                    onCancelled: { removed in
                        selected = nil
                        message = removed
                            ? "Booking removed. That airing is free to record again."
                            : "This airing is cancelled. The series pass carries on."
                        Task {
                            await model.refreshSchedule()
                            focusSoon { focused = firstRowID }
                        }
                    },
                    onManagePass: { pass in editingPass = pass },
                    onClose: {
                        let id = selected?.id
                        selected = nil
                        focusSoon { focused = id }
                    }
                )
            }
            if let pass = editingPass {
                EditSeriesPassScreen(
                    pass: pass,
                    api: api,
                    onChanged: { updated in
                        editingPass = updated
                        Task { await model.refreshPasses(); await model.refreshSchedule() }
                    },
                    onDeleted: {
                        editingPass = nil
                        selected = nil
                        message = "Series pass deleted."
                        Task {
                            await model.refreshPasses()
                            await model.refreshSchedule()
                            focusSoon { focused = firstRowID }
                        }
                    },
                    onClose: { editingPass = nil }
                )
            }
        }
        .onAppear { focusSoon { focused = firstRowID } }
        .onExitCommand {
            if editingPass != nil {
                editingPass = nil
            } else if selected != nil {
                let id = selected?.id
                selected = nil
                focusSoon { focused = id }
            } else {
                onLeave()
            }
        }
    }

    private var firstRowID: String? { groups.first(where: { !$0.items.isEmpty })?.items.first?.id }

    private var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            ScreenHeader("Scheduled Recordings", subtitle: subtitle) {
                Text("Menu goes back to Manage DVR")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if let message {
                Text(message)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.accent200)
                    .lineLimit(2)
            }
            if groups.allSatisfy(\.items.isEmpty) {
                Text("Nothing is scheduled. Record an airing from the Guide, or add a series pass.")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.vertical, 20)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        if !group.items.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(group.label)
                                    .font(.nocturne(34, .medium))
                                    .foregroundStyle(Nocturne.text)
                                ForEach(group.items) { job in
                                    Button { selected = job } label: {
                                        ScheduledJobRow(job: job, focused: focused == job.id)
                                    }
                                    .buttonStyle(BareButtonStyle())
                                    .focused($focused, equals: job.id)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 1400, alignment: .leading)
            }
            .disabled(selected != nil || editingPass != nil)
        }
    }

    private var subtitle: String? {
        guard let schedule = model.schedule else { return nil }
        return "\(schedule.count) scheduled · \(schedule.passes) pass\(schedule.passes == 1 ? "" : "es")"
    }
}

/// One queued airing.
struct ScheduledJobRow: View {
    let job: Job
    let focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ServerImage(path: job.art) {
                InitialsTile(initials: job.initials, logoBg: job.logoBg, size: 68, fontSize: Nocturne.TextSize.floor)
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 12) {
                    Text(job.program.title)
                        .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(1)
                    JobStatusChip(status: job.status)
                    if job.passId == "manual" {
                        Text("Record Now")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                    }
                }
                if !job.episodeLine.isEmpty {
                    Text(job.episodeLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                }
                Text("\(job.number) \(job.channelName) · \(job.timeRange)")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let reason = job.reason, !reason.isEmpty {
                Text(reason)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(2)
                    .frame(maxWidth: 340, alignment: .trailing)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}

/// The server's own job status, in the guide's colours.
struct JobStatusChip: View {
    let status: String

    private var colour: Color {
        switch status {
        case "Recording": return GuideMark.green
        case "Conflict", "FAILED": return Color(hex: 0xC2686B)
        case "Skipped", "STOPPED": return Nocturne.neutral600
        default: return Nocturne.accent600
        }
    }

    var body: some View {
        Text(status.uppercased())
            .font(.nocturne(Nocturne.TextSize.floor))
            .tracking(0.1 * Nocturne.TextSize.floor)
            .foregroundStyle(colour)
            .padding(.vertical, 2)
            .padding(.horizontal, 10)
            .overlay {
                Capsule().strokeBorder(colour.opacity(0.6), lineWidth: 1)
            }
    }
}

/// The airing, with the two things that can be done to it.
struct ScheduledJobDetail: View {
    let job: Job
    let pass: PassView?
    let api: APIClient
    let onCancelled: (Bool) -> Void
    let onManagePass: (PassView) -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?
    @State private var armed = false
    @State private var busy = false
    @State private var error: String?

    private var isManual: Bool { job.passId == "manual" }

    private var cancelDetail: String {
        if armed {
            return isManual
                ? "The booking is removed; the airing can be recorded again"
                : "This airing only; the series pass carries on"
        }
        return isManual ? "Removes this one-off booking" : "Skips this airing, keeps the pass"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.82), Nocturne.bg.opacity(0.96)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .top, spacing: 40) {
                ServerImage(path: job.art) {
                    InitialsTile(initials: job.initials, logoBg: job.logoBg, size: 260, fontSize: 64)
                }
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Text("SCHEDULED")
                                .font(.nocturne(Nocturne.TextSize.floor))
                                .tracking(0.12 * Nocturne.TextSize.floor)
                                .foregroundStyle(Nocturne.accent300)
                            JobStatusChip(status: job.status)
                        }
                        Text(job.program.title)
                            .font(.nocturne(48, .medium))
                            .foregroundStyle(Nocturne.text)
                            .lineLimit(2)
                        if !job.episodeLine.isEmpty {
                            Text(job.episodeLine)
                                .font(.nocturne(Nocturne.TextSize.secondary))
                                .foregroundStyle(Nocturne.neutral300)
                                .lineLimit(1)
                        }
                        Text("\(job.dateLabel) · \(job.timeRange) · \(job.number) \(job.channelName)")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                            .lineLimit(1)
                        Text(isManual ? "One-off Record Now" : "Series pass · \(job.passTitle)")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(isManual ? Nocturne.neutral500 : GuideMark.gold)
                            .lineLimit(1)
                    }
                    VStack(spacing: 10) {
                        MenuRow(title: busy ? "Cancelling…" : (armed ? "Cancel recording — click again to confirm" : "Cancel recording"),
                                state: cancelDetail,
                                focused: focused == "cancel") {
                            Task { await cancel() }
                        }
                        .focused($focused, equals: "cancel")

                        if let pass {
                            MenuRow(title: "Manage pass",
                                    state: pass.countLabel,
                                    focused: focused == "pass") { onManagePass(pass) }
                                .focused($focused, equals: "pass")
                        }
                    }
                    if let error {
                        Text(error)
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral200)
                            .lineLimit(2)
                    }
                    Text("Padding is a property of the pass, not of one airing — the server keeps no per-airing setting.")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral600)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(44)
            .frame(width: 1300, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.7), radius: 40, y: 16)
        }
        .focusSection()
        .onExitCommand { onClose() }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = "cancel"
            }
        }
    }

    private func cancel() async {
        guard !busy else { return }
        guard armed else {
            armed = true
            return
        }
        busy = true
        error = nil
        do {
            let result = try await api.cancelJob(id: job.id)
            onCancelled(result.removed)
        } catch {
            self.error = WriteError.text(error)
            armed = false
            print("[schedule] cancel failed: \(error)")
        }
        busy = false
    }
}
