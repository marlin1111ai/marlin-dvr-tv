# Pass 127 — S6: a frame-step click waits for the item and the resume seek

**Date:** 2026-09-25 (19:00–19:35 EDT)
**Built on:** `2888704460533144b0a2032da11a51e1986a1ec2` (Pass 126). **One commit, not pushed** — the owner
tests on Home Theater first.

**Result.** S6 is built as Pass 119's report describes it, in the two files that report names and no other:
`PlayerModel.swift` (+17 / −0) and `PlayerHost.swift` (+3 / −1, a comment). `frameStep` now declines,
before its `cancelPendingSeeks`, while the item is not yet `.readyToPlay` and while the resume seek is still
in flight; the app owns the arrow then, so such a click does nothing at all. **Measured on Home Theater with
the console attached** (drive 1): a pause and six Right clicks inside the first two seconds after Resume —
the first click declined "the item is not ready yet", the second "the resume seek is still in flight",
**the resume seek then landed on 898.000 s**, and every later click stepped **0.033367 s at 29.9700 fps**.
**The run of record** (run 2, `launch()`): the same burst, 126 clicks, no crash, the Player up throughout,
and "Resume S6 E16 · 15 min in" before and after — `** TEST EXECUTE SUCCEEDED **`. `restart(at:)`,
S5's change, `armArrowOwnership` and `armSelectOwnership` are untouched.

**Found beside S6, not built.** A pause that lands before the item is ready leaves Apple's transport bar's
scrub head at 0:00; it stays there through the resume seek and 126 frame steps, and a Select to play on
seeks to it. Drive 1's harness lost the subject's saved position that way; it was put back (§3.3). Open
question 1.

**What this pass did not do.** It did not touch the bedroom Apple TV. It sent **no write of its own** to the
Marlin DVR server: my requests were two `GET /api/logs`; the app's own traffic was its launch pings, its
play sessions (a `POST` and a `DELETE` each) and GETs (§5). Nothing was installed on this Mac. marlin-dvr was
not cloned or read. No diagnostic was added to the app target. `GuideScreen.swift`, `ScreenShell.swift`,
`RailView.swift`, `design/`, `icon-source/`, `REVIEW.md` and every existing report are unchanged.

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:84).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`2888704460533144b0a2032da11a51e1986a1ec2`**. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — what was built

### 2.1 The defect, traced at HEAD

- `attach` (`:202`) calls `player.play()` and sets `.playing` on an item whose status is still `.unknown`;
  Pass 96 measured 0.45–0.79 s from attach to `.readyToPlay`, then 0.19–0.32 s for the resume seek to
  land (`reports/2026-09-16-pass96-resume-whole-recording.md:167-168`).
- `frameStep`'s guard checked `isRecording`, `isPaused`, `phase == .playing`, `frames` and the item — not
  readiness, not `pendingResumeSeek`. A paused click in the window reached `cancelPendingSeeks` and an
  exact seek with a completion handler on an item with no timebase.
- A click during the seek's flight cancelled the resume seek after `resumeSeekDone` had been set, so the
  item stayed at the top and `tick()`'s next save wrote that over the stored entry.
- Where Pass 119's report corrected REVIEW.md: the crash is not established — the SDK documents a cancelled
  seek, not an exception, for a target outside the (empty) seekable ranges — and the window is the first
  0.45–0.79 s after the Player appears at whatever point playback begins, not "the first second of a
  recording".

### 2.2 The fix

- **`frameStep`** (`:436`): after the existing guard, `guard item.status == .readyToPlay` (`:438`) and
  `guard pendingResumeSeek == nil` (`:442`), each returning false with a console line — `[framestep]
  declined — the item is not ready yet` / `… the resume seek is still in flight`. Both sit before
  `cancelPendingSeeks`, as Pass 119 (b) asks.
- **Why a declined click does nothing at all:** `PlayerScreen` arms `ownsArrows` whenever the model is
  paused on a recording (`PlayerScreen.swift:47`), and `armArrowOwnership` has disabled Apple's two arrow
  recognizers for as long as that holds (Pass 29). A false from `frameStep` lets the press fall through to
  `super`, where nothing is listening. Pass 119 (d) names this as the narrow exception to the Pass 28
  decision.
- **Comments brought true:** `frameStep`'s doc (`:427-434`) and the Pass 28 paragraph in
  `PlayerHost.swift`'s header (`:21-23`), which listed the cases where `frameStep` answers false.
- **Untouched:** `restart(at:)` — `position = target` (`:882`) and Pass 125's `if everAttached` (`:866`);
  `armArrowOwnership`, `armSelectOwnership`; `armResumeSeek`, `seekToResumePosition`, `resumeSeekLanded`.

---

## 3. Verify — five runs on Home Theater, the app's code identical throughout

```
xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p127 build-for-testing
xcodebuild test-without-building -xctestrun build/p127/Build/Products/…xctestrun \
  -destination 'platform=tvOS,name=Home Theater' \
  -only-testing:"Marlin DVR TVUITests/FrameStepReadyUITests/<method>"
```

`FrameStepReadyUITests` (new), three methods. The drive: Home → Recordings; open *The Proof Is Out There*
S6 E16 (`dd5f3e4a6778`, 1 hr 11 min, 29.97 fps — preferred because its saved spot sits in no detected
break, where the standing subject's now does) from its Continue watching card; read show detail's Resume
line; press Resume; at about +0.9 s press Select to pause; six Right clicks at 120 ms; sixty Right and
sixty Left at 150 ms; Menu from the paused state; read the Resume line again. The app target was built once
(19:03) and did not change; every later `build-for-testing` rebuilt the harness only.

| # | Method | Launch ping | Result | What it showed |
|---|---|---|---|---|
| 1 | console drive | `19:04:39.106` (devicectl) | failed on the harness | **S6's window hit, the fix held** (§3.1); the harness's clock read and its play-on Select were wrong (§3.2) |
| — | restore ×4 | 19:10:58 … `19:17:43.236` | the fourth passed | the subject's position put back to "15 min in" (§3.3) |
| 2 | console drive | `19:20:06.232` (devicectl) | passed | a faster start; no click met the window; 126 steps of 0.033367 s (§3.4) |
| 3 | `launch()` | `19:22:13.003` | passed | two log strings worded for drive 1, then neutralised |
| **4** | **`launch()`** | **`19:24:24.346`** | **passed — the record** | §3.5 |

### 3.1 Drive 1 — the window hit, with the console attached

The app's own lines, the Mac's clock on each; Resume pressed at `19:05:08.319`:

```
19:05:08.275 [player] session smuhkjipgc4dc40 recording mode=copy start=0.0 duration=4270.266
19:05:09.100 [player] first fetch (file) → 206
19:05:09.116 [resume] will seek to 898.00 s once the item is ready
19:05:09.278 [player] paused (14:58)                         ← the harness's Select, 0.16 s after attach, before ready
19:05:09.338 [framestep] app owns the arrow — 2 player recognizer(s) disabled
19:05:09.518 [framestep] declined — the item is not ready yet            ← click 1
19:05:09.861 [framestep] declined — the resume seek is still in flight   ← click 2
19:05:10.192 [resume] asked 898.00 s, landed t=898.000367 → position 898.00 s of 4270.27 s
19:05:10.347 [framestep] frame rate 29.9700 fps (nominalFrameRate read 29.9700) → one frame = 0.033367 s
19:05:10.347 [framestep] +0.033333 s (one frame at 29.9700 fps = 0.033367 s) → t=898.033700   ← click 3
19:05:10.647 [framestep] +0.033367 s … → t=898.067067                                          ← click 4
19:05:10.977 [framestep] +0.033367 s … → t=898.100433                                          ← click 5
19:05:11.328 [framestep] +0.033367 s … → t=898.133800                                          ← click 6
19:05:17.591 … 19:05:40.543   sixty × [framestep] +0.033367 s … → t=900.135800
19:05:46.317 … 19:06:03.754   sixty × [framestep] -0.033367 s … → t=898.133800
```

The pause landed before the item was ready; click 1 was declined in the not-ready window and click 2 in the
seek's flight; the resume seek — which click 2 would have cancelled at HEAD — landed 367 µs from the
saved position; and every one of the next 124 clicks moved 0.033367 s (the first 0.033333 s, a rounding on
the first landing), sixty forward to 900.136 and sixty back to 898.134.

### 3.2 Why drive 1's harness failed, and what it found

Two readings were wrong, and the second cost the subject its position.

- **Apple's transport-bar clock.** The harness read a static text "0:00" as the position. Screenshot
  `03-paused-after-the-burst` from that drive shows the picture at the resumed spot and **the bar's scrub
  head at the far left**. A pause that lands before the item is ready leaves the head at 0:00, and it stays
  there through the resume seek and 126 programmatic seeks — the bar follows `currentTime` while playing,
  not while paused. In Pass 125's run the pause came 17 s into playback and the head read "03:24".
- **Select to play on.** That Select seeks to the head: `19:06:15.265 [player] playing (0:00)`, then
  `[commercials] break 1 starts at 0.00 s (position 0.00 s)`; Menu then ran `stop()` in `.playing`, whose
  save wrote a position under five seconds, and show detail drew no Resume line. **This is Apple's transport
  behaviour after an early pause, not S6's, and nothing in this app touches the scrub head**; before this pass
  a click in the window cancelled the seek and the item was at the top anyway. It is open question 1.

The harness now reads the app's own store — the Resume line and the card — never the bar's clock; proves
the Player is up by the metadata line the bar draws; and leaves from the paused state with Menu.

### 3.3 The restore

The drive had found *The Proof Is Out There* S6 E16 at "14 min in" and left it at the top.
`testPutTheSubjectsPositionBack` (`launch()`, ping `19:17:43.236`) opened the show from its shelf card, chose
the S6 E16 row (Right across "Edit series pass" into the episodes, then Down), played it from the top and
walked forward with Apple's own 10 s skip — eighty-eight Right clicks while playing, the app never owning
the arrow — then left with Menu: **"Resume S6 E16 · 15 min in"** (session `19:18:24.949`–`19:19:32.010`,
1.16 GB served). Three earlier attempts (pings 19:10:58, 19:13:04, 19:14:45, 19:16:23) failed in the
harness's navigation — a shelf walk that went Left into the rail and Down there; a shelf card's label
leading with its badge, "4 new, The Proof Is Out There, 4 episodes"; and Right from "Play newest" landing on
"Edit series pass", the button Pass 103 added, so that a second Right is what crosses into the episodes.
Each is now in the harness. The position is one minute past where the drive found it.

### 3.4 Drive 2 — the final harness, with the console attached

Ping `19:20:06.232`; Resume pressed `19:20:34.392`:

```
19:20:34.333 [player] session smuhl3dau7188a1 recording mode=copy start=0.0 duration=4270.266
19:20:34.349 [player] first fetch (file) → 206
19:20:34.369 [resume] will seek to 915.00 s once the item is ready
19:20:35.157 [resume] asked 915.00 s, landed t=915.000711 → position 915.00 s of 4270.27 s
19:20:35.376 [player] paused (15:15)                          ← the harness's Select, after the seek had landed
19:20:35.613 … 19:21:35.932   66 × +0.033367 s and 60 × −0.033367 s, no other size, t=915.034 … 917.203 … 915.201
19:21:40.229 [player] stop: phase=playing session=smuhl3dau7188a1
19:21:40.394 [session] DELETE smuhl3dau7188a1 → 200
```

A faster start this time — the first fetch 16 ms after the session and the seek landed at +0.8 s — so the
pause fell after it and no click met the window; all 126 stepped exactly. Menu from the paused state kept
"15 min in". Whether a given run's burst lands inside the window is timing the harness cannot control;
drive 1 is the measurement of the window, on the same binary.

### 3.5 The run of record — run 4

**19:24:19–19:25:54, `** TEST EXECUTE SUCCEEDED **`, "Executed 1 test, with 0 failures", 91.3 s.** Its
lines, verbatim, the screen reads trimmed:

```
[pass127 19:24:25.326] launched
[pass127 19:24:35.734] Continue watching cards: ["The Proof Is Out There, S6 E16 · 15 min in", "History's Greatest Mysteries, S4 E14 · 3 min in", "History's Greatest Mysteries, S7 E20 · 1 min in"]
[pass127 19:24:35.735] subject: “The Proof Is Out There, S6 E16 · 15 min in” — 15 min in before
[pass127 19:24:40.815] show detail before: “Resume S6 E16 · 15 min in” · focus=Resume S6 E16 · 15 min in
[pass127 19:24:41.363] Resume pressed
[pass127 19:24:42.509] Select (pause) sent at about +0.9 s
[pass127 19:24:44.694] six Right clicks sent, about +1.1 s to +2.0 s
[pass127 19:24:52.462] after the burst: the app is up and the Player is drawn · the bar's scrub head reads 915 s (the head, not the app's position — see the header) · text=[…]
[pass127 19:25:19.859] 60 Right clicks sent; the app and the Player are still up
[pass127 19:25:47.203] 60 Left clicks sent; the app and the Player are still up
[pass127 19:25:52.402] show detail after: “Resume S6 E16 · 15 min in” — 15 min in
[pass127 19:25:52.703] RESULT no crash; 126 clicks sent — which of them fell inside the not-ready window is the console's to say; saved 15 → 15 min in
```

**The launch ping and the server's view of the run** (`GET /api/logs`, client id replaced):

```
19:24:24.346 POST /api/clients/<client id>/ping 200
19:24:24.352–.360  GET /api/cameras, /api/library, /api/radio, /api/channels, /api/schedule, /api/guide/now   (Home)
19:24:30.776–.881  GET /api/library, six GET /api/library/shows/…                                            (Recordings)
19:24:36.136 GET /api/library/shows/the-proof-is-out-there 200 · GET /api/passes 200                       (show detail)
19:24:41.249 TRS  session smuhl8nts3f53f8: serving the .mp4 beside The Proof Is Out There — 1.81 GB, no ffmpeg
19:24:41.250 POST /api/play/sessions 200
19:24:41.436 GET /api/library/recordings/dd5f3e4a6778/commercials 200
             59 × GET /api/play/file/smuhl8nts3f53f8/video.mp4 206
19:25:47.683 DELETE /api/play/sessions/smuhl8nts3f53f8 200                                                 (Menu → stop())
19:25:47.683 TRS  session smuhl8nts3f53f8 ended after 1m: stop requested by D/S Apple TV; 150.22 MB served
```

Across 19:00–19:27 the log holds **eighteen non-GET requests, all the app's own**: eight launch pings, five
session `POST`s and their five `DELETE`s. Nothing else.

**Screenshots** (run 4), in `reports/assets/pass127/`: `01-continue-watching-before.jpg`,
`02-show-detail-before.jpg`, `03-paused-after-the-burst.jpg` (the picture at the resumed spot, the bar's
head at 15:15), `04-after-60-right-clicks.jpg`, `05-after-60-left-clicks.jpg`, `06-show-detail-after.jpg`.

---

## 4. Run or traced

**Run on Home Theater:**
- **Resume lands on the saved position** — drive 1's `landed t=898.000367` with the burst under way and two
  clicks already declined; drive 2's `915.000711`; every run's Resume line kept to the minute;
- **each Left or Right click after that moves exactly one frame** — 246 steps across the two console drives,
  every one 0.033367 s at 29.9700 fps (the first of drive 1 0.033333 s), none of another size; the two
  `launch()` runs sent 126 each with the Player up throughout;
- **a click declined in the not-ready window, and one in the seek's flight, does nothing at all** — drive 1,
  two declined and the time unmoved until the first stepped click;
- no crash, across five runs and 630 paused clicks;
- the position surviving Menu from the paused state, on the Resume line and the card.

**Code-traced only:**
- which clicks of the record run's burst fell inside the window — its console is not attached; drive 1 is
  the measurement, on the same binary, and drive 2 shows the window can be missed;
- the exception REVIEW.md feared — never seen on tvOS 26.6 or any other: no run before this pass ever
  clicked inside the window, and after it no seek is sent there;
- the `playNext` variant, and a live channel or camera (`frameStep` bails before the new guards);
- the dependence on `AVPlayerViewController`'s internals that makes a declined click do nothing
  (COLD-START.md's closed item on `armArrowOwnership`), unchanged and not re-measured.

---

## 5. The server reads this pass made

Two `GET http://192.168.1.250:8090/api/logs` with `curl`, after drive 1 and after run 4. `GET /api/settings`
was not read. Everything else was the app's own traffic (§3).

**The saved positions.** *The Proof Is Out There* S6 E16 read "14 min in" before the pass, was lost by
drive 1's harness, was restored to "15 min in" (§3.3) and reads "15 min in" after the record; *History's
Greatest Mysteries*'s two positions were not touched. No entry was cleared — nothing was played to its end —
and nothing was deleted, trashed, kept, scheduled or marked watched.

---

## 6. Records this pass changes, recorded forward and not edited

- DECISIONS.md, 2026-09-07 (frame-by-frame): *"Left and right **clicks** move one frame while paused on a
  recording"* — now with the narrow exception Pass 119 (d) names: not before the item is ready, and not
  while the resume seek is in flight; the record stays true as history.
- `PlayerHost.swift`'s Pass 28 header paragraph, *"`frameStep` answers false in every other case — playing,
  live, camera"* — amended in place, a comment, with the two new cases.
- **COLD-START.md's Player line is brought to the current state in place** (step 3); *Next step* likewise,
  with Pass 126's paragraph kept beneath it, labelled.

Checked and not changed: the owner's decision that clicks step and swipes keep their skips (2026-09-07) —
swipes are untouched; Pass 29's `armArrowOwnership` — byte-identical; Pass 125's S5 — byte-identical.

---

## Open questions

1. **After a pause that lands before the item is ready, Apple's transport bar's scrub head sits at 0:00 and
   the next Select seeks there**, losing the resume position (§3.2, measured once). Nothing in this app
   touches the scrub head; the pause window is about a second after Resume. Leave it, or build something —
   for instance refuse the pause until the item is ready, or seek the bar's head after the resume seek lands?
   Until decided, Menu from such a pause is safe and Select is not.
2. **The harness reads no clock inside the Player.** Since Pass 110 removed the recording HUD, the only
   in-Player position is Apple's bar, and §3.2 shows when it lies. The exact numbers are the console's;
   should a future pass need them under `launch()`, a disclosed print or a re-drawn position line would be
   the way.
3. `armResumeSeek` still reads its target out of `position` (Pass 98's question, closed 2026-09-20; Pass 125
   left it too).

## What I am least sure of

1. **That drive 1's two declined clicks are the whole of S6's path.** They hit both windows once each; the
   record run may have hit neither. The guard is the same code either way, and drive 1 ran the committed
   binary — but the window was hit in one drive of three.
2. **That the scrub-head finding is Apple's and general**, not something about that one early pause. It was
   seen once, and I did not spend a further run on it because it is outside S6.
3. **That "does nothing at all" holds on a tvOS where `armArrowOwnership` fails open.** There a declined
   click would be Apple's 10 s skip — the closed item's stated failure mode, not a new one.

## How the owner can check it on Home Theater

Open Recordings, pick a Continue watching card, press Resume, and **press Select to pause straight away** —
within the first second. Then click Left or Right a few times. For a moment nothing happens; then each
click moves one frame, and the picture is where he left off, not the top of the recording. Pausing later
and stepping works exactly as before. **After such an early pause, leave with Menu**: a Select to play on
may jump to the top of the recording (open question 1), which is Apple's transport bar and not this change.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/PlayerModel.swift` | 2 | two guards with console lines at the top of `frameStep`; its doc comment; +17 / −0 |
| `Marlin DVR TV/PlayerHost.swift` | 2 | one sentence in the header's Pass 28 paragraph; +3 / −1 |
| `Marlin DVR TVUITests/FrameStepReadyUITests.swift` | Verify | new — the run's harness, three methods (the record with `launch()`, the console drive, the restore), which the pass allows |
| `DECISIONS.md` | 3 | the Pass 127 entry: the bedroom install after Pass 126, then S6 |
| `COLD-START.md` | 3 | the Player line; *Next step*, with Pass 126's paragraph kept beneath it, labelled |
| `reports/2026-09-25-pass127-s6-frame-step-waits-for-ready.md` | 3 | new — this report |
| `reports/assets/pass127/` (6 `.jpg`, 2.0 MB) | 3 | new — run 4's screenshots, exported from its result bundle |

**Nothing else was changed.** `GuideScreen.swift`, `ScreenShell.swift`, `RailView.swift`, `ResumeStore.swift`,
`project.pbxproj` and every other app and test file are byte-identical; the UI-test target is a synchronised
folder, so the harness needed no project edit. Scratch — the two consoles, the seven test logs, the two log
reads and the exported attachments — is in the session scratchpad, outside the repo. `build/p127` is the
DerivedData of the runs; `build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, one ahead of `origin/main` (`2888704`). Nothing was pushed: the owner
tests on Home Theater first.
