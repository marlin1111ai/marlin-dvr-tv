//
//  ArtView.swift
//  Marlin DVR TV
//
//  Pass 137: the image-aspect contract (REA report §3.3, §5.1 item 4; owner's calls of
//  2026-10-26). Every picture the server hands out is drawn by this view in the shape its source
//  declares, and the fallback chain is the same everywhere: the artwork, then the grey
//  placeholder, then the channel's initials tile when a channel is known.
//
//  What the server sends, read from its source at `674a7a7` (`cmd/marlin-dvr/artwork.go`, the
//  tip on 2026-10-26; the live read was not possible from this Mac this pass): a show's art is
//  the title's TMDB poster (`poster_path`, served at TMDB's `w342` or `w780`, which are 2:3
//  portrait) or a custom URL the Art Picker set; an airing's art is the provider's feed image
//  through `/api/art/feed`, with that same poster as its fallback; a recording's thumb is a
//  frame grab (16:9); a camera's still is 16:9; a channel's logo is the provider's image, of any
//  shape. Nothing it serves is 4:3 and no backdrop route exists, so `placard` is declared for
//  the contract and used by nothing today.
//

import SwiftUI

/// The picture kinds and the shape each is drawn in.
enum ArtKind {
    /// 2:3 — a show's art and an airing's art.
    case poster
    /// 4:3 — declared for the contract; nothing the server sends today is this shape.
    case placard
    /// 16:9 — a recording's frame grab, a camera's still.
    case screencap
    /// Any shape, fitted whole inside a square tile on a light backing — a channel's logo, drawn
    /// the way the Guide's channel cell has drawn it since Pass 86, so a wide logo is never cropped.
    case logo

    /// Width over height; nil for the logo, which is fitted rather than framed.
    var ratio: CGFloat? {
        switch self {
        case .poster: return 2.0 / 3.0
        case .placard: return 4.0 / 3.0
        case .screencap: return 16.0 / 9.0
        case .logo: return nil
        }
    }
}

/// One picture in its declared shape. Give `width` or `height` and the other follows the
/// aspect; give both only where the design fixed the box itself (the Recordings poster card,
/// Pass 47), in which case the picture fills the box and is cropped. `initials` and `logoBg`
/// add the channel's initials tile as the last link of the fallback chain; without them the
/// chain ends at the grey placeholder.
struct ArtView: View {
    let kind: ArtKind
    let path: String?
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var initials: String? = nil
    var logoBg: String? = nil
    var cornerRadius: CGFloat = Nocturne.Radius.sm

    private var size: CGSize {
        switch (width, height, kind.ratio) {
        case let (w?, h?, _): return CGSize(width: w, height: h)
        case let (w?, nil, r?): return CGSize(width: w, height: w / r)
        case let (nil, h?, r?): return CGSize(width: h * r, height: h)
        case let (w?, nil, nil): return CGSize(width: w, height: w)
        case let (nil, h?, nil): return CGSize(width: h, height: h)
        case (nil, nil, _): return CGSize(width: 82, height: 82)
        }
    }

    var body: some View {
        Group {
            if kind == .logo {
                // The loaded logo sits 6 pt inside the tile on the Guide cell's `neutral200`
                // backing; the fallback keeps the whole box, with no backing of its own.
                ServerImage(path: path, contentMode: .fit, inset: 6, backing: Nocturne.neutral200) { fallback }
            } else {
                ServerImage(path: path) { fallback }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// The channel's initials on its `logoBg` colour, filling the box whatever its shape; the
    /// grey placeholder when no channel is known.
    @ViewBuilder
    private var fallback: some View {
        if let initials, let logoBg {
            Rectangle()
                .fill(Color(hexString: logoBg) ?? Nocturne.neutral800)
                .overlay {
                    Text(initials)
                        .font(.nocturne(min(size.width, size.height) * 26 / 82, .semibold))
                        .foregroundStyle(Nocturne.neutral100)
                }
        } else {
            ArtPlaceholder(cornerRadius: cornerRadius)
        }
    }
}
