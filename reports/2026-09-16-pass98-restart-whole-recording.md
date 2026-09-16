# Pass 98 — restart resumes from the whole recording (Pass 95 T1)

**Date:** 2026-09-16
**Built, tested on Home Theater, committed, NOT pushed.** The owner tests it first.
**App-target diff: one file, `PlayerModel.swift`, +24 / −4.** No new harness: step 2's device drive
hit its own STOP condition (§2) and the existing `ResumeRewindUITests` was re-run unchanged as the
regression. `PlayerHost.swift`, `PlaybackSession.swift`, `PlayRequest.swift` and the Xcode project
file are untouched. The bedroom Apple TV was not touched.

**Server traffic:** only what the app itself sent while playing, plus `GET /api/logs`.

**HEAD this was built from: `80458f9ddb85599c79186e819aabc479bbb698f2`** (Pass 97), with
`git status --porcelain` showing only `?? icon-source/`.

---

## THE RESULT, so it is not buried

**T1 is built: `restart(at:)` no longer pre-seeds `startOffset` with the target, and a restarted
recording reaches that target the same way Resume has since Pass 96** — the new session asks for the
whole recording and the app seeks once the item is ready.

**But no restart can be driven on the device, and step 2's own STOP clause is what this pass
followed.** All four callers were traced and none is reachable with the remote on a healthy
recording playback:

| Caller | Why it cannot be reached |
|---|---|
| **Frame 6h — `ExpiredState`'s "Restart"** | needs a keep-alive `410`, and the session cannot idle out: the app fetches every **10 s** against the server's **15 s** watchdog |
| **Frames 6f/6g — `FailureState`'s "Try again"** | needs the POST, the route check, the first fetch or AVPlayer to fail; none is producible from the remote |
| **`timeJumped()`'s seek-beyond** | its guard needs `!fullyPrepared`, which is false on the file route from the first tick |
| **`stopBlockingRecordingAndWatch()`** (a fourth, not named by the step) | live only, and needs a tuner-busy 502 |

**The empirical half of that is in this pass's own evidence**: the harness's session ran **5 minutes**
of scrubbing, pausing and playing and **ended only on the app's own DELETE** — no watchdog line, no
410 — and the app's console carries **zero** `restarted start=` lines across both device runs.

**What was driven on the device is the regression, and it passes.** `ResumeRewindUITests`, unchanged,
**TEST SUCCEEDED in 389.479 s**: Resume still lands on the saved position, scrubbing back still
reaches **`0:03 of 42:51`**, and the prompt still arms and lands on a break's `endSeconds`. **Frame
stepping is still 0.033367 s a click at 29.97 fps** — measured after a resume, not after a restart,
because a restart could not be reached.

---

## 1. Step 1 — what was built

**One file, `PlayerModel.swift`.** Two lines of behaviour, and the rest is why.

### 1.1 `restart(at:)` — `:818-846`

`startOffset = target` became **`startOffset = 0`** (`:839`). That line was correct until Pass 96
and stopped being so: `PlayRequest.startSeconds` answers 0 for a recording now, so the server builds
the whole MP4 and the item's own t=0 is the recording's first frame. `startAgain` overwrites the
field with whatever the server echoes (`:859`) — which is 0 — so this only has to be honest for the
window in between, and now it is.

`position = target` (`:844`) is unchanged **and is now documented as load-bearing**, because it is
the whole of T1:

> **Load-bearing, and the whole of T1.** This is how `target` reaches the seek: `attach` calls
> `armResumeSeek` (`:228`), which reads `position`, and nothing between here and there writes it —
> `startAgain` replaces `startOffset` and `duration` and never `position`, `tick()` is held off by
> `phase == .starting`, and `detachPlayer` has already run above.

**Nothing else in the teardown changed.** The same `detachPlayer()`, the same `sessions.stop(id:)`
DELETE, the same `ResumeStore.save(...)`, in the same order, with the same `writeDone = false`.

### 1.2 `startAgain(at:)` — `:848-853`

**No code change at all** — only a doc comment recording that `target` still reaches `withStart` but
**no longer reaches the wire**, so nobody later reads `create(request.withStart(target))` and assumes
the server is being told where to start. The parameter is kept because the session's own log line
prints it.

### 1.3 One Pass 96 comment was corrected

`armResumeSeek`'s doc (`:213-227`) claimed **"Nothing in `restart(at:)` or `startAgain(at:)` was
changed by this pass (Pass 95 T1)"**. That was true when Pass 96 wrote it and is false now. It is
rewritten to say that Pass 96 relied on the `position` write incidentally and **Pass 98 made it
deliberate**. Disclosed here because this project does not normally rewrite comments that carry
`file:line` citations — but a comment whose *claim* has become untrue is a different thing from one
whose line numbers have drifted.

### 1.4 Live, cameras and radio

**Unchanged, by construction.** For a live channel or a camera `restart()` is called with no
argument and `isRecording` is false, so `target` is 0 — which is exactly what `startOffset = 0` now
writes, and what `startOffset = target` wrote before. `armResumeSeek` returns at its
`guard isRecording`. Radio never creates a play session at all.

## 2. Step 2 — the STOP, with the trace and the evidence behind it

Step 2 said: *"If no restart can be reached on the device without changing app code, STOP that step,
code-trace all three callers … and say so."* **That is what happened.** No harness was extended and
none was added.

### 2.1 Frame 6h — `ExpiredState`'s "Restart"

Frame 6h **is** the Expired state: `PlayerScreen.swift:398` marks the section
*"6f / 6g / other failures (dc:1248-1255) and 6h (dc:1256-1259)"*, and `ExpiredState` (`:435-452`)
is the `410 · session ended` card. Its "Restart" button is `:448`, wired to `model.restart()` at
`:51`. So step 2's two named candidates — "frame 6h's Restart" and "the Expired state's Restart" —
are **one button**.

It needs `phase == .expired`, which only `sessionExpired()` (`PlayerModel.swift:698`) sets, which is
called only from the keep-alive loop when `status == 410` (`:690`). The server answers 410 only for
a session it still holds that has gone `!Active` (`playfile.go:216-222`), and a session goes inactive
only on the app's own DELETE or on the idle watchdog — `hlsIdleTimeout = 15 * time.Second` of
nothing fetched (`hls.go:49`, watchdog at `:207-225`). The app fetches every **10 s**
(`PlaybackSession.keepAliveInterval`, `:29`, loop at `PlayerModel.swift:675-692`).

**10 s against a 15 s budget: the session cannot expire while the app is running, and no press on
the remote can make it.** There is no session lifetime cap in the server — the only other sweep
(`stream.go:138`) removes sessions that are *already finished*.

**Measured this pass, not only reasoned:** the harness's session lived 5 minutes under constant
scrubbing and pausing and ended on the app's DELETE.

```
14576 11:34:11.323 TRS session smu49gxh450d6f7 created: History's Greatest Mysteries (recording, copy) for D/S Apple TV
16170 11:39:39.436 TRS session smu49gxh450d6f7 stop requested (running=true)
16172 11:39:39.438 TRS session smu49gxh450d6f7 ended after 5m: stop requested by D/S Apple TV; 3.46 GB served; ffmpeg exit: 0; folder smu49gxh450d6f7 removed
```

No `watchdog` line, no 410, and `running=true` at the moment the app asked it to stop.

### 2.2 Frames 6f/6g — `FailureState`'s "Try again"

`PlayerScreen.swift:426`, wired to `model.restart()` at `:50`. It is a **third** caller that step 2
did not name, and it is not reachable either: `phase == .failed` needs the POST to throw, the route
check to refuse (`routeRefused`), the first fetch to fail, or AVPlayer to fail the item. On a
finished H.264/AAC recording served by a healthy server, none of those can be produced from the
remote — and producing one deliberately would mean a server write or pulling the network, both
outside this pass.

### 2.3 `timeJumped()`'s seek-beyond

`PlayerModel.swift:657-670`, calling `restart(at: target)` at `:669`. Its guard requires
`!fullyPrepared`; on the file route `preparedTo = startOffset + range.end` is the whole duration from
the first tick, so `fullyPrepared` is true and the branch is dead. Pass 41 §4.4 established this and
Pass 96 re-confirmed it. **Unchanged and unreachable.**

One new wrinkle, checked because Pass 96 introduced it: `tick()` now returns early while the resume
seek is pending, so `preparedTo` is 0 for that moment and `fullyPrepared` is briefly false. It does
not open the branch — `timeJumped`'s own guard also requires `Date().timeIntervalSince(attachedAt) > 3`,
and the seek lands well inside a second (Pass 96 measured 0.185 s and 0.317 s).

### 2.4 `stopBlockingRecordingAndWatch()`

`PlayerModel.swift:808`, `await restart()`. Live only — it requires `failure?.busyRecordings`, which
is only populated for a live 502 (`fail(...)`, `:746-769`, the write at `:755`). It exercises the teardown but never the
recording target, and it needs a recording in progress to stop.

### 2.5 So the recording restart path is **traced, not driven**

The trace is: `restart(at:)` writes `position = target` (`:844`) → `startAgain` POSTs with
`startSeconds` 0 and sets `startOffset = created.start` = 0 (`:859`) → `attach` (called at `:878`) calls
`armResumeSeek` (`:228`), which reads `position` → `pendingResumeSeek = target` → the `.readyToPlay`
arm seeks there. Every link was read at this HEAD. **Nothing between the write and the read touches
`position`**: `detachPlayer` (`:902-916`) does not, `startAgain` does not, `tick()` is held off by
`phase == .starting`, and a late `resumeSeekLanded` clears `pendingResumeSeek` before its
`player.currentItem` guard returns.

**The console confirms no restart fired**, so the trace stands alone: `grep -c "restarted start="`
over both runs' console output is **0**.

## 3. What was driven on the device

Two runs, both with the app's launch ping in the server's log, so neither can have exercised a stale
build:

```
14441 11:31:32.510 POST /api/clients/…/ping 200    ← the console probe (devicectl --console)
14544 11:33:46.421 POST /api/clients/…/ping 200    ← ResumeRewindUITests, launch()
```

### 3.1 The regression — `ResumeRewindUITests`, unchanged, TEST SUCCEEDED in 389.479 s

This is the real risk of the change: `restart(at:)` sits on the path to the shared `attach`, and
Resume is what the owner accepted yesterday. It still works.

| Claim | Result | Evidence |
|---|---|---|
| Resume lands on the saved position, not 0 | **968 s** against a stored 932.000 s plus playback before the reading | `98a` |
| Scrubbing back reaches 0:00 | **0.0 s** after 100 Left presses; HUD reads **`0:03 of 42:51`**, Apple's transport `00:03` / `-42:48`, over the episode's opening title card | **`98b`** |
| The prompt arms at a break and Select lands on its `endSeconds` | armed with the transport reading **1273 s**, inside break 4 (**1271.20–1478.54**); Select put playback at **1482 s** against its end of **1478.54 s** | `98c`, `98d` |

The break it proved is **break 4 this time**, where Pass 96's run proved break 3 — breaks 1–3 had
been spent during the scrub-back. The harness's break-agnostic assertion handled that without
editing, which is what it was rewritten for in Pass 96 §4.2.

### 3.2 Frame stepping — after a **resume**, not a restart

A restart could not be reached, so the check was made where it could be. The app's own console, on
this build:

```
[player] session smu49eilqb0608d recording mode=copy start=0.0 duration=2570.568
[resume] will seek to 932.00 s once the item is ready
[resume] asked 932.00 s, landed t=932.000400 → position 932.00 s of 2570.57 s
[framestep] frame rate 29.9700 fps (nominalFrameRate read 29.9700) → one frame = 0.033367 s
[framestep] app owns the arrow — 2 player recognizer(s) disabled
[framestep] +0.033367 s (one frame at 29.9700 fps = 0.033367 s) → t=959.775133
[framestep] arrow returned to the player — 2 recognizer(s) restored
```

**0.033367 s exactly**, `armArrowOwnership` claiming and restoring the same two recognizers, and the
seek landing within **0.4 ms** of the stored position. `frameStep` is byte-identical to Pass 96's,
so this also stands for the restart path if it is ever driven.

**How the console was captured, and its cost.** A temporary `FrameStepProbe` harness using
`activate()`, with the app started by `xcrun devicectl device process launch --console` (Pass 38's
method). **It is deleted; `grep -rn "FrameStepProbe"` over both targets returns nothing.** Unlike
Pass 96, **no diagnostic was added to the app target** — the `[resume]` and `[framestep]` lines are
shipped code — so nothing had to be reverted and the binary on Home Theater is the committed one
throughout.

### 3.3 The server's side, and the saved positions

Both sessions remuxed the whole 1.09 GB recording warm — **2.094 s** and **2.108 s** — consistent
with Pass 96's 2.151 s and 2.124 s.

Saved positions, read off the device with `xcrun devicectl device copy from` into the session
scratchpad, never committed (the plist also holds a credential key, which was neither printed nor
copied here):

| | before Pass 98 | after |
|---|---|---|
| `5328bb632e76` | 932.000 s | **1485.001 s** |
| every other entry | unchanged | unchanged |
| entries | **12** | **12** — none cleared |

`5328bb632e76` moved forward because the harness ends past break 4 and leaves it there; its restore
loop only walks *up* to where Pass 96 found it and 1482 s is already past that.

## 4. What was not driven, and what was traced instead

- **Every restart caller** (§2). Traced at this HEAD, confirmed unreachable, and confirmed
  unexercised by the console. **This is the second pass running in which the recording restart path
  has not been on a television, and it is now a deliberate, evidenced limit rather than an
  oversight.**
- **Frame stepping after a restart** — done after a resume instead (§3.2), on byte-identical code.
- **Live and camera restart** — `stopBlockingRecordingAndWatch` and frame 6h for a live channel were
  not driven; the argument is §1.4's, that `target` is 0 for them either way.
- **A recording still being written, and one that is not H.264/AAC** — still refused with the
  server's 502, still never exercised (Pass 42).
- **The bedroom Apple TV** was not touched and still runs `4396d84`.

## 5. Open questions

1. **How should a recording restart ever be proved?** Three ways exist and none is in this pass's
   scope: a disclosed, reverted diagnostic that forces `phase = .expired`; asking the owner to pull
   the Apple TV's network for 20 seconds mid-playback, which would produce a real 410; or a
   debug-only control. **Nothing was built and the owner has not been asked.**
2. **`armResumeSeek` still reads `position` implicitly** (`position > 0 ? position : request.resumeSeconds`).
   Passing the target into `attach` explicitly would remove the coupling that §2.5 has to argue for
   in prose. It is a small refactor of Pass 96's accepted code, it was **not built**, and it is the
   cleanest thing a later pass could do here.
3. **`request.withStart(target)` is now a call that changes nothing** (§1.2). Removing it is
   behaviour-neutral and was deliberately not done — the scope lock names the teardown path as
   "change nothing else".
4. **Pass 96's open questions stand** — the 2 s target and the three ways out of it, what the
   Starting screen should say during the wait, why a recording's first remux is about five times
   slower than its next, and a break the viewer scrubs through being spent for that playback.

## 6. The three things I am least sure of

1. **That the traced hand-off actually holds at runtime.** Every link was read and nothing writes
   `position` between the write and the read — but **no restart has ever run on a device**, on this
   build or the last. If it is wrong, a restarted recording begins at the top instead of at the
   restart point, silently, and the first person to see it will be the owner.
2. **That `startOffset = 0` is right rather than merely harmless.** It is overwritten by
   `created.start` a moment later in every path that reaches `attach`. In the path that does *not* —
   `create` throwing, so `fail(...)` runs — `startOffset` is now 0 where it used to be `target`.
   Nothing in the Failure state reads it, which I checked; if something ever does, this changed what
   it would see.
3. **That the regression run covers what the change could break.** It exercises Resume, scrubbing
   and the commercial skip thoroughly, and all three passed — but the change is *in a function the
   regression never calls*. Its real value is negative evidence: the edit did not disturb the shared
   attach path.

## 7. SCOPE CHECK — every path touched, mapped to its step

| Path | What happened | Step |
|---|---|---|
| `Marlin DVR TV/PlayerModel.swift` | **edited** — `restart(at:)`'s `startOffset`, three doc comments | 1 |
| `Marlin DVR TV/PlayerScreen.swift`, `PlayerHost.swift`, `PlaybackSession.swift`, `PlayRequest.swift` | **read only** | 1, 2 |
| `~/Xcode/marlin-dvr-reference` (`hls.go`, `playfile.go`, `stream.go`) | **read only** — no fetch, pull or checkout | 2 |
| `Marlin DVR TVUITests/ResumeRewindUITests.swift` | **run unchanged**, not edited | 2, 3 |
| `Marlin DVR TVUITests/FrameStepProbe.swift` | created for the console reading and **deleted** | 3 |
| `reports/assets/pass98/*.jpg` | **created** — 4 screenshots | 3 |
| Home Theater | built, installed once, two runs; left on the committed build | 3 |
| `http://192.168.1.250:8090` | the app's own playback traffic, plus `GET /api/logs` | 2, 3 |
| `DECISIONS.md`, `COLD-START.md` | **updated** | 3 |
| `reports/2026-09-16-pass98-restart-whole-recording.md` | **created** | 4 |

**Not touched:** `armArrowOwnership`, `armSelectOwnership`, `PlaybackSession`'s first-fetch
`URLSession` configuration, `PlayRequest.swift`, `Marlin DVR TV.xcodeproj`, `design/`, the bedroom
Apple TV, the Unraid host, marlinpc, the HDHomeRun, the UNAS4Pro share. No `GET /api/settings`, no
`GET /api/status`, no server write beyond what playing a recording does.

## 8. Git

Built from **`80458f9`** (Pass 97), the only untracked path being `icon-source/`. This pass's one
commit carries `PlayerModel.swift`, the four screenshots, this report, `DECISIONS.md` and
`COLD-START.md`. **It is committed and NOT pushed** — the owner tests it on Home Theater first, and
Home Theater is left running exactly this build. This pass's own SHA is not written here and cannot
be (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 98 response.
