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
        VStack(alignment: .leading, spacing: expanded ? 8 : 12) {
            brand
                .padding(.bottom, 26)
            ForEach(Destination.railOrder) { destination in
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

    /// The accent bar and the wordmark (dc:59-62); the bar alone when collapsed (dc:181).
    private var brand: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Nocturne.accent)
                .frame(width: 12, height: 30)
                .padding(.leading, expanded ? 0 : 26)
            if expanded {
                Text("Marlin")
                    .font(.nocturne(Nocturne.TextSize.body, .medium))
                    .foregroundStyle(Nocturne.text)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(clientName)
            Text(ServerConfig.hostLabel)
        }
        .font(.nocturne(Nocturne.TextSize.floor))
        .foregroundStyle(Nocturne.neutral600)
    }
}

/// One rail entry. Active (the current screen) and focused states follow the design data
/// `railAt` / `railFocused` (dc:1138-1149): active = accent tint, accent-700 hairline,
/// accent-200 ink; focused = 4 pt accent ring, stronger tint, text ink; otherwise neutral-500.
struct RailItem: View {
    let destination: Destination
    let expanded: Bool
    let isActive: Bool
    let isFocused: Bool

    private var ink: Color {
        if isFocused { return Nocturne.text }
        if isActive { return Nocturne.accent200 }
        return Nocturne.neutral500
    }

    private var fill: Color {
        if isFocused { return Nocturne.accent.opacity(0.16) }
        if isActive { return Nocturne.accent.opacity(0.14) }
        return .clear
    }

    private var ring: (Color, CGFloat) {
        if isFocused { return (Nocturne.accent, Nocturne.Focus.ringWidth) }
        if isActive { return (Nocturne.accent700, 1) }
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
                        .font(.nocturne(Nocturne.TextSize.body))
                        // Every entry is one line: "Manage DVR" (Pass 10B) is the first label
                        // long enough to wrap in the 372 pt expanded rail.
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 10)
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
    }
}
