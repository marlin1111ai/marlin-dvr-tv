# Pass 119 — REVIEW.md's fifteen "should fix" items and the Guide's Left back-step, sorted for building

**Date:** 2026-09-24 (begun late on 2026-09-23)
**READ-ONLY for the app.** No app-target file, test-target file, project file, scheme, `design/` file,
`REVIEW.md` or existing report was changed. Nothing was built, installed, launched or tested, and
neither Apple TV was touched. **No request of any kind went to the Marlin DVR server or any other host
on the LAN.** `icon-source/` was not touched. marlin-dvr was not cloned: its source was read from
GitHub at `0fa05e1` through `gh api`, printed to the terminal only, with nothing written to disk (§4).

**HEAD every `file:line` below was read at: `33666a244c6f0b9e35c61d40904aa9db58eb67a0`.** That commit
adds `REVIEW.md` alone on top of `e7dc4c8`, so every app, test and project file is byte-identical to
what REVIEW.md reviewed. Line numbers drift, and comments and reports are never rewritten
(COLD-START.md:81).

**Nothing here is built, proposed or ranked beyond the sort the pass asked for.** The sixteen items
are the owner's pick of 2026-09-23: REVIEW.md's S1, S2 and S4–S16, and item G. No other REVIEW.md
finding is sorted, re-reported or proposed. Where a reader found something next to an item, it
appears only if it bears on that item's (a)–(f).

---

## How the sort was made

Two read-only rounds.

- **Round one.** Eight readers each took two items, grouped by the code they touch: G with S11, S1
  with S2, S4 with S16, S5 with S6, S7 with S8, S9 with S14, S10 with S13, S12 with S15. Each read the
  code at HEAD and grepped the whole notebook (COLD-START, DECISIONS, COLD-START-HISTORY, every report).
  A ninth reader swept the notebook for all sixteen items independently of the others, looking for
  records the fixes would change and records that mark a touched path fragile or load-bearing.
- **Round two.** Eight verifiers, one per pair, were told to refute round one. Each reopened every
  cited line, checked each notebook quote verbatim at its line, and judged SWEEP or STANDALONE against
  the definition. Each owner question had to pass three tests: only the owner can answer it; the
  answer changes what gets built for that item; and neither the item's own text, REVIEW.md's fix nor
  the notebook already answers it.

**What round two changed:**
- **S1** moved from STANDALONE to **SWEEP**. No notebook record calls the scheme or the
  `-only-testing` run path fragile or load-bearing.
- **S11** moved from SWEEP to **STANDALONE**. A plain discard of stale answers would break Pass 116's
  owner-accepted "no notice is coalesced away".
- **Four of the five owner questions were dropped.** G's two: G's own text settles the trigger, and
  the footer is not part of G. S5's: the owner has already picked S5 to build. S13's is kept, reworded.
- Several conflict quotes were added or removed. The final lists are in §3.

My own read of the Guide, ScreenShell, the scheme and ten cited lines agrees with the verified result.

---

## 1. Step 1 — the state before anything changed

- `git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and
  `git ls-remote origin main` all read **`33666a244c6f0b9e35c61d40904aa9db58eb67a0`**.
  `git rev-list --left-right --count main...origin/main` was `0 0`.
  `git status --porcelain` showed only `?? icon-source/`. **No stop condition.**
- **`33666a2` is REVIEW.md alone.** `git show --stat` lists one file, `REVIEW.md`, with 248
  insertions. Its one parent is **`e7dc4c8`** (`e7dc4c88e55b8578aaa1913e2f7e9bcb24ffa566`), Pass 118's
  commit, and `git merge-base --is-ancestor e7dc4c8 origin/main` succeeds.

---

## 2. The sort

### SWEEP — independent and additive (12)

- **S1** — one scheme attribute, or an opt-in in a few harness `setUp`s. No record marks the scheme or
  the run path fragile. The one unknown is option A's effect on `-only-testing` (§3).
- **S2** — one guard at `ShowDetailSeriesPassUITests.swift:246-248`, in the test target only.
- **S4** — one function, `WeatherLocation.start()` (`:90-115`). No record marks the location path
  fragile. Same state machine as S16.
- **S7** — two modifiers and a focus fallback in two list views. It copies Pass 33's
  device-measured Trash fix under the standing rule at DECISIONS.md:407-409. Goes with S8.
- **S8** — error state on the failure path only, copying the Trash pattern already in the same file.
  It adds no read, timer or retry, so Pass 106's A5 stands. Goes with S7.
- **S9** — one change inside `ShowDetailModel` (`ShowDetailScreen.swift:74-81` or `:211`). The one
  load-bearing neighbour, `PlayRequest.id`, is untouched.
- **S10** — query-value encoding in four builders. No record marks them fragile. The Pass 86 logo
  bytes constrain it only if the Go escaper is moved.
- **S12** — one file, the info panel's own reload path (`PlayerInfoPanel.swift:233`, `:494-506`).
  The notebook records that path as code-traced only, never as fragile.
- **S13** — two lines in `AiringSheet.swift` (`:150`, `:169`). No record marks the sheet's re-reads
  fragile. The one owner question (§5) is S13's.
- **S14** — one file, copying On Now's measured 60 s reload (`OnNowScreen.swift:167-179`). The Pass
  25 and Pass 31 focus rules are properties it keeps, not code it edits.
- **S15** — confined to CameraCard (`CamerasScreen.swift:127-135`). Done in the shared `ServerImage`
  instead, it would reach 14 other callers and Pass 86/87's accepted fallback, and would be out of
  scope.
- **S16** — a flag reset in `WeatherLocation.swift` (`:127-128`, `:166-174`), keeping the recorded
  25 s timeout. Same state machine as S4.

### STANDALONE — touches a recorded fragile or load-bearing path, or plainly hard (4)

- **G** — press handling rebuilt on Pass 77's settle rule (DECISIONS.md:1196-1197). Nothing at HEAD can
  stop the grid-to-rail move (DECISIONS.md:1182, :1199-1200). A block at the shell would touch Pass
  25's `railRestore` (DECISIONS.md:245-247; 27 of 27, COLD-START.md:58).
- **S5** — edits the save in `restart(at:)`. The notebook records that path as "the reason the restart
  path is sorted STANDALONE rather than swept" (DECISIONS.md:1903-1905) and as "the session-teardown
  path Pass 39 named the Player's most fragile area"
  (`reports/2026-09-16-pass95-resume-rewind-recon.md:46-47`). The load-bearing `position = target`
  (`PlayerModel.swift:845`) is in the same function.
- **S6** — `frameStep` is the Player's in-item seek, "the Player's seek path, which the prompt names
  as automatically standalone" (`reports/2026-09-08-pass39-three-defects-recon.md:547`). The declined
  click then rests on `armArrowOwnership`'s recorded dependency on AVPlayerViewController internals
  (DECISIONS.md:288-290).
- **S11** — the guard sits on `fetch`'s landing lines (`GuideScreen.swift:234-238`). Pass 116 put the
  override clear there "in the same turn the new rows are stored … not before"
  (`reports/2026-09-19-pass116-guide-live-redraw.md:71-73`), and those lines carry the owner-accepted
  "no notice is coalesced away" (DECISIONS.md:2875-2877). A plain discard breaks that (§3).

### Items that share code (a fact for whoever schedules the builds, not a ranking)

- **G and S11**: both touch `GuideModel`'s window writes and `fetch` (`GuideScreen.swift:134-252`).
  G adds a backward window write and, below `fetchStart`, one read per press. S11's staleness test
  must cover it.
- **S4 and S16**: the same state machine in `WeatherLocation.swift`. Making them one change is the
  builder's call.
- **S7 and S8**: the same two empty-sentence blocks (`ScheduleManageView.swift:113-118`,
  `PassesManageView.swift:75-80`). Whatever S8 shows on a failed read must be S7's focusable element.
- **S5 and S6**: the same file and the same Pass 96 resume-seek state (`position`,
  `pendingResumeSeek`).
- **S12 and S13**: the panel's `scheduleJob` (`PlayerInfoPanel.swift:482-490`), if the owner widens
  S13 (§5).

### Where REVIEW.md's description did not hold, in whole or in part

No item fails outright. Eight hold only in part:

- **S1** — only GuideRightEdge's waits are hours long (about 2 h). GuideLiveRedraw's unattended wait
  is 1200 s, about half an hour for the class (`GuideLiveRedrawUITests.swift:67-68`). ManageDVR and
  TrashRestore are also written to write, but at HEAD stale navigation stops both before their writes.
- **S5** — the progress bar vanishes only when the session POST itself failed. After a later failure,
  show detail draws an empty bar (`ScreenChrome.swift:183-184`).
- **S6** — the crash is not established. The tvOS 27.0 SDK header documents a cancelled seek, not an
  exception, for a target outside the (empty) seekable ranges (`AVPlayerItem.h:341-345`). The window
  is the ~0.45–0.79 s after the Player appears, at any point in playback, not "the first second of a
  recording".
- **S7** — cancelling the last scheduled recording empties the list only for a one-off Record Now. A
  cancelled pass airing stays as a Skipped row.
- **S10** — the poster miss is certain only for ";". For "+", the server may still draw a poster,
  possibly the wrong one, when it holds a TMDB token.
- **S11** — the blank grid is also repaired by a notice, a reconnect, a collection pick, or +12h
  followed by Menu or ↩ Now. A counter bumped per fetch misses REVIEW.md's own example.
- **S13** — the stated mechanism is wrong for the sheet. Every host returns its previous jobs when a
  read fails, so a failed read gives back the old copy. The fallback acts only after a *successful*
  read that lacks the job, which is exactly the defect. REVIEW.md's wording describes the Player
  panel's `scheduleJob`.
- **S16** — "every time until quit" needs the first request never to answer at all. "Both Apple TVs
  hold a cached fix" is on record for Home Theater only.

---

## 3. Each item

Each item is given as: (a) whether it holds · (b) files the fix touches · (c) sort · (d) records the
fix changes · (e) one Home Theater run · (f) owner.

### G — the Guide's Left back-step (owner, 2026-09-23: "go back as it did forward")

**(a) Not a REVIEW.md item.** What the code does today, at the points G changes:

- **`gridMoved` acts on `.right` only:** `guard direction == .right, model.sheet == nil, channelMenu
  == nil, !collectionsOpen else { return }` (`GuideScreen.swift:574`).
- **The press G names is Left on a row's channel cell, and it is the only press that crosses from the
  grid to the rail.**
  - Left from a row's first programme lands on that row's channel cell.
  - The channel cell's `HoldButton` sits in `GuideRowView`'s HStack (`:909-917`), inside the grid's
    `ScrollView` (`:404-427`). Pass 76 logged its Left at the grid
    (`reports/2026-09-12-pass76-right-edge-probe.md:321-323`).
  - Left from the channel cell goes to the rail. Pass 77 measured `G left 3 -> grid:channel-cell` then
    `G left 4 -> rail`, four slots ahead (`reports/2026-09-12-pass77-guide-scroll-right.md:273-274`).
  - The header and the rail are focus sections of their own (`:837`; `RailView.swift:78`).
- **Nothing at HEAD keeps focus in the grid on that press.** `.onMoveCommand` "is an observer, not a
  consumer" (DECISIONS.md:1180-1182). `UIFocusGuide`, a window-level recognizer and a focusable edge
  affordance "all remain untouched and unmeasured" (DECISIONS.md:1199-1200). Whether a Left that
  crosses into the rail delivers a move command to the grid at all has never been measured.
- **A mirrored settle is needed.** Pass 76 saw every moving Left deliver its command after the focus
  write. A test made at receipt would therefore step the window on the same press that walks onto the
  channel cell: Pass 77's "one press, two actions" (DECISIONS.md:1214-1219). The Right side uses a
  150 ms settle (`:536`, `:577`) and `engineSteppedRightAt` / `isRightwardStep` (`:326`, `:505`,
  `:556-560`).
- **"Refetch only by the existing rule": two lines exist, and only one works backward.**
  - `pageForward` and `nudgeForward` use `if windowEnd > fetchEnd` (`:143`, `:172`), which DECISIONS.md:1226
    calls "the existing rule". It can never fire on a back-step.
  - `tick` and `snapToNow` use `windowStart < fetchStart || windowEnd > fetchEnd` (`:198`, `:221`),
    which DECISIONS.md:1339-1341 calls "the existing rule". That record, and the code comment at
    `:189-190`, say `nudgeForward` uses this line; at HEAD it does not.
  - `fetch` anchors `fetchStart` at the requested start (`:237`). So after the 45th nudge, a second
    +12h, a collection pick while ahead, or any Pass 116 notice or reconnect, the first back-step
    lands below `fetchStart`.
  - With the one-sided line, rows whose programme ended in that gap would draw their first slot blank.
    With the two-sided line, each such press costs one `GET /api/guide` and one `GET /api/schedule`.
    Only the two-sided line keeps "every row together".
- **The floor.** `tick()` rolls only when `windowStart < nowHalfHour` (`:196`). That rests on
  "`windowStart` is only ever set to the current half hour or advanced past it" (DECISIONS.md:1333-1335).
  A back-step keeps it only if floored at the true current half hour. `model.now` can be up to a
  minute stale, so the floor wants `Date()`, as `snapToNow` reads it (`:218`).
- **Unchanged by G:** Menu, ↩ Now, +12h, the collection filter (`fetch` carries it, `:226`) and the
  Pass 116 redraw. G does not name the footer (`:886`), which stays as built.

**(b) Files.**
- `Marlin DVR TV/GuideScreen.swift` — certain:
  - `gridMoved`'s guard, keeping the overlay part;
  - a model back-step, floored at the current half hour and refetching on the two-sided line;
  - a leftward-step stamp mirroring `isRightwardStep`;
  - `gridMoved`'s doc comment (`:562`);
  - the block itself, if it can live in the Guide.
- `Marlin DVR TV/ScreenShell.swift` — possibly: only if the crossing is blocked at the shell. That is
  `railRestore`'s path (`:66`, `:74-87`).
- `Marlin DVR TV/RailView.swift` — possibly: only if the block lives in the rail's own entries.
  Left from the Guide header must still reach the rail.
- `Marlin DVR TVUITests/GuideRightEdgeUITests.swift` — possibly: the run's harness method.
  `testScrollThenRailRoundTrip` presses Left at most four times (`:726`) and asserts the rail at
  `:731`, so under G it fails from four slots ahead. Record it stale or amend it.

**(c) STANDALONE.** See §2.

**(d) Records G changes, quoted.** The owner's decision of 2026-09-23 supersedes each of these for
the one press it names. They are recorded forward and not edited.

- DECISIONS.md:1204-1206, 2026-09-12 (Pass 77, the owner's decisions): *"One Right press on the last
  visible cell of a row moves the window forward one slot (30 min); forward only; Left, Menu, `↩ Now`,
  `+12h` and a rail trip all behave exactly as they did."*
- DECISIONS.md:1270-1273, 2026-09-12 (Pass 78, accepted "it all feels good"): *"one Right press on the
  last visible cell of a row moving the window forward **one slot (30 min)**, with the time strip,
  every row and the header moving together; **forward only**; `Left`, `Menu`, `↩ Now`, `+12h` and a
  rail trip all behaving as they did;"*
- `reports/2026-09-12-pass78-scroll-accepted-and-pushed.md:23` (Pass 78's report copy): *"- **Forward
  only.** `Left`, `Menu`, `↩ Now`, `+12h` and a rail trip all behave as they did."*
- COLD-START.md:60, the Guide line: *"Right on the last visible cell of a row moves the window forward
  one slot, forward only, with the strip and every row together, refetching once every 45 slots, focus
  staying on the same programme while it is in the window (Passes 75–78)"*.

Checked and not changed:
- DECISIONS.md:18 (design 3a, "forward-only from the current half hour"): G keeps that floor.
- DECISIONS.md:234-238 and COLD-START.md:58 (the ring lands on the entry that opened the screen):
  where a crossing lands is unchanged. The mechanism is the fragile part (c).

**(e) One Home Theater run, no server write.** Launch with `devicectl … --console --terminate-existing`
so `fetch=` is readable and the new build is the one driven; the harness drives that process.
1. Open the Guide at now.
2. Right-nudge at a row's last cell until the window is four slots ahead. This stays inside the
   first fetch.
3. Left along the row to its channel cell. The header must not move on that press.
4. Left four times. Each press moves the header, the strip's first column and the rows back 30 min
   together; focus stays on the channel cell; no `[rail] entered` line; `fetch=` unchanged. At now,
   "· now" shows and ↩ Now goes.
5. A fifth Left enters the rail with the ring on Guide.
6. If the shell or rail was touched, one Left from the collections button still reaches the rail.

If the chosen block does not hold in that run, stop and report rather than iterate on the device.

**Stays traced:**
- a back-step below `fetchStart` and its per-press read;
- a half-hour boundary during back-steps, and the floor's clock;
- Menu, ↩ Now and +12h after back-steps;
- a Pass 116 notice during back-steps (needs a server write);
- overlays open; the Player on top;
- a physical swipe against XCUIRemote; a fast presser against the mirrored settle.

**(f) None.** G's own clause fixes the trigger: "a Left press that would otherwise take focus out of
the grid into the sidebar" is Left on a channel cell and nothing else. Focus stays on that cell, which
is the Pass 77 rule applied to a cell that never leaves the window (`:643-647`). See §6.

### S1 — ⌘U runs every harness against the live DVR, including the ones that write

**(a) Holds in part.**

What holds:
- The shared scheme has one TestableReference with `skipped = "NO"`, no skip list and an
  auto-created test plan (`Marlin DVR TV.xcscheme:31`, `:33-34`).
- ⌘U or a bare `xcodebuild test` therefore runs all 23 files and 70 methods against the compiled-in
  address (`ServerAPI.swift:15`).
- Three classes reach real writes at HEAD:
  - `DeleteRefreshUITests.swift:141-143` (trash);
  - `StopRecordingUITests.swift:89` and `:123` (book, then stop; `:114` only arms);
  - `CommercialSkipUITests.swift:372-381` (play to the end → `PUT` watched, `PlaybackSession.swift:167-176`).

What does not hold:
- Only GuideRightEdge's boundary waits are hours long (`:993`, `:1052`, `:1105`, `:1152`; about 2 h).
  GuideLiveRedraw's unattended wait is 1200 s (`:67-68`), about half an hour for the class.
- ManageDVRUITests (Cancel, `:101-106`) and TrashRestoreUITests (two Restores, `:147`) are also
  written to write. At HEAD stale navigation stops both first (`:82`; `:37-38` against
  `Destination.swift:27`, failing at `:122`).
- "Every recorded run named one class" has one exception: Pass 9's bare `test-without-building`
  (`reports/2026-09-06-pass9-sweep4-fixes.md:64-65`), harmless then.

**(b) Files.** One of two disjoint sets; REVIEW.md's "or" makes the choice the builder's.
- **Option A:** `Marlin DVR TV.xcodeproj/xcshareddata/xcschemes/Marlin DVR TV.xcscheme:34` only.
- **Option B:** a runner-environment opt-in (`XCTSkipUnless` in `setUpWithError`, passed as
  `TEST_RUNNER_…`, the route `P116_WAIT` already uses, `GuideLiveRedrawUITests.swift:39`, `:68`) in the
  `setUp` of:
  - `DeleteRefreshUITests.swift:38-42`;
  - `StopRecordingUITests.swift:35-39`;
  - `CommercialSkipUITests.swift:47-52` (read from the runner's environment, not a launch argument,
    because it joins a devicectl-launched process through `activate()`, `:13-18`);
  - possibly `ManageDVRUITests.swift` and `TrashRestoreUITests.swift`.
  Under B, the live brief at COLD-START.md:80 would need to name the opt-in.
- Neither option touches `project.pbxproj`: the target is a synchronised folder (`:16`, `:91-93`).

**(c) SWEEP.** No record calls the scheme or the `-only-testing` path fragile or load-bearing. The
recorded run commands are instructions (COLD-START-HISTORY.md:2337-2404), not fragility records. The
fix is one attribute or a few guards. The unknown is technical and stated in (e).

**(d) None.** Pass 9 open question 7, "Keep it for future passes?"
(`reports/2026-09-06-pass9-sweep4-fixes.md:307-309`), was closed as built (COLD-START.md:110).
Option A keeps the target in the scheme and only skips it for ⌘U.

**(e)** S1 needs no run of its own.
- **Option A:** the pass's one representative run, through the recorded `-only-testing` form, is the
  check. Tests executed plus the launch ping in `GET /api/logs` (COLD-START.md:103) mean the route
  survived. Zero tests executed means option A broke every recorded run command. Either outcome
  writes nothing.
- **Option B:** no safe run exists. A broken gate's negative path is itself a write.
- ⌘U is a Mac-side action.

**Stays traced:**
- that ⌘U runs no writer after the fix;
- that a gated class skips before `launch()` / `activate()`;
- the wait lengths;
- (spot-checked, not exhaustive) that no other `continueAfterFailure = true` harness turns one failed
  check into a write.

**(f) None.**

### S2 — ShowDetailSeriesPassUITests can press "Record the series"

**(a) Holds.**
- `continueAfterFailure = true` (`ShowDetailSeriesPassUITests.swift:62`).
- The focus check at `:246-247` is a soft `XCTAssertTrue`, and the Select at `:248` runs whatever it
  found.
- With the pass gone, the one control reads and acts as "Record the series" → `recordSeries()` →
  `POST /api/passes` (`ShowDetailScreen.swift:260-266`, `:356-361`; `ServerWrites.swift:194`).
- Only REVIEW.md's "focus is almost certainly on it" is unmeasured. The walk presses Down two or three
  times from that button, and both columns are focus sections (`ShowDetailScreen.swift:277`, `:414`).
  A stray Select would either create a pass or play an episode. The guard is needed either way.

**(b)** `Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift:246-248` only. `openShow`'s measured
walk (`:140-149`) is untouched.

**(c) SWEEP.** One guard in the test target.

**(d) None.** The fix makes COLD-START.md:80 ("never presses \"Record the series\"") and
DECISIONS.md:2323-2324 true in every state rather than changing them.

**(e) Optional, one run** of the Pass 103 command (`reports/2026-09-16-pass103-a1-series-pass.md:156-158`).
- It proves the happy path still passes, 103a–103d.
- Believe it only with the launch ping and no `POST /api/passes` in `GET /api/logs`.
- Precondition: a read of `GET /api/passes` shows the pass show still holds its pass. If not, the
  harness is not run at all, fixed or not.

**Stays traced:** the stop branch itself, which needs the owner's pass deleted or the server failing.

**(f) None.**

### S4 — Location set to Never in Settings: the saved position is still used and sent

**(a) Holds.**
- `start()` returns the cached fix at `WeatherLocation.swift:94-98`, before the authorization switch at
  `:104-114`.
- `marlinWeatherFix` is never removed. It is written only through `cache(_:)` (`:80-84`, from `:161`
  and `:185`).
- Under Never, `WeatherModel.run()` (`WeatherModel.swift:102-108`, `:122-125`) still sends the fix to
  WeatherKit, whatever the launch order.
- The NOAA half (`RadarScreen.swift:196-198` → `RadarSource.swift:114`) holds only if the manager's
  creation-time authorization callback (`:144-145`) lands before `start()`. That is likely and
  unmeasured.

**(b)** `Marlin DVR TV/WeatherLocation.swift`, certain:
- in `start()`, read the authorization status before the cache;
- on `.denied` or `.restricted`, remove `marlinWeatherFix` and `finish(.declined)`;
- keep cache-first for authorized, and for `.notDetermined` with a cache (DECISIONS.md:56);
- the comments at `:23-24` and `:88-89` go stale.

Possibly, a new evidence harness in `Marlin DVR TVUITests/`. No project or scheme edit.

**(c) SWEEP.** One function. No record marks the location path fragile.

**(d)** `reports/2026-09-06-pass13-weather-radar.md:179-180` (Pass 13, approved and pushed,
DECISIONS.md:67): *"A cached fix short-circuits `start()` entirely: no prompt, no request."*
- Under denied or restricted it no longer does.
- The proven half, no prompt after the first grant (`:180-182`), is kept.
- Also out of date, though not a decision: the Pass 71 recon's inventory row giving the key as
  never removed (`reports/2026-09-11-pass71-guide-collections-recon.md:804`).

DECISIONS.md:56 ("cached after the first grant") and COLD-START.md:69 stand.

**(e) One owner-in-the-loop run.** The fixed build is installed as an upgrade, so the client id, resume
positions and cached fix are kept.
1. The owner sets Marlin DVR TV to Never in tvOS Settings.
2. The harness cold-starts the app and reads three sentences:
   - Home's glance: "Weather needs this Apple TV's location — open Weather" (`HomeWeatherGlance.swift:118`);
   - Weather: "No location, so no weather." (`WeatherScreen.swift:126`);
   - Radar: "No location, so no radar." (`RadarScreen.swift:240`).
3. The owner restores the grant; the glance fills with no prompt.

Conditions:
- The Settings round trip has never been recorded on tvOS 26.6. Pass 13 recovered from a denial by
  reinstalling (`pass13 report :368-370`).
- If the restore fails, the run stops. A reinstall would wipe the client id and trigger
  `POST /api/clients/register`, a server write.

**Stays traced:**
- that no WeatherKit, geocoder or NOAA request is sent (no network capture);
- that the key is actually removed (step 3 cannot tell);
- `.restricted`; Location Services off system-wide;
- a mid-session withdrawal;
- the launch ordering.

**(f) None.**

### S5 — "Try again" after a failed start wipes the saved resume position

**(a) Holds in part.**

What holds:
- A failed start never moves `position` off 0 (`PlayerModel.swift:49`). Only `armResumeSeek` does
  (`:233-236`), after `attach` (`:159`).
- So Try again (`PlayerScreen.swift:447`, wired `:67`) runs `restart()` with target 0 (`:826`), and
  its `ResumeStore.save` (`:832-834`) overwrites the real entry.
- The 0 stays in three cases: a failed retry, Menu during the retry, or Back. `fail` never saves;
  `stop` saves only in `.playing` (`:892`) and `startAgain` sets `.starting` (`:855`).
- `isResumable` (`ResumeStore.swift:77`) then drops the Resume line and the Continue watching card.
- A successful retry heals it (`:233` falls back to `request.resumeSeconds`).

What does not hold: the progress bar vanishes only when the POST itself failed (duration 0). After a
later failure show detail draws an empty bar (`ScreenChrome.swift:183-184`).

**(b)**
- `Marlin DVR TV/PlayerModel.swift`, `restart(at:)` `:832-834`, certain: skip the save when playback
  never attached, or keep the entry until the retry lands. `position = target` (`:845`) must stay
  exactly as it is, and the doc comment at `:821-824` goes stale.
- `Marlin DVR TV/ResumeStore.swift:83-85`, possibly, comment only ("saves unconditionally").

**(c) STANDALONE.** See §2.

**(d) Records the fix changes:**
- DECISIONS.md:2043-2044, 2026-09-16 (Pass 98, the T1 build the owner closed in Pass 99): *"**Nothing
  else in the teardown changed**: the same detach, the same DELETE, the same `ResumeStore.save`, in the
  same order."* The teardown's save becomes conditional. The record stays true as Pass 98's history.
- `reports/2026-09-16-pass91-continue-watching.md:161` (Pass 91, accepted in Pass 93): *"On
  `restart(at:)` — **unconditionally**, which is why the shelf keeps its own end-of-file test"*. The
  end-of-file test is still needed for an attached restart at the end.

**Adjacent, not changed:** the owner's closure of T1 — *"im not spending any time on something that
might never ever happen close this and move on to anything major or that is unfinished"*
(COLD-START.md:95; DECISIONS.md:2097-2099, 2026-09-16 (Pass 99)). It closed the restart target's hand-off,
which the fix leaves alone. He picked S5 by name on 2026-09-23.

**(e) No run on a healthy server reaches the changed save.** The failure needs the server down or
restarting, which is off limits, or the Apple TV's network pulled, which was declined for this path
(DECISIONS.md:2107-2111).

One conditional exception needs no write. The server refuses a recording still being written with a
502 at POST (`stream.go:664-666`, `playfile.go:103-107` at `0fa05e1`, read from source). If the owner
has one at run time and show detail lists it (unverified), then click, the 502 card and Try again
reach the changed branch. A before/after `devicectl … copy from` of the preferences (Pass 96 §4.3;
never print the credential key) shows whether an entry at 0 appears. That proves only the skip,
since such a recording has no prior entry.

Otherwise the run is a regression only: Resume on a saved spot lands on it.

**Stays traced:** the preserved spot after a failed retry; Menu during the retry; the `playNext`
variant; T1's hand-off.

**(f) None.** The owner's pick answers "fix it or leave it closed".

### S6 — a frame step before the item is ready

**(a) Holds in part.**

What holds:
- `attach()` sets `.playing` (`PlayerModel.swift:208`) before the item is ready.
- `frameStep`'s guard (`:422`) has no readiness or `pendingResumeSeek` check.
- So a paused click (`PlayerHost.swift:314-319`) reaches `cancelPendingSeeks` (`:429`) and a
  completion-handler seek (`:438`).
- The gap is Pass 96's 0.45–0.79 s (`reports/2026-09-16-pass96-resume-whole-recording.md:167`). It was
  measured twice on 1.8.2's remux path and never on the sidecar path.
- **The second effect holds by trace.** A click during the resume seek's 0.185–0.317 s flight (`:168`)
  cancels it after `resumeSeekDone` is set (`:616`). The next save then writes the unmoved time over
  the stored entry.

What does not hold:
- **The crash is not established.** The tvOS 27.0 SDK documents exceptions only for invalid times or
  tolerances, and a cancelled seek for a target outside the seekable ranges, which are empty before
  ready (`AVPlayerItem.h:341-345`). The readiness exception rests on third-party reports.
- The window is the first ~0.45–0.79 s after the Player appears, at whatever point playback begins,
  not "the first second of a recording".

**(b)**
- `Marlin DVR TV/PlayerModel.swift`, certain: add `item.status == .readyToPlay` and
  `pendingResumeSeek == nil` to `:422`, before `:429`. The doc comment at `:417-419` goes stale.
- `Marlin DVR TV/PlayerHost.swift:17-21`, possibly, comment only ("falls straight through to Apple's
  transport bar"). No code change there.

**(c) STANDALONE.** See §2.

**(d)** DECISIONS.md:269-270, 2026-09-07 (frame-by-frame, owner decision "Clicks step; swipes keep
their fixed skips"): *"Left and right **clicks** move one frame while paused on a recording"*.

A narrow exception follows. Before `.readyToPlay`, and during the resume seek's flight, a paused
click does nothing: neither a step nor Apple's skip, because the app still owns the arrow
(`PlayerScreen.swift:47`).

**(e) One no-harm run**, by a temporary disclosed probe or the owner's hands, because
`ResumeRewindUITests` cannot pass since Pass 110 (COLD-START.md:80).
- Resume a saved recording; the moment "Preparing the recording" goes, pause and send a burst of Right
  clicks.
- Look for: no crash; `[resume] … landed` on the saved spot; after landing, a click still steps
  +0.033367 s at 29.97 fps.
- Read the stored position before and after and put it back. Never play to the end.

**Stays traced:**
- that any click fell inside either window;
- the exception on tvOS 26.6;
- that a declined paused click does nothing (the internals dependency, COLD-START.md:88).

**(f) None.**

### S7 — empty Scheduled Recordings or Your Passes: Menu drops out of the app

**(a) Holds in part.**

What holds:
- The empty sentences are plain `Text` (`ScheduleManageView.swift:113-118`,
  `PassesManageView.swift:75-80`).
- Every focus request is nil on an empty list: `:51`, `:77` and `:84` via `firstRowID` at `:98`, and
  `PassesManageView.swift:39`, `:50`.
- That is the trap Pass 33 measured (`reports/2026-09-07-pass33-trash-restore.md:256-261`).

What does not hold:
- "After cancelling the last scheduled recording" empties the list only for a one-off Record Now. A
  cancelled pass airing stays as a Skipped row (`ScheduleManageView.swift:47-48`; `passes.go:388-389`
  at `0fa05e1`, read from source; COLD-START.md:111).
- Pausing the last pass (through Manage pass, `:68`) is another way the schedule empties.

**(b)** Both certain:
- `Marlin DVR TV/ScheduleManageView.swift`: make the sentence focusable as `"empty"`; fall back to it
  at `:51`, `:77` and `:84`; give it the `.disabled` the ScrollView has at `:141`; the restores at
  `:58` and `:91` may need it too.
- `Marlin DVR TV/PassesManageView.swift`: the same, at `:75-80`, `:39`, `:50` and `:94`.

**(c) SWEEP.**

**(d) None.** It applies DECISIONS.md:407-409 ("A screen must always have something focusable…") and
does not change it. COLD-START.md:67 gains two more lists when built.

**(e) One run**, shared with S8, by remote or a new read-only harness. ManageDVRUITests cannot be used:
it steers by the removed Recordings row (`:36-47`) and sends a Cancel (`:100-107`).
- It proves only the non-empty path: first row focused, Menu back to the hub, Trash as before.
- No empty list can be produced without writes to his schedule.

**Stays traced:** every empty path, resting on Pass 33's measurement of the same mechanism and fix.

**(f) None.**

### S8 — Manage DVR shows a failed read as "no passes", "nothing scheduled" or "Reading the server…"

**(a) Holds.**
- The system and passes failures go to the console only (`ManageDVRScreen.swift:60`, `:65`).
- So the hub reads "0 passes" (`:163`), Your Passes says "No series passes yet…"
  (`PassesManageView.swift:75-76`), and Manage pass is hidden (`ScheduleManageView.swift:42`, `:299`).
- StorageCard keeps "Reading the server…" (`:208-212`) for as long as the screen is open.
- `refreshSchedule` (`:70-72`) never clears the error set at `:62`.
- One loose phrase: the hub's ErrorLine sits under a row reading "0 scheduled" (`:159`, `:172-174`).
  "Nothing is scheduled…" is on the list screen, which shows no error.

**(b)** All certain:
- `Marlin DVR TV/ManageDVRScreen.swift` — an error per section, set and cleared in the existing catches
  (`:60-65`, `:71`, `:75`), shown on the hub rows and in StorageCard (call site `:153`). Trash stays
  byte-identical.
- `Marlin DVR TV/ScheduleManageView.swift` and `Marlin DVR TV/PassesManageView.swift` — the failure
  text is, or lives in, S7's focusable element.

**(c) SWEEP.**

**(d) None.** Pass 106's A5 (DECISIONS.md:2436-2439, "so leave it as is"; COLD-START.md:119) stands
only if the builder adds no Try again, timer or re-read. The fix needs none.

**(e)** Same run as S7. It proves the success path and that no false error appears.

**Stays traced:** every failure branch and the clear-on-success path, which needs a write. This
matches `reports/2026-09-16-pass102-a1-a5-recon.md:463-464`.

**(f) None.**

### S9 — after a Delete on a show's page, the Player auto-plays the deleted episode

**(a) Holds.**
- `ShowDetailScreen.swift:211` hands the Player `model.detail`. Only `load()` sets it (`:62`, from the
  one-shot `.task` at `:183-184`).
- Keep and Delete edit only `episodes` (`:74-81`).
- `PlayRequest.swift:136-140` picks the next episode from that stale list, and
  `PlayerScreen.swift:83-85` and `:129-137` auto-play it.
- The failure follows from the trash-time id change (DECISIONS.md:404-406) and the server's 404 "no
  such recording" (`stream.go:584-588` at `0fa05e1`, read from source, not measured).
- One precision: the countdown offers the deleted episode directly only when it is the next-newer one.

**(b)**
- `Marlin DVR TV/ShowDetailScreen.swift`, certain: `apply()` also rewrites `detail`, or `play()` builds
  the show from `episodes`.
- `Marlin DVR TV/Models.swift:421`, possibly, only if `episodes` becomes a `var`.

**(c) SWEEP.**

**(d) None.** Pass 31's "a re-read of `GET /api/library`, not a local edit" (DECISIONS.md:311) is the
shelves' rule. The same pass records show detail's local edit as correct
(`reports/2026-09-07-pass31-delete-refresh.md:58-59`). "Show detail does not reload after the Player
closes" (COLD-START.md:111) stands, because the fix adds no reload.

**(e) Only with server writes the owner authorises in his own words, naming the show and episodes, or
his own presses.** The standing trash authorisation covers two single-recording ids only
(DECISIONS.md:410-412).

Before he authorises, tell him three things:
- a Delete is permanent if the trash period is "Immediately" (soft delete last measured in Pass 31;
  `GET /api/settings` is off limits);
- a trash and restore clears Watched, Favorite and Keep (`library.go:814-817`, read from source);
- playing to the end marks it watched on both TVs.

With that, one run:
1. Delete the next-newer episode.
2. On the same page, play the older one to its end.
3. 6e names the surviving episode, and the 10 s auto-play starts a real one.
4. Restore afterwards.

**Stays traced:** the Keep half (invisible to the Player); the "Immediately" branch; a chain across
two deletions; the pre-fix 404 itself.

**(f) None.**

### S10 — a title containing "+" or ";" cannot be opened from Search or On Later

**(a) Holds in part.**
- `URLComponents` leaves "+" and ";" literal (`ServerAPI.swift:105`, `AiringSheet.swift:43`,
  `Models.swift:459`, `OnLaterScreen.swift:79`). Measured in a scratch Swift 6.4 file on macOS, since
  deleted: "A + B" → `title=A%20+%20B`, "A;B" → `title=A;B`.
- The server reads every value with `r.URL.Query().Get` (§4). So a "+" becomes a space and a pair
  containing ";" is dropped.
- Search and On Later then say "The server no longer lists that airing." (`GuideSearchScreen.swift:147`,
  `OnLaterScreen.swift:323`).

What does not fully hold:
- The poster miss is certain only for ";" (empty title → 404, `artwork.go:501-504`).
- For "+", the mangled key misses the title's cached or custom poster. But with a TMDB token, a fresh
  search (`:284`) and the first-candidate fallback (`:252`) may still draw one, possibly the wrong one.
- REVIEW.md leaves implicit that On Later's `u=` value has the same exposure (";" → 400,
  `artwork.go:479-480`).

**(b)** Certain:
- `Marlin DVR TV/ServerAPI.swift` (`url(_:query:)`, `:101-110`) — or per call in `ChannelFilter.swift`
  (`:93`, `:102`), possibly;
- `Marlin DVR TV/AiringSheet.swift` (`:40-45`, which also serves On Later's fallback, Your Passes and
  the Player's Starting screen);
- `Marlin DVR TV/Models.swift` (`:456-461`, the Trash copy — encoding only; merging the two builders
  is N42, not picked);
- `Marlin DVR TV/OnLaterScreen.swift` (`:75-83`, both `u=` and `title=`).

Possibly:
- `Marlin DVR TV/GuideScreen.swift` (`:1026-1036`), only if the Go escaper is extracted. The logo
  bytes must stay identical.
- An evidence step in `GuideSearchUITests.swift`.

**(c) SWEEP.**

**(d) None.** The Pass 86 logo record (DECISIONS.md:1639-1643, accepted `:1656-1657`) constrains a
moved escaper only. Search's "whole-title equality" (DECISIONS.md:842-853) becomes true for every
title.

**(e) Conditional.** First check read-only whether a "+" or ";" title is in the guide
(`GET /api/guide/find?q=%2B`, `?q=%3B`).
- If one is, a run types a substring of it in Search, opens the row, and the airing sheet appears.
- If none is, before and after look the same and S10 stays traced.
- The server logs only the path (`main.go:181`, `:189`), so the bytes come from the app's console.

**Stays traced:** the builders' bytes (checked outside the project, as Pass 86 did); On Later; Trash,
Your Passes and Player posters; the `u=` case; whichever character is absent; the TMDB-dependent "+"
poster.

**(f) None.**

### S11 — Guide reads that finish out of order can fill the grid with the wrong window

**(a) Holds in part.**

What holds:
- `fetch` stores `rows`, `fetchStart` and `fetchEnd` after the await with no check
  (`GuideScreen.swift:234`, `:237-238`).
- REVIEW.md's +12h, +12h, Menu blanks the grid with ↩ Now hidden:
  - the first +12h makes no request (`:143`);
  - `snapToNow` makes none either while the old range stands (`:221`);
  - the late answer is stored, `cells(for:)` is empty (`:259`), and `isAtNow` hides the pill (`:809`).

What does not hold:
- "Until the next half-hour roll or until the Guide is left" leaves out three other repairs:
  - a Pass 116 notice or reconnect (`:213-215`);
  - a collection pick (`:204-206`);
  - +12h followed by Menu or ↩ Now (`:221`).
- The fix text is incomplete:
  - A counter bumped per fetch misses REVIEW.md's own example, because `snapToNow` starts no fetch.
  - A plain window/filter discard loses a notice. Open at S; +12h (no request); a notice starts
    `fetch(from: S+12h)` (`:214`); Menu snaps to S with no request; the notice's answer is discarded;
    the owed loop ends (`:706-714`); the server change is never drawn.

**(b)**
- `Marlin DVR TV/GuideScreen.swift`, certain, all inside `fetch` (`:224-252`):
  - keep an answer only if it still covers the window and filter now showing, and is not older than
    the stored one;
  - discard before the `serverWins` clear (`:236`) and still set `loaded` (`:251`);
  - after a discard, re-read at the current window and filter, at least for a notice's answer;
  - print the discard.
- `Marlin DVR TV/GuideCollections.swift`, possibly, not needed.
- `Marlin DVR TVUITests/GuideRightEdgeUITests.swift`, possibly, for the run.

**(c) STANDALONE.** See §2.

**(d) None**, if done as above. Checked and unchanged:
- DECISIONS.md:2875-2877 ("no notice is coalesced away");
- COLD-START.md:60 (every notice re-reads at the window and collection showing);
- DECISIONS.md:1047 ("No generation counter was added to the Guide." — about the focus rebuild; a
  fetch sequence number should not be called a generation).

**(e) One run, no server write:** +12h twice then Menu, and +12h twice then ↩ Now, each giving a filled
grid at now; a pick while ahead redraws in place.
- The discard branch runs only under a disclosed diagnostic delay in `fetch`, reverted before the
  commit (precedent DECISIONS.md:1158-1161).
- XCUIRemote cannot land a press inside one round trip.

**Stays traced:** every notice path, including Menu during a notice's re-read (needs a server write); a
pick before the first load; overlapping nudge refetches; G's back-step reads once G exists.

**(f) None.**

### S12 — an info panel open across a programme change keeps the old show's pass

**(a) Holds, by trace.**
- `.task(id: program?.end)` (`PlayerInfoPanel.swift:233`) is cancelled by its own `program = airing`
  (`:404`) while the pass and schedule reads at `:421-424` are in flight.
- `pass` keeps the ended show's value (`:460-462`). `job` becomes nil (`:486-489`, `:423`), so Record
  replaces the chip (`:329`) and Edit pass opens the old pass (`:332-334`).
- Precisions:
  - `pass` is whatever the ended show had, so a new show with a pass can read "Add to pass";
  - the Conflict line (`:380-385`) also drops;
  - the first open (`:224-232`) is unaffected;
  - the failure rests on the cancel beating a few-millisecond LAN reply, which is traced, never
    measured.

**(b)**
- `Marlin DVR TV/PlayerInfoPanel.swift`, certain (`:233`, `:494-506`, possibly `:419-428`). Keep the
  following, and touch none of the write mirrors, `scheduleJob`'s contract or Pass 109's close paths:
  - `loaded` after the reads (`:429`);
  - the post-reload focus (`:505`);
  - `firstFocusID`'s Pass 49 rule (`:164-169`);
  - the message clearing (`:501-504`).
- `Marlin DVR TVUITests/PlayerInfoPanelUITests.swift`, possibly, evidence only.

**(c) SWEEP.**

**(d) None.** Two owner decisions stand and are carried out, not reversed:
- DECISIONS.md:2529-2530 ("Just show the current show.");
- DECISIONS.md:2567-2568 (an airing that ends is replaced by the next).

The code-traced label (DECISIONS.md:2586) stays true of Pass 108's build.

**(e) One run, if the day's lineup cooperates.**
1. Play live on a channel that holds no tuner.
2. Open the panel just before a :00 or :30 end and hold it past end+2 s.
3. Pick the boundary in advance from GETs only: one where the two shows differ in pass state, or the
   next airing is already booked.
4. Otherwise attach the console and look for no `[panel] passes:` / `[panel] schedule:` errors. The
   server log's GETs prove nothing, because the old build sends them too.
5. Read the series button's label before any Select ("Add to pass" creates a pass), and press only
   Menu inside the editor.

If the lineup gives no telling boundary, the fix stays traced.

**Stays traced:** the pre-fix self-cancel; a genuine read failure at the boundary; a second
consecutive boundary; the cancel-versus-reply race.

**(f) None.**

### S13 — after deleting a series pass from the airing sheet, the sheet still shows the booking

**(a) Holds in part.**

The outcome holds. After Edit series pass → Delete:
- the successful re-read at `AiringSheet.swift:150` no longer lists the job;
- `?? job` keeps the Queued one, and the chip (`:253-254`) stays;
- the Guide behind drops its mark (`GuideScreen.swift:255-263`).

The mechanism as worded does not hold:
- Every host keeps its previous jobs when a read fails (`GuideScreen.swift:284-290`,
  `GuideSearchScreen.swift:172-178`, `OnLaterScreen.swift:292-298`). A failed read hands back the old
  copy, not nothing.
- The fallback acts only after a successful read that lacks the job. REVIEW.md's wording describes the
  Player panel's `scheduleJob` (`PlayerInfoPanel.swift:482-490`).
- `:169` holds for a Record Now cancelled elsewhere (`passes.go:938-949`, read from source) or a pass
  deleted or paused elsewhere. It does not hold for a cancelled pass airing, which stays listed as
  Skipped and reads correctly as unbooked.

**(b)**
- `Marlin DVR TV/AiringSheet.swift`, certain. The minimal route drops `?? job` at `:150` and
  `?? selection.job` at `:169`, as `:421` already does. That is "fall back only when the read fails",
  because the hosts already return their old copy.
- On REVIEW.md's literal route (a callback that reports failure), possibly also the closures and
  `refreshSchedule` in `GuideScreen.swift` (`:458-461`, `:284-290`), `GuideSearchScreen.swift`
  (`:268-271`, `:172-178`; the load-bearing rebuild at `:253-256` and `:312-315` untouched) and
  `OnLaterScreen.swift` (`:386-389`, `:292-298`).
- `Marlin DVR TV/PlayerInfoPanel.swift` only if the owner says yes to §5 (`:203` and `scheduleJob`
  at `:482-490`).

**(c) SWEEP.**

**(d) Records the fix changes:**
- DECISIONS.md:356-357, 2026-09-07 (Pass 32, accepted in Pass 34): *"The `?? job` fallback the sheet's
  other writes use is deliberately absent here: keeping a stale `Recording` job would leave a Stop
  button on a recording that is already over."*
  - Not reversed: Stop keeps no fallback.
  - The delete re-read and the re-read on open stop falling back after a successful read.
  - On the minimal route, "the sheet's other writes use" stays true for `record()` and
    `recordSeries()`.

If the sheet alone is fixed, these change as well:
- DECISIONS.md:2530-2532, 2026-09-16 (Pass 108, the owner's decision; accepted "all good", `:2607`):
  *"**Each button does what the app's existing control of that kind does** (airing sheet, show
  detail, the Guide's hold), **with the same result messages.**"* The panel's Edit pass → Delete
  would then keep showing "● Scheduled" where the sheet no longer does.
- DECISIONS.md:2556, 2026-09-16 (Pass 108): *"**Mirrored, not called — none of those screens was
  edited.** Record mirrors `AiringSheet.record()`; the live pass button `AiringSheet.recordSeries()`
  and its editor block;"* The mirror at `PlayerInfoPanel.swift:198-205` diverges from
  `AiringSheet.swift:137-157`.
- COLD-START.md:65: *"each **mirroring** the airing sheet's, show detail's or the Guide hold's control
  with the same result messages, none of those screens changed"*.

**(e) Only with the owner's own words authorising two writes, create a pass and delete it, or his own
presses.**
1. In the Guide, open an airing flagged New, well ahead, on a show with no pass. A new pass defaults
   to new episodes (`passes.go:716`).
2. Record the series; the chip reads "● Scheduled · Queued".
3. Edit series pass → Delete; the sheet shows "Record this airing" and the mark is gone.

**Stays traced:** `:169` (needs a second client's write); the failed-read branch; the Search and On
Later hosts; the panel's copy.

**(f) One question — §5.**

### S14 — Favorites never re-reads and hands the Player an ended programme

**(a) Holds.**
- Favorites reads once, in the one-shot `.task` at `FavoritesScreen.swift:92-96`.
- The Player's root `fullScreenCover` (`ContentView.swift:53-56`) leaves that task alive and never
  re-runs it. So the rows keep the old title and end time (`:163`, `:167`).
- `:118` hands the Player the ended programme, labelled "‹title› · until ‹past time›" by
  `PlayRequest.swift:112`.
- Precisions:
  - On Now's 60 s loop narrows the staleness to 60 s rather than removing it;
  - the same label also reaches 6d, Failure and Expired (`PlayerScreen.swift:342`, `:430`, `:466`).

**(b)** `Marlin DVR TV/FavoritesScreen.swift` only, certain: On Now's loop in place of the one-shot
task, with focus set on the first pass only.

REVIEW.md's fallback ("at least when the Player closes") would also touch `ContentView.swift` and
`ScreenShell.swift`'s `railRestore` path. The loop covers the Player-closed case within 60 s, so the
fallback is not needed.

**(c) SWEEP.**

**(d) Records the fix changes.** All three are the Pass 108 call. It was the foreman's, not the
owner's; the owner accepted Pass 108 as a whole, "all good" (DECISIONS.md:2607).
- DECISIONS.md:2537 (2026-09-16, Pass 108, "Foreman calls within those decisions"): *"screens
  underneath show a change made from the panel the next time they are opened."*
- COLD-START.md:65: *"the screens underneath show a change the next time they open"*.
- `reports/2026-09-16-pass108-player-info-panel.md:309`: *"The Guide and Favorites show the change the
  next time they are opened."*

After the fix, a Favorite or Unfavorite made from the panel reaches Favorites within 60 s, possibly
while the Player is still up.

**(e) One run, no data write.**
- Across a programme boundary on a favourite, the row's title and "ends …" change within 60 s while
  focus stays on the same row. Sample it with the remote in the rail and in the content, as Pass 25
  did.
- After a Player round trip spanning a boundary, the rows are current and the next pick's Starting
  screen shows a future end.
- Favorites' subtitle carries no refresh time, so the run must span one or two boundaries.
- On an antenna favourite a live session holds a tuner.

**Stays traced:** whether a timed loop keeps running behind the cover (inferred, COLD-START.md:101); a
failed read during a reload; a focused favourite removed behind the Player.

**(f) None.**

### S15 — every 45 s the camera pictures blink to the "snapshot.jpg" placeholder

**(a) Holds, by trace.**
- Each successful reload bumps `tick` (`CamerasScreen.swift:36`) into the query (`:48`).
- The stateless `AsyncImage` in `ServerImage.swift:19-30` draws the card's fallback (`:127-134`) until
  the new no-store JPEG arrives, usually after a fresh RTSP pull (`cameras.go:201`, `:206` at
  `0fa05e1`, read from source).
- Precisions:
  - only a successful `/api/cameras` read changes the URL;
  - an offline camera already shows "no snapshot";
  - "one by one" is traced — the notebook's last count is one camera;
  - `AsyncImage`'s reset and the blank's length are unmeasured, as REVIEW.md says.

**(b)**
- `Marlin DVR TV/CamerasScreen.swift`, certain. CameraCard keeps the last loaded picture until the new
  one loads, and keeps today's fallback for first load, offline and failure. It must also keep:
  - the `Color.clear` overlay sizing (`reports/2026-09-05-pass6-sweep2-screens.md:26`);
  - the Button and focus (`:82-89`), the loop (`:96-107`) and the query.
- `Marlin DVR TV/ServerImage.swift`, possibly, only as an opt-in whose default leaves the other 14
  callers on today's path.
- Possibly, an evidence method.

**(c) SWEEP** (confined to Cameras).

**(d) None.** For a Cameras-confined fix, DECISIONS.md:253-257 (reloads move no focus),
DECISIONS.md:1636-1638 and :1654-1655 (Pass 86/87 logo fallback, accepted) and DECISIONS.md:101-102
(the now-playing bar's icon) all stand.

**(e) One run, no write.** Stay on Cameras through two reloads. At each "Snapshot age 0-1 s" marker,
sample and screenshot inside the new load's window: the previous picture shows, then changes, and
focus stays on the card. The claims hold at the sampled moments only.

**Stays traced:** an offline or failing snapshot; several cameras; the pre-fix blank's length; the 14
other callers (shown unchanged by the diff).

**(f) None.**

### S16 — Weather's "Try again" after a location failure never asks again

**(a) Holds in part.**

What holds:
- `requested` is set only at `WeatherLocation.swift:119` and never cleared.
- After a failed first request (`:171-172`), Try again (`WeatherModel.swift:95-100`) re-enters
  `start()`, stops at `:118`, and times out at `:127-128`.

What does not hold:
- "Every time until quit" needs the first request never to answer at all. A late
  `didUpdateLocations` (`:153-163`) still caches the fix, and the next Try again succeeds through `:91`.
- "Both Apple TVs already hold a cached fix" is on record for Home Theater only (`pass13 report :327`).
  The bedroom's is unrecorded (`:362`; Pass 22 `:438`).
- The denial-arriving-as-error case rests only on the code comment at `:167-168`.

**(b)** `Marlin DVR TV/WeatherLocation.swift`, certain:
- clear `requested` in `didFailWithError` (`:166-174`, both branches) and in the timeout branch
  (`:127-128`), not in `finish()` as a whole, which also runs on success;
- reword `:63-64`;
- optionally stop the outstanding request at the timeout (`CLLocationManager.h:606`, `:627-628`).

**(c) SWEEP.**

**(d) None.** DECISIONS.md:56's "one-shot" is set against continuous updates, and a retry after a
failure is still one-shot and adds no prompt. The recorded reason for the 25 s timeout
(`pass13 report :187-189`) is kept.

**(e) No dedicated run; S16 stays traced under the one-run budget.**
- S4's run does not reach this path, because each launch starts with `requested` false.
- A failed first request cannot be produced on Home Theater on demand.
- A reinstall would wipe the client id, and the next launch would register again, a server write.
- The Simulator route needs a tvOS simulator runtime, and **none is installed on this Mac**: Xcode
  27.0 (27A266a); `xcrun simctl list runtimes` lists none. Installing one needs the owner's
  authorisation.

**Stays traced:** Try again after a failure; timeout then Try again; the kCLErrorDenied path; a late
callback during the retry; tvOS's handling of a second outstanding request.

**(f) None.**

---

## 4. The server read (S10, and source checks for S5, S7, S9, S13, S15)

- **The commit.** `gh api repos/marlin1111ai/marlin-dvr/commits/0fa05e13927b202df469a430789df9c9683c73c4`
  returned that SHA, committed 2026-09-20T03:15:06Z. This is the commit the notebook names
  (COLD-START.md:44).
- **How it was read.** The tree was listed with `git/trees/…?recursive=1`. Each file was read with
  `gh api -H "Accept: application/vnd.github.raw" repos/marlin1111ai/marlin-dvr/contents/<path>?ref=0fa05e1…`,
  piped to `grep`, `sed` or `awk` on the terminal. **No server file was written to disk**, and none is
  on this Mac now. The excerpts the readers printed exist only in this session's own transcript.
  Nothing was cloned. `~/Xcode/marlin-dvr-reference` does not exist.
- **Query parsing, for S10:**
  - `go.mod:3` is `go 1.27`.
  - `cmd/marlin-dvr/main.go:368` returns `a.logRequests(mux)`, and `:460` builds the `http.Server` with
    `Handler: a.routes()`. There is no `AllowQuerySemicolons`.
  - `logRequests` logs only `r.URL.Path` (`:172-192`).
  - `guide.go:816-817`: `handleGuideSearch` reads `title` with `r.URL.Query().Get`, lower-cases and
    trims it, returns `[]` when it is empty (`:831`), and compares for equality (`:836`).
  - `guide.go:860-861`: `handleGuideFind` reads `q` the same way (empty → `[]` at `:873`).
  - `artwork.go:477`: `handleArtFeed` reads `u`, and answers 400 when it is missing (`:479-481`).
  - `artwork.go:501`: `handleArtShow` reads `title`, and answers 404 when it is empty (`:502-504`).
  - `handleGuide` (`guide.go:650-671`), `handleChannels` (`sources.go:1048`) and the library reads
    (`library.go:469`, `:633`) all use `r.URL.Query()` too. No handler uses `FormValue` or its own
    parser.
  - Go's own rule, that a pair containing ";" is dropped and `URL.Query()` discards the error while
    "+" decodes to a space, was read in the Mac's local Go 1.26.3 standard library
    (`net/url/url.go:174`, `:965-967`, `:1154-1157`). That it still holds in 1.27 is inferred.
- **Source checks for other items.** All at `0fa05e1`, all **read from source, not measured** against
  the running server (COLD-START.md:44):
  - S5: `stream.go:664-666`, `playfile.go:103-107`;
  - S7: `passes.go:388-389`, `:395-396`;
  - S9: `library.go:127-130`, `:811-839`; `stream.go:584-588`;
  - S13: `passes.go:716`, `:799-823`, `:938-949`;
  - S15: `cameras.go:201`, `:206`, `:432`.

---

## 5. Question for the owner

1. **S13 — the Player's info panel.** REVIEW.md's S13 names only the airing sheet. The Player's info
   panel has the same line: on live TV, Edit pass → Delete re-reads with `?? job`
   (`PlayerInfoPanel.swift:203`), so the panel keeps showing "● Scheduled" for a booking the deleted
   pass no longer holds.

   Your Pass 108 decision was that each panel button does what the airing sheet's control does
   (DECISIONS.md:2530-2532). Fixing the sheet alone makes the two differ here.

   **Should S13 fix the panel's copy too, or fix the sheet only and record the panel as differing?**
   Fixing the panel is slightly bigger: its schedule read returns nothing when it fails
   (`:482-490`), and it sits in the code S12 reworks.

No other question passed the three tests.

---

## 6. What I am least sure of

1. **Whether G can be built inside the Guide at all.** Nothing at HEAD can stop the engine carrying
   Left from a channel cell into the rail. Whether that crossing even delivers a move command to the
   grid has never been measured. So whether `ScreenShell.swift` — Pass 25's 27-of-27 path — has to
   change is open until the build's one run.
   A reading call sits beside it. "The mirror of Pass 77's Right" alone would point at the row's first
   programme cell. G's explicit clause, "would otherwise take focus out of the grid into the sidebar",
   decides for the channel cell, and that is how it is sorted.
2. **Whether option A of S1 is safe.** If `-only-testing` does not run a class from a testable marked
   `skipped = "YES"` with an auto-created test plan, option A silently breaks every recorded harness
   command. One `xcodebuild` invocation settles it. None was made here.
3. **S11's STANDALONE call.** The notebook never uses the words "fragile" or "load-bearing" for
   `fetch`. I read Pass 116's recorded placement of the override clear and its accepted "no notice is
   coalesced away" as load-bearing. The race's width is also unmeasured: a 48-slot `GET /api/guide`
   has never been timed.
4. **Whether S6 crashes at all.** If tvOS 26.6 cancels the not-ready seek rather than raising, S6's
   harm is the cancelled resume seek and the lost saved spot. The fix is the same either way.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `reports/2026-09-24-pass119-review-should-fix-sort.md` | 2–3 (written in 3) | new — this report |
| `DECISIONS.md` | 4 | appended the Pass 119 entry |
| `COLD-START.md` | 4 | *Closed by the owner's call of 2026-09-20*: two bullets added at its end (the 2026-09-23 closure of C1, S3, N23, N24; the not-picked line). *Next step*: a new paragraph on top for this batch, with Pass 118's paragraph kept beneath it, labelled |

**Nothing else was written.**
- No app-target file, test-target file, project file, scheme, `design/` file, `REVIEW.md`,
  existing report or `icon-source/` file changed.
- `COLD-START-HISTORY.md` was not touched. The pass names three files, so Pass 118's *Next step*
  paragraph stays in `COLD-START.md` under a label rather than moving there by Pass 89's rule.
- `COLD-START.md`'s *Open questions* section still reads "None" although §5's question now waits on
  the owner. The pass named only the closed section and *Next step*, so the question is carried in
  *Next step* and left out of that section.
- The readers' scratch outputs in the session scratchpad were deleted after this report was written.
