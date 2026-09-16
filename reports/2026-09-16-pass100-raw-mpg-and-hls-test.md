# Pass 100 — raw `.mpg` and HLS as alternatives to the remuxed file

**Date:** 2026-09-16
**Device test on Home Theater. No shipped app code changed** — the whole of it was a disclosed
diagnostic, **fully reverted with `git checkout --` before the commit**, and the reverted build was
rebuilt, reinstalled and relaunched on Home Theater with its launch ping confirmed in the server's
log. The bedroom Apple TV was not touched. `~/Xcode/marlin-dvr-reference` was read, never fetched,
pulled or checked out.

**Server traffic:** GETs on recording and contract routes, the app's own play-session POST/DELETE
traffic, `GET /api/logs` and `GET /api/status`. **No settings, no admin, no other write.**

**HEAD: `b866a0fdd6f93330b84a3f2787a097b11e932348`** (Pass 99), `git status --porcelain` showing
only `?? icon-source/`.

**The request, relayed by the owner on 2026-09-16:** before the server changes anything, test on the
Apple TV whether AVPlayer can play the raw recording `.mpg` served over HTTP with byte ranges and no
remux, and whether HLS can give rewind-to-zero.

---

## THE ANSWERS, so they are not buried

### The raw `.mpg` — not testable, because the server does not serve it

**There is no route on this server that serves a recording's original `.mpg`.** Not in the contract,
not in the routing table, and not on the running 1.8.2 server when asked directly. **Steps 2–5 were
therefore skipped**, as step 1 instructs, and no number in this report is a raw-`.mpg` number.
**Nothing was built to make one** — the server is not this project's to change. §1 has the evidence.

### HLS — yes to rewind-to-zero, and it is fast, but the old defects come back

Measured on Home Theater with the pre-Pass-42 HLS route and `start: 0`:

- **Rewind to zero works and is exact.** `asked 0.00 s → landed t=0.000`, in **0.184 s** and
  **0.176 s** on the two subjects. The seekable range starts at **0.00** from `.readyToPlay`.
- **Every seek is exact and fast once the range is complete** — to the saved position, to 20:00, to
  60:00, back to 0:00: **all landed on the asked second to three decimals, in 0.162–0.239 s.**
- **Press to picture is 0.647 s and 0.814 s** against the file route's **10.916 s** and **7.567 s** —
  **13× and 9× faster**, because there is no remux to wait for.
- **But the seekable range is not there at the start.** At `.readyToPlay` it is **0…172.18 s** of a
  42:51 recording and **0…216.23 s** of a 1:42:18 one. It reaches the whole recording somewhere
  between +8 s and +30 s.
- **So Pass 96's resume seek fails on HLS.** It fires at `.readyToPlay` and is clamped to the written
  edge: **asked 1485.00 s, landed 172.13 s**; **asked 4498.00 s, landed 216.18 s**. A resumed
  recording would start near the beginning instead of where he left off.
- **The LIVE badge is back, and it never goes away.** Photographed on Apple's transport over a
  recording at +5 s **and still there at +40 s with the whole recording seekable**.
- **`canPlayFastForward` is false at `.readyToPlay` and still false at +30 s.**
  `canStepForward`/`canStepBackward` are false throughout, as Pass 27 measured.
- **The frame-rate reading goes unstable.** HLS exposes no `assetTrack`, so the app falls back to
  `currentVideoFrameRate`, and it **adopted 25.0000 fps three times** during the run — a frame step
  of 0.040000 s instead of 0.033367 s.

---

## 1. Step 1 — is there a route that serves the original `.mpg`?

**No. Three independent checks, all negative.**

**a. The contract does not describe one.** `HLS-CLIENT-API.md` §8 *"What is not there"* lists what
is missing and names only the fragmented-MP4 route: *"The fragmented-MP4 route
`GET /api/play/s/{id}.mp4` … still exists unchanged and is what the browser uses; it is a chunked,
length-less stream with no seeking."* No section of the contract mentions the original file.

**b. The routing table has no such route.** All 102 `mux.HandleFunc` registrations in
`cmd/marlin-dvr/main.go` were read. Every file-serving site in the server is one of four:

| Site | What it serves |
|---|---|
| `hls.go:359` | HLS playlist, `init.mp4`, `segNNNNN.m4s` — session-scoped |
| `playfile.go:269` | the **remuxed** `video.mp4` in the session's temp folder |
| `library.go:1127` | a recording's **thumbnail** JPEG |
| `artwork.go:470` | cached artwork |
| `main.go:195` | `staticHandler(webDir)` — the **web UI folder only** (`main.go:356`) |

**The recordings root is never mounted.** Even the server's own web player creates a session:
`web/watch.html:86` POSTs `/api/play/sessions` and `:88` sets `video.src = session.url`.

**One near miss, worth passing back to them.** `rss.go:88` advertises an enclosure URL of
`base + "/api/play/recording/" + rec.ID + ".mp4"` — **and no such route is registered.** It is a
dead URL in their own RSS feed.

**c. The running 1.8.2 server answers 404 to every spelling.** Twenty GETs with `Range: bytes=0-0`,
ten per subject:

```
404  /api/play/recording/<id>.mp4          404  /api/library/recordings/<id>/raw
404  /api/play/recording/<id>              404  /api/library/recordings/<id>/download
404  /api/library/recordings/<id>/file     404  /api/library/recordings/<id>.mpg
404  /api/library/recordings/<id>/video.mpg 404 /api/library/recordings/<id>
404  /api/library/recordings/<id>/media    404  /api/library/recordings/<id>/stream
```

**The probe method is sound**, proved by four controls on the same server in the same minute:

```
200  /api/library/recordings/5328bb632e76/commercials
200  /api/library/recordings/5328bb632e76/mediainfo
200  /api/library/recordings/5328bb632e76/thumb.jpg
200  /api/play/info?rec=5328bb632e76
```

**`GET /api/status` at the time of the probe:**
`{"name":"marlin-dvr","version":"1.8.2","uptime_seconds":211499,"port":8089}`.

### 1.1 What steps 2–5 would have measured, and what stands in their place

| Step | The question | Status |
|---|---|---|
| 2 | Raw `.mpg` press → picture, split three ways | **Not run** — no route |
| 3 | Exact seeks to 20:00, 60:00 and 0:00 on the raw `.mpg` | **Not run** — no route |
| 4 | Resume on the raw `.mpg` by seeking once ready | **Not run** — no route |
| 5 | Raw `.mpg` A/V alignment, and seeks to each break's `endSeconds` | **Not run** — no route |

**Nothing was substituted for them.** The recordings live on the UNAS4Pro share, which `CLAUDE.md`
puts out of bounds, so serving one from the Mac to fake the route was not an option and was not
attempted. **If the marlin-dvr project adds a byte-range route for the original file, every one of
steps 2–5 becomes a short device run** — the harness shape is in §2 below and would need only the
URL changed.

---

## 2. Step 6a — what the HLS route did not do for recordings, from the record

Each with the file and the quote, read at this HEAD.

| # | What HLS did not do | Where it is recorded |
|---|---|---|
| 1 | **Remove the LIVE badge from a recording.** | Pass 41 §4.1: "the badge is `AVPlayerViewController`'s own transport, **drawn because the EVENT playlist never gets `#EXT-X-ENDLIST`**" |
| 2 | **Allow a scrub or fast-forward early in playback.** | Pass 41 §4.2: "On a growing EVENT playlist only the written part is advertised, so early in playback the range is short … **while Apple's own transport refuses a scrub past it for the same reason**" |
| 3 | **Resume where it was asked to.** | COLD-START, *Known and unfixed*: "A resumed recording starts well past its resume point … `start=1680` was at **1988 s** by the fourth tick. Recordings are an HLS EVENT playlist the server is still writing and **AVPlayer joins it near the live edge**" (Pass 38) |
| 4 | **Let `AVPlayerItem` step a frame.** | DECISIONS (Pass 28): "inert on this app's HLS recordings — **`canStepForward` and `canStepBackward` both false**"; measured in `reports/2026-09-07-pass27-framestep-recon.md:90` |
| 5 | **Seek past the written edge without a new session.** | `PlayerModel.timeJumped()` exists only for that: "A user seek … to the end of the prepared range while the recording is not fully segmented → DELETE, new session at that position, player at 0 (contract §3; standing call)" |
| 6 | **Give a definite duration to the item.** | Pass 41 §4.2: "`preparedTo` … becomes `startOffset + duration` on the first tick" only on the file route; the HUD's "Prepared to …" line exists for the HLS case (`PlayerScreen.swift:250-251`) |

**All six were re-measured this pass. Five are confirmed still true; one — number 3 — is now
measured precisely rather than as an overshoot.** See §3.

---

## 3. Step 6b — HLS on Home Theater, measured

Two sessions, both `format=hls`, `start=0.0`, driven by the Siri Remote through a disclosed probe,
with the app's console captured by `xcrun devicectl device process launch --console`.

### 3.1 Press to picture

| Leg | `5328bb632e76` · 42:51 | `d9a4f5c76696` · 1:42:18 |
|---|---|---|
| Press → POST answered | 0.059 s | 0.049 s |
| → first bytes (playlist, 200) | +0.206 s | +0.408 s |
| → item `.readyToPlay` | +0.381 s | +0.288 s |
| → **first frame drawn** (`timeControlStatus` → `.playing`) | +0.002 s | +0.068 s |
| **Press → picture** | **0.647 s** | **0.814 s** |

**There is no remux leg at all.** The server starts ffmpeg and serves the playlist as it segments;
its own log records the sessions starting at 14:50:37.684 and 14:53:04.704 with **no "remux
finished" line**, because the file route's remux is the only thing that produces one.

### 3.2 The seekable range grows — and this is the whole catch

```
[p100] at .readyToPlay: seekable 0.00…172.18 (172.18 s wide), duration(item)=nan,
       canPlayFastForward=false, canStepForward=false
[p100] t+8 s:  seekable 0.00…2570.57 (2570.57 s wide)
[p100] t+30 s: seekable 0.00…2570.57 (2570.57 s wide), canPlayFastForward=false,
       canPlayReverse=false, canStepForward=false, canStepBackward=false
```

and on the longer recording:

```
[p100] at .readyToPlay: seekable 0.00…216.23 (216.23 s wide)
[p100] t+8 s:  seekable 0.00…3967.98 (3967.98 s wide)    ← still not the whole 6138.13 s
[p100] t+30 s: seekable 0.00…6138.13 (6138.13 s wide)
```

**The range starts at 0.00 in both** — that is what makes rewind-to-zero possible — but its end
takes between 8 and 30 seconds to reach the recording's duration. The mechanism is in the server's
own source: recordings are an **EVENT** playlist, `-hls_playlist_type event`
(`cmd/marlin-dvr/hls.go:78`), "every segment kept for the life of the session … `#EXT-X-ENDLIST`
when ffmpeg" finishes (`hls.go:36-37`).

**`item.duration` is `nan`** on HLS. The app's HUD is right anyway because it uses the session's
`duration`, not the item's.

### 3.3 The resume seek fails on HLS

Pass 96's resume seek fires at `.readyToPlay` and clamps to `seekableRange`. On HLS that range is
still short, so:

```
[resume] will seek to 1485.00 s once the item is ready
[resume] asked 1485.00 s, landed t=172.132989 → position 172.13 s of 2570.57 s

[resume] will seek to 4498.00 s once the item is ready
[resume] asked 4498.00 s, landed t=216.177000 → position 216.18 s of 6138.13 s
```

**Asked 1485 s, got 172 s. Asked 4498 s, got 216 s.** This is record item 3 of §2, measured exactly:
not an overshoot past the resume point but a **clamp far short of it**. On HLS the app would have to
wait for the range to cover the target before seeking, which nothing in the shipped player does.

### 3.4 Once the range is complete, every seek is exact and fast

| Seek | `5328bb632e76` | `d9a4f5c76696` |
|---|---|---|
| to the saved position | asked 1485.00 → **landed 1485.001**, 0.174 s | asked 4498.00 → **landed 4498.000**, 0.239 s |
| to 20:00 | asked 1200.00 → **landed 1200.000**, 0.167 s | asked 1200.00 → **landed 1200.000**, 0.185 s |
| to 60:00 | — (recording is 42:51) | asked 3600.00 → **landed 3600.000**, 0.162 s |
| **back to 0:00** | asked 0.00 → **landed 0.000**, 0.184 s | asked 0.00 → **landed 0.000**, 0.176 s |

Every one with both tolerances `.zero`, `rate=1.00` and `likelyToKeepUp=true` two seconds later, so
the picture was present and playing after each. **This is the direct answer to "can HLS give
rewind-to-zero": yes, exactly, in under two tenths of a second — once the range is there.**

### 3.5 The LIVE badge is back, and it stays

`100-transport-early-short-range.jpg` — paused at +5 s, seekable range still short: Apple's transport
draws a **red `LIVE` badge** beside "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY", with the app's own
HUD above it reading "1:08 of 42:51".

`100-transport-full-range.jpg` — paused at +40 s, **the whole recording seekable**: the badge is
**still drawn**. It does not clear when the range completes.

**This also settles the ambiguity Pass 42 §4b flagged.** That pass could not tell a dumped `"LIVE"`
string from a drawn badge and the owner settled it by eye. Here the string and the badge are both
present and photographed, on HLS; on the file route the owner confirmed on 2026-09-08 that the badge
is gone.

### 3.6 Fast-forward, frame stepping and the frame rate

- **`canPlayFastForward` is `false` at `.readyToPlay` and still `false` at +30 s**, with the whole
  recording seekable. `canPlayReverse`, `canStepForward` and `canStepBackward` are false too — which
  matches `reports/2026-09-07-pass27-framestep-recon.md:90` exactly.
- **Two Right presses on the transport moved playback 0:06 → 0:31**, so Apple's ±10 s *skip* works;
  it is *fast-forward* (a rate change) that the item refuses. The final word on how that feels is
  the owner's transport, not a flag.
- **The frame-rate reading is unstable on HLS.** The app falls back to `currentVideoFrameRate`
  because HLS exposes no `assetTrack`, and across the run it adopted **25.0000 fps three times**
  (`currentVideoFrameRate read 25.7595`, `25.9421`, `25.2455`) and 29.9700 the rest of the time. At
  25 fps a frame step is **0.040000 s** instead of 0.033367 s. On the file route Passes 96 and 98
  both read a stable `nominalFrameRate` of 29.9700.

---

## 4. Step 7 — the three routes side by side

"File route" numbers are Pass 96's, measured on the same two subjects and cited, not re-run here
(`reports/2026-09-16-pass96-resume-whole-recording.md` §3.2).

| | **File route** (shipped) | **HLS, `start: 0`** (this pass) | **Raw `.mpg`** |
|---|---|---|---|
| Press → picture, 42:51 | **10.916 s** | **0.647 s** | **no route — not testable** |
| Press → picture, 1:42:18 | **7.567 s** | **0.814 s** | — |
| Press → `.readyToPlay`, 42:51 / 1:42:18 | 10.732 s / 7.250 s | **0.646 s / 0.746 s** | — |
| Wait for server work before the first byte | 10.233 s / 6.429 s (whole-file remux) | **0.206 s / 0.408 s** (none) | — |
| Seekable at `.readyToPlay` | the whole recording | **0…172.18 s / 0…216.23 s** | — |
| Seekable at +8 s | whole | 0…2570.57 / 0…3967.98 | — |
| Seekable at +30 s | whole | whole | — |
| Resume seek at `.readyToPlay` | **lands exactly** (asked 931.00 → 931.001633) | **clamped short**: 1485.00 → 172.13; 4498.00 → 216.18 | — |
| Seek to the saved position, range complete | already there | **exact**, 0.174 / 0.239 s | — |
| Seek to 20:00 / 60:00 | not measured | **exact**, 0.167 / 0.185 / 0.162 s | — |
| **Rewind to 0:00** | reached by scrubbing (Passes 96, 98) | **exact, 0.184 / 0.176 s** | — |
| LIVE badge on a recording | **gone** (owner, 2026-09-08) | **drawn, and stays at +40 s** | — |
| `canPlayFastForward` | not measured | **false throughout** | — |
| `canStepForward` / `canStepBackward` | not measured | **false** (as Pass 27) | — |
| Frame-rate source and stability | `nominalFrameRate`, stable 29.9700 | `currentVideoFrameRate`, **adopted 25.0000 three times** | — |
| `item.duration` | finite | **NaN** | — |
| Server work per play | whole-file remux, 2.1–10.2 s | progressive segmenting, no wait | — |

---

## 5. Step 8 — the revert, and what the evidence cost

**The diagnostic was reverted with `git checkout --`**, which is byte-exact, on
`PlayRequest.swift`, `ShowDetailScreen.swift` and `PlayerModel.swift`, and `Probe100.swift` was
deleted. `grep -rn "Probe100\|PASS 100 DIAGNOSTIC\|p100"` over both targets returns nothing, and
`PlayRequest.format` reads `case .recording: return "file"` again. The reverted build was rebuilt,
reinstalled and launched; **its launch ping is in the server's log at 14:59:56.480**, after the
diagnostic build's at 14:49:51.736.

**Saved positions — and this is the real cost of the pass.** Read off the device with
`xcrun devicectl device copy from` into the session scratchpad, never committed (the plist also
holds a credential key, which was neither printed nor copied here):

| | before | after |
|---|---|---|
| `5328bb632e76` | 1485.001 s | **32.004 s** |
| `d9a4f5c76696` | 4498.000 s | **76.000 s** |
| every other entry | unchanged | unchanged |
| entries | **12** | **12 — none cleared** |

**Nothing was cleared, but both subjects' positions were moved to near the start**, because the
probe's seek script ends at 0:00 and playback then ran on from there before the app saved. The two
numbers above are recoverable by hand if the owner wants them back; **nothing was written to the
device to restore them**, because no step authorised writing to the app's container.

---

## 6. What was not driven on the device

- **Everything about the raw `.mpg`** (§1.1). Not traced either — there is nothing to trace: the
  route does not exist, so there is no code path to read.
- **The file-route numbers in §4** are Pass 96's, cited, not re-run. Only the HLS column and the
  raw-`.mpg` column are this pass's.
- **HLS A/V alignment** was not measured. Step 5's sync question belonged to the raw `.mpg`, and
  nothing in this pass measured first audio and video timestamps on any route; the desync remains
  where Pass 39 put it (NOT OURS).
- **Seeks to each break's `endSeconds`** (step 5) were not run on any route this pass; Pass 98
  measured one on the shipped file route (armed at 1273 s, landed 1482 s against 1478.54 s).
- **The bedroom Apple TV** was not touched and still runs `4396d84`.

---

## 7. Open questions

1. **Is a byte-range route for the original `.mpg` worth adding?** This pass cannot say — it could
   not test one. What it can say is that the question is **entirely on the marlin-dvr side** until
   such a route exists, and that the harness to test it would be short.
2. **`rss.go:88` advertises `/api/play/recording/{id}.mp4`, which is not a registered route.** Their
   RSS feed carries a dead enclosure URL. **Raised here, not sent to them.**
3. **If HLS were ever chosen, the resume seek would need to wait for the range.** Nothing in the
   shipped player does that, and nothing was built here.
4. **The LIVE badge on HLS never clears**, even with the whole recording seekable — so an
   `#EXT-X-ENDLIST` at the end of segmenting may not be enough on tvOS 26.6. That is their Pass 84
   open question 3, and this pass did not test a playlist with `ENDLIST` present.
5. **Nothing here is a recommendation.** The owner asked for measured numbers either way and that is
   what this is.

---

## 8. The three things I am least sure of

1. **That "first frame drawn" is really the first frame.** It is `timeControlStatus` reaching
   `.playing`, which is a proxy: AVFoundation reports it when it starts the timebase, and the panel
   may light a fraction later. It lands 0.002 s and 0.068 s after `.readyToPlay`, which is fast
   enough that the proxy could be hiding a real gap. The `.readyToPlay` row in §4 is the harder
   number.
2. **That the 8-to-30-second range growth generalises.** It was measured twice, on one Apple TV, on
   one server, with warm files — the same 1.09 GB recording the file route remuxed in 2.1 s warm and
   10.2 s cold. On a cold cache the HLS range would very likely fill more slowly, and **that case was
   not measured**.
3. **That `canPlayFastForward: false` means what the owner experiences as "fast-forward doesn't
   work".** The flag was false throughout, and two Right presses still skipped 10 s each. Which of
   those the owner meant when he reported the defect in 2026-09-08 is not settled by this pass.

---

## 9. Files touched, mapped to steps

| Path | What happened | Step |
|---|---|---|
| `~/Xcode/marlin-dvr-reference` (`main.go`, `hls.go`, `playfile.go`, `library.go`, `artwork.go`, `rss.go`, `web/watch.html`, `HLS-CLIENT-API.md`) | **read only** | 1, 3 |
| `http://192.168.1.250:8090` — 24 GETs on recording/contract routes, `GET /api/logs`, `GET /api/status`, plus the app's own session traffic | request only | 1, 3, 8 |
| `Marlin DVR TV/PlayRequest.swift`, `ShowDetailScreen.swift`, `PlayerModel.swift` | diagnostic added, **reverted with `git checkout --`** | 6, 8 |
| `Marlin DVR TVUITests/Probe100.swift` | created, **deleted** | 6, 8 |
| `reports/assets/pass100/*.jpg` | **created** — 7 screenshots | 6 |
| Home Theater | diagnostic built/installed/run twice; committed build rebuilt, reinstalled, relaunched | 6, 8 |
| `DECISIONS.md`, `COLD-START.md` | **updated** | 9 |
| `reports/2026-09-16-pass100-raw-mpg-and-hls-test.md` | **created** | 9 |

**Not touched:** the bedroom Apple TV, `design/`, the Xcode project file, the Unraid host, marlinpc,
the HDHomeRun, the UNAS4Pro share. No `GET /api/settings`, no admin route, no server write.

## 10. Git

Built from `b866a0f` (Pass 99). This pass's one commit carries this report, its screenshots,
`DECISIONS.md` and `COLD-START.md` — **no app-target or test-target file is in it**, because the
diagnostic was reverted. This pass's own SHA is not written here and cannot be
(DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 100 response.
