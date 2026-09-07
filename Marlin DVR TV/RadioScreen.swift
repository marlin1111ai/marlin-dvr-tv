//
//  RadioScreen.swift
//  Marlin DVR TV
//
//  Pass 19 step 2: Radio, live at last — the rail entry and the Home tile were drawn and
//  inert from Pass 5 until now.
//
//  Built to the app's look, not to frame 5g (owner, 2026-09-06) — the same route the radar,
//  Manage DVR and Favorites took. The design draws eleven values per station and the server
//  supplies three (Pass 18 §3.6), so the design's frequency square, genre line, now-playing
//  line, track line and favourite star are dropped rather than filled with invention, and the
//  one thing the server *is* generous with — the icon it has already fetched and cached — takes
//  the square the design gave to a frequency string. A tile is the icon and the name. The
//  now-playing bar is the icon, the name and a Stop.
//
//  Order is the server's (:302). Nothing here sorts.
//

import SwiftUI

@Observable
final class RadioModel {
    private let api: APIClient
    private(set) var stations: [RadioStation] = []
    /// The server's own `count`, kept beside the array so the header can say if they disagree.
    private(set) var count = 0
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            let response = try await api.radio()
            // In the owner's order, exactly as returned.
            stations = response.stations
            count = response.count
            error = nil
            print("[radio] \(stations.count) station(s): \(stations.map(\.name).joined(separator: ", "))")
        } catch {
            self.error = "\(error)"
            print("[radio] /api/radio: \(error)")
        }
        loaded = true
    }
}

struct RadioScreen: View {
    let onLeave: () -> Void
    @State private var model: RadioModel
    @State private var player = RadioPlayer()
    @FocusState private var focused: String?

    /// The focus id of the now-playing bar's Stop.
    private static let stopID = "radio.stop"

    init(api: APIClient, onLeave: @escaping () -> Void) {
        self.onLeave = onLeave
        _model = State(initialValue: RadioModel(api: api))
    }

    private var subtitle: String? {
        guard model.loaded, model.error == nil else { return nil }
        let n = model.stations.count
        return "\(n) station\(n == 1 ? "" : "s") · audio only, no tuner needed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            ScreenHeader("Radio", subtitle: subtitle) {
                Text("Streams come straight from the station, not the DVR")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if player.phase.station != nil {
                nowPlayingBar
            }
            content
            Spacer(minLength: 0)
        }
        .defaultFocus($focused, model.stations.first?.id ?? "loading")
        .task {
            await model.load()
            let id = model.stations.first?.id
            focusSoon { focused = id ?? "loading" }
        }
        // Step 5: leaving the Radio screen stops the stream and tears the player down. This is
        // the same lifetime as every other player in the app — nothing keeps playing behind
        // another screen, and there is no audio session or background mode that would let it.
        .onDisappear { player.stop() }
        .onExitCommand {
            player.stop()
            onLeave()
        }
    }

    // MARK: The list, and the two ways it can have nothing in it (step 1)

    @ViewBuilder
    private var content: some View {
        if !model.loaded {
            LoadingLine().focusable().focused($focused, equals: "loading")
        } else if let error = model.error {
            // The handler has no failure path and always answers 200 (Pass 18 §1.6), so this
            // is the server being unreachable rather than the server saying no.
            VStack(alignment: .leading, spacing: 12) {
                Text("The station list could not be read from the DVR.")
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                ErrorLine(text: error)
            }
            .padding(.vertical, 24)
            .focusable()
            .focused($focused, equals: "loading")
        } else if model.stations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("No radio stations yet.")
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                Text("Stations are added on the DVR's own Radio page; this Apple TV only plays the list the server holds.")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
            }
            .padding(.vertical, 24)
            .focusable()
            .focused($focused, equals: "loading")
        } else {
            stations
        }
    }

    private static let columns = [GridItem(.flexible(), spacing: 30), GridItem(.flexible(), spacing: 30)]

    private var stations: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 18) {
                Text("Stations")
                    .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                    .foregroundStyle(Nocturne.text)
                LinearGradient(colors: [Nocturne.divider, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Self.columns, spacing: 18) {
                    ForEach(model.stations) { station in
                        Button {
                            player.play(station)
                        } label: {
                            StationTile(station: station, focused: focused == station.id)
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused($focused, equals: station.id)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .focusSection()
    }

    // MARK: The now-playing bar (step 4), which is also where a failure is said (step 7)

    private var nowPlayingBar: some View {
        let phase = player.phase
        let station = phase.station
        return HStack(alignment: .center, spacing: 34) {
            StationIcon(station: station, size: 132, glyph: 58)
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.eyebrow(phase))
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .tracking(0.14 * Nocturne.TextSize.floor)
                    .foregroundStyle(Self.isFailure(phase) ? Nocturne.neutral300 : Nocturne.accent300)
                Text(station?.name ?? "")
                    .font(.nocturne(44, .medium))
                    .tracking(-0.01 * 44)
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                // Nothing else is drawn while it is connecting or playing — the server has no
                // programme, track, bitrate or frequency to draw (Pass 18 §3.6). A failure is
                // the one thing that has more to say, and step 7 requires it said out loud.
                if case .failed(_, let message) = phase {
                    Text(message)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                let id = station?.id
                player.stop()
                // The bar goes away with the player, taking focus with it; put focus back on
                // the station it was playing rather than letting the screen lose it.
                focusSoon { focused = id ?? model.stations.first?.id }
            } label: {
                InertActionButton(title: "Stop", primary: false, focused: focused == Self.stopID)
            }
            .buttonStyle(BareButtonStyle())
            .focused($focused, equals: Self.stopID)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 34)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusSection()
    }

    private static func eyebrow(_ phase: RadioPlayer.Phase) -> String {
        switch phase {
        case .idle: return ""
        case .connecting: return "CONNECTING"
        case .playing: return "NOW PLAYING"
        case .failed: return "COULDN'T PLAY"
        }
    }

    private static func isFailure(_ phase: RadioPlayer.Phase) -> Bool {
        if case .failed = phase { return true }
        return false
    }
}

/// One station: the icon the DVR cached, and the name. Nothing else — the server has nothing
/// else (owner, 2026-09-06).
struct StationTile: View {
    let station: RadioStation
    let focused: Bool

    var body: some View {
        HStack(spacing: 26) {
            StationIcon(station: station, size: 120, glyph: 52)
            Text(station.name)
                .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                .tracking(-0.01 * Nocturne.TextSize.tileLabel)
                .foregroundStyle(Nocturne.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused, restingRing: Nocturne.hairline)
    }
}

/// The server's cached icon (`iconUrl`, resolved against the base), with the app's placeholder
/// when the server has none or the fetch fails. The raw `icon` is never loaded — it points at
/// Wikipedia and Google, and the contract says to use the cached copy (:317-318).
struct StationIcon: View {
    let station: RadioStation?
    var size: CGFloat = 120
    var glyph: CGFloat = 52

    var body: some View {
        ServerImage(path: station?.iconUrl, contentMode: .fit) {
            ZStack {
                LinearGradient(colors: [Nocturne.neutral800, Nocturne.neutral900], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "radio")
                    .font(.nocturne(glyph))
                    .foregroundStyle(Nocturne.neutral400)
            }
        }
        .frame(width: size, height: size)
        .background(Nocturne.neutral900, in: RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
    }
}
