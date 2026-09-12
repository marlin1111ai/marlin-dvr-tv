# Pass 76 — device probe: Right at the Guide's right-hand edge

**Date:** 2026-09-12
**Base commit:** `fce20c2` (Pass 75, "Guide scroll-right recon").
**Result: the three questions are answered on the device, and the diagnostic is reverted.** No
app-target source changed: `git diff HEAD --stat` over `Marlin DVR TV/` is empty and no `[probe]`,
`probeMove` or `onMoveCommand` remains in any app file (§7). What this pass leaves behind is the
harness, the notebook additions and this report.

**This pass exists to answer Open Question 1 of `reports/2026-09-12-pass75-guide-scroll-recon.md`**,
which that pass called the one thing the whole scroll-right design rests on and the one thing no
prior device run had touched. Pass 75 §2.3 also found that **no run in `reports/` had ever pressed
Right inside a Guide row at all**, so the baseline was untested too. Both are now measured.

**Server traffic.** **No request was made by hand at all.** The only traffic is the app's own, driven
on the device: `GET /api/guide`, `GET /api/schedule`, and the `POST /api/clients/{id}/ping` it has
sent on every launch since sweep 1 (`ClientSession.swift:62-81`). **That ping is the only non-GET
request in the pass**, it is the app's standing behaviour rather than this pass's, and the harness
uses `activate()` so it does not even cause one per test. Nothing was recorded, no pass created, no
collection or lineup or library or schedule touched, and the airing sheet was never opened.
`~/Xcode/marlin-dvr-reference` and `design/` were not opened. Unraid as a host, marlinpc, the
HDHomeRun and the UNAS4Pro share were not touched.

**Redaction.** The device console also carried the app's launch ping line, which prints this Apple
TV's client id and LAN address. **It is not reproduced anywhere in this report**; every console block
below is filtered to `[probe]` lines only. No credential, token, device id or client id appears here.
The ids that do appear (`hdhr-10a75953:2.1`, `hdhr-10a75953:8.1`, `hdhr-10a75953:45.1`) are lineup
identifiers of the form already committed throughout `reports/`.

---

## 1. The answers

**Three questions, one line each, as the step asks.**

1. **Does Right walk a row cell by cell? YES.** Measured on three rows across three runs: on row 2.1
   focus moved from the cell at **x=554** to the cell at **x=1203** (`hdhr-10a75953:2.1@1789214400` →
   `…@1789218000`), and on row 8.1 from the channel cell to the first programme cell
   (`ch:hdhr-10a75953:8.1` → `…8.1@1789210800`) and on to the next (`…@1789210800` → `…@1789216200`).
2. **Does tvOS deliver a Right press to the app when focus cannot move? YES, through
   `.onMoveCommand`.** In the instrumented run, **14 presses produced 14 move commands — one per
   press, no exceptions** — covering all 7 presses where focus could not move *and* all 7 where it
   could. A second instrumented run added 8 more presses and 8 more commands.
3. **It is delivered via `.onMoveCommand`, so no alternative capture mechanism was tried** — the step
   said to note it and stop if `.onMoveCommand` did not deliver, and it does. `UIFocusGuide`, a
   window-level press recognizer and a focusable edge affordance (Pass 75 §5.3) remain unmeasured.

**And the answer to the question the step did not ask, which is where focus goes at the edge:
nowhere.** Twelve edge presses across three rows left focus on the same element with the same frame
every time — **not** the `+12h` pill, **not** another row, **not** the rail, **not** nothing. A Left
press immediately after each run moved focus, which proves the remote and the focus engine were both
alive for the presses that did nothing.

### 1.1 Three things a build must know, and they are not what "the app sees the press" implies

- **`.onMoveCommand` fires identically whether or not focus moved**, so it cannot tell the app that a
  press was refused. **Edge-ness is the app's own to determine** — it can, from `focused` against the
  last id of `cells(for:)` for that row (`GuideScreen.swift:153-163`), but it must.
- **The command reaches the innermost registered handler only.** Two instances were attached, one on
  the grid's `ScrollView` and one on the screen's root `ZStack`. **All 22 commands across both
  instrumented runs came from the grid instance; not one came from the root.** A handler attached too
  high sees nothing and reads exactly like "tvOS never delivered it".
- **The `@FocusState` write and the command delivery race, so the app's own "did focus move?" reading
  is unsafe.** Measured: **6 of the 7 moving presses delivered the command *after* the focus write**
  (the handler therefore compared the post-move value against itself and reported `moved=false` when
  focus had in fact moved); **1 arrived before it** and reported `moved=true`. The value read at
  **+250 ms was correct in all 14 cases**; the value at receipt was not. Anything built on this must
  read the settled value.

**`.onMoveCommand` did not change behaviour, and that was controlled for.** The instrumented arm
reproduced the uninstrumented arm **element for element and frame for frame** — same opening cell
`(554,228 637x82)`, same single moving press to `(1203,228 637x82)`, same edge, same three dead
presses, same Left control, and the same five-row survey ending on the 1286 pt cell. It is an
observer, not a consumer.

---

## 2. How it was measured

**Three device runs on Home Theater (Apple TV 4K, 3rd generation, tvOS 26.6), real Siri Remote.**
The pass was split into arms because one run cannot answer both questions: if `.onMoveCommand` had
*consumed* the move, the walk could not have been measured with it attached, and "Right does not walk
a row" would have been indistinguishable from "the instrument ate it".

| Run | App build | Harness | Purpose |
|---|---|---|---|
| **A** | focus-change logging only | `testRightAlongTheFirstRowAndThreePressesPastTheEdge`, `testRightOnACellThatFillsTheWindow` | the baseline, with zero instrument risk |
| **B** | A **plus** two `.onMoveCommand` instances | the same two tests | does the app see the press; did the instrument change anything |
| **C** | same build as B | `testRightAlongARowOfHalfHourCells` (added) | a second row, because row 0 held only two cells so answer 1 rested on a single moving press |

Each run: `xcodebuild build-for-testing` → `devicectl device install app` →
`devicectl device process launch --console --terminate-existing` in the background →
`xcodebuild test-without-building`. The console launch is the `CommercialSkipUITests` pattern and the
reason the harness uses `activate()` rather than `launch()`: XCUITest does not forward the app's
`print` output (COLD-START, Pass 38), so a `launch()` would kill the console and take the `[probe]`
lines with it.

**All five test executions passed.** A `[probe]`-line count equal to the press count in every run is
the evidence that **no console line was dropped** — the failure mode Pass 38 warned about.

| Run | Presses driven | `move` commands logged | Match |
|---|---|---|---|
| A | 6 right, 2 left, 4 down | (no `.onMoveCommand` in this build) | — |
| B | 8 right, 2 left, 4 down = **14** | **14** | exact |
| C | 4 right, 2 left, 1 down, 1 right-to-reenter = **8** | **8** | exact |

---

## 3. VERIFY — the harness's focused-element output, per press, verbatim

### 3.1 Run A (no `.onMoveCommand`) — the baseline

```
[pass76 08:11:21.539] OPEN zone=grid:programme-cell
[pass76 08:11:22.524] OPEN focus: 9:“Good Morning America” (554,228 637x82)
[pass76 08:11:23.883] OPEN the Guide focused “Good Morning America” (554,228 637x82)
[pass76 08:11:30.432] WALK press #1 RIGHT zone=grid:programme-cell moved=true
[pass76 08:11:30.433] WALK   before: 9:“Good Morning America” (554,228 637x82)
[pass76 08:11:30.433] WALK   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:35.402] WALK press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:11:35.402] WALK   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:35.402] WALK   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:36.012] WALK press #2 changed nothing — this is the edge
[pass76 08:11:36.266] RESULT cells walked before the edge: 1 (presses 1…1 each moved focus)
[pass76 08:11:36.267] RESULT zones in order: grid:programme-cell -> grid:programme-cell -> grid:programme-cell
[pass76 08:11:41.092] EDGE press #1 RIGHT zone=grid:programme-cell moved=false
[pass76 08:11:41.092] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:41.093] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:45.400] EDGE press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:11:45.400] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:45.401] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:49.890] EDGE press #3 RIGHT zone=grid:programme-cell moved=false
[pass76 08:11:49.890] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:49.891] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:51.666] EDGE after three more Right presses: zone=grid:programme-cell focus=9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:56.368] CONTROL press #1 XCUIRemoteButton(rawValue: 2) zone=grid:programme-cell moved=true
[pass76 08:11:56.369] CONTROL   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:11:56.369] CONTROL   after : 9:“Good Morning America” (554,228 637x82)
[pass76 08:11:57.154] CONTROL Left from the edge: zone=grid:programme-cell
[pass76 08:12:27.725] OPEN focus: 9:“Good Morning America” (554,228 637x82)
[pass76 08:12:29.973] SURVEY row 0: “Good Morning America” (554,228 637x82)
[pass76 08:12:33.326] SURVEY row 1: “Today” (554,322 315x82)
[pass76 08:12:36.452] SURVEY row 2: “Today” (554,416 315x82)
[pass76 08:12:39.557] SURVEY row 3: “WJZ Saturday News at 8AM” (554,510 637x82)
[pass76 08:12:42.668] SURVEY row 4: “Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:43.287] SURVEY row 4 fills the window: width 1286 pt > 1200
[pass76 08:12:45.172] FULL before: zone=grid:programme-cell focus=9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:50.040] FULL press #1 RIGHT zone=grid:programme-cell moved=false
[pass76 08:12:50.041] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:50.041] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:54.405] FULL press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:12:54.406] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:54.406] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:58.840] FULL press #3 RIGHT zone=grid:programme-cell moved=false
[pass76 08:12:58.841] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:12:58.841] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:13:00.857] FULL after three Right presses: zone=grid:programme-cell focus=9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:13:05.721] FULLCONTROL press #1 XCUIRemoteButton(rawValue: 2) zone=grid:channel-cell moved=true
[pass76 08:13:05.721] FULLCONTROL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:13:05.721] FULLCONTROL   after : 9:“WB, WBFF45, 45.1” (236,604 300x82)
[pass76 08:13:06.326] FULLCONTROL Left from it: zone=grid:channel-cell
```

**Reading it:** the Guide opened on `Good Morning America` at `(554,228 637x82)`. `WALK press #1`
moved focus to `(1203,228 637x82)` — the next cell, same row. `WALK press #2` changed nothing, and so
did `EDGE` presses #1, #2 and #3. `CONTROL` (Left) moved focus back to `(554,228)`. The survey then
walked five rows and found row 4's single cell at `(554,604 1286x82)` — the full 1286 pt programme
area — and three Right presses on it moved nothing, while Left moved to the channel cell at
`(236,604 300x82)`.

### 3.2 Run B (with `.onMoveCommand`) — the control for the instrument

```
[pass76 08:15:44.756] OPEN zone=grid:programme-cell
[pass76 08:15:45.985] OPEN focus: 9:“Good Morning America” (554,228 637x82)
[pass76 08:15:47.238] OPEN the Guide focused “Good Morning America” (554,228 637x82)
[pass76 08:15:54.245] WALK press #1 RIGHT zone=grid:programme-cell moved=true
[pass76 08:15:54.245] WALK   before: 9:“Good Morning America” (554,228 637x82)
[pass76 08:15:54.245] WALK   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:15:59.271] WALK press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:15:59.271] WALK   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:15:59.271] WALK   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:15:59.776] WALK press #2 changed nothing — this is the edge
[pass76 08:16:00.022] RESULT cells walked before the edge: 1 (presses 1…1 each moved focus)
[pass76 08:16:00.022] RESULT zones in order: grid:programme-cell -> grid:programme-cell -> grid:programme-cell
[pass76 08:16:04.688] EDGE press #1 RIGHT zone=grid:programme-cell moved=false
[pass76 08:16:04.688] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:04.689] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:09.516] EDGE press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:16:09.517] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:09.517] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:13.886] EDGE press #3 RIGHT zone=grid:programme-cell moved=false
[pass76 08:16:13.886] EDGE   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:13.886] EDGE   after : 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:15.880] EDGE after three more Right presses: zone=grid:programme-cell focus=9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:20.656] CONTROL press #1 XCUIRemoteButton(rawValue: 2) zone=grid:programme-cell moved=true
[pass76 08:16:20.657] CONTROL   before: 9:“Good Morning America” (1203,228 637x82)
[pass76 08:16:20.657] CONTROL   after : 9:“Good Morning America” (554,228 637x82)
[pass76 08:16:21.446] CONTROL Left from the edge: zone=grid:programme-cell
[pass76 08:16:51.800] OPEN focus: 9:“Good Morning America” (554,228 637x82)
[pass76 08:16:54.301] SURVEY row 0: “Good Morning America” (554,228 637x82)
[pass76 08:16:57.686] SURVEY row 1: “Today” (554,322 315x82)
[pass76 08:17:00.814] SURVEY row 2: “Today” (554,416 315x82)
[pass76 08:17:03.938] SURVEY row 3: “WJZ Saturday News at 8AM” (554,510 637x82)
[pass76 08:17:07.203] SURVEY row 4: “Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:08.020] SURVEY row 4 fills the window: width 1286 pt > 1200
[pass76 08:17:10.065] FULL before: zone=grid:programme-cell focus=9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:14.739] FULL press #1 RIGHT zone=grid:programme-cell moved=false
[pass76 08:17:14.739] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:14.739] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:19.281] FULL press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:17:19.282] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:19.282] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:23.580] FULL press #3 RIGHT zone=grid:programme-cell moved=false
[pass76 08:17:23.581] FULL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:23.581] FULL   after : 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:25.415] FULL after three Right presses: zone=grid:programme-cell focus=9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:30.171] FULLCONTROL press #1 XCUIRemoteButton(rawValue: 2) zone=grid:channel-cell moved=true
[pass76 08:17:30.171] FULLCONTROL   before: 9:“Fox 45 Morning News” (554,604 1286x82)
[pass76 08:17:30.171] FULLCONTROL   after : 9:“WB, WBFF45, 45.1” (236,604 300x82)
[pass76 08:17:30.685] FULLCONTROL Left from it: zone=grid:channel-cell
```

**Identical to run A in every frame.** Same opening cell, same one moving press, same edge at press
#2, same three dead presses, same survey rows 0-4, same 1286 pt cell, same controls.

### 3.3 Run C — a second row

```
[pass76 08:20:51.432] ROW1 after Down: 9:“Today” (554,322 315x82)
[pass76 08:20:55.263] ROW1 at the channel cell: 9:“WG, WGAL-TV, 8.1” (236,322 300x82)
[pass76 08:20:58.906] ROW1 first cell: “Today” (554,322 315x82)
[pass76 08:21:04.894] ROW1WALK press #1 RIGHT zone=grid:programme-cell moved=true
[pass76 08:21:04.895] ROW1WALK   before: 9:“Today” (554,322 315x82)
[pass76 08:21:04.895] ROW1WALK   after : 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:09.303] ROW1WALK press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:21:09.304] ROW1WALK   before: 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:09.304] ROW1WALK   after : 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:09.304] ROW1WALK press #2 changed nothing — this is the edge after 1 moving press(es)
[pass76 08:21:10.104] ROW1 RESULT 1 moving Right press(es), then the edge; zone=grid:programme-cell
[pass76 08:21:14.532] ROW1EDGE press #1 RIGHT zone=grid:programme-cell moved=false
[pass76 08:21:14.532] ROW1EDGE   before: 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:14.532] ROW1EDGE   after : 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:18.995] ROW1EDGE press #2 RIGHT zone=grid:programme-cell moved=false
[pass76 08:21:18.996] ROW1EDGE   before: 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:18.996] ROW1EDGE   after : 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:20.664] ROW1EDGE after two more: zone=grid:programme-cell focus=9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:25.233] ROW1CONTROL press #1 XCUIRemoteButton(rawValue: 2) zone=grid:programme-cell moved=true
[pass76 08:21:25.233] ROW1CONTROL   before: 9:“News 8 Today/Weekend” (881,322 958x82)
[pass76 08:21:25.233] ROW1CONTROL   after : 9:“Today” (554,322 315x82)
```

**Reading it:** row 8.1 also held two visible cells — `Today` at `(554,322 315x82)`, clipped at the
left edge (it starts at 07:00, the window starts at 08:00), and `News 8 Today/Weekend` at
`(881,322 958x82)`, clipped at the right. 315 + 12 + 958 = 1285 ≈ the 1286 pt programme area, which
is Pass 75 §2.1's frame arithmetic confirmed from the device. One moving Right press, then the edge,
then two dead presses, then Left moved back.

---

## 4. VERIFY — the device console `[probe]` lines, verbatim

Filtered to `[probe]` only; the launch ping line is deliberately excluded (§Redaction).

### 4.1 Run A

```
[probe] focus nil -> hdhr-10a75953:2.1@1789214400
[probe] focus hdhr-10a75953:2.1@1789214400 -> hdhr-10a75953:2.1@1789218000
[probe] focus hdhr-10a75953:2.1@1789218000 -> hdhr-10a75953:2.1@1789214400
[probe] focus nil -> hdhr-10a75953:2.1@1789214400
[probe] focus hdhr-10a75953:2.1@1789214400 -> hdhr-10a75953:8.1@1789210800
[probe] focus hdhr-10a75953:8.1@1789210800 -> hdhr-10a75953:11.1@1789210800
[probe] focus hdhr-10a75953:11.1@1789210800 -> hdhr-10a75953:13.1@1789214400
[probe] focus hdhr-10a75953:13.1@1789214400 -> hdhr-10a75953:45.1@1789210800
[probe] focus hdhr-10a75953:45.1@1789210800 -> ch:hdhr-10a75953:45.1
```

Nine lines. **The only focus changes are the ones the harness saw move** — the `.task` assignment,
the one moving Right press (`@1789214400` → `@1789218000`), the Left control, then the second test's
`.task`, its four Down presses, and its Left control. **There is no line for any of the six Right
presses that the harness read as not moving.**

### 4.2 Run B

```
[probe] focus nil -> hdhr-10a75953:2.1@1789214400
[probe] focus hdhr-10a75953:2.1@1789214400 -> hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right before=hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right settled before=hdhr-10a75953:2.1@1789218000 after=hdhr-10a75953:2.1@1789218000 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right settled before=hdhr-10a75953:2.1@1789218000 after=hdhr-10a75953:2.1@1789218000 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right settled before=hdhr-10a75953:2.1@1789218000 after=hdhr-10a75953:2.1@1789218000 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right settled before=hdhr-10a75953:2.1@1789218000 after=hdhr-10a75953:2.1@1789218000 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:2.1@1789218000
[probe] move site=grid dir=right settled before=hdhr-10a75953:2.1@1789218000 after=hdhr-10a75953:2.1@1789218000 moved=false
[probe] focus hdhr-10a75953:2.1@1789218000 -> hdhr-10a75953:2.1@1789214400
[probe] move site=grid dir=left before=hdhr-10a75953:2.1@1789214400
[probe] move site=grid dir=left settled before=hdhr-10a75953:2.1@1789214400 after=hdhr-10a75953:2.1@1789214400 moved=false
[probe] focus nil -> hdhr-10a75953:2.1@1789214400
[probe] focus hdhr-10a75953:2.1@1789214400 -> hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=down before=hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=down settled before=hdhr-10a75953:8.1@1789210800 after=hdhr-10a75953:8.1@1789210800 moved=false
[probe] focus hdhr-10a75953:8.1@1789210800 -> hdhr-10a75953:11.1@1789210800
[probe] move site=grid dir=down before=hdhr-10a75953:11.1@1789210800
[probe] move site=grid dir=down settled before=hdhr-10a75953:11.1@1789210800 after=hdhr-10a75953:11.1@1789210800 moved=false
[probe] move site=grid dir=down before=hdhr-10a75953:11.1@1789210800
[probe] focus hdhr-10a75953:11.1@1789210800 -> hdhr-10a75953:13.1@1789214400
[probe] move site=grid dir=down settled before=hdhr-10a75953:11.1@1789210800 after=hdhr-10a75953:13.1@1789214400 moved=true
[probe] focus hdhr-10a75953:13.1@1789214400 -> hdhr-10a75953:45.1@1789210800
[probe] move site=grid dir=down before=hdhr-10a75953:45.1@1789210800
[probe] move site=grid dir=down settled before=hdhr-10a75953:45.1@1789210800 after=hdhr-10a75953:45.1@1789210800 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:45.1@1789210800
[probe] move site=grid dir=right settled before=hdhr-10a75953:45.1@1789210800 after=hdhr-10a75953:45.1@1789210800 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:45.1@1789210800
[probe] move site=grid dir=right settled before=hdhr-10a75953:45.1@1789210800 after=hdhr-10a75953:45.1@1789210800 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:45.1@1789210800
[probe] move site=grid dir=right settled before=hdhr-10a75953:45.1@1789210800 after=hdhr-10a75953:45.1@1789210800 moved=false
[probe] focus hdhr-10a75953:45.1@1789210800 -> ch:hdhr-10a75953:45.1
[probe] move site=grid dir=left before=ch:hdhr-10a75953:45.1
[probe] move site=grid dir=left settled before=ch:hdhr-10a75953:45.1 after=ch:hdhr-10a75953:45.1 moved=false
```

### 4.3 Run C

```
[probe] focus nil -> hdhr-10a75953:2.1@1789214400
[probe] focus hdhr-10a75953:2.1@1789214400 -> hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=down before=hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=down settled before=hdhr-10a75953:8.1@1789210800 after=hdhr-10a75953:8.1@1789210800 moved=false
[probe] focus hdhr-10a75953:8.1@1789210800 -> ch:hdhr-10a75953:8.1
[probe] move site=grid dir=left before=ch:hdhr-10a75953:8.1
[probe] move site=grid dir=left settled before=ch:hdhr-10a75953:8.1 after=ch:hdhr-10a75953:8.1 moved=false
[probe] move site=grid dir=right before=ch:hdhr-10a75953:8.1
[probe] focus ch:hdhr-10a75953:8.1 -> hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=right settled before=ch:hdhr-10a75953:8.1 after=hdhr-10a75953:8.1@1789210800 moved=true
[probe] focus hdhr-10a75953:8.1@1789210800 -> hdhr-10a75953:8.1@1789216200
[probe] move site=grid dir=right before=hdhr-10a75953:8.1@1789216200
[probe] move site=grid dir=right settled before=hdhr-10a75953:8.1@1789216200 after=hdhr-10a75953:8.1@1789216200 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:8.1@1789216200
[probe] move site=grid dir=right settled before=hdhr-10a75953:8.1@1789216200 after=hdhr-10a75953:8.1@1789216200 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:8.1@1789216200
[probe] move site=grid dir=right settled before=hdhr-10a75953:8.1@1789216200 after=hdhr-10a75953:8.1@1789216200 moved=false
[probe] move site=grid dir=right before=hdhr-10a75953:8.1@1789216200
[probe] move site=grid dir=right settled before=hdhr-10a75953:8.1@1789216200 after=hdhr-10a75953:8.1@1789216200 moved=false
[probe] focus hdhr-10a75953:8.1@1789216200 -> hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=left before=hdhr-10a75953:8.1@1789210800
[probe] move site=grid dir=left settled before=hdhr-10a75953:8.1@1789210800 after=hdhr-10a75953:8.1@1789210800 moved=false
```

**Reading 4.2 and 4.3 together.** Every `move site=grid dir=…` pair is one press. Counting them
against the harness gives 14 and 8 — one per press, including the moving ones. `dir=right` appears
for the press that moved focus as well as for the ones that did not. **`site=root` appears nowhere in
either run.** And the ordering varies: at
`move site=grid dir=down before=hdhr-10a75953:11.1@1789210800` the command arrived *before* the focus
write and the settled line reports `moved=true`, while every other moving press has its `focus …→…`
line *above* its `move` line and therefore reports `moved=false` — the race described in §1.1.

---

## 5. The diagnostic's exact diff, so it is on record

This is what was added to `Marlin DVR TV/GuideScreen.swift` for run B and run C, and what
`git checkout --` removed before the commit. Run A was the `.onChange(of: focused)` hunk alone.

```diff
diff --git a/Marlin DVR TV/GuideScreen.swift b/Marlin DVR TV/GuideScreen.swift
index 9854c36..2e72cd7 100644
--- a/Marlin DVR TV/GuideScreen.swift	
+++ b/Marlin DVR TV/GuideScreen.swift	
@@ -304,6 +304,8 @@ struct GuideScreen: View {
                     .padding(.vertical, 6)
                 }
                 .disabled(model.sheet != nil || channelMenu != nil || collectionsOpen)
+                // [probe] Pass 76 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+                .onMoveCommand { direction in probeMove("grid", direction) }
                 legend
                     .padding(.top, 16)
             }
@@ -341,12 +343,18 @@ struct GuideScreen: View {
                 )
             }
         }
+        // [probe] Pass 76 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+        // Two attachment points, same modifier, so a silent "grid" instance cannot be mistaken for
+        // "tvOS never delivered the press".
+        .onMoveCommand { direction in probeMove("root", direction) }
         .defaultFocus($focused, "loading")
         .task {
             await model.loadNow()
             focusSoon { focused = firstCellID ?? "collections" }
         }
-        .onChange(of: focused) { _, new in
+        .onChange(of: focused) { old, new in
+            // [probe] Pass 76 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+            print("[probe] focus \(old ?? "nil") -> \(new ?? "nil")")
             if let new, new.contains("@") { lastCell = new }
         }
         .onChange(of: hold.holds) { _, _ in handleHold() }
@@ -373,6 +381,19 @@ struct GuideScreen: View {
         }
     }
 
+    // [probe] Pass 76 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+    /// (a) the direction received, (b) the focused cell id before and 250 ms after the press,
+    /// (c) whether the focus engine moved focus. Prints only; changes no state and no layout.
+    private func probeMove(_ site: String, _ direction: MoveCommandDirection) {
+        let before = focused ?? "nil"
+        print("[probe] move site=\(site) dir=\(direction) before=\(before)")
+        Task {
+            try? await Task.sleep(for: .milliseconds(250))
+            let after = focused ?? "nil"
+            print("[probe] move site=\(site) dir=\(direction) settled before=\(before) after=\(after) moved=\(before != after)")
+        }
+    }
+
     /// Menu on the overlay: it closes and nothing changes.
     private func closeCollections() {
         collectionsOpen = false
```

**Two attachment points, one modifier.** The step named `.onMoveCommand` as the mechanism to
instrument; attaching it at two sites was a guard against a placement false negative, not a second
mechanism — and it earned its place, because the root instance never fired (§1.1). **Adding
`.onMoveCommand` is itself the instrument and could in principle have altered focus movement**, which
is exactly why run A exists and why §1's control paragraph is part of the answer rather than an aside.

**It changed no layout and no state.** `probeMove` only reads `focused` and prints. The build added
**no new warning**: the reverted tree builds with the same two warnings it had before —
`PlayerModel.swift:325` (`nominalFrameRate` deprecated in tvOS 16.0) and `GuideScreen.swift:400`
(`channelFocusID` in a synchronous nonisolated context) — both pre-existing and both untouched.

---

## 6. Files touched, mapped to step numbers

| File | Step(s) | What |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | **1** | the `[probe]` diagnostic — **added, used, and reverted with `git checkout --` before the commit.** Not in the commit; its diff is §5 |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | **2** | **new** — the device harness, three tests. Test target only; nothing in the app target |
| `DECISIONS.md` | **5** | a new dated entry, **47 insertions, 0 deletions** |
| `COLD-START.md` | **5** | the Pass 76 entry, the citation-drift block, and a new first paragraph under "Next step" — **55 insertions, 0 deletions** |
| `reports/2026-09-12-pass76-right-edge-probe.md` | REPORT | this file |

**Not touched:** every other Swift file in both targets, the Xcode project file (both targets are
filesystem-synchronised groups, so the new test file needs no project edit), `Info.plist`, the
entitlements file, every build setting, the asset catalog, `design/`, `icon-source/`,
`~/Xcode/marlin-dvr-reference`, and every earlier report. **No new dependency, no refactor, no config
change, and no test-only code in the app target.**

### 6.1 Step 5's citation corrections

The six drifts Pass 75 listed are corrected in `COLD-START.md` as one-line additions naming the old
and the new numbers, under a heading that says so. **The drifted comment lines themselves are not
edited** — the step forbade it, and this project does not rewrite written history to match a later
reading (DECISIONS.md, 2026-09-09 (Pass 56)). Each was re-verified against `HEAD` after the
diagnostic was reverted, so the numbers are the shipped ones:

| Citing site | Says | Is |
|---|---|---|
| `GuideScreen.swift:21` | `ScreenShell.swift:55` | **`:57`** |
| `GuideSearchScreen.swift:46` | `ScreenShell.swift:51` | **`:57`** |
| `GuideSearchScreen.swift:301` | `ScreenShell.swift:51` | **`:57`** |
| `AiringSheet.swift:76` | `Models.swift:170` | **`Models.swift:288`** |
| `AiringSheet.swift:77` | `GuideScreen.swift:173-178` | **`:193-198`** |
| `GuideSearchScreen.swift:170` | `GuideScreen.swift:145-147`, `:162-168` | **`:182-188`** and **`:165-167`** |
| `GuideSearchScreen.swift:282` | `GuideScreen.swift:318-323` | **`:359-364`** |

That is seven rows for six listed drifts because Pass 75 grouped `GuideSearchScreen.swift:46` and
`:301` into one row; they are two separate comments and are listed separately here.

---

## 7. VERIFY — the revert

```
$ git checkout -- "Marlin DVR TV/GuideScreen.swift"

$ git diff HEAD --stat -- "Marlin DVR TV"
(empty)

$ git diff HEAD --stat
(empty — before the notebook was edited)

$ grep -rn "\[probe\]\|probeMove\|onMoveCommand" "Marlin DVR TV"/*.swift
(no output)
```

**Every probe and scratch file is outside the repo.** The three console logs, the three test logs,
the saved diagnostic copy and the saved diff live in the session scratchpad, not in the working tree.
The two derived-data directories this pass created under `build/` were removed
(`build/p76check` deleted; `build/p76` is the test build and `build/` is `.gitignore`d at line 4).
`git status` shows only `icon-source/` — the standing untracked baseline — plus this pass's own
tracked additions.

---

## 8. Raised, not acted on

1. **The owner has still chosen no mechanism.** This pass measured; it built nothing and proposes
   nothing. Pass 75 §5's three families are all still open, and (b) — the existing window advanced a
   slot at a time — is now the only one whose press capture is **known to work**.
2. **`.onMoveCommand` is `@available(tvOS 13.0, *)` and iOS-unavailable** (Pass 75 §5.3,
   `SwiftUI.swiftinterface:12271-12293`). Nothing in this app used it before this pass, and after the
   revert nothing does again. If it is adopted, it becomes the app's **only** use of the modifier.
3. **Auto-repeat was not measured.** The owner's goal says the window "keeps moving as long as there
   are listings", which implies a held Right. Every press here was a discrete `XCUIRemote.press`.
   **Whether a held Right produces repeated move commands, and at what rate, is unmeasured** — and it
   matters, because a re-render per repeat is the cost Pass 75 could not time.
4. **The three rows measured all held exactly two visible cells.** That is the owner's guide at 08:00
   on a Saturday, not a property of the Guide. A row with four or five cells would give more moving
   presses, and none was measured.
5. **`COLD-START.md` is not corrected for a build-warning claim, because that was not in scope.**
   The Pass 72 report §1 step 1 says *"The build is clean: zero deprecation warnings"*. Measured here
   at `HEAD`: there are **two** warnings, one of them a deprecation
   (`PlayerModel.swift:325`, `nominalFrameRate`). Pass 72's claim was about warnings *its* change
   added, and in that narrow sense it stands — but "zero deprecation warnings" is not true of the
   build as a whole. **Reported as a question rather than edited**, since step 5 named only the six
   citation drifts.
6. **`icon-source/` is still 32 untracked entries**, the owner's undecided call
   (`DECISIONS.md`, 2026-09-08). Restated so it is not mistaken for drift.

---

## 9. The things I am least sure of

1. **That `.onMoveCommand` fires for a press the focus engine refuses *because* it was refused, and
   not for some other reason I have not separated.** What I measured is that it fires for **every**
   directional press — moving and non-moving alike, 22 of 22. That is a stronger and simpler result
   than "it fires at the edge", and it is what the log shows. But it means I have **not** isolated
   edge behaviour at all: I have shown the modifier is indifferent to it. If a build needs "tell me
   when the press was refused", this pass proves the platform will not tell it.
2. **That the +250 ms settle window is long enough in general.** It was correct in all 14 cases here,
   on an idle Guide with the rows already realised. I did not test it under a reload, with the
   collections overlay closing, or on the slower Apple TV in the bedroom — and the one press that
   delivered before the focus write shows the ordering is genuinely a race rather than a rule. A
   build that picks a delay from this number is picking it from fourteen samples on one device.
3. **That "Right walks a row cell by cell" generalises beyond two-cell rows.** Four moving Right
   transitions were observed, all on rows with exactly two visible cells, and one of those four was
   channel-cell → first-cell rather than cell → cell. I believe a four-cell row behaves the same and
   nothing in `GuideRowView` suggests otherwise, but I measured the two-cell case three times rather
   than the general case once.

---

## 10. SCOPE CHECK — every path touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md`, `reports/2026-09-12-pass75-guide-scroll-recon.md` | read | required reading |
| `Marlin DVR TV/GuideScreen.swift` | **written, then reverted** | 1, 4 |
| `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` | **created** | 2 |
| `COLD-START.md`, `DECISIONS.md` | **appended to, additions only** | 5 |
| `reports/2026-09-12-pass76-right-edge-probe.md` | **created** | REPORT |
| Home Theater (Apple TV 4K, tvOS 26.6) | **three installs, three console launches, five test executions** | 2 |
| `build/p76`, `build/p76check` | derived data, `.gitignore`d; `p76check` deleted | 2 |
| the session scratchpad | six logs, the diagnostic copy, its diff | 2, 5 |
| `http://192.168.1.250:8090/` | **no request by hand.** The app's own GETs plus its standing launch ping | 2 |
| `~/Xcode/marlin-dvr-reference`, `design/` | **not opened** | — |

**Not touched:** Unraid as a host, marlinpc `192.168.1.245`, the HDHomeRun `192.168.1.105`, the
UNAS4Pro share, the Master Bedroom Apple TV, every other folder under `~/Xcode`, and every earlier
report.

---

## 11. Git

One commit on `main` on top of `fce20c2`: the harness, the two notebook files and this report
together, per the Pass 68 rule that a pass's report goes inside its own commit. **The diagnostic is
not in it** — it was reverted first, and §7 is the proof.

The three SHAs (`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`) are
verified after a fresh `git fetch origin` and reported in this pass's response, because a commit
cannot contain its own hash (`DECISIONS.md` 2026-09-09 (Pass 60) rule (b)).

**Nothing forced. No history rewritten. No branch other than `main`.**
