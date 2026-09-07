# DECISIONS — Marlin DVR TV

## 2026-09-05

- Name: Marlin DVR TV.
- Repo: `marlin1111ai/marlin-dvr-tv`, Public, SSH remote (`git@github.com:marlin1111ai/marlin-dvr-tv.git`).
- Folder: `~/Xcode/Marlin DVR TV`.
- Platform: tvOS + SwiftUI, built in Xcode on the Mac.
- The server repo (`marlin1111ai/marlin-dvr`) is read-only reference via a local clone at `~/Xcode/marlin-dvr-reference` and is never edited from this project.
- Server changes, if ever needed, are raised as decisions for the marlin-dvr project.
- Rules (the same as marlin-dvr): recon before build; scope lock; no installs without owner authorization; separate push gate for code the owner tests; nothing force-pushed ever; no secrets in the repo, logs, or reports.
- Deployment target stays tvOS 18.0. Both Apple TVs run tvOS 26.6 (owner, 2026-09-05).
- Playback: the app plays video via HLS output from the Marlin DVR server (contract: HLS-CLIENT-API.md in marlin-dvr, server 1.1.0). Raised in the marlin-dvr project; built there in Passes 14–19.

## 2026-09-05 (design)

- Approved UI design: design/ ("Marlin DVR TV.dc.html", Claude Design export ATV-DVR.zip, Nocturne design system). Read-only, never edited; this project's screens are built to it.
- Variants chosen by the owner: 1b left rail navigation; 2a tile-grid Home (launcher, no rail on Home); 3a comfortable guide (8 rows, 2-hour window, forward-only from the current half hour); 4a poster 2:3 shelf cards.
- In scope now: Home, On Now, Guide (with the airing sheet: Record Now, Series Pass, Watch live), On Later, Recordings (shelves + show detail), Cameras, Player (states 6a–6h). Designed but future, not to be built until the owner says so: Favorites, Weather (WeatherKit), Radio, Settings.
- Facts of the design the app implements itself: resume position kept per Apple TV; DRM channels hidden from lists; the client name shown in the UI is the name this Apple TV registered under.

## 2026-09-05 (sweep 1)

- Build plan: the four sweeps of the Pass 4 report §4, in that order. Pass 5 is sweep 1 (foundation, rail, Home).
- Type and icons: the system font (San Francisco) at the design's sizes and weights, and SF Symbols mapped to the design's Phosphor icons. Nothing bundled.
- Server base URL: a single constant, http://192.168.1.250:8090 (no Settings screen yet).
- Plain HTTP: the App Transport Security exception is NSAllowsLocalNetworking, verified on the Apple TV in Pass 5. Not NSAllowsArbitraryLoads; if the device refuses the connection that is a stop-and-report, not a switch.
- Client id persists in UserDefaults. The client registers with name = the Apple TV's device name, app = "Marlin DVR TV" + the app version, type = "Apple TV", os = the tvOS version. Ping on every launch; re-register on a 404.
- Future screens (Favorites, Weather, Radio, Settings): tiles and rail entries present as drawn, inert. The Home weather glance is omitted until Weather is built.
- Home greeting name: the fixed string "Marlin".
- Client name: each Apple TV is renamed once by the owner on the server's Clients page; the app shows the name the server holds. No device-name entitlement.

## 2026-09-06 (sweep 2)

- Owner acceptance: sweep 2 tested on Home Theater 2026-09-06, all screens work.
- Guide click behaviour (owner, 2026-09-06): clicking a program that is airing now plays it immediately; the airing sheet opens on click only for programs that have not started. Press-and-hold on a current cell opens the sheet (record/pass). Built in sweep 3 with the Player.
- Live pause in the first minute: AVPlayer will not pause a live HLS stream until its seekable window is ~60 s (Pass 7B). The app handles Select itself while the window is short — pauses and holds the position — and defers to AVPlayer's own handling once the window is long enough. Owner decision 1a.
- Owner acceptance: sweep 3 (Player, incl. Pass 7C live pause) tested on Home Theater 2026-09-06 — live pause from the first second, resume from the pause point, recording resume, camera: all pass.

## 2026-09-06 (sweep 4 + fixes)

- Owner acceptance: Passes 8, 9, 10 and 10B tested on Home Theater 2026-09-06 — all accepted. Pushed together in Pass 11.
- Episode menu (owner, 2026-09-06): Mark unwatched and the recording Favorite flag are dropped. Click and hold an episode offers **Keep** and **Delete**, and nothing else.
- Channel favourites (owner, 2026-09-06): a channel is favourited by click-and-hold on its cell in the Guide's left column (`PUT /api/sources/{id}/lineup/{guid}` with `favorite`). There is no favourite control on the airing sheet.
- "Watch live" appears on the airing sheet only while the programme is airing at the current time. A live session plays what is on now (stream.go:214-218), so the button is meaningless on a future airing.
- When a show already has a series pass, the sheet offers **Edit series pass** instead of "Record the series". Whether a pass exists is read from `GET /api/passes` (matched on seriesId, falling back to title as the server does); the server's 409 is never shown raw.
- Favorites screen is built (owner, 2026-09-06): the rail's Favorites entry lists the server's favourite channels with what is on now, and a click plays the channel live.
- Manage DVR is built and lives in the **bottom slot of the rail** (owner, 2026-09-06): storage, Scheduled Recordings (with Cancel recording and Manage pass), Your Passes (the pass editor), and Trash (Restore per row, Empty Trash behind a confirm). The design's rail carries no settings-area entry of its own — Settings is a Home tile only — so the bottom of the rail is that slot.
- Weather, Radio and Settings stay parked: present as drawn and inert until the owner says otherwise.

## 2026-09-06 (Pass 13 — Weather and radar)

- **Radar is IN**, as an addition to the approved design (owner, 2026-09-06). The design draws no radar and no map anywhere (Pass 12 §1.1); this is a deliberate addition to it.
- **The radar view is built to the app's look, not designed first** — the same route as Manage DVR and Favorites (COLD-START.md, Pass 10: "Neither screen is in the approved design; both are built to the app's look").
- **The daily list is 5 rows** — the count the design ships (`wxDaily`, dc:1390-1394) — not the render hint's 7 (dc:742) and not WeatherKit's 10. This settles Pass 12 Open Question 2.
- **Location: one-shot `requestLocation` with the system prompt, cached after the first grant.** tvOS has no continuous updates (`startUpdatingLocation` is `API_UNAVAILABLE(tvos)`). This settles Pass 12 Open Question 3.
- **Tile source: whatever step 1 finds.** Step 1 read the owner's iPhone weather app and **found none** — its Maps tab is a "Coming soon" placeholder (`Marlin Weather/MapsView.swift:5-7`). The radar view is built and works; it has no source to draw, and says so on screen. A provider is the owner's to name (Pass 13 Open Question 1).
- **WeatherKit is not enabled for `com.marlin1111.MarlinDVRTV`** (Pass 13 step 2, a stop-and-report). The app signs with the team wildcard profile, which carries no `com.apple.developer.weatherkit`, and on the Apple TV every WeatherKit call fails with `xpcConnectionFailed … com.apple.weatherkit.authservice … Sandbox restriction`. Pass 13 was forbidden to add, request or work around the entitlement, and did not. The Weather screen and the Home glance are built and reachable; both print that sentence instead of data until the capability is enabled.
- **The place name is the town and state only** ("Fallston, MD"), read from `CLPlacemark.locality` + `.administrativeArea`. MapKit's tvOS 26 replacement `MKReverseGeocodingRequest` returns the **street address of the house** in its `shortAddress`, which is neither what the design draws nor something to put on a television, so it is not used.

## 2026-09-06 (Pass 14 — the NOAA radar source)

- **Radar tiles come from NOAA / the National Weather Service** (owner, 2026-09-06). Free, no key, no account, public domain. No other provider is evaluated or used. The service is the NWS Integrated Dissemination Program's MRMS base reflectivity image service, `https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer` — WSR-88D composite reflectivity, Web Mercator (EPSG:3857), updated every five minutes, about two hours of history, `copyrightText` "National Oceanic and Atmospheric Administration, NOAA, National Weather Service, NWS".
- **Terms**: weather.gov/disclaimer — "The information on National Weather Service (NWS) Web pages are in the public domain… and may be used without charge for any lawful purpose", and permission is not required to display unaltered NWS products. NWS disclaims all warranties. The radar chrome credits "NOAA / NWS MRMS base reflectivity".
- **NOAA publishes no `{z}/{x}/{y}` tiles for it** — `/tile/z/x/y` answers 404, `exportTilesAllowed` is false, and NCEP's GeoServer WMTS answers 403. What it publishes is a bounding-box endpoint (`exportImage`, plus an equivalent OGC WMS). So the app converts each tile's z/x/y to that tile's Web Mercator bbox in `NOAARadarTileOverlay.url(forTilePath:)`. Everything NOAA-specific lives in `RadarSource.swift`.
- **Frame times are NOAA's, never invented**: the service's mosaic catalog is queried with this Apple TV's position, and the `idp_validtime` of each raster covering it becomes a frame. That also keeps the app location-agnostic — NOAA runs separate series for CONUS, Alaska, Hawaii, the Caribbean and Guam.
- **Pass 13 (71b88d3) was pushed to `origin main`** as approved, verified by fetch, `git rev-parse` and `git ls-remote` all reading the same SHA. Fast-forward; nothing forced.
- **The radar ships as one live frame rather than an animated loop** (Pass 14 finding, not an owner decision to re-open): with six frames the frame list, the times and all the tiles are correct (215 requested, 215 loaded, 0 failed) but MapKit does not repaint an `MKTileOverlayRenderer` whose `alpha` goes 0 → 1, so most frames draw blank. Repairing that means changing Pass 13's loop, which Pass 14's scope forbade. `RadarSource.frameCount` is 1 and carries the reason.

## 2026-09-06 (Pass 15 — radar animation and refresh)

- **The radar animates** (owner, 2026-09-06). Pass 13's loop is fixed rather than left pinned at one frame. The mechanism is attach-and-detach — exactly one frame's `MKTileOverlay` is on the map at a time and a step removes it and adds the next. Three alternatives were tried on the device and none repaints: `alpha` + `setNeedsDisplay()` (Pass 14), `alpha` + `setNeedsDisplayInMapRect:` and `exchangeOverlay:withOverlay:` (both Pass 15). `RadarSource.frameCount` is unpinned; the loop runs over whatever NOAA's catalog holds, measured this pass at 17 scans over 112 minutes.
- **The radar refreshes while the view is open** (owner, 2026-09-06). NOAA's frame list is re-read every **five minutes** — inside the shortest observed gap between scans (355 s, mean 419 s) — so the newest scan reaches the screen within about a minute of publication. The timer starts with the view's load and is cancelled in `stop()`, which the view calls on disappear: nothing polls behind another screen and no timer survives a back out. A refresh that fails leaves the frames already on screen alone.
- **The tile source stays NOAA MRMS** as built in Pass 14. No other provider was evaluated or used.
- **Measured cost, recorded because it is not resolved:** attaching and detaching makes MapKit discard and re-fetch the frame's tiles on every step — **about 2,300 requests a minute** at rest on the radar screen. **NOAA answered HTTP 403 during Pass 15's testing**, and the app showed "NOAA's radar service answered HTTP 403" on screen as it should. An in-memory store of tiles already fetched would remove nearly all of that traffic; it was explicitly out of Pass 15's scope and is Open Question 1 of its report.
- **The "Lost connection to testmanagerd" deaths are the test harness, not the app** (Pass 15 step 2): memory flat at 433 MB with 1.66 GB headroom, zero tile traffic during the loop, no crash report, and five consecutive three-minute runs on the six-frame radar passed — one of them with a second debug session deliberately attached. The Mac reaches the Apple TV over `transportType: localNetwork`; that wireless connection is what drops. Nothing was changed in the app for it.

## 2026-09-06 (Pass 16 — the radar tile cache)

- **Owner acceptance: the animated radar was tested on Home Theater and accepted** (owner, 2026-09-06). `68b05b5` (Pass 14) and `9dcc135` (Pass 15) were pushed to `origin main` together, verified by fetch, `git rev-parse` and `git ls-remote` all reading the same SHA. Fast-forward; nothing forced, rebased or amended.
- **The in-memory tile cache is built** (owner, 2026-09-06), answering Pass 15 Open Question 1. `RadarTileStore` keys tiles by NOAA's own tile URL — which carries the scan's `time=` — so a cached tile is always exactly the tile for the frame being drawn and the store cannot show one scan's weather under another's timestamp. Only successful, non-empty responses are kept, so a failure stays a failure. **Memory only**: no file is written, nothing survives the app, and `RadarModel.stop()` empties it when the view closes. Bounded at 96 MB and trimmed oldest-first; a refresh drops the tiles of scans that have rolled out of NOAA's window.
- **Measured, on the Apple TV**: 432 tiles, **43 MB**, about 2.4 MB per frame across 18 frames; app footprint 497 MB with 1.6 GB headroom. Requests fell from **2,327 a minute** (Pass 15) to **53 a minute** over eight minutes, and to roughly **5 a minute at rest** — the only ongoing traffic being one frame's tiles per five-minute refresh. NOAA answered everything; no 403 and no tile failures in this pass.
- **The frame pace is retuned to 900 ms** with a 2,200 ms hold on the newest frame (owner decision to retune, 2026-09-06). Rendering no longer sets it: with the store, frames come up whole at 550 ms too (twenty-five one-second samples, every one complete). The pace was chosen for the one burst left — the cold first cycle still fetches each frame once, and spreading it lowered the peak from 2,389 to 1,426 requests a minute — and because eighteen scans, about two hours of weather, read better over a seventeen-second cycle.
- **The five-minute refresh was observed firing** for the first time (Pass 15 never saw it): at the five-minute mark the frame list went from 17 to 18, NOAA requests rose by exactly 24 — one frame's tiles — and the newest displayed timestamp advanced.
- **Owner acceptance: Pass 16 tested on Home Theater 2026-09-06 and accepted** — the radar tile store, the 900 ms frame pace and the five-minute refresh. Pushed in Pass 17.
- **The radar tile store dies with the view** (owner, 2026-09-06). Each visit to the radar pays the cold cycle again — about seventeen seconds and roughly 432 tiles — and the store is not kept alive between visits. This settles Pass 16 Open Question 3.

## 2026-09-06 (Pass 19 — the Radio screen)

- **Radio comes off the parked list and is built now** (owner, 2026-09-06). **Settings stays
  parked** — present as drawn and inert, a Home tile only. Radio's rail entry and Home tile,
  drawn and inert since Pass 5, are live: `Destination.radio.isBuiltNow` is `true` and
  `ScreenShell` routes it to `RadioScreen`.
- **The station tile is built to the app's look, not designed first** (owner, 2026-09-06) — the
  same route the radar, Manage DVR and Favorites took. **A tile carries the server's cached icon
  and the station name, and nothing else.** The design's frequency string, genre, bitrate,
  track/artist line and favourite star are **dropped**: the server has no data for any of them
  (Pass 18 §3.6 — of the eleven values frame 5g draws, `/api/radio` supplies three). The icon takes
  the 76 px square the design gave to a frequency string, which is the one field the server is
  generous with and the design had nowhere to put.
- **The now-playing bar is kept**, carrying the playing station's icon, its name, and a stop
  control (owner, 2026-09-06). **Nothing else** — no programme, track, bitrate, frequency,
  favourite star or volume slider. The one addition is that a station which will not play says so
  there, naming the failure, because silence presented as playing is not allowed.
- **Leaving the Radio screen stops the stream** (owner, 2026-09-06). Radio does **not** continue
  behind other screens and does **not** survive the screen dimming: it has the same lifetime as
  every other player in the app. `RadioScreen.onDisappear` and its Menu handler call
  `RadioPlayer.stop()`, and so does `UIApplication.didEnterBackgroundNotification`. **No
  `AVAudioSession` category and no `UIBackgroundModes` entry** were added, so nothing in the build
  could let audio outlive the foreground. This overrides the design's footer line, which says
  playback continues with the screen dimmed and that Menu returns to the rail without stopping the
  stream (`dc:844`, `dc:767`).
- **`format` is ignored entirely** (owner, 2026-09-06). The contract calls it "a hint only"
  (`HLS-CLIENT-API.md:297`) and it is the **empty string on both** of the owner's stations. It is
  never drawn, and above all it is never handed to AVFoundation: **no MIME option of any kind is
  passed**, in particular not `AVURLAssetOverrideMIMETypeKey`, whose header states that a supplied
  type is the only one considered and that the server-provided MIME type and the path extension are
  ignored (`AVAsset.h:550-552`). AVFoundation reads the type off the wire.
- **The app is read-only against `/api/radio`.** No station is added, edited, reordered or deleted
  from the Apple TV, and the list is rendered **in the server's order** with no sort anywhere
  (`:302`).
- **AVPlayer follows the StreamTheWorld 302** (Pass 19 step 6a, measured on the Apple TV — the
  first time anyone measured AVPlayer rather than curl). The redirector answers `302 Found` with a
  **zero-byte body**; AVPlayer decoded 28.6 s of audio from that URL, which can only have come from
  the CDN the `Location` header names.
- **tvOS plays the `.aac` mount** (Pass 19 step 6b, measured on the Apple TV). This was the open
  unknown — the AAC mount is the first station in the owner's list and the server project's Pass 32
  never reached one even with curl. AVFoundation reported the decoded track as `'aac ' 22050 Hz
  1 ch` for WBAL NewsRadio 1090 and `'.mp3' 22050 Hz 1 ch` for WCBM Talk Radio 680. **Both stations
  play.**
- **No ATS change was needed and none was made.** Both stations are `https://` on a public host,
  which ATS permits by default, and the icons come from the DVR's own IP, which the existing
  `NSAllowsLocalNetworking` exception already covers. `Info.plist` is untouched. The rule for a
  plain-`http://` station is still open (Pass 18 Open Question 3).
