//
//  Theme.swift
//  Marlin DVR TV
//
//  Nocturne design tokens (design/_ds/…/styles.css, _ds_manifest.json) and the tvOS
//  rules stated on the design page (design/"Marlin DVR TV.dc.html", header): screens are
//  1920 × 1080 at 1×; content sits 60 pt from top and bottom and 80 pt from the sides;
//  body text is 29 pt and secondary text never under 23 pt; one element carries focus,
//  drawn as a 4 pt accent ring, a lift and an ambient shadow. Only the ramp steps that
//  frames 1b (rail) and 2a (Home) use are carried here.
//
//  Pass 136 (owner, 2026-10-26, his 2b): Nocturne's colours stay. Added beside them are the
//  semantic colour pairs, the focusable label's states and one named text-style set — the REA
//  report's §3.4, §3.5 and §5.1 items 12–13 — with the three colours that lived in screens (the
//  Guide's green and gold, the schedule's conflict red) moved in here.
//

import SwiftUI

enum Nocturne {
    // Roles (styles.css :root)
    static let bg = Color(hex: 0x161826)
    static let surface = Color(hex: 0x232532)
    static let text = Color(hex: 0xE9E9ED)
    static let accent = Color(hex: 0x9184D9)
    static let divider = Color(hex: 0xE9E9ED).opacity(0.16)   // color-mix(#e9e9ed 16%, transparent)
    static let section = Color(hex: 0x262A60)

    // Accent ramp steps used by 1b / 2a
    static let accent200 = Color(hex: 0xE7E5FE)
    static let accent300 = Color(hex: 0xD2CEFD)
    static let accent600 = Color(hex: 0x796CBF)
    static let accent700 = Color(hex: 0x5D5294)
    static let accent900 = Color(hex: 0x2B2741)

    // Neutral ramp steps used by 1b / 2a
    static let neutral100 = Color(hex: 0xF3F5FE)
    static let neutral200 = Color(hex: 0xE4E7F5)
    static let neutral300 = Color(hex: 0xCFD3E5)
    static let neutral400 = Color(hex: 0xB2B6CA)
    static let neutral500 = Color(hex: 0x9397AB)
    static let neutral600 = Color(hex: 0x75798C)
    static let neutral700 = Color(hex: 0x595D6C)
    static let neutral800 = Color(hex: 0x3F424D)
    static let neutral900 = Color(hex: 0x292B31)

    /// --radius-sm / -md / -lg
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 14
    }

    /// --space-1 … --space-8 (density 0.70×), in points
    enum Space {
        static let s1: CGFloat = 2.8
        static let s2: CGFloat = 5.6
        static let s3: CGFloat = 8.4
        static let s4: CGFloat = 11.2
        static let s6: CGFloat = 16.8
        static let s8: CGFloat = 22.4
    }

    /// The tvOS layout rules from the design page header and frames 1b / 2a
    enum Layout {
        static let marginVertical: CGFloat = 60
        static let marginHorizontal: CGFloat = 80
        static let railExpandedWidth: CGFloat = 372     // 1b aside
        static let railCollapsedWidth: CGFloat = 180    // 3a–5e aside
        static let contentLeadingBesideRail: CGFloat = 56   // 1b content padding-left
    }

    /// Type sizes named on the design page and used by 1b / 2a (points; the system font)
    enum TextSize {
        static let floor: CGFloat = 23        // secondary never under 23 pt
        static let secondary: CGFloat = 26
        static let body: CGFloat = 29
        static let cardTitle: CGFloat = 31
        static let tileLabel: CGFloat = 38
        static let screenTitle: CGFloat = 52
        static let greeting: CGFloat = 60
    }

    /// The one focus treatment: 4 pt accent ring, a lift, an ambient shadow (FOCUS_ON in the design data)
    enum Focus {
        static let ringWidth: CGFloat = 4
        static let lift: CGFloat = 6
        static let shadowColor = Color.black.opacity(0.7)
        static let shadowRadius: CGFloat = 32
        static let shadowY: CGFloat = 26
        /// Pass 136: the scale that goes with the lift (REA report §5.2 item 2) — 5 %, drawn over
        /// the neighbours without moving them, small enough that a full-width row stays on screen.
        static let scale: CGFloat = 1.05
    }

    /// Pass 136: the semantic colour pairs — one text ink and one background tint per meaning.
    /// Nocturne's own colours, kept (owner's 2b): the recording and scheduled green and the pass
    /// gold are the Guide's marks (dc:1183-1189), the error red is the schedule's conflict colour,
    /// and the tint is the 20 % the Guide draws behind a marked cell. Favourited shares the pass
    /// gold (the Guide's ★); warning and destructive are drawn nowhere yet and take the gold and
    /// the red so that the first screen to need them has a value to read. The Channels app's own
    /// hex-to-role pairing is unconfirmed (REA report §3.5), so nothing here is copied from it.
    enum Semantic {
        struct Pair {
            let text: Color
            let background: Color
            init(_ hex: UInt32, tint: Double = 0.2) {
                text = Color(hex: hex)
                background = Color(hex: hex, opacity: tint)
            }
        }
        static let recording = Pair(0x57B083)
        static let scheduled = Pair(0x57B083)
        static let pass = Pair(0xD6A94E)
        static let favourited = Pair(0xD6A94E)
        static let warning = Pair(0xD6A94E)
        static let error = Pair(0xC2686B)
        static let destructive = Pair(0xC2686B)
    }

    /// Pass 136: the focusable label's states — resting, focused and active (the chosen item of a
    /// list that stays marked while focus is elsewhere: the rail's current entry, dc:1138-1143, and
    /// the Settings group whose rows are showing). The resting and focused values are the outlined
    /// action button's (Pass 9); every button that draws its own focus reads the focused state from
    /// here, so one place sets it. A row's resting fill stays its own where it sits on a half-tone.
    enum FocusLabel {
        static let restingInk = neutral200
        static let restingFill = Color.clear
        static let restingRing = neutral700
        static let focusedInk = text
        static let focusedFill = accent.opacity(0.18)
        static let focusedRing = accent
        static let activeInk = accent200
        static let activeFill = accent.opacity(0.14)
        static let activeRing = accent700
    }

    /// Pass 136: one named text-style set over the sizes above (REA report §3.4, §5.1 item 13).
    /// The views built from this pass on read a style by name; the screens built before it keep
    /// their size constants, which are the same numbers.
    enum TextStyle {
        case title, subtitle, meta, body, cellTitle, cellSubtitle, cellMeta, button

        var size: CGFloat {
            switch self {
            case .title: return TextSize.screenTitle
            case .subtitle, .cellSubtitle: return TextSize.secondary
            case .meta, .cellMeta: return TextSize.floor
            case .body, .button: return TextSize.body
            case .cellTitle: return TextSize.cardTitle
            }
        }

        var weight: Font.Weight {
            switch self {
            case .title, .cellTitle: return .medium
            case .subtitle, .meta, .body, .cellSubtitle, .cellMeta, .button: return .regular
            }
        }
    }

    /// --shadow-sm is a 1 px hairline of neutral-800
    static let hairline = neutral800
}

extension Color {
    /// A colour from a 24-bit RGB hex value (sRGB).
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour from a CSS hex string such as "#1b4b8f" (the server's `logoBg`).
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(hex: value)
    }
}

extension Font {
    /// The system font (owner decision: San Francisco, no bundled fonts) at a design size and weight.
    /// Design weight 300 = .light, 400 = .regular, 500 = .medium, 600 = .semibold.
    static func nocturne(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Pass 136: the same font by the name of its style.
    static func nocturne(_ style: Nocturne.TextStyle) -> Font {
        nocturne(style.size, style.weight)
    }
}
