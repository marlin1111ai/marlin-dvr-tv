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
