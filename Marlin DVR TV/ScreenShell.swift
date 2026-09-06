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

import SwiftUI

struct ScreenShell: View {
    @Binding var screen: Destination?
    let clientName: String
    let api: APIClient
    @FocusState private var focus: ShellFocus?

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
                // Favorites, Weather, Radio: present as drawn, inert (DECISIONS.md).
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
        .onExitCommand { screen = nil }
    }

    /// Pass 6 (sweep 2): the five read-only screens; anything else keeps the placeholder.
    @ViewBuilder
    private var content: some View {
        let leave = { screen = nil }
        switch current {
        case .onNow: OnNowScreen(api: api, onLeave: leave)
        case .guide: GuideScreen(api: api, onLeave: leave)
        case .onLater: OnLaterScreen(api: api, onLeave: leave)
        case .recordings: RecordingsScreen(api: api, onLeave: leave)
        case .cameras: CamerasScreen(api: api, onLeave: leave)
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
