//
//  ScreenChrome.swift
//  Marlin DVR TV
//
//  Pieces every sweep-2 screen shares: the screen header (52 pt title, 26 pt subtitle,
//  frames 1b/3a/5a/5b/5e), the design's one focus treatment as a modifier, the small
//  uppercase tag (frame 5c "New"), the pill (chips and the guide's "+12h"), the art
//  placeholder block, and the loading / error lines.
//

import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
            Text(title)
                .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                .tracking(-0.01 * Nocturne.TextSize.screenTitle)
                .foregroundStyle(Nocturne.text)
            if let subtitle {
                Text(subtitle)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

/// The 4 pt accent ring, the lift and the ambient shadow (design data FOCUS_ON), or the
/// resting hairline.
struct FocusTreatment: ViewModifier {
    let focused: Bool
    var cornerRadius: CGFloat = Nocturne.Radius.md
    var lift: CGFloat = Nocturne.Focus.lift
    var restingRing: Color = .clear

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : restingRing, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
            .offset(y: focused ? -lift : 0)
            .shadow(color: focused ? Nocturne.Focus.shadowColor : .clear, radius: Nocturne.Focus.shadowRadius, y: Nocturne.Focus.shadowY)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

extension View {
    func focusTreatment(_ focused: Bool, cornerRadius: CGFloat = Nocturne.Radius.md, lift: CGFloat = Nocturne.Focus.lift, restingRing: Color = .clear) -> some View {
        modifier(FocusTreatment(focused: focused, cornerRadius: cornerRadius, lift: lift, restingRing: restingRing))
    }
}

/// "NEW" style tag: 23 pt, uppercase, accent-300 on an accent-700 hairline (frame 5c, dc:561).
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.nocturne(Nocturne.TextSize.floor))
            .tracking(0.12 * Nocturne.TextSize.floor)
            .foregroundStyle(Nocturne.accent300)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous)
                    .strokeBorder(Nocturne.accent700, lineWidth: 1)
            }
    }
}

/// A pill: the filter chips of frame 1b (dc:80-83) and the guide's "+12h" / "↩ Now" (dc:192, 314).
struct PillLabel: View {
    let text: String
    var active = false
    var focused = false
    var size: CGFloat = Nocturne.TextSize.secondary

    var body: some View {
        Text(text)
            .font(.nocturne(size))
            .foregroundStyle(active ? Nocturne.accent200 : (focused ? Nocturne.text : Nocturne.neutral400))
            .padding(.vertical, size == Nocturne.TextSize.secondary ? 10 : 8)
            .padding(.horizontal, size == Nocturne.TextSize.secondary ? 24 : 20)
            .background(active ? Nocturne.accent900 : (focused ? Nocturne.accent.opacity(0.14) : .clear), in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    focused ? Nocturne.accent : (active ? Nocturne.accent700 : Nocturne.neutral800),
                    lineWidth: focused ? Nocturne.Focus.ringWidth : 1
                )
            }
            .lineLimit(1)
            .fixedSize()
    }
}

/// The grey art block the design draws where server art goes (dc:383, 459, 558).
struct ArtPlaceholder: View {
    var cornerRadius: CGFloat = Nocturne.Radius.md

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: [Nocturne.neutral800, Nocturne.neutral900], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// Moves focus after the next render — a screen's content does not receive focus on its own
/// when it appears beside the rail (observed in Pass 6), so each screen sets it once it has data.
func focusSoon(_ apply: @escaping () -> Void) {
    Task {
        try? await Task.sleep(for: .milliseconds(80))
        apply()
    }
}

struct LoadingLine: View {
    var text = "Loading…"

    var body: some View {
        Text(text)
            .font(.nocturne(Nocturne.TextSize.secondary))
            .foregroundStyle(Nocturne.neutral500)
    }
}

struct ErrorLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.nocturne(Nocturne.TextSize.floor))
            .foregroundStyle(Nocturne.neutral400)
            .lineLimit(2)
    }
}

/// The 6 pt progress track of frames 1b / 4b (dc:93-95).
struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Nocturne.neutral800)
                Capsule().fill(Nocturne.accent).frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

/// An inert, focusable button drawn like the design's outlined action (frame 5c/5d buttons).
struct InertActionButton: View {
    let title: String
    let primary: Bool
    let focused: Bool
    var size: CGFloat = Nocturne.TextSize.body

    var body: some View {
        Text(title)
            .font(.nocturne(size))
            .foregroundStyle(primary || focused ? Nocturne.text : Nocturne.neutral200)
            .padding(.vertical, 18)
            .padding(.horizontal, 36)
            .background(focused ? Nocturne.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(focused ? Nocturne.accent : Nocturne.neutral700, lineWidth: focused ? Nocturne.Focus.ringWidth : 1)
            }
            .shadow(color: focused ? Nocturne.accent.opacity(0.24) : .clear, radius: 0, x: 0, y: 0)
            .fixedSize()
    }
}
