# Pass 42 — the single-file MP4 playback route, built

**Date:** 2026-09-08
**Committed locally. NOT pushed** — this is real playback code behind the separate push gate.
**Three files changed**, the three the Pass 41 build plan names. No project setting, build script,
config or dependency was touched, and no new dependency was added. `design/` was not touched.
`reports/2026-09-08-pass40-session-start-values.md` was not opened, staged, committed or amended.

The app talked to `http://192.168.1.250:8090/` during the device test — that is ordinary app
traffic. **No administrative, diagnostic or shell request was made to the server, and nothing on it
was changed.**

**Steps 1–6 of the plan are built. Step 7 is NOT built: it is explicitly conditional on open
question 7.2, which is unanswered.** See §3.

---

## 1. What was built, step by step

The specification is §5 of `reports/2026-09-08-pass41-single-file-route-recon.md`. Every line
number below was re-read from the files as they now stand, not inherited from Pass 41.

### Step 1 — `PlayRequest.swift`: a `format` computed property

**`PlayRequest.swift:46-52`**, placed beside `kind` (`:26-32`) in the same shape:

```swift
    var format: String {
        switch self {
        case .live: return "hls"
        case .recording: return "file"
        case .camera: return "hls"
        }
    }
```

The switch is exhaustive with **no `default`**, so a future kind has to make the choice rather than
inherit one. Nothing else in the enum changed.

### Step 2 — `PlaybackSession.swift`: stop hardcoding the format

**`PlaybackSession.swift:70`**, the one line in the app that ever named a format:

```swift
-  let body = CreateBody(kind: request.kind, id: request.targetID, format: "hls", …)
+  let body = CreateBody(kind: request.kind, id: request.targetID, format: request.format, …)
```

`CreateBody` itself (`:60-66`) is unchanged — it already had a `format` field.

### Step 3 — `Models.swift`: no change, as the step says

`PlaySession` was re-read this pass at **`Models.swift:394-404`**: nine non-optional fields,
`url` an untyped `String`. It decodes the file route's response without an edit, which the device
evidence in §4 confirms. **`Models.swift` is not in this pass's diff** — `git status` shows three
modified files and it is not one of them.

### Step 4 — `PlayerModel.swift`: read `created.format` and honour it

The check, **`PlayerModel.swift:176-181`**:

```swift
    private static func routeRefused(asked: String, got: String) -> String? {
        guard asked == "file", got != "file" else { return nil }
        return "The server did not start a single-file session — it answered format \"\(got)\". "
             + "A server older than 1.8.0 answers that way with no error, and what it returns "
             + "instead cannot be seeked."
    }
```

Called at **`:135-139`** in `start()` and **`:765-769`** in `startAgain(at:)`, in both cases after
the session is stored and the URL resolved but **before anything is fetched or played**. On a
mismatch it prints the asked/got pair and goes to the existing `fail(...)`, so the Failure state
draws it with no new UI.

**It fires only when the app asked for `"file"`** (`guard asked == "file"`). An `"hls"` request
cannot be failed by it, so live channels and cameras keep exactly the behaviour they had.

**A choice inside this step, disclosed rather than made silently.** Step 4's wording is "it must
**not** treat the response as a file: fall back to today's HLS behaviour, **or** fail loudly" — two
options, and the step does not pick one. I did not pick on preference either. This pass's scope lock
lists "fallback to the HLS route" as out of scope and says refused recordings are "never silently
routed back to HLS unless a step says so"; step 4 offers fallback as an alternative rather than
specifying it. **Fail loudly is therefore the only one of the two the scope lock permits**, and that
is what is built. If the owner wants the fallback instead, it is a one-branch change and this is the
place for it.

### Step 5 — `PlaybackSession.swift`: a first fetch that neither buffers nor times out early

**`PlaybackSession.swift:114-128`**, `firstFileByte(_:)`, a sibling of `firstPlaylist` (`:87-98`):

```swift
    func firstFileByte(_ url: URL) async -> PlaylistProbe {
        var req = URLRequest(url: url)
        req.setValue("bytes=0-0", forHTTPHeaderField: "Range")   // :116
        req.timeoutInterval = Self.fileTimeout                   // :117
        do {
            let (data, response) = try await fileSession.data(for: req)
            …
```

- **`Range: bytes=0-0`** (`:116`) — the same header `keepAlive` already uses (`:132`). One byte,
  never the whole file. `firstPlaylist`'s un-ranged `data(for:)` would have pulled the entire
  remuxed recording into memory.
- **`fileTimeout = 660`** seconds (`:37`) — 11 minutes. The server's own ceiling on a remux is 10
  minutes, so the server's error text always arrives before this client gives up, and a timeout
  here means the network went away rather than that the remux was slow. The number is derived from
  the server's ceiling, not chosen.
- **A separate `URLSession`** (`:24`, built `:50-54`). This is the one implementation detail the
  step did not spell out, and it is required for the step to work at all: the shared `session` is
  built with `timeoutIntervalForRequest = 25` (`:47`), a configuration value can override a longer
  per-request one, and `create`'s POST sets no per-request timeout so it depends on that 25. Raising
  the shared value would have changed the POST for live and cameras too. The long wait gets its own
  configuration instead of everyone else's being relaxed.

### Step 6 — `PlayerModel.swift`: route the probe

**`start()` at `:140-151`** and **`startAgain(at:)` at `:770-779`**, the same shape in both:

```swift
        let probe = request.format == "file"
            ? await sessions.firstFileByte(url)
            : await sessions.firstPlaylist(url)
        print("[player] first fetch (\(request.format)) → \(probe.status) \(probe.text)")
        guard !stopped else { return }
        guard Self.firstFetchSucceeded(probe.status, format: request.format) else {
            await fail(status: probe.status, message: probe.text, sessionID: created.id)
            return
        }
```

with **`:186-188`**:

```swift
    private static func firstFetchSucceeded(_ status: Int, format: String) -> Bool {
        format == "file" ? (status == 200 || status == 206) : status == 200
    }
```

`http.ServeFile` answers a ranged request with **206 Partial Content**, which the device run
confirms it does (§4). **The HLS arm is still exactly `status == 200`**, unchanged. Both constraints
the step named are preserved: the gate still feeds `fail(...)` so the existing Failure state covers
the server's four 502s with no new UI, and everything between the POST returning and the first GET
is still local-only work, so the server's 15-second idle budget is met as it is today.

### Step 7 — NOT BUILT. Blocked on open question 7.2

Step 7 ends with "**Conditional on the owner's answer to §7.2.**" 7.2 is `start: 0` versus
`start: N` for resume, and the brief states that only 7.1 is answered. **Choosing it myself would
be the scope violation the brief names**, so nothing was built for it and no stub was left. §3
carries the question and what the device run says about it.

---

## 2. How the code distinguishes recordings from live, cameras and radio

**At one line: `PlayRequest.swift:49`, `case .recording: return "file"`.** Every other kind returns
`"hls"` from `:48` and `:50` of the same switch.

That value reaches the wire at exactly one place, `PlaybackSession.swift:70`, which is the app's
only `POST /api/play/sessions` construction site — re-verified this pass with
`grep -rn "play/sessions" --include="*.swift"`, which finds one. Both callers
(`PlayerModel.swift:118` and `:757`) go through it.

Downstream, the two behaviour branches both test `request.format == "file"`
(`PlayerModel.swift:143`, `:148`, `:770`, `:775`) and the safety check tests `asked == "file"`
(`:177`). **A live channel or camera never satisfies any of them**, so it takes the identical code
path it took before this pass: `firstPlaylist`, `status == 200`, no format check.

**Radio does not appear in any of this and needs no branch**: it never creates a play session at
all — it plays the station URL directly (`RadioStation.swift:31`, `RadioPlayer.swift:10`), so it
cannot reach `PlayRequest` or `PlaybackSessionClient`.

---

## 3. The seven open questions — which came up

| # | Question | Came up? | Effect on this pass |
|---|---|---|---|
| **7.2** | `start: 0` or `start: N` for resume | **YES — it blocks step 7** | Step 7 not built. See below. |
| 7.3 | What the screen says during a long wait | Did not arise in code | No step names it; nothing built. The wait was short here (§4). |
| 7.4 | Fall back to HLS, or show the error, for a refused recording | **Brushed against, in step 4** | Resolved by this pass's own scope lock, not by me — see step 4 above. The two *server-side* refusals (non-copy, still-recording) need no code: they are 502s at POST time and already reach `fail(...)`. |
| 7.5 | Temp space on Unraid | No | Not a client question. Untested. |
| 7.6 | Ask marlin-dvr to document the route | No | Not code. Still unanswered. |
| 7.7 | Two untracked report files | No | Untouched; both still untracked. |
| 7.8 | Does `AVPlayerItem` tolerate a silent connection | **YES — and it did not arise as a problem** | The remux was fast enough here that no long silent wait occurred (§4). **Still effectively unanswered for a long remux.** |

**Six of the seven remain unanswered.** 7.2 is the one that stopped work.

**What the device run says about 7.2, offered as evidence and not as a decision.** The run sent
`start: 1484.004768173` and the arithmetic came out **exactly self-consistent**: the skip landed at
item time `t=272.538500` and the app reported `position 1478.54 s of 2570.57 s`, which is
`startOffset + t` to the pixel, and `1478.54` is precisely the fourth break's own `endSeconds`.

**This corrects something I wrote in Pass 41.** §4.3 of that report claimed that with `start: N`
"`fullyPrepared` would be false forever, the HUD's 'x of y' would be wrong, and the commercial
clamp's stated assumption would break." That was wrong. Because the server trims the file with
`-ss` **and** echoes the same `start` back, `startOffset` compensates exactly:
`preparedTo = startOffset + range.end = N + (D − N) = D`, so `fullyPrepared` is true, the HUD is
right, and the clamp holds — which the exact landing above demonstrates. **`start: N` is not
broken.** 7.2 is therefore a wait-versus-cleanliness trade, not a correctness bug, and the pass is
usable as it stands. The correction is recorded here rather than by editing the Pass 41 report,
which is out of scope.

---

## 4. Evidence

### 4a. The build (task step 4)

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'generic/platform=tvOS Simulator' build
…
** BUILD SUCCEEDED **
```

**Warnings introduced by this pass: none.** A filtered re-run
(`grep -E "^\*\* BUILD|(warning|error): "`) over the device build returns exactly one warning:

```
/Users/marlin1111/Xcode/Marlin DVR TV/Marlin DVR TV/PlayerModel.swift:325:48: warning:
  'nominalFrameRate' was deprecated in tvOS 16.0: Use load(.nominalFrameRate) instead
```

**It is pre-existing, not introduced.** The identical line is at `HEAD:288` of the same file
(`git show HEAD:"Marlin DVR TV/PlayerModel.swift" | grep -n nominalFrameRate` → `:288`), it is Pass
28's frame-step code, and `git diff -U0 … | grep -c nominalFrameRate` returns **0** — this pass's
diff does not touch it. It moved from line 288 to 325 only because the two helpers were added above
it. Fixing it is not in any numbered step.

### 4b. The device run (task step 5)

`Home Theater` was available and paired (`xcrun devicectl list devices` → *Apple TV 4K (3rd
generation)*, `available (paired)`). The app was installed, launched with the console attached, and
driven by the **existing** Pass 38 harness `CommercialSkipUITests/testPromptAppearsAndSelectSkips`,
which walks Home → Recordings → the show → play. **No test file was written or edited** — a fourth
file would have been a STOP.

**Subject:** *History's Greatest Mysteries* S4 E14 "Who Is D.B. Cooper?", a finished 43-minute,
1.12 GB Philo recording. `TEST SUCCEEDED`, 67.4 s, 0 failures.

**The three things the brief asks to be shown, from the device console. The client id is
REDACTED.**

**The POST body the app sent:**

```
[diag42] POST /api/play/sessions body:
{"format":"file","start":1206.001497533,"client":"<REDACTED-CLIENT-ID>","kind":"recording","id":"5328bb632e76"}
```

**The full response it received:**

```
[diag42] response 200:
{"duration":2570.568,"format":"file","id":"smttdw891e10096","kind":"recording","mode":"copy",
 "start":1206.001497533,"sub":"Who Is D.B. Cooper","title":"History's Greatest Mysteries",
 "url":"/api/play/file/smttdw891e10096/video.mp4"}
```

**The URL the player was handed:**

```
[diag42] player handed URL: http://192.168.1.250:8090/api/play/file/smttdw891e10096/video.mp4
         (asked file, got file)
```

**The request carried `"format":"file"`; the response came back with `"format":"file"` and a
`.mp4` url; the player was handed that url.** That is what was to be shown.

Everything else the run logged, unedited apart from the redaction:

```
[player] session smttdw891e10096 recording mode=copy start=1206.001497533 duration=2570.568
[player] first fetch (file) → 206
[session] keep-alive loop started for video.mp4 every 10 s
[commercials] 5328bb632e76 → detected: 4 break(s) [176.54-206.54, 305.57-371.54, 730.56-925.46, 1271.20-1478.54], …
[session] keep-alive #1 → 206
[session] keep-alive #2 → 206
[commercials] break 4 starts at 1271.20 s (position 1275.76 s) — prompt up for 5 s, skip would land at 1478.54 s
[commercials] app owns Select — 5 player recognizer(s) disabled, 0 of them also arrow recognizer(s)
[commercials] Select returned to the player — 5 recognizer(s) restored
[commercials] skipped +199.56 s → t=272.538500, position 1478.54 s of 2570.57 s
[session] keep-alive #3 → 206
[player] stop: phase=playing session=smttdw891e10096
[session] DELETE smttdw891e10096 → 200 {"ok":true,"wasRunning":true}
```

Reading it: the step 6 probe answered **206**, exactly as `firstFetchSucceeded` was written to
expect; the keep-alive also answers 206 now (it was 200 against a playlist) and never 410; commercial
skip still works unmodified and landed **exactly** on the break's `endSeconds`; and the DELETE was
accepted. **No `[player] route refused` line appeared**, which is step 4's check passing.

### 4c. The shipped build is the tested build

The three `[diag42]` lines above came from a **disclosed, temporary diagnostic** — three `print`
statements and nothing else — added only to make the wire traffic visible, because the app does not
log the POST body or the raw response. That is Pass 38's disclosed-diagnostic pattern.

**It has been fully reverted**: `grep -rn "diag42" --include="*.swift" .` returns nothing, and the
committed diff contains no `print` of a body or a response.

The reverted build was then rebuilt, reinstalled and re-run on the device, and it **still takes the
file route**:

```
[player] session smtte07a4ac5e05 recording mode=copy start=1484.004768173 duration=2570.568
[player] first fetch (file) → 206
[session] keep-alive #1 → 206      … through #14, all 206
```

**That second run's test FAILED, and the failure is fully explained and is not a regression.**
`XCTAssertTrue failed - no prompt after 40 forward skips`. The four breaks end at **1478.54 s** and
this session started at **1484.00 s** — past every break in the recording, so no prompt could
possibly appear. The cause is the resume position the *first* run left behind, which is the exact
behaviour COLD-START documents for this harness: "every test leaves a resume position further into
the subject recording than the last, so `testZResetTheSubjectRecordingsResume` exists to play it out
to its end, which is the only thing that clears one." Nothing in the app misbehaved: the session was
created, the file route was taken, the probe answered 206, and no error was logged.

### 4d. What was NOT tested, stated plainly

- **A long remux.** The subject is 1.12 GB and the wait was short enough that no timing line stands
  out in the console. **The 11-minute timeout, the long silent wait (7.8), and anything about a
  multi-gigabyte recording are untested.**
- **Both refusal branches (non-H.264/AAC, and still-recording).** The subject is H.264/Stereo and
  finished, so `mode: "copy"` was granted. Neither 502 was provoked. They are traced only: they
  arrive as a 502 from the POST, which `PlaybackSession.check` (`:155-162`) turns into an `APIError`
  that `start()` (`:123-125`) hands to `fail(...)`. **Not exercised.**
- **The `routeRefused` branch.** It requires a server that answers something other than `"file"`;
  the owner's server is 1.8.0 and answered `"file"`. **Code-traced, never fired.**
- **Live channels, cameras and radio.** Not driven in this pass. They are unchanged by diff and by
  the branch analysis in §2, but that is reasoning, not a device run.
- **Anything about the picture.** I cannot see the screen and make no claim about it. One
  observation the owner should weigh is in the closing summary.

---

## 5. Commit status

**Committed locally. NOTHING WAS PUSHED.**

The build commit is **`137f1de`** — in full:

```
$ git rev-parse HEAD
137f1de1e4e1fc7ab3392a5a411fca71cf8f113c
```

```
$ git log --oneline -1
137f1de Pass 42: recordings play as one seekable MP4 (steps 1-6; step 7 blocked)
```

**`git push` was not run in this pass, to any remote, at any point.** `origin/main` is still at
`b11f4c6`, where Pass 41 left it, so the local branch is two commits ahead of the remote: this
build commit and the one that records this SHA. The owner tests on Home Theater and the push
follows his approval.

*(This paragraph is the second commit — the SHA above cannot exist inside the commit it names, and
the build commit is left untouched rather than amended.)*

`git status --porcelain` after the commit shows only the two pre-existing untracked report files,
neither of which this pass touched.

---

## 6. Open questions

1. **7.2 is still the blocker for step 7**, and §3 adds evidence that should make it easier: with
   `start: N` the position arithmetic is exactly self-consistent on this route, so the choice is
   wait-versus-cleanliness, not correctness. My Pass 41 §4.3 claim to the contrary was wrong and is
   corrected in §3.
2. **Step 4's two-way wording.** It permits fallback-to-HLS or fail-loudly and this pass built fail
   loudly, on the scope lock's authority rather than a preference (§1 step 4). **Does the owner want
   the fallback instead?** Without it, a server that stops answering `"file"` makes recordings fail
   rather than silently degrade — which is the safer default but is a real behaviour change if the
   server is ever rolled back to 1.7.0.
3. **The separate `URLSession` in step 5 is an implementation detail the step did not name.** It is
   required for the step's own timeout to take effect without changing the POST for live and
   cameras. Flagged in case the owner considers it beyond the step.
4. **I left a resume position deep inside the owner's D.B. Cooper recording.** The two runs moved it
   from 1206 s to past 1484 s and the second run added 40 forward skips on top. That is a change to
   the owner's data, disclosed rather than quietly left: it is per-Apple-TV, and playing the
   recording to its end clears it. **Not cleaned up**, because doing so means playing it out and
   marking it watched, which is a further change I was not asked to make.
5. **`testPromptAppearsAndSelectSkips` will keep failing** until that resume is cleared, for the
   reason in §4c. It is a harness precondition, not app behaviour.

---

## 7. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `Marlin DVR TV/PlayRequest.swift` | **modified** (+20 lines) | build plan step 1 |
| `Marlin DVR TV/PlaybackSession.swift` | **modified** | build plan steps 2 and 5 |
| `Marlin DVR TV/PlayerModel.swift` | **modified** | build plan steps 4 and 6 |
| `Marlin DVR TV/Models.swift` | **read only, unmodified** | build plan step 3 (which says no change) |
| `Marlin DVR TVUITests/CommercialSkipUITests.swift` | **read and run, unmodified** | task step 5 (drive the remote without a fourth file) |
| `reports/2026-09-08-pass41-single-file-route-recon.md` | read | the specification |
| `COLD-START.md`, `DECISIONS.md` | read | required reading |
| `reports/2026-09-08-pass42-single-file-route.md` | **created** | DELIVERABLE |

**Three source files changed, as the constraint requires.** No fourth source file was modified.

**Not touched:** every other folder under `~/Xcode`; the reference clone (not read this pass — Pass
41 §2.3 already settles the server side, and the brief says not to re-derive it); the server's data,
config and admin UI; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share; `design/`;
`reports/2026-09-08-pass40-session-start-values.md`; the Xcode project, `Info.plist`, the
entitlements file and every build setting.

**No new dependency of any kind.** No credential, token, device id or account identifier appears in
this report — the client id in the POST body is redacted.

---

## CLOSING SUMMARY FOR THE OWNER

**What you should now see when you play a recording.** The app asks the 1.8.0 server for the whole
recording as one finished MP4 instead of a growing playlist. Proved on Home Theater: the request
went out with `"format":"file"`, the server answered `"format":"file"` with
`/api/play/file/…/video.mp4`, and playback ran from it. Live TV, the cameras and radio are on
exactly the path they were on before — that is decided at a single line and they cannot reach the
new one.

In practice: **a short pause before a recording starts** while the server rebuilds the file, and
then the scrub bar should be the whole recording rather than only the part the server has written.
Fast-forward should work immediately instead of after a wait, and resuming should land where you
left off rather than minutes further on. Commercial skip is untouched and still worked in the test.

**What only you can judge.** Two things.

First, **whether the "LIVE" badge is actually gone.** I cannot see the screen and I will not claim
it. I have to flag something honest, though: the test harness's dump of the on-screen text still
contained the word `LIVE` while the player was up. That dump also contained the show-detail text
behind the player at the same time, so it may be reading a stale or underlying element rather than
the transport bar — it is genuinely ambiguous and I am not going to resolve it by guessing. **Please
look at the transport bar yourself.** If LIVE is still there, the change did not achieve its main
purpose and I would rather know that now.

Second, **whether the wait before playback is acceptable.** Their measurements were on a different
machine, never on your Unraid box, and nothing on screen tells you the app is waiting rather than
stuck — the Starting screen says "Preparing the recording" with a pulsing bar and no progress. What
that screen should say during a long wait is open question 7.3 and no step let me change it.

**What this pass cost.** Three source files, 121 lines added and 6 removed. Two clean builds, two
device installs and two harness runs. One temporary three-line diagnostic, used to capture the wire
traffic and then fully removed. **It is committed but not pushed** — it is behind your test gate, so
the push waits for you. One side effect, disclosed: your D.B. Cooper recording now has a resume
position deep inside it, from my two test runs.

**The three things I am least certain about.**

1. **The LIVE badge**, above. It is the main reason for the change and it is the one thing I could
   not verify.
2. **What happens on a long remux.** The recording I tested is 1.12 GB and came back quickly. A
   multi-gigabyte one may wait far longer, and whether the Apple TV's video player will sit through
   a connection that stays silent that long is untested — I set the app's own patience to 11 minutes
   to be safe, but the player has timeouts of its own that I do not control.
3. **The two kinds of recording the server refuses outright** — anything not H.264/AAC, and anything
   still recording. They should show a clear error rather than play. I traced the path but never
   provoked either, because the recording I had available is neither.
