# Pass 108 — the Player's info panel (build)

**Date:** 2026-09-16
**Committed locally, NOT pushed.** The owner tests on Home Theater first.
**Base:** `3377aefd9f43e76e25259c0079f69ace343e0d93` (Pass 107). Before anything changed, `git fetch origin`
then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main` all read it,
`git rev-list --left-right --count main...origin/main` was `0 0`, and `git status --porcelain` showed
only `?? icon-source/`.

**Nothing on the server was created, changed or deleted.** The run's only non-GET traffic was the
app's own launch ping and the two play sessions it opened and closed (§4.3). No panel button was
pressed. The bedroom Apple TV was not touched.

---

## 1. The owner's decisions (2026-09-16), in substance

- While a recording or a live channel plays, **a swipe down on the remote's touch surface, or a click
  down on its ring, opens the app's own info panel over the video** (today a swipe down does nothing —
  owner). **Its buttons take focus while it is up.**
- **Fields:** the channel logo, the show's title, episode name, season and episode, HD and rating tags
  when the server provides them, and the description. **No channel number.**
- **Recording:** "Add to season pass"; "Edit pass" when the show already has one.
- **Live:** "Record", showing "● Recording" or "● Scheduled" when that airing already has that state
  (as the airing sheet's first control, Pass 49); "Add to pass", "Edit pass" when a pass exists;
  "Favorite", "Unfavorite" when the channel already is one. **Favorite is live only.**
- **Live describes and acts on the show airing on the channel now**, including after a pause or rewind
  — *"Just show the current show."*
- **Each button does what the app's existing control of that kind does** (airing sheet, show detail,
  the Guide's hold), **with the same result messages.**
- **Foreman calls within those decisions:** a live channel with nothing in the guide shows the channel
  and only Favorite/Unfavorite; a recording's logo comes from matching its channel text to
  `GET /api/channels`, and it has no logo if nothing matches; no "Stop recording" button; tags are HD
  and rating only; Menu with the panel up closes the panel, and Menu again leaves the Player as today;
  screens underneath show a change made from the panel the next time they are opened.

**How this pass got here.** The first attempt at Pass 108 stopped at step 1 before writing any code:
XCUITest on tvOS can press remote buttons and cannot swipe (`XCUIRemote.h` has `pressButton:` only;
`XCUIElement.h:176-208` puts every swipe inside `#if !TARGET_OS_TV`), so step 2's "swipe down → the
panel" could not be driven, and nothing said whether a down click opens the panel. The owner's answer is
the first decision above, and step 2 opens the panel with `remote.press(.down)`.

---

## 2. What was built

### 2.1 Files

| File | Change |
|---|---|
| `Marlin DVR TV/PlayerInfoPanel.swift` | **new**, 615 lines — the panel |
| `Marlin DVR TV/PlayerHost.swift` | +104 / −1 — the two openers and the focus guard |
| `Marlin DVR TV/PlayerScreen.swift` | +28 / −2 — the panel's state, placement, Menu and phase handling |
| `Marlin DVR TV/Models.swift` | +20 — `Episode.meta`, decoded only for the rating |
| `Marlin DVR TVUITests/PlayerInfoPanelUITests.swift` | **new**, 343 lines — the Home Theater harness |

**Not edited:** `PlayerModel.swift` (so `restart(at:)` is untouched), `PlaybackSession.swift`,
`AiringSheet.swift`, `ShowDetailScreen.swift`, `GuideScreen.swift`, `FavoritesScreen.swift`,
`ChannelActionsMenu.swift`, `EditSeriesPassScreen.swift`, and the project file — the targets are
synchronised folders, so the two new files needed no project change.

### 2.2 Opening the panel — `PlayerHost.swift`

- **The click down** is a `UIPress` of `.downArrow`. `pressesBegan` (`:307`) now has a branch for it
  (`:322`) that asks `onInfoPanel()`. True — a recording or a live channel — swallows the press and its
  release (`:351`); false — a camera — falls through to `super` as before. The branch sits after the
  frame-step branches and before the Select branches, and **touches neither**: each matches its own press
  type.
- **The swipe down** is not a press, so it gets a `UISwipeGestureRecognizer` (`:127`), direction `.down`,
  indirect touches only, `allowedPressTypes = []`, `cancelsTouchesInView = false`, and a delegate that
  lets it recognise simultaneously with everything (`:184`). **It is added to the container's own `view`
  (`:171`), not inside `playerController.view`**, which is the only tree `armArrowOwnership` (`:224`)
  and `armSelectOwnership` (`:247`) walk — and they skip any recognizer with no press types anyway. Its
  action (`:176`) calls the same `onInfoPanel()`.
- **Focus.** `setInfoPanelOpen` (`:190`) mirrors the panel's state from SwiftUI. While the panel is up,
  `shouldUpdateFocus` (`:203`) refuses any focus move whose destination sits inside this container
  (`contains`, `:211`, a walk up `parentFocusEnvironment`), so focus cannot fall back onto the video with
  the panel still drawn. When the panel closes, focus is requested back onto the container.
- **`armArrowOwnership`, `armSelectOwnership`, `recognizers(in:claiming:)`, `viewWillDisappear`, the
  frame-step branches, the Select-skip branch and Pass 7C's short-window Select are byte-identical** —
  `git diff` shows insertions around them and no line inside them. The one removed line is the class
  declaration, which gained `UIGestureRecognizerDelegate`.

### 2.3 The panel in the Player — `PlayerScreen.swift`

- `@State infoPanelOpen` (`:30`); `openInfoPanel()` (`:110`) answers true and opens it only while
  `phase == .playing` and the request is a recording or a live channel — **never a camera**.
- The panel is drawn last inside the `.playing` block (`:56-57`), over the HUD and the commercial prompt.
- **Any phase change away from `.playing` closes it** (`:72`), so it is never left over an Ended, Failed
  or Expired card, and never reappears by itself after a restart.
- **Menu** (`:89`): with the panel up it closes the panel; otherwise `dismiss()` exactly as before. The
  panel's own `.onExitCommand` (`PlayerInfoPanel.swift:193`) is nearer its focused button and normally
  takes the press first; the root's check covers the moment before focus lands.

### 2.4 The panel — `PlayerInfoPanel.swift`

**Layout, chosen by this pass, not by the owner** (there is no design for it; the Pass 38 precedent): one
card across the top of the screen at the standard 60 / 80 pt margins, on the Nocturne surface at 94 %,
with the logo on the left (140 pt, `GuideChannelTile`'s drawing — Pass 86's backing and initials
fallback — through `/api/art/feed`), then the title (52 pt), `S.. E.. · episode name`, the tags as
`TagChip`s, the description (three lines at most), the controls (each 340 pt wide), and the footer.
Photographs 108a and 108d.

**The fields**

| Field | Recording | Live |
|---|---|---|
| Logo | the `GET /api/channels` channel whose `"\(number) \(name)"` equals `episode.channel`; none if nothing matches (`loadRecordingChannel`, `:438`) | the channel from `GET /api/guide/now`, else the tuned one |
| Title | the show's title — `show?.title ?? episode.show`, show detail's `showTitle` | `program.title` of the airing **now** |
| Episode line | `S\(season) E\(episode)` when either is non-zero, then `episodeTitle` — the app's own form | `S\(season) E\(episode)` when either is non-zero, else `episodeNum` (e.g. `E185`), then `episodeTitle` (`:100`) |
| Tags (`:119`) | `"HD"` when `episode.tags` holds it; the rating from `episode.meta?.rating` unless `""` or `"None"` — the server's own rule for appending it to `tags` | `"HD"` from the channel's `hd` — the airing sheet's rule (`AiringSheet.swift:116`); `program.rating` |
| Description | `episode.description` | `program.desc` |

**No channel number is drawn anywhere**: the panel never uses `PlayRequest.title` or `.subtitle`, both
of which carry one.

**`Models.swift`: `Episode.meta: EpisodeMeta?` (`:392`, `:400`)** decodes only `rating`, and **its
initialiser cannot throw** — a `try?` container and a `try?` read — so every screen that decodes an
`Episode` (show detail, the shelves, the long-press menu, `RecordingUpdate`) decodes exactly as before
whatever `meta` looks like. `meta` is `json:"meta,omitempty"` in the 1.8.1 source (`library.go:77`) and
present on 1.9.3's answer (Pass 107 §2.2).

**Live reads what is on now, every time the panel opens** (`loadLive`, `:367`): `GET /api/guide/now`,
the channel picked out of the whole lineup (the route takes no channel); then, in parallel,
`GET /api/passes` and `GET /api/schedule`, as the sheet reads them when it opens. **A channel not in that
answer has nothing in the guide**: the panel shows the logo and only Favorite/Unfavorite, with the flag
from `GET /api/channels`. **An airing that ends while the panel is still up is replaced by the next one**
(`reloadWhenTheAiringEnds`, `:464`), and a result message about the airing that ended is cleared with it.
Until the first read returns, a focusable "Loading…" holds focus in the panel.

**The controls, each mirroring the control it is named for** — the screens' own functions are `private`,
so each is mirrored and **none of those screens was changed**:

| Panel control | Mirrors | Write route (**unconfirmed at the running server, 1.9.3; from the 1.8.1 source**) |
|---|---|---|
| **Record** (`record`, `:482`) — "● Recording" / "● Scheduled" as `StateChip`s by `airingState` (`:141`) | `AiringSheet.record()` `:352-369`, `airingState` `:83-88` | `POST /api/record` |
| **Add to pass / Edit pass** (live, `recordSeriesFromTheAiring`, `:504`) | `AiringSheet.recordSeries()` `:371-395`, editor block `:137-157` | `POST /api/passes`; in the editor `PUT` / `DELETE /api/passes/{id}` |
| **Add to season pass / Edit pass** (recording, `recordSeriesFromTheShow`, `:532`) | `ShowDetailScreen.recordSeries()` `:356-380`, editor block `:160-180` | the same |
| **Favorite / Unfavorite** (`toggleFavourite`, `:559`) | `ChannelActionsMenu.apply()` `:83-94` | `PUT /api/sources/{sourceId}/lineup/{guid}` |

- **The result messages are the existing ones, word for word**: "Set to record · *status* · *reason*",
  "Series pass created · *n recordings scheduled*", "This show already has a series pass." / "… — use
  Edit series pass.", "Series pass deleted.", and the sheet's and `WriteError.text`'s failure lines. The
  409 is never shown raw. After Record and after a pass is created or deleted on live, the schedule is
  re-read and the first control follows it, as the sheet's does.
- **Called unchanged:** the `APIClient` calls, `AiringSheet.matchingPass(in:program:)`,
  `ShowDetailScreen.matchingPass(in:showTitle:)`, `AiringSheet.friendly`, `WriteError.text`, `StateChip`,
  `EditSeriesPassScreen` and `GuideChannelTile.artFeedPath`.
- **First focus** (`firstFocusID`, `:150`): the recording's pass button; on live, Record when the airing
  is unbooked, else the pass button — the sheet's rule — or Favorite when there is nothing in the guide.
- **No "Stop recording."** The screens underneath are not told about a change; they show it next time
  they open.

---

## 3. Build

- **Simulator:** `xcodebuild … -destination 'generic/platform=tvOS Simulator' -derivedDataPath
  build/p108-sim build` → **BUILD SUCCEEDED**. The first attempt failed on
  `UIFocusSystem.environment(_:contains:)`, which is `NS_REFINED_FOR_SWIFT` and not exposed; it was
  replaced by the `parentFocusEnvironment` walk (`PlayerHost.swift:211`) and rebuilt.
- **Device:** the harness run below built and installed the app on Home Theater first. **No warning in
  any file this pass touched**, in either build.

---

## 4. The Home Theater run

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p108 test -only-testing:"Marlin DVR TVUITests/PlayerInfoPanelUITests"
```

**`** TEST SUCCEEDED **` — `testTheInfoPanelOverARecordingAndALiveChannel` passed in 108.363 s**, run
22:59:54 → 23:01:57 −0400. One run; nothing was retried.

### 4.1 The server as it stood before the run

Read at 22:59:36 with the app's own GETs and `GET /api/status` (1.9.3): *History's Greatest Mysteries*
has a pass (`0 recordings scheduled`, new episodes) and both its recordings carry `"9001 HISTORY"`,
`tags ["HD","H264","Stereo","TV-PG"]` and `meta.rating "TV-PG"`; the first favourite in server order is
`philo:6044` 9001 HISTORY — a Philo channel, which holds no tuner — airing *Pawn Stars: Best Of* S6 E8
"The Magic of Vegas", TV-PG, which matches no pass; all 9 scheduled jobs are `Queued`, none on now.

### 4.2 The launch ping — found before any screenshot was believed

`GET /api/logs`: **`23:00:10.123 INFO HTTP POST /api/clients/<client id>/ping 200`** — 2.7 s after the
test case started at `23:00:07.459`, and the first HTTP line of the run. `launch()`, not `activate()`.

### 4.3 Every non-GET the server logged in the run window (22:59:54 – 23:01:58)

| Time | Request |
|---|---|
| 23:00:10.123 | `POST /api/clients/<client id>/ping` — the launch |
| 23:00:32.217 | `POST /api/play/sessions` — the recording |
| 23:00:51.536 | `DELETE /api/play/sessions/…` — the recording's session, on the second Menu |
| 23:01:31.088 | `POST /api/play/sessions` — the live channel |
| 23:01:51.723 | `DELETE /api/play/sessions/…` — the live session, on the second Menu |

**120 GETs and those 5, nothing else.** No POST, PUT or DELETE reached `/api/record`, `/api/passes`,
`/api/schedule/jobs`, `/api/sources/…/lineup` or `/api/library/recordings`, and nothing was marked
watched. The panel's own reads are in the log where the Down landed: `23:00:42.579 GET /api/channels`,
`:606 GET /api/art/feed`, `:615 GET /api/passes` (recording); `23:01:42.540 GET /api/guide/now`, `:547 GET
/api/art/feed`, `:608 GET /api/passes`, `:609 GET /api/schedule` (live).

### 4.4 What the device showed — the harness's own lines

```
[pass108 23:00:32.072] show detail focus, the control about to be pressed: "Resume S4 E14 · 39 s in"
[pass108 23:00:42.482] recording playing; focus before Down: other:
[pass108 23:00:47.157] recording panel — title: History's Greatest Mysteries · episode: S4 E14 · Who Is D.B. Cooper? · tags: ["HD", "TV-PG"] · logo: true
[pass108 23:00:47.202] recording panel — pass button: Edit pass · pass line: ◆ Series pass · 0 recordings scheduled · new episodes · focus: Edit pass
[pass108 23:00:47.594] recording panel — every panel string: ["History's Greatest Mysteries", "S4 E14 · Who Is D.B. Cooper?", "In 1971, a man hijacks a Northwest Orient Airlines flight, demanding four parachutes and $200,000.", "◆ Series pass · 0 recordings scheduled · new episodes", "HD", "TV-PG", "Edit pass"]
[pass108 23:00:50.954] after Menu: panel up false, focus other:, show detail focused false
[pass108 23:00:52.300] after the second Menu: focus Resume S4 E14 · 56 s in
[pass108 23:01:30.970] Favorites focus, the channel about to be played: "9001 · HISTORY, ★, HD, Pawn Stars: Best Of, ends 11:05 PM"
[pass108 23:01:47.269] live panel — title: Pawn Stars: Best Of · episode: S6 E8 · The Magic of Vegas · tags: ["HD", "TV-PG"] · logo: true
[pass108 23:01:47.290] live panel — record: Record · series: Add to pass · favorite: Unfavorite · pass line: none · focus: Record
[pass108 23:01:47.705] live panel — every panel string: ["Pawn Stars: Best Of", "S6 E8 · The Magic of Vegas", "The crew are spellbound by a collection of magical memorabilia and casino collectibles, from mysterious illusions to iconic Sin City finds.", "HD", "TV-PG", "Record", "Add to pass", "Unfavorite"]
[pass108 23:01:51.126] after Menu: panel up false, focus other:
[pass108 23:01:52.441] after the second Menu: focus 9001 · HISTORY, ★, HD, Pawn Stars: Best Of, ends 11:05 PM
```

**Every value matches the server's state read before the run (§4.1).** Neither panel string contains
`9001`. Focus sat on the player (`other:`) before each Down, moved onto the panel's first control with
it, went back to the player on the first Menu, and returned to the screen underneath on the second.

### 4.5 Screenshots — `reports/assets/pass108/`

| File | What it shows |
|---|---|
| `108a-recording-panel.jpg` | the panel over *Who Is D.B. Cooper?* — HISTORY logo, title, `S4 E14 · Who Is D.B. Cooper?`, `HD` `TV-PG`, the description, **Edit pass** focused, the gold pass line. No Apple transport UI on screen |
| `108b-recording-panel-closed.jpg` | after Menu: the recording playing, nothing drawn over it |
| `108c-recording-player-left.jpg` | after Menu again: show detail, focus on "Resume S4 E14 · 56 s in" |
| `108d-live-panel.jpg` | the panel over 9001 HISTORY live — logo, *Pawn Stars: Best Of*, `S6 E8 · The Magic of Vegas`, `HD` `TV-PG`, the description, **Record** focused, **Add to pass**, **Unfavorite** |
| `108e-live-panel-closed.jpg` | after Menu: the channel playing, nothing drawn over it |
| `108f-live-player-left.jpg` | after Menu again: Favorites, focus on the 9001 HISTORY row |

The originals are 3840 × 2160 PNGs in the run's result bundle (session scratchpad, not committed); these
are 1920 × 1080 JPEG copies, as in earlier passes.

### 4.6 Disclosed cost

- **The owner's saved position on `5328bb632e76` moved from 39 s to 56 s** — show detail read "Resume S4
  E14 · 39 s in" before the run and "· 56 s in" after it. No position was cleared.
- Two play sessions, opened and closed by the app (§4.3). The live one was on a Philo channel.
- No diagnostic was added to the app and no temporary harness was made, so nothing had to be reverted.

---

## 5. Code-traced only

Each is traced from the code as built; **none was driven on a television.**

1. **The touch-surface swipe.** `swipeDown` (`PlayerHost.swift:127`) on the container's view →
   `swipedDown` (`:176`) → `onInfoPanel` → `PlayerScreen.openInfoPanel` (`:110`). XCUITest cannot swipe
   on tvOS. What is not known: whether a `UISwipeGestureRecognizer` on the container's view recognises
   alongside `AVPlayerViewController`'s own touch handling on tvOS 26.6. **If it does not, the click down
   still opens the panel and the swipe does nothing, as today.**
2. **The click down while paused on a recording.** `armArrowOwnership` disables the player's arrow
   recognizers — the ones Pass 29 found claim up and down too (`PlayerHost.swift:26-27`) — but the press
   still reaches `pressesBegan`, exactly as the left and right clicks that step frames do; the down
   branch (`:322`) opens the panel. With the panel up, left and right move focus in the panel instead of
   stepping; after Menu, focus is back on the player with `ownsArrows` unchanged, so stepping resumes.
3. **Commercial skip.** Its claim, prompt, timer and seek are untouched. **With the panel up, Select
   presses the panel's focused button, not the skip**, because the panel's buttons have focus and the
   container is not in their responder chain; the prompt goes by itself after five seconds as it always
   has. Opening the panel does not dismiss the prompt.
4. **Frame stepping.** Untouched; reachable only with the panel closed (item 2).
5. **Every button press**, its 409 and failure branches, its result message, and each label's change
   after its own write — Record → ● Scheduled / ● Recording, Add → Edit, Favorite ↔ Unfavorite — and
   everything inside the editor.
6. **"● Recording" and "● Scheduled" on the panel** — no airing on now was booked, and booking one is a
   write.
7. **A live channel with nothing in the guide** — no favourite was in that state.
8. **An airing ending while the panel is up** (`reloadWhenTheAiringEnds`).
9. **Pass 7C's live Select during the first minute with the panel up** — the Select goes to the panel's
   button and not to the container, by the same responder-chain fact as item 3.
10. **Every write route at 1.9.3.**

---

## 6. What the owner should press to test

**The two ways in**
- **Swipe:** play any recording or live channel and swipe down on the touch surface. The panel should
  appear. Menu closes it; Menu again leaves the Player.
- **Click down while paused on a recording:** play a recording, pause it, click down on the ring. The
  panel should appear. Menu closes it — then left and right clicks should still step one frame each.

**Recording**
- **Edit pass:** *History's Greatest Mysteries* (has a pass) → Down → "Edit pass" is focused → Select
  opens the same editor the Guide opens. Menu closes the editor back to the panel. *(Nothing is written
  unless you change a row inside.)*
- **Add to season pass:** *Hitler's DNA* (no pass) → Down → "Add to season pass" → Select. **This creates
  a real series pass.** Expect "Series pass created · *n* recordings scheduled" and the button turning
  into "Edit pass". Delete it from the editor if you don't want it ("Series pass deleted.").

**Live**
- **Record:** on a channel whose current show isn't booked → Down → "Record" → Select. **This records the
  airing, and because it is on now the server starts recording at once** (`recorder.go:847`). Expect
  "Set to record · *status*" and the control turning into "● Recording" or "● Scheduled". Stop it from
  the airing sheet's "Stop recording" or Manage DVR if you don't want it.
- **Add to pass / Edit pass:** Down → "Add to pass" → Select creates a pass for the current show
  ("Series pass created · …") and the button becomes "Edit pass", which opens the editor.
- **Favorite / Unfavorite:** on a favourite → Down → "Unfavorite" → Select; the label turns to
  "Favorite". Select again to put it back. **Server-wide** — the web UI and the bedroom Apple TV see it.
  The Guide and Favorites show the change the next time they are opened.
- **Nothing in the guide:** a channel with no listing should show only its logo and Favorite/Unfavorite.

**Commercial skip, with the panel**
- Play `5328bb632e76` or `d9a4f5c76696` to a break; with the panel **closed**, Select should skip as
  before. Opening the panel while the prompt is up gives Select to the panel's button instead (§5 item 3).

---

## Open questions

1. **The panel's position and look were chosen by this pass** — a card across the top of the screen at
   the standard margins. There was no design and no decision on it.
2. **"Shows the channel" was built as the logo alone** for a live channel with nothing in the guide — no
   channel name, since the decisions list no name field and forbid the number.
3. **With the commercial-skip prompt up, opening the panel gives Select to the panel.** On a recording
   the focused button is "Edit pass" or "Add to season pass", and the latter creates a pass. Nothing was
   built to change it.
4. **Live's HD tag is the channel's `hd`**, the airing sheet's rule, not the programme's `video: "HDTV"`.
   On today's lineup they never disagree the other way (Pass 107 §2.3). **A 4K recording would show no HD
   tag**: the server replaces `"HD"` with `"4K"` at height ≥ 2000, and the decision is HD and rating only.
   No 4K recording exists in the library.
5. **The running server is 1.9.3**; COLD-START's *The server* line still says 1.9.1. It is not one of this
   pass's named edits and stays open (Pass 107 open question 1).
6. **Pass 38's instruction not to be the first focusable view over a running `AVPlayerViewController` is
   superseded** by the owner's decision that the panel's buttons take focus. Recorded, not re-asked.

## What I am least sure of

1. **The swipe.** The recognizer is built to the book, but no swipe has ever reached it, and whether it
   recognises beside `AVPlayerViewController` on tvOS 26.6 is unknown. The click down is proven; the
   swipe is not.
2. **The click down while paused on a recording** rests on the press reaching `pressesBegan` while the
   player's up/down/left/right recognizers are disabled — true for left and right by Pass 29's
   measurement, reasoned for down.
3. **Every write the panel makes is a mirror, not a call**, and every route is unconfirmed at 1.9.3. A
   mirror that drifts from its original would not show until a button is pressed.

## SCOPE CHECK

| File | Step |
|---|---|
| `Marlin DVR TV/PlayerInfoPanel.swift` (new) | 1 |
| `Marlin DVR TV/PlayerHost.swift` | 1 |
| `Marlin DVR TV/PlayerScreen.swift` | 1 |
| `Marlin DVR TV/Models.swift` | 1 |
| `Marlin DVR TVUITests/PlayerInfoPanelUITests.swift` (new) | 2 |
| `reports/assets/pass108/108a…108f` (6 JPEGs) | 2 |
| `reports/2026-09-16-pass108-player-info-panel.md` | 3 |
| `DECISIONS.md` | 3 |
| `COLD-START.md` (Player line, *Next step*) | 3 |

`icon-source/` stays untracked and untouched. Build products are under the ignored `build/`. The result
bundle, the raw screenshots and the server reads are in the session scratchpad, not in the repo.
