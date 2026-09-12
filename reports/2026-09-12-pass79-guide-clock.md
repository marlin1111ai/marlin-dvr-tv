# Pass 79 — the Guide keeps up with the clock

**Date:** 2026-09-12
**Base commit:** `fda3992` (Pass 78, the scroll-right accepted and pushed).
**Result: built, run against a real half-hour boundary on Home Theater, committed locally and NOT
pushed — the owner tests it first.**

The owner's defect of 2026-09-12: left open, the Guide did not move with the time — the window, the
"· now" column and the Now marker stayed where they were when the screen opened. A beat once a
minute now republishes the screen's clock, and a window sitting at now advances to the new current
half hour at each half-hour boundary. A window scrolled ahead is never moved.

**The app-target diff is `GuideScreen.swift` alone: 115 insertions, 6 deletions.** No other app file,
no project file, no `Info.plist`, no entitlements, no asset, no new dependency and **no new file of
any kind**. **Build warnings are unchanged from HEAD's two**, measured by a clean build of each tree
rather than asserted (§6).

**This pass was interrupted by the owner partway through and resumed under a shorter brief.** §5
says exactly what the interrupted run had done, what was killed, and what was discarded.

**Server traffic.** The app's own `GET /api/guide` and `GET /api/schedule`, plus its standing
`POST /api/clients/{id}/ping` on each launch (`ClientSession.swift:62-81`) — the only non-GET
request, and the app's own behaviour rather than this pass's. **No request of any kind was made by
hand this pass.** `~/Xcode/marlin-dvr-reference` and `design/` were not opened.

**Redaction.** The device console carries the app's launch-ping line, which prints this Apple TV's
client id and LAN address. It is reproduced nowhere below; every console block is filtered to
`[guide]` and `[rail]` lines. No credential, token, device id or client id appears in this report.

---

## 1. The cause, with file:line — and it is two things, not one

All `HEAD` line numbers below are `Marlin DVR TV/GuideScreen.swift` at `fda3992`, read from a
`git archive HEAD` copy rather than from memory.

### 1.1 Nothing ticked the Guide. Nothing at all.

`GuideModel.windowStart` (HEAD `:90`) is the one number the whole screen is derived from, and at
`HEAD` it had exactly four writers — **every one of them a user action or the screen opening**:

| Writer | HEAD line | Driven by |
|---|---|---|
| `loadNow()` | `:108` | the screen's `.task`, once, on open |
| `pageForward()` | `:114` | the `+12h` pill |
| `nudgeForward()` | `:143` | Pass 77's Right press at a row's edge |
| `snapToNow()` | `:156` | the `↩ Now` pill, and Menu |

**There was no timer, no `.task` loop, no scene-phase handler and no notification observer anywhere
in `GuideScreen.swift`.** Its only two `Task.sleep`s were one-shots — the 60 ms after the airing
sheet closes (`:409`) and Pass 77's 150 ms focus settle (`:469`) — and `grep` over the file for
`Timer`, `scenePhase` and `NotificationCenter` returns nothing. So **`windowStart` was set once, on
open, from `TimeFormat.currentHalfHour` (`:108` → `Formatting.swift:65`), and never again.**

For contrast, these are the app's periodic loops, and the Guide is not among them: On Now 60 s
(`OnNowScreen.swift:170-177`), Cameras 45 s (`CamerasScreen.swift:98-105`), the radar's frame loop
and 5-minute refresh (`RadarScreen.swift:95-113`), the player's keep-alive and 1 s observer
(`PlayerModel.swift:600`, `:650`) and the airing sheet's 20 s clock (`AiringSheet.swift:173-179`).

### 1.2 Even a clock that did move would have redrawn nothing

This is the half that is easy to miss, and it had to be fixed too. At `HEAD`:

```swift
var isAtNow: Bool { windowStart == TimeFormat.currentHalfHour }                  // :99
PillLabel(text: "↩ Now · \(TimeFormat.clock(Date()))", active: true, …)          // :566
```

`TimeFormat.currentHalfHour` reads `Date()` (`Formatting.swift:65`), and so does the pill.
**A `Date()` read inside a view body is observed by nothing** — `GuideModel` is `@Observable`, so
SwiftUI tracks the model properties a body reads and redraws when they change, and the wall clock is
not one of them. Everything the screen says about "now" therefore could not react to the passage of
time at all, only to some other change on the model:

- the strip's `· now` suffix, `slotLabel` HEAD `:619` (`index == 0 && model.isAtNow`)
- the footer sentence, HEAD `:634`
- whether `↩ Now` is drawn, HEAD `:559` — and its clock, HEAD `:566`
- whether `+12h` is drawn, HEAD `:571`

**That is why the Now marker froze at the time the screen opened**, which is precisely what the
owner reported.

### 1.3 The app already had the answer, one screen over

`AiringSheet.swift:62` holds `@State private var now = Date()`, and `:173-179` is a `.task` loop
that republishes it every 20 seconds:

```swift
.task {
    // Keeps "Watch live" honest if the sheet is left open across the start time.
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(20))
        now = Date()
    }
}
```

The sheet knew it had to hold its own clock. The Guide never got one. Pass 79's `GuideModel.now` is
the same idea, owned by the model rather than the view because `isAtNow` is the model's.

---

## 2. The fix

All line numbers in this section are the **committed** `Marlin DVR TV/GuideScreen.swift`.

### 2.1 An observed clock, and one half hour derived from it

```swift
private(set) var now = Date()                                              // :112
var nowHalfHour: Int { Int(now.timeIntervalSince1970 / 1800) * 1800 }      // :118
var isAtNow: Bool { windowStart == nowHalfHour }                           // :120
```

`loadNow()` (`:127`) and `snapToNow()` (`:201`) republish `now` at the instant they read it, so no
action can leave the observed clock behind the wall clock, and the two can never straddle a boundary
between two separate `Date()` reads. The `↩ Now` pill reads `TimeFormat.clock(model.now)` (`:675`).

### 2.2 The beat

```swift
@discardableResult
func tick() async -> Bool {                                                // :187
    now = Date()
    guard windowStart < nowHalfHour else { return false }
    windowStart = nowHalfHour
    if windowStart < fetchStart || windowEnd > fetchEnd { await fetch(from: windowStart) }
    return true
}
```

Four things about those five lines:

- **It always republishes the clock**, whether or not it rolls. That is what makes the pill, the
  footer, the strip's `· now` and both header pills tell the truth as the clock passes.
- **`windowStart < nowHalfHour` is an exact test, not an approximation.** `windowStart` is only ever
  set to the current half hour or advanced past it, so being *behind* the clock can only mean the
  window was at now and the clock moved on. **A window scrolled ahead by a nudge or by `+12h` is
  therefore never moved**, and neither is one the clock has merely caught up with — that one simply
  becomes `isAtNow` again.
- **The roll is one write to `windowStart`.** The strip (`slotStarts`, `:106`), every row
  (`cells(for:)`, `:237`), the header's date range (`windowLabel`, `:285`), the `· now` marker
  (`:728`), the footer (`:743`) and both pills (`:666`, `:680`) are all derived from that one number
  and from nothing else. This is the property Pass 77 built the scroll-right on, unchanged.
- **The refetch is the existing rule** — the same line `snapToNow()` and `nudgeForward()` use — so a
  beat inside the fetched 24 hours makes **no request at all**.

### 2.3 Where the beat lives, and why it cannot become an orphan

```swift
.task {                                                                    // :437
    await model.loadNow()
    focusSoon { focused = firstCellID ?? "collections" }
    var beats = 0
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.secondsToNextMinute()))
        guard !Task.isCancelled else { break }
        beats += 1
        await beat()
    }
    print("[guide] clock stopped after \(beats) beat(s)")                  // :452
}
```

It is a `.task` on the Guide and nothing else, which is what ties it to **the screen's** lifetime
rather than the app's: `ScreenShell.swift:57` puts `.id(current)` on the content and destroys the
Guide on every rail visit, and SwiftUI cancels a destroyed view's `.task`. The count printed on exit
is what turns that from an argument into a reading (§4.2). **No `Timer`, no `NotificationCenter`, no
scene-phase observer and no state above the shell was added.**

`secondsToNextMinute()` (`:570`) aligns the beat to the wall clock's next whole minute instead of
spacing it a fixed 60 s apart, so a roll lands within a moment of the half hour it belongs to and
the pill's clock changes on the minute it names.

### 2.4 Focus, and the overlay guard

`beat()` (`:582`) does nothing at all while the airing sheet, the channel menu or the collections
drop-down is up — the guard `gridMoved` already takes, for the same reason: each of them owns the
remote and disables the grid, and a roll underneath one would move the grid and could leave the
sheet's Menu restoring focus (`lastCell`) to a cell that no longer exists.

`settleFocusAfterRoll` (`:598`) is **Pass 77's rule reused, not reinvented**: focus stays on the same
programme while it is still in the window, and goes to the leftmost cell its row still has when the
programme has left. A row with no cell at all in the new window falls back to `firstCellID` — Pass 77
open question 1's third case, and this screen's existing convention. Anything that is not a programme
cell is left where it is. **`nudge(from:)` (`:548`) was not touched**; Pass 77's proven path is
byte-identical.

### 2.5 Two readings of the brief, stated as readings

- **"The Now marker" is read as the `↩ Now · 2:04 PM` pill.** The defect names three things — the
  window, the "· now" column and the Now marker — and the app has exactly two that say "now": the
  strip's `· now` suffix and that pill's clock. **There is no vertical now-line in the app or in
  `design/`** (Pass 75 §3, settled and not re-derived). The pill's clock is the only reading that can
  track *within* a half hour, which is what the third required behaviour asks for. It now does (§4.3).
- **"Cells' live/past state updates" — no cell has a live/past appearance in this app, and none was
  invented.** `GuideCellLabel` (`:841-880`) colours a cell from its `mark` and from nothing else. The
  distinction is behavioural: `select` (`:323-330`) reads the wall clock at press time, so clicking a
  programme that is on now has always played it live. What the roll changes is **which** programmes
  are in the window: `cells(for:)` keeps only those with `p.end > windowStart` (`:241`), so a
  programme that has ended leaves the grid at the roll. The before/after screenshots of §4.1 show
  exactly that — WGAL-TV's leftmost cell goes from "Premier League Soccer" to "Premier League Goal
  Z…", and WJZ-TV's from "SailGP Racing" to "College Football Today".

---

## 3. Files touched, mapped to the steps

| File | Step | What |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | **1** | the whole fix: `now`, `nowHalfHour`, `isAtNow` and `tick()` on the model; `now = Date()` added to `loadNow()` and `snapToNow()`; the beat loop on the existing `.task`; `secondsToNextMinute`, `beat()` and `settleFocusAfterRoll()` on the view; the `↩ Now` pill reading `model.now`. **115 insertions, 6 deletions** |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | VERIFY | Pass 76/77's harness **extended, not replaced** — no new file, per the constraints. **376 insertions, 0 deletions** |
| `DECISIONS.md` | **2** | the Pass 79 entry — **86 insertions, 0 deletions** |
| `COLD-START.md` | **2** | the Pass 79 entry under "What is built" and a new first paragraph under "Next step" — **50 insertions, 0 deletions** |
| `reports/2026-09-12-pass79-guide-clock.md` | deliverable | this report |

**Not touched:** every other Swift file in both targets, the Xcode project file, `Info.plist`, the
entitlements file, every build setting, the asset catalog, `design/`, `icon-source/`,
`~/Xcode/marlin-dvr-reference`, and every earlier report.

---

## 4. VERIFY — what was run on the device, and what was only traced

**Run** means driven on Home Theater (Apple TV 4K, 3rd generation, tvOS 26.6) with the real Siri
Remote, against the committed app code. **The binary on the device is the code being committed**:
`GuideScreen.swift` was last modified at 12:47:01, the app binary was built at 12:47:33 and installed
at 12:52:25, and every later `build-for-testing` recompiled the UI-test bundle only.

### 4.1 The named check — RUN. One real boundary, window at now, unfiltered

`testTheWindowRollsWithTheClockAtNow`, **14:14:49 → 14:30:58, across the real 14:30 boundary,
PASSED** (963.8 s). Result bundle
`build/p79/Logs/Test/Test-Marlin DVR TV-2026.09.12_14-14-49--0400.xcresult`; the two screenshots the
step asks for are its attachments **`120-at-now-before-the-boundary`** and
**`121-at-now-after-the-boundary`**.

The screen was **opened and then not touched again** — no press of any kind between the two
readings; the harness only reads.

```
[pass76 14:15:08.222] A-OPEN window=“Sat Sep 12 · 2:00 – 4:00 PM” startMin=375240 focus=9:“College Football” (554,228 637x82)
[pass76 14:15:13.593] A-OPEN window=“Sat Sep 12 · 2:00 – 4:00 PM” strip=["2:00 PM · now", "2:30 PM", "3:00 PM", "3:30 PM"] footer=at-now nowPill=absent
[pass76 14:15:20.205] A held cell before the boundary: “College Football” (554,228 637x82)
[pass76 14:29:28.824] A t-76s  window=“Sat Sep 12 · 2:00 – 4:00 PM” strip=["2:00 PM · now", "2:30 PM", "3:00 PM", "3:30 PM"] footer=at-now nowPill=absent
[pass76 14:30:04.754] A t-41s  window=“Sat Sep 12 · 2:00 – 4:00 PM” strip=["2:30 PM · now", "3:00 PM", "3:30 PM", "4:00 PM"] footer=at-now nowPill=absent
[pass76 14:30:40.748] A t-5s   window=“Sat Sep 12 · 2:30 – 4:30 PM” strip=["2:30 PM · now", "3:00 PM", "3:30 PM", "4:00 PM"] footer=at-now nowPill=absent
[pass76 14:30:41.859] A-AFTER  window=“Sat Sep 12 · 2:30 – 4:30 PM” startMin=375270 focus=9:“College Football” (554,228 315x82)
[pass76 14:30:48.117] A RESULT window 375240 -> 375270 minutes (30 min), current half hour is 375270
[pass76 14:30:53.443] A strip ["2:00 PM · now", "2:30 PM", "3:00 PM", "3:30 PM"] -> ["2:30 PM · now", "3:00 PM", "3:30 PM", "4:00 PM"]
[pass76 14:30:53.497] A-AFTER STRIP first column “2:30 PM · now” (554,157 160x31)
[pass76 14:30:55.451] A FOCUS stayed on “College Football”: (554,228 637x82) -> (554,228 315x82)
```

and the app's own console for the same moment:

```
[guide] roll -> Sat Sep 12 · 2:30 – 4:30 PM · fetch=1789236000
[guide] roll · focus stays on hdhr-10a75953:2.1@1789228800
```

What that establishes, item by item:

- **The window advanced by exactly one half hour, to the new current half hour.** `375240 → 375270`
  minutes, and the Mac's own current half hour at the reading was `375270`. Asserted, not eyeballed.
- **The strip moved with it, and the strip is read independently of the header.** `stripColumns()`
  matches strip labels by **shape and screen band** (a clock at y≈157), never by matching the header's
  date range, so "the strip agrees with the window" is two readings and not one. `stripFirstColumn`
  then asserts the agreement separately.
- **The "· now" marker moved with the strip and stayed on the first column** — `"2:00 PM · now"` →
  `"2:30 PM · now"` — because the window is at now again.
- **`isAtNow` stayed true**: the footer still reads "Starts at the current half hour · forward only"
  and **no `↩ Now` pill is drawn**, in both screenshots.
- **The settled focused element is shown before and after**: the accent ring stays on WMAR-HD 2.1's
  "College Football", and its box narrows `637 → 315 pt` as the window slides over it. That is the
  rows re-laying, not just the header.
- **Every row moved.** In the screenshots, WGAL-TV 8.1's leftmost cell goes from "Premier League
  Soccer" to "Premier League Goal Z…" and WJZ-TV 13.1's from "SailGP Racing" to "College Football
  Today": the programmes that ended at 2:30 have left the window. That is the live/past change of
  §2.5, drawn.
- **No network on the tick.** `fetch=1789236000` is 14:00:00 — the fetch start from the Guide's own
  load at 14:15 — and it is **unchanged** after the roll.
- **The roll landed on the boundary.** The sample at 14:29:28 still read the old window; the strip
  had already advanced by 14:30:04. The beat is aligned to the whole minute, so it fired at
  14:30:00 ± scheduling jitter.

**One artefact, recorded so nobody reads it as a rendering lag.** The 14:30:04 sample shows the new
strip beside the *old* header date range. `clockLine` runs two separate accessibility queries about
two seconds apart, and the roll fell between them; the very next sample has both advanced, and the
14:30:41 reading confirms it. It is the harness's snapshot timing, not the app's.

### 4.2 Also run before the interruption, and passing

These were driven against the same binary earlier in the session, before the owner's interruption
narrowed the brief. They are reported because they happened, not because the shorter brief asked
for them.

- **The same test across the real 13:30 boundary — PASSED** (1117.2 s). `1:00 – 3:00 PM` →
  `1:30 – 3:30 PM`, strip `"1:00 PM · now"` → `"1:30 PM · now"`, focus held on "College Football"
  with its box narrowing `1286 → 958 pt`, footer still at-now. **Its result bundle has since been
  pruned by Xcode's own log store** — only the newest two survive — so its screenshots are gone and
  only the full textual log remains. That is why §4.1's run was made.
- **`testTheRollHoldsTheCollection` across the real 14:00 boundary — PASSED** (1629.3 s), bundle
  `…13-33-46….xcresult` retained. With the owner's "Local" collection selected: `1:30 – 3:30 PM` →
  `2:00 – 4:00 PM`, strip advanced, **the five rows unchanged and in the server's order**
  (`WMAR-HD, WGAL-TV, WBAL-DT, WJZ-TV, ESPN`) before and after, the button still reading "Local", and
  WBFF45 and CWWNUV — both non-members — absent throughout. **Collection filtering holds across the
  roll.**
- **`testTheClockStopsWhenTheGuideDoes` — PASSED** (579.8 s), and this is the orphan check. The
  console across four Guide visits:

  ```
  [guide] clock stopped after 9 beat(s)     ← Guide open 12:53 → 13:02
  [guide] clock stopped after 4 beat(s)     ← Guide open 13:02:43 → 13:06:18
  [guide] clock stopped after 2 beat(s)     ← Guide open 13:09:43 → 13:11:55
  [guide] clock stopped after 21 beat(s)    ← Guide open 13:12:30 → 13:33:40
  ```

  **Every count equals the number of whole minutes that Guide was on screen**, and during the three
  minutes on Radio between the second and third visits there is **no `[guide]` line of any kind**.
  A beat that had outlived its screen would have shown up in the next Guide's count; none did.
- **One earlier attempt at the 13:00 boundary failed on an over-strict assertion of my own**, not on
  the app: it required the focused cell's box to move left, which is false for a cell clipped at the
  window's left edge — such a cell is drawn flush at x = 554 in the old window and the new one alike
  (Pass 75 §2.1). The measurement in that run was correct and matches every other. The assertion was
  relaxed to "never rightward" and the test re-run; both re-runs passed.

### 4.3 Partial — the scrolled window, cut short by the interruption

`testAScrolledWindowDoesNotRollAndTheNowPillTracksTheClock` was started at 14:03 and **killed at
14:13 by this pass's step 0**, about 18 minutes before its boundary. So **the "a scrolled window does
not roll across a boundary" half was never reached and is code-traced only.** What it did measure, in
ten minutes with the window held two slots ahead:

```
[pass76 14:04:11.299] C79 ↩ Now before the boundary: “↩ Now · 2:04 PM”
[pass76 14:04:50.940] C79 window=“Sat Sep 12 · 3:00 – 5:00 PM” strip=["3:00 PM", …] footer=ahead nowPill=“↩ Now · 2:04 PM”
[pass76 14:05:26.002] C79 window=“Sat Sep 12 · 3:00 – 5:00 PM” strip=["3:00 PM", …] footer=ahead nowPill=“↩ Now · 2:05 PM”
[pass76 14:06:00.928] C79 window=“Sat Sep 12 · 3:00 – 5:00 PM” strip=["3:00 PM", …] footer=ahead nowPill=“↩ Now · 2:06 PM”
…
[pass76 14:13:01.193] C79 window=“Sat Sep 12 · 3:00 – 5:00 PM” strip=["3:00 PM", …] footer=ahead nowPill=“↩ Now · 2:13 PM”
```

**That is the third required behaviour, measured directly: within a half hour the Now marker tracks
the clock**, minute by minute — 2:04, 2:05, 2:06 … 2:13 — while **the window does not move**, the
footer stays "ahead" and the strip carries no `· now`. Ten minutes of it, on a window two slots ahead.
What it did not reach is the boundary itself.

### 4.4 Traced, not run — stated as traced

- **A window scrolled ahead does not roll across a boundary.** Traced: `tick()` (`:188`) refuses
  unless `windowStart < nowHalfHour`, and a scrolled window is by construction ahead. §4.3 measured
  ten minutes of it holding still, but not a boundary.
- **The app backgrounded across a boundary.** `testTheGuideIsAtTheTrueHalfHourAfterBackgrounding`
  exists in the harness and **has never been executed**. Traced, in two paths: if tvOS relaunches the
  app, `loadNow()` (`:127`) sets the window from the clock it reads at that moment; if tvOS resumes
  the suspended process with the Guide still on screen, `Task.sleep(for:)` uses `ContinuousClock`,
  which counts time while the machine sleeps, so the deadline has long passed and the beat runs at
  once and rolls to `nowHalfHour` — which is the true current half hour however many boundaries were
  missed, since the roll is an assignment and not an increment. **Neither path was watched.**
- **The refetch on a roll.** Never exercised: both measured boundaries stayed inside the fetched
  24 hours and `fetch=` never moved. Reaching it needs the Guide left open for about 22 hours. The
  line is `snapToNow()`'s and `nudgeForward()`'s own, and Pass 77 measured it firing on a nudge.
- **The overlay guard** (`:583`). Traced only. Nobody has watched a boundary pass with the airing
  sheet open.
- **The beat behind the Player.** The Player is a `fullScreenCover` on `ContentView.swift:53`, so
  `ScreenShell` and the Guide stay in the view hierarchy — which is what lets Pass 25's focus restore
  work — and the `.task` is therefore **not** cancelled while a programme plays. Traced: the Guide
  keeps beating and rolling behind the player and is current when it is dismissed. Not measured, and
  §7 says why I am not certain it is harmless.

---

## 5. What the interrupted run had done, what was killed, and what was discarded

The owner interrupted at about 14:13, partway through a longer verification sequence, and re-issued
a shorter brief. Reported in full so nothing is left ambiguous.

**Killed at step 0, both confirmed gone:**

- pid 10434 — the `xcodebuild test-without-building` run of the scrolled-window test (§4.3), 18
  minutes short of its boundary.
- pid 4834 — the `devicectl device process launch --console` that had the app's console attached.

**Nothing was discarded from the repository, because there was nothing to discard.** `git status`
at step 0 read exactly:

```
 M "Marlin DVR TV/GuideScreen.swift"
 M "Marlin DVR TVUITests/GuideRightEdgeUITests.swift"
?? icon-source/
```

Both modified files are this pass's own work and both are in scope, so both were **kept**.
`icon-source/` is the standing untracked baseline — 32 entries, the owner's undecided call since
Passes 51–55 (`DECISIONS.md`, 2026-09-08) — and was not touched. `git status --porcelain -uall`
confirms **no other untracked file anywhere in the tree**: no probe, no scratch file, no half-written
source. Everything the interrupted run produced went either to the session scratchpad (the run logs,
the console capture, two clean-build trees) or to `build/p79`, which `.gitignore:4` ignores.

**The app-target code was complete and correct before the interruption and was not rewritten
afterwards.** `GuideScreen.swift` has not been modified since 12:47:01. What happened after the
interruption was: the processes above were killed, the notebook and this report were written, and
**one** further device run was made — §4.1 — because the earlier passing run's screenshots had been
pruned from Xcode's log store and the shorter brief asks for a screenshot before and after.

**Two edits were made to the harness after the interrupted run began**, both test-target only and
neither in the app: the over-strict frame assertion of §4.2 was relaxed at 13:01, and the
backgrounding test was made to report a relaunch rather than fail on one at 14:03. **The five Pass 79
tests are committed with the file; three of them have run and passed, one ran partway (§4.3) and one
has never been executed.** The file header says so, so nobody later reads an unrun test as a green one.

---

## 6. The build

Two warnings before, two after — measured rather than asserted, by a clean build of each tree into
its own derived-data path:

| Tree | Warnings | Which |
|---|---|---|
| `HEAD` (`fda3992`), from `git archive` into a scratch directory | **2** | `GuideScreen.swift:528` `channelFocusID` concurrency; `PlayerModel.swift:325` `nominalFrameRate` deprecated |
| this pass's working tree | **2** | `GuideScreen.swift:635` `channelFocusID` concurrency; `PlayerModel.swift:325` `nominalFrameRate` deprecated |

**The same two warnings.** `channelFocusID` moved from `:528` to `:635` because Pass 79 inserts lines
above it; nothing else changed. The UI-test target builds clean. **No test-only code is in the app
target** — the three `print`s added are `[guide]` lines of the same kind the screen already emits at
`:401`, `:496`, `:499` and `:522`.

---

## 7. Open questions

Raised, not acted on.

1. **`TimeFormat.currentHalfHour` (`Formatting.swift:65`) now has no caller.** `GuideScreen.swift`
   was its only one. The model derives the half hour from its own observed clock instead, so that a
   window write and an `isAtNow` read can never straddle a boundary between two separate `Date()`
   reads. Removing the now-unused property is a `Formatting.swift` edit and outside this pass's
   scope; it is left exactly as it is.
2. **A window exactly one slot ahead becomes at-now when the clock catches up, and the `↩ Now` pill
   is then removed.** If the remote happened to be **on that pill** at that moment, nothing has been
   built to re-place focus — the owner's rules name no case for it, and inventing one is the kind of
   hardening this pass forbids. Unmeasured. The screen always has other focusable items (the
   collections button, the grid, the rail), so this is at worst a focus jump the engine chooses, not
   a stranded remote — but that is reasoning, not a measurement.
3. **The beat pauses entirely while one of the Guide's own overlays is up** (§2.4), so the pill's
   clock freezes and the roll is deferred to the first beat after the overlay closes — up to 60
   seconds. Chosen deliberately over rolling the grid beneath an open sheet. Whether the owner would
   rather have the clock keep running behind the sheet is his call.
4. **The beat keeps beating behind the Player** (§4.4). If a boundary passes during playback the
   Guide rolls, and focus may be re-placed by `settleFocusAfterRoll` — which would change Pass 25's
   measured property that a Player round trip returns focus to the very card it left. It can only do
   so when the card's programme has left the window, in which case returning to it is impossible
   anyway. Not measured.
5. **The one-minute beat is a choice, not a measurement.** It is what the `↩ Now` clock's minute
   resolution needs, and it costs one body evaluation of the Guide a minute — far less often than
   the focus engine already causes one on every remote press. Nobody has profiled it.
6. **`icon-source/` is still 32 untracked entries**, the owner's undecided call (`DECISIONS.md`,
   2026-09-08). Restated so it is not mistaken for drift.
7. **Everything Pass 77 left open is untouched by this pass** and is not re-raised here.

---

## 8. The three things I am least sure of

1. **That "the Now marker" is the `↩ Now · 2:04 PM` pill.** The owner's defect lists three things and
   the app has only two that say "now". I built the pill's clock to track and measured it doing so
   (§4.3), and Pass 75 §3 settles that no vertical now-line exists in the app or in `design/`. But if
   he meant a marker that does not exist yet, then this pass has fixed two of the three things he
   named and the third is a new drawing rather than a repair. **This is the reading I would most like
   corrected if it is wrong.**
2. **That the backgrounded case behaves as traced.** §4.4's argument rests on `Task.sleep(for:)`
   defaulting to `ContinuousClock`, which counts time while the machine sleeps, so a suspended app
   wakes with an expired deadline and beats at once. I believe the mechanism, and the reopened-Guide
   path is trivially safe because `loadNow()` reads the clock fresh. What I have not watched is tvOS
   actually resuming a suspended app onto a Guide that then rolls — and if the beat somehow does not
   fire on resume, the window would sit stale until the next whole minute at worst, which is still
   self-correcting but is not what the step asks to see. **The harness test for it exists and has
   never been run.**
3. **That pausing the beat under an overlay is the right trade.** It is the conservative choice and
   it matches `gridMoved`'s existing guard, but it means the one place the clock is most visible over
   a long sit — the airing sheet left open — is exactly where it stops. The alternative risks the
   sheet's Menu restoring focus to a cell the roll deleted, which is a worse failure; I chose the
   quiet one. Nobody has watched either.

---

## 9. SCOPE CHECK

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md`, the Pass 75 and Pass 77 reports | read | required reading |
| `Marlin DVR TV/GuideScreen.swift` | **written** | 1 |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | **written** (extended, not created) | VERIFY |
| `COLD-START.md`, `DECISIONS.md` | **appended to, additions only** | 2 |
| `reports/2026-09-12-pass79-guide-clock.md` | **created** | deliverable |
| Home Theater | builds, installs, console launches and five device test executions | VERIFY |
| `http://192.168.1.250:8090/` | the app's own GETs and its launch ping; **no request by hand** | VERIFY |
| `build/p79` | derived data, `.gitignore`d | VERIFY |
| the session scratchpad | run logs, the console capture, and two clean-build trees for §6 | 1, VERIFY |
| `~/Xcode/marlin-dvr-reference`, `design/` | **not opened** | — |

**Not touched:** Unraid as a host, marlinpc, the HDHomeRun, the UNAS4Pro share, the Master Bedroom
Apple TV, every other folder under `~/Xcode`, and every earlier report.

---

## 10. Git

**One commit on `main`, local and NOT pushed.** The code, the harness, the notebook and this report
together, per the Pass 68 rule that a pass's report goes inside its own commit. **The owner tests it
on Home Theater before anything is pushed** — the standing separate push gate. Nothing forced, no
history rewritten, no branch other than `main`.
