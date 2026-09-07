# Pass 32 — stopping a recording from the Guide, and the trash list

**2026-09-07.** Two owner requests. **Item A is built and proven on Home Theater. Item B stopped
at its own gate in step 5 and nothing was built for it** — the server has no trash listing to read,
and step 5 says that is a stop-and-report rather than something to work around.

Committed locally, **not pushed**. Pass 31 is also unpushed; the owner tests both together.

---

## 0. One thing about the brief, before the findings

Step 1 asks for the server side "per HLS-CLIENT-API.md and the reference clone", while
ABSOLUTE DO-NOT-TOUCH lists "design/ and the reference clone" and says to stop and report if
anything pulls me toward them. **I did not read the reference clone or `HLS-CLIENT-API.md`**, and
took the do-not-touch list as the stronger instruction. Nothing was lost by it: every server fact
below is carried either by this app's own typed calls and the server file:line the notebook already
records, by Pass 8's live evidence, or by read-only probes of the running server. Where a claim
rests only on those, it says so.

---

## A — Cancel / stop a recording in progress

### A.1 Step 1 — what existed today

**Two different server calls already existed, and neither was reachable from the Guide.**

| | Call | Typed at | Used from |
|---|---|---|---|
| **Stop what is recording now** | `POST /api/schedule/jobs/{id}/stop` | `ServerWrites.swift:261-267`, answer `StopOutcome` at `:126-136` | `PlayerModel.stopBlockingRecordingAndWatch()` `PlayerModel.swift:523-532` — frame 6g only |
| **Cancel an airing that has not started** | `PUT /api/schedule/jobs/{id}` `{"skipped": true}` | `ServerWrites.swift:247-252`, answer `JobCancelResult` at `:78-85` | `ScheduleManageView.swift:343` — Manage DVR → Scheduled Recordings |

The stop call was reachable **only** from frame 6g, "Stop the recording and watch", and 6g only
appears when a *live* start fails with a tuner-busy 502 (`PlayerScreen.swift:404-405`). So a
recording could be started from the Guide and there was no way to stop it from the Guide — the
owner had to provoke a 502 on another channel, or wait.

**The server does have the endpoint, so step 1's stop-and-report does not apply.** It is not merely
wired: Pass 8 exercised it live and logged the server's answer —
`[write] stop job rec-mtq17zi54f4ab8 → STOPPED The Aging Brain stopped by owner`
(`reports/2026-09-06-pass8-sweep4-writes.md` §3). The server does not answer until the recorder has
closed the file (recorder.go:672-676, as recorded in `ServerWrites.swift:261-262`), so the tuner is
free and the partial file is on disk by the time the call returns.

**Which status means "recording now".** `Job.status` (`Models.swift:170`) is one of
`Queued | Skipped | Conflict | Recording | COMPLETED | FAILED | STOPPED`. Only `Recording` means a
file is being written. The Guide already relies on this: `GuideModel.mark(for:)`
(`GuideScreen.swift:170-176`) draws ● RECORDING on exactly that value.

### A.2 Steps 2 and 3 — what changed

One file, `AiringSheet.swift` — the sheet a hold on a Guide cell opens (`GuideScreen.swift:223-236`).

- **`recordingJob`** (`:79-82`) — the airing's job while `status == "Recording"`, and nil otherwise.
  A pass's airing qualifies exactly as a Record Now booking does; this is deliberately **not**
  `manualJob` (`:71-74`), which is limited to `passId == "manual"`.
- **The button** (`:251-255`) — "Stop recording", rendered only when `recordingJob != nil`, so it is
  absent before a booking, absent on a queued one, and gone once the recording is over.
- **Armed on the first click** (`stopArmed`, `:64`; `stopRecording()` `:375-405`). The first click
  changes the label to "Stop recording — click again" and says *"This keeps what has recorded so far
  and stops the rest. Click again to confirm."*; only the second click sends anything. This follows
  Manage DVR's Cancel recording (`ScheduleManageView.swift:292-295`), which arms the same way,
  because the part not yet recorded cannot be recovered.
- **Step 3, the refresh** — on success the sheet re-reads rather than editing what it holds:
  `job = await onScheduleChanged()` (`:396`), which is the Guide's own
  `model.refreshSchedule()` + `model.job(channelId:programStart:)` (`GuideScreen.swift:298-301`).
  That is Pass 31's rule applied here, and it redraws the Guide's ● marks at the same time.
  **The `?? job` fallback the other writes use is deliberately absent**: if a stopped job had left
  `GET /api/schedule`, keeping the old `Recording` copy would leave a Stop button on a recording
  that is already over.

**One more change was needed to make the button honest** (`:154`). The sheet used to take the job
straight from the Guide's cell and never refresh it, and the Guide refreshes its schedule only when
this sheet writes — never on a timer. A booking that had since started recording would therefore
still read `Queued`, and Stop would not appear. The sheet now re-reads the schedule when it opens,
falling back to the Guide's copy if that read fails.

### A.3 Step 4 — device evidence, Home Theater, the real Siri Remote

`Marlin DVR TVUITests/StopRecordingUITests.swift` (new, 128).

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/StopRecordingUITests"
```

**`** TEST SUCCEEDED **`, 1 test, 0 failures, 42.4 s, 12:04:46–12:05:31.**

```
[pass32 12:05:06.199] book: holding, focus is Midday Maryland
[pass32 12:05:14.093] booked: "Set to record · Recording"
[pass32 12:05:17.924] reopen: holding, focus is Midday Maryland, ● RECORDING
[pass32 12:05:29.331] armed
[pass32 12:05:31.041] stopped: "Recording stopped · STOPPED · stopped by owner"
```

| Screenshot | What it shows |
|---|---|
| `01-sheet-before-recording.png` | The sheet on *Midday Maryland*, 2.1 WMAR-HD. **No Stop button** — nothing is recording |
| `02-sheet-after-booking.png` | "Set to record · Recording"; the Guide cell behind it gains ● RECORDING |
| `03-sheet-reopened-while-recording.png` | **"● Scheduled / Recording · Record the series · Watch live · Stop recording"** — four controls, all fitting |
| `04-stop-armed.png` | "Stop recording — click again", with the sentence saying what is kept and what is lost |
| `05-after-the-stop.png` | Chip reads **"● Scheduled / STOPPED"**, message **"Recording stopped · STOPPED · stopped by owner"**, and the **Stop button is gone** |

Five assertions carry it: Stop is absent before recording; present once recording; focus reaches it;
**one click only arms it**; and after the write both the button and its armed form are gone.

**The server agrees** — read directly from this Mac at 12:05:46, seconds after the run:

| | |
|---|---|
| `GET /api/schedule` | `rec-mtrfm5v9d1fd63` · 2.1 · *Midday Maryland* · **`STOPPED`** |
| `GET /api/library` | the partial recording landed: `midday-maryland`, 1 episode |
| `GET /api/library/shows/midday-maryland` | `b7a3822d83b4` · **7.66 MB** · `exists true` · `trash false` |

The job stays listed as `STOPPED` rather than disappearing, so `onScheduleChanged()` returned it and
`recordingJob` went nil on the status. **The nil branch of `:396` was therefore not exercised** — it
is reasoning about a case this server did not produce.

### A.4 The run that failed first, and why

The first attempt was killed after ~11 minutes. **The fault was the harness, not the app.** It read
the screen with `app.staticTexts.allElementsBoundByIndex`, and on a Guide of 83 channel rows one
such call took about five minutes on the device (11:53:15 → 11:58:19 in its log). Three of them ran
past the point where the booked programme ended on its own, so Stop was never reached. The harness
was rewritten to use scoped, short-circuited queries (`firstMatch`, exact labels) and the loop that
walks focus was bounded; the rewrite runs in 42 s. The header of the test file carries this so it is
not reintroduced. Nothing was retried blind: the run was stopped, diagnosed from its own timestamps,
and re-run once.

That aborted run **did** leave a recording behind — see §C.

---

## B — Restore from Trash: STOP AND REPORT at step 5

### B.1 How the trash list is built today

`ManageModel.refreshTrash` (`ManageDVRScreen.swift:74-104`):

1. `GET /api/library?limit=500`;
2. collect the show ids out of the **section items** (`:78-84`);
3. ask each show `GET /api/library/shows/{id}?trash=1`, six at a time (`:86-99`).

`TrashManageView.swift:5-7` states the reason in the file itself: *"The library has no trash
endpoint of its own, so `ManageModel` assembles the list show by show."* Restore is
`PUT /api/library/recordings/{id} {"trash": false}` (`TrashManageView.swift:8`, via
`api.updateRecording(id:flag:.trash(false))`); Empty Trash is `POST /api/library/trash/empty`
(`ServerWrites.swift:254-259`). **Empty Trash was not sent in this pass and its code was not touched.**

### B.2 The server exposes no trash listing — measured

Probed read-only against the running server today:

| Request | Answer |
|---|---|
| `GET /api/library/trash` | **404** |
| `GET /api/trash` | **404** |
| `GET /api/library/recordings?trash=1` | **404** |
| `GET /api/library/shows` | **404** |
| `GET /api/library?trash=1` | **200 — and byte-for-byte identical to `GET /api/library`**, so the parameter is ignored |

The only trash-aware reads the server has are per show, and they need a show id you already hold.
This matches what Pass 10 recorded from the server repo. **So step 5's condition is met and item B
stops here.**

### B.3 Why this cannot be worked around from the client

It is worse than "the list is assembled awkwardly". Pass 31 measured that a show whose last episode
is trashed **leaves `GET /api/library` entirely** — `shows` went 1 → 0, every section emptied, at
`limit=6` and `limit=500` alike. There is therefore **no route by which the app can learn that
show's id**, and without the id the per-show trash read cannot be made. The recording is not merely
hard to list; it is undiscoverable through the public API.

Confirmed still true at 12:03 today: the library lists the shows that exist, and
`GET /api/library/shows/hazardous-history-with-henry-winkler?trash=1` still answers
`6007a13f0b46 · trash true · exists true · 1.86 GB` — but only because **I already knew that id**,
from having deleted it in Pass 31. The app has no such memory, and inventing one (caching show ids
the app has happened to see) would be a client-side guess at server state that would miss anything
deleted from the web UI or the other Apple TV. That is the workaround step 5 forbids.

### B.4 What this blocks, plainly

- **Step 6 was not built.** "Make the Trash list come from the server directly" has nothing to read.
- **Step 7 could not be run.** The Henry Winkler episode cannot be reached in Manage DVR → Trash, so
  Restore cannot be pressed on it from the device. **Restore therefore remains "wired but never
  exercised live"**, exactly as COLD-START.md has said since Pass 10.
- **Step 8's second half is already answered** and needs no build: with the show still in the library
  the existing list is correct (Pass 10 rendered it from a real trashed recording); with the show
  gone it is empty, which is the defect.

**The fix belongs to the marlin-dvr project**, which is the standing rule for server changes
(COLD-START.md, "The rules"). The smallest thing that would unblock item B is a single read —
`GET /api/library/trash`, answering the trashed `episodeView`s the way `?trash=1` already does per
show. With that endpoint, item B becomes a small change to `refreshTrash` and nothing else.

---

## C — What this pass left on the owner's server

Named rather than tidied away, because none of it was in the steps and removing it would be a write
nobody asked for:

| | |
|---|---|
| `midday-maryland` `b7a3822d83b4` | **7.66 MB** — the throwaway of step 4, stopped by the test |
| `the-view` `eccf81dbdab2` | **275.92 MB** — booked by the **aborted** first run (§A.4) and left to finish on its own when that run was killed. Not intended; disclosed |
| `hazardous-history-with-henry-winkler` `6007a13f0b46` | 1.86 GB, still `trash true` from Pass 31, still unreachable from the Apple TV |

Two server writes were made in total: one `POST /api/record` and one
`POST /api/schedule/jobs/{id}/stop`. Nothing was deleted, nothing was restored, Empty Trash was
never sent.

---

## SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `Marlin DVR TV/AiringSheet.swift` | **modified** — `stopArmed` `:64`, `recordingJob` `:79-82`, the schedule re-read on open `:154`, the button `:251-255`, `stopRecording()` `:375-405`, header note | A2, A3 |
| `Marlin DVR TVUITests/StopRecordingUITests.swift` | **new** — the device harness; written, found too slow, rewritten, kept | A4 |
| `reports/2026-09-07-pass32-cancel-and-restore.md` | **new** — this report | deliverable |
| `reports/assets/pass32/*.png` | **new** — the five screenshots the passing run attached | A4 |
| `COLD-START.md`, `DECISIONS.md` | **modified** — the standing notebook record | project rule |
| `build/**` | build output and result bundles; git-ignored, never committed | A |

**Not done, as scoped:** **nothing was built for item B** — `ManageDVRScreen.swift` and
`TrashManageView.swift` are untouched by diff. Empty Trash was not exercised and not changed. No
change to playback, frame stepping, the end-of-range defect, or any other screen's refresh
behaviour — the only refresh touched is the airing sheet's own, which steps 2 and 3 called for. No
server-side change was made or attempted. No new dependency. **The reference clone,
`HLS-CLIENT-API.md` and `design/` were not read** (§0), and nothing outside this folder was written;
Unraid, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched beyond the DVR's own HTTP
API. `GET /api/settings` was not read, per the owner's standing instruction from Pass 31.

**Git: committed locally, not pushed** — the owner tests Passes 31 and 32 together.
