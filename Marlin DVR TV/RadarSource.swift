//
//  RadarSource.swift
//  Marlin DVR TV
//
//  Pass 14: the radar tiles come from NOAA — the National Weather Service's Integrated
//  Dissemination Program GIS service (owner decision, 2026-09-06). Free, no key, no account,
//  public domain. Pass 13 left `frames()` empty because it had no source; this is that source,
//  and it is the only one. The map, the renderer, the loop and the on-screen failure message
//  were all built in Pass 13 and are not rebuilt here.
//
//  The service
//  -----------
//  https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/
//      radar_base_reflectivity_time/ImageServer
//
//  NWS's own words, read from `?f=pjson` this pass: "The Radar Base Reflective Time Imagery
//  Service consists of data from Multi-Radar/MULTI-Sensor System (MRMS). It provides weather
//  radar information for all the composite Weather Service Doppler Radars (WSR 88-D)… Update
//  Frequency: Every 5 minutes… This service is time-enabled, meaning clients can submit image
//  requests including a time parameter specified in epoch time format." `copyrightText` is
//  "National Oceanic and Atmospheric Administration, NOAA, National Weather Service, NWS" and
//  `spatialReference` is `{"wkid": 102100, "latestWkid": 3857}` — Web Mercator, the projection
//  MKTileOverlay wants (MKTileOverlay.h:13).
//
//  Why the tiles are built rather than templated
//  ---------------------------------------------
//  NOAA does **not** publish this as `{z}/{x}/{y}` tiles. `/tile/6/24/17` answers 404,
//  `exportTilesAllowed` is `false`, and the service carries no `tileInfo`; NCEP's GeoServer
//  WMTS (`opengeo.ncep.noaa.gov/geoserver/gwc/service/wmts`) answers 403 Forbidden. What NOAA
//  does publish is a bounding-box image endpoint — `exportImage`, and an equivalent OGC WMS.
//  So `MKTileOverlay(urlTemplate:)` cannot express it, and `NOAARadarTileOverlay` below
//  converts each tile's z/x/y into the Web Mercator bounding box of that tile and asks for
//  exactly that picture. Everything NOAA-specific lives in this file.
//
//  Terms
//  -----
//  weather.gov/disclaimer: "The information on National Weather Service (NWS) Web pages are in
//  the public domain, unless specifically noted otherwise, and may be used without charge for
//  any lawful purpose", and "Permission is not required to display unaltered NWS products
//  which include the NWS name or NWS/NOAA visual identifier as part of the original product."
//  The same page disclaims all warranties and any fitness for a particular purpose — this is
//  a picture of the weather, not a safety instrument.
//

import CoreLocation
import Foundation
import MapKit

/// One radar frame: a real MRMS scan, identified by NOAA's own raster name and stamped with
/// NOAA's own valid time. Frame times are never invented here.
nonisolated struct RadarFrame: Identifiable, Equatable {
    /// NOAA's raster name, e.g. "CONUS_L2_BREF_QCD_20260906_222818". Stable, and the thing the
    /// map's overlay list is diffed on.
    let id: String
    /// `idp_validtime` — when the scan is valid, which is what the frame-time line shows.
    let time: Date
}

/// What went wrong, in a sentence the radar view can print. Step 4: never a silent failure and
/// never an empty map presented as working.
nonisolated struct RadarSourceError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

nonisolated enum RadarSource {
    // MARK: The service

    private static let imageServer =
        "https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer"

    /// Shown beside the frame time. NWS asks that its products not be passed off as anything
    /// else; naming the source is both the courtesy and the accuracy.
    static let attribution: String? = "NOAA / NWS MRMS base reflectivity"

    // MARK: The tile scheme

    /// 512 pt tiles rather than MapKit's default 256. The picture is identical — the same
    /// Web Mercator grid, one level shallower — but it is a quarter of the HTTP requests for
    /// the same screen, which matters when every frame of the loop is its own set of requests
    /// against a public service (§"Rate limit" in the Pass 14 report).
    static let tileSize = CGSize(width: 512, height: 512)
    /// MRMS's own cell is about 565 m (`pixelSizeX` = 564.774 in the service description).
    /// At 512 pt tiles that resolution is reached around z 7, so z 8 is already finer than the
    /// data; asking for more would be upsampling at NOAA's expense.
    static let minimumZ = 3
    static let maximumZ = 8

    /// How many frames to ask for.
    ///
    /// **One**, and the reason is a defect this pass found rather than a limit of NOAA's.
    /// NOAA has plenty of history — the mosaic catalog offers about two hours, eighteen MRMS
    /// scans, six to eight minutes apart — and asking for six of them works: all six frame
    /// times come back, the loop steps through them and their tiles all download (measured on
    /// the Apple TV: 215 tiles requested, 215 loaded, 0 failed). What does **not** happen is
    /// drawing. Pass 13's loop stacks one tile overlay per frame and shows one by setting
    /// `MKOverlayRenderer.alpha`, and on the device MapKit does not repaint a tile renderer
    /// whose alpha goes 0 → 1: most frames render blank, one renders a stale fragment. With a
    /// single frame there is no alpha swap and the whole viewport draws correctly.
    ///
    /// So this ships the newest scan as one live layer, which is honest and complete, rather
    /// than an animation that is mostly blank. Repairing the loop means changing how the
    /// visible frame is selected — Pass 13's code, which Pass 14 was told not to rebuild — so
    /// it is Open Question 1 of the Pass 14 report, with the evidence.
    static let frameCount = 1

    // MARK: The frames

    /// The most recent MRMS scans covering this Apple TV, oldest first.
    ///
    /// The times are not guessed at a fixed cadence: the service's mosaic catalog is asked
    /// which rasters actually cover this point, and their own `idp_validtime` values become the
    /// frames. The spatial filter is what keeps this location-agnostic — NOAA publishes
    /// separate raster series for CONUS, Alaska, Hawaii, the Caribbean and Guam, and the query
    /// returns whichever one this Apple TV is standing in.
    static func frames(near coordinate: CLLocationCoordinate2D) async throws -> [RadarFrame] {
        let point = WebMercator.point(coordinate)
        var components = URLComponents(string: imageServer + "/query")!
        components.queryItems = [
            .init(name: "where", value: "1=1"),
            .init(name: "geometry", value: String(format: "%.1f,%.1f", point.x, point.y)),
            .init(name: "geometryType", value: "esriGeometryPoint"),
            .init(name: "inSR", value: "3857"),
            .init(name: "spatialRel", value: "esriSpatialRelIntersects"),
            .init(name: "outFields", value: "name,idp_validtime"),
            .init(name: "returnGeometry", value: "false"),
            .init(name: "orderByFields", value: "idp_validtime DESC"),
            .init(name: "resultRecordCount", value: String(frameCount)),
            .init(name: "f", value: "json"),
        ]
        guard let url = components.url else {
            throw RadarSourceError("The NOAA radar catalog address could not be built.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw RadarSourceError("NOAA's radar service could not be reached — \(error.localizedDescription)")
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RadarSourceError("NOAA's radar service answered HTTP \(http.statusCode).")
        }

        let decoded: CatalogResponse
        do {
            decoded = try JSONDecoder().decode(CatalogResponse.self, from: data)
        } catch {
            throw RadarSourceError("NOAA's radar service sent something this app could not read.")
        }
        // ArcGIS reports its own errors inside a 200 response.
        if let error = decoded.error {
            throw RadarSourceError("NOAA's radar service refused the request: \(error.message) (\(error.code)).")
        }

        return decoded.features
            .compactMap { feature -> RadarFrame? in
                let attributes = feature.attributes
                guard let name = attributes.name, let milliseconds = attributes.idp_validtime else { return nil }
                return RadarFrame(id: name, time: Date(timeIntervalSince1970: Double(milliseconds) / 1000))
            }
            .sorted { $0.time < $1.time }   // the catalog is newest-first; the loop runs forwards
    }

    /// Printed when the query succeeds but NOAA has nothing here — the honest reading of an
    /// empty answer, since the service covers the United States and its territories and
    /// nowhere else.
    static let unconfiguredReason: String? = """
        NOAA has no radar for this Apple TV's location. The National Weather Service's MRMS \
        service covers the United States, Alaska, Hawaii, the Caribbean and Guam; a location \
        outside that returns no frames. Nothing is wrong with the app or the network.
        """

    /// The overlay that draws one frame. `RadarScreen` asks for this rather than building an
    /// `MKTileOverlay` itself, so the NOAA-specific URL shape stays in this file.
    static func overlay(for frame: RadarFrame) -> MKTileOverlay {
        let overlay = NOAARadarTileOverlay(frame: frame, imageServer: imageServer)
        overlay.tileSize = tileSize
        overlay.minimumZ = minimumZ
        overlay.maximumZ = maximumZ
        // Radar sits on top of the base map, which stays visible underneath.
        overlay.canReplaceMapContent = false
        return overlay
    }

    // MARK: The catalog's shape

    private struct CatalogResponse: Decodable {
        struct Feature: Decodable { let attributes: Attributes }
        struct Attributes: Decodable {
            let name: String?
            let idp_validtime: Int64?
        }
        struct ServiceError: Decodable {
            let code: Int
            let message: String
        }
        var features: [Feature] = []
        var error: ServiceError?
    }
}

/// Turns MapKit's z/x/y into the one thing NOAA serves: a picture of a bounding box.
///
/// `url(forTilePath:)` is MKTileOverlay's documented hook for exactly this — the class's own
/// header describes the URL-template initialiser as one way to build a tile URL, and this
/// override as the other (MKTileOverlay.h:43). Nothing else about the overlay changes, so the
/// renderer, the loop and the alpha swap of Pass 13 all still apply.
nonisolated final class NOAARadarTileOverlay: MKTileOverlay {
    let frame: RadarFrame
    private let imageServer: String

    /// Counted so the view can tell "NOAA is quiet today" (no echoes) apart from "no tile ever
    /// arrived" (step 4). Read on the main actor by `RadarModel`.
    nonisolated(unsafe) static var tilesRequested = 0
    nonisolated(unsafe) static var tilesLoaded = 0
    nonisolated(unsafe) static var tilesFailed = 0
    nonisolated(unsafe) static var lastFailure: String?

    static func resetCounters() {
        tilesRequested = 0
        tilesLoaded = 0
        tilesFailed = 0
        lastFailure = nil
    }

    init(frame: RadarFrame, imageServer: String) {
        self.frame = frame
        self.imageServer = imageServer
        super.init(urlTemplate: nil)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let box = WebMercator.tileBounds(z: path.z, x: path.x, y: path.y)
        // The tile is drawn at the screen's scale, so ask NOAA for that many pixels rather than
        // stretching a smaller picture.
        let pixels = Int(tileSize.width * max(path.contentScaleFactor, 1))
        var components = URLComponents(string: imageServer + "/exportImage")!
        components.queryItems = [
            .init(name: "bbox", value: String(format: "%.1f,%.1f,%.1f,%.1f", box.minX, box.minY, box.maxX, box.maxY)),
            .init(name: "bboxSR", value: "3857"),
            .init(name: "imageSR", value: "3857"),
            .init(name: "size", value: "\(pixels),\(pixels)"),
            .init(name: "format", value: "png32"),
            .init(name: "transparent", value: "true"),
            // Epoch milliseconds — the service's documented time parameter. This is NOAA's own
            // valid time for the scan, not a time this app made up.
            .init(name: "time", value: String(Int64(frame.time.timeIntervalSince1970 * 1000))),
            .init(name: "f", value: "image"),
        ]
        return components.url!
    }

    /// Logged once per frame so the console shows the real address this Apple TV asks NOAA
    /// for, rather than a description of it.
    private var hasLoggedURL = false

    /// Only to count, to log the first URL and to keep the last failure's words; the fetch
    /// itself is still MapKit's.
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        Self.tilesRequested += 1
        if !hasLoggedURL {
            hasLoggedURL = true
            print("[radar] \(frame.id) tile z\(path.z) x\(path.x) y\(path.y) -> \(url(forTilePath: path).absoluteString)")
        }
        let frameID = frame.id
        super.loadTile(at: path) { data, error in
            if let error {
                print("[radar] tile failed for \(frameID): \(error.localizedDescription)")
                Self.tilesFailed += 1
                Self.lastFailure = error.localizedDescription
            } else if let data, !data.isEmpty {
                Self.tilesLoaded += 1
            } else {
                Self.tilesFailed += 1
                Self.lastFailure = "NOAA returned an empty tile."
            }
            result(data, error)
        }
    }
}

/// The spherical-mercator arithmetic the tile scheme needs, in one place.
nonisolated enum WebMercator {
    /// Half the world in metres — the edge of the EPSG:3857 square.
    static let extent = 20037508.342789244

    static func point(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        let x = coordinate.longitude * extent / 180
        let clamped = min(max(coordinate.latitude, -85.05112878), 85.05112878)
        let y = log(tan((90 + clamped) * .pi / 360)) / (.pi / 180) * extent / 180
        return (x, y)
    }

    /// The bounding box of one XYZ tile, in EPSG:3857 metres. `y` counts down from the north,
    /// which is the standard XYZ (not TMS) convention MKTileOverlay uses.
    static func tileBounds(z: Int, x: Int, y: Int) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let span = (extent * 2) / pow(2, Double(z))
        let minX = -extent + Double(x) * span
        let maxY = extent - Double(y) * span
        return (minX, maxY - span, minX + span, maxY)
    }
}
