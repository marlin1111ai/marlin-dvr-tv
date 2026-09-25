# Pass 125 — S5: "Try again" after a failed start keeps the saved position

**Date:** 2026-09-25 (18:41–19:00 EDT)
**Built on:** `4a7f927cd8a58088f0084aa416547083f3185b37` (Pass 124). **One commit, not pushed** — the owner
tests on Home Theater first.

**Result.** S5 is built as Pass 119's report describes it, in the two files that report names and no other:
`PlayerModel.swift` (+23 / −3) and `ResumeStore.swift` (+3 / −2, a comment). `restart(at:)` writes the
resume store only once playback has attached at least once in that Player, so "Try again" after a failed
start no longer overwrites the recording's real saved position with 0; a failed retry, or Menu during the
retry, leaves the real place in the store, and a retry that lands still seeks to it. The load-bearing
`position = target` is byte-identical and nothing S6 touches is in the diff. **Run on Home Theater (run 2,
the record):** Resume on *History's Greatest Mysteries* S4 E14, saved "3 min in", landed at transport
clock 204 s; after Menu the Resume line and the Continue watching card still read "3 min in" —
`** TEST EXECUTE SUCCEEDED **`. **The failed-start path itself is traced** (§4): it needs a failure the
remote cannot produce, and none was forced.

**What this pass did not do.** It did not touch the bedroom Apple TV. It sent **no write of its own** to the
Marlin DVR server: my requests were two `GET /api/logs`; the app's own traffic in the runs was its launch
pings, its play sessions (one `POST` each; run 2's `DELETE` on Menu) and GETs (§5). Nothing was installed
on this Mac. marlin-dvr was not cloned or read. No diagnostic was added and no failure was forced.
`GuideScreen.swift`, `ScreenShell.swift`, `RailView.swift`, `PlayerHost.swift`, `design/`, `icon-source/`,
`REVIEW.md` and every existing report are unchanged.

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:84).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`4a7f927cd8a58088f0084aa416547083f3185b37`**. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — what was built

### 2.1 The defect, traced at HEAD

- After a **failed start** — the session `POST` refused, the first fetch failed, or the route refused —
  `fail()` detaches nothing (nothing was attached), `phase` is `.failed`, and **`position` is still 0**: before
  playback the only writer of `position` is `armResumeSeek`, which runs inside `attach` (`:203`, `:236`).
- "Try again" (`PlayerScreen.swift:447`, wired at `:67`) runs `restart()` with no argument, so `target` is
  that `position`, 0 (`:834`), and the teardown's `ResumeStore.save` wrote **0 over the recording's real
  saved position**. `ResumeStore.isResumable` (`ResumeStore.swift:77`) then dropped the Resume line and
  the Continue watching card.
- A retry that landed healed it: `armResumeSeek` falls back to `request.resumeSeconds` when `position` is 0
  (`:233`), the seek lands there, and `tick()` saves within 10 s. A retry that **failed**, or Menu during
  "Preparing the recording" (`stop()` saves only in `.playing`, `:892`), left the 0.
- Where Pass 119's report corrected REVIEW.md: the progress bar vanishes only when the `POST` itself failed
  (duration 0); after a later failure show detail draws an empty bar. The loss that matters is the position,
  and that is what is fixed.

### 2.2 The fix

- **`everAttached`** (`:87`): true from the first `attach` (`:213`), never cleared. `attachedAt` cannot serve,
  because `detachPlayer()` clears it — and `fail()` calls `detachPlayer()` — before `restart(at:)` reads
  anything, so it is nil in every restart-from-failure whether or not playback ever ran.
- **`restart(at:)`** (`:833`): the save runs only when `everAttached` (`:849`); otherwise it prints
  `[resume] restart with nothing ever attached — the saved position on <id> is kept, not overwritten with
  <target> s` (`:852`) and leaves the entry alone. Every other caller has attached and saves exactly as
  before: `playbackFailed` → `fail` after playback, `sessionExpired` (410), and `timeJumped`'s seek past the
  prepared range.
- **Untouched:** `position = target` (`:865`), the hand-off Pass 98 made load-bearing; `startAgain(at:)`;
  `armResumeSeek`; `frameStep`, `seekToResumePosition` and `cancelPendingSeeks` (S6); `stop()`; `saveResume()`.
- **Comments brought true:** `restart(at:)`'s doc (`:826-831`), which Pass 119 said would go stale, now says
  the save is conditional; `ResumeStore.isFinished`'s doc (`ResumeStore.swift:83-86`) no longer says
  `restart(at:)` "saves unconditionally".

### 2.3 The path after the fix, traced

Start fails → `.failed`, `position` 0, `everAttached` false → Try again → `restart()`: no save, the entry
is intact → `position = 0` → `startAgain` → **(a)** it fails again: `fail`, the entry is intact; Menu →
`stop()` in `.failed`, no save; **(b)** it lands: `attach` → `armResumeSeek` reads `position` 0, falls back to
`request.resumeSeconds` (the position show detail passed in), seeks there on `.readyToPlay`, `tick()` saves
it. **(c)** Menu during the retry's "Preparing the recording": `stop()` in `.starting`, no save, the entry
is intact.

---

## 3. Verify — the run on Home Theater

```
xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p125 build-for-testing
xcodebuild test-without-building -xctestrun build/p125/Build/Products/…xctestrun \
  -destination 'platform=tvOS,name=Home Theater' \
  -only-testing:"Marlin DVR TVUITests/ResumeRoundTripUITests"
```

`ResumeRoundTripUITests` (new), `launch()`, one method: Home → Recordings; read the Continue watching cards;
open the standing subject's card; read show detail's Resume line; press Resume; pause on Apple's transport
and read its clock; play on; Menu; read the Resume line; Menu; read the card. It is the regression Pass 119's
report says a healthy server can prove for S5, and nothing more.

### 3.1 Run 1 — failed on the harness, the app right

18:46:09–18:47:08, launch ping `18:46:16.742`. The harness read the cards — *History's Greatest Mysteries*
S4 E14 · 3 min in, *The Proof Is Out There* S6 E16 · 14 min in, *History's Greatest Mysteries* S7 E20 · 1 min
in — opened the first, read "Resume S4 E14 · 3 min in" with focus on it, pressed Select, and then failed its
own "the Player did not open" check. **The app had opened the Player and played** — the server's log:

```
18:46:33.523 TRS  session smuhjvmlu5f864b: serving the .mp4 beside History's Greatest Mysteries — 1.09 GB, no ffmpeg (Pass 101)
18:46:33.523 HTTP POST /api/play/sessions 200
18:46:34.652 HTTP GET /api/play/file/smuhjvmlu5f864b/video.mp4 206          (and 27 more chunk fetches to 18:46:55)
18:46:35.150 HTTP GET /api/library/recordings/5328bb632e76/commercials 200
18:47:10.525 TRS  session smuhjvmlu5f864b ended after 1m: watchdog: nothing fetched for 15s; 94.03 MB served
```

The check had two halves and both were wrong. It waited for "Preparing the recording", which a finished
recording no longer shows for long enough to be queried — since 1.9.1 the server serves the `.mp4` beside it
with no remux, and the session was created 0.4 s after the press. Its fallback, that show detail's own text
had gone, was wrong too: the text under the Player's cover stays in the accessibility tree (run 2's screen
read shows it beside the transport clock). The runner then killed the app without a `DELETE`, and the server's
own 15 s watchdog ended the session. **The harness change:** the transport clock read on the pause is now the
proof that the Player is up; no app-target line changed.

### 3.2 Run 2 — the record

**18:48:21–18:49:18, `** TEST EXECUTE SUCCEEDED **`, "Executed 1 test, with 0 failures", 52.3 s.** Its lines,
verbatim, the screen read trimmed to what matters:

```
[pass125 18:48:28.317] launched
[pass125 18:48:38.633] Continue watching cards: ["History's Greatest Mysteries, S4 E14 · 3 min in", "The Proof Is Out There, S6 E16 · 14 min in", "History's Greatest Mysteries, S7 E20 · 1 min in"]
[pass125 18:48:38.633] subject: “History's Greatest Mysteries, S4 E14 · 3 min in” — 3 min in before
[pass125 18:48:43.756] show detail before: “Resume S4 E14 · 3 min in” · focus=Resume S4 E14 · 3 min in
[pass125 18:48:44.278] Resume pressed
[pass125 18:49:01.979] paused: transport clock=204 s · text=[… "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY", "03:24", …]
[pass125 18:49:10.399] show detail after: “Resume S4 E14 · 3 min in” — 3 min in
[pass125 18:49:15.688] Continue watching cards after: ["History's Greatest Mysteries, S4 E14 · 3 min in", "The Proof Is Out There, S6 E16 · 14 min in", "History's Greatest Mysteries, S7 E20 · 1 min in"]
[pass125 18:49:15.966] RESULT resumed at 204 s; saved position 3 → 3 min in
```

Reading it: the saved position was inside the third minute; Resume landed at **204 s** (Apple's transport bar
read "03:24" on the pause, 17 s of playback after the press, so the seek landed at about 187 s — inside that
minute, not at 0); after Menu the Resume line and the card both still carried the position. Had Resume landed
at 0, the position saved on leaving would have read "n s in", and the harness asserts the minute.

**The launch ping and the server's view of run 2** (`GET /api/logs`, client id replaced):

```
18:48:27.336 POST /api/clients/<client id>/ping 200
18:48:27.336–.352  GET /api/channels, /api/cameras, /api/library, /api/guide/now, /api/radio, /api/schedule   (Home)
18:48:33.760–.860  GET /api/library, six GET /api/library/shows/…                                            (Recordings)
18:48:39.042 GET /api/library/shows/history-s-greatest-mysteries 200 · GET /api/passes 200                (show detail)
18:48:44.183 TRS  session smuhjyffa29f4e3: serving the .mp4 beside History's Greatest Mysteries — 1.09 GB, no ffmpeg
18:48:44.183 POST /api/play/sessions 200
18:48:44.211 GET /api/library/recordings/5328bb632e76/commercials 200
             24 × GET /api/play/file/smuhjyffa29f4e3/video.mp4 206
18:49:05.750 DELETE /api/play/sessions/smuhjyffa29f4e3 200                                                (Menu → stop())
18:49:05.750 TRS  session smuhjyffa29f4e3 ended after 0m: stop requested by D/S Apple TV; 82.30 MB served
```

Across 18:40–18:50 the log holds **five non-GET requests, all the app's own**: two launch pings, two session
`POST`s and run 2's `DELETE`. Nothing else.

**Screenshots** (run 2), in `reports/assets/pass125/`: `01-continue-watching-before.jpg`,
`02-show-detail-before.jpg` (the Resume line focused), `03-paused-after-resume.jpg` (Apple's transport bar
at 03:24), `04-show-detail-after.jpg`, `05-continue-watching-after.jpg`.

---

## 4. Run or traced

**Run on Home Theater (run 2):**
- Resume on a recording with a saved position lands on that position, not at 0 (the transport clock);
- the position survives leaving the Player with Menu — on show detail's Resume line and on the Continue
  watching card;
- the session's `DELETE` on Menu, and no refetch of the store's numbers from anywhere but the store.

**Code-traced only — the whole of S5's own path (§2.3):**
- "Try again" after a failed start, with the entry kept rather than written to 0;
- a retry that fails again; Menu during the retry; the retry that lands and seeks to the kept position;
- the `[resume] … is kept` line, which no run has ever printed;
- the `playNext` variant, and T1's hand-off (`position = target` → `armResumeSeek`), which stays traced as
  Pass 99 left it.

**Not forced:** the failure needs the server down or restarting (off limits), or the Apple TV's network pulled
(declined on 2026-09-16, Pass 99), or a diagnostic (the same). Pass 119's one write-free exception — a
recording still being written, which the server refuses with a 502 at `POST` — was not available: the
library's recordings were all finished at run time, and such a recording would have proved only the skip, with
no prior entry to keep.

---

## 5. The server reads this pass made

Two `GET http://192.168.1.250:8090/api/logs` with `curl`, after run 1 and after run 2. `GET /api/settings`
was not read. Everything else was the app's own traffic in the runs (§3).

**The saved position on `5328bb632e76`** read "3 min in" before run 1 and after run 2; the two runs played
about twenty seconds of it each and the harness's reading is in minutes, so the exact seconds are not known
here. No entry was cleared — the recording was never played to its end — and nothing was deleted, trashed,
kept, scheduled or marked watched.

---

## 6. Records this pass changes, recorded forward and not edited

- DECISIONS.md, 2026-09-16 (Pass 98): *"**Nothing else in the teardown changed**: the same detach, the same
  DELETE, the same `ResumeStore.save`, in the same order."* — the save is conditional now; the record stays
  true as Pass 98's history.
- `reports/2026-09-16-pass91-continue-watching.md:161`: *"On `restart(at:)` — **unconditionally**, which is why
  the shelf keeps its own end-of-file test"* — the shelf's test is still needed, for an attached restart at
  the end.
- `PlayerModel.swift`'s own comments at `:826-831` and `ResumeStore.swift:83-86`, brought true in place.
- **COLD-START.md's Player line and its closed-section T1 entry are brought to the current state in place**
  (step 3); *Next step* likewise, with Pass 124's paragraph kept beneath it, labelled.

Checked and not changed: the owner's closure of T1 (Pass 99) — the hand-off is untouched and still traced;
Pass 96's resume-by-seeking — `armResumeSeek` and `seekToResumePosition` are byte-identical.

---

## Open questions

1. **`armResumeSeek` still reads its target out of `position`** (Pass 98's open question, closed with
   everything else on 2026-09-20). S5 leaves that as it is; making the target explicit would have been a
   change beyond what S5 needs.
2. **The `[resume] … is kept` line has never been printed on a device**, and cannot be without a failure.
   If the owner ever sees "Try again" after a failed start, the console line is the one thing that would
   say the fix ran.

## What I am least sure of

1. **That "playback attached at least once in this Player" is the right condition in every case**, rather
   than "the target is a real place". They differ only for a Player that attached, failed within its first
   ten seconds before any tick, and is retried — where the save writes the resume target `armResumeSeek` set
   in `position`, which is the saved position itself. I traced that and believe it is right; I did not run it.
2. **The harness's reading of where Resume landed is Apple's transport clock 17 s after the press**, not
   the app's own `[resume] asked … landed …` line, which needs a console. 204 s is inside the saved minute
   and far from 0, which is what the claim needs; the seek's exactness rests on Pass 96's measurement.
3. **The failed-start path is traced, twice removed:** the fix is in a function no device run has ever
   entered (Pass 98, Pass 99), and the branch it adds is one no run can reach without a failure the owner
   has declined to force.

## How the owner can see it on Home Theater

On a healthy server, what can be seen is the regression: open Recordings, pick a Continue watching card,
press Resume — it lands where he left it — press Menu, and the Resume line and the card are still there
with the position moved on by what he watched. **S5's own case shows only when a start fails** — the server
down or restarting — and then "Try again" keeps his place: the Resume line and the card stay, where before
this pass they vanished and the place was lost.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/PlayerModel.swift` | 2 | `everAttached`, set in `attach`; the conditional save and its print in `restart(at:)`; two doc comments; +23 / −3 |
| `Marlin DVR TV/ResumeStore.swift` | 2 | one doc comment on `isFinished`; +3 / −2 |
| `Marlin DVR TVUITests/ResumeRoundTripUITests.swift` | Verify | new — the run's harness, `launch()`, one method, which the pass allows |
| `DECISIONS.md` | 3 | the Pass 125 entry: the bedroom install after Pass 124, then S5 |
| `COLD-START.md` | 3 | the Player line; the closed-section T1 entry; *Next step*, with Pass 124's paragraph kept beneath it, labelled |
| `reports/2026-09-25-pass125-s5-try-again-keeps-the-position.md` | 3 | new — this report |
| `reports/assets/pass125/` (5 `.jpg`, 1.6 MB) | 3 | new — run 2's screenshots, exported from its result bundle |

**Nothing else was changed.** `GuideScreen.swift`, `ScreenShell.swift`, `RailView.swift`, `PlayerHost.swift`,
`project.pbxproj` and every other app and test file are byte-identical; the UI-test target is a synchronised
folder, so the harness needed no project edit. Scratch — the two test logs, the two log reads and the exported
attachments — is in the session scratchpad, outside the repo. `build/p125` is the DerivedData of the runs;
`build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, one ahead of `origin/main` (`4a7f927`). Nothing was pushed: the owner
tests on Home Theater first.
