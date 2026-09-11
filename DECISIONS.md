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

## 2026-09-06 (Pass 20 — Pass 19 accepted and pushed, and the Home Radio count)

- **Owner acceptance: Radio was tested on Home Theater 2026-09-06 and accepted.** Both stations
  play. The two Pass 19 commits were approved for push and **pushed to `origin main`** —
  `2a3b43b` ("the Radio screen, playing on the Apple TV") and `dc28aec` ("the notebook, and the
  report with the step 6 findings"). Verified by fetching and comparing three independent
  readings: local `HEAD`, `origin/main`, and `git ls-remote origin main`, all
  `dc28aec90f9eeb60fd183cf47b8ca68e8d740c26`. Fast-forward from `3aa6ebe`, which is still an
  ancestor; nothing forced, rebased or amended.
- **The Home Radio tile shows the station count from the server** instead of the static word
  "Stations" (owner, 2026-09-06). Home reads a **sixth endpoint**, `GET /api/radio`, beside the
  five it already read, and the tile draws **"2 stations"**. The number is the endpoint's own
  `count` field (`radio.go:87`), not the length of the array.
- **The wording follows the tiles that were already there**, which was the instruction: the count
  first, then a lowercase noun — "83 channels live", "6 upcoming", "4 favourite channels", "1 of 1
  online". Radio's is "*n* station" / "*n* stations", pluralised the way the Favorites tile
  pluralises. It also matches the design's own sub-line for this tile, "6 stations" (`dc:1361`),
  and the Radio screen's own header. **No other tile was touched.**
- **The fallback is the word "Stations", not a number and not "unavailable"** (owner, 2026-09-06).
  A server that does not answer and a list with nothing in it both leave the tile exactly as it has
  read since Pass 5. This deliberately differs from every other tile, which says "unavailable" when
  its read fails. The count is also **cleared** on those paths rather than left alone: `HomeModel`
  outlives the Home screen, which reloads on every return to it, so a number kept from an earlier
  read could otherwise sit under a server that had since gone away. Nothing stale is ever shown.
- **The tile-subtitle precedence is flipped.** `HomeModel.subtitle(for:)` used to return the static
  line first and consult the loaded one only if there was none, which is why Radio could never show
  a number. A loaded value now wins and the static line is the fallback. Weather and Settings are
  unaffected — they have no loaded value at all.
- **Owner acceptance: Pass 20 was tested on Home Theater 2026-09-06 and accepted** — the Home Radio
  tile showing the station count from the server. Pushed to `origin main` in Pass 21.

## 2026-09-06 (Pass 22 — WeatherKit enabled, and both weather screens populated)

- **The owner registered the explicit App ID.** Description "Marlin DVR TV", bundle id
  `com.marlin1111.MarlinDVRTV`, with **WeatherKit ticked** under App Services. This clears the
  stop-and-report of Pass 13 step 2. Confirmed from Apple's own answer before anything in the
  repo was touched: asked with a scratchpad-only entitlements file and a scratchpad derived-data
  path, Apple returned a new development profile — `tvOS Team Provisioning Profile:
  com.marlin1111.MarlinDVRTV`, `AppIDName` **"Marlin DVR TV"**, application-identifier
  `<team>.com.marlin1111.MarlinDVRTV`, and `com.apple.developer.weatherkit = true`. **Xcode
  cannot have done that**: WeatherKit is `"canRequestFromPortal": false` in Xcode's own portal
  capability table (`DVTPortal.framework/.../DVTPortalCachedPortalCapabilities.json`, entry
  `data[185]`, read by hand this pass), so the capability on that App ID is the owner's doing.
- **The app signs against that App ID, not the team wildcard** (owner, 2026-09-06). Two things
  in the repo make it so and nothing else: a new `Marlin DVR TV.entitlements` at the repo root
  holding the single key `com.apple.developer.weatherkit`, and `CODE_SIGN_ENTITLEMENTS =
  "Marlin DVR TV.entitlements"` in the app target's Debug and Release configurations.
  **`CODE_SIGN_STYLE` stays `Automatic`** — no profile is pinned in the project; automatic
  signing picked the explicit profile by itself once the entitlement existed. The UI-test target
  is untouched and still signs with the wildcard. Bundle id, `TVOS_DEPLOYMENT_TARGET = 18.0`,
  `DEVELOPMENT_TEAM` and `Info.plist` are unchanged, and **no ATS change was needed or made**.
- **WeatherKit answers on the Apple TV.** Pass 13's `xpcConnectionFailed(… "The connection to
  service named com.apple.weatherkit.authservice was invalidated … Sandbox restriction.")` no
  longer appears: zero `[weather]` lines in the device console across the runs of this pass, and
  the screens draw data.
- **Three defects that only content could reveal were found on the device and fixed** (owner's
  rule for this pass: fix what populating reveals, add nothing).
  1. **The current-conditions detail line was cut** — "H 78° · L 61° · humidity 71% · wind 5 mph
     N…". `WeatherScreen`'s current block now carries `.layoutPriority(1)`, so it takes its
     natural width and the alert card is the flexible half of the row, which is what the design
     draws (`flex:1; min-width:0`, dc:721).
  2. **The Weather screen's content never took focus.** The read is shared with Home, so by the
     time the screen opened the model was already `.ready` and `onChange(of: phase)` never fired;
     the remote stayed in the rail and the daily rows could not be reached. The screen now asks
     for the first daily row in `.task` as well, which is where frame 5f draws the ring
     (dc:1402-1403).
  3. **The Home glance read "Apple Apple Weather", and was cut.** `WeatherAttribution.serviceName`
     is already "Apple Weather" and the card prefixed a second "Apple" of its own; the prefix is
     gone. The line still did not fit the 520 pt card, so the text column now takes its width
     before the trailing spacer (`.layoutPriority(1)`) and the glyph's box is the design's 58 pt
     rather than 72 (dc:134). All four lines of frame 2a now render whole.
- **The daily list stays 5 rows** and **the hourly strip 8 columns**, as decided in Pass 13; both
  were counted on the screen this pass.
- **The alert card has still never been drawn with real data** (Pass 22 Open Question 1). No
  alert is in force for this location, and `WeatherKit.WeatherAlert` has no public initializer
  (`SDK: WeatherKit.swiftinterface:1235-1241`), so it cannot be staged with a real value. Its
  *layout* was checked with a disclosed diagnostic that fed the card two strings of WeatherKit's
  own shape; the card wrapped and sat correctly, and **the diagnostic was reverted before
  committing**. Its screenshot is labelled `-diagnostic`.
- **The design's "Now" column does not appear, and that is correct.** `WeatherFormat.hourLabel`
  labels the current hour "Now", but WeatherKit's hourly forecast starts at the top of the hour
  and the screen drops hours more than 30 minutes gone, so between :30 and :59 the first column
  is the next clock hour. Frame 5f draws no "Now" either (its strip is 3 PM → 10 PM, dc:1379-1386),
  so what renders matches the design.
- **The second row of the daily list says "Tomorrow" where the design says a weekday name**
  (dc:1391, "Saturday"). Left as it is: the string comes from `TimeFormat.relativeDay`, which the
  Guide, On Later and Recordings all share, and changing it would change those screens.
- **Owner acceptance: Pass 22 was tested on Home Theater 2026-09-06 and accepted** — WeatherKit
  enabled on the explicit App ID `com.marlin1111.MarlinDVRTV`, the app signing against it instead
  of the team wildcard, and the Weather screen (frame 5f) and the Home glance (frame 2a) both
  drawing real data, with the three defects that populating them revealed fixed. The four Pass 22
  commits — `d4ee05c` (the signing), `9063207` (the three fixes), `6d7d887` (the device harness
  and its screenshots) and `b52c4e4` (the notebook and the report) — were approved for push and
  **pushed to `origin main`** in Pass 23, together with that pass's own notebook commit.
  Fast-forward from `bf5e9ba`, which is still an ancestor; nothing forced, rebased or amended.

## 2026-09-07 (rail focus)

- **Owner decision: the remote comes back to the rail entry that opened the screen you are on.**
  Swipe left from the Guide and the ring is on Guide; from Radio, on Radio — every screen, every
  time, regardless of how the content happens to be laid out. Recorded here because Pass 24 raised
  it as an open question (its Open Question 1) and the owner answered it: restore-to-origin, not
  "the last entry the remote touched". It is also what the approved design already drew — the rail
  data gives the 4 pt accent focus ring to the **active** index and to no other (`railFocused`,
  dc:1144-1149), and the one frame that draws the rail expanded is fed `railFocused(2)` on the
  On Now screen (dc:55, dc:1345).
- **Home stays as it is: no rail, by design** (dc:111). Selecting Home from the rail leaves the
  shell, so there is nothing to come back to. Untouched this pass and asserted on the device.
- **The fix records nothing new.** `ScreenShell.screen` was always the record of which entry opened
  the content; only the restore was missing. It is `ScreenShell.railRestore`, and it fires on the
  crossing from the content into the rail and never again — otherwise Up and Down inside the rail
  would snap back and the rail would be unusable.
- **`focusScope` + `prefersDefaultFocus` was tried first and is not the mechanism.** Built that way,
  put on Home Theater with no other change, it reproduced Pass 24's landings entry for entry: 2 of 9
  right, 7 wrong. The tvOS focus engine does not consult a scope's default-focus preference when the
  remote swipes directionally into it. The code was removed and the measurement is recorded in
  `RailView.swift`'s header so nobody spends another device run on it.
- **Verified on Home Theater with the real Siri Remote** (Pass 25 report §3–§6): all nine
  rail-drawing entries over three rounds, **27 of 27 correct**; Home draws no rail; the On Now (60 s)
  and Cameras (45 s) reloads move focus neither in the rail nor in the content, with each screen's
  own subtitle proving the refresh happened; and one Player round trip returns focus to the same
  card it left and still lands on Cameras.
- **Still open and deliberately untouched**: `ShellFocus.content` remains declared and unused — this
  fix did not need it, since "focus is nil" already means the remote is in the content; Select on the
  rail entry of the screen you are already on still does nothing; and the sub-screens (show detail,
  the Manage DVR sections, the Radar, the airing sheet) were not looked at.

## 2026-09-07 (frame-by-frame)

- **Frame-by-frame stepping is for recordings only. Live is explicitly out** (owner, 2026-09-07).
  It was out of scope from the first recon and stayed out through the fix; `frameStep` declines at
  its first guard unless the item is a recording, so a live channel or a camera never arms. Live was
  never driven on the device across Passes 27–29 — tuning takes a tuner — and is unchanged by diff.
- **Clicks step; swipes keep their fixed skips** (owner, 2026-09-07). Left and right **clicks** move
  one frame while paused on a recording, matching the owner's older DVR app: the discrete press is
  the precise tool. Swipes were never touched and structurally cannot be — a swipe on the touch
  surface is not a `UIPress`, so it never reaches the code that steps. While **playing**, left and
  right stay Apple's skip (measured at +12 s and +13 s throughout Passes 28–29).
- **The step API is ruled out; exact seeks are the mechanism.** `AVPlayerItem.step(byCount:)` is
  inert on this app's HLS recordings — `canStepForward` and `canStepBackward` both false, forty
  calls, zero nanoseconds moved, in copy mode and transcode mode alike (Pass 27, measured on Home
  Theater). A frame is instead a **seek to `currentTime() ± 1/fps` with `toleranceBefore` and
  `toleranceAfter` both `.zero`**; the zero tolerance is what makes AVFoundation land on the adjacent
  frame rather than the nearest keyframe (owner's approach, from his earlier DVR app; proven in
  Pass 28). Pending seeks are cancelled first so a chase seek cannot overwrite one with its own
  tolerance, each step is computed fresh from `currentTime()` so it cannot drift, and play/pause is
  never touched — AVPlayer renders the seek target while paused, so the frame simply appears.
- **The app takes the arrow away from `AVPlayerViewController` while paused on a recording, and
  gives it straight back otherwise** (Pass 29). Claiming the press was not enough: the player handles
  the arrow with its **own gesture recognizers**, which run alongside the responder chain rather than
  in it. The app disables exactly those recognizers — matched on the public `allowedPressTypes`,
  never by class name — and restores precisely the ones it disabled. **The transport bar itself is
  not suppressed**: it still draws, Select is still Apple's, and the arrows return on resume. This
  is a deliberate dependency on another framework's internals, taken knowingly; it fails open, back
  to Apple's skip, rather than crashing.
- **Owner acceptance: Passes 28 and 29 were tested on Home Theater 2026-09-07 and accepted** —
  frame-by-frame works and the 10-second accumulation is gone. Both commits — `58ebb12` (the exact
  seek and the click binding) and `26f7e2b` (the recognizer ownership, and the frame-rate guard that
  only believes real rates) — were approved for push and **pushed to `origin main`** in Pass 30,
  with that pass's own notebook commit. Fast-forward from `a720858`, which is still an ancestor;
  nothing forced, rebased or amended.
- **Known and unfixed, recorded so no later pass mistakes it for proven:** frame stepping goes
  erratic near the end of the prepared range (measured at 1:05:27 of a 1:11:10 recording, clock
  moving backwards; not Apple — every press was the app's). Suspect is the seek-past-the-prepared-range
  restart at `PlayerModel.swift:382`. It is Pass 28 Open Question 3 and wants its own pass. The full
  list is under **KNOWN AND UNFIXED** in COLD-START.md.

## 2026-09-07 (Pass 31 — the Recordings list after a delete)

- **The Recordings shelves re-read the library the moment a write in show detail changes it**
  (owner defect, 2026-09-07). Deleting an episode and pressing Menu used to come back to the
  library as it was read when the screen first opened: `RecordingsModel.load()` had exactly one
  caller, the `.task` at `RecordingsScreen.swift:68`, and that task hangs off the `Group` holding
  both the shelves and show detail, so opening detail never ended it. Leaving Recordings worked
  only because `ScreenShell.swift:51` gives the content `.id(current)` and rebuilds it.
- **The refresh is a re-read of `GET /api/library`, not a local edit of the list.** Episode counts,
  the unwatched badge, which shelf a show sits on and the header's own totals are all the server's,
  and `limit: 6` means one delete can pull a seventh show into view — none of it is derivable from
  the single `episodeView` the delete answers with.
- **It fires while show detail is still on top**, not on the way back, so the shelves are correct on
  their first frame instead of correcting themselves a moment later. The read is ~3 ms on this
  network. It fires for **Keep** as well as Delete: both are writes the server accepts against the
  library those shelves are drawn from.
- **A reload still cannot pull focus out of the rail.** Focus is repaired only when the focused card
  is gone, and the guard takes `focused` as non-nil first — nil means the remote is in the rail.
  This keeps the property Pass 25 measured for the On Now and Cameras timed reloads.
- **Delete is a soft delete on this server, measured rather than assumed** (Pass 31 §3.3).
  `roots[0].files` stayed at 5 across the delete and the recording is in the trash with
  `exists: true`, so the server answered with the episode and not `{ok, deleted}`. **No
  `GET /api/settings` read was made** — the owner did not authorise one this pass, and the Unraid
  host stays on the do-not-touch list.
- **Pass 8 Open Question 11 is overturned.** A show whose last episode is trashed does **not** stay
  in the library index with 0 visible episodes: `shows` went 1 → 0 and all three sections emptied,
  at `limit=6` and `limit=500` alike. The card disappears outright, which is what the owner wanted
  to see.
- **Consequence, found and deliberately not fixed (scope lock):** because the app assembles the
  trash from `GET /api/library`'s show list, a recording trashed as the **last** episode of its show
  is invisible in Manage DVR → Trash and cannot be restored from the Apple TV. The server's web UI
  still holds it. Recorded under KNOWN AND UNFIXED in COLD-START.md.
- **The recording deleted for the test was not restored** (owner, 2026-09-07): "whether it sits in
  trash or is gone entirely is fine either way". `6007a13f0b46`, Hazardous History With Henry
  Winkler S2 E20, 1.86 GB, `trash=true`, still on disk. `POST /api/library/trash/empty` was never
  sent.
- **Committed locally and not pushed** — the owner tests first.

## 2026-09-07 (Pass 32 — Stop recording from the Guide; the trash list blocked)

- **A recording in progress can be stopped from the Guide** (owner request, 2026-09-07). Hold the
  cell and the airing sheet offers **Stop recording**. Until now the only entry point to
  `POST /api/schedule/jobs/{id}/stop` was frame 6g's "Stop the recording and watch", which appears
  only on a tuner-busy 502 during a live start — so a recording started from the Guide could not be
  stopped from it.
- **The button turns on `Job.status == "Recording"`, and on nothing else.** Queued, Skipped and
  Conflict have not started; COMPLETED, STOPPED and FAILED are over. **A pass's airing qualifies
  exactly as a Record Now booking does** — it is deliberately not gated on `passId == "manual"` the
  way the sheet's existing "● Scheduled" chip is.
- **Stop is armed on the first click**, like Manage DVR's Cancel recording: the label becomes "Stop
  recording — click again" and the sheet says "This keeps what has recorded so far and stops the
  rest." Only the second click sends anything. What has not been recorded cannot be recovered.
- **On success the sheet re-reads the schedule rather than editing what it holds** — Pass 31's rule.
  The `?? job` fallback the sheet's other writes use is deliberately absent here: keeping a stale
  `Recording` job would leave a Stop button on a recording that is already over. On this server the
  job stays listed as `STOPPED`, so that nil branch was not exercised.
- **The sheet now re-reads `GET /api/schedule` when it opens, not only when it writes.** The Guide
  refreshes its schedule only when the sheet writes and never on a timer, so a booking that had since
  started recording would still read Queued and Stop would not appear.
- **Proven on Home Theater with the real remote**: *Midday Maryland* on 2.1 booked from the Guide,
  the sheet reopened, armed, confirmed — "Recording stopped · STOPPED · stopped by owner", the button
  gone, and the server reading `rec-mtrfm5v9d1fd63 STOPPED` with a 7.66 MB partial in the library.
- **Item B — the trash list — is a STOP AND REPORT, and nothing was built for it.** The server has
  no trash listing: `GET /api/library/trash`, `/api/trash`, `/api/library/recordings?trash=1` and
  `/api/library/shows` all answer **404**, and `GET /api/library?trash=1` returns bytes identical to
  `GET /api/library`. The only trash-aware read is per show and needs an id the app cannot obtain,
  because a show whose last episode is trashed leaves `GET /api/library` altogether (Pass 31).
  **`ManageDVRScreen.swift` and `TrashManageView.swift` are untouched.**
- **A client-side cache of show ids was considered and rejected**, not merely unbuilt: it would be a
  guess at server state and would miss anything deleted from the web UI or the other Apple TV. Step 5
  forbids working around the missing endpoint.
- **The unblock is a server change, raised for the marlin-dvr project** as the standing rule
  requires: one read, `GET /api/library/trash`, answering the trashed `episodeView`s the way
  `?trash=1` already does per show. With it, item B is a small change to `ManageModel.refreshTrash`.
- **Restore is still wired but never exercised live** — step 7 could not be run, because the episode
  it names cannot be reached from the Apple TV. Unchanged since Pass 10.
- **The reference clone and `HLS-CLIENT-API.md` were not read.** Step 1 asked for them while the same
  prompt put the clone on ABSOLUTE DO-NOT-TOUCH; the do-not-touch list was taken as the stronger
  instruction and the contradiction is reported rather than resolved unilaterally.
- **Left on the server, disclosed:** `midday-maryland` `b7a3822d83b4` (7.66 MB, the step-4
  throwaway) and `the-view` `eccf81dbdab2` (275.92 MB, booked by an aborted first run of the harness
  and left to finish when that run was killed). Neither was deleted — that was not in the steps.
- **Committed locally and not pushed** — the owner tests Passes 31 and 32 together. (Accepted on Home Theater and pushed in Pass 34.)

## 2026-09-07 (pass 33)

- The Trash screen reads `GET /api/library/trash` (marlin-dvr 1.6.0). The show-by-show walk it used
  since Pass 10 is deleted; against 1.6.0 that walk returns nothing at all — **not** because the
  per-show `?trash=1` read stopped surfacing trashed episodes, which it still does
  (`library.go:609`, `:626`, `:659`), but because `GET /api/library` builds its show list with
  `showSummaries(false)`, which skips a trashed recording before it creates that show's entry
  (`library.go:409`), so a show whose recordings are all trashed has no discoverable `showId` for
  the walk to ask about (cause corrected by the marlin-dvr project, 2026-09-08).
- A trashed recording is its own type, `TrashItem` (eight fields), not `Episode` (28). The listing
  carries no `showId`, `file`, `thumb` or server-made label, and cannot: the show may have left the
  library. Decoding is strict on the item so a shape change fails loudly; the `recordings` array is
  taken leniently so a future `null` for empty cannot blank the screen.
- Byte counts the server would otherwise have labelled itself are formatted the server's way —
  `SizeFormat.serverStyle`, 1024-based, two decimals, a copy of its `humanBytes`. The existing
  `SizeFormat.bytes` is 1000-based and disagrees by 7% on a gigabyte; a trash row has no `sizeLabel`
  to fall back on, and the Apple TV must not contradict the web UI about a recording's size.
- **A recording's id changes while it is in the trash** (1.6.0 moves the file to `DVR/Trash/` and the
  id follows the path), and Restore changes it back exactly. Nothing in the app may treat a trash-time
  id as durable. `ResumeStore` keys on the library id and therefore survives a restore.
- Empty Trash keeps the `"empty-trash"` focus id; the empty-state sentence is focusable and holds
  `"empty"`. A screen must always have something focusable, or the remote's Menu leaves the app
  instead of reaching `.onExitCommand`.
- Owner, 2026-09-07: Pass 32's two leftovers (`b7a3822d83b4` Midday Maryland, `eccf81dbdab2` The View)
  are throwaway and may be trashed and restored freely for evidence. That authorisation covers those
  two ids and nothing else.
- The owner emptied his own trash from the web UI at 20:51:50 on 2026-09-07, permanently deleting the
  four recordings this pass was written around. Recorded in COLD-START so no later pass hunts for them.

## 2026-09-07 (pass 34)

- **Passes 31, 32, 32A and 33 accepted by the owner on Home Theater and pushed** — delete refresh,
  Stop recording from the Guide, the trash list off the new server endpoint, and Restore.
  `origin/main` is at `93de296`.
- **The Trash list comes from the server's `GET /api/library/trash` and from nothing else.** This
  settles a choice that was open across Passes 31–33. The two alternatives are both rejected on the
  record, so no later pass reopens them:
  - **A per-show walk** (`GET /api/library/shows/{id}?trash=1` for every show, the Pass 10 design) —
    rejected because it cannot see a recording whose show has left the library, which is most of what
    the trash holds, and because under 1.6.0 the per-show read no longer returns trashed episodes at
    all, so the walk now finds nothing whatever.
  - **Caching show ids the app has seen**, so the walk has something to ask for — rejected as a
    client-side guess at server state. It would miss anything deleted from the web UI or the other
    Apple TV, and it invents a memory the server is the authority for.
- **Empty Trash stays unexercised from the app.** It has been wired since Pass 10 and has never been
  sent from an Apple TV, deliberately: it deletes files on disk permanently, for every client at
  once, and the server offers no confirmation of its own. It keeps its two-click arming and stays out
  of scope until the owner asks for it by name. Restore left this category in Pass 33; Empty Trash
  and stopping a pass's airing have not.
- **Automatic pruning is gone server-side in 1.6.0: a series pass never trashes anything on its own**
  (owner, 2026-09-07). Nothing reaches the trash unless a person put it there. The keep rule in the
  Edit series pass screen no longer causes deletions by itself, and the app must not describe it as
  though it does.
- Raised for the marlin-dvr project, recorded and not acted on: `trashedAt` does not update when the
  same file is trashed twice, and Empty Trash has no confirmation step. Both are in COLD-START under
  "Raised for the marlin-dvr project".


## 2026-09-08 (Pass 38 — commercial skip)

- **Owner acceptance: Pass 38 was tested on Home Theater 2026-09-08 and accepted** — the commercial
  skip prompt works. Pushed to `origin main` in Pass 39 together with Pass 37's recon report and
  the notebook work recording the acceptance.
- **The feature is exactly what the owner settled and nothing more** (owner, 2026-09-08): a
  recording plays, playback reaches the start of a commercial break, a small prompt appears for
  five seconds saying the break can be skipped, SELECT jumps to the end of the break, pressing
  nothing lets the commercial play. **No auto-skip mode, no setting, no toggle, no preference, no
  chapter marks and no timeline shading** were built, proposed or stubbed.
- **The commercials route is `GET /api/library/recordings/{id}/commercials` (contract §10), and
  `GET /api/library/recordings/{id}/segments` is not used.** §10.7 says the older route answers
  `"02:57"` strings that have already lost the two decimals the `.edl` carried, collapses several
  realities onto `"not run"`, and carries no source — so it is the wrong route for a player and
  the owner asked for it to be left exactly as it is.
- **Two decodings deliberately break this app's strict habit, because §10 instructs it.** `edl` is
  optional (`:397`, `omitempty`; §10.5 says its absence is the ordinary case), and **`state` is
  decoded as a `String` and mapped, never as a `Decodable` enum** — §10.3 (`:410`) says to treat
  anything unrecognised as `"unknown"`, and an enum would throw on a fifth value from a future
  server instead. Everything else follows §10.2's table and stays strict.
- **Only `state: "detected"` arms the feature** (owner's step 3, 2026-09-08). A `"none"` from an
  `m3u` source is a **real answer** — no prompt will ever show for that recording, and that is
  correct behaviour, not a failure. A `"none"` from `hdhomerun` is treated like `"unknown"`,
  per §10.6: comskip exits 1 with its clean "Commercials were not found" on the owner's 720p
  antenna recordings, and on a commercial channel that answer is very probably wrong. `""` means
  "source unknown, not antenna" (`:486`) and is not believed either. Everything else — `unknown`,
  `running`, an unrecognised value, a transport failure, any non-200 — shows nothing at all, with
  no user-visible message. **Playback is never blocked, delayed or altered by any of it.**
- **The prompt is not focusable, and the press is claimed instead.** No focusable view has ever
  been placed over a running `AVPlayerViewController` in this app (Pass 37 Open Question 1) and
  Pass 38 was told not to be the first. `PlayerHost.armSelectOwnership` is the exact counterpart of
  Pass 29's `armArrowOwnership`: it disables the player's own Select recognizers — matched on the
  public `allowedPressTypes`, never by class name — for as long as the prompt is up, and restores
  precisely those on dismissal, on a skip, on a pause and in `viewWillDisappear`. **Measured on the
  device at every arming: 5 Select recognizers, 0 of them also arrow recognizers**, and frame
  stepping unchanged at 0.033367 s a click. The two claims are separate and never overlap in time.
- **The prompt is built to the app's look, not designed first** (owner, 2026-09-08) — the same
  route the radar, Manage DVR, Favorites and Radio took. It sits bottom-trailing at the standard
  60 / 80 pt margins, on the Nocturne surface at 86 %, with an accent SELECT capsule. **Its
  position was chosen by this pass, not by the owner**, and it overlaps the right end of Apple's
  transport bar when the transport happens to be on screen.
- **The skip is the existing in-item exact seek, never `restart(at:)`** — that tears the session
  down and shows the Starting screen. Play/pause is not touched, the target is clamped to the
  seekable range the way `frameStep` already clamps, and clamped again against the recording's
  duration so it can never land at or past the end. **The duration is the play session's**, which
  contract §3 (`:134`) states is the whole recording's even for a session started at an offset —
  this closes Pass 37 Open Question 2.
- **`state: "running"` is treated as this playback simply having no segments.** There is no poll
  and no retry: §10.3 (`:422`) warns that an `"unknown"` may never resolve and says "Do not poll it
  forever". One call per playback, from `attach()`, and never again — the ranges are absolute
  recording seconds, so they survive a `restart(at:)`.
- **A resumed recording starts well past its resume point, and it is not this pass's doing.**
  Measured with a disclosed, reverted diagnostic: `start=1680` was at 1988 s by the fourth tick.
  Recordings are an HLS EVENT playlist the server is still writing and AVPlayer joins it near the
  live edge. Recorded under KNOWN AND UNFIXED in COLD-START.md; **not fixed, and no client-side
  compensation was built for it.**
- **Disclosed cost of the evidence:** playing a recording to its end marks it watched and clears
  its resume, and the harness did that while resetting state between runs. *History's Greatest
  Mysteries* S4 E14 is now `watched: true` and **the owner's "35 min in" resume position on it is
  gone**; Storage Wars S4 E19 is watched too. Nothing was deleted, trashed, hidden or scheduled,
  and no `GET /api/settings` was read.


## 2026-09-08 (Pass 42 — the single-file MP4 playback route)

- **Owner acceptance: Pass 42 was tested on Home Theater 2026-09-08 and accepted** — everything
  works, and **the LIVE badge is no longer there** (owner, 2026-09-08). That closes the one claim
  only he could settle. Pushed to `origin main` in Pass 43 together with the notebook work
  recording the acceptance. It also **resolves the ambiguity Pass 42 §4b flagged**: the harness's
  on-screen text dump contained the string `LIVE` while the player was up, and the builder refused
  to interpret it. The owner's own eyes settle it — that string was stale text from the screen
  behind the player, not a badge being drawn.
- **Recordings play through the single-file MP4 route; live TV, cameras and radio keep HLS.**
  A recording is remuxed whole by the server with `-c copy` into one faststart MP4 and served with
  byte ranges, so its full length is seekable from the first second. Live channels and cameras stay
  on HLS, which is the only thing that can carry a growing stream and the time-shift buffer. The
  choice is made at **one line, `PlayRequest.swift:49`**, and reaches the wire at
  **`PlaybackSession.swift:70`**, the app's only `POST /api/play/sessions` site. Radio needs no
  branch: it never creates a play session at all.
- **Where the build plan offered a choice and did not make one, the scope lock made it — not the
  builder.** Pass 41's build-plan step 4 said a response that is not the route asked for "must not
  be treated as a file: **fall back to today's HLS behaviour, or fail loudly**", and picked neither.
  Pass 42's own scope lock listed "fallback to the HLS route" as out of scope and said refused
  recordings are "never silently routed back to HLS unless a step says so"; step 4 offers the
  fallback as an alternative rather than specifying it. **Fail loudly was therefore the only one of
  the two the scope lock permitted, and that is what was built** (`PlayerModel.swift:176-181`).
  It is **a one-branch change if the owner ever wants the other**, and the place for it is that
  function. **The owner has not been asked**, and this decision was taken on the scope lock's
  authority rather than on his preference or the builder's.
- **The long-wait first fetch needed a `URLSession` of its own, and that is why.** Build-plan step 5
  asked for a first fetch with a timeout well above the longest remux. A `URLSessionConfiguration`'s
  `timeoutIntervalForRequest` can override a longer per-request `timeoutInterval`, and
  `PlaybackSessionClient`'s shared session is built with 25 s — which `create`'s POST depends on,
  because it sets no per-request timeout of its own. **Raising the shared value would have changed
  the POST for live channels and cameras too**, so the long wait was given its own configuration
  instead (`PlaybackSession.swift:24`, `:37`, `:50-54`) rather than everyone else's being relaxed.
  The 11-minute value is derived from the server's own 10-minute remux ceiling, not chosen.
- **Build-plan step 7 was not built.** It is "resume by seeking, not by `start`", and the plan makes
  it **conditional on open question 7.2**, which is unanswered. The builder stopped rather than
  choosing, which is what the pass required; no stub and nothing "prepared but disabled" was left.
- **A correction to this project's own reporting.** Pass 41 §4.3 claimed that sending `start: N` on
  the file route "would break `fullyPrepared`, the HUD's 'x of y' and the commercial clamp".
  **That was wrong.** The server applies `-ss` to trim the file **and** echoes the same `start`
  back, so `startOffset` compensates exactly: `preparedTo = startOffset + range.end = N + (D − N)
  = D`. Measured on the device in Pass 42: a commercial skip landed at item time `t=272.538500`
  with the app reporting `position 1478.54 s`, which is `startOffset + t` and is the break's exact
  `endSeconds`. **Open question 7.2 is therefore a wait-versus-cleanliness trade, not a correctness
  bug**, and the app is correct as shipped without step 7. Recorded here rather than by editing the
  Pass 41 report, the way this project's other corrections are.
- **The two recordings the server refuses are refused, not worked around.** A recording still being
  written and a recording that is not H.264/AAC each earn a 502 with the server's own text, which
  reaches the existing Failure state. Neither is routed back to HLS and no retry was built.
  **Neither was exercised on the device** — the only subject available was finished and H.264.
- **No client-side compensation for the audio/video desync was built, and none is to be.** It stays
  with the marlin-dvr project, as Pass 39 sorted it.
- **Disclosed cost of the evidence:** capturing the wire traffic needed three `print` statements the
  app does not otherwise have, added as a disclosed diagnostic and **fully reverted** before the
  commit; the reverted build was then reinstalled and re-run on the device to confirm the shipped
  code is the tested code. Two device runs left **a resume position deep inside *History's Greatest
  Mysteries* S4 E14** (1206 s → past 1484 s, plus 40 forward skips), which is recorded in
  COLD-START. Nothing was deleted, trashed, hidden or scheduled, no `GET /api/settings` was read,
  and no administrative or diagnostic request was made to the server.


## 2026-09-08 (Pass 47 — the Recordings shelf focus clipping)

- **Owner acceptance: Pass 47 was tested on Home Theater 2026-09-08 and accepted** — "good to go"
  (owner, 2026-09-08). Pushed to `origin main` in Pass 48 together with the notebook work recording
  the acceptance.
- **Option C was the owner's choice, from the three the Pass 46 recon offered** (owner, 2026-09-08):
  grow the focused card's **real layout box** — 252×344 to 296×404 with the `-22` lift — the way
  `design/` specifies at `dc:1273`, so that only the intended lift overhangs upward.
  **Option A (more padding above the row) and option B (`.scrollClipDisabled()`) were rejected**,
  and neither was built, stubbed, or added alongside C as a safety net. The recon deliberately
  presented all three without choosing; the choice was the owner's.
- **`RecordingsScreen.swift:114`'s ScrollView clipping and the `.padding(.vertical, 44)` at `:127`
  were left untouched, by owner instruction.** Both were verified byte-identical after the change,
  and `.scrollClipDisabled()` appears nowhere in the app. The fix had to work without either, and
  it does.
- **The `scaleEffect` was removed, not kept alongside the layout change.** A render transform
  changes no layout, which is the whole cause: it grew the card about its centre and threw ~38 pt
  upward on top of the 22 pt lift, overflowing a 44 pt budget. Keeping both would have reintroduced
  the defect.
- **The row reflowing sideways is an accepted cost, not a defect.** The focused card is 44 pt wider,
  so cards to its right shift as focus moves. The owner was told this **before** choosing option C
  and accepted it.
- **The 60 pt downward shift of the shelves below was not compensated for, and is an open item the
  owner has seen and accepted — not a decision to leave it forever.** The focused card's box is
  60 pt taller, so the shelf and everything under it grow while it holds focus. It clips nothing and
  it is `design/`'s own behaviour (`dc:383`), but **the owner was told about it only after Pass 47**,
  not before choosing. **Nothing was built to absorb it**, because every way of doing so goes through
  `:114` or `:127` — the two lines he instructed be left alone. If it turns out to bother him, that
  is a later decision and it reopens those two lines.
- **The title and episode count no longer enlarge on focus.** `dc:389-390` fix them at 26 pt and
  23 pt in both states; the old scale was enlarging them. The app now matches the design. Recorded
  because it is a visible change nobody asked for in those words — it fell out of removing the scale.
- **Multi-card focus traversal on the reflowing shelf is untested.** The device run proved shelf
  navigation survives a card whose layout box changes on focus, but the available non-destructive
  harness matched the first card it read and sent no rightward presses. Proving it would have needed
  a new test file or the harness that deletes one of the owner's recordings; **neither was done**.


## 2026-09-08 (Pass 49 — the airing sheet's first control)

- **Owner acceptance: Pass 49 was tested on Home Theater 2026-09-08 and accepted** — "all good"
  (owner, 2026-09-08). Pushed to `origin main` in Pass 50 together with the notebook work recording
  the acceptance. It closes the first entry under **KNOWN AND UNFIXED after Pass 33**.
- **The owner's rule, in his terms** (owner, 2026-09-08): **the control is never hidden.** It becomes
  a **status indicator** whenever the airing already has a state, and stays a real button only when
  it does not — "Recording" while the recorder is running on it, "Scheduled" while it is booked and
  not started, "Record this airing" otherwise. **"Recording" and "Scheduled" are indicators, not
  actions**: not focusable, and nothing happens on Select.
- **Hiding the control was explicitly rejected, and the reason is the whole point.** A series pass
  covers a **show**, not every airing. The pass existing tells you nothing about the state of the
  airing in front of you — the airing's own job does. If a pass is not picking an episode up, hiding
  the button would leave the owner **no way to record it at all**. So the slot is always occupied.
- **This is a fallback, not the primary signal.** The Guide grid already shows gold for a series pass
  and green for recording; the point of the change is that the sheet must not say something
  different from what the Guide already shows.
- **The other three controls and the amber line are untouched.** "Edit series pass", "Watch live" and
  "Stop recording" keep their labels, behaviour, conditions and positions byte-for-byte, and so does
  the amber series-pass line beneath them. The Guide grid and its gold/green marks were read but not
  changed.
- **The green-versus-gold difference was raised to the owner and left as built.** A pass-scheduled
  airing shows a **green** "● Scheduled" chip where the Guide draws a **gold** "◆ SERIES PASS". The
  meaning is the same and the amber pass line still names the pass. **A gold chip would have been a
  fourth state the owner did not ask for** — he specified three — so it was reported rather than
  invented (owner, 2026-09-08).
- **`manualJob` was removed, not left as dead code.** It was the defective predicate — it required
  `passId == "manual"`, which is exactly why a pass-driven job fell through to the Record button — and
  leaving it in place would have invited a later pass to reach for the wrong test. `passId` is no
  longer consulted anywhere in that decision.
- **`firstFocusID` had to follow the state.** It is what the sheet assigns to `focused` when it
  opens; had it kept the old gating, a pass-driven recording would have opened trying to focus
  `"record"` — an id that no longer exists in two of the three cases — and focus would have landed
  nowhere. It now resolves to the series button whenever the first slot is a chip.
- **No new request, no new model field, no new source of truth.** The state is `Job.status`, from the
  schedule read the sheet already performs on open, read exactly as the Guide's own marks read it.
- **Disclosed limit of the evidence:** only the **unbooked** case was proven on the device, with a
  write-free harness. The "Recording" and "Scheduled" renderings were **code-traced only** — reaching
  them needed a new harness file or one that books and stops a real recording on the owner's DVR, and
  neither was done. The owner's acceptance by eye is what covers them.


## 2026-09-08 (Passes 51-55 — the app icon and Top Shelf art)

- **Owner acceptance: the icon was looked at on Home Theater 2026-09-08 and accepted** (owner,
  2026-09-08). Pushed to `origin main` in Pass 55 with the notebook work recording it.
- **The owner supplied a complete, structured asset catalog rather than regenerating layered
  artwork.** Pass 52 measured that a tvOS icon stack needs **at least two of its three layers**
  populated, not three, and Pass 51 had planned for nine images on the assumption that three were
  required. What arrived was an `AppIcon.brandassets` with a two-layer `App Icon.imagestack` and the
  400×240 that had been missing — **which needed no repair of any kind** and which `actool` accepted
  with no error, warning or note. **Nothing of his was edited**: the 19 files went into the project
  byte-identical (`diff -r`), and the only project change was two lines repointing
  `ASSETCATALOG_COMPILER_APPICON_NAME` at `AppIcon`, because his folder is named that and the setting
  still pointed at the empty template.
- **"MARLIN TV" stays.** The artwork renders "MARLIN TV" while the app's `CFBundleName` is
  "Marlin DVR TV". Pass 51 §6.1 reported the difference; **the owner decided on 2026-09-08 that it is
  fine, and it is not to be raised again.**
- **Both layers of the icon stack point at the same two opaque images**, so the parallax depth effect
  has nothing behind it to reveal. **This is the owner's choice for now** (owner, 2026-09-08). It
  compiles clean — Pass 52 established there is no transparency rule — and it was left exactly as
  supplied. No transparent front layer was generated, suggested or stubbed.
- **`FocusClick.dataset` was deliberately not added.** It arrived inside the owner's catalog: a
  4,100-byte `focus_click.caf`. It is not icon artwork, **no Swift source references it**, and no
  numbered step named it, so importing it would have added an unused asset nobody asked for. **Left
  in `icon-source/`, untouched.**
- **The project's empty template `App Icon & Top Shelf Image.brandassets` was left in place.** It is
  unused now that the setting points at `AppIcon`. Pass 53 §4 proved it produces **byte-identical**
  `actool` output whether present or absent, so it does no harm; **removing it was not a numbered
  step and is not this project's call to make unasked.**
- **The fate of `icon-source/` is the owner's call and has not been decided.** All **32** of its
  entries remain untracked — the loose PNGs Pass 51 examined, his structured catalog (now duplicated
  inside the project), `AccentColor.colorset` and `FocusClick.dataset`. **Nothing there has been
  deleted, moved, renamed or committed by any pass.**
- **The app was installed on a second Apple TV** — "Master Bedroom ATV" (`AppleTV6,2`, tvOS 26.6) —
  from the same binary as Home Theater (Pass 54). **It is development-signed and will stop launching
  when the profile expires; when that is has not been checked.**


## 2026-09-09 (Pass 56 — no more handoff briefs)

- **This project uses `COLD-START.md` and `DECISIONS.md` only. They are the whole record.** No
  further handoff-brief file is written by any pass (owner, 2026-09-08). This matches how the
  owner's other projects run.
- **`MARLIN-DVR-TV-HANDOFF-2026-09-09.md` was retired into `COLD-START.md` by Pass 56 and deleted.**
  Pass 55 wrote it because it was written before the decision above was taken. Pass 56 compared it
  section by section against `COLD-START.md`, found that all but two of its substantive facts were
  already carried, moved those two in, and then removed the file
  (`reports/2026-09-09-pass56-retire-handoff-brief.md`).
- **The two facts that had to move** were **the 27-session start-values table's standing state** and
  **the marlin-dvr project's outstanding request that the owner match the sessions where he observed
  the audio/video desync to individual session records.** Both now live under
  "Raised for the marlin-dvr project" in `COLD-START.md`.
- **`MARLIN-DVR-TV-HANDOFF-2026-09-08b.md` was not deleted because it is not on disk.** Pass 55
  reported it exists only in the owner's Context panel; Pass 56 re-checked and it is still nowhere in
  the repo or the working tree. **Removing it from the Context panel is the owner's to do.**
- **No report was edited or deleted.** `reports/2026-09-08-pass55-push-and-handoff.md` stays exactly
  as written, including the brief it describes — reports are the historical record and are never
  rewritten to match a later decision.


## 2026-09-09 (Pass 57 — the project has a CLAUDE.md)

- **The project has a `CLAUDE.md` at its root.** Pass 57 created it. It is the standing brief the
  builder reads automatically at the start of every session, so the rules that were only ever stated
  in a pass prompt now travel with the repo.
- **It holds the standing builder rules and a pointer to the notebook, and nothing else.** The eight
  rules — recon before build, scope lock, no installs without owner authorization, the separate push
  gate, never force-push or rewrite history, no secrets, stop and report when blocked, and the
  do-not-touch list copied word for word from `COLD-START.md` — plus one line saying where the record
  lives.
- **No project state ever goes in `CLAUDE.md`** — not what is built, not what is broken, not open
  questions, not pass history. **`COLD-START.md` and `DECISIONS.md` remain the whole record**, as
  decided for Pass 56 above, and `CLAUDE.md` only points at them. A fact that would go stale belongs
  in the notebook, never in the standing rules.
- **`CLAUDE.md` is committed, not ignored.** It was deliberately kept out of `.gitignore` so every
  session on any machine gets the same rules. **No `.claude/` directory and no `CLAUDE.local.md` were
  created**; all four memory locations were checked and were absent before this pass.


## 2026-09-09 (Pass 58 — CLAUDE.md's ninth rule)

- **The server-repo rule is now in `CLAUDE.md`**, as its ninth and last bullet, after the
  do-not-touch line: *"The server repo is read-only reference; server changes, if ever needed, are
  raised as decisions for the marlin-dvr project."* It was extracted from `COLD-START.md` line 23 by
  `grep` rather than retyped, and then string-compared and `cmp`-compared against it: **byte-identical**.
  Pass 57 left it out because step 3 fixed that file's contents exactly; Pass 58 was the numbered step
  that put it in. **One insertion, zero deletions — nothing else in `CLAUDE.md` changed.**
- **`CLAUDE.md` now carries every rule in `COLD-START.md`'s rules list.** Measured, not assumed:
  `COLD-START.md` has **eight** rules; **five** now appear in `CLAUDE.md` byte-identical (recon, no
  installs, push gate, do-not-touch, server repo) and **three** in reworded or strengthened form
  (scope lock; "Nothing force-pushed, ever" became "Never force-push and never rewrite history"; the
  no-secrets rule gained the redaction clause). **No rule is missing in substance.**
- **`CLAUDE.md` has nine bullets, not eight, because one is its own:** *"If anything blocks, stop and
  report. Do not work around it."* has **no counterpart in `COLD-START.md`'s rules list.** It came
  from Pass 57's step 3 text.
- **"The ninth rule" means the ninth bullet of `CLAUDE.md`, not a ninth rule of `COLD-START.md`.**
  `reports/2026-09-09-pass57-claude-md.md` §3.2 and §8 called it "COLD-START.md's ninth rule", which
  is wrong — it is that file's **seventh** of eight. **The Pass 57 report is not edited**; reports are
  the historical record. The correction is recorded here, and here is what governs.
- **The two lists are still maintained by hand and can drift.** Pass 57 raised this and it is still
  open: `CLAUDE.md` duplicates the rules rather than pointing at them, and three of them are already
  worded differently in the two files. **Not changed** — deciding which file is the source of truth
  is the owner's call.


## 2026-09-09 (Pass 59 — COLD-START.md brought current through Pass 58)

- **`COLD-START.md`'s "Next step" section is current through Pass 58.** Its running push history had
  stopped at Pass 55's `fd96b1d`. A new paragraph at the head of the section — the section runs
  most-recent-first — records the commits since, with **every SHA read from `git log` and
  `git ls-remote origin main`, none from memory**: `48e8f91` (Pass 55's own follow-up commit, which
  the older paragraph never named), `10499e5` and `8f371a6` (Pass 56), `be0cae9` (Pass 57) and
  `67ec874` (Pass 58). **Nothing is unpushed as of Pass 58.**
- **The chain was checked, not assumed.** All six commits are ancestors of `origin/main`,
  `git log --merges` over the range is empty, and each commit's parent is the one before it —
  linear, nothing forced, rebased or amended.
- **`COLD-START.md`'s "Where things live" now lists `CLAUDE.md`**: at the project root, the standing
  builder rules and a pointer to this notebook, never project state, per the Pass 57 entry above.
- **Additions only.** `git diff` on `COLD-START.md` is **19 insertions, 0 deletions** — no existing
  line was rewritten, reworded, moved or removed, as the pass required.
- **"Next step" now opens with two paragraphs that each say nothing is unpushed** — the new one
  scoped "as of Pass 58", the older one written when `fd96b1d` was head. The older text was left
  exactly as written because the pass forbade rewriting it. **Whether the section should be
  consolidated is the owner's call and is not decided.**


## 2026-09-09 (Pass 60 — one source of truth for the rules)

Both entries below are **standing rules**, not observations about this pass.

- **(a) `CLAUDE.md` is the single source of truth for the standing builder rules.** `COLD-START.md`'s
  "The rules" section keeps its heading and now holds one line pointing at `CLAUDE.md`; **its eight
  bullets are deleted and this file no longer carries its own copy.** **A rule change is made in
  `CLAUDE.md` only** — never by editing a second copy, and never by adding rules back here. The two
  lists had already drifted in three places, which is why there is now one.
- **No rule was lost in the deletion.** Verified bullet by bullet before deleting: all eight had a
  counterpart in `CLAUDE.md` — **five byte-identical**, and three carried in wording that is the same
  or stronger ("Nothing force-pushed, ever" → "Never force-push and never rewrite history"; the
  no-secrets rule, whose original sentence survives as an **exact prefix** with a redaction clause
  added; and scope lock). The table is in
  `reports/2026-09-09-pass60-rules-source-of-truth.md` §3.
- **(b) A pass records its own verified push in its report and in its response to the owner, not in a
  second commit.** Passes 55 and 56 each used a follow-up commit for this. **That is not the pattern
  going forward.** Passes 57, 58 and 59 each raised the inconsistency as an open question; it is now
  settled, and **no later pass should re-raise it.** A pass makes one commit, pushes it, verifies the
  push live with `git fetch origin`, `git rev-parse main`, `git rev-parse origin/main` and
  `git ls-remote origin main`, and reports the result. The post-push SHA lives in the pass response
  and in the next pass's notebook update, not in the commit it describes.
- **`COLD-START.md`'s older "Next step" paragraph is now dated to its own moment.** Its opening
  "**Nothing is unpushed.**" became "**Nothing was unpushed as of Pass 55.**" — one sentence, nothing
  else in that paragraph touched. This closes the double-claim Pass 59 raised.
- **Known dangling reference, deliberately not fixed:** the Pass 58 paragraph in "Next step" still
  reads "the server-repo rule from the rules list above" and "this file's rules list holds **eight**
  rules". **That list no longer exists in this file.** The sentences are true of the moment they
  describe, and Pass 60's steps forbade changing anything else in the file, so they stand. **Whether
  to reword them is the owner's call.**


## 2026-09-09 (Pass 61 — two corrections)

- **The scope-lock rule binds what gets built *or changed* again.** `CLAUDE.md`'s bullet read "Scope
  lock: build only what the pass names"; it now reads **"Scope lock: build or change only what the
  pass names."** The rest of the bullet is unchanged, including "never built, not even disabled".
  `COLD-START.md`'s original said "gets built **or changed**", and Pass 60 §3.1 flagged that the
  surviving wording had quietly narrowed to builds alone — which mattered, because most passes edit
  documentation rather than build anything. **The breadth is restored and the tail is still stronger
  than the original.**
- **The change was made in `CLAUDE.md` and nowhere else**, which is Pass 60 rule (a) working as
  intended: there is one copy, so a rule correction is one edit with nothing to keep in step.
- **The Pass 58 paragraph in "Next step" no longer points at a list that does not exist.** It said
  the server-repo rule came "from the rules list above" and that "this file's rules list holds
  **eight** rules" — both dangling once Pass 60 removed that list. The references now read as history
  ("copied word for word from this file's rules list **as it then stood**", "**then held** eight
  rules", "the server-repo rule **was** its seventh") and cite where the rules live now: that rule is
  the last of `CLAUDE.md`'s nine bullets, and **Pass 60 removed this file's list, so `CLAUDE.md`'s
  bullets are the only copy.**
- **What the paragraph records is unchanged.** Every fact it carried survives — the bullet added, the
  word-for-word copy proved byte-identical, the report citation, `67ec874` as a fast-forward from
  `be0cae9`, the miscount the Pass 57 report made, the count of eight and the seventh position, and
  the one `CLAUDE.md` bullet with no counterpart. **Only the tense and the pointers changed.**
- **This closes both open questions Pass 60 left.** Neither should be re-raised.


## 2026-09-11 (Passes 62-65 — the Search screen)

- **Owner acceptance: the Search screen was tested on Home Theater 2026-09-11 and accepted** —
  "all good" (owner, 2026-09-11). Pushed to `origin main` in Pass 66 with this notebook work.
- **Search is a rail entry, directly under Radio and above the Manage DVR bottom slot, and it has
  no Home tile** (owner, 2026-09-11). It is the eleventh rail entry. The design draws no search
  of any kind — its own header says "No search" (`dc:38`) — so the screen is **built to the app's
  look**, the sixth to take that route after Manage DVR, Favorites, the radar, Radio and the
  commercial-skip prompt. The 3 × 3 Home grid is untouched. An eleventh rail entry fits: Pass 62
  worked it out from Pass 24's measured frames and **Pass 63 photographed it**, expanded rail,
  eleven entries and the two-line footer all inside the frame.
- **Results come from `GET /api/guide/find?q=`; clicking one reconstitutes the airing from
  `GET /api/guide/search?title=`, never from `GET /api/guide`** (owner, 2026-09-11). `find`
  answers with twenty thin display rows and the true total in `count`, and carries neither a
  `Program` nor a `MergedChannel`, so a second read is unavoidable. **`/api/guide` was rejected
  for cause**: its block builder rounds the cursor up to whole half hours and skips listings that
  end inside a slot already consumed (`guide.go:679`, `:699`, `:705`), dropping **about 3 %** of
  them — the marlin-dvr project's own measurement, recorded by them as known and not being fixed.
  An airing it drops is one the Guide screen cannot show either, so search would have been the
  only route to it and the one route that failed. `/api/guide/search` walks the stored guide
  directly and has no such hole; it is whole-title equality, which is exactly right when the
  title being asked with is the row's own. A new decoder for it is Pass 63's, strict on every
  field, decoding the embedded `Program` from the same container the way `GuideNowItem` and
  `GuideRow` already decode `MergedChannel`.
- **DRM results are filtered out**, matching the standing rule that DRM channels never appear in
  any list (`ChannelFilter.swift:5-8`, DECISIONS.md 2026-09-05 (design)). Both routes walk
  `a.channels(false)`, which carries DRM channels rather than hiding them, so the rule is applied
  client-side like every other shape in that file. **Silently**: nothing on screen says a result
  was hidden. The one exception is honesty rather than disclosure — when the server reports
  matches and every returned row was filtered, the screen says "No airings match “x” on a channel
  this app can play" instead of a flat "no matches".
- **When `count` exceeds the twenty rows returned, the screen says so and names both numbers**
  (owner, 2026-09-11): "Showing the first 20 of 704 matches · type more of the title to narrow
  it". **Neither number is this app's arithmetic** — both are the server's own, taken before the
  DRM filter, so the line describes the search and never the list. The cap is not pageable: there
  is no offset, cursor or page parameter, so the twenty-first match is reachable only by typing
  more, which is what the line tells the user to do.
- **A query and its results survive a trip to the rail and back** (owner, 2026-09-11).
  `ScreenShell.swift:51` puts `.id(current)` on the content and destroys the screen on every
  visit, so the model is owned above the shell like `HomeModel` and `WeatherModel`. Proven on the
  device: the count line is string-identical and the rows element-for-element identical across a
  round trip through Radio.
- **The search input is tvOS's own `.searchable`, not a hand-built `TextField`** (owner,
  2026-09-11, after the Pass 64 probe). **A plain `TextField` was measured as a full-screen
  takeover**: Select summons a keyboard that blurs the whole app out of sight, and Pass 64 proved
  the field's own frame makes no difference by pinning it to the top of the screen and
  photographing the identical takeover. `.searchable` instead draws a field and a one-row
  alphabet strip about 66 pt tall at the top, with everything below still on screen and still
  reachable — the remote goes down into the results and back up to the strip without the keyboard
  ever being dismissed. **No `NavigationStack` is needed**; Pass 64 ran one as a control and it
  drew pixel-for-pixel the same. UIKit's `UISearchController` in a `UISearchContainerViewController`
  was the third candidate: contained directly it draws but **cannot be focused at all**, and
  inside a `UINavigationController` it works but **dismisses the keyboard the moment focus enters
  the results**, which is why `.searchable` was chosen over it.
- **The sheet-close focus rebuild stays, and it was removed and measured before that was
  decided.** Writing the row's id into `@FocusState` after the airing sheet closes does not move
  the focus engine — Pass 63 measured the screen ending with nothing at all focused. The fix is a
  `generation` counter that rebuilds the content subtree, the one mechanism in this app that
  re-focuses reliably (`ScreenShell.swift:51` does the same with `.id(current)`). **Pass 65 took
  it out rather than assume `.searchable` had changed things**, put the plain assignment back
  properly, and the device answered `focused=[]` again — the identical failure. It went back in
  and focus returned to the exact row. **Not to be removed a third time without the device saying
  so.**


## 2026-09-11 (Pass 67 — the notebook brought current)

- **`COLD-START.md`'s "Next step" is current through Pass 66.** Its newest paragraph had stopped
  at Pass 58's `67ec874`, leaving six landed commits unnamed. A new paragraph at the head of the
  section — which runs most-recent-first — records them: `77bf616` (Pass 59), `4f78906`
  (Pass 60), `49a5672` (Pass 61), `1107b12` (Pass 63), `d0ff593` (Pass 65) and `b028650`
  (Pass 66). **Nothing is unpushed as of Pass 66.**
- **Every SHA was read from `git log` and `git ls-remote`, none from memory, and the chain was
  checked rather than assumed:** all six are ancestors of `origin/main`,
  `git log --merges 67ec874..b028650` is empty, each commit's parent is the one before it, and
  `67ec874` is still an ancestor of the current head.
- **Additions only.** `git diff --numstat` on `COLD-START.md` reported **22 insertions, 0
  deletions**; no existing line was rewritten, reworded, moved or removed.
- **The Pass 66 report is committed**, unmodified —
  `reports/2026-09-11-pass66-search-accepted-and-pushed.md`, scanned for credentials, tokens and
  device ids first and none found. Pass 66 necessarily left it untracked: its own steps put the
  report after the push, and a push SHA cannot be written into a commit that precedes it.
- **That is now a recognised pattern, not an oversight.** A pass whose report records its own
  verified push leaves that report untracked, and the next pass commits it — as Pass 63 did for
  Pass 62's, Pass 65 for Pass 64's, and this pass for Pass 66's. **This pass's own report is
  untracked for the same reason and is the next pass's to pick up.**
- **The record that a pass's `reports/` file belongs in the repo is unchanged** (owner,
  2026-09-08). Nothing above weakens it; it only names when the committing happens.


## 2026-09-11 (Pass 68 — a pass's report goes in its own commit)

This entry is a **standing rule**, not an observation about this pass.

- **A pass writes its report and commits it BEFORE pushing.** The report goes inside the commit
  it belongs to. **No pass leaves an untracked report for the next one to sweep up.** The order
  is: do the work, write the report, commit everything together, push, verify the push.
- **The verified push SHA is not in the report.** It cannot be — a commit cannot contain its own
  SHA — and it does not need to be: **Pass 60 rule (b) already says where it lives**, which is
  the pass response and the next pass's notebook entry. Nothing is lost by leaving it out of the
  report, and the report stops being a reason to delay the commit.
- **This closes a cycle that ran three times.** Under the old ordering the report was written
  after the push so that it could carry the verified SHA, which meant it could not be in the
  commit: **Pass 62's report was left untracked and committed by Pass 63, Pass 66's by Pass 67,
  and Pass 67's by this pass.** Each sweep-up was correct under the ordering it inherited; the
  ordering was the defect.
- **The reports themselves were never at risk** — every one of them reached the repo, unmodified
  and byte-identical, one pass later than it should have. What the old ordering cost was a
  working tree that was never clean at the end of a pass, and a standing task handed forward.
- **`reports/2026-09-11-pass67-notebook-current.md` and
  `reports/2026-09-11-pass68-report-ordering.md` are both in this pass's single commit**, which
  is the rule working the first time it is applied.
- **This is settled. No later pass should re-raise it**, and none should re-derive why the old
  ordering existed. Pass 67 §7.1 named the fix; this is it.
