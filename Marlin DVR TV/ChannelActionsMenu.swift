//
//  ChannelActionsMenu.swift
//  Marlin DVR TV
//
//  Pass 9 step 7: click and hold a channel cell in the Guide's left column to favourite or
//  unfavourite that channel — `PUT /api/sources/{sourceId}/lineup/{guid} {"favorite": …}`
//  (sources.go:960-1004). The row shows the channel's current state, which comes from the
//  `MergedChannel` the guide response embeds (the same `favorite` field `/api/channels`
//  returns, sources.go:103-122).
//
//  The override is server-wide, like "Hide this channel": the web UI and the other Apple TV
//  see the favourite too. Nothing on the airing sheet favourites a channel.
//

import SwiftUI

struct ChannelActionsMenu: View {
    let channel: MergedChannel
    let isFavourite: Bool
    let api: APIClient
    /// The favourite flag the server now holds.
    let onApplied: (Bool) -> Void
    let onClose: () -> Void

    @FocusState private var focused: String?
    @State private var busy = false
    @State private var error: String?

    private var actionTitle: String { isFavourite ? "Unfavorite" : "Favorite" }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.bg.opacity(0.72), Nocturne.bg.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHANNEL")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .tracking(0.12 * Nocturne.TextSize.floor)
                        .foregroundStyle(Nocturne.accent300)
                    HStack(spacing: 18) {
                        InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: 62, fontSize: Nocturne.TextSize.floor)
                        Text("\(channel.number) · \(channel.name)")
                            .font(.nocturne(44, .medium))
                            .foregroundStyle(Nocturne.text)
                            .lineLimit(1)
                    }
                }
                MenuRow(
                    title: busy ? "Working…" : actionTitle,
                    state: isFavourite ? "★ Favorite" : "Not a favorite",
                    focused: focused == "favorite"
                ) {
                    guard !busy else { return }
                    Task { await apply() }
                }
                .focused($focused, equals: "favorite")
                Text("Favorites are the server's own list: the web UI and the other Apple TV see this too.")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
                    .lineLimit(2)
                if let error {
                    Text(error)
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral200)
                        .lineLimit(2)
                }
            }
            .padding(44)
            .frame(width: 860, alignment: .topLeading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
        }
        .focusSection()
        .onExitCommand { onClose() }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                focused = "favorite"
            }
        }
    }

    private func apply() async {
        busy = true
        error = nil
        do {
            let override = try await api.setChannelFavourite(sourceId: channel.sourceId, guid: channel.guid, favourite: !isFavourite)
            onApplied(override.favorite)
        } catch {
            self.error = WriteError.text(error)
            print("[channel] favourite failed: \(error)")
        }
        busy = false
    }
}

/// One row of an actions menu: title on the left, current state on the right (frame 5d's
/// long-press list, dc:643, and the same treatment for the channel menu).
struct MenuRow: View {
    let title: String
    let state: String
    let focused: Bool
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            HStack(spacing: 20) {
                Text(title)
                    .font(.nocturne(Nocturne.TextSize.body))
                    .foregroundStyle(enabled ? Nocturne.text : Nocturne.neutral600)
                Spacer(minLength: 0)
                Text(state)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : Nocturne.neutral800, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
        }
        .buttonStyle(BareButtonStyle())
    }
}
