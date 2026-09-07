# COLD-START — Marlin DVR TV

## What the app is

Marlin DVR TV is a tvOS app (SwiftUI) that will be a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . Pass 1 (2026-09-05) created the empty Xcode project and the plumbing only. No app features are written.

## Where things live

- This folder: `~/Xcode/Marlin DVR TV` — the Xcode project, the notebook (this file, DECISIONS.md, reports/), and the git repo. The only writable tree.
- Repo: `git@github.com:marlin1111ai/marlin-dvr-tv.git` (branch `main`).
- Server reference clone: `~/Xcode/marlin-dvr-reference` — a read-only clone of marlin-dvr. Never edited, never pushed, never run from.
- Server URL: http://192.168.1.250:8090/ (Marlin DVR on Unraid). Not touched by this project's tooling.
- Approved design: `design/` — the Claude Design export (`Marlin DVR TV.dc.html`, Nocturne design system, `ATV-DVR.zip`). Read-only; never edited. The screens are built to it (DECISIONS.md, 2026-09-05 (design)).

## The rules

- Recon before build.
- Scope lock: nothing not named in a pass's steps gets built or changed; anything extra goes in the report as a question.
- No installs without owner authorization.
- Separate push gate for code the owner tests.
- Nothing force-pushed, ever.
- No secrets in the repo, logs, or reports.
- The server repo is read-only reference; server changes, if ever needed, are raised as decisions for the marlin-dvr project.
- Do not touch: the other folders under `~/Xcode`, the Marlin DVR server and its data, the Unraid host 192.168.1.250, marlinpc 192.168.1.245, the HDHomeRun 192.168.1.105, the UNAS4Pro share.

## How to build

- Open `Marlin DVR TV.xcodeproj` in Xcode and press ⌘B.
- Or from the command line:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build
```

  The tvOS 26.5 platform component (simulator runtime and device support) is installed on this Mac (confirmed in Pass 3, 2026-09-05); the scheme/destination line above works, and so does this target/SDK form:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -target "Marlin DVR TV" -sdk appletvsimulator -configuration Debug build
```

## What is built

The empty project — Pass 1 was plumbing. One app entry point (`Marlin_DVR_TVApp.swift`) and one `ContentView` showing the app name.

Pass 2 (server recon, `reports/2026-09-05-pass2-server-recon.md`) and Pass 3 (HLS client recon against `HLS-CLIENT-API.md`, `reports/2026-09-05-pass3-hls-client-recon.md`) are done; both were read-only and wrote reports only.

Pass 4 (`reports/2026-09-05-pass4-design-and-build-recon.md`) put the approved design into `design/`, recorded the design decisions, and mapped every in-scope screen to the server API and into build sweeps.

Pass 5 (sweep 1, `reports/2026-09-05-pass5-sweep1-foundation.md`, pushed after the owner's Home Theater test): the foundation — ATS exception, API client, models, DRM filter, image loader, client register/ping — plus the rail and Home.

Pass 6 (sweep 2, `reports/2026-09-05-pass6-sweep2-screens.md`, pushed after the owner's Home Theater test): the read-only screens — On Now, Guide with the airing sheet, On Later, Recordings with show detail, Cameras.

Pass 7 (sweep 3, `reports/2026-09-06-pass7-sweep3-player.md`, accepted by the owner on Home Theater and pushed): the Player — HLS sessions per `HLS-CLIENT-API.md` (server 1.2.1), AVPlayerViewController with the overlays of frames 6a–6h, recordings with seek-by-new-session, the per-Apple-TV resume store and watched-on-end, live channels with the server's time-shift buffer, cameras, and the entry points from On Now, the Guide, the airing sheet, show detail and Cameras.

Pass 8 (sweep 4, `reports/2026-09-06-pass8-sweep4-writes.md`, accepted by the owner on Home Theater and pushed in Pass 11; its fixes are Pass 9): the writes — "Record this airing" (`POST /api/record`) and "Record the series" (`POST /api/passes`) on the airing sheet with the ● SCHEDULED / ◆ SERIES PASS marks on the Guide; the show-detail click-and-hold menu (Keep, Favorite, Mark unwatched, Delete → `PUT /api/library/recordings/{id}`, a trashed episode leaving the list); "Hide this channel" (`PUT /api/sources/{id}/lineup/{guid}`); and "Stop the recording and watch" on a tuner-busy 502 (`POST /api/schedule/jobs/{id}/stop`, then the live session). Two defects shipped in sweeps 2–3 were found and fixed there: `.onLongPressGesture` never fires on a tvOS Button (click-and-hold now goes through `HoldButton`), and the episode list could not be reached with the remote (focus sections).

Pass 9 (sweep 4 fixes, `reports/2026-09-06-pass9-sweep4-fixes.md`, accepted by the owner on Home Theater and pushed in Pass 11): the seven fixes from that test — click-and-hold rebuilt on UIKit's press pipeline and **proven on the physical Apple TV** by an XCUITest that presses the real remote (a new `Marlin DVR TVUITests` target, four tests including a negative control); the airing sheet's buttons made to fit; "Watch live" only while the programme is on; "Edit series pass" instead of "Record the series" when the show already has one, with no raw 409 ever shown; a new Edit series pass screen (record mode, padding, keep rule, delete with a confirm); the episode menu cut to Keep and Delete; and click-and-hold on a channel cell in the Guide to favourite it.

Pass 10 (`reports/2026-09-06-pass10-favorites-and-manage.md`, accepted by the owner on Home Theater and pushed in Pass 11): the Favorites screen — the rail's Favorites entry is live and lists the server's favourite channels with what is on now, clicking one plays it live — and the **Manage DVR** area (Pass 10B moved its entry to the bottom of the rail; it was briefly a row on Recordings): the storage line from `GET /api/system`, Scheduled Recordings (the schedule grouped, with a detail view offering Cancel recording and Manage pass), Your Passes (the pass editor, which gains Pause/Resume), and Trash (Restore per row, Empty Trash behind two clicks). Counts on every row come from the server. Neither screen is in the approved design; both are built to the app's look.

Pass 10B (`reports/2026-09-06-pass10b-manage-in-rail.md`, accepted by the owner on Home Theater and pushed in Pass 11): the owner's fix — Manage DVR is a rail entry in the bottom slot of the rail, not a row on Recordings. The screen itself is unchanged and Home is untouched.

Pass 11 (`reports/2026-09-06-pass11-acceptance-and-push.md`): the acceptance recorded in DECISIONS.md and here, and Passes 8, 9, 10 and 10B pushed to `origin main` together.

Pass 12 (`reports/2026-09-06-pass12-weather-recon.md`): Weather screen recon, read-only, report only. It read frame 5f field by field (the design draws **no** radar and no map anywhere), gathered everything the notebook says about Weather, and checked the installed tvOS SDK for what is possible: `MKMapView`, `MKTileOverlay` and `MKTileOverlayRenderer` are all available on tvOS 9.2+, SwiftUI's `Map` has no raster-tile content type at all, MapKit has no frame-animation API, WeatherKit is present at tvOS 16.0 and exposes a counterpart for every field the design draws — but no radar, no tiles, no imagery.

Pass 13 (`reports/2026-09-06-pass13-weather-radar.md`): the **Weather screen** (frame 5f) and the **Home weather glance** (frame 2a, live at last), both fed only by WeatherKit; the **one-shot location** with the system prompt, cached after the first grant, with a spoken state for every way it can fail; and the **radar view** — `MKMapView` in `UIViewRepresentable`, `MKTileOverlay` + `MKTileOverlayRenderer`, an app-written frame loop with the frame time shown, flat and north-up — reachable from the Weather screen. Two things stop short of working and are named plainly, not papered over: **WeatherKit is not enabled for this app's bundle id**, so every forecast call fails and both screens print that instead of data; and **step 1 found no radar tile source** in the owner's iPhone weather app, so the radar has a map and a loop but no tiles and says so on screen. Both are the owner's to unblock.

Pass 14 (`reports/2026-09-06-pass14-noaa-radar.md`): Pass 13 pushed to `origin main` (71b88d3), and the radar given a real source — **NOAA**. The National Weather Service's MRMS base-reflectivity service (`mapservices.weather.noaa.gov/eventdriven/…/radar_base_reflectivity_time/ImageServer`) is free, needs no key and no account, and is public domain. It publishes no `{z}/{x}/{y}` tiles, so `NOAARadarTileOverlay` converts each tile's z/x/y into that tile's Web Mercator bounding box and asks the service's `exportImage` for exactly that picture; frame times are NOAA's own `idp_validtime` values, read from the service's mosaic catalog with a spatial filter so the frames are the ones covering this Apple TV. **Real radar draws on Home Theater** — proven with a full-viewport storm system. It ships as **one live frame, not a loop**: with six frames every frame time and every tile arrives (215 requested, 215 loaded, 0 failed) but MapKit does not repaint a tile renderer whose alpha goes 0 → 1, so the animation is mostly blank. That is a defect in Pass 13's loop, which Pass 14 was told not to rebuild; it is Open Question 1 of the Pass 14 report.

Pass 15 (`reports/2026-09-06-pass15-radar-animation.md`): the radar **animates**. Pass 13's loop revealed one frame by setting `MKOverlayRenderer.alpha`, which tvOS does not repaint; `setNeedsDisplayInMapRect:` and `exchangeOverlay:withOverlay:` do not repaint either, both measured on the device. What does is attaching and detaching: exactly one frame's overlay is on the map and stepping the loop removes it and adds the next. `frameCount` is unpinned, so the loop runs over everything NOAA offers — 17 to 18 scans, about two hours. The view also **refreshes every five minutes** while it is on screen (NOAA lands a scan every 355-483 s) and the timer is cancelled on disappear. The "Lost connection to testmanagerd" deaths of Pass 14 were diagnosed and are **not an app defect**: memory is flat (433 MB, 1.6 GB headroom), no tile traffic during the loop, no crash report, and five consecutive three-minute runs passed — the Mac talks to the Apple TV over `transportType: localNetwork`, and that wireless test connection is what drops.

**The cost, measured and unresolved:** attaching and detaching is the only mechanism that repaints, and it makes MapKit re-fetch every tile on every step — **about 2,300 NOAA requests a minute** with the radar simply sitting open. During Pass 15's testing **NOAA answered HTTP 403** and the app said so on screen. The radar is left as built and the rate is Open Question 1 of the Pass 15 report; a small in-memory frame store would cut it by roughly 98 % but was outside that pass's scope.

Pass 16 (`reports/2026-09-06-pass16-radar-cache.md`, accepted by the owner on Home Theater 2026-09-06 and pushed in Pass 17): Passes 14 and 15 pushed to `origin main` (`9dcc135`), and the radar's traffic problem solved. `RadarTileStore` keeps the tiles already fetched and serves them back on the next step, so a loop that re-downloaded everything now redraws from memory: **2,327 requests a minute became 53 a minute over eight minutes, and about 5 a minute at rest** once the frames are loaded. Measured on the Apple TV: 432 tiles held, **43 MB**, 2.4 MB per frame across 18 frames, with the app at 497 MB and 1.6 GB of headroom. The store is memory only, bounded at 96 MB, trimmed of scans that roll out of NOAA's window, and emptied by `RadarModel.stop()` when the view closes. NOAA answered every request — **no 403 and no failures anywhere in this pass**. The frame pace is retuned from 550 ms to **900 ms** (hold 2200 ms): frames render whole at either now, so the pace was chosen to spread the one-time cold burst — 2,389 requests a minute peak became 1,426 — and to make two hours of weather read in a seventeen-second cycle. The **five-minute refresh was seen to fire** for the first time: 17 frames became 18, NOAA requests rose by exactly one frame's worth, and the newest timestamp advanced.

Pass 17 (commit `6a724fb`, no report — it is recorded in DECISIONS.md): Pass 16's acceptance.
Pass 18 (`reports/2026-09-06-pass18-radio-recon.md`): Radio recon, read-only, report only — the
contract's §9, one `GET /api/radio`, the design's frame 5g field by field, and what the existing
Player can and cannot do for a station.

Pass 19 (`reports/2026-09-06-pass19-radio.md`): the **Radio screen**, built and playing. The rail
entry and the Home tile were drawn and inert since Pass 5 and are live now. The screen is built to
the app's look, not to frame 5g (owner, 2026-09-06): a two-column grid of station tiles, each the
icon the DVR has already cached plus the station's name, in the server's order and never sorted;
and a now-playing bar carrying that station's icon, its name and a Stop. The design's frequency
string, genre, bitrate, track/artist line and favourite star are dropped — the server has no data
for any of them — and `format` is ignored entirely (it is the empty string on both of the owner's
stations). Audio is a **bare AVPlayer**: `AVPlayerItem(url:)` on the URL the server gives, no play
session, no HLS, no keep-alive, no `AVPlayerViewController` and **no MIME option of any kind**.
Leaving the screen stops the stream, and so does the app leaving the foreground; there is no audio
session category and no background mode.

**The two things nobody had ever observed are settled, on the Apple TV.** *(a)* **AVPlayer follows
the StreamTheWorld 302.** The redirector answers `302` with a **zero-byte body**, and AVPlayer
decoded twenty-eight seconds of audio from it — audio it could only have got from the CDN the
`Location` names. *(b)* **tvOS plays the `.aac` mount**, which is the first station in the owner's
list and the one the server project never reached even with curl: AVFoundation reported the decoded
track as `'aac ' 22050 Hz 1 ch`. The MP3 station reported `'.mp3' 22050 Hz 1 ch`. **Both stations
play**: WBAL NewsRadio 1090 and WCBM Talk Radio 680, each driven by the real Siri Remote.

Pass 20 (`reports/2026-09-06-pass20-home-radio-count.md`): Pass 19 **pushed to `origin main`**
(`2a3b43b` and `dc28aec`, verified by fetch, `git rev-parse` and `git ls-remote` all reading the
same SHA — fast-forward, nothing forced, rebased or amended), and the **Home Radio tile given the
station count**. Home now reads a sixth endpoint, `GET /api/radio`, alongside the five it already
read, and the tile says **"2 stations"** in place of the static word "Stations" — the number first
and a lowercase noun, the shape every other counted tile uses. The count is the server's own
`count` field. If the server does not answer, or the list is empty, the tile drops back to
"Stations" rather than showing "0 stations", "unavailable", or a number kept from an earlier read;
both fallbacks were photographed on the Apple TV. No other tile changed, which was asserted by
capturing all nine on the device.

Pass 21 (no report — it is recorded here and in DECISIONS.md): **Pass 20 was accepted by the owner
on Home Theater 2026-09-06 and pushed to `origin main`** — `2e7542b` (the Home Radio count) and
`ec0f863` (its notebook and report), with this pass's own notebook commit — verified by fetch,
`git rev-parse` and `git ls-remote` all reading the same SHA. Fast-forward; nothing forced, rebased
or amended.

Pass 22 (`reports/2026-09-06-pass22-weatherkit.md`): **WeatherKit is enabled and both weather
screens are populated at last.** The owner registered the explicit App ID
`com.marlin1111.MarlinDVRTV` ("Marlin DVR TV") with WeatherKit ticked; this pass confirmed that
from Apple's own answer before changing anything, added the capability to the target (a new
`Marlin DVR TV.entitlements` carrying `com.apple.developer.weatherkit`, and
`CODE_SIGN_ENTITLEMENTS` in the app target's two configurations — nothing else), and the app now
signs against **`tvOS Team Provisioning Profile: com.marlin1111.MarlinDVRTV`** instead of the team
wildcard. Pass 13's `xpcConnectionFailed … com.apple.weatherkit.authservice … Sandbox restriction`
is **gone**: zero `[weather]` errors in the device console, and the Weather screen (frame 5f) and
the Home glance (frame 2a) both draw **real data on Home Theater** — 64°, Clear, feels like 61°,
H 78° / L 61° / humidity 71% / wind 5 mph NNE, 8 hourly columns and 5 daily rows with their range
bars, under the Apple Weather attribution. Three defects that only content could reveal were found
and fixed: the current-conditions detail line was cut ("wind 5 mph N…"), the Weather screen's
content never took focus so the remote was stuck in the rail, and the Home glance read "Apple
Apple Weather" and was cut. **The alert card is still unseen** — no alert is in force for this
location and `WeatherKit.WeatherAlert` has no public initializer, so its layout was checked with a
disclosed, reverted diagnostic and not with real data.

Pass 23 (no report — it is recorded here and in DECISIONS.md): **Pass 22 was accepted by the owner
on Home Theater 2026-09-06 and pushed to `origin main`** — `d4ee05c` (the signing), `9063207` (the
three fixes), `6d7d887` (the device harness and its screenshots) and `b52c4e4` (the notebook and
the report), with this pass's own notebook commit — verified by fetch, `git rev-parse` and
`git ls-remote` all reading the same SHA. Fast-forward from `bf5e9ba`; nothing forced, rebased or
amended.

## What is NOT built

The future screen **Settings**: present as drawn and inert, parked until the owner says otherwise (DECISIONS.md 2026-09-06 sweep 4 + fixes). Weather left this list in Pass 13 and **Radio in Pass 19**.

**Built but blocked on the owner**: nothing. Both entries this block ever held are closed — the radar's request rate by Pass 16's tile store, and **every WeatherKit value by Pass 22**: the App ID carries the capability, the target is entitled, and both weather screens draw real data on the Apple TV. The one thing still unproven there is the **alert card**, which needs a real alert in the owner's area to be seen (Pass 22 Open Question 1).

Deliberately still inert or absent: show detail's "Series pass" button and the Player's 6e "Delete this recording" (Pass 8 Open Question 1); any click behaviour on the Guide's channel cell — the hold favourites it, a click does nothing (Pass 9 Open Question 1); any way to un-skip a cancelled pass airing; and any auto-refresh of the Manage DVR lists (Pass 10 Open Questions 2 and 4). Cancelling a booking, which Pass 8 lacked, now lives in Manage DVR → Scheduled Recordings.

**Built but never exercised against the live server** — wired and code-traced, not proven, and named here so no one assumes otherwise (Pass 10 §4c and Open Question 3):

- **Restore** from the trash (`PUT /api/library/recordings/{id} {"trash": false}`) — the trash held a real recording of the owner's, so it was not pressed. The same function was exercised live in the other direction in Pass 8.
- **Empty Trash** (`POST /api/library/trash/empty`) — it deletes files on disk permanently for every client; never sent.
- **Cancel recording on a pass's airing** — only the one-off Record Now case was cancelled live. Same call; the server answers `removed: false` and skips that airing while the pass carries on.

## Open questions

See the Open Questions sections of `reports/2026-09-05-pass2-server-recon.md` (server recon) and `reports/2026-09-05-pass3-hls-client-recon.md` (HLS client recon). Environment questions from Pass 1 are listed in `reports/2026-09-05-pass1-plumbing.md`.

## Next step

None assigned — the owner directs what comes next. Pass 22 is accepted and on `origin main`;
nothing is committed locally and unpushed, and there is no sweep in flight.

Standing candidates, should the owner want them: the three untested-live paths above; the parked screen (Settings); and the Open Questions of `reports/2026-09-06-pass9-sweep4-fixes.md`, `reports/2026-09-06-pass10-favorites-and-manage.md` and the earlier recon reports.

To run the on-device hold tests again:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/RemoteHoldUITests"
```

The Manage DVR and rail UI tests (`ManageDVRUITests`, `RailManageUITests`) drive the Simulator;
`ManageDVRUITests` needs a scheduled recording and a series pass to exist. Both are evidence
harnesses from their passes, not standing tests. So are `RadioUITests` (Pass 19) and
`HomeRadioCountUITests` (Pass 20), which need the physical Apple TV and the owner's two stations:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/RadioUITests"
```

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/HomeRadioCountUITests"
```

`WeatherKitEnabledUITests` (Pass 22) is the same kind of harness: the physical Apple TV, the real
remote, and it photographs the Weather screen and the Home glance with WeatherKit data in them.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/WeatherKitEnabledUITests"
```
