# Pass 95 — resume gives no way back to before the resume point: read-only recon

**Date:** 2026-09-16
**READ-ONLY.** No Swift file, test file, project file, `Info.plist`, entitlements file or asset was
modified. **Nothing was built** — no diff, no stub, no disabled branch. The files this pass writes
are this report, `COLD-START.md` and `DECISIONS.md`, committed together.
**No request of any kind was made to `http://192.168.1.250:8090/` this pass** — not a GET.
`~/Xcode/marlin-dvr-reference` was read with `sed` and `grep` only — never edited, never fetched,
never pulled, never checked out, nothing run from it. `design/` was not read. No build, no device
run, no install.

**The HEAD every `file:line` below was read from: `4f91406c07cc7d41d0c987b632f638aeaa048805`**
(Pass 94), with `git status --porcelain` showing only `?? icon-source/`. Every line number in this
report was read in this run, not carried over from an earlier pass — Pass 41's build-plan step 7
cites Pass 41-era line numbers (`:118`, `:722`, `:703-716`, `:713`, `:220`, `:101`, `:487-491`) and
**those have all moved**; §3 restates them at this HEAD.

**What the owner said, and what he decided** (2026-09-16):

> resuming a recording starts at the saved spot and there is no way to rewind to before it

> this settles Pass 41 open question 7.2 — resume asks for the whole recording from the beginning
> and then seeks to the saved position (Pass 41 build-plan step 7)

---

## THE RESULT, so it is not buried

**The owner is right, the cause is one line on the wire, and there is no bug anywhere.** The app
sends the saved position as the play session's `start`, and the server applies it as ffmpeg's `-ss`
**before** it builds the single-file MP4. The file it then remuxes *begins* at the resume point. The
scrubber can reach every second of that file and there are no seconds before it, because they were
never remuxed. Nothing in the app restricts seeking — `requiresLinearPlayback` is set only for
cameras (`PlayerScreen.swift:36`).

**The change the owner has decided is small and its blast radius is smaller than Pass 41 feared.**
Sending `start: 0` and seeking afterwards means `startOffset` is 0, and **every single reader of
`startOffset` degenerates correctly**, because they all compute `position = startOffset + t`, which
at `startOffset = 0` is the identity (§2: ten readers, ten correct). DECISIONS.md, 2026-09-08
(Pass 42) already corrected Pass 41 §4.3's claim that today's `start: N` breaks `fullyPrepared`, the
HUD and the commercial clamp — **it does not**; the server echoes `start` back and `startOffset`
compensates exactly. So **both schemes are correct, and the difference is reach and wait, which is
exactly the trade the owner has now settled.**

**The work is three edits in two files, and one of them is the fragile one.** Two are additive and
independent (SWEEP); the third is `restart(at:)` / `startAgain(at:)`, the session-teardown path Pass
39 named the Player's most fragile area, and it is STANDALONE (§4).

**The price is the remux.** Today, resuming at 1 h 40 m of a 1 h 42 m recording remuxes two minutes;
afterwards it remuxes the whole thing, every time. The existing 11-minute first-fetch timeout already
covers the server's own 10-minute ceiling (`PlaybackSession.swift:37`), so nothing about the timeout
needs to change — but the "Preparing the recording" screen will stand for longer, which is Pass 41
open question **7.3**, still unanswered and **not reopened here**.

---

## 1. Step 1 — the cause, with `file:line`

### 1.1 Where the saved position becomes the play request's `start`

Four links, and each one was read at this HEAD:

| # | Where | Line | What it does |
|---|---|---|---|
| 1 | `ShowDetailScreen.swift` | **`:148-150`** | `play(_ episode:from start:)` → `onPlay(.recording(episode: episode, show: model.detail, start: start))` |
| 2 | `PlayRequest.swift` | **`:14`** | the case itself: `case recording(episode: Episode, show: ShowResponse?, start: Double)` |
| 3 | `PlayRequest.swift` | **`:63-67`** | `var startSeconds: Double` — `if case .recording(_, _, let start) = self { return start }` |
| 4 | `PlaybackSession.swift` | **`:70`** | the **only** `POST /api/play/sessions` in the app: `CreateBody(… start: request.startSeconds)` |

Then `PlayerModel.start()` at **`:118-121`** takes the answer back:

```
let created = try await sessions.create(request)
session = created
startOffset = created.start        // :120
duration = created.duration        // :121
```

`PlayRequest.format` at **`:46-52`** is what makes a recording `"file"` — the single line that
chooses the route (DECISIONS.md, 2026-09-08 (Pass 42)). So a recording carries **both** `format:
"file"` and a non-zero `start` in the same body.

### 1.2 What the server does with it — read in the reference clone, not requested

The clone is at `eb0c098` (1.8.1 source; the running server answers 1.8.2 and what 1.8.2 changed is
not known to this project — DECISIONS.md, 2026-09-13 (Pass 85)). It was read, not fetched.

- **`cmd/marlin-dvr/stream.go:328-331`** — inside the `case "recording":` arm, **before** the
  `format` switch:

  ```go
  if req.Start > 0 {
      args = append(args, "-ss", strconv.FormatFloat(req.Start, 'f', 3, 64))
  }
  args = append(args, "-i", rec.Path, "-map", "0:v:0", "-map", "0:a:0?")
  ```

- **`cmd/marlin-dvr/playfile.go:108-117`** — `startFile` takes those same `x.args`, strips the
  fragmented-MP4 output args and appends `fileOutputArgs()`. **The `-ss` is still in them.** So the
  single-file MP4 is the *remainder* of the recording, and its own t=0 **is** the resume point.
- **`cmd/marlin-dvr/stream.go:322`** — `x.Duration = mi.Duration`, the **whole** recording's length,
  and **`:394`** echoes both back: `"duration": x.Duration, "start": x.Start`.

This is Pass 41's **D7**, restated at the current source. It is the whole cause: **there is nothing
in the file before the resume point**, so no scrubber, no rewind and no arrow can reach it.

### 1.3 Every entry point that resumes

`grep` for `.recording(` and `onPlay(` across the app target finds **exactly two** places a
recording play request is built, and **one** that rebuilds it with a new start:

| Entry point | Line | `start` it passes |
|---|---|---|
| Show detail — **"Resume S9 E11 · 22 min in"** (frame 5d) | `ShowDetailScreen.swift:174-184`, the call at **`:177`** | `resume.entry.position` — the saved position |
| Show detail — **"Play newest"** | **`:186-189`**, the call at **`:188`** | `ResumeStore.entry(for: newest.id)?.position ?? 0` |
| Show detail — **clicking an episode row** | **`:234-241`**, the call at **`:236`** | `ResumeStore.entry(for: episode.id)?.position ?? 0` |
| The Player's **"Play next episode"** (frame 6e) | `PlayerScreen.swift:98-107`, the call at **`:101`** | `model.request.replacing(episode: next, start: 0)` — **always 0**, never resumes |
| The Player's **restart** (frame 6h, the Expired state, and the seek-beyond path) | `PlayerModel.swift:759` | `request.withStart(target)` — `PlayRequest.swift:120-123` |

**Continue watching (Pass 91) is not a fourth entry point.** Its cards set `selected = item.show`
(`RecordingsScreen.swift:271-275`) and open show detail, which is the same screen that then offers
Resume — the comment at `RecordingsScreen.swift:259-261` says so and the code matches. So **all three
resuming entry points are in `ShowDetailScreen.swift` and all three go through `play(_:from:)` at
`:148-150`.**

**Two of the three resume without the owner asking to.** "Play newest" and a plain click on an
episode row both pass the stored position if there is one — the same behaviour, reached without
pressing a button labelled "Resume". Worth knowing when the change is tested.

---

## 2. Step 2 — every reader of `startOffset` or the session's `start`, and whether each survives `start: 0`

`startOffset` is written in three places (`:120`, `:750`, `:761`) and read in seven. `duration` and
`preparedTo` are included because they are the other two halves of the same arithmetic.

| # | Reader | Line | What it computes | Correct at `startOffset = 0` with a seek? |
|---|---|---|---|---|
| 1 | `tick()` — the position | **`:257`** | `position = startOffset + t` | **Yes.** It becomes `position = t`, the identity. This is the assumption every row below rests on. |
| 2 | `tick()` — `preparedTo` | **`:260`** | `preparedTo = startOffset + range.end` | **Yes.** `0 + D = D`. Today it is `N + (D − N) = D`. Same number, arrived at more simply. |
| 3 | `fullyPrepared` | **`:101`** | `duration > 0 && preparedTo >= duration − 2` | **Yes.** True from the first tick, exactly as today. |
| 4 | HUD **"x of y"** | `PlayerScreen.swift:246-247` | `clock(position) of clock(duration)` | **Yes, with one transient.** `duration` is the whole recording either way. But between `attach()` and the seek landing, `position` reads ≈ 0, so the HUD can show "0:00 of 43:00" for a moment. §5 makes this a device check. |
| 5 | HUD **"Prepared to …"** | `PlayerScreen.swift:250-251` | drawn only when `!fullyPrepared` | **Yes.** Never drawn on a complete file, before or after. |
| 6 | `frameStepLanded` | **`:408`** | `position = startOffset + landed` | **Yes.** Same identity. The step itself (`frameStep` `:379-400`) is pure item time and never reads `startOffset`. |
| 7 | **Commercial skip — the seek target** | **`:529`** | `target = max(0, absolute − startOffset)` | **Yes, and strictly better.** At `startOffset = 0` the target is the break's own `endSeconds`. Today a break lying *before* the resume point has a negative target and is clamped to `range.start` (`:530-535`); at 0 every break in the recording is reachable. |
| 8 | **Commercial skip — the duration clamp** | **`:528`** | `absolute = min(absolute, duration − 1)` | **Yes.** `duration` is the whole recording in both schemes (`stream.go:322`), which is the assumption the comment at `:524-526` states. |
| 9 | `commercialSkipLanded` | **`:547`** | `position = startOffset + landed` | **Yes.** Same identity. |
| 10 | `timeJumped()` — seek past the prepared range | **`:586`** | `target = startOffset + t` | **Yes, and still inert.** Its guard at **`:585`** requires `!fullyPrepared`, which is false on a complete file in both schemes. Unchanged and unreachable either way (Pass 41 §4.4). |
| 11 | `saveResume()` | **`:819-824`** | saves `position` and `duration` | **Yes.** It stores absolute seconds in both schemes, so **every position already in the store keeps its meaning** and nothing has to be migrated. |
| 12 | `restart(at:)`'s own save | **`:748`** | `ResumeStore.save(… position: target, duration: duration)` | **Yes**, same reason — but see row 14. |
| 13 | `playedToEnd()` | **`:628-644`** | marks watched, `ResumeStore.clear` | **Yes.** Fires on `AVPlayerItemDidPlayToEndTime`; the file ends at the recording's end in both schemes. |
| 14 | **`restart(at:)` — the write** | **`:750`** | `startOffset = target` | **NO. This is the one line that is wrong under the change** and must be dealt with by the build pass (§3, §4 T1). |
| 15 | `startAgain(at:)` — the write | **`:761`** | `startOffset = created.start` | **Yes, once the POST sends 0** — it would then set 0, correcting row 14 a moment later. The window between `:750` and `:761` is the fragile part. |
| 16 | The Expired state's copy | `PlayerScreen.swift:480` | "Restart continues from \(clock(position))." | **Yes as text**, provided the restart it describes actually resumes there — which is row 14 again. |
| 17 | The console lines | **`:122`**, **`:763`** | print `start=` and `duration=` | **Yes.** They report what the server answered, whatever it is. |
| 18 | **Continue watching's position and bar** | `RecordingsScreen.swift` (the shelf), `ResumeStore.swift:21-31` | reads stored entries | **Yes, and untouched.** Both Pass 91's "40 min in" and Pass 92's `position ÷ duration` bar read the store, never `startOffset`. |
| 19 | Show detail's **Resume** label and row bars | `ShowDetailScreen.swift:175`, `:238` | `ResumeStore.label(for:)`, `EpisodeRow(resume:)` | **Yes, and untouched.** Same store, same meaning. |

**Ten readers of `startOffset`, and nine of them are correct at 0 without being touched.** The
tenth, `restart(at:)` `:750`, is the standalone item.

Also worth stating plainly, because Pass 41 §4.3 predicted otherwise and Pass 42 corrected it on the
record: **nothing in this table is broken today**. Today's numbers are right; they just describe a
file that starts at the resume point.

---

## 3. Step 3 — every file and line step 7 would change

Pass 41's step 7 reads: *"For a file session, send `start: 0` and seek in-item once the item is
ready, instead of `create(request.withStart(target))`."* Restated at this HEAD:

### 3.1 The lines

| # | File | Line(s) at `4f91406` | What step 7 needs of it |
|---|---|---|---|
| A | `PlayRequest.swift` | **`:63-67`** (`startSeconds`) | A recording's **wire** start becomes 0. The saved position must still reach the model, so the case's associated `start` (`:14`) stays — it is also `PlayRequest.id` (`:20`), which is the `fullScreenCover`'s identity and must not change meaning. |
| B | `PlaybackSession.swift` | **`:70`** | The one POST site. No edit if A changes what `startSeconds` answers; named here because it is the only place a `start` reaches the wire. |
| C | `PlayerModel.swift` | **`:190-201`** (`attach`) | The item is created at `:191` and played at `:196`. The resume target has to be remembered here, per item, so a second item (a restart) does not inherit the first one's. |
| D | `PlayerModel.swift` | **`:552-557`** (`itemStatusChanged`) | **This is where the seek belongs.** It is already the KVO arm for `item.status`, observed at **`:226-228`**, and today it handles only `.failed`. A `.readyToPlay` arm is the "after the item is ready" point step 7 asks for, and it is a new branch on an existing observer. |
| E | `PlayerModel.swift` | **`:113-154`** (`start()`) | No line changes, but the shape does: `attach(url)` at **`:152`** is no longer the last thing that decides where playback begins. |
| F | `PlayerModel.swift` | **`:740-753`** (`restart(at:)`) | **`:750` `startOffset = target` becomes wrong** and `:759`'s `request.withStart(target)` must stop meaning "ask the server to start there". |
| G | `PlayerModel.swift` | **`:755-786`** (`startAgain(at:)`) | Reaches the same `attach(url)` at **`:779`**, so whatever C and D do must work for it too. |
| H | `PlayerModel.swift` | new private state | A "seek here once ready" value and a once-per-item latch. There is no existing property that can carry it: `startOffset` (`:47`) is the server's answer and would be 0. |

**Two files carry every edit: `PlayRequest.swift` and `PlayerModel.swift`.**
`PlaybackSession.swift` is named for the wire site and may need no change at all.
**`ShowDetailScreen.swift` needs no change** — all three entry points keep passing the saved
position; only what the Player does with it changes.

### 3.2 Where the seek goes, and why there

**`itemStatusChanged()` `:552-557`, on `.readyToPlay`.** Three reasons, all read at this HEAD:

1. It is **already observed** — `observe(_:)` registers `item.observe(\.status …)` at **`:226-228`**
   and hops to the main actor. No new observer is needed.
2. `attach()` calls `player.play()` at **`:196`** before the item is ready, so a seek issued there
   would be against an item with no timebase. `.readyToPlay` is the first moment a seek is honoured.
3. The app already owns an exact in-item seek with both tolerances `.zero` and a
   `seekableRange` clamp, twice — `frameStep` **`:387-398`** and `skipCommercialBreak`
   **`:536-540`**. `seekableRange` is **`:245-250`**. The resume seek is the same move, so the build
   pass has two worked examples in the same file and needs no new machinery.

### 3.3 Anything on the path that touches `armArrowOwnership`, `armSelectOwnership` or the file route's first fetch

**`armArrowOwnership` — not touched, and cannot be.** It is driven by
`ownsArrows: model.isRecording && model.isPaused` (`PlayerScreen.swift:37`) into
`PlayerHost.swift:70` / **`:79`**, and claims only left/right recognizers
(`PlayerHost.swift:134-150`). The resume seek happens while **playing and not paused**, so
`ownsArrows` is false throughout it. Its guard `owns != armed` at **`:135`** also means the extra
SwiftUI updates a new observable property would cause are no-ops.

**`armSelectOwnership` — not touched, and cannot be.** Driven by
`ownsSelect: model.commercialPrompt != nil` (`PlayerScreen.swift:38`) into `PlayerHost.swift:71` /
**`:80`**, claiming only `.select` (`PlayerHost.swift:157-174`), with the same
`owns != selectArmed` guard at **`:158`**. No prompt can be up before the first frame.

**But the commercial *fetch* is on this path, and it is the one real interaction.**
`attach()` ends with `loadCommercialsOnce()` at **`:200`**, and `tick()` calls
`noticeCommercialBreak()` at **`:258`** once a second. Under `start: 0` the item begins at t ≈ 0
**before** the seek lands, so `position` (`:257`) reads ≈ 0 for that window. `noticeCommercialBreak`
(**`:476-486`**) tests `position >= startSeconds && position < endSeconds` and **latches the range
into `promptedRanges` at `:480` the first time it matches**. A recording whose first break begins at
or very near 0 could therefore have that break offered — or silently burned — in the pre-seek window.
**No recording in the owner's library is in that shape**: Pass 94 measured the earliest break in the
library at **176.54 s** (`5328bb632e76`) and 1091.29 s (`d9a4f5c76696`). This is named, not fixed,
and it is a device observation in §5 rather than work in §4, because the owner did not ask for it.

**The file route's first fetch — unchanged, and already big enough.**
`PlayerModel.swift:143-151` chooses `sessions.firstFileByte(url)` for a file session;
`PlaybackSession.swift:114-127` is that probe, on its own `fileSession` with
`fileTimeout = 660` s (**`:37`**) — eleven minutes, chosen in Pass 42 to sit above the server's own
ten-minute remux ceiling. **Step 7 does not change a line of it, but it does change what it waits
for**: the whole recording's remux instead of the tail's. The budget already covers that. What
changes for the viewer is how long `StartingOverlay` (`PlayerScreen.swift:112`) and its "Preparing
the recording" line (`PlayerModel.swift:156-162`) stand — Pass 41 open question **7.3**, untouched.

---

## 4. Step 4 — SWEEP and STANDALONE

Only the work the owner asked for is listed. Nothing else is proposed.

### SWEEP — additive, independent

| # | The work | Files and lines | Why it is a sweep, in one line |
|---|---|---|---|
| **S1** | **A recording's session asks for the whole recording**: the wire `start` becomes 0. | `PlayRequest.swift:63-67`; the wire site `PlaybackSession.swift:70` | One value on one request, and §2 shows all ten `startOffset` readers stay correct at 0 with no edit. |
| **S2** | **Seek to the saved position once the item is ready.** | `PlayerModel.swift` — remember the target in `attach` `:190-201`, seek in a new `.readyToPlay` arm of `itemStatusChanged` `:552-557`, plus the private state (H) | A new branch on an observer that already exists (`:226-228`), using the exact-seek-plus-clamp the file already does twice (`:387-398`, `:536-540`). Nothing existing changes behaviour. |

### STANDALONE — fragile or do-not-touch paths

| # | The work | Files and lines | Why it is standalone, in one line |
|---|---|---|---|
| **T1** | **Make restart resume the same way**: `startOffset = target` stops being right, and `withStart(target)` stops meaning "start the session there". | `PlayerModel.swift:740-753` (`restart(at:)`, the write at `:750`) and `:755-786` (`startAgain(at:)`, the POST at `:759`, the attach at `:779`) | It is the session-teardown-and-recreate path Pass 39 named the Player's most fragile area, it is reached from three unrelated callers — frame 6h Restart, the Expired state (`PlayerScreen.swift:480`) and `timeJumped()` `:589` — and it is the only reader of `startOffset` (§2 row 14) that the change makes wrong. |

**S1 and S2 are one another's other half** — S1 alone would start every resume at the beginning,
S2 alone would seek to a point the file already starts at. They land together or not at all; they
are "independent" of everything *else*, not of each other. **T1 can follow afterwards**, because
until it lands a restart simply behaves as it does today.

---

## 5. Step 5 — what the build pass must prove on the device, and what can only be code-traced

### 5.1 Must be proved on the device

1. **The rewind itself.** Resume a recording, then scrub *back past the resume point* with the
   remote and watch picture from before it. This is the owner's whole report and nothing short of
   the television proves it.
2. **The seek lands on the saved position** — not at 0, not past it. The HUD's "x of y"
   (`PlayerScreen.swift:246-247`) against the store's own number for that recording, read off the
   device the way Pass 92 read it.
3. **The wait.** Time "Preparing the recording" for a whole-recording remux, on the owner's largest
   subject. For scale, and **read in Pass 94's log on 2026-09-16, not re-fetched this pass**: the
   server logged remuxes finishing in **2.84 s to 9.771 s for files of 1.43–1.81 GB**. Those
   sessions' own `start` values are not in the log, so **whether any of them was a whole-file remux
   is not established** — which is exactly why this has to be measured rather than inferred.
4. **The HUD's first second.** Whether "0:00 of 43:00" is visible before the seek lands (§2 row 4),
   and for how long.
5. **Frame stepping still steps one frame.** Pass 29's measured 0.033367 s at 29.97 fps, and
   `armArrowOwnership`'s console line reporting the same recognizer count as before
   (`PlayerHost.swift:140`).
6. **The commercial prompt still arms, and no spurious one appears.** `5328bb632e76` is the only
   usable subject — Pass 94 measured it as one of just two recordings in the library with markers,
   with breaks at 176.54, 305.57, 730.56 and 1271.20 s. Two things to watch: a skip still landing on
   `endSeconds`, and **nothing flashing in the pre-seek window** (§3.3). A break *before* the resume
   point becoming reachable for the first time (§2 row 7) is also newly observable here.
7. **Playing to the end still marks watched and clears the resume** (`:628-644`).
8. **Restart still resumes where it says it does** — frame 6h and the Expired state's copy
   (`PlayerScreen.swift:480`) — once T1 lands.

### 5.2 Can only be code-traced

- **`timeJumped()`'s seek-past-the-prepared-range restart** (`:577-591`). Its guard at `:585`
  requires `!fullyPrepared`, which is false on a complete file, so it **cannot be made to fire** on
  this route. Already on the record (Pass 41 §4.4) and unchanged by this work.
- **A recording still being written, and one that is not H.264/AAC.** Both earn a 502 at POST time
  and neither has ever been exercised on the device (DECISIONS.md, 2026-09-08 (Pass 42)); `start: 0`
  does not change either of them.
- **The failure branches** — `routeRefused` (`:176-181`), `firstFetchSucceeded` (`:186-188`) and
  `fail(…)` (`:666-689`). Reachable only by breaking something on purpose.
- **The zero-duration guards** — the commercial clamp's `if duration > 0` (`:528`) and
  `saveResume`'s (`:822`). The server always answers a duration for a finished recording.
- **A remux long enough to approach the server's ten-minute ceiling.** Nothing in the owner's
  library is near it, so the eleven-minute timeout (`PlaybackSession.swift:37`) cannot be exercised
  honestly.
- **`recoverIfPausePointLeftWindow()`** (`:302-313`) — live only; a recording never reaches it.

---

## 6. Open questions

1. **Does the seek go through `player.seek` or `item.seek`, and with which tolerances?** The file
   has two precedents with both tolerances `.zero` (`:387-398`, `:536-540`) and one with
   `.positiveInfinity` after (`:306-307`). An exact seek to an arbitrary second may cost a moment of
   decode; a tolerant one is instant but lands on a keyframe. **Not chosen here.**
2. **Should "Play newest" and a plain episode click still resume silently?** Two of the three entry
   points (§1.3) pass the stored position without any button saying so. Unchanged by this work, and
   the owner has never been asked.
3. **Pass 41 open question 7.3 — what the screen says during the wait — becomes more visible**, and
   is deliberately **not** reopened here. So do 7.4 (fall back or show the error) and 7.5 (temp space
   on Unraid).
4. **Nothing is proposed about the pre-seek window's effect on the commercial prompt** (§3.3). If the
   device shows a flash, the fix is the owner's to ask for.
5. **Should the resume seek be skipped when the saved position is tiny?** `ResumeStore.isResumable`
   is `position > 5` (`ResumeStore.swift:77`), but the three entry points pass
   `?? 0` and do not apply it. Unchanged by this work.

---

## 7. The three things I am least sure of

1. **That 1.8.2 still applies `-ss` where 1.8.1 does.** §1.2 is read from the reference clone at
   `eb0c098`, which is **1.8.1**; the running server answers **1.8.2** and this project does not know
   what changed. The behaviour the owner describes is exactly what `-ss` produces, and Pass 42
   measured the echo arithmetic on the device, so the diagnosis is strongly corroborated — but it is
   a reading of source one version behind the binary, and **this pass made no request to check**.
2. **That `.readyToPlay` is early enough and late enough.** It is the right observer and the right
   moment in principle, but nobody has issued a seek from it in this app. Whether AVFoundation
   honours it immediately on a byte-range-served MP4, and whether `player.play()` at `:196` has
   already rendered a frame of the opening by then, are device facts — and §5.1's items 1 and 4 exist
   because I cannot settle them from the source.
3. **That the remux cost is as small as the log suggests.** The 2.84–9.771 s figures in §5.1 are
   real, but their `start` values are unknown, so they may all be tail remuxes. If a whole 1 h 42 m
   recording takes substantially longer, the owner is trading a long wait for the rewind — and he
   has decided the trade without that number in front of him.

---

## 8. SCOPE CHECK — every path touched, mapped to its step

| Path | Read / written | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` (Passes 38, 41, 42, 91, 92, 94) | read | the brief's "read first" |
| `reports/2026-09-08-pass41-single-file-route-recon.md`, `…pass42…`, `…pass94…` | read | the brief's "read first" |
| `~/Xcode/marlin-dvr-reference/cmd/marlin-dvr/stream.go`, `playfile.go` | **read only** — no fetch, pull or checkout | 1 |
| `Marlin DVR TV/{PlayerModel,PlayerScreen,PlayerHost,PlayRequest,PlaybackSession,ShowDetailScreen,RecordingsScreen,ResumeStore,Models}.swift` | **read only** | 1, 2, 3 |
| `git rev-parse`, `git status`, `git grep`-style `grep` in this repo | read only | verify |
| `reports/2026-09-16-pass95-resume-rewind-recon.md` | **written** | 8 |
| `COLD-START.md` — "Raised for the marlin-dvr project" and "Next step" | **updated** | 6 |
| `DECISIONS.md` | **appended** | 7 |

**Not touched:** every app-target and test-target source file, `Marlin DVR TV.xcodeproj`, `design/`,
the other folders under `~/Xcode`, **the server — no request of any kind**, the Unraid host,
marlinpc, the HDHomeRun, the UNAS4Pro share. No build, no install, no device run, no code change.

---

## 9. Git

Read before anything in this repo changed: `HEAD`, `main` and `origin/main` all at
**`4f91406c07cc7d41d0c987b632f638aeaa048805`** (Pass 94), `git status --porcelain` showing only
`?? icon-source/`. **Every `file:line` in this report was read from that tree in this run.**

This pass's commit carries this report, the `DECISIONS.md` entry and the two `COLD-START.md` edits,
and is pushed as a fast-forward from `4f91406`. **This pass's own SHA is not written here and cannot
be** — a commit cannot contain its own SHA (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 95
response and belongs in the next pass's notebook entry.
