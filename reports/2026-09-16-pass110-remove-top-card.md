# Pass 110 — the Player's top info card removed on recordings and live channels

**Date:** 2026-09-16
**Committed locally, NOT pushed.** The owner tests on Home Theater first, together with Pass 109's swipe up.
**Base:** `81860906e26521cfebc5452188ba1c698dddaac0` (Pass 109, local). Before anything changed, `git fetch
origin`, then `git rev-parse main` read `8186090…`, `git rev-parse origin/main` and `git ls-remote origin
main` both read `3377aefd9f43e76e25259c0079f69ace343e0d93`, `git rev-list --left-right --count
main...origin/main` was `2 0`, and `git status --porcelain` showed only `?? icon-source/`.

**Nothing on the server was created, changed or deleted.** No panel button was pressed. The bedroom Apple
TV was not touched.

---

## 1. The owner's decision (2026-09-16)

About the card in his photo, his words: **"now that we added the new thing this is not needed"**. The
card is the one across the top of the Player over a recording, reading in his photo "History's Greatest
Mysteries" / "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY" / "2:09 of 42:51" / "Resume kept by D/S Apple
TV". **Remove it on recordings and live channels.** Foreman's call: cameras have no info panel, so wherever
the card appears on a camera, it stays.

---

## 2. What was removed, and on which playback kinds

The card is two views chosen in one place, `PlayerScreen.hud` (`PlayerScreen.swift:105`, drawn at `:54`):
`RecordingHUD` (frame 6c) for a recording, `LiveHUD` (frame 6b) for everything else — a live channel **or a
camera**.

| Kind | Before | After |
|---|---|---|
| **Recording** | `RecordingHUD` for 6 s after playback starts, **for the whole of a pause**, and for 6 s after resuming | **nothing** |
| **Live channel** | `LiveHUD` for 6 s after start, 6 s after resuming, 6 s after a rewind or fast-forward, and 8 s with a notice | **nothing** |
| **Camera** | `LiveHUD` | **`LiveHUD`, unchanged** |

**The change is the dispatch** — `else if model.hudVisible || model.notice != nil { if isRecording {
RecordingHUD } else { LiveHUD } }` became `else if model.isCamera, model.hudVisible || model.notice != nil
{ LiveHUD }` (`:108`) — and **`RecordingHUD` is deleted**, since nothing else drew it. **A camera reaches
`LiveHUD` by exactly the same values as before**: it is never live, so it never took the first branch, and
never a recording, so the old `else` sent it there; `LiveHUD` itself is byte-identical.

### 2.1 What the recording card carried

As in his photo: the show's title; `S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY`; `2:09 of 42:51`;
`Resume kept by D/S Apple TV`. **Two more lines went with it that his photo does not show**, neither of
which the file route ever draws in practice: **"Prepared to *time*. Jumping past that point restarts
playback there — a second or two of buffering, not an error."**, drawn only while a recording is not fully
prepared (always prepared on the single-file route since Pass 42), and **the notice slot**, which no code
sets on a recording.

### 2.2 What the live card carried that his photo does not show — removed with it

1. **The LIVE badge** — "LIVE" at the live edge, **"LIVE · −12 s"** when behind it.
2. **The title line "ch9001 HISTORY"** — the channel number and name.
3. **The subtitle "Pawn Stars · until 12:03 AM"**.
4. **"12 s behind live · buffer 1 min"**, drawn whenever the picture is more than 6 s behind live.
5. **The notice "The pause point left the buffer — resumed at the oldest point still available."**
   (`PlayerModel.swift:351`), shown for 8 s when a pause outlasts the time-shift buffer. **The card was the
   only place it was drawn, so it is no longer shown anywhere on a live channel.** `PlayerModel` still sets
   it and still re-seeks exactly as before; only its text is gone.

### 2.3 Not the card, and not changed

- **The paused-live screen (frame 6d, `PausedLiveOverlay`, `:301`)** — the dimmed picture with "❙❙ Paused",
  "Paused at … · now … behind live", "Held for … · the buffer holds …", "Press play to continue from here…",
  and top-left **"LIVE · HELD  ch9001 HISTORY · Pawn Stars · until 12:03 AM"**. It is a paused state, not
  the card, and the pass names only the card. Photograph 110f. Open question 1.
- **Apple's own transport bar** at the bottom of the screen, which `AVPlayerViewController` draws when
  playback starts, on a pause, on a scrub and on a touch, **with its own title and subtitle from the item's
  metadata** — on a recording "History's Greatest Mysteries" over "S4 E14 · Who Is D.B. Cooper? · 9001
  HISTORY", on live "ch9001 HISTORY" under a red "LIVE" and "Pawn Stars · until 12:03 AM". **That metadata
  is set in `PlayerModel.swift:240-251`, which this pass may not touch.** Photographs 110a, 110b, 110f and
  110x. Open question 2.

**Files not touched:** `PlayerModel.swift`, `PlaybackSession.swift`, `PlayerHost.swift`,
`PlayerInfoPanel.swift`, `CamerasScreen.swift`; the commercial-skip prompt, the Starting, Failure, Expired
and Ended states, and `LiveHUD` are byte-identical.

---

## 3. Build

`xcodebuild … -destination 'generic/platform=tvOS Simulator' -derivedDataPath build/p110-sim build` →
**BUILD SUCCEEDED**, first attempt; `build-for-testing` → **TEST BUILD SUCCEEDED** before each device run.
**No warning in either file this pass touched**, in any build.

---

## 4. The Home Theater run

`PlayerInfoPanelUITests` gains **`testNoTopCardOnARecordingOrALiveChannel`** (`:373`), run on its own. It
knows playback has started from the Starting screen (6a) going away — the old methods knew it from the card
itself — and then looks for the card at every moment the app used to draw it: **just after start, while
paused, just after resuming**, then **Down opens the panel and Up closes it**, then Menu leaves the Player.
A recording first, then the first Favorites channel live.

### 4.1 Run 1 — failed on the live half, and the app was right

`TEST FAILED`, 4 failures, 123.680 s (suite started 23:28:42.730; launch ping `23:28:46.416`). **The
recording half passed every check.** The live half reported the card's lines **"ch9001 HISTORY" and
"LIVE" at every step** — just started, paused, resumed, and after the panel closed.

**Diagnosis, from the run's own screenshots, with no retry until it was understood.** At the live start
(kept as `110x-run1-apple-transport-at-live-start.jpg`) **there is no card at the top of the screen**; the
red "LIVE" badge and the large "ch9001 HISTORY" are **Apple's transport bar along the bottom**, drawn from
the item's metadata. After the panel closed (run 1's 110h) **nothing at all was drawn over the picture**,
yet the same two strings were read — so Apple's title view **stays in the accessibility tree while hidden**.
The harness's live check matched text only, and at the live edge Apple's two strings are the card's two
strings. **Nothing in the app was changed.**

**The fix, in the harness only:** a live card line must also sit **in the top half of the screen**, where
the card was drawn (60 pt from the top), and every lookalike is logged with its position (`liveCardLines`,
`:343`). The recording's checks were not changed — its card lines ("x of y", "Resume kept by …",
"Prepared to …") are drawn by nothing else.

### 4.2 Run 2 — the run that counts

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates -derivedDataPath build/p110 \
  test -only-testing:"Marlin DVR TVUITests/PlayerInfoPanelUITests/testNoTopCardOnARecordingOrALiveChannel"
```

**`** TEST SUCCEEDED **` — passed in 125.267 s**, run 23:33:01 → 23:35:14 −0400.

**The launch ping — found before any screenshot was believed:** `GET /api/logs` →
**`23:33:10.077 INFO HTTP POST /api/clients/<client id>/ping 200`**, 2.2 s after the suite started
(`23:33:07.857`). `launch()`, not `activate()`.

**Every non-GET in the window (23:33:01 – 23:35:20):** the ping; `POST /api/play/sessions` 23:33:28.398 and
`DELETE /api/play/sessions/…` 23:34:01.749 (the recording); `POST` 23:34:41.091 and `DELETE` 23:35:08.986
(the live channel). **128 GETs and those 5.** Run 1's window held the same shape — the ping, two sessions
opened and closed, 119 GETs.

### 4.3 The harness's own lines (run 2)

The log prefix is the harness's existing `pass108` helper.

```
[pass108 23:33:30.598] recording: Starting screen gone true
[pass108 23:33:33.113] recording, just started: card lines []; clock texts ["02:34"]; focus other:
[pass108 23:33:46.279] recording, paused: frames identical true; clock ["02:38"] → ["02:38"]; card lines []; …
[pass108 23:33:53.595] recording, resumed: frames moving true; card lines [] / []
[pass108 23:33:57.722] recording panel up — title History's Greatest Mysteries · button Edit pass · focus Edit pass
[pass108 23:34:01.260] recording after Up: panel up false; card lines []; focus other:
[pass108 23:34:02.523] recording, after Menu: focus Resume S4 E14 · 2 min in
[pass108 23:34:40.990] Favorites focus, the channel about to be played: "9001 · HISTORY, ★, HD, Pawn Stars, ends 12:03 AM" → the live card's title would read "ch9001 HISTORY"
[pass108 23:34:43.262] live: Starting screen gone true
[pass108 23:34:46.035] live, just started: card lines []; lookalikes anywhere: "ch9001 HISTORY" @ x 84 y 802, "LIVE" @ x 98 y 757; screen midY 540; focus other:
[pass108 23:34:55.817] live, paused: paused-live screen true; card lines []; lookalikes anywhere: "ch9001 HISTORY" @ x 84 y 802, "LIVE" @ x 98 y 757; …
[pass108 23:34:59.339] live, resumed: paused screen gone true; card lines []; lookalikes anywhere: "ch9001 HISTORY" @ x 84 y 802, "LIVE" @ x 98 y 757
[pass108 23:35:03.894] live panel up — title Pawn Stars · record Record · favorite Unfavorite · focus Record
[pass108 23:35:08.398] live after Up: panel up false; card lines []; lookalikes anywhere: "ch9001 HISTORY" @ x 84 y 802, "LIVE" @ x 98 y 757; focus other:
[pass108 23:35:09.711] live, after Menu: focus 9001 · HISTORY, ★, HD, Pawn Stars, ends 12:03 AM
```

**What it proves.**
- **Recording:** no card just after start, **none while paused** — and the pause was real: two captures 2 s
  apart identical and Apple's clock standing at 02:38 — none after resuming, while the picture moved.
  **Down opened the panel** with focus on "Edit pass"; **Up closed it**; still no card; Menu returned to
  show detail.
- **Live:** no card just after start, **none while paused** (the paused-live screen was up), none after
  resuming. **Down opened the panel** over the airing now — *Pawn Stars*, "Record", "Unfavorite";
  **Up closed it**; still no card; Menu returned to Favorites.
- **The only lookalikes on live, at every step, were at y 757 and y 802** — the bottom of the screen, where
  Apple's transport bar draws its badge and title (110e, 110x) — and **none was in the top half**.

### 4.4 Screenshots — `reports/assets/pass110/`

| File | Run | What it shows |
|---|---|---|
| `110a-recording-started-no-card.jpg` | 2 | the recording just started: **no card at the top**; Apple's transport bar at the bottom ("History's Greatest Mysteries", "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY", 02:34) |
| `110b-recording-paused-no-card.jpg` | 2 | the recording paused: **no card**; Apple's paused transport bar, 02:38 |
| `110c-recording-panel-up.jpg` | 2 | Down: the info panel, "Edit pass" focused |
| `110d-recording-panel-closed-no-card.jpg` | 2 | Up: the panel gone, nothing over the picture |
| `110e-live-started-no-card.jpg` | 2 | 9001 HISTORY live just started: no card at the top |
| `110f-live-paused-no-card.jpg` | 2 | live paused: **the paused-live screen (6d)**, top-left "LIVE · HELD", with Apple's bar below — no card |
| `110g-live-panel-up.jpg` | 2 | Down: the panel — *Pawn Stars*, S23 E8, **Record**, **Edit pass** (the current airing matches his "Pawn Stars" pass), **Unfavorite** |
| `110h-live-panel-closed-no-card.jpg` | 2 | Up: the panel gone, nothing over the picture |
| `110x-run1-apple-transport-at-live-start.jpg` | 1 | the frame the diagnosis rests on: no card at the top, Apple's "LIVE" and "ch9001 HISTORY" at the bottom |

1920 × 1080 JPEG copies; the 3840 × 2160 originals stay in the two result bundles in the session scratchpad.

### 4.5 Disclosed cost

- **Two device runs, not one** — the first failed on the harness, as above.
- The saved position on `5328bb632e76` moved from about 2:11 to about 2:47 across both runs; show detail read
  "2 min in" before and after. No position was cleared, nothing was marked watched, no commercial break was
  reached (the first is at 2:56.5).
- Four play sessions in all, each opened and closed by the app; the live ones on a Philo channel.
- No diagnostic was added to the app.

---

## 5. Consequences for the existing evidence harnesses — recorded, not changed

- **`ResumeRewindUITests` (Pass 96, re-run by Pass 98) can no longer take a reading**: it reads the
  recording's position from the card's "x of y" (`hudPosition`, `ResumeRewindUITests.swift:138`) and waits
  for "Resume kept by D/S Apple TV" (`:254`).
- **`PlayerInfoPanelUITests`' Pass 108 and Pass 109 methods cannot pass**: both wait for the card's
  "Resume kept by …" line, and Pass 108's live half for its "LIVE" badge, to know playback has started. Left
  as their passes ran them; the harness header says so.
- No other harness in `Marlin DVR TVUITests` reads either card.

---

## 6. Code-traced only

1. **Cameras still draw the card** — the dispatch is traced above; no camera was played.
2. **The live "pause point left the buffer" notice is no longer shown** — reaching it needs a pause longer
   than the buffer.
3. **The live card after a rewind or fast-forward** (`timeJumped`, `PlayerModel.swift:660`) and **the "−lag"
   badge and "behind live · buffer" line** — gone with the dispatch; not driven.
4. **Pass 109's swipe up**, still code-traced.

---

## 7. What the owner should press to test

- **A recording:** play one. At the start, when you pause (Select or play/pause) and when you resume, **the
  card at the top should not appear**. Apple's own bar at the bottom still shows the title and episode — that
  is Apple's, not the card (open question 2).
- **A live channel:** play one. At the start and when you resume, **no card at the top**. Pausing shows the
  "Paused" screen as before (open question 1).
- **The panel still works:** click down (or swipe down) opens it, click up (or swipe up — Pass 109's, not yet
  tested) closes it, Menu closes it and Menu again leaves the Player.
- **A camera:** play one — **the card should still appear** at the top as before.

---

## Open questions

1. **The paused-live screen (6d) was not changed.** Its top-left line reads "LIVE · HELD  ch9001 HISTORY ·
   Pawn Stars · until 12:03 AM" — with the channel number — over the centred "Paused" text. It is not the
   card and the pass names only the card.
2. **Apple's own transport bar still shows a title and subtitle**, from the item's metadata: on a recording
   "History's Greatest Mysteries" over "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY" — close to the card's
   first two lines, channel number included — and on live "ch9001 HISTORY" with "Pawn Stars · until …". It
   appears whenever Apple's bar does. The text is set in `PlayerModel.swift:240-251`, do-not-touch here, and
   AVKit's switch for the title view would be set in `PlayerHost.swift`, also do-not-touch.
3. **The live notice** "The pause point left the buffer — resumed at the oldest point still available." has
   no other place to appear now (§2.2 item 5).
4. **Two harnesses can no longer read the recording's position** (§5).
5. **The running server is 1.9.3**; COLD-START's *The server* line still says 1.9.1.

## What I am least sure of

1. **That the live check would have caught a real card.** It could not be shown one — the card is gone — so
   what stands behind "no card on live" is the position rule, the log of every lookalike at the bottom of the
   screen, and the screenshots, rather than a check proven against the old build.
2. **Whether the owner counts Apple's bottom bar or the paused-live screen as part of "the card"** (open
   questions 1 and 2). Both still show a title with the channel number.
3. **Cameras**, traced and not played.

## SCOPE CHECK

| File | Step |
|---|---|
| `Marlin DVR TV/PlayerScreen.swift` | 1 |
| `Marlin DVR TVUITests/PlayerInfoPanelUITests.swift` | 2 |
| `reports/assets/pass110/110a…110h`, `110x…` (9 JPEGs) | 2 |
| `reports/2026-09-16-pass110-remove-top-card.md` | 3 |
| `DECISIONS.md` | 3 |
| `COLD-START.md` (Player line, *Next step*) | 3 |

`icon-source/` stays untracked and untouched. Build products are under the ignored `build/`; both result
bundles, both logs and the server reads are in the session scratchpad.
