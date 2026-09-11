//
//  ScreenShell.swift
//  Marlin DVR TV
//
//  A screen inside the rail: the rail on the left, the content beside it with the design's
//  60/80 pt margins and 56 pt clearance from the rail (frame 1b, dc:74). The rail is
//  expanded while focus is on a rail item and collapsed while focus is in the content.
//  Menu (the exit command) returns to Home, as the guide footer of frame 3c states
//  ("Back again leaves the Guide"); the sweep-2 screens handle Menu themselves and call
//  `onLeave` when they have nothing of their own to close.
//
//  Pass 25: the remote comes back to the rail entry of the screen it is on. `screen` was
//  always the record of which entry opened the content — nothing ever restored it, so tvOS
//  picked the rail icon nearest whatever the content had focused (Pass 24 §4.2). The restore
//  is `railRestore` below, and it fires only on the crossing from the content into the rail,
//  so Up/Down inside the rail still move freely.
//

import SwiftUI

struct ScreenShell: View {
    @Binding var screen: Destination?
    let clientName: String
    let api: APIClient
    /// Pass 13: the one WeatherKit read, shared with Home so the location prompt happens once.
    let weather: WeatherModel
    /// Pass 63: Search's model is owned above the shell, because `.id(current)` below rebuilds
    /// the content on every visit and the owner's decision is that a query and its results
    /// survive a trip to the rail and back.
    let search: GuideSearchModel
    let onPlay: (PlayRequest) -> Void
    @FocusState private var focus: ShellFocus?
    /// True while the remote is inside the rail; the guard on the restore, so it fires on the
    /// way in and never again.
    @State private var railHasFocus = false

    private var current: Destination { screen ?? .home }

    private var railExpanded: Bool {
        if case .rail = focus { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            RailView(current: current, expanded: railExpanded, clientName: clientName, focus: $focus) { destination in
                if destination == .home {
                    screen = nil
                } else if destination.isBuiltNow {
                    screen = destination
                }
                // Every rail entry is built now; Settings is a Home tile only and stays parked.
            }
            content
                .id(current)
                .padding(.top, Nocturne.Layout.marginVertical)
                .padding(.bottom, Nocturne.Layout.marginVertical)
                .padding(.leading, Nocturne.Layout.contentLeadingBesideRail)
                .padding(.trailing, Nocturne.Layout.marginHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .focusSection()
        }
        .background(Nocturne.bg)
        .onChange(of: focus) { _, landed in railRestore(landed) }
        .onExitCommand { screen = nil }
    }

    /// Focus has moved. If it has just crossed into the rail from the content — from the Player
    /// coming down, or from a reload, or from a plain swipe left — put it on the entry of the
    /// screen that is open, whatever the focus engine picked by geometry. Movement *within* the
    /// rail is left alone: `railHasFocus` is already true by then.
    private func railRestore(_ landed: ShellFocus?) {
        guard case .rail(let entry) = landed else {
            railHasFocus = false
            return
        }
        guard !railHasFocus else { return }
        railHasFocus = true
        if entry == current {
            print("[rail] entered on \(entry.rawValue) — already the current screen")
        } else {
            print("[rail] entered on \(entry.rawValue), restoring to \(current.rawValue)")
            focus = .rail(current)
        }
    }

    /// The screens that exist: sweep 2's five, Favorites (Pass 10), Manage DVR (Pass 10B),
    /// Weather (Pass 13), Radio (Pass 19) and Search (Pass 63). Anything else keeps the
    /// placeholder.
    @ViewBuilder
    private var content: some View {
        let leave = { screen = nil }
        switch current {
        case .favorites: FavoritesScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .onNow: OnNowScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .guide: GuideScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .onLater: OnLaterScreen(api: api, onLeave: leave)
        case .recordings: RecordingsScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .cameras: CamerasScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .manage: ManageDVRScreen(api: api, onLeave: leave)
        case .weather: WeatherScreen(model: weather, onLeave: leave)
        case .radio: RadioScreen(api: api, onLeave: leave)
        case .search: GuideSearchScreen(model: search, api: api, onLeave: leave)
        default: PlaceholderScreen(destination: current)
        }
    }
}

/// An empty, titled screen; sweep 2 replaces it with the real content.
struct PlaceholderScreen: View {
    let destination: Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                Text(destination.label)
                    .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                    .tracking(-0.01 * Nocturne.TextSize.screenTitle)
                    .foregroundStyle(Nocturne.text)
                Spacer(minLength: 0)
            }
            Text("Nothing here yet. This screen is built in sweep 2.")
                .font(.nocturne(Nocturne.TextSize.secondary))
                .foregroundStyle(Nocturne.neutral500)
            Spacer(minLength: 0)
        }
    }
}
