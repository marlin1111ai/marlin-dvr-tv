//
//  HomeView.swift
//  Marlin DVR TV
//
//  Home, frame 2a: a launcher with no rail (dc:111) — greeting, the fixed name "Marlin"
//  (owner decision), date and time, and nine tiles with a live sub-line each
//  (dc:120-160; data dc:1353-1368). The weather glance card (dc:133-143) is omitted until
//  Weather is built; its 520 pt slot is kept so the clock sits where the design puts it.
//

import SwiftUI

/// Loads the tile sub-lines from the server (Pass 4 §3.2), each endpoint once, no retries.
@Observable
final class HomeModel {
    private let api: APIClient
    private(set) var subtitles: [Destination: String] = [:]
    private(set) var loaded = false

    init(api: APIClient) {
        self.api = api
    }

    func subtitle(for destination: Destination) -> String {
        if let s = destination.staticTileSubtitle { return s }
        return subtitles[destination] ?? "…"
    }

    func load() async {
        async let channels = api.channels()
        async let onNow = api.onNow()
        async let schedule = api.schedule()
        async let library = api.library()
        async let cameras = api.cameras()

        do {
            let list = try await channels
            subtitles[.guide] = "\(list.count) channels live"
            // Pass 10: the same read serves the Favorites tile — no extra request.
            let favourites = list.filter(\.favorite).count
            subtitles[.favorites] = favourites == 0
                ? "None yet"
                : "\(favourites) favourite channel\(favourites == 1 ? "" : "s")"
        } catch {
            subtitles[.guide] = "unavailable"
            subtitles[.favorites] = "unavailable"
            print("[home] channels: \(error)")
        }
        do {
            let items = try await onNow
            subtitles[.onNow] = "\(items.count) programs live"
        } catch {
            subtitles[.onNow] = "unavailable"
            print("[home] guide/now: \(error)")
        }
        var recordingNow = 0
        do {
            let response = try await schedule
            subtitles[.onLater] = "\(response.count) upcoming"
            recordingNow = response.jobs.filter { $0.status == "Recording" }.count
        } catch {
            subtitles[.onLater] = "unavailable"
            print("[home] schedule: \(error)")
        }
        do {
            let response = try await library
            subtitles[.recordings] = "\(response.recordings) recordings · \(recordingNow) recording now"
        } catch {
            subtitles[.recordings] = "unavailable"
            print("[home] library: \(error)")
        }
        do {
            let response = try await cameras
            subtitles[.cameras] = "\(response.online) of \(response.count) online"
        } catch {
            subtitles[.cameras] = "unavailable"
            print("[home] cameras: \(error)")
        }
        loaded = true
    }
}

struct HomeView: View {
    let model: HomeModel
    let onSelect: (Destination) -> Void
    @FocusState private var focusedTile: Destination?

    var body: some View {
        ZStack {
            Nocturne.bg
            // radial-gradient(1400px 700px at 50% -18%, accent-900, transparent 62%) — dc:121
            RadialGradient(
                colors: [Nocturne.accent900, .clear],
                center: UnitPoint(x: 0.5, y: -0.18),
                startRadius: 0,
                endRadius: 700
            )
            .scaleEffect(x: 2, y: 1)
            VStack(alignment: .leading, spacing: 44) {
                header
                tiles
            }
            .padding(.vertical, Nocturne.Layout.marginVertical)
            .padding(.horizontal, Nocturne.Layout.marginHorizontal)
        }
        .defaultFocus($focusedTile, .guide)
        .task { await model.load() }
    }

    // MARK: Header (dc:124-144)

    private var header: some View {
        HStack(alignment: .top, spacing: 48) {
            HStack(alignment: .top, spacing: 20) {
                Image(systemName: "tv")
                    .font(.nocturne(38))
                    .foregroundStyle(Nocturne.neutral400)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 2) {
                    TimelineView(.everyMinute) { context in
                        Text(Self.greeting(at: context.date))
                            .font(.nocturne(Nocturne.TextSize.greeting, .light))
                            .tracking(-0.02 * Nocturne.TextSize.greeting)
                            .foregroundStyle(Nocturne.text)
                    }
                    Text("Marlin")
                        .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                        .foregroundStyle(Nocturne.neutral300)
                }
            }
            Spacer(minLength: 0)
            TimelineView(.everyMinute) { context in
                Text(Self.clockLine(at: context.date))
                    .font(.nocturne(Nocturne.TextSize.tileLabel))
                    .foregroundStyle(Nocturne.neutral200)
                    .padding(.top, 14)
            }
            Spacer(minLength: 0)
            // The weather glance's slot (520 pt), empty until Weather is built.
            Color.clear.frame(width: 520, height: 1)
        }
    }

    static func greeting(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// "Friday, September 5 · 9:42 PM" (dc:132)
    static func clockLine(at date: Date) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let time = date.formatted(.dateTime.hour().minute())
        return "\(day) · \(time)"
    }

    // MARK: Tiles (dc:146-158)

    private var tiles: some View {
        let rows = stride(from: 0, to: Destination.homeTiles.count, by: 3).map {
            Array(Destination.homeTiles[$0..<min($0 + 3, Destination.homeTiles.count)])
        }
        return VStack(spacing: 26) {
            ForEach(rows, id: \.first!.id) { row in
                HStack(spacing: 26) {
                    ForEach(row) { destination in
                        Button {
                            onSelect(destination)
                        } label: {
                            HomeTile(
                                destination: destination,
                                subtitle: model.subtitle(for: destination),
                                isFocused: focusedTile == destination
                            )
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focusedTile, equals: destination)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One Home tile (dc:148-156): a tinted gradient, an icon box, the label and the sub-line;
/// focused = 4 pt accent ring, a 6 pt lift and the ambient shadow (dc:1366-1367).
struct HomeTile: View {
    let destination: Destination
    let subtitle: String
    let isFocused: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: destination.tileSymbol)
                .font(.nocturne(34))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text(destination.label)
                    .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                    .tracking(-0.01 * Nocturne.TextSize.tileLabel)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            // linear-gradient(150deg, tint, color-mix(tint 55%, bg)) — dc:1365
            LinearGradient(
                colors: [destination.tileTint, destination.tileTint.mix(with: Nocturne.bg, by: 0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: shape
        )
        .overlay {
            shape.strokeBorder(
                isFocused ? Nocturne.accent : Color.white.opacity(0.08),
                lineWidth: isFocused ? Nocturne.Focus.ringWidth : 1
            )
        }
        .offset(y: isFocused ? -Nocturne.Focus.lift : 0)
        .shadow(
            color: isFocused ? Nocturne.Focus.shadowColor : .clear,
            radius: Nocturne.Focus.shadowRadius,
            y: Nocturne.Focus.shadowY
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
