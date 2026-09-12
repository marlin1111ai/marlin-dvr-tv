# COLD-START — Marlin DVR TV

## What the app is

Marlin DVR TV is a tvOS app (SwiftUI) and a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . What is built is listed under "What is built" below.

## Where things live

- This folder: `~/Xcode/Marlin DVR TV` — the Xcode project, the notebook (this file, DECISIONS.md, reports/), and the git repo. The only writable tree.
- Standing rules: `CLAUDE.md` at the project root — the builder's standing rules and a pointer to this notebook. Never project state; the notebook stays the record (DECISIONS.md, 2026-09-09 (Pass 57)).
- Repo: `git@github.com:marlin1111ai/marlin-dvr-tv.git` (branch `main`).
- Server reference clone: `~/Xcode/marlin-dvr-reference` — a read-only clone of marlin-dvr. Never edited, never pushed, never run from.
- Server URL: http://192.168.1.250:8090/ (Marlin DVR on Unraid). Not touched by this project's tooling.
- Approved design: `design/` — the Claude Design export (`Marlin DVR TV.dc.html`, Nocturne design system, `ATV-DVR.zip`). Read-only; never edited. The screens are built to it (DECISIONS.md, 2026-09-05 (design)).

## The rules

The standing builder rules live in `CLAUDE.md` at the project root. Read it. This file no longer keeps its own copy of them; a rule change is made in `CLAUDE.md` only (DECISIONS.md, 2026-09-09 (Pass 60)).

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

**The server is marlin-dvr 1.8.1** (Pass 72, 2026-09-12), and this one **is** measured from here:
`GET /api/status` answers `{"name":"marlin-dvr","version":"1.8.1",…}` — read in Pass 71 and read
again in Pass 72. It supersedes the **1.8.0** this file recorded on the owner's own Status-page
reading of 2026-09-08 (**VERSION 1.8.0, "up to date · checked 45m ago"**). Before that it was
**1.7.0**, which the owner
installed at **00:06 on 2026-09-08 from the app's own Status-page button**, an in-place update
rather than an Unraid image switch (marlin-dvr project, 2026-09-08). Three things this app depends
on:

- **`GET /api/library/trash` exists**, and Manage DVR → Trash is built on it (Pass 33). Landed in
  1.6.0 and carried forward.
- **Automatic pruning is gone server-side: a series pass never trashes anything on its own**
  (owner, 2026-09-07). Nothing reaches the trash unless a person put it there — from this app, from
  the web UI, or from the other Apple TV. The keep rule in the Edit series pass screen (Pass 9) no
  longer causes deletions by itself.
- **The single-file MP4 playback route exists** — `POST /api/play/sessions` with
  `"format":"file"`, served at `GET /api/play/file/{id}/video.mp4`. New in 1.8.0, and what
  recordings now play through (Pass 42, below).

**Their contract file is behind their server, and this matters to anyone reading it.**
`HLS-CLIENT-API.md` in the marlin-dvr repo is **byte-unchanged across the whole 1.8.0 delivery** —
Pass 41 ran `git diff --stat c417c60 095de81 -- HLS-CLIENT-API.md` in the reference clone and it
returned nothing. It still declares in its own header that it describes **1.7.0**, and its §2
request-body table at **line 68** states the opposite of the new behaviour: *"`"hls"` selects HLS.
Absent, `""` or `"mp4"` gives the old fragmented-MP4 pipe"* — `"file"` is not listed anywhere in
the file. Their `COLD-START.md` omits the route from its playback-route list too.
**§2.3 of `reports/2026-09-08-pass41-single-file-route-recon.md` is the only written description of
this route we have**, read from their Go source (`cmd/marlin-dvr/playfile.go`,
`cmd/marlin-dvr/stream.go`) at `origin/main`. Anyone building against the contract file alone will
be wrong about this route.

Note that the read-only reference clone at `~/Xcode/marlin-dvr-reference` now has a **checked-out
tree at 1.8.1** (`cmd/marlin-dvr/main.go:38`), and **`HEAD` and `origin/main` both read `eb0c098`**
(verified in Pass 72; `origin/main` read `095de81` before, and `c417c60` and `fba51f2` before
that), so their current sources and notebook can be read out of the clone directly, or with
`git show origin/main:<path>`. Server facts are still measured against the running server's own
responses and its `GET /api/logs`, never against the checkout.

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

Pass 24 (`reports/2026-09-06-pass24-rail-focus-recon.md`): rail focus recon, read-only, report
only — a stop-and-report at step 4, because one cause explained every failure. **Nothing in the app
had ever set rail focus.** `ScreenShell`'s `@FocusState focus` was read in two places and written in
none, `ShellFocus.content` was dead code, the rail had no `.defaultFocus`, and no last-selection was
stored anywhere, so on a swipe left tvOS picked the rail icon nearest the **vertical centre of
whatever the content had focused**. Measured on Home Theater over three identical rounds: of the ten
rail entries, nine open a screen with a rail to come back to, **2 landed on the right entry and 7 did
not** — and the two that worked (Favorites, Weather) were coincidences of layout, Weather by 1.5 pt.
A twelve-probe test proved the mechanism by walking the highlight down a screen's content and
watching the rail landing walk down with it, twelve out of twelve. Nothing was changed.

Pass 25 (`reports/2026-09-07-pass25-rail-focus-restore.md`): **the fix — swipe left lands on the
entry you came from, every screen, every time.** Twelve lines of behaviour in one file. Nothing new
is recorded, because the record already existed: `ScreenShell.screen` *is* the entry that opened the
content; only the restore was missing, and it is now `ScreenShell.railRestore`, fired on the crossing
from the content into the rail and never again, so Up/Down inside the rail still move freely. This is
what the design draws (`railFocused`, dc:1144-1149). **The declarative approach was tried first and
measured to do nothing**: `focusScope` + `prefersDefaultFocus(destination == current)` on the rail,
built and put on the Apple TV with no other change, reproduced Pass 24's table entry for entry — the
focus engine does not consult a scope's default-focus preference on a directional swipe into it. That
code was removed; `RailView.swift` is comment-only this pass. Verified on Home Theater with the real
remote: **all nine rail-drawing entries, three rounds, 27 of 27 correct** (Pass 24's 7 failures all
fixed, and the content focus in each case is the same one Pass 24 measured). Home still draws no
rail, asserted rather than assumed. The **periodic reloads do not steal or move focus** — On Now
(60 s) and Cameras (45 s) each watched with the remote parked in the rail and again with it in the
content, sampled every 5 s, with each screen's own subtitle proving the refresh actually happened —
and **one Player round trip** returns focus to the very card it left (same element, same frame) and
still lands on Cameras. `RailFocusRestoreUITests` is the harness and is committed.

Pass 26 (`reports/2026-09-07-pass26-guide-recon.md`): guide-data recon for the **server** project,
read-only, report only — does a server change to guide times affect this app? **No.** Nothing gates
live playback on guide data: a session is created from the channel id alone, the server treats a
missing programme as an empty subtitle rather than an error, and **Favorites lists and plays every
favourite channel whether or not the guide has a listing**, so a channel broadcasting through a
guide hole stays watchable. The app reads three guide routes and **never reads `span` or `empty`** —
the only two lines that touch a block read `block.program` — and the Guide screen has never rounded:
cells are placed and sized from `program.start`/`end`, absolutely positioned, so a listings gap
already draws as empty background. The precondition given was about **field shape, not times**:
`GuideBlock.title/.subtitle/.span/.isLive/.channelId` are non-optional in this app's decoder and
dropping any would fail the whole Guide screen.

**Corrections from the marlin-dvr project, received 2026-09-07 and recorded here rather than by
editing the landed report:** the change is their **Pass 42, not Pass 41** (Pass 41 stopped at its
first step and built nothing); **Pass 42 made no server-side change at all** — `/api/guide`, the
half-hour round-up at `guide.go:699` and the `span` values are byte-for-byte unchanged, and only
their own admin Guide page changed how it lays out what it receives. **Our field-shape clearance was
verified against their repo and stands** — every field present, non-optional, unrenamed, no
`omitempty`, with `channelId` still on the block as well as the row. Their **Pass 45** added
`GET /api/guide/find`, purely additive; **this app does not call it and needs nothing**. Their
Pass 42 also made the web UI's Watch Now render for any live non-DRM channel, matching what this app
already does. Three server changes are built and undeployed; the container still runs 1.4.0.

Pass 27 (`reports/2026-09-07-pass27-framestep-recon.md`): frame-step recon on paused recordings.
**`step(byCount:)` is inert on this app's HLS recordings** — `canStepForward` and `canStepBackward`
are both false, and forty step calls moved the playhead zero nanoseconds, in the server's copy mode
and its transcode mode alike. That measurement stands. **Its verdict does not**: the report concluded
frame stepping was unachievable, and Pass 28 overturned it. The report carries an addendum saying so.
Recordings are an HLS **EVENT** playlist, not VOD.

Passes 28 and 29 (`reports/2026-09-07-pass28-framestep.md`,
`reports/2026-09-07-pass29-framestep-fix.md`, **accepted by the owner on Home Theater 2026-09-07**):
**frame-by-frame on a paused recording.** The mechanism is an **exact seek** — `currentTime() ± 1/fps`
with `toleranceBefore` and `toleranceAfter` both `.zero`, which is what lands on the adjacent frame
instead of the nearest keyframe — never `step(byCount:)`. Pending seeks are cancelled first, each
step is computed fresh from `currentTime()` so it cannot drift, and play/pause is never touched.
**Left and right clicks only, and only while paused on a recording**; swipes never reach the code at
all, because a swipe is not a `UIPress`. Measured: **+0.033367 s per click on 29.97 fps material and
0.016667 s on 59.94 fps**, forward and backward, in both encode modes.

Pass 29 fixed the defect the owner found: each click was frame-stepping **and** being taken by Apple
as a 10-second skip, so five clicks banked 50 seconds. Claiming the press was never enough —
**`AVPlayerViewController` handles the arrow with its own gesture recognizers**, which run alongside
the responder chain rather than in it (proved on the device: every press reached `pressesBegan`,
none was forwarded to `super`, and Apple skipped anyway). `armArrowOwnership`
(`PlayerHost.swift:108-120`) disables exactly those recognizers — matched on the public
`allowedPressTypes`, never by class name — while the app owns the arrow, and restores precisely the
ones it disabled otherwise, including on `viewWillDisappear`. The transport bar is not suppressed:
it still draws, Select is still Apple's, and the arrows return to Apple on resume. Accumulation gone
(10 clicks = +0.334 s, resume advanced only by playback), and fast clicks 400 ms apart now step
perfectly. The frame rate comes from the video track, believed only when it lands within 5% of a
real rate (23.976 … 60) — a raw 28.00 reading on 29.97 material would have skipped a frame every
fifteenth click.

Pass 31 (`reports/2026-09-07-pass31-delete-refresh.md`, accepted by the owner on Home Theater and
pushed in Pass 34): **a deleted recording leaves the Recordings shelves without leaving the screen.** The owner's defect: delete an episode from show
detail, press Menu, and the shelves still showed the recording. Cause, and it is the whole of it —
`RecordingsModel.load()` was called from one place, the `.task` at `RecordingsScreen.swift:68`, and
that task is attached to the `Group` that holds *both* branches, so opening show detail never ended
it and backing out just re-rendered the snapshot taken when the screen first opened. Leaving
Recordings worked because `ScreenShell.swift:51` puts `.id(current)` on the content and rebuilds it.
The fix is `ShowDetailScreen.onLibraryChanged` (`:85`, fired at `:118`) → `RecordingsScreen.reloadShelves`
(`:158-168`), which re-reads `GET /api/library` **while show detail is still on top**, so the shelves
are right on their first frame rather than correcting themselves after. It is a re-read, not a local
edit: episode counts, the unwatched badge, shelf membership and the header totals are all the
server's, and `limit: 6` means one delete can pull a seventh show into view. Focus is repaired only
when the focused card is gone, and never when `focused` is nil, so a reload cannot pull the remote
out of the rail (Pass 25's property, kept).

**Proven on Home Theater with the real remote** (`DeleteRefreshUITests`, 49.9 s, 0 failures): the
shelves after backing out are **byte-identical** to the shelves on a fresh entry — same screenshot
MD5 — and no longer equal to the library as it stood before the delete. The delete is a **soft
delete**, measured rather than assumed: `roots[0].files` stayed at 5 across it and the recording is
in the trash with `exists: true`. No `GET /api/settings` read was made (not authorised).

**Pass 8 Open Question 11 is overturned.** It recorded that a show whose last episode is trashed
"stays in the library index with 0 visible episodes until the trash expires". It does not: `shows`
went 1 → 0 and all three sections went empty, at `limit=6` and `limit=500` alike. The card
disappears outright.

### KNOWN AND UNFIXED after Pass 29 — do not mistake these for proven, and do not re-derive them

- **Stepping is erratic near the end of the prepared range — VERY LIKELY closed by Pass 42, not
  proven.** Measured at **1:05:27 of a 1:11:10 recording**: forward clicking moved the clock
  *backwards* by 3 s and the per-second counts came out 6, 21, 30 instead of a flat 30. **It is not
  Apple** — the counters read `arrows=134 super=0 owns=true supp=2`, so every press was the app's.
  The suspect was the app's own seek-past-the-prepared-range restart in `timeJumped()`, and on the
  file route that restart **cannot fire**: its guard requires `!fullyPrepared`, and a complete file
  is fully prepared from the first tick. **But the suspect was always a suspect and never a proof,
  and nobody has watched the same spot in the same recording since**, so this is not recorded as
  fixed. If the real cause was something else in how exact seeks behave near the end, Pass 42
  changed nothing about it.
- **The recognizer-disabling fix depends on `AVPlayerViewController`'s internals.** It matches on a
  public property, but if a future tvOS changes how many arrow recognizers the player has or where
  they live, it quietly stops working. It **fails open** — back to Apple's skip and the old
  accumulation defect, not a crash. There is no public API to decline the transport's arrow handling.
- **Live playback was never driven on the device across Passes 28 and 29.** Tuning a channel takes a
  tuner and live was scoped out. It is unchanged by diff, and `frameStep` bails at its first guard
  when the item is not a recording.
- **Nobody has diffed two stills.** The evidence is a timeline moving by exactly one frame duration;
  no one has proved the *picture* advances one frame of motion rather than the clock alone.

Pass 32 (`reports/2026-09-07-pass32-cancel-and-restore.md`, accepted by the owner on Home Theater
and pushed in Pass 34): **item A built and proven; item B stopped at its gate and nothing was built
for it. Item B is now closed by Pass 33** — the server change it asked for shipped as 1.6.0.

**A — stop a recording from the Guide.** Hold a Guide cell that is recording and the airing sheet
now offers **Stop recording**, armed on the first click like Manage DVR's Cancel. The call is
`POST /api/schedule/jobs/{id}/stop` — the same one frame 6g makes, proven live in Pass 8 — and until
now 6g was its only entry point, reachable solely from a tuner-busy 502 on a live start, so a
recording started from the Guide could not be stopped from it. The button turns on `Job.status ==
"Recording"` and on nothing else, so it is absent before a booking, absent while Queued, and gone
once the recording is over; a pass's airing qualifies exactly as a Record Now does. On success the
sheet re-reads `GET /api/schedule` rather than editing what it holds (Pass 31's rule), which redraws
the Guide's ● marks at the same time. **The sheet also re-reads the schedule when it opens** — the
Guide refreshes only when the sheet writes, never on a timer, so a booking that had since started
recording would otherwise still read Queued and Stop would not appear.
**Proven on Home Theater** (`StopRecordingUITests`, 42.4 s, 0 failures): booked *Midday Maryland* on
2.1 from the Guide, reopened the sheet, armed, confirmed — the sheet read
`Recording stopped · STOPPED · stopped by owner`, the Stop button went, and the server agreed
seconds later (`GET /api/schedule` → `rec-mtrfm5v9d1fd63` **STOPPED**; the 7.66 MB partial in the
library). One click alone never sends anything, asserted.

**B — the trash list. STOP AND REPORT, per step 5: the server exposed no trash listing.**
**Superseded — this is history now**: 1.6.0 added `GET /api/library/trash` and Pass 33 built the
screen on it. Kept because it records what the API looked like before. Measured read-only that day,
not inferred: `GET /api/library/trash` 404, `GET /api/trash` 404,
`GET /api/library/recordings?trash=1` 404, `GET /api/library/shows` 404, and `GET /api/library?trash=1`
returns **bytes identical** to `GET /api/library`, so the parameter is ignored. The only trash-aware
read is per show and needs an id you already hold — and Pass 31 measured that a show whose last
episode is trashed leaves `GET /api/library` entirely, so the app cannot learn that id at all. It is
undiscoverable, not merely awkward. Caching ids the app has seen would miss anything deleted from
the web UI or the other Apple TV, and is the workaround step 5 forbids. **`ManageDVRScreen.swift`
and `TrashManageView.swift` are untouched by diff**, Restore is still unexercised live, and the
unblock is a server change for the marlin-dvr project: one read, `GET /api/library/trash`.

**Note on the brief:** step 1 asked for the server side "per HLS-CLIENT-API.md and the reference
clone" while the same prompt put the reference clone on ABSOLUTE DO-NOT-TOUCH. The do-not-touch list
was taken as the stronger instruction; **neither the clone nor `HLS-CLIENT-API.md` was read**, and
every server fact in the report rests on this app's typed calls, the notebook's recorded citations,
Pass 8's live evidence, or read-only probes of the running server.

### KNOWN AND UNFIXED after Pass 33 — do not mistake these for proven, and do not re-derive them

Everything in this list survived the owner's Home Theater acceptance of Passes 31–33. None of it is
a regression; it is what those passes deliberately did not reach.

- **CLOSED by Pass 49 — the airing sheet's series-pass chip being wrong for a pass-driven
  recording.** A recording a series pass had started showed **"Record this airing" alongside "Stop
  recording"**, and pressing it would have earned a 409 from the server. **What the defect actually
  was:** the sheet asked whether a *series pass* existed instead of asking the *airing's own job*
  what state it was in — Stop turned on `Job.status == "Recording"` and correctly ignored `passId`,
  while the chip and the Record button were gated on `passId == "manual"`, so a pass-driven job fell
  through to the Record button while Stop was simultaneously offered. Found in Pass 32, scoped out
  there and in Pass 33, fixed in Pass 49. **Note that this entry's own citation had drifted:** it
  read `manualJob :71-74`, and the property was in fact at **`:70-73`** when Pass 49 re-read it.
- **Stopping a pass's airing has never been exercised on the device.** Only the one-off Record Now
  case was. The code path is identical and deliberately not gated on `passId`, but that is reasoning,
  not evidence.
- **Old-form (pre-1.6.0) trash entries are untested and now untestable.** Pass 33 proved Restore for
  the 1.6.0 form only — a file the server moved to `DVR/Trash/`. The owner's four old-form
  recordings were deleted before they could be used (see below), and 1.6.0 always moves the file, so
  no old-form entry can be made again. Whether the server's Restore handles a file that never moved
  is **server behaviour no client change can affect**.
- **The id rule is an inference, not a proof.** "A recording's id is derived from its file path, so
  it changes when the file moves into the trash and changes back on restore" rests on **two files,
  three cycles each**, plus the server's own log line `id X -> Y`. It held every time and the
  trash-time id was identical on each cycle, but the sample is two.
- **Resume survival was reasoned, never watched.** That a resume position survives a trash-and-restore
  follows from the id round trip plus `ResumeStore.clear` having exactly one call site
  (`PlayerModel.swift:449`, end-of-playback). **Nobody has watched a "22 min in" label survive one.**
  Neither Pass 33 subject had a resume entry.
- **`trashedAt` does not update when the same file is trashed a second time.** Measured across three
  trash/restore cycles on one recording (Pass 33): the listing kept reporting the *first* trashing.
  The app shows what the server says. A marlin-dvr matter; nothing was changed here.
- **Stepping is erratic near the end of the prepared range** — still open, unchanged since Pass 29.
  See the first entry under **KNOWN AND UNFIXED after Pass 29** for the measurement and the suspect.

Pass 33 (`reports/2026-09-07-pass33-trash-restore.md`, accepted by the owner on Home Theater and
pushed in Pass 34): **the Trash screen reads the new endpoint, and Restore is proven live for the
first time.**

**The server's `GET /api/library/trash` (1.6.0) is real and matches what was announced.** All eight
fields (`id`, `show`, `episodeTitle`, `season`, `episode`, `aired`, `trashedAt`, `size`) on every
row, always present — `""` and `0` rather than omitted. Two facts the announcement did not carry:
the rows come **wrapped** as `{"count": N, "recordings": [...]}`, and **`trashedAt` has nanosecond
precision**, which `ISO8601DateFormatter` refuses at every option (`ServerTime.date` in
`Formatting.swift` drops the fraction first). **Empty is `{"count":0,"recordings":[]}`** — `[]`, not
`null`, measured. The endpoint takes **no parameters**: `limit`, `show`, `trash`, `q` are all ignored
and the whole list comes at once.

**`ManageModel.refreshTrash` is one read now**, and `TrashItem` is its own eight-field type — not
`Episode`, which has 28 and whose `showId`/`file`/`thumb` cannot exist for a recording whose show has
left the library. **The per-show `?trash=1` read no longer returns trashed episodes at all** under
1.6.0 (measured: it returned the Henry Winkler episode at 12:03 and 0 episodes at 20:52), so the old
Pass 10 walk would now show an empty Trash **even for a show still in the library**. The rebuild was
the only thing that still works, not an optimisation.

**Restore works, proven on Home Theater** (`TrashRestoreUITests`, 83.3 s, 0 failures): two recordings
restored from the list, both back in the library and **on the Recordings shelves**, the list dropping
each one as it went and the hub falling to "empty". This closes "Restore is wired but never exercised
live", which had stood since Pass 10.

**The recording id CHANGES while a recording is in the trash** (new in 1.6.0, because the file moves):
`b7a3822d83b4 ⇄ 3ded51f52f76`, `eccf81dbdab2 ⇄ eda86144bf38`, deterministic and exactly reversed by
Restore. The server logs the swap itself. **`ResumeStore` therefore survives a restore** — its key is
the library id, which comes back — but the entry is unreachable while the recording sits in the trash.
`ResumeStore.clear` is called from one place only, `PlayerModel.swift:449` at end-of-playback, so
nothing in the trash path deletes it.

**Fixed on the way:** restoring the *last* recording in the trash used to trap the user on the screen —
rows gone, Empty Trash disabled, so nothing could take focus and Menu left the app instead of reaching
`.onExitCommand`. The empty-state sentence is focusable now and holds the `"empty"` focus id. Present
in the Pass 10 code too; nobody had ever emptied the trash from the Apple TV.

**Corrections from the marlin-dvr project, received 2026-09-08 and recorded here rather than by
editing the landed report:** Pass 33's finding that **"the per-show `?trash=1` read no longer
returns trashed episodes at all" is wrong as to cause.** The symptom was real; the explanation was
not. **The per-show read still returns trashed episodes** — `GET /api/library/shows/{id}` still
takes `?trash=1` (`library.go:609`), still keeps exactly the episodes whose trash flag matches the
request (`library.go:626`), and still answers with `showingTrash` (`library.go:659`). What Pass 33
actually hit is one route earlier: **`GET /api/library` builds its show list with
`showSummaries(false)`, which skips a trashed recording *before* it creates that show's entry**
(`library.go:409`), so a show whose recordings are all trashed never appears in the library and
**its `showId` cannot be learned from anywhere** — and the per-show read needs that id in its
path. Same symptom, different cause: not a read that stopped answering, but an id that cannot be
discovered to ask it with.

**Pass 34's decision is unchanged.** Trash is built on `GET /api/library/trash` and stays there. The
per-show walk was rejected on the undiscoverable-`showId` grounds *as well as* on the cause now
corrected, and this correction confirms that ground rather than weakening it — the server's own
source says the same thing at `library.go:689-693`. **Nothing in the app changes.**

**`GET /api/library/trash` landed in their `b98a4a2`** ("Pass 61: GET /api/library/trash — list
every trashed recording", 2026-09-07), which is **after both refs this project's clone held** —
its checkout `9325d94` and the `fba51f2` it had already fetched — so no ref available to Passes
32-35 could have shown the endpoint. Verified in the clone with `git merge-base --is-ancestor`.

### THE OWNER'S FOUR TRASHED RECORDINGS ARE GONE — do not go looking for them

**At 20:51:50 on 2026-09-07 a `POST /api/library/trash/empty` from the owner's own web-UI session
permanently deleted all four** — 3.80 GB freed, 0 failed, per the server's own log. **Not this
project**: every non-GET request logged from the server's 20:36:52 start until that moment was the
owner's browser, and Pass 33 sent no POST/PUT/DELETE before 21:09.

- **`6007a13f0b46`** (Hazardous History With Henry Winkler S2 E20, 1.86 GB), tracked here since
  Pass 31 as the unreachable trashed recording, **no longer exists**. The Pass 31/32 entry about it
  is closed by deletion, not by a fix.
- The server's delete log names every path: all four were `/mnt/unas4pro/DVR/<Show>/<file>.mpg`,
  **still in their original show folders** — the pre-1.6.0 form. **That form can no longer be
  produced**, since every trash under 1.6.0 moves the file to `DVR/Trash/`. So Pass 33 could test
  the **new form only**, and the old form's Restore path is server behaviour no client change can
  affect.

- **Pass 32's two leftovers are back in the library and clean**: `midday-maryland` `b7a3822d83b4`
  (7.66 MB) and `the-view` `eccf81dbdab2` (275.92 MB). The owner authorised trashing and restoring
  **these two ids only** for Pass 33's evidence, and both were restored to their original ids and
  paths. The trash is empty and the pass left nothing behind.

Pass 37 (`reports/2026-09-08-pass37-commercial-skip-recon.md`): commercial-skip recon, read-only,
report only. It answered whether the app as it stood could draw a prompt over running playback
(yes — `RecordingHUD` already does, auto-hidden by `showHUD(for:)`), which press could answer it
(none is unowned, but `armArrowOwnership` is a proven claim-and-return machine), how a break would
be noticed (`tick()`'s `position` already implements §10.4's `edlTime = playerPosition + start`),
how to jump (the in-item exact seek, not `restart(at:)`), where the duration comes from, and which
two §10 fields would break a strict decoder. `~/Desktop/marlin-dvr-context/` vanished mid-pass and
its §2.2 question went unanswered; **Pass 38 closed it** from §3 of the contract.

Pass 38 (`reports/2026-09-08-pass38-commercial-skip.md`, **accepted by the owner on Home Theater
2026-09-08 and pushed in Pass 39**): **commercial skip.** A recording plays, playback reaches the
start of a break, a small prompt appears bottom-right for five seconds saying the break can be
skipped, SELECT jumps to the end of the break, and pressing nothing lets the commercial play.

- **`CommercialSegments.swift`** is the decodable for `GET /api/library/recordings/{id}/commercials`
  (contract §10) and the one call. Two decodings depart from this app's strict habit **because §10
  says to**: `edl` is optional (`:397`, `omitempty`, and §10.5 says its absence is the ordinary
  case), and **`state` is decoded as a `String` and mapped, never as a `Decodable` enum**, because
  §10.3 (`:410`) says to treat any unrecognised value as `"unknown"` rather than throw.
- **Only `state: "detected"` arms anything.** A `"none"` from an `m3u` source is a real answer and
  shows nothing ever; a `"none"` from anything else — and `unknown`, `running`, an unrecognised
  value, a transport failure or any non-200 — also shows nothing. That is the ordinary outcome for
  most of the library and it is deliberate.
- One fetch per playback from `attach()`, never repeated, never polled. Breaks are noticed on the
  **existing** 1 s periodic observer; no second observer and no boundary observer was added. Each
  range prompts at most once per playback, including after seeking backwards into it.
- The skip is the app's **existing in-item exact seek** with `frameStep`'s clamp plus a clamp against
  the recording's duration. **Not `restart(at:)`** — no session is torn down, no Starting screen,
  and play/pause is never touched.
- **`PlayerHost.armSelectOwnership`** is the exact counterpart of Pass 29's `armArrowOwnership`:
  while and only while the prompt is up, the player's own Select recognizers are disabled — matched
  on the public `allowedPressTypes`, never by class name — and precisely those are restored, on
  dismissal, on a skip, on a pause and in `viewWillDisappear`. Measured on the device every single
  arming: **5 Select recognizers, 0 of them also arrow recognizers.** The prompt itself is **not
  focusable**; no focusable view has still ever been placed over a running player in this app.

**Proven on Home Theater** on the owner's Philo recording of *History's Greatest Mysteries* S4 E14
"Who Is D.B. Cooper?" — the recording §10.2's own example is drawn from — which the server reports
**4 breaks** for (`176.54-206.54, 305.57-371.54, 730.56-925.46, 1271.20-1478.54`): the prompt
appeared **0.27 s** after a break's own start second; Select landed on `endSeconds` **exactly**
(`t=206.540000` and `t=925.460000`); pressing nothing timed the prompt out at 5 s and played the
break; a break already offered was never offered again even after seeking back into it; a pause took
the prompt down and handed Select back; and frame stepping was unchanged at **0.033367 s a click**.
Recordings the server answers `"unknown"` or `"none"` for showed nothing at all across twenty
forward skips.

**Two things the pass found and did not paper over.** comskip's first break on that recording is
exactly 30.00 s — one advert out of a longer pod — so a skip that lands precisely on `endSeconds`
lands in the middle of the next advert; that is the server's detection, not the app's arithmetic.
And the end-of-recording clamp, the `hdhomerun` `"none"` branch and the network-failure branch were
**never exercised live** — the owner's library holds only m3u recordings and no break came near the
end of a file.

Pass 39 (`reports/2026-09-08-pass39-three-defects-recon.md`) reconnoitred the owner's three named
defects read-only and fixed none of them; its sorting stands. Note that **the report file was left
untracked by Pass 39 itself** — commit `424c584` carried only `COLD-START.md` and `DECISIONS.md`,
verified in Pass 41 by `git ls-files reports/ | grep -c pass39` returning `0`. **It is committed and
pushed now**: Pass 44 committed it unmodified in `6fee5b5`, verified on `origin/main` at `f167663`.

Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) was left untracked the same way and
**is committed and pushed now**: Pass 44 committed it unmodified in `6fee5b5`, verified on
`origin/main` at `f167663`. **Pass 44 opened it**, to run the mandatory credential scan before
committing it to this public repo; nothing was found and its contents were not edited.

Pass 41 (`reports/2026-09-08-pass41-single-file-route-recon.md`): read-only recon of the server's
new single-file MP4 route against this app's Player, report only. It established the route from
their Go source because their contract does not document it (above), named ten points where the
route's real behaviour differs from the summary this project had been given, and wrote the build
plan Pass 42 was built from.

Pass 42 (`reports/2026-09-08-pass42-single-file-route.md`, **accepted by the owner on Home Theater
2026-09-08 and pushed in Pass 43**): **a recording plays as one complete, seekable MP4 instead of a
growing HLS playlist.**

- **What it does.** The app asks the server to remux the whole finished recording with `-c copy`
  into one faststart MP4 and serve it with byte ranges, instead of joining an HLS EVENT playlist
  the server is still writing. The file is complete before a byte is served, so its whole length is
  seekable from the first second.
- **Recordings take this route; live TV, cameras and radio do not.** The choice is made at exactly
  one line — **`PlayRequest.swift:49`, `case .recording: return "file"`** — and every other kind
  returns `"hls"` from `:48` and `:50` of the same switch. That value reaches the wire at
  **`PlaybackSession.swift:70`**, the app's only `POST /api/play/sessions` construction site.
  Radio needs no branch at all: it never creates a play session (`RadioStation.swift:31`,
  `RadioPlayer.swift:10`).
- **The app now reads the response's `format` field, which nothing read before**
  (`PlayerModel.swift:176-181`, called at `:135` and `:765`). The server's own `format` switch has
  no `default` arm, so a server that does not know the format answers **200** with the old
  unseekable pipe and only that field says so. The check fires only when `"file"` was asked for, so
  the HLS path is untouched.
- **The first fetch for a file session is `Range: bytes=0-0` on its own `URLSession`**
  (`PlaybackSession.swift:114-128`, session at `:24`, built `:50-54`) with an **11-minute** timeout
  (`:37`), above the server's own 10-minute remux ceiling. It never buffers the file.
- **Proven on Home Theater**: the request carried `"format":"file"`, the response returned
  `"format":"file"` with `/api/play/file/<id>/video.mp4`, the first fetch answered **206**, the
  keep-alive answered 206 throughout and never 410, commercial skip was unchanged and landed
  **exactly** on the break's `endSeconds`, and the DELETE was accepted. Captured with a
  disclosed three-line diagnostic that was then fully reverted; the reverted build was reinstalled
  and re-run and still took the file route.
- **Steps 1–6 of the Pass 41 build plan were built. Step 7 was not** — it is conditional on that
  report's open question 7.2, which is unanswered, and the builder stopped rather than choosing.

**What this route costs, as measured or traced facts:**

- **The remux wait moves to the front of playback.** Playback cannot begin until the server has
  rebuilt the file; in exchange, the whole recording is seekable once it does. The marlin-dvr
  project measured 2.4 s / 11 s / 26 s for 8-minute / 43-minute / 1 h 42 m shows **on marlinpc**,
  and states in its own Pass 85 report that this does not hold for Unraid. **It has never been
  measured on the Unraid box this app talks to.**
- **A recording still being written is refused outright**, with a 502 and the server's text "this
  recording is still in progress — it can be played when it finishes". The HLS route used to play
  whatever had been written so far. **Not exercised on the device** (Pass 42 §4d).
- **A recording that is not H.264/AAC is refused outright**, with a 502 and "this recording is not
  H.264/AAC, so it cannot be remuxed without re-encoding — use the HLS route for it". **Not
  exercised on the device** (Pass 42 §4d). Neither refusal is routed back to HLS.
- **Nothing on screen distinguishes the wait from a stall.** The Starting screen (frame 6a) shows
  "Preparing the recording" and an indefinite pulse bar, unchanged by Pass 42.

**The audio/video desync on recordings is untouched by any of this and is still open with the
marlin-dvr project.** Pass 39 sorted it NOT OURS — every parameter, setting and seek in this app
was inventoried and none can shift audio against video — and Pass 42 changed nothing about it. No
client-side compensation has ever been built for it, and none is to be.

**The state of the record after Pass 42's device runs:** two runs left a **resume position deep
inside the owner's *History's Greatest Mysteries* S4 E14 "Who Is D.B. Cooper?" recording** — from
1206 s to past 1484 s, plus 40 forward skips on the second run. It is per-Apple-TV and playing the
recording to its end clears it. Because of it, `CommercialSkipUITests/testPromptAppearsAndSelectSkips`
will keep failing until it is cleared: all four of that recording's breaks end at 1478.54 s, so a
session resuming past that can never reach one. That is a harness precondition, not app behaviour.

Pass 46 (`reports/2026-09-08-pass46-shelf-focus-clipping-recon.md`): read-only recon of a defect the
owner reported — on the Recordings screen, a focused poster card in the "Recently Watched" shelf had
its **top edge cut off**, with the bottom and sides intact. Report only; nothing changed.

Pass 47 (`reports/2026-09-08-pass47-shelf-focus-fix.md`, **accepted by the owner on Home Theater
2026-09-08 — "good to go" — and pushed in Pass 48**): **the focused poster card grows its real
layout box instead of being scaled, and nothing clips.**

- **What was wrong.** The card was enlarged by `scaleEffect(296.0/252.0, anchor: .center)`, a
  **render transform that changes no layout**, so it grew about its centre and threw roughly **38 pt
  upward** on top of the existing 22 pt lift — about **60 pt of overhang into the 44 pt** that
  `.padding(.vertical, 44)` (`RecordingsScreen.swift:127`) provides. The horizontal
  `ScrollView` at **`RecordingsScreen.swift:114`** clips its content by default, and
  `.scrollClipDisabled()` appears nowhere in the app, so the excess was cropped. Only the top
  suffered because the `-22` offset pulls the card away from the bottom edge and does nothing
  sideways (Pass 46 §2.5).
- **What was done.** The card now takes the two sizes `design/` specifies rather than being scaled.
  Three lines:
  - **`RecordingsScreen.swift:196`** — `.frame(width: focused ? 296 : 252, height: focused ? 404 : 344)`
  - **`RecordingsScreen.swift:222`** — `.frame(width: focused ? 296 : 252, alignment: .leading)`
  - the `scaleEffect` was **deleted**, not left alongside.

  `dc:1273` gives the two states as `w: 296 : 252, h: 404 : 344, lift: -22 : 0`, and `dc:382-383`
  applies them as the container's `width` and the art's `height`. The 4 pt accent ring (`dc:1275`),
  the shadow (`dc:1274`) and the `-22` offset already matched the design and are unchanged.
- **The arithmetic that now holds.** `HStack(alignment: .top)` (`:115`) aligns children by their
  layout tops, so the bigger box grows **downward** and the only upward displacement is the lift:
  **22 pt of overhang against the 44 pt budget**, clearing by a factor of two. **The card-height term
  is gone entirely** — the overhang no longer depends on `H` at all — so Pass 46's threshold, "it
  clips whenever the card is taller than 252 pt", **no longer applies at any card height**. The
  bottom gains clearance (66 pt) and the sides cannot overhang at all, because the growth is now
  inside the layout box.

**Two behaviours that are now true and were accepted — not defects:**

- **The row reflows sideways.** The focused card's box is 44 pt wider (252 → 296), so cards to its
  right shift right as focus moves along the shelf. **The owner was told this before choosing** the
  approach and accepted it (owner, 2026-09-08).
- **The shelves below shift down 60 pt while a card is focused.** The focused card's box is 60 pt
  taller (344 → 404) and `HStack` takes its tallest child's height, so the shelf, the scroll content
  and everything under it grow with it. **The owner was told this after Pass 47**, not before
  choosing, and accepted it (owner, 2026-09-08). Both behaviours are `design/`'s own — `dc:383` makes
  the focused art `404px` and a flex row grows with it.

**The title and episode count no longer enlarge on focus.** The old `scaleEffect` enlarged the whole
card including its text; the design does not. `dc:389` fixes the title at 26 px and `dc:390` the
count at 23 px **in both states**, and the app now matches. This is a deliberate consequence of
dropping the scale, not an oversight.

**What the device test did and did not establish** (Pass 47 §5). It **did** establish that shelf
focus navigation survives a card whose layout box changes on focus: on Home Theater, against the
binary built in that pass, the shelves were reached, the harness delivered eight `.left` presses to
the shelf, focus read as a poster card, `.select` opened its show, and the whole run passed in 128 s.
It did **not** establish traversal across several reflowing cards — `openShow` reads focus *before*
each `.right` and matched on its first read, so **zero `.right` presses were sent**. **Multi-card
traversal on the reflowing shelf is untested, not known to work.** No claim was made about how any
of it looks; that was the owner's acceptance to give.

Pass 49 (`reports/2026-09-08-pass49-airing-sheet-record-button.md`, **accepted by the owner on Home
Theater 2026-09-08 — "all good" — and pushed in Pass 50**): **the Guide airing sheet's first control
reports the airing's own state instead of always offering to record it.** This closes the first entry
under **KNOWN AND UNFIXED after Pass 33** above.

- **What the owner decided, and why the control is never hidden.** A series pass covers a **show**,
  not every airing: if the pass is not picking an episode up, hiding the button would leave no way to
  record it (owner, 2026-09-08). So the control is always in its slot and becomes a status indicator
  only when the airing itself has a state:
  - recording right now → **"● Recording"**, not pressable
  - booked but not started → **"● Scheduled"**, not pressable
  - neither → **"Record this airing"**, pressable, behaving exactly as before
- **Where it is.** `AiringSheet.swift` — `AiringState` and `airingState` at **`:81`, `:83-88`**
  (replacing the old `manualJob`, which was removed rather than left as dead code), the three-way
  control at **`:251-256`**, and `firstFocusID` at **`:186`**, which had to follow the state or the
  sheet would open trying to focus a `"record"` control that no longer exists in two of the three
  cases. **The two status states are not focusable**: `StateChip` (`:447-475`) is a plain `VStack` of
  `Text`s with no `Button`, no `.focusable()` and no `.focused()`, so the focus engine never offers
  it. **"Edit series pass", "Watch live" and "Stop recording" are byte-identical** in label,
  behaviour, condition and position, as is the amber series-pass line.
- **The state comes from data the app already held — no new request and no new model field.** It is
  `Job.status` (`Models.swift:170`), the same field `recordingJob` (`:79-82`) already used for
  `job.status == "Recording"`, taken from the `GET /api/schedule` read the sheet already performs
  when it opens (`:154`, for the reason given at `:149-153`). `passId` is deliberately no longer
  consulted. The statuses are read exactly as the Guide's own marks read them
  (`GuideScreen.swift:173-178`), and **`GuideScreen.swift` was not changed**.

**The limit of the evidence, recorded as a limit and not as working.** Only the **unbooked** case was
proven on the device, by the write-free `RemoteHoldUITests` hold, which opened the sheet and found a
pressable "Record this airing" — a real assertion, since a job would have rendered a chip instead.
**The "Recording" and "Scheduled" branches were code-traced only.** Reaching them needed either a new
harness file or `StopRecordingUITests`, which books and stops a real recording on the owner's DVR;
neither was done, and the airing the owner photographed had stopped recording hours earlier. **The
owner accepted both branches by eye on Home Theater on 2026-09-08.**

**Two behaviours recorded so nobody later reads them as defects:**

- **A pass-scheduled airing shows a green "● Scheduled" chip where the Guide grid shows gold
  "◆ SERIES PASS".** Same meaning — it will record — and the amber series-pass line under the buttons
  still says it is a pass. A gold chip would have been a **fourth** state the owner did not ask for;
  he specified three. Raised with him and left as built (owner, 2026-09-08).
- **An airing whose recording has finished, failed or been stopped now offers "Record this airing"
  again.** Under the old gating a manual job in a terminal state still drew "● Scheduled", which was
  wrong. It is **correct by the owner's rule** — such an airing is neither recording nor scheduled —
  and it is beyond the symptom he reported.

**The chip's appearance is carried over, not design-specified.** `design/` frame 5c draws its button
row at **`dc:568-572`** as three pressable controls — "Record this airing", "Record the series",
"Watch live" — and **specifies no status label of any kind**. `StateChip` keeps the shape and
typography it has had since Pass 8, which the owner accepted on Home Theater in Pass 9.

Passes 51–55 (`reports/2026-09-08-pass51-tvos-icon-recon.md`, `…pass52-icon-layer-probe.md`,
`…pass53-icon-wire-in.md`, `…pass54-bedroom-install.md`, `…pass55-push-and-handoff.md`):
**the app has a real icon and Top Shelf art**, accepted by the owner on Home Theater 2026-09-08.

**Three independent proofs it is genuinely in the product** (Pass 53 §6). **Pass 51 §5 found the
bundle had none of this** — no `Assets.car` at all and no icon key of any kind:

- **`Assets.car` is now in the built bundle** — 12,683,304 bytes (simulator), 9,369,752 (device).
- **The built `Info.plist` declares it**: `CFBundleIcons` → `CFBundlePrimaryIcon = "App Icon"`, plus
  `TVTopShelfImage` → `TVTopShelfPrimaryImage` and `TVTopShelfPrimaryImageWide`.
- **`xcrun assetutil --info` over that `Assets.car` shows all four slots** — `App Icon/Front/Content`
  and `App Icon/Back/Content` at 1x and 2x, `App Icon - App Store` at 1x and 2x, and both Top Shelf
  images at 1x and 2x — together with the `ZZZZFlattenedImage` and `ZZZZRadiosityImage` entries
  `actool` only generates from a real layered stack.

**Where the artwork is, and what changed.** The owner supplied it as a **complete
`AppIcon.brandassets` catalog**, structured, at `icon-source/Assets.xcassets/`. **It needed no
repair**: every file its manifests named existed, every real dimension matched its declared scale,
no layer was empty, and `actool` accepted it with no error, warning or note (Pass 53 §3–§4). It was
copied byte-identical into `Marlin DVR TV/Assets.xcassets/AppIcon.brandassets/` (19 files, verified
with `diff -r`). **The only project change was two lines** — his folder is named `AppIcon` while the
setting still pointed at the empty template's longer name, so
`ASSETCATALOG_COMPILER_APPICON_NAME` became `AppIcon` in both configurations
(`project.pbxproj:313`, `:345`).

**Measured facts about tvOS icons — do not relearn these** (Pass 52, from `actool`'s own output):

- **A tvOS app icon stack needs at least 2 of its 3 layers populated**, in Apple's words:
  *"The image stack "App Icon" must have at least 2 layers with applicable content. Although it has
  3 layers, only 1 has applicable content."* One layer is an error; two and three compile clean.
- **Zero populated layers is silently accepted** — which is exactly why this app built happily with a
  wholly empty catalog for fifty passes.
- **`actool` exits 0 while printing that error** and still writes an `Assets.car`. **The structured
  `com.apple.actool.document.errors` section is the signal, not the exit status.**
- **There is no per-layer transparency rule.** All-alpha, all-opaque, opaque-back under alpha fronts
  and the reverse all compiled with no diagnostic mentioning alpha.
- **The rule fires only on the small 400×240 `tv`-idiom stack.** The App Store slot was accepted with
  one layer and with none, isolated in its own run. `CFBundlePrimaryIcon` is emitted only when the
  small stack has content.
- **The `tv-marketing` App Store slot does take a 2x at 2560×1536** (Pass 53 §4.3), with no
  diagnostic. **This corrects Pass 51's "1x only" reading**, which was true of Xcode's `tv`-idiom
  template slot but not of the owner's `tv-marketing` one.

**Known and deliberate — not defects:**

- **Both icon stack layers point at the same two files** (`AppIcon-400x240.png`,
  `AppIcon-800x480.png`), and those are opaque, so **the focus depth effect has nothing behind to
  reveal**. This is the owner's choice for now (owner, 2026-09-08) and was left exactly as supplied.
- **The artwork says "MARLIN TV" while the app is "Marlin DVR TV".** The owner decided on 2026-09-08
  that this is fine. **It is not to be raised again.**
- **`FocusClick.dataset` came with the catalog and was deliberately not added.** It is a 4,100-byte
  `focus_click.caf` sound asset; **no Swift source references `FocusClick` or `focus_click`**
  (`grep -rn` over every `.swift` returns nothing) and no pass has asked for it. It stays in
  `icon-source/`, untouched.
- **The empty template `App Icon & Top Shelf Image.brandassets` is still in the project catalog**,
  unused now that the setting points at `AppIcon`. Pass 53 §4 proved it harmless — `actool`'s output
  is **byte-identical** with and without it — and left it alone.

**`CFBundleIconName` is an iOS key and is correctly absent on tvOS.** Pass 51 checked for it and
Pass 53 checked again; both found it missing, and that is right. tvOS declares its icon through
`CFBundleIcons`/`CFBundlePrimaryIcon` and `TVTopShelfImage`. **No later pass should hunt for it.**

**The app is installed on a second Apple TV.** Pass 54 installed HEAD `0b3589d` on
**"Master Bedroom ATV"** (Apple TV 4K, `AppleTV6,2`, tvOS 26.6) — the only reachable tvOS device
other than Home Theater. The binary is **byte-identical** to Home Theater's
(`sha256 acde806…`); only the asset catalog was re-thinned for that model. **It is a
development-signed build and will stop launching when the provisioning profile expires. When that
is has not been checked and is unknown.**

Passes 62-65 (`reports/2026-09-11-pass62-guide-search-recon.md`,
`reports/2026-09-11-pass63-guide-search.md`,
`reports/2026-09-11-pass64-keyboard-layout-probe.md`,
`reports/2026-09-11-pass65-searchable.md`, **accepted by the owner on Home Theater 2026-09-11 —
"all good" — and pushed in Pass 66**): **the Search screen.** Type a programme title on the Siri
Remote and the guide is searched as you type, with the results on screen the whole time; click one
and the airing sheet opens on it with every control live.

- **It is the eleventh rail entry, directly under Radio and above the Manage DVR bottom slot, and
  it has no Home tile** (owner, 2026-09-11). The design draws no search at all — its own header
  says "No search" (`dc:38`) — so the screen is built to the app's look, the sixth to take that
  route. The 3 × 3 Home grid is unchanged. Pass 62 worked out from Pass 24's measured frames that
  an eleventh rail entry *ought* to fit and asked for a photograph before anyone relied on it;
  **Pass 63 took it** — eleven entries and the two-line footer all inside the frame.
- **Two reads, and the second one is the point.** `GET /api/guide/find?q=` answers the typing:
  case-insensitive substring on the **title only**, over every airing whose end is still in the
  future, at most **20** rows with the true total in `count`. Its rows are thin display rows and
  cannot rebuild either type the sheet needs, so clicking one reconstitutes the airing from
  **`GET /api/guide/search?title=`** — **never from `GET /api/guide`**, whose block builder rounds
  to whole half hours and silently drops about **3 %** of listings (the marlin-dvr project's own
  measurement, recorded by them as known and not being fixed). An airing `/api/guide` drops is one
  the Guide screen cannot show either, so search would have been the only route to it and the one
  route that failed. `/api/channels` supplies the `MergedChannel` and `/api/schedule` the job.
  **`GuideSearchMatch` is the new decoder**, strict on every field, taking the embedded `Program`
  from the same container the way `GuideNowItem` and `GuideRow` already take `MergedChannel`.
- **DRM results are filtered out silently**, per the standing rule. Both routes walk
  `a.channels(false)`, which carries DRM channels, so the rule is applied client-side like every
  other shape in `ChannelFilter.swift`.
- **"Showing the first 20 of 704 matches · type more of the title to narrow it"** — both numbers
  the server's own, taken before the DRM filter, so the line describes the search and not the
  list. The cap is not pageable; typing more is the only way past it.
- **A query and its results survive a trip to the rail**, which needed the model to be owned above
  `ScreenShell` like `HomeModel` and `WeatherModel`, because `ScreenShell.swift:51` destroys the
  screen on every visit.
- **The input is tvOS's `.searchable`, not a hand-built `TextField`** (owner, 2026-09-11, after
  the Pass 64 probe). A plain `TextField` was **measured** as a full-screen takeover that blurs
  the app out of sight — and pinning it to the top of the screen changes nothing, which Pass 64
  photographed. `.searchable` draws a field and a one-row alphabet strip about 66 pt tall at the
  top and leaves everything below on screen and reachable. No `NavigationStack` is needed.
  UIKit's `UISearchController` was the third candidate and lost on behaviour: contained directly
  it draws but cannot be focused at all, and inside a `UINavigationController` it works but
  dismisses the keyboard the moment focus enters the results.
- **The sheet-close focus rebuild is load-bearing and has been measured twice.** Writing the row's
  id into `@FocusState` after the sheet closes does not move the focus engine; a `generation`
  counter that rebuilds the content subtree does. **Pass 65 removed it rather than assume
  `.searchable` had changed anything, and the device answered `focused=[]` — the identical Pass 63
  failure — so it went back in.** Do not remove it a third time without the device saying so.

**Two behaviours the owner accepted on Home Theater — known, and not defects:**

- **The screen's own header sits below tvOS's search field.** `.searchable`'s field lands at the
  very top (y 60-130) with its keyboard strip under it (y 164-231), and the app's
  `ScreenHeader` — "Search · Programme titles in the guide" — draws below both, at y 306-368,
  clearing the strip by 75 pt. Nothing is obscured, but the screen does carry two headings, tvOS's
  and the app's. `.automatic` is the only placement tvOS offers, so where the chrome lands is not
  this app's to choose. Accepted as built (owner, 2026-09-11).
- **The keyboard strip scrolls off the top, and coming back to it is a walk.** It is not a pinned
  header: eight rows down a 20-row result it sits at **y = -141**, off screen, and **one Up press
  goes to the previous row, not to the strip** — it took **eight Up presses** to get back.
  Measured twice, the same both times. Accepted as built (owner, 2026-09-11).

Passes 71-72 (`reports/2026-09-11-pass71-guide-collections-recon.md`,
`reports/2026-09-12-pass72-guide-collections.md`, **built and proven on Home Theater 2026-09-12,
committed locally and NOT pushed — the owner tests it first**): **channel collections in the
Guide.** The header reads **"Guide" · a collections button · the date range · ↩ Now / +12h**;
pressing the button drops the app's own overlay listing "All Channels" and every collection the
server has; picking one reloads the grid filtered to it, in the owner's own order; the button takes
that collection's name; and the Apple TV remembers the pick across a rail trip and across a
relaunch.

- **The whole thing is one query parameter the typed client already had.**
  `GET /api/guide?filter=<collection id>` (`ChannelFilter.swift:61-69`, which has accepted
  `filter:` since sweep 2 and was simply never passed one by the Guide). The server does the
  filtering **and** the ordering: `filterChannels` re-sorts its result back into the owner's stored
  member order, overriding the channel-number sort, with its own comment "collection order wins"
  (`sources.go:389-401`). **Measured on the device:** 375 buttons unfiltered, 39 filtered to
  "Local", and the five rows drawn in exactly the order the live GET returned them — WMAR-HD 2.1,
  WGAL-TV 8.1, WBAL-DT 11.1, WJZ-TV 13.1, ESPN 50007.
- **`ScreenHeader` gained one optional slot** between the title and the subtitle
  (`ScreenChrome.swift:13-52`), defaulting to `EmptyView`. Every other screen renders unchanged,
  photographed from HEAD's code and from this pass's and compared frame by frame.
- **One new `UserDefaults` key, `"marlinGuideCollection"`** — the fourth this app writes, after
  `marlinClientId`, `marlinResume.<id>` and `marlinWeatherFix`. It holds JSON `{"id","name"}`, and
  `GuideCollectionsModel` is owned above `ScreenShell` like `HomeModel`, `WeatherModel` and
  `GuideSearchModel`, because `ScreenShell.swift:55` destroys the Guide on every rail visit.
- **A stale collection id fails invisibly on the server, so the app handles it.** An unknown
  `filter` applies **no predicate** and returns every visible channel — measured live on
  2026-09-12: `filter=col-does-not-exist-pass72` answered `channelCount: 91`. The app reverts to
  All Channels silently and clears the key on the next collections read.
- **The Guide's plain `@FocusState` re-focus was measured and is enough.** It was tried first, as
  the pass required, across six row-replacing reloads on Home Theater and never left the screen
  unfocused — so the Search screen's `.id(generation)` rebuild was **not** copied into the Guide.
  The standing question from Passes 63, 65, 66 and 68 — whether `GuideScreen` carries the same
  latent focus defect — is answered **no** for this case.
- **The empty-collection state is built and unproven.** "Nothing in <name> right now" plus focus on
  the collections button exists in code and has never been seen, because the server will not
  produce an empty filtered guide for an id it does not know and the owner's one collection has
  five live members. Named here so nobody mistakes it for tested.
- **Only the Guide is filtered.** `GET /api/guide/now` and `GET /api/channels` honour `filter` too
  and this app already calls both, but the approved design is the Guide alone; Home, On Now,
  Favorites and Search are untouched.

`GuideCollectionsUITests` (Pass 72) is the same kind of harness and needs the physical Apple TV,
the real remote and the owner's live "Local" collection. **It makes no server write of any kind.**
Its five tests are `testTheHeaderButtonAndTheOverlay`, `testChoosingACollectionFiltersTheGridAndComingBack`,
`testTheCollectionSurvivesATripToTheRail`, `testTheCollectionSurvivesARelaunch` and
`testTwoUnchangedScreens`. **Every query in it is a predicate, never an enumeration**, and that is
load-bearing: the Guide realises all 91 channel rows at once, so
`descendants(matching: .any).allElementsBoundByIndex` resolves 585+ elements at about 0.8 s each and
the test never finishes — measured, twice, before the harness was rewritten.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/GuideCollectionsUITests"
```

Pass 73 (`reports/2026-09-12-pass73-empty-collection-proof.md`, **proven on Home Theater
2026-09-12, committed locally and NOT pushed**): **the empty-collection state is no longer
unproven.** This supersedes the Passes 71-72 bullet above that says it "is built and unproven";
that bullet was true when written and is kept as history. **No app-target code changed in this
pass** — the built behaviour matched Pass 72's spec in every particular, so nothing was corrected.

- **The owner made a collection with no channels in it: "Test", `col-1789211011169`.** That is what
  Pass 72 could not produce for itself without a write. `GET /api/guide?filter=col-1789211011169`
  answers **`channelCount: 0`, `channels: []`**.
- **A known-but-empty collection and an unknown id are different server behaviours.** Empty returns
  an empty envelope; **unknown still returns the whole 91-channel lineup**. So `reconcile()` still
  earns its place, and the **stale-id revert is still unproven** — that one needs a collection
  deleted, which is a write this project does not make.
- **On the device:** the single line "Nothing in Test right now" at `(236.0, 222.5)`, **twelve
  buttons on the whole screen** — eleven rail icons and the collections button — **no `+12h` and no
  `↩ Now`**, and focus on the collections button. **A cold launch reproduces it element-for-element**,
  every label and frame identical, with **zero presses** needed to reach the button. Select from
  there opens the overlay; choosing Local brings all five rows back in the server's order.
- **This answers the first of the three things Pass 72 said it was least sure of** — that the
  Guide's plain `@FocusState` re-focus had never been watched with an **empty** grid, the one path
  where a stranded remote would matter most. It holds.

`GuideCollectionsUITests` now has **six** tests: Pass 73 added
`testAnEmptyCollectionDrawsItsOwnLineAndKeepsTheRemote`, which needs the empty collection to exist
on the server as well as "Local". **All six passed together in 454.8 s.** The predicate-not-
enumeration rule above has exactly one documented exception, in that test: with an empty grid the
tree holds tens of elements, and only a full listing can prove that the one line is the *only*
thing drawn.

Pass 74 (`reports/2026-09-12-pass74-collections-accepted-and-pushed.md`): **the owner tested the
Guide's channel collections on Home Theater on 2026-09-12 and accepted them — "all good"** (owner,
2026-09-12) — and **Passes 72 and 73 were pushed**, `9f5505e` and `c7e0fb4`, a fast-forward from
`2206a92`, with this pass's own commit carrying the notebook and its report. **This supersedes the
"committed locally and NOT pushed — the owner tests it first" clauses in the two entries above**;
both are kept as history. One acceptance covers both passes because **Pass 73 changed no app-target
code** — the binary tested carries Pass 72's behaviour. The acceptance covers the collections button,
the drop-down, the filtered reload, persistence across a rail trip and a relaunch, and the empty
state. **It closes none of the open questions** those passes raised: the overlay still does not
scroll, "Collections unavailable" is still unproven, the **stale-id revert is still unproven** and
needs a collection deleted, and whether the collection should reach `GET /api/guide/now` and
`GET /api/channels` is still the owner's call.

Pass 76 (`reports/2026-09-12-pass76-right-edge-probe.md`): **what a Right press does at the right-hand
edge of a Guide row, measured on Home Theater — Pass 75's first open question, answered.** Read-only
as to the app: the `[probe]` diagnostic in `GuideScreen.swift` was **reverted with `git checkout --`
before the commit**, and `git diff HEAD --stat` over the app target is empty. **The only source this
pass leaves behind is the test harness**, `Marlin DVR TVUITests/GuideRightEdgeUITests.swift`.

- **Right walks a Guide row cell by cell** — three rows, two runs, focus moving x=554 → x=1203 on
  row 2.1 and channel cell → first cell → next cell on row 8.1. Pass 75 §2.3 recorded that no device
  run had ever pressed Right inside a Guide row; it has now.
- **At the last visible cell, Right moves focus nowhere** — 12 edge presses across three rows, focus
  unchanged every time, not to `+12h`, not to another row, not to the rail, not to nothing. Left
  moved immediately afterwards each time, which is the control.
- **A cell filling the whole window (1286 pt, the full programme area) behaves the same** — three
  presses, no movement.
- **tvOS delivers every one of those presses to the app through `.onMoveCommand`: 14 presses,
  14 move commands, including all 7 that could not move and all 7 that could.** The modifier is an
  observer, not a consumer — the arm with it attached reproduced the arm without it frame for frame.
- **Three things a build must know, all measured here.** (1) `.onMoveCommand` fires identically
  whether or not focus moved, so **edge-ness is the app's to determine** from `focused` against the
  last id of `cells(for:)`. (2) It is delivered to the **innermost** registered handler only — 22 of
  22 commands came from the instance on the grid's `ScrollView` and **none** from the one on the
  screen's root, so a handler in the wrong place sees nothing and reads as "tvOS never delivered it".
  (3) The `@FocusState` write and the command delivery **race** — 6 of 7 moving presses delivered the
  command after the write — so only the settled value (+250 ms was enough in all 14 cases) may be
  trusted, never the value at receipt.
- **No alternative capture mechanism was tried**, per the pass's own stop rule. `UIFocusGuide`, a
  window-level press recognizer and a focusable edge affordance stay unmeasured.

Pass 77 (`reports/2026-09-12-pass77-guide-scroll-right.md`): **the Guide scrolls right.** One Right
press on the last visible cell of a row moves the window forward one slot (30 min); the time strip,
every row and the header move together, because all three are derived from `GuideModel.windowStart`
and nothing else. Forward only. `Left`, `Menu`, `↩ Now`, `+12h` and a rail trip are unchanged.
**The diff is `GuideScreen.swift` alone** — 129 insertions, 1 deletion — plus the harness, the notebook
and the report. **Committed locally and NOT pushed: the owner tests it on Home Theater first.**

- **Where the press comes from.** `.onMoveCommand` on the grid's own `ScrollView`, the site Pass 76
  measured as the only one that receives it. The edge is read from the **settled** focus 150 ms later,
  because the `@FocusState` write and the command delivery race; a press the focus engine consumed is
  recognised by the rightward step it made, not by comparing `focused` before and after.
- **The limit.** `lastListedSlot` reads the same `block.program` that `endOfListings` reads, so the two
  cannot disagree. The refetch is `pageForward()`'s existing rule: **one refetch every 45 slots**,
  measured, with the strip, rows and focus intact across it.
- **Focus after a nudge** stays on the same programme while it is in the window and goes to the
  leftmost cell of its row when it is not — both proven on the device. A **third** case the rule does
  not name is real: a row can have no cell at all in the new window (the owner's 2.1 has a gap at
  11:30 AM), and focus then falls back to `firstCellID` on another row.
- **A held Right does not auto-repeat** — a 2-second and a 4-second hold each advanced the window one
  slot. Nothing was built for it, per the pass's own instruction.
- **Roughly three presses in five move the window, not five in five**, and that is the owner's two
  rules combining rather than a defect: because focus stays on the same programme, the revealed slot
  often puts a new cell to its right, and the next press is taken by the focus engine to move on to it.
  Measured 48 slots in 78 presses, 46 in 80, 3 in 5, 4 in 5. **Whether he wants that is his call** — the
  alternative contradicts his focus rule.
- **Nothing else changed, and each was proven at a 30-minute offset**: the footer's two sentences, the
  strip's "· now" marker, `↩ Now`, `+12h`, the midnight column ("Sun · 12:00 AM") and the "Local"
  collection's five rows in the server's order.
- **A pre-existing limit found while testing and deliberately not touched:** Up from a grid cell whose
  x falls between the collections button and the right-hand pills moves focus nowhere, because the
  header has no focusable item above that span — the same thing `WeatherScreen.swift:109-113` records.
  It matters more now, since reaching `↩ Now` from the right-hand edge needs a Left press first.

Pass 78 (`reports/2026-09-12-pass78-scroll-accepted-and-pushed.md`): **the owner tested the Guide's
scroll-right on Home Theater on 2026-09-12 and accepted it — "it all feels good"** (owner,
2026-09-12) — and **Pass 77 was pushed**, `f0613e5`, a fast-forward from `38067c8`, with this pass's
own commit carrying the notebook and its report. **This supersedes the "committed locally and NOT
pushed" clause in the Pass 77 entry above**, which is kept as history.

- **The acceptance covers** one Right press on a row's last visible cell moving the window one slot
  with the strip and every row together, forward only, `Left`/`Menu`/`↩ Now`/`+12h`/a rail trip
  unchanged, the window stopping at the last listed slot, and the refetch on the existing rule.
- **The focus rule is accepted as built**: focus stays on the programme while it is in the window,
  and goes to the leftmost cell of its row when it has left.
- **The press ratio is accepted, which closes Pass 77 open question 2.** Roughly three presses in
  five move the window — 1.00 slots per press on a long programme, 0.60 on half-hour ones — and the
  owner was told before he accepted. **It is not a defect and not an open item.**
- **It closes nothing else Pass 77 raised:** the third focus case where a row has no cell at all in
  the new window, whether a *physical* held Right auto-repeats, the pre-existing header geometry that
  blocks Up from the middle of a row, `lastListedSlot` being per-fetch, and the 150 ms settle.
- **No app-target code changed in Pass 78** — the binary the owner tested is Pass 77's.

Pass 79 (`reports/2026-09-12-pass79-guide-clock.md`): **the Guide keeps up with the clock.** The
owner's defect of 2026-09-12 — left open, the Guide did not move with the time; the window, the
"· now" column and the Now marker stayed where they were when the screen opened. A beat once a
minute republishes the screen's clock, and a window sitting at now advances to the new current half
hour at each half-hour boundary. **The app-target diff is `GuideScreen.swift` alone**, 115
insertions and 6 deletions, plus the Pass 76/77 harness, the notebook and the report. Build warnings
unchanged from HEAD's two, measured by a clean build of each tree. **Committed locally and NOT
pushed: the owner tests it on Home Theater first.**

- **The cause was two things, not one.** Nothing ever moved the window — `windowStart` had four
  writers at `HEAD` and all four were a user action or the screen opening, and there was **no timer,
  no `.task` loop, no scene-phase handler and no notification observer anywhere in
  `GuideScreen.swift`**. And nothing would have redrawn if it had: `isAtNow` and the `↩ Now` pill
  both read `Date()` inside the view body, **which SwiftUI observes not at all**, so the strip's
  "· now", the footer sentence and both header pills could not react to the passage of time.
- **The screen's clock is now `GuideModel.now`, and everything "now" derives from it.** The roll is
  one write to `windowStart`, so the strip, every row, the header's date range and the "· now"
  marker move together — the same single-number property Pass 77 built the scroll-right on.
- **A scrolled window is never moved.** The test is `windowStart < nowHalfHour`, which is exact: the
  window is only ever set to the current half hour or advanced past it, so being behind the clock
  can only mean it was at now. A window the clock catches up with simply becomes `isAtNow` again.
- **No extra network on the beat** — the refetch is the existing rule, the same line `snapToNow()`
  and `nudgeForward()` use. Across three real boundaries on Home Theater the app's own `fetch=`
  never moved.
- **The beat is a `.task` on the Guide**, so `ScreenShell.swift:57`'s `.id(current)` ends it on every
  rail visit. It prints `[guide] clock stopped after N beat(s)` when the loop ends, and the counts
  measured on the device match the minutes each Guide was on screen exactly — 9, 4, 2 and 21 beats
  for four visits, with **no `[guide]` line at all** during three minutes away on Radio.
- **"The Now marker" is read as the `↩ Now · 2:04 PM` pill, and that is an interpretation.** The app
  has exactly two things that say "now" — the strip's `· now` suffix and that pill's clock — and
  **there is no vertical now-line in the app or in `design/`** (Pass 75 §3). The pill's clock is the
  one reading that can track *within* a half hour, and it now does.
- **A cell has no live/past appearance in this app and none was invented.** `GuideCellLabel` colours
  a cell from its `mark` alone; the live/past distinction is behavioural (`select` reads the wall
  clock at press time and was always current), and what the roll changes is which programmes are in
  the window at all.
- **The line numbers Pass 77's report and this file cite for `GuideScreen.swift` have moved**, since
  Pass 79 inserts above them — the `channelFocusID` build warning, for instance, is at **`:635`**
  where Pass 77 recorded `:528`. The earlier text is left exactly as written, as this project's rule
  requires (DECISIONS.md, 2026-09-09 (Pass 56)).

Pass 80 (`reports/2026-09-12-pass80-clock-accepted-and-pushed.md`): **the owner tested the Guide's
clock on Home Theater on 2026-09-12 and accepted it — "all good"** (owner, 2026-09-12) — and
**Pass 79 was pushed**, `02f3764`, a fast-forward from `fda3992`, with this pass's own commit
carrying the notebook and its report. **This supersedes the "committed locally and NOT pushed"
clause in the Pass 79 entry above**, which is kept as history.

- **The acceptance covers** the Guide left open moving with the time — at each half-hour boundary a
  window sitting at now advances to the new current half hour, strip, rows, header date range and
  the "· now" marker together, with ended programmes leaving the grid; the `↩ Now · 2:04 PM` pill
  tracking the clock within a half hour; Pass 77's focus rule after a roll; the collection filter
  holding across it; and the beat stopping with the screen.
- **It also settles the two things Pass 79 could not finish on the device**, and they are closed on
  the owner's own test rather than on a device run of ours: **a window scrolled ahead does not roll**
  across a boundary (Pass 79 measured ten minutes of it holding still but was killed short of the
  boundary), and **the Guide reopened after the app sat backgrounded across a boundary is on the
  true current half hour** (Pass 79 never ran that at all). **The harness test for the backgrounded
  case is still unexecuted and its file header still says so** — that label stays.
- **A standing rule was taken the same day: one real device run per pass for the main behaviour, the
  rest code-traced, and the owner tests before every push.** Every claim is labelled run or traced,
  in the report and in the header of any harness file carrying a written-but-unrun test. It was
  settled after Pass 79's original brief listed five checks that each needed a real half-hour
  boundary and the owner interrupted it partway to cut the list to one (DECISIONS.md, 2026-09-12
  (Pass 80)).
- **No app-target code changed in Pass 80** — the binary the owner tested is Pass 79's.

Passes 81-82 (`reports/2026-09-12-pass81-on-later-pills-recon.md`,
`reports/2026-09-12-pass82-on-later-pills.md`, **built and proven on Home Theater 2026-09-12,
committed locally and NOT pushed — the owner tests it first**): **On Later is three pills and a card
grid.** It takes On Now's page layout — the header, a pill row beneath it, a three-column grid — and
lists **every** upcoming airing on the channels the owner's collections hold, under **"On Today" ·
"On This Week" · "Premieres"**. It opens on On Today every visit and the pick does not persist.

- **`GET /api/guide/later` is no longer read by this app at all.** Pass 81 measured why: the route
  takes **no parameters** (seven different query strings, byte-identical bodies), caps each of its
  two sections at **24 items**, keeps only airings it judges "notable", and de-duplicates by
  `seriesId` across **both** sections with one shared map — so an airing tonight can be suppressed
  by a later-in-the-week showing of the same series. None of it is switchable off.
- **`api.later()`, `LaterResponse`, `LaterSection` and `LaterItem` are now uncalled and are left in
  place.** Nothing reads `/api/guide/later`. Removing them was not in Pass 82's scope.
- **THE SERVER NEVER SETS `premiere`. Do not re-derive this.** `program.premiere` is true on
  **0 of 16,121** airings measured live on 2026-09-12, and zero again in `/api/guide/later`,
  `/api/guide/now`, an uncapped `/api/guide/search` and `/api/schedule`. `finale` is zero too, while
  `new` is 1,325 and `live` 589 over the same set. XMLTV's `<premiere>` is parsed as a presence-only
  element whose text is discarded (`guide.go:147`, `:240`) and **neither Philo nor Verizon emits
  it**; the HDHomeRun cloud path never assigns `Premiere`, `Live` or `Finale` at all
  (`guide.go:435-451`). **The server therefore cannot tell a season premiere from a series
  premiere.** The Premieres pill runs the owner's derived rule instead (DECISIONS.md, 2026-09-12
  (Pass 81)), with the flag kept as its first clause so it starts working by itself if that ever
  changes.
- **The Premieres pill selects nothing on the owner's data today** — 0 airings over the next seven
  days, seen on the television, with "Nothing on Premieres for your collections" in its place. That
  is the guide's content, not a defect.
- **The route is `GET /api/guide?filter=<collection id>&slots=48` — seven requests per non-empty
  collection, seven in total on the owner's data.** `slots` is clamped to 48, so 24 hours is the
  most one request carries and seven is the floor for a week. The week is fetched once per visit and
  the three pills filter what is in hand; a pill press makes no request.
- **Its cost is measured, not assumed: the block builder drops 2 airings of 140 over seven days
  (1.4 %)**, compared directly against `/export/*/guide.xml` for the same five channels — a 15-minute
  *Monday Night Postgame* at 23:15 and a three-hour *College Football*, both on ESPN, both listings
  the half-hour block layout cannot place. **`/export/guide.xml` is complete and was rejected for
  cause**: it drops the premiere flag, `seriesId`, `rating` and `originalAirDate` (`export.go:95-111`)
  and is 16.5 MB for the whole lineup.
- **On Later has a DRM filter for the first time.** Pass 81 recorded it as the one list in the app
  without one, because `/api/guide/later` carries no `drm` field. Reading `/api/guide` instead means
  `ChannelFilter.swift:67`'s existing `.playable` applies, and nothing new was written for it.
- **Select on a card opens the airing sheet**, reconstituted the way Search does it — the programme
  re-read from `GET /api/guide/search?title=`, never taken from the `/api/guide` row — and the
  channel reused from the guide row rather than re-read, because a guide row already embeds the
  server's own `MergedChannel`. Two reads where Search makes three.
- **The plain `@FocusState` re-focus after the sheet closes works here**, like the Guide and unlike
  the Search screen. **No generation counter was added.**
- **Three app files changed and no more**: `OnLaterScreen.swift` (rewritten),
  `Models.swift` (`ChannelCollection` gained `channelIds`) and `ScreenShell.swift` (one line, so the
  sheet's "Watch live" has a Player to hand the channel to). **The Home On Later tile is untouched**
  and still counts scheduled bookings from `GET /api/schedule`.

`OnLaterPillsUITests` (Pass 82) is an evidence harness needing the physical Apple TV, the real
remote and at least one non-empty collection. **It makes no server write.** Its one test is
`testOnLaterOpensOnTodayThePillsSwitchAndACardOpensTheSheet`.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/OnLaterPillsUITests"
```

Pass 83 (`reports/2026-09-12-pass83-on-later-accepted-pushed-bedroom.md`): **the owner tested
On Later's three pills on Home Theater on 2026-09-12 and accepted them — "good to go"** (owner,
2026-09-12) — and **Pass 82 was pushed**, `ad7f5f5`, a fast-forward from `54b2335`, with this pass's
own commit carrying the notebook and its report. **This supersedes the "committed locally and NOT
pushed — the owner tests it first" clause in the Passes 81-82 entry above**, which is kept as
history.

- **The acceptance covers** the page layout, the three pills and the absence of channel-filter
  pills, every airing on collection channels with no "notable" narrowing, opening on On Today with
  the pick not persisting, the sort, the empty states, and Select opening the airing sheet.
- **Three things were accepted explicitly rather than by silence**, and they close Pass 82's first
  two open questions: the **Premieres pill being empty** on the current data; the **two app files
  touched outside `OnLaterScreen.swift`** (`Models.swift`'s `channelIds`, and the one line in
  `ScreenShell.swift:99` that gives the sheet's "Watch live" a Player); and the **`/api/guide`
  block-layout loss of 2 airings in 140 over a week, both on ESPN** (DECISIONS.md, 2026-09-12
  (Pass 83)).
- **No app-target code changed in Pass 83** — the binary the owner tested is Pass 82's.
- **The bedroom Apple TV is no longer twenty-eight commits behind.** It had run Pass 53's `0b3589d`
  since 2026-09-08; Pass 83 built the pushed head for it and installed it by the method Pass 54
  recorded — `xcodebuild -destination 'platform=tvOS,name=Master Bedroom ATV'
  -allowProvisioningUpdates build`, then `xcrun devicectl device install app` — to the same device.
  **Home Theater was not reinstalled in this pass.** It is still a development-signed build and will
  stop launching when the provisioning profile expires; when that is is still unchecked.

### Citation drift corrected by Pass 76 — the drifted comment lines are NOT edited, these are the current numbers

The six the Pass 75 report listed, each re-verified against `HEAD` after that pass's diagnostic was
reverted. **The comments themselves are left exactly as written** — reports and in-code history are
not rewritten to match a later reading (DECISIONS.md, 2026-09-09 (Pass 56)); this list is where the
true numbers live.

- `GuideScreen.swift:21` cites `ScreenShell.swift:55` for `.id(current)` — it is **`ScreenShell.swift:57`**.
- `GuideSearchScreen.swift:46` cites `ScreenShell.swift:51` for `.id(current)` — it is **`ScreenShell.swift:57`**.
- `GuideSearchScreen.swift:301` cites `ScreenShell.swift:51` for the same line — it is **`ScreenShell.swift:57`**.
- `AiringSheet.swift:76` cites `Models.swift:170` for `Job.status` — it is **`Models.swift:288`**.
- `AiringSheet.swift:77` cites `GuideScreen.swift:173-178` for `mark(for:)` — it is **`GuideScreen.swift:193-198`**.
- `GuideSearchScreen.swift:170` cites `GuideScreen.swift:145-147` and `:162-168` for the schedule pair — they are **`GuideScreen.swift:182-188`** (`refreshSchedule()`) and **`:165-167`** (`job(channelId:programStart:)`).
- `GuideSearchScreen.swift:282` cites `GuideScreen.swift:318-323` for the sheet-close focus restore — it is **`GuideScreen.swift:359-364`**.

**`COLD-START.md:855` and `reports/2026-09-12-pass72-guide-collections.md` §1 step 6 also cite
`ScreenShell.swift:55`; the line is `:57`.** Both are left as written for the same reason.

### KNOWN AND UNFIXED after Pass 38 — do not mistake these for proven, and do not re-derive them

- **CLOSED by Pass 42 — a resumed recording starting well past its resume point.** It was measured
  on Home Theater in Pass 38 with a disclosed, reverted diagnostic: a session created with
  `start=1680` was already at **1988 s at its fourth tick**, five minutes further on than asked
  for, because recordings were an HLS **EVENT** playlist the server was still writing and AVPlayer
  joined it near its live edge. A complete MP4 has no live edge to join. Kept because it records
  what the HLS route did.
- **Because of that, "a playback that starts inside a break offers it" could not be proved** in
  Pass 38 — three attempts, each time the playhead was already past the break by the first tick.
  **Still unproved:** Pass 42 did not attempt it, so the containment test that would fire is still
  only reasoning.
- **One skip landed 1.01 s past `endSeconds` instead of on it.** Two landings were exact to six
  decimal places, both from sessions with `startOffset = 0`; the third, from a session with
  `startOffset = 931.000155`, asked for 547.539845 in item time and landed at 548.548231. It lands
  past the break, never short, so it never lands inside a commercial. Unexplained.
- Everything under **KNOWN AND UNFIXED after Pass 29** and **after Pass 33** still stands.

## What is NOT built

The future screen **Settings**: present as drawn and inert, parked until the owner says otherwise (DECISIONS.md 2026-09-06 sweep 4 + fixes). Weather left this list in Pass 13 and **Radio in Pass 19**.

**Built but blocked on the owner**: nothing. Both entries this block ever held are closed — the radar's request rate by Pass 16's tile store, and **every WeatherKit value by Pass 22**: the App ID carries the capability, the target is entitled, and both weather screens draw real data on the Apple TV. The one thing still unproven there is the **alert card**, which needs a real alert in the owner's area to be seen (Pass 22 Open Question 1).

Deliberately still inert or absent: show detail's "Series pass" button and the Player's 6e "Delete this recording" (Pass 8 Open Question 1); any click behaviour on the Guide's channel cell — the hold favourites it, a click does nothing (Pass 9 Open Question 1); any way to un-skip a cancelled pass airing; and any auto-refresh of the Manage DVR lists (Pass 10 Open Questions 2 and 4). Cancelling a booking, which Pass 8 lacked, now lives in Manage DVR → Scheduled Recordings.

**Built but never exercised against the live server** — wired and code-traced, not proven, and named here so no one assumes otherwise (Pass 10 §4c and Open Question 3):

- **Empty Trash** (`POST /api/library/trash/empty`) — it deletes files on disk permanently for every client; never sent.
- **Cancel recording on a pass's airing** — only the one-off Record Now case was cancelled live. Same call; the server answers `removed: false` and skips that airing while the pass carries on.
- **Stop recording on a pass's airing** — Pass 32 proved Stop on the device for a one-off Record Now only. The code path is the same and deliberately not gated on `passId`, but it has never been driven for a pass, and the sheet shows a wrong "Record this airing" control beside it in exactly that case (**KNOWN AND UNFIXED after Pass 33**).
- **Restore is no longer on this list.** Pass 33 exercised it live on Home Theater, twice.

## Raised for the marlin-dvr project — recorded here, not acted on

Server behaviour this project measured and does not own. The standing rule is that server changes are
raised as decisions for marlin-dvr (see **The rules**); nothing below was changed, worked around, or
compensated for in the app.

- **`trashedAt` does not update when the same file is trashed twice.** Measured across three
  trash/restore cycles on one recording (Pass 33): `GET /api/library/trash` kept reporting the
  *first* trashing, so a row can read "Trashed today at 9:09 PM" during a 9:16 PM session. The app
  shows the server's value unaltered.
- **Empty Trash has no confirmation step server-side.** `POST /api/library/trash/empty` deletes every
  trashed file on disk, permanently, for every client, the moment it arrives — there is no
  are-you-sure and no dry run. Both this app and the web UI have to invent their own guard; this app
  arms the button on the first click and sends only on the second. On 2026-09-07 that call removed
  3.80 GB of the owner's recordings in one request (see above).
- **The audio/video desync on recordings — and their outstanding request.** Pass 39 sorted it
  **NOT OURS**: every parameter, setting and seek in this app was inventoried and none can shift
  audio against video. Nothing in Passes 42–56 changed it, and **no client-side compensation has
  ever been built for it, nor is any to be.** **The marlin-dvr project has asked the owner to match
  the sessions in which he observed the desync to individual session records.** That request is
  **outstanding and is the owner's to answer**; nothing has been done about it here.
- **The 27-session start-values table is still unsettled with the marlin-dvr foreman.** They asked
  for **the full 27 rows published in this repo with stable labels `S01`–`S27`**, and **explicitly
  asked us NOT to re-capture and NOT to pursue the send-versus-apply question until they ask.** A
  prompt to do that work was written and **the owner did not send it** — he is settling the shape
  with them first. **IT MUST NOT BE RE-ISSUED UNPROMPTED.** The Pass 38 captures the rows would come
  from live in a **session temp directory, not in this repo**
  (`reports/2026-09-08-pass40-session-start-values.md` §1 records their path); **if they vanish, only
  a fresh Apple TV capture could recover the rows — which is exactly what they asked us not to
  spend.**
- **Their 1.8.1 report was answered on 2026-09-11, and its central claim was corrected.** That claim
  — *no client sends `"format":"file"` on the recording session request, so the LIVE badge, the
  refused fast-forward and the resume overshoot are all still live* — **was true of every client
  until the evening of 2026-09-08 and is out of date now.** This app has sent `"format":"file"` on
  every recording session request since `137f1de` (2026-09-08 21:01:06 -0400), which is an ancestor
  of `origin/main` and of `0b3589d`, the build on both Apple TVs; `git diff 137f1de HEAD` over the
  three player files is empty, so nothing since has reverted it (Pass 70). The three defects stay
  closed on the evidence already recorded above — the badge and the fast-forward wait on the owner's
  own Home Theater testing of 2026-09-08, the overshoot by Pass 42's measurement. **The reply is
  `reports/2026-09-11-pass70-note-to-marlin-dvr.md`**, written to be read by them and confined to
  what they asked about; the check behind it is
  `reports/2026-09-11-pass69-server-181-check.md`. **Nothing was asked of them and no request was
  sent to the server.** In particular the undocumented route (Pass 41 open question 7.6) was **not**
  re-raised and stays open.
- **1.8.1's change to `GET /api/library`'s `recordings` count — it now excludes trashed recordings —
  needs nothing from this app.** The field is a non-optional `Int` (`Models.swift:330`), so a value
  change cannot affect decoding, and it is displayed in exactly two places: the Recordings screen
  header (`RecordingsScreen.swift:86`) and the Home Recordings tile (`HomeView.swift:76`). Nothing
  else reads it and nothing derives from it. **Both strings simply show a smaller number** (Pass 70).

## Open questions

See the Open Questions sections of `reports/2026-09-05-pass2-server-recon.md` (server recon) and `reports/2026-09-05-pass3-hls-client-recon.md` (HLS client recon). Environment questions from Pass 1 are listed in `reports/2026-09-05-pass1-plumbing.md`.

## Next step

**Nothing is unpushed as of Pass 83.** The owner accepted On Later's three pills on Home Theater on
2026-09-12 ("good to go"), and the commit that had been waiting on that test was pushed: **`ad7f5f5`
(Pass 82, the pills themselves)**, together with **this pass's own commit**, which carries this
paragraph, the `DECISIONS.md` acceptance entry and
`reports/2026-09-12-pass83-on-later-accepted-pushed-bedroom.md`. **A fast-forward from `54b2335`**,
which is still an ancestor; no merges in the range, and `ad7f5f5`'s parent is `54b2335`; nothing
forced, rebased or amended. **This pass's own SHA is not written here and cannot be** — a commit
cannot contain its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 83 response and
belongs in the next pass's entry. **The bedroom Apple TV was brought up to that pushed head in this
pass**, and its install evidence sits in the same place and for the same structural reason — the
install is of the head this commit becomes. The paragraph below, written by Pass 82, described the
unpushed state correctly when written and is kept as history.

**Pass 82 is committed locally and NOT pushed.** On Later's three pills
(`reports/2026-09-12-pass82-on-later-pills.md`) were built, proven on Home Theater on 2026-09-12 and
committed in one commit with the harness, the screenshots, the notebook and the report — **the owner
tests it on Home Theater before anything is pushed**, which is the standing separate push gate.
Local `main` is one commit ahead of `origin/main`; nothing forced, rebased or amended. This pass's
own SHA is not written here and cannot be — a commit cannot contain its own SHA (DECISIONS.md,
2026-09-11 (Pass 68)); it is in the Pass 82 response and belongs in the next pass's entry.
**Pass 81's recon report was pushed already**, in `54b2335`. The paragraph below, written by
Pass 80, described the state correctly when written and is kept as history.

**Nothing is unpushed as of Pass 80.** The owner accepted the Guide's clock on Home Theater on
2026-09-12 ("all good"), and the commit that had been waiting on that test was pushed: **`02f3764`
(Pass 79, the clock itself)**, together with **this pass's own commit**, which carries this
paragraph, the `DECISIONS.md` acceptance entry, the standing one-device-run rule and
`reports/2026-09-12-pass80-clock-accepted-and-pushed.md`. **A fast-forward from `fda3992`**, which is
still an ancestor; no merges in the range, and `02f3764`'s parent is `fda3992`; nothing forced,
rebased or amended. **This pass's own SHA is not written here and cannot be** — a commit cannot
contain its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 80 response and belongs
in the next pass's entry. The paragraph below, written by Pass 79, described the unpushed state
correctly when written and is kept as history.

**Pass 79 is committed locally and NOT pushed.** The Guide's clock
(`reports/2026-09-12-pass79-guide-clock.md`) was built, run against a real half-hour boundary on
Home Theater and committed in one commit with the harness, the notebook and the report — **the owner
tests it on Home Theater before anything is pushed**, which is the standing separate push gate.
Local `main` is one commit ahead of `origin/main`; nothing forced, rebased or amended. This pass's
own SHA is not written here and cannot be — a commit cannot contain its own SHA (DECISIONS.md,
2026-09-11 (Pass 68)); it is in the Pass 79 response and belongs in the next pass's entry. The
paragraph below, written by Pass 78, described its own state correctly when written.

**Nothing is unpushed as of Pass 78.** The owner accepted the Guide's scroll-right on Home Theater on
2026-09-12 ("it all feels good"), and the commit that had been waiting on that test was pushed:
**`f0613e5` (Pass 77, the scroll-right itself)**, together with **this pass's own commit**, which
carries this paragraph, the `DECISIONS.md` acceptance entry and
`reports/2026-09-12-pass78-scroll-accepted-and-pushed.md`. **A fast-forward from `38067c8`**, which is
still an ancestor; no merges in the range, and `f0613e5`'s parent is `38067c8`; nothing forced, rebased
or amended. **This pass's own SHA is not written here and cannot be** — a commit cannot contain its own
SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 78 response and belongs in the next pass's
entry. The paragraph below, written by Pass 77, described the unpushed state correctly when written
and is kept as history.

**Pass 77 is committed locally and NOT pushed.** The Guide's scroll-right
(`reports/2026-09-12-pass77-guide-scroll-right.md`) was built and proven on Home Theater and committed
in one commit with the harness, the notebook and the report — **the owner tests it on Home Theater
before anything is pushed**, which is the standing separate push gate. Local `main` is one commit ahead
of `origin/main`; nothing forced, rebased or amended. The paragraph below, written by Pass 76, still
describes its own state correctly.

**Nothing is unpushed as of Pass 76.** Pass 75 (`fce20c2`, the Guide scroll-right recon) and Pass 76
(this pass's own commit, the right-edge device probe) are both on `origin/main`; Pass 76's own SHA is
not written here and cannot be — a commit cannot contain its own SHA (DECISIONS.md, 2026-09-11
(Pass 68)) — so it is in the Pass 76 response and belongs in the next pass's entry. **Pass 76 left no
app-target change at all**: its diagnostic was reverted before the commit, and what it added is the
harness `Marlin DVR TVUITests/GuideRightEdgeUITests.swift`, the notebook and its report. **The Guide
scroll-right itself is not built** — Passes 75 and 76 are recon and measurement only, and the owner
has not chosen a mechanism.

**Nothing is unpushed as of Pass 74.** The owner accepted the Guide's channel collections on Home
Theater on 2026-09-12 ("all good"), and the two commits that had been waiting on that test were
pushed: **`9f5505e` (Pass 72, the collections themselves) and `c7e0fb4` (Pass 73, the
empty-collection state proven on the device)**, together with **this pass's own commit**, which
carries this paragraph, the `DECISIONS.md` acceptance entry and
`reports/2026-09-12-pass74-collections-accepted-and-pushed.md`. **A fast-forward from `2206a92`**,
which is still an ancestor; no merges in the range, `c7e0fb4`'s parent is `9f5505e` and `9f5505e`'s
parent is `2206a92`; nothing forced, rebased or amended. **This pass's own SHA is not written here
and cannot be** — a commit cannot contain its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in
the Pass 74 response and belongs in the next pass's entry. The two paragraphs below, written by
Passes 73 and 72, described the unpushed state correctly when written and are kept as history.

**Two commits are now local and unpushed, and both wait on the same test.** Pass 73
(`reports/2026-09-12-pass73-empty-collection-proof.md`) proved the empty-collection state on Home
Theater and is committed on top of Pass 72's `9f5505e`; local `main` is **two commits ahead of
`origin/main`**, nothing forced, rebased or amended. **Pass 73 changed no app-target code** — its
only source edit is `GuideCollectionsUITests` — so the binary the owner tests is Pass 72's
behaviour, and one Home Theater acceptance covers both commits. The paragraph below, written by
Pass 72, still describes its own commit correctly; only the count of unpushed commits has moved.

**Pass 72 is committed locally and NOT pushed.** The Guide's channel collections
(`reports/2026-09-12-pass72-guide-collections.md`) were built, proven on Home Theater on
2026-09-12 and committed in one commit with the report and its screenshots — **the owner tests it
on Home Theater before anything is pushed**, which is the standing separate push gate. The commit
is the first unpushed work since Pass 66's push; local `main` is one commit ahead of `origin/main`
and nothing was forced, rebased or amended. **Pass 71's recon report was pushed already**, in
`2206a92`.

**Nothing is unpushed as of Pass 66.** On 2026-09-11 local `main`, `origin/main` and
`git ls-remote origin main` all read `b028650`. **Six commits have landed since Pass 58's
`67ec874`**, and every SHA below was read from `git log` and `git ls-remote`, none from memory:
`77bf616` (Pass 59, this section brought current through Pass 58),
`4f78906` (Pass 60, `CLAUDE.md` made the single source of truth for the rules),
`49a5672` (Pass 61, two corrections to it),
`1107b12` (Pass 63, the Search screen),
`d0ff593` (Pass 65, that screen moved onto `.searchable`), and
`b028650` (Pass 66, the owner's acceptance and this notebook). **The chain was checked rather
than assumed:** all six are ancestors of `origin/main`, `git log --merges 67ec874..b028650` is
empty, each commit's parent is the one before it, and `67ec874` is still an ancestor of the
current head — nothing forced, rebased or amended. **Pass 66 pushed the last three together** as
a fast-forward from `49a5672`, verified live that day by fetch, `git rev-parse main`,
`git rev-parse origin/main` and `git ls-remote origin main` all reading `b028650`
(`reports/2026-09-11-pass66-search-accepted-and-pushed.md`). **Passes 62 and 64 have no commit of
their own, and that is correct**: both were read-only — Pass 62 wrote a report only, and Pass 64
deleted every probe file and restored `ScreenShell.swift` with `git checkout` before reporting —
so their reports ride in `1107b12` and `d0ff593` respectively, each committed by the pass that
followed. **Pass 67 committed the Pass 66 report**, which that pass necessarily left untracked
because its own steps put the report after the push and a push SHA cannot be written into a
commit that precedes it (`reports/2026-09-11-pass67-notebook-current.md`).

**Nothing is unpushed as of Pass 58.** On 2026-09-09 local `main`, `origin/main` and
`git ls-remote origin main` all read `67ec874`. Every commit since Pass 55's push is an ancestor of
`origin/main` and the chain is linear — no merge commit, nothing forced, rebased or amended.
**Pass 55 pushed a second commit** that the paragraph below does not name: `48e8f91`, recording that
pass's verified push in the notebook, the brief and its report. **Pass 56 retired the handoff brief**
— `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` folded into this file and deleted
(`reports/2026-09-09-pass56-retire-handoff-brief.md`) — pushed as `10499e5`, verified there by fetch,
`git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading
`10499e5`; that pass's own verified-push record followed as `8f371a6`. **Pass 57 created `CLAUDE.md`**
at the project root — the standing builder rules and a pointer to this notebook, never project state
(`reports/2026-09-09-pass57-claude-md.md`) — pushed as `be0cae9`, a fast-forward from `8f371a6`.
**Pass 58 added that file's ninth bullet**, the server-repo rule, copied word for word from this
file's rules list as it then stood and proved byte-identical
(`reports/2026-09-09-pass58-claude-md-ninth-rule.md`) — pushed as `67ec874`, a fast-forward from
`be0cae9`. That rule is now the last of `CLAUDE.md`'s nine bullets. **Pass 58 also corrected a
miscount:** the Pass 57 report called it "COLD-START.md's ninth", but this file's rules list then held
**eight** rules and the server-repo rule was its seventh; `CLAUDE.md` has nine bullets because one of
them — "If anything blocks, stop and report" — had no counterpart in that list. **Pass 60 has since
removed this file's rules list**, so `CLAUDE.md`'s bullets are now the only copy (DECISIONS.md,
2026-09-09 (Pass 58) and 2026-09-09 (Pass 60)).

**Nothing was unpushed as of Pass 55.** The owner accepted **the app icon and Top Shelf art** on Home Theater on
2026-09-08 and **Pass 55 pushed it** together with Pass 54's report and this notebook work
(`reports/2026-09-08-pass55-push-and-handoff.md`) — verified on 2026-09-08 by fetch, `git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading `fd96b1d`, a fast-forward from `0a80a57` with nothing forced, rebased or amended. **This project keeps no
separate handoff-brief file: `COLD-START.md` and `DECISIONS.md` are the whole record** (owner,
2026-09-08). Pass 55 wrote `MARLIN-DVR-TV-HANDOFF-2026-09-09.md` before that decision was taken;
**Pass 56 moved what it carried that this file did not into here and deleted it**
(`reports/2026-09-09-pass56-retire-handoff-brief.md`). Before that,
the owner accepted **Pass 49** (the airing sheet's first control) on Home Theater on 2026-09-08 —
"all good" — and **Pass 50 pushed it** together with that pass's notebook work
(`reports/2026-09-08-pass50-push-notebook.md`) — verified on 2026-09-08 by fetch, `git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading `2e03996`, a fast-forward from `61257bc` with nothing forced, rebased or amended. Before that, the owner accepted
**Pass 47** (the Recordings shelf focus fix) on Home Theater on 2026-09-08 — "good to go" — and
**Pass 48 pushed it** together with that pass's notebook work
(`reports/2026-09-08-pass48-push-notebook.md`) — verified on 2026-09-08 by fetch, `git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading `a0097b5`, a fast-forward from `65ae372` with nothing forced, rebased or amended. Before that, **Pass 46 pushed**
its own recon report on 2026-09-08, verified at `65ae372`, and **Passes 44 and 45** pushed the two
formerly-untracked reports and the two notebook corrections that followed them, verified at
`f167663` and `fd59d35`. Before that, the owner accepted **Pass 42** (the single-file MP4 route) on
Home Theater on 2026-09-08 and **Pass 43 pushed it** together with that pass's notebook work
(`reports/2026-09-08-pass43-push-notebook.md`) — verified on 2026-09-08 by fetch, `git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading `5755db7`, a fast-forward from `b11f4c6` with nothing forced, rebased or amended. Before that, the owner accepted
**Pass 38** (commercial skip) on Home Theater on 2026-09-08 and **Pass 39 pushed it** with Pass 37's
recon report; **Pass 41 pushed** its own recon report on 2026-09-08, verified at `b11f4c6`. Before
that, the owner accepted Passes 31, 32, 32A and 33 on Home Theater and **Pass 34 pushed** them on
2026-09-07 (`reports/2026-09-07-pass34-push-notebook.md`); **Pass 35 verified that push** on
2026-09-08 — local HEAD, `origin/main` and `git ls-remote origin main` all read `aad7992`
(`reports/2026-09-08-pass35-context-refresh-recon.md`).

**Of the owner's three named defects, two are closed and one is not.** All three were reconnoitred
read-only in Pass 39, whose file:line answers and sorting still stand.

- **A "LIVE" indicator showing while a recording plays — CLOSED.** The owner tested Pass 42 on
  Home Theater on 2026-09-08 and reports **the LIVE badge is no longer there** (owner, 2026-09-08).
  The badge was never the app's own: Pass 39 §4.1 established that a recording is drawn by
  `RecordingHUD` and can never reach either of the app's live indicators, so it was
  `AVPlayerViewController`'s transport reacting to a playlist with no `#EXT-X-ENDLIST`. A complete
  MP4 gives it nothing to react to.
- **Having to wait after starting a recording before fast forward works — CLOSED** (owner,
  2026-09-08: everything works). The seekable range was short because only the written part of the
  playlist was advertised; a complete file advertises all of it from the first response.
- **Audio out of sync with video on recordings — STILL OPEN, and not this project's code.** Pass 39
  sorted it **NOT OURS** and Pass 42 changed nothing about it. It is with the marlin-dvr project.

Waiting to be picked up, in no particular order: **the series-pass sheet chip**, since it is a wrong
control the owner can press today; **stopping a pass's airing on the device**, which would settle the
same area; frame stepping near the end of the prepared range (**KNOWN AND UNFIXED after Pass 29**,
recorded there as very likely closed by Pass 42 but not proven); and the rest of **KNOWN AND UNFIXED
after Pass 33**. **Item B of Pass 32 is closed** — the server change it asked for shipped as 1.6.0's
`GET /api/library/trash` and Pass 33 built on it — as is the Pass 31 entry about a last-episode
recording being unreachable, which that endpoint fixes.

**Six open questions from `reports/2026-09-08-pass41-single-file-route-recon.md` are still
unanswered** and Pass 42 answered none of them: 7.2 (`start: 0` or `start: N` for resume, which is
what blocked build-plan step 7), 7.3 (what the Starting screen should say during a long remux),
7.4 (whether a refused recording should fall back to HLS or show the error), 7.5 (temp space on
Unraid), 7.6 (whether to ask the marlin-dvr project to document the route in `HLS-CLIENT-API.md`),
and 7.7 (the two untracked report files). 7.1 was answered by the owner's Status-page reading and
7.8 was overtaken: the app's own long-wait timeout is built, but no long remux has been observed.

**7.7's files are no longer untracked.** The owner decided on 2026-09-08 that a report the notebook
cites by name belongs in the repo, and **Pass 44 committed and pushed both of them**, unmodified —
`reports/2026-09-08-pass39-three-defects-recon.md` (38,079 bytes) and
`reports/2026-09-08-pass40-session-start-values.md` (24,813 bytes), the two filenames read from
`git status --porcelain --untracked-files=all` in that pass. Each went in byte-identical, verified
by `git hash-object` of the working copy matching the staged blob, with `core.autocrlf` unset and no
`.gitattributes`. Both were scanned for credentials first and none was found
(`reports/2026-09-08-pass44-push-untracked-reports.md`). The push was verified on 2026-09-08 by fetch, `git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading `2fd90cb`, a fast-forward from `aa7f0e8` with nothing forced, rebased or amended.

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

`RailFocusRestoreUITests` (Pass 25) is the same kind of harness and needs the physical Apple TV. Its
four tests are `testEveryRailEntryLandsOnItself` (all nine entries, three rounds),
`testHomeStillDrawsNoRail`, `testReloadsDoNotMoveFocus` (about five minutes — it waits out a full
On Now and Cameras reload cycle twice each) and `testFocusSurvivesAPlayerRoundTrip`, which opens a
camera, the one Player path that holds no tuner.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/RailFocusRestoreUITests"
```

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/WeatherKitEnabledUITests"
```

`TrashRestoreUITests` (Pass 33) is the same kind of harness and needs the physical Apple TV. It reads
Manage DVR → Trash and restores what is in it, so **it only passes with something in the trash** —
put a recording there first with `PUT /api/library/recordings/{id} {"trash": true}` and edit the two
show names in `Self.trashed` to match. It makes two writes, both Restores, and never presses Empty
Trash.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/TrashRestoreUITests"
```

`CommercialSkipUITests` (Pass 38) is the same kind of harness and needs the physical Apple TV, plus
a recording the server has actually detected breaks in — the owner's Philo recordings, not antenna
ones. **It is the one harness that does not call `launch()`**: XCUITest does not forward the app's
`print` output, so the app is started separately with the console attached and the harness uses
`activate()` to join the running process instead of replacing it.

```
xcrun devicectl device process launch --device <Home Theater> --console --terminate-existing \
  com.marlin1111.MarlinDVRTV &
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/CommercialSkipUITests"
```

Two things about that console, learned the hard way in Pass 38: **it drops lines under high output
volume**, so a missing line is not evidence that an event did not happen; and every test leaves a
resume position further into the subject recording than the last, so
`testZResetTheSubjectRecordingsResume` exists to play it out to its end, which is the only thing
that clears one.
