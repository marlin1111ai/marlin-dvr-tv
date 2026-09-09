# Pass 41 — single-file playback route recon

**Date:** 2026-09-08
**Read-only on all code. Exactly one file is written this pass: this report.**
**No request of any kind was made to `192.168.1.250:8090`.** No Swift source, project setting,
build script, config or dependency was changed. `design/` was not touched. Nothing was built,
prototyped or stubbed. In the reference clone the only command run was `git fetch origin`; there
was no checkout, edit, commit or push there.

---

## 0. Required reading — what was present

| File named in the brief | Present? | Read |
|---|---|---|
| `COLD-START.md` | yes, 657 lines | in full, including **KNOWN AND UNFIXED after Pass 38** |
| `DECISIONS.md` | yes, 505 lines | in full |
| `HLS-CLIENT-API.md` **in this repo** | **NO — this repo has no such file** | read instead from the reference clone at `origin/main` (§2) |
| `reports/2026-09-08-pass39-three-defects-recon.md` | yes, 678 lines | in full |

The two `.md` files at this repo's root are `COLD-START.md` and `DECISIONS.md` — there is no
`HLS-CLIENT-API.md` here and never has been. The contract lives only in the marlin-dvr repo and is
read out of the clone, which is how Pass 39 read it too (its §0 recreated a Desktop copy from the
same `git show`).

---

## 1. Git state, read-only — four raw outputs

Each was run as its own command, in `~/Xcode/Marlin DVR TV`. Nothing was changed or committed at
this step.

```
$ git rev-parse HEAD
424c584a04f81a8bbade8c46422f1b4015992938
```

```
$ git rev-parse origin/main
424c584a04f81a8bbade8c46422f1b4015992938
```

```
$ git ls-remote origin main
424c584a04f81a8bbade8c46422f1b4015992938	refs/heads/main
```

```
$ git status --porcelain
?? reports/2026-09-08-pass39-three-defects-recon.md
?? reports/2026-09-08-pass40-session-start-values.md
```

All three refs agree: local `HEAD`, `origin/main` and the remote are the same commit. Nothing is
unpushed.

**`reports/2026-09-08-pass40-session-start-values.md` — status only, as instructed.** It is
**untracked** (`??`). It was not opened, staged, committed, amended or touched in any way by this
pass.

**An unasked-for observation about the other untracked file, recorded because it bears on the
notebook's accuracy and nothing was done about it.**
`reports/2026-09-08-pass39-three-defects-recon.md` is **also untracked**, and
`git ls-files reports/ | grep -c pass39` returns `0`. Commit `424c584` ("Pass 39: Pass 38 accepted
on Home Theater, recorded in the notebook") touched **only** `COLD-START.md` and `DECISIONS.md`:

```
$ git show --stat --oneline 424c584
424c584 Pass 39: Pass 38 accepted on Home Theater, recorded in the notebook
 COLD-START.md | 129 +++++++++++++++++++++++++++++++++++++++++++++++++++-------
 DECISIONS.md  |  62 ++++++++++++++++++++++++++++
 2 files changed, 177 insertions(+), 14 deletions(-)
```

So COLD-START.md's "Pass 39 pushed it together with … `reports/2026-09-08-pass39-three-defects-recon.md`"
is not true of the file itself — the notebook prose landed, the report did not. **It was not
committed here**: the scope lock allows exactly one new file, and that is this report. It is
raised as an open question (§7.7).

---

## 2. Their contract — and the file route is not in it

### 2.1 The fetch, and the clone's state before and after

Run in `~/Xcode/marlin-dvr-reference`. **`git fetch origin` only. No checkout, no edit, no commit,
no push, nothing run from the tree.**

```
=== BEFORE FETCH origin/main ===
c417c60a6d415fbacd7797490d43cba59338d414
=== HEAD (checkout, untouched) ===
9325d94439ef4c9db637c5014ff79f41d1f63956
=== STATUS ===
?? README-REFERENCE.md
```

```
$ git fetch origin
From github.com:marlin1111ai/marlin-dvr
   c417c60..095de81  main       -> origin/main
=== EXIT: 0 ===
=== AFTER FETCH origin/main ===
095de815adac50eaf77dcaa7cdb50115942c46c5
=== HEAD still ===
9325d94439ef4c9db637c5014ff79f41d1f63956
=== STATUS still ===
?? README-REFERENCE.md
```

**The clone is exactly what COLD-START.md describes.** It says the checkout is "still at 1.2.1"
and that `origin/main` "was fetched on 2026-09-08 and now reads `c417c60`". Both held before the
fetch. The checkout is unmoved at `9325d94`, the working tree is unchanged (`?? README-REFERENCE.md`
before and after), and only the remote-tracking ref advanced.

**New `origin/main` SHA: `095de815adac50eaf77dcaa7cdb50115942c46c5`.**

`appVersion = "1.8.0"` at `cmd/marlin-dvr/main.go:38`.

What arrived in `c417c60..095de81`:

```
 COLD-START.md                                      | 196 +++---
 DECISIONS.md                                       |  55 ++
 MARLIN-DVR-HANDOFF-2026-09-08.md                   | 424 +++++++++++
 cmd/marlin-dvr/hls.go                              |   9 +-
 cmd/marlin-dvr/main.go                             |  18 +-
 cmd/marlin-dvr/playfile.go                         | 273 +++++++
 cmd/marlin-dvr/stream.go                           |  31 +-
 reports/…pass83… pass84… pass85… pass86… pass87… pass88…
 13 files changed, 3981 insertions(+), 103 deletions(-)
```

### 2.2 Does their contract document the file route? — **No. Not one word.**

**`HLS-CLIENT-API.md` is byte-unchanged across the whole 1.8.0 delivery.**

```
$ git diff --stat c417c60 095de81 -- HLS-CLIENT-API.md
(no output — unchanged)

$ git log --oneline -10 origin/main -- HLS-CLIENT-API.md
c417c60 Pass 80: bring HLS-CLIENT-API.md up to 1.7.0 and document the trash route
ed8c2b2 Pass 73: GET /api/library/recordings/{id}/commercials for the Apple TV
d16be62 Pass 33: radio stations (build sweep)
1bb416c Pass 21: live time-shift buffer
82c7055 Pass 19: 1.1.0 deployed, HLS client note
```

It is 595 lines, §§1–11, and its own header (lines 6–13) says it "describes the server at version
**1.7.0**" and warns "if it does not say `1.7.0`, this file is behind the server and anything below
may be stale." That warning is now in force. **There is no §12, no `/api/play/file`, no
`video.mp4`, and no `"format":"file"` anywhere in the file.**

Worse than silent — **the contract's `format` row actively contradicts the new value.**
`HLS-CLIENT-API.md:68`, in §2's request-body table:

> | `format` | string | **`"hls"`** selects HLS. Absent, `""` or `"mp4"` gives the old fragmented-MP4 pipe (`stream.go:211`, `:289`) |

and `:104`, in §2.2's response table: `| format | "hls" |`. A client built strictly to the contract
would conclude `"file"` is not a legal value.

**Their own `COLD-START.md` is stale in the same way.** Its architecture row (line 23) still lists
the playback routes as `POST /api/play/sessions` (`format: "hls"`), `GET /api/play/s/{id}.mp4`,
`GET /api/play/hls/{id}/{file}` and `DELETE /api/play/sessions/{id}` — **`GET /api/play/file/…` is
absent.**

**So the whole of §2.3 below is read from their Go source at `origin/main`, not from a contract.**
That is a finding in itself: this app would be implementing an undocumented route against source
it is told to treat as reference only.

### 2.3 What the route actually is, from their source

| Fact | Where |
|---|---|
| Route registered | `cmd/marlin-dvr/main.go:332` — `GET /api/play/file/{id}/{file}` → `handlePlayFile` |
| Request struct | `stream.go:262-268` — `kind`, `id`, `client`, `start`, `format`. **Unchanged shape**; only the accepted `format` values grew |
| `format` switch | `stream.go:376-391` — `case "hls"`, `case "file"`, **no `default`** |
| URL built | `playfile.go:60` — `"/api/play/file/" + id + "/video.mp4"`; the only filename served is `video.mp4` (`:50`, enforced `:212`) |
| Response fields | `stream.go:394` — exactly nine: `id`, `url`, `title`, `sub`, `kind`, `mode`, `duration`, `start`, `format` |
| Serving | `playfile.go:265-269` — `Content-Type: video/mp4`, `Cache-Control: no-store`, `X-Marlin-Session`, then `http.ServeFile` (Range, If-Range, Content-Length) |
| Seekable from the first byte | `playfile.go:68-70` — `-movflags +faststart`, moov atom moved to the front |
| Remux only | `playfile.go:68-70` — `-c copy` inherited from `stream.go:335`; nothing re-encodes |
| Stop | `DELETE /api/play/sessions/{id}` — `main.go:328`, unchanged |
| Watchdog | `playfile.go:145` starts the **same** `hlsWatchdog`; `hlsIdleTimeout = 15 * time.Second` (`hls.go:49`) |
| Per-session log | `main.go:329` — `GET /api/play/sessions/{id}/log`, unchanged |

### 2.4 Every point where their repo and the BACKGROUND disagree

Ten. Numbered so they can be answered individually.

**D1 — "The marlin-dvr project has deployed server 1.8.0." Their own record says it did not.**
Their Pass 88 report (`reports/2026-09-08-pass88-1-8-0-published.md`) opens:

> **NOTHING WAS INSTALLED, DEPLOYED OR SWITCHED.** The Unraid host `192.168.1.250` and the running
> `marlin-dvr` container were not contacted at all this pass — no `GET`, no `POST`, no SSH, no
> `docker` command aimed at them. In particular **no `POST /api/update`** … The owner installs by
> pressing the Status page button himself; that is the whole point of this pass.
>
> **`:1.8.0` is published on ghcr and verified.** Digest
> `sha256:96c07c58ab32475f35be3dc4101039d4007c510133c9eb7a645fadf82a7a32e4` …

**Published ≠ deployed.** Both notebooks still record the container running **1.7.0** since the
owner's in-place update at 00:06 on 2026-09-08. **This pass cannot check the running version** —
`GET /api/system` is a request to the do-not-touch server. If the owner has not pressed the button,
the file route is not reachable at all, and D2 says what happens then.

**D2 — an unknown `format` is not an error; it silently gives the old, unseekable pipe.**
The BACKGROUND does not mention this and it is the most dangerous single fact in the pass.
`stream.go:376` switches on `req.Format` with `case "hls"` and `case "file"` and **no `default`
arm**. `Format` was already defaulted to `"mp4"` at `stream.go:273` and `url` to
`"/api/play/s/" + x.ID + ".mp4"` at `stream.go:375`. So a 1.7.0 server — which has no `"file"`
case — answers `"format":"file"` with **HTTP 200**, `"format":"mp4"`, and the browser's
fragmented-MP4 pipe, which `HLS-CLIENT-API.md:290-292` describes as "a chunked, length-less stream
with **no seeking**". No error, no warning. The app would play something strictly worse than today
and nothing in the response's shape would say so except the `format` field.

**D3 — the wait is on the GET, not on the POST.**
BACKGROUND: "The server remuxes the whole file at POST time, so there is a wait before the first
byte." Precisely: `startFile` builds the command, calls `cmd.Start()` (`playfile.go:131`) and
**returns immediately** (`:146`); `handleCreateSession` then writes the JSON (`stream.go:394`). The
POST is fast. The **first GET blocks**, polling `x.ffmpegOut` every 200 ms
(`playfile.go:226-253`) with a hard ceiling of `playFileWait = 10 * time.Minute` (`:51`). Same
wall-clock, different request — and it matters enormously, because this app's first GET is a
whole-body `URLSession.data(for:)` with a 25-second timeout (§3.4).

**D4 — "It is NOT established what counts as 'fetching' during the remux window." It is
established, in their source.** `handlePlayFile` calls `x.touch()` **before** the wait loop
(`playfile.go:223`) and **again on every 200 ms iteration** (`:252`). The blocking GET therefore
feeds the 15-second watchdog for the entire remux, and their comment says so at `:206-208`: "the
wait feeds it too, so a long remux is never killed by the idle timeout." **What must be under 15 s
is only the POST → first-GET gap**, exactly as BACKGROUND says — but nothing else needs inventing.

**D5 — the route refuses any recording that is not `mode: "copy"`.** Not mentioned in BACKGROUND,
which only shows `"mode":"copy"` in its example. `playfile.go:99-101`:

```go
if x.Mode != "copy" {
    return errors.New("this recording is not H.264/AAC, so it cannot be remuxed without re-encoding — use the HLS route for it")
}
```

`copyMode` is decided at `stream.go:324`: `mi.VideoCodec == "h264" && (mi.AudioCodec == "aac" || "" || "mp3")`. Anything else is a **502** at POST time. This is a real branch — part of the
owner's library must keep the HLS route.

**D6 — the route refuses a recording still being written.** `playfile.go:105-107`, 502: "this
recording is still in progress — it can be played when it finishes". BACKGROUND says "FINISHED
RECORDING" but does not name the refusal, and today the HLS route plays what has been written so
far (`HLS-CLIENT-API.md:135-139`). This is a behaviour **loss** for in-progress recordings.

**D7 — `start` is still applied as ffmpeg's `-ss`, and `duration` still reports the whole
recording.** BACKGROUND's example carries `"start":0` and is silent on this. `stream.go:329-331`
adds `-ss` in the `case "recording":` arm — **before** the `format` switch — so a file session
created with `start: 1680` remuxes only the remainder and the MP4's own t=0 is 1680 s into the
show. Meanwhile `stream.go:322` sets `x.Duration = mi.Duration`, the **whole** recording's length,
which is what `:394` echoes back. Send a non-zero `start` on this route and the response's
`duration` describes a file that does not exist. This is a trap, and §5 turns it into a decision.

**D8 — 410 is not the only ended-session answer; 404 is the other.** BACKGROUND: "later requests
return 410." `handlePlayFile` returns **404** when the session is not in the map, when its `Format`
is not `"file"`, or when the filename is not `video.mp4` (`playfile.go:210-215`), and **410
"session ended"** only when the session is still held but `!x.Active` (`:216-222`). `Streams.add`
deletes finished sessions older than 10 minutes whenever any new session is created
(`stream.go:130-147`). So a session killed by the watchdog answers 410 for a while and 404
afterwards.

**D9 — there are four distinct loud failures, not one.** BACKGROUND names only
`"single-file MP4 session could not start: <reason>"`. That one is the **POST-time** 502
(`stream.go:387`). Three more are **GET-time** 502s, each suffixed " (see the session log)":
"the remux failed (…)" (`playfile.go:232-235`), "the remux did not finish within 10m0s"
(`:241-244`), and "the remux produced no file" / "the remux produced an empty file"
(`:256-262`). All arrive as plain text.

**D10 — the ~9 s/GB figure, and what it was measured on.** BACKGROUND says "never measured on the
Unraid box the app talks to", which agrees with their own report — but the samples are worth
having. Their Pass 85 report, §"How long you wait before it starts playing", measured **on
marlinpc**:

> * an **8-minute** show: **2.4 seconds**
> * a **43-minute** show: **11 seconds**
> * a **1 hour 42 minute** show: **26 seconds**
>
> The pattern is about **9 seconds per gigabyte** … ≈ **110 MB/s**

and their own caveat at Pass 85 lines 42–45: this "**does not hold**" for Unraid, where neither
location has been measured. Their Pass 86 (`…pass86-recordings-moved-to-unraid-array.md`) records
that the recordings **moved to the Unraid array**, so even the read path has changed since the
measurement.

**Two further facts from their repo that BACKGROUND does not carry, and that matter here.**

- **Nothing else can reach this route.** Their Pass 87 headline: "**Pass 85 added a third playback
  output, and nothing calls it.** … The browser UI **cannot reach the new route at all** — it never
  sends a `format` field". This app would be the route's first and only client; there is no second
  implementation to compare behaviour against.
- **The temp file lands in `os.TempDir()`** (`playfile.go:55-58`), which inside the Unraid container
  is `docker.img`. Their Pass 85 flagged "a 2.7 GB temp file per concurrent session" as an
  unresolved risk, not a settled one.

**One point where they and BACKGROUND agree exactly.** "They cannot prove the LIVE badge
disappears; only a device test can." Their Pass 87 says the same three times — at its line 544
("you **CANNOT** fully check this on marlinpc … This route serves no playlist at all"), in its
verification table at line 621 ("**Only by proxy** … the badge itself needs the Apple TV app
pointed at this route, and **nothing points at it yet**"), and as its first open question at 769.

---

## 3. Our side, with eyes on the real code

**The Swift sources were enumerated this pass, not remembered.** `find "Marlin DVR TV" -name '*.swift'`
returned **47** files; the count was then confirmed by hand from a numbered `ls -1 | grep '\.swift$' | nl`
listing, which ends at line 47 and whose only non-Swift sibling in that folder is `Assets.xcassets`.
The UI-test target holds a further 12 Swift files. Nothing below is inherited from an earlier
report's wording.

### 3.1 Where the app builds a `POST /api/play/sessions` body — **one place, `format` hardcoded**

`grep -rn "play/sessions" --include="*.swift" .` finds exactly one construction site.

**`PlaybackSession.swift:41-47`** — the body type, five fields, all non-optional:

```swift
private struct CreateBody: Encodable {
    let kind: String
    let id: String
    let format: String
    let client: String
    let start: Double
}
```

**`PlaybackSession.swift:51`** — the only place it is filled:

```swift
let body = CreateBody(kind: request.kind, id: request.targetID, format: "hls", client: clientID ?? "", start: request.startSeconds)
```

**`format` is sent, and it is hardcoded to the string literal `"hls"` at that one line.** It is not
absent, not configurable, not derived from the request. The other four come from `PlayRequest`
(`:26-32` `kind`, `:35-41` `targetID`, `:44-47` `startSeconds`) and from
`PlaybackSessionClient.clientID` (`:39`, the id `ClientSession` persisted).

There are exactly **two** callers of `create(_:)`: `PlayerModel.start()` at `PlayerModel.swift:118`
and `PlayerModel.startAgain(at:)` at `:722`. Both go through the same hardcoded line.

### 3.2 The model the response decodes into — nine fields, none optional, `format` never read

**`Models.swift:394-404`:**

```swift
struct PlaySession: Decodable {
    let id: String
    let url: String         // "/api/play/hls/<id>/index.m3u8"
    let title: String
    let sub: String
    let kind: String
    let mode: String        // copy | transcode
    let duration: Double    // recordings only
    let start: Double
    let format: String
}
```

**Every field is non-optional.** They are exactly the nine the server writes at `stream.go:394`, in
the same names and types.

**What it would do with `"format":"file"` and a `.mp4` url: it would decode cleanly and notice
nothing.** `url` is an untyped `String` — `/api/play/file/<id>/video.mp4` satisfies it as readily as
a `.m3u8` path; the comment at `:396` is a comment. `format` decodes into a stored property that
**nothing in the app ever reads**: `grep -rn "\.format\b"` across every Swift file returns no
consumer (the only `.format` hits are `RadioStation`'s own unrelated field and `DateFormatter`
calls). The four fields actually consumed are read at `PlayerModel.swift:119-122` — `url` (via
`:130`), `start` → `startOffset` (`:120`), `duration` (`:121`), `id`, plus `kind` and `mode` in the
console line at `:122` only.

**The consequence is D2's other half.** If the server answered `format:"mp4"` with the old pipe URL
— which is what a 1.7.0 server does — the app would decode a 200, take the URL, and play it. There
is no field the app checks that would tell it the request was not honoured.

### 3.3 Every distinct route into playback, and which are recordings

`grep -rn "\.live(channel\|\.recording(episode\|\.camera("` over `Marlin DVR TV/`, excluding
`PlayRequest.swift` itself, gives six construction sites, plus two in-Player derivations.

| # | Route | Site | Kind |
|---|---|---|---|
| 1 | Guide cell → Watch live | `GuideScreen.swift:215` | live |
| 2 | Airing sheet → Watch live | `GuideScreen.swift:296` | live |
| 3 | Favorites → click a channel | `FavoritesScreen.swift:118` | live |
| 4 | On Now → click a card | `OnNowScreen.swift:146` | live |
| 5 | Cameras → click a camera | `CamerasScreen.swift:84` | camera |
| 6 | Show detail → `play(_:from:)` | `ShowDetailScreen.swift:148-150` | **recording** |

**All recordings enter through the single funnel at `ShowDetailScreen.swift:149`**, which has three
callers:

- **Resume from the store** — `ShowDetailScreen.swift:177`, `play(resume.episode, from: resume.entry.position)`.
  `resume` is `ResumeStore.latest(among:)` (`ResumeStore.swift:38-46`), which only offers an entry
  whose `position > 5`.
- **"Play newest"** — `:188`, `play(newest, from: ResumeStore.entry(for: newest.id)?.position ?? 0)`.
- **An episode row** — `:236`, `play(episode, from: ResumeStore.entry(for: episode.id)?.position ?? 0)`.

**So every one of the three carries a resume position when one exists**, not just the Resume button.

Two more recording paths are created inside the Player and never touch a screen:

- **Auto-play-next** — `PlayerScreen.swift:98-107` `playNext()`: `model.request.replacing(episode: next, start: 0)`
  (`PlayRequest.swift:94-97`), fired by the Ended state's button or automatically by the countdown
  hitting zero (`PlayerScreen.swift:65-67`). **`start: 0` always.**
- **Seek-past-the-prepared-range restart and the 6h/expired Restart** — `PlayerModel.restart(at:)`
  `:703-716` → `startAgain(at:)` `:718-741`, which calls `create(request.withStart(target))`
  (`PlayRequest.swift:100-103`).

**Radio is not a play session at all** and is out of every path above: `RadioStation.swift:31` and
`RadioPlayer.swift:10` both record that the app plays the station URL directly with no
`POST /api/play/sessions`, per contract §9 (`HLS-CLIENT-API.md:324-326`).

### 3.4 The Player's attach path

**The sequence, `PlayerModel.start()` `:113-143`:**

1. `:118` `let created = try await sessions.create(request)` — the POST.
2. `:119-122` four local assignments and one `print`.
3. `:130` `ServerConfig.resolve(created.url)` — `URL(string:relativeTo: baseURL)` (`ServerAPI.swift:22-25`).
4. `:134` `let probe = await sessions.firstPlaylist(url)` — **the first GET.**
5. `:137-140` fails unless `probe.status == 200`.
6. `:141` `attach(url)`, `:142` `startKeepAlive(url)`.

**The elapsed time between the POST returning and the first byte being requested is the four
assignments, one `print` and one `URL(string:)` at `:119-130` — microseconds of local main-actor
work, no `await`, no I/O.** The 15-second POST→GET budget is met today with five orders of
magnitude to spare, and would still be met on the file route.

**`attach(_:)` `:153-164` — how the URL becomes an item:**

```swift
private func attach(_ url: URL) {
    let item = AVPlayerItem(url: url)          // :154
    item.preferredForwardBufferDuration = 0    // :155  the buffer hint
    item.externalMetadata = Self.metadata(for: request)  // :156
    observe(item)                              // :157
    player.replaceCurrentItem(with: item)      // :158
    player.play()                              // :159
    attachedAt = Date()                        // :160
    phase = .playing                           // :161
    showHUD(for: 6)                            // :162
    loadCommercialsOnce()                      // :163
}
```

- **The buffer hint is `preferredForwardBufferDuration = 0`** (`:155`) — "let AVFoundation choose".
  It is the only buffering property the app sets.
- **The metadata strings** are built by `metadata(for:)` `:166-177`: `.commonIdentifierTitle` =
  `request.title`, and `.iTunesMetadataTrackSubTitle` = `request.subtitle` when non-empty, each
  with `extendedLanguageTag = "und"`. For a recording those are `episode.show` and
  `"S9 E11 · <title> · <channel>"` (`PlayRequest.swift:53`, `:64-69`).
- `PlayerHost.attach` (`PlayerHost.swift:112-117`) sets `playerController.requiresLinearPlayback = linearOnly`
  (`:115`), and `linearOnly` is `model.isCamera` (`PlayerScreen.swift:36`) — **cameras only**.
  Recordings and live are `false`, so the app never itself forbids seeking.

**The first GET is the problem for this route, and it is worth stating exactly.**
`firstPlaylist(_:)` (`PlaybackSession.swift:66-77`):

```swift
var req = URLRequest(url: url)
req.timeoutInterval = Self.firstPlaylistTimeout      // :68   — 25 s
let (data, response) = try await session.data(for: req)   // :70
```

with `static let firstPlaylistTimeout: TimeInterval = 25` (`:26`) and the same value on the
session's `timeoutIntervalForRequest` (`:33`). Two consequences on the file route:

1. **It has no `Range` header and uses `session.data(for:)`, which buffers the entire body into
   `Data`.** Against `video.mp4` that is the whole remuxed recording in memory — gigabytes.
2. **It would very likely time out first.** The server sends nothing at all while it blocks
   (`playfile.go:226-253`), so the 25 s idle timeout is the binding constraint. On their marlinpc
   numbers a 43-minute show (11 s) would squeak through and a 1 h 42 m show (26 s) would not, and
   the Unraid rate is unmeasured. A timeout returns `PlaylistProbe(status: 0, …)` (`:75`), which
   `start()` turns into `fail(...)` at `:137-139` — the Failure state, with the session left for the
   watchdog.

This single call is the hardest blocker in the app and §5 step 4 is about it.

### 3.5 Everything that assumes a playlist rather than a file

**`seekableTimeRanges` — three readers.**

- `PlayerModel.seekableRange` `:208-213` — filters to ranges with a positive numeric duration and
  returns `(first.start.seconds, last.end.seconds)`. **This is the app's whole notion of what can be
  seeked to.**
- `PlayerHost.seekableWindow` `:209-215` — the same computation, used by the live short-window
  Select path.
- Everything else goes through `seekableRange`.

**The seek clamps — two, identical in shape.**

- `frameStep(_:)` `:353-358`: clamps the ±1-frame target to `[range.start, max(range.start, range.end - 0.05)]`.
- `skipCommercialBreak()` `:493-498`: the same two lines, after a separate clamp against `duration`
  at `:491`.

**`frameStep(_:)` `:341-363`** — guards on `isRecording, isPaused, phase == .playing` (`:343`),
cancels pending seeks (`:350`), computes the target fresh from `item.currentTime()` (`:351-352`),
clamps (`:353-358`), then seeks with both tolerances `.zero` (`:359`). The frame rate comes from
`refreshFrameRate()` `:285-302`, whose comment at `:293` records that **"HLS items expose no
assetTrack"** — an assumption about the item type that a file-backed item may simply invalidate in
the app's favour (an MP4 item usually does expose `assetTrack.nominalFrameRate`, the `:288` branch
the code prefers but has never been able to take).

**`timeJumped()` `:540-554` and its restart.** This is the mechanism COLD-START names as the
suspect for the erratic end-of-range stepping, and **its line number has moved: COLD-START says
`PlayerModel.swift:382`; in the file as it stands today it is `:540-554`**, the file having grown
with Pass 38's commercial-skip code. Re-verified this pass:

```swift
guard isRecording, phase == .playing, !restartingBeyond, let attachedAt, Date().timeIntervalSince(attachedAt) > 3,
      let item = player.currentItem, let range = seekableRange else { return }   // :545-546
let t = item.currentTime().seconds
guard t.isFinite, range.end - t < 1.5, !fullyPrepared else { return }            // :548
let target = startOffset + t
print("[player] seek past the prepared range: \(target)s of \(duration)s")        // :550
restartingBeyond = true
await restart(at: target)                                                        // :552
```

It fires only when a seek lands within **1.5 s** of the end of the seekable range **and**
`!fullyPrepared`.

**`restart(at:)` `:703-716`** — `detachPlayer()`, cancel keep-alive, `DELETE` the session, save the
resume entry at the target, set `startOffset = target` and `position = target`, then
`startAgain(at:)` `:718-741`, which POSTs `request.withStart(target)` and repeats the
`firstPlaylist` → `attach` sequence. **This is a full teardown: the Starting screen goes back up.**

**`startOffset` `:47`** — set from `created.start` at `:120` and `:724`, and from `target` at `:713`.
It is the offset every absolute position is built on: `position = startOffset + t` at `:220`,
`:371`, `:510`; `preparedTo = startOffset + range.end` at `:223`; the commercial target converts
back with `absolute - startOffset` at `:492`. `PlayerModel.swift:434` records that this is contract
§10.4's `edlTime = playerPosition + start`.

**`preparedTo` `:50` and `fullyPrepared` `:101`.**

```swift
var fullyPrepared: Bool { duration > 0 && preparedTo >= duration - 2 }   // :101
if let range = seekableRange { preparedTo = startOffset + range.end }    // :223
```

`fullyPrepared` is the direct expression of "the EVENT playlist has caught up with the file". It
gates `timeJumped()`'s restart (`:548`) and the HUD line at `PlayerScreen.swift:250-251`.

**`PlayerModel.isLive` `:97` and both live indicators.**

```swift
var isLive: Bool { if case .live = request { return true }; return false }
```

**It is the request's kind and nothing else** — no stream property, no playlist property. The app's
two live indicators are:

- **`LiveHUD`, `PlayerScreen.swift:190`** — `Text(atLiveEdge ? "LIVE" : "LIVE · −\(…)")`.
- **`PausedLiveOverlay`, `PlayerScreen.swift:348`** — `Text("LIVE · HELD")`.

Both are unreachable for a recording. `PlayerScreen.swift:77-88`:

```swift
if model.isPaused && model.isLive {          // :79
    PausedLiveOverlay(model: model)
} else if model.hudVisible || model.notice != nil {
    if model.isRecording {                   // :82
        RecordingHUD(model: model)
    } else {
        LiveHUD(model: model)                // :85
    }
}
```

A recording gets `RecordingHUD`, always. **The "LIVE" the owner sees on a recording is therefore
`AVPlayerViewController`'s own transport, not the app's** — which is what Pass 39 §4.1–4.2 concluded
and this pass re-verified from the same source rather than inheriting.

**The commercial-skip `attach()` path.** `loadCommercialsOnce()` `:393-397` is called from
`attach(_:)` `:163`, guarded by `commercialsRequested` so it runs **once per playback** and never
polls (`:385-392`, per contract §10.3's "Do not poll it forever"). Breaks are noticed on the
existing 1 s observer via `noticeCommercialBreak()` `:439-449`, using `position` — i.e. `startOffset + t`.
The skip, `skipCommercialBreak()` `:484-505`, clamps **against the session's duration** first:

```swift
var absolute = prompt.endSeconds
if duration > 0 { absolute = min(absolute, duration - Self.commercialSkipEndMargin) }   // :490-491
var target = CMTime(seconds: max(0, absolute - startOffset), …)                          // :492
```

`commercialSkipEndMargin = 1` (`:383`), and the comment at `:487-489` states the assumption
explicitly: "`duration` here is the play session's, which contract §3 states is the whole
recording's **even for a session started at an offset**." **That assumption survives the file
route only if `start` stays 0** — see D7.

### 3.6 What is on screen between "play pressed" and "first frame"

**The state is `PlayerModel.Phase.starting`** (`PlayerModel.swift:20`, set at `:114`), and it is
drawn by **`StartingOverlay`, `PlayerScreen.swift:48` and `:112-145`** — frame 6a.

It draws, in order: the background and radial gradient (`:117-119`), artwork or the channel
initials tile (`:121`, `:147-150`), `model.request.title` at 64 pt (`:123`), the subtitle (`:128`),
a **`PulseBar`** (`:133`), `model.startingLine` (`:135`), and a floor line (`:138`):

```swift
Text(model.isLive ? "Live channels usually take 2–6 seconds. Press Menu to cancel." : "Press Menu to cancel.")
```

`startingLine` for a recording is **"Preparing the recording"** (`PlayerModel.swift:145-151`).

`PulseBar` (`PlayerScreen.swift:165-178`) is a capsule with
`.easeInOut(duration: 0.8).repeatForever(autoreverses: true)` — **an indefinite pulse, not a
progress bar**. It shows no percentage, no elapsed time and no estimate.

**Does it stay up for an arbitrary wait, or time out?** It **times out — via the network, not via
any timer of its own.** There is no app-side deadline on `.starting`. The bound is the two
URLSession timeouts, both 25 s (`PlaybackSession.swift:26`, `:33`, `:68`): the POST (through
`data(for:path:)` `:128-134`) and then `firstPlaylist`. On a timeout, `probe.status == 0` →
`fail(status: 0, …)` (`PlayerModel.swift:137-139`) → `phase = .failed` (`:651`) → `FailureState`
(`PlayerScreen.swift:50`), whose title for status 0 is "playback failed" (`:415`). So today the
longest a recording can sit on 6a is roughly 25 s per stage, and then it becomes an error screen —
**not a spinner that waits forever, and not a screen that explains a long wait either.**

The only other thing the app ever says about waiting is in the **playing** HUD, not this one:
`PlayerScreen.swift:250-251`, shown while `!model.fullyPrepared`:

> "Prepared to \(…). Jumping past that point restarts playback there — a second or two of buffering, not an error."

### 3.7 How a 410 is handled today, anywhere in the play path

**Exactly one place turns a 410 into behaviour**, and it is the keep-alive.

`PlaybackSession.keepAlive(_:)` `:80-91` sends `Range: bytes=0-0` with a 20 s timeout and returns
the status. `PlayerModel.startKeepAlive(_:)` `:558-579` runs it every 10 s
(`PlaybackSessionClient.keepAliveInterval = .seconds(10)`, `:27`) and:

```swift
if status == 410 {          // :573
    self.sessionExpired()
    return
}
```

`sessionExpired()` `:581-587` saves the resume position for a recording, detaches the player,
cancels the loop and sets `phase = .expired`. That is drawn by **`ExpiredState`**
(`PlayerScreen.swift:51`, `:477-480`): the code line "410 · session ended" and, for a recording,
"The session expired. Restart continues from \(PlayerTime.clock(model.position))." — with a
Restart button wired to `model.restart()` (`:51`), which is `restart(at:)` with `requested == nil`,
i.e. `position` (`PlayerModel.swift:704`).

**Everywhere else, a 410 is an ordinary HTTP failure, not an expiry.**

- On the **POST**, `PlaybackSession.check` `:136-143` throws `APIError(kind: .http(status: 410))`,
  which `start()` `:123-125` turns into `fail(status: 410, …)` → **`.failed`**, not `.expired`.
  `PlayerScreen.swift:413` gives it the code line "410 · session ended" in the *Failure* state.
- On the **first playlist GET**, `firstPlaylist` returns status 410 and `start()` `:137-139` calls
  `fail(status: 410, …)` → **`.failed`**.

So the app distinguishes "the session died while I was watching" (`.expired`, offers Restart at the
saved position) from "it was already dead when I asked" (`.failed`, offers Back and Retry). Nothing
retries a 410 automatically anywhere.

---

## 4. What the file route would close, leave open, or make worse

Tied to §3.5 throughout. Each verdict says what it rests on.

### 4.1 The LIVE badge — **CLOSED, by construction; unproven, and only the Apple TV can prove it**

The badge is not ours to remove: §3.5 re-verified that `PlayerModel.isLive` (`:97`) is the request
kind alone, that `LiveHUD`'s "LIVE" (`PlayerScreen.swift:190`) and `PausedLiveOverlay`'s "LIVE ·
HELD" (`:348`) are both unreachable for a recording (`:79`, `:82-86`), and therefore that the badge
is `AVPlayerViewController`'s own transport, drawn because the EVENT playlist never gets
`#EXT-X-ENDLIST`.

The file route removes the input that produces it. There is no playlist at all — a finished MP4
with a fixed `Content-Length` and `Accept-Ranges: bytes` (`playfile.go:265-269`, `http.ServeFile`),
whose moov atom is at the front before a byte is served (`:68-70`). AVFoundation gets a definite
duration and no live edge, so there is nothing for a live transport to be drawn from.

**This is stronger than the alternative fix.** Their Pass 84's open question 3 asks whether an
`#EXT-X-ENDLIST` alone clears the badge or whether Apple also wants `EXT-X-PLAYLIST-TYPE:VOD` —
an open tvOS question. For an MP4 that question does not arise.

**But it is reasoning, not evidence**, and both projects say so: their Pass 87 line 544 ("you
CANNOT fully check this on marlinpc"), its table at 621 ("Only by proxy"), and this project's Pass
39 Open Question 5. It needs one device run.

### 4.2 Fast-forward refused early in playback — **CLOSED, and the cost moves to the front**

Mechanism, from §3.5: the app's entire notion of what may be seeked to is `seekableRange`
(`:208-213`) reading `item.seekableTimeRanges`. On a growing EVENT playlist only the written part
is advertised, so early in playback the range is short and both clamps — `frameStep`'s `:353-358`
and `skipCommercialBreak`'s `:493-498` — pin any target to the written edge, while Apple's own
transport refuses a scrub past it for the same reason.

A complete, faststart MP4 advertises the whole file as seekable from the first response. Both
clamps stop being restrictive, `preparedTo` (`:223`) becomes `startOffset + duration` on the first
tick, and the transport allows a scrub anywhere.

**Made worse, honestly:** the wait does not vanish, it moves. Today you can watch after a second or
two and merely cannot skip forward yet; on the file route there is nothing to watch until the remux
finishes — their marlinpc samples are 2.4 s / 11 s / 26 s for 8-minute / 43-minute / 1 h 42 m
shows, and the Unraid figure is unmeasured (D10). And the HUD line at `PlayerScreen.swift:250-251`
("Prepared to …") becomes dead text, because `fullyPrepared` is true immediately.

### 4.3 Resume overshoot — KNOWN AND UNFIXED 4 — **CLOSED, but only with a decision about `start`**

The overshoot is AVPlayer joining a growing playlist near its live edge: COLD-START records
`start=1680` arriving at **1988 s** by the fourth tick. A file has no live edge; playback begins at
the file's own t=0. So the symptom cannot occur on this route **in either of the two possible
shapes** — but they are not equivalent, and D7 is why:

- **Send `start: 0` and seek in-item after the item is ready.** `startOffset` stays 0, so
  `position = startOffset + t` (`:220`) is honest, `duration` (`:322` server-side) describes the
  file that actually exists, `fullyPrepared` (`:101`) is meaningful, and
  `skipCommercialBreak`'s duration clamp (`:490-491`) keeps the assumption its own comment states.
  **Cost:** the remux is the whole recording every time, so resuming at 1 h 40 m still pays the
  full-file wait.
- **Keep sending `start: N`.** `stream.go:329-331` still applies `-ss`, so the MP4 is only the
  remainder and its t=0 *is* the resume point — the wait is proportionally shorter. **Cost:** the
  response's `duration` still reports the whole recording (`stream.go:322`, `:394`), so it
  disagrees with the file. `fullyPrepared` would be false forever, the HUD's "x of y" would be
  wrong, and the commercial clamp's stated assumption would break.

**Verdict: closed either way; the first shape is the honest one and §5 plans for it, with the
trade-off raised as a question.**

There is a free by-catch. KNOWN AND UNFIXED after Pass 38 records "One skip landed 1.01 s past
`endSeconds` instead of on it", from the one session that had `startOffset = 931.000155` while the
two exact landings both had `startOffset = 0`. Sending `start: 0` always would eliminate the only
condition under which that was ever observed. **That is a correlation of one, not a diagnosis.**

### 4.4 Erratic end-of-range frame stepping — KNOWN AND UNFIXED 3 — **CLOSED as to its named
suspect, by removing the suspect's trigger; not proven, because the suspect was never proven**

COLD-START's entry names the suspect: "the app's own seek-past-the-prepared-range restart,
`PlayerModel.swift:382`" — re-verified this pass as `timeJumped()` at **`:540-554`** (§3.5; the
line has moved).

On the file route that restart **cannot fire**. Its guard at `:548` requires both
`range.end - t < 1.5` and `!fullyPrepared`. With the whole file seekable, `preparedTo` (`:223`) is
`startOffset + duration` from the first tick, so `fullyPrepared` (`:101`) is true and the second
condition fails permanently. There is also no longer a "prepared edge" at 1:05:27 of a 1:11:10
recording for a step to be near — the seekable range simply is the recording.

**Two reasons this is "very likely" and not "closed":**

1. **The suspect was a suspect.** COLD-START says "Suspect is", not "the cause is". If the
   erratic behaviour has another cause — AVFoundation's handling of exact seeks near the end of a
   *file* is not obviously better than near the end of a *playlist* — the file route does not touch
   it.
2. The measurement was made **paused and frame-stepping**, and nothing about the file route has
   been driven on a device by anyone.

### 4.5 Summary table

| Defect | Verdict | Rests on |
|---|---|---|
| LIVE badge | **Closes** | badge is Apple's (`PlayerScreen.swift:79-86`, `:190`, `:348`; `PlayerModel.swift:97`); MP4 has fixed length, no live edge (`playfile.go:68-70`, `:265-269`) |
| Fast-forward refused early | **Closes**; wait moves to the front | `seekableRange` `:208-213` and the two clamps `:353-358`, `:493-498` stop being short |
| Resume overshoot (K&U 4) | **Closes**, with a `start` decision | no live edge to join; but `-ss` still applies (`stream.go:329-331`) while `duration` stays whole (`:322`) |
| Erratic end-of-range stepping (K&U 3) | **Very likely closes** | `timeJumped()`'s restart `:540-554` can no longer fire (`:548` + `fullyPrepared` `:101`) — but it was only ever the suspect |
| **New, made worse** | Long blank wait on 6a; `firstPlaylist` buffers the whole MP4 and times out at 25 s; non-`copy` recordings refused (D5); in-progress recordings refused (D6); temp space on Unraid | §3.4, §3.6, D5, D6 |

---

## 5. BUILD PLAN for a later pass — on paper only, nothing built

Minimum set to put **recordings** on the file route while **live, cameras and radio keep the HLS
route byte-for-byte untouched**. Radio needs no mention in any step: it never creates a session
(`RadioStation.swift:31`, `RadioPlayer.swift:10`).

Steps 1–7 are changes. Anything I am not certain about is a **question** in §7, not a step.

**1. `PlayRequest.swift` — add a `format` computed property.**
Beside `kind` (`:26-32`), in the same shape: `"file"` for `.recording`, `"hls"` for `.live` and
`.camera`. One switch, no other change to the enum. This is the single place the route choice is
expressed, so live and camera cannot drift onto it by accident.

**2. `PlaybackSession.swift:51` — stop hardcoding the format.**
Replace the literal `format: "hls"` with `format: request.format`. This is the only line in the app
that names a format, and both callers (`PlayerModel.swift:118`, `:722`) go through it.

**3. `Models.swift` — no change needed; `PlaySession` already decodes the response.**
Verified in §3.2: nine non-optional fields, exactly the nine `stream.go:394` writes, and `url` is
an untyped `String`. **Listed as a step so a later pass does not "fix" it.** The work is in step 4.

**4. `PlayerModel.swift` — read `created.format` and honour it. This is the safety step, not a
nicety.**
After `:119`, branch on `created.format`. When the app asked for `"file"` and the server answered
anything else, it must **not** treat the response as a file: fall back to today's HLS behaviour, or
fail loudly. Without this, a 1.7.0 server silently hands back the old fragmented-MP4 pipe with
HTTP 200 (D2) and the app plays something with no seeking at all. `created.format` is decoded today
and read by nothing (§3.2), so this is new consumption of an existing field.

**5. `PlaybackSession.swift` — a first-fetch for the file route that does not buffer the body and
does not time out during the remux.**
`firstPlaylist` (`:66-77`) is wrong for this route twice over (§3.4): `session.data(for:)` buffers
the entire MP4 into memory, and its 25 s timeout (`:26`, `:33`, `:68`) fires while the server is
legitimately blocked. Add a sibling probe for file sessions that sends `Range: bytes=0-0` — the
same header `keepAlive` already uses (`:82`) — with a `timeoutInterval` well above the longest
expected remux. It returns a status, not a body.

**6. `PlayerModel.start()` `:113-143` and `startAgain(at:)` `:718-741` — route the probe.**
Call step 5's probe for a file session and today's `firstPlaylist` for HLS. Two constraints the
edit must preserve: the POST→first-GET gap stays local-only work (`:119-130`, §3.4), and the
`probe.status == 200` gate at `:137-140` / `:730-733` keeps feeding `fail(...)`, so the existing
Failure state keeps working for D9's four 502s with no new UI.

**7. `PlayerModel.swift` — resume by seeking, not by `start`.**
For a file session, send `start: 0` and seek in-item once the item is ready, instead of
`create(request.withStart(target))`. Touches the two POST sites (`:118` via
`PlayRequest.startSeconds` `:44-47`, and `:722`) and `restart(at:)` `:703-716`, which sets
`startOffset = target` at `:713`. Keeping `startOffset = 0` is what preserves the stated assumptions
of `position` (`:220`), `fullyPrepared` (`:101`) and `skipCommercialBreak`'s duration clamp
(`:487-491`). **Conditional on the owner's answer to §7.2.**

**Two things deliberately NOT in the plan, with the reason.**

- **`timeJumped()` `:540-554` needs no edit.** Its own guard at `:548` (`!fullyPrepared`) makes it
  inert on a complete file (§4.4). Adding an explicit `isFileSession` guard would be belt-and-braces
  on a path that is already closed, and touching the seek path is precisely what Pass 39 sorted as
  "the Player's most fragile area". **Left alone unless a device run shows it firing.**
- **No new UI, spinner, progress, retry or timeout.** Out of scope here and named as questions
  §7.3 and §7.4 instead.

---

## 6. Step 6 — the push, and the three readings

The report was committed and pushed in this same pass; the three commands were run separately and
every value is pasted. No force-push; no history rewritten.
`reports/2026-09-08-pass40-session-start-values.md` was **not** staged, committed, amended or
touched, and neither was `reports/2026-09-08-pass39-three-defects-recon.md`.

<!--PUSH_EVIDENCE-->

---

## 7. Open questions for the owner

**7.1 Is 1.8.0 actually installed on the Unraid container?** Their Pass 88 says
"NOTHING WAS INSTALLED, DEPLOYED OR SWITCHED" and that the image is published to ghcr only
(digest `sha256:96c07c58…`), to be installed by pressing the Status page button. Both notebooks
still record 1.7.0 running. **This pass could not check** — that is a request to the do-not-touch
server. It matters because on 1.7.0 the request does not fail, it silently degrades (D2). *What
breaks without an answer:* a build pass could ship, test against a 1.7.0 server, and see
unseekable playback with no error to explain it.

**7.2 `start: 0` or `start: N` for resume?** D7 and §4.3. `start: 0` gives an honest `duration`,
a working `fullyPrepared` and a valid commercial clamp, at the price of remuxing the whole
recording even when resuming near the end. `start: N` is faster but leaves `duration` describing a
file that does not exist. **This is the owner's call because it is a wait-versus-correctness
trade**, and step 7 of the plan is written for `start: 0`.

**7.3 What should the screen say during a multi-minute wait?** Today 6a shows an indefinite
`PulseBar` and "Preparing the recording" (§3.6), and turns into an error at ~25 s. On the file
route the honest wait may be tens of seconds and the ceiling is the server's 10 minutes
(`playfile.go:51`). Any change here is new UI, which this pass is forbidden to build. *What breaks
without it:* a viewer sees a pulsing bar for 30+ seconds with no indication anything is happening.

**7.4 Should a refused recording fall back to HLS automatically, or show the error?** D5 and D6:
a non-H.264/AAC recording and a still-recording one both earn a 502 at POST time with a plain-text
reason. Automatic fallback keeps everything playable and hides the difference; showing the error is
truthful and simpler. **Not designed here** — it is retry logic, explicitly out of scope.

**7.5 Temp space on Unraid.** The MP4 lands under `os.TempDir()` (`playfile.go:55-58`), which in
the container is inside `docker.img`; their own Pass 85 left "a 2.7 GB temp file per concurrent
session" as an unresolved risk. Two Apple TVs watching two long recordings is two such files at
once. *What breaks without an answer:* a full `docker.img` affects every container on the box, not
just this one.

**7.6 Should the marlin-dvr project be asked to document the route in `HLS-CLIENT-API.md`?**
§2.2: the contract is unchanged, still says it describes 1.7.0, and its `format` row (`:68`) states
that anything other than `"hls"` gives the old pipe. Building against undocumented source
contradicts the standing rule that this app is built to the contract. **Raised, not acted on** —
that is a decision for marlin-dvr.

**7.7 Two report files are untracked and one of them was supposed to have been pushed.**
§1: `reports/2026-09-08-pass39-three-defects-recon.md` is untracked and commit `424c584` contains
only `COLD-START.md` and `DECISIONS.md`, although COLD-START.md says Pass 39 pushed the report with
them. **Nothing was done about it** — the scope lock permits exactly one new file this pass. Does
the owner want a later pass to commit it?

**7.8 The one thing no amount of reading can settle.** Whether `AVPlayerItem` tolerates an HTTP
response that sends no bytes for tens of seconds before the first byte arrives. The server blocks
deliberately (`playfile.go:226-253`) and AVFoundation's own network timeouts are not the app's
`URLSession`'s. **Only the Apple TV can answer this**, and it is the single riskiest unknown in the
whole plan.

---

## 8. SCOPE CHECK — every file touched or created

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md` | read | required reading |
| `DECISIONS.md` | read | required reading |
| `reports/2026-09-08-pass39-three-defects-recon.md` | read only; **not staged, not committed** | required reading; §1 |
| `reports/2026-09-08-pass40-session-start-values.md` | **not opened**; status reported from `git status` only | step 1 |
| `Marlin DVR TV/*.swift` (47 files enumerated; 9 read) | **read only** | step 3 |
| `Marlin DVR TVUITests/*.swift` (12 files, listed only) | listed | step 3 enumeration |
| `~/Xcode/marlin-dvr-reference` | `git fetch origin` + `git show origin/main:…` + `git log`/`git diff` on refs. **No checkout, edit, commit, push, or run.** Checkout `9325d94` and working tree (`?? README-REFERENCE.md`) identical before and after | step 2 |
| `reports/2026-09-08-pass41-single-file-route-recon.md` | **created — the only write** | DELIVERABLE, step 6 |

**Not touched:** every other folder under `~/Xcode`; the server and its API at
`192.168.1.250:8090` (zero requests of any kind); Unraid `192.168.1.250`; marlinpc `192.168.1.245`;
the HDHomeRun `192.168.1.105`; the UNAS4Pro share; `design/`; every Swift source, the Xcode project,
`Info.plist`, the entitlements file and `build/`.

**Nothing was built, run, installed or added.** No dependency of any kind. No credential, token,
device id or account identifier appears in this report.

---

## CLOSING SUMMARY FOR THE OWNER

**The headline: this is a small change to our code that fixes three of your problems at once — and
it is blocked on something that is not code.**

The change on our side is genuinely small. The app has exactly **one line** that chooses the
playback format (`PlaybackSession.swift:51`, `format: "hls"`), and exactly **one place** that turns
a session into something the player can show (`PlayerModel.attach`). The response model already
decodes every field the new route returns, without a single edit. Roughly seven small steps, all in
three files, and live TV, cameras and radio need no change at all.

**What it fixes.** The **LIVE badge** on a recording goes, because it was never ours to draw —
it is Apple's, shown because we hand it an unfinished playlist, and a finished MP4 gives it nothing
to draw. **The wait before fast-forward works** goes, because the whole file is seekable from the
first second instead of only the part the server has written so far. **The resume overshoot** goes,
because a file has no "live edge" for the player to jump to. And the **erratic frame stepping near
the end** very probably goes too, because the restart we suspected of causing it can no longer
trigger. Four of the items on the backlog, from one change.

**What it costs.** The wait does not disappear — it moves to the front. Today a recording starts in
about a second and you cannot skip for a while; afterwards, you wait while the server rebuilds the
file, then everything works properly. Their measurements on their own PC were 2.4 s for an
8-minute show, 11 s for a 43-minute one and 26 s for a 1 h 42 m one — but **nobody has measured it
on your Unraid box**, and the recordings moved to the array since. Two kinds of recording would
stop playing on this route entirely and need to stay on the old one: anything that is not
H.264/AAC, and anything still recording.

**What this pass cost.** Read-only throughout. Four `git` reads here, one `git fetch` in the
reference clone and about twenty `git show`/`git log` reads out of it, nine Swift files read
closely and 47 enumerated, and one file written — this report. Nothing was built, nothing was run,
no simulator, no device, and **not one request to the server**.

**The three things I am least certain about.**

1. **Whether the new server is actually running.** Their own Pass 88 report says it was published
   to the registry but **not installed** — you install it by pressing the button on the Status
   page. I am not allowed to ask the server which version it is. And this matters more than it
   sounds: if we send the new request to the old server, it does not complain — it quietly gives
   back the old, unseekable stream with a perfectly normal-looking success. That is question 7.1
   and it should be answered before anyone builds.
2. **Whether the Apple TV will sit still through the wait.** The server deliberately answers
   nothing at all until the file is ready. Our own first request would give up after 25 seconds
   today, which the plan fixes — but whether Apple's video player tolerates a silent connection for
   half a minute is something no amount of reading the code can tell me. Only the Apple TV can.
3. **Whether the frame-stepping fix is real.** The notebook names our restart as the *suspect*, not
   the proven cause. Removing it should fix the symptom, and I have shown it can no longer fire —
   but if the real cause was something else in how the player handles exact seeks near the end,
   this changes nothing there.

**My recommendation:** answer question 7.1 first — it is one glance at the Status page, and it
decides whether a build pass is worth scheduling at all.
