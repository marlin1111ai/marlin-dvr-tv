//
//  Destination.swift
//  Marlin DVR TV
//
//  The nine rail destinations of frame 1b (design data `nav`, dc:1133-1137) and the nine
//  Home tiles of frame 2a (`tiles`, dc:1353-1368), with the design's Phosphor icons mapped
//  to SF Symbols (owner decision: nothing bundled). Weather, Radio and Settings are present
//  as drawn and inert until the owner says otherwise (DECISIONS.md); Favorites went live in
//  Pass 10.
//
//  Pass 10B adds a tenth rail entry, `manage`, below the design's nine (owner, 2026-09-06):
//  the design's rail has no settings-area entry of its own — Settings is a Home tile only
//  (dc:1133-1137 lists nine, none of them Settings) — so Manage DVR takes the slot at the
//  bottom of the rail. It is a rail destination only: the Home grid stays exactly as frame
//  2a draws it, so `homeTiles` is unchanged.
//

import SwiftUI

enum Destination: String, CaseIterable, Identifiable, Hashable {
    case home, favorites, onNow, guide, onLater, recordings, cameras, weather, radio, settings, manage

    var id: String { rawValue }

    /// Rail order: frame 1b's nine, then Manage DVR at the bottom (Pass 10B).
    static let railOrder: [Destination] = [.home, .favorites, .onNow, .guide, .onLater, .recordings, .cameras, .weather, .radio, .manage]

    /// Home tile order, frame 2a (three rows of three). Manage DVR is not among them.
    static let homeTiles: [Destination] = [.guide, .onNow, .onLater, .recordings, .cameras, .favorites, .weather, .radio, .settings]

    var label: String {
        switch self {
        case .home: return "Home"
        case .favorites: return "Favorites"
        case .onNow: return "On Now"
        case .guide: return "Guide"
        case .onLater: return "On Later"
        case .recordings: return "Recordings"
        case .cameras: return "Cameras"
        case .weather: return "Weather"
        case .radio: return "Radio"
        case .settings: return "Settings"
        case .manage: return "Manage DVR"
        }
    }

    /// SF Symbol for the rail (design: ph-house, ph-star, ph-television-simple, ph-grid-four,
    /// ph-clock, ph-film-reel, ph-video-camera, ph-cloud-sun, ph-radio).
    var railSymbol: String {
        switch self {
        case .home: return "house"
        case .favorites: return "star"
        case .onNow: return "tv"
        case .guide: return "square.grid.2x2"
        case .onLater: return "clock"
        case .recordings: return "film"
        case .cameras: return "video"
        case .weather: return "cloud.sun"
        case .radio: return "radio"
        case .settings: return "slider.horizontal.3"
        // The settings-area icon, and the one the Pass 10 Recordings row used.
        case .manage: return "slider.horizontal.3"
        }
    }

    /// SF Symbol for the Home tile; the tile for On Now uses ph-play-circle, Settings ph-sliders-horizontal.
    var tileSymbol: String {
        switch self {
        case .onNow: return "play.circle"
        default: return railSymbol
        }
    }

    /// Tile tint from the design data (dc:1354-1362).
    var tileTint: Color {
        switch self {
        case .guide: return Color(hex: 0x2B4C78)
        case .onNow: return Color(hex: 0x4A3F7A)
        case .onLater: return Color(hex: 0x1F5F5C)
        case .recordings: return Color(hex: 0x5A3A6B)
        case .cameras: return Color(hex: 0x7A3F3F)
        case .favorites: return Color(hex: 0x7A6320)
        case .weather: return Color(hex: 0x245C66)
        case .radio: return Color(hex: 0x2F5F36)
        case .settings: return Color(hex: 0x3A3F4A)
        // Neither is a Home tile; the tint is never drawn for them.
        case .home, .manage: return Nocturne.surface
        }
    }

    /// The screens that exist. Favorites went live in Pass 10 and Manage DVR moved into the
    /// rail in Pass 10B; Weather, Radio and Settings are still present as drawn and inert
    /// (DECISIONS.md).
    var isBuiltNow: Bool {
        switch self {
        case .onNow, .guide, .onLater, .recordings, .cameras, .favorites, .manage: return true
        case .home, .weather, .radio, .settings: return false
        }
    }

    /// Sub-line for tiles that are present as drawn but inert (no fabricated numbers).
    var staticTileSubtitle: String? {
        switch self {
        case .weather: return "Local weather"
        case .radio: return "Stations"
        case .settings: return "Server, tuners, storage"
        default: return nil
        }
    }
}
