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

The standing builder rules live in `CLAUDE.md` at the project root. Read it. This file no longer keeps its own copy of them; a rule change is made in `CLAUDE.md` only (DECISIONS.md, 2026-09-09 (Pass 60)). One standing rule is the owner's about this project's own hardware rather than the builder's conduct, and it is kept with the devices it governs: **the bedroom Apple TV is brought up with every proven batch** — see *Standing state of the devices and the evidence* (DECISIONS.md, 2026-09-16 (Pass 102)). It is written there once, not copied here.

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

Current state only — one line per screen and one per standing fact, each citing the pass it comes from. The pass-by-pass narrative this section used to be is history now (the pointer is the last line of this file); nothing below is new, and where an earlier entry was superseded by a later one, the later one is what is written (the resolutions are listed in `reports/2026-09-13-pass89-cold-start-trimmed.md`).

### The server

- **The server is marlin-dvr 1.9.1**, measured from `GET /api/status` on 2026-09-16 (Pass 101). It superseded the 1.8.2 read on 2026-09-13 (Pass 85), which superseded the 1.8.1 read in Passes 71 and 72, which superseded the owner's own 1.8.0 and 1.7.0 readings of 2026-09-08 (Pass 72, Pass 85). **1.9.1 writes an `.mp4` sidecar beside the `.mpg` when a recording finishes and serves that file directly on `format:"file"` with byte ranges and no remux** — relayed by the owner from the marlin-dvr project, 2026-09-16 (Pass 101).
- Three server facts this app depends on: **`GET /api/library/trash` exists** (1.6.0) and Manage DVR → Trash is built on it (Pass 33); **automatic pruning is gone server-side — a series pass never trashes anything on its own**, so the keep rule in the Edit series pass screen no longer causes deletions by itself (owner, 2026-09-07; Pass 34); **the single-file MP4 playback route exists** — `POST /api/play/sessions` with `"format":"file"`, served at `GET /api/play/file/{id}/video.mp4` — new in 1.8.0 (Pass 42).
- **`HLS-CLIENT-API.md` in the marlin-dvr repo is behind their server**: byte-unchanged across the whole 1.8.0 delivery, its header still says 1.7.0, and `"file"` is not listed anywhere in it; §2.3 of `reports/2026-09-08-pass41-single-file-route-recon.md` is the only written description of that route, read from their Go source (Pass 41).
- **The reference clone `~/Xcode/marlin-dvr-reference` has `HEAD` and `origin/main` both at `eb0c098`**, a checked-out tree at 1.8.1, so their sources and notebook can be read out of it directly; server facts are still measured against the running server's own responses and its `GET /api/logs`, never against the checkout (Pass 72; still `eb0c098` at Pass 85).

### Foundation, packaging and the two Apple TVs

- The foundation: ATS exception, API client, models, DRM filter, image loader, client register/ping (Pass 5).
- The app signs against **`tvOS Team Provisioning Profile: com.marlin1111.MarlinDVRTV`** rather than the team wildcard, through a `Marlin DVR TV.entitlements` carrying `com.apple.developer.weatherkit` and `CODE_SIGN_ENTITLEMENTS` in the app target's two configurations (Pass 22).
- **The app has a real icon and Top Shelf art**: the owner's `AppIcon.brandassets`, copied byte-identical into the project's catalog, with `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` the only project change; both icon-stack layers point at the same two opaque files (owner's choice); the artwork says "MARLIN TV" and that is not to be raised again; `FocusClick.dataset` stays in `icon-source/`, untouched; the empty template brandassets is left in place; `CFBundleIconName` is correctly absent on tvOS and no later pass should hunt for it (Passes 51–55).
- **The app is installed on two Apple TVs** — Home Theater and **"Master Bedroom ATV"** (Apple TV 4K, `AppleTV6,2`, tvOS 26.6) — the bedroom one by Pass 54's method to the same device: `xcodebuild -destination 'platform=tvOS,name=Master Bedroom ATV' -allowProvisioningUpdates build`, then `xcrun devicectl device install app` (Passes 54, 83); which build each runs is in "Next step" below. **Both are development-signed builds that will stop launching when the provisioning profile expires; when that is has not been checked** (Passes 54, 83).
- **This project keeps no separate handoff-brief file: `COLD-START.md` and `DECISIONS.md` are the whole record** (owner, 2026-09-08); the one brief ever written was folded in and deleted (Pass 56).
- A pass records its verified push in its response and in the next pass's notebook entry, never in its own commit — a commit cannot contain its own SHA — and its report goes inside its own commit before the push (DECISIONS.md, 2026-09-09 (Pass 60) rule (b); 2026-09-11 (Pass 68)).

### The screens — what each does today

- **Home** (Pass 5): the launcher, a 3 × 3 tile grid with no rail (Passes 25, 62–65); reads six endpoints, and the Radio tile says "*n* stations" from `GET /api/radio`'s `count`, falling back to the word "Stations" and never showing a stale number (Pass 20); the weather glance (frame 2a) draws real WeatherKit data (Pass 22); the On Later tile still counts scheduled bookings from `GET /api/schedule` — "*n* upcoming" — not airings (Pass 82).
- **The rail** (Pass 5): Manage DVR lives in its bottom slot (Pass 10B); a swipe left lands on the entry that opened the screen you are on, every screen, every time — `ScreenShell.railRestore`, fired on the crossing from the content into the rail and never again — proven for all nine rail-drawing entries, 27 of 27 (Pass 25); the Radio entry is live (Pass 19); Search is the eleventh entry, directly under Radio and above Manage DVR, with no Home tile (Passes 62–65).
- **On Now** (Pass 6): the channels with what is on now, reloading every 60 s without moving focus in the rail or the content (Pass 25); clicking a channel plays it live through the Player (Pass 7).
- **Guide** (Pass 6): the grid with the airing sheet; cells are placed and sized from `program.start`/`end`, the app never reads `span` or `empty`, and a listings gap draws as empty background (Pass 26); ● SCHEDULED / ◆ SERIES PASS marks (Pass 8); click-and-hold on a channel cell favourites it and a click on it does nothing (Pass 9); "Guide" · a collections button · the date range · ↩ Now / +12h in the header, the button dropping the app's own overlay of "All Channels" and every collection, `GET /api/guide?filter=<collection id>` filtering and ordering the grid server-side, the pick remembered in the `UserDefaults` key `"marlinGuideCollection"` across a rail trip and a relaunch, a stale id reverting to All Channels silently, and the empty state "Nothing in <name> right now" with focus on the button (Passes 71–74); Right on the last visible cell of a row moves the window forward one slot, forward only, with the strip and every row together, refetching once every 45 slots, focus staying on the same programme while it is in the window (Passes 75–78); a beat once a minute republishes the screen's clock, a window sitting at now rolls to the new current half hour at each half-hour boundary, a scrolled window never rolls, the `↩ Now · 2:04 PM` pill tracks the clock, and the beat stops with the screen (Passes 79–80); the channel cell draws the channel's logo through `/api/art/feed?u=` plus the Go-escaped source URL, aspect-fitted 6 pt inside the 62 pt tile on a `Nocturne.neutral200` (`#E4E7F5`) backing, and the initials tile with no backing when `logo` is empty or fails to load — 96 `GET /api/art/feed` for the Guide's 96 logo rows, the one 404 being 50002 Science Channel's `.svg` — with the white antenna logos' faint contrast on the backing (1.23:1 and 1.14:1) shown to the owner and accepted as built (Passes 86–87).
- **The airing sheet** (Pass 8): "Record this airing" (`POST /api/record`) and "Record the series" (`POST /api/passes`); "Edit series pass" instead of "Record the series" when the show already has one, with no raw 409 ever shown, "Watch live" only while the programme is on, and buttons that fit (Pass 9); "Stop recording" while `Job.status == "Recording"`, armed on the first click, with the schedule re-read when the sheet opens and after a write (Pass 32); the first control reports the airing's own state — "● Recording" or "● Scheduled", not pressable — and is "Record this airing" only when it has none, never hidden; a pass-scheduled airing shows a green "● Scheduled" chip where the Guide draws gold ◆, raised and left as built (Pass 49).
- **On Later** (Passes 81–83): On Now's page layout with three pills — "On Today" · "On This Week" · "Premieres" — listing every upcoming airing on the channels the owner's collections hold, opening on On Today every visit with the pick not persisting; the route is `GET /api/guide?filter=<collection id>&slots=48`, seven requests per non-empty collection, fetched once per visit, a pill press making no request; `GET /api/guide/later` is no longer read and `api.later()`, `LaterResponse`, `LaterSection` and `LaterItem` are left in place uncalled; the server never sets `premiere`, so the Premieres pill runs the owner's derived rule and selects nothing on his data today, accepted; the DRM filter applies through `.playable`; Select opens the airing sheet with the programme re-read from `GET /api/guide/search?title=`; the block builder's loss of 2 airings in 140 over a week, both on ESPN, is accepted.
- **Recordings and show detail** (Pass 6): the shelves and show detail; click-and-hold on an episode offers Keep and Delete (`PUT /api/library/recordings/{id}`), a trashed episode leaving the list, and the episode list is reachable with the remote (Passes 8, 9); after a Keep or Delete the shelves re-read `GET /api/library` while show detail is still on top, with focus repaired only when the focused card is gone (Pass 31); the focused poster card grows its real layout box 252×344 → 296×404 with the 22 pt lift and nothing clips, the row reflows sideways and the shelves below shift down 60 pt while a card is focused — both accepted — and the title and episode count no longer enlarge on focus (Pass 47); **the first shelf is the app's own "Continue watching"** — the recordings *this* Apple TV has an unfinished saved position on, from `ResumeStore`, newest position first, one card per recording with "S6 E17 · 40 min in" where a show card counts episodes and no "n new" badge, resolved through `GET /api/library/shows/{id}` because the server has no per-recording read, not drawn at all when it is empty — **and the server's "Recently Watched" shelf is not drawn**, while "Recently Updated" and "Recently Added" stay the server's; it is per Apple TV, so the two Apple TVs differ (Pass 91); each of those cards carries a **6 pt progress bar across the bottom of its poster**, `position ÷ duration` from the numbers already on the card and so costing no request, filled `Nocturne.accent` on `Nocturne.bg` at 0.7, inside the card's corner radius and adding nothing to its layout box, no bar at all when the stored duration is 0, and none on any other shelf's cards (Pass 92); **show detail's second button is the airing sheet's series-pass control, reached from a show** — "Record the series" when `GET /api/passes` holds none for the title, "Edit series pass" once it does, opening the same `EditSeriesPassScreen` the Guide and Manage DVR open, with the sheet's own 409 handling, its result text and its gold `◆ Series pass · n recordings scheduled · all/new episodes` line under the buttons (on two lines, where the sheet's fits on one); the match is on the title alone because a show carries no `seriesId`, no `GET /api/schedule` is read because this screen draws no airing state, and there is no `recordMode: "new"` warning because the sheet has none; **the press itself, the 409, the failure branch and the button's change after an add or a delete were code-traced only when it was built** — no write was sent — **and they are covered now by the owner's acceptance on Home Theater by eye, "all checked and good", not by any measurement this project holds** (Passes 103, 104).
- **Cameras** (Pass 6): reloads every 45 s without moving focus (Pass 25); a camera plays through the Player, the one Player path that holds no tuner (Passes 7, 25).
- **Player** (Pass 7): HLS sessions per `HLS-CLIENT-API.md`, `AVPlayerViewController` with the overlays of frames 6a–6h, the per-Apple-TV resume store and watched-on-end, live channels with the server's time-shift buffer, cameras, and the entry points from On Now, the Guide, the airing sheet, show detail and Cameras; "Stop the recording and watch" on a tuner-busy 502 — `POST /api/schedule/jobs/{id}/stop`, then the live session (Pass 8); frame-by-frame on a paused recording by left and right clicks only — an exact seek to `currentTime() ± 1/fps` with both tolerances `.zero`, never `step(byCount:)`, +0.033367 s a click at 29.97 fps — with `armArrowOwnership` disabling `AVPlayerViewController`'s own arrow recognizers while the app owns the arrow and restoring them otherwise, and a frame rate believed only within 5 % of a real one (Passes 28, 29); commercial skip — a five-second prompt bottom-right at the start of a detected break, Select landing exactly on `endSeconds` by the in-item exact seek, only `state: "detected"` from `GET /api/library/recordings/{id}/commercials` arming it, one fetch per playback, `armSelectOwnership` claiming Select only while the prompt is up (Pass 38); **recordings play as one complete, seekable MP4 through the single-file route** — chosen at `PlayRequest.swift:49`, reaching the wire at `PlaybackSession.swift:70`, the response's `format` field checked, a `Range: bytes=0-0` first fetch on its own `URLSession` with an 11-minute timeout — while live TV, cameras and radio stay on HLS; a recording still being written or not H.264/AAC is refused with the server's 502 text and never routed back to HLS; the Starting screen says "Preparing the recording" during the remux wait, indistinguishable from a stall (Pass 42); **a resumed recording asks the server for the whole recording — `start: 0` on the wire, whatever the saved position — and the app seeks to that position itself once the item reaches `.readyToPlay`**, an exact in-item seek with both tolerances `.zero` and the same `seekableRange` clamp `frameStep` uses, so **there is picture before the resume point and the viewer can rewind into it**; `tick()` publishes nothing for the recording until that seek lands, so the HUD never shows 0:00 and no break is spent by a position the viewer never saw; **it costs the whole recording's remux every time — measured at 10.916 s and 7.567 s press-to-picture on Home Theater, 85–94 % of it the server's remux, against the owner's 2 s requirement, and nothing was built to shorten it** (Pass 96); **a restarted recording reaches its target the same way** — `restart(at:)` no longer pre-seeds `startOffset` with the target and the target travels in `position` to `armResumeSeek`, with the teardown otherwise unchanged — but **no restart caller can be reached from the remote, so that path is traced and has never been driven on a device** (Pass 98); **the LIVE badge over a recording and the wait before fast-forward are closed** by that route on the owner's own test; **the audio/video desync on recordings is not this app's** and no client-side compensation has been built or is to be (Passes 39, 42).
- **Favorites** (Pass 10): the server's favourite channels with what is on now; clicking one plays it live; it lists and plays every favourite channel whether or not the guide has a listing (Pass 26).
- **Manage DVR** (Pass 10, in the rail's bottom slot per Pass 10B): the storage line from `GET /api/system`; Scheduled Recordings grouped, with Cancel recording and Manage pass; Your Passes — the pass editor, with Pause/Resume; Trash — Restore per row, Empty Trash behind two clicks — with every count the server's; Trash reads `GET /api/library/trash` into its own eight-field `TrashItem`, Restore is proven live, a recording's id changes while it is in the trash and Restore changes it back so `ResumeStore` survives a restore, and the empty-state sentence is focusable so Menu still reaches `.onExitCommand` (Pass 33); the Trash list comes from that endpoint and nothing else — the per-show walk and a client-side id cache are both rejected on the record (Pass 34).
- **Edit series pass** (Pass 9): record mode, padding, keep rule, delete with a confirm; the keep rule no longer causes deletions by itself (owner, 2026-09-07; Pass 34).
- **Weather** (Pass 13): frame 5f, fed only by WeatherKit, with the one-shot location prompt cached after the first grant and a spoken state for every way it can fail; **populated with real data on Home Theater since WeatherKit was enabled on the explicit App ID** — the current-conditions line, 8 hourly columns, 5 daily rows with range bars, the Apple Weather attribution — with the three defects that only content could reveal fixed; **the alert card has still never been drawn with real data** (Pass 22).
- **Radar** (Pass 13): `MKMapView` in `UIViewRepresentable` with `MKTileOverlay` + `MKTileOverlayRenderer`, reachable from the Weather screen; the source is **NOAA** — the NWS MRMS base-reflectivity `ImageServer`, free, no key, public domain — with each tile's z/x/y converted to a bounding box for `exportImage` and frame times from NOAA's own mosaic catalog (Pass 14); it **animates** by attaching and detaching exactly one frame's overlay at a time over everything NOAA offers, and refreshes every five minutes while on screen, the timer cancelled on disappear (Pass 15); `RadarTileStore` keeps fetched tiles in memory only, bounded at 96 MB, emptied by `RadarModel.stop()`, cutting 2,327 requests a minute to 53 and about 5 at rest, at a 900 ms frame pace with a 2,200 ms hold (Pass 16).
- **Radio** (Pass 19): a two-column grid of station tiles — the icon the DVR has cached plus the name, in the server's order, never sorted — and a now-playing bar with that station's icon, name and a Stop; audio is a bare `AVPlayer` on the URL the server gives, with no play session, no HLS, no keep-alive, no `AVPlayerViewController` and no MIME option; leaving the screen or the foreground stops the stream; **both of the owner's stations play**, including the `.aac` mount, and AVPlayer follows the StreamTheWorld 302 (Pass 19); the Home tile's station count is Pass 20's.
- **Search** (Passes 62–65): type a programme title on the Siri Remote and `GET /api/guide/find?q=` answers as you type — case-insensitive substring on the title, at most 20 rows with the true total in `count`, "Showing the first 20 of *n* matches · type more of the title to narrow it" — and clicking a row reconstitutes the airing from `GET /api/guide/search?title=`, never from `GET /api/guide`, opening the airing sheet with every control live; DRM results are filtered out silently; the query and results survive a trip to the rail; the input is tvOS's `.searchable`, not a hand-built `TextField`; the sheet-close focus rebuild (a `generation` counter) is load-bearing and was measured twice — do not remove it a third time without the device saying so; the screen's own header sits below tvOS's search field, and the keyboard strip scrolls off the top and takes a walk to come back to — both accepted as built.

### Standing state of the devices and the evidence

- **STANDING RULE — the bedroom Apple TV is brought up with every proven batch.** The owner's words, 2026-09-16: **"whenever we done doing updates and they a proven always update the bedroom"**. Once a batch is proven on Home Theater, updating the bedroom Apple TV to that same build is **its own step of that work**, not a separate pass to be scheduled later and not something to leave until asked. Until the next batch is proven the two televisions may legitimately differ, and *Next step* says which build each is on (DECISIONS.md, 2026-09-16 (Pass 102)).
- **The owner's four pre-1.6.0 trashed recordings are gone — do not go looking for them.** His own web-UI `POST /api/library/trash/empty` at 20:51:50 on 2026-09-07 permanently deleted all four; `6007a13f0b46` no longer exists; the old-form trash entry can no longer be produced (Pass 33).
- Pass 32's two leftovers, `midday-maryland` `b7a3822d83b4` and `the-view` `eccf81dbdab2`, are back in the library and clean, and they were the only ids ever authorised for trash-and-restore evidence (Pass 33).
- Two Pass 42 device runs left a resume position deep inside *History's Greatest Mysteries* S4 E14 "Who Is D.B. Cooper?" on Home Theater; it is per-Apple-TV, only playing the recording to its end clears it, and `CommercialSkipUITests/testPromptAppearsAndSelectSkips` keeps failing until it is cleared (Pass 42).
- **Evidence harnesses, not standing tests**, one per pass in `Marlin DVR TVUITests`, most needing the physical Apple TV and the real remote: `RemoteHoldUITests` (Pass 9); `ManageDVRUITests` and `RailManageUITests`, which drive the Simulator, the first needing a scheduled recording and a series pass (Pass 10); `RadioUITests` (Pass 19); `HomeRadioCountUITests` (Pass 20); `WeatherKitEnabledUITests` (Pass 22); `RailFocusRestoreUITests`, four tests, one about five minutes (Pass 25); `DeleteRefreshUITests` (Pass 31); `StopRecordingUITests` (Pass 32); `TrashRestoreUITests`, which needs something in the trash and makes two Restore writes (Pass 33); `CommercialSkipUITests`, which uses `activate()` rather than `launch()` so the app's console stays attached, needs a recording with detected breaks, and whose `devicectl` console drops lines under high output volume (Pass 38); `GuideCollectionsUITests`, six tests, every query a predicate and never an enumeration (Passes 72, 73); `GuideRightEdgeUITests` (Pass 76); `OnLaterPillsUITests` (Pass 82); `GuideChannelLogosUITests` (Pass 86); `ContinueWatchingUITests` (Pass 91), which needs at least one unfinished saved position in that Apple TV's own `UserDefaults` and so cannot run on a simulator; `ResumeRewindUITests` (Pass 96, re-run unchanged as Pass 98's regression), which uses `launch()` and needs a saved position on `5328bb632e76`, walks forward at 1.2 s a press so the model's 1 Hz `tick()` can land inside a break, and ends by walking the saved position back to where it found it; `ContinueWatchingBarUITests` (Pass 92), the same requirement, which parks focus in the rail for its unfocused shot because pressing Down scrolls the shelf 570 pt off the top of the screen, and which uses `launch()` rather than `activate()` for the reason under KNOWN AND UNFIXED. Their run commands moved with the old "Next step" paragraphs (Pass 89).
- **`file:line` citations drift.** The comments and reports that carry them are never rewritten (DECISIONS.md, 2026-09-09 (Pass 56)); the last re-verified list is Pass 76's, `ScreenShell.swift`'s `.id(current)` being at `:57` where older comments cite `:51` or `:55`, and that list is superseded for `GuideScreen.swift` by Pass 79's insertions — `:635` where Pass 77 recorded `:528` — and again by Pass 86's change to that file (Passes 76, 79, 86).

### Known and unfixed — measured, still open, do not mistake for proven and do not re-derive

- Frame stepping goes erratic near the end of the prepared range — measured at 1:05:27 of a 1:11:10 recording, the clock moving backwards, every press the app's — **very likely closed by the file route, not proven**: nobody has watched the same spot since (Passes 29, 42).
- `armArrowOwnership` depends on `AVPlayerViewController`'s internals and fails open to Apple's skip if a future tvOS changes them (Pass 29).
- Live playback was never driven on the device in the frame-stepping passes; `frameStep` bails when the item is not a recording (Pass 29).
- Nobody has diffed two stills to prove the picture advances one frame of motion rather than the clock alone (Pass 29).
- Stopping a pass's airing on the device, and Cancel recording on a pass's airing, have never been exercised live; only the one-off Record Now case was (Passes 32, 33).
- Old-form (pre-1.6.0) trash entries are untested and now untestable; the id rule rests on two files, three cycles each; resume survival across a trash-and-restore was reasoned, never watched (Pass 33).
- "A playback that starts inside a break offers it" is still unproved, and one commercial skip landed 1.01 s past `endSeconds` instead of on it, unexplained (Pass 38).
- The end-of-recording clamp, the `hdhomerun` `"none"` branch and the network-failure branch of commercial skip were never exercised live (Pass 38).
- **Pass 95's T1 is built (Pass 98), its path has never run on a television, and the owner closed it there** — "im not spending any time on something that might never ever happen close this and move on to anything major or that is unfinished" (owner, 2026-09-16). It is **code-traced only**: `restart(at:)` writes `position = target`, nothing between that write and `armResumeSeek`'s read touches `position`, and the `.readyToPlay` seek puts playback there. **If the trace is wrong, a restarted recording begins at the top of the recording instead of at the restart point, silently.** It could not be driven because no restart caller is reachable from the remote: frame 6h **is** the Expired state and needs a keep-alive 410, which cannot happen because the app fetches every 10 s against the server's 15 s `hlsIdleTimeout` and there is no session lifetime cap; `FailureState`'s "Try again" needs a failure the remote cannot produce; `timeJumped()`'s seek-beyond is dead on the file route; `stopBlockingRecordingAndWatch()` is live only. Pass 98 measured the empirical half — a 5-minute session ended only on the app's own DELETE, and the console carried zero `restarted start=` lines. **The three ways to force one were offered and declined; none is to be built unasked** (Passes 96, 98, 99).
- **The 2 s start the owner asked for is met — by the server, not by this app — and is closed by marlin-dvr 1.9.1 on the owner's own test** (relayed 2026-09-16; Pass 101). 1.9.1 writes an `.mp4` sidecar beside the `.mpg` when a recording finishes and serves it directly on `format:"file"` with byte ranges and no remux: **first byte at 796 µs against 5.6–12.0 s before**, and **recordings start instantly on the Apple TV, owner-tested**. **The app's own press-to-picture was not re-measured in this pass** — "instant" is his reading on the television, not a number taken here — and `format:"file"` is unchanged for the app: same POST, same URL, same byte ranges. **A recording with no sidecar yet still takes the old remux path.** **Pass 96's open question 1 — the 2 s target and the three ways out of it — is closed with this item; none of the three was taken by this app and nothing was asked of the marlin-dvr project.** What was measured before is kept as history, not re-derived: 85–94 % of the press-to-picture time was the server's single-file remux, 10.225 s and 6.308 s in its own log against the app's 10.233 s and 6.429 s; the **first** remux of a recording was much slower than the next — 10.225 s against 2.151 s and 2.124 s for the same 1.09 GB whole-file remux — so a warm start was about 2.8 s, arithmetic on two measurements and never measured directly. Why the first was slower is still not this project's to answer and no request was made to find out (Passes 96, 101).
- A break the viewer scrubs through is **spent for that playback** — `noticeCommercialBreak` latches each range into `promptedRanges` and offers it at most once (Pass 38's design). With the whole recording now reachable this will happen more often: rewind past a break and it will not be offered again until the Player is re-entered. Raised in Pass 96, not changed.
- On the file route: a recording still being written, and one that is not H.264/AAC, were never exercised on the device; the remux wait has never been measured on the Unraid box; build-plan step 7 — resume by seeking, not by `start` — is not built, pending Pass 41 open question 7.2 (Pass 42).
- Pass 41's open questions 7.2 (start: 0 or start: N for resume), 7.3 (what the Starting screen should say during a long remux), 7.4 (fall back to HLS or show the error), 7.5 (temp space on Unraid) and 7.6 (whether to ask marlin-dvr to document the route) are still unanswered; 7.1 was answered, 7.7 closed by Pass 44, 7.8 overtaken (Passes 41, 42, 44).
- Multi-card focus traversal on the reflowing Recordings shelf is untested, and the 60 pt downward shift of the shelves is an open item the owner has seen and accepted, not a decision to leave it forever (Pass 47).
- Continue watching: the shelf is built when the screen opens and after a Keep or Delete, and **not** after a playback — the Player is a `fullScreenCover` over the screen and does not end its `.task`, so playing something and pressing Menu twice shows the shelf as it was read on the way in (the same staleness the server's "Recently Watched" shelf had; leaving Recordings and coming back rebuilds it). Whether a server-`watched` recording should drop off the shelf is the owner's call and it does not today; the empty-shelf case is traced and was never exercised, because exercising it would have meant clearing his saved positions; a position on a show past the shelves' `limit: 6` would go undrawn (Pass 91). **"Newest position first" is no longer on this list — Pass 92 measured it** from the store's own `savedAt` and the five cards' timestamps are strictly descending in the order drawn.
- The Continue watching progress bar: the zero-duration branch that draws no bar is code-traced and was never exercised; the translucent track has only been seen over posters that are dark along their bottom edge; nothing distinguishes 99 % watched from 100 %; and the bar has no accessibility value, so VoiceOver hears the card's text and nothing of the bar (Pass 92). **The focus ring covering 4 of the bar's 6 pt on a focused card has left this list**: it was shown to the owner and accepted as built, not deferred (DECISIONS.md, 2026-09-16 (Pass 93)).
- **A UI-test harness that uses `activate()` can photograph the previous build.** Pass 92's first two runs passed every assertion with the new feature absent from the screen: `activate()` resumed the process already running on the television while the new build sat installed and unlaunched. The proof is the server's log — the app pings on every launch (`ClientSession.swift:8-9`) and there was **no ping** in those runs. `activate()` exists for Pass 38's console attachment; `ContinueWatchingBarUITests` uses `launch()`. **`ContinueWatchingUITests` (Pass 91), `GuideChannelLogosUITests` (Pass 86) and `OnLaterPillsUITests` (Pass 82) still use `activate()` without a console and carry the same trap** — check for the launch ping before believing their screenshots (Pass 92).
- The "Recording" and "Scheduled" branches of the airing sheet's first control were code-traced only and accepted by eye (Pass 49).
- The Weather alert card has never been drawn with real data; its layout was checked with a disclosed, reverted diagnostic (Pass 22).
- The Guide's collections: the overlay does not scroll, "Collections unavailable" is unproven, the stale-id revert is unproven and needs a collection deleted, and whether the collection should also reach `GET /api/guide/now` and `GET /api/channels` is the owner's call (Passes 72–74).
- The Guide's scroll-right: a row can have no cell at all in the new window and focus falls back to `firstCellID` on another row; whether a physical held Right auto-repeats; the header has no focusable item above the middle of a row, so Up from there moves nowhere and `↩ Now` needs a Left first; `lastListedSlot` is per-fetch; the 150 ms settle's cost to a fast presser (Passes 77, 78).
- The Guide's clock: `TimeFormat.currentHalfHour` has no caller; the `↩ Now` pill vanishing under focus when the clock catches a one-slot-ahead window; the beat pausing entirely while one of the Guide's own overlays is up; the beat continuing behind the Player; the roll's refetch unexercised; the backgrounded-boundary harness test still unexecuted and labelled so in its header (Passes 79, 80).
- On Later: the two-read sheet reconstitution; the ≤30-minute far edge of "On This Week"; the now-dead `api.later()`, `LaterResponse`, `LaterSection` and `LaterItem`; which sentence an undrawable-but-non-empty union should get; the card carrying no new/live/premiere tags (Passes 82, 83).
- Standing candidates, should the owner want them: the untested-live paths above, the parked Settings screen, and the Open Questions of the Pass 9 and Pass 10 reports and the earlier recon reports (Passes 9, 10).

## What is NOT built

The future screen **Settings**: present as drawn and inert, parked until the owner says otherwise (DECISIONS.md 2026-09-06 sweep 4 + fixes). Weather left this list in Pass 13 and **Radio in Pass 19**.

**Built but blocked on the owner**: nothing. Both entries this block ever held are closed — the radar's request rate by Pass 16's tile store, and **every WeatherKit value by Pass 22**: the App ID carries the capability, the target is entitled, and both weather screens draw real data on the Apple TV. The one thing still unproven there is the **alert card**, which needs a real alert in the owner's area to be seen (Pass 22 Open Question 1).

**Four things stay as they are by the owner's decision of 2026-09-16, not by omission, and none of them is to be built** (DECISIONS.md, 2026-09-16 (Pass 106)): the Player's 6e **"Delete this recording"**, which stays drawn and inert — *"Don't build it and don't ask again."*, **and it is not to be raised again**; **any click behaviour on the Guide's channel cell** — the hold favourites it, a click does nothing, and that is finished, which answers Pass 9 Open Question 1 with *"It's fine. Leave it as it is."*; **any way to un-skip a cancelled pass airing** — cancelling a pass's airing while the pass carries on is how he wants it, *"thats the way it should work"*, which answers Pass 10 Open Question 4; and **any auto-refresh of the Manage DVR lists** — they reload each time Manage DVR is opened, *"so leave it as is"*, which answers Pass 10 Open Question 2. **Show detail's "Series pass" button left this list in Pass 103**, where it became the airing sheet's series-pass control (DECISIONS.md, 2026-09-16 (Pass 103)). Cancelling a booking, which Pass 8 lacked, lives in Manage DVR → Scheduled Recordings.

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
- **Commercial detection has failed on the owner's server on every recording made since
  2026-09-08.** Measured read-only in Pass 94 from the eleven `GET
  /api/library/recordings/{id}/commercials` answers and the `detect` record the library carries
  beside each recording: **nine of eleven answer `state: "unknown"`**, eight of them with the same
  stored reason — `the app's comskip.ini is missing (stat
  /Apps/dvr/marlin-dvr/data/versions/<v>/comskip.ini: no such file or directory)`, naming first
  `versions/1.8.0/` and later `versions/1.8.2/` — and the ninth interrupted at 00:06:08 on
  2026-09-08 by the in-place update itself. **The last successful detection on that server ended at
  22:42:21 on 2026-09-07.** Only `5328bb632e76` (4 breaks) and `d9a4f5c76696` (8 breaks), both
  recorded 2026-09-07, carry markers at all, which is why **the commercial-skip prompt has never
  appeared for the owner** — the app is correct and has nothing to show. The failure is **silent**
  (nothing in the admin UI or the log says detection has stopped) and **not self-healing** (contract
  §10.3: nothing re-runs detection), so every recording made from 2026-09-08 onward is permanently
  without markers even after a fix. The mechanism, read from the reference clone at `eb0c098`, is in
  **`reports/2026-09-16-pass94-commercial-skip-recon.md` §8**. **Nothing was changed on the server,
  nothing was asked of them, and no request was sent to them.**

## Open questions

See the Open Questions sections of `reports/2026-09-05-pass2-server-recon.md` (server recon) and `reports/2026-09-05-pass3-hls-client-recon.md` (HLS client recon). Environment questions from Pass 1 are listed in `reports/2026-09-05-pass1-plumbing.md`.

## Next step

**Nothing is unpushed as of Pass 107.** **Both Apple TVs still run `c0fce4a`**, untouched by this
pass, so the two televisions match.

Pass 107 is **read-only recon** of the owner's decisions of 2026-09-16 for **a swipe-down info panel
in the Player** — `reports/2026-09-16-pass107-player-info-panel-recon.md`. **Nothing was built**, no
build was made, neither Apple TV was touched, and **no write of any kind reached the server**: 14
GETs on read-only routes, and `GET /api/settings` was not read.

- **What a swipe down does today is AVKit's own info panel**, on a recording and on live alike — the
  app handles no swipe down and feeds Apple's panel only a title and a subtitle, **both carrying the
  channel number**. **Nobody on this project has ever observed that panel on a television.**
- **The fields.** A live channel's are all in hand **as of the moment of tuning** and never re-read;
  a Favorites channel with no listing has none. A recording's are in hand **except the channel logo:
  the server gives a recording no channel id and no logo.** The buttons need `GET /api/passes` and
  `GET /api/schedule`.
- **Nine owner calls stand before any build**, each with its file and quote in §5 of the report and
  no option invented — among them how the panel relates to AVKit's own, and **Pass 38's instruction
  not to be the first to put a focusable view over a running player**.
- **The running server answers 1.9.3**, where *The server* above still records 1.9.1 and Pass 103
  read 1.9.2; that line was not edited. **Every write route the panel would use rests on the 1.8.1
  clone and was not called.**
- **Pass 106's verified push SHA is `db38beb`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 107 response and belongs in the next pass's
entry. The paragraph below, written by Pass 106, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 106.** **Both Apple TVs run `c0fce4a`** — Home Theater since the
Pass 103 harness installed it, the bedroom since Pass 105 — so the standing bedroom rule above is
satisfied and the two televisions match.

Pass 106 is a notebook pass. It records Pass 105's install and the owner's decisions of 2026-09-16
closing **A2–A5**. **No app-target file, test-target file, project file or report was changed,
neither Apple TV was touched, and no request of any kind was sent to the server.**

- **Inventory group A is closed. A1 is built (Passes 103–105) and accepted; A2, A3, A4 and A5 are
  not to be built.** The four behaviours stay exactly as they are, now **by decision rather than by
  omission** — see *What is NOT built* above, where each carries his own words. **A2 is not to be
  raised again.**
- **Three long-standing open questions are answered by owner decision rather than by work:** Pass 9
  Open Question 1 (a click on a Guide channel cell — no), and Pass 10 Open Questions 2 and 4 (no
  Manage DVR auto-refresh, no un-skip).
- **Pass 105, install only, no commit.** "Master Bedroom ATV" built from `c0fce4a` by Pass 54's
  method into `~/Library/Developer/Xcode/DerivedData/MarlinDVRTV-bedroom` — **the path did not exist
  beforehand, so that build was clean** — and installed first try. The device reports **Version 1.0 ·
  Bundle Version 1**, which are constants here and identify no build, so the binary was tied to its
  code instead: **Pass 103's strings were found in the built `Marlin DVR TV.debug.dylib`**. **The app
  was not opened on that device**, so nothing shows A1 drawing on that screen.
- **Several of the owner's statements are his reports of his own server and his own use of the app,
  not measurements this project took** — that a deleted recording can be restored, that the hold
  favourites and unfavourites a channel, and that pressing record in the Guide records a cancelled
  pass airing. They are recorded as his; **nothing here verified any of them**, and
  `GET /api/settings` was still not read.
- **Pass 105's open items stand:** nothing has launched the app on the bedroom television, and
  **both Apple TVs run development-signed builds that will stop launching when the profile expires,
  which no pass has yet checked.**
- **Pass 104's verified push SHA is `c0fce4a`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 106 response and belongs in the next pass's
entry. The paragraph below, written by Pass 104, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 104.** **Home Theater runs the pushed build** — Pass 103's, which
the owner accepted; **the bedroom Apple TV does not — it is still on `4396d84`.** This batch is
proven, so the standing rule above falls due and **the bedroom is brought up next**.

Pass 104 is a notebook-and-push pass. It records the owner's acceptance of **A1** on Home Theater —
**"all checked and good"** (owner, 2026-09-16) — and pushes Pass 103. **No app-target file,
test-target file or project file was changed, neither Apple TV was touched, and no request of any
kind was sent to the server.**

- **What the acceptance covers, and what it does not.** It covers show detail's series pass button
  as built. It does **not** convert Pass 103's traced paths into measurements: the **"Record the
  series" press, the 409 branch, the failure branch and the button's change after an add or a
  delete** are covered **by his acceptance by eye**, the way Pass 49's two chip renderings are, and
  by nothing this project measured.
- **Pass 103's open questions stand**, none closed by the acceptance: the running server answering
  **1.9.2** where *The server* above still records 1.9.1; show detail not reloading after the Player
  closes; `Resume S0 E0`; a pass created here carrying no channel; and Down from the last Continue
  watching card going nowhere.
- **Pass 103's verified commit is `8ab78a9`.** This pass pushes it with its own commit, as a
  fast-forward from `22066d5`.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 104 response and belongs in the next pass's
entry. The paragraph below, written by Pass 103, described its own state correctly when written and
is kept as history.

**Pass 103 is committed and NOT pushed.** The owner tests the **"Record the series" press** on Home
Theater first — it is the one path in this pass that writes, and it is the half of A1 that is
code-traced only. **Home Theater already runs the Pass 103 build**: the evidence harness installed
and launched it at 21:06:56 on 2026-09-16. **The bedroom Apple TV does not — it is still on
`4396d84`**, and the standing rule above brings it up with the next proven batch, which this is not
until he has pressed that button.

Pass 103 builds **A1**, show detail's series pass button, on the owner's decision of 2026-09-16 that
closed Pass 102's open question 5 — `reports/2026-09-16-pass103-a1-series-pass.md`.

- **What it is now.** The button that had been inert since Pass 8 is the airing sheet's series-pass
  control reached from a show: **"Record the series"** with no pass, **"Edit series pass"** once
  there is one, opening the same `EditSeriesPassScreen` the Guide and Manage DVR open, with the
  sheet's 409 handling, its result text and its gold `◆ Series pass · …` line. **Only
  `ShowDetailScreen.swift` changed**; `AiringSheet.swift`, the editor and the project file were not
  edited.
- **What was proven and what was not.** Run-verified on Home Theater: both labels against the
  server's real state, the gold line, the editor opening and Menu leaving it with the pass intact.
  **Code-traced only: the "Record the series" press, the 409 branch, the failure branch, and the
  button's change after an add or a delete** — each needs a write on his DVR.
- **No write of any kind reached the server.** The app's one non-GET was its launch ping at
  `21:07:02.866`. Three POSTs in the same log window are the **owner's own web UI**, not this app —
  two are routes the app does not call anywhere, and `POST /api/record` landed after the test
  process had ended.
- **The running server answers 1.9.2, not the 1.9.1 the notebook records** (`GET /api/status`
  today; its log also reports `1.9.3 is published`). **The *The server* line above was not edited** —
  that is not one of this pass's three COLD-START edits — and it is open question 1 of the report.
- **Measured on a screen this pass did not touch: Down from the last Continue watching card goes
  nowhere.** The shelf holds 5 cards and those below hold 4, each with its own horizontal scroll
  offset, so tvOS finds nothing below the 5th. It cost the first device run; the harness now returns
  to the left-hand column before every Down. **Nothing was changed on the Recordings screen.**
- **Pass 102's verified push SHA is `22066d5`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 103 response and belongs in the next pass's
entry. The paragraph below, written by Pass 102, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 102.** **Home Theater runs the committed build; the bedroom Apple
TV does not — it is still on `4396d84`.** The standing rule above says it comes up with the next
proven batch.

Pass 102 is **read-only recon**. It sorts inventory items **A1–A5** for building, which the owner
ordered on 2026-09-16 — `reports/2026-09-16-pass102-a1-a5-recon.md`. **Nothing was built**, no build
was made, neither Apple TV was touched, and **no write of any kind reached the server**.

- **The sort. SWEEP — additive, independent, clear of do-not-touch: A1, A3, A4, A5. STANDALONE:
  A2 alone.** A2 is the one destructive item: the same
  `PUT /api/library/recordings/{id} {"trash": true}` **deletes the file outright** when the server's
  trash period is "Immediately", and it fires inside the Player's end-of-recording teardown on a
  root-level `fullScreenCover` with `.interactiveDismissDisabled(true)` and no library-change
  callback. **A3 is in the sweep but cannot start**: Pass 9 open question 1 — "Should a click tune
  the channel live?" — **is** the item, and it is unanswered.
- **A2's button is not absent — it is drawn and inert** (`PlayerScreen.swift:393`, empty action).
  COLD-START's "inert **or** absent" was right; the Pass 99 inventory row's "is absent" is the loose
  wording, and that report is not rewritten (Pass 56's rule).
- **Three versions, kept apart.** The running server is **1.9.1**, the reference clone **1.8.1**
  (`eb0c098`), the contract **1.7.0**. **Seven read routes were confirmed 200 against 1.9.1 itself**;
  **every write route A1–A5 needs is unconfirmed at 1.9.1** and none was called.
- **Five owner calls are waiting**, each with its file and quote in §3 of the report and **no option
  invented**: A3's Pass 9 open question 1; whether A2's delete is recoverable (it turns on a setting
  this project will not read); whether frame 6e gets a confirm step; what A4 should say for the two
  airings it cannot restore; and A5's interval, for which the notebook records nothing.
- **A4's proof needs his authorisation first:** all 8 of his scheduled jobs read `Queued` today, so
  there is **no skipped airing to un-skip** — producing one means cancelling a real recording of
  his, which is what Pass 10 declined to do.
- **Pass 101's verified push SHA is `90ff524`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 102 response and belongs in the next pass's
entry. The paragraph below, written by Pass 101, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 101.** **Home Theater runs the committed build; the bedroom Apple
TV does not — it is still on `4396d84`.**

Pass 101 is a notebook pass. It records what the owner relayed from the marlin-dvr project on
2026-09-16: **marlin-dvr 1.9.1 is running on 192.168.1.250 and the 7–11 s recording start is gone**.
**No app code changed, no build was made, neither Apple TV was touched, and nothing is owed by this
app.**

- **The version was read: `GET /api/status` answered `1.9.1`** on 2026-09-16, and that request is
  the only one this pass sent to the server. It supersedes the 1.8.2 reading of Pass 85.
- **Their fix, relayed:** when a recording finishes the server writes an **`.mp4` sidecar** beside
  the `.mpg`, and `format:"file"` serves that file directly with byte ranges and **no remux** —
  **first byte at 796 µs against 5.6–12.0 s before**. **Recordings start instantly on the Apple TV,
  owner-tested.**
- **Nothing changes for this app.** `format:"file"` is the same POST, the same URL and the same byte
  ranges; **a recording with no sidecar yet still takes the old remux path**; the library JSON now
  carries `remux{status,queuedAt,startedAt,endedAt,exitCode,file}` beside `detect{}`, which the app
  need not read and was not changed to read; **the HLS route is untouched**, so Pass 100's numbers
  for it stand as taken.
- **Pass 96's 2 s requirement is met by the server change, on the owner's test**, and the
  *Known and unfixed* item and **Pass 96's open question 1** are closed accordingly. **The app's own
  start time was not re-measured in this pass.**
- **Commercial skip is confirmed working end to end on the Apple TV** (owner, 2026-09-16) — he
  played a recording, the prompt appeared and the seek landed. **Pass 94's missing-`comskip.ini`
  finding is left exactly as it stands**: nothing here re-measured detection and nothing here claims
  it is fixed.
- **Pass 100's verified push SHA is `83127d1`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 101 response and belongs in the next pass's
entry. The paragraph below, written by Pass 100, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 100.** **Home Theater runs the committed build; the bedroom Apple
TV does not — it is still on `4396d84`.**

Pass 100 answered a request from the marlin-dvr side, relayed by the owner: test on the Apple TV
whether the **raw recording `.mpg`** can be played over HTTP with byte ranges and no remux, and
whether **HLS** can give rewind-to-zero
(`reports/2026-09-16-pass100-raw-mpg-and-hls-test.md`). **No shipped app code changed.**

- **The raw `.mpg` could not be tested: this server does not serve it.** Not in the contract, not in
  the 102 route registrations, and **404 from the running 1.8.2 server on all ten spellings for both
  subjects**, against four controls that answered 200. Steps 2–5 were skipped as the pass instructed
  and nothing was substituted. **To pass back: `rss.go:88` advertises `/api/play/recording/{id}.mp4`
  and no such route is registered.**
- **HLS gives rewind-to-zero exactly, and reaches picture 9–13× faster** — **0.647 s** and
  **0.814 s** press-to-picture against the file route's 10.916 s and 7.567 s, with every seek exact
  in 0.162–0.239 s and **0:00 landing at t=0.000**. **But every defect the file route closed comes
  back**: at `.readyToPlay` the seekable range is only 172 s and 216 s of the two recordings and
  takes 8–30 s to complete, so **Pass 96's resume seek is clamped short — asked 1485 s, landed
  172 s**; the **LIVE badge is drawn over a recording and stays even at +40 s**;
  `canPlayFastForward` and the step flags are **false throughout**; `item.duration` is NaN; and the
  frame rate reads unstable, the app adopting **25.0000 fps three times**.
- **The three routes are side by side in §4 of the report**, the six things HLS never did are quoted
  from the record in §2, and **the LIVE badge is photographed** in `reports/assets/pass100/`.
- **Disclosed cost:** the probe's seek script ends at 0:00, so both subjects' saved positions moved
  to near the start — `5328bb632e76` **1485.001 → 32.004 s**, `d9a4f5c76696` **4498.000 → 76.000 s**.
  **No entry was cleared — 12 before, 12 after.** The old values are in the report and recoverable
  by hand; nothing was written to the device to restore them.
- **The diagnostic was reverted with `git checkout --`** and the reverted build rebuilt, reinstalled
  and relaunched, with its launch ping in the server's log. **Nothing is raised with marlin-dvr and
  nothing is recommended** — the owner asked for measured numbers either way.
- **Pass 99's verified push SHA is `b866a0f`.** This pass's one commit is a fast-forward from it.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 100 response and belongs in the next pass's
entry. The paragraph below, written by Pass 99, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 99.** **Home Theater runs this build; the bedroom Apple TV does
not — it is still on `4396d84`.**

**Pass 95's T1 is closed** — "im not spending any time on something that might never ever happen
close this and move on to anything major or that is unfinished" (owner, 2026-09-16). Pass 98's
restart change stays in, **code-traced and never driven on a television**, and the three ways to
force a restart were offered and declined. Pass 98's other open questions are neither closed nor
re-raised.

- **Pass 98's `6a1a0dd` is pushed**, together with this pass's own commit carrying the inventory,
  this paragraph and the `DECISIONS.md` entry — **a fast-forward from `80458f9`**, which is still an
  ancestor. Nothing forced, rebased or amended.
- **Everything this project records as unfinished is now in one file**:
  `reports/2026-09-16-pass99-unfinished-inventory.md`, read-only, **62 items** — **12** a feature or
  screen not built or not working, **20** smaller known defects, **18** questions waiting on the
  owner, **4** deferred by his own word, **8** belonging to the marlin-dvr project. Every item cites
  the notebook or a report; **nothing was added, ranked or proposed**, and anything the notebook
  records as closed is deliberately absent.
- **No app-target or test-target file changed in this pass**, no build was made, no device was
  touched, and **no request of any kind was sent to the server**. The binary on Home Theater is
  Pass 98's, unchanged.
- **The bedroom Apple TV was not touched** and still resumes the old way, without Continue watching,
  the progress bar or resume-rewind, until the owner has it brought up.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 99 response and belongs in the next pass's
entry. The paragraph below, written by Pass 98, described its own state correctly when written and
is kept as history.

**Pass 98 is committed and NOT pushed. The owner tests it on Home Theater first, and Home Theater
is left running exactly this build.**

Pass 98 (`reports/2026-09-16-pass98-restart-whole-recording.md`) builds **Pass 95's T1** (owner,
2026-09-16): `restart(at:)` and `startAgain(at:)` resume the same way Pass 96 made Resume work. The
app-target diff is **one file, `PlayerModel.swift`, +24 / −4**; no harness was added or extended.

- **What changed is two lines and their reasons.** `startOffset = target` became **`startOffset = 0`**
  — that line was correct until Pass 96 and stopped being so — and `position = target` is unchanged
  but **now documented as load-bearing**, because it is how the target reaches `armResumeSeek` and
  the `.readyToPlay` seek. `startAgain(at:)` has no code change, only a comment that `target` no
  longer reaches the wire. **Nothing else in the teardown changed**, and live, cameras and radio are
  unchanged by construction.
- **No restart caller can be reached from the remote, so step 2's own STOP clause is what this pass
  followed.** Frame 6h **is** the Expired state, and it needs a keep-alive 410 that cannot happen —
  the app fetches every 10 s against the server's 15 s watchdog, and there is no session lifetime
  cap. `FailureState`'s "Try again", `timeJumped()`'s seek-beyond and
  `stopBlockingRecordingAndWatch()` are all out of reach too. **Measured, not only reasoned:** the
  harness's session lived 5 minutes under constant scrubbing and ended only on the app's own DELETE,
  and the console carries zero `restarted start=` lines. **The recording restart path is traced and
  has never run on a television.**
- **What the owner should look at first:** everything except the restart. If he can reach the
  Expired or Failure card in ordinary use — an unplugged Ethernet cable for twenty seconds would do
  it — pressing Restart there is the one test this pass could not perform.
- **The regression passes.** `ResumeRewindUITests` **unchanged**, **TEST SUCCEEDED in 389.479 s**:
  Resume still lands on the saved position, scrubbing back still reaches **`0:03 of 42:51`**, and
  the prompt armed at 1273 s inside break 4 with Select landing at 1482 s against its `endSeconds`
  of 1478.54. Four screenshots in `reports/assets/pass98/`, with the app's launch ping in the
  server's log for both runs.
- **Frame stepping is still 0.033367 s a click at 29.97 fps** — after a **resume**, not a restart,
  because a restart could not be reached.
- **Disclosed cost:** a temporary `FrameStepProbe` harness for the console reading, **deleted before
  the commit**; **no diagnostic was added to the app target**, so nothing had to be reverted. The
  saved position on `5328bb632e76` moved **932.000 → 1485.001 s**; **no entry was cleared — 12
  before, 12 after.**
- **Pass 97's verified push SHA is `80458f9`**, read before anything changed, with
  `git status --porcelain` showing only `?? icon-source/`. This pass's one commit is a fast-forward
  from it and **is not pushed**. **The bedroom Apple TV was not touched and still runs `4396d84`.**

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 98 response and belongs in the next pass's
entry. The paragraph below, written by Pass 97, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 97.** **Home Theater runs this build; the bedroom Apple TV does
not — it is still on `4396d84`.**

**Pass 96 was tested on Home Theater on 2026-09-16 and accepted — "bank it all good"**
(owner, 2026-09-16): a resumed recording's session sends **`start: 0`** whatever the saved position,
and the app **seeks to that position itself** once the item reaches `.readyToPlay`, so **there is
picture before the resume point and he can rewind into it**.

- **Pass 96's `12ef07f` is pushed**, together with this pass's own commit carrying
  `reports/2026-09-16-pass96-resume-whole-recording.md`'s acceptance, this paragraph and the
  `DECISIONS.md` entry — **a fast-forward from `3a88477`**, which is still an ancestor. Nothing
  forced, rebased or amended.
- **The acceptance covers the start time as measured, not a promise to improve it.** Press to
  picture was **10.916 s** and **7.567 s**, **85–94 % of it the server's remux**, against his own
  2 s requirement; a warm repeat of the same whole-file remux took 2.151 s and 2.124 s, so a warm
  start is about 2.8 s by arithmetic. **Nothing was built to shorten it.** The three ways out are in
  the Pass 96 report's open question 1, all outside this app, **none taken, and nothing asked of the
  marlin-dvr project.**
- **No app-target or test-target file changed in this pass.** The binary the owner accepted is Pass
  96's, and the binary pushed is the same one.
- **Pass 95's T1 is the next pass** (owner, 2026-09-16) — `restart(at:)` and `startAgain(at:)`,
  which Pass 96 read and did not edit. Their hand-off is traced and **was never driven on the
  device**; frame 6h's Restart, the Expired state's Restart and `timeJumped()`'s seek-beyond all
  need a television.
- **The bedroom Apple TV was not touched** and still resumes the old way until the owner has it
  brought up.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 97 response and belongs in the next pass's
entry. The paragraph below, written by Pass 96, described its own state correctly when written and
is kept as history.

**Pass 96 is committed and NOT pushed. The owner tests it on Home Theater first, and Home Theater
is left running exactly this build.**

Pass 96 (`reports/2026-09-16-pass96-resume-whole-recording.md`) builds Pass 95's **S1 and S2**
(owner, 2026-09-16): a resumed recording's session sends **`start: 0`** whatever the saved position,
and the app **seeks to that position itself** once the item reaches `.readyToPlay`. **T1 —
`restart(at:)` and `startAgain(at:)` — is its own later pass** (owner, 2026-09-16) and is not built.
The app-target diff is **two files, `PlayRequest.swift` and `PlayerModel.swift`, +109 / −1**;
`PlaybackSession.swift` and `ShowDetailScreen.swift` have no diff.

- **The owner can rewind now, and it is photographed.** `reports/assets/pass96/96d-rewound-to-the-start.jpg`
  shows the HUD reading **`0:03 of 42:51`** on *History's Greatest Mysteries* S4 E14 with the
  episode's opening title card on screen — footage that **did not exist in the file** the server
  built before this pass.
- **His 2-second requirement is NOT met, and the time is not the app's.** Press → picture at the
  saved position: **10.916 s** for `5328bb632e76` and **7.567 s** for `d9a4f5c76696` (the largest
  recording, 1 hr 42 min). **85–94 % of both is the server's remux**, with the server's own log
  agreeing with the app's clock to 8 ms and 121 ms. Everything the app does is 0.684 s and 1.138 s.
  **Nothing was built to shorten it.** It was not 2 s before this pass either: the old build remuxed
  a *trimmed* part of the same recording in 11.049 s, 43 minutes earlier. A **warm** repeat of the
  same whole-file remux took 2.151 s and 2.124 s, so a warm start is about **2.8 s** — arithmetic,
  not a reading. His options are all outside this app and none was taken.
- **The Home Theater run** was `ResumeRewindUITests`, **TEST SUCCEEDED in 228.959 s**, eight
  screenshots in `reports/assets/pass96/`, `launch()` not `activate()`, with the app's launch ping
  in the server's log for every run. It proved all three claims: Resume lands on the saved position
  and not 0; 40 Left presses reach 0:00; the prompt arms at 733 s inside the break 730.56–925.46 and
  Select lands at 929 s against its `endSeconds` of 925.46. **Frame stepping still moves 0.033367 s
  a click at 29.97 fps** after a resume.
- **The harness's first run failed twice and the app was right both times** — it had spent the break
  it then tried to prove, and a stray Select left the player paused so 65 "restore" presses went to
  the frame stepper. Both fixes are in the harness, none in the app; §4.2 of the report has it.
- **Disclosed cost:** a timing diagnostic and a temporary probe harness, **both removed before the
  commit**, with the reverted build rebuilt, reinstalled and re-run. The failed run moved the saved
  position on `5328bb632e76` from **931.002 s to 330.079 s**; the run that counts put it back to
  **932.000 s**. `d9a4f5c76696` moved to 2433.000 s. **No entry was cleared — 12 before, 12 after.**
- **Pass 95's verified push SHA is `3a88477`**, read before anything changed, with
  `git status --porcelain` showing only `?? icon-source/`. This pass's one commit is a fast-forward
  from it and **is not pushed**. **The bedroom Apple TV was not touched and still runs `4396d84`.**
- To run the harness again — the physical Apple TV, the real remote, and a saved position on
  `5328bb632e76`. It makes no server write beyond what playing a recording does:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p96 test -only-testing:"Marlin DVR TVUITests/ResumeRewindUITests"
```

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 96 response and belongs in the next pass's
entry. The paragraph below, written by Pass 95, described its own state correctly when written and
is kept as history.

**Pass 95 is a read-only recon and changed no code. It made no server request of any kind.**
It answers the owner's report of 2026-09-16 — *resuming a recording starts at the saved spot and
there is no way to rewind to before it* — and records his decision settling **Pass 41 open question
7.2**: **resume asks for the whole recording from the beginning and then seeks to the saved
position** (Pass 41 build-plan step 7). **Nothing was built**
(`reports/2026-09-16-pass95-resume-rewind-recon.md`).

- **The cause is one value on the wire, and there is no bug.** The app sends the saved position as
  the play session's `start` (`ShowDetailScreen.swift:148-150` → `PlayRequest.swift:63-67` →
  `PlaybackSession.swift:70`), and the server applies it as ffmpeg's `-ss` **before** it builds the
  single-file MP4 (`stream.go:328-331`, carried into `playfile.go:108-117`). The file that is
  remuxed *begins* at the resume point, so there is nothing before it to rewind to. The app never
  restricts seeking — `requiresLinearPlayback` is set for cameras only (`PlayerScreen.swift:36`).
- **All three resuming entry points are in `ShowDetailScreen.swift`** — Resume (`:177`), Play newest
  (`:188`) and a click on an episode row (`:236`) — and **Continue watching is not a fourth**: its
  cards open show detail (`RecordingsScreen.swift:271-275`). The Player's Play next always sends
  `start: 0` (`PlayerScreen.swift:101`).
- **`start: 0` costs almost nothing in correctness.** Ten readers of `startOffset` were listed and
  **nine are correct at 0 untouched**, because they all compute `position = startOffset + t`, which
  at 0 is the identity. The tenth is `restart(at:)`'s `startOffset = target`
  (`PlayerModel.swift:750`). DECISIONS.md, 2026-09-08 (Pass 42) had already corrected Pass 41 §4.3's
  claim that today's `start: N` breaks `fullyPrepared`, the HUD or the commercial clamp — **it does
  not**; both schemes are correct and the difference is reach and wait.
- **The work sorts into two SWEEP items and one STANDALONE.** SWEEP: send `start: 0`
  (`PlayRequest.swift:63-67`, `PlaybackSession.swift:70`); seek once the item is ready, in a new
  `.readyToPlay` arm of `itemStatusChanged` (`PlayerModel.swift:552-557`), on the observer that
  already exists at `:226-228`. STANDALONE: `restart(at:)` / `startAgain(at:)`
  (`PlayerModel.swift:740-786`), the session-teardown path Pass 39 called the Player's most fragile
  area. **`armArrowOwnership` and `armSelectOwnership` are not on the path and cannot be**, and the
  file route's first fetch needs no edit — its 11-minute timeout already covers the server's
  10-minute ceiling (`PlaybackSession.swift:37`).
- **The price is the remux**, which becomes the whole recording every time. Pass 41 open question
  **7.3** — what the screen says during the wait — becomes more visible and was **not** reopened.
- **Pass 94's finding is now in "Raised for the marlin-dvr project"** above: commercial detection
  has failed on every recording since 2026-09-08 with the missing `comskip.ini` reason. **Nothing
  was sent to them.**
- **Pass 94's verified push SHA is `4f91406`**, and every `file:line` in the Pass 95 report was read
  from that tree in this run. `git status --porcelain` showed only `?? icon-source/`. This pass's one
  commit is a fast-forward from it. **Both Apple TVs still run `4396d84`'s binary** — no app-target
  file has changed since.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 95 response and belongs in the next pass's
entry. The paragraph below, written by Pass 94, described its own state correctly when written and
is kept as history.

**Pass 94 is a read-only recon and changed no code.** It answers the owner's report that the
commercial-skip prompt has never appeared for him at a break, and the answer is not in this app:
**nine of his eleven recordings have no commercial markers at all, and the two that do are not the
ones he has been watching** (`reports/2026-09-16-pass94-commercial-skip-recon.md`).

- **Server-side commercial detection has failed on every recording made since 2026-09-08**, with the
  same stored reason on each: `the app's comskip.ini is missing (stat
  /Apps/dvr/marlin-dvr/data/versions/<v>/comskip.ini: no such file or directory)`. Nine recordings
  therefore answer `state: "unknown"`, which under Pass 38's rule shows nothing, ever. **Only
  `5328bb632e76`** (History's Greatest Mysteries S4 E14, 4 breaks) **and `d9a4f5c76696`** (Hitler's
  DNA, 8 breaks), both recorded 2026-09-07, can arm the prompt at all — and on Home Theater each is
  saved about six minutes short of its next break. The last successful detection on this server ended
  at 22:42:21 on 2026-09-07.
- **The app is not at fault.** Every file between the play request and the prompt is unchanged since
  Pass 42's `137f1de` — the build the owner watched work — and the `"unknown"` branch is doing
  exactly what Pass 38 decided it must. **No fix was built, proposed as a diff or stubbed**; the cause
  is the server's and is raised, not acted on, in §8 of the report and in the `DECISIONS.md` entry.
- **The measurement was 19 GETs and nothing else**: `/api/status` (1.8.2), `/api/library`, the four
  shows, the eleven `…/commercials`, and `/api/logs` twice. No server write, no `GET /api/settings`,
  no build, no install, **no device run** — so nothing here is a live proof that the prompt still
  draws today, and the two detected recordings are the only test subjects left.
- **Deferred (owner, 2026-09-16): a tvOS Top Shelf extension showing Continue watching — not now,
  later. Nothing built.**
- **Pass 93's verified push SHA is `4396d84`**, read three ways before anything changed, with
  `main...origin/main` at `0 0` and `git status --porcelain` showing only `?? icon-source/`. This
  pass's one commit — the report, the `DECISIONS.md` entry and this paragraph — is a fast-forward
  from it. **Both Apple TVs still run that build and neither was touched.**

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 94 response and belongs in the next pass's
entry. The paragraph below, written by Pass 93, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 93.** **Both Apple TVs run this build.**

**Passes 91 and 92 were tested on Home Theater on 2026-09-16 and accepted — "good to go"**
(owner, 2026-09-16): the Recordings screen drawing **"Continue watching"** from this Apple TV's
`ResumeStore` in place of the server's **"Recently Watched"** shelf, and the **6 pt
`Nocturne.accent` progress bar** on those cards. **The focus ring covering 4 of the bar's 6 pt on a
focused card was shown to him before he accepted and is accepted as built**, not an open item.
Pass 92's other open questions are neither closed nor re-raised.

- **Pass 91's `c633c9f` and Pass 92's `ab2570a` are pushed**, together with this pass's own commit
  carrying `reports/2026-09-16-pass93-accepted-pushed-bedroom.md`, this paragraph and the
  `DECISIONS.md` entry — **a fast-forward from `92a4770`**, which is still an ancestor. Nothing
  forced, rebased or amended.
- **No app-target file changed in this pass.** The binary the owner accepted is Pass 92's, and the
  binary pushed and installed is the same one.
- **The bedroom Apple TV ("Master Bedroom ATV", `AppleTV6,2`, tvOS 26.6) was brought from
  `168d8a7` to this build**, built from the pushed head by Pass 54's method and installed with
  `xcrun devicectl device install app`. **Install only** — not launched, no harness run there, no
  screenshot. The device's own `xcrun devicectl device info apps` reading is in the Pass 93
  response.
- **The bedroom build directory is now
  `~/Library/Developer/Xcode/DerivedData/MarlinDVRTV-bedroom`, and it is reused on every future
  bedroom install** (owner, 2026-09-16) — no more per-pass `build/pNN` trees for that device.
- **Home Theater already runs this build** from Pass 92's own device run; it was not touched in
  this pass.

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 93 response and belongs in the next pass's
entry. The paragraph below, written by Pass 92, described its own state correctly when written and
is kept as history.

**Passes 91 and 92 are committed and NOT pushed. The owner tests them on Home Theater first.**

Pass 92 (`reports/2026-09-16-pass92-progress-bar.md`) puts a **6 pt progress bar across the bottom
of each Continue watching poster**, filled `position ÷ duration` from the two numbers Pass 91
already put on the card, so it costs no request. Cards on the other shelves have none. The
app-target diff is **one file**, `RecordingsScreen.swift`, **+67 / −1** — `ResumeStore.swift`,
`ScreenChrome.swift` and `ShowDetailScreen.swift` are untouched, so show detail's own resume bars
are unchanged.

- **The tokens are existing ones and nothing was added to `Theme.swift`**: filled `Nocturne.accent`
  (`#9184D9`), unfilled `Nocturne.bg` (`#161826`) at `0.7`, height 6 pt (dc:93-95).
- **The Home Theater run** was `ContinueWatchingBarUITests`, **TEST SUCCEEDED in 24.570 s**, with
  its two screenshots in `reports/assets/pass92/`. **Every one of the five bars matches its stored
  fraction to within half a point** — one screen pixel — at fractions from 0.120 to 0.581, and the
  focused card's to 0.08 pt at its grown 296 pt width. The store was read off the Apple TV with
  `xcrun devicectl device copy from` (a read, into a session scratch directory, never committed)
  before the first run and after the last, byte-identical across both.
- **What the owner should look at first:** on a **focused** card the 4 pt accent focus ring covers
  the bar's bottom 4 pt of 6 and is the same colour, so only 2 pt of it is distinguishable. The
  fill boundary is still visible (photograph `92b`). Three fixes are in the report's open question
  1 and none was built.
- **A trap worth carrying forward:** the pass's first two runs passed every assertion with **no bar
  on screen**, because `XCUIApplication.activate()` resumed the Pass 91 process still running on
  the television while the new build sat installed and unlaunched. The server's log proved it — no
  launch ping in those runs, one in every run before and after. This harness uses `launch()`;
  three others still use `activate()` and carry the same trap (see KNOWN AND UNFIXED).
- **Pass 91's "newest position first" is now measured**, from the same store read; it has left the
  known-and-unfixed list.
- **Pass 89's verified push SHA is `92a4770`** and **`origin/main` is still `92a4770`**: local
  `main` is now **two** commits ahead — Pass 91's `c633c9f` and this pass's. Nothing forced,
  rebased or amended.
- **Home Theater runs this build**; the **bedroom Apple TV was not touched and still runs
  `168d8a7`**.
- To run the harness again — the physical Apple TV, the real remote, and at least one unfinished
  saved position on it. It makes no server write:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p92 test -only-testing:"Marlin DVR TVUITests/ContinueWatchingBarUITests"
```

This pass's own SHA is not written here and cannot be (DECISIONS.md, 2026-09-11 (Pass 68)); it is
in the Pass 92 response. The paragraph below, written by Pass 91, described its own state correctly
when written and is kept as history.

**Pass 91 is committed and NOT pushed. The owner tests it on Home Theater first.**

Pass 91 (`reports/2026-09-16-pass91-continue-watching.md`) replaces the Recordings screen's
server-drawn **"Recently Watched"** shelf with the app's own **"Continue watching"** — the
recordings *this* Apple TV has an unfinished saved position on, from `ResumeStore`, newest position
first, in the same place and the same card. The app-target diff is `RecordingsScreen.swift` and
`ResumeStore.swift`, and **nothing about what `ResumeStore` stores changed**.

- **Pass 89's verified push SHA is `92a4770`**, read three ways before anything was changed
  (`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`), with
  `git status --porcelain` showing only `?? icon-source/`. This pass's one commit is a
  fast-forward from it; **`origin/main` is still `92a4770`** and this pass's commit is the only
  thing local `main` is ahead by.
- **Home Theater now runs this build** — the device run installed it — and the **bedroom Apple TV
  was not touched and still runs `168d8a7`**, so the two televisions are on different builds until
  the owner says otherwise. When he does install it there, that Apple TV will show **its own**
  positions on the shelf, not Home Theater's; that is the point of the change, not a fault.
- **The Home Theater run that counts** was `ContinueWatchingUITests`, **TEST SUCCEEDED in 26.574 s**, with
  its two screenshots in `reports/assets/pass91/`. It drew **five cards** — *The Proof Is Out There*
  S6 E17 (40 min into 1 hr 10 min) and S6 E16 (14 min into 1 hr 11 min), *History's Greatest
  Mysteries* S4 E14 (15 min into 43 min) and S7 E20 (1 min into 8 min), and *Hitler's DNA* (12 min
  into 1 hr 42 min) — every one unfinished, while the other **seven** of the library's twelve
  recordings, which carry no saved position, drew no card. **No server write of any kind**: the only
  non-GET line in the server's own log across the run is the app's launch ping.
- **The first of the two runs failed one assertion and the screen was right** — it looked for show
  detail's Resume line among `staticTexts`, and a tvOS button's text is not one. Fixed to read
  `app.buttons` and re-run; both runs' screenshots are byte-identical. Disclosed in §4 of the report.
- **What the owner should decide first:** whether a recording the *server* calls `watched` should
  drop off the shelf. It does not today, and *History's Greatest Mysteries* S4 E14 is on the shelf in
  exactly that state — `watched: true` server-side, 15 minutes in on this Apple TV. It is one line.
  The report's §7 carries that and five more.
- To run the harness again — the physical Apple TV, the real remote, and at least one unfinished
  saved position on it. It makes no server write:

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p91 test -only-testing:"Marlin DVR TVUITests/ContinueWatchingUITests"
```

This pass's own SHA is not written here and cannot be — a commit cannot contain its own SHA
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 91 response and belongs in the next pass's
entry. The paragraph below, written by Pass 88, described its own state correctly when written and
is kept as history.

**Nothing is unpushed as of Pass 88.** **Both Apple TVs run `168d8a7`.** Home Theater has run it
since Pass 87's push; the bedroom Apple TV ("Master Bedroom ATV", `AppleTV6,2`, tvOS 26.6) was built
and installed from that same head in this pass, by Pass 54's method, and its own
`xcrun devicectl device info apps` reading, its Guide-logos screenshot and its evidence sit in
`reports/2026-09-13-pass88-bedroom-install.md` and `reports/assets/pass88/`. This pass's commit
carries that report, this paragraph and the `DECISIONS.md` entry, and is pushed as a fast-forward
from `168d8a7`. This pass's own SHA is not written here and cannot be — a commit cannot contain its
own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 88 response and belongs in the next
pass's entry. The paragraph below, written by Pass 87, described its own state correctly when
written and is kept as history.

The pass-by-pass narrative that was "What is built", and every superseded "Next step" paragraph — with the harness run commands that sat among them — are in `COLD-START-HISTORY.md`, moved there byte-for-byte by Pass 89.
