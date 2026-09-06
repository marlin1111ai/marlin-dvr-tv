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
}
