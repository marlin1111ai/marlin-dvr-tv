# Pass 109 — swipe up or click up closes the Player's info panel

**Date:** 2026-09-16
**Committed locally, NOT pushed.** The owner tests the swipe up on Home Theater first.
**Base:** `b3ec4ea94d35dc1b887ae750b088c6a8685542e1` (Pass 108, local). Before anything changed, `git fetch
origin`, then `git rev-parse main` read `b3ec4ea…`, `git rev-parse origin/main` and `git ls-remote origin
main` both read `3377aefd9f43e76e25259c0079f69ace343e0d93`, `git rev-list --left-right --count
main...origin/main` was `1 0`, and `git status --porcelain` showed only `?? icon-source/`.

**Nothing on the server was created, changed or deleted.** No panel button was pressed. The bedroom Apple
TV was not touched.

---

## 1. The owner's decisions (2026-09-16)

1. **Pass 108 is accepted on Home Theater. His words: "all good".** Nothing is claimed beyond those two
   words — in particular they are not read here as a measurement of any path Pass 108 recorded as
   code-traced (the swipe down, the click down while paused, commercial skip and frame stepping with the
   panel, every button press).
2. **With the info panel up, a swipe up on the remote's touch surface, or a click up on its ring, closes
   the panel, the same as Menu does. Menu is unchanged.**

---

## 2. What was built — `PlayerInfoPanel.swift` only, +101 / −0

**Both ways in call `onClose`, the one call the panel's Menu handler (`.onExitCommand`) makes**, so an Up
closes the panel by exactly Menu's path: `PlayerScreen`'s `infoPanelOpen` goes false, the panel is
removed, and `PlayerHost.setInfoPanelOpen(false)` asks focus back onto the player (Pass 108).

- **The click up** — `.onMoveCommand` on the panel's card (`:179`), acting on `.up` only. It is on the
  card because that is where focus is while the panel is up: the panel's controls sit in one row with
  nothing focusable above them, and the Player's container refuses focus back into the video while the
  panel is up (Pass 108), so the Up itself moves nothing and the command is the whole of it.
- **The swipe up** — a `UISwipeGestureRecognizer` (`.up`, indirect touches only, no press types,
  `cancelsTouchesInView = false`, recognising simultaneously with everything) **installed on the window
  by a zero-size probe in the panel's background** (`SwipeUpDetector`, `:217`, `:652`;
  `SwipeUpProbeView`, `:668`) — `RemoteHoldDetector`'s pattern (`RemoteHold.swift:89-153`). It is put on
  in `didMoveToWindow` (`:683`) and taken off when the panel leaves the window or is dismantled
  (`uninstall`, `:702`), so **it exists exactly as long as the panel does**. It is on the window, not on
  the Player's container where Pass 108's swipe-down recognizer is, because the panel's focused button is
  not inside that container, so a recognizer there would never see the touch.
- **Neither acts while the pass editor is open over the panel.** The click up is on the card, and the
  editor is the card's sibling, so an Up in the editor never reaches it; the swipe checks
  `editingPass == nil`. In the editor Up keeps moving between its rows, as it does wherever the editor is
  opened, and Menu there closes the editor first, as before. **This is the reading taken of "the same as
  Menu does"** — see open question 1.

**Untouched:** `PlayerHost.swift`, `PlayerScreen.swift`, `Models.swift`, `PlayerModel.swift`,
`PlaybackSession.swift`, `AiringSheet.swift`, `ShowDetailScreen.swift`, `GuideScreen.swift`,
`FavoritesScreen.swift`, `EditSeriesPassScreen.swift`, and the project file. **Every line Pass 108 wrote
in `PlayerInfoPanel.swift` is unchanged** — the diff is insertions only: a header paragraph, the
`import UIKit`, the move command, the background probe, and the two types at the end of the file.

---

## 3. Build

`xcodebuild … -destination 'generic/platform=tvOS Simulator' -derivedDataPath build/p109-sim build` →
**BUILD SUCCEEDED**, first attempt. The Home Theater run below built and installed the app on the device.
**No warning in either file this pass touched**, in either build.

---

## 4. The Home Theater run

`PlayerInfoPanelUITests` gains **`testUpClosesThePanelOverARecording`** (`:220`), run on its own; Pass
108's `testTheInfoPanelOverARecordingAndALiveChannel` is unchanged and was not run.

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates -derivedDataPath build/p109 \
  test -only-testing:"Marlin DVR TVUITests/PlayerInfoPanelUITests/testUpClosesThePanelOverARecording"
```

**`** TEST SUCCEEDED **` — passed in 47.040 s**, run 23:15:10 → 23:16:10 −0400. One run; nothing retried.

### 4.1 Before the run

`GET /api/status` → 1.9.3; `GET /api/passes` and `GET /api/library/shows/history-s-greatest-mysteries`
→ the show still has its pass (`pass-…384`), so its panel button reads "Edit pass".

### 4.2 The launch ping — found before any screenshot was believed

`GET /api/logs`: **`23:15:26.072 INFO HTTP POST /api/clients/<client id>/ping 200`**, 3.7 s after the
suite started (`23:15:22.331`) and the run's first HTTP line. `launch()`, not `activate()`.

### 4.3 Every non-GET in the run window (23:15:10 – 23:16:20)

| Time | Request |
|---|---|
| 23:15:26.072 | `POST /api/clients/<client id>/ping` — the launch |
| 23:15:44.295 | `POST /api/play/sessions` — the recording (served from its `.mp4` sidecar, no ffmpeg) |
| 23:16:06.436 | `DELETE /api/play/sessions/…` — on Menu |

**58 GETs and those 3, nothing else.**

### 4.4 The harness's own lines

The log prefix is the harness's existing `pass108` helper, unchanged.

```
[pass108 23:15:44.174] show detail focus, the control about to be pressed: "Resume S4 E14 · 1 min in"
[pass108 23:15:54.721] recording playing; HUD up false; focus before Down: other:
[pass108 23:15:58.206] panel up — title: History's Greatest Mysteries · pass button: Edit pass · focus: Edit pass
[pass108 23:16:01.714] after Up: panel up false, focus other:, recording HUD up false
[pass108 23:16:06.279] two frames 4 s apart: 6397640 and 6304557 bytes, identical false; HUD up false; panel up false
[pass108 23:16:07.200] after Menu: focus Resume S4 E14 · 1 min in
```

**What it proves.** Down opened the panel with focus on "Edit pass". **Up closed it**: the panel's
controls were gone within the 10 s the harness allows, and focus was back on the player (`other:`), not
on the panel and not on show detail — so Up did not leave the Player. **The recording was still
playing**: the recording HUD, which a pause brings back and keeps up (`PlayerModel.timeControlChanged`),
was not up, and two full-screen captures 4 s apart were not identical. Menu then left the Player as
before.

### 4.5 Screenshots — `reports/assets/pass109/`

| File | What it shows |
|---|---|
| `109a-panel-up.jpg` | the panel over *Who Is D.B. Cooper?*, "Edit pass" focused |
| `109b-after-up-panel-closed.jpg` | right after Up: the recording (an aerial river shot), nothing over it — no panel, no HUD, no Apple transport UI |
| `109c-seconds-later-still-playing.jpg` | 4 s later: a different shot (the "Tina-Bar · Members Only" sign) — the recording moved on |
| `109d-menu-left-the-player.jpg` | after Menu: show detail, focus on "Resume S4 E14 · 1 min in" |

1920 × 1080 JPEG copies of the run's 3840 × 2160 captures, which stay in the result bundle in the session
scratchpad.

### 4.6 Disclosed cost

The saved position on `5328bb632e76` moved forward by about the 22 s it played (session 23:15:44 →
23:16:06); show detail read "1 min in" before and after. No position was cleared, nothing was marked
watched. No diagnostic was added and no temporary harness made.

---

## 5. Code-traced only

1. **The swipe up.** XCUITest cannot swipe on tvOS (Pass 108 §1). Traced: the probe's recognizer on the
   window (`:683`) → `swiped` (`:708`) → the closure (`:217`) → `onClose`. What is not known is whether a
   window-level swipe recognizer fires on tvOS 26.6 beside SwiftUI's own focus handling while a panel
   button has focus. The one comparable recognizer in this app — `RemoteHoldDetector`'s Select long
   press on the window — has worked on the physical remote since Pass 9, but it claims a press, not
   touches. **If the swipe does not fire, the click up and Menu still close the panel.**
2. **Up while the editor is open** — moves between the editor's rows and does not close the panel, by
   construction (§2).
3. **Up over a live channel's panel** — the same card, the same command, the same `onClose`; not run.
4. **Up while the live panel is still "Loading…"** — the loading line is inside the card and takes focus,
   so the command reaches it; not run.
5. **Whether a swipe up also produces a move command** and so closes the panel through both ways at once
   — harmless if it does, since closing is setting one flag false.

---

## 6. What the owner should press to test

- **Swipe up:** play a recording or a live channel, open the panel (swipe down or click down), then
  **swipe up on the touch surface**. The panel should close and the video keep playing. Menu then leaves
  the Player.
- **Click up:** the same, clicking up on the ring instead — the run above proved this one on a recording.
- **In the editor:** on *History's Greatest Mysteries*, open the panel, Select "Edit pass" to open the
  editor, then click up and swipe up. The editor's rows should move and **the panel should stay**; Menu
  closes the editor, then Up or Menu closes the panel. Nothing is written unless you press a row.
- **Menu:** unchanged — Menu closes the panel, Menu again leaves the Player.

---

## Open questions

1. **"The same as Menu does", inside the editor.** Menu with the editor open closes the editor, not the
   panel. Up with the editor open was left as the editor's own row-to-row move and does not close
   anything, because making it close would take Up away from the editor's rows. Built as the reading of
   the decision, not asked.
2. **The running server is 1.9.3**; COLD-START's *The server* line still says 1.9.1 (Pass 107 open
   question 1). Not a named edit here.

## What I am least sure of

1. **The swipe up**, for the reason in §5 item 1: a window-level touch recognizer beside SwiftUI focus on
   tvOS 26.6 has never been driven.
2. **"Still playing" rests on two captures differing and the HUD staying down**, not on the player's own
   clock — the Player publishes no position while the HUD is hidden. The two frames show different shots
   of the programme, so the evidence is strong, but it is pictures, not a reading.
3. **The editor reading** (open question 1) is a judgement about what "the same as Menu does" means where
   the panel is not the thing in front.

## SCOPE CHECK

| File | Step |
|---|---|
| `Marlin DVR TV/PlayerInfoPanel.swift` | 1 |
| `Marlin DVR TVUITests/PlayerInfoPanelUITests.swift` | 2 |
| `reports/assets/pass109/109a…109d` (4 JPEGs) | 2 |
| `reports/2026-09-16-pass109-panel-close.md` | 3 |
| `DECISIONS.md` | 3 |
| `COLD-START.md` (Player line, *Next step*) | 3 |

`icon-source/` stays untracked and untouched. Build products are under the ignored `build/`; the result
bundle and server reads are in the session scratchpad.
