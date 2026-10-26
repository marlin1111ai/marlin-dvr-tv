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
//  Pass 136 (owner, 2026-10-26, his 1a): Menu on a screen opens the sidebar on the entry of the
//  screen that is open, and Menu again — with the sidebar open — goes Home; `onLeave`, which the
//  screens call when Menu finds nothing of their own to close, is that same opening. A Left out of
//  the content lands on `SidebarCatcher`, a strip over the rail's trailing edge, which hands focus
//  to the current entry before any other entry can draw its ring; `railRestore` stays behind it
//  for the crossings that are not a move (the Player coming down, a reload). Settings is routed
//  to `SettingsScreen`.
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
    /// Pass 72: the Guide's chosen collection, owned above this shell for the same reason.
    let collections: GuideCollectionsModel
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
                .overlay(alignment: .leading) {
                    // Pass 136: the catcher sits over the rail's trailing 16 pt — nearer to every
                    // content row than any rail entry, so a Left lands here first (see below).
                    SidebarCatcher(armed: !railExpanded) { openSidebar() }
                        .frame(width: SidebarCatcherView.width)
                        .offset(x: -SidebarCatcherView.width)
                }
                .focusSection()
        }
        .background(Nocturne.bg)
        .onChange(of: focus) { _, landed in railRestore(landed) }
        // Pass 136 (owner's 1a): Menu with the sidebar open goes Home; Menu anywhere else in the
        // shell opens the sidebar. The screens that handle Menu themselves reach the same opening
        // through `onLeave`.
        .onExitCommand {
            if case .rail = focus {
                screen = nil
            } else {
                openSidebar()
            }
        }
    }

    /// Pass 136: open the sidebar on the entry of the screen that is open. `railRestore` sees the
    /// landing as already current and leaves it.
    private func openSidebar() {
        print("[rail] opening the sidebar on \(current.rawValue)")
        focus = .rail(current)
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
    /// Weather (Pass 13), Radio (Pass 19), Search (Pass 63) and Settings (Pass 136). Anything
    /// else keeps the placeholder.
    @ViewBuilder
    private var content: some View {
        // Pass 136: leaving a screen opens the sidebar; Home is one more Menu away.
        let leave = { openSidebar() }
        switch current {
        case .favorites: FavoritesScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .onNow: OnNowScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .guide: GuideScreen(api: api, collections: collections, onLeave: leave, onPlay: onPlay)
        // Pass 82: On Later's cards open the airing sheet, whose "Watch live" needs a Player to
        // hand the channel to — every other screen that shows the sheet already gets `onPlay`.
        case .onLater: OnLaterScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .recordings: RecordingsScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .cameras: CamerasScreen(api: api, onLeave: leave, onPlay: onPlay)
        case .manage: ManageDVRScreen(api: api, onLeave: leave)
        case .weather: WeatherScreen(model: weather, onLeave: leave)
        case .radio: RadioScreen(api: api, onLeave: leave)
        case .search: GuideSearchScreen(model: search, api: api, onLeave: leave)
        case .settings: SettingsScreen(api: api, clientName: clientName, onLeave: leave)
        default: PlaceholderScreen(destination: current)
        }
    }
}

// MARK: Pass 136 — the catcher at the sidebar/content boundary

/// A 16 pt focusable strip over the rail's trailing edge, hosted in UIKit the way the Guide's
/// `BackStepCatcher` is (Pass 123), so that a Left from anywhere in the content lands here — the
/// nearest thing to the left of every row — and the shell puts focus on the entry of the screen
/// that is open before any other rail entry can draw its ring. It can be focused only while
/// something in the content has focus (`armed`, and the focus system reporting a focused item): a
/// screen appearing with nothing focused never lands here, and a Right from the rail passes over it
/// into the content. It is invisible and draws no focus effect.
struct SidebarCatcher: UIViewRepresentable {
    let armed: Bool
    let onFocus: () -> Void

    func makeUIView(context: Context) -> SidebarCatcherView { SidebarCatcherView() }

    func updateUIView(_ view: SidebarCatcherView, context: Context) {
        view.armed = armed
        view.onFocus = onFocus
    }
}

final class SidebarCatcherView: UIView {
    static let width: CGFloat = 16

    var armed = false
    var onFocus: () -> Void = {}

    override var canBecomeFocused: Bool {
        armed && UIFocusSystem.focusSystem(for: self)?.focusedItem != nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView === self {
            print("[rail] boundary catcher took a \(context.focusHeading == .left ? "Left" : "move") from the content")
            onFocus()
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
