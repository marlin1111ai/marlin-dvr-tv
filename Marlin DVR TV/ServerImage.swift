//
//  ServerImage.swift
//  Marlin DVR TV
//
//  Images the server hands out as server-relative paths (art, thumbs) or provider URLs
//  (channel logos), resolved against the base URL, with the design's initials tile as the
//  fallback (frame 1b On Now cards, dc:88: a coloured square with the channel initials).
//

import SwiftUI

/// Loads a server image; shows `fallback` while loading, when there is no path, or on failure.
/// Pass 137: `inset` and `backing` dress the loaded picture only — a fitted logo sits inset on a
/// light backing (`ArtView`) — and never the fallback, which keeps the whole box; both default to
/// nothing, so every earlier caller draws as before.
struct ServerImage<Fallback: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    var inset: CGFloat = 0
    var backing: Color? = nil
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        if let url = ServerConfig.resolve(path) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    // Sized by the caller's frame, never by the image (a wide snapshot in fill mode
                    // would otherwise widen its card — seen in Pass 6).
                    Color.clear
                        .overlay { image.resizable().aspectRatio(contentMode: contentMode).padding(inset) }
                        .background(backing ?? .clear)
                        .clipped()
                } else {
                    fallback()
                }
            }
        } else {
            fallback()
        }
    }
}

/// The channel initials on the server's `logoBg` colour (sources.go:118-119); 82 pt in 1b, 62 pt in 3a.
struct InitialsTile: View {
    let initials: String
    let logoBg: String
    var size: CGFloat = 82
    var fontSize: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous)
            .fill(Color(hexString: logoBg) ?? Nocturne.neutral800)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.nocturne(fontSize, .semibold))
                    .foregroundStyle(Nocturne.neutral100)
            }
    }
}

/// A channel's logo from the provider URL, or its initials tile when there is none or it fails.
/// Pass 137: drawn by the image contract's logo kind — fitted whole on a light backing, never
/// cropped (On Now and Favorites; the Player's panel has its own).
struct ChannelLogo: View {
    let channel: MergedChannel
    var size: CGFloat = 82

    var body: some View {
        ArtView(kind: .logo, path: channel.logo, width: size, initials: channel.initials, logoBg: channel.logoBg)
    }
}
