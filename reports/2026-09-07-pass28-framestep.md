# Pass 28 — Frame-by-frame on paused recordings, by exact seek — 2026-09-07

**It steps a real frame.** Paused on a recording, a right click moves the picture forward by
exactly one frame and a left click back by one. Measured on Home Theater with the real remote:
**+0.033367 s per click on 29.97 fps material** (1/29.97 = 0.033367) and **0.016667 s per click on
59.94 fps material** (1/59.94 = 0.016683) — thirty clicks to cross a second on the first, sixty on
the second, forward and backward alike.

The owner was right and Pass 27 was wrong about the verdict: `step(byCount:)` really is inert on
these HLS items, but that was the wrong mechanism. An **exact seek** — `currentTime() ± 1/fps`
with `toleranceBefore` and `toleranceAfter` both `.zero` — lands on the adjacent frame. Pass 27's
report carries an addendum saying so.

**One honest limit, measured and reproduced: fast repeated clicks are not always ours.** At a
click every 700 ms the app won every press. At a click every 320–420 ms, on the 29.97 fps
recording, Apple's transport took the arrow instead and skipped 10 s. §4 has the numbers.

**Committed locally, not pushed** — this is real playback code and the owner tests it first.

---

## 1. What changed — three files, one behaviour

### `PlayerModel.swift` — the frame rate, and the step

**The frame rate** (`PlayerModel.swift:269-302`). `nominalFrameRate` off the video track is asked
for first, as specified. HLS items very often expose no `assetTrack` at all — Pass 27 read `0`
from it on both recordings — so the fallback is the `AVPlayerItemTrack`'s `currentVideoFrameRate`,
the rate actually being rendered. It is refreshed on every `tick()` while playing
(`PlayerModel.swift:209`), so the real rate is in hand well before anyone pauses, and the default
is 30 until then.

Two guards, both earned on the device:

- **A plausibility window, 10–121 fps.** `currentVideoFrameRate` sags towards zero during start-up
  and rebuffering. The first device run of this pass sampled **2.17 fps** and every frame step was
  then **0.46 s** long — the harness measured 2.17 clicks per second, which is exactly
  self-consistent and exactly wrong. One bad sample poisons every later step, so a reading outside
  the window is ignored rather than adopted.
- **Snapping to a real rate** (`standardFrameRates`, `PlayerModel.swift:293`). `currentVideoFrameRate`
  is a rolling average and reads a little off — Pass 27 measured 30.59 for 29.97 material. A
  reading within 5 % of a standard rate (23.976, 24, 25, 29.97, 30, 50, 59.94, 60) is taken as
  that rate. This is what keeps a step landing *on* the next frame: an over-estimated rate makes
  the step fall short, and two clicks in a row then show the same picture.

**The step** (`PlayerModel.swift:315-338`):

```
guard isRecording, isPaused, phase == .playing, frames != 0, let item = player.currentItem else { return false }
…
item.cancelPendingSeeks()                      // a chase seek would overwrite this with its own tolerance
let from = item.currentTime()
var target = frames > 0 ? CMTimeAdd(from, frameDuration) : CMTimeSubtract(from, frameDuration)
…                                              // clamped to the seekable range
item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { … }
```

`frameDuration` is built at a 90 kHz timescale, where 1/25, 1/30 and 1/29.97 all land within a
microsecond. Each step is computed fresh from `currentTime()`, never from an accumulated frame
index, so it cannot drift. **Play/pause is not touched** — AVPlayer renders the seek target while
paused, so the frame simply appears. The function returns `false` in every case that is not a
paused recording, which is the caller's signal to leave the press alone.

`frameStepLanded` (`PlayerModel.swift:340-349`) refreshes `position` because `tick()` does not run
while paused and the HUD's existing "x of y" would otherwise stand still while the picture moved.
No HUD element was added.

### `PlayerHost.swift` — the binding, through the mechanism that already claims Menu

`pressesBegan` gains two lines of the same shape as the existing Menu claim
(`PlayerHost.swift:113-120`), and `pressesEnded` swallows the matching release
(`PlayerHost.swift:129-132`) so Apple's transport never sees half a press. `frameStep` is what
decides — the container asks and acts only if the answer is yes.

**Swipes are untouched, structurally.** A swipe on the touch surface is not a `UIPress`, so it
never reaches this code at all. Only the discrete click does, which is what the owner's older app
does too.

### `PlayerScreen.swift` — one line

The closure is handed to `PlayerHost` (`PlayerScreen.swift:36-37`). Nothing else changed.

---

## 2. Device evidence — the measurement, and how it was taken

**How the step size was measured without instrumenting the shipping app.** The Recording HUD
already prints the position at one-second resolution (`PlayerTime.clock`, `PlayerModel.swift:628`).
The harness clicks one frame at a time and counts how many clicks it takes for that clock to tick
over. If a click really moves 1/fps, the count between two consecutive ticks *is* the frame rate.
A click that moved a keyframe would tick the clock in one or two; a click that moved nothing would
never tick it.

| Recording | Server mode | fps | Direction | Clicks per second tick | One click |
|---|---|---|---|---|---|
| Hazardous History With Henry Winkler | **copy** | 29.97 | forward | **30, 30, 30** | 0.033333 s |
| Hazardous History With Henry Winkler | **copy** | 29.97 | backward | **30, 30, 30** | 0.033333 s |
| The Aging Brain | **transcode** | 59.94 | forward | **60, 60, 60** | 0.016667 s |
| The Aging Brain | **transcode** | 59.94 | backward | **60, 60, 60** | 0.016667 s |

Both encode modes the server can produce were covered, as asked: **copy** is the broadcaster's own
GOP, **transcode** is the server's forced 4-second keyframes. Frame stepping does not care —
which is the point of an exact seek.

**Direct per-click deltas.** A targeted run read the exact position out of the app before and
after each click. Ten clicks on the copy-mode 29.97 fps recording, five with Apple's transport
overlay showing and five after it had hidden:

```
FS[who] overlay-up     click 1: 1898.613483 → 1898.646850  delta=+0.033367
FS[who] overlay-up     click 2: 1898.646850 → 1898.680217  delta=+0.033367
FS[who] overlay-up     click 3: 1898.680217 → 1898.713583  delta=+0.033366
FS[who] overlay-up     click 4: 1898.713583 → 1898.746950  delta=+0.033367
FS[who] overlay-up     click 5: 1898.746950 → 1898.780317  delta=+0.033367
FS[who] overlay-hidden click 1: 1898.780317 → 1898.813683  delta=+0.033366
FS[who] overlay-hidden click 2: 1898.813683 → 1898.847050  delta=+0.033367
FS[who] overlay-hidden click 3: 1898.847050 → 1898.880417  delta=+0.033367
FS[who] overlay-hidden click 4: 1898.880417 → 1898.913783  delta=+0.033366
FS[who] overlay-hidden click 5: 1898.913783 → 1898.947150  delta=+0.033367
```

**1/29.97 = 0.0333667 s.** Ten for ten, to the microsecond, and **whether Apple's overlay is up or
hidden makes no difference**. On the 59.94 fps recording the app's own reading of the last step was
`-0.016689 s` against a true frame of 0.016683 s, over 406 steps in one sitting with none declined.

**The step lands on frames, not keyframes.** A keyframe landing on the copy-mode recording would
have been roughly half a second and ragged; on the transcoded one it would have been a flat 4
seconds. Neither appeared: the deltas are one frame, constant to six decimal places, on both.

---

## 3. Playing, live and camera are unchanged

- **Playing.** A right click while playing still moves **+12 s** — Apple's own skip, measured in
  every run (`FS[rec0] PLAYING right-click: 2201 s → 2213 s (delta 12 s)`;
  `FS[rec1] … 66 s → 78 s (delta 12 s)`). `frameStep` requires `isPaused` and declines otherwise,
  so the press falls through untouched.
- **The control run proves the binding is real.** The same harness against the **unmodified** app
  measured a paused arrow click moving exactly **10 s** each time (623 → 633 → 643 → 653). With
  the change, the same clicks move one frame. The feature is doing the work, not a coincidence.
- **Camera.** `testCameraIsUntouched` played a camera, paused it and clicked left and right: the
  Player carried on and Menu returned to the Cameras screen. A camera is not a recording, so
  `frameStep` declines and Apple keeps the click.
- **Live.** Not driven on the device this pass — tuning a live channel takes a tuner, and the
  owner's scope was explicit that live must not be gone near. It is unchanged by construction and
  by diff: `handleShortWindowSelect` and the whole Pass 7C path are **byte-identical**
  (`git diff` touches only the header comment, the `frameStep` property, and the two arrow lines
  in `pressesBegan`/`pressesEnded`), and `frameStep` returns false for `.live` at its first guard
  because `isRecording` is false. Open Question 2.

---

## 4. The honest limit: fast repeated clicks are not always ours

Reproduced, and not solved:

| Click cadence | Recording | What a paused arrow did |
|---|---|---|
| every **700 ms** | copy, 29.97 fps | **one frame**, 10 clicks out of 10 (§2) |
| every **320–420 ms** | copy, 29.97 fps | **Apple's 10 s skip**, in two separate runs |
| every **320–420 ms** | transcode, 59.94 fps | **one frame**, 60 per second, in two separate runs |

In the failing case the app's own counters showed the step being asked for and **acting** — 8
presses, 8 acted, 0 declined — while the position moved essentially nothing (1610.239928 →
1610.239358 over those 8 steps) and the clock jumped 10 s per click. So the press reached the app
*and* Apple acted anyway, and our exact seek was cancelled before it could land: every step calls
`cancelPendingSeeks()`, so a click arriving before the previous seek completes throws that seek
away.

**What this means in the hand:** deliberate, separate clicks — which is how anyone actually inches
through a play — step one frame every time. Hammering the arrow can hand the press to Apple's
skip and jump ten seconds instead. The threshold was not bisected; 700 ms was clean and 420 ms was
not, on one of the two recordings.

Per the owner's instruction this is **reported, not worked around** — no attempt was made to
suppress Apple's transport, and nothing was changed to chase it. Open Question 1.

---

## 5. Pass 27's report is corrected, not rewritten

`reports/2026-09-07-pass27-framestep-recon.md` gains a clearly-marked addendum at the end. Its
original text is untouched: the `step(byCount:)` measurement stands and was correct — forty calls,
zero movement — but its verdict that frame stepping is unachievable does not, and the addendum
says so and points here.

---

## 6. Open Questions

1. **Rapid clicks can be taken by Apple's transport** (§4). Not investigated further and not
   worked around, as instructed. If the owner wants it solid under hammering, the next pass would
   have to establish what Apple is recognising — a repeat/hold rather than discrete clicks is the
   obvious suspect — and that is a design decision, not a bug fix.
2. **Live was not driven on the device** (§3), to avoid taking a tuner. Unchanged by diff and by
   the `isRecording` guard.
3. **A frame step near the very end of the prepared range** was not tested. The step clamps to the
   seekable range, but a recording still being segmented has a moving end, and `timeJumped()`
   already restarts the session when a seek lands within 1.5 s of it (`PlayerModel.swift:382`).
   Whether a frame step can trip that was not exercised.
4. **The picture was not compared frame to frame.** The evidence here is the timeline moving by
   exactly one frame duration; nobody diffed two screenshots to prove the image changed by one
   frame of motion.

---

## 7. SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `Marlin DVR TV/PlayerModel.swift` | **modified** — `frameRate` + `refreshFrameRate` + `adopt`; `frameStep`; `frameStepLanded`; one line in `tick()` | 1, 2 |
| `Marlin DVR TV/PlayerHost.swift` | **modified** — the `frameStep` closure and the two arrow lines in `pressesBegan`/`pressesEnded` | 3 |
| `Marlin DVR TV/PlayerScreen.swift` | **modified** — one line, handing the closure to `PlayerHost` | 3 |
| `Marlin DVR TVUITests/FrameStepUITests.swift` | **created, run on the device, deleted before committing** — SHA-256 `e4daf81d2e0100e09783b9b1ba391fd15b4ddc57e09d141fef4c5631445202b1` | 4, 5 |
| `reports/2026-09-07-pass27-framestep-recon.md` | **addendum appended**, original text untouched | 6 |
| `reports/2026-09-07-pass28-framestep.md` | **new** — this report | deliverable |
| `build/**` | build output and logs; git-ignored, never committed | 4, 5 |

**A temporary diagnostic was used and reverted.** To find the 2.17 fps bug and to read exact
positions, the HUD's existing position line briefly carried a `[DIAG fps=… step=… pos=… steps=…]`
suffix and `PlayerModel` briefly carried three counters. Both are **gone** — `grep -c DIAG` returns
0 in both files — and the numbers in §2 and §4 that came from it are labelled as such.

**Not done, as scoped:** no slow-motion, no MP4 delivery path, no change to live playback, no new
on-screen control or HUD element, no change to swipe handling, no scrubbing feature, no new
dependency. Nothing in `design/`, the reference clone or on any host outside this folder was read
or written; the only server traffic was the harness's library reads and the play sessions it
opened and DELETEd.
