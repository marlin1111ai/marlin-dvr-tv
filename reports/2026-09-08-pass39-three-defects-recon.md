# Pass 39 — Pass 38 pushed, then three owner-reported defects reconnoitred

**Date:** 2026-09-08
**Part one wrote and pushed. Part two is read-only: no Swift written, nothing fixed.**
**The server at 192.168.1.250 was not called, probed or curled at any point in this pass.**

---

## 0. The contract, recreated — and the clone byte-identical

`~/Desktop/marlin-dvr-context/` had gone again. Recreated with two `git show`s inside the clone,
no fetch:

```
$ mkdir -p ~/Desktop/marlin-dvr-context
$ cd ~/Xcode/marlin-dvr-reference
$ git show origin/main:HLS-CLIENT-API.md > ~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md
$ git show origin/main:COLD-START.md     > ~/Desktop/marlin-dvr-context/MARLIN-DVR-SERVER-COLD-START.md
$ wc -l ~/Desktop/marlin-dvr-context/*.md
     595 HLS-CLIENT-API.md
    1350 MARLIN-DVR-SERVER-COLD-START.md
$ shasum -a 256 ~/Desktop/marlin-dvr-context/*.md
ad8c1e5abe4474f9fb6635371dffd95c90339836b20f98f87c069061e552f56b  HLS-CLIENT-API.md
ac35e17b2cc8267d8af989cb545f05550c338f4ded7a88f8c6959cec09f118d6  MARLIN-DVR-SERVER-COLD-START.md
```

**Proof the clone did not change** — the same four readings before and after:

| | before | after |
|---|---|---|
| `git status --porcelain` | `?? README-REFERENCE.md` | `?? README-REFERENCE.md` |
| `git rev-parse HEAD` | `9325d944…` | `9325d944…` |
| `git rev-parse origin/main` | `c417c60a…` | `c417c60a…` |
| sha256 over every file outside `.git` | `37d916c824baa3ec111f232b36f1006a13f0c7998e6f212d728d56ae5c7664b5` | `37d916c824baa3ec111f232b36f1006a13f0c7998e6f212d728d56ae5c7664b5` |

No fetch, pull, checkout, merge, commit or push was run there.

---

## PART ONE — acceptance and push

### 1. The acceptance, recorded

The owner tested Pass 38 on Home Theater on 2026-09-08 and accepts it: the skip prompt works.

- **`COLD-START.md`** gains the Pass 37 and Pass 38 entries in the "What is built" narrative,
  following the form every accepted pass uses; a new **`### KNOWN AND UNFIXED after Pass 38`**
  section; a rewritten **`## Next step`** naming the three defects below; and the
  `CommercialSkipUITests` harness command with the two things Pass 38 learned about running it.
- **`DECISIONS.md`** gains **`## 2026-09-08 (Pass 38 — commercial skip)`** — the acceptance, the
  scope the owner settled, the two §10-mandated decodings, the arming rules, the non-focusable
  prompt and the claimed press, the seek choice, and the disclosed cost of the evidence.

The first entry of KNOWN AND UNFIXED after Pass 38 is the pre-existing defect Pass 38 measured and
did not fix, recorded as fact with no proposal attached:

> **A resumed recording starts well past its resume point.** Measured on Home Theater in Pass 38
> with a disclosed, reverted diagnostic: a session created with `start=1680` was already at
> **1988 s at its fourth tick**, about four seconds in — five minutes further on than the resume
> position asked for. Recordings are an HLS **EVENT** playlist the server is still writing
> (contract §3), and AVPlayer joins it near its live edge rather than at its beginning; the
> transport bar says "LIVE" on these items, which is the same fact showing on screen. **Nothing in
> Pass 38 causes this and nothing in Pass 38 changed it** … It is pre-existing and unfixed.
>
> **Because of that, "a playback that starts inside a break offers it" could not be proved.**

### 2. The push, and the three readings

```
$ git push origin main
To github.com:marlin1111ai/marlin-dvr-tv.git
   18b4c53..424c584  main -> main
```

Verified by reading the remote back, each as its own command:

```
$ git fetch origin
(exit 0)

$ git rev-parse HEAD
424c584a04f81a8bbade8c46422f1b4015992938

$ git rev-parse origin/main
424c584a04f81a8bbade8c46422f1b4015992938

$ git ls-remote origin main
424c584a04f81a8bbade8c46422f1b4015992938	refs/heads/main
```

**All three agree.** Fast-forward, nothing forced, rebased or amended:

```
$ git merge-base --is-ancestor 18b4c53 HEAD && echo "yes — fast-forward, nothing rewritten"
yes — fast-forward, nothing rewritten

$ git diff --stat 18b4c53..424c584
 COLD-START.md                                      | 129 +++-
 DECISIONS.md                                       |  62 ++
 Marlin DVR TV/CommercialSegments.swift             | 155 +++++
 Marlin DVR TV/PlayerHost.swift                     |  70 +-
 Marlin DVR TV/PlayerModel.swift                    | 159 +++++
 Marlin DVR TV/PlayerScreen.swift                   |  43 +-
 Marlin DVR TVUITests/CommercialSkipUITests.swift   | 382 +++++++++++
 reports/2026-09-08-pass37-commercial-skip-recon.md | 748 +++++++++++++++++++++
 reports/2026-09-08-pass38-commercial-skip.md       | 572 ++++++++++++++++
 9 files changed, 2303 insertions(+), 17 deletions(-)
```

Three commits landed: `d259c5f` (the commercial skip), `344b75d` (the Desktop-folder note) and
`424c584` (this pass's notebook work). The working tree was clean afterwards.

---

# PART TWO — the recon (read-only)

Scope was the whole `Marlin DVR TV/` source tree and the whole notebook, not an inherited file
list. Every negative below is a `grep` actually run this pass, not a memory.

---

## 3. ITEM 1 — audio out of sync with video on recordings

### 3.1 Every parameter the app sends when it creates a session

`PlaybackSession.swift:41-51` is the whole of it — five fields, and there is no sixth:

```
41	    private struct CreateBody: Encodable {
42	        let kind: String
43	        let id: String
44	        let format: String
45	        let client: String
46	        let start: Double
47	    }
…
51	        let body = CreateBody(kind: request.kind, id: request.targetID, format: "hls", client: clientID ?? "", start: request.startSeconds)
```

What §2 says each one does (`HLS-CLIENT-API.md:64-70`):

| Field | What the app sends | Contract |
|---|---|---|
| `kind` | `"recording"` (`PlayRequest.swift:26-32`) | "`"recording"`, `"live"` or `"camera"`" (`:66`) |
| `id` | `episode.id` (`PlayRequest.swift:35-41`) | "the recording / channel / camera id (§2.1)" (`:67`) |
| `format` | the literal **`"hls"`**, hard-coded | "**`"hls"`** selects HLS. Absent, `""` or `"mp4"` gives the old fragmented-MP4 pipe (`stream.go:211`, `:289`)" (`:68`) |
| `client` | the persisted client id | "your client id from §1 (optional)" (`:69`) |
| `start` | `request.startSeconds` | "seconds; **recordings only**, see §3" (`:70`) |

**There is no parameter that selects copy mode versus transcode mode, and the app has no way to
ask for one.** §2.2 (`:101`) says the server decides it from the file:

> `mode` | `"copy"` (remux, no re-encode) or `"transcode"` (H.264/AAC). Recording: copy when the
> file is H.264 with AAC/MP3/no audio, else transcode (`stream.go:247-253`).

**And on the owner's recordings the server chose `copy` every single time.** Twenty play sessions
across three different recordings on Home Theater in Pass 38, from the app's own console
(session ids redacted; `mode=` is the server's own answer, `PlayerModel.swift:122`):

```
[player] session <redacted> recording mode=copy start=0.0    duration=2570.568
[player] session <redacted> recording mode=copy start=0.0    duration=2402.4
[player] session <redacted> recording mode=copy start=0.0    duration=54.054
[player] session <redacted> recording mode=copy start=194.000662764  duration=2570.568
[player] session <redacted> recording mode=copy start=931.000155362  duration=2570.568
…  20 sessions in total, every one mode=copy
```

**Nothing is being re-encoded.** Whatever is wrong with the audio, no encoder produced it.

### 3.2 Every AVFoundation setting the app applies

This is the complete list. `PlayerModel.swift:153-159`:

```
153	    private func attach(_ url: URL) {
154	        let item = AVPlayerItem(url: url)
155	        item.preferredForwardBufferDuration = 0
156	        item.externalMetadata = Self.metadata(for: request)
157	        observe(item)
158	        player.replaceCurrentItem(with: item)
159	        player.play()
```

and `PlayerHost.swift:112-117`:

```
112	    func attach(player: AVPlayer, linearOnly: Bool, shortWindowSelect: Bool) {
113	        playerController.player = player
114	        playerController.showsPlaybackControls = true
115	        playerController.requiresLinearPlayback = linearOnly
116	        playerController.allowsPictureInPicturePlayback = false
```

`preferredForwardBufferDuration = 0` is **the automatic setting, not a restriction** — the SDK
header says so (`AppleTVOS.sdk/…/AVPlayerItem.h:524-527`):

> Indicates the media duration the caller prefers the player to buffer from the network ahead of
> the playhead … **If it is set to 0, the player will choose an appropriate level of buffering for
> most use cases.**

`AVPlayer()` is default-constructed (`PlayerModel.swift:39`), and `AVPlayerItem(url:)` is built
with **no `AVURLAsset` options at all** — in particular no MIME override.

**Everything the app does not do**, each a `grep` over `Marlin DVR TV/*.swift` run this pass,
excluding `RadioPlayer.swift` which is the unrelated audio-only path:

```
AVAudioSession:                                0 hit(s)
audioTimePitchAlgorithm:                       0 hit(s)
audioMix:                                      0 hit(s)
AVMediaSelectionGroup:                         0 hit(s)
selectMediaOption:                             0 hit(s)
preferredPeakBitRate:                          0 hit(s)
automaticallyWaitsToMinimizeStalling:          0 hit(s)
setRate:                                       0 hit(s)
player.rate:                                   0 hit(s)
masterClock:                                   0 hit(s)
sourceClock:                                   0 hit(s)
AVURLAsset:                                    0 hit(s)
allowedAudioSpatialization:                    0 hit(s)
```

`Info.plist` carries no `UIBackgroundModes` and no audio key — it holds exactly two entries,
`NSLocationWhenInUseUsageDescription` and the ATS `NSAllowsLocalNetworking` exception. The
entitlements file holds one key, `com.apple.developer.weatherkit`. The only `audio` mention in the
whole video path is a comment in `RadioStation.swift:9`.

### 3.3 Does the app do anything to audio/video timing?

**No.** It hands the server's playlist URL to `AVPlayerItem(url:)` untouched. It never selects a
track, never sets a rate, never installs a timebase or clock, never builds an audio mix, and never
reads `AVPlayerItem.duration` — every `duration` in the app is the play session's
(`PlayerModel.swift:121`, `:725`) or a `CMTimeRange`'s (`:210`, `PlayerHost.swift:212`).

### 3.4 Could the seeks leave audio and video offset? — traced, not speculated

There are exactly three seek call sites for a recording, and all three are the same call shape:

| Site | Line | When it can run |
|---|---|---|
| `frameStep` | `PlayerModel.swift:359` | `guard isRecording, isPaused, phase == .playing, frames != 0, …` (`:343`) — **paused only** |
| Pass 38's `skipCommercialBreak` | `PlayerModel.swift:501` | `guard let prompt = commercialPrompt, phase == .playing, …` (`:485`) — **only while the prompt is up** |
| live pause-point recovery | `PlayerModel.swift:270` | inside `recoverIfPausePointLeftWindow`, reached only from `if isLive` at `:253` / `:257` — **never on a recording** |

Both recording seeks are `item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)`
preceded by `item.cancelPendingSeeks()`. A seek re-primes both tracks to one presentation time; it
is not a mechanism that can shift one against the other, and neither call touches rate, tracks or
any clock.

The seek-past-prepared restart (`timeJumped()`, `PlayerModel.swift:540-554`) does not offset
anything either — it throws the item away and builds a new session, so whatever the new stream is,
it is the new stream's property.

**And none of the three had run when the desync was seen.** Across every device run of Pass 38 —
thirteen captured console logs — `[player] seek past the prepared range` printed **0 times**:

```
$ grep -c "seek past the prepared range" console-*.log
… 0 for every one of the thirteen files
```

Frame stepping only exists while paused, and the commercial skip only exists for the five seconds a
prompt is up. The owner sees the desync while simply watching.

### 3.5 The owner's evidence — the browser plays the same recordings in sync

**What the browser gets versus what this app gets.** They are two different routes off the same
session record. §8 of the contract (`HLS-CLIENT-API.md:290-292`):

> The fragmented-MP4 route `GET /api/play/s/{id}.mp4` (`main.go:291`, `stream.go:315`) still
> exists unchanged and **is what the browser uses**; it is a chunked, length-less stream with no
> seeking.

The app gets `GET /api/play/hls/{id}/{file}` where `{file}` is `index.m3u8`, `init.mp4` or
`segNNNNN.m4s` (§5, `:209-213`).

**Same ffmpeg arguments up to the muxer; different muxer.** The server's own notebook, Pass 15
(`MARLIN-DVR-SERVER-COLD-START.md:241-249`):

> **Pass 15 (HLS Pass A)** HLS output for recordings and cameras (`cmd/marlin-dvr/hls.go`):
> `POST /api/play/sessions` with `format: "hls"` starts ffmpeg with **the same input/codec
> arguments as the browser path** but the **`hls` muxer** writing `init.mp4`, `segNNNNN.m4s` and
> `index.m3u8` into `data/stream/hls/<session>/` … Recordings: EVENT playlist, 4-s fMP4 segments,
> every segment kept for the session (decision 2a), `#EXT-X-ENDLIST` when ffmpeg finishes (copy
> and transcode modes; the transcode variant forces a keyframe every 4 s).

They are **not the same ffmpeg invocation** — each session starts its own process — but they are
built from the same argument function up to the output stage, and the encode mode is decided by the
file, not by the pipe (§2.2 `:101`, quoted in 3.1). The output halves are separate by design:
`hlsOutputArgs` is a `switch kind` at `hls.go:57-72` and the browser path is explicitly outside it
(`MARLIN-DVR-SERVER-COLD-START.md:320-322`: "Live gets its own arm of the `switch kind` in
`hlsOutputArgs` … so recordings, cameras, **the browser's fragmented-MP4 path** and the watchdog are
untouched").

So for one of the owner's recordings both pipes are a **`-c copy` remux of the same source file**,
and the only difference is that the browser gets one continuous fragmented MP4 while the Apple TV
gets it cut into segments with an `init.mp4` and a playlist.

**Does his evidence rule out the recording file itself?** **Yes.** The browser decodes the same
file's same elementary streams — same input arguments, same copy mode, no re-encode on either side
— and plays it in sync. If the `.mpg` carried the offset, it would carry it to the browser too.

**Does it rule out the server?** **No — it rules out one half of the server.** It clears the source
file, the input stage and the codec stage, all of which the two routes share. It says nothing about
the HLS muxing stage, which is the one part of the server the browser never exercises.

**The single observation that would separate the two hypotheses.** Fetch one HLS session's
`init.mp4` and its first few `segNNNNN.m4s` and read the audio and video track timestamps out of
them — the `tfdt` `baseMediaDecodeTime` per track against each track's timescale — and compare the
audio-minus-video offset with the same measurement taken on the source file. If the packaged
segments already carry the offset, the server's HLS packaging owns it; if they are aligned and it
only appears on screen, AVFoundation's handling of that packaging owns it. **That observation
cannot be made from this project**: every one of those bytes comes from `http://192.168.1.250:8090/`,
which is on this pass's ABSOLUTE DO-NOT-TOUCH list. It is a measurement for the marlin-dvr project,
or one the owner can make himself by opening the app's own HLS URL in a player on his Mac.

**Plainly: is there anything in this app that could cause it?** **No.** The complete list of what
the app does to the item is §3.2 above — construct it from a URL, set a documented-as-automatic
buffer hint, attach two metadata strings for the transport bar, play, pause and seek. None of those
can move audio relative to video, and the two seeks that exist do not run while the owner is simply
watching (§3.4). **On the evidence this is the packaging, not the client — a marlin-dvr matter, and
this project does not fix it.** No client-side compensation was designed, proposed or written.

---

## 4. ITEM 2 — a "LIVE" icon shows while watching a recording

### 4.1 Every place the app itself draws a live indicator

Two, and only two. `grep -rn '"LIVE'` over the source finds nothing else.

| Where | file:line | The exact condition |
|---|---|---|
| `LiveHUD`'s capsule — `"LIVE"` or `"LIVE · −…"` | `PlayerScreen.swift:190` | reached only through the `hud` dispatcher's `else` branch, `:84-86` |
| `PausedLiveOverlay`'s `"LIVE · HELD"` | `PlayerScreen.swift:348` | `if model.isPaused && model.isLive` (`:79`) |

The dispatcher, `PlayerScreen.swift:77-88`:

```
77	    @ViewBuilder
78	    private var hud: some View {
79	        if model.isPaused && model.isLive {
80	            PausedLiveOverlay(model: model)
81	        } else if model.hudVisible || model.notice != nil {
82	            if model.isRecording {
83	                RecordingHUD(model: model)
84	            } else {
85	                LiveHUD(model: model)
86	            }
87	        }
88	    }
```

**A recording can reach neither.** `PlayerModel.swift:97-99`:

```
97	    var isLive: Bool { if case .live = request { return true }; return false }
98	    var isRecording: Bool { if case .recording = request { return true }; return false }
```

Both are read straight off the `PlayRequest` enum case the screen was constructed with
(`PlayRequest.swift:12-16`). For a recording `isLive` is structurally `false` and `isRecording` is
`true`, so line 79 fails and line 82 takes the `RecordingHUD` branch. There is no flag, no server
field and no timer that can flip either one.

(The only other `isLive` in the codebase is `GuideBlock.isLive`, `Models.swift:97` — a Guide
listing field, never read by the Player.)

### 4.2 So where does the owner's LIVE come from — the app is faithful, the badge is Apple's

**It is `AVPlayerViewController`'s own transport bar, not this app.** The evidence is in Pass 38's
captured screen dumps, which list every static text on screen. Two facts settle it:

1. The app's own `RecordingHUD` strings are **absent** at the moments LIVE is present.
   `RecordingHUD` always draws `"Resume kept by \(model.clientName)"` (`PlayerScreen.swift:255`)
   and, while not fully prepared, `"Prepared to …"` (`:250`). Across the nine harness logs:

   ```
   $ grep -c "Resume kept by" run*.log pause.log final.log
   … 0 in eight of the nine files, 1 in run3.log
   $ grep -c "Prepared to" run*.log pause.log final.log
   … 0 in all nine
   ```

2. LIVE appears in the same run of strings as Apple's transport clock and the metadata subtitle
   the app hands the transport (`PlayerModel.metadata(for:)`, `:166-177`), and nowhere near an app
   string. From `run2.log`, twelve seconds into playback — after `showHUD(for: 6)` had long
   expired, so the app was drawing nothing at all:

   ```
   … "S4 E14 · Who Is D.B. Cooper? · 9001 HISTORY", "02:09", " ", " ", " ", "LIVE"
   ```

**Why Apple draws it.** The recording is an HLS **EVENT** playlist that the server is still
writing. §3 of the contract (`HLS-CLIENT-API.md:117-119`):

> **EVENT playlist:** it starts short and grows as ffmpeg works; **every segment is kept for the
> life of the session** (no `delete_segments` on this branch, `hls.go:66`). When ffmpeg finishes
> the playlist carries `#EXT-X-ENDLIST`.

Until that `#EXT-X-ENDLIST` is written, AVFoundation has no definite duration for the item and
`AVPlayerViewController` renders its live transport, badge included. **Nothing in this app keys any
indicator off the playlist type** — the app never reads `AVPlayerItem.duration`, never inspects the
playlist, and both of its own live indicators key off the `PlayRequest` case instead.

**So: the app is not misreading a flag, and no server field is being shown wrongly. The app draws
no live indicator for a recording at all.** The badge is Apple's UI reporting, correctly for what
it has been handed, that the stream it is playing has not been declared finished. The thing that is
wrong is upstream of the badge: the app is asked to play a completed recording and is handed a
still-open EVENT playlist.

---

## 5. ITEM 3 — you must wait before fast forwarding a recording

### 5.1 Nothing in the app refuses or swallows a forward seek

The app has exactly **one** press pipeline that can touch the Player —
`PlayerContainerController.pressesBegan/pressesEnded`. A sweep for every alternative found none:
`onMoveCommand` 0 hits, `onPlayPauseCommand` 0 hits, and the only other `UIPress` code in the app is
`RemoteHold`'s window recognizer, which is `.select`-only (`RemoteHold.swift:124`) and is
**suspended for the whole time a Player is on screen** (`ContentView.swift:46`,
`hold.suspended = id != nil`).

`PlayerHost.swift:217-240`, in full:

```
217	    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
218	        if presses.contains(where: { $0.type == .menu }) {
219	            onMenu()
220	            return
221	        }
224	        if presses.contains(where: { $0.type == .leftArrow }) {
225	            if frameStep(-1) { swallowArrowRelease = true; return }
226	        }
227	        if presses.contains(where: { $0.type == .rightArrow }) {
228	            if frameStep(1) { swallowArrowRelease = true; return }
229	        }
233	        if presses.contains(where: { $0.type == .select }) {
234	            if onSelectSkip() { swallowSelectRelease = true; return }
235	        }
236	        if shortWindowSelect, presses.contains(where: { $0.type == .select }) {
237	            handleShortWindowSelect()
238	        }
239	        super.pressesBegan(presses, with: event)
240	    }
```

Both early returns are conditional on a callback answering **true**, and on a *playing* recording
both answer false at their first guard:

```
PlayerModel.swift:343	guard isRecording, isPaused, phase == .playing, frames != 0, let item = player.currentItem else { return false }
PlayerModel.swift:485	guard let prompt = commercialPrompt, phase == .playing, let item = player.currentItem else { return false }
```

`isPaused` is false while watching, and `commercialPrompt` is nil except for a five-second window.
So the press falls through to `super` and the transport bar's own handler.

`requiresLinearPlayback`, which really would forbid seeking, is set from `linearOnly`
(`PlayerHost.swift:115`) and `PlayerScreen.swift:36` passes `linearOnly: model.isCamera` —
**false for a recording**, true only for cameras.

**Conclusion: the app is not the gate.** No app code can refuse, delay or swallow a forward seek on
a playing recording.

### 5.2 What the gate is

What is left is the seekable range of a playlist that is still being written. The app reads it,
never sets it — `PlayerModel.swift:208-213`:

```
208	    private var seekableRange: (start: Double, end: Double)? {
209	        guard let item = player.currentItem else { return nil }
210	        let ranges = item.seekableTimeRanges.map(\.timeRangeValue).filter { $0.duration.isNumeric && $0.duration.seconds > 0 }
211	        guard let first = ranges.first, let last = ranges.last else { return nil }
212	        return (first.start.seconds, last.end.seconds)
213	    }
```

and stores its end as `preparedTo` once a second (`:223`, `preparedTo = startOffset + range.end`).
`AVPlayerViewController`'s scrubber and its ten-second skip can only move inside
`seekableTimeRanges`; the contract says that range starts short and grows (§3 `:117-119`, quoted
above), so early in a session there is little to fast-forward into and a forward press clamps to
what exists. The app's own HUD says as much in the copy it was given in sweep 3
(`PlayerScreen.swift:250`):

> "Prepared to \(PlayerTime.clock(model.preparedTo)). Jumping past that point restarts playback
> there — a second or two of buffering, not an error."

There is a second, sharper effect sitting on the same edge — `timeJumped()`,
`PlayerModel.swift:540-554`, which is **KNOWN AND UNFIXED** and was not touched:

```
545	        guard isRecording, phase == .playing, !restartingBeyond, let attachedAt, Date().timeIntervalSince(attachedAt) > 3,
546	              let item = player.currentItem, let range = seekableRange else { return }
547	        let t = item.currentTime().seconds
548	        guard t.isFinite, range.end - t < 1.5, !fullyPrepared else { return }
…
551	        restartingBeyond = true
552	        await restart(at: target)
```

Land within 1.5 s of the prepared edge while `!fullyPrepared` and the app tears the session down and
rebuilds it at that position, which passes through `phase = .starting` and puts the Starting screen
up. `fullyPrepared` is `duration > 0 && preparedTo >= duration - 2` (`PlayerModel.swift:101`).

**How long is the wait, and what ends it?** It ends when ffmpeg finishes remuxing the file: the
playlist gains `#EXT-X-ENDLIST`, the whole recording becomes seekable, and `fullyPrepared` turns
true so the restart above can no longer fire. **This pass cannot put a number on it**, because the
only way to measure it is to watch a session's playlist grow, which means calling the server. What
can be said from evidence already in hand: it is fast, and it is not the same every time. In Pass
38, a session created with `start=1680` had **308 seconds of content within about four seconds** of
starting (`[diag] t4 pos=1988.08 off=1680.00`), which is roughly 77× real time and would finish a
43-minute recording in well under a minute; yet in another run of the same recording started at
`start=0`, playback was still at 176 s three minutes in, so at that moment the playlist had *not*
run away. Both are single measurements of the same race between ffmpeg and AVPlayer's first parse,
and neither is a duration for the owner's complaint. **Measuring it properly needs either a device
run or a server call, and both are out of scope for this pass.**

### 5.3 Shared root causes

**Yes, with the resumed-recording defect from step 1 — the same root, three symptoms.** The
recording is handed to AVPlayer as an EVENT playlist that has not been declared finished. That one
fact produces: **item 2**, because AVFoundation has no definite duration and `AVPlayerViewController`
draws its live transport; **item 3**, because only the written part is seekable; and the **resumed
recording overshoot**, because AVPlayer joins a growing playlist near its live edge rather than at
its start. All three end at the same moment, when `#EXT-X-ENDLIST` is written.

**With the erratic stepping near the end of the prepared range (KNOWN AND UNFIXED after Pass 29),
partly.** That entry names `timeJumped()`'s restart as its suspect, and §5.2 shows the same restart
sitting on the same prepared edge, so they share the edge and the suspect. They are not the same
symptom: Pass 29's was measured while **paused and frame-stepping** at 1:05:27 of a 1:11:10
recording, and this one is about forward seeking while playing. Nothing was fixed in either.

---

## 6. THE SORTING

For the owner's three items only. No item was added.

| # | Item | Pile | Why | Rough size |
|---|---|---|---|---|
| 1 | **Audio out of sync on recordings** | **NOT OURS** | Every parameter, setting and seek in this app is inventoried in §3 and none can shift audio against video; the app hands the playlist to AVPlayer untouched. The owner's own evidence clears the file, the input stage and the codec stage — the browser shares all three and is in sync — and leaves the HLS muxing stage, which only the app's route exercises. That is `hls.go`, a marlin-dvr file. **Raise it there with §3.5's measurement.** | nothing here; a recon-and-fix pass for marlin-dvr |
| 2 | **LIVE icon on a recording** | **STANDALONE** | Not a bug in the drawing — the app draws no live indicator for a recording at all (§4.1) — so there is no small fix. Anything that changes it changes what the app plays or what the server declares: either the server closes the playlist for a completed recording, or the client stops presenting an open EVENT playlist as an ordinary recording. That is the Player's session and attach path, which is fragile code, and it is entangled with items 1 and 3. **It cannot be swept with anything.** | small if the answer is a server change; a careful Player pass if not |
| 3 | **Wait before fast forward** | **STANDALONE** | Same root as item 2 and as the resumed-recording overshoot (§5.3), and it lives on the prepared-range edge that `timeJumped()` already misbehaves on (KNOWN AND UNFIXED after Pass 29). It touches the Player's seek path, which the prompt names as automatically standalone, and it needs a measurement on the device before any change is designed. | one pass to measure, then one to change; not sweepable |

**Nothing is SAFE-TO-SWEEP.** Two of the three are the same root cause in the Player's most
fragile area and the third is not this project's code. If the owner wants one pass rather than
three, items 2 and 3 are the pair that belong together — they end at the same instant and would be
proved by the same device run — but that pass is a Player-seek pass and needs its own scope.

---

## OPEN QUESTIONS

Raised, not acted on. Nothing was built, changed, fixed or proposed.

1. **The one measurement that would settle item 1 cannot be made from this project.** Reading the
   audio and video `baseMediaDecodeTime` out of one HLS session's `init.mp4` and segments requires
   fetching them from `192.168.1.250:8090`, which is on the do-not-touch list. **Does the owner
   want to authorise a read-only fetch of one session's segments in a later pass**, or should it go
   to marlin-dvr as a request? Without it, "the packaging carries the offset" is a conclusion by
   elimination — sound, but not directly measured.

2. **The length of the fast-forward wait is unmeasured.** §5.2 gives two bounds from Pass 38 data
   that disagree by two orders of magnitude, because both are single samples of a race. A number
   needs either a device run watching `preparedTo` climb or a server-side look at the playlist. Both
   were out of scope here.

3. **Whether the desync varies with position, or is a fixed offset, is unknown.** The owner reported
   it as a fact about watching recordings; nobody has recorded whether it is constant, grows, or
   appears only after a seek. That is one sentence from him and it changes which server-side
   mechanism is likely.

4. **`canUseNetworkResourcesForLiveStreamingWhilePaused` is not set, and its default is `NO`.** The
   SDK header (`AVPlayerItem.h:517-520`) says that with it off, `seekableTimeRanges` is **not**
   periodically updated while paused. Noticed while inventorying §3.2 and named here only because it
   touches the same prepared-range edge as item 3. **Not changed, and not proposed** — it is outside
   the owner's three items.

5. **Item 2 has no fix inside this app that would not change behaviour the owner has accepted.**
   The badge is Apple's, drawn correctly for an open EVENT playlist. Suppressing it means either
   changing what the server declares or replacing `AVPlayerViewController`'s transport — the second
   would throw away Pass 7's standing "Apple's transport UI as-is" decision, Pass 29's arrow
   ownership and Pass 38's Select ownership. **Reported as a question, not attempted.**

6. **This pass ran nothing.** No build, no simulator, no device, no server call. Every claim is
   read from source, from the contract, from the server's own notebook, or from console and test
   output already captured on Home Theater in Pass 38 and quoted here.

---

## SCOPE CHECK

| Path | Access | Required by |
|---|---|---|
| `~/Xcode/marlin-dvr-reference` | two `git show origin/main:…`; **no** fetch/checkout/merge/commit/push/write; unchanged, proved | step 0 |
| `~/Desktop/marlin-dvr-context/HLS-CLIENT-API.md` | **written** (recreated), then read | step 0; steps 3, 3b, 4, 5 |
| `~/Desktop/marlin-dvr-context/MARLIN-DVR-SERVER-COLD-START.md` | **written** (recreated), then read | step 0; step 3b |
| `COLD-START.md` | read, then **edited** | WHAT TO READ FIRST; step 1 |
| `DECISIONS.md` | read, then **edited** | WHAT TO READ FIRST; step 1 |
| `reports/2026-09-08-pass37-…md`, `reports/2026-09-08-pass38-…md` | read | WHAT TO READ FIRST |
| `Marlin DVR TV/PlaybackSession.swift` | read (whole) | step 3 |
| `Marlin DVR TV/PlayerModel.swift` | read (whole) | steps 3, 4, 5 |
| `Marlin DVR TV/PlayerHost.swift` | read (whole) | steps 3, 5 |
| `Marlin DVR TV/PlayerScreen.swift` | read (whole) | steps 3, 4, 5 |
| `Marlin DVR TV/PlayRequest.swift`, `Models.swift`, `RemoteHold.swift`, `ContentView.swift` | read | steps 3, 4, 5 |
| every `*.swift` in `Marlin DVR TV/` and `Marlin DVR TVUITests/` | read via `grep` (AV settings, `LIVE`, `isLive`, press handlers, seek guards, `duration`) | steps 3, 4, 5 |
| `Info.plist`, `Marlin DVR TV.entitlements` | read | step 3 |
| `AppleTVOS.sdk/…/AVPlayerItem.h` | read (`:512-527`) | step 3 |
| Pass 38's captured console and test logs (scratchpad) | read | steps 3, 4, 5 |
| `reports/2026-09-08-pass39-three-defects-recon.md` | **written** (this file) | DELIVERABLE |
| the server at 192.168.1.250:8090 | **not called, probed or curled** | — |

**This report is written after the push and is left uncommitted**, as the brief directs. `git push`
was run once, in step 2, before part two began; nothing in part two has been committed or pushed.

**Not done, per the scope lock.** No Swift written, not a stub and not a disabled one; nothing in
steps 3-5 fixed, patched or refactored, including everything in KNOWN AND UNFIXED and the
`canUseNetworkResourcesForLiveStreamingWhilePaused` observation; **no client-side compensation for
the desync designed or proposed**; no item added to the owner's three; Pass 38's commercial skip
untouched; the server not contacted; the reference clone not fetched, checked out or modified;
`design/` not opened; no notebook file edited beyond `COLD-START.md` and `DECISIONS.md` as steps 1-2
name.

**Credential scan.** Play-session ids are redacted from every quoted console line. The Apple TV's
LAN address, its `devicectl` device identifier and the client id are not reproduced. The only
addresses here are `192.168.1.250:8090`, already in `ServerAPI.swift:15` and throughout the
notebook, and the two image digests quoted from the server's own notebook. Recording ids are not
quoted in this report.

---

## CLOSING SUMMARY FOR THE OWNER

**(a) The audio sync problem is the server's, not this app's.** The app does nothing to audio at
all — no volume, no track picking, no timing, no speed control. It takes the address the server
gives it and hands it straight to Apple's player. Your own test proves the recording file is fine,
because the web page plays the same file and it is in sync. What the web page never uses is the one
piece the Apple TV does use: the server chops the recording into four-second pieces for the Apple
TV, and the browser gets it in one continuous piece. That chopping is the only difference left, and
it lives in the DVR server. **This is one to raise with the marlin-dvr project**, and the report
above names the exact measurement that would confirm it — which needs someone to look at the
server, and this project is not allowed to.

**(b) The LIVE icon is not ours.** This app never puts a LIVE badge on a recording — it cannot; the
code that draws one only exists for live channels. What you are seeing is Apple's own player
controls. The server sends the recording as a stream that is still being written and never says
"this is the end", so Apple's player assumes it is a live broadcast and labels it accordingly. It is
Apple reporting honestly what it was handed.

**(c) The fast-forward wait is the same thing again.** You cannot fast forward into a part of the
recording the server has not sent yet, and when you start playing, it is still sending. Once it
finishes, the whole recording is available and fast forward works normally. **I cannot give you a
number of seconds** — measuring it needs either the Apple TV in front of me or a look at the server,
and this pass was read-only, so I am not going to guess. It is fast; it is not the same every time.

**(d) None of the three can be swept together.** The sync problem is not our code. The LIVE icon and
the fast-forward wait are actually **one problem wearing two faces** — both caused by the recording
being sent as an unfinished stream — and they will both stop the moment that changes. But that
sits in the Player's most delicate code, next to something already known to misbehave, so it wants
its own careful pass with a measurement first.

**(e) The three things I am least certain about.**

1. **I cannot prove the desync is in the packaging — I can only prove it is not in this app.** I
   inventoried everything the app does and none of it can move audio against video, and your browser
   test clears the file itself. That leaves the server's chopping stage by elimination, which is
   good reasoning but not a direct measurement. The measurement needs the server.
2. **I do not know how long the fast-forward wait is.** Two pieces of evidence I already had
   disagree wildly, because they measure a race rather than a duration. Anyone who tells you a
   number without watching it happen is guessing.
3. **Whether fixing the "unfinished stream" problem is a server change or an app change is genuinely
   open.** The tidiest fix is the server saying "this recording is complete" — but that is not my
   call, and I have not proposed it as work; I have only recorded that it is where the three
   symptoms meet.
