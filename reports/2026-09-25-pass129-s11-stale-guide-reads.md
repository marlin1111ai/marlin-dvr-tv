# Pass 129 — S11: a Guide read that lands late never fills the grid

**Date:** 2026-09-25 (19:42–21:20 EDT)
**Built on:** `7eb4915120ed4ae2a7112038a5a54051c7b62bdd` (Pass 128). **One commit, not pushed** — the owner
tests on Home Theater first.

**Result.** S11 is built as Pass 119's report describes it, in the one file it names as certain:
`GuideScreen.swift` (+59 / −1), all inside `GuideModel`'s `fetch`. Every read is numbered; an answer that
lands is kept only if it is not older than the one on screen, was asked for the collection now showing and
covers the window now showing; otherwise it is discarded and said so, and — for a server notice's answer,
or whenever the rows on screen no longer fit the screen — read again at the window and collection showing.
Pass 116's redraw is as accepted: every notice still causes a re-read, one that arrives during a re-read
still causes one more after it, and no notice is coalesced away. **The discard was driven on Home Theater**
under a disclosed, reverted 4 s read delay: +12h, +12h, Menu one second later —
`[guide] read 3 discarded — covers Sat Sep 26 7:30 PM – Sun Sep 27 7:30 PM, the window is Fri Sep 25 ·
7:30 – 9:30 PM` — and the grid was filled at now, twice in two drives. **The run of record** (run 4,
`launch()`, ping `20:47:07.292`): +12h twice then Menu and then ↩ Now, each a filled grid at now; a held
Right of four slots, one Left back-step and a held Left to now; Local picked while ahead redrawing in place
and All Channels put back — `** TEST EXECUTE SUCCEEDED **`. Passes 122's and 123's code is untouched.

**Found beside S11, not built.** A Menu inside a collection pick's read reaches the shell and the app goes
Home: `pick()` puts focus back in the grid only after its read lands, and focus sits in the rail until
then. Measured twice under the delay; open question 1. And **the server restarted as marlin-dvr 1.11.6 at
20:40:50**, in the middle of run 3, which rode through it on Pass 116's reconnect; open question 3.

**What this pass did not do.** It did not touch the bedroom Apple TV. It sent **no write of any kind** to the
Marlin DVR server: my requests were three `GET /api/logs`; the app's own traffic was its launch pings and
GETs (§5). Nothing was installed on this Mac. marlin-dvr was not cloned or read. The owner's Guide pick was
left as found, All Channels. `ScreenShell.swift`, `RailView.swift`, `PlayerModel.swift`, `PlayerHost.swift`,
`design/`, `icon-source/`, `REVIEW.md` and every existing report are unchanged.

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:84).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`7eb4915120ed4ae2a7112038a5a54051c7b62bdd`**. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — what was built

### 2.1 The defect, traced at HEAD

- `fetch` stored `rows`, `fetchStart` and `fetchEnd` after its await with no check of what the screen
  showed by then.
- REVIEW.md's case: +12h (no request — the range on screen covers 12 h ahead), +12h again (a read for
  24 h ahead starts), Menu before it lands: `snapToNow` makes no request either, because the range on
  screen still covers now; the late answer is then stored over it, `cells(for:)` finds nothing for a
  window at now in rows read for a day later, and `isAtNow` hides ↩ Now — a blank grid with nothing to
  explain it, until the next roll, notice, pick or move.
- Where Pass 119's report corrected REVIEW.md: three more things repair it, and the fix REVIEW.md wrote is
  incomplete — a counter alone misses its own example (`snapToNow` starts no read), and a plain discard by
  window and filter loses a notice whose answer lands after Menu.

### 2.2 The fix — `fetch` and three lines of state

- **`fetchSerial`, `storedSerial`, `storedFilter`** (`:135-137`): a number per read, and the number and
  collection of the answer whose rows are on screen.
- **`staleReason`** (`:290`): nil when the answer belongs on screen at the moment it lands; otherwise one
  of three reasons — older than the stored answer; asked for a collection no longer showing; or not
  covering the window showing (its own range, `start … start + slots × 30 min`, against `windowStart …
  windowEnd`).
- **`fetch`** (`:304`): after the await, a stale answer is discarded before the favourites clear
  (`serverWins`), `loaded` is still set, and the discard is printed with its reason; then **the read is made
  again at the window and collection showing when the discarded answer was a notice's, or whenever
  `storedAnswerFitsTheScreen`** (`:284`) **is false** — the stored rows' collection is not the one showing,
  or their range does not cover the window. The second condition is what a collection picked while ahead
  and then Menu needs: the discarded answer was the pick's, and the rows still on screen are the old
  collection's. A kept answer stores its number and collection with its range (`:339-340`).
- **Pass 116's guarantees, checked:** `serverRedraw`'s owed loop is untouched, so a notice during a re-read
  still causes one more after it; a discarded notice answer is read again, never dropped; and a notice
  answer dropped as older than a stored one lost nothing, because the later read was sent after the change
  the notice announced. Pass 119 (d)'s three records hold as written.
- **Untouched:** `loadNow`, `pageForward`, `nudgeForward`, `nudgeBack`, `tick`, `snapToNow`,
  `reloadForCollection`, `reloadForNotice`, `serverRedraw`; Pass 122's `backStepCatcher`, Pass 123's
  `forwardStepCatcher`, `RingHoldWatch` and the footer; `GuideCollections.swift`.

### 2.3 The disclosed diagnostic, and its removal

To land a press inside a read — which XCUIRemote cannot do against a LAN server answering in tens of
milliseconds — a delay was added on top of the fix, gated on an environment variable the `devicectl`
launch passed, and removed before the clean build:

```diff
             async let schedule = api.schedule()
+            // [probe] Pass 129 DIAGNOSTIC ONLY — reverted before the commit.
+            if let text = ProcessInfo.processInfo.environment["MARLIN_PROBE_FETCH_DELAY"], let delay = Double(text) {
+                print("[probe] read \(serial) for \(TimeFormat.clock(unix: start)) · \(filter ?? "All Channels") held for \(delay) s")
+                try? await Task.sleep(for: .seconds(delay))
+            }
             let g = try await guide
```

Removed by a scripted edit of exactly those lines; `grep -rn 'Pass 129 DIAGNOSTIC\|MARLIN_PROBE\|\[probe\]'`
over the app target then found nothing, and the app-target diff against HEAD was the fix alone (+59 / −1,
§7). The clean build's warnings are the two pre-existing ones, `GuideScreen.swift:1084` and
`PlayerModel.swift:373`.

---

## 3. Verify — the discard drives, with the console attached

`GuideStaleReadUITests` (new), two methods. The second, `testAReadThatLandsLateIsDiscarded`, drove the
diagnostic build launched by `devicectl … --console -e '{"MARLIN_PROBE_FETCH_DELAY":"4"}'` — neither
`launch()` nor `activate()` — so the app's own lines could be read beside the harness's.

### 3.1 Drive 1 (19:48–19:53): the discard

Resume of the sequence, the app's lines with the Mac's clock:

```
19:50:02.678 [probe] read 3 for 7:30 PM · All Channels held for 4.0 s        ← the second +12h's read, for Sat 7:30 PM
19:50:03.973 [guide] menu: sheet=false channelMenu=false collections=false atNow=false   ← Menu, 1.3 s later; snapToNow, no request
19:50:06.693 [guide] read 3 discarded — covers 7:30 PM–7:30 PM, the window is Fri Sep 25 · 7:30 – 9:30 PM
```

and the harness's reading after it: `window="Fri Sep 25 · 7:30 – 9:30 PM" strip="7:30 PM · now"
nowPill=false cells=12` — the grid filled at now. (The print's "7:30 PM–7:30 PM" is the answer's range
with its days left out; the print gained them before drive 2.) The drive then tried Pass 119's second case
and found the finding in §3.3.

### 3.2 Drive 2 (19:54–19:56): the same, the print with the day

```
19:55:19.287 [probe] read 3 for 7:30 PM · col-… held for 4.0 s
19:55:20.582 [guide] menu: sheet=false channelMenu=false collections=false atNow=false
19:55:23.581 [guide] read 3 discarded — covers Sat Sep 26 7:30 PM – Sun Sep 27 7:30 PM, the window is Fri Sep 25 · 7:30 – 9:30 PM
```

harness: `window="Fri Sep 25 · 7:30 – 9:30 PM" strip="7:30 PM · now" nowPill=false cells=12` —
screenshot `stale-01-menu-inside-the-read.jpg`. (This drive opened on Local, the pick drive 1 had left; the
discard is the same on either collection.)

### 3.3 The finding: a Menu inside a pick's read goes Home

Both drives then pressed +12h, picked Local and pressed Menu inside the pick's 4 s read:

```
19:55:44.410 [rail] entered on home, restoring to guide      ← the moment of the pick's Select
19:55:44.427 [probe] read 4 for 7:30 AM · col-… held for 4.0 s
19:55:46.713 [guide] stopped listening to the server         ← the Menu, 2.3 s later: the Guide is gone
19:55:48.429 [guide] collection Local rows=11 refocus=…      ← the pick's read lands on a screen already left
```

No `[guide] menu:` line: the Guide's own `.onExitCommand` never saw the press. When the overlay closes,
the focus engine puts focus in the rail (`railRestore` moves it to the Guide entry), and `pick()`'s
`focusSoon { focused = firstCellID }` runs only **after** `reloadForCollection()` returns — on a healthy
server tens of milliseconds, under the delay four seconds. A Menu in that gap is `ScreenShell`'s, which
leaves for Home. So Pass 119's "pick while ahead, then Menu before the pick's read lands" cannot be driven
on this build — the discard it would exercise stays traced (§4) — and the behaviour is open question 1.
Neither drive's harness assertions on that stage count for anything; the app went Home.

---

## 4. Verify — the run of record on Home Theater

```
xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p129 build-for-testing
xcodebuild test-without-building -xctestrun build/p129/Build/Products/…xctestrun \
  -destination 'platform=tvOS,name=Home Theater' \
  -only-testing:"Marlin DVR TVUITests/GuideStaleReadUITests/testWindowAndCollectionMovesStillFillTheGrid"
```

The clean build, `launch()`. **Four runs; the fourth is the record.**

| Run | Time | Result | Why |
|---|---|---|---|
| 1 | 19:57–20:10 | failed on the harness | every stage right to the pick; the harness capped Local at 8 rows and the owner's Local holds 11 now |
| 2 | 20:11–20:25 | failed on the harness | every stage right to the pick; the harness held WBFF45 to be a non-member (Pass 77) and it is one now |
| 3 | 20:26–20:45 | passed | its launch ping had left the server's log: **the server restarted as 1.11.6 at 20:40:50**, its log began again there, and run 3 rode through it on Pass 116's reconnect re-read (`20:40:54`) |
| **4** | **20:47:02–21:07:13** | **passed — the record** | §4.1 |

Runs 1 and 2 ended on Local; each later run chose All Channels first, and run 4 left it there.

### 4.1 Run 4 — `** TEST EXECUTE SUCCEEDED **`, 1 test, 0 failures, 1207 s

```
[pass129 20:47:08.238] launched
[pass129 20:48:16.077] OPEN window=“Fri Sep 25 · 8:30 – 10:30 PM” startMin=394350 strip=“8:30 PM · now” nowPill=false collection=“All Channels” cells=12 zone=grid:programme-cell focus=9:“R.J. Decker” (554,228 315x82) clockHalfHour=394350
[pass129 20:50:11.826] pressed +12h · window=“Sat Sep 26 · 8:30 – 10:30 AM”
[pass129 20:50:49.346] pressed +12h · window=“Sat Sep 26 · 8:30 – 10:30 PM”
[pass129 20:51:30.058] PLUS 24H window=“Sat Sep 26 · 8:30 – 10:30 PM” startMin=395790 strip=“8:30 PM” nowPill=true collection=“All Channels” cells=12 …
[pass129 20:53:07.569] MENU window=“Fri Sep 25 · 8:30 – 10:30 PM” startMin=394350 strip=“8:30 PM · now” nowPill=false collection=“All Channels” cells=12 …
[pass129 20:54:29.993] pressed +12h · window=“Sat Sep 26 · 8:30 – 10:30 AM”
[pass129 20:55:08.714] pressed +12h · window=“Sat Sep 26 · 8:30 – 10:30 PM”
[pass129 20:55:38.555] pressed ↩ Now · window=“Fri Sep 25 · 8:30 – 10:30 PM”
[pass129 20:56:38.595] NOW PILL window=“Fri Sep 25 · 8:30 – 10:30 PM” startMin=394350 strip=“8:30 PM · now” nowPill=false collection=“All Channels” cells=12 …
[pass129 20:58:34.474] HELD RIGHT 3 s -> 4 slot(s) window=“Fri Sep 25 · 10:30 PM → Sat Sep 26 · 12:30 AM” startMin=394470 strip=“10:30 PM” nowPill=true … cells=12 zone=grid:programme-cell focus=9:“Jimmy Kimmel Live!” (1256,228 583x82)
[pass129 21:00:43.471] ONE LEFT CLICK ON THE CHANNEL CELL window=“Fri Sep 25 · 10:00 PM – 12:00 AM” startMin=394440 strip=“10:00 PM” nowPill=true … zone=grid:channel-cell focus=9:“WMAR-HD, 2.1” (236,228 300x82)
[pass129 21:01:48.372] HELD LEFT window=“Fri Sep 25 · 9:00 – 11:00 PM” startMin=394380 strip=“9:00 PM · now” nowPill=false … cells=12 zone=grid:channel-cell focus=9:“WMAR-HD, 2.1” (236,228 300x82) clockHalfHour=394380
[pass129 21:03:05.197] pressed +12h · window=“Sat Sep 26 · 9:00 – 11:00 AM”
[pass129 21:03:33.485] chose “Local” · button now “Local”
[pass129 21:03:36.115] LOCAL WHILE AHEAD window=“Sat Sep 26 · 9:00 – 11:00 AM” startMin=395100 strip=“9:00 AM” nowPill=true collection=“Local” cells=12 … channelCells=11
[pass129 21:03:53.974] chose “All Channels” · button now “All Channels”
[pass129 21:05:03.714] ALL CHANNELS BACK window=“Sat Sep 26 · 9:00 – 11:00 AM” startMin=395100 strip=“9:00 AM” nowPill=true collection=“All Channels” cells=12 … channelCells=13
[pass129 21:06:30.324] MENU AT THE END window=“Fri Sep 25 · 9:00 – 11:00 PM” startMin=394380 strip=“9:00 PM · now” nowPill=false collection=“All Channels” cells=12 …
[pass129 21:07:12.057] RESULT +12h twice → Menu and → ↩ Now filled at now; hold Right 4 slots, one back-step, held Left to now; Local while ahead in place; All Channels back
```

Reading it: the clock crossed 9:00 PM during the run and the harness reads the current half hour each
time. Every window move showed the right window and a drawn grid (`cells=12` is the harness's sampling
cap); the pick while ahead left the window at Sat 9:00 AM with ↩ Now up and drew eleven channel rows
against thirteen-plus on All Channels; the held Right, the back-step and the held Left are as Passes 122
and 123 left them.

**The launch ping and the server's view of the run** (`GET /api/logs`, read at 21:07:13, client id
replaced; art, thumbnail and schedule reads left out):

```
20:47:07.292 POST /api/clients/<client id>/ping 200      ← Home Theater's, the only non-GET request 20:46–21:12
20:47:12.740 GET /api/guide 200                          (the Guide opens — loadNow)
20:47:17.502 GET /api/collections 200 · 20:47:17.519 GET /api/guide 200     (Pass 116's first connect re-read)
20:50:44.463 GET /api/guide 200                          (the second +12h — the first made no request)
20:52:04.070 GET /api/guide 200                          (Menu: the stored range was a day ahead, so a read)
20:55:03.845 GET /api/guide 200                          (the second +12h again)
20:55:33.555 GET /api/guide 200                          (↩ Now)
21:03:17.010 GET /api/collections 200 · 21:03:27.371 GET /api/guide 200     (the overlay, then the Local pick)
21:03:42.052 GET /api/collections 200 · 21:03:47.784 GET /api/guide 200     (the overlay, then All Channels)
21:05:33.474 GET /api/guide 200                          (Menu at the end)
21:07:12.437 GET /api/events 200                         (the stream closing as the run ended)
```

The held Right, the back-step and the held Left made no read — inside the fetched range — and no read of
S11's own appears: a healthy server answers inside one round trip, so nothing was stale.

**Screenshots** (run 4), in `reports/assets/pass129/`: `01-open-at-now.jpg`, `02-plus-24h.jpg`,
`03-menu-back-at-now.jpg`, `04-now-pill-back-at-now.jpg`, `05-back-step.jpg`, `06-held-left-at-now.jpg`,
`07-local-while-ahead.jpg`, `08-all-channels-back.jpg`; and from drive 2, `stale-01-menu-inside-the-read.jpg`.

---

## 5. Run or traced

**Run on Home Theater:**
- **the discard itself** — a +12h read landing after Menu, discarded with its reason printed and the grid
  filled at now: twice, under the 4 s delay, on the fix's code (drives 1 and 2);
- +12h twice then Menu, and +12h twice then ↩ Now, each the right window and a filled grid at now (run 4);
- a collection pick while ahead redrawing in place — the window unmoved, Local's rows — and All Channels
  put back the same way (run 4);
- Pass 122's Left back-step and Pass 123's held ring, forward and back to now (run 4);
- Pass 116's connect re-read on every Guide open, and **its reconnect re-read on a real server restart**
  (run 3, `20:40:54`, four seconds after `marlin-dvr 1.11.6 started`).

**Code-traced only:**
- the discard of a **notice's** answer and the re-read that follows it — needs a server write, off limits
  since the owner's four of Pass 116;
- the discard of a **pick's** answer landing after Menu, and the re-read `storedAnswerFitsTheScreen` then
  causes — cannot be driven while focus sits in the rail during the read (§3.3);
- an answer dropped as older than a stored one; overlapping nudge reads across the 45-slot refetch; a pick
  before the first load; Menu during a notice's re-read.

---

## 6. The server reads this pass made

Three `GET http://192.168.1.250:8090/api/logs` with `curl`, after drive 1, after run 3 and after run 4.
`GET /api/settings` was not read. Everything else was the app's own traffic: one launch ping per
`launch()` and per `devicectl` launch — six in all, the two drives and the four record runs — and GETs. **The server restarted at 20:40:50 as marlin-dvr 1.11.6** (its
log's first line), not by anything this pass did; its log began again there, which is why run 3's ping
could not be shown and run 4 was made.

---

## 7. The revert, checked before the commit

```
$ grep -rn 'Pass 129 DIAGNOSTIC\|MARLIN_PROBE\|\[probe\]' "Marlin DVR TV"
(none)
$ git diff HEAD --numstat -- "Marlin DVR TV"
59	1	Marlin DVR TV/GuideScreen.swift
$ git diff HEAD -- "Marlin DVR TV/GuideScreen.swift" | grep -n '^[-+].*backStep\|^[-+].*forwardStep\|^[-+].*RingHold\|^[-+].*leftRing\|^[-+].*Menu snaps back'
(none)
```

---

## 8. Records this pass changes, recorded forward and not edited

- None of Pass 116's. DECISIONS.md's *"no notice is coalesced away"* and COLD-START's *"every notice re-reads
  at the window and collection showing"* hold as written, checked as Pass 119 (d) asked. Pass 72's *"No
  generation counter was added to the Guide"* holds: `fetchSerial` numbers reads, not focus rebuilds.
- **COLD-START.md's Guide line and *Next step* are brought to the current state in place** (step 3), with
  Pass 128's paragraph kept beneath it, labelled. Its server line still says 1.11.1 (open question 3).

---

## Open questions

1. **A Menu inside a collection pick's read goes Home** (§3.3). `pick()` refocuses the grid only after its
   read lands; until then focus sits in the rail, where Menu is the shell's. On a LAN server the gap is tens
   of milliseconds; on a slow read it is the whole read. Refocus before the read, or leave it?
2. **The pick-then-Menu discard is traced, not run**, for that reason; and the notice's discard needs a
   server write. Both branches are the same three lines as the +12h discard that was run.
3. **The server is marlin-dvr 1.11.6 since 20:40:50 on 2026-09-25**, read from its log; `COLD-START.md`'s
   server line says 1.11.1 and this pass was not named for it. What 1.11.2–1.11.6 changed was not read.
4. **The Guide's log buffer is short for a 202-row Guide**: each open fetches about two hundred channel logos
   through `/api/art/feed`, so the server's 2000-line log holds well under an hour, and a launch ping can
   be gone before a long run ends. Not this app's to change; recorded for the next harness.

## What I am least sure of

1. **That the re-read condition is complete.** A notice's answer always re-reads; any other discard re-reads
   only when the stored rows no longer fit the screen. The argument that every other case is already
   covered — whoever moved the window or the collection either found the stored range covering it or
   started a read of its own, and the newest read is kept — is a trace over the seven window writers, not
   a run.
2. **That the +12h discard stands for the pick's and the notice's.** The three share `staleReason` and the
   same discard lines; only the reason and the re-read differ, and neither of the other two was driven.
3. **The pick's focus gap** was measured under an artificial 4 s read. On the owner's server a pick's read
   returns in about 50 ms, so I have not seen a real Menu land in it; whether he ever will is a guess.

## How the owner can check it on Home Theater, including Pass 116's live redraw

Open the Guide. **Press +12h twice, then Menu**: the Guide is back at now with its listings, ↩ Now gone.
**Press +12h twice, then ↩ Now**: the same. **Press +12h once, then pick a collection**: the collection's
rows appear with the window still ahead; pick All Channels again and it is still ahead. **Hold Right on
the ring**, click Left on a channel's logo cell, **hold Left**: as before — forward, one step back, and back
to now stopping on the channel. **Pass 116's live redraw**: with the Guide open, change a channel's name or
a collection's members on the server's admin page; the Guide redraws within a second without being left,
the window and the highlight where they were. S11's own case shows only when a read is slow: Menu, ↩ Now
or a pick inside one, and then the grid stays filled instead of going blank.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | 2 (measure) | the `[probe]` delay — **added on top of the fix, driven twice, and removed by a scripted edit of its lines**; not in the commit; its diff is §2.3 |
| `Marlin DVR TV/GuideScreen.swift` | 2 | `fetchSerial`, `storedSerial`, `storedFilter`, `storedAnswerFitsTheScreen`, `staleReason`, the discard and re-read in `fetch`, a header paragraph; +59 / −1 |
| `Marlin DVR TVUITests/GuideStaleReadUITests.swift` | Verify | new — the run's harness, `launch()`, two methods (the record, and the discard drive against the console-launched diagnostic), which the pass allows |
| `DECISIONS.md` | 3 | the Pass 129 entry: the bedroom install after Pass 128, then S11 |
| `COLD-START.md` | 3 | the Guide line; *Next step*, with Pass 128's paragraph kept beneath it, labelled |
| `reports/2026-09-25-pass129-s11-stale-guide-reads.md` | 3 | new — this report |
| `reports/assets/pass129/` (9 `.jpg`) | 3 | new — run 4's screenshots and drive 2's discard stage, exported from their result bundles |

**Nothing else was changed.** `ScreenShell.swift`, `RailView.swift`, `PlayerModel.swift`, `PlayerHost.swift`,
`GuideCollections.swift`, `project.pbxproj` and every other app and test file are byte-identical; the UI-test
target is a synchronised folder, so the harness needed no project edit. Scratch — the two consoles, the
diagnostic's diff, the six test logs, the three log reads and the exported attachments — is in the session
scratchpad, outside the repo. `build/p129probe` and `build/p129` are the DerivedData of the diagnostic and
the clean runs; `build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, one ahead of `origin/main` (`7eb4915`). Nothing was pushed: the owner
tests on Home Theater first.
