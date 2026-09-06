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
struct ServerImage<Fallback: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        if let url = ServerConfig.resolve(path) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: contentMode)
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
struct ChannelLogo: View {
    let channel: MergedChannel
    var size: CGFloat = 82

    var body: some View {
        ServerImage(path: channel.logo) {
            InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: size, fontSize: size * 26 / 82)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style: .continuous))
    }
}
