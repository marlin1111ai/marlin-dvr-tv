//
//  RadarSource.swift
//  Marlin DVR TV
//
//  Pass 13 step 1: where the radar tiles come from.
//
//  The owner's decision was "tile source: whatever step 1 finds". Step 1 read the owner's
//  iPhone weather app, `~/Xcode/Marlin Weather`, read-only, and **found no radar tile source
//  at all**. That project's Maps tab is a placeholder and always has been:
//
//    Marlin Weather/MapsView.swift:5-7
//      "Phase 2: reserved tab. Future radar / precipitation maps. Per the design,
//       this stays in the tab bar but shows a 'Coming soon' empty state to read
//       as a reserved, future feature."
//    Marlin Weather/MapsView.swift:19-33 — an SF Symbol, "Radar & Maps", a subtitle
//      ("Live precipitation radar and storm tracking are coming to Marlin Weather soon.")
//      and a "Coming soon" pill. No map, no tiles, no request.
//    design_handoff_marlin_weather/README.md:117 — the design says the same:
//      "Purpose: Future radar / precipitation maps. Keep the tab in the bar but show an
//       empty state … and a 'Coming soon' pill."
//
//  The only outbound hosts in that whole project are Apple WeatherKit and the owner's own
//  WeatherFlow Tempest station (`https://swd.weatherflow.com/swd/rest`,
//  Tempest/TempestProvider.swift:19 and Forecast/TempestForecastProvider.swift:18). Tempest
//  is a personal-access-token API for a backyard sensor, not a radar tile service, and its
//  token is a credential — so it is not a candidate here and no credential of any kind was
//  read into, or written into, this project.
//
//  Pass 13's scope lock forbids picking a provider of its own ("Any second tile source,
//  provider fallback … EXPLICITLY OUT OF SCOPE"), so this file names none. `frames` is the
//  single place a source plugs in: give it a URL template and a frame list and the radar view
//  below runs unchanged. Until the owner names one, `frames` returns nothing and
//  `RadarScreen` says so on screen rather than showing a bare map as if it were working.
//

import Foundation
import MapKit

/// One radar frame: the moment it was captured and the `{z}/{x}/{y}` template that serves it.
struct RadarFrame: Identifiable, Equatable {
    /// The template MKTileOverlay takes, with "{x}", "{y}", "{z}" (and optionally "{scale}")
    /// substituted per tile — MKTileOverlay.h:17.
    let urlTemplate: String
    /// What the frame time line shows. Radar frames are stamped by the provider, never by us.
    let time: Date

    var id: String { urlTemplate }
}

enum RadarSource {
    /// The provider's name for the attribution line, once there is a provider.
    static let attribution: String? = nil

    /// The tile scheme every frame uses. Standard spherical-mercator XYZ (EPSG:3857) is what
    /// MKTileOverlay expects (MKTileOverlay.h:13); a source that ships TMS-flipped tiles
    /// would set `geometryFlipped` instead.
    static let tileSize = CGSize(width: 256, height: 256)
    static let minimumZ = 3
    static let maximumZ = 10

    /// The frames to animate, newest last.
    ///
    /// Empty because step 1 found no source. The failure it produces is the one step 6 asks
    /// for: "If the source is unreachable or returns no frames, the view says so on screen."
    /// A source is added here and nowhere else — `RadarScreen` needs no change.
    static func frames() async throws -> [RadarFrame] {
        []
    }

    /// Why there are no frames, in the owner's words rather than an error code. `nil` once a
    /// source exists — then a genuine failure speaks for itself.
    static let unconfiguredReason: String? = """
        No radar tile source is configured. Pass 13 step 1 read the Marlin Weather project on \
        this Mac and found none — its Maps tab is a "Coming soon" placeholder \
        (MapsView.swift:5-7), and the only services it talks to are Apple WeatherKit and the \
        Tempest station API, neither of which serves radar tiles. Naming a provider was out of \
        scope for this pass, so nothing was chosen here.
        """
}
