# Pass 27 — Frame-step recon: can a paused recording be stepped? — 2026-09-07

**No. Not forward, not backward, not by one frame and not to a keyframe.** Measured on Home
Theater on a real recording: paused, `AVPlayerItem.canStepForward` and `canStepBackward` are both
**false**, and calling `step(byCount: 1)` and `step(byCount: -1)` ten times each moves the item
**exactly zero nanoseconds**. The same on a copy-mode recording and a transcode-mode one, so it is
not a keyframe-interval problem. The one related capability the item does report is
`canPlaySlowForward = true`.

Live TV was out of scope by the owner's call and was not touched.

**Citation keys.** `File.swift:NN` = line NN of that file at `d401aab` (Pass 26). `hls.go:NN`,
`stream.go:NN` = the read-only reference clone. Device lines are quoted verbatim from
`build/pass27-run.log`. No credential, token, account identifier or device identifier is here.

---

## 0. What was run, and on what

| | |
|---|---|
| Device | Apple TV 4K (3rd generation), `AppleTV14,1`, **tvOS 26.6**, named Home Theater |
| Mac | macOS 26.6.2 (25G83), Xcode 26.6 (17F113), SDK `AppleTVOS26.5` |
| Harness | `Marlin DVR TVUITests/FrameStepReconUITests.swift` — **temporary, disclosed, deleted before the commit** (§7) |
| App source | **not changed** — proved by the app dylib's SHA-256 before, with, and after the harness (§7) |
| Recordings measured | **copy mode** — "The Mega-Brands That Built America", 2696.694 s; **transcode mode** — "Earth Odyssey With Dylan Dreyer", 191.417 s |

The harness never drives the app. It builds its **own** `AVPlayer` inside the test runner on the
device, on a real recording's HLS playlist from the real server — same media, same AVFoundation,
same hardware. It made no server write: `GET /api/library`, `GET /api/library/shows/{id}`,
`POST /api/play/sessions` (the same call the app's own Player makes) and `DELETE` of every session
it opened, including the ones it did not use.

---

## 1. What the Player is, and where pause is handled

**A mix, weighted heavily to Apple.** `AVPlayerViewController` is hosted as a child of a plain
container controller, with its own transport bar left switched on — a standing call:

```
PlayerHost.swift:22-38    struct PlayerHost: UIViewControllerRepresentable
PlayerHost.swift:49       private let playerController = AVPlayerViewController()
PlayerHost.swift:53-59    playerController.showsPlaybackControls = true
                          playerController.requiresLinearPlayback = linearOnly      // cameras
PlayerHost.swift:61-69    added as a child view controller, filling the container
```

On top of it SwiftUI draws **passive** overlays (`PlayerScreen.swift:32-46`): `StartingOverlay`,
then `LiveHUD` or `RecordingHUD`, plus `PausedLiveOverlay` for live only
(`PlayerScreen.swift:72-73`). While playing or paused on a recording the overlay is
`RecordingHUD` — **text only, nothing focusable** (`PlayerScreen.swift:224+`). Only the terminal
states (`ended`, `failed`, `expired`) put buttons on screen (`PlayerScreen.swift:42-44`).

**The app never pauses a recording itself.** It observes the pause and reacts to it:

```
PlayerModel.swift:165-167  observations.append(player.observe(\.timeControlStatus, …))
PlayerModel.swift:211-235  timeControlChanged() → isPaused = true, pausedAt = Date(),
                           showHUD(for: nil), and for a recording saveResume()
```

Its only `player.pause()` is in teardown (`PlayerModel.swift:501`). So on a recording, pause is
Apple's, start to finish; the app just hears about it.

**The existing sub-60-second live Select handling** — the one place the app takes a press away from
Apple — is `PlayerContainerController.handleShortWindowSelect()` (`PlayerHost.swift:109-135`):

- armed only by `shortWindowSelect`, which is `model.isLive` (`PlayerScreen.swift:36`);
- it fires only while the item's seekable window is under `appleHandlesFromWindow = 60` s
  (`PlayerHost.swift:43`), otherwise it logs and defers (`:112-115`);
- it lets Apple's handler go first and, after `appleGrace = 0.35` s (`:46`), pauses or resumes
  **only if `timeControlStatus` is unchanged** (`:118-132`).

Why it exists: Pass 7B measured AVPlayerViewController refusing to pause a live item at a 30 s and
36 s window and accepting at 60 s, and a live channel's window starts at zero (`PlayerHost.swift:9-15`).
**On a recording this whole path is inert** — `shortWindowSelect` is false, so Select is Apple's alone.

---

## 2. Paused on a recording: what the item says it can do — measured

Copy mode, after 6.315 s of real playback at rate 1 with a player layer attached
(`presentationSize=(1920.0, 1080.0)`, `seekable=["0.000…2696.694"]`, `timeControl=2` = playing),
then paused:

```
FRAMESTEP tracks=3 currentVideoFrameRate while playing = 30.59111
FRAMESTEP ==== PAUSED ON A RECORDING (copy mode) ====
FRAMESTEP canStepForward=false  canStepBackward=false
FRAMESTEP canPlayFastForward=false canPlayFastReverse=false canPlayReverse=false canPlaySlowForward=true canPlaySlowReverse=false
FRAMESTEP rate=0.0 timeControlStatus=0 (0=paused)
FRAMESTEP frame rate 30.59111 fps → one frame = 0.032689235287574586 s
```

They do not settle late. Re-read once a second for five seconds:

```
FRAMESTEP  flags at +2 s paused: canStepForward=false canStepBackward=false timeControl=0
FRAMESTEP  flags at +3 s paused: canStepForward=false canStepBackward=false timeControl=0
FRAMESTEP  flags at +4 s paused: canStepForward=false canStepBackward=false timeControl=0
FRAMESTEP  flags at +5 s paused: canStepForward=false canStepBackward=false timeControl=0
FRAMESTEP  flags at +6 s paused: canStepForward=false canStepBackward=false timeControl=0
```

Transcode mode, same run, second recording (`seekable=["0.000…84.029"]`, 30.49585 fps):

```
FRAMESTEP ==== PAUSED ON A RECORDING (transcode mode) ====
FRAMESTEP canStepForward=false  canStepBackward=false
FRAMESTEP canPlayFastForward=false canPlayFastReverse=false canPlayReverse=false canPlaySlowForward=true canPlaySlowReverse=false
```

**Identical.** The only capability of the family that is true, in both modes, is
**`canPlaySlowForward`**.

---

## 3. What a step actually moves — measured

Apple documents `step(byCount:)` as doing nothing when the flag is false, so the harness called it
anyway: that turns *"the item says no"* into *"the item says no **and** nothing moves"*, which is
the stronger statement.

**How the distance was measured.** `item.currentTime()` is read immediately **before** the
`step(byCount:)` call and again once the value has **stopped changing** — polled every 40 ms and
taken as settled after three identical reads, with a 2 s ceiling. Both readings are logged as
seconds to six decimal places **and** as the raw `CMTime` rational (`value/timescale`), so a
sub-frame move could not be rounded away. The timescale AVFoundation used is nanoseconds
(1 000 000 000), i.e. a resolution about 30 million times finer than the 0.0327 s frame.

Ten steps each way, both modes — forty step calls in total:

| Recording | Mode | Direction | n | Before → after | Δ | Spread |
|---|---|---|---|---|---|---|
| The Mega-Brands That Built America | copy | `step(byCount: 1)` | 10 | `6319301495/1000000000` → same | **+0.000000 s** | 0.000000 |
| The Mega-Brands That Built America | copy | `step(byCount: -1)` | 10 | `6319301495/1000000000` → same | **+0.000000 s** | 0.000000 |
| Earth Odyssey With Dylan Dreyer | transcode | `step(byCount: 1)` | 10 | `18079122617/1000000000` → same | **+0.000000 s** | 0.000000 |
| Earth Odyssey With Dylan Dreyer | transcode | `step(byCount: -1)` | 10 | `18079122617/1000000000` → same | **+0.000000 s** | 0.000000 |

```
FRAMESTEP FORWARD  step(byCount: 1)  SUMMARY n=10 moved=0 min=+0.000000 max=+0.000000 spread=0.000000 mean=+0.000000
FRAMESTEP BACKWARD step(byCount: -1) SUMMARY n=10 moved=0 min=+0.000000 max=+0.000000 spread=0.000000 mean=+0.000000
FRAMESTEP after stepping: canStepForward=false canStepBackward=false rate=0.0
```

The current time was **bit-identical** across all twenty calls in each recording — not one frame,
not a keyframe jump, not a sub-frame nudge. The owner's discriminator ("keyframe landing looks
like an inconsistent or ~3–4 s delta; a true frame step does not") does not even come into play:
there is no delta to characterise.

---

## 4. Every remote input while paused on a recording

**The app binds exactly one press in the Player: Menu.** Everything else is Apple's.

| Input | What the app does with it | Evidence |
|---|---|---|
| **Menu** | claimed by the container → `onMenu` → `dismiss()`: stops the session and closes the Player | `PlayerHost.swift:91-95, :102-105`; `PlayerScreen.swift:36, :83-88`; also `PlayerScreen.swift:64` `.onExitCommand` |
| **Select** | **nothing** — falls through to `super.pressesBegan` → AVPlayerViewController, because `shortWindowSelect` is false for a recording | `PlayerHost.swift:96-99`, `PlayerScreen.swift:36` |
| **Left / Right arrow** | nothing | never referenced; `PlayerHost.swift:15` "Edge clicks and swipes are never touched" |
| **Swipe left / right** | nothing | same |
| **Up / Down** | nothing | same |
| **Play/Pause** | nothing | same |
| **Click-and-hold** | explicitly disabled while the Player is up | `ContentView.swift:46` `hold.suspended = id != nil`; `RemoteHold.swift:54` `guard !suspended` |

So **every input except Menu is free of app bindings** — but not free of *Apple's*, since
AVPlayerViewController owns the transport bar. **What Apple's own transport does with each of
those while paused was not driven with the remote this pass**; the harness measured the player
item, not the UI. That does not affect the verdict: no button can reach a step that the item
refuses to perform.

---

## 5. VOD or live-style, and does it affect stepping?

**Neither, strictly: recordings are an HLS *EVENT* playlist.** The app always asks for HLS
(`PlaybackSession.swift:51` — `format: "hls"`), and the server writes:

```
hls.go:75-78   -f hls -hls_segment_type fmp4 -hls_fmp4_init_filename init.mp4
               -hls_segment_filename seg%05d.m4s
               -hls_time 4 -hls_playlist_type event -hls_flags temp_file+independent_segments
hls.go:36-38   "Recordings: an EVENT playlist, every segment kept for the life of the
                session …, #EXT-X-ENDLIST when ffmpeg finishes."
```

So it starts short, grows as ffmpeg works, keeps every segment, and gains `#EXT-X-ENDLIST` at the
end — VOD-like in that nothing is deleted and the whole thing stays seekable, live-like in that it
grows while you watch. The device confirms the seekable range is the **whole recording**
(`seekable=["0.000…2696.694"]` against `duration=2696.694`).

**Keyframes**, which is what would matter if stepping worked at all: in **transcode** mode the
server forces one every 4 s (`hls.go:70-73`, `-force_key_frames expr:gte(t,n_forced*4)`); in
**copy** mode — what an h264 + aac recording gets (`stream.go:246-249`) — there is no forcing and
the GOP is the broadcaster's own.

**Does it affect stepping? Not in the way one would expect — it is upstream of that.** Both modes
were measured and both refuse identically, so the answer is not about GOP length. The relevant
fact is the delivery format itself: this is a **streamed HLS asset**, and on this device
AVFoundation reports no step capability for one, whatever its keyframe spacing. One thing follows
from that and is worth recording: the server's session route also accepts `format: "mp4"` and in
fact defaults to it (`stream.go:185` — `Format string // "" | mp4 | hls`, and the session is
created with `Format: "mp4"`). A progressive MP4 asset is the classic case where AVFoundation
*does* step. **That was not measured** — this pass was scoped to recordings as the app plays them
today, over HLS — and it is Open Question 1.

---

## 6. Verdict

**Frame-by-frame stepping is not achievable on a paused recording as this app plays them today —
in either direction.** It is not a matter of wiring a button to it: there is nothing to wire.
Paused on a real recording on the Apple TV, after six seconds of genuine playback with video
presenting at 1920×1080 and the whole 45-minute recording seekable, `AVPlayerItem` reports
`canStepForward = false` and `canStepBackward = false`, and holds those values for at least six
seconds of paused settling. Calling `step(byCount: 1)` and `step(byCount: -1)` anyway — ten of
each, on a copy-mode recording and again on a transcode-mode one — moved the playhead **not one
nanosecond**: the `CMTime` was bit-identical before and after all forty calls, at nanosecond
resolution. So there is no forward-only consolation prize and no "it lands on a keyframe instead"
behaviour to live with; the call is simply inert. Because copy mode (the broadcaster's own GOP)
and transcode mode (the server's forced 4-second keyframes) behave identically, the cause is not
keyframe spacing — it is that these are streamed HLS assets, and this device's AVFoundation offers
no step capability for one. The only neighbouring capability that *is* available, in both modes,
is `canPlaySlowForward = true`, which means slow-motion forward is possible where stepping is not;
nothing was built or designed for that here, and what to do with it is the owner's call. The one
avenue that could change the answer is untested and named as Open Question 1: the server can serve
a recording as a progressive **MP4** instead of HLS — it is the route's default — and a progressive
asset is the classic case where AVFoundation does step. That would be a different pass, and it
would trade away the seek-by-new-session behaviour the HLS path is built on.

---

## 7. The harness: disclosed, and reverted

`Marlin DVR TVUITests/FrameStepReconUITests.swift` was written for this pass, lived only in the
**UI-test target**, and was **deleted before the commit**. It is not in this commit and not in the
repository. Its SHA-256 as run was
`f53369206f6f93d74870d283509052b515117d10fde91bbd93e9c663ba2d633a`.

**The app binary is the proof that nothing in the app changed.** All of the app's Swift lives in
`Marlin DVR TV.debug.dylib`; the `Marlin DVR TV` executable beside it is the launcher stub, re-signed
on every build.

| | SHA-256 of `Marlin DVR TV.debug.dylib` | Mach-O UUID of `Marlin DVR TV` |
|---|---|---|
| **before** the harness existed (device build at `d401aab`) | `75be3b2b76b53d1e8decba00d7ed1da638d7552dc207ff94d2440f337343dd59` | `3597FB26-E343-35F3-B060-4EC149A95D64` |
| **with** the harness in the tree (the build that produced every result above) | `75be3b2b76b53d1e8decba00d7ed1da638d7552dc207ff94d2440f337343dd59` | `3597FB26-E343-35F3-B060-4EC149A95D64` |
| **after** the harness was deleted (this build) | `75be3b2b76b53d1e8decba00d7ed1da638d7552dc207ff94d2440f337343dd59` | `3597FB26-E343-35F3-B060-4EC149A95D64` |

Identical throughout: the harness changed the test bundle and **not one byte of the app**.

### 7a. Three things the harness had to get right, recorded so the next one does not lose a run to them

None of these are app defects; all three are properties of measuring AVFoundation from a test
process, and each one silently produced a *wrong* answer before it was fixed.

1. **The test body runs on the main thread** (`Thread.isMainThread` = `true`, logged). `Thread.sleep`
   there blocks the main run loop, so AVPlayer's state machine never runs: the item sat at status
   `.unknown` with nothing fetched, for 60 s. Spinning the run loop instead
   (`RunLoop.current.run(until:)`) fixed it.
2. **The XCTest runner starts backgrounded** — `activationState=2` — and tvOS will not start video
   in a backgrounded process, nor activate an audio session for one ("Session activation failed").
   `play()` returned to rate 0 instantly with no `reasonForWaitingToPlay`.
   `XCUIApplication(bundleIdentifier: <runner>).activate()` brought it to `activationState=0`,
   after which the audio session activated and playback ran.
3. **The first playlist must be fetched before AVPlayer sees the URL.** The server blocks up to 20 s
   waiting for ffmpeg's first segment (contract §7), which AVPlayer does not wait out on its own.
   The app already does exactly this (`PlaybackSession.swift:65-77`, "GET the playlist once, in
   full, before AVPlayer sees it"); the harness had to mirror it.

**Had any of the three been left unfixed, the flags would still have read `false`** — and the
answer would have looked the same while meaning nothing. They are fixed, playback genuinely ran
(`timeControl=2`, `+6.315 s` and `+6.064 s` of advance, `presentationSize=(1920.0, 1080.0)`), and
only then were the flags read.

---

## 8. Open Questions

1. **Would a progressive MP4 session step?** The server's session route defaults to
   `format: "mp4"` and the app opts into `"hls"` (`stream.go:185`, `PlaybackSession.swift:51`).
   A progressive asset is where AVFoundation normally supports stepping. Untested — out of this
   pass's scope. It would cost one device run on the existing pattern, and it is the only thing
   that could turn this verdict around. It would also mean giving up the HLS path's
   seek-by-new-session behaviour (contract §3), so it is a real trade, not a free win.
2. **`canPlaySlowForward = true`** in both modes. Slow-motion forward is available where stepping
   is not. Nothing was designed or built for it here.
3. **What Apple's transport bar does with each remote input while paused on a recording** was not
   driven with the remote this pass (§4). It does not affect the verdict, but it is the one part of
   question 4 that is answered from source rather than from the device.
4. **Live TV was excluded by the owner** and nothing about it was measured or changed.

---

## 9. SCOPE CHECK — every file touched

| File | What happened to it |
|---|---|
| `Marlin DVR TVUITests/FrameStepReconUITests.swift` | **created, run on the device, deleted before committing** (§7) |
| `reports/2026-09-07-pass27-framestep-recon.md` | **new** — this report |
| `Marlin DVR TV/**` (`PlayerHost`, `PlayerScreen`, `PlayerModel`, `PlaybackSession`, `RemoteHold`, `ContentView`, `Models`) | **read only** |
| `~/Xcode/marlin-dvr-reference` (`hls.go`, `stream.go`, `HLS-CLIENT-API.md`) | **read only** — never edited, never pushed, never run |
| `build/**` | build output and logs; git-ignored, never committed |

**No app source was changed** (proved in §7), **no frame-step implementation was written — not a
stub, not a disabled path**, live playback was not touched, and nothing in `design/` was read or
written. The only server traffic was the library reads and the play sessions the harness opened
and then DELETEd; no write route was called.

---

# ADDENDUM — 2026-09-07, added by Pass 28

**The measurement above stands. The verdict does not.**

Everything this report says about `step(byCount:)` is correct and was correctly measured:
`canStepForward` and `canStepBackward` are both false on these HLS items, and forty step calls
moved the playhead zero nanoseconds. None of that has changed.

But §6's conclusion — "frame-by-frame stepping is not achievable on a paused recording" — was
wrong, because `step(byCount:)` was the wrong mechanism. **Frame stepping is achievable, and it is
now built and measured on the device.** An *exact seek* does it: `currentTime() ± 1/fps` with
`toleranceBefore` and `toleranceAfter` both `.zero`. The zero tolerance is what makes AVFoundation
land on the adjacent frame instead of the nearest keyframe.

Measured on Home Theater in Pass 28, on the same class of HLS recording this report tested:
**+0.033367 s per click on 29.97 fps material** and **0.016667 s on 59.94 fps material**, forward
and backward, in copy mode and in transcode mode alike.

The lesson worth keeping: this report established that *one API* is inert and then generalised
from it to the capability. The flags were telling the truth about `step(byCount:)` and nothing
more.

See `reports/2026-09-07-pass28-framestep.md`.
