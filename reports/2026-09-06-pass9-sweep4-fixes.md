# Pass 9 — Sweep 4 fixes from the owner's Home Theater test (code; separate push gate) — 2026-09-06

The seven fixes the owner's test asked for, built on the Pass 8 app. **Committed locally only;
nothing was pushed** — the owner tests on Home Theater first, and the push carries Pass 8 and
Pass 9 together.

**The headline, first: click-and-hold now works on the physical Siri Remote, and that is
measured, not argued.** Pass 8's hold was built on a SwiftUI button style's `isPressed`; it
worked on the Simulator and did nothing on the owner's remote, and nothing on this Mac could
tell the two apart. Pass 9 rebuilds it on UIKit's press pipeline and adds an XCUITest that
runs **on Home Theater itself** and issues a real `press(.select, forDuration: 1.2)`. Four
tests, including a negative control and a trigger-isolation test, pass on the device (§1).

The other six fixes were verified hands-on in the Simulator against the live server, and the
build is installed and running on Home Theater for the owner (§9).

Citation keys: `dc:NNN` = `design/Marlin DVR TV.dc.html`; `file:line` = `cmd/marlin-dvr/` in
the reference clone at HEAD `9325d94439ef4c9db637c5014ff79f41d1f63956` (unchanged this pass;
its working tree still holds only the untracked `README-REFERENCE.md`). Server 1.2.1.

Network use, all against `http://192.168.1.250:8090`: GETs; the app's client ping; and the
writes named in §8 — two lineup `favorite` overrides (set and unset), three passes created,
two pass edits and three pass deletions, every one of them mine and every one undone. **No
recording was created, played, or flagged; the owner's pass, schedule, library and settings
are byte-for-byte as they were found** (§8, cleanup proof).

---

## 1. Step 1 — click-and-hold on the real remote

### What was wrong

Pass 8 timed the hold from `ButtonStyle.Configuration.isPressed`. On the Simulator that
tracks the whole press (a mouse press-and-hold on its Apple TV Remote opened the menu every
time). On the owner's remote it does not, so nothing ever fired. `isPressed` is SwiftUI's
own press-animation state, not a report of the button's duration.

### What it is now

`RemoteHold.swift` (208 lines, new). The hold is detected in UIKit and published to the
screen, which acts on whatever *it* has focused — so one code path serves a programme cell,
a channel cell and an episode row:

- **Trigger A (primary): `UILongPressGestureRecognizer` with
  `allowedPressTypes = [.select]`, `minimumPressDuration = 0.5`, installed on the window** by
  a zero-size `RemoteHoldDetector` in `ContentView`'s background. This is the pre-SwiftUI
  tvOS way to read a click-and-hold. It is on the same UIKit press pipeline as the Pass 7C
  live-pause fix, which the owner has already accepted working on this hardware.
- **Trigger B (kept): the Pass 8 `isPressed` timer**, so a remote that honours it also works.
- `RemoteHold.fire` drops a second trigger's report inside 400 ms, so a remote that honours
  both fires the hold **once** — seen in the console: `[hold] press recognizer → hold #1`
  followed by `[hold] press state: duplicate inside 0.4 s, dropped`.
- The click that ends the same press is swallowed (`armSwallow` when a screen acts,
  `pressEnded` shortens it to a 400 ms tail), so a hold never also plays the channel.
- `suspended` is set while the Player is up: the recognizer lives on the window, and without
  it a hold during playback would open a sheet on the screen underneath.

### The proof, on the device

A UI-test target (`Marlin DVR TVUITests`, 132 lines, one file) exists for exactly this. It is
the only way this Mac can press a real remote. Run against **Home Theater**:

```
xcodebuild -scheme "Marlin DVR TV" -destination 'platform=tvOS,name=Home Theater' \
           -allowProvisioningUpdates test-without-building

t = 11.22s Pressing and holding Select button for 1.2s
Test Case 'RemoteHoldUITests.testClickAndHoldOnAChannelCellOpensTheChannelMenu'   passed (15.235 s)
t =  9.15s Pressing and holding Select button for 1.2s
Test Case 'RemoteHoldUITests.testClickAndHoldOnTheCurrentProgrammeOpensTheAiringSheet' passed (14.235 s)
Test Case 'RemoteHoldUITests.testPlainClickOnAChannelCellDoesNotOpenTheChannelMenu' passed (15.169 s)
t = 11.37s Pressing and holding Select button for 1.2s
Test Case 'RemoteHoldUITests.testWindowRecognizerAloneRecognisesTheHold'          passed (15.407 s)
     Executed 4 tests, with 0 failures (0 unexpected) in 60.046 seconds
```

What each one buys:

| Test | What a pass means |
|---|---|
| hold on a **channel cell** → the channel menu opens | the hold is recognised on this hardware |
| hold on the **programme airing now** → the airing sheet opens | the owner's own case: a plain click there *plays* the channel, so the sheet can only come from a hold |
| **plain click** on a channel cell → the menu stays shut | the control: the first test is not passing because "any press opens it" |
| hold with `MARLIN_DISABLE_PRESS_STATE_HOLD=1` → still opens | **trigger A alone works on the device**; the Pass 8 mechanism is not carrying it |

The fourth is the one that settles the diagnosis: with the Pass 8 path switched off by launch
environment, the window recognizer recognised the hold on the physical remote by itself. That
environment switch is the test's own hook and is documented in the source.

These four ran twice against the device: once on the mechanism alone, and again at the end
against the **final** code of this pass, after every other change (both runs above, same
result). In the Simulator the same suite passes and the console shows both triggers firing
and one being deduped.

**Honest limit.** XCUIRemote drives the device's press pipeline, which is what the app reads;
it is not a thumb. It cannot tell us how a hold *feels*, whether 0.5 s is the right threshold
for the owner, or whether he was pressing the clickpad hard enough to register a click at all
in the Pass 8 test. Those need his hand on the remote.

---

## 2. Step 2 — the airing sheet fits

The row overflowed because each button was `.fixedSize()`, so three long labels ran past the
card ("Watch live" clipped to "W"). `InertActionButton` gains `flexible`: the button shares
the row's width, keeps one line, and shrinks its label to 60% before anything is cut. The
sheet's row is the only caller; every other button in the app is untouched.

The status line moved to directly under the buttons (it used to be pushed to the bottom of a
fixed-height card by a `Spacer`), the title dropped 60 → 56 pt and the description 5 → 3
lines, so the card never runs out of room.

Evidence: `10-hold-opens-sheet-current-airing.jpg` — the three-button case, "Record this
airing · Record the series · Watch live", all whole; `12-sheet-edit-series-pass.jpg` — the
longest label the sheet can show, "Edit series pass", beside "Record this airing" and above
the status line.

## 3. Step 3 — "Watch live" only while it is on

`isAiringNow` is `program.start ≤ now < program.end`, re-evaluated every 20 s so a sheet left
open across the start time does not lie. Future airings never show the button.

Evidence: `11-future-airing-no-watch-live.jpg` — Fugitives Caught on Tape, 2:30–3:00 PM, read
at 1:58 PM: two buttons only. Compare `10-hold-opens-sheet-current-airing.jpg`, a programme
running 12:00–3:00 PM read at 1:30 PM: three buttons.

## 4. Step 4 — "Edit series pass", and never a raw 409

The sheet reads `GET /api/passes` when it opens and matches this show against them the way
the server does (passes.go:719-726): the airing's own `seriesId` first, then the
`"title:<lower>"` id the server derives when a listing has none, then the pass title. When one
is found the button reads **Edit series pass** and a gold line under it reads
`◆ Series pass · N recordings scheduled · new episodes`.

Evidence, `12-sheet-edit-series-pass.jpg`, with the app's own console line:
`[sheet] pass for "Fugitives Caught on Tape": pass-mtq460lfb97905 0 recordings scheduled`.

**The 409 was tested for real, not traced.** With the sheet open on "Counting Cars" (no pass),
a pass was created behind the app's back with `curl`, and then "Record the series" was
pressed. The server answered 409; the app reloaded the passes, flipped the button to "Edit
series pass" and wrote, in plain words, **"This show already has a series pass — use Edit
series pass."** No status code, no server text (`13-409-in-plain-words.jpg`; console
`[sheet] pass 409, reloaded: pass-mtq4f62x79253a`). Every other failure goes through
`AiringSheet.friendly`, which turns the cases the owner can act on into sentences and never
shows a bare code.

Fixed on the way: creating the pass replaced the "Record the series" button with a different
view, and focus fell to the rail (visible in the Pass 8 screenshots too). One control now
changes its own title, so focus stays in the sheet.

## 5. Step 5 — the Edit series pass screen

`EditSeriesPassScreen.swift` (192 lines, new), opened by that button. Four settings and no
more; each row cycles to its next value on a click and writes it immediately with
`PUT /api/passes/{id}`, then redraws from the `passView` the server answers with — so the
screen always shows the server's state, never a guess.

| Row | Field | Choices |
|---|---|---|
| Record | `recordMode` | New episodes only · All episodes |
| Start early | `padBefore` | none · 1 · 2 · 5 · 10 · 15 · 30 minutes |
| Stop late | `padAfter` | the same |
| Keep | `keepMode` + `keepLast`/`keepUnwatched` | All · Unwatched Only · Last 3 · Last 5 · Last 10 |
| Delete this pass | `DELETE /api/passes/{id}` | arms on the first click, deletes on the second |

Live run (§8b): `20-edit-pass-screen.jpg` on open (Record: New episodes only, Start early: 5
mins before, Stop late: 3 mins after, Keep: All); two edits →
`[write] pass pass-mtq460lfb97905 → recordMode=new pad=10/3 keep=All` and
`… keep=Unwatched Only`, the screen redrawing to "10 mins before" and "Unwatched Only"
(`21-edit-pass-changed.jpg`), and `GET /api/passes` agreeing: `padBefore 10 '10 mins before'
… keepMode unwatched … keepLabel 'Unwatched Only'`. Delete armed
(`22-edit-pass-delete-confirm.jpg`: "Delete this pass — click again to confirm · This cannot
be undone"), confirmed, and the sheet returned to "Record the series" with "Series pass
deleted." (`23-sheet-after-pass-deleted.jpg`).

## 6. Step 6 — the episode menu is Keep and Delete

"Mark unwatched" and "Favorite" are gone; the menu is two rows. The show-detail footer now
reads "Click and hold an episode for Keep and Delete", and the episode row no longer carries
a ★ Favorite flag (nothing in the app sets it any more) — ✓ Watched and ◆ Keep remain.

Evidence: `30-show-detail-keep-and-delete.jpg`, `31-episode-menu-two-rows.jpg`. The menu was
opened with a hold and **closed without pressing anything** — no recording was flagged in
this pass.

## 7. Step 7 — favourite a channel from the guide's left column

The channel cell in the Guide's left column is now focusable (`ChannelCell`), and a
click-and-hold on it opens `ChannelActionsMenu` (131 lines, new) with one row that reads the
channel's current state and flips it:
`PUT /api/sources/{sourceId}/lineup/{guid} {"favorite": true|false}`. The state comes from the
`MergedChannel` the guide response embeds — the same `favorite` field `/api/channels` returns.
A favourite channel shows a gold ★ beside its name. Nothing on the airing sheet favourites a
channel.

A plain click on a channel cell does nothing: no click behaviour was named for it, and this
pass invents none (Open Question 1).

## 8. Live-server tests and the cleanup proof

Server state read at 13:54, before anything: **1 pass and 1 job, both the owner's** — a series
pass on "Hazardous History With Henry Winkler" (9001 HISTORY) with one recording queued for
9:00 PM tonight, plus a library of 2 shows / 3 recordings. All of it was left alone; my own
targets were made for the test and removed.

### 8(a) Favourite a channel, and put it back

9000 AETV (`philo:6043`), a channel with no override of any kind before or after:

```
[write] lineup philo/6043 favorite=true  → hidden=false favorite=true
GET /api/channels   favourites now: [('9000', 'AETV')]        ← 41-channel-menu-favorite.jpg → 42-channel-favourited-star.jpg
[write] lineup philo/6043 favorite=false → hidden=false favorite=false
GET /api/channels   favourites now: []   | visible count 38
GET /api/sources/philo/lineup   channels with hidden or favorite set: []
```

The menu read "Favorite · Not a favorite" first and "Unfavorite · ★ Favorite" second
(`43-channel-menu-unfavorite.jpg`), i.e. it reflects the server's state, not a local guess.

### 8(b) A series pass, edited and deleted from the app

The show was chosen so the test could not schedule anything: "Fugitives Caught on Tape" has
11 airings in the guide and **none flagged new** (`/api/guide/search`), and the pass defaults
to `recordMode "new"`, so it queued **0 jobs** at every point.

```
[write] pass "Fugitives Caught on Tape" series=title:fugitives caught on tape
        → pass-mtq460lfb97905 0 recordings scheduled          (created from the sheet)
GET /api/passes  → 2 passes: the owner's (1 job) and mine (0 jobs)
   sheet reopened → "Edit series pass"                         12-sheet-edit-series-pass.jpg
[write] pass pass-mtq460lfb97905 → pad=10/3   keep=All         (Start early 5 → 10)
[write] pass pass-mtq460lfb97905 → pad=10/3   keep=Unwatched Only
GET /api/passes  → mine: padBefore 10 '10 mins before' · keepMode unwatched · 'Unwatched Only'
[write] pass pass-mtq460lfb97905 deleted                       (armed, then confirmed)
```

A second pass ("Counting Cars", `pass-mtq4f62x79253a`) was created with `curl` to force the
409 of §4 and then deleted through the app's own editor. Both of my passes are gone.

**The step asked for "passes count back to 0"; the honest target is "no pass of mine
remains", because the owner's pass was already there when this pass began and is not mine to
delete.** It is still there, with its original settings.

### 8(c) Nothing recorded, nothing flagged

No `POST /api/record`, no `PUT /api/library/recordings/…`, no playback session — the episode
menu was opened and closed without a press. Both passes queued 0 jobs, so nothing was ever
scheduled by me.

### Cleanup proof, 14:05, the server's own answers

```
GET /api/passes    count 1  jobs 1
   pass-mtq2l4ca21e831 'Hazardous History With Henry Winkler'
   recordMode new · pad '5 mins before' / '3 mins after' · keep 'All' · jobs 1     ← identical to 13:54
GET /api/schedule  count 1 · 5ac218891674 Queued pass-mtq2l4ca21e831
                   9001 HISTORY · Hazardous History With Henry Winkler · 9:00pm–10:03pm
GET /api/channels  visible 38 · favourites []
   philo:          hidden=0 []  favorite=[]
   hdhr-10a75953:  hidden=12 [22.1 22.2 22.3 22.4 40.2 40.3 62.2 103.1 110.1 129.1 157.1 165.1]  favorite=[]
GET /api/library   shows 2  recordings 3
   the-aging-brain             d3105e15f069  watched=False fav=False keep=False trash=False
   earth-odyssey-…             4b4a3f0f8fc8  watched=True  fav=False keep=False trash=False
GET /api/settings  trashAfter '1 day'  padBefore '5 mins before'  padAfter '3 mins after'
GET /api/play/sessions   active 0
```

Every line matches the 13:54 snapshot. The 12 hidden antenna channels are the owner's own set.

### 8(d) What the Simulator verified, and what still needs the remote

Steps 2, 3, 4, 5, 6 and 7 were driven hands-on in the Simulator against the live server, with
the screenshots and server responses above. Step 1 is the one verified **on the device** —
four XCUITest runs on Home Theater. **What no test here can settle is how the hold feels in
the hand**: whether 0.5 s is comfortable, and whether the owner's own press registers as it
did for the test harness. That is the first thing to try on the remote.

## 9. Step 9 — installed on Home Theater

The final build (with every change of this pass) was installed and launched at 14:06:59
(`devicectl … install app` → `installationURL: …/Marlin DVR TV.app/`, `process launch` →
"Launched application"), and the server logged its ping: `Apple TV | 192.168.1.30 | Marlin
DVR TV 1.0 | online True | now`. It is left installed and running.

---

## Open Questions

1. **A plain click on a channel cell does nothing.** The cell had to become focusable for the
   hold; no click behaviour was named, so it has none. Should a click tune the channel live?
2. **The hold threshold is 0.5 s.** Chosen to match tvOS's own feel; nothing measured it
   against the owner's hand. Longer if it triggers by accident, shorter if it feels sticky.
3. **Two triggers are shipped.** The device test shows trigger A carries the hold on its own,
   so trigger B (the Pass 8 path) is redundant there. It stays because it costs nothing and
   the other Apple TV — an older model, `Master Bedroom ATV` — has not been tested. Drop it
   once both remotes are proven?
4. **Editing "Record" to "All episodes" can queue a lot of recordings at once** on a show that
   airs often, and the screen writes immediately with no preview of what it will schedule. It
   shows the new count afterwards. Warn before, or leave it?
5. **The edit screen cycles values on a click.** It suits a remote and matches the menu rows,
   but there is no way to jump straight to a value, and Keep's "Unwatched + N Watched" form
   is not offered (only "Unwatched Only").
6. **A pass on the same series but a different channel** counts as "this show already has a
   pass" here; the server's uniqueness is per series *and* channel (passes.go:725). The app
   never sets a channel, so it cannot create the second one anyway.
7. **The UI-test target is new in the project** (`Marlin DVR TVUITests`, one file, added to the
   shared scheme). It is the evidence harness for step 1 and the only way this Mac can press
   a real remote; it ships no code into the app. Keep it for future passes?
8. **`MARLIN_DISABLE_PRESS_STATE_HOLD`** stays in the app as the switch the isolation test
   throws. It does nothing unless set in the launch environment.
9. **The guide's marks still go stale** until the screen is re-entered (Pass 8 Open Question 5,
   unchanged).
10. **Deleting a pass from the sheet leaves the sheet open** on that airing with "Record the
    series" — correct, but there is still no way to cancel a *Record Now* booking (Pass 8
    Open Question 2, unchanged).

---

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/RemoteHold.swift` (new, 208) — `RemoteHold`, the window press recognizer, `HoldButton` | 1 |
| `Marlin DVR TV/HoldButton.swift` — **deleted**, superseded by the above | 1 |
| `Marlin DVR TV/ContentView.swift` — the one `RemoteHold`, the detector, suspend while the Player is up | 1 |
| `Marlin DVR TV/GuideScreen.swift` — hold routed through focus, the focusable `ChannelCell`, the channel menu, favourite state | 1, 7 |
| `Marlin DVR TV/ShowDetailScreen.swift` — hold routed through focus, footer copy, the ★ flag dropped from the row | 1, 6 |
| `Marlin DVR TV/AiringSheet.swift` — flexible button row, status line under it, Watch-live rule, pass lookup, Edit series pass, friendly errors | 2, 3, 4 |
| `Marlin DVR TV/ScreenChrome.swift` — `InertActionButton.flexible` | 2 |
| `Marlin DVR TV/EditSeriesPassScreen.swift` (new, 192) | 5 |
| `Marlin DVR TV/EpisodeActionsMenu.swift` — two rows, `MenuRow` reused | 6 |
| `Marlin DVR TV/ChannelActionsMenu.swift` (new, 131) — the channel menu and the shared `MenuRow` | 7 |
| `Marlin DVR TV/ServerWrites.swift` — `setChannelFavourite`, `passes`, `updatePass`, `deletePass`, the fuller `PassView`, `PassEdit` | 4, 5, 7 |
| `Marlin DVR TV/ServerAPI.swift` — `delete` | 5 |
| `Marlin DVR TVUITests/RemoteHoldUITests.swift` (new, 132) | 1 (the device proof) |
| `Marlin DVR TV.xcodeproj/project.pbxproj`, `xcshareddata/xcschemes/Marlin DVR TV.xcscheme` — the UI-test target and its scheme entry | 1 (the device proof) |
| `reports/assets/pass9/*.jpg` (14 files, 2.2 MB) | 8 |
| `COLD-START.md` — "What is built", "What is NOT built", "Next step" | deliverable |
| `reports/2026-09-06-pass9-sweep4-fixes.md` (this file) | deliverable |
| Local commit "Pass 9: sweep 4 fixes"; **no push** | deliverable |

Nothing else was written. Untouched: `DECISIONS.md`, `Info.plist`, the app target's build
settings, `Assets.xcassets`, `design/`, and every other Swift file (`Models.swift`,
`ChannelFilter.swift`, `ClientSession.swift`, `Destination.swift`, `RailView.swift`,
`HomeView.swift`, `Formatting.swift`, `ScreenShell.swift`, `OnNowScreen.swift`,
`OnLaterScreen.swift`, `RecordingsScreen.swift`, `CamerasScreen.swift`, `ServerImage.swift`,
`Theme.swift`, `ResumeStore.swift`, `PlayRequest.swift`, `PlaybackSession.swift`,
`PlayerHost.swift`, `PlayerModel.swift`, `PlayerScreen.swift`, `Marlin_DVR_TVApp.swift`).

Outside the repo: DerivedData; the app on the Simulator and on Home Theater; and on the
server, two lineup `favorite` overrides set and unset, three passes created and three deleted
— all accounted for in §8. The reference clone and `design/` were only read. No request went
beyond port 8090; none to marlinpc, the HDHomeRun directly, or the UNAS4Pro share. Nothing
installed on the Mac; no packages; no third-party code.
