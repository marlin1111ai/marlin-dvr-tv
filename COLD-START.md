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

Current state only — one line per screen and one per standing fact, each citing the pass it comes from. The pass-by-pass narrative this section used to be is history now (the pointer is the last line of this file); nothing below is new, and where an earlier entry was superseded by a later one, the later one is what is written (the resolutions are listed in `reports/2026-09-13-pass89-cold-start-trimmed.md`).

### The server

- **The server is marlin-dvr 1.8.2**, measured from `GET /api/status` on 2026-09-13 (Pass 85). It superseded the 1.8.1 read in Passes 71 and 72, which superseded the owner's own 1.8.0 and 1.7.0 readings of 2026-09-08 (Pass 72, Pass 85).
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
- **Recordings and show detail** (Pass 6): the shelves and show detail; click-and-hold on an episode offers Keep and Delete (`PUT /api/library/recordings/{id}`), a trashed episode leaving the list, and the episode list is reachable with the remote (Passes 8, 9); after a Keep or Delete the shelves re-read `GET /api/library` while show detail is still on top, with focus repaired only when the focused card is gone (Pass 31); the focused poster card grows its real layout box 252×344 → 296×404 with the 22 pt lift and nothing clips, the row reflows sideways and the shelves below shift down 60 pt while a card is focused — both accepted — and the title and episode count no longer enlarge on focus (Pass 47); **the first shelf is the app's own "Continue watching"** — the recordings *this* Apple TV has an unfinished saved position on, from `ResumeStore`, newest position first, one card per recording with "S6 E17 · 40 min in" where a show card counts episodes and no "n new" badge, resolved through `GET /api/library/shows/{id}` because the server has no per-recording read, not drawn at all when it is empty — **and the server's "Recently Watched" shelf is not drawn**, while "Recently Updated" and "Recently Added" stay the server's; it is per Apple TV, so the two Apple TVs differ (Pass 91).
- **Cameras** (Pass 6): reloads every 45 s without moving focus (Pass 25); a camera plays through the Player, the one Player path that holds no tuner (Passes 7, 25).
- **Player** (Pass 7): HLS sessions per `HLS-CLIENT-API.md`, `AVPlayerViewController` with the overlays of frames 6a–6h, the per-Apple-TV resume store and watched-on-end, live channels with the server's time-shift buffer, cameras, and the entry points from On Now, the Guide, the airing sheet, show detail and Cameras; "Stop the recording and watch" on a tuner-busy 502 — `POST /api/schedule/jobs/{id}/stop`, then the live session (Pass 8); frame-by-frame on a paused recording by left and right clicks only — an exact seek to `currentTime() ± 1/fps` with both tolerances `.zero`, never `step(byCount:)`, +0.033367 s a click at 29.97 fps — with `armArrowOwnership` disabling `AVPlayerViewController`'s own arrow recognizers while the app owns the arrow and restoring them otherwise, and a frame rate believed only within 5 % of a real one (Passes 28, 29); commercial skip — a five-second prompt bottom-right at the start of a detected break, Select landing exactly on `endSeconds` by the in-item exact seek, only `state: "detected"` from `GET /api/library/recordings/{id}/commercials` arming it, one fetch per playback, `armSelectOwnership` claiming Select only while the prompt is up (Pass 38); **recordings play as one complete, seekable MP4 through the single-file route** — chosen at `PlayRequest.swift:49`, reaching the wire at `PlaybackSession.swift:70`, the response's `format` field checked, a `Range: bytes=0-0` first fetch on its own `URLSession` with an 11-minute timeout — while live TV, cameras and radio stay on HLS; a recording still being written or not H.264/AAC is refused with the server's 502 text and never routed back to HLS; the Starting screen says "Preparing the recording" during the remux wait, indistinguishable from a stall (Pass 42); **the LIVE badge over a recording and the wait before fast-forward are closed** by that route on the owner's own test; **the audio/video desync on recordings is not this app's** and no client-side compensation has been built or is to be (Passes 39, 42).
- **Favorites** (Pass 10): the server's favourite channels with what is on now; clicking one plays it live; it lists and plays every favourite channel whether or not the guide has a listing (Pass 26).
- **Manage DVR** (Pass 10, in the rail's bottom slot per Pass 10B): the storage line from `GET /api/system`; Scheduled Recordings grouped, with Cancel recording and Manage pass; Your Passes — the pass editor, with Pause/Resume; Trash — Restore per row, Empty Trash behind two clicks — with every count the server's; Trash reads `GET /api/library/trash` into its own eight-field `TrashItem`, Restore is proven live, a recording's id changes while it is in the trash and Restore changes it back so `ResumeStore` survives a restore, and the empty-state sentence is focusable so Menu still reaches `.onExitCommand` (Pass 33); the Trash list comes from that endpoint and nothing else — the per-show walk and a client-side id cache are both rejected on the record (Pass 34).
- **Edit series pass** (Pass 9): record mode, padding, keep rule, delete with a confirm; the keep rule no longer causes deletions by itself (owner, 2026-09-07; Pass 34).
- **Weather** (Pass 13): frame 5f, fed only by WeatherKit, with the one-shot location prompt cached after the first grant and a spoken state for every way it can fail; **populated with real data on Home Theater since WeatherKit was enabled on the explicit App ID** — the current-conditions line, 8 hourly columns, 5 daily rows with range bars, the Apple Weather attribution — with the three defects that only content could reveal fixed; **the alert card has still never been drawn with real data** (Pass 22).
- **Radar** (Pass 13): `MKMapView` in `UIViewRepresentable` with `MKTileOverlay` + `MKTileOverlayRenderer`, reachable from the Weather screen; the source is **NOAA** — the NWS MRMS base-reflectivity `ImageServer`, free, no key, public domain — with each tile's z/x/y converted to a bounding box for `exportImage` and frame times from NOAA's own mosaic catalog (Pass 14); it **animates** by attaching and detaching exactly one frame's overlay at a time over everything NOAA offers, and refreshes every five minutes while on screen, the timer cancelled on disappear (Pass 15); `RadarTileStore` keeps fetched tiles in memory only, bounded at 96 MB, emptied by `RadarModel.stop()`, cutting 2,327 requests a minute to 53 and about 5 at rest, at a 900 ms frame pace with a 2,200 ms hold (Pass 16).
- **Radio** (Pass 19): a two-column grid of station tiles — the icon the DVR has cached plus the name, in the server's order, never sorted — and a now-playing bar with that station's icon, name and a Stop; audio is a bare `AVPlayer` on the URL the server gives, with no play session, no HLS, no keep-alive, no `AVPlayerViewController` and no MIME option; leaving the screen or the foreground stops the stream; **both of the owner's stations play**, including the `.aac` mount, and AVPlayer follows the StreamTheWorld 302 (Pass 19); the Home tile's station count is Pass 20's.
- **Search** (Passes 62–65): type a programme title on the Siri Remote and `GET /api/guide/find?q=` answers as you type — case-insensitive substring on the title, at most 20 rows with the true total in `count`, "Showing the first 20 of *n* matches · type more of the title to narrow it" — and clicking a row reconstitutes the airing from `GET /api/guide/search?title=`, never from `GET /api/guide`, opening the airing sheet with every control live; DRM results are filtered out silently; the query and results survive a trip to the rail; the input is tvOS's `.searchable`, not a hand-built `TextField`; the sheet-close focus rebuild (a `generation` counter) is load-bearing and was measured twice — do not remove it a third time without the device saying so; the screen's own header sits below tvOS's search field, and the keyboard strip scrolls off the top and takes a walk to come back to — both accepted as built.

### Standing state of the devices and the evidence

- **The owner's four pre-1.6.0 trashed recordings are gone — do not go looking for them.** His own web-UI `POST /api/library/trash/empty` at 20:51:50 on 2026-09-07 permanently deleted all four; `6007a13f0b46` no longer exists; the old-form trash entry can no longer be produced (Pass 33).
- Pass 32's two leftovers, `midday-maryland` `b7a3822d83b4` and `the-view` `eccf81dbdab2`, are back in the library and clean, and they were the only ids ever authorised for trash-and-restore evidence (Pass 33).
- Two Pass 42 device runs left a resume position deep inside *History's Greatest Mysteries* S4 E14 "Who Is D.B. Cooper?" on Home Theater; it is per-Apple-TV, only playing the recording to its end clears it, and `CommercialSkipUITests/testPromptAppearsAndSelectSkips` keeps failing until it is cleared (Pass 42).
- **Evidence harnesses, not standing tests**, one per pass in `Marlin DVR TVUITests`, most needing the physical Apple TV and the real remote: `RemoteHoldUITests` (Pass 9); `ManageDVRUITests` and `RailManageUITests`, which drive the Simulator, the first needing a scheduled recording and a series pass (Pass 10); `RadioUITests` (Pass 19); `HomeRadioCountUITests` (Pass 20); `WeatherKitEnabledUITests` (Pass 22); `RailFocusRestoreUITests`, four tests, one about five minutes (Pass 25); `DeleteRefreshUITests` (Pass 31); `StopRecordingUITests` (Pass 32); `TrashRestoreUITests`, which needs something in the trash and makes two Restore writes (Pass 33); `CommercialSkipUITests`, which uses `activate()` rather than `launch()` so the app's console stays attached, needs a recording with detected breaks, and whose `devicectl` console drops lines under high output volume (Pass 38); `GuideCollectionsUITests`, six tests, every query a predicate and never an enumeration (Passes 72, 73); `GuideRightEdgeUITests` (Pass 76); `OnLaterPillsUITests` (Pass 82); `GuideChannelLogosUITests` (Pass 86); `ContinueWatchingUITests` (Pass 91), which needs at least one unfinished saved position in that Apple TV's own `UserDefaults` and so cannot run on a simulator. Their run commands moved with the old "Next step" paragraphs (Pass 89).
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
- On the file route: a recording still being written, and one that is not H.264/AAC, were never exercised on the device; the remux wait has never been measured on the Unraid box; build-plan step 7 — resume by seeking, not by `start` — is not built, pending Pass 41 open question 7.2 (Pass 42).
- Pass 41's open questions 7.2 (start: 0 or start: N for resume), 7.3 (what the Starting screen should say during a long remux), 7.4 (fall back to HLS or show the error), 7.5 (temp space on Unraid) and 7.6 (whether to ask marlin-dvr to document the route) are still unanswered; 7.1 was answered, 7.7 closed by Pass 44, 7.8 overtaken (Passes 41, 42, 44).
- Multi-card focus traversal on the reflowing Recordings shelf is untested, and the 60 pt downward shift of the shelves is an open item the owner has seen and accepted, not a decision to leave it forever (Pass 47).
- Continue watching: the shelf is built when the screen opens and after a Keep or Delete, and **not** after a playback — the Player is a `fullScreenCover` over the screen and does not end its `.task`, so playing something and pressing Menu twice shows the shelf as it was read on the way in (the same staleness the server's "Recently Watched" shelf had; leaving Recordings and coming back rebuilds it). Whether a server-`watched` recording should drop off the shelf is the owner's call and it does not today; the empty-shelf case is traced and was never exercised, because exercising it would have meant clearing his saved positions; "newest position first" is traced and not measured, because nothing draws `savedAt`; a position on a show past the shelves' `limit: 6` would go undrawn (Pass 91).
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
