# Pass 96 — resume from the whole recording (Pass 95 S1 + S2)

**Date:** 2026-09-16
**Built, tested on Home Theater, committed, NOT pushed.** The owner tests it first.
**App-target diff: two files** — `PlayRequest.swift` and `PlayerModel.swift`, **+109 / −1**.
One new evidence harness, `ResumeRewindUITests`. `restart(at:)` and `startAgain(at:)` (Pass 95 T1),
`PlayerHost`'s `armArrowOwnership` and `armSelectOwnership`, and `PlaybackSession`'s first-fetch
`URLSession` configuration were **read and not edited**. The Xcode project file is unchanged (the
target uses synchronised file groups, so the new test file needed no project edit). The bedroom
Apple TV was not touched. `~/Xcode/marlin-dvr-reference` was not read this pass.

**Server traffic:** only what the app itself sent while playing, plus `GET /api/status` and
`GET /api/logs`. No other request of any kind.

**HEAD this was built from: `3a88477f32a1c9c8bdbfc4e884cae5eb3437ce72`** (Pass 95), with
`git status --porcelain` showing only `?? icon-source/`.

---

## THE RESULT, so it is not buried

**The owner can now rewind to before the resume point. It is measured, on his own television, with
the picture on screen.** `96d-rewound-to-the-start.jpg` is the proof: the app's HUD reads
**`0:03 of 42:51`** on *History's Greatest Mysteries* S4 E14, a recording whose saved position was
930-odd seconds in, with the episode's opening title card on screen. Before this pass that footage
was not slow to reach — **it did not exist in the file the server built.**

**The 2-second requirement is not met, and the time is not the app's.** Measured from the Resume
press to the picture at the saved position:

| | `5328bb632e76` (42:51, 1.09 GB) | `d9a4f5c76696` (1:42:18, 2.60 GB) |
|---|---|---|
| **Total, press → picture** | **10.916 s** | **7.567 s** |
| of which, the server's remux | 10.233 s — **94 %** | 6.429 s — **85 %** |
| of which, everything the app does | 0.684 s | 1.138 s |

**The app's own share is under 1.2 s in both cases.** The rest is the server remuxing the recording
into a single MP4 before it will serve a byte, and §3 shows the server's own log agreeing with the
app's clock to within 130 ms. **Nothing was built to shorten it**, as step 3 required.

**It was not 2 seconds before this pass either.** On the old build, 43 minutes before this one was
installed, the same server remuxed a **trimmed** part of *Hitler's DNA* in **11.049 s** (§3.4). The
file route has always paid this; what changed is that it now remuxes the whole recording rather than
the tail.

**The best case is about 2.8 s and that figure is derived, not measured.** The same whole-recording
remux, repeated on a warm cache, took **2.151 s** and **2.124 s** (§3.3). Adding the app's measured
0.684 s of legs gives ≈ 2.8 s — still over the target, and it is arithmetic, not a reading.

---

## 1. Step 1 — the session asks for the whole recording

**One file, one property, and the wire site needed no edit at all.**

`PlayRequest.startSeconds` (`PlayRequest.swift:63-81`) now answers **0 for every kind**, through an
exhaustive switch with no `default`, so a future kind has to decide rather than inherit — the rule
`format` already follows. `PlaybackSession.swift:70` is the app's only `POST /api/play/sessions`
and already sent `start: request.startSeconds`, so **it is byte-unchanged**.

The saved position still has to reach the Player, so the case keeps carrying it and a second
property exposes it:

```swift
/// Where a resumed recording is to be **seeked** to once its item is ready …
/// **This never reaches the wire.**
var resumeSeconds: Double {
    if case .recording(_, _, let start) = self { return start }
    return 0
}
```

`PlayRequest.id` (`:20`) is still built from the same associated value, so the `fullScreenCover`'s
identity is unchanged.

**Live, cameras and radio are untouched.** Live and camera always sent `start: 0` and still do;
radio creates no play session at all. The three entry points in `ShowDetailScreen.swift` are
unchanged — **that file has no diff in this pass** — and still pass the saved position in.

The wire proves it. Both sessions in §3, from the app's own console:

```
[player] session smu47rhxvaa5dc5 recording mode=copy start=0.0 duration=2570.568
[player] session smu47to8w3640d4 recording mode=copy start=0.0 duration=6138.132
```

`start=0.0` on a resume of a recording that was 931 s and 2353 s in. `duration` is the whole
recording in both, as it always was.

## 2. Step 2 — the seek, once the item is ready

Four pieces, all in `PlayerModel.swift`:

**a. Two private fields** (`:93-98`): `pendingResumeSeek` — where this playback is to begin, in
absolute recording seconds, from `attach` until the seek lands — and `resumeSeekDone`, so a
`.readyToPlay` that arrives twice cannot seek twice.

**b. `armResumeSeek()`** (`:213-237`), called from `attach` at **`:203`**, before `observe(item)` so
the target is in hand before the KVO that will fire on it is registered. It picks the target:

```swift
let target = position > 0 ? position : request.resumeSeconds
```

**This is how `restart(at:)` keeps working without being edited.** `restart(at:)` writes
`position = target` at **`:830`** before it reaches `attach`, and `startAgain(at:)` replaces
`startOffset` and `duration` but never `position` — so a restart arrives here with its own target
already in `position`, and `start()` arrives with `position` at 0 and the saved position on the
request. Both were read; neither was changed.

It also sets `position = target` immediately, so the HUD's "x of y" never shows 0:00 in the moment
between the first frame and the seek landing. Pass 95 §2 row 4 predicted that flash; this is what
removes it.

**c. The tick guard** (`:293-297`). Until the seek lands, `tick()` returns before touching anything
for a recording. Two reasons, and the second is the one that matters:

> Publishing `startOffset + t` in that window would flash 0:00 in the HUD, and
> `noticeCommercialBreak` would test the wrong second — and latch the break it matched into
> `promptedRanges`, spending it.

That closes the risk Pass 95 §3.3 raised, without touching Pass 38's code.

**d. The seek** (`:598-636`). A `.readyToPlay` arm on the KVO that `observe` already registers for
`item.status` (`:262-264`) — no second observer — calling `seekToResumePosition(_:)`, which is the
app's existing in-item exact seek: both tolerances `.zero`, clamped to `seekableRange` exactly the
way `frameStep` (`:420-441`) and `skipCommercialBreak` (`:562-583`) clamp. `absolute - startOffset`
is kept although `startOffset` is now always 0, because it is the same conversion the rest of the
file uses and stays right if the server ever answers a `start` of its own.

**It lands exactly.** From the console, both recordings:

```
[resume] will seek to 931.00 s once the item is ready
[resume] asked 931.00 s, landed t=931.001633 → position 931.00 s of 2570.57 s

[resume] will seek to 2353.02 s once the item is ready
[resume] asked 2353.02 s, landed t=2353.022333 → position 2353.02 s of 6138.13 s
```

The asked value is the store's own to two decimals; the landings are within **2 ms** and **2 µs** of
the stored positions of 931.001644 s and 2353.022337 s. **No seek is issued when the saved position
is 0** — `armResumeSeek` returns at `guard target > 0`, so playing from the top costs nothing.

## 3. Step 3 — the start time, measured

### 3.1 How, and what it cost

Nothing in the shipped app measures this, so a **disclosed timing diagnostic** was added: a
`ResumeTiming` holder in `PlayerModel.swift`, one mark at each leg, one press stamp in
`ShowDetailScreen.swift`, and a temporary `ResumeTimingProbe` UI test using `activate()` so Pass
38's `devicectl … --console` capture stayed attached. **All of it was removed before the commit**
— `grep -rn "PASS 96 TIMING\|ResumeTiming"` over both targets returns nothing, `ShowDetailScreen.swift`
has no diff in this pass, and `ResumeTimingProbe.swift` is deleted. The reverted build was rebuilt,
reinstalled on Home Theater and re-run (§4), and it is the build the television is left running.

### 3.2 The four legs

Both recordings, Home Theater, 2026-09-16. `d9a4f5c76696` is the **largest recording in the
library** — 1 hr 42 min, 2.68 GB on disk — named from the durations Pass 94 recorded and the store's
own `duration` field, with no request made to find it.

| Leg | `5328bb632e76` · 42:51 | `d9a4f5c76696` · 1:42:18 |
|---|---|---|
| Resume pressed → `POST /api/play/sessions` answered | **0.047 s** | **0.031 s** |
| → first fetch returned `206` | **+10.233 s** | **+6.429 s** |
| → item `.readyToPlay` | **+0.452 s** | **+0.790 s** |
| → resume seek landed, picture at the saved position | **+0.185 s** | **+0.317 s** |
| **press → picture** | **10.916 s** | **7.567 s** |

**Against the owner's 2 s: missed, by 8.9 s and 5.6 s.** Where the time goes is not in doubt: the
second leg is the app waiting on `GET /api/play/file/{id}/video.mp4`, which the server does not
answer until the remux is finished.

### 3.3 The server's own timing for the same two sessions

```
12029 10:46:25.173 TRS session smu47rhxvaa5dc5: ffmpeg pid 7116 started, single-file MP4 remux (copy) …
12035 10:46:35.398 TRS session smu47rhxvaa5dc5: remux finished in 10.225s — History's Greatest Mysteries is 1.09 GB, ready to play and seekable
12119 10:48:06.659 TRS session smu47to8w3640d4: ffmpeg pid 7123 started, single-file MP4 remux (copy) …
12122 10:48:12.966 TRS session smu47to8w3640d4: remux finished in 6.308s — Hitler's DNA is 2.60 GB, ready to play and seekable
```

**10.225 s against the app's 10.233 s, and 6.308 s against 6.429 s** — agreement to 8 ms and 121 ms,
measured independently at the two ends. The wait is the remux and nothing else.

**And it is mostly a cold cache.** The same whole-recording remux of the same 1.09 GB file, twice
more during §4's harness runs:

```
12246 10:55:11.320 TRS session smu482q9b4034c9: remux finished in 2.151s — History's Greatest Mysteries is 1.09 GB …
13519 11:04:16.445 TRS session smu48eewg3b6f45: remux finished in 2.124s — History's Greatest Mysteries is 1.09 GB …
```

**2.151 s and 2.124 s for exactly the work that took 10.225 s the first time.** Adding the app's
measured 0.684 s of other legs puts a warm press-to-picture at **about 2.8 s** — still over the
target. That 2.8 s is **arithmetic on two measurements, not a measurement**: no timing run was made
against a warm cache, because the diagnostic was already reverted.

### 3.4 What it cost before this pass — the same recording, on the old build

The ring still held the owner's own sessions from 43 minutes before this build was installed, after
his 10:03:37 launch ping, all on `d9a4f5c76696`:

```
11480 10:03:56.216 TRS session smu468mmkdf47dc: remux finished in 11.049s — Hitler's DNA is 2.28 GB …
11701 10:05:26.273 TRS session smu46apyp6848b2: remux finished in 3.47s  — Hitler's DNA is 1.67 GB …
11740 10:05:56.399 TRS session smu46bdcb9b6620: remux finished in 3.298s — Hitler's DNA is 1.60 GB …
```

Those are **trimmed** remuxes — 1.60–2.28 GB of a file whose whole remux is 2.60 GB — so they are
what `start: N` used to cost. **11.049 s, 3.47 s, 3.30 s: the 2 s target was already being missed,
by the same mechanism, before Pass 96 existed.** What this pass changed is that the remux is now
always the whole recording; on this evidence that is worth **about 3 s** on a warm cache for this
file (6.308 s whole against 3.30–3.47 s trimmed), and it bought the ability to rewind.

**`GET /api/status` at 11:09:** `{"name":"marlin-dvr","version":"1.8.2","uptime_seconds":197302,"port":8089}`.

### 3.5 Frame stepping, checked once after a resume

Step 3's standing constraint. From the console, after the resume of `5328bb632e76`:

```
[framestep] frame rate 29.9700 fps (nominalFrameRate read 29.9700) → one frame = 0.033367 s
[framestep] app owns the arrow — 2 player recognizer(s) disabled
[framestep] +0.033367 s (one frame at 29.9700 fps = 0.033367 s) → t=961.264932
[framestep] arrow returned to the player — 2 recognizer(s) restored
```

**0.033367 s exactly**, at 29.97 fps, after a resume that is now a seek — and `armArrowOwnership`
claiming and restoring the same two recognizers, untouched by this pass. The frame-step code is
byte-identical in the diagnostic build and the committed one, so this reading stands for both.

## 4. Step 4 — `ResumeRewindUITests` on Home Theater

`launch()`, not `activate()` (Pass 92's trap). **Every run's launch ping is in the server's log**,
so no run can have photographed a stale build:

```
11997 10:45:34.219 POST /api/clients/…/ping 200    ← the timing build, launched by devicectl --console
12209 10:54:43.380 POST /api/clients/…/ping 200    ← harness run 1 (failed; §4.2)
13482 11:03:49.485 POST /api/clients/…/ping 200    ← harness run 2, TEST SUCCEEDED
```

### 4.1 The run that counts — TEST SUCCEEDED in 228.959 s

Screenshots in `reports/assets/pass96/`.

| Claim | What the device did | Evidence |
|---|---|---|
| **Resume lands on the saved position, not 0** | HUD read **336 s** (`5:36 of 42:51`) against a stored 330.079 s plus six seconds of playback before the reading | `96b`, log `CLAIM 1` |
| **Scrubbing back reaches 0:00** | 40 Left presses took it to **0.0 s**; the HUD reads **`0:03 of 42:51`** and Apple's own transport reads `00:03` / `-42:48`, over the episode's opening title card | `96c-20` (141 s), `96c-40` (0 s), **`96d`** |
| **The prompt arms at the next break and Select lands on its `endSeconds`** | 68 Right presses; the prompt armed with Apple's transport reading **12:13 = 733 s**, inside the break **730.56–925.46**; Select put playback at **929 s** against that break's end of **925.46 s** | **`96e`** (the prompt over a visible commercial), **`96f`** (`15:29 of 42:51`, back in the programme) |

The harness does not decide in advance which break it will prove: it walks forward until the prompt
arms, reads Apple's transport clock, and checks that the landing is the `endSeconds` of the break
that clock sits in. The 929 s reading is taken ~3.5 s after the skip, with playback running.

### 4.2 The first harness run failed twice, and both were the harness's fault

Disclosed in full, because the app was right both times.

**Failure 1 — "the skip prompt did not arm at the break".** The harness had already spent it. Its
own log: at 10:56:43, *"the skip prompt appeared while scrubbing back (press 80)"*, and the next
reading was **188 s** — inside break 1, 176.54–206.54. `noticeCommercialBreak` latches each range
into `promptedRanges` so it prompts **at most once per playback** (`PlayerModel.swift:517-521`,
Pass 38's design), so when the harness later walked forward into the same break there was nothing
left to offer. Contributing: the forward walk paced presses at 340 ms where Pass 38 used 1.2 s, so
the model's 1 Hz `tick()` had little chance to land inside a 30-second window.

**Failure 2 — "the skip landed at 322 s".** There was no skip. With no prompt up, the Select meant
as the skip went to Apple's transport and **paused**. The reading helper then assumed it had been
entered while playing: its first Select resumed, its second paused — so it left the player paused,
and the 65 "restore" Right presses that followed went to **the app's frame stepper**, which owns the
arrows while paused on a recording (Pass 29). 65 clicks × 0.033367 s ≈ 2.2 s, which is exactly why
the position moved 322 → 327 s.

**Both fixes are in the harness and none is in the app.** The reading helper now waits out any
prompt and asserts that the pause took; the break hunt walks at 1.2 s a press; the run proves
whichever break is still unspent rather than a break named in advance.

### 4.3 The saved position was moved and put back

Read off the device with `xcrun devicectl device copy from` before and after, into the session
scratchpad, never committed. **The plist also holds a credential key, which was neither printed nor
copied into this report.**

| | `5328bb632e76` | `d9a4f5c76696` |
|---|---|---|
| Before this pass | **931.002 s** | 2353.022 s |
| After the failed run 1 | 330.079 s | 2433.000 s |
| **After the run that counts** | **932.000 s** | 2433.000 s |

**Nothing was cleared: 12 entries before, 12 after.** The failed run left the owner's position on
`5328bb632e76` at 330 s; the second run ends by walking back up to where Pass 96 found it, and left
it at **932.000 s — one second from the 931.002 s it started at**. `d9a4f5c76696` moved 80 s
forward because the timing probe played it; nothing put that back.

## 5. What was not driven on the device, and what was code-traced instead

- **`restart(at:)` and `startAgain(at:)`** — frame 6h's Restart, the Expired state's Restart, and
  `timeJumped()`'s seek-beyond. **Not exercised.** They are Pass 95's T1 and this pass was forbidden
  to edit them; the argument that they still work is the trace in §2b — `restart(at:)` writes
  `position = target` at `:830`, `startAgain` never overwrites `position`, so `armResumeSeek` finds
  the target there. **That is reasoning, not a reading**, and it is the first thing T1's pass should
  put on a television.
- **`timeJumped()`** cannot be made to fire on a complete file (`!fullyPrepared` is false), as Pass
  41 §4.4 established. Unchanged and unexercised.
- **A recording still being written, and one that is not H.264/AAC** — both still refused with the
  server's 502 and both still never exercised (Pass 42).
- **The `guard target > 0` branch** — a recording played from the top, which issues no seek — was
  not separately photographed. It is the path "Play newest" and `PlayerScreen.swift:101` take.
- **Live, cameras and radio** were not played in this pass at all. They are unchanged by
  construction: `startSeconds` was 0 for them before and after, and `armResumeSeek` returns at
  `guard isRecording`.
- **A warm-cache press-to-picture total** was not measured; §3.3's ≈ 2.8 s is arithmetic.
- **The bedroom Apple TV** was not touched and still runs `4396d84`'s binary.

## 6. Open questions

1. **The 2 s requirement is not met and cannot be met inside this app.** 85–94 % of the wait is the
   server's remux. The owner's options are all outside this pass's scope: ask marlin-dvr to serve
   the file progressively rather than after the whole remux; go back to `start: N` and give up the
   rewind; or accept ~2–3 s warm and ~7–11 s cold. **Nothing was built and nothing was asked of
   them.**
2. **Should the Starting screen say more during that wait?** It says "Preparing the recording" and
   nothing else. This is Pass 41 open question **7.3**, now more visible and still unanswered.
3. **T1 is still not built** — `restart(at:)` and `startAgain(at:)` still POST through
   `withStart(target)`, which now sends 0, and rely on §2b's `position` hand-off. It is its own
   pass, after the owner tests this one.
4. **The first remux of a recording is much slower than the next** — 10.225 s against 2.124 s for
   the same file. Whether that is the Unraid page cache, the UNAS4Pro share, or something else is
   not this project's to answer, and no request was made to find out.
5. **A break the viewer scrubs through is spent for that playback** (§4.2). That is Pass 38's
   deliberate design, and with the whole recording now reachable it will happen more often — a
   viewer who rewinds past a break will not be offered it again until they re-enter the Player.
   Raised, not changed.

## 7. The three things I am least sure of

1. **That `restart(at:)` still resumes where it should.** §2b's reasoning is tight and the code it
   depends on was read at this HEAD, but **no restart was driven on the device in this pass**. If
   `startAgain` ever gains a `position` write, the hand-off breaks silently — the recording would
   restart at the top instead of at the restart point.
2. **That `.readyToPlay` is always reached before anything else needs `position`.** It was on four
   playbacks today, all on one Apple TV, all on the file route, all on recordings that were already
   finished. A `.readyToPlay` that never arrives would leave `pendingResumeSeek` set and `tick()`
   returning early — playback would run with a frozen HUD. No timeout was built for that, and none
   was asked for.
3. **That the warm-cache number is representative.** Two warm remuxes of one recording is thin
   evidence for "≈ 2.8 s", and the cold first remux of that same file was nearly five times slower.
   What the owner actually experiences depends on whether the recording he picks has been read
   recently, which nothing in this app controls or can see.

## 8. SCOPE CHECK — every path touched, mapped to its step

| Path | What happened | Step |
|---|---|---|
| `Marlin DVR TV/PlayRequest.swift` | **edited** — `startSeconds` → 0, new `resumeSeconds` | 1 |
| `Marlin DVR TV/PlayerModel.swift` | **edited** — the two fields, `armResumeSeek`, the `tick` guard, the `.readyToPlay` arm, `seekToResumePosition`, `resumeSeekLanded` | 2 |
| `Marlin DVR TV/PlaybackSession.swift` | **read only** — already sent `request.startSeconds`; the first-fetch `URLSession` config untouched | 1 |
| `Marlin DVR TV/ShowDetailScreen.swift` | diagnostic added and **fully reverted**; no diff in this pass | 3 |
| `Marlin DVR TVUITests/ResumeTimingProbe.swift` | created for the timing run and **deleted** | 3 |
| `Marlin DVR TVUITests/ResumeRewindUITests.swift` | **created** | 4 |
| `reports/assets/pass96/*.jpg` | **created** — 8 screenshots | 4 |
| `http://192.168.1.250:8090` | the app's own playback traffic, plus `GET /api/status` and `GET /api/logs` | 3, 4 |
| Home Theater | built, installed twice, three runs; left on the committed build | 3, 4 |
| `DECISIONS.md`, `COLD-START.md` | **updated** | 5 |
| `reports/2026-09-16-pass96-resume-whole-recording.md` | **created** | 6 |

**Not touched:** `restart(at:)` / `startAgain(at:)`, `armArrowOwnership`, `armSelectOwnership`,
`PlaybackSession`'s first-fetch `URLSession` configuration, `Marlin DVR TV.xcodeproj`, `design/`,
the reference clone, the bedroom Apple TV, the Unraid host, marlinpc, the HDHomeRun, the UNAS4Pro
share. No `GET /api/settings`. No server write beyond what playing a recording does.

## 9. Git

Built from **`3a88477`** (Pass 95), the only untracked path being `icon-source/`. This pass's one
commit carries the two app files, the harness, the eight screenshots, this report, `DECISIONS.md`
and `COLD-START.md`. **It is committed and NOT pushed** — the owner tests it on Home Theater first,
and Home Theater is left running exactly this build. This pass's own SHA is not written here and
cannot be (DECISIONS.md, 2026-09-11 (Pass 68)); it is in the Pass 96 response.
