# Pass 69 — the server's 1.8.1 report, checked against this app

**Date:** 2026-09-11
**READ-ONLY. Nothing was changed, built, installed or created in the repo.** No Swift file was
written. No file was written anywhere inside `~/Xcode/Marlin DVR TV`. No commit, no push, no
`git add`. **Not one request of any kind was sent to `192.168.1.250:8090`** — no GET, no POST, no
`/api/system`, no `/api/settings`. Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share and
`design/` were not touched. The reference clone was read **only** with
`git show origin/main:<path>` — no fetch, no checkout, nothing run from it.

**Tree state at the end of this pass, unchanged from its start:** `git status --porcelain
--untracked-files=all` lists **only the 32 entries under `icon-source/`**, exactly as
`DECISIONS.md` 2026-09-08 (Passes 51-55) records them. No tracked file is modified.

**One note on where this report lives.** The pass ordered "Report only… Change nothing… tree clean
apart from `icon-source/`" and also "Nothing committed, nothing pushed". Writing this file into
`reports/` would have left the tree not clean, and committing it was forbidden, so **the report is
this response** and a copy sits in the session scratchpad outside the repo. Pass 68's standing rule
("a pass writes its report and commits it before pushing") is not broken, only unreachable this
pass. **Whether a later pass should commit this report into `reports/` is the owner's call.**

---

## 0. Required reading — what was read

| Named in the brief | Present | Read |
|---|---|---|
| `COLD-START.md` | 1,088 lines | in full |
| `DECISIONS.md` | 944 lines | in full |
| `CLAUDE.md` | 14 lines | in full |
| `reports/2026-09-08-pass41-single-file-route-recon.md` | 999 lines | in full |
| `reports/2026-09-08-pass42-single-file-route.md` | 378 lines | in full |
| `reports/2026-09-08-pass43-push-notebook.md` | 336 lines | in full |
| `reports/2026-09-08-pass44-push-untracked-reports.md` | 290 lines | §§1-4 |
| `reports/2026-09-08-pass45-cold-start-corrections.md` | 282 lines | §§1-5 |

Every line number below was read from the files **as they stand at `HEAD` = `9445179`**, not
inherited from an earlier report. Where an earlier report's citation has since moved, both numbers
are given.

---

## 1. The JSON body this app sends to `POST /api/play/sessions` for a recording

**There is exactly one construction site in the app.** `grep -rn "play/sessions" --include="*.swift" .`
returns one request being built: `PlaybackSession.swift:71`. Every other hit is a comment, a
`DELETE` (`:145`) or the session-log `GET` (`:159`).

**The body type — `PlaybackSession.swift:60-66`**, five fields, all non-optional, no custom
`CodingKeys`:

```swift
private struct CreateBody: Encodable {
    let kind: String
    let id: String
    let format: String
    let client: String
    let start: Double
}
```

**Where it is filled — `PlaybackSession.swift:70`**, the one line:

```swift
let body = CreateBody(kind: request.kind, id: request.targetID, format: request.format, client: clientID ?? "", start: request.startSeconds)
```

It is encoded at **`PlaybackSession.swift:74`** with a plain `JSONEncoder()`. Because the struct
declares no `CodingKeys`, the five property names above **are** the five JSON keys, and there are no
others.

### Key by key, for a recording

| Key | Value it carries | Where the value comes from |
|---|---|---|
| `kind` | `"recording"` | `PlayRequest.kind`, `PlayRequest.swift:26-32`, recording arm at **`:29`** |
| `id` | the library recording id — `episode.id` | `PlayRequest.targetID`, `:55-61`, recording arm at **`:58`**; `Episode.id` is `Models.swift:339` |
| `format` | **`"file"`** | `PlayRequest.format`, `:46-52`, recording arm at **`:49`** — `case .recording: return "file"` |
| `client` | the client id persisted in `UserDefaults` under `"marlinClientId"`, or `""` if absent | `PlaybackSessionClient.clientID`, `PlaybackSession.swift:58`; key at `ClientSession.swift:17`; the `?? ""` is at `PlaybackSession.swift:70`. **Redacted here and not read from any device.** |
| `start` | the resume position in seconds, as a JSON number | `PlayRequest.startSeconds`, `:64-67`, reading the `start` of `case .recording` (`:14`) |

**So the body is, in shape:**

```json
{"kind":"recording","id":"<recording id>","format":"file","client":"<REDACTED client id>","start":<seconds>}
```

### Is `"format":"file"` among them? — **Yes. Always, for every recording, unconditionally.**

`PlayRequest.format` (`:46-52`) is a pure switch on the enum case. The recording arm returns the
literal `"file"` at **`:49`** and there is no other arm it can take: `.live` returns `"hls"` at
`:48` and `.camera` at `:50`, and the switch has **no `default`**. There is no setting, no
`UserDefaults` read, no feature flag, no server probe and no fallback anywhere in that property or
at the call site — `PlaybackSession.swift:70` passes `request.format` straight through.

A recording cannot stop being a recording on the way to the wire, either: the two functions that
rewrite a request keep the case (`PlayRequest.replacing(episode:start:)` **`:114-117`** and
`PlayRequest.withStart(_:)` **`:120-123`** both reconstruct `.recording`).

**Both callers of `create(_:)` go through that one line** — `PlayerModel.swift:118` in `start()` and
`PlayerModel.swift:759` in `startAgain(at:)`.

### Where `start` comes from, since it is the only value that varies

Every recording enters through one funnel, **`ShowDetailScreen.swift:148-150`**
(`onPlay(.recording(episode:show:start:))` at `:149`), which has three callers:

- **`:177`** — Resume, `play(resume.episode, from: resume.entry.position)`
- **`:188`** — "Play newest", `from: ResumeStore.entry(for: newest.id)?.position ?? 0`
- **`:236`** — an episode row, same shape

plus two paths created inside the Player: auto-play-next at **`PlayerScreen.swift:101`**
(`replacing(episode: next, start: 0)`) and the restart at **`PlayerModel.swift:752`** →
**`:759`** (`request.withStart(target)`).

---

## 2. Which URL the app then plays — **the `url` field from the response, never one it builds**

- The response decodes into `PlaySession` (**`Models.swift:497-507`**), whose `url` is an untyped
  `String` at **`:499`**.
- `start()` resolves it at **`PlayerModel.swift:130`** — `ServerConfig.resolve(created.url)` — and
  `startAgain(at:)` at **`:764`**.
- `ServerConfig.resolve` (**`ServerAPI.swift:22-25`**) is `URL(string: path, relativeTo: baseURL)`
  against `http://192.168.1.250:8090` (**`ServerAPI.swift:15`**). It adds no path of its own.
- That URL is handed to the player at **`PlayerModel.swift:152`** (`attach(url)`) and
  **`:779`**, and `attach` builds the item at **`PlayerModel.swift:191`** —
  `AVPlayerItem(url: url)`. **That is the only `AVPlayerItem` in the Player**
  (`grep -rn "AVPlayerItem(" --include="*.swift"` finds one other, `RadioPlayer.swift:113`, which is
  radio and never a play session).
- The **same** URL is given to the keep-alive at **`:153`** and **`:780`**
  (`PlaybackSession.keepAlive`, **`:130-141`**).

**The app builds no playback URL anywhere.** `grep -rn "index.m3u8\|m3u8\|video.mp4\|play/file\|play/hls\|play/s/" --include="*.swift" .`
returns exactly **two hits, both comments** — `Models.swift:499` and `PlaybackSession.swift:99`.
There is no string concatenation, no `URLComponents`, no path appended to the session id.

**Device evidence (Pass 42 §4b, Home Theater, 2026-09-08):** the server answered
`"url":"/api/play/file/smttdw891e10096/video.mp4"` and the console line was
`[diag42] player handed URL: http://192.168.1.250:8090/api/play/file/smttdw891e10096/video.mp4
(asked file, got file)`.

---

## 3. The app does send `format:"file"` — what Passes 41-45 proved, and what is out of date

### 3.1 What the five passes proved, and how

**Pass 41 (recon, read-only, `reports/2026-09-08-pass41-single-file-route-recon.md`).** It
established the route **from the server's own Go source** because the contract does not describe it:
`HLS-CLIENT-API.md` is byte-unchanged across the whole 1.8.0 delivery (`git diff --stat c417c60
095de81 -- HLS-CLIENT-API.md` returned nothing, Pass 41 §2.2), still declares itself 1.7.0, and its
§2 table at line 68 says the opposite — `"file"` appears nowhere in it. §2.3 is the only written
description of the route either project has. §3.1 measured the app's then-state: **`format` was
hardcoded to the literal `"hls"`** at the single construction site, and §3.2 measured that the
response's `format` field was decoded and **read by nothing**. §2.4 D2 is the finding that governed
the build: the server's `format` switch has **no `default` arm**, so a server that does not know
`"file"` answers **200** with the old unseekable pipe and only that field says so. §5 is the
seven-step build plan.

**Pass 42 (the build, `reports/2026-09-08-pass42-single-file-route.md`).** Steps 1-6 built in three
files; step 7 deliberately not built because it is conditional on open question 7.2. Proved on Home
Theater with the existing Pass 38 harness (`TEST SUCCEEDED`, 67.4 s, 0 failures) on a finished
43-minute, 1.12 GB Philo recording, captured with three disclosed `print` statements:

- the request carried **`"format":"file"`**;
- the response carried **`"format":"file"`** with `"url":"/api/play/file/smttdw891e10096/video.mp4"`;
- the first fetch answered **206**; the keep-alive answered **206 throughout and never 410**;
- commercial skip landed **exactly** on the break's `endSeconds` (`t=272.538500`, reported
  `position 1478.54 s of 2570.57 s`);
- the `DELETE` was accepted (200);
- **no `[player] route refused` line appeared** — the `format` check passing.

The diagnostic was then **fully reverted**, and the reverted build was rebuilt, reinstalled and
re-run on the device: **it still took the file route** (`[player] first fetch (file) → 206`,
keep-alive 206 through #14).

**Pass 43 (acceptance and push, `reports/2026-09-08-pass43-push-notebook.md`).** The owner tested
Pass 42 on Home Theater on 2026-09-08 and reported everything works and **the LIVE badge is no
longer there**. Three commits went to `origin/main` as a plain fast-forward from `b11f4c6` —
`137f1de` (the build), `787f01e` (its report), `5755db7` (the notebook) — verified by `git fetch`,
`git rev-parse HEAD`, `git rev-parse origin/main` and `git ls-remote origin main` all reading
`5755db7`.

**Passes 44 and 45 add nothing to the route's evidence, and should not be read as if they did.**
Pass 44 committed the two formerly-untracked reports unmodified (`6fee5b5`, verified on
`origin/main` at `f167663`); Pass 45 corrected two stale sentences in `COLD-START.md`. Neither
touched a Swift file — Pass 44's §8 and Pass 45's header both state it. They are the repo-hygiene
tail of the same day.

### 3.2 What I verified myself this pass, from git rather than from the reports

| Check | Result |
|---|---|
| `git log -S'case .recording: return "file"' -- "Marlin DVR TV/PlayRequest.swift"` | one commit: **`137f1de`** |
| `git log -S'format: request.format' -- "Marlin DVR TV/PlaybackSession.swift"` | one commit: **`137f1de`** |
| `git show -s --format='%H %ad %s' --date=iso 137f1de` | `137f1de1e4…` · **2026-09-08 21:01:06 -0400** · "Pass 42: recordings play as one seekable MP4 (steps 1-6; step 7 blocked)" |
| `git merge-base --is-ancestor 137f1de HEAD` | **yes** |
| `git merge-base --is-ancestor 137f1de origin/main` | **yes** |
| `git rev-parse HEAD` / `git rev-parse origin/main` / `git ls-remote origin main` | all three read **`9445179`** |
| `git diff --stat 137f1de HEAD -- PlayRequest.swift PlaybackSession.swift PlayerModel.swift` | **empty — byte-identical**; no later pass altered the route |
| `PlaySession` at `137f1de:Models.swift:394-404` vs `HEAD:Models.swift:497-507` | identical nine fields; it only moved, because Pass 63's search decoders went in above it |
| `git merge-base --is-ancestor 137f1de 0b3589d` | **yes** — the binary Pass 54 installed on **both** Apple TVs contains the file route |

So the change is not a local experiment: it is on the **public** remote
`marlin1111ai/marlin-dvr-tv`, has been since 2026-09-08, is unmodified since, and is in the build
running on Home Theater and Master Bedroom ATV.

### 3.3 The route exists on their side too, read from their source

From the reference clone, `git show origin/main:<path>` only:

- `cmd/marlin-dvr/main.go:38` — `appVersion = "1.8.0"`.
- `cmd/marlin-dvr/stream.go:376-391` — `switch req.Format` with **`case "file": // Pass 85: one
  seekable MP4, remuxed per play (playfile.go)`** at **`:384`**, `url = playFileURL(x.ID)` at
  `:390`, and the nine-field response written at `:394`.

The clone's `origin/main` is the ref Pass 41 fetched (1.8.0). **It cannot show 1.8.1 and this pass
was forbidden to fetch**, so nothing here is a claim about 1.8.1's source.

### 3.4 What in the server's report is out of date

**(a) The central claim — "no client sends `format:"file"` on the recording session request" — is
false for this app, and has been since 21:01 on 2026-09-08.** Every recording session request this
app has built since that commit carries `"format":"file"` (`PlayRequest.swift:49` →
`PlaybackSession.swift:70`), the code is on `origin/main`, and it is in the binary installed on both
Apple TVs (§3.2).

**Where the claim probably comes from, and when it was true.** Pass 41 §2.4 quotes the marlin-dvr
project's own Pass 87 headline: *"Pass 85 added a third playback output, and nothing calls it. … The
browser UI **cannot reach the new route at all** — it never sends a `format` field."* That was
accurate, and at the moment it was written it was true of **every** client. This app became the
route's first and only client the same evening. A 1.8.1 report repeating it is carrying a fact whose
shelf life ended hours after it was written.

**(b) "The LIVE badge is still live" — closed, on the owner's own eyes.** He tested Pass 42 on Home
Theater on 2026-09-08 and reported the badge gone (`DECISIONS.md` 2026-09-08 (Pass 42);
`COLD-START.md` "Next step"). It was never this app's badge to draw: `PlayerModel.isLive`
(**`PlayerModel.swift:97`**) is the request kind and nothing else, and both of the app's live
indicators — `LiveHUD`'s "LIVE" (**`PlayerScreen.swift:190`**) and `PausedLiveOverlay`'s
"LIVE · HELD" (**`:348`**) — are unreachable for a recording, because `PlayerScreen.swift:79-86`
routes a recording to `RecordingHUD` always. It was `AVPlayerViewController`'s own transport
reacting to an EVENT playlist with no `#EXT-X-ENDLIST`; a finished MP4 gives it nothing to react to.

**(c) "Fast-forward is still refused early in playback" — closed** (owner, 2026-09-08: everything
works). The app's whole notion of what may be seeked to is `seekableRange`
(**`PlayerModel.swift:245-250`**), read from `item.seekableTimeRanges`. A complete faststart MP4
advertises the whole file from the first response, so the two clamps that used to pin a target to
the written edge — `frameStep`'s at **`PlayerModel.swift:390-395`** and `skipCommercialBreak`'s at
**`:530-535`** — stop being restrictive, and `preparedTo` (**`:260`**) reaches `duration` on the
first tick, which makes `fullyPrepared` (**`:101`**) true.

**(d) "Resume overshoot is still live" — closed.** The overshoot was AVPlayer joining a growing
playlist near its live edge (`start=1680` arriving at 1988 s by the fourth tick, Pass 38). Pass 42's
second device run created a session with `start=1484.004768173` and the position arithmetic came out
exactly self-consistent: a skip landed at item time `t=272.538500` while the app reported
`position 1478.54 s`, which is `startOffset + t` and is the break's exact `endSeconds`. Pass 42 §3
records the correction this forced on this project's **own** Pass 41 §4.3 claim — `start: N` does
**not** break `fullyPrepared`, the HUD or the commercial clamp, because the server echoes the same
`start` it trims with.

**(e) One thing the server project may be relying on that is no longer true of this client: a
silent degrade is now impossible.** If a server answers a `"file"` request with anything else, this
app does **not** play it. `routeRefused` (**`PlayerModel.swift:176-181`**), called at **`:135`** and
**`:765`** before anything is fetched, sends it to the Failure state with the text *"The server did
not start a single-file session — it answered format \"<got>\"."* So if 1.8.1 ever stopped honouring
`"file"`, the owner would see an error screen, not the old EVENT playlist and not a LIVE badge.

**(f) The one claim in their area I cannot check, and am not claiming.** Whether the **running**
container is 1.8.1, and what it actually received, are facts about the do-not-touch server. This
pass sent it nothing. Everything above is what the app's code sends, plus Pass 42's device capture
of 2026-09-08.

---

## 4. Where the app displays `recordings` from `GET /api/library` — **two places, and nowhere else**

- Decoded at **`Models.swift:330`** — `let recordings: Int` in `LibraryResponse`
  (**`:327-335`**), **non-optional**.
- The read is **`ChannelFilter.swift:108-112`** — `func library(limit: Int? = nil)` →
  `get("/api/library", query:)`.

**Display site 1 — the Recordings screen header.**
**`RecordingsScreen.swift:86`**: `return "\(lib.shows) shows · \(lib.recordings) recordings"`, the
`subtitle` property at `:84-87`, drawn by `ScreenHeader` at **`:91`**. Its read is
`api.library(limit: 6)` at **`:35`**, and it is re-run by `reloadShelves` (**`:158-168`**) after a
write in show detail.

**Display site 2 — the Home Recordings tile.**
**`HomeView.swift:76`**: `subtitles[.recordings] = "\(response.recordings) recordings · \(recordingNow) recording now"`,
from `api.library()` with **no** limit at **`:39`**; the failure branch is `"unavailable"` at
**`:78`**.

**Nowhere else.** `grep -rn "\.recordings\b" --include="*.swift" "Marlin DVR TV/"` returns only
those two, plus `ManageDVRScreen.swift:82` (`trash = response.recordings`) — which is
`TrashResponse.recordings`, the **array** of `TrashItem` from `GET /api/library/trash`
(**`Models.swift:422-437`**), a different field on a different endpoint. The Trash header counts
that array itself (**`TrashManageView.swift:96-99`**) and never consults the library's number, so
the two are independent and nothing in the app adds them together or compares them.

**What 1.8.1's change does to this app: the two strings show a smaller number, and nothing else.**
The field is a non-optional `Int`, so a change in its **value** cannot affect decoding; nothing in
the app derives, caches, compares or sums it.

**One observation, offered because it cuts in the app's favour.** At 1.8.0 the number was
`recCount := len(a.lib.idx.Recordings)` (`library.go:479`, read from the clone at `origin/main`) —
the whole index, trashed recordings included — while the shelves under the same header are built
from `showSummaries(false)`, which skips trashed recordings (`library.go:409`, cited in
`COLD-START.md` from the marlin-dvr project's 2026-09-08 correction). So the header could count
recordings the shelves below it deliberately did not show. **Excluding trashed makes the app's two
lines more consistent with what is on screen beneath them, not less.** Nothing needs to change here.

---

## 5. Is there any handling for a wait before first byte on a recording? — **yes, one state, and it says nothing about waiting**

**The wait itself.** On the file route the first fetch is `firstFileByte`
(**`PlaybackSession.swift:114-127`**): `Range: bytes=0-0` at **`:116`**, `timeoutInterval =
fileTimeout` at **`:117`**, on a `URLSession` of its own (**`:24`**, built **`:50-54`**) whose
configuration timeout is the same value. **`fileTimeout = 660` seconds** (**`:37`**) — eleven
minutes, above the server's own ten-minute remux ceiling. It is awaited at
**`PlayerModel.swift:143-145`** and **`:770-772`**.

**What is on screen for all of it.** `phase` is `.starting`, set at **`PlayerModel.swift:114`**
(and **`:756`** on a restart), and drawn by `StartingOverlay` — frame 6a —
**`PlayerScreen.swift:48`**, defined **`:112-162`**:

- the show's artwork (**`:121`**, recording branch **`:151-154`**);
- `model.request.title` at 64 pt (**`:123`**) and the subtitle (**`:127-131`**);
- a **`PulseBar`** (**`:133`**, defined **`:165-178`**) — a capsule animated
  `.repeatForever(autoreverses: true)` at **`:175`**. **An indefinite pulse. No percentage, no
  elapsed time, no estimate, no progress of any kind.**
- `model.startingLine` (**`:135`**), which for a recording is the fixed string **"Preparing the
  recording"** (`PlayerModel.swift:156-162`, recording arm **`:159`**);
- and the floor line **"Press Menu to cancel."** (**`:138`** — the 2-6 seconds sentence is the
  `isLive` branch of the same ternary and a recording never sees it).

**There is no spinner and no buffering state, and `AVPlayerViewController` is not even mounted.**
`PlayerHost` is gated on `model.phase == .playing` at **`PlayerScreen.swift:35`**, so Apple's own
loading indicator cannot be on screen during the wait either.
`grep -rn "LikelyToKeepUp\|BufferEmpty\|loadedTimeRanges\|ProgressView\|buffering"` over
`Marlin DVR TV/` finds **no** buffering observer and **no** `ProgressView`; the only "buffering" in
the app is a word in the HUD sentence at **`PlayerScreen.swift:251`**, which is gated on
`!model.fullyPrepared` (**`:250`**) and is therefore **dead text on the file route**, because
`fullyPrepared` (**`PlayerModel.swift:101`**) is true from the first tick (**`:260`**).

**There is no app-side deadline on `.starting`** — the only bound is the 660 s URLSession timeout.
On a timeout `firstFileByte` returns `status: 0` (**`PlaybackSession.swift:125`**), which
**`PlayerModel.swift:148-151`** turns into `fail(status: 0, …)` → `phase = .failed` (**`:688`**) →
`FailureState` (**`PlayerScreen.swift:50`**) reading code **"playback failed"** (**`:415`**) and
title **"Playback stopped"** (**`:425`**).

**And after `attach`, the app stops watching.** `attach` sets `phase = .playing` at
**`PlayerModel.swift:198`** immediately — before any frame is drawn — so a further AVFoundation
stall is whatever `AVPlayerViewController` draws on its own. `timeControlChanged`'s
`.waitingToPlayAtSpecifiedRate` arm (**`:293-294`**) does nothing unless `isLive`.

**So: nothing on screen distinguishes a legitimate remux wait from a stall.** That is exactly what
`COLD-START.md` records as a cost of the route, and it is Pass 41 **open question 7.3**, still
unanswered by any pass.

---

## 6. Does the app handle `410 session ended` on a recording? — **yes, in three places, and they are two different screens**

**(a) 410 while watching — the keep-alive.** `startKeepAlive` (**`PlayerModel.swift:595-616`**) runs
`PlaybackSessionClient.keepAlive` every 10 s (`keepAliveInterval`, **`PlaybackSession.swift:29`**;
the fetch is `Range: bytes=0-0` at **`:132`**) against the same URL the player is using
(**`PlayerModel.swift:153`**, **`:780`**). At **`:610-613`**:

```swift
if status == 410 {
    self.sessionExpired()
    return
}
```

`sessionExpired()` (**`:618-624`**) **saves the resume position for a recording** (**`:620`** →
`saveResume()` **`:819-824`**), detaches the player (**`:621`**), cancels the loop (**`:622`**) and
sets `phase = .expired` (**`:623`**).

**What the user sees:** `ExpiredState` (**`PlayerScreen.swift:51`**, defined **`:469-486`**) — the
code line **"410 · SESSION ENDED"** (**`:477`**), the title **"The stream ended on the server"**
(**`:478`**), the show and episode beneath it (**`:479`**), and for a recording the sentence
**"The session expired. Restart continues from \<clock\>."** (**`:480`**), with two buttons:
**Restart** (**`:482`**, `model.restart()` → `restart(at: nil)`, whose target is `position`,
**`PlayerModel.swift:740-741`**) and **Back** (**`:483`**). Focus lands on "restart"
(**`PlayerScreen.swift:61`**).

**(b) 410 on the POST.** `PlaybackSession.check` (**`:186-194`**) throws
`APIError(kind: .http(status: 410))`, which `start()` catches at **`PlayerModel.swift:123-125`** and
turns into `fail(status: 410, …)` → `phase = .failed`. The user sees **`FailureState`** — code
**"410 · SESSION ENDED"** (**`PlayerScreen.swift:413`**), title **"Playback stopped"** (the
`default` arm, **`:425`**), the server's own text as the body (**`:431`**), and buttons **Back**
(**`:459`**) and **Try again** (**`:460`**).

**(c) 410 on the first fetch.** `firstFileByte` returns `status: 410` with the server's body text
(**`PlaybackSession.swift:120-123`**); `firstFetchSucceeded` (**`PlayerModel.swift:186-188`**)
rejects it and **`:148-151`** calls `fail(status: 410, message: probe.text, …)` — the same
`FailureState` as (b).

**So the app deliberately separates "the session died while I was watching" (`.expired`, Restart at
the saved position) from "it was already dead when I asked" (`.failed`, Back / Try again).**

**Three limits, named rather than implied:**

1. **Only 410 ends the keep-alive loop.** Pass 41 §2.4 **D8** records that the file route answers
   **404** once the session has been dropped from the server's map (`playfile.go:210-215`), and
   410 only while it is still held but inactive (`:216-222`). A 404 from the keep-alive is printed
   at **`PlayerModel.swift:609`** and **nothing branches on it** — the loop keeps running every
   10 s against a session that is gone.
2. **Nothing retries a 410 automatically**, anywhere. Every path above is a screen with buttons.
3. **410 has never been observed on the file route.** Pass 42's device run logged **206 for every
   keep-alive and never 410** (§4b, §4c). All of the above is code-traced for this route.

---

## VERDICT — the server's central claim does not hold for this app

**It is wrong on its face, and it has been wrong since 21:01 on 2026-09-08.** This app sends
`"format":"file"` on every recording session request — one line, `PlayRequest.swift:49`, reaching
the wire at `PlaybackSession.swift:70`, the app's only `POST /api/play/sessions` site. The commit
that did it is `137f1de`, it is an ancestor of `origin/main` (`9445179` on the remote as I read it
this pass), the three files are byte-identical to that commit today, and the binary Pass 54 put on
both Apple TVs contains it.

**The three consequences the report says are "still live" are not.** The LIVE badge and the
fast-forward wait were both tested by the owner on Home Theater on 2026-09-08 and reported closed
(`DECISIONS.md` 2026-09-08 (Pass 42)); the resume overshoot is closed by measurement (Pass 42's
exact `startOffset + t` arithmetic). Two of those three rest on the owner's own eyes, which is the
only evidence that was ever available for them, and the notebook says so.

**The part of the report that is sound, and worth keeping.** Two of its premises are still true and
this app depends on them: their `format` switch has no `default` arm, and their `HLS-CLIENT-API.md`
still documents none of this. **`reports/2026-09-08-pass41-single-file-route-recon.md` §2.3 remains
the only written description of the route either project has** — which is the likeliest reason a
1.8.1 report could be written without knowing it has a client. Pass 41 **open question 7.6** (ask
the marlin-dvr project to document the route in the contract) is still unanswered, and this
contradiction is the best argument yet for answering it.

**What the notebook and the server's report disagree about is a date, not a fact.** Their claim was
true of every client, including ours, until the evening of 2026-09-08.

---

## What I could not determine, and why

1. **What the running 1.8.1 server actually receives and answers.** Every route to that is a
   request to `192.168.1.250:8090`, which this pass forbade and the standing rules put on
   do-not-touch. All playback evidence here is either the app's code or Pass 42's device capture of
   **2026-09-08 against 1.8.0**.
2. **Anything about 1.8.1's source.** The reference clone's `origin/main` is the 1.8.0 ref Pass 41
   fetched (`appVersion = "1.8.0"`, `main.go:38`) and fetching was forbidden, so I could neither
   confirm their `case "file"` survives in 1.8.1 nor read the `recordings` change myself. The
   1.8.1 behaviours I discuss are taken from the brief's description of their report.
3. **Whether the owner's Apple TVs are still running a build with the file route.** The last
   install this notebook records is Pass 54's `0b3589d`, which contains `137f1de` — but no pass has
   checked what is installed today, and Pass 54's build is development-signed with an expiry nobody
   has checked (`COLD-START.md`, Passes 51-55).
4. **Whether a long remux behaves.** Untested since Pass 42 said so: the 660 s timeout, the long
   silent wait (open question 7.8) and anything multi-gigabyte have never been exercised, and the
   wait has **never been measured on the Unraid box** at all.
5. **Both server refusals.** A still-recording recording and a non-H.264/AAC one are 502s that
   reach `fail(...)`; neither has ever been provoked (Pass 42 §4d). So "refused outright" is a
   trace, not an observation.

## What I am least sure of

1. **What the server's 1.8.1 report actually says.** I have not read it — only the brief's summary
   of its central claim. If it says something narrower (for example that *their* web UI sends no
   `format`, which is still true per their own Pass 87, or that nothing had been **observed** in a
   particular log window), then my verdict addresses a claim it did not make. **That is the single
   biggest risk in this report**, and the fix is cheap: put their report in front of me.
2. **Whether their claim is about clients or about sessions they can see.** If 1.8.1 genuinely
   logged no `format:"file"` session, something real is happening — an older build on one Apple TV,
   a log window that caught no recording playback, or a behaviour change in 1.8.1 that makes this
   app fail loudly (`PlayerModel.swift:176-181`) instead of playing. **The app cannot tell those
   apart from here**, and distinguishing them needs one recording played on Home Theater with the
   console attached. I did not do that: this pass was read-only and sends the server nothing.
3. **My reading of the report-file instruction** (§0). The convention says reports live in
   `reports/`; this pass's end-state says the tree must be clean and nothing committed. I chose the
   end-state. If that is wrong, the remedy is one commit in the next pass and nothing is lost.
4. **The 404 gap in the keep-alive** (§6 limit 1). That it matters rests on Pass 41's reading of
   `playfile.go:210-222`, not on anything observed — no 410 and no 404 has ever been seen on this
   route.

---

## SCOPE CHECK — every path touched

| Path | Access |
|---|---|
| `COLD-START.md`, `DECISIONS.md`, `CLAUDE.md` | **read only** |
| `reports/2026-09-08-pass41…` through `…pass45…` (5 files) | **read only** |
| `Marlin DVR TV/*.swift` — `PlayRequest`, `PlaybackSession`, `PlayerModel`, `PlayerScreen`, `Models`, `ServerAPI`, `ChannelFilter`, `RecordingsScreen`, `HomeView`, `ShowDetailScreen`, `ManageDVRScreen`, `TrashManageView`, `ClientSession`, `PlayerHost` | **read only** (plus repo-wide `grep`) |
| `~/Xcode/marlin-dvr-reference` | **`git show origin/main:<path>` only** — `cmd/marlin-dvr/main.go`, `stream.go`, `library.go`. No fetch, no checkout, no edit, nothing run |
| git, this repo | read-only commands only: `log`, `show`, `diff`, `rev-parse`, `merge-base`, `status`, `ls-remote` |
| The session scratchpad | the only place written — this report's copy |

**Not touched:** the Marlin DVR server and its API — **zero requests of any kind**; Unraid
`192.168.1.250`; marlinpc `192.168.1.245`; the HDHomeRun `192.168.1.105`; the UNAS4Pro share;
`design/`; every other folder under `~/Xcode`; every Swift source, the Xcode project, `Info.plist`,
the entitlements file, `build/`, and `icon-source/`.

**No build, no test, no device run, no install, no dependency.** No credential, token, device id or
client id appears in this report — the `client` value of §1 is described and redacted, and was never
read from any device.
