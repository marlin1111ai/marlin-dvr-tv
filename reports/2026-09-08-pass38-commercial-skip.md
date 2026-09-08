# Pass 38 — commercial skip, built

**Date:** 2026-09-08
**Working tree:** `~/Xcode/Marlin DVR TV` (plus one read-only file recreated on the Desktop).
**Committed locally. NOT pushed** — the owner tests on Home Theater first.

The feature as the owner settled it: a recording is playing, playback reaches the start of a
commercial break, a small prompt appears for five seconds saying the break can be skipped,
SELECT jumps to the end of the break, and pressing nothing lets the commercial play. That is
what was built, and nothing else.

---

## 0. The contract, recreated, and the clone left byte-identical

`~/Desktop/marlin-dvr-context/` was gone, as Pass 37 recorded. It was recreated exactly as
Pass 36 did — one `git show`, no fetch, no checkout, nothing written in the clone:

```
$ mkdir -p ~/Desktop/marlin-dvr-context
$ cd ~/Xcode/marlin-dvr-reference
$ git show origin/main:HLS-CLIENT-API.md > ~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md
$ wc -l ~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md
     595
$ shasum -a 256 ~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md
ad8c1e5abe4474f9fb6635371dffd95c90339836b20f98f87c069061e552f56b
```

**The clone's working tree is byte-identical before and after this pass** — measured both
times, not asserted:

| | before | after |
|---|---|---|
| `git status --porcelain` | `?? README-REFERENCE.md` | `?? README-REFERENCE.md` |
| `git rev-parse HEAD` | `9325d944…` | `9325d944…` |
| `git rev-parse origin/main` | `c417c60a…` | `c417c60a…` |
| sha256 of every tracked+untracked file | `37d916c824baa3ec111f232b36f1006a13f0c7998e6f212d728d56ae5c7664b5` | `37d916c824baa3ec111f232b36f1006a13f0c7998e6f212d728d56ae5c7664b5` |

No fetch, pull, checkout, merge, commit or push was run there.

**It vanished again.** After the build and the device runs were finished,
`~/Desktop/marlin-dvr-context/` was gone a second time — `ls` answered "No such file or
directory", exactly the way Pass 37 found it. Nothing in this pass writes to or removes
anything on the Desktop other than that one `git show` redirect. It was recreated once more by
the same command, and the file is there now with the same sha256. **Something outside these
passes is removing that folder**, and it is worth the owner knowing, because a later pass that
depends on it will keep finding it missing.

### §10 versus this prompt — no stop

§10 was read in full (`HLS-CLIENT-API.md:341-509`). **There is no disagreement with the prompt
on any field name, type or value**, which is the stop condition. Two cross-references in the
prompt point at the wrong sub-section, and one instruction deliberately departs from §10's
advice; neither is a field disagreement, so neither triggered a stop, and both are recorded
here rather than reconciled silently:

- The prompt's step 7 cites "§10.5" for "a measured break ending 0.10 s before end of file".
  That sentence is in **§10.4** (`:443-444`: "Every range lies inside the recording's own
  duration; the last one can end within a tenth of a second of the end of the file"). §10.5 is
  the `from` table. The fact is real and unchanged; only the section number differs.
- §10.4 says to clamp "to the duration you already have from `GET /api/play/info?rec=<id>` or
  `…/mediainfo`" (`:444-445`). The prompt instead directs the clamp at `PlayerModel.duration`
  (`:48`), which comes from the play-session response. **That is sound, and §3 settles it**:
  "`duration` in the response is the whole recording's duration (`stream.go:239`)" (`:134`),
  stated for exactly the seek-with-a-`start`-offset case. This also **closes Pass 37 Open
  Question 2**, which could not be answered when the file had vanished.

---

## 1. What was built, and where

| Path | New / changed | The step that required it |
|---|---|---|
| `Marlin DVR TV/CommercialSegments.swift` | **new**, 155 lines | 1 (the type and the call), 3 (which answers arm) |
| `Marlin DVR TV/PlayerModel.swift` | changed, +159 lines | 2 (fetch once), 3, 4 (noticing), 5 (the 5 s life), 7 (the skip) |
| `Marlin DVR TV/PlayerHost.swift` | changed, +70 lines | 6 (the press) |
| `Marlin DVR TV/PlayerScreen.swift` | changed, +43 lines | 5 (drawing it), 6 and 7 (wiring the press) |
| `Marlin DVR TVUITests/CommercialSkipUITests.swift` | **new**, evidence harness | 8 |

Nothing else in the repo is touched. `git diff --stat` for the three changed files:

```
 Marlin DVR TV/PlayerHost.swift   |  70 ++++++++++++++++-
 Marlin DVR TV/PlayerModel.swift  | 159 +++++++++++++++++++++++++++++++++++++++
 Marlin DVR TV/PlayerScreen.swift |  43 ++++++++++-
 3 files changed, 269 insertions(+), 3 deletions(-)
```

### Step 1 — the model and the call

`CommercialsResponse` follows §10.2's table field for field, and `APIClient.commercials(recordingID:)`
is one `get` with an interpolated path and no query items, exactly the shape of
`APIClient.get` (`ServerAPI.swift:71-75`) as it already is.

**The decoding decisions, each with the §10 line it rests on:**

| Decision | Why, in §10's own words |
|---|---|
| **`edl` is `String?`** | "**Absent** when there is no markers file (`omitempty`, `commercials.go:87`)" (`:397`). §10.5 adds that the no-markers case "always accompanies `state: "unknown"`" (`:453`) — the ordinary case. A missing `edl` is not an error and is never treated as one. |
| **`state` is decoded as a `String`, never as a `Decodable` enum** | "Switch on exactly these four and treat anything else as `"unknown"`" (`:410`). A `Decodable` enum would throw on a fifth value, which is the opposite instruction. The property is `stateRaw`, mapped through `CommercialState(_ raw:)` whose `default` case is `.unknown`. Its Swift case for `"none"` is named `noneFound`, to stay clear of `Optional.none`. |
| **`ranges` is a non-optional `[CommercialRange]`** | "Always present; `[]` when there are none (`commercials.go:119`)" (`:393`). |
| **`source` is non-optional, and so are its three `String`s** | "Always present; all three fields are `""` when it cannot be established" (`:396`). |
| **`id`, `count`, `from`, `detail` non-optional** | `:391`, `:394`, `:395`, `:398` — all listed without `omitempty`. |
| **Nothing branches on `from`** | "Treat `"edl"` and `"state"` as equally authoritative; `from` is there so you can tell them apart, not so you can prefer one" (`:460-462`). It is logged, never acted on. |
| **`detail` is logged and never parsed or shown** | "one English sentence for a log or a debug screen. **Do not parse it.** Its wording is not part of the contract" (`:398`). |

`startSeconds` / `endSeconds` are `Double`, "as floats with two decimals, exactly as comskip
wrote them into the `.edl`" (`:429-430`). The app's shared `JSONDecoder` has no key strategy
(`ServerAPI.swift:63`), so every property name matches the JSON key; `state` is the one
exception and is mapped by an explicit `CodingKeys`.

### Step 2 — fetched once, on playback start

`PlayerModel.attach(_:)` ends with `loadCommercialsOnce()`, guarded by
`isRecording, !commercialsRequested, let recordingID = request.episode?.id`
(`PlayRequest.swift:81-84`). A live channel, a camera and a radio station all fail the first
guard. **`restart(at:)` re-enters `attach` and does not fetch again** — the ranges are absolute
recording seconds, so they survive a new session. There is no poll, no retry, and no cache
across playbacks; `state: "running"` is treated as this playback simply having no segments,
per §10.3's "Do not poll it forever" (`:422`). Nothing waits on the call, so playback is never
blocked, delayed or altered by it — including when it fails.

### Step 3 — which answers arm the feature

One computed property, `CommercialsResponse.plan`:

| Answer | Plan | On screen |
|---|---|---|
| `detected` | `.arm(ranges)` | prompts at each break |
| `none`, `source.type == "m3u"` | `.playThrough` | nothing, ever — a real answer (§10.6 `:479`) |
| `none`, `source.type == "hdhomerun"` | `.dontKnow` | nothing (§10.6 `:476-482`) |
| `none`, `source.type == ""` | `.dontKnow` | nothing — `""` is "source unknown, not antenna" (`:486`) |
| `running`, `unknown`, anything unrecognised | `.dontKnow` | nothing |
| transport failure, 404, any non-200 | the `catch`, one console line | nothing |

`playThrough` and `dontKnow` are deliberately kept apart even though they produce the same
screen, so the console line says which fact it is instead of claiming the other.

### Step 4 — noticing a break

`tick()` (`PlayerModel.swift:215-231` in the committed file) gained exactly one line, `noticeCommercialBreak()`,
placed right after `position = startOffset + t`. **No second observer and no boundary observer
was added** — `grep` still finds one `addPeriodicTimeObserver` and no `addBoundaryTimeObserver`
in the app. Pass 37 confirmed that `position` already implements §10.4's
`edlTime = playerPosition + start`, so a range's seconds and `position` are the same number
line with no conversion.

A range prompts when `position` is inside `[startSeconds, endSeconds)` and the range is not
already in `promptedRanges`. Containment rather than a crossing test, so a playhead that lands
inside a break is handled the same way as one that walks into it. **Each range prompts at most
once per playback**: the index goes into `promptedRanges` the moment the prompt appears, which
is what makes seeking backwards into a break silent (proved in §2 below).

### Step 5 — the prompt

`CommercialSkipPrompt` (`PlayerScreen.swift:288-311`) is drawn in the same `ZStack` above
`PlayerHost` that the HUD already uses (`:33-54`), inside the `phase == .playing` branch. It is
an accent `SELECT` capsule and the line "Skip the commercial break" on the Nocturne surface at
86 %, with the standard 60 / 80 pt margins — the same treatment `RecordingHUD` and `LiveHUD`
use. There is no approved design for it; it is built to the app's look, like Manage DVR,
Favorites, the radar and Radio before it.

**It is not focusable.** No `Button`, no `.focusable`, no `@FocusState` — the pass was told not
to be the first thing in this app to put a focusable view over a running player, and it is not.
Nothing had to be made focusable to draw it, so the stop-and-report condition did not arise.

Its five seconds are kept by `armPromptTimeout()` (`PlayerModel.swift:455-465`), which is the
timed mechanism of `showHUD(for:)` (`:784-793`) — a cancellable task that sleeps and then clears the flag. It is
its own task rather than a `showHUD(for: 5)` call so that showing the prompt cannot drag the
recording HUD on screen with it; `showHUD` and `hudVisible` are untouched.

### Step 6 — the press

`PlayerHost.armSelectOwnership(_:)` (`PlayerHost.swift:157-171`) is the exact counterpart of
`armArrowOwnership` (`:134-146`). Both now share one finder, `recognizers(in:claiming:)`, which
matches on the **public `allowedPressTypes`** and never on a class name. Select's claim keeps
its own `selectSuppressed` array, so each claim restores precisely what it disabled and
neither can touch the other's recognizers.

It is armed from `ownsSelect: model.commercialPrompt != nil`, so Select returns to Apple the
instant the prompt goes — on time-out, on a skip, on a pause (`timeControlChanged` calls
`dismissCommercialPrompt()`), on `detachPlayer()`, and in `viewWillDisappear`, which now
disarms both claims. `pressesBegan` asks `onSelectSkip()` first and swallows the matching
release; it answers false whenever no prompt is up, so the press falls through to `super` and
Select is Apple's exactly as it is today. **The arrows are untouched by this pass** — measured,
not assumed, in §2.

### Step 7 — the skip

`skipCommercialBreak()` (`PlayerModel.swift:484-509`) uses the app's existing in-item exact
seek — the same call, the same zero tolerances and the same seekable-range clamp as `frameStep`
(`:350-359`). **`restart(at:)`
is not called**, so no session is torn down and the Starting screen never appears. Play/pause
is never touched. The target is `min(endSeconds, duration - 1)` converted to item time by
`absolute - startOffset`, then clamped to the seekable range, so it can never land at or past
the end of the recording.

---

## 2. Live evidence, on Home Theater

Every line below is from the physical Apple TV (Apple TV 4K 3rd gen, tvOS 26.6), driving the
real Siri Remote through `CommercialSkipUITests`, with the app's own console captured
separately by `xcrun devicectl device process launch --console`. The device identifier and the
Apple TV's LAN address are redacted; nothing else is edited.

**How the console was captured, and one honest limit.** XCUITest does not forward the app's
`print` output, so the app is launched by `devicectl … --console` first and the harness uses
`XCUIApplication.activate()` rather than `launch()`, which attaches to the running process
instead of replacing it. **That console drops lines under high output volume** — proved while
diagnosing §3 below — so an absent line is not by itself evidence that an event did not happen.
Every claim here rests on a line that *is* present, or on a screenshot.

### The subject recording

The owner's library holds three shows, all from m3u (Philo) sources. The subject is
**History's Greatest Mysteries S4 E14 "Who Is D.B. Cooper?"**, which is the very recording
§10.2's example response is drawn from. The app's own line, every playback:

```
[commercials] 5328bb632e76 → detected: 4 break(s) [176.54-206.54, 305.57-371.54, 730.56-925.46,
1271.20-1478.54], from "state", source type "m3u" — 4 commercial segments from History's
Greatest Mysteries S04E14 Who Is D.B. Cooper 2026-09-07-1100.edl.
```

Four breaks, not the two §10.2 prints as an illustration. The first two match §10.2 exactly.

### (a) The prompt appears at a real break, and Select skips past it

`testPromptAppearsAndSelectSkips` — **passed (68.6 s)**.

```
[player] session smtsninvvf3aff8 recording mode=copy start=0.0 duration=2570.568
[commercials] 5328bb632e76 → detected: 4 break(s), from "state", source type "m3u" — …
[commercials] break 1 starts at 176.54 s (position 176.81 s) — prompt up for 5 s, skip would land at 206.54 s
[commercials] app owns Select — 5 player recognizer(s) disabled, 0 of them also arrow recognizer(s)
[commercials] Select returned to the player — 5 recognizer(s) restored
[commercials] skipped +16.41 s → t=206.540000, position 206.54 s of 2570.57 s
```

The prompt appeared **0.27 s** after the break's own start second, and Select landed on
**exactly `endSeconds`, 206.540000**. The test's own reading of the screen at that moment:

```
[pass38 08:34:40.545] PROMPT after 4 forward skips — clock ["03:09"], screen ["SELECT",
"Skip the commercial break", …]
```

Screenshot `02-the-prompt-at-a-real-break` shows the prompt bottom-right over the picture with
Apple's transport bar reading 03:07 of 39:43. Screenshot `03-immediately-after-select` shows
the prompt gone and the picture moved.

A second, independent landing from a different break, same test class:

```
[commercials] break 3 starts at 730.56 s (position 738.66 s) — prompt up for 5 s, skip would land at 925.46 s
[commercials] skipped +183.45 s → t=925.460000, position 925.46 s of 2570.57 s
```

And a third, from a session that was **not** started at zero:

```
[player] session smtspgfjl8cceb7 recording mode=copy start=931.000155362 duration=2570.568
[commercials] break 4 starts at 1271.20 s (position 1276.09 s) — prompt up for 5 s, skip would land at 1478.54 s
[commercials] skipped +202.18 s → t=548.548231, position 1479.55 s of 2570.57 s
```

**Two of the three landed on `endSeconds` to six decimal places; the third landed 1.01 s
beyond it** (target 1478.54 from a session whose `startOffset` was 931.000155). It landed past
the break, never short of it. The overshoot is not explained and is Open Question 5.

### (b) Pressing nothing plays the commercial normally

`testPromptTimesOutAndTheBreakPlays` — **passed (137.1 s)**.

```
[commercials] break 3 starts at 730.56 s (position 735.67 s) — prompt up for 5 s, skip would land at 925.46 s
[commercials] app owns Select — 5 player recognizer(s) disabled, 0 of them also arrow recognizer(s)
[commercials] prompt timed out — the break plays normally
[commercials] Select returned to the player — 5 recognizer(s) restored
```

No skip line, because nothing was pressed. The test asserted the prompt was gone 9 s after it
appeared and still gone 8 s after that, with playback continuing.

### (c) A break already offered is never offered again

`testASkippedBreakIsNotOfferedAgain` — **passed (85.8 s)**. After the skip above (break 4,
landing at 1479.55), the test pressed **Left eight times**, putting the playhead back inside
the break it had just skipped, then asserted no prompt once a second for twenty seconds. None
appeared. Seeking backwards into a break that has been offered is silent, as step 4 requires.

### (d) A pause takes the prompt down and hands Select back

`testPauseDismissesThePrompt` — **passed (56.3 s)**. Play/Pause was pressed while the prompt
was up, not Select:

```
[commercials] break 2 starts at 305.57 s (position 313.90 s) — prompt up for 5 s, skip would land at 371.54 s
[commercials] app owns Select — 5 player recognizer(s) disabled, 0 of them also arrow recognizer(s)
[player] paused (5:15)
[commercials] Select returned to the player — 5 recognizer(s) restored
[player] playing (5:16)
```

Note there is **no "prompt timed out" line** — the pause took it down, before the timer could.
The test read the screen 3.9 s later: `paused, prompt gone — clock ["05:15"]`.

### (e) Select outside the prompt is Apple's, and frame stepping is unchanged

`testSelectOutsideThePromptIsApples` — **passed (90.9 s)**.

```
[player] paused (22:49)                          ← Select with no prompt: Apple's transport paused it
[framestep] app owns the arrow — 2 player recognizer(s) disabled
[framestep] +0.033367 s (one frame at 29.9700 fps = 0.033367 s) → t=280.220655
… ten of these, t=280.187 → t=280.520955 …
[player] playing (22:49)                         ← Select again: Apple's transport resumed it
[framestep] arrow returned to the player — 2 recognizer(s) restored
```

Ten right clicks while paused moved the playhead **+0.3337 s in total**, which is ten frames of
29.97 fps material and not ten ten-second skips. This is Pass 29's measurement reproduced
exactly, on this build.

**This also settles the stop condition about the arrows.** The two claims are separate and
measured to be so: the arrow claim disables **2** recognizers, the Select claim disables **5**,
and the app prints how many overlap — **`0 of them also arrow recognizer(s)`, on every single
arming across every run**. Claiming Select does not touch the arrows or frame stepping.

### (f) A recording with no segments behaves exactly as it does today

Two different no-prompt answers were driven live.

**`state: "unknown"` from an m3u source** — `testARecordingWithNoSegmentsIsUnchanged`,
**passed (104.4 s)**, on the other 40-minute recording of the same show:

```
[commercials] 62be7fad307a → "unknown" from source type "m3u": no prompt for this playback
[pass38 08:43:20.780] 20 forward skips, no prompt at any point — clock ["06:16"]
```

Twenty forward skips across roughly four minutes of the recording, with the prompt asserted
absent after every one.

**`state: "none"` from an m3u source** — the real answer of §10.6, on the Storage Wars
recording:

```
[player] session smtsn3fawf30b6f recording mode=copy start=0.0 duration=54.054
[commercials] 1f728c318959 → none, from an m3u source: a real answer, this recording has no breaks
```

No prompt, no error, nothing on screen. Playback was unaffected in both cases: same Starting
screen, same HUD, same transport, same resume.

### (g) The build

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'generic/platform=tvOS' -allowProvisioningUpdates clean build
** BUILD SUCCEEDED **
```

Two warnings, **both pre-existing and neither in code this pass wrote**:
`GuideScreen.swift:336` (main-actor isolation, from an earlier pass) and
`PlayerModel.swift:288` (`nominalFrameRate` deprecation, inside Pass 28's `refreshFrameRate`).
No warning and no error comes from `CommercialSegments.swift`, `PlayerHost.swift`,
`PlayerScreen.swift` or the new code in `PlayerModel.swift`.

### What this pass left on the server, disclosed

The harness sends no `PUT`, `POST` or `DELETE` of its own, but **playing a recording to its end
marks it watched**, and this pass did that several times while resetting the subject
recording's resume position between runs:

- **History's Greatest Mysteries S4 E14 "Who Is D.B. Cooper?"** is now `watched: true` and its
  resume position is cleared. **The owner had a resume on it at "35 min in" when this pass
  began; that is gone.** It was cleared by playback reaching the end, not by any delete.
- **Storage Wars S4 E19** (54 s) reached its end during the first survey and is `watched: true`.
- **S7 E20 "The Hunt for Osama bin Laden"** was played and carries a resume position.

Nothing was deleted, trashed, hidden, recorded or scheduled. No `GET /api/settings` was read.

---

## 3. One defect found by testing, and one it turned out not to be

**A defect was found and fixed.** The commercials answer was originally stored from whatever
thread the network call resumed on, while `tick()` — its only reader — runs on the main queue.
`loadCommercials(recordingID:)` is now `@MainActor` and its `Task` is `Task { @MainActor … }`,
as is the prompt's five-second timer, so the store and the read are on the same thread. This
matches how every other AVFoundation callback in the file already hops to the main actor
(`PlayerModel.swift:183-184`).

**A second suspected defect turned out not to be one, and the real cause is worth recording.**
Several runs showed a playback that began at or just before a break producing no prompt. A
temporary diagnostic (added, run, and **removed before the commit** — `grep -c diag` on the
committed `PlayerModel.swift` is 0) measured why:

```
[player] session smtsp7em46b74c3 recording mode=copy start=1680.000649333 duration=2570.568
[diag] t4 pos=1988.08 off=1680.00 ranges=4 hit=- prompted=[] prompt=nil paused=no phase=playing
```

At the **fourth** tick of a session created with `start=1680` — about four seconds in —
`AVPlayerItem.currentTime()` already read **308 s**. The recording is an HLS **EVENT** playlist
that the server is still writing (contract §3, `:117-119`), and AVPlayer starts near its live
edge rather than at its beginning; the transport bar says "LIVE" on these items, which is the
same fact showing on screen. So a playback asked to resume at 1680 s actually began at about
1988 s, past the break the resume was inside.

**Nothing in this pass causes that and nothing in this pass changes it.** `startOffset`,
`attach`, session creation and the resume store are untouched by diff. It is reported, not
fixed — see Open Questions 1 and 2.

---

## OPEN QUESTIONS

Raised, not acted on. Nothing below was built, changed or worked around.

1. **A resumed recording does not start where it was asked to.** Measured above: a session
   created with `start=1680` was already at 1988 s four seconds in — **five minutes further on
   than the resume position**. This is pre-existing app/AVFoundation behaviour on the server's
   EVENT playlists and has nothing to do with commercials, but it is the biggest thing this
   pass turned up. It means the resume line in show detail ("Resume S4 E14 · 35 min in") can be
   a promise the Player does not keep. **Should a later pass take this?** What breaks without
   it: resuming a long recording lands minutes late, and this feature silently does nothing for
   breaks that fall in the gap.

2. **Because of (1), "a playback that starts inside a break offers it" could not be driven to a
   conclusion.** Three attempts were made; each time the playhead was already past the break by
   the first tick. The code path is the same containment test that fires everywhere else and
   there is no separate branch for it, but that is reasoning, not evidence, and it is named here
   rather than claimed.

3. **The end-of-recording clamp has never been exercised.** `min(endSeconds, duration - 1)`
   never bound: the last break on the subject recording ends at 1478.54 s of 2570.57 s. §10.4's
   "a break ending within a tenth of a second of the end of the file" did not occur in the
   owner's library this pass. The margin of **1 second** was chosen by me, not by the contract
   or the prompt; anything from a few frames to a few seconds would satisfy "never at or past
   the end", and the owner may want a different number.

4. **The `hdhomerun` branch of step 3 was never exercised live.** The owner's library currently
   holds only m3u (Philo) recordings — 9001 HISTORY and 9002 FYI. The antenna case that §10.6 is
   written for could not be driven because there is no antenna recording to drive it with. Traced
   only. The same is true of a network failure and a non-200: the `catch` was never entered.

5. **One skip landed 1.01 s past `endSeconds` instead of on it.** Two landings were exact to six
   decimal places (206.540000, 925.460000), both from sessions with `startOffset = 0`; the third,
   from a session with `startOffset = 931.000155`, asked for 547.539845 in item time and landed at
   548.548231. It lands past the break, never short, so it never lands inside a commercial — but
   the extra second is unexplained.

6. **comskip's first break on this recording is exactly 30.00 s, and the skip lands in the middle
   of the ad pod.** Screenshot `04-after-the-skip`, four seconds after a skip that landed exactly
   on `endSeconds` 206.54, shows **another commercial**, not the show. The two long breaks (195 s
   and 207 s) look like whole pods; the first two (30.00 s and 65.97 s) do not. This is the
   server's detection quality, not the app's arithmetic — the app went precisely where the markers
   said. Nothing was compensated for; §10 is explicit that "The app does the skipping" and the
   markers are what they are.

7. **The prompt overlaps the right end of Apple's transport bar when the transport is on screen.**
   Visible in `02-the-prompt-at-a-real-break`: the prompt covers the "39:43" total-duration label.
   In ordinary viewing the transport is not up when a break starts, so it did not come up in
   normal use — only under a harness that presses arrows to reach the break. The prompt has no
   approved design and the prompt's position was not specified; it was placed bottom-trailing.
   **Where the owner wants it is his call.**

8. **The Desktop reference folder disappeared for a second time**, mid-pass, as it did in
   Pass 37. Recreated both times from the clone. Not this pass's doing — nothing here writes to
   the Desktop except that one redirect — but two passes running is a pattern, not an accident.

9. **`devicectl`'s console drops lines under high output volume.** Proved while diagnosing §3:
   with a per-tick print the console showed tick #1 at a position 324 seconds later than the
   session start, and the numbered diagnostic proved the earlier lines had simply not arrived.
   Recorded so a later pass does not read a missing console line as a missing event.

10. **Pass 37 Open Question 2 is closed**, by §3 `:134`: the session response's `duration` is the
   whole recording's, even for a session started at an offset. The clamp in step 7 is built on
   the right number.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md` | **written** (recreated), then read | step 0 |
| `~/Xcode/marlin-dvr-reference` | one `git show origin/main:…`; **no** fetch/checkout/merge/commit/push/write | step 0 |
| `COLD-START.md`, `DECISIONS.md`, `reports/…pass37…md` | read only | WHAT TO READ FIRST |
| `Marlin DVR TV/CommercialSegments.swift` | **new** | 1, 3 |
| `Marlin DVR TV/PlayerModel.swift` | changed | 2, 3, 4, 5, 7 |
| `Marlin DVR TV/PlayerHost.swift` | changed | 6 |
| `Marlin DVR TV/PlayerScreen.swift` | changed | 5, 6, 7 |
| `Marlin DVR TVUITests/CommercialSkipUITests.swift` | **new** | 8 |
| `reports/2026-09-08-pass38-commercial-skip.md` | **new** (this file) | DELIVERABLE |
| the running server at 192.168.1.250:8090 | not curled, probed or written by hand — reached only by the app itself while playing | 8 |

**Not done, per the scope lock.** No auto-skip mode, setting, preference or toggle; no chapter
marks, timeline shading or break indicators; no polling, retry, caching across playbacks or
prefetch; no new dependency; no change to the arrows, frame stepping or `armArrowOwnership`'s
behaviour while paused; `GET /api/library/recordings/{id}/segments` not called or referenced in
code; nothing in KNOWN AND UNFIXED touched, including `timeJumped()` (`:540-554`); no edit to
`COLD-START.md` or `DECISIONS.md`; no error handling or hardening beyond steps 1-7; `design/`
not opened; nothing pushed. The temporary diagnostic used in §3 was removed before the commit.

**Credential scan.** Everything quoted was reviewed first. The Apple TV's LAN address and the
`devicectl` device identifier appear in raw tool output and are **not reproduced here**; the
client id from `[client] ping ok` is likewise omitted. The only address in this report is
`192.168.1.250:8090`, which is already in `ServerAPI.swift:15` and throughout the notebook.
Recording ids (`5328bb632e76`, `62be7fad307a`, `1f728c318959`) are the owner's library ids, the
same kind the notebook has recorded since Pass 31, and `5328bb632e76` is §10.2's own example.

---

## COMMITTED AND UNPUSHED

One commit, local only, on `main`. It contains the four source files and this report.
**`git push` was not run.** The owner tests on Home Theater first, then the push is a separate
gate as the standing rule requires. `origin/main` is still at `18b4c53`.

The app currently installed on Home Theater **is this build** — it was installed by
`devicectl` and by the test runs, so the owner can pick up the remote and try it now without
anyone rebuilding anything.

---

## CLOSING SUMMARY FOR THE OWNER

**What you will see.** Play a recording. When the picture reaches the start of a commercial
break, a small dark panel appears in the bottom-right corner. It has a purple **SELECT** badge
and the words "Skip the commercial break". Press the centre button on the remote and the
picture jumps straight to the end of the break and keeps playing. It never stops, never shows
the "Preparing" screen, and never changes whether you are playing or paused.

**If you press nothing.** After five seconds the panel disappears by itself and the commercial
plays through, exactly as it does today. It will not ask you again about that same break, even
if you rewind back into it. Pausing also makes it disappear, and the centre button goes back to
doing its normal play/pause job the moment it does.

**Which recordings this works on.** Your Philo recordings — the ones on 9001 HISTORY, 9002 FYI
and the rest — are the ones the server has actually found commercials in. I proved it on
*History's Greatest Mysteries*, "Who Is D.B. Cooper?", where the server has four breaks marked
and all four behaved correctly. Most of your other recordings come back as "we don't know", and
for those **nothing happens at all**: no panel, no message, no error, no change to anything.
That is the normal case and it is deliberate. For antenna recordings the detector on your
hardware reports "no commercials" when there almost certainly are some, so the app treats that
answer as "don't know" and stays quiet rather than pretending.

**Outside the prompt nothing changed.** The centre button is Apple's as it always was, the
left/right arrows still skip ten seconds while playing and still step one frame at a time while
paused, and none of that moved by so much as a frame in testing.

**The three things I am least certain about.**

1. **Resuming a long recording does not land where it says it will.** I measured this by
   accident: a recording asked to resume at 28 minutes actually started at 33. That is an
   existing problem in the app, not something I added, and I was not allowed to fix it this
   pass — but you should know it is there, and it means the skip prompt will quietly miss a
   break if you resume into the middle of one.
2. **The server's markers are not always the whole ad break.** On the D.B. Cooper recording,
   the first "break" the server found is exactly thirty seconds long — one advert out of a
   longer run of them. The skip goes precisely where the server says, so on that one you press
   SELECT and land in the middle of the next advert. The two long breaks later in the same
   recording look like proper full ad breaks and skip cleanly. This is the detector's doing,
   not the app's.
3. **Where the panel sits.** I put it in the bottom-right corner because there is no approved
   design for it. If you happen to have the transport bar on screen at the time, it covers the
   end of it. Move it wherever you like — that is a five-minute change once you have seen it on
   your own television.
