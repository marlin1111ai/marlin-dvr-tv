# Pass 94 — why the commercial-skip prompt never appears: read-only recon

**Date:** 2026-09-16
**READ-ONLY.** No Swift file, test file, project file, `Info.plist`, entitlements file or asset was
modified. **No fix of any kind was built, proposed as a diff, stubbed or disabled.** The files this
pass writes are this report, `DECISIONS.md` and `COLD-START.md`, committed together.
`~/Xcode/marlin-dvr-reference` was read with `sed`, `grep`, `ls` and `git rev-parse` only — never
edited, never fetched, never pulled, never checked out, nothing run from it. `design/` was not read.
**Every request to `http://192.168.1.250:8090/` was a GET** — no POST, PUT or DELETE, no play session
opened, and **no `GET /api/settings`**. No build, no device run, no install.

**Pass number.** The highest-numbered report in `reports/` before this pass is `pass93`, so this is
**Pass 94**.

**Redaction.** Nothing quoted below carries a token, a credential or a device id. The HDHomeRun
tuner's device id appears in the log's `GUIDE` lines; none of those lines is quoted. The client names
the server prints (`Apple TV`, `D/S Apple TV`) are the names the owner registered and are already in
the notebook.

---

## THE ANSWER, so it is not buried

**The prompt never appears because nine of the owner's eleven recordings have no commercial markers
at all, and the two that do are not the ones he has been watching.**

Server-side commercial detection has been **failing on every recording made since 2026-09-08** with
one repeated reason:

```
the app's comskip.ini is missing
(stat /Apps/dvr/marlin-dvr/data/versions/1.8.2/comskip.ini: no such file or directory)
```

Measured today from the eleven `GET /api/library/recordings/{id}/commercials` responses and the
`detect` block the library carries beside each recording:

| Answer | Recordings | Would the prompt ever arm? |
|---|---|---|
| `state: "detected"` | **2** — both recorded **2026-09-07** | yes |
| `state: "unknown"` | **9** — every recording made **2026-09-08 or later** | **no, never** |
| `state: "none"` | 0 | — |
| `state: "running"` | 0 | — |

**The app is not at fault and nothing on its path is broken.** Every file between the play request
and the prompt is byte-identical to the build the owner accepted on 2026-09-08 (§6), the decode
handles all eleven answers correctly, and the `"unknown"` branch is doing exactly what Pass 38's
decision says it must: show nothing, say nothing, never block playback. It has nothing to show
because the server has nothing to give.

**The two recordings that can arm are `5328bb632e76` (History's Greatest Mysteries S4 E14 "Who Is
D.B. Cooper?", 4 breaks) and `d9a4f5c76696` (Hitler's DNA, 8 breaks)** — the ones Passes 38 and 42
were proved on. Both are from 2026-09-07. Both still carry a saved position on Home Theater, and
from that position each needs **about six minutes of uninterrupted playback** before its next break
arrives (§3.3). Everything else he might pick — all four *The Food That Built America*, all four
*The Proof Is Out There*, and *History's Greatest Mysteries* S7 E20 — can show him nothing at all.

**The cause is server-side and is not this project's to fix.** It is raised in §8 for the marlin-dvr
project, per `CLAUDE.md`. Nothing was changed on the server and no non-GET request was sent to it.

---

## VERIFY — the evidence

### V1. The git reading, taken before any file in this repo was changed

```
$ git fetch origin
$ git rev-parse main
4396d846faca38ab8e88f4b83f4585f6efd083cf
$ git rev-parse origin/main
4396d846faca38ab8e88f4b83f4585f6efd083cf
$ git ls-remote origin main
4396d846faca38ab8e88f4b83f4585f6efd083cf	refs/heads/main
$ git rev-list --left-right --count main...origin/main
0	0
$ git status --porcelain
?? icon-source/
```

Pass 93's verified push SHA is therefore **`4396d84`**, `origin/main` is at it, nothing was waiting,
and the only untracked path is the standing `icon-source/`.

### V2. Every request this pass made, in order

All GETs, all to `http://192.168.1.250:8090`, between **09:46:09 and 09:47:32 EDT on 2026-09-16**:

| # | Request | Answer |
|---|---|---|
| 1 | `GET /api/status` | 200 |
| 2 | `GET /api/library` | 200 |
| 3–6 | `GET /api/library/shows/{id}` × 4 | 200 each |
| 7–17 | `GET /api/library/recordings/{id}/commercials` × 11 | 200 each |
| 18 | `GET /api/logs` | 200 |
| 19 | `GET /api/logs?since=0&limit=5000` | 200 |

The server's own log records requests 7–17 and confirms there were exactly eleven of them and no
others of that shape (§4.2). **Every table in this report is built from those responses**, saved in
this session's scratchpad and never committed. Nothing was inherited from an earlier pass —
the recording count was arrived at by walking the shows and counting the episodes by hand (§2.3).

---

## 1. Step 1 — the gate: can a GET on the commercials route start server-side work?

**It cannot. The gate passes, and the calls in §2 were made only after this was established.**

Read in the reference clone at `eb0c098` (`HEAD` and `origin/main` both, unchanged since Pass 72;
the clone was not fetched):

- `HLS-CLIENT-API.md:341-509` — contract §10 in full.
- `cmd/marlin-dvr/commercials.go:109-163` — `handleCommercials`.
- `cmd/marlin-dvr/commercials.go:167-186` — `answerFromEDL`.
- `cmd/marlin-dvr/commercials.go:220-250` — `recordingSourceOf`.

The handler does four things and nothing else: a library lookup (`a.lib.find`), a read of the
already-stored `st.Detect` record, in the no-record case a single `parseEDL` of one file beside the
recording, and an exact-match scan of a slice the server already holds in memory. The source says so
in its own words at `commercials.go:167-169`:

> `answerFromEDL` is owner decision 2a. It reads one file beside the recording and nothing else: no
> state is written, no id is computed, no flag is changed, and a missing file is not an error.

and at `commercials.go:231-232`:

> Both steps are exact-match reads over a slice the server already holds in memory. Nothing is
> written, no id is recomputed and no state is repaired.

Contract §10 agrees from the other side: detection is queued by the **recorder** when a recording
reaches COMPLETED or STOPPED (`recorder.go:489-490`, `comskip.go:124`), never by this route, and
§10.3 states plainly that "nothing re-runs detection, and an interrupted run is not retried at the
next start". There is no write path, no queue insertion and no repair in the handler.

**One caveat, recorded rather than resolved.** The clone is 1.8.1 source (`main.go:38` reads
`appVersion = "1.8.1"`) and the running server answers **1.8.2** (§2.1). What 1.8.2 changed is not
known to this project (DECISIONS.md, 2026-09-13 (Pass 85)). The gate was therefore checked against
the contract and against the nearest source this project may read, which is what was available; it
is not a reading of the exact binary that answered. Every measurement below is taken from the
running server's own responses, not from the checkout.

---

## 2. Step 2 — the walk, and the table

### 2.1 `GET /api/status`

```json
{"name":"marlin-dvr","version":"1.8.2","uptime_seconds":193449,"port":8089}
```

**Version 1.8.2**, matching Pass 85's reading and not the 1.8.1 the clone holds. `uptime_seconds`
193449 is 53 h 44 m, putting this process's start at about **04:02 EDT on 2026-09-14**.

### 2.2 `GET /api/library`

```
"configured": true, "recordings": 11, "shows": 4,
"scannedAt": "2026-09-16T09:43:10.817410615-04:00", "scanning": false
"roots": [{"path":"/mnt/unas4pro/DVR","exists":true,"readable":true,"files":13}]
```

Three sections — `recently-watched` (1 item), `recently-updated` (4) and `recently-added` (4) —
holding **four distinct shows** between them: `history-s-greatest-mysteries`, `the-proof-is-out-there`,
`the-food-that-built-america`, `hitler-s-dna`.

### 2.3 The walk, and the count made by hand

`GET /api/library/shows/{id}` for each of the four, then the episodes counted from the four
responses:

| Show | `count` the show reports | episodes in `episodes[]` |
|---|---|---|
| The Proof Is Out There | 4 | 4 |
| The Food That Built America | 4 | 4 |
| History's Greatest Mysteries | 2 | 2 |
| Hitler's DNA | 1 | 1 |
| **Counted by hand** | | **11** |

Eleven, which also matches `GET /api/library`'s own `recordings: 11` — but the count above was made
by counting the four `episodes[]` arrays, not by reading that field. It is **not** the twelve Pass 91
recorded nine days ago: the server's log shows one recording trashed at 01:51:36 this morning
(§4.3), and since 1.8.1 the `recordings` field excludes trashed recordings.

### 2.4 The table — every recording, from `GET /api/library/recordings/{id}/commercials`

All eleven answered **HTTP 200**. `source` is `{"id":"philo","name":"Philo","type":"m3u"}` on every
single one — **there is no `hdhomerun` recording in the library at all**, so §10.6's antenna rule
plays no part in what follows.

| # | id | Show | Episode | Channel | Source | `state` | `from` | Breaks | `edl` |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `5328bb632e76` | History's Greatest Mysteries | S4 E14 · Who Is D.B. Cooper? | 9001 HISTORY | m3u / philo | **`detected`** | `state` | **4** | present |
| 2 | `d9a4f5c76696` | Hitler's DNA | (no season/episode, no episode title) | 9001 HISTORY | m3u / philo | **`detected`** | `state` | **8** | present |
| 3 | `cac7c08639ec` | History's Greatest Mysteries | S7 E20 · The Hunt for Osama bin Laden: Case Closed | 9001 HISTORY | m3u / philo | `unknown` | `state` | 0 | absent |
| 4 | `dd5f3e4a6778` | The Proof Is Out There | S6 E16 · Hellfire Vs. UFO, Amityville Ghost, And Mall World | 9001 HISTORY | m3u / philo | `unknown` | `state` | 0 | absent |
| 5 | `ef4d2419605d` | The Proof Is Out There | S6 E17 · First UFO Film, Alien Mummy, And Miracle Plane Crash Survivor | 9001 HISTORY | m3u / philo | `unknown` | `state` | 0 | absent |
| 6 | `6cfd12efd1e7` | The Proof Is Out There | S6 E18 · Falling UFO, Monster Of The North Sea, Interdimensional Portals | 9001 HISTORY | m3u / philo | `unknown` | `state` | 0 | absent |
| 7 | `921f44aeab9b` | The Proof Is Out There | S6 E19 · Mystery Orbs, Alien Autopsy, And Secret Underground City | 9001 HISTORY | m3u / philo | `unknown` | `state` | 0 | absent |
| 8 | `84a96ec4d479` | The Food That Built America | S3 E9 · Beyond the Burger | 9002 FYI | m3u / philo | `unknown` | `state` | 0 | absent |
| 9 | `72041bb7016c` | The Food That Built America | S3 E10 · Chain Reaction | 9002 FYI | m3u / philo | `unknown` | `state` | 0 | absent |
| 10 | `c3303f49688a` | The Food That Built America | S3 E11 · Let Them Eat Snack Cakes | 9002 FYI | m3u / philo | `unknown` | `state` | 0 | absent |
| 11 | `d4ab55bd7f01` | The Food That Built America | S4 E1 · Breakfast That Pops | 9002 FYI | m3u / philo | `unknown` | `state` | 0 | absent |

`from` is `"state"` on all eleven — every one has a stored detection record, so §10.5's `.edl`
fallback was never reached and no recording is in the "markers file but no record" case.

### 2.5 The raw JSON — one per distinct state seen

Only two of §10.3's four states occur in this library. Both are quoted whole, exactly as they came
back.

**`state: "detected"` — `5328bb632e76`:**

```json
{
  "id": "5328bb632e76",
  "state": "detected",
  "ranges": [
    {"startSeconds": 176.54, "endSeconds": 206.54},
    {"startSeconds": 305.57, "endSeconds": 371.54},
    {"startSeconds": 730.56, "endSeconds": 925.46},
    {"startSeconds": 1271.2, "endSeconds": 1478.54}
  ],
  "count": 4,
  "from": "state",
  "source": {"id": "philo", "name": "Philo", "type": "m3u"},
  "edl": "History's Greatest Mysteries S04E14 Who Is D.B. Cooper 2026-09-07-1100.edl",
  "detail": "4 commercial segments from History's Greatest Mysteries S04E14 Who Is D.B. Cooper 2026-09-07-1100.edl."
}
```

**`state: "unknown"` — `921f44aeab9b`, the most recent recording in the library:**

```json
{
  "id": "921f44aeab9b",
  "state": "unknown",
  "ranges": [],
  "count": 0,
  "from": "state",
  "source": {"id": "philo", "name": "Philo", "type": "m3u"},
  "detail": "Detection failed — the app's comskip.ini is missing (stat /Apps/dvr/marlin-dvr/data/versions/1.8.2/comskip.ini: no such file or directory)"
}
```

Note `edl` is **absent**, not null — the case `CommercialSegments.swift:16-20` makes the field
optional for.

**The second `detected` answer, `d9a4f5c76696`**, since its ranges are used in §3.3:

```json
{
  "id": "d9a4f5c76696",
  "state": "detected",
  "ranges": [
    {"startSeconds": 1091.29, "endSeconds": 1349.21},
    {"startSeconds": 1930.09, "endSeconds": 2190.09},
    {"startSeconds": 2633.3,  "endSeconds": 2921.22},
    {"startSeconds": 3396.29, "endSeconds": 3669.2},
    {"startSeconds": 4221.35, "endSeconds": 4494.22},
    {"startSeconds": 4822.35, "endSeconds": 5053.38},
    {"startSeconds": 5412.11, "endSeconds": 5672.23},
    {"startSeconds": 6136.83, "endSeconds": 6138.03}
  ],
  "count": 8,
  "from": "state",
  "source": {"id": "philo", "name": "Philo", "type": "m3u"},
  "edl": "Hitler's DNA 2026-09-07-2100.edl",
  "detail": "8 commercial segments from Hitler's DNA 2026-09-07-2100.edl."
}
```

**And the one `unknown` that is not a failure** — `cac7c08639ec`, whose detection was interrupted
rather than failed. Same state to the app, different history, and it is the hinge of §8:

```json
{
  "id": "cac7c08639ec",
  "state": "unknown",
  "ranges": [],
  "count": 0,
  "from": "state",
  "source": {"id": "philo", "name": "Philo", "type": "m3u"},
  "detail": "Detection did not run — server stopped during detection (not re-run automatically)"
}
```

### 2.6 The `detect` record behind each answer, in time order

`GET /api/library/shows/{id}` carries the library's own stored `detect` block per episode. It is the
same record `handleCommercials` reads, and it says **when** each answer was decided:

| `queuedAt` | id | Recording | `status` | exit | segs | `reason` |
|---|---|---|---|---|---|---|
| 2026-09-07 12:03:00 | `5328bb632e76` | HGM S4 E14 | **`detected`** | 0 | **4** | — |
| 2026-09-07 22:37:00 | `d9a4f5c76696` | Hitler's DNA | **`detected`** | 0 | **8** | — |
| 2026-09-08 00:06:08 | `cac7c08639ec` | HGM S7 E20 | `interrupted` | −1 | 0 | server stopped during detection (not re-run automatically) |
| 2026-09-08 22:06:00 | `dd5f3e4a6778` | Proof S6 E16 | `failed` | 0 | 0 | the app's comskip.ini is missing (… **`versions/1.8.0/`** …) |
| 2026-09-08 23:08:00 | `ef4d2419605d` | Proof S6 E17 | `failed` | 0 | 0 | … **`versions/1.8.0/`** … |
| 2026-09-14 10:03:00 | `84a96ec4d479` | Food S3 E9 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |
| 2026-09-14 11:03:00 | `72041bb7016c` | Food S3 E10 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |
| 2026-09-14 12:03:00 | `c3303f49688a` | Food S3 E11 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |
| 2026-09-14 13:03:00 | `d4ab55bd7f01` | Food S4 E1 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |
| 2026-09-15 22:06:00 | `6cfd12efd1e7` | Proof S6 E18 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |
| 2026-09-15 23:08:00 | `921f44aeab9b` | Proof S6 E19 | `failed` | 0 | 0 | … **`versions/1.8.2/`** … |

**The last recording this server successfully detected commercials in finished detecting at
22:42:21 on 2026-09-07.** Every recording since has come back empty, and the line falls exactly at
the owner's first in-place version update — the one contract §10's own header dates at **00:06 on
2026-09-08**, which is the minute `cac7c08639ec`'s run was interrupted.

---

## 3. Step 3 — which rows would arm the prompt under the Pass 38 rules

### 3.1 The rule, as Pass 38 settled it

DECISIONS.md, 2026-09-08 (Pass 38): "**Only `state: "detected"` arms the feature**", a `"none"` from
`m3u` is a real answer that shows nothing, a `"none"` from `hdhomerun` is treated like `"unknown"`,
and "everything else — `unknown`, `running`, an unrecognised value, a transport failure, any non-200
— shows nothing at all, with no user-visible message." In code that is `CommercialsResponse.plan`,
`CommercialSegments.swift:125-134`, and it is the only place the decision is made.

### 3.2 Applied to the eleven

| Rows | `state` | Plan (`CommercialSegments.swift:125-134`) | On screen |
|---|---|---|---|
| **2** — `5328bb632e76`, `d9a4f5c76696` | `detected` | `.arm(ranges)` | the prompt, at each break |
| **9** — every other row | `unknown` | `.dontKnow` | **nothing, ever** |
| 0 | `none` | `.playThrough` | — |
| 0 | `running` | `.dontKnow` | — |

**Two of eleven rows can arm the prompt. Nine cannot, and never will** — nothing re-runs detection
(§10.3), so those nine answers are final unless something changes on the server.

Each of the nine prints exactly one line to the console and does nothing else
(`PlayerModel.swift:465`):

```
[commercials] 921f44aeab9b → "unknown" from source type "m3u": no prompt for this playback
```

### 3.3 The two that can arm — and why even they may not have shown him anything

Pass 92 read Home Theater's `ResumeStore` off the device this morning and published the numbers
(`reports/2026-09-16-pass92-progress-bar.md` §5.4). Against the ranges above:

| Recording | Saved position on Home Theater | Where that falls | Next break starts | Wait before the first prompt |
|---|---|---|---|---|
| `5328bb632e76` HGM S4 E14 | **931.00 s** of 2570.57 s | 5.5 s past the end of break 3 (730.56–925.46) | **1271.20 s** | **340 s — 5 min 40 s** |
| `d9a4f5c76696` Hitler's DNA | **739.02 s** of 6138.13 s | before break 1 | **1091.29 s** | **352 s — 5 min 52 s** |

Show detail resumes from the saved position (`ShowDetailScreen.swift:236`,
`ResumeStore.entry(for:)?.position ?? 0`), so on Home Theater **both of the two recordings that can
arm the prompt need about six minutes of uninterrupted playback from where he left off before the
first break arrives**. Starting either from the beginning instead would reach `5328bb632e76`'s first
break at 176.54 s — just under three minutes.

This is context, not the finding. The finding is the nine rows that can never arm at all.

---

## 4. Step 4 — `GET /api/logs`

### 4.1 What the log can and cannot say

The server's log is an in-memory ring. `GET /api/logs` answers 2000 lines by default and
`?since=0&limit=5000` drained the whole of it — `total: 5000`, 5000 lines, running from
**23:15:09 on 2026-09-15 to 09:47:32 on 2026-09-16**.

**There is not one comskip or detection line anywhere in that window**, and the reason is arithmetic,
not absence of evidence: the most recent detection attempt in the whole library is
`921f44aeab9b`'s at **23:08:00 on 2026-09-15** (§2.6), which is **about seven minutes older than the
oldest line the ring still holds**. The failures are therefore recorded where §2.6 read them — in
the library's own stored `detect` records, which is the durable copy — and not in the log this pass
could reach. `GET /api/logs/download` would hold more; it was not called, because step 4 names
`GET /api/logs` and this pass builds nothing beyond its steps.

Tags present in the 5000 lines: `GUIDE` 3146, `HTTP` 1157, `CAM` 524, `IDX` 118, `TRS` 38, `ART` 8,
`BAK` 5, `DVR` 2, `UPD` 1, `SRC` 1. No `COMSKIP`, no detection tag of any kind.

### 4.2 What it does say — this pass's own eleven requests

```
11334 09:46:53.538 INFO HTTP GET /api/library/recordings/cac7c08639ec/commercials 200
11335 09:46:54.665 INFO HTTP GET /api/library/recordings/5328bb632e76/commercials 200
11336 09:46:54.693 INFO HTTP GET /api/library/recordings/d9a4f5c76696/commercials 200
11337 09:46:54.704 INFO HTTP GET /api/library/recordings/d4ab55bd7f01/commercials 200
11338 09:46:54.715 INFO HTTP GET /api/library/recordings/c3303f49688a/commercials 200
11339 09:46:54.724 INFO HTTP GET /api/library/recordings/72041bb7016c/commercials 200
11340 09:46:54.735 INFO HTTP GET /api/library/recordings/84a96ec4d479/commercials 200
11341 09:46:54.744 INFO HTTP GET /api/library/recordings/921f44aeab9b/commercials 200
11342 09:46:54.753 INFO HTTP GET /api/library/recordings/6cfd12efd1e7/commercials 200
11343 09:46:54.762 INFO HTTP GET /api/library/recordings/ef4d2419605d/commercials 200
11344 09:46:54.771 INFO HTTP GET /api/library/recordings/dd5f3e4a6778/commercials 200
```

Eleven, all 200, and — as §1 predicted — **not one line of detection work follows any of them**. The
route did no work beyond answering.

### 4.3 And what it says about which recordings are actually being played

Every recording playback in the window, from the `TRS` session lines:

```
6737 00:14:56.794 TRS session smu3l7e1jaf7ef7 created: The Proof Is Out There (recording, copy) for D/S Apple TV
6953 00:29:08.321 TRS session smu3lpo4e670727 created: The Proof Is Out There (recording, copy) for D/S Apple TV
6976 00:29:18.271 TRS session smu3lpvsr23f907 created: The Proof Is Out There (recording, copy) for D/S Apple TV
6998 00:29:35.796 TRS session smu3lq9blb5a0af created: The Proof Is Out There (recording, copy) for D/S Apple TV
7019 00:30:00.974 TRS session smu3lqsqz03757a created: The Proof Is Out There (recording, copy) for D/S Apple TV
7901 01:38:03.682 TRS session smu3o6azj4547c7 created: The Food That Built America (recording, copy) for Apple TV
7961 01:39:21.282 TRS session smu3o7yv3b9ecfb created: The Food That Built America (recording, copy) for Apple TV
```

**Seven recording playbacks, on two shows, and every recording of both shows answers `unknown`.**
Neither of the two recordings that carry markers was played at all in the window. That is the
owner's experience written out in the server's own log: the prompt cannot appear for anything he
has been watching.

Two other lines from the window, for the record:

```
8456 01:51:36.255 INFO DVR Trash The Food That Built America/The Food That Built America S03E08 Pop Stars 2026-09-14-0800.mpg: moved 1 file to /mnt/unas4pro/DVR/Trash/…
9265 04:04:27.383 INFO UPD update check (scheduled): up to date (1.8.2)
```

The first is why the library holds eleven recordings this morning and twelve on 2026-09-16 when Pass
91 counted. The second confirms the running version independently of `/api/status`.

---

## 5. Step 5 — the app's path, from playback start to the prompt on screen

Every line below was read in the working tree at `4396d84`. Nothing on this path has a pending edit;
`git status --porcelain` shows only `?? icon-source/`.

**1. The request is built.** `ShowDetailScreen.swift:148-149` — `play(_:from:)` makes
`.recording(episode:show:start:)`, and `:236` passes `ResumeStore.entry(for: episode.id)?.position ?? 0`
as the start. The only other construction sites are `PlayRequest.swift:115` and `:121`
(`replacing(episode:start:)` and `withStart(_:)`), which rebuild the same case. **A recording
PlayRequest therefore always carries a real `Episode`** — there is no path that plays a recording
without one.

**2. The session is created and the item attached.** `PlayerModel.start()` at `:113`; the POST at
`PlaybackSession.swift:70` with `format: "file"` chosen at `PlayRequest.swift:49`; `startOffset =
created.start` and `duration = created.duration` at `PlayerModel.swift:120-121`; the file route's
`Range: bytes=0-0` probe at `:143-151`; then `attach(url)` at `:152`.

**3. The fetch.** `attach()` ends with `loadCommercialsOnce()` — **`PlayerModel.swift:200`**, the
last line of the function. `loadCommercialsOnce` at **`:430-434`** guards on
`isRecording, !commercialsRequested, let recordingID = request.episode?.id`. All three hold for
every recording playback: `isRecording` is `if case .recording = request` (`:98`),
`commercialsRequested` is false on a fresh `PlayerModel`, and `request.episode` is non-nil per step 1.
**`restart(at:)` reaches the same `attach()`** through `startAgain` at `:779`, and the
`commercialsRequested` latch means the answer is fetched once per `PlayerModel` and re-used — which
is correct, because §10.4's ranges are absolute recording seconds.

**4. The wire and the decode.** `APIClient.commercials(recordingID:)` —
`CommercialSegments.swift:152-154` — `GET /api/library/recordings/{id}/commercials` through
`APIClient.get` at `ServerAPI.swift:71-75`. Decoded into `CommercialsResponse`
(`CommercialSegments.swift:99-135`), with `state` a `String` and `edl` optional, per §10.3 and
§10.5. **All eleven of today's responses decode**: every required field is present in all eleven, and
the nine that omit `edl` omit exactly the one field that is optional.

**5. The state mapping.** `CommercialsResponse.state` at `:122` → `CommercialState.init(_:)` at
`:69-77`, unrecognised values falling to `.unknown`. Then `CommercialsResponse.plan` at `:125-134`,
the single place Pass 38's rule lives.

**6. The arming.** `PlayerModel.loadCommercials(recordingID:)` at `:442-467`, **`@MainActor`
deliberately** — the comment at `:436-441` records the measured failure that made it so. On `.arm`
it stores `commercialRanges = ranges` (`:457`) and prints the detected line (`:459`); on
`.playThrough` (`:463`) and `.dontKnow` (`:465`) it prints one line and stores nothing. A thrown
request prints at `:451` and returns. **Nothing in any branch blocks, delays or alters playback.**

**7. The time check against playback.** `tick()` at `:252-268`, driven by the 1-second periodic
observer added at `:219-222`. For a recording it sets `position = startOffset + t` (`:257`) — §10.4's
`edlTime = playerPosition + start`, already computed — and calls `noticeCommercialBreak()` (`:258`).
That function, at **`:476-486`**, requires `commercialPrompt == nil`, `!isPaused` and
`!commercialRanges.isEmpty`, then looks for a range with
`position >= $0.startSeconds && position < $0.endSeconds` that is not already in `promptedRanges`.
**On an `unknown` answer `commercialRanges` is empty and this returns at its first guard, every
second, for the whole playback.** On a hit it sets `commercialPrompt` and arms the 5-second timeout
(`:492-500`).

**8. On screen, and the press.** `PlayerScreen.swift:45` draws `CommercialSkipPrompt()` while
`model.commercialPrompt != nil`, and `:38` passes that same non-nil test into `PlayerHost`'s
`ownsSelect`. `PlayerHost.swift:233-235` offers a Select press to `onSelectSkip`, which is
`model.skipCommercialBreak()` (`PlayerScreen.swift:40`), landing at
`PlayerModel.skipCommercialBreak()` `:521-542`.

### 5.1 Could the file route (Pass 42), or anything since, stop it firing?

**No — and the file route is the one part of this that has been proved live.**

- **The arithmetic was measured on the device, on the file route, in Pass 42.** A commercial skip
  landed at item time `t=272.538500` with the app reporting `position 1478.54 s` — which is
  `startOffset + t` and is **exactly `endSeconds` of break 4 of `5328bb632e76`**, the range quoted in
  §2.5. That is recorded in DECISIONS.md, 2026-09-08 (Pass 42), as the correction to Pass 41 §4.3:
  the server applies `-ss` to trim *and* echoes the same `start` back, so `startOffset` compensates
  exactly. **The prompt has been seen working on this route.**
- **`loadCommercialsOnce()` is inside `attach()`**, which both `start()` and `startAgain()` reach
  only after the route check and the probe succeed. A refused route fails the playback outright
  (`PlayerModel.swift:135-139`), so there is no state in which the player is showing a recording and
  the commercials call was skipped.
- **The file route's long first fetch delays `attach()`, not the order of things.** The fetch is
  fired from `attach()` and the ranges are stored on the main actor while `tick()` runs at 1 Hz; a
  late answer costs at most the first second or two of a break, and `noticeCommercialBreak` keeps
  testing every tick while `position < endSeconds`.
- **Nothing since Pass 42 touched the path** — §6.

The two things that *do* stop it firing are both outside the app: nine recordings with no markers
(§2.4), and, for the two that have them, a resume point that sits about six minutes short of the
next break (§3.3).

---

## 6. Step 6 — `git log` from Pass 42's commit to HEAD over every file on that path

Pass 42's commit is **`137f1de`** ("Pass 42: recordings play as one seekable MP4 (steps 1-6; step 7
blocked)"), found by `git log --diff-filter=A -- reports/2026-09-08-pass42-single-file-route.md`.

`git log --oneline 137f1de..HEAD -- <file>` for each file on §5's path:

| File on the path | Commits since `137f1de` |
|---|---|
| `Marlin DVR TV/CommercialSegments.swift` | **0** |
| `Marlin DVR TV/PlayerModel.swift` | **0** |
| `Marlin DVR TV/PlayerScreen.swift` | **0** |
| `Marlin DVR TV/PlayerHost.swift` | **0** |
| `Marlin DVR TV/PlayRequest.swift` | **0** |
| `Marlin DVR TV/PlaybackSession.swift` | **0** |
| `Marlin DVR TV/ServerAPI.swift` | **0** |
| `Marlin DVR TV/ShowDetailScreen.swift` | **0** |
| `Marlin DVR TV/ResumeStore.swift` | 1 — `c633c9f` (Pass 91) |
| `Marlin DVR TV/Models.swift` | 3 — `1107b12` (Pass 63), `9f5505e` (Pass 72), `ad7f5f5` (Pass 82) |
| `Marlin DVR TV/RecordingsScreen.swift` | 3 — `d285d5b` (Pass 47), `c633c9f` (Pass 91), `ab2570a` (Pass 92) |

**Eight of the eleven files are byte-identical to the build the owner accepted on 2026-09-08.** The
three that changed did not change anything on this path:

- **`Models.swift`: `git diff --stat 137f1de..HEAD` is `125 +++, 0 ---`** — pure addition. The three
  commits add `ChannelCollection`, `CollectionsResponse`, `FindRow`, `FindResponse` and On Later's
  types. **`Episode` is untouched**, and nothing was removed or altered.
- **`ResumeStore.swift`: `47 insertions(+), 1 deletion(-)`** (Pass 91). The single deleted line is
  `entry.position > 5` inside `latest(among:)`, replaced by a call to the new
  `isResumable(_:)`, which is `entry.position > 5`. The same test, given a name. Everything else is
  new: `saved()`, `isResumable`, `isFinished`.
- **`RecordingsScreen.swift`** is a screen, not a player file. It is on the path only as an entry
  point — the Continue watching card leads to show detail, which builds the request at
  `ShowDetailScreen.swift:148-149` as it always did.

**No commit since Pass 42 has touched the commercial-skip path.** The prompt's code is the code the
owner watched work.

---

## 7. What this pass did not do

No fix. No diff, no stub, no disabled branch, no proposal written as code. The cause is on the
server and §8 raises it; anything the app might do about it is an owner's decision and is listed as
an open question in §9, not built.

---

## 8. Raised for the marlin-dvr project — recorded here, not acted on

**Commercial detection has been dead on the owner's server since the in-place version update of
2026-09-08, and it will stay dead for every future recording.** Eight of eleven recordings carry the
same `detect.reason`:

```
the app's comskip.ini is missing
(stat /Apps/dvr/marlin-dvr/data/versions/1.8.0/comskip.ini: no such file or directory)   ← 2026-09-08
(stat /Apps/dvr/marlin-dvr/data/versions/1.8.2/comskip.ini: no such file or directory)   ← 2026-09-14, 2026-09-15
```

Read out of the reference clone at `eb0c098` (1.8.1 source — see §1's caveat), the two halves fit:

- **`comskip.go:225`** resolves the ini with `filepath.Abs(comskipIniFile)` where `comskipIniFile` is
  the bare string `"comskip.ini"` (`:38`). `filepath.Abs` resolves against the **process's working
  directory**. `:230` is the exact sentence the owner's recordings carry.
- **`Dockerfile:44-47`** sets `WORKDIR /Apps/dvr/marlin-dvr` and copies `comskip.ini` beside the
  binary there, which is why this worked before.
- **`launch.sh:47-51`** — the Pass 57 launcher — reads `data/versions/current`, and when it names a
  usable downloaded version it does `cd "$DATA/versions/$V"` and `exec ./marlin-dvr`. It checks that
  the version folder holds `marlin-dvr` and `web`. **It does not check for, and the version bundle
  evidently does not carry, `comskip.ini`** — so from the first in-place update onward the working
  directory is `…/data/versions/<V>/`, `filepath.Abs("comskip.ini")` points into a folder that has no
  such file, and **every detection fails before comskip is ever invoked** (the check sits above the
  exec; `exitCode` is 0 and `segments` is 0 on all eight).

The dates corroborate it exactly: the last successful detection ended **22:42:21 on 2026-09-07**; the
next recording's run was **interrupted at 00:06:08 on 2026-09-08**, the minute contract §10's own
header dates the owner's in-place update to; and every run since has failed, naming first
`versions/1.8.0/` and then `versions/1.8.2/`.

**Consequences for them to weigh, stated and not acted on:** the fault is silent — nothing in the
admin UI or the log says commercial detection has stopped, and the only place it surfaces is a
per-recording `detect.reason`; it is not self-healing, since §10.3 says nothing re-runs detection, so
**every recording made between 2026-09-08 and whenever this is fixed is permanently without markers**
even afterwards; and the same relative-path shape would hit any other file the app resolves against
its working directory.

**Nothing was changed on the server, nothing was asked of them, and no request was sent.** Per
`CLAUDE.md` this is a decision for the marlin-dvr project and it is the owner's to carry across.

---

## 9. Open questions

1. **Does the owner want this raised with marlin-dvr, and in what form?** §8 is written to be read by
   them but has not been sent, shaped into a note, or copied anywhere. Nothing was asked of them —
   and the standing entries in COLD-START's "Raised for the marlin-dvr project" show this project
   does not raise things unprompted.
2. **Should the app say anything when a recording answers `unknown`?** Today it says nothing, by
   Pass 38's explicit decision ("no user-visible message"). The owner has now spent eight days
   assuming a feature was broken when the app was silently correct. Whether silence is still the
   right answer — and, if not, what a one-line notice would say and where it would sit — is his call
   and no part of it was built.
3. **Should the app distinguish "this recording has no markers" from "this recording has none"?**
   The plan type already keeps `playThrough` and `dontKnow` apart for exactly this reason
   (`CommercialSegments.swift:82-84`) and nothing on screen uses the distinction.
4. **Nothing in the app re-asks.** One fetch per playback, no poll, per §10.3. If detection is ever
   fixed server-side, a recording already played once in a session will still hold the old answer
   until the Player is re-entered. This is Pass 38's decision and is not a defect; it is listed so
   nobody re-derives it.
5. **The two `detected` recordings are the only live test subjects left**, and both need about six
   minutes of playback from their saved position to reach a break (§3.3). Any future device proof of
   the prompt should either start one of them from 0 or clear its saved position first — and
   `5328bb632e76` is the one Pass 42's runs already left deep inside, with `CommercialSkipUITests`
   failing until it is cleared (COLD-START, "Standing state of the devices").
6. **`GET /api/logs/download` was not called.** It holds more than the 5000-line ring and would carry
   the 2026-09-14 and 2026-09-15 detection failures as they were logged. Step 4 named `GET /api/logs`
   and this pass did not go past it.

---

## 10. The three things I am least sure of

1. **That the `comskip.ini` diagnosis in §8 is the whole mechanism.** The *fact* is certain — eight
   recordings carry that exact reason string, and the reason string comes from `comskip.go:230`. The
   *explanation* — launcher `cd`, relative `filepath.Abs`, version bundle without the ini — is read
   out of 1.8.1 source while the server runs **1.8.2**, whose changes are unknown to this project.
   The shape is consistent with the failing paths naming `versions/1.8.0/` and then `versions/1.8.2/`,
   but I did not look inside the container and could not: it is on the do-not-touch list.
2. **That six minutes is really what stands between the owner and a prompt on the two detected
   recordings.** Those positions were read off Home Theater by Pass 92 at about 01:00 this morning,
   not by this pass — no device run was permitted — and the **bedroom Apple TV has its own store,
   which nobody has read**. If he has watched either recording since, or tried it on the bedroom
   television, the numbers in §3.3 are stale. The nine-of-eleven finding does not depend on them.
3. **That nothing else on the path could also be wrong.** The path is traced and its git history is
   clean (§6), and Pass 42 measured a skip landing on an exact `endSeconds` on this very route — but
   **no device run was made in this pass**, so nothing here is a live proof that the prompt still
   draws today. Three of Pass 38's branches have never been exercised live at all (COLD-START, KNOWN
   AND UNFIXED), and "a playback that starts inside a break offers it" is still unproved. If the
   owner clears a position and plays `5328bb632e76` from 0, the answer arrives at 176.54 s.

---

## 11. SCOPE CHECK — every path touched, mapped to its step

| Path | Read / written | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md`, `reports/` (Passes 37, 38, 42) | read | the brief's "read first" |
| `~/Xcode/marlin-dvr-reference/HLS-CLIENT-API.md` (§10), `cmd/marlin-dvr/commercials.go`, `comskip.go`, `launch.sh`, `Dockerfile` | read only — no fetch, pull or checkout | 1, 8 |
| `http://192.168.1.250:8090/api/status`, `/api/library`, `/api/library/shows/{id}` × 4, `/api/library/recordings/{id}/commercials` × 11 | GET only | 2 |
| `http://192.168.1.250:8090/api/logs` | GET only | 4 |
| `Marlin DVR TV/{CommercialSegments,PlayerModel,PlayerScreen,PlayerHost,PlayRequest,PlaybackSession,ServerAPI,ShowDetailScreen,ResumeStore,Models,RecordingsScreen}.swift` | **read only** | 5, 6 |
| `git log`, `git diff`, `git rev-parse`, `git ls-remote`, `git fetch` in this repo | read only | 6, 8 |
| `reports/2026-09-16-pass94-commercial-skip-recon.md` | **written** | 8 |
| `DECISIONS.md` | **appended** | 7 |
| `COLD-START.md` | **"Next step" updated** | 8 |
| session scratchpad (the 17 saved responses) | written, **not committed** | 2, 4 |

**Not touched:** every app-target and test-target source file, `Marlin DVR TV.xcodeproj`, `design/`,
the other folders under `~/Xcode`, the Marlin DVR server beyond GETs, the Unraid host, marlinpc, the
HDHomeRun, the UNAS4Pro share. No build, no install, no device run, no server write, no
`GET /api/settings`.

---

## 12. Git

Before anything in this repo changed: `main`, `origin/main` and `git ls-remote origin main` all read
**`4396d846faca38ab8e88f4b83f4585f6efd083cf`** (Pass 93), `main...origin/main` counted `0 0`, and
`git status --porcelain` showed only `?? icon-source/` (§V1).

This pass's commit carries this report, the `DECISIONS.md` entry and the `COLD-START.md` "Next step"
paragraph, and is pushed as a fast-forward from `4396d84`. **This pass's own SHA is not written here
and cannot be** — a commit cannot contain its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in
the Pass 94 response and belongs in the next pass's notebook entry.
