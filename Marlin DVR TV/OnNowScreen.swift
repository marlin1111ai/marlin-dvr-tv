//
//  OnNowScreen.swift
//  Marlin DVR TV
//
//  On Now, the content of frame 1b (dc:74-100): the filter chips, a card per playable
//  channel from GET /api/guide/now (guide.go:667-691) with the logo or initials tile,
//  "number · name", the program title, the episode line, the server's "ends …" string and
//  a progress bar derived from start/end; refreshed every minute. A long press on a card
//  shows that channel's next six hours from GET /api/guide (12 slots) as a list; Menu closes it.
//

import SwiftUI

enum ChannelChip: Hashable {
    case favorites, all, hd, source(String)

    var label: String {
        switch self {
        case .favorites: return "Favorites"
        case .all: return "All"
        case .hd: return "HD"
        case .source(let name): return name
        }
    }

    /// The query the server understands (sources.go:362-386).
    var filterQuery: String? {
        switch self {
        case .favorites: return "Favorites"
        case .hd: return "HD"
        default: return nil
        }
    }

    var sourceQuery: String? {
        if case .source(let name) = self { return name }
        return nil
    }
}

struct NextHours: Identifiable {
    let channel: MergedChannel
    let programs: [Program]
    let from: Int
    var id: String { channel.id }
}

@Observable
final class OnNowModel {
    private let api: APIClient
    private(set) var items: [GuideNowItem] = []
    private(set) var sources: [String] = []
    private(set) var totalPlayable = 0
    private(set) var refreshedAt: Date?
    private(set) var loaded = false
    private(set) var error: String?
    var chip: ChannelChip = .all
    var nextHours: NextHours?

    init(api: APIClient) {
        self.api = api
    }

    var chips: [ChannelChip] {
        [.favorites, .all, .hd] + sources.map { .source($0) }
    }

    func chipLabel(_ chip: ChannelChip) -> String {
        chip == .all ? "All \(totalPlayable)" : chip.label
    }

    /// Source names in order of appearance (the `source` field of GET /api/channels).
    func loadSources() async {
        do {
            let channels = try await api.channels()
            totalPlayable = channels.count
            var seen: [String] = []
            for c in channels where !seen.contains(c.source) { seen.append(c.source) }
            sources = seen
        } catch {
            print("[onnow] channels: \(error)")
        }
    }

    func load() async {
        do {
            items = try await api.onNow(source: chip.sourceQuery, filter: chip.filterQuery)
            refreshedAt = Date()
            error = nil
        } catch {
            self.error = "\(error)"
            print("[onnow] guide/now: \(error)")
        }
        loaded = true
    }

    /// The next six hours on one channel: GET /api/guide?slots=12&source=<its source>, then that row.
    func showNextHours(for item: GuideNowItem) async {
        do {
            let guide = try await api.guide(start: nil, slots: 12, source: item.channel.sourceId)
            guard let row = guide.channels.first(where: { $0.channel.id == item.channel.id }) else { return }
            var seen = Set<Int>()
            var programs: [Program] = []
            for block in row.blocks {
                if let p = block.program, !seen.contains(p.start) {
                    seen.insert(p.start)
                    programs.append(p)
                }
            }
            nextHours = NextHours(channel: item.channel, programs: programs, from: guide.start)
        } catch {
            self.error = "\(error)"
            print("[onnow] guide: \(error)")
        }
    }
}

struct OnNowScreen: View {
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @State private var model: OnNowModel
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: OnNowModel(api: api))
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 3)

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 34) {
                ScreenHeader("On Now", subtitle: subtitle)
                chips
                if let error = model.error, model.items.isEmpty {
                    ErrorLine(text: error)
                } else if !model.loaded {
                    LoadingLine().focusable().focused($focused, equals: "loading")
                }
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Self.columns, spacing: 30) {
                        ForEach(model.items) { item in
                            Button {
                                onPlay(.live(channel: item.channel, program: item.program))   // sweep 3 entry point
                            } label: {
                                OnNowCard(item: item, focused: focused == item.id)
                            }
                            .buttonStyle(BareButtonStyle())
                            .focused($focused, equals: item.id)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                print("[onnow] long press on \(item.channel.number) \(item.channel.name)")
                                Task { await model.showNextHours(for: item) }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .disabled(model.nextHours != nil)
            }
            if let next = model.nextHours {
                NextHoursOverlay(next: next)
            }
        }
        .defaultFocus($focused, model.items.first?.id ?? "loading")
        .task {
            await model.loadSources()
            var first = true
            while !Task.isCancelled {
                await model.load()
                if first {
                    first = false
                    let id = model.items.first?.id
                    focusSoon { focused = id ?? "chip:All" }
                }
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onExitCommand {
            print("[onnow] menu: overlay=\(model.nextHours != nil)")
            if model.nextHours != nil {
                model.nextHours = nil
            } else {
                onLeave()
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let at = model.refreshedAt { parts.append("Refreshed \(TimeFormat.clock(at))") }
        parts.append("\(model.items.count) channels")
        return parts.joined(separator: " · ")
    }

    private var chips: some View {
        HStack(spacing: 14) {
            ForEach(model.chips, id: \.self) { chip in
                Button {
                    model.chip = chip
                    Task { await model.load() }
                } label: {
                    PillLabel(text: model.chipLabel(chip), active: model.chip == chip, focused: focused == "chip:\(chip.label)")
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: "chip:\(chip.label)")
            }
        }
        .focusSection()
    }
}

/// One On Now card (dc:87-97) plus the episode line and the new/live flags the task adds.
struct OnNowCard: View {
    let item: GuideNowItem
    let focused: Bool

    private var progress: Double {
        guard let p = item.program, p.end > p.start else { return 0 }
        let now = Date().timeIntervalSince1970
        return (now - Double(p.start)) / Double(p.end - p.start)
    }

    private var episodeLine: String? {
        guard let p = item.program else { return nil }
        var parts: [String] = []
        if let n = p.episodeNum, !n.isEmpty { parts.append(n) }
        if let t = p.episodeTitle, !t.isEmpty { parts.append(t) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var flags: [String] {
        guard let p = item.program else { return [] }
        var out: [String] = []
        if p.new == true { out.append("New") }
        if p.live == true { out.append("Live") }
        if p.premiere == true { out.append("Premiere") }
        if p.finale == true { out.append("Finale") }
        return out
    }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ChannelLogo(channel: item.channel, size: 82)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("\(item.channel.number) · \(item.channel.name)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                    ForEach(flags, id: \.self) { TagChip(text: $0) }
                }
                Text(item.title)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(2)
                if let episodeLine {
                    Text(episodeLine)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineLimit(1)
                }
                Text(item.endsIn)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                ProgressBar(fraction: progress)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 26)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}

/// The next six hours of one channel, as a simple list over the screen.
struct NextHoursOverlay: View {
    let next: NextHours
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Nocturne.bg.opacity(0.85)
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text("\(next.channel.number) · \(next.channel.name)")
                        .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                        .foregroundStyle(Nocturne.text)
                    Text("Next 6 hours from \(TimeFormat.clock(unix: next.from))")
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                }
                if next.programs.isEmpty {
                    Text("No listings.")
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                }
                ForEach(next.programs, id: \.start) { p in
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        Text(TimeFormat.timeRange(p.start, p.end))
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                            .frame(width: 260, alignment: .leading)
                        Text(p.title)
                            .font(.nocturne(Nocturne.TextSize.secondary))
                            .foregroundStyle(Nocturne.text)
                            .lineLimit(1)
                        if let t = p.episodeTitle, !t.isEmpty {
                            Text(t)
                                .font(.nocturne(Nocturne.TextSize.floor))
                                .foregroundStyle(Nocturne.neutral400)
                                .lineLimit(1)
                        }
                    }
                }
                Text("Menu closes")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
                    .padding(.top, 10)
            }
            .padding(48)
            .frame(width: 1180, alignment: .leading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : Nocturne.neutral500, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
            .focusable()
            .focused($focused)
        }
        .focusSection()
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = true
            }
        }
    }
}
