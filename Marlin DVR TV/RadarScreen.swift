//
//  RadarScreen.swift
//  Marlin DVR TV
//
//  Pass 13 step 6: the radar, reachable from the Weather screen. It is not in the approved
//  design — the owner added it in Pass 13 — so it is built to the app's look, the same route
//  Manage DVR and Favorites took (COLD-START.md, Pass 10).
//
//  Why UIKit. SwiftUI's `Map` has no raster-tile content type at all: the tvOS
//  `_MapKit_SwiftUI` interface is 1,128 lines and the string "tile" does not appear in it
//  once (Pass 12 §3b). Raster tiles need `MKTileOverlay` + `MKTileOverlayRenderer` on a UIKit
//  `MKMapView`, hosted here through `UIViewRepresentable` (tvOS 13.0).
//
//  Flat and north-up, because tvOS gives no choice: `rotateEnabled`, `pitchEnabled` and
//  `showsCompass` are all `API_UNAVAILABLE(tvos)` (MKMapView.h:145, :146, :152). They are not
//  referenced below — referencing them would not compile.
//
//  The loop is app code. MapKit on tvOS has no frame-sequence, time-dimension or
//  tile-animation API of any kind (Pass 12 §3c), so every frame is its own overlay and
//  renderer, all added at once so their tiles are already fetched, and the visible one is
//  chosen by setting `MKOverlayRenderer.alpha` — the one primitive that carries no platform
//  restriction (MKOverlayRenderer.h:48).
//
//  With no source configured (RadarSource, step 1) there are no frames, and this screen says
//  so over a plain map rather than presenting an empty map as though it were working.
//

import MapKit
import SwiftUI

@Observable
final class RadarModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// No frames — either no source is configured or the source returned none.
        case noFrames(String)
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var frames: [RadarFrame] = []
    private(set) var index = 0

    private var loopTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    /// NOAA lands a new scan every 355 to 483 seconds (measured this pass, mean 419 s). Five
    /// minutes sits inside the shortest of those gaps, so the newest scan reaches the screen
    /// within about a minute of NOAA publishing it, and it costs one catalog request an
    /// interval — negligible beside the tile traffic. It runs only while the radar is up.
    private static let refreshEvery: Duration = .seconds(300)
    /// The pace, retuned in Pass 16 once the tile store made every frame draw from memory.
    ///
    /// Rendering is no longer what sets it: with the store, frames come up whole at 550 ms —
    /// twenty-five one-second samples at varied phases, every one fully painted, and complete
    /// six seconds into a cold start. What does set it is the one burst left on NOAA. The first
    /// cycle still has to fetch each frame once, about 432 tiles, and cramming that into a
    /// 10-second cycle peaked at 2,389 requests a minute — the same shape of load that drew a
    /// 403 in Pass 15. At 900 ms the same 432 requests spread over about 17 seconds instead.
    ///
    /// It also reads better: eighteen scans is about two hours of weather, and two hours in
    /// seventeen seconds lets the eye follow a storm rather than blink at it. The pause on the
    /// newest frame is kept in proportion so "now" is where the loop rests.
    private static let step: Duration = .milliseconds(900)
    private static let holdOnNewest: Duration = .milliseconds(2200)

    var currentFrame: RadarFrame? {
        frames.indices.contains(index) ? frames[index] : nil
    }

    func load(near coordinate: CLLocationCoordinate2D) async {
        phase = .loading
        NOAARadarTileOverlay.resetCounters()
        startRefreshing(near: coordinate)
        do {
            let found = try await RadarSource.frames(near: coordinate)
            frames = found
            index = max(found.count - 1, 0)
            if found.isEmpty {
                phase = .noFrames(RadarSource.unconfiguredReason ?? "The radar source returned no frames.")
            } else {
                phase = .ready
                startLoop()
                watchTiles()
            }
        } catch {
            frames = []
            phase = .failed("The radar source could not be reached: \(error.localizedDescription)")
        }
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.frames.count > 1 else { return }
                let isNewest = self.index == self.frames.count - 1
                try? await Task.sleep(for: isNewest ? Self.holdOnNewest : Self.step)
                if Task.isCancelled { return }
                self.index = (self.index + 1) % self.frames.count
            }
        }
    }

    /// Re-reads NOAA's frame list while the view is up, so the picture and its timestamp keep
    /// current. `stop()` cancels it and the view calls that on disappear, so nothing polls
    /// behind another screen and no timer outlives a back out.
    private func startRefreshing(near coordinate: CLLocationCoordinate2D) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshEvery)
                guard !Task.isCancelled, let self else { return }
                // A refresh that fails leaves what is already on screen alone: the radar keeps
                // running on the frames it has rather than blanking on a hiccup.
                guard let fresh = try? await RadarSource.frames(near: coordinate),
                      !fresh.isEmpty,
                      fresh.map(\.id) != self.frames.map(\.id) else { continue }
                NOAARadarTileOverlay.store.keepOnly(frames: Set(fresh.map(\.id)))
                self.frames = fresh
                self.index = fresh.count - 1
                self.phase = .ready
                self.startLoop()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        // Nothing outlives the view: backing out of the radar frees every cached tile.
        NOAARadarTileOverlay.store.removeAll()
        tileWatchTask?.cancel()
        tileWatchTask = nil
    }

    // MARK: Tiles that never arrive (step 4)

    /// A frame list can come back fine and every tile behind it still fail — a bare base map
    /// then looks exactly like clear weather, which is the one thing the radar must never do.
    /// This watches the overlay's counters and speaks up when nothing has drawn.
    private(set) var tileTrouble: String?
    private var tileWatchTask: Task<Void, Never>?

    private func watchTiles() {
        tileWatchTask?.cancel()
        tileWatchTask = Task { [weak self] in
            // MapKit asks for tiles as the map lays out; give it a few seconds before judging.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                let loaded = NOAARadarTileOverlay.tilesLoaded
                let failed = NOAARadarTileOverlay.tilesFailed
                if loaded == 0 && failed > 0 {
                    let reason = NOAARadarTileOverlay.lastFailure ?? "the reason was not reported"
                    self.tileTrouble = "NOAA sent the frame list but not one radar tile has loaded — \(failed) attempts, and the last said: \(reason)"
                } else {
                    self.tileTrouble = nil
                }
            }
        }
    }
}

struct RadarScreen: View {
    /// The one-shot fix the Weather screen already has; the map centres on it. Nil means the
    /// owner declined or the fix failed, and this screen says that instead of guessing a place.
    let fix: LocationFix?
    let place: String?
    let onLeave: () -> Void

    @State private var model = RadarModel()
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Nocturne.bg
            if let fix {
                RadarMapView(
                    center: fix.coordinate,
                    frames: model.frames,
                    visibleIndex: model.index
                )
                .ignoresSafeArea()
            }
            LinearGradient(
                colors: [Color.black.opacity(0.72), .clear, Color.black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            overlayChrome
        }
        .task {
            guard let fix else { return }
            await model.load(near: fix.coordinate)
        }
        .onDisappear { model.stop() }
        .onExitCommand { onLeave() }
        // tvOS gives the screen nothing else to focus while the map is the only content;
        // without a focusable item the Menu handler never receives the press.
        .focusable()
        .focused($focused)
        .onAppear { focusSoon { focused = true } }
    }

    private var overlayChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                Text("Radar")
                    .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                    .tracking(-0.01 * Nocturne.TextSize.screenTitle)
                    .foregroundStyle(Nocturne.text)
                if let place {
                    Text(place)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                }
                Spacer(minLength: 20)
                Text("Menu to go back")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            Spacer(minLength: 0)
            status
        }
        .padding(.vertical, Nocturne.Layout.marginVertical)
        .padding(.horizontal, Nocturne.Layout.marginHorizontal)
    }

    /// The frame time when the loop is running (step 6: "with the frame time shown"), and the
    /// plain reason when it is not.
    @ViewBuilder
    private var status: some View {
        switch (fix, model.phase) {
        case (nil, _):
            note(
                "No location, so no radar.",
                detail: "The radar centres on this Apple TV's own location, and it does not have one. Open Weather and allow it, or try again there."
            )
        case (_, .loading):
            note("Loading the radar frames…", detail: nil)
        case (_, .noFrames(let reason)):
            note("No radar frames to show.", detail: reason)
        case (_, .failed(let reason)):
            note("The radar source did not answer.", detail: reason)
        case (_, .ready):
            VStack(alignment: .leading, spacing: 14) {
                if let trouble = model.tileTrouble {
                    note("The radar frames are listed but not drawing.", detail: trouble)
                }
                frameTime
            }
        }
    }

    private var frameTime: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                Text(model.currentFrame.map { TimeFormat.clock($0.time) } ?? "—")
                    .font(.nocturne(Nocturne.TextSize.tileLabel, .medium))
                    .foregroundStyle(Nocturne.text)
                    .monospacedDigit()
                Text("frame \(model.index + 1) of \(model.frames.count)")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                if let credit = RadarSource.attribution {
                    Text("· \(credit)")
                        .font(.nocturne(Nocturne.TextSize.floor))
                        .foregroundStyle(Nocturne.neutral600)
                }
            }
            // A tick per frame, the current one lit — the loop's position at a glance.
            HStack(spacing: 6) {
                ForEach(Array(model.frames.enumerated()), id: \.element.id) { position, _ in
                    Capsule()
                        .fill(position == model.index ? Nocturne.accent : Nocturne.neutral800)
                        .frame(width: position == model.index ? 46 : 26, height: 6)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
        .background(Nocturne.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
    }

    private func note(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                .foregroundStyle(Nocturne.text)
            if let detail {
                Text(detail)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                    .frame(maxWidth: 1240, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 30)
        .background(Nocturne.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
    }
}

// MARK: - The map

/// `MKMapView` in SwiftUI, with one `MKTileOverlay` per radar frame.
struct RadarMapView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    let frames: [RadarFrame]
    let visibleIndex: Int

    /// About 320 km across — a metro area and the weather heading for it.
    private static let span = MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // Muted so the radar reads over it, and no points of interest to compete with.
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        map.preferredConfiguration = configuration
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.showsUserLocation = false
        map.setRegion(MKCoordinateRegion(center: center, span: Self.span), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.sync(frames: frames, on: map)
        context.coordinator.show(index: visibleIndex, on: map)
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        map.removeOverlays(map.overlays)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        /// The overlay per frame, in frame order, and the renderer MapKit made for each.
        private var overlays: [MKTileOverlay] = []
        private var renderers: [ObjectIdentifier: MKTileOverlayRenderer] = [:]
        private var frameIDs: [String] = []
        private var shown = -1
        /// The single overlay currently on the map.
        private var attached: MKTileOverlay?

        /// Builds one overlay per frame but attaches none — `show(index:on:)` attaches exactly
        /// one at a time.
        func sync(frames: [RadarFrame], on map: MKMapView) {
            let ids = frames.map(\.id)
            guard ids != frameIDs else { return }
            frameIDs = ids
            if let attached { map.removeOverlay(attached) }
            attached = nil
            renderers.removeAll()
            shown = -1
            overlays = frames.map(RadarSource.overlay(for:))
        }

        /// The animation: exactly one frame's overlay is on the map, and stepping the loop
        /// swaps it for the next one's.
        ///
        /// Pass 13 stacked all the frames and revealed one by setting `MKOverlayRenderer.alpha`.
        /// That does not repaint on tvOS — proven twice on the device, once with
        /// `setNeedsDisplay()` (Pass 14) and again with `setNeedsDisplayInMapRect:` (Pass 15,
        /// attempt 1): every tile loads, nothing draws. Attaching and detaching is the
        /// mechanism MapKit does honour, because adding an overlay is what makes it ask for a
        /// renderer and draw one.
        func show(index: Int, on map: MKMapView) {
            guard index != shown, overlays.indices.contains(index) else { return }
            shown = index
            let incoming = overlays[index]
            if let attached {
                guard attached !== incoming else { return }
                map.removeOverlay(attached)                      // PASS15 attempt 3
            }
            map.addOverlay(incoming, level: .aboveLabels)
            attached = incoming
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let tiles = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
            renderers[ObjectIdentifier(tiles)] = renderer
            return renderer
        }
    }
}
