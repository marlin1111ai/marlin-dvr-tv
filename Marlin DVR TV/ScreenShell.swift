//
//  ScreenShell.swift
//  Marlin DVR TV
//
//  A screen inside the rail: the rail on the left, the content beside it with the design's
//  60/80 pt margins and 56 pt clearance from the rail (frame 1b, dc:74). The rail is
//  expanded while focus is on a rail item and collapsed while focus is in the content.
//  Menu (the exit command) returns to Home, as the guide footer of frame 3c states
//  ("Back again leaves the Guide").
//

import SwiftUI

struct ScreenShell: View {
    @Binding var screen: Destination?
    let clientName: String
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
            PlaceholderScreen(destination: current)
                .padding(.top, Nocturne.Layout.marginVertical)
                .padding(.bottom, Nocturne.Layout.marginVertical)
                .padding(.leading, Nocturne.Layout.contentLeadingBesideRail)
                .padding(.trailing, Nocturne.Layout.marginHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .focusable()
                .focused($focus, equals: .content)
                .focusSection()
        }
        .background(Nocturne.bg)
        .defaultFocus($focus, .content)
        .onExitCommand { screen = nil }
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
