# Pass 14 — push Pass 13, then the NOAA radar source — 2026-09-06

Pass 13 is on `origin main`. The radar has a real source and **real NOAA radar draws on the
Apple TV** — proven with a full-viewport storm system, not a coloured stand-in.

One thing is smaller than it was meant to be, and it is stated up front rather than buried:
**the radar shows one live frame, not an animation.** NOAA has the history — about two hours,
eighteen scans — and the app reads it correctly: with six frames every frame time comes back
right and every tile downloads (215 requested, 215 loaded, 0 failed). What fails is drawing.
Pass 13's loop stacks one tile overlay per frame and reveals one by setting
`MKOverlayRenderer.alpha`, and on the device MapKit does not repaint a tile renderer whose
alpha goes 0 → 1. That is a defect in Pass 13's code, which this pass was told not to rebuild,
so it is Open Question 1 with the evidence attached, and `frameCount` is 1 with the reason in
the source.

---

## 1. Pass 13 pushed (step 1)

`71b88d3` went to `origin main` as a fast-forward. Verified three independent ways **after**
a fresh `git fetch`, not from the push command's own output:

```
$ git fetch origin
$ git rev-parse HEAD          71b88d34088851669905113b03714c070afb566b
$ git rev-parse origin/main   71b88d34088851669905113b03714c070afb566b
$ git ls-remote origin main   71b88d34088851669905113b03714c070afb566b   refs/heads/main
$ git rev-list --left-right --count origin/main...HEAD
  behind 0   ahead 0
```

The push printed `265ccc1..71b88d3  main -> main` — two dots, no leading `+`, so it was a
fast-forward. `git reflog show origin/main` records it as `update by push` on top of
`265ccc1`. **Nothing was force-pushed.**

---

## 2. The NOAA endpoint (step 2)

Read-only, before any code was written. Everything below was fetched this pass; the URLs are
given so it can be checked.

### 2.1 The service

```
https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/
    radar_base_reflectivity_time/ImageServer
```

Read from `?f=pjson`, quoted verbatim from the service's own metadata:

> "The Radar Base Reflective Time Imagery Service consists of data from Multi-Radar/MULTI-Sensor
> System (MRMS). It provides weather radar information for all the composite Weather Service
> Doppler Radars (WSR 88-D). This image service has a four-hour moving time slider window. It
> has data for the Continental United States, Alaska, The Caribbean, Guam, and Hawaii… Update
> Frequency: Every 5 minutes… This service is time-enabled, meaning clients can submit image
> requests including a time parameter specified in epoch time format (milliseconds since 00:00
> January 1, 1970)… All times are specifed in UTC. If time parameters are omitted, the most
> recent image will be returned."

- `copyrightText` = `"National Oceanic and Atmospheric Administration, NOAA, National Weather Service, NWS"`
- `spatialReference` = `{"wkid": 102100, "latestWkid": 3857}` — **Web Mercator**, the projection
  `MKTileOverlay` is built for (MKTileOverlay.h:13).
- `pixelSizeX` = `pixelSizeY` = `564.774` m — MRMS's own cell size.
- `serviceDataType` = `esriImageServiceDataTypeProcessed`, `currentVersion` 11.3.

### 2.2 The tile scheme: NOAA does **not** publish XYZ tiles

Checked rather than assumed:

| Probe | Result |
|---|---|
| `…/ImageServer/tile/6/24/17` | **HTTP 404**, `text/html` |
| `exportTilesAllowed` in the service metadata | **`false`** |
| a `tileInfo` / `singleFusedMapCache` block | **absent** |
| `opengeo.ncep.noaa.gov/geoserver/gwc/service/wmts` (NCEP's GeoServer WMTS) | **HTTP 403 Forbidden** |
| `radar.weather.gov/ridge/standard/CONUS_0.gif` | HTTP 200, but a single un-georeferenced GIF, not tiles |

What NOAA *does* publish is a **bounding-box** endpoint, `exportImage`, plus an equivalent
time-enabled OGC WMS 1.3.0 (`…/ImageServer/WMSServer?request=GetCapabilities` returns
`<Name>radar_base_reflectivity_time</Name>` and `Dimension name="time" units="ISO8601"`).
Both take a bbox, neither takes z/x/y.

**Consequence for the app:** `MKTileOverlay(urlTemplate:)` cannot express this, because a
template only substitutes `{x}`, `{y}`, `{z}` and `{scale}` and cannot compute a bounding box.
So `NOAARadarTileOverlay` overrides `url(forTilePath:)` — MKTileOverlay's other documented way
of producing a tile URL (MKTileOverlay.h:43) — and converts each tile's z/x/y into that tile's
Web Mercator bbox. The URL it builds, exactly as the Apple TV sends it:

```
https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/
  radar_base_reflectivity_time/ImageServer/exportImage
  ?bbox=-10958012.4,5479006.2,-10801469.3,5635549.2
  &bboxSR=3857&imageSR=3857&size=512,512&format=png32&transparent=true
  &time=1788733698000&f=image
```

That is standard spherical-mercator XYZ (not TMS): `y` counts down from the north, tile span is
`40075016.686 / 2^z`, and no `geometryFlipped` is needed.

### 2.3 The frame / timestamp mechanism

The service is time-enabled, so `time=<epoch ms>` selects a scan. The frames are **not** guessed
at a fixed cadence — the service's own mosaic catalog is asked which rasters cover this Apple
TV, and their `idp_validtime` values become the frames:

```
…/ImageServer/query?where=1=1&geometry=-8515941.0,4802207.2&geometryType=esriGeometryPoint
  &inSR=3857&spatialRel=esriSpatialRelIntersects&outFields=name,idp_validtime
  &returnGeometry=false&orderByFields=idp_validtime DESC&resultRecordCount=6&f=json
```

The spatial filter is what keeps the app location-agnostic: NOAA runs five separate raster
series — the catalog's `name` prefixes counted by hand this pass were **CONUS 18, ALASKA 17,
CARIB 17, GUAM 17, HAWAII 17** (86 records) — and the query returns whichever series this Apple
TV is standing in. For Fallston it returns CONUS, e.g.
`CONUS_L2_BREF_QCD_20260906_222818`.

**Cadence, measured rather than quoted.** The 18 CONUS records spanned 20:30:16Z → 22:28:18Z
(1 h 58 m) with gaps alternating about 6 and 8 minutes:

```
20:30:16  +366s  +465s  +363s  +483s  +363s  +480s  +343s  +500s  +351s
          +491s  +353s  +485s  +347s  +468s  +380s  +470s  +374s  → 22:28:18
```

So: "every 5 minutes" is NOAA's stated update rate; the observed spacing of published CONUS
scans is nearer 6–8 minutes, and roughly two hours are retained (the description says four).

### 2.4 Rate limit, headers, credential

- **Credential: none.** Every request in this pass was anonymous. No key, no token, no account,
  no `Authorization` header. Nothing of the sort exists in the code or this report.
- **Required header: none observed.** Plain `curl` with its default user agent, and MapKit's own
  tile loader, both succeed. (This is *not* `api.weather.gov`, which does ask for a User-Agent.)
- **Rate limit — reported honestly, because the evidence is mixed.** A web search surfaced the
  claim that NOAA's IDP "restricts individual user access to 120 hits per minute". **I could not
  find that stated on any NOAA page I was able to read** — `weather.gov/gis`,
  `weather.gov/gis/IDP-GISRestMetadata` and `weather.gov/gis/cloudgiswebservices` say nothing
  about limits, and the last only gives contacts (`sdm@noaa.gov` for operational issues,
  `nws.mapservices@noaa.gov` for questions). My own measurement did not hit a limit: **60
  distinct `exportImage` requests in 11 seconds (≈327/min) returned 60 × HTTP 200**, no 429 and
  no 503. So the figure is unverified, and the app is nonetheless built to be economical (§3.2).
- **Caching:** responses carry `cache-control: max-age=43200` and an `ETag`.

### 2.5 Terms

`weather.gov/disclaimer`, quoted:

> "The information on National Weather Service (NWS) Web pages are in the public domain, unless
> specifically noted otherwise, and may be used without charge for any lawful purpose"

> "Permission is not required to display unaltered NWS products which include the NWS name or
> NWS/NOAA visual identifier as part of the original product."

> "NWS is provides such information 'as is,' and NWS disclaims any and all warranties, whether
> express or implied, including (without limitation) any implied warranties of merchantability
> or fitness for a particular purpose."

Public domain, free, no key — and a picture of the weather, not a safety instrument. The radar
chrome credits **"NOAA / NWS MRMS base reflectivity"** beside the frame time.

---

## 3. What was built (steps 3 and 4)

### 3.1 The source

`Marlin DVR TV/RadarSource.swift` was rewritten (79 → 304 lines). It holds everything
NOAA-specific and nothing else:

- `RadarSource.frames(near:)` — the catalog query of §2.3, decoded, ArcGIS's in-body `error`
  object handled, sorted oldest-first.
- `RadarSource.overlay(for:)` — vends the overlay for one frame, so `RadarScreen` never needs to
  know NOAA's URL shape.
- `NOAARadarTileOverlay` — `url(forTilePath:)` builds the `exportImage` URL of §2.2; it asks for
  `tileSize × contentScaleFactor` pixels so a 4K screen gets a crisp tile.
- `WebMercator` — the projection arithmetic, in one place.
- `RadarSourceError` — every failure carries a sentence the view can print.
- `RadarFrame` is now `{ id, time }`, where `id` is NOAA's own raster name and `time` is NOAA's
  own `idp_validtime`. **No frame time in this app is invented.**

### 3.2 The tile scheme chosen, and why

| Setting | Value | Reason |
|---|---|---|
| `tileSize` | **512 × 512** | The same Web Mercator grid one level shallower: identical picture, a quarter of the HTTP requests for the same screen. |
| `maximumZ` | **8** | MRMS's cell is ~565 m; at 512 pt tiles that resolution is reached near z 7. Asking beyond z 8 is upsampling at NOAA's expense. |
| `minimumZ` | 3 | unchanged from Pass 13. |
| `format` | `png32`, `transparent=true` | Measured alternatives on one heavy tile: png32 133,858 B; png8/png24/png 120,977 B. The palette formats save ~10 % and lose the alpha ramp, so they were not worth taking. |

### 3.3 The four lines that changed outside the source

The map, the renderer, the loop and the "no source" message were **not** rebuilt. What changed:

1. `RadarModel.load()` → `load(near:)`, so the catalog can be asked what covers this Apple TV.
2. `RadarScreen`'s `.task` passes its existing `fix` into that call.
3. `Coordinator.sync` builds its overlays with `RadarSource.overlay(for:)` instead of
   `MKTileOverlay(urlTemplate:)` — one line, because NOAA is not a template.
4. Step 4's new failure case, below.

### 3.4 Failure behaviour (step 4)

Pass 13 covered "the frame list failed" and "there are no frames". Wiring in a real network
source opened a third door that Pass 13 could not have hit: **the frame list can succeed and
every tile behind it still fail** — and a bare base map then looks exactly like clear weather,
which is the one thing a radar must never do.

So `NOAARadarTileOverlay` counts requests, successes and failures and keeps the last failure's
words, and `RadarModel` watches those counters every five seconds. If tiles have been attempted
and **none** has loaded, the view prints, over the map:

> **The radar frames are listed but not drawing.**
> NOAA sent the frame list but not one radar tile has loaded — *N* attempts, and the last said:
> *the reason*

The other two messages are unchanged in behaviour but now name NOAA:

- frame list unreachable → "NOAA's radar service could not be reached — …", "NOAA's radar
  service answered HTTP *n*.", or "NOAA's radar service refused the request: *message* (*code*)."
- no frames returned → "NOAA has no radar for this Apple TV's location. The National Weather
  Service's MRMS service covers the United States, Alaska, Hawaii, the Caribbean and Guam; a
  location outside that returns no frames. Nothing is wrong with the app or the network."

Every tile request's URL is also logged once per frame (`[radar] <raster name> tile z/x/y -> <url>`),
and every tile failure is logged.

---

## 4. Evidence — hands-on, on Home Theater

### 4.1 The build under test is the build that was tested

```
$ xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build
** BUILD SUCCEEDED **
```

No errors and no warnings from any file this pass touched. (The one warning in the target is
pre-existing, in `GuideScreen.swift:336`, a file Pass 14 never opened.) Every device run
installed that build first with `xcrun devicectl device install app` and then ran; the final run
at **18:56:36** is the code as committed, after the last source change at 18:56:27.

The harness is the same remote-driven XCUITest as Pass 13 (`WeatherRadarUITests`), pressing the
real Siri Remote.

### 4.2 Real NOAA radar drawing on the Apple TV

`reports/assets/pass14/atv-01-real-noaa-radar-diagnostic-recentre.png` — the whole viewport
filled with a live mesoscale system over Minnesota and Iowa: blue and green returns with yellow
and red cores, correctly georeferenced against Mankato, Sioux Falls, Worthington, Austin and
Waterloo, sitting under the app's own chrome. The status line reads
`6:50 PM · frame 1 of 1 · req 48 ok 23 fail 0 · NOAA / NWS MRMS base reflectivity`.

`atv-02-tile-url-and-counters-diagnostic.png` — the same pipeline earlier, with the **real URL
the Apple TV built** on screen:
`https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/exportImage?bbox=-10958012.4,5479006.2,-10801469.3,5635549.2&bboxSR=3857…`
and the counters `req 211 ok 211 fail 0`.

**These two were taken with a temporary diagnostic**, disclosed here and reverted before the
commit: the map was pointed at 44.0 N, 94.5 W (where the weather was) instead of the Apple TV's
own location, and the tile counters and last URL were drawn on screen. **The tiles in them are
real NOAA tiles** — nothing was generated locally, nothing was simulated. `grep -rn "DIAGNOSTIC"`
over the app sources returns nothing.

### 4.3 The shipping build, at the owner's location

`atv-04-shipping-build-at-home.png` — the committed code, no diagnostics, centred on Fallston:
`Radar   Fallston, MD` … `6:50 PM · frame 1 of 1 · NOAA / NWS MRMS base reflectivity`, with a
small green echo near Old Bridge, New Jersey and clear skies over Maryland.

That blank map is **correct, and was checked rather than assumed**. The frame the app displayed
is `CONUS_L2_BREF_QCD_20260906_225011`, which is exactly NOAA's newest scan at that moment; and
NOAA's own `exportImage` of the same region at the same instant came back at 3,221 bytes — an
almost entirely transparent picture — against 95,067 bytes for CONUS at the same instant
(`noaa-conus-same-instant.png`). The sky over Maryland really was clear.

### 4.4 The loop, and why it ships as one frame

`atv-03-six-frame-loop-draws-nothing-diagnostic.png` — with `frameCount = 6`, eighteen seconds
into the radar: `frame 3 of 6 · req 215 ok 215 fail 0` and **not one pixel of radar drawn**,
over the same Minnesota storm that renders fully at `frameCount = 1`.

What that rules in and out:

- **Not the network.** 215 tiles requested, 215 loaded, 0 failed.
- **Not re-fetching.** The counter barely moved across the whole observation (211 → 215) while
  the loop cycled repeatedly, so MapKit is *not* re-requesting on each alpha change — Pass 13's
  Open Question 3 is answered, and the answer is that the tiles are already in hand.
- **Not timing.** At eighteen seconds, frame 3's tiles had been loaded for many seconds.
- **It is the alpha swap.** MapKit does not repaint an `MKTileOverlayRenderer` whose `alpha`
  goes 0 → 1, even with `setNeedsDisplay()`. Removing the swap entirely — one frame, one overlay
  — makes the whole viewport draw correctly and stay drawn. That is the controlled comparison in
  §4.2 versus §4.4, same place, same service, same code but for `frameCount`.

Repairing it means changing how the visible frame is selected, which is Pass 13's loop, which
step 3 says is "not rebuilt" here. So it is Open Question 1 and `frameCount` is 1.

### 4.5 What I could not prove

- **A working animation.** Never seen. §4.4 is the evidence for why, not a claim that it works.
- **The 120-hits-per-minute limit.** Neither confirmed nor triggered (§2.4). I have not run the
  app long enough, or from enough devices, to know what NOAA does under sustained load.
- **Coverage outside CONUS.** The Alaska, Hawaii, Caribbean and Guam series exist in the catalog
  and the spatial query is written to pick them up, but only the CONUS path has been exercised —
  the Apple TV is in Maryland. The out-of-coverage message has never been seen either.
- **The tile-failure message of §3.4 has never fired**, because no tile has failed. It is
  code-traced, not observed.
- **Remote pan and zoom on the map** remain untested, as in Pass 13; no step asks for them.
- **Two test runs died with "Lost connection to testmanagerd"** while sitting on the radar with
  six frames — both times on that screen, never on any other, and never in Pass 13. I have not
  diagnosed it. It may be the same MapKit trouble as §4.4 or simply load; it is named here rather
  than left out. The single-frame runs since have all passed.
- **WeatherKit is still not enabled**, so the Weather screen behind the radar still shows its
  sandbox error. That is Pass 13's finding and explicitly out of Pass 14's scope; the owner is
  enabling it.

---

## 5. Notebook (step 5)

- `COLD-START.md` "What is built" gained a **Pass 14** paragraph, and the "Radar tiles" entry
  under *Built but blocked on the owner* was replaced by **"The radar loop"** — the source is no
  longer the blocker, the loop is.
- `DECISIONS.md` gained `## 2026-09-06 (Pass 14 — the NOAA radar source)`: the owner's NOAA
  decision, the service and its terms, the fact that NOAA publishes no XYZ tiles and what the app
  does instead, where frame times come from, the verified push, and the one-frame finding.

What happened only.

---

## Open Questions

1. **The loop does not draw, and the fix is in Pass 13's code.** Stacking one tile overlay per
   frame and swapping `MKOverlayRenderer.alpha` does not repaint on the device (§4.4). The
   alternatives Pass 12 §3c listed and this pass did not build: keep a single overlay and
   repoint it (subclass `loadTile`, then `MKTileOverlayRenderer.reloadData()` per step), or
   `exchangeOverlay(_:with:)` / remove-and-add so only the current frame is on the map at all.
   Both mean editing `RadarScreen`'s coordinator. **What breaks without it:** the radar stays a
   single current picture and NOAA's two hours of history go unused. Shall a later pass do it?
2. **Nothing refreshes while the radar is open.** The frame list is read once when the view
   appears. NOAA publishes a new scan every 6–8 minutes, so a radar left on screen goes stale
   silently. No step named refresh, so none was built. On a timer, or on re-entry?
3. **The rate limit is unverified** (§2.4). Worth settling before any loop work multiplies the
   request count by the frame count.
4. **Requesting a frame's exact `idp_validtime` occasionally returns the neighbouring scan.**
   Measured: over six frames, one adjacent pair came back byte-identical, and nudging the
   request by +1 s shifted every frame by one instead of fixing it — the instant-to-raster
   mapping at interval boundaries is the service's business, not something to reverse-engineer.
   Harmless today (one frame), but it would show as a stuttered step in a working loop.
5. **`maximumZ` is 8**, so zooming past the data's own resolution shows upsampled pixels rather
   than refusing to zoom. Fine, or should the map's `cameraZoomRange` be clamped to match?
6. **Base reflectivity only.** NOAA's IDP publishes other layers on the same host — precipitation
   type, echo tops, storm-total accumulation, warnings polygons. None was built; none was asked
   for.
7. **The tile URL log** (`[radar] … -> <url>`) prints once per frame. Useful now; worth quietening
   before this is anything other than a debug build.

---

## SCOPE CHECK

| File | Created / touched / read | Step that required it |
|---|---|---|
| *(git)* `origin main` ← `71b88d3` | **pushed**, verified by fetch + `rev-parse` + `ls-remote` | 1 |
| `Marlin DVR TV/RadarSource.swift` (304) | **rewritten** — the NOAA service, the frame query, the tile overlay, the projection maths | 2, 3, 4 |
| `Marlin DVR TV/RadarScreen.swift` | touched — `load(near:)`, the fix passed in, overlays from the source, the tile-failure line | 3, 4 |
| `Marlin DVR TVUITests/WeatherRadarUITests.swift` | touched — dwell time on the radar, so network tiles have time to arrive | 4 (evidence) |
| `COLD-START.md` | touched — Pass 14 paragraph; the blocked-item now names the loop, not the source | 5 |
| `DECISIONS.md` | touched — `## 2026-09-06 (Pass 14 — the NOAA radar source)` | 5 |
| `reports/2026-09-06-pass14-noaa-radar.md` | **created** — this file | 6 |
| `reports/assets/pass14/*.png` (5 files) | **created** — 4 device screenshots + NOAA's own CONUS image | 6 |
| `mapservices.weather.noaa.gov` (`?f=pjson`, `/query`, `/exportImage`, `/WMSServer`) | **read only**, over the internet | 2 |
| `opengeo.ncep.noaa.gov`, `radar.weather.gov`, `weather.gov/gis`, `weather.gov/disclaimer` | **read only** — checked and ruled out, or terms | 2 |
| `COLD-START.md`, `DECISIONS.md`, `reports/2026-09-06-pass13-weather-radar.md` | read first, before anything else | preamble |
| `build/`, `<session scratchpad>` | build output and working images, **git-ignored / outside the repo** | 4 |

**Not created, not changed, not installed:** no second tile source, no provider fallback, no
offline tile cache, no new dependency or package, no entitlement or capability, no WeatherKit or
Weather-screen data-path change, no bundle-id or build-setting change, no ATS change, no change
to `design/`, to the parked Radio and Settings screens, or to any screen built in Passes 5–13.
Nothing outside `~/Xcode/Marlin DVR TV` was written, and no folder under `~/Xcode` other than
this one was read — the Pass 13 exception for the iPhone weather app was not used again.
**No request was sent to 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share**
beyond the app's usual DVR client ping.

**Temporary diagnostics, all reverted before the commit:** the map re-centred on 44.0 N 94.5 W;
the tile counters and last URL drawn on screen; `frameCount` briefly 6 and 1 while the loop was
being diagnosed. `grep -rn "DIAGNOSTIC"` over `Marlin DVR TV/` returns nothing. No tile was ever
generated locally — every pixel of radar in every screenshot came from NOAA.

**Secret scan before commit.** Every file this pass adds or changes was grepped for `token`,
`secret`, `password`, `bearer`, `api[-_]key`, `apikey`, `ssh-rsa`, `BEGIN … PRIVATE KEY`, the
Apple team identifier pattern and the device UDID. **No matches.** The NOAA service takes no
credential, so there is none to leak.

## Push gate

Step 1's push is done and verified. Steps 2–6 are committed locally and **not pushed**, per the
pass's gate. The owner tests on Home Theater.
