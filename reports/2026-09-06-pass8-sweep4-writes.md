# Pass 8 — Sweep 4: the writes (code; separate push gate) — 2026-09-06

The five server writes of the Pass 4 plan §4, built on the Pass 5–7 app and tested hands-on
against the live server on the running build: Record this airing, Record the series, the
show-detail long-press menu (Keep / Favorite / Mark unwatched / Delete), Hide this channel,
and "Stop the recording and watch" on a tuner-busy live start. **Committed locally only;
nothing was pushed** — the owner tests on Home Theater first.

Two defects that block the sweep were found and fixed on the way (§6): the tvOS long press
never fired, and the episode list could not be reached with the remote. Both were shipped in
sweeps 2–3 and neither had been exercised before.

**Gate check (step 6a), first.** `GET /api/settings` → `trashAfter: "1 day"` (not
"Immediately"), so the trash tests were allowed to run and the file the trash flag marks
stays on disk until the owner's own one-day expiry removes it. The setting was read, never
written; `POST /api/library/trash/empty` was never called.

Citation keys: `dc:NNN` = `design/Marlin DVR TV.dc.html`; `file:line` = `cmd/marlin-dvr/` in
the reference clone at HEAD `9325d94439ef4c9db637c5014ff79f41d1f63956` (unchanged this pass,
working tree still only the untracked `README-REFERENCE.md`). Server version `1.2.1`.

Network use, all against `http://192.168.1.250:8090`: GETs; the app's client ping; the five
writes under test; three live HLS sessions I opened and closed myself to occupy tuners; and
the test-fixture calls named in §4. Nothing installed, no packages, no Info.plist or
build-setting change, no server settings changed.

---

## 1. What was built, file by file

All under `Marlin DVR TV/` (file-system-synchronized group, so new files need no project
edit). Line counts by `wc -l`.

| File | Step | What it is |
|---|---|---|
| `ServerWrites.swift` (182, new) | 1–5 | The five typed calls and the shapes they answer with. `recordNow(channelId:start:)` → `RecordOutcome {id, status, reason?}` (the server answers either the computed `Job` or the minimal `{id, status:"Queued"}`, recorder.go:845-847, so only the three common fields are decoded); `createPass(title:seriesId:)` → `PassView`; `updateRecording(id:flag:)` → `RecordingUpdate` (an `Episode`, **or** `.deleted` when the trash period is "Immediately" and the server answers `{ok, deleted}` instead, library.go:683-691); `setChannelHidden(sourceId:guid:hidden:)` → `LineupOverride`; `stopJob(id:)` → `StopOutcome`. `RecordingFlag` carries one flag per call. `WriteError.text` renders a failure as the server's own words with its status ("409 · that airing is already set to record"). One `[write] …` console line per call, for the evidence below. |
| `ServerAPI.swift` (Pass 5 file, +11) | 1–5 | `put(_:body:)` beside `post`, both through one private `write(_:_:body:)`. Nothing else changed. |
| `AiringSheet.swift` (Pass 6 file, 172 → 287) | 1, 2 | "Record this airing" → `POST /api/record {channelId, start: program.start}`; "Record the series" → `POST /api/passes {title, seriesId?}` (the server fills recordMode "new", keepMode "all" and the padding defaults, passes.go:715-722). After either the guide refetches `/api/schedule` and hands the sheet this airing's job back, so the sheet redraws from what the server now reports: the button is replaced by a `● Scheduled · <status>` or `◆ Series pass · <title>` chip, and a footer line shows the server's `status`/`reason` or the plain-text error. Focus moves to the next live button when a button is replaced. No conflict is predicted before booking (Pass 4 Open Question 6 stands). |
| `GuideScreen.swift` (Pass 6 file, +58) | 1, 2 | `GuideModel.refreshSchedule()` for after a write. `GuideMark` gains `.scheduled`: ● RECORDING while the recorder runs, **● SCHEDULED** for a Record Now booking that has not started (green, as the design's REC mark, dc:1183-1189), ◆ SERIES PASS for an airing a pass covers; the legend reads "Recording or set to record". The sheet is given the API client and the refresh callback. The cell is now a `HoldButton` (§6.1). |
| `EpisodeActionsMenu.swift` (148, new) | 3 | The long-press menu of frame 5d (dc:643) in the Nocturne theme: Keep, Favorite, Mark unwatched, Delete, each one `PUT /api/library/recordings/{id}` with the matching flag. Keep and Favorite are toggles and show On/Off; "Mark unwatched" sends `{watched:false}` and is disabled with "Already unwatched" when the episode is not watched; "Delete" sends `{trash:true}`. The card carries the standing note that Delete only sets the trash flag and that keep/favorite/watched are shared with the other Apple TV (library.go:68-79; dc:514). Menu (the exit command) closes it. |
| `ShowDetailScreen.swift` (Pass 6 file, +104) | 3 | The model keeps a mutable `episodes` list and `apply(_:to:)` updates or removes one from the `episodeView` the server returns; the counts and the size line follow. Click and hold an episode opens the menu. Both columns became focus sections (§6.2). "Series pass" here stays inert (§8, Open Question 1). |
| `PlayerModel.swift` (Pass 7 file, +65) | 4, 5 | `Failure.busyRecordings` becomes `[BusyRecording]` (the job id plus the line frame 6g prints), so the copy and the stop call name the same recording. `hideChannel()` → `PUT /api/sources/{id}/lineup/{guid} {hidden:true}`, with a notice saying the channel leaves every list on its next load. `stopBlockingRecordingAndWatch()` → `POST /api/schedule/jobs/{id}/stop`, then `restart()`; the stop call returns only once the recorder has closed the file (recorder.go:672-676), so the tuner is free before the new session is created. `fail()` now forgets the stopped session so the restart does not DELETE it twice. |
| `PlayerScreen.swift` (Pass 7 file, +24) | 4, 5 | The 6f "Hide this channel" and 6g "Stop the recording and watch" buttons call those two; both disappear once their write has succeeded, and the card shows the result line. "Delete this recording" on 6e stays inert (§8, Open Question 1). |
| `HoldButton.swift` (81, new) | 1, 3 | Click versus click-and-hold on tvOS — see §6.1. |

---

## 2. Steps 1 and 2 — Record this airing, Record the series

Driven through the app on the tvOS 26.5 simulator (Apple TV 4K 3rd generation) against the
live server; console through `simctl launch --console-pty`, server evidence through
`GET /api/logs`, `/api/schedule` and `/api/passes`.

**Record this airing** — the guide's 1:00 PM cell on 54.1 CWWNUV ("The Aging Brain",
1:00–1:30 PM), sheet opened by clicking a future airing (`11-airing-sheet-5c.jpg`):

```
app     [write] record hdhr-10a75953:54.1@1788714000 → rec-mtq0vmthc7619b Queued
server  seq=5115 12:24:54.343 [DVR]  Record Now: The Aging Brain on 54.1 CWWNUV at Sun 1:00 PM (pad 5/3 min)
        seq=5116 12:24:54.343 [HTTP] POST /api/record 200
        seq=5117 12:24:54.344 [HTTP] GET /api/schedule 200          ← the sheet's refresh
GET /api/schedule   count 1 · rec-mtq0vmthc7619b | Queued | manual | 54.1 CWWNUV | The Aging Brain | 1:00pm–1:30pm
```

The sheet redrew as **"● Scheduled · Queued"** with the footer "Set to record · Queued"
(`12-sheet-scheduled-queued.jpg`), and the guide cell carried the mark. After the app was
rebuilt and relaunched the mark was still there, read fresh from `/api/schedule`:
**● SCHEDULED** in green on that cell (`13-guide-mark-scheduled.jpg`).

**Record the series**, twice, on purpose:

- *"Xploration Outer Space"* (45.1, 1:00 PM). `[write] pass "Xploration Outer Space"
  series=C10857096ENE40Y → pass-mtq0yj8c72b630 0 recordings scheduled`; server `seq=5133
  [DVR] pass created: Xploration Outer Space (new episodes, 0 jobs queued)`, `seq=5134 POST
  /api/passes 200`. The sheet showed **"◆ Series pass · Xploration Outer Space"** and
  "Series pass created · 0 recordings scheduled" (`14-sheet-series-pass.jpg`). **Zero jobs**
  is the server's own rule, not a failure: the pass defaults to `recordMode "new"` and none
  of that show's three upcoming airings is flagged new (`GET /api/guide/search?title=…` →
  3 matches, all `new: false`). No ◆ mark follows a pass with no jobs — the marks are joined
  from `/api/schedule`, so a pass that matches nothing is invisible on the grid.
- Pressing "Record the series" again on the same airing after closing and reopening the sheet
  gave the 409 verbatim in the sheet: **"409 · a pass for this series already exists:
  Xploration Outer Space"** (`15-sheet-409-pass-exists.jpg`), and the button stayed live
  because no write happened.
- *"MLB Baseball"* (8.1 WGAL, 1:00 PM, `new: true`, 2 airings server-wide). `[write] pass
  "MLB Baseball" series=C191273ENZO34 → pass-mtq112y31d58bb 1 recording scheduled`; server
  `seq=5148 [DVR] pass created: MLB Baseball (new episodes, 1 job queued)`, `seq=5149 POST
  /api/passes 200`. The guide then showed **both marks at once** — ◆ SERIES PASS on
  MLB Baseball at 1:00 PM and ● SCHEDULED on The Aging Brain at 1:00 PM
  (`16-guide-both-marks.jpg`) — and `/api/schedule` listed both jobs:

```
3790ee0e6f60      | Queued | pass pass-mtq112y31d58bb | 8.1 WGAL-TV | MLB Baseball    | 1:00pm–4:00pm
rec-mtq0vmthc7619b| Queued | pass manual              | 54.1 CWWNUV | The Aging Brain | 1:00pm–1:30pm
```

  The pass queued **one** job, not two: the same episode airs on 8.1 and 11.1 and the server
  books it once.

**Cancelled, as step 6b requires.** Both were removed well before their 12:55 pre-padded
start (the airings began at 1:00 PM; nothing ever recorded from them):

```
PUT /api/schedule/jobs/rec-mtq0vmthc7619b {"skipped":true} → {"ok":true,"removed":true,"skipped":true}
DELETE /api/passes/pass-mtq112y31d58bb                     → {"ok":true}
DELETE /api/passes/pass-mtq0yj8c72b630                     → {"ok":true}   (the Xploration pass)
GET /api/schedule → count 0 passes 0        GET /api/passes → count 0 jobs 0
```

Re-entering the Guide showed a clean grid, no marks (`17-guide-marks-cleared.jpg`). Those
three cancel/delete calls are **not** app features — Pass 8's steps name only the two writes
above, so they were made with `curl` as test cleanup (Open Question 2).

---

## 3. Steps 5 and 6e — the tuner-busy state and "Stop the recording and watch"

The state was produced, so the path was tested rather than traced. The HDHomeRun HDFX-4K has
**four** tuners (`/api/sources[].hdhomerun.tunerCount`), so four antenna holders were needed:

1. My own throwaway recording, made with `POST /api/record` on the airing then on 54.1
   CWWNUV (§4): job `rec-mtq17zi54f4ab8`, status **Recording** on the reply.
2. Three live HLS sessions I opened myself on 2.1, 11.1 and 13.1 and kept alive with a
   5-second playlist fetch (`smtq18ek99e625d`, `smtq18ftl204aa4`, `smtq18gof1ed36c`; each
   first playlist 200). `GET /api/play/sessions` → `active 3`; server load 0.35 on a
   20-core i7-12700K, `activeStreams 3`.

The app then tried to watch a fifth antenna channel, 45.1 WBFF45:

```
app     [player] session smtq19ltz47197c live mode=transcode start=0.0 duration=0.0
        [player] first playlist → 502 ffmpeg exited before writing a playlist (see the session log)
server  seq=5344 12:35:46.258 [HTTP] POST /api/play/sessions 200
        seq=5345 12:35:46.287 [TRS]  ffmpeg exited early (exit status 8) — Error opening input: Server returned 5XX Server Error reply
        seq=5346 12:35:46.461 [TRS]  ffmpeg exited before writing a playlist
        seq=5347 12:35:46.461 [HTTP] GET /api/play/hls/smtq19ltz47197c/index.m3u8 502
        seq=5349 12:35:46.465 [HTTP] GET /api/play/sessions/smtq19ltz47197c/log 200   ← the app fetching the log
        seq=5350 12:35:46.471 [HTTP] GET /api/schedule 200                            ← the app attributing the tuner
```

Frame 6g came up exactly as designed (`20-tuner-busy-6g.jpg`): **"502 · STREAM COULD NOT
START / The tuner is busy / ch45.1 WBFF45 · Xploration Nature Knows Best · until 1:00 PM"**,
the server's own text, then *"Likely holding the tuner: The Aging Brain on 54.1 until 1:03 PM.
Stop that recording to watch this, or pick a channel on another source."*, with the buttons
**Stop the recording and watch · Pick another channel · Try again · Show the server log**.
The 1:03 PM is the padded end the server reports, not the airing's 1:00.

Pressing the button:

```
[write] stop job rec-mtq17zi54f4ab8 → STOPPED The Aging Brain stopped by owner
[player] session smtq1aot6567dd9 restarted start=0.0
[session] keep-alive loop started for index.m3u8 every 10 s
[session] keep-alive #1 → 206
```

and ch45.1 was playing (`21-live-after-stop.jpg`). One tuner freed, one live session started,
in one press. The three sessions I was holding were then released (`{"ok":true,
"wasRunning":true}` ×3) and `GET /api/play/sessions` returned `active 0`.

The 502's own text never says "tuner busy" — the attribution is the app's, derived from
`/api/schedule` and the channel's `sourceId` exactly as Pass 4 §3.10 said it would have to be.

---

## 4. Step 3 and step 6c — the throwaway recording and the four flags

**The throwaway recording.** `POST /api/record {channelId:"hdhr-10a75953:54.1",
start:1788712200}` — the same request shape the sheet builds — on the airing then in progress;
the reply was the `Job` with `status: "Recording"`, id `rec-mtq17zi54f4ab8`. It ran for about
two minutes and was ended by the step-5 test above (`stopped by owner`), leaving the partial
file `The Aging Brain/The Aging Brain 2026-09-06-1230.mpg`, recording id **`eb236eabca27`**,
56.33 MB, 2 min. **This is the only recording touched by the flag tests**; the owner's one
recording (`4b4a3f0f8fc8`, Earth Odyssey With Dylan Dreyer) was never written to and is
verified unchanged in §7.

It was booked with `curl` rather than through the sheet because the sheet cannot be opened on
an airing that is already in progress without a click-and-hold, and a hold cannot be produced
on the simulator at all (§6.1 — three input methods tried). The request is byte-for-byte the
one `APIClient.recordNow` sends, and the same call was proven through the app on a future
airing in §2.

**The four flags**, every one through the app's own long-press menu (`32-episode-menu-open.jpg`,
`35-menu-full-state.jpg`), each verified against `GET /api/library/shows/the-aging-brain`:

| Menu row | App console | Server after |
|---|---|---|
| Keep (Off → On) | `[write] recording eb236eabca27 keep=true → watched=false favorite=false keep=true trash=false` | `keep True`; the row grew a **◆ Keep** flag (`33-row-keep-flag.jpg`); server log `seq=5644 [DVR] recording eb236eabca27 (…): watched=false favorite=false keep=true trash=false (flags only; the file is untouched…)`, `seq=5645 PUT … 200` |
| Keep (On → Off) | `[write] … keep=false → … keep=false …` | `keep False` — the toggle works both ways |
| Favorite (Off → On) | `[write] … favorite=true → watched=false favorite=true keep=false trash=false` | `fav True`; the row showed **★ Favorite** |
| Mark unwatched | `[write] … watched=false → watched=false favorite=true keep=false trash=false` | `watched False`. The row was watched first (a `curl` fixture `{"watched":true}`, since a fresh recording is unwatched and the row is disabled then — it read "Already unwatched" before and "✓ Watched" after, `34-menu-watched-favorite.jpg`) |
| Favorite (On → Off) | `[write] … favorite=false → watched=true favorite=false keep=false trash=false` | `fav False` |
| **Delete** | `[write] … trash=true → watched=true favorite=false keep=false trash=true` | `GET …/shows/the-aging-brain` → **count 0, trashCount 1**; `?trash=1` → `eb236eabca27 … trash True exists True`. In the app the episode **left the list**: "0 episodes · 0 unwatched · Zero KB" (`37-episode-gone-after-trash.jpg`) |

Every row redrew from the `episodeView` the server returned, not from a guess: the
`watched=true` in the last two lines is the server's own value, written by the Player's
watched-on-end (§8 question 6) between two menu actions, and the menu picked it up on the next
write's reply.

**The final state of the throwaway is trash-flagged, and that is deliberate.** `keep` is off,
so the owner's "Remove Items From Trash After: 1 day" removes the file on its own; the expiry
honours only `trash` and `TrashedAt` (trash.go:227-252), so nothing blocks it. It was **not**
restored from the trash, and `POST /api/library/trash/empty` was never called.

---

## 5. Step 4 — Hide this channel

The write, the exact request `PlayerModel.hideChannel()` builds, on a Philo channel with no
existing override (9028 ACCUWEATHER, `philo:6903`):

```
before  GET /api/sources/philo/lineup   → 6903 hidden False favorite False, mapped 9028/ACCUWEATHER
        GET /api/channels               → 38 channels, philo:6903 present
PUT /api/sources/philo/lineup/6903  {"hidden":true}   → {"hidden":true,"favorite":false}
after   GET /api/channels               → 37, philo:6903 absent
        GET /api/guide/now              → 37, philo:6903 absent
```

In the app, returning to Home reloaded the counts: **"Guide 37 channels live · On Now 37
programs live"** (`40-home-37-channels-hidden.jpg`) — the channel left the app's lists on the
next load, which is what step 4 asks for.

```
PUT /api/sources/philo/lineup/6903  {"hidden":false}  → {"hidden":false,"favorite":false}
after   GET /api/channels               → 38, philo:6903 present
        lineup row 6903                 → hidden False favorite False, mapped 9028/ACCUWEATHER
        philo channels with any override flag: 0      (as before the test)
```

and the app read **38 again** (`41-home-38-channels-restored.jpg`). One caveat stated
precisely: the round trip leaves an all-false override record stored for that guid where
before there was none (`l.Overrides[guid] = o` always writes, sources.go:1022). Every visible
field is identical, and the lineup reports no flag set on any Philo channel.

**The app's own button could not be reached, and here is why.** "Hide this channel" renders
only on frame 6f, the 403 the server answers for a DRM channel (stream.go:205-208). All five
DRM channels on this server (103.1, 110.1, 129.1, 157.1, 165.1) are also `hidden: true`, so
they are absent from `/api/channels` and `/api/guide`; and even unhidden the app's own DRM
rule (`ChannelFilter.playable`) drops them from every list. There is therefore no path through
the UI to a 403, and none was manufactured. The button's code path is one call —
`api.setChannelHidden(sourceId:guid:hidden:true)` on `request.channel` — and that call is what
was executed above. **Declared: the endpoint and the effect on the app's lists are tested; the
button itself is traced, not pressed.**

---

## 6. Found and fixed: two defects that blocked this sweep

### 6.1 `.onLongPressGesture` on a tvOS Button never fires

Sweep 3 wired both click-and-hold gestures — the guide cell that opens the airing sheet
(DECISIONS.md 2026-09-06) and, as written at the start of this pass, the episode menu — with
`.onLongPressGesture(minimumDuration: 0.5)` on the same `Button` that has a click action. On
tvOS that never runs: the focused Button takes the Select press and fires its action on
release however long the press was held.

Established on the running app with three different inputs, all on a guide cell whose click
plays live (so the two outcomes are distinguishable):

| Input | Held | Result |
|---|---|---|
| System Events `key down return` / `key up return` | 1.2 s | click — live session started |
| the same | 2.5 s | click |
| CGEvent `keyDown` with auto-repeat posted every 50 ms | 1.5 s | click (`30-longpress-defect-plays.jpg`) |
| Real mouse press-and-hold on the Simulator's Apple TV Remote touch surface | 1.5 s | click — the recording started playing |

The fourth is the faithful one: it is the Siri Remote's own select button with a genuine press
duration, and it still clicked.

**The fix** is `HoldButton.swift`: the button style reports `configuration.isPressed`, which
tvOS does set for the whole press; a timer started on press-down fires the hold action at
0.5 s (so the menu appears under your thumb, not on release) and sets a flag that makes the
Button's own action a no-op when the press ends. Both sites now use it — the episode row and
the guide cell. With it, a 1.2–1.4 s hold on the remote opens the menu every time
(`32-episode-menu-open.jpg`), and a short click still plays.

This is a change to sweep-3 behaviour, and it is in scope because step 1 and step 3 both
depend on it: click-and-hold is the only route to the airing sheet for a programme already in
progress ("record what's on now") and the only route to the episode menu.

### 6.2 The episode list could not be reached with the remote

In show detail the left column (Resume / Play newest / Series pass, low on the screen) and the
episode rows (high on the right) are one `HStack`. tvOS moves focus geometrically, so right
from "Series pass" found nothing and the episode rows were unreachable — proven by pressing
right, right, up, down from the buttons with no focus change. `.focusSection()` on each column
fixes it; the episode row takes focus on the first right press (`31-episode-row-focusable.jpg`).

Also pre-existing and also shipped since sweep 2. No episode row had ever been focused before
this pass.

### 6.3 Smaller things fixed in passing

- The sheet lost focus to the rail when a pressed button was replaced by its state chip
  (visible in `12-sheet-scheduled-queued.jpg`, taken before the fix); focus now moves to the
  next live button in the sheet.
- The ● mark said "RECORDING" for a booking that had not started; it now says **SCHEDULED**
  for a queued Record Now and keeps RECORDING for a running one, with the legend "Recording or
  set to record".
- `PlayerModel.fail()` now forgets the stopped session, so "Stop the recording and watch" no
  longer DELETEs an already-removed session a second time (`DELETE … → 404` in the 6g run).

---

## 7. Cleanup, proven

Taken at 13:00:05, after every test, with the server's own answers:

```
GET /api/schedule        → count 0  passes 0        (no groups, no items)
GET /api/passes          → count 0  jobs 0          passes: []
GET /api/play/sessions   → active 0                 (no session listed active)
GET /api/sources/philo/lineup           → hidden=0  favorite=[]  renamed=[]
GET /api/sources/hdhr-10a75953/lineup   → hidden=12 ['22.1 MPT-HD','22.2 MPT-2','22.3 MPTKIDS',
     '22.4 NHK-WLD','40.2 WLYH-SD','40.3 Pocono','62.2 EXITOS','103.1 KYW-TV','110.1 WCAU-TV',
     '129.1 WTXFDT','157.1 WPSG','165.1 WUVP-DT']   favorite=[] renamed=[]
GET /api/channels        → 38
GET /api/settings        → trashAfter '1 day'  padBefore '5 mins before'  padAfter '3 mins after'
                           detectCommercials True
```

Item by item against step 7:

| Required | Evidence |
|---|---|
| No job I created still queued or recording | `/api/schedule` count 0. `rec-mtq0vmthc7619b` was removed by `{"skipped":true}` (`"removed":true`); `rec-mtq17zi54f4ab8` ended STOPPED and left the schedule when its airing ended at 1:00 PM. Nothing ever ran except the ~2-minute throwaway. |
| My test pass deleted | `/api/passes` count 0; both `DELETE /api/passes/{id}` returned `{"ok":true}`. Neither pass ever recorded anything. |
| The hidden channel unhidden | `philo` lineup: no channel hidden, none favourited, none renumbered or renamed; `/api/channels` back to 38; the app reads 38. The 12 hidden antenna channels are the owner's own set, exactly as found at 12:16. |
| No orphaned sessions | `active 0`. Every session opened this pass was closed: the app's own by the app (`DELETE … {"ok":true,"wasRunning":true}`), the three tuner-holds by their script (three `{"ok":true,"wasRunning":true}` lines), and the failed 6g session by the server itself when ffmpeg died. |
| The throwaway recording left trash-flagged | `shows/the-aging-brain` → visible 0, trashCount 1; `?trash=1` → `eb236eabca27 … keep False trash True exists True`. It expires under the owner's "1 day" setting. **Not restored, trash never emptied.** |
| The owner's recording untouched | `4b4a3f0f8fc8` Earth Odyssey With Dylan Dreyer: `watched True fav False keep False trash False` — the state Pass 7 left it in, with no write from this pass. Its show detail was opened once by a mis-navigation and closed with no action. |
| Server settings untouched | `/api/settings` reads exactly what it read before the pass began. |

Left behind on purpose, and nothing else: the throwaway recording in the trash, and the
records of the sessions and the two finished jobs, which the server keeps as history.

---

## 8. Open Questions

1. **Two sweep-4 buttons in the Pass 4 plan are not in Pass 8's steps, so they were left
   inert:** show detail's "Series pass" (5d, `library.go:632-639` gives the show's existing
   pass title) and the Player's "Delete this recording" on 6e. Both are one call each to code
   that now exists (`createPass`, `updateRecording(.trash(true))`). Wire them in a follow-up?
2. **Cancelling is not in the app at all.** Nothing undoes a Record Now (`PUT
   /api/schedule/jobs/{id} {skipped:true}`) or a series pass (`DELETE /api/passes/{id}`) from
   the Apple TV; I used `curl` for both. The sheet shows "● Scheduled" with no way back.
3. **`recordMode: "new"` surprises.** A series pass on a show whose upcoming airings are not
   flagged new queues nothing and leaves no ◆ mark, which reads as "the button did nothing".
   Say so in the sheet ("0 recordings scheduled — this pass records new episodes only"), or
   offer "all episodes"?
4. **Press-and-hold on the real remote is still unverified.** §6.1 fixed a defect I could
   reproduce three ways in the simulator, and the fix works there; the Siri Remote itself has
   never been tested on either gesture. This is the first thing to try on Home Theater.
5. **The guide's marks go stale.** `/api/guide` is fetched 24 hours at a time and the schedule
   with it; paging inside that window does not refetch, so a change made elsewhere (or by
   `curl`) shows only after leaving and re-entering the Guide. Writes made in the app refresh
   it themselves. Refresh the schedule on a timer, or on every window move?
6. **Show detail does not reload after the Player closes**, so a recording marked watched by
   playing to the end still reads unwatched until the screen is re-entered (seen in §4).
7. **"Hide this channel" hides for everyone.** The override is server-wide (Pass 4 Open
   Question 8): the web UI and the other Apple TV lose the channel too, and only the web UI can
   put it back — the app has no unhide. Is that the intent?
8. **The 6f path is unreachable** (§5). If "Hide this channel" is meant to be usable, it needs
   an entry point that is not a DRM 403 — the channel row in the Guide, say.
9. **One recording is stopped, not several.** Frame 6g's button stops the first recording
   listed; if two hold tuners the retry can fail again. Stop all listed, or name the one?
10. **Another client's live session can hold a tuner** and never appears in `/api/schedule`
    (Pass 4 Open Question 12): in that case 6g says "The stream could not start" with no
    "likely holding" line and no stop button. Should the app read `/api/play/sessions` too?
11. **The throwaway recording's show folder** ("The Aging Brain") stays in the library index
    with 0 visible episodes until the trash expires. Cosmetic; nothing to do.
12. **Console lines** `[write] …` remain as diagnostics, with `[player]`/`[session]` from
    sweep 3.

---

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/ServerWrites.swift` (new) | 1, 2, 3, 4, 5 — the five calls and their shapes |
| `Marlin DVR TV/ServerAPI.swift` — `put` beside `post` | 1–5 (3 and 4 are PUTs) |
| `Marlin DVR TV/AiringSheet.swift` — the two writes, the state chips, the server's words | 1, 2 |
| `Marlin DVR TV/GuideScreen.swift` — `refreshSchedule`, the ● SCHEDULED mark, the sheet's arguments, `HoldButton` | 1, 2 (+ 6.1) |
| `Marlin DVR TV/EpisodeActionsMenu.swift` (new) — the long-press menu | 3 |
| `Marlin DVR TV/ShowDetailScreen.swift` — the mutable episode list, the menu, the flags on a row, focus sections | 3 (+ 6.2) |
| `Marlin DVR TV/HoldButton.swift` (new) — click vs click-and-hold | 1, 3 (the defect of §6.1) |
| `Marlin DVR TV/PlayerModel.swift` — `BusyRecording`, `hideChannel`, `stopBlockingRecordingAndWatch`, the session fix | 4, 5 |
| `Marlin DVR TV/PlayerScreen.swift` — the 6f and 6g buttons wired | 4, 5 |
| `reports/assets/pass8/*.jpg` (20 files, 3.0 MB) | 6 |
| `COLD-START.md` — "What is built", "What is NOT built", "Next step" | deliverable |
| `reports/2026-09-06-pass8-sweep4-writes.md` (this file) | deliverable |
| Local commit "Pass 8: sweep 4 — the writes"; **no push** | deliverable |

Nothing else was written. Untouched in the repo: `DECISIONS.md`, `Info.plist`, the project
file and build settings, `Assets.xcassets`, `design/`, and every other Swift file
(`Models.swift`, `ChannelFilter.swift`, `ClientSession.swift`, `Destination.swift`,
`RailView.swift`, `HomeView.swift`, `Formatting.swift`, `ScreenChrome.swift`, `ScreenShell.swift`,
`OnNowScreen.swift`, `OnLaterScreen.swift`, `RecordingsScreen.swift`, `CamerasScreen.swift`,
`ServerImage.swift`, `Theme.swift`, `ResumeStore.swift`, `PlayRequest.swift`,
`PlaybackSession.swift`, `PlayerHost.swift`, `ContentView.swift`, `Marlin_DVR_TVApp.swift`).

Outside the repo: DerivedData; the app on the simulator and on Home Theater (installed and
launched at 13:00, its ping and five GETs in the server log); on the server, the two cancelled
jobs, the two deleted passes, the throwaway recording now in the trash, the sessions listed
above and the lineup override round trip — all accounted for in §7. The reference clone and
`design/` were only read. No request went beyond port 8090; none to marlinpc, the HDHomeRun
directly, or the UNAS4Pro share. Nothing installed; no packages; no third-party code. Two
small helper binaries were compiled in the session scratchpad (outside `~/Xcode`) to drive the
simulator's remote for the long-press test, and are not part of the app.
