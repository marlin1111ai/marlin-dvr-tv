# Pass 6 — Sweep 2: the read-only screens (code; separate push gate) — 2026-09-05/06

The five read-only screens of the Pass 4 report §4 sweep 2, built to frames 1b, 3a, 3c, 5a, 5b, 5c, 5d and 5e on the Pass 5 theme, rail and client, replacing the Pass 5 placeholders. Built with both COLD-START lines, run on the tvOS simulator and on the "Home Theater" Apple TV; evidence in §8. **Committed locally only; nothing was pushed** — the owner tests on Home Theater first.

Network use, all against `http://192.168.1.250:8090`: GETs (`/api/channels`, `/api/guide/now`, `/api/guide`, `/api/guide/later`, `/api/schedule`, `/api/library`, `/api/library/shows/{id}`, `/api/cameras`, `/api/cameras/{id}/snapshot.jpg`, `/api/art/show`, `/api/art/feed`, `/api/logs`, `/api/clients`) and the app's `POST /api/clients/{id}/ping`. No play session, no PUT, no POST of any other kind, no DELETE. Nothing installed on the Mac; no packages; no bundled fonts or icons; no Info.plist or build-setting change.

Citation keys: `dc:NNN` = a line of `design/Marlin DVR TV.dc.html`; `Pass 4 §n` = `reports/2026-09-05-pass4-design-and-build-recon.md`; `file:line` = `cmd/marlin-dvr/` in the reference clone at `eef49e8`.

## What was built, file by file (steps 1–7)

All new files are in `Marlin DVR TV/` (synchronized group, no target edits). Line counts by `wc -l`.

| File | Step | What it is |
|---|---|---|
| `Formatting.swift` (90, new) | shared | `TimeFormat` (clock "2:41 PM", range "2:30 – 4:30 PM", short day "Fri Sep 5", weekday, Today/Tomorrow/weekday, midnight test, the current half hour as the server truncates it, guide.go:599-604); `SizeFormat.bytes`; `String.cachedDurationSuffix`, the ", 16 min" the server appends to `airedLabel` only when the probe is cached (library.go:518-523; `humanMinutes` forms, passes.go:301-313). |
| `ScreenChrome.swift` (186, new) | shared | `ScreenHeader` (52 pt title, 26 pt subtitle, trailing slot); `focusTreatment` (4 pt accent ring, lift, shadow); `TagChip` ("NEW", dc:561); `PillLabel` (chips and the guide pills, dc:80-83, 192, 314); `ArtPlaceholder`; `LoadingLine`, `ErrorLine`; `ProgressBar` (dc:93-95); `InertActionButton` (the outlined action of dc:569-571 and dc:602-605); `focusSoon`, which moves focus after the next render — a screen's content does not receive focus on its own beside the rail (observed in this pass, §8.2). |
| `OnNowScreen.swift` (341, new) | 1 | `ChannelChip` (Favorites / All N / HD / one per source name from the channels' `source` field, per the standing call; the server filter and source queries, sources.go:362-386); `OnNowModel` (loads `/api/guide/now` with the chip, DRM-filtered; sources and the playable total from `/api/channels`; refresh time; the next-six-hours fetch `/api/guide?slots=12&source=<its source>` and that channel's row); `OnNowScreen` (header "Refreshed h:mm · N channels", chips, a 3-column grid of `OnNowCard`s, reload every 60 s, long press → `NextHoursOverlay`, Menu closes the overlay else leaves); `OnNowCard` (logo or initials tile 82 pt, "number · name", NEW/LIVE/PREMIERE/FINALE tags, title 31 pt, episode line from `episodeNum · episodeTitle`, the server's `endsIn`, progress from `program.start/end`, dc:87-97); `NextHoursOverlay` (time range · title · episode per program, "Menu closes"). |
| `GuideScreen.swift` (424, new) | 2 | `GuideMark` (● green `#57b083`, ◆ gold `#d6a94e`, dc:1176, 1189); `GuideCellItem` (a program in the window with its clipped start/end fractions); `GuideModel` — window of 2 h from the current half hour, `+12h` = +43 200 s, one `GET /api/guide?start=&slots=48` per 24 h (guide.go:593-596) refetched when the window leaves the fetched range, `GET /api/schedule` alongside; `cells(for:)` re-lays each row from `program.start/end` (once per program, `guideBlock.program`, guide.go:550-558), not from `span`; `mark(for:)` joins a job by `channelId` + `program.start` (passes.go:53-77): `status == "Recording"` → ●, `passId != "manual"` and Queued/Conflict → ◆; `endOfListings` when a whole 24 h fetch has no program; `windowLabel` names both days when the window crosses midnight (dc:311). `GuideScreen` — header with "↩ Now · h:mm" (only when not at now) and "+12h" pills in a focus section, the CHANNEL column header with four half-hour labels (the first of a new day as "Sun · 12:00 AM" with the accent underline, dc:321-327; "· now" on the first when at now), a vertical scroll of `GuideRowView`s, the legend (dc:227-229 / dc:354); Menu: close the sheet → snap to now → leave. `GuideRowView` (initials tile 62 pt, name, number, 300 pt column; cells placed by fraction with 12 pt gaps in a `GeometryReader`); `GuideCellLabel` (title, mark tag, 20 % tint and hairline in the mark's colour, dc:1191-1194). |
| `AiringSheet.swift` (165, new) | 3 | `AiringSelection` (channel, program, the joined job; `artPath` builds `/api/art/show?title=`); `AiringSheet` (dim gradient, 1400 × 586 pt surface, poster 340 × 474 from `/api/art/show` with `PosterFallback` — the channel initials at poster size — when the server has no art (404, artwork.go:458-471); flags as tags; "number · name · HD"; title 60 pt; `episodeTitle · episodeNum`; "Today/Tomorrow/weekday h:mm – h:mm · rating"; description up to five lines; the three inert buttons; the conflict line "✕ Conflict: <reason>" only when the joined job's `status == "Conflict"` (passes.go:475-477) — nothing is predicted). Focus moves to "Record this airing" on appear. |
| `OnLaterScreen.swift` (145, new) | 4 | `OnLaterModel` (`GET /api/guide/later`, guide.go:695-754); `OnLaterScreen` (header with the design subtitle and the clock, two columns from the two sections, each a vertical scroll of `LaterRow`s); `LaterRow` (92 pt art or placeholder, title 31 pt, subtitle, "channel · when", the "● Scheduled" pill when `scheduled`, dc:458-468). Selecting a row is inert (later sweep). |
| `RecordingsScreen.swift` (176, new) | 5 | `RecordingsModel` (`GET /api/library?limit=6`, library.go:427-469); `RecordingsScreen` (header "N shows · M recordings" — no TB figure; the design's note; the response's three shelves, each a horizontal row of `PosterCard`s, "Nothing yet." when empty; selecting a show opens `ShowDetailScreen`; Menu returns to the shelves with focus on the first card, else leaves); `PosterCard` (252 × 344 art from `art`, the "N new" badge from `unwatched`, title, "N episodes"; focused = ×1.17, lifted 22 pt, 4 pt ring, shadow, dc:1273-1275). |
| `ShowDetailScreen.swift` (231, new) | 6 | `ShowDetailModel` (`GET /api/library/shows/{id}`, library.go:586-640; `summaryLine` = "N episodes · M unwatched · <sum of episode sizes> · <most common channel>"); `ShowDetailScreen` (poster 520 × 472, title 52 pt, the summary line, "Play newest" and "Series pass" inert — no resume line; "Episodes · Newest first"; `EpisodeRow`s; the design's long-press footer line, inert); `EpisodeRow` (thumb 236 × 133 from `thumb`, "S9 E12" from season/episode, title, "✓ Watched", description two lines, "Aired Sep 5, 2026 · 16 min · 579.35 MB" with the duration only from the cached suffix — nothing calls `mediainfo` — and the tags as hairline chips). |
| `CamerasScreen.swift` (168, new) | 7 | `CamerasModel` (`GET /api/cameras`, hidden ones dropped, cameras.go:280-289; a `tick` that changes the snapshot query every reload so the image is fetched again; reload every 45 s); `CamerasScreen` (header "N of M online", "Snapshot age N s · click for live view" ticking each second, a 2-column grid of `CameraCard`s); `CameraCard` (snapshot from `/api/cameras/{id}/snapshot.jpg?v=<tick>`, cameras.go:419-434, 330 pt tall; the Online/Offline pill; name 31 pt; codec upper-cased; "✕ <lastError> · checked <lastCheck>" when offline). Selecting is inert. |
| `ScreenShell.swift` (85, Pass 5 file) | wiring | Routes the five destinations to their screens (`content`), passes `onLeave`; the content is no longer itself focusable — each screen owns its focus; Menu fallback kept. |
| `ContentView.swift` (39), `Marlin_DVR_TVApp.swift` (30) (Pass 5 files) | wiring | The `APIClient` is kept by the app and handed to `ContentView` → `ScreenShell`. |
| `ServerImage.swift` (68, Pass 5 file) | 7 | The loaded image is drawn as an overlay on `Color.clear` and clipped, so it takes the caller's frame and never widens its container — the 480 × 180 camera snapshot in fill mode had pushed its card past the grid cell (§8.2). |

Standing calls applied: counts and lists cover every playable channel across sources; chips are Favorites / All N / HD / "HDFX-4K (10A75953)" / "Philo" (the source names the server returns); DRM channels never appear (the Pass 5 filter inside every typed call). Inert as drawn: Watch live, Record this airing, Record the series (5c), Play newest, Series pass, the episode long-press menu (5d), On Later rows (5a), camera live view (5e). No resume line and no resume bars until the resume store exists.

How Menu behaves (the exit command): On Now — closes the next-hours overlay, else leaves; Guide — closes the airing sheet (focus returns to the cell), else snaps to now, else leaves; Recordings — leaves show detail (focus returns to the first card), else leaves; On Later and Cameras — leave. Leaving returns to Home; Menu on Home exits the app (tvOS default).

## 8. Test evidence

### 8.1 Builds — both COLD-START lines, final code

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build
(build exit 0)
252: ** BUILD SUCCEEDED **

$ xcodebuild -project "Marlin DVR TV.xcodeproj" -target "Marlin DVR TV" -sdk appletvsimulator -configuration Debug build
(exit 0)
529: warning: ONLY_ACTIVE_ARCH=YES requested with multiple ARCHS and no active architecture could be computed; building for all applicable architectures
530: ** BUILD SUCCEEDED **

$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build
(exit 0)
144:     Signing Identity:     "Apple Development: wayne Coburn (K876F53J4H)"
173: ** BUILD SUCCEEDED **
```

No Swift errors or warnings in any build; the one warning is the target/SDK form's architecture note, as in Pass 5. The target/SDK line was run once, on the code two edits before final (the last two edits touched text and focus only); the scheme and device lines were run on the final code.

### 8.2 Simulator — screenshots (`reports/assets/pass6/`, `xcrun simctl io booted screenshot`, downscaled 3840×2160 → 1920×1080 with `sips -Z 1920`)

Key presses went to the Simulator through `osascript` (`System Events` key codes: Return = Select, arrows, Escape = Menu), each after activating the Simulator and checking it was frontmost — the owner was using the Mac during the run and several early presses had gone to another app. Four duplicate Home captures taken after Menu on each screen were deleted; `08-home-after-guide.png` stands for that transition.

| File | What it shows |
|---|---|
| `00-home.png` | Home after launch (sweep 1), Guide tile focused. |
| `01-guide.png` | Guide at now: window "Sat Sep 5 · 11:30 PM → Sun Sep 6 · 1:30 AM" (midnight crossing named, dc:311), columns "11:30 PM · now", "Sun · 12:00 AM" with the accent underline, "12:30 AM", "1:00 AM"; eight rows; cells laid from start/end (a 6-minute sliver on WJZ-TV before "Retire Smart Maryland", a 2-hour cell for "Saturday Night Live", "Cyc…" a 10-minute cell on NHK-WLD); legend; "+12h"; focus on the first cell. |
| `02-airing-sheet.png` | Select on "The Good News": the sheet with the server's poster, "2.1 · WMAR-HD · HD", the title, "Today 11:30 PM – 12:00 AM", the three inert buttons with "Record this airing" focused. (The later run on "Saturday Night Live" also showed the episode line "Sabrina Carpenter · S51E03" and the description.) |
| `03-guide-after-sheet.png` | Menu closed the sheet; focus back on the cell. |
| `05-guide-focus-up.png` | Up from the grid reaches "+12h" (header focus section). |
| `06-guide-paged.png` | After +12h: "Sun Sep 6 · 12:00 – 2:00 PM", the "↩ Now · 12:16 AM" pill, the legend "Menu snaps back to now · forward only, 24 hours per request", the list scrolled to the first row with listings (AETV) with focus on "Alaska State Troopers"; 30-minute and 60-minute cells on AETV/HISTORY/FYI. The antenna rows above are empty at that hour (§8.6). |
| `07-guide-after-menu.png` | Menu snapped back to now (window "12:00 – 2:00 AM", "Sun · 12:00 AM · now"). |
| `08-home-after-guide.png` | Menu at now left the Guide for Home. |
| `10-on-now.png` | On Now: "Refreshed 12:03 AM · 36 channels", chips Favorites / All 45 / HD / HDFX-4K (10A75953) / Philo, the 3-column cards with logos, NEW tags, episode lines, "ends …" and progress bars. |
| `20-on-later.png` | On Later: "On Today" and "On This Week" columns with art, subtitle, "channel · when"; nothing carries "● Scheduled" because the schedule is empty. |
| `30-recordings.png` | Recordings: "3 shows · 3 recordings", the note, shelves Recently Watched ("Nothing yet."), Recently Updated, Recently Added; the focused MythBusters card enlarged and lifted with its "1 new" badge. |
| `31-show-detail.png` | Show detail: poster, "MythBusters", "1 episode · 1 unwatched · 607.5 MB · 9018 SCIENCE", "Play newest" (focused) and "Series pass"; the episode row "S5 E13 Grenades and Guts", description, "Aired Sep 5, 2026 · 16 min · 579.35 MB" — the 16 min came from the cached suffix, no ffprobe — and the tags. |
| `32-recordings-after-menu.png` | Menu from show detail: back on the shelves with the first card focused. |
| `40-cameras.png` | Cameras: "1 of 1 online", "Snapshot age 8 s · click for live view", the Cow Cam card with the live snapshot, "Online", "Cow Cam · HEVC". |

Console lines from the runs (the app's `print`s through `simctl launch --console-pty`):

```
[client] ping ok: id=cmtp93dxwb8c6f8 name=Apple TV 4K (3rd generation) app=Marlin DVR TV 1.0 type=Apple TV os=tvOS 26.5 ip=192.168.1.10
[guide] menu: sheet=true atNow=true       ← Menu closed the sheet
[guide] menu: sheet=false atNow=false     ← Menu snapped to now
[guide] menu: sheet=false atNow=true      ← Menu left the Guide
[onnow] menu: overlay=false               ← Menu left On Now
```

Two things found and fixed during the run, both visible in the earlier captures I replaced: (1) on entering a screen, focus landed on the rail's Home item, so the first Select went Home — every screen now moves focus into its content once data arrives (`focusSoon`); (2) the camera card overflowed its grid cell because the 480 × 180 snapshot in fill mode widened its container — `ServerImage` now sizes by the caller's frame; the focused poster card was clipped by its shelf — padding added.

### 8.3 Guide rows and columns, counted by hand against frame 3a

From `01-guide.png`: rows WMAR-HD 2.1, WGAL-TV 8.1, WBAL-DT 11.1, WJZ-TV 13.1, MPT-HD 22.1, MPT-2 22.2, MPTKIDS 22.3, NHK-WLD 22.4 = **8 rows** visible; time columns 11:30 PM, 12:00 AM, 12:30 AM, 1:00 AM = **4 columns** of 30 minutes = a 2-hour window. Frame 3a: "8 rows, 2-hour window" (dc:176), four `guideTimes` (dc:1207), eight `guideComfort` rows (dc:1203). Match. The remaining 37 playable rows scroll below.

### 8.4 The ● and ◆ marks

Not exercised: during the whole test `GET /api/schedule` answered `count 0, passes 0, groups []` — nothing scheduled or recording on the server (no pass exists and no Record Now was booked; this pass may not create one). The join is implemented (`GuideModel.mark(for:)` on `channelId` + `program.start`) but no airing carried a mark, and the airing sheet's conflict line was likewise never shown. Stated plainly as untested; the owner's first pass or Record Now on the web UI will show it.

### 8.5 Home Theater — install, launch, and the server's log for that one launch

```
$ xcrun devicectl device install app --device [REDACTED] ".../Debug-appletvos/Marlin DVR TV.app"
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
$ xcrun devicectl device process launch --device [REDACTED] com.marlin1111.MarlinDVRTV
Launched application with com.marlin1111.MarlinDVRTV bundle identifier.
```

`GET /api/logs?since=1828` fifteen seconds later — every line the server logged after the launch (the app is at 192.168.1.30):

```
seq=1829 00:17:53.205 INFO [HTTP]  POST /api/clients/cmtp95bma18e6ad/ping 200
seq=1830 00:17:53.212 INFO [HTTP]  GET /api/channels 200
seq=1831 00:17:53.213 INFO [HTTP]  GET /api/library 200
seq=1832 00:17:53.215 INFO [HTTP]  GET /api/cameras 200
seq=1833 00:17:53.215 INFO [HTTP]  GET /api/schedule 200
seq=1834 00:17:53.217 INFO [HTTP]  GET /api/guide/now 200
seq=1835 00:18:05.035 ERR  [GUIDE] HDFX-4K (10A75953): HDHomeRun guide fetch failed: HTTP 403
```

One ping and five GETs (Home's tiles); nothing else from the app. The last line is the server's own guide refresh, not app traffic (§8.6). `GET /api/clients` afterwards:

```
id=cmtp95bma18e6ad name='Apple TV' app='Marlin DVR TV 1.0' os='tvOS 26.6' ip=192.168.1.30 online=True lastSeen=now
id=cmtp93dxwb8c6f8 name='Apple TV 4K (3rd generation)' app='Marlin DVR TV 1.0' os='tvOS 26.5' ip=192.168.1.10 online=True lastSeen=now
```

The app is left installed and running on Home Theater, on Home. Device screenshots cannot be taken from the Mac; the screens above are the simulator's.

### 8.6 A server-side finding met during the test

The server logged `HDHomeRun guide fetch failed: HTTP 403` for the antenna source at 00:14 and 00:18 (seq 1774, 1835). The antenna channels' listings end around 1 AM Sunday: a `GET /api/guide?start=<Sun 12:00 PM>&slots=48` (8 ms, 484 KB) returned 50 rows of which 29 carry programs — the Philo rows — and the first eight rows (all antenna) are "No listing" across the 24 hours. That is why the paged guide's antenna rows are empty in `06-guide-paged.png` while the Philo rows have cells. A matter for the marlin-dvr project (Open Question 4); the app shows what the server has.

### 8.7 What could not be tested here

The long press on an On Now card (step 1). Holding Return through `System Events` does not register as a press-and-hold in the tvOS Simulator and leaves its remote input stuck, after which every key is swallowed (two earlier runs were lost to it). The overlay code path is unexercised; the owner's click-and-hold on the Siri Remote is the test (Open Question 3).

## Open Questions

1. **Antenna chip label.** The chip reads "HDFX-4K (10A75953)", the source's server name (standing call); the design says "Antenna" (dc:83). Map `type == "hdhomerun"` sources from `/api/sources` to "Antenna", or rename the source on the server?
2. **Default chip.** The design's mock has Favorites active (dc:80); the server has no favourites, so the app opens on All. Confirm.
3. **Long press.** Unverifiable on the simulator (§8.7). Does click-and-hold on the Siri Remote open the next-six-hours list on Home Theater, and does Menu close it?
4. **HDHomeRun guide fetch 403** (§8.6): the antenna guide is not refreshing on the server; paged windows on antenna rows stay empty until it is. For the marlin-dvr project.
5. **Day word on the sheet.** A program that started yesterday and is still on reads "Saturday 11:29 PM – 1:03 AM"; "Yesterday"/"Tonight" wording is a choice.
6. **Tag chips truncate** on the episode meta row when the description is wide ("H2…", "Ster…"). Wrap the tags to a second line, or drop the codec tag?
7. **On Later selection** is inert; the design implies the airing sheet from there (Pass 4 §3.6). Wire it in the next pass?
8. **"24 hours per request"** is implemented as a 48-slot fetch per window start; "+12h" hides only when a whole 24-hour fetch has no program at all, so with the antenna outage paging continues through Philo listings. Acceptable?
9. **Conflict line and marks** untested (§8.4).
10. **Third shelf.** The server's "Recently Updated" section is shown between the design's two (dc:1313-1330). Keep all three?
11. **Menu on Home** exits the app (tvOS default). Wanted?
12. **Console diagnostics** (`[guide] menu`, `[onnow] menu`, `[onnow] long press` prints) stay in the code; remove later?
13. **Camera codec line** shows "HEVC"; no resolution exists (Pass 4 OQ 11). Fine as is?
14. **Snapshot staleness.** The app re-requests every 45 s and the server caches 45 s (cameras.go:201), so a frame can be up to ~90 s old; `refresh=1` forces a probe but was not asked for.
15. **Focus on entry** needed a programmatic nudge (`focusSoon`) because SwiftUI put initial focus on the rail; it works in every screen tested, but it is a workaround worth a second look on hardware.
16. **Guide click-to-play — sweep 3 item** (owner decision, 2026-09-06, DECISIONS.md): clicking a program that is airing now plays it immediately; the airing sheet opens on click only for programs that have not started; press-and-hold on a current cell opens the sheet (record/pass). Sweep 2 opens the sheet on every click; the split is built in sweep 3 with the Player.

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/OnNowScreen.swift` (new) | 1 |
| `Marlin DVR TV/GuideScreen.swift` (new) | 2 |
| `Marlin DVR TV/AiringSheet.swift` (new) | 3 |
| `Marlin DVR TV/OnLaterScreen.swift` (new) | 4 |
| `Marlin DVR TV/RecordingsScreen.swift` (new) | 5 |
| `Marlin DVR TV/ShowDetailScreen.swift` (new) | 6 |
| `Marlin DVR TV/CamerasScreen.swift` (new) | 7 |
| `Marlin DVR TV/Formatting.swift`, `ScreenChrome.swift` (new, shared) | 1–7 |
| `Marlin DVR TV/ScreenShell.swift`, `ContentView.swift`, `Marlin_DVR_TVApp.swift` (Pass 5 files: routing and the API client handed through) | wiring |
| `Marlin DVR TV/ServerImage.swift` (Pass 5 file: image sized by the caller's frame) | 7 |
| `reports/assets/pass6/*.png` (14 files) | 8 |
| `COLD-START.md` — "What is built", "What is NOT built", "Next step" | deliverable |
| `reports/2026-09-05-pass6-sweep2-screens.md` (this file) | deliverable |
| `build/` (ignored) — the target/SDK build line's output | 8, not committed |
| Local commit "Pass 6: sweep 2 — On Now, Guide, On Later, Recordings, Cameras"; **no push** | deliverable |

Untouched: `DECISIONS.md`, `Info.plist`, the project file and build settings, `Assets.xcassets`, every other Pass 5 source (`Theme.swift`, `ServerAPI.swift`, `Models.swift`, `ChannelFilter.swift`, `ClientSession.swift`, `Destination.swift`, `RailView.swift`, `HomeView.swift`). Outside the repo: DerivedData, the app on the booted simulator and on Home Theater. The reference clone and `design/` were only read. No request went beyond port 8090 of the server; no request to marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing installed; no packages; no third-party code.

## Pass 6B — acceptance, guide click decision, push (2026-09-06)

**Owner's acceptance:** sweep 2 tested on Home Theater 2026-09-06, all screens work. The Pass 6 commit `51d0381` was approved for push.

**Decision recorded** (`DECISIONS.md`, `## 2026-09-06 (sweep 2)`): clicking a program that is airing now plays it immediately; the airing sheet opens on click only for programs that have not started; press-and-hold on a current cell opens the sheet (record/pass). Built in sweep 3 with the Player. Added above as Open Question 16 (sweep 3 item). No code changed in this pass: the sweep 2 Guide still opens the sheet on every click until sweep 3 wires the Player.

**Push.** Pass 6B commits `DECISIONS.md` and this report as "Pass 6B: acceptance; guide click-to-play decision" and pushes `origin main`, carrying the approved `51d0381` as well. The three-SHA verification (local `HEAD`, `origin/main` after `git fetch`, `git ls-remote origin main`) is stated in the pass's closing reply; no follow-up commit writes it here.
