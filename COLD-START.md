# COLD-START — Marlin DVR TV

## What the app is

Marlin DVR TV is a tvOS app (SwiftUI) and a client of the Marlin DVR server — a Go DVR server running as a Docker container on Unraid at http://192.168.1.250:8090/ , source repo git@github.com:marlin1111ai/marlin-dvr.git . What is built is listed under "What is built" below.

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

**The server is marlin-dvr 1.8.0** (owner, 2026-09-08): he read his own Status page and it showed
**VERSION 1.8.0, "up to date · checked 45m ago"**. Not measured from here — the running server is
on this project's do-not-touch list — so this is the owner's own reading, cited the way this file
cites the marlin-dvr project's other version facts. Before that it was **1.7.0**, which the owner
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

Note that the read-only reference clone at `~/Xcode/marlin-dvr-reference` has a **checked-out tree
still at 1.2.1** (`cmd/marlin-dvr/main.go:38`), which has none of this — checking it out is the
owner's job and no pass has done it. **Its `origin/main` was fetched in Pass 41 on 2026-09-08 and
now reads `095de81`** (it read `c417c60` before, and `fba51f2` before that), so their current
sources and notebook can be read out of the clone with `git show origin/main:<path>` without
checking anything out. Server facts are still measured against the running server's own responses
and its `GET /api/logs`, never against the checkout.

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

- **The airing sheet's series-pass chip is wrong for a pass-driven recording.** A recording that a
  series pass started shows **"Record this airing" alongside "Stop recording"** — pressing it would
  earn a 409 from the server. The cause is in the sheet's own gating: Stop turns on
  `Job.status == "Recording"` and correctly ignores `passId`, while the "● Scheduled" chip and the
  Record button are still gated on `passId == "manual"` (`AiringSheet.swift`, `manualJob` `:71-74`).
  **Never driven on the device** — Pass 32 proved Stop for a one-off Record Now, not for a pass.
  Found in Pass 32, scoped out there and in Pass 33. **Unfixed.**
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
defects read-only and fixed none of them; its sorting stands. Note that **the report file itself is
untracked** — commit `424c584` carried only `COLD-START.md` and `DECISIONS.md`, verified in Pass 41
by `git ls-files reports/ | grep -c pass39` returning `0`.

Pass 40 (`reports/2026-09-08-pass40-session-start-values.md`) is untracked and no later pass has
opened it.

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

## Open questions

See the Open Questions sections of `reports/2026-09-05-pass2-server-recon.md` (server recon) and `reports/2026-09-05-pass3-hls-client-recon.md` (HLS client recon). Environment questions from Pass 1 are listed in `reports/2026-09-05-pass1-plumbing.md`.

## Next step

**Nothing is unpushed.** The owner accepted **Pass 42** (the single-file MP4 route) on Home Theater
on 2026-09-08 and **Pass 43 pushed it** together with this notebook work
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
