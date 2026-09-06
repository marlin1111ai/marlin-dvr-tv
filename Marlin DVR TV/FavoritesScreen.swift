//
//  FavoritesScreen.swift
//  Marlin DVR TV
//
//  Pass 10 step 1: the rail's Favorites entry, live. The favourites are the server's own
//  list — the `favorite` flag on each `MergedChannel` (sources.go:103-122), the same flag the
//  Guide's click-and-hold sets (Pass 9 step 7) and the web UI shows.
//
//  Two reads, both already in the app: `GET /api/channels` for the channels and their flag,
//  and `GET /api/guide/now` for what is on each of them, joined on the channel id. The guide
//  read is best-effort: a favourite with no listing still appears, just without a programme
//  line. Clicking a channel plays it live, the same path the Guide uses when a cell that is
//  airing now is clicked (DECISIONS.md 2026-09-06).
//
//  This screen is not in the approved design (Favorites was drawn but never specified), so it
//  is built to the app's own look: the On Now card, in one column.
//

import SwiftUI

@Observable
final class FavoritesModel {
    private let api: APIClient
    private(set) var channels: [MergedChannel] = []
    /// What is on now, by channel id; empty when the guide read failed or has no listing.
    private(set) var onNow: [String: GuideNowItem] = [:]
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            async let channelsCall = api.channels()
            async let nowCall = api.onNow()
            let all = try await channelsCall
            channels = all.filter(\.favorite)
            do {
                onNow = Dictionary(uniqueKeysWithValues: try await nowCall.map { ($0.channel.id, $0) })
            } catch {
                onNow = [:]
                print("[favorites] guide/now: \(error)")
            }
            error = nil
        } catch {
            self.error = "\(error)"
            print("[favorites] channels: \(error)")
        }
        loaded = true
    }
}

struct FavoritesScreen: View {
    let onLeave: () -> Void
    let onPlay: (PlayRequest) -> Void
    @State private var model: FavoritesModel
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void, onPlay: @escaping (PlayRequest) -> Void) {
        self.onLeave = onLeave
        self.onPlay = onPlay
        _model = State(initialValue: FavoritesModel(api: api))
    }

    private var subtitle: String? {
        guard model.loaded else { return nil }
        let n = model.channels.count
        return "\(n) favourite channel\(n == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            ScreenHeader("Favorites", subtitle: subtitle) {
                Text("The server's own favourites — shared with the web UI and the other Apple TV")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if let error = model.error, model.channels.isEmpty {
                ErrorLine(text: error)
            } else if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            } else if model.channels.isEmpty {
                emptyState
            } else {
                list
            }
            Spacer(minLength: 0)
        }
        .defaultFocus($focused, model.channels.first.map(\.id) ?? "loading")
        .task {
            await model.load()
            let id = model.channels.first?.id
            focusSoon { focused = id ?? "loading" }
        }
        .onExitCommand { onLeave() }
    }

    /// Nothing favourited yet: say exactly where the flag is set.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No favourite channels yet.")
                .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                .foregroundStyle(Nocturne.text)
            Text("In the Guide, click and hold a channel in the left-hand column and choose Favorite.")
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(Nocturne.neutral500)
        }
        .padding(.vertical, 34)
    }

    private var list: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                ForEach(model.channels) { channel in
                    Button {
                        onPlay(.live(channel: channel, program: model.onNow[channel.id]?.program))
                    } label: {
                        FavoriteRow(channel: channel, now: model.onNow[channel.id], focused: focused == channel.id)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($focused, equals: channel.id)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: 1400, alignment: .leading)
        }
    }
}

/// One favourite: the channel's logo, its number and name, and what is on now when the guide
/// has a listing for it.
struct FavoriteRow: View {
    let channel: MergedChannel
    let now: GuideNowItem?
    let focused: Bool

    private var progress: Double? {
        guard let p = now?.program, p.end > p.start else { return nil }
        return (Date().timeIntervalSince1970 - Double(p.start)) / Double(p.end - p.start)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ChannelLogo(channel: channel, size: 82)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("\(channel.number) · \(channel.name)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(1)
                    Text("★")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(GuideMark.gold)
                    if channel.hd {
                        Text("HD")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral500)
                    }
                }
                if let now {
                    Text(now.title)
                        .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(2)
                    Text(now.endsIn)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral500)
                    if let progress {
                        ProgressBar(fraction: progress)
                            .padding(.top, 4)
                    }
                } else {
                    Text("No listing right now")
                        .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                        .foregroundStyle(Nocturne.neutral500)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 26)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}
