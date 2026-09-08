# Pass 33 — the Trash screen reads the new server endpoint, and Restore works

**2026-09-07.** marlin-dvr 1.6.0 shipped `GET /api/library/trash`, unblocking what Pass 32 stopped
at. **All five steps are done.** The endpoint matches what was announced, the Trash screen is
rebuilt on it, and **Restore is proven live on Home Theater for the first time since it was written
in Pass 10** — two recordings restored, both back in the library and on the Recordings shelves.

Committed locally, **not pushed**. Passes 31, 32 and 33 are unpushed; the owner tests them together.

Two things did not go to plan and are reported rather than papered over: **the owner's four trashed
recordings were permanently deleted mid-pass by his own web UI** (§0), and **step 4's premise turned
out not to hold** — the trash held only one of the two forms, and after the deletion the other form
cannot be made any more (§4).

---

## 0. What happened to the owner's four trashed recordings

**They are gone. Permanently. At 20:51:50 tonight, from the owner's own web-UI session — not from
this project.** This is the server's own log, not an inference:

```
20:51:42  GET / , /Marlin Dashboard.dc.html , /api/settings , POST /api/clients/cmtotjemh7dc9f4/ping
20:51:44  12 × GET /api/library/trash + 1 × HEAD          ← mine, all reads
20:51:50  DVR deleted /mnt/unas4pro/DVR/The Mega-Brands That Built America/… (1.18 GB) — Empty Trash
20:51:50  DVR deleted /mnt/unas4pro/DVR/Hazardous History With Henry Winkler/… (1.86 GB) — Empty Trash
20:51:50  DVR deleted /mnt/unas4pro/DVR/The Aging Brain/… (569.05 MB) — Empty Trash
20:51:50  DVR deleted /mnt/unas4pro/DVR/Earth Odyssey With Dylan Dreyer/… (206.85 MB) — Empty Trash
20:51:50  DVR Empty Trash: 4 recordings deleted (3.80 GB freed), 0 failed
20:51:50  HTTP POST /api/library/trash/empty 200
```

That is 2 minutes and 5 seconds after this pass first read the endpoint. **Every non-GET request
the server logged from its 20:36:52 start until that moment** was the owner's browser: pings,
`POST /api/update`, `POST /api/record`, `PUT /api/passes/pass-mtqmcna30c9176`, and later two
`PUT /api/settings` and ten `DELETE /api/clients/…`. **This pass sent no POST, PUT or DELETE before
21:09** — the sole entry attributable to it in that window is one `HEAD /api/library/trash`, a probe
that hung in `curl` and was killed. Empty Trash was never pressed from the Apple TV in this pass and
its code was not touched.

Two consequences, both carried forward into COLD-START.md so no later pass looks for them:

- **`6007a13f0b46`** (Hazardous History With Henry Winkler S2 E20, 1.86 GB), which the notebook has
  tracked since Pass 31 as the unreachable trashed recording, **no longer exists.**
- Every one of the four was deleted from `/mnt/unas4pro/DVR/<Show>/…` — **all four were still in
  their original show folders.** They were the pre-1.6.0 form, and with them gone that form cannot
  be produced any more. See §4.

---

## 1. Step 1 — what `GET /api/library/trash` actually returns

Read from this Mac at **20:49:45**, while the owner's four were still there. **Raw, unedited:**

```json
{"count":4,"recordings":[
{"id":"6007a13f0b46","show":"Hazardous History With Henry Winkler","episodeTitle":"Surviving the '70s","season":2,"episode":20,"aired":"2026-09-06T21:00:00-04:00","trashedAt":"2026-09-07T11:12:13.882484831-04:00","size":2000783044},
{"id":"d3105e15f069","show":"The Aging Brain","episodeTitle":"","season":0,"episode":0,"aired":"2026-09-06T13:00:00-04:00","trashedAt":"2026-09-07T10:51:38.59846497-04:00","size":596695648},
{"id":"4b4a3f0f8fc8","show":"Earth Odyssey With Dylan Dreyer","episodeTitle":"On the Hunt","season":6,"episode":23,"aired":"2026-09-05T09:30:00-04:00","trashedAt":"2026-09-07T09:13:18.78147695-04:00","size":216893412},
{"id":"b694d42ce74f","show":"The Mega-Brands That Built America","episodeTitle":"Rise of the Personal Computer","season":4,"episode":6,"aired":"2026-09-06T22:03:00-04:00","trashedAt":"2026-09-07T09:13:08.170798905-04:00","size":1263666816}]}
```

**HTTP 200, `application/json`, 907 bytes, 4.1 ms.** Server `1.6.0`, build `2026.09.05`
(`GET /api/system`).

### Do the field names and types match what was announced?

**Yes, exactly — every one of the eight, on every row, with no omissions.**

| Announced | Present | Type as returned | Note |
|---|---|---|---|
| `id` | yes | string | 12 lowercase hex |
| `show` | yes | string | the show's **title**, not its slug |
| `episodeTitle` | yes | string | `""` when absent — the key is always there, never omitted |
| `season` | yes | number | `0` when absent |
| `episode` | yes | number | `0` when absent |
| `aired` | yes | string | RFC 3339 with offset, whole seconds |
| `trashedAt` | yes | string | RFC 3339 with offset, **nanosecond** fraction |
| `size` | yes | number | bytes |

**Two shape facts the announcement did not mention, neither of them a mismatch:**

1. **The rows come wrapped**, not as a bare array: `{"count": N, "recordings": [...]}`. `count`
   equalled `len(recordings)` in every response measured.
2. **`trashedAt` carries nine fractional digits** (`…13.882484831-04:00`), which is Go's default and
   which `ISO8601DateFormatter` **refuses at every option** — it accepts at most three. The app
   drops the fraction before parsing (`ServerTime.date`, `Formatting.swift`). `aired` has no
   fraction and parses directly.

### The empty-result shape — measured, not assumed

```
GET /api/library/trash  →  {"count":0,"recordings":[]}
```

`recordings` is **`[]`, not `null`**, and `count` is `0` — so the empty case needs no special
handling. This was measured three times at 21:02:15/17/19, and again at 21:17:54 after the pass's
own restores. It was measurable only because of §0; had the trash not been emptied the pass would
have had to reason about it rather than read it. The decoder is lenient about `recordings` anyway
(`TrashResponse.init(from:)`), because one server release marshalling an empty slice as `null`
would otherwise blank the screen with a decode error.

### It takes no parameters

`?limit=2`, `?limit=0`, `?show=nope`, `?trash=1`, `?q=zzzz` — all returned the **complete** list,
byte-identical to the bare call. There is no paging and no filter; the whole trash comes at once.

### What else was measured, that the rebuild depends on

| Probe | Answer | Why it matters |
|---|---|---|
| `GET /api/library/recordings/{id}/thumb.jpg` on all four | **404** | a trashed recording has no thumbnail, so the row cannot use one |
| `GET /api/art/show?title=…` for a show that has left the library | **200, 47 KB JPEG** | the row draws the **show's poster** instead |
| `GET /api/library/recordings/{id}` | 404 `no such API route` | there is no per-recording read; the listing is all there is |
| `GET /api/library/shows/{slug}?trash=1` for all 3 library shows | **0 episodes, `trashCount` 0** | see below |

**The old approach is not merely incomplete against 1.6.0 — it now returns nothing at all.** Pass 32
measured `hazardous-history-with-henry-winkler?trash=1` returning that trashed episode at 12:03
today. At 20:52 the same call returned **0 episodes**. The per-show `?trash=1` read no longer
surfaces these recordings, so the Pass 10 walk would have shown an empty Trash **even for a show
still in the library**. The rebuild was not an optimisation; it was the only thing that still works.

### The owner's 3.79 GB

The four totalled **4,078,038,920 bytes**. The server's own `humanBytes` (1024-based, `%.2f`) makes
that **3.80 GB**, and its Empty Trash line at 20:51:50 says exactly `3.80 GB freed`. The owner's
3.79 GB is the same four files with the last digit truncated rather than rounded. **Decimal
formatting would have said 4.08 GB** — which is why the app now formats these counts the server's
way (§2).

---

## 2. Step 2 — the rebuild

### `ManageModel.refreshTrash` — the whole walk replaced by one read

**Before** (`ManageDVRScreen.swift:74-104`, 31 lines): `GET /api/library?limit=500` → collect show
ids from the section items → `GET /api/library/shows/{id}?trash=1` for every one of them, six at a
time in a task group → sort by show name.

**After** (11 lines):

```swift
/// GET /api/library/trash — one read, kept in the server's order (newest trashed first).
func refreshTrash() async {
    do {
        let response = try await api.trash()
        trash = response.recordings
        trashError = nil
        print("[manage] trash: \(trash.count) recording(s), server count \(response.count), \(SizeFormat.serverStyle(trashBytes))")
    } catch {
        trashError = WriteError.text(error)
        print("[manage] trash: \(error)")
    }
}
```

`trashFetchWidth` is gone with it. **The stale comment is removed** — both copies of it: the header
line in `ManageDVRScreen.swift` and the one in `TrashManageView.swift:5-7` that said *"The library
has no trash endpoint of its own"*. Each is replaced by what is true now, with a note saying what
the old walk was and why it no longer works, so nobody reinstates it.

### `TrashItem` — its own type, not `Episode`

The listing carries **eight fields**. `Episode` has **28**, including `showId`, `file`, `thumb`,
`exists` and every server-made label. Decoding a `TrashItem` as an `Episode` was never possible, and
should not be faked: a recording in the trash may have no show in the library at all. So the pass
adds `TrashItem` and `TrashResponse` (`Models.swift`), decoded **strictly** on the item — if the
server's shape moves, the read fails loudly rather than drawing a screen of blank rows.

### What the row draws, now that the server labels nothing for it

| Line | Before (from `Episode`) | Now |
|---|---|---|
| poster | `episode.thumb`, 120×68 landscape | `GET /api/art/show?title=…`, 52×78 at the design's 2:3 — the thumbnail 404s once trashed |
| title | `episode.show` | unchanged |
| middle | `S2 E20 · Surviving the '70s` | unchanged, and **absent entirely** when season, episode and title are all empty |
| bottom | `episode.dateLabel · episode.sizeLabel` | `Aired Mon Sep 7 · 275.92 MB · Trashed today at 9:09 PM` |

Two supporting additions in `Formatting.swift`:

- **`SizeFormat.serverStyle`** reproduces the server's `humanBytes` (system.go:120-131): 1024-based,
  `%.0f` for B and KB, `%.2f` above. The existing `SizeFormat.bytes` is `ByteCountFormatter` in
  `.file` style, which is **1000-based** — the two disagree by 7% on a gigabyte, and the trash rows
  have no `sizeLabel` of their own to fall back on. Using it means the same recording reads
  **1.86 GB** on the Apple TV and in the web UI.
- **`ServerTime.date`** parses the two RFC 3339 stamps, dropping Go's nanosecond fraction first
  (§1). Because these carry the server's offset — unlike its `dateLabel` strings, which are
  container-local text — the dates are shown in **this Apple TV's own time**.

### Two more things the screen gained

- **The size is on both screens now.** The hub reads `Trash — 2 in trash · 283.58 MB`, the list's
  header `Trash · 2 recordings · 283.58 MB`. The show-by-show list had no total to show.
- **Empty is now distinguishable from failed.** `ManageModel.trashError` is set when the read throws,
  and the screen says *"The trash could not be read — …"* instead of *"The trash is empty."* The old
  code swallowed the error and claimed empty.

**Order** is the server's own — newest trashed first — where the old list sorted by show name.

---

## 3. Step 3 — Restore, proven on Home Theater

`Marlin DVR TVUITests/TrashRestoreUITests.swift` (new, 213 lines).

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
  -only-testing:"Marlin DVR TVUITests/TrashRestoreUITests"
```

**`** TEST SUCCEEDED **`, 1 test, 0 failures, 83.3 s, 21:15:23–21:16:53.**

```
[pass33 21:16:09.502] both trashed recordings are listed
[pass33 21:16:09.519] header: 2 recordings · 283.58 MB
[pass33 21:16:09.579] restoring The View; focus is The View, S29 E205 · Season 29, Episode 205,
                      Aired Mon Sep 7 · 275.92 MB · Trashed today at 9:09 PM, Restore
[pass33 21:16:10.923] restored: Restored The View · Season 29, Episode 205 to its show.
[pass33 21:16:16.305] restoring Midday Maryland; focus is Midday Maryland,
                      Aired Mon Sep 7 · 7.66 MB · Trashed today at 9:09 PM, Restore
[pass33 21:16:17.729] restored: Restored Midday Maryland to its show.
[pass33 21:16:51.912] both restored shows are on the shelves
```

| Screenshot | What it shows |
|---|---|
| `10-manage-hub.png` | the hub's Trash row: **"2 in trash · 283.58 MB"** |
| `11-trash-list.png` | both rows — The View with its poster and `S29 E205 · Season 29, Episode 205`; Midday Maryland with the placeholder and **no middle line at all** |
| `12-after-restoring-the-view.png` | The View gone, header down to **"1 recording · 7.66 MB"** |
| `13-…-midday-maryland.png` / `14-trash-empty.png` | **"Restored Midday Maryland to its show."**, header **"empty"**, and the empty-trash sentence |
| `15-hub-after-the-restores.png` | the hub agrees: **"Trash — empty"** |
| `16-…-shelves-after-the-restores.png` | **both shows back on the Recordings shelves**, The View and Midday Maryland under Recently Updated, `4 shows · 5 recordings` |

**The subjects.** The owner's four were gone by the time the device run could happen (§0), so with
his explicit authorisation the pass used **the two recordings Pass 32 left behind and disclosed in
its §C** — `b7a3822d83b4` (Midday Maryland, 7.66 MB, the throwaway its test created) and
`eccf81dbdab2` (The View, 275.92 MB, booked by its aborted run). The owner wants neither and
authorised trashing and restoring **these two ids only**. They were put into the trash from this Mac
before each run; the harness itself only reads and restores. **Both are back in the library now**,
at their original ids and original paths, `trash false`, `exists true`.

**The server agrees**, from its own log:

```
21:16:09.904 PUT /api/library/recordings/eda86144bf38 200
21:16:09  DVR Restore Trash/The View/… : moved 3 files to /mnt/unas4pro/DVR/The View
21:16:09  DVR removed empty trash folder /mnt/unas4pro/DVR/Trash/The View
21:16:16.703 PUT /api/library/recordings/3ded51f52f76 200
21:16:16  DVR Restore Trash/Midday Maryland/… : moved 3 files to /mnt/unas4pro/DVR/Midday Maryland
```

### The defect this found, and fixed

**The first device run failed after both restores succeeded**, at the step that leaves the screen:
with the trash empty, **nothing on the screen could take focus**. The rows are gone and the Empty
Trash button is `.disabled(model.trash.isEmpty)`, so the remote's Menu never reached
`.onExitCommand` — it went to the system instead and the app was left. Restoring the last recording
in the trash **trapped the user on the screen**. This existed in the Pass 10 code too; nobody had
ever emptied the trash from the Apple TV to find it.

The fix is two lines: the empty-state sentence is now `.focusable()` and holds the `"empty"` focus
id, and the Empty Trash button takes `"empty-trash"` for itself. **`empty()` is untouched** — it
still asks for `"empty"` on success, which now resolves to the sentence, so the same trap is closed
on that path without exercising or changing Empty Trash.

Two other failures on the way, both harness faults, diagnosed from their own output and fixed once
each — no blind retries:

1. `.left` from Home does nothing: **Home is the tile launcher and carries no rail** (design variant
   2a). The harness now opens Recordings first and steps into the rail from there, as
   `RailManageUITests` does.
2. XCUITest **refuses a string identifier over 128 characters**, and two of this screen's lines are
   longer. Those waits use `BEGINSWITH` predicates now.

---

## 4. Step 4 — the two forms. Only one could be tested, and here is why

**The premise did not hold.** The brief said the trash held both forms at once. It did not:

**All four of the owner's trashed recordings were the old form.** The server's Empty Trash log names
the path of every file it deleted, and all four were `/mnt/unas4pro/DVR/<Show>/<file>.mpg` — still in
their original show folders. **Not one was in `DVR/Trash/`.** There was never a new-form entry among
them to restore.

**And with them deleted, the old form cannot be produced any more.** It exists only as a leftover of
recordings trashed *before* 1.6.0 started moving files. Every trash under 1.6.0 moves the file —
measured directly, twice:

```
21:15:16 DVR Trash Midday Maryland/Midday Maryland 2026-09-07-1200.mpg:
         moved 3 files to /mnt/unas4pro/DVR/Trash/Midday Maryland
21:15:16 DVR removed empty show folder /mnt/unas4pro/DVR/Midday Maryland
```

**So: the pass tested the NEW form only — a file the server moved to `DVR/Trash/` — and it works,
end to end, twice.** The old form is untested from the Apple TV and now untestable. What can be said
about it without a device run: the endpoint listed all four old-form recordings correctly (§1), the
screen renders whatever the endpoint returns and cannot see a file path, and Restore is a `PUT` on
the id the listing supplies. The one thing genuinely unproven is whether the server's Restore handler
does the right thing for a file that never moved — **that is server behaviour, not app behaviour**,
and no client change could affect it.

**Both list rows were exercised, though**, which is the other axis that mattered: The View carries a
season, an episode and a title; Midday Maryland has none of the three and its middle line is absent
rather than reading a stray `S0 E0` (asserted).

---

## 5. Step 5 — the id, and the resume key

### **The id changes while a recording is in the trash.** It is derived from the file path.

Measured, and stated by the server itself:

```
21:15:16  DVR recording Midday Maryland/… is now Trash/Midday Maryland/…
                                          (id b7a3822d83b4 -> 3ded51f52f76, trash=true)
21:16:16  DVR recording Trash/Midday Maryland/… is now Midday Maryland/…
                                          (id 3ded51f52f76 -> b7a3822d83b4, trash=false)
```

| | in the library | in the trash |
|---|---|---|
| Midday Maryland | `b7a3822d83b4` | `3ded51f52f76` |
| The View | `eccf81dbdab2` | `eda86144bf38` |

**It round-trips exactly.** Restore moves the file back and the id returns to what it was — verified
across three separate trash/restore cycles, and the trash-time id was **identical each time**, so
the mapping is deterministic, not random.

**This is a 1.6.0 behaviour and it is new.** The owner's four old-form recordings kept their ids
while trashed — `6007a13f0b46` in the 20:49 listing is the same id Passes 31 and 32 recorded for it
in the library — because their files never moved. **Anything trashed from now on gets a different
id while it sits there.**

### The resume key survives a restore. It does not survive the trash itself.

`ResumeStore` (`ResumeStore.swift:22-33`) keys on `UserDefaults` under `"marlinResume." + recordingID`,
and `ResumeStore.clear` is called from **exactly one place in the app** — `PlayerModel.swift:449`,
at end-of-playback, beside `watched: true`. Nothing in the trash or restore path touches it.

So, precisely:

- **After a restore, the resume position is found again.** The entry was saved under the library id,
  the id comes back as that same library id, and the key matches. **Survives.**
- **While the recording is in the trash, that entry is unreachable** — the listing hands the app the
  trash-time id, which no `marlinResume.` key matches. In practice this costs nothing: a trashed
  recording cannot be played from the app, and Trash rows show no resume.
- **The key is never orphaned**, because the app can only ever write a resume entry from the Player,
  which only opens recordings that are in the library.

**Not measured directly:** no resume entry existed for either subject on Home Theater, so this is
read from the id evidence above plus the single `clear` call site, not from watching a "22 min in"
label survive a round trip. Proving it that way would mean playing a recording, trashing it and
restoring it — more writes than this pass was authorised for.

---

## What this pass left on the owner's server

**Nothing.** The trash is empty, both subjects are back in the library at their original ids, and the
library reads `4 shows · 5 recordings`, `root files 5`, matching the state before the pass began plus
the owner's own new recordings.

**Every write this pass made** — ten `PUT /api/library/recordings/{id}`, all on the two authorised
recordings (five trashing them, five restoring them; the trash-time ids are the same two files):

```
21:09:17  PUT …/b7a3822d83b4   21:09:17  PUT …/eccf81dbdab2      trash=true
21:13:28  PUT …/eda86144bf38   21:13:35  PUT …/3ded51f52f76      trash=false   (first device run)
21:15:16  PUT …/b7a3822d83b4   21:15:16  PUT …/eccf81dbdab2      trash=true
21:16:09  PUT …/eda86144bf38   21:16:16  PUT …/3ded51f52f76      trash=false   (passing run)
21:17:08  PUT …/b7a3822d83b4   21:17:08  PUT …/3ded51f52f76      trash=true then false (the trashedAt check)
```

**No POST, no DELETE, nothing on any other recording, and Empty Trash was never sent.**

### One server quirk noticed in passing

**`trashedAt` does not update when the same file is trashed again.** Midday Maryland was trashed at
21:09:17, restored, trashed again at 21:15:16 and a third time at 21:17:08 — and the listing still
reported `trashedAt: 2026-09-07T21:09:17.459497642-04:00` every time, which is why the device
screenshots read *"Trashed today at 9:09 PM"* during a 21:16 run. The app shows what the server
says. Noted for the marlin-dvr project; nothing was changed here.

---

## SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `Marlin DVR TV/Models.swift` | **modified** — `TrashItem` and `TrashResponse` added before the Cameras mark | 2 |
| `Marlin DVR TV/ChannelFilter.swift` | **modified** — `func trash()` added beside the other typed reads | 2 |
| `Marlin DVR TV/Formatting.swift` | **modified** — `SizeFormat.serverStyle`, `enum ServerTime` | 2 |
| `Marlin DVR TV/ManageDVRScreen.swift` | **modified** — header comment, `trash: [TrashItem]`, `trashError`, `trashBytes`, `refreshTrash` rewritten, `trashFetchWidth` deleted, hub row shows the size | 2 |
| `Marlin DVR TV/TrashManageView.swift` | **modified** — header comment, `TrashRow(item:)` rebuilt, subtitle, restore message, empty/error state, empty-state focus fix | 2, 3 |
| `Marlin DVR TVUITests/TrashRestoreUITests.swift` | **new** — the device harness | 3, 4 |
| `reports/2026-09-07-pass33-trash-restore.md` | **new** — this report | deliverable |
| `reports/assets/pass33/*.png` | **new** — the seven screenshots the passing run attached | 3 |
| `COLD-START.md`, `DECISIONS.md` | **modified** — the standing notebook record, including §0 | project rule |
| `build/**` | build output and result bundles; git-ignored, never committed | 3 |

**Not done, as scoped.** **Empty Trash was not exercised and `empty()` was not changed** — its only
knock-on is the focus id its success path asks for, which now resolves to the empty-state sentence
instead of a disabled button (§3); the function's own lines are untouched by diff. No change to
delete, playback, frame stepping, the guide, or Pass 32's series-pass sheet chip defect. No
server-side change was made or attempted. No new dependency. Nothing outside this folder was
written; Unraid, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched beyond the DVR's own
HTTP API. **`GET /api/settings` was not read**, per the owner's standing instruction from Pass 31.

**The reference clone was read, as this pass's brief permits, and it is stale**: it sits at
marlin-dvr **1.2.1** (`cmd/marlin-dvr/main.go:38`, last commit "Pass 26: 1.2.1 deployed") and its
`main.go:285` registers only `POST /api/library/trash/empty`. **It has no `GET /api/library/trash`.**
Pulling it is the owner's job, so **every server fact in this report was measured against the running
1.6.0 server** — its responses, and its own `/api/logs`. The only thing taken from the clone is
`humanBytes` at `system.go:120-131`, and the app's copy of it is confirmed against live
`sizeLabel` values (`8031172 → "7.66 MB"`, `289325120 → "275.92 MB"`).

**Git: committed locally, not pushed** — Passes 31, 32 and 33 go to the owner together.
