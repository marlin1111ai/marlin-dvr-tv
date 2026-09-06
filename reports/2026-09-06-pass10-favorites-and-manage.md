# Pass 10 — Favorites screen and the Manage DVR area (code; separate push gate) — 2026-09-06

The management views the owner's old DVR had, on the Apple TV, plus the Favorites screen the
rail has pointed at since Pass 5. Neither is in the approved design, so both are built to the
app's own look. **Committed locally only; nothing was pushed** — the push carries Passes 8, 9
and 10 together after the owner's test.

Citation keys: `file:line` = `cmd/marlin-dvr/` in the reference clone at HEAD
`9325d94439ef4c9db637c5014ff79f41d1f63956` (unchanged this pass; its working tree still holds
only the untracked `README-REFERENCE.md`). Server 1.2.1.

**A note on the task's numbers.** The task said the owner has 21 passes. At 14:38, before
anything was touched, `GET /api/passes` returned **1** (Hazardous History With Henry Winkler,
1 airing queued) and `GET /api/schedule` returned **1**. Every count in this report is the
server's own, read at the time; the before/after proof in §4 uses the real ones.

Server writes made this pass, all mine and all undone: two lineup `favorite` overrides (set,
unset), one series pass (created, deleted), two Record Now bookings (created, cancelled — one
of them from the app, which is the feature under test). **No recording was created, played to
its end, or flagged; Restore and Empty Trash were never sent** (§4c).

---

## 1. Step 1 — the Favorites screen

`FavoritesScreen.swift` (188, new). The rail's Favorites entry is live: `Destination.favorites`
joins `isBuiltNow` and `ScreenShell` routes it.

The list is the server's own favourites — the `favorite` flag on each `MergedChannel`
(sources.go:103-122), the same flag the Guide's click-and-hold sets in Pass 9 and the web UI
shows. Two reads the app already makes: `GET /api/channels` for the channels and the flag, and
`GET /api/guide/now` for what is on each of them, joined on channel id. The guide read is
best-effort — a favourite with no listing still appears, with "No listing right now" instead of
a programme. Each row is the On Now card's shape: logo, `number · name · ★ · HD`, the
programme, the server's "ends 3:04 PM" line and a progress bar. Clicking a row plays the
channel live, the same call the Guide makes when a cell that is airing now is clicked.

The Home tile's subtitle is real too, and costs nothing: `HomeModel` already reads
`/api/channels` for the Guide tile, so the favourites are counted from the same response
(`10-home-favorites-tile.jpg`, "4 favourite channels").

**Empty state**: when nothing is favourited the screen says "No favourite channels yet." and
"In the Guide, click and hold a channel in the left-hand column and choose Favorite."
**It was not exercised live** — the owner has four favourites and they are not mine to remove
to make the list empty. The branch is `model.channels.isEmpty` in `FavoritesScreen.body`;
declared, not asserted.

## 2. Step 2 — Manage DVR

Reached from a new row at the top of Recordings (`20-recordings-manage-row.jpg`), the only
change this pass makes to a screen of the approved design.

`ManageDVRScreen.swift` (244, new) is the hub and the shared model. One `ManageModel` reads
everything once and the three lists share it, so moving between them costs no extra requests.

### 2a Storage

`GET /api/system` (system.go:257-260). Every value is the server's own formatted string —
nothing is recomputed here: `228.63 GB used · 10.68 TB free of 10.91 TB`, a bar at
`diskUsedPercent`, and the server's own line `10.68 TB available on the recordings volume`
(`21-manage-hub.jpg`). The bar keeps a visible sliver below 1% so it never looks broken.

### 2b Scheduled Recordings

`ScheduleManageView.swift` (352, new). The rows are `GET /api/schedule` in the server's own
groups (Today / Tomorrow / a weekday / a date, passes.go:838-879), each with the job's art or
its channel tile, the programme, the server's status as a chip, a "Record Now" tag for a
one-off, the channel and the time range, and the server's `reason` when it has one
(`30-scheduled-list.jpg`).

Clicking a row opens the airing (`31-scheduled-detail.jpg`) with two actions:

- **Cancel recording** → `PUT /api/schedule/jobs/{id} {"skipped": true}` (passes.go:927-967).
  It arms on the first click and sends on the second, and the copy says what will actually
  happen, because the server treats the two kinds differently: a **one-off Record Now is
  removed** and its airing becomes free to record again (`removed: true`), while a **pass's
  airing is only skipped and the pass carries on**. The detail reads "Removes this one-off
  booking" or "Skips this airing, keeps the pass" accordingly.
- **Manage pass** → the Pass 9 editor for that job's pass. **Hidden for a Record Now job** —
  `passId` is the literal "manual" and there is nothing to open. Verified by assertion, not by
  eye: `XCTAssertFalse(app.staticTexts["Manage pass"].exists)` on the manual booking.

**No per-airing padding.** `Job` (passes.go:53-77) carries no padding field and the server has
no per-airing control; the detail says so in a line rather than showing a control that would
do nothing.

### 2c Your Passes

`PassesManageView.swift` (148, new): every pass from `GET /api/passes` with its art, title, a
PAUSED chip when it is paused, and a line of what it holds — `1 recording scheduled · new
episodes · keep all`, plus the channel it is pinned to or "any channel"
(`40-passes-list.jpg`). Clicking one opens the same Pass 9 editor, so a pass is edited in one
place wherever it is reached from.

**Pause/Resume was missing from Pass 9 and is added here**: a row reading Pause/Resume with
"Running" or "Paused — nothing is queued", writing `PUT /api/passes/{id} {"paused": …}`
(passes.go:688-690). `PassEdit` gains the field (`41-pass-editor-with-pause.jpg`).

### 2d Trash

`TrashManageView.swift` (190, new). **The library has no trash endpoint**: the only route to a
trashed recording is `GET /api/library/shows/{id}?trash=1`, per show. `ManageModel.refreshTrash`
therefore reads `/api/library?limit=500` once, takes the union of the section items as the
show list, and asks each show for its trashed episodes six at a time. Each row shows the show,
the episode line, the date and the size, with **Restore** on the right; the header carries
**Empty Trash** (`50-trash-list.jpg`).

- Restore → `PUT /api/library/recordings/{id} {"trash": false}` on one click; it is not
  destructive.
- Empty Trash → `POST /api/library/trash/empty` (trash.go:194-222) behind two clicks. The
  first arms it and says "This deletes the files on disk for good — for the web UI and the
  other Apple TV too."; only the second sends it. It is disabled and dimmed when the trash is
  empty.

## 3. Step 3 — the counts

The hub's three rows carry the server's counts: `1 scheduled`, `1 pass`, `1 in trash`
(`21-manage-hub.jpg`), and each list repeats them in its header (`2 scheduled · 2 passes`,
`2 passes · 1 airing queued`, `1 recording`). One bug was found and fixed here: the scheduled
row pluralised its word and read **"2 scheduleds"**; it now reads "N scheduled" (the fix is
covered by an assertion, §4).

---

## 4. Live-server tests

Driven two ways. The Favorites tests used synthetic key presses; part way through the pass the
Mac's keyboard focus was being taken by other applications, which makes that unreliable, so the
Manage DVR flow was driven by **XCUITest** instead (`ManageDVRUITests.swift`, 164, new). That
needs no Mac focus, asserts on the text the app actually draws, and attaches a screenshot at
each step — better evidence than a picture alone, and the reason every claim below can name the
string it checked.

**Before-state, 14:38:** 1 pass (Hazardous History, `pass-mtq2l4ca21e831`, 1 job) · schedule 1 ·
favourites 9001, 9009, 9019, 9021 · library 2 shows / 3 recordings · trash 1
(`eb236eabca27`, The Aging Brain) · `trashAfter "1 day"` · sessions 0.

### 4(a) Favourites

The owner's four rendered first (`11-favorites-owner-four.jpg`). Then one of my own —
`PUT /api/sources/philo/lineup/6043 {"favorite": true}` on 9000 AETV, a channel with no
override before or after (the app's own favourite write was proven in Pass 9; this pass is
about the screen that reads it):

```
GET /api/channels → 9000 AETV, 9001 HISTORY, 9009 DISCOVERY, 9019 AHC, 9021 DISCOVERY-LIFE
   the screen reloaded to "5 favourite channels", AETV first          12-favorites-with-test-channel.jpg
   clicking AETV started live playback                                 13-favorites-plays-live.jpg
   [session] keep-alive #1 → 206      (the Player's own session, stopped with Menu)
PUT …/6043 {"favorite": false} → {"hidden":false,"favorite":false}
GET /api/channels → 9001, 9009, 9019, 9021        · sessions active 0
```

The empty state was not exercised — see §1.

### 4(b) A pass and a booking, through the app

Fixtures (both mine, both chosen to schedule nothing that could record): a pass on "Fugitives
Caught on Tape", which has 11 airings in the guide and **none flagged new**, so with the
server's default `recordMode "new"` it queued **0 jobs**; and one Record Now on "Infomercials
@ 4PM" (9023 AS-INFOMERCIALS, 4:00–5:00 PM), booked at 14:53 with an hour before its padded
start.

The UI test then walked the whole area and asserted at every step:

```
Test Case 'ManageDVRUITests.testManageDVR' passed (54.887 seconds)
   ✓ hub: "Scheduled Recordings", "Your Passes", "Trash"
   ✓ hub: a label containing "used ·" and "free of"           (the storage summary)
   ✓ hub: a label containing "available on the recordings volume"
   ✓ scheduled list holds "Infomercials @ 4PM" (mine) and "Hazardous History With Henry Winkler" (his)
   ✓ detail says "One-off Record Now"
   ✓ "Manage pass" is NOT present on the manual booking
   ✓ first click arms: "Cancel recording — click again to confirm"
   ✓ second click: "Booking removed. That airing is free to record again."
   ✓ "Infomercials @ 4PM" is gone from the list
   ✓ passes list holds "Fugitives Caught on Tape" and "Hazardous History With Henry Winkler"
   ✓ the editor opens on the test pass: "SERIES PASS", "Pause", "Delete this pass"
   ✓ trash holds "The Aging Brain", with "Empty Trash" and "Restore" present
```

and the server agreed — the schedule went from 2 to 1, the survivor being the owner's:

```
before the cancel   count 2 · rec-mtq66objd08f01 Queued manual  … Infomercials @ 4PM 4:00pm–5:00pm
                            · 5ac218891674      Queued pass-…   … Hazardous History  9:00pm–10:03pm
after the cancel    count 1 · 5ac218891674      Queued pass-mtq2l4ca21e831 · Hazardous History
```

(The first run of the suite failed on its **last** assertion — `Empty Trash` is a single-Text
button and is exposed as a *button*, not a static text. The app was right; the query was wrong.
The assertion now accepts either, the booking was re-created, and the whole suite was re-run
green. Both runs cancelled a booking of mine, which is why two were created.)

Then `DELETE /api/passes/pass-mtq66oan4343fb` → `{"ok":true}`, and a second test asserted the
hub's counts on the cleaned-up server, which is also how the "scheduleds" fix was verified:

```
Test Case 'ManageDVRUITests.testManageHubCountsAfterCleanup' passed (16.290 seconds)
   ✓ a label ending " scheduled" and not containing "scheduleds"
   ✓ a pass count · ✓ a trash count            → "1 scheduled · 1 pass · 1 in trash"
```

### 4(c) Trash — read only, and why

The list was rendered and asserted from the owner's own trashed recording, and **nothing was
pressed**: `Restore` and `Empty Trash` were never sent to the server. The trash holds one real
item of his (`eb236eabca27`, The Aging Brain, 56.33 MB), Empty Trash deletes files on disk
permanently for every client, and this pass was told not to create a recording to test with.

So, stated plainly: **Restore and Empty Trash are wired but were not exercised live.** What
backs them is a code trace and one prior result:

- Restore calls `api.updateRecording(id:flag: .trash(false))` — the same function, with the
  same `{"trash": …}` body, that Pass 8 exercised live in the other direction (`trash=true`,
  with the server's log line and the episode leaving the list). Only the boolean differs.
- Empty Trash calls `api.emptyTrash()` → `POST /api/library/trash/empty`, decoding
  `{deleted, freed, failed, errors}` exactly as trash.go:214 writes it. The two-click arming
  is local state (`emptyArmed`) and was seen in the code path, not on screen.

### 4(d) Everything of the owner's, before and after

| | before 14:38 | after 14:59 |
|---|---|---|
| passes | 1 · Hazardous History · new · 5 mins before / 3 mins after · keep All · paused false · 1 job | **identical** |
| schedule | 1 · `5ac218891674` Queued · 9001 HISTORY · 9:00pm–10:03pm | **identical** |
| favourites | 9001, 9009, 9019, 9021 | **identical** (philo lineup: hidden none, favourite those four) |
| library | 2 shows · 3 recordings | **identical** |
| trash | 1 · `eb236eabca27` | **identical** |
| recordings' flags | `4b4a3f0f8fc8` watched · `d3105e15f069` unwatched, no keep/favourite/trash | **identical** |
| settings | trashAfter "1 day" · padBefore "5 mins before" · padAfter "3 mins after" | **identical** |
| play sessions | 0 active | 0 active |

One thing to declare rather than bury: while navigating with key presses, a mis-aimed Select
started playback of the owner's Earth Odyssey recording. It was stopped with Menu within
seconds (`[session] DELETE … {"ok":true,"wasRunning":true}`), it did not reach the end, and no
flag was written — `4b4a3f0f8fc8` still reads `watched=true` from Pass 8, with favourite, keep
and trash all false. The app's own resume store (per Apple TV, in UserDefaults on the
Simulator) now holds a position for it; nothing on the server changed.

## 5. Step 5 — installed on Home Theater

The final build was installed and launched at 15:00:15 (`devicectl … install app` →
`installationURL: …/Marlin DVR TV.app/`, `process launch` → "Launched application"), and the
server logged its check-in: `Apple TV | 192.168.1.30 | Marlin DVR TV 1.0 | online True | now`.
It is left installed and running.

---

## Open Questions

1. **The trash costs one request per show.** With two shows that is two; with the design's 38
   it would be 38 on every visit to Manage DVR. A `GET /api/library/trash` on the server would
   make it one — a marlin-dvr decision, raised here, not made.
2. **Nothing auto-refreshes.** The lists read when they open and after a write, per the scope
   lock. A recording that starts while the schedule list is open still reads "Queued" until
   the screen is re-entered.
3. **Cancel on a pass's airing was not exercised live** — only the Record Now case was, since
   the only pass airing on the server is the owner's and skipping it would have changed his
   schedule. The code path is the same call; only the server's `removed` differs, and the copy
   already distinguishes them.
4. **A skipped pass airing cannot be un-skipped from the app.** The server takes
   `{"skipped": false}` (passes.go:955) and the app never sends it, so a cancelled pass airing
   can only be restored from the web UI.
5. **Storage is the volume's, not the library's.** `diskUsed` is everything on the recordings
   volume, which is what the server reports; there is still no per-library total (Pass 4 Open
   Question 9).
6. **The pass editor writes on every click.** Cycling Keep four times sends four PUTs. It suits
   a remote, but a pass with many airings recomputes the schedule each time.
7. **Empty Trash gives no per-recording choice** — it is all or nothing, as the server's
   endpoint is. Deleting one trashed item permanently is not possible from the app.
8. **The Favorites screen does not offer un-favouriting.** That is the Guide's click-and-hold
   (Pass 9 step 7). Should a hold on a Favorites row do it too?
9. **The Manage DVR row sits above the shelves on Recordings** and takes the first focus when
   there are no cards. If the owner would rather have it elsewhere — the rail, say — that is a
   different entry point, not a different screen.
10. **`ManageDVRUITests` is new in the UI-test target.** It is this pass's evidence harness and
    ships no code into the app; it makes one write (the Cancel on a booking created for it) and
    never touches the trash.

---

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/FavoritesScreen.swift` (new, 188) | 1 |
| `Marlin DVR TV/Destination.swift` — Favorites joins `isBuiltNow`, its static subtitle removed | 1 |
| `Marlin DVR TV/ScreenShell.swift` — routes `.favorites` | 1 |
| `Marlin DVR TV/HomeView.swift` — the Favorites tile's count, from the read already made | 1 |
| `Marlin DVR TV/ManageDVRScreen.swift` (new, 244) — the hub, `ManageModel`, the storage card | 2a, 2d, 3 |
| `Marlin DVR TV/ScheduleManageView.swift` (new, 352) — list, detail, Cancel, Manage pass | 2b |
| `Marlin DVR TV/PassesManageView.swift` (new, 148) | 2c |
| `Marlin DVR TV/TrashManageView.swift` (new, 190) — list, Restore, Empty Trash | 2d |
| `Marlin DVR TV/EditSeriesPassScreen.swift` — the Pause/Resume row | 2c |
| `Marlin DVR TV/RecordingsScreen.swift` — the "Manage DVR" row and its navigation | 2 (entry point) |
| `Marlin DVR TV/Models.swift` — `SystemInfo` | 2a |
| `Marlin DVR TV/ChannelFilter.swift` — `system()`, `show(id:trash:)` | 2a, 2d |
| `Marlin DVR TV/ServerWrites.swift` — `cancelJob`, `emptyTrash`, `JobCancelResult`, `EmptyTrashResult`, `PassEdit.paused` | 2b, 2c, 2d |
| `Marlin DVR TVUITests/ManageDVRUITests.swift` (new, 164) | 4 (the evidence harness) |
| `reports/assets/pass10/*.jpg` (13 files, 1.7 MB) | 4 |
| `COLD-START.md` — "What is built", "What is NOT built", "Next step" | deliverable |
| `reports/2026-09-06-pass10-favorites-and-manage.md` (this file) | deliverable |
| Local commit "Pass 10: Favorites screen and the Manage DVR area"; **no push** | deliverable |

Nothing else was written. Untouched: `DECISIONS.md`, `Info.plist`, the project file and build
settings, `Assets.xcassets`, `design/`, the rail (`RailView.swift`), and every other Swift file
(`ServerAPI.swift`, `RemoteHold.swift`, `AiringSheet.swift`, `GuideScreen.swift`,
`ShowDetailScreen.swift`, `EpisodeActionsMenu.swift`, `ChannelActionsMenu.swift`,
`OnNowScreen.swift`, `OnLaterScreen.swift`, `CamerasScreen.swift`, `ScreenChrome.swift`,
`ServerImage.swift`, `Theme.swift`, `ResumeStore.swift`, `PlayRequest.swift`,
`PlaybackSession.swift`, `PlayerHost.swift`, `PlayerModel.swift`, `PlayerScreen.swift`,
`ClientSession.swift`, `ContentView.swift`, `Marlin_DVR_TVApp.swift`).

Outside the repo: DerivedData; the app on the Simulator and on Home Theater; and on the server,
the writes listed at the top, all undone and proven in §4(d). The reference clone and `design/`
were only read. No request went beyond port 8090; none to marlinpc, the HDHomeRun directly, or
the UNAS4Pro share. Nothing installed on the Mac; no packages; no third-party code.
