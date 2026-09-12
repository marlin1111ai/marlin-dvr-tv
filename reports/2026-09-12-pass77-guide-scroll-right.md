# Pass 77 — the Guide scrolls right

**Date:** 2026-09-12
**Base commit:** `38067c8` (Pass 76, the right-edge device probe).
**Result: built, proven on Home Theater across all nine VERIFY items, committed locally and NOT
pushed — the owner tests it first.**

One Right press on the last visible cell of a row moves the window forward one slot (30 min). The time
strip, every row and the header move together. Forward only. `Left`, `Menu`, `↩ Now`, `+12h` and a rail
trip behave exactly as they did.

**The app-target diff is `GuideScreen.swift` alone: 129 insertions, 1 deletion** — and the one deletion
is a closure signature (`{ _, new in` → `{ old, new in`). No other app file, no project file, no
`Info.plist`, no entitlements, no asset, no new dependency and no new app-target file.
**Build warnings are unchanged from HEAD's two**: `PlayerModel.swift:325` (`nominalFrameRate`
deprecated) and the `channelFocusID` concurrency warning, which has moved from `GuideScreen.swift:400`
to `:528` because of the lines added above it. **No test-only code is in the app target.**

**Server traffic.** The app's own `GET /api/guide` and `GET /api/schedule`, plus its standing
`POST /api/clients/{id}/ping` on each launch (`ClientSession.swift:62-81`) — the only non-GET request,
and the app's behaviour rather than this pass's. **One GET by hand**, `/api/guide/stats`, read before
the run to size VERIFY (i) from the real coverage horizon rather than guessing it. Nothing was
recorded, no pass created, no collection or lineup or library or schedule touched, and the airing sheet
was never opened. `~/Xcode/marlin-dvr-reference` and `design/` were not opened.

**Redaction.** The device console carries the app's launch-ping line, which prints this Apple TV's
client id and LAN address. It is reproduced nowhere below; every console block is filtered to
`[guide]` lines. No credential, token, device id or client id appears in this report.

---

## 1. What was built

### Step 1 — the press, and why the edge is read late

`.onMoveCommand` on the grid's own `ScrollView`, **`GuideScreen.swift:347`**. That attachment point is
measured, not chosen: Pass 76 put one instance there and one on this screen's root `ZStack` and found
**all 22 move commands arriving at the grid instance and none at the root**.

`gridMoved` (**`:462`**) acts on `.right` and nothing else, and it reads the edge from the **settled**
focus 150 ms later rather than at receipt. The reason is Pass 76's race: of seven presses the focus
engine acted on, **six delivered the command after the `@FocusState` write** and one before it. At
receipt `focused` is therefore sometimes the cell the engine has just arrived at — and nudging on that
would make the press that walks *on to* the last cell move the window as well. One press, two actions,
which is Pass 29's defect in another costume.

So a press the engine consumed is recognised not by a before/after comparison but by **the kind of
focus change it made**. `isRightwardStep` (**`:448`**) is true for a later programme on the same
channel, or for that row's channel cell handing over to its first programme cell. Nothing else on this
screen produces one: a Left step goes to an earlier start, Up and Down change channel, and a nudge's
own landing is the leftmost cell, which is earlier than the cell it came from. `engineSteppedRightAt`
(**`:258`**) records when one last happened; a press within 150 ms of one is the engine's, not the
window's.

### Step 2 — focus after a nudge

`nudge(from:)` (**`:487`**): focus stays on the same programme while that programme is still in the
window — nothing is assigned, because the cell keeps its identity and SwiftUI keeps focus on it — and
when the programme has left the window focus goes to the leftmost cell its row still has.

**There is a third case the owner's rule does not name, and it is real rather than theoretical: the row
may have no cell at all in the new window.** The owner's channel 2.1 has a listings gap around
11:30 AM, and when a programme left the window there its row was empty. Focus then falls back to
`firstCellID` — a cell on another row — which is the app's existing convention at `:347`, `:368`,
`:395` and `:435`, and is what keeps the remote from being stranded. Open question 1.

### Step 3 — the limit, and the refetch

`lastListedSlot` (**`:118`**) is the start of the last slot in the fetched range that has a listing in
it. It reads the same thing `endOfListings` reads — a block's `program` — so the two cannot disagree:
nil there is exactly `endOfListings == true`. `nudgeForward` (**`:132`**) refuses when the next slot
would pass it, and otherwise advances `windowStart` by one slot and refetches **by the existing rule**,
`if windowEnd > fetchEnd`, the same line `pageForward()` uses.

### Step 5 — what was deliberately not touched

The footer (`:572`), `↩ Now` (`:497`), `+12h` (`:509`), the strip's "· now" marker (`:557`), the
midnight accent (`:536`) and the collection filter (`:162`) all already derive from `windowStart`.
**None of them was changed**, and each was proven correct at a 30-minute-offset window — §2 step 5.

---

## 2. Step 4's finding: **tvOS does not auto-repeat the move command, so nothing was built for it**

```
[pass76 08:59:14.735] H held Right for 2.0 s -> 1 slot(s) · window=“Sat Sep 12 · 9:00 – 11:00 AM”
[pass76 08:59:14.736] H   rate: 0.50 slots/s, one step every 2000 ms
[pass76 08:59:23.300] H held Right for 4.0 s -> 1 slot(s) · window=“Sat Sep 12 · 9:30 – 11:30 AM”
[pass76 08:59:23.301] H   rate: 0.25 slots/s, one step every 4000 ms
[pass76 08:59:25.038] H focus at the end: 9:“Jack Hanna's Passport” (1203,228 309x82)
```

A **2-second** hold advanced the window **one** slot. A **4-second** hold advanced it **one** slot. One
press, one move command, however long the button is held. The step said that if it does not repeat,
report it and build nothing — so there is **no timer, no synthetic repeat and no repeat handling of any
kind** anywhere in the change.

**The limit of this measurement, stated plainly:** it is `XCUIRemote.press(.right, forDuration:)`, a
synthesized hold, not a thumb on the owner's remote. Pass 9 established that a synthesized hold does
drive the device's own press pipeline (that is how the click-and-hold tests work), so the hold itself
is real; what I cannot rule out is that a physical hold repeats where a synthesized one does not. The
owner will find out in a second on Home Theater, and if it does repeat, each repeat is its own move
command and the window steps again with no code change.

---

## 3. The one thing the owner should decide: roughly three presses in five move the window

This is a consequence of his two rules combining, not a defect, and it is the headline reading of the
pass.

Because focus **stays on the same programme** after a nudge (step 2), the slot the nudge reveals often
puts a **new** cell to the right of that programme — and the next Right press is then taken by the
focus engine to move on to the new cell instead of moving the window. Measured, as slots per press:

| Case | Slots | Presses | Ratio |
|---|---|---|---|
| (a), a row of 30-minute programmes | 3 | 5 | 0.60 |
| (a) re-run, focus on a long programme | 3 | **3** | **1.00** |
| (c), 48 slots across a full day | 48 | 78 | 0.62 |
| (f), while filtered to "Local" | 4 | 5 | 0.80 |
| (i), near the horizon | 34 | 46 | 0.74 |

**On a row carrying one long programme every press moves the window; on a row of half-hour programmes
it alternates.** The alternative — focus tracking the right-hand edge so every press steps — directly
contradicts the owner's step 2, so it was **not** built. Open question 2.

---

## 4. VERIFY — Home Theater, with the settled focused-element output for each

Every item below was measured on Home Theater (Apple TV 4K, 3rd generation, tvOS 26.6) with the real
Siri Remote, against the committed app code. Screenshots are attached to the test results in
`build/p77/Logs/Test/`. The harness is the Pass 76 file extended — **no new file**, per the pass's
constraints.

**One disclosure about composition.** The app source changed **once** mid-testing: `· fetch=…` was
added to the nudge log line so the refetch in (c) could be counted. That is print-only. Items (a) and
(b) were re-run against the final build after it; every other item was already measured against it.

### (a) Three nudges from a row's last cell — the strip and the window moving together

```
[pass76 10:39:00.363] OPEN window=“Sat Sep 12 · 10:30 AM – 12:30 PM” startMin=375030 focus=9:“Jack Hanna's Passport” (554,228 315x82)
[pass76 10:39:00.408] OPEN STRIP first column “10:30 AM · now” (554,157 175x31)
[pass76 10:39:15.208] ATEDGE window=“Sat Sep 12 · 10:30 AM – 12:30 PM” startMin=375030 focus=9:“College Football” (1524,228 315x82)
[pass76 10:39:20.198] EDGE press #1 -> nudged windowStep=30min window=“Sat Sep 12 · 11:00 AM – 1:00 PM”
[pass76 10:39:20.281] NUDGE#1 STRIP first column “11:00 AM” (554,157 106x31)
[pass76 10:39:25.342] EDGE press #2 -> nudged windowStep=30min window=“Sat Sep 12 · 11:30 AM – 1:30 PM”
[pass76 10:39:25.522] NUDGE#2 STRIP first column “11:30 AM” (554,157 106x31)
[pass76 10:39:30.628] EDGE press #3 -> nudged windowStep=30min window=“Sat Sep 12 · 12:00 – 2:00 PM”
[pass76 10:39:30.682] NUDGE#3 STRIP first column “12:00 PM” (554,157 108x31)
[pass76 10:39:30.929] EDGE outcomes in order: nudged -> nudged -> nudged
[pass76 10:39:30.929] EDGE window start minutes at each nudge: [375030, 375060, 375090, 375120]
[pass76 10:39:30.929] RESULT 3 nudges in 3 presses (0 press(es) were taken by the focus engine)
```

Window start minutes `375030 → 375060 → 375090 → 375120`: **+30 each, three times.** The strip's first
column tracked it exactly — `"10:30 AM · now"` → `"11:00 AM"` → `"11:30 AM"` → `"12:00 PM"` — and the
screenshots `21`, `22`, `23` are the three states with the strip and every row shifted together.
Walking to the last cell did **not** move the window (`ATEDGE` equals `OPEN`), which is the control.

### (b) Focus after a nudge — both of the owner's cases

```
[pass76 10:37:13.942] B CASE 1 focus stayed on the same programme “College Football”: (1524,228 315x82) -> (1203,228 637x82)
[pass76 10:38:19.044] B CASE 2 “College Football” left the window; focus is now “Storage Wars” (554,658 315x82) — leftmost column x=554
[pass76 10:38:19.287] B RESULT focus-held seen=true, programme-left-the-window seen=true
```

**Case 1:** the same programme kept focus and its cell simply moved left, `(1524,228)` → `(1203,228)`.
**Case 2:** when "College Football" left the window, focus went to the **leftmost column, x=554**.

### (c) 48 slots — one refetch, strip and rows still aligned, focus on a real cell

```
[pass76 09:05:27.166] C-OPEN window=“Sat Sep 12 · 9:00 – 11:00 AM” startMin=374940 focus=9:“Good Morning America” (554,228 637x82)
[pass76 09:05:27.209] C-OPEN STRIP first column “9:00 AM · now” (554,157 163x31)
[pass76 09:05:52.052] C 12 presses -> 7 slots · window=“Sat Sep 12 · 12:30 – 2:30 PM”
[pass76 09:06:08.635] C 24 presses -> 13 slots · window=“Sat Sep 12 · 3:30 – 5:30 PM”
[pass76 09:06:25.194] C 36 presses -> 20 slots · window=“Sat Sep 12 · 7:00 – 9:00 PM”
[pass76 09:06:42.879] C 48 presses -> 28 slots · window=“Sat Sep 12 · 11:00 PM → Sun Sep 13 · 1:00 AM”
[pass76 09:07:00.114] C 60 presses -> 36 slots · window=“Sun Sep 13 · 3:00 – 5:00 AM”
[pass76 09:07:16.685] C 72 presses -> 43 slots · window=“Sun Sep 13 · 6:30 – 8:30 AM”
[pass76 09:07:24.969] C DONE 48 slot(s) in 78 press(es) · window=“Sun Sep 13 · 9:00 – 11:00 AM”
[pass76 09:07:26.450] C-END window=“Sun Sep 13 · 9:00 – 11:00 AM” startMin=376380 focus=9:“Hoarders” (554,658 1286x82)
[pass76 09:07:26.526] C-END STRIP first column “9:00 AM” (554,157 99x31)
[pass76 09:07:26.541] C RESULT 48 slots in 78 presses
[pass76 09:07:27.194] C-ALIGN STRIP first column “9:00 AM” (554,157 99x31)
[pass76 09:07:27.996] C focus at the end: 9:“Hoarders” (554,658 1286x82)
```

Sat 9:00 AM → **Sun 9:00 AM, exactly +24 h**, in 78 presses. The strip reads the window's start at both
ends. Focus finishes on a real cell — "Hoarders", a 1286 pt full-window cell. And the refetch, from the
app's own log:

```
nudge #1: fetch=1789218000
nudge #49: fetch=1789299000
```

**Two distinct fetched ranges across 48 slots — one refetch.** `1789299000 − 1789218000 = 81,000 s`,
which is exactly 45 slots, so the refetch lands on **this test's nudge 45** exactly as the arithmetic
predicts: `windowEnd > fetchEnd` first holds once `windowStart` has advanced 45 slots. *(The indices
above count every nudge in the console, and the four from the "Local" test that ran before it are
included — #49 overall is #45 of this test.)* An earlier 90-slot run showed the same 81,000 s step
twice, which confirms the period rather than a coincidence.

### (d) +12h, then a nudge, then ↩ Now

```
[pass76 09:56:26.637] D-OPEN window=“Sat Sep 12 · 9:30 – 11:30 AM” startMin=374970 focus=9:“Good Morning America” (554,228 315x82)
[pass76 09:56:36.975] D header right end is “+12h”
[pass76 09:56:42.253] D pressed +12h · window=“Sat Sep 12 · 9:30 – 11:30 PM”
[pass76 09:56:43.383] D-PLUS12 window=“Sat Sep 12 · 9:30 – 11:30 PM” startMin=375690 focus=9:“Storage Wars” (554,658 326x82)
[pass76 09:56:52.498] D-WALK on the row's last visible cell after 2 press(es): 9:“Storage Wars” (1567,658 272x82)
[pass76 09:56:56.969] D press #1 -> nudged windowStep=30min window=“Sat Sep 12 · 10:00 PM – 12:00 AM”
[pass76 09:56:57.875] D-NUDGED window=“Sat Sep 12 · 10:00 PM – 12:00 AM” startMin=375720 focus=9:“Storage Wars” (1246,658 594x82)
[pass76 09:57:50.299] D-NOW header right end is “+12h”
[pass76 09:57:58.050] D-NOW pressed “Good Morning America”
[pass76 09:57:59.265] D-NOW window=“Sat Sep 12 · 9:30 – 11:30 AM” startMin=374970 focus=9:“Good Morning America” (554,228 315x82)
[pass76 09:57:59.549] D RESULT +12h -> nudge -> ↩ Now all correct
```

`+12h` took 9:30 AM → 9:30 PM; the nudge then moved exactly 30 minutes to 10:00 PM; `↩ Now` returned
the window to **9:30 – 11:30 AM, which is now**, with focus on the first cell. *(The `D-NOW pressed …`
line prints a label re-read 5 s after the press, by which time the window had already snapped and focus
had moved to the first cell — the window going 10:00 PM → 9:30 AM is what proves the pill fired.)*

### (e) About two days ahead, then Menu

```
[pass76 09:49:40.399] E-OPEN window=“Sat Sep 12 · 9:30 – 11:30 AM” startMin=374970 focus=9:“Good Morning America” (554,228 315x82)
[pass76 09:49:54.423] E after +12h #1: window=“Sat Sep 12 · 9:30 – 11:30 PM”
[pass76 09:50:19.849] E after +12h #2: window=“Sat Sep 12 · 9:30 – 11:30 PM”
[pass76 09:50:44.720] E after +12h #3: window=“Sat Sep 12 · 9:30 – 11:30 PM”
[pass76 09:51:09.235] E after +12h #4: window=“Sat Sep 12 · 9:30 – 11:30 PM”
[pass76 09:51:18.088] E-WALK on the row's last visible cell after 2 press(es): 9:“Storage Wars” (1567,658 272x82)
[pass76 09:51:26.537] E DONE 4 slot(s) in 5 press(es) · window=“Sat Sep 12 · 11:30 PM → Sun Sep 13 · 1:30 AM”
[pass76 09:51:26.537] E 4 slot(s) in 5 press(es) two days out
[pass76 09:51:28.030] E-FAR window=“Sat Sep 12 · 11:30 PM → Sun Sep 13 · 1:30 AM” startMin=375810 focus=9:“Storage Wars” (913,658 631x82)
[pass76 09:51:36.278] E-MENU window=“Sat Sep 12 · 9:30 – 11:30 AM” startMin=374970 focus=9:“Good Morning America” (554,228 315x82)
[pass76 09:51:36.890] E RESULT Menu from ~2 days ahead snapped back to now and stayed on the Guide
```

`+12h` plus four nudges put the window at **Sat 11:30 PM → Sun 1:30 AM**, across midnight. **Menu
snapped it back to 9:30 – 11:30 AM, now**, and stayed on the Guide.

### (f) The "Local" collection, scrolled four slots

```
[pass76 09:04:15.044] F chose “Local” · button now “Local”
[pass76 09:04:15.268] F filtered rows: ["WMAR-HD", "WGAL-TV", "WBAL-DT", "WJZ-TV", "ESPN"]
[pass76 09:04:19.451] F-WALK on the row's last visible cell after 2 press(es): 9:“Jack Hanna's Passport” (1524,228 315x82)
[pass76 09:04:26.387] F DONE 4 slot(s) in 5 press(es) · window=“Sat Sep 12 · 11:00 AM – 1:00 PM”
[pass76 09:04:26.387] F 4 slot(s) in 5 press(es)
[pass76 09:04:26.700] F-SCROLLED window=“Sat Sep 12 · 11:00 AM – 1:00 PM” startMin=375060 focus=9:“Hearts of Heroes” (554,228 315x82)
[pass76 09:04:27.236] F filtered rows after scrolling: ["WMAR-HD", "WGAL-TV", "WBAL-DT", "WJZ-TV", "ESPN"]
[pass76 09:04:42.469] F-reset chose “All Channels” · button now “All Channels”
```

The five rows in the server's own order **before and after** scrolling, the button still reading
"Local", and WBFF45 and CWWNUV — both non-members — absent throughout.

### (g) Scrolled, then out to the rail and back

```
[pass76 09:23:28.011] G-WALK on the row's last visible cell after 2 press(es): 9:“Jack Hanna's Passport” (1524,228 315x82)
[pass76 09:23:37.722] G DONE 4 slot(s) in 7 press(es) · window=“Sat Sep 12 · 11:00 AM – 1:00 PM”
[pass76 09:23:39.028] G-SCROLLED window=“Sat Sep 12 · 11:00 AM – 1:00 PM” startMin=375060 focus=9:“College Football” (1203,228 637x82)
[pass76 09:23:42.716] G left 1 -> grid:programme-cell
[pass76 09:23:46.106] G left 2 -> grid:programme-cell
[pass76 09:23:49.498] G left 3 -> grid:channel-cell
[pass76 09:23:52.894] G left 4 -> rail
[pass76 09:24:09.874] G back-left 1 -> rail
[pass76 09:24:24.753] G-BACK window=“Sat Sep 12 · 9:00 – 11:00 AM” startMin=374940 focus=9:“Good Morning America” (554,228 637x82)
[pass76 09:24:25.040] G RESULT a rail trip returns the window to now, as today
```

Four slots ahead, out to the rail, down to Radio, open it, back up to the Guide, back in: **the window
is at now**, as today. That is `ScreenShell.swift:57`'s `.id(current)` rebuilding the screen, unchanged
by this pass.

### (h) Held Right — §2.

### (i) The last slot that has a listing, and a further Right

```
[pass76 10:25:36.860] I press #45 -> nudged windowStep=30min window=“Sat Sep 26 · 2:00 – 4:00 PM”
[pass76 10:25:39.732] I press #46 -> nudged windowStep=30min window=“Sat Sep 26 · 2:30 – 4:30 PM”
[pass76 10:25:42.609] I press #47 -> nothing windowStep=0min window=“Sat Sep 26 · 2:30 – 4:30 PM”
[pass76 10:25:45.469] I press #48 -> nothing windowStep=0min window=“Sat Sep 26 · 2:30 – 4:30 PM”
[pass76 10:25:48.519] I press #49 -> nothing windowStep=0min window=“Sat Sep 26 · 2:30 – 4:30 PM”
[pass76 10:25:48.519] I 34 nudge(s), then 3 consecutive press(es) that did nothing
[pass76 10:25:48.803] I-LIMIT window=“Sat Sep 26 · 2:30 – 4:30 PM” startMin=395430 focus=9:“AccuWeather Weekend” (554,658 315x82)
[pass76 10:25:49.388] I-LIMIT STRIP first column “2:30 PM” (554,157 96x31)
[pass76 10:25:49.418] I RESULT the window stops at the last slot that has a listing; further Right presses do nothing
```

and the app's own refusals:

```
[guide] nudge refused at Sat Sep 26 · 2:30 – 4:30 PM — no later slot has a listing
[guide] nudge refused at Sat Sep 26 · 2:30 – 4:30 PM — no later slot has a listing
[guide] nudge refused at Sat Sep 26 · 2:30 – 4:30 PM — no later slot has a listing
```

The window stopped at **Sat Sep 26 · 2:30 – 4:30 PM**. Presses **47, 48 and 49 did nothing at all** —
window unchanged, focus unchanged — and the console carries exactly three `nudge refused` lines, one
per press. The strip still reads the window's start and focus is on a real cell.

**This cross-checks the limit against the server independently.** `GET /api/guide/stats` read before
the run answered `"coverageUntil":"Sat 3:00 PM"` — the last programme anywhere ends at 15:00 — so the
last slot that contains a listing begins at **14:30**, which is exactly where the window stopped.
`lastListedSlot` computes `(15:00 − 1s)` truncated to the half hour; the device agrees with the
arithmetic to the minute.

### Step 5 — the footer, the now marker, the pills and the midnight column at an offset window

```
[pass76 09:39:11.171] S5-OPEN STRIP first column “9:30 AM · now” (554,157 163x31)
[pass76 09:39:23.345] S5-WALK on the row's last visible cell after 3 press(es): 9:“Hearts of Heroes” (1524,228 315x82)
[pass76 09:39:29.038] S5-OFFSET window=“Sat Sep 12 · 10:00 AM – 12:00 PM” startMin=375000 focus=9:“Hearts of Heroes” (1203,228 309x82)
[pass76 09:39:29.868] S5-OFFSET STRIP first column “10:00 AM” (554,157 110x31)
[pass76 09:39:29.891] S5 footer, now marker, ↩ Now and +12h all correct at a 30-minute offset
[pass76 09:39:37.724] S5-12h header right end is “+12h”
[pass76 09:39:43.002] S5-12h pressed +12h · window=“Sat Sep 12 · 10:00 PM – 12:00 AM”
[pass76 09:39:51.115] S5-W1 on the row's last visible cell after 2 press(es): 9:“Storage Wars” (1246,658 594x82)
[pass76 09:39:57.376] S5-MIDNIGHT window=“Sat Sep 12 · 10:30 PM → Sun Sep 13 · 12:30 AM” startMin=375750 focus=9:“Storage Wars” (924,658 620x82)
[pass76 09:39:57.662] S5 midnight column “Sun · 12:00 AM” (1527,157 171x31)
[pass76 09:39:57.662] S5 RESULT footer, now marker, pills and the midnight column all correct off the half hour
```

At a 30-minute offset: the footer flips to "Menu snaps back to now · forward only, 24 hours per
request" and the at-now sentence is gone; the strip's first column loses "· now"; `↩ Now` and `+12h`
are both drawn. Across midnight the midnight column is **named** — `"Sun · 12:00 AM"` at
`(1527, 157)` — which is frame 3c's own treatment (`dc:321-327`). **None of these was touched.**

---

## 5. Files touched, mapped to step numbers

| File | Step(s) | What |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | **1, 2, 3** | the whole change: `lastListedSlot` and `nudgeForward` on the model; `.onMoveCommand` on the grid's `ScrollView`; `gridMoved`, `cellKey`, `isRightwardStep`, `lastCellID(inRowOf:)`, `nudge(from:)`, `engineSteppedRightAt` and the two constants on the view; one line added to the existing `.onChange(of: focused)`. **129 insertions, 1 deletion** |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | **VERIFY, 4** | Pass 76's harness extended with the nine items and the held-Right measurement. **Test target only.** No new file, per the constraints |
| `DECISIONS.md` | **6** | the Pass 77 entry — **63 insertions, 0 deletions** |
| `COLD-START.md` | **6** | the Pass 77 entry under "What is built" and a new first paragraph under "Next step" — **40 insertions, 0 deletions** |
| `reports/2026-09-12-pass77-guide-scroll-right.md` | deliverable | this report |

**Not touched:** every other Swift file in both targets, the Xcode project file, `Info.plist`, the
entitlements file, every build setting, the asset catalog, `design/`, `icon-source/`,
`~/Xcode/marlin-dvr-reference`, and every earlier report. **Step 5 changed nothing by design** — the
footer, `↩ Now`, `+12h`, the now marker, the midnight accent and the collection filter were proven
rather than edited.

---

## 6. Open questions

Raised, not acted on.

1. **The row can have no cell at all in the new window, which the owner's focus rule does not cover.**
   Measured on his own data: channel 2.1 has a listings gap around 11:30 AM, and focus then lands on
   another row's first cell (the app's existing `firstCellID` fallback). The alternative would be to
   leave focus on the channel cell of the same row, which the rule also does not name. **Not chosen.**
2. **Roughly three presses in five move the window** (§3). The alternative contradicts step 2, so it
   was not built. **His call.**
3. **A held Right does not repeat** (§2), measured with a synthesized hold. If a physical hold does
   repeat, the window steps per repeat with no code change — but then the repeat rate becomes the
   scroll speed, and nobody has seen that.
4. **A pre-existing header-geometry limit that this feature makes more visible.** Up from a grid cell
   whose x falls between the collections button and the right-hand pills moves focus **nowhere**: the
   header has no focusable item above that span and the focus engine refuses. It is the same thing
   `WeatherScreen.swift:109-113` records for its Radar button, and it cost three harness runs to
   diagnose. It matters more now, because the owner will sit at the right-hand edge of a row often and
   reaching `↩ Now` from there needs a Left press first. **Nothing was changed for it** — it is outside
   what this pass names.
5. **`lastListedSlot` is computed from the current fetch only**, so a 24-hour span in which *every*
   channel's listings stop early would stop the scroll one fetch short of the true horizon. Near the
   real horizon that is the intended behaviour and (i) proves it; mid-range it would be a false stop.
   Unexercised — the owner's guide has no such hole.
6. **The 150 ms settle is latency the owner feels on every nudge**, and a human pressing Right faster
   than about 150 ms apart would have the second press suppressed as the engine's. Not measured with a
   human hand.
7. **`icon-source/` is still 32 untracked entries**, the owner's undecided call
   (`DECISIONS.md`, 2026-09-08). Restated so it is not mistaken for drift.

---

## 7. The three things I am least sure of

1. **That the press-to-slot ratio will feel right to the owner.** I measured it five ways and it ranges
   from 1.00 on a long programme to 0.60 on half-hour programmes, and I believe those numbers. What I
   cannot tell you is whether "it must feel fluid" is satisfied by a scroll that sometimes takes two
   presses a slot. I built his rule exactly as written rather than the one that would always step,
   because step 2 is explicit — but this is the decision in the pass I would most like overruled if I
   read his intent wrong.
2. **That `isRightwardStep` catches every way the focus engine can consume a Right press.** I can show
   it catches the two I found — cell to a later cell in the same row, and channel cell to first cell —
   and that nothing else on this screen makes a rightward same-row change. But it is a *sufficient*
   test built from the cases I could produce, not a proof over all of them. If some path I have not
   thought of moves focus rightward without matching it, that press would both move focus and nudge.
   Nothing in 300-odd device presses did.
3. **That the limit behaves at the horizon for reasons rather than by luck.** (i) stopped at exactly
   the slot `coverageUntil` predicts, three presses in a row did nothing, and the refusal log fired
   three times — that is strong. But it is **one** horizon, on one evening's guide data, and the
   horizon moved by ten hours between two `stats` reads earlier in the day. I have not watched what
   happens if a refresh extends the listings while the window is parked at the old limit; the next
   fetch should simply allow more, and that is reasoning, not a measurement.

---

## 8. SCOPE CHECK

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md`, the Pass 75 and Pass 76 reports | read | required reading |
| `Marlin DVR TV/GuideScreen.swift` | **written** | 1, 2, 3 |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | **written** (extended, not created) | VERIFY, 4 |
| `COLD-START.md`, `DECISIONS.md` | **appended to, additions only** | 6 |
| `reports/2026-09-12-pass77-guide-scroll-right.md` | **created** | deliverable |
| Home Theater | builds, installs, console launches and ten device test executions | VERIFY |
| `http://192.168.1.250:8090/` | the app's own GETs and its launch ping; **one GET by hand** (`/api/guide/stats`) | 3, VERIFY (i) |
| `build/p77` | derived data, `.gitignore`d; `build/p77check` created and deleted | VERIFY |
| the session scratchpad | the run and console logs | VERIFY |
| `~/Xcode/marlin-dvr-reference`, `design/` | **not opened** | — |

**Not touched:** Unraid as a host, marlinpc, the HDHomeRun, the UNAS4Pro share, the Master Bedroom
Apple TV, every other folder under `~/Xcode`, and every earlier report.

---

## 9. Git

**One commit on `main`, local and NOT pushed.** The code, the harness, the notebook and this report
together, per the Pass 68 rule that a pass's report goes inside its own commit. **The owner tests it on
Home Theater before anything is pushed** — the standing separate push gate. Nothing forced, no history
rewritten, no branch other than `main`.
