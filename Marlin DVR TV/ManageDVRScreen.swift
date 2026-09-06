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
//    Trash                per show, GET /api/library/shows/{id}?trash=1 (library.go:586-640)
//
//  The trash has no list endpoint of its own: the only way to it is show by show, so the hub
//  reads the library once and then asks each show for its trashed episodes, a few at a time.
//  Every count on this screen is the server's own (step 3).
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
    /// Every trashed episode in the library, newest show order; `Episode.show` names its show.
    private(set) var trash: [Episode] = []
    private(set) var loaded = false
    private(set) var error: String?

    /// How many show-trash reads run at once, so a big library does not flood the server.
    private static let trashFetchWidth = 6

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

    /// The library has no trash list, so: every show once, then its trashed episodes.
    func refreshTrash() async {
        do {
            let library = try await api.library(limit: 500)
            var ids: [String] = []
            var seen = Set<String>()
            for section in library.sections {
                for item in section.items where !seen.contains(item.id) {
                    seen.insert(item.id)
                    ids.append(item.id)
                }
            }
            var found: [Episode] = []
            var index = 0
            while index < ids.count {
                let slice = ids[index ..< min(index + Self.trashFetchWidth, ids.count)]
                index += Self.trashFetchWidth
                await withTaskGroup(of: [Episode].self) { group in
                    for id in slice {
                        group.addTask { [api] in
                            (try? await api.show(id: id, trash: true))?.episodes ?? []
                        }
                    }
                    for await episodes in group { found.append(contentsOf: episodes) }
                }
            }
            trash = found.sorted { $0.show == $1.show ? $0.id < $1.id : $0.show < $1.show }
            print("[manage] trash: \(trash.count) episode(s) across \(ids.count) show(s)")
        } catch {
            print("[manage] library: \(error)")
        }
    }

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
                        state: model.trashCount == 0 ? "empty" : "\(model.trashCount) in trash",
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
