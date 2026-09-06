# Pass 7 — Sweep 3: the Player (code; separate push gate) — 2026-09-06

The Player of frames 6a–6h on top of the Pass 5 foundation and the Pass 6 screens: HLS sessions per the contract, AVPlayerViewController with the app's overlays, recordings with seek-by-new-session, the per-Apple-TV resume store and watched-on-end, live channels on the server's time-shift buffer, cameras, and the entry points. Tested hands-on on the tvOS simulator against the live server (fifteen sessions) and installed and launched on Home Theater. **Committed locally only; nothing was pushed** — the owner tests on Home Theater first.

**Contract check (READ FIRST).** Reference clone HEAD `9325d94439ef4c9db637c5014ff79f41d1f63956` ("Pass 26 report: pushed SHA"); `git merge-base --is-ancestor 3613b0a HEAD` → yes (3613b0a "Pass 26: 1.2.1 deployed" is one commit behind HEAD). `HLS-CLIENT-API.md` at HEAD is 275 lines; §4 "Live channels and cameras over HLS" carries the time-shift buffer (Pass 21: `hlsLiveSeg` 2 s, `liveWindowEntries`, the "Live TV Buffer" table, "the whole advertised window is seekable", "a pause longer than the buffer loses the pause point", "the tuner is held for the whole session"); §6 the idle watchdog (15 s, every fetch stamps the session). The server answered `GET /api/status` with version **1.2.1** and `GET /api/settings` reports `liveBuffer: "1 hour"`. The gate passed. The contract's header still says 1.1.0 / `ed49d64`; the server source at HEAD differs from Pass 3's `eef49e8` only in `guide.go`, `hls.go`, `main.go`, `settings.go`, `sources.go`, with no JSON-tag change (`git diff … | grep json:` empty), so the sweep 2 models still hold.

Network use, all against `http://192.168.1.250:8090`: GETs; the app's `POST /api/clients/{id}/ping`; `POST /api/play/sessions` (15); `GET /api/play/hls/…` (playlists, init and segments, and the keep-alive `Range: bytes=0-0` playlist fetches); `DELETE /api/play/sessions/{id}` (14 by the app, §6d); `GET /api/play/sessions` and `/{id}/log`; and **one** `PUT /api/library/recordings/4b4a3f0f8fc8` `{watched: true}` when that recording played to its end. No `/api/record`, no passes, no trash, no settings. Nothing installed; no packages; no Info.plist or build-setting change.

Citation keys: `contract §n` = `HLS-CLIENT-API.md` at `9325d94`; `dc:NNN` = `design/Marlin DVR TV.dc.html`; `Pass n §m` = this repo's reports; `file:line` = `cmd/marlin-dvr/` at `9325d94`.

## What was built, per step, file by file

All new files in `Marlin DVR TV/` (synchronized group). Line counts by `wc -l`.

| File | Step | What it is |
|---|---|---|
| `PlayRequest.swift` (104, new) | 5 | `PlayRequest`: `.live(channel, program)`, `.recording(episode, show, start)`, `.camera(camera)`; the `kind`, `id` and `start` for `POST /api/play/sessions` (contract §2); the overlay title/subtitle ("ch2.1 WMAR-HD", "The Key of David · until 11:00 AM"; "S6 E23 · On the Hunt · 11.1 WBAL-DT"); the next-newer episode of the show (the list is newest first, library.go:586-640); `withStart` / `replacing(episode:)`. |
| `PlaybackSession.swift` (145, new) | 1 | `PlaybackSessionClient`: `create` (`{kind, id, format: "hls", client: <the persisted id>, start}`, the 200 means ffmpeg and the tuner are held, contract §2.2); `firstPlaylist` (one full GET with a 25-second timeout — the server blocks up to 20 s, contract §7 — returning the status and the plain-text body); `keepAlive` (`Range: bytes=0-0`, returns the status; every fetch stamps the session, §6); `stop` (DELETE, never throws, §5); `log` (`/api/play/sessions/{id}/log`, §7); `markWatched` (PUT `{watched: true}`, library.go:643-666). Own `URLSession`, cache disabled, no retries. |
| `ResumeStore.swift` (54, new) | 3 | UserDefaults entries `marlinResume.<recording id>` = `{position, duration, savedAt}`; `latest(among:)` picks the most recently saved episode of a show for the 5d "Resume S6 E23 · 35 s in" line; `label`. |
| `PlayerModel.swift` (484, new) | 2–4 | `@Observable PlayerModel`: phases `starting / playing / ended / expired / failed`; `start()` = create → first playlist (non-200 → failure with the server's text; 502 also fetches the session log's last six lines and, for live, names the recordings with `status == "Recording"` on the channel's source from `/api/schedule` as the likely tuner holders, frame 6g) → `AVPlayerItem` with the resolved playlist URL and title/subtitle metadata → play → keep-alive loop every 10 s (410 → `expired`, frame 6h). Recording: `position = start + currentTime`, `preparedTo = start + seekableTimeRanges.end` (AVFoundation's reading of the playlist's last segment, the "Prepared to" line), resume saved every 10 s while playing, on pause and on stop; a user seek (`AVPlayerItem.timeJumped`) to within 1.5 s of the prepared end while the recording is not fully segmented → DELETE, new session with `start` = that position, player at 0 (contract §3); `didPlayToEndTime` → detach, DELETE, PUT watched, clear the resume, `ended` with a 10-second countdown when a next episode exists. Live: `behindLive = seekableEnd − currentTime`, `bufferSeconds = seekable window`; pause/resume/rewind are AVPlayer's; on resume, or on a 404 in the item's error log, a position before the window's start is re-seeked to its start + 2 s with a one-line notice (contract §4; never to the live edge). `restart(at:)` for 6h and seek-beyond; `stop()` (resume save, detach, cancel loops, DELETE) for dismissal, background and switching. HUD visibility: 6 s after start, while paused, 6 s after a seek or a notice. Console lines `[player] …` / `[session] …` for the evidence. |
| `PlayerHost.swift` (78, new) | 2 | `PlayerContainerController` hosting `AVPlayerViewController` as a child (Apple's transport UI as-is; `requiresLinearPlayback` for cameras; PiP off); requests focus for the player on appear; catches the Menu press that AVPlayerViewController leaves unconsumed and hands it to SwiftUI as `onMenu`. |
| `PlayerScreen.swift` (502, new) | 2 | `PlayerScreen`: the host underneath, the overlays on top; Menu → stop then dismiss; background (`scenePhase`) → the same; `onDisappear` → stop, so no path leaves a session running; `playNext` for 6e. Overlays in the Pass 5 theme: `StartingOverlay` (6a: initials tile / poster, title, subtitle, the pulsing bar, "Tuning the antenna and starting the encoder", "Live channels usually take 2–6 seconds. Press Menu to cancel.", dc:865-878); `LiveHUD` (6b: "LIVE" pill at the edge or "LIVE · −2 min 8 s", the lag and buffer line, the notice); `RecordingHUD` (6c: title, "0:39 of 3:11", "Prepared to 0:36. Jumping past that point restarts playback there…", "Resume kept by <client name>", dc:927-950); `PausedLiveOverlay` (6d: "Paused", "Paused at 10:51 AM · now 5 s behind live", "Held for 0:05 · the buffer holds 1 min 8 s · the tuner stays in use while paused", "Press play to continue from here…", the "LIVE · HELD" pill — the design's "no buffer" copy is gone); `EndedState` (6e: "Marked watched on the server", "Next episode starts in N seconds." / "That was the newest episode of this show.", Play SxEy / Back to the show / Delete this recording (inert)); `FailureState` (6f/6g and 404/other: the status code, the server's text, the likely tuner holders, "Stop the recording and watch" (inert) / "Back to the guide" / "Hide this channel" (inert) / "Pick another channel" / "Try again" / "Show the server log"); `ExpiredState` (6h: "410 · session ended", Restart / Back). Overlays sit at the top so Apple's transport bar keeps the bottom. |
| `ContentView.swift` (Pass 5 file) | 5 | `.fullScreenCover(item:)` presents the Player over everything; `interactiveDismissDisabled` so Menu is the Player's, not the system's; `onPlay` handed to the shell. |
| `ScreenShell.swift` (Pass 6 file) | 5 | `onPlay` passed to On Now, the Guide, Recordings and Cameras. |
| `OnNowScreen.swift` (Pass 6 file) | 5 | Card click → `.live(channel, program)`. |
| `GuideScreen.swift` (Pass 6 file) | 5 | DECISIONS.md 2026-09-06: click on an airing on now → live; click on a future airing → the sheet; press-and-hold on a cell → the sheet; "Watch live" on the sheet → live. |
| `AiringSheet.swift` (Pass 6 file) | 5 | "Watch live" wired (`onWatchLive`); Record / Series pass stay inert. |
| `RecordingsScreen.swift`, `ShowDetailScreen.swift` (Pass 6 files) | 3, 5 | Show detail: the "Resume S6 E23 · 35 s in" line (frame 5d) when a position exists, Play newest and the episode click from the stored position, the resume bar on the thumb when position and duration are known; the long-press footer stays inert. |
| `CamerasScreen.swift` (Pass 6 file) | 5 | Card click → `.camera`. |

## 6. Test evidence

Simulator: Apple TV 4K (3rd generation), tvOS 26.5; key presses through `osascript` after checking the Simulator is frontmost; console through `simctl launch --console-pty`; server evidence through `GET /api/logs`, `GET /api/play/sessions` and `GET /api/library/shows/{id}`. Screenshots under `reports/assets/pass7/` (3840×2160 → 1920 wide, JPEG). Builds, final code:

```
$ xcodebuild … -scheme "Marlin DVR TV" -destination 'generic/platform=tvOS Simulator' build → ** BUILD SUCCEEDED ** (exit 0)
$ xcodebuild … -scheme "Marlin DVR TV" -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates build → ** BUILD SUCCEEDED ** (exit 0)
```

### 6(a) The recording — Earth Odyssey With Dylan Dreyer S6 E23 "On the Hunt" (id `4b4a3f0f8fc8`, 3 min 11 s, MPEG-2 → transcode)

The only recording on the server today (`GET /api/library`: 1 show, 1 recording). **This is the recording that was marked watched.**

Play, seek past the prepared range (three skip-forward presses landed at the end of the seekable range), dismiss, reopen:

```
[player] session smtpvot6359214f recording mode=transcode start=0.0 duration=191.416733
[player] first playlist → 200                       (POST 09:59:37.900 → first index.m3u8 200 at 09:59:38.505)
[player] seek past the prepared range: 35.886s of 191.416733s
[session] DELETE smtpvot6359214f → 200 {"ok":true,"wasRunning":true}
[player] session smtpvozdff24e8f restarted start=35.886
```

Server log: `seq=206 09:59:45.927 [TRS] session smtpvot6359214f stop requested`, `seq=207 DELETE … 200`, `seq=209 session smtpvozdff24e8f created … for Apple TV 4K (3rd generation)`, `seq=210 POST /api/play/sessions 200`. Screens: `50-recording-starting-6a.jpg` (poster, title, "S6 E23 · On the Hunt · 11.1 WBAL-DT", the bar, "Preparing the recording"), `51-recording-playing-hud-6c.jpg` ("0:02 of 3:11 · Resume kept by Apple TV 4K (3rd generation)"), `52-recording-after-seek-beyond-6c.jpg` ("0:39 of 3:11 · Prepared to 0:36. Jumping past that point restarts playback there…"). After dismissal, show detail reads **"Resume S6 E23 · 35 s in"** with the resume bar on the thumb (`53-show-detail-resume-line.jpg`).

Reopen from Resume (a rebuilt app, see "Found and fixed"): `[player] session smtpvt5cnb38849 recording … start=35.886`; keep-alives `#1 → 206`, `#2 → 206`, `#3 → 206` (server `seq=312 10:03:11.295 GET …/index.m3u8 206`, `seq=316 10:03:21.304 … 206`, `seq=317 10:03:31.316 … 206`); Menu → `[player] stop` → `DELETE smtpvt5cnb38849 → 200` (server `seq=327 10:03:36.724 DELETE … 200`, `seq=328 … ended after 1m: stop requested by Apple TV 4K (3rd generation)`).

Play to the end from the saved position: `[player] session smtpvxnie88a5ec recording … start=70.886…`; keep-alives #1–#11 (server 206 lines 10:06:41 → 10:08:21, one every 10 s; `seq=374 10:06:40.663 ffmpeg finished — … fully segmented; folder stays until the viewer stops`); then

```
[player] played to end
[session] DELETE smtpvxnie88a5ec → 200 {"ok":true,"wasRunning":true}
[session] watched:true → 4b4a3f0f8fc8
```

```
seq=396 10:08:30.812 [TRS]  session smtpvxnie88a5ec stop requested (running=true)
seq=397 10:08:30.813 [HTTP] DELETE /api/play/sessions/smtpvxnie88a5ec 200
seq=399 10:08:30.822 [DVR]  recording 4b4a3f0f8fc8 (…S06E23 On the Hunt 2026-09-05-0930.mpg): watched=true favorite=false keep=false trash=false (flags only …)
seq=400 10:08:30.824 [HTTP] PUT /api/library/recordings/4b4a3f0f8fc8 200
```

`GET /api/library/shows/earth-odyssey-with-dylan-dreyer` afterwards: `4b4a3f0f8fc8 watched: True watchedAt: 2026-09-06T10:08:30.82167455-04:00` (before the test: `watched: False`). The 6e state showed "MARKED WATCHED ON THE SERVER", the title, "That was the newest episode of this show.", "Back to the show" focused and "Delete this recording" (`57-recording-ended-6e.jpg`); "Back to the show" returned to show detail (`59-show-detail-after-end.jpg`). No next episode exists, so the countdown and "Play S6 E24" could not be exercised.

### 6(b) Live — an antenna channel and a Philo channel

Antenna, ch2.1 WMAR-HD, session `smtpxh8js63bc64` (`60-on-now-antenna-first-card.jpg` shows the card):

```
seq=3003 10:49:43.817 [TRS] session smtpxh8js63bc64: live time-shift buffer 1h 0m — playlist window 1800 × 2 s
seq=3005 10:49:43.821 [TRS] session smtpxh8js63bc64 created: ch2.1 WMAR-HD (live, transcode) for Apple TV 4K (3rd generation)
seq=3006 10:49:43.821 [HTTP] POST /api/play/sessions 200
seq=3007 10:49:49.848 [HTTP] GET /api/play/hls/smtpxh8js63bc64/index.m3u8 200   ← first playlist, 6.0 s after the POST
[player] paused (0 s behind live)      10:51:03
[player] playing (0 s behind live)     10:53:15   ← 2 min 12 s later
seq=3333 10:53:35.884 [HTTP] DELETE /api/play/sessions/smtpxh8js63bc64 200
seq=3334 10:53:35.934 [TRS] session smtpxh8js63bc64 ended after 4m: stop requested by Apple TV 4K (3rd generation); 161.51 MB served
keep-alive 206 fetches in the session: 22
```

Screens: `61-live-antenna-starting-6a.jpg` (the WM tile, "ch2.1 WMAR-HD", "The Key of David · until 11:00 AM", "Tuning the antenna and starting the encoder", "Live channels usually take 2–6 seconds. Press Menu to cancel."); `62-live-antenna-hud-live-edge-6b.jpg` (the "LIVE" pill at the edge with Apple's transport bar below); `63-live-antenna-paused-6d.jpg` ("Paused at 10:51 AM · now 5 s behind live · Held for 0:05 · the buffer holds 1 min 8 s · the tuner stays in use while paused"); `64-live-antenna-paused-2min-6d.jpg` (the same after two minutes); `65-live-antenna-resumed-lag-6b.jpg` after play: **"LIVE · −2 min 8 s · 2 min 8 s behind live · buffer 3 min 22 s"** — playback continued from the pause point; `66-live-antenna-after-rewind-6b.jpg` after six skip-back presses: "−3 min 17 s".

Philo, ch9002 FYI, session `smtpxaajfecd9d9`: POST 10:44:19.807 → first playlist 200 at 10:44:22.021 (2.2 s); `[player] paused (6 s behind live)` 10:45:37, `[player] playing (5 s behind live)` 10:47:49 (2 min 12 s); 22 keep-alives; `DELETE … 200` 10:48:09.538, "ended after 4m: stop requested … 152.55 MB served". Screens `70-live-philo-starting-6a.jpg`, `71-live-philo-paused-6d.jpg` ("now 12 s behind live · the buffer holds 1 min 10 s"), `72-live-philo-paused-2min-6d.jpg` ("now 2 min 17 s behind live · Held for 2:10"), `73-live-philo-resumed-lag-6b.jpg` ("−2 min 15 s · buffer 3 min 22 s"), `74-live-philo-after-rewind-6b.jpg` ("−3 min 17 s"). Two earlier FYI sessions (`smtpwxq92d2963f`, `smtpx2ss698a427`) ran the same sequence with 21 keep-alives each; four earlier antenna/HISTORY sessions (`smtpw4d93b293e7`, `smtpw8i0n68c6b6`, `smtpwevd0a1c007`, `smtpwj84nbed25a`, `smtpwovped0c37d`, `smtpwt2p014d086`) were the scripting attempts before the pause landed (see "Found and fixed"); every one ended with its DELETE.

The antenna first playlist measured 5.8 s (`smtpwevd0a1c007`: 10:19:53.799 → 10:19:59.641) and 6.0 s; HISTORY 0.4 s; FYI 1.8–2.2 s; the camera 5.6 s; the recording 0.6 s — all inside the 25-second timeout of the first fetch.

### 6(c) The camera — Cow Cam, session `smtpw2l6k504328`

```
seq=414 10:10:20.736 [TRS] session smtpw2l6k504328 created: Cow Cam (camera, transcode) …
seq=416 10:10:26.371 [HTTP] GET /api/play/hls/smtpw2l6k504328/index.m3u8 200     ← 5.6 s
seq=425 10:10:36.577 [HTTP] GET …/index.m3u8 206                                  ← keep-alive
[player] stop: phase=playing session=smtpw2l6k504328
seq=435 10:10:46.406 [HTTP] DELETE /api/play/sessions/smtpw2l6k504328 200
```

Screens `80-camera-starting-6a.jpg` ("Connecting to the camera"), `81-camera-playing.jpg`, `82-cameras-after-menu.jpg`. One Menu press stopped and dismissed.

### 6(d) Every session inactive; one DELETE per session

`GET /api/play/sessions` at the end: `active: 0`. Fifteen sessions were started in this pass. Fourteen ended with the app's DELETE (each listed above or in the log window: DELETE lines at 09:59:45, 10:03:36, 10:08:30, 10:10:46, 10:14:31, 10:17:43, 10:22:51, 10:26:14, 10:30:31, 10:33:46, 10:38:14, 10:42:10, 10:48:09, 10:53:35). **One did not:** `smtpvozdff24e8f` (the first seek-beyond session, 09:59) was ended by the server's watchdog at 10:00:31 ("nothing fetched for 15s") because the keep-alive loop of that first build never fetched and the system's cover dismissal skipped the model's stop — both found here and fixed before every later session. Stated plainly as the one exception.

### 6(e) The first-playlist wait and the keep-alives in the server log

The first `GET …/index.m3u8 200` follows each POST by 0.4–6.0 s (above). The keep-alives are the `index.m3u8 206` lines every 10 s for the life of every session — 22 in the four-minute antenna session, 11 in the two-minute recording — and, once ffmpeg finished a recording and AVPlayer stopped polling the EVENT playlist, they were the only fetches (`seq=377 … seq=395`, 10:06:51 → 10:08:21), which is the Pass 3 item-4 case the standing call was written for.

### 6(f) Overlay states reached

6a (recording, live, camera), 6b (live edge; behind live after resume and after rewind), 6c (playing; after seek-beyond with "Prepared to"), 6d (paused live, at 5 s and after 2 min), 6e (ended, marked watched). Not reachable in this test: 6f (no DRM channel is listed), 6g (no second tuner user; no 502 occurred), 6h (no session expired under the final code), the "pause point left the buffer" notice (needs a pause longer than the 1-hour buffer), the next-episode countdown (one recording).

### Home Theater

The final build was installed and launched at 10:42 (`devicectl … install app` → "App installed", `process launch` → "Launched application"); the server logged its ping and five GETs from 192.168.1.30 and nothing else. The device UI cannot be driven from the Mac; the playback checks above are the simulator's, and the closing summary tells the owner what to try on the Apple TV. The app is left installed and running there.

### Found and fixed during the test (all in this commit)

1. **Keep-alive never fetched** in the first build: the loop's cancellation check inside the `Task` closure returned before the fetch. Rewritten with a plain sleep-then-fetch loop and a console line per fetch; every later session shows the 206s.
2. **System dismissal skipped stop:** the fullScreenCover's own Menu handling dismissed the Player before the model ran `stop()`, and the press also reached the screen underneath. `interactiveDismissDisabled` on the cover, `onDisappear → stop`, and the host controller's Menu catch; from then on one Menu press stops (DELETE in the log) and dismisses, and show detail stays where it was.
3. **Select presses lost at first:** the player did not receive focus on appearance; an explicit focus update was added. On the simulator, Select still does nothing for roughly the first 30–70 seconds of a live session (the scripted pause had to wait), which is why the two-minute pauses were started 40+ s in. Whether the Siri Remote's click pauses at once on the Apple TV is Open Question 1.
4. A `StateCard.body` name clash and a missing `import AVKit` (compile errors on the first build).

## Open Questions

1. **Select at the start of playback.** On the simulator a Select press is ignored for the first 30–70 s of a live session (not for a recording). Does the Siri Remote click pause a live channel immediately on Home Theater? If not, the focus handoff to AVPlayerViewController needs another look.
2. **Channels without a current listing cannot be tuned.** On Now and the Guide list only channels with a program (guide.go:683-688), so when the antenna guide is stale (the HTTP 403 of Pass 6 §8.6) the antenna channels vanish from every entry point. A tune-by-channel entry is not in any sweep; where should it go?
3. **Apple's transport bar shows its own red "LIVE" badge on recordings** while the EVENT playlist has no ENDLIST (`51-recording-playing-hud-6c.jpg`); AVKit treats EVENT as live. Cosmetic; hide Apple's title view, or accept?
4. **HUD placement and timing.** The overlays sit top-left and hide after 6 s (shown while paused, after a seek, and with a notice) so Apple's transport bar keeps the bottom; the design draws a persistent bottom panel. Confirm.
5. **"Prepared to"** is AVFoundation's seekable end rather than a parse of the playlist (the keep-alive fetch is one byte). Acceptable?
6. **Untested paths:** 6f, 6g (the busy-tuner naming from `/api/schedule`), 6h with Restart, the pause-point-left-the-buffer notice (a pause over an hour), the next-episode countdown and auto-play (one recording on the server), and the 404 "share not mounted" text.
7. **Seek beyond the prepared range** triggers when a user seek lands within 1.5 s of the prepared end; in the test three skip-forward presses did it. Scrubbing to the end of the bar is the intended gesture; confirm on the remote.
8. **A recording still being recorded** ends its playlist early (contract §3); playing to that end would mark it watched. Guard by comparing position to `duration`, or a server-side matter?
9. **Keep-alive traffic:** six one-byte requests a minute per session in the server log. Fine?
10. **Console prints** (`[player]`, `[session]`) remain as diagnostics.
11. **The one watchdog-ended session** (`smtpvozdff24e8f`) is recorded above; nothing to do, noted for the record.
12. **Live HUD "behind live" while paused** counts up with the wall clock (`pausedPosition + held`); after resume the measured lag matched it within a second in every run, but the two are computed differently.

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `Marlin DVR TV/PlaybackSession.swift` (new) | 1 |
| `Marlin DVR TV/PlayerModel.swift`, `PlayerHost.swift`, `PlayerScreen.swift` (new) | 2–4 |
| `Marlin DVR TV/ResumeStore.swift` (new) | 3 |
| `Marlin DVR TV/PlayRequest.swift` (new) | 5 |
| `Marlin DVR TV/ContentView.swift`, `ScreenShell.swift`, `OnNowScreen.swift`, `GuideScreen.swift`, `AiringSheet.swift`, `RecordingsScreen.swift`, `ShowDetailScreen.swift`, `CamerasScreen.swift` (Pass 5/6 files: entry points and the resume line only) | 5 (3 for show detail's resume line) |
| `reports/assets/pass7/*.jpg` (22 files, 4.2 MB) | 6 |
| `COLD-START.md` — "What is built", "What is NOT built", "Next step" | deliverable |
| `reports/2026-09-06-pass7-sweep3-player.md` (this file) | deliverable |
| Local commit "Pass 7: sweep 3 — Player"; **no push** | deliverable |

Untouched: `DECISIONS.md`, `Info.plist`, the project file and build settings, `Assets.xcassets`, `Theme.swift`, `ServerAPI.swift`, `Models.swift`, `ChannelFilter.swift`, `ClientSession.swift`, `Destination.swift`, `RailView.swift`, `HomeView.swift`, `Formatting.swift`, `ScreenChrome.swift`, `OnLaterScreen.swift`, `ServerImage.swift`, `Marlin_DVR_TVApp.swift`. Outside the repo: DerivedData, the app on the simulator and on Home Theater, fifteen session records on the server (all inactive), and the watched flag on one recording. The reference clone and `design/` were only read. No request went beyond port 8090; none to marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing installed; no packages; no third-party code.

## Pass 7B — live TV does not pause: cause established, no fix applied (2026-09-06)

**Owner test result** (Home Theater, 2026-09-06): recording resume PASS, camera PASS, live FAIL — after a live channel starts, clicking the touch surface scrubs but never pauses. Owner requirement: a click pauses live TV immediately once the picture is up; a second click resumes from the pause point.

**Outcome of this pass, stated first:** the cause is established with evidence and it is not app code intercepting the click. AVPlayerViewController itself declines to pause an HLS item that has no `#EXT-X-ENDLIST` while its seekable window is short (observed: refused at 30 s and 36 s, accepted at 60 s). A live session's window starts at zero and grows two seconds per two seconds, so the first minute after tuning is unpausable by Apple's own handling; a recording escapes the same rule within seconds because ffmpeg finishes segmenting it and the playlist gains ENDLIST. Under the constraint that Apple's play/pause handling must receive the click as it does on a recording, with no custom play/pause gesture added, there is nothing in the app to remove or reroute — so no code fix was made, and this pass stops for the owner's decision (below). Every session started was stopped.

### Step 1 — reproduction on the simulator

Instrumentation (kept in this commit, all `print`): `PlayerContainerController` logs every press it receives with the press types, the focused item, the player's `rate`, `timeControlStatus`, `reasonForWaitingToPlay`, the current time and the item's seekable window (`PlayerHost.swift:78-90`), and every focus change; `PlayerModel` logs every `timeControlStatus` transition (`PlayerModel.swift:199`) and every entry into the live recovery check (`:231`). Select was sent 1, 5 and 30 seconds after the console reported the first playlist (the picture appears within a second of it), plus 60 and 90 s on live.

| Path | Select at | Seekable window at the press | Focused item | rate / status before | Result |
|---|---|---|---|---|---|
| recording `smtpykwwka1debc` | +1 s | none yet | `_AVFocusContainerView` (AVKit) | 1.0 / playing | **ignored** |
| recording | +5 s | 0–36 s (36 s, growing) | same | 1.0 / playing | **ignored** |
| recording | +30 s | 0–191 s, fully segmented (ENDLIST) | same | 1.0 / playing | **paused** (`timeControl=0`, `[player] paused (0:32)`) |
| live ch2.1 `smtpym8o2a96b35` | +1 s | 0–0 s | same | 1.0 / playing | **ignored** |
| live | +5 s | 0–4 s | same | 1.0 / playing | **ignored** |
| live | +30 s | 0–30 s | same | 1.0 / playing | **ignored** |
| live | +60 s | 0–60 s | same | 1.0 / playing | **paused** (`timeControl=0`, `[player] paused (0 s behind live)`) |
| live | +90 s | 0–90 s | same | 0.0 / paused | **resumed from the pause point** (t = 63 s before and after; `recover check: t=63.2 range=0.0-90.1` → no seek) |

Press delivery was identical in every row: `began types=2040` (the touch-surface click), `began types=4` (Select), `ended types=2040`; the Select's `ended` never reaches the container in any row — AVPlayerViewController consumes it — whether or not it pauses. Focus was on AVKit's `_AVFocusContainerView` from the moment the host appeared (`[focus] nil → _AVFocusContainerView`) and stayed there; no overlay ever held focus. No keep-alive, HUD or recovery activity coincided with a press. A first live run (`smtpyfs3ua1a84f`, presses at 1/5/30 s) gave the same three "ignored" results.

The recording therefore has the same defect in its first seconds; the owner's "recording pauses correctly" holds because a 3-minute recording is fully segmented (ENDLIST) within about ten seconds, after which pause works. A long recording in transcode mode is segmented at roughly seven times real time, so its window passes 60 s within about ten seconds too.

### Step 2 — cause, with file:line

- The click reaches Apple's handling on live exactly as on a recording: `PlayerHost.swift:78-84` forwards every non-Menu press with `super.pressesBegan`, `:87-90` likewise for `pressesEnded`; `:52` keeps focus on the player controller; `:38` sets `requiresLinearPlayback` only for cameras. The press log shows the same sequence, the same focused item and the same forwarded state on both paths.
- Nothing live-only touches the press path: the overlays (`PlayerScreen.swift:69-77`) are non-focusable SwiftUI views and never appear in the focus log; the keep-alive (`PlayerModel.swift:288`) is a background fetch; `tick()` (`:183`) only reads the player; the live recovery (`:231`) ran once, on the +90 s resume, and did not seek because the position was inside the window.
- The variable that separates "ignored" from "paused" is the item's seekable window and the presence of ENDLIST, not the path, the time since start, or the focus: refused at 30 s (live) and 36 s (recording, no ENDLIST); accepted at 60 s (live) and at 191 s with ENDLIST (recording). That is AVPlayerViewController's own treatment of short-window live streams (it also shows its red LIVE badge in that state, Pass 7 Open Question 3). The server's live playlist starts empty and lists only the segments ffmpeg has produced (`hls.go:79-80`, contract §4: 2-second segments, the window fills at real time), so the window is under a minute for the first minute of every live session.

### Step 3 — fix

None applied. Under the stated constraint the only things "in the way" are AVKit's rule and the server's initially empty window; neither is app code, and the app cannot enlarge a window whose segments do not exist yet. The remedies are the owner's call:

1. **App-side Select handling while the window is short** — the container already receives the Select `began`; it could pause/resume the player itself when, after the press, AVKit has left the player playing. That is exactly the "custom play/pause gesture on top" the constraint forbids, so it was not built.
2. **Accept the first minute.** After ~60 s of a live session the click pauses and resumes from the pause point (the +60/+90 rows), and the Pass 7 two-minute pauses all ran after that point.
3. **A server-side change** would have to make the playlist advertise a longer window from the first second, which is not possible for segments that do not yet exist; raised only to say it was considered.

The Pass 7 finding "Select ignored for the first 30–70 s on the simulator" is this same rule, not a focus problem; the explicit focus update added in Pass 7 is harmless but was not the fix it seemed.

### Steps 4–5

Not run: there is no fixed build to prove or install. Home Theater keeps the Pass 7 build, running. The three sessions started in this pass — `smtpyfs3ua1a84f` (live ch2.1), `smtpykwwka1debc` (recording), `smtpym8o2a96b35` (live ch2.1) — each ended with the app's DELETE (`[session] DELETE … → 200 {"ok":true,"wasRunning":true}` in the console for all three); `GET /api/play/sessions` afterwards: `active: 0`, all three listed inactive. No library or schedule write was made.

### Open Questions (Pass 7B)

1. Which remedy: the app-side handler for the short-window period (lifting the constraint), accepting the first minute, or something on the server side that I have not thought of?
2. On the Apple TV, a click near the left or right edge of the touch surface skips ±10 s in AVKit's player; the owner's "it scrubs" may include that. A centre click after a minute should pause — worth one check when deciding.
3. The diagnostic `print` lines added here (`[press]`, `[focus]`, the fuller `[player] timeControl=…`) stay in the code for the owner's own reproduction; remove them with the fix.

### SCOPE CHECK (Pass 7B)

| Path | Step |
|---|---|
| `Marlin DVR TV/PlayerHost.swift` — press, focus and window logging | 1 |
| `Marlin DVR TV/PlayerModel.swift` — status-transition and recovery logging | 1 |
| `reports/2026-09-06-pass7-sweep3-player.md` — this section | deliverable |
| Local commit "Pass 7B: live TV pause — cause established, no fix (owner decision)"; **no push** | deliverable |

No other file changed. Server traffic: GETs, the ping, three play sessions with their DELETEs, `GET /api/play/sessions`. Nothing installed; no plist or build-setting change.

## Pass 7C — live pause during the first minute (owner decision 1a, 2026-09-06)

**Decision recorded** (`DECISIONS.md`, under 2026-09-06, verbatim from the task): the app handles Select itself while a live channel's seekable window is too short for AVPlayer to pause, holds the position, and defers to AVPlayer's own handling once the window is long enough.

### What changed (files:lines)

- `Marlin DVR TV/PlayerHost.swift` (rewritten, 136 lines). `PlayerHost` gains `shortWindowSelect`, true for live channels only. `PlayerContainerController`: the threshold `appleHandlesFromWindow = 60` s (`:43`) — Pass 7B measured AVPlayerViewController refusing to pause at a 30 s and a 36 s window and accepting at 60 s, so the hand-over is at 60 s; `appleGrace = 0.35` s (`:46`); `seekableWindow` (`:84`) reads the item's seekable range; `pressesBegan` (`:91`) forwards every press to Apple's handler as before and, for a live item, also calls `handleShortWindowSelect` (`:109-136`): if the window is 60 s or more it only logs "→ Apple's handler" and does nothing; below 60 s it notes whether the player was playing and, 0.35 s later — after Apple's handler has had the press-ended it acts on — pauses the player if it is still playing, or resumes it (`player.play()`, from the paused position, never a seek) if it is still paused; if Apple's handler already changed the state it does nothing. Edge clicks, swipes and every other press are untouched; the Menu catch is unchanged. The Pass 7B diagnostics (`describePress`, `didUpdateFocus`) are gone.
- `Marlin DVR TV/PlayerScreen.swift:34` — passes `shortWindowSelect: model.isLive`.
- `Marlin DVR TV/PlayerModel.swift` — the Pass 7B diagnostic lines (the per-transition `timeControl=…` print and the recovery-check print) removed; the Pass 7 `[player] paused / playing` lines stay for the evidence. Nothing else in the model, the recording path or the camera path changed. The keep-alive runs throughout, unchanged.

**Threshold used: 60 seconds of seekable window.** Below it the container acts; from it on, Apple's handler alone. Because the container acts only when Apple's handler has left the player as it was, a lower real threshold on some tvOS build cannot double-toggle.

### Step 4 evidence (simulator; console lines and `GET /api/logs`)

Antenna, ch2.1 WMAR-HD, session `smtpz7v5v29af7b`:

```
[select] window 0 s < 60 → app paused           ← Select 1 s after the picture (11:38:33)
[player] paused (0 s behind live)
[select] window 120 s → Apple's handler         ← Select after 2 min (11:40:34)
[player] playing (0 s behind live)
[select] window 126 s → Apple's handler         ← Select: Apple pauses
[player] paused (119 s behind live)             ← 119 s behind = resumed from the pause point, not the edge
[select] window 130 s → Apple's handler         ← Select: Apple resumes
[player] playing (118 s behind live)
[player] stop: phase=playing session=smtpz7v5v29af7b
[session] DELETE smtpz7v5v29af7b → 200 {"ok":true,"wasRunning":true}     (server seq=4481 11:40:48.633)
```

Screens: `90-7c-antenna-paused-1s.jpg` — the 6d overlay one second in: "Paused at 11:38 AM · now 2 s behind live · Held for 0:02 · the buffer holds 0 s"; `91-7c-antenna-paused-2min.jpg` — the same overlay two minutes later with the lag grown; `92-7c-antenna-resumed-lag.jpg` — after the resume: **"LIVE · −1 min 59 s · 1 min 59 s behind live · buffer 2 min 2 s"**; `93-7c-antenna-paused-apple.jpg` — the pause Apple's handler made.

Philo, ch9001 HISTORY, session `smtpzbcsk4ea3b5`: `[select] window 0 s < 60 → app paused` at +1 s (11:41:10); after 2 min `[select] window 130 s → Apple's handler`, `[player] playing (8 s behind live)`; then Apple's pause `[player] paused (129 s behind live)` and resume `playing (128 s behind live)`; DELETE (seq=4636 11:43:24.591). Screens `94-7c-philo-paused-1s.jpg`, `95-7c-philo-resumed-lag.jpg` ("−2 min 7 s · buffer 2 min 10 s").

Left alone, ch9001 HISTORY, session `smtpzecvxb8cd1f`: tuned and untouched for about 100 s, then Select: `[select] window 106 s → Apple's handler`, `[player] paused (4 s behind live)` — no interception; Select again: `[select] window 106 s → Apple's handler`, `[player] playing (3 s behind live)`; DELETE (seq=4783 11:45:19.630). Screen `96-7c-70s-paused-apple.jpg` ("the buffer holds 1 min 46 s").

Recording, session `smtpzha3te0bba7` (start 32.2 s from the resume store): `[player] paused (0:44)` and `[player] playing (0:45)` on two Selects with no `[select]` line — Apple's handler alone, as before; DELETE (seq=4834 11:46:06.894). Camera, session `smtpzi96vffe850`: played (`97-7c-camera.jpg`), Menu, DELETE (seq=4859 11:46:43.534).

Sessions list afterwards (`GET /api/play/sessions`):

```
active: 0
  smtpz7v5v29af7b live inactive | ch2.1 WMAR-HD
  smtpzbcsk4ea3b5 live inactive | ch9001 HISTORY
  smtpzecvxb8cd1f live inactive | ch9001 HISTORY
  smtpzha3te0bba7 recording inactive | Earth Odyssey With Dylan Dreyer
  smtpzi96vffe850 camera inactive | Cow Cam
```

Five POSTs, five DELETEs in the server log (seq 4360/4481, 4489/4636, 4641/4783, 4800/4834, 4848/4859). Builds: simulator and Home Theater both `BUILD SUCCEEDED`, no warnings.

### Step 5

The Pass 7C build was installed and launched on Home Theater at 11:47 (ping and five GETs from the device in the server log) and is left running.

### Open Questions (Pass 7C)

1. The 0.35-second grace before the container acts is the one visible cost: in the first minute a pause lands about a third of a second after the click. Shorten it, or accept?
2. `[select] …` and the Pass 7 `[player] paused/playing` console lines remain as evidence; remove with the sweep 4 cleanup.

### SCOPE CHECK (Pass 7C)

| Path | Step |
|---|---|
| `DECISIONS.md` — one bullet under 2026-09-06 | 1 |
| `Marlin DVR TV/PlayerHost.swift` — short-window Select handling; 7B diagnostics removed | 2, 3 |
| `Marlin DVR TV/PlayerScreen.swift` — one argument | 2 |
| `Marlin DVR TV/PlayerModel.swift` — 7B diagnostics removed | 3 |
| `reports/assets/pass7/9*-7c-*.jpg` (8 files) | 4 |
| `reports/2026-09-06-pass7-sweep3-player.md` — this section | deliverable |
| Local commit "Pass 7C: live pause during the first minute"; **no push** | deliverable |

No other file changed. Server traffic: GETs, the ping, five play sessions with their DELETEs, the sessions list. No library or schedule write. Nothing installed on the Mac; no plist or build-setting change.

## Pass 7D — sweep 3 acceptance and push (2026-09-06)

**Owner's acceptance:** sweep 3 (the Player, including the Pass 7C live pause) tested on Home Theater 2026-09-06 — live pause from the first second, resume from the pause point, recording resume, camera: all pass. Recorded in `DECISIONS.md` under 2026-09-06.

**Push.** Pass 7D commits `DECISIONS.md` and this section as "Pass 7D: sweep 3 acceptance" and pushes `origin main`, carrying the three approved commits with it:

| Commit | What it is |
|---|---|
| `b0b03ec` | Pass 7: sweep 3 — Player (the 6 new Player files, the entry points, 22 screenshots, the report) |
| `b6b5eab` | Pass 7B: live TV pause — cause established, no fix (the reproduction and the diagnosis) |
| `7ad29cf` | Pass 7C: live pause during the first minute (owner decision 1a; the 60-second threshold, 8 screenshots) |
| this one | Pass 7D: sweep 3 acceptance |

No code changed in this pass and no request was sent to the server. The three-SHA verification (local `HEAD`, `origin/main` after `git fetch`, `git ls-remote origin main`) is stated in the pass's closing reply; no follow-up commit writes it here.
