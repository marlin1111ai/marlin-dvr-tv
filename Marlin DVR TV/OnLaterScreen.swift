//
//  OnLaterScreen.swift
//  Marlin DVR TV
//
//  On Later, frame 5a (dc:436-492): the two sections of GET /api/guide/later
//  (guide.go:695-754) — title, subtitle, "channel · when", the art square, and the
//  ● Scheduled mark. Rows take focus; selecting one is owned by a later sweep.
//

import SwiftUI

@Observable
final class OnLaterModel {
    private let api: APIClient
    private(set) var sections: [LaterSection] = []
    private(set) var loaded = false
    private(set) var error: String?

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            sections = try await api.later().sections
            error = nil
        } catch {
            self.error = "\(error)"
            print("[later] guide/later: \(error)")
        }
        loaded = true
    }
}

struct OnLaterScreen: View {
    let onLeave: () -> Void
    @State private var model: OnLaterModel
    @FocusState private var focused: String?

    init(api: APIClient, onLeave: @escaping () -> Void) {
        self.onLeave = onLeave
        _model = State(initialValue: OnLaterModel(api: api))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            ScreenHeader("On Later", subtitle: "New, premiere, live, finale and movie airings") {
                TimelineView(.everyMinute) { context in
                    Text("\(TimeFormat.shortDay(context.date)) · \(TimeFormat.clock(context.date))")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral500)
                }
            }
            if let error = model.error, model.sections.isEmpty {
                ErrorLine(text: error)
            } else if !model.loaded {
                LoadingLine().focusable().focused($focused, equals: "loading")
            }
            HStack(alignment: .top, spacing: 48) {
                ForEach(Array(model.sections.enumerated()), id: \.offset) { index, section in
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 18) {
                            Text(section.label)
                                .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                                .foregroundStyle(Nocturne.text)
                            LinearGradient(colors: [Nocturne.divider, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(height: 1)
                        }
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 22) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { itemIndex, item in
                                    let id = "\(index):\(itemIndex)"
                                    Button {
                                        // Opening the airing from here is a later sweep's wiring.
                                    } label: {
                                        LaterRow(item: item, focused: focused == id)
                                    }
                                    .buttonStyle(BareButtonStyle())
                                    .focused($focused, equals: id)
                                }
                                if section.items.isEmpty {
                                    Text("Nothing listed.")
                                        .font(.nocturne(Nocturne.TextSize.secondary))
                                        .foregroundStyle(Nocturne.neutral500)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .defaultFocus($focused, model.sections.first(where: { !$0.items.isEmpty }).map { _ in "0:0" } ?? "loading")
        .task {
            await model.load()
            let id = model.sections.firstIndex(where: { !$0.items.isEmpty }).map { "\($0):0" }
            focusSoon { focused = id ?? "loading" }
        }
        .onExitCommand { onLeave() }
    }
}

/// One On Later row (dc:458-468).
struct LaterRow: View {
    let item: LaterItem
    let focused: Bool

    var body: some View {
        HStack(spacing: 22) {
            ServerImage(path: item.art) {
                ArtPlaceholder(cornerRadius: Nocturne.Radius.sm)
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(1)
                Text("\(item.channel) · \(item.when)")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.scheduled {
                Text("● Scheduled")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.accent200)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .overlay { Capsule().strokeBorder(Nocturne.accent600, lineWidth: 1) }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(focused ? Nocturne.accent.mix(with: Nocturne.surface, by: 0.9) : Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .focusTreatment(focused)
    }
}
