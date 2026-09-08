//
//  ManageDVRScreen.swift
//  Marlin DVR TV
//
//  Pass 10 step 2: the management area the owner's old DVR had, reached from the "Manage DVR"
//  row at the top of Recordings. Not in the approved design — built to the app's own look.
//
//  The hub shows what the server holds and how much room is left, and leads to three lists:
//
//    Storage              GET /api/system disk fields (system.go:16-46; Pass 2 §2.1)
//    Scheduled Recordings GET /api/schedule            (passes.go:838-879)
//    Your Passes          GET /api/passes              (passes.go:575-596)
//    Trash                GET /api/library/trash (server 1.6.0)
//
//  Every count on this screen is the server's own (step 3).
//
//  Pass 33: the trash used to be assembled show by show from GET /api/library/shows/{id}?trash=1,
//  because the library had no trash listing. That never showed a recording whose show had left
//  the library — the app had no way to learn such a show's id (Pass 32 §B.3) — and against 1.6.0
//  it shows nothing at all, since the per-show read no longer returns trashed episodes (measured,
//  Pass 33 §1). One read replaces the whole walk.
//

import SwiftUI

enum ManageSection: String, Identifiable {
    case schedule, passes, trash
    var id: String { rawValue }
}

@MainActor
@Observable
final class ManageModel {
    private let api: APIClient

    private(set) var system: SystemInfo?
    private(set) var schedule: ScheduleResponse?
    private(set) var passes: [PassView] = []
    /// Every trashed recording the server holds, in its own order — newest trashed first.
    private(set) var trash: [TrashItem] = []
    private(set) var loaded = false
    private(set) var error: String?
    /// Why the trash list is empty when it is: nil means the server said so, a string means the
    /// read failed and the screen must not claim the trash is empty.
    private(set) var trashError: String?

    init(api: APIClient) {
        self.api = api
    }

    var scheduledCount: Int { schedule?.count ?? 0 }
    var passCount: Int { passes.count }
    var trashCount: Int { trash.count }

    func load() async {
        async let systemCall = api.system()
        async let scheduleCall = api.schedule()
        async let passesCall = api.passes()

        do { system = try await systemCall } catch { print("[manage] system: \(error)") }
        do { schedule = try await scheduleCall } catch {
            self.error = "\(error)"
            print("[manage] schedule: \(error)")
        }
        do { passes = try await passesCall } catch { print("[manage] passes: \(error)") }
        await refreshTrash()
        loaded = true
    }

    func refreshSchedule() async {
        do { schedule = try await api.schedule() } catch { print("[manage] schedule: \(error)") }
    }

    func refreshPasses() async {
        do { passes = try await api.passes() } catch { print("[manage] passes: \(error)") }
    }

    /// GET /api/library/trash — one read, kept in the server's order (newest trashed first).
    func refreshTrash() async {
        do {
            let response = try await api.trash()
            trash = response.recordings
            trashError = nil
            print("[manage] trash: \(trash.count) recording(s), server count \(response.count), \(SizeFormat.serverStyle(trashBytes))")
        } catch {
            trashError = WriteError.text(error)
            print("[manage] trash: \(error)")
        }
    }

    /// What the trash is holding on disk, for the screen's subtitle.
    var trashBytes: Int { trash.reduce(0) { $0 + $1.size } }

    /// The pass a scheduled job belongs to, for "Manage pass". Nil for a Record Now job.
    func pass(for job: Job) -> PassView? {
        guard job.passId != "manual" else { return nil }
        return passes.first { $0.id == job.passId }
    }
}

struct ManageDVRScreen: View {
    let api: APIClient
    let onLeave: () -> Void
    @State private var model: ManageModel
    @State private var section: ManageSection?
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void) {
        self.api = api
        self.onLeave = onLeave
        _model = State(initialValue: ManageModel(api: api))
    }

    var body: some View {
        Group {
            switch section {
            case .schedule:
                ScheduleManageView(api: api, model: model, onLeave: closeSection)
            case .passes:
                PassesManageView(api: api, model: model, onLeave: closeSection)
            case .trash:
                TrashManageView(api: api, model: model, onLeave: closeSection)
            case nil:
                hub
            }
        }
        .task {
            await model.load()
            focusSoon { focused = "schedule" }
        }
        .onExitCommand {
            if section != nil {
                closeSection()
            } else {
                onLeave()
            }
        }
    }

    private func closeSection() {
        let previous = section?.rawValue
        section = nil
        focusSoon { focused = previous ?? "schedule" }
    }

    private var hub: some View {
        VStack(alignment: .leading, spacing: 30) {
            ScreenHeader("Manage DVR", subtitle: model.system?.diskVolume) {
                Text("Everything here is the server's own state, shared with the web UI")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            StorageCard(system: model.system)
            if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            }
            VStack(spacing: 12) {
                MenuRow(title: "Scheduled Recordings",
                        state: "\(model.scheduledCount) scheduled",
                        focused: focused == "schedule") { section = .schedule }
                    .focused($focused, equals: "schedule")
                MenuRow(title: "Your Passes",
                        state: count(model.passCount, "pass", plural: "passes"),
                        focused: focused == "passes") { section = .passes }
                    .focused($focused, equals: "passes")
                MenuRow(title: "Trash",
                        state: trashState,
                        focused: focused == "trash") { section = .trash }
                    .focused($focused, equals: "trash")
            }
            .frame(maxWidth: 1400, alignment: .leading)
            if let error = model.error {
                ErrorLine(text: error)
            }
            Spacer(minLength: 0)
        }
        .defaultFocus($focused, "schedule")
    }

    /// "4 in trash · 3.80 GB". The size is the listing's own byte counts added up (Pass 33
    /// step 2) — the hub had no figure for it while the list was assembled show by show.
    private var trashState: String {
        if model.trashError != nil && model.trash.isEmpty { return "could not read" }
        guard model.trashCount > 0 else { return "empty" }
        return "\(model.trashCount) in trash · \(SizeFormat.serverStyle(model.trashBytes))"
    }

    private func count(_ n: Int, _ word: String, plural: String? = nil) -> String {
        n == 1 ? "1 \(word)" : "\(n) \(plural ?? word + "s")"
    }
}

/// Step 2a: how much room is left, from the server's own formatted disk fields.
struct StorageCard: View {
    let system: SystemInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("Storage")
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                Spacer(minLength: 0)
                if let system {
                    Text("\(system.diskUsed) used · \(system.diskFree) free of \(system.diskTotal)")
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral400)
                } else {
                    Text("Reading the server…")
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral600)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Nocturne.neutral800)
                    Capsule()
                        .fill(Nocturne.accent)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 14)
            Text(system?.diskLabel ?? " ")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral500)
                .lineLimit(1)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 26)
        .frame(maxWidth: 1400, alignment: .leading)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
    }

    /// A sliver stays visible at 0–1% so the bar never looks broken.
    private var fraction: Double {
        guard let system else { return 0 }
        return max(0.01, min(1, Double(system.diskUsedPercent) / 100))
    }
}
