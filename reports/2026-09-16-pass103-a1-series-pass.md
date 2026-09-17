# Pass 103 — A1: show detail's series pass button

**Date:** 2026-09-16
**Built:** `Marlin DVR TV/ShowDetailScreen.swift` only, plus one new evidence harness.
**Run on Home Theater:** yes — one passing run, photographed, with the launch ping found in
`GET /api/logs` first.
**Writes sent to the server by this pass: none.** The app's only non-GET in the whole run was its
own launch ping (`ClientSession.swift:8-9`). §5.4 proves it line by line, including the three POSTs
that appear in the same log window and are **the owner's own web UI, not this app**.

`file:line` below was read at HEAD `22066d54a36c68c218f4f3ca2ab1dc810075ef7b` (Pass 102). Line
numbers drift and are never rewritten afterwards (COLD-START, *Standing state of the devices*).

---

## 0. What the owner decided, and what this pass did with it

Pass 102 §6 open question 5 — *"**Does A1's button become 'Edit series pass' when a pass exists**,
as the airing sheet's does (3.6)? Not settled anywhere"* — was the gate. It was put to him and he
answered it (2026-09-16), in substance:

> Show detail's button reads **"Record the series"** when the show has no series pass, and pressing
> it does exactly what the airing sheet's "Record the series" does — same flow, same screens, same
> route, same result text, shown under show detail's buttons the way the sheet shows it. Once the
> show has a pass, the button reads **"Edit series pass"** and opens the same editor the Guide's
> "Edit series pass" opens. The button follows the show's pass state the way the airing sheet's
> does, including after an add or a delete. **No `recordMode: "new"` warning** (the sheet has none).

That settles every choice Pass 102 §3.6 and §6.5 recorded as open, so this pass built it. **Nothing
was invented beyond it**, and where a show could not be made to behave exactly like an airing, the
difference is written down rather than papered over (§2.2).

---

## 1. What was there before

- `ShowDetailScreen.swift:195` — `inert("Series pass", id: "pass")`.
- `ShowDetailScreen.swift:208-216` — the `inert(_:id:)` helper, a `Button` whose whole action body
  was the comment *"'Series pass' here is not in Pass 8's steps (the airing sheet's is); it stays
  inert."*
- `ShowDetailScreen.swift:13-14` — the file header saying the same.

The design, frame **5d** (`design/Marlin DVR TV.dc.html:605`), gives the button a bare
`<span>Series pass</span>` in a row of two beside `Play newest` — a label and a position and no
behaviour, which is what Pass 102 §1 recorded and what re-reading the design confirmed. The
design's only other "Series pass" is at `:288`, inside frame **3b** (the Guide). There is no 5d
variant anywhere for a show that already has a pass.

---

## 2. What was built

All of it in `ShowDetailScreen.swift`. `AiringSheet.swift`, `EditSeriesPassScreen.swift`,
`ServerWrites.swift`, `Models.swift` and the project file are **untouched** — `git diff --stat`
over the app target is one file.

### 2.1 The control, and the flow behind it

| | |
|---|---|
| **The button** | One control with two labels, not two controls: `pass == nil ? "Record the series" : "Edit series pass"`. That is the sheet's own arrangement and the sheet's own reason (`AiringSheet.swift:258-259`) — swapping the view would drop focus the moment the pass is created. |
| **No pass → press** | `recordSeries()`, a copy of `AiringSheet.recordSeries()` (`:371-395`): `api.createPass(title:seriesId:)` (`ServerWrites.swift:192`), then `pass = created` and the message **"Series pass created · \(countLabel)"**. |
| **409** | The sheet's branch, unchanged in substance: never the raw 409 — re-read the passes, then **"This show already has a series pass — use Edit series pass."** (or the shorter sentence if the re-read finds nothing). By the time the sentence is on screen the button already reads "Edit series pass". |
| **Any other failure** | `AiringSheet.friendly(_:fallback:)`, **called unchanged**, with the sheet's own fallback sentence. |
| **Has a pass → press** | `editingPass = pass`, which draws **`EditSeriesPassScreen`** — the one editor a pass is reached through from anywhere: the Guide reaches it through the sheet (`AiringSheet.swift:137`), and Manage DVR reaches it from `ScheduleManageView.swift:63` and `PassesManageView.swift:26`. |
| **After an edit / after a delete** | The sheet's callbacks, copied: `onChanged` sets `pass` and `editingPass` to the updated `passView`; `onDeleted` sets `pass = nil`, closes the editor, says **"Series pass deleted."** and returns focus to the button — which by then reads "Record the series" again. |
| **The footer** | The sheet's footer (`AiringSheet.swift:298-321`): the write's result text, or, with no message, the gold **`◆ Series pass · n recordings scheduled · all/new episodes`**. Directly under the buttons, as the sheet has it. |
| **Pass state** | One `GET /api/passes` in the screen's existing `.task`, after `model.load()`. |
| **`recordMode: "new"` warning** | None, per the decision. Pass 8 Open Question 3 stays open for both screens. |

### 2.2 Three places a show is not an airing, each a deliberate difference

1. **No `onScheduleChanged()`.** The sheet re-reads `GET /api/schedule` after its write to refresh
   the Guide's ● / ◆ marks and its own first control. Show detail draws nothing from the schedule
   and has no airing state, so there is nothing to refresh and **no such read is made**. The result
   text is unaffected: `countLabel` comes from the POST's own `passView`, not from the schedule.
2. **The match is on the title alone.** `AiringSheet.matchingPass(in:program:)` (`:340-350`) needs a
   `Program`; a show has none, and fabricating one to reuse the function would have meant inventing
   a channel, a start and an end. Of its three rules only two can bear on a title-only subject — the
   `"title:<lower>"` id the server derives for a listing with no `seriesId`, and the pass title — and
   **those two are exactly what the server itself applies** to fill `ShowResponse.pass`
   (`library.go:659-664`, read from the 1.8.1 clone by Pass 102). So `matchingPass(in:showTitle:)`
   is that pair, written in this file, and **`AiringSheet.swift` was not edited**. Pass 102 §1 had
   already measured why this is safe on this server: all 8 passes and all 88 programmes carry
   `title:`-prefixed ids, so a pass created here matches exactly the airings a sheet-created pass
   would.
3. **`ShowResponse.pass` is not what the button reads.** It is in hand with no extra read, but it is
   the matching pass *title* (`Models.swift:407`) and opening the editor needs the `PassView`
   itself. One read answering both questions beats two sources for one fact.

### 2.3 One deviation from "the way the sheet shows it", and why

The gold footer is **`.lineLimit(2)` where the sheet's same line is `.lineLimit(1)`**. The sheet
draws it across a 1400 pt card; show detail's left column is 520 pt. The first passing run
photographed it cut off — `◆ Series pass · 5 recordings scheduled · all episod…` — so the line was
given a second line. **The text is the sheet's, unchanged**; only the room it is given differs, and
it now matches the message line above it, which is `.lineLimit(2)` in both screens. This is the only
place the two footers differ, and it is disclosed rather than absorbed.

### 2.4 Two small things the new state made necessary

- The content is `.disabled(menuEpisode != nil || editingPass != nil)` and `handleHold()` gained an
  `editingPass == nil` guard, so the episode menu cannot open behind the editor. This is the pattern
  `EpisodeActionsMenu` already used.
- `inert(_:id:)` was **replaced**, not left beside its successor. It existed only for this button;
  leaving it would be dead code inviting a later pass to reach for it, which is the reason Pass 49
  removed `manualJob` rather than leave it (DECISIONS.md, 2026-09-08 (Pass 49)).

---

## 3. The route, and what it is worth at the running server

| Route | Kind | Standing |
|---|---|---|
| `POST /api/passes` | **write** | **Unconfirmed at the running server.** It is a write, so this pass did not call it either, and the newest source readable is the 1.8.1 clone (Pass 102 §0, `passes.go:705-737`). The app has sent it from the airing sheet since Pass 9, which is why the 409 branch is written the way it is — **not** a reason to call it confirmed. |
| `GET /api/passes` | read | Called twice by the two device runs, **200 both times** (§5.4), at the running server. |
| `GET /api/library/shows/{id}` | read | The read the screen already made; unchanged. |

**The running server is 1.9.2, not the 1.9.1 the notebook records.** `GET /api/status` answered
`{"name":"marlin-dvr","version":"1.9.2","uptime_seconds":2834,"port":8089}` today, and the server's
own log carries `update check (requested): 1.9.3 is published; this server runs 1.9.2`. COLD-START's
*The server* line and DECISIONS' Pass 101 entry both say 1.9.1, measured on 2026-09-16. **Nothing
was changed in those lines by this pass** — see §7 open question 1 — and no conclusion here rests on
the difference: `POST /api/passes` was unconfirmed at 1.9.1 and is unconfirmed at 1.9.2 for the same
reason, that nobody has called it.

---

## 4. The harness

`Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift`, one test. An evidence harness, not a
standing test: it needs Home Theater, the real remote, and the owner's own library.

**It is written so that it cannot write.** `"Record the series"` is photographed and **never
pressed** — it is `POST /api/passes`, which creates a pass and queues recordings on his DVR, and
Pass 102 §5/A1 recorded that a pass made for evidence should be one he wants. Inside the editor
**nothing is pressed at all**: every `MenuRow` writes `PUT /api/passes/{id}` on a single click and
the editor opens with focus on the first of them (`EditSeriesPassScreen.swift:135-139`), so the
harness reads it, photographs it and leaves by **Menu**. "Leaving it saves and deletes nothing" is
therefore established by never having sent anything, which is stronger than checking afterwards.

It uses **`launch()`**, not `activate()`, for the reason COLD-START records under *Known and
unfixed*: `activate()` photographed a stale build in Pass 92.

The two subjects were read from the server before the run, not guessed — `GET /api/library/shows/…`
answered `pass: ""` for **Hitler's DNA** and `pass: "The Food That Built America"` for **The Food
That Built America**. Both cases existed in his library already, so the run needed no setup.

---

## 5. The verification — Home Theater

### 5.1 The runs

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p103 test -only-testing:"Marlin DVR TVUITests/ShowDetailSeriesPassUITests"
```

`build/p103` is git-ignored (`.gitignore:4:build/`).

| Run | Result | Bundle |
|---|---|---|
| 20:57:12 | **FAILED**, 14 failures, all from one cause | `…/Test-Marlin DVR TV-2026.09.16_20-57-12--0400.xcresult` |
| 21:02:49 | **TEST SUCCEEDED**, 61.417 s | `…/Test-Marlin DVR TV-2026.09.16_21-02-49--0400.xcresult` |
| 21:06:56 | **TEST SUCCEEDED**, 59.674 s — the run the screenshots come from, after §2.3's one-line change | `…/Test-Marlin DVR TV-2026.09.16_21-06-56--0400.xcresult` |

### 5.2 The first run failed on navigation, not on the feature — and it is worth recording why

All 14 failures cascaded from one: the harness could not reach the card for *The Food That Built
America*, and every later assertion then ran on the wrong screen. **The walk's own log says exactly
what happened:**

```
step 3: focus is History's Greatest Mysteries, S7 E20 · 1 min in
step 4: focus is History's Greatest Mysteries, S7 E20 · 1 min in
…identical through step 17
```

It had walked Right to the **end** of the Continue watching shelf and then pressed Down. **Down from
there does nothing.** Continue watching holds 5 cards on this Apple TV; the two server shelves below
hold 4 (then 5); each row keeps its own horizontal scroll offset, so from the 5th card there is no
focusable card below and tvOS refuses the move. Four Downs and ten Rights all no-ops.

The harness was changed to walk each row and **come back to the left-hand column before going
down** — counting its own Rights and undoing them with the same number of Lefts, which also keeps it
from pressing Left off the first card into the rail (Pass 25's `railRestore`). It now also reports a
press that does not move focus, so a stuck walk says where it stuck instead of spending its budget.
**This is a fact about the Recordings screen, which this pass did not touch and did not change.**

Two things the failed run is nonetheless evidence for, because they passed inside it: part 1 — the
no-pass case — raised no failure at all, and the screen it wrongly landed on, *History's Greatest
Mysteries*, drew `◆ Series pass · 0 recordings scheduled · new episodes`, a third show exercising
the has-a-pass path.

### 5.3 What the passing run saw

From the harness's own log, 21:07:

| | |
|---|---|
| **Hitler's DNA** (no pass) | buttons `… "Play newest", "Record the series" …`; footer **none** |
| **The Food That Built America** (has a pass) | buttons `… "Play newest", "Edit series pass" …`; footer **`◆ Series pass · 5 recordings scheduled · all episodes`** |
| **the press** | `walking to "Edit series pass": focus is Edit series pass` → Select |
| **the editor** | `"SERIES PASS"`, `"The Food That Built America"`, `"5 recordings scheduled · any channel"`, rows `Record / All episodes`, `Start early / 3 mins before`, `Stop late / 3 mins after`, `Keep / All`, `Pause / Running`, `Delete this pass`; `editor focus: Record, All episodes` |
| **after Menu** | buttons `… "Edit series pass" …`; footer **unchanged**; `focus: Edit series pass` |

Asserted as well: the Pass 8 label `"Series pass"` is nowhere on either screen; a show with no pass
draws no `◆` line; the editor is gone after Menu; and no `"Series pass deleted."` message appeared.

### 5.4 The launch ping, and the proof that this app wrote nothing

The passing run ran 21:06:56–21:08:00. In `GET /api/logs` two clients ping in that window, and they
are easy to tell apart:

- **The app: one ping, `21:07:02.866`** — 2.1 s after the test suite started at 21:07:00.750. One
  launch, one ping. That is the Pass 92 signature, and it is why the screenshots are believed.
- **The web UI: six pings**, each landing with a page load (`Marlin Advanced.dc.html` at 21:06:27,
  `Marlin Dashboard.dc.html` at 21:08:10) and each followed by `GET /api/settings`, a route this app
  never requests and this project is forbidden to read.

**Every request the app made in that window was a GET but for that one ping**, including the two
this pass added — `GET /api/passes 200` at `21:07:18.392` (right after
`GET /api/library/shows/hitler-s-dna`) and at `21:07:42.654` (right after
`…/the-food-that-built-america`).

**Three POSTs do appear in the same window, and none is this app's:**

| | |
|---|---|
| `21:06:29.252 POST /api/comskip/redetect 200` | **Before the run started.** The app has no such call anywhere (`grep` over both targets: nothing). It follows the Advanced admin page loading at 21:06:27 and queued all 11 recordings for detection. |
| `21:07:52.778 POST /api/guide/refresh 200` | Inside the window. The app has no such call anywhere. It follows the server's own XMLTV loads. |
| `21:08:03.361 POST /api/record 200` | **After the test process ended** (21:08:00.424). The log line beside it is `Record Now: Expedition X on 9009 DISCOVERY at Wed 9:00 PM`. The app does have `POST /api/record`, but only from the airing sheet's "Record this airing" — reachable from the Guide, On Later and Search, **none of which this harness visited**; it was on Recordings, show detail and the editor throughout. |

The owner was working in the server's own web admin UI while the run went on. Nothing here asked
him to, and nothing here depends on it.

### 5.5 The screenshots — `reports/assets/pass103/`

Exported with `xcrun xcresulttool export attachments` from the 21:06:56 bundle, then converted from
3840 × 2160 PNG to 1920 × 1080 JPEG with `sips -Z 1920 -s format jpeg`, so 1 px is 1 pt.

| Screenshot | What it shows, as viewed |
|---|---|
| **`103a-no-pass-record-the-series.jpg`** | *Hitler's DNA*. The 5d row of two reads **Play newest** · **Record the series**, in the design's own positions. No `◆` line under them. Focus is on the primary `Resume S0 E0 · 1 min in` above. |
| **`103b-has-pass-edit-series-pass.jpg`** | *The Food That Built America*. The same row reads **Play newest** · **Edit series pass**, with the gold **`◆ Series pass · 5 recordings scheduled · all episodes`** directly beneath, on two lines (§2.3). |
| **`103c-editor-open.jpg`** | `EditSeriesPassScreen` over a dimmed show detail — `SERIES PASS`, the pass title, `5 recordings scheduled · any channel`, and all six rows, with **Record / All episodes** focused. The same screen the Guide opens. |
| **`103d-back-on-show-detail.jpg`** | After Menu. The button still reads **Edit series pass** and now holds focus; the gold line is unchanged; the pass is intact. |

### 5.6 What is run-verified and what is code-traced only

**Run-verified on Home Theater:**

- A show with no pass draws "Record the series", no "Edit series pass", no "Series pass", no ◆ line.
- A show with a pass draws "Edit series pass" and the gold footer carrying the server's own
  `countLabel` and `recordMode`.
- `GET /api/passes` fires once per show-detail open, 200 both times.
- Pressing "Edit series pass" opens `EditSeriesPassScreen` for that pass, focused on its first row.
- Menu closes the editor and returns to show detail with the button, the footer and the pass
  unchanged — and nothing was sent to cause a change.

**Code-traced only, and it is the larger half:**

- **The "Record the series" press.** `POST /api/passes` was never sent. So `createPass` returning a
  `passView`, `pass = created`, the message "Series pass created · …", and the button changing to
  "Edit series pass" **after an add** are all traced, not seen.
- **The 409 branch** — `loadPass()` then the two sentences — and **the general failure branch**
  through `AiringSheet.friendly`. Neither was reached.
- **The button's change after a delete**, and the message "Series pass deleted.". Deleting a pass of
  his was not something to do for evidence, so `onDeleted` is traced: it is the sheet's own
  callback body minus the schedule read.
- **`onChanged`** — editing a setting inside the editor writes, so it was not pressed.
- The **"This show already has a series pass."** sentence (the 409 whose re-read finds nothing) is
  unreachable on this server's data and is traced twice over.

---

## 6. Files touched

| Step | File | What |
|---|---|---|
| 1 | `Marlin DVR TV/ShowDetailScreen.swift` | The whole of A1. The only app-target file changed. |
| 2 | `Marlin DVR TVUITests/ShowDetailSeriesPassUITests.swift` | New; the evidence harness. Picked up automatically — the targets are `PBXFileSystemSynchronizedRootGroup`s, so **the project file was not edited**. |
| 2 | `reports/assets/pass103/103a…d.jpg` | The four screenshots. |
| 3 | `COLD-START.md`, `DECISIONS.md`, this report | The notebook. |

---

## 7. Open questions

1. **The running server answers 1.9.2; the notebook says 1.9.1** (§3). COLD-START's *The server*
   line and the Pass 101 entry were **not** edited — this pass's scope is A1, and a server-version
   line is not one of the three COLD-START edits it names. Should the next pass record 1.9.2 (and
   the `1.9.3 is published` the server's own log reports)?
2. **Show detail still does not reload after the Player closes** — Pass 8 Open Question 6, untouched
   and now slightly more visible: the pass footer is read when the screen opens, so a pass created or
   deleted elsewhere while show detail sits behind the Player is not reflected until the screen is
   re-entered. Not changed, not raised as a defect, recorded.
3. **`Resume S0 E0 · 1 min in`** is plainly visible in `103a` — a season-0/episode-0 recording
   rendering as "S0 E0". Pre-existing (`ShowDetailScreen.swift:175`, Pass 6 / Pass 91's label), not
   this pass's, not touched. Recorded because this pass's own evidence photographs it.
4. **A pass created from show detail carries no channel**, exactly as one created from the sheet
   does (`channel: ""`, "any channel" in the editor). That is the server's default and it matches
   every one of his 8 existing passes, so nothing was done about it.
5. **Down from the last Continue watching card goes nowhere** (§5.2). Measured on the Recordings
   screen, which this pass did not touch. Whether that matters to the owner with a remote in his
   hand is his call; nothing was built and nothing was disabled.

## 8. What I am least sure of

1. **That the "Record the series" press behaves as traced when he makes it.** It is the half of A1
   that could not be proven without creating a pass on his DVR, and `POST /api/passes` is
   unconfirmed at the running server. The flow is a copy of the sheet's, which has worked since
   Pass 9, and the 409 branch exists precisely because the server can refuse — but a copy of a
   working flow is an argument, not a measurement.
2. **That matching on the title alone is right for every show he will ever have.** It is right for
   all four in his library today and it is what the server itself does for `ShowResponse.pass`. Two
   shows with the same title on different channels would collide — but so would they in the sheet,
   and the server's own `Pass.matches` falls through to the title in exactly the same way. I did not
   find a case where the sheet and this screen would disagree; I did not prove there is none.
3. **That opening the editor from here is as harmless as it looked.** Nothing was pressed inside it
   and nothing was sent, so what §5.3 shows is that the editor draws and closes. Whether a *write*
   from inside the editor lands correctly when its parent is show detail rather than the sheet is
   `onChanged`, and `onChanged` is traced.
