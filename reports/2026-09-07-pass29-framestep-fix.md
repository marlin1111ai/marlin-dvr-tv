# Pass 29 — Frame step: the click is ours alone — 2026-09-07

**Pass 28 claimed the press. Apple was never taking it through the press chain.** It handles the
arrow with its **own gesture recognizers**, which run in parallel with the responder chain, so no
amount of not-calling-`super` could ever have stopped it. Found read-only, with evidence, before
anything was changed (§1).

The fix disables exactly those recognizers — matched on their public `allowedPressTypes`, never by
class name — for as long as the app owns the arrow, and restores the very same ones the moment it
does not. **The 10-second accumulation is gone**, and the fast-click case Pass 28 lost now steps
perfectly: 20 clicks 400 ms apart moved `+0.667333 s` against an expected `+0.667334 s`.

**Committed locally, not pushed.** Pass 28 is also unpushed; the owner tests both together.

---

## 1. Step 1 — how the click actually reached Apple

Read-only introspection, on the device, before any change. Two counters and a walk of the player's
own view tree, surfaced through a temporary readout (§6).

```
FS[p29] after 10 steps: [DIAG pos=2968.057240 fps=29.97 arrows=10 super=0
  recs=33 arrowRecs=3
    AVNonDigitizerTapRecognizer@d1[down/up/left/right],
    AVNonDigitizerTapRecognizer@d1[down/up/left/right],
    UIScrollViewDirectionalPressGestureRecognizer@d6[up/down/left/right]-off
  | chain=_AVFocusContainerView>AVUnifiedPlayerPlaybackControlsViewController>
    _AVPlayerViewControllerContainerView>AVPlayerViewController>UIView>
    PlayerContainerController>UIKitPlatformViewHost<…<PlayerHost>>>HostingView>…]
```

Three facts, and together they settle it:

1. **`arrows=10`** — every one of the ten arrow presses reached `PlayerContainerController.pressesBegan`.
2. **`super=0`** — not one of them was forwarded to `super.pressesBegan`. The responder chain above
   this controller never saw them.
3. **Apple skipped 10 s anyway** — the defect the owner reported.

So Apple's handling cannot be coming through the responder chain. `arrowRecs=3` says where it does
come from: **two `AVNonDigitizerTapRecognizer`s at depth 1 inside `AVPlayerViewController`'s view,
each claiming `[down/up/left/right]`** (the third, a `UIScrollViewDirectionalPressGestureRecognizer`
six levels down, is already disabled). A gesture recognizer is not part of the responder chain — it
observes the event stream alongside it — which is precisely why Pass 28's claim, correct in form,
had no effect on Apple at all.

The responder chain print also shows the shape of the problem: `AVPlayerViewController` and its
private container views sit **between** the focused view and `PlayerContainerController`, so the
app is downstream of Apple in every sense.

---

## 2. What changed

### `PlayerHost.swift` — arrow ownership

`armArrowOwnership(_:)` (`PlayerHost.swift:108-120`) is called from both `makeUIViewController`
and `updateUIViewController` (`:54`, `:61`) with `ownsArrows`, so it tracks the paused state as it
changes:

- **When the app owns the arrow** it collects the player's currently-enabled arrow recognizers and
  disables them, remembering exactly which ones it touched (`suppressed`, `:83`).
- **When it does not**, it re-enables precisely those and forgets them. Nothing it did not disable
  is ever touched.
- `viewWillDisappear` (`:136-139`) disarms, so the player's recognizers can never be left switched
  off behind the app.

`arrowRecognizers(in:)` (`:122-134`) walks the player's view tree and matches on
**`allowedPressTypes`**, which is public API. **No private class name is relied on** — the
`AVNonDigitizerTapRecognizer` name appears in this report as evidence and nowhere in the code.

The transport bar is **not** suppressed: it still draws, Select is still Apple's, and the arrows go
back to Apple the instant playback resumes.

### `PlayerScreen.swift` — one line

`ownsArrows: model.isRecording && model.isPaused` (`PlayerScreen.swift:37`). That is the whole
policy: a paused recording, and nothing else.

### `PlayerModel.swift` — a frame-rate defect found while testing

Not in this pass's step list, but found by it and fixed rather than shipped. Pass 28's guard
accepted any reading between 10 and 121 fps. On the device, just after a resume,
`currentVideoFrameRate` read **28.00** on 29.97 material — 6.6 % out, so it snapped to nothing and
was adopted raw. Every step would then have been 0.0357 s: **enough to skip a frame every fifteenth
click**. `adopt` (`PlayerModel.swift:295-310`) now believes only a reading that lands within 5 % of
a real rate, and keeps the rate already in hand otherwise. Disclosed here because it changes
shipping behaviour beyond the literal task.

---

## 3. Step 3 — the accumulation is gone

Paused, ten clicks, then resume. Positions read from the app itself:

| | Position | Change |
|---|---|---|
| before stepping | 3941.285 s | — |
| after 10 clicks | 3941.619 s | **+0.334 s** = 10 × 1/29.97, exactly ten frames |
| after resume + ~3.5 s of play | 3945.102 s | **+3.483 s** — playback, and nothing else |

Had Apple still been banking its own position underneath, resuming would have landed near
**+100 s**. It landed at the stepped position and played on from there. The same run reported
`arrows=10 super=0 owns=true supp=2` — ten presses ours, none forwarded, two of the player's
recognizers held off.

The earlier run of this same test, taken **before** the fix, is the control: it showed the identical
`arrows=10 super=0` with `owns=false supp=0` and Apple acting anyway.

---

## 4. Step 4 — fast clicks now hold

Pass 28's known limit was that clicks about 400 ms apart lost to Apple. Twenty clicks at exactly
that cadence:

```
FS[fast] after  5 clicks: pos=3925.882092 (+0.166833 from start)
FS[fast] after 10 clicks: pos=3926.048926 (+0.333667 from start)
FS[fast] after 15 clicks: pos=3926.215759 (+0.500500 from start)
FS[fast] after 20 clicks: pos=3926.382592 (+0.667333 from start)
FS[fast] 20 clicks at 400 ms: moved=+0.667333  expected=+0.667334  [arrows=20 super=0 owns=true supp=2]
```

**Twenty clicks, twenty frames, to within a microsecond** — and the intermediate readings show it
was one frame per click the whole way, not an average that happened to land right. Pass 28's
fast-click limit is closed.

---

## 5. Step 5 — playing, live, camera and swipes unchanged

- **Playing.** A right click while playing still does Apple's skip, in every run of this pass:
  `+12 s`, `+13 s`, `+12 s`, `+13 s`. `ownsArrows` is false while playing, so the recognizers are
  enabled and untouched.
- **Camera.** `testCameraIsUntouched` passed on the shipping build: a camera played, paused, took
  left and right clicks, and Menu returned to the Cameras screen. `isRecording` is false, so the
  app never arms.
- **Live.** Not driven on the device — tuning a channel takes a tuner and live was scoped out. It
  is unchanged by construction: `ownsArrows` requires `isRecording`, so a live item never disables
  anything, and the Pass 7C `handleShortWindowSelect` path is untouched by this diff.
- **Swipes.** Untouched, structurally: a swipe on the touch surface is not a `UIPress` and the
  recognizers disabled here are matched on `allowedPressTypes`, which a swipe does not carry.

**Final verification ran on the shipping build with every diagnostic removed** — the 59.94 fps
recording measured 60, 60, 59 clicks per second forward and 59, 60, 60 backward (a 59 is one
frame's rounding at the tick boundary, not a lost click), and the camera test passed.

---

## 6. The temporary diagnostic, and its removal

To find the press path and to read exact positions, the HUD's existing position line briefly
carried a `[DIAG …]` suffix, `PlayerHost` briefly carried a `FrameStepDiag` counter enum and a
`diagnose()` view-tree walk, and `pressesBegan` briefly counted arrows and `super` calls. **All of
it is gone** — `grep -c "DIAG\|FrameStepDiag"` returns 0 in both files — and the shipping build was
re-verified on the device afterwards (§5). The device harness
`Marlin DVR TVUITests/FrameStepUITests.swift` was deleted before the commit; SHA-256
`1b5faf163c9d22b2b2a838205fe0df902ddd1471afb7f20fd8beec83268d707b`.

---

## 7. Open Questions

1. **Stepping goes erratic near the end of the prepared range — new, and not fixed.** On the
   1:11:10 recording at **1:05:27**, forward clicking moved the clock *backwards* by 3 s and the
   clicks-per-second counts came out 6, 21, 30 instead of a flat 30. **It is not Apple**: the same
   run read `arrows=134 super=0 owns=true supp=2`, so every press was the app's. The prime suspect
   is the app's own seek-past-the-prepared-range restart — `timeJumped()` restarts the session when
   a seek lands within 1.5 s of the prepared end (`PlayerModel.swift:382`) — which was already
   Pass 28's Open Question 3 and is now confirmed to bite in practice. Left alone as out of scope;
   it wants its own pass. Everywhere else in the same recording, and throughout the 20:45 one,
   stepping was exact.
2. **Live was not driven on the device** (§5), to avoid taking a tuner.
3. **The picture was still not compared frame to frame.** The evidence remains a timeline moving by
   exactly one frame duration; nobody diffed two stills.
4. **Disabling another framework's recognizers is a real dependency on its internals**, even
   matched by public property. If a future tvOS gives `AVPlayerViewController` a different number
   of arrow recognizers, or moves them, this quietly stops working — it would fail *open*, back to
   Apple's skip and the old defect, not into a crash. There is no public API to decline the
   transport's arrow handling; that is the honest state of it.

---

## 8. SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `Marlin DVR TV/PlayerHost.swift` | **modified** — `ownsArrows`, `armArrowOwnership`, `arrowRecognizers(in:)`, `viewWillDisappear`; the temporary `FrameStepDiag`/`diagnose()` added and removed | 1, 2 |
| `Marlin DVR TV/PlayerScreen.swift` | **modified** — one line, `ownsArrows:`; the temporary DIAG readout added and removed | 2 |
| `Marlin DVR TV/PlayerModel.swift` | **modified** — `adopt` now believes only real frame rates (§2), a defect found while testing | beyond the step list, disclosed |
| `Marlin DVR TVUITests/FrameStepUITests.swift` | **restored, extended, run on the device, deleted before committing** | 1, 3, 4, 5 |
| `reports/2026-09-07-pass29-framestep-fix.md` | **new** — this report | deliverable |
| `build/**` | build output and logs; git-ignored, never committed | 1, 3, 4, 5 |

**Not done, as scoped:** no change to live playback, no new on-screen control or HUD, no change to
swipe handling, no scrubbing feature, no slow-motion, no new dependency. **No compensating
counter-seek and no wholesale suppression of the transport bar** — the two things the brief
forbade. Nothing in `design/`, the reference clone, or on any host outside this folder was read or
written; the only server traffic was the harness's library reads and the play sessions it opened
and DELETEd.
