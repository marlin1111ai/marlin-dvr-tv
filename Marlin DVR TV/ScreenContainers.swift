//
//  ScreenContainers.swift
//  Marlin DVR TV
//
//  Pass 137: the screen containers the Channels app builds every screen from (REA report §2.3,
//  §5.1 item 2), built once here and reused — the grid page with a filter bar, and the list with
//  a side detail. The third, the rails page, is Recordings' shape and is not built until
//  Recordings moves onto it (owner's 3a, 2026-10-26: later, after the first two are seen).
//
//  On Now and On Later are the grid page (this pass); Settings is the list-plus-detail (lifted
//  out of Pass 136's screen). A container owns layout only — the header, the bar, the status
//  line, the grid or the two panes — never the cards, the rows or the models.
//

import SwiftUI

/// The filter bar: chips in a sideways-scrolling row, so however many there are the row never
/// runs past the screen or pushes the shell (the overflow Pass 136 found on On Now, owner's 1a),
/// and a slot on the right for the Sort / Genre / Rating menus the Channels bar has — empty in
/// this pass (owner's 2a). tvOS scrolls the row to keep the focused chip in view by itself.
struct FilterBar<Item: Hashable, Menus: View>: View {
    let items: [Item]
    let label: (Item) -> String
    let isActive: (Item) -> Bool
    let focusID: (Item) -> String
    var focus: FocusState<String?>.Binding
    let select: (Item) -> Void
    let menus: () -> Menus

    /// Chips only; the menu slot is empty.
    init(items: [Item],
         label: @escaping (Item) -> String,
         isActive: @escaping (Item) -> Bool,
         focusID: @escaping (Item) -> String,
         focus: FocusState<String?>.Binding,
         select: @escaping (Item) -> Void) where Menus == EmptyView {
        self.items = items
        self.label = label
        self.isActive = isActive
        self.focusID = focusID
        self.focus = focus
        self.select = select
        self.menus = { EmptyView() }
    }

    /// Chips and the menus on the right.
    init(items: [Item],
         label: @escaping (Item) -> String,
         isActive: @escaping (Item) -> Bool,
         focusID: @escaping (Item) -> String,
         focus: FocusState<String?>.Binding,
         select: @escaping (Item) -> Void,
         @ViewBuilder menus: @escaping () -> Menus) {
        self.items = items
        self.label = label
        self.isActive = isActive
        self.focusID = focusID
        self.focus = focus
        self.select = select
        self.menus = menus
    }

    var body: some View {
        HStack(spacing: 28) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            select(item)
                        } label: {
                            PillLabel(text: label(item), active: isActive(item), focused: focus.wrappedValue == focusID(item))
                        }
                        .buttonStyle(BareButtonStyle())
                        .focused(focus, equals: focusID(item))
                    }
                }
                // The focus ring is drawn inside the pill, so no padding is needed for it; the
                // 4 pt keeps the scroll view's clip clear of the ring's edge.
                .padding(.vertical, 4)
            }
            menus()
        }
        .focusSection()
    }
}

/// The grid page: the screen header, the bar under it, an optional status line, and a
/// three-column grid of whatever cards the screen passes — On Now's page (dc:74-100), which On
/// Later copied in Pass 82. `disabled` greys the grid while an overlay is up.
///
/// **The focus room (owner's photos, 2026-10-26).** The scroll area clips at its own edges, and a
/// focused card grows 5 % about its centre and lifts 6 pt (`FocusTreatment`), so a card in the
/// first column — sitting flush with the content's edge — lost its left side, a card in the third
/// column ran past the content's right edge, and the top row lost its ring. The grid is therefore
/// inset inside the scroll area on every side by the growth itself: the side inset is computed
/// from the measured content width (`focusInset(for:)`, so three columns *and* a focused card
/// fit inside it, sidebar closed or open), and the top and bottom carry `focusHeadroom`. The
/// scroll area itself still clips, so cards scrolled under the bar never draw over it.
struct GridPage<Trailing: View, Bar: View, Status: View, Cards: View>: View {
    let title: String
    var subtitle: String? = nil
    var disabled = false
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let status: () -> Status
    @ViewBuilder let cards: () -> Cards

    /// Three flexible columns, 28 across and 30 down (On Now since Pass 6).
    static var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 28), count: 3) }
    static var columnCount: CGFloat { 3 }
    static var columnSpacing: CGFloat { 28 }

    /// The room above the top row and below the last: the lift, the scale on a card up to
    /// 300 pt tall (7.5 pt) and the part of the ambient shadow that reaches above the card
    /// (its radius less its downward offset, 6 pt) — 20 pt.
    static var focusHeadroom: CGFloat { 20 }

    /// The room at each side, from the width the scroll area actually has: the inset `i` and
    /// the column `c` that solve `c = (W − 2i − 2s) / 3` with `i = c · (scale − 1) / 2`, rounded
    /// up, so a focused card in the first or the third column grows exactly to the content's
    /// edge and not past it. 13 pt at the content width beside the collapsed rail (1604 pt,
    /// columns of 507), 12 pt beside the open sidebar (1412 pt).
    static func focusInset(for width: CGFloat) -> CGFloat {
        let growth = (Nocturne.Focus.scale - 1) / 2
        let column = (width - (columnCount - 1) * columnSpacing) / (columnCount + 2 * growth)
        return max(0, ceil(column * growth))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            ScreenHeader(title, subtitle: subtitle, trailing: trailing)
            bar()
            status()
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Self.columns, spacing: 30) {
                        cards()
                    }
                    .padding(.horizontal, Self.focusInset(for: geo.size.width))
                    .padding(.vertical, Self.focusHeadroom)
                }
            }
            .disabled(disabled)
        }
    }
}

/// The list with a side detail: the groups on the left, the chosen group's rows on the right
/// (REA §2.3's list-plus-detail; Settings since Pass 136).
struct ListDetailPage<Groups: View, Detail: View>: View {
    let title: String
    var subtitle: String? = nil
    var listWidth: CGFloat = 420
    @ViewBuilder let groups: () -> Groups
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            ScreenHeader(title, subtitle: subtitle)
            HStack(alignment: .top, spacing: 40) {
                groups()
                    .frame(width: listWidth)
                detail()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A group in the list pane: a focusable label with the three states the rail entry has — focused,
/// active (its rows are the ones showing) and resting — read from the focus-label tokens.
/// Pass 136's Settings group row, moved here with the container.
struct ListGroupRow: View {
    let title: String
    let active: Bool
    let focused: Bool

    private var ink: Color {
        if focused { return Nocturne.FocusLabel.focusedInk }
        if active { return Nocturne.FocusLabel.activeInk }
        return Nocturne.neutral500
    }

    private var fill: Color {
        if focused { return Nocturne.FocusLabel.focusedFill }
        if active { return Nocturne.FocusLabel.activeFill }
        return .clear
    }

    private var ring: (Color, CGFloat) {
        if focused { return (Nocturne.FocusLabel.focusedRing, Nocturne.Focus.ringWidth) }
        if active { return (Nocturne.FocusLabel.activeRing, 1) }
        return (.clear, 1)
    }

    var body: some View {
        Button { } label: {
            Text(title)
                .font(.nocturne(.body))
                .foregroundStyle(ink)
                .padding(.vertical, 16)
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fill, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                        .strokeBorder(ring.0, lineWidth: ring.1)
                }
                .scaleEffect(focused ? Nocturne.Focus.scale : 1)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
        .buttonStyle(BareButtonStyle())
    }
}
