//
//  Destination.swift
//  Marlin DVR TV
//
//  The nine rail destinations of frame 1b (design data `nav`, dc:1133-1137) and the nine
//  Home tiles of frame 2a (`tiles`, dc:1353-1368), with the design's Phosphor icons mapped
//  to SF Symbols (owner decision: nothing bundled). Favorites, Weather, Radio and Settings
//  are present as drawn and inert until the owner says otherwise (DECISIONS.md).
//

import SwiftUI

enum Destination: String, CaseIterable, Identifiable, Hashable {
    case home, favorites, onNow, guide, onLater, recordings, cameras, weather, radio, settings

    var id: String { rawValue }

    /// Rail order, frame 1b.
    static let railOrder: [Destination] = [.home, .favorites, .onNow, .guide, .onLater, .recordings, .cameras, .weather, .radio]

    /// Home tile order, frame 2a (three rows of three).
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
        case .home: return Nocturne.surface
        }
    }

    /// The screens sweep 2 fills; selecting one opens its placeholder now. The rest are inert.
    var isBuiltNow: Bool {
        switch self {
        case .onNow, .guide, .onLater, .recordings, .cameras: return true
        case .home, .favorites, .weather, .radio, .settings: return false
        }
    }

    /// Sub-line for tiles that are present as drawn but inert (no fabricated numbers).
    var staticTileSubtitle: String? {
        switch self {
        case .favorites: return "Favorite channels"
        case .weather: return "Local weather"
        case .radio: return "Stations"
        case .settings: return "Server, tuners, storage"
        default: return nil
        }
    }
}
