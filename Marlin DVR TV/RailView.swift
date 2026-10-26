//
//  RailView.swift
//  Marlin DVR TV
//
//  The sidebar rail of frame 1b: the design's nine destinations in its order plus Manage DVR
//  at the bottom (Pass 10B, owner 2026-09-06), expanded to
//  372 pt with labels while focus is in the rail (dc:58-73), collapsed to a 180 pt icon
//  strip while focus is in the content (the aside of frames 3a–5e, dc:180-185). Not shown
//  on Home (dc:111). The footer names this Apple TV and the server (dc:69-72).
//
//  Pass 25: which entry the remote comes back to is `ScreenShell`'s to decide, not the focus
//  engine's — the rail itself is unchanged. `focusScope` + `prefersDefaultFocus(destination ==
//  current)` was tried here first and measured on the Apple TV to change nothing at all: the
//  landing stayed Pass 24's, entry for entry. The rail draws the ring on the active entry
//  (`railFocused`, dc:1144-1149); putting focus there is `ScreenShell.railRestore`.
//
//  Pass 136 (owner, 2026-10-26): the app icon's artwork at the top instead of the accent bar
//  and wordmark, Settings as the twelfth entry at the bottom, the list read from
//  `Destination.sidebar`, and the focus scale on the entry. Twelve entries and the logo have to
//  fit in the 960 pt between the margins, so the entry's vertical padding is 8 pt (was 10) and
//  the collapsed spacing 8 pt (was 12).
//

import SwiftUI

/// Where focus is inside a screen shell: on a rail item, or in the content.
enum ShellFocus: Hashable {
    case rail(Destination)
    case content
}

/// A button that draws only its label; focus is drawn by the label itself.
struct BareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct RailView: View {
    let current: Destination
    let expanded: Bool
    let clientName: String
    @FocusState.Binding var focus: ShellFocus?
    let onSelect: (Destination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            brand
                .padding(.bottom, 20)
            ForEach(Destination.sidebar) { destination in
                Button {
                    onSelect(destination)
                } label: {
                    RailItem(
                        destination: destination,
                        expanded: expanded,
                        isActive: destination == current,
                        isFocused: focus == .rail(destination)
                    )
                }
                .buttonStyle(BareButtonStyle())
                .focused($focus, equals: .rail(destination))
            }
            Spacer(minLength: 0)
            if expanded {
                footer
            }
        }
        .padding(.top, Nocturne.Layout.marginVertical)
        .padding(.bottom, Nocturne.Layout.marginVertical)
        .padding(.leading, Nocturne.Layout.marginHorizontal)
        .padding(.trailing, expanded ? 34 : 0)
        .frame(width: expanded ? Nocturne.Layout.railExpandedWidth : Nocturne.Layout.railCollapsedWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Nocturne.surface.opacity(expanded ? 0.7 : 0.6), .clear],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Nocturne.divider).frame(width: 1)
        }
        .focusSection()
        .animation(.easeInOut(duration: 0.2), value: expanded)
    }

    /// Pass 136: the app icon's own artwork (owner's 3a) — `SidebarLogo` in the catalog, the one
    /// image copied from the icon's front layer — at the icon's 5:3: 150 × 90 pt expanded, 64 × 38 pt
    /// collapsed, where it lines up with the icon column. It replaces the accent bar and wordmark
    /// of dc:59-62 and the bar alone of dc:181.
    private var brand: some View {
        Image("SidebarLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: expanded ? 150 : 64, height: expanded ? 90 : 38)
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(clientName)
            Text(ServerConfig.hostLabel)
        }
        .font(.nocturne(.meta))
        .foregroundStyle(Nocturne.neutral600)
    }
}

/// One rail entry. Active (the current screen) and focused states follow the design data
/// `railAt` / `railFocused` (dc:1138-1149): active = accent tint, accent-700 hairline,
/// accent-200 ink; focused = 4 pt accent ring, stronger tint, text ink; otherwise neutral-500.
/// Pass 136: the inks and rings are read from the focus-label tokens (the same values), and the
/// entry scales on focus.
struct RailItem: View {
    let destination: Destination
    let expanded: Bool
    let isActive: Bool
    let isFocused: Bool

    private var ink: Color {
        if isFocused { return Nocturne.FocusLabel.focusedInk }
        if isActive { return Nocturne.FocusLabel.activeInk }
        return Nocturne.neutral500
    }

    private var fill: Color {
        if isFocused { return Nocturne.accent.opacity(0.16) }
        if isActive { return Nocturne.FocusLabel.activeFill }
        return .clear
    }

    private var ring: (Color, CGFloat) {
        if isFocused { return (Nocturne.FocusLabel.focusedRing, Nocturne.Focus.ringWidth) }
        if isActive { return (Nocturne.FocusLabel.activeRing, 1) }
        return (.clear, 1)
    }

    var body: some View {
        Group {
            if expanded {
                HStack(spacing: 20) {
                    Image(systemName: destination.railSymbol)
                        .font(.nocturne(34))
                        .frame(width: 36)
                    Text(destination.label)
                        .font(.nocturne(.body))
                        // Every entry is one line: "Manage DVR" (Pass 10B) is the first label
                        // long enough to wrap in the 372 pt expanded rail.
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: destination.railSymbol)
                    .font(.nocturne(36))
                    .frame(width: 64, height: 64)
            }
        }
        .foregroundStyle(ink)
        .background(fill, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                .strokeBorder(ring.0, lineWidth: ring.1)
        }
        .scaleEffect(isFocused ? Nocturne.Focus.scale : 1)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
