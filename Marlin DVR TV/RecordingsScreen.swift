//
//  RecordingsScreen.swift
//  Marlin DVR TV
//
//  Recordings, frame 5b (dc:500-538) with the 4a poster cards (dc:375-394): the header
//  counts from GET /api/library (shows, recordings; the TB figure is omitted — no endpoint
//  supplies it, Pass 4 §3.7), the three shelves of the response, six cards per row, the
//  unwatched badge. Selecting a show opens show detail; Menu returns to the shelves.
//

import SwiftUI

@Observable
final class RecordingsModel {
    private let api: APIClient
    private(set) var library: LibraryResponse?
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            library = try await api.library(limit: 6)
            error = nil
        } catch {
            self.error = "\(error)"
            print("[recordings] library: \(error)")
        }
        loaded = true
    }
}

struct RecordingsScreen: View {
    let api: APIClient
    let onLeave: () -> Void
    @State private var model: RecordingsModel
    @State private var selected: ShowSummary?
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void) {
        self.api = api
        self.onLeave = onLeave
        _model = State(initialValue: RecordingsModel(api: api))
    }

    var body: some View {
        Group {
            if let selected {
                ShowDetailScreen(api: api, show: selected)
            } else {
                shelves
            }
        }
        .task {
            await model.load()
            let id = firstCardID
            focusSoon { focused = id ?? "loading" }
        }
        .onExitCommand {
            if selected != nil {
                selected = nil
                let id = firstCardID
                focusSoon { focused = id ?? "loading" }
            } else {
                onLeave()
            }
        }
    }

    private var subtitle: String? {
        guard let lib = model.library else { return nil }
        return "\(lib.shows) shows · \(lib.recordings) recordings"
    }

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 38) {
            ScreenHeader("Recordings", subtitle: subtitle) {
                Text("Watched and keep flags are shared with the other Apple TV")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            if let error = model.error, model.library == nil {
                ErrorLine(text: error)
            } else if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(model.library?.sections ?? [], id: \.key) { section in
                        VStack(alignment: .leading, spacing: 18) {
                            Text(section.label)
                                .font(.nocturne(34, .medium))
                                .foregroundStyle(Nocturne.text)
                            if section.items.isEmpty {
                                Text("Nothing yet.")
                                    .font(.nocturne(Nocturne.TextSize.floor))
                                    .foregroundStyle(Nocturne.neutral600)
                                    .frame(height: 60)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 30) {
                                        ForEach(section.items) { show in
                                            let id = "\(section.key):\(show.id)"
                                            Button {
                                                selected = show
                                            } label: {
                                                PosterCard(show: show, focused: focused == id)
                                            }
                                            .buttonStyle(BareButtonStyle())
                                            .focused($focused, equals: id)
                                        }
                                    }
                                    .padding(.vertical, 44)
                                    .padding(.horizontal, 40)
                                }
                            }
                        }
                    }
                }
            }
        }
        .defaultFocus($focused, firstCardID ?? "loading")
    }

    private var firstCardID: String? {
        guard let section = model.library?.sections.first(where: { !$0.items.isEmpty }), let show = section.items.first else { return nil }
        return "\(section.key):\(show.id)"
    }
}

/// The 4a poster card (dc:381-392): 2:3 art, the unwatched badge, title and count below;
/// focused = larger, lifted 22 pt, 4 pt ring, ambient shadow (dc:1273-1275).
struct PosterCard: View {
    let show: ShowSummary
    let focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ServerImage(path: show.art) {
                ArtPlaceholder()
            }
            .frame(width: 252, height: 344)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if show.unwatched > 0 {
                    Text("\(show.unwatched) new")
                        .font(.nocturne(Nocturne.TextSize.floor, .semibold))
                        .foregroundStyle(Nocturne.bg)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Nocturne.accent, in: Capsule())
                        .padding(14)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : Nocturne.neutral900, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
            .shadow(color: focused ? Nocturne.Focus.shadowColor : .clear, radius: Nocturne.Focus.shadowRadius, y: Nocturne.Focus.shadowY)
            Text(show.title)
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(Nocturne.text)
                .lineLimit(2)
            Text("\(show.count) episode\(show.count == 1 ? "" : "s")")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral500)
        }
        .frame(width: 252, alignment: .leading)
        .scaleEffect(focused ? 296.0 / 252.0 : 1, anchor: .center)
        .offset(y: focused ? -22 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}
