# Pass 3 — HLS client recon (read-only) + two decisions — 2026-09-05

Source-plus-contract recon of what the Marlin DVR TV app must do to play video from the Marlin DVR server's HLS output, against `HLS-CLIENT-API.md` in the reference clone. No request was sent to the server or any LAN host. Network use: `git fetch origin` in the reference clone and the push of this report. Nothing installed, nothing run.

Citation keys: `contract §n` = a section of `HLS-CLIENT-API.md`; `file:line` = `cmd/marlin-dvr/` in the reference clone at HEAD unless another folder is named; `Pass 2 §n` = `reports/2026-09-05-pass2-server-recon.md` in this repo; Apple documents are cited by title and URL from prior knowledge — **no Apple page was fetched in this pass** (network was limited to git), so those citations are pointers to verify, not quotations.

## 1. Reference clone and the contract (step 1)

| Item | Value |
|---|---|
| Path | `~/Xcode/marlin-dvr-reference` |
| HEAD before `git fetch origin` | `eef49e8919b7842de293a62e864ee2730509dcac` |
| `git fetch origin` | ran, exit 0, nothing new |
| `origin/main` after fetch | `eef49e8919b7842de293a62e864ee2730509dcac` |
| `git rev-list --left-right --count HEAD...origin/main` | `0 0` |
| HEAD commit | "Pass 19 report: pushed SHA", 2026-09-05 19:55:39 -0400 |
| Working tree | clean except the untracked `README-REFERENCE.md` from Pass 1 |
| `HLS-CLIENT-API.md` at HEAD | present (`git cat-file -e HEAD:HLS-CLIENT-API.md`), 231 lines |
| "as pushed at" SHA the contract cites | `ed49d64` (contract line 4), server version **1.1.0** (`main.go:38-39`) |

Two facts about the clone's history:

- HEAD was `d0280f76` when Pass 2 read it. The clone's reflog shows `pull: Fast-forward` to `eef49e8` at 2026-09-05 20:01:36 -0400, after Pass 2 and before this pass. That pull was not made by this project's passes (Pass 2 only fetched). No pull was needed or made in this pass.
- The contract's cited SHA `ed49d64` is two commits behind HEAD (`82c7055` "Pass 19: 1.1.0 deployed, HLS client note", `eef49e8`). `git diff --stat ed49d64 HEAD` touches only `COLD-START.md`, `DECISIONS.md`, `HLS-CLIENT-API.md` and `reports/2026-09-05-pass19-deploy-record.md`. **No code differs between `ed49d64` and HEAD**, so every code citation was checked against HEAD and that is the same as checking it against the cited SHA.

What changed in the server between Pass 2's `d0280f76` and HEAD (13 commits, Passes 14–19): `hls.go` (new, 337 lines), `procs.go` (new, 161 lines), `stream.go` (+36/−…: `format` field, HLS start, orphan-guard hooks), `main.go` (version 1.1.0, the HLS route, the guard sweep and shutdown), `recorder.go` (guard hooks), the deploy template pinned to `:1.1.0`, notebook and six reports. `library.go`, `sources.go`, `cameras.go`, `clients.go` and `web/` are byte-identical to what Pass 2 read (`git diff --stat d0280f76 HEAD`).

### 1.1 Citation check — every `file:line` in the contract against HEAD

Method: each cited range was printed from HEAD (`sed -n`/`cat -n`) and compared with the sentence that cites it. "Resolves" = the cited lines are the described code (a range that starts or ends a line or two off is still counted as resolving and noted). "Differs" = the cited lines are other code; the actual location at HEAD is given.

**Resolve exactly or within a line or two (33):**

| Contract | Cited | Status at HEAD |
|---|---|---|
| §1 register route | `main.go:268` | resolves |
| §1 register handler | `clients.go:236-260` | resolves (handler is 236-259) |
| §1 request fields | `clients.go:224-231` | resolves |
| §1 defaults | `clients.go:245-249` | resolves (the "Web browser" fallback continues to 251) |
| §1 id generated | `clients.go:244` | resolves |
| §1 ping route / handler / 404 | `main.go:269`, `clients.go:262-…`, `clients.go:265` | resolve |
| §2 session route | `main.go:287` | resolves |
| §2 handler | `stream.go:179-300` | resolves (handler is 179-296) |
| §2 request body | `stream.go:180-186` | resolves (`format` is line 185) |
| §2.1 recording id / field / library | `library.go:638`, `:36`, `:428` | resolve |
| §2.1 channels handler, id, drm | `sources.go:1007`, `:319`, `:321` | resolve |
| §2.1 cameras handler | `cameras.go:280-288` | resolves (280-289) |
| §2.1 play/info route / handler | `main.go:293`, `stream.go:454-490` | resolve (handler 455-491) |
| §2.2 playlist URL | `hls.go:52` | resolves |
| §2.2 live title/sub | `stream.go:215-218` | resolves (214-218) |
| §2.2 recording title/sub | `stream.go:236-238` | resolves (237-238) |
| §2.2 recording copy/transcode | `stream.go:247-253` | resolves (246-252) |
| §2.2 live always transcode | `stream.go:221` | resolves (220-221) |
| §2.2 duration | `stream.go:239` | resolves |
| §2.2 startHLS | `hls.go:106-146` | resolves (107-147) |
| §3 output args | `hls.go:56-71` | resolves (57-72) |
| §3 keyframe forcing | `hls.go:58-62` | resolves (59-63) |
| §3 "ffmpeg finished … folder stays" | `hls.go:158-161` | resolves |
| §4 live/camera output args | `hls.go:68-70` | resolves (69-70) |
| §5 HLS route / handler | `main.go:292`, `hls.go:287-330` | resolve (handler 287-337) |
| §5 file-name rule / 404 | `hls.go:50`, `:290` | resolve |
| §5 410 session ended | `hls.go:296-300` | resolves (297-300) |
| §5 DELETE route / handler / HLS end | `main.go:289`, `stream.go:420-435`, `:426-428` | resolve |
| §5 sessions list route / handler | `main.go:288`, `stream.go:414-417` | resolve |
| §6 watchdog goroutine | `hls.go:184-198` | resolves (185-203) |
| §6 startup sweep | `main.go:363-366`, `cmd/marlin-dvr/procs.go` | resolve |
| §7 403 DRM, 404 channel, 404 camera, 400 bad json | `stream.go:206-209`, `:202-204`, `:255-257`, `:187-190` | resolve (205-208, 201-204, 256-259, 187-190) |
| §7 502 "HLS session could not start" and its reasons | `stream.go:290-295`; `hls.go:110`, `:127`, `:136` | resolve (286-290; reasons at 110, 127, 136) |
| §7 502 ffmpeg exited / no playlist within 20 s / blocking wait | `hls.go:311-318`, `:305-318`, `:303-322` | resolve (304-325) |
| §7 log route / handler | `main.go:290`, `stream.go:438-…` | resolve |
| §8 no auth middleware; fMP4 route/handler | `main.go:200-300`, `main.go:291`, `stream.go:315` | resolve (routes 201-315; handler 311-388) |

**Differ — the cited lines are other code (16). Actual location at HEAD:**

| Contract | Cited | What is at the cited lines | Actual at HEAD |
|---|---|---|---|
| §1 response with id | `clients.go:259` | closing brace | `clients.go:258` (`writeJSON(w, a.clientView(c))`) |
| §1 "a browser at <ip>" | `stream.go:212-216` | live-channel input error and title | `stream.go:192-196` |
| §2 `format` selects HLS | `stream.go:211`, `:289` | live input 400; `return` in the HLS-error branch | field `stream.go:185`, default `"mp4"` at `:191`, check `if req.Format == "hls"` at `:285` |
| §2, §3 `start` → `-ss` | `stream.go:224-226` | "no such recording" 404 | `stream.go:242-244` |
| §2 bad `kind` 400 | `stream.go:286-288` (also §7) | the HLS-error branch | `stream.go:279-282` |
| §2.1 channels route | `main.go:229` | `PUT /api/sources/{id}/lineup/{guid}` | `main.go:230` |
| §2.1 cameras route | `main.go:277` | `GET /api/library/shows/{id}` | `main.go:295` |
| §2.2 response written | `stream.go:299` | blank line after the handler | `stream.go:295` |
| §2.2 url assigned | `stream.go:296` | closing brace | `stream.go:291` |
| §2.2 camera title/sub | `stream.go:256-257` | "no such camera" 404 | `stream.go:265-266` |
| §2.2 camera copy/transcode | `stream.go:262-266` | camera RTSP-URL error | `stream.go:271-277` |
| §2.2 `startHLS` called | `stream.go:290` | `return` in the error branch | `stream.go:286` |
| §3, §4, §6, §7 constants `hlsRecordingSeg`, `hlsCameraSeg`, `hlsCameraList`, `hlsIdleTimeout`, `hlsPlaylistWait`, and "no delete_segments" | `hls.go:44`, `:45`, `:46`, `:42`, `:43`, `:66` | each one line early | `hls.go:45`, `:46`, `:47`, `:43`, `:44`, `:67` (the whole `const` block is 42-48) |
| §4 `transcodeArgs` | `stream.go:149-157` | `Session.stop()` | `stream.go:166-174` |
| §5 content types, no-store and `X-Marlin-Session` | `hls.go:324`, `:326`, `:333-334` | each one line early | `hls.go:325`, `:327`, `:334-335` |
| §5 relative URIs because ffmpeg runs in the session folder | `hls.go:113`, `:118` | `x.dir` assigned; context created | `hls.go:120` (`cmd.Dir = x.dir`) with the comment at 55-57 |
| §6 every fetch stamps the session; `touch` | `hls.go:298`, `:210-214` | the 410 error; inside `end()` | `hls.go:301` (and 323 inside the wait loop); `touch` at 218-222 |
| §6 shutdown ends HLS sessions | `main.go:397-399` | `signal.Notify` and the goroutine start | `main.go:404-406` |
| §7 404 recording missing file; 502 ffprobe; 404 no such recording | `stream.go:232-235`, `:237-240`, `:229-231` | ffprobe error; title/sub/duration; file-missing 404 | `stream.go:228-231`, `:232-236`, `:224-227` |
| §7 reason "session folder" | `hls.go:114` | `MkdirAll` line | `hls.go:115` |

**Non-code citations (4):**

| Contract | Cited | Status |
|---|---|---|
| §3 observed end state, 48 segments, `seg00047.m4s`, `#EXT-X-ENDLIST` | `reports/2026-09-05-pass18-version-1-1-0.md` §3a | resolves (report lines 151-154) |
| §3 recording still in progress ends early | `reports/2026-09-05-pass15-hls-recordings-cameras.md` Open Question 7 | resolves (report line 310) |
| §4 first playlist 5.8 s (antenna) / 1.8 s (M3U); §5 tuner free 1 s after DELETE | `reports/2026-09-05-pass16-hls-live.md` T1, T6 | resolve (T1: "HTTP 200 after 5.81 s", "tuner free after 1s"; T6: "HTTP 200 after 1.80 s") |
| §4 camera segments ~3 s observed | `reports/2026-09-05-pass16-hls-live.md` Open Question 3 | **does not resolve**: that Open Question is about the two guard lines in `handlePlaySession`. The camera observation is in the same report's T7b line ("after 8 s: MEDIA-SEQUENCE:0, 3 segments on disk") |
| §6 watchdog primary, DELETE in addition = "owner decision, Pass 16, recorded in DECISIONS.md" | reference `DECISIONS.md` | **attribution differs**: the reference `DECISIONS.md` records it under the Pass 15 owner decisions as a "Foreman default, told to owner … (Pass 14 Open Question 7)", not as a Pass 16 owner decision (reference `DECISIONS.md` line 183; the Pass 16 decisions at 184-187 are segment length, the orphan guard and tuner use) |

Everything the contract states about behaviour was found to match the code at HEAD; only line numbers and two report/decision attributions drift. Raised for the marlin-dvr project in Open Questions 6 and 7.

## 2. AVFoundation versus the app (step 2)

### 2(a) What AVPlayer/AVFoundation on tvOS handles on its own

| Server behaviour | Server evidence | What AVFoundation does with it | Apple/IETF reference |
|---|---|---|---|
| **EVENT playlist that grows, then `#EXT-X-ENDLIST`** (recordings) | `-hls_playlist_type event`, all segments kept (`hls.go:67`, contract §3); ENDLIST when ffmpeg finishes (contract §3; observed `pass18` §3a) | Treats `EXT-X-PLAYLIST-TYPE:EVENT` as append-only: keeps reloading the playlist, extends `seekableTimeRanges` as segments appear, and stops reloading once `EXT-X-ENDLIST` is present; `duration` becomes finite then | RFC 8216 §4.3.3.5 (EVENT), §4.3.3.4 (ENDLIST), §6.3.4 (reloading; a playlist with ENDLIST is not reloaded); `AVPlayerItem.seekableTimeRanges` and `.duration` — https://developer.apple.com/documentation/avfoundation/avplayeritem |
| **Live sliding window** (live channels, cameras) | 2-s segments, 6-entry list, `delete_segments`, media sequence advancing (`hls.go:70`, contract §4) | Reloads the playlist about once per target duration, follows `EXT-X-MEDIA-SEQUENCE`, plays near the live edge; `duration` is indefinite; `seekableTimeRanges` is the window | RFC 8216 §4.3.3.2 (MEDIA-SEQUENCE), §6.2.2 (live playlist, segments removed from the head), §6.3.3-6.3.4 (playing/reloading) |
| **Relative segment URIs** | ffmpeg runs inside the session folder so URIs are bare file names (`hls.go:55-57`, `:120`; contract §5) | Resolves each URI against the playlist URL (`…/api/play/hls/<id>/index.m3u8` → `…/api/play/hls/<id>/segNNNNN.m4s`) | RFC 8216 §4.1 (relative URIs are resolved against the playlist URI) |
| **fMP4 init segment** | `-hls_segment_type fmp4 -hls_fmp4_init_filename init.mp4` (`hls.go:64`); playlist carries `EXT-X-MAP` | Fetches `init.mp4` once per discontinuity range and applies it to the `.m4s` segments; fMP4 in HLS is supported on tvOS 10 and later | RFC 8216 §4.3.2.5 (EXT-X-MAP); "HLS Authoring Specification for Apple Devices" (fragmented MP4 segments) — https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices |
| **Byte ranges** | Segments are whole files (no `single_file` flag, `hls.go:64-70`), so the playlist has no `EXT-X-BYTERANGE`; files are served by `http.ServeFile`, which honours `Range` (`hls.go:336`) | Requests whole segments; `Range` support on the server is available but not needed. If a playlist ever used `EXT-X-BYTERANGE`, AVFoundation handles it | RFC 8216 §4.3.2.2 (EXT-X-BYTERANGE) |
| **Playlist polling** | Every playlist/segment GET stamps the session (`hls.go:301`) | Polls the playlist itself while it is live/EVENT (about every 2 s live, 4 s recording) and fetches segments as its buffer needs; no app timer is needed **while it is polling** (see 2(b) items 3 and 4 for when it is not) | RFC 8216 §6.3.4 |
| **Program date time** | `program_date_time` flag on live/camera (`hls.go:70`) | Exposes `AVPlayerItem.currentDate()` for the live window | RFC 8216 §4.3.2.6; `AVPlayerItem.currentDate()` |
| **Independent segments** | `independent_segments` flag (`hls.go:67`, `:70`) and forced keyframes on recording transcodes (`hls.go:59-63`) | Can start decoding at any segment boundary (seek granularity = segment) | RFC 8216 §4.3.5.1 (EXT-X-INDEPENDENT-SEGMENTS) |
| **Codecs** | H.264 High 4.1 ≤ 720p + AAC-LC (transcode) or copied H.264 + AAC/MP3 (`stream.go:166-174`, `:246-252`, `:271-277`) | Hardware-decoded on every Apple TV | Pass 2 §3.7 (unchanged by the contract) |

### 2(b) What the app must do itself

Each item: what it is; what fails without it; where the app has more than one way, the ways are listed as facts and the choice is left to Open Questions.

1. **Create the session.** `POST /api/play/sessions` with JSON `{"kind": "recording"|"live"|"camera", "id": …, "format": "hls", "client": <client id>, "start": <seconds, recordings only>}` (contract §2; `stream.go:180-186`, `:285-291`). The response's `url` is a server-relative path (`/api/play/hls/<id>/index.m3u8`, `hls.go:52`), to be resolved against the base URL the app uses (host port 8090, Pass 2 "How the inventory was made"). ffmpeg and, for live, the tuner are held from this moment (contract §2.2; `hls.go:107-147`).
   *Without it:* there is no playlist to give AVPlayer; the HLS route answers 404 for an unknown session (`hls.go:290-293`). Omitting `format` yields the fragmented-MP4 pipe, which AVPlayer cannot play (contract §8; Pass 2 §3.7).

2. **Survive the first-playlist wait.** The first `GET …/index.m3u8` blocks until ffmpeg's first segment exists, polling every 200 ms for up to 20 s, then answers 502 (`hls.go:44`, `:304-325`; contract §7). Measured first-playlist times: 5.8 s antenna live, 1.8 s M3U live, 4.6 s camera (pass16 T1, T6, T7b). AVFoundation exposes no documented per-request timeout for playlist loads (`AVURLAsset` options — https://developer.apple.com/documentation/avfoundation/avurlasset — carry no timeout key), so how long AVPlayer itself waits is undocumented. Facts about the two ways: (i) hand the URL straight to `AVPlayer(url:)` and rely on its undocumented wait; (ii) fetch `index.m3u8` once with `URLSession` (`timeoutIntervalForRequest` above 20 s) before creating the player, which also surfaces 502/410/404 as plain HTTP statuses with text bodies; that fetch stamps the session (`hls.go:301`), so the player must then start fetching within 15 s (item 3). A second playlist fetch returns at once because the file exists (`hls.go:306-308`).
   *Without it:* a player or client whose timeout is under the wait sees a failure while the server is still starting; the session is then left to the 15-s watchdog.

3. **Keep the 15-s idle watchdog fed while paused.** Nothing fetched for 15 s ends the session: ffmpeg is killed, the folder deleted, the tuner released (`hls.go:43`, `:185-203`; contract §6). Only playlist and segment GETs count (`hls.go:301`). A paused AVPlayer stops fetching once its buffer is full; Apple documents the forward buffer as player-controlled (`AVPlayerItem.preferredForwardBufferDuration` — https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredforwardbufferduration) and does not document continued polling while paused. Ways, as facts: (i) the app issues its own `GET …/index.m3u8` on a timer shorter than 15 s while paused; (ii) the app `DELETE`s the session on pause and creates a new one on resume, with `start` = the saved position for a recording (live has no `start`, `stream.go:199-221`); (iii) the app never pauses the player (mute/hide instead).
   *Without it:* after 15 s paused every request returns 410 `session ended` (`hls.go:297-300`); resuming fails until a new session exists.

4. **Keep the watchdog fed after `#EXT-X-ENDLIST` while playing.** Once a recording is fully segmented the playlist carries ENDLIST (contract §3) and a compliant client stops reloading it (RFC 8216 §6.3.4). From then on only segment fetches stamp the session. In steady playback AVPlayer fetches roughly one 4-s segment per 4 s of playback, under the limit; but when its forward buffer already holds the rest of the recording (the last part of any recording, or any stretch it has buffered ahead of a seek), no fetch happens and the watchdog ends the session while playback continues from the buffer. A later seek back into deleted segments then gets 410. This is source-level reasoning (`hls.go:185-203`, `:301`; RFC 8216 §6.3.4) plus Apple's documented buffer control; it is untested.
   *Without it:* seeks late in a recording can fail with 410 after the session has quietly ended. The same three ways as item 3 apply.

5. **Seek past the segmented range with a new session.** AVPlayer seeks freely inside `seekableTimeRanges` (2(a)). For a recording, a target beyond what ffmpeg has segmented so far needs a new `POST` with `start` = the target in seconds; it becomes ffmpeg's `-ss` (`stream.go:242-244`; contract §3). The new session has its own id, playlist and numbering from 0; the old session should be `DELETE`d or it lives until its watchdog fires. Live and camera sessions ignore `start` (`stream.go:199-221`, `:254-278`) and have no time-shift (contract §4).
   *Without it:* seeking beyond the segmented range stalls at the end of `seekableTimeRanges`.

6. **Compute position = `start` + player time.** A session created with `start` = S has a timeline that begins at 0 (contract §3), so the absolute position in the recording is S + `AVPlayer.currentTime()` (https://developer.apple.com/documentation/avfoundation/avplayer/currenttime()). The whole recording's length is `duration` in the session response (`stream.go:239`), not the player's `duration`.
   *Without it:* the scrubber, resume point and "watched" logic are off by S after any seek-by-new-session.

7. **Stop with `DELETE /api/play/sessions/{id}`.** No body; response `{"ok": true, "wasRunning": …}`; for HLS it records the reason and cancels the session, ffmpeg is killed, the folder removed, the tuner released about 1 s later (`stream.go:420-435`; `hls.go:165-181`; contract §5; pass16 T1).
   *Without it:* the session ends anyway 15 s after the last fetch (`hls.go:185-203`), so a tuner stays held up to 15 s longer and the folder persists that long; the owner's rule is that the watchdog is primary and DELETE is in addition (contract §6; reference `DECISIONS.md` line 183).

8. **Handle the error statuses.** All are plain-text bodies (Pass 2 "How the inventory was made"). On `POST`: 403 `this channel is DRM-protected and cannot be streamed` (`stream.go:205-208`); 404 `no such channel` / `no such recording` / `no such camera` (`stream.go:201-204`, `:224-227`, `:256-259`); 404 `recording file is not available (is the share mounted?)` (`stream.go:228-231`); 502 ffprobe message (`stream.go:232-236`); 502 `HLS session could not start: …` (`stream.go:286-290`); 400 `bad json` / `kind must be …` (`stream.go:187-190`, `:279-282`). On the HLS route: 404 for an unknown session or a file name outside `index.m3u8|init.mp4|segNNNNN.m4s` (`hls.go:50`, `:290-293`); 410 `session ended` (`hls.go:297-300`); 502 `ffmpeg exited before writing a playlist` / `ffmpeg produced no playlist within 20s` on the first playlist GET, after which the session is ended (`hls.go:312-321`). Inside AVPlayer these statuses surface only as an item failure (`AVPlayerItem.status == .failed`, `AVPlayerItemFailedToPlayToEndTime`) and in `AVPlayerItem.errorLog()` entries, which carry the HTTP status (https://developer.apple.com/documentation/avfoundation/avplayeritemerrorlogevent); a `URLSession` pre-fetch (item 2) sees them directly. The session log (`GET /api/play/sessions/{id}/log`, `stream.go:438-452`) holds ffmpeg's stderr. The `drm` flag on `/api/channels` and `/api/play/info?live=` lets the app avoid the 403 before posting (`sources.go:321`; `stream.go:464`).
   *Without it:* DRM channels, a missing share, a dead camera and an expired session all look like a generic playback failure.

9. **Register the client and ping it; persist the id.** `POST /api/clients/register` with `{"name","app","type","os"}` returns the client with a server-generated `id` (`clients.go:236-259`; contract §1); a tvOS user agent is not recognised, so without explicit fields the entry reads "Web browser" (`clients.go:124-160`, `:246-251`). `POST /api/clients/{id}/ping` on launch updates last-seen; an unknown id answers 404 `unknown client; register again` (`clients.go:262-266`). The `id` in a register body is ignored (`clients.go:225`, `:244`; Pass 2 §4), so the id **must persist on the device** or every launch creates a new Clients-page entry. Ways, as facts: `UserDefaults`, the Keychain, or `NSUbiquitousKeyValueStore` (survives reinstall via iCloud). The id goes in `client` on the session POST so the server's "Watching … from …" line names the device (`stream.go:192-196`); an unknown or empty `client` is not an error (contract §1).
   *Without it:* the Clients page fills with duplicate devices and sessions show as "a browser at <ip>".

10. **Carry an App Transport Security exception.** The server is plain HTTP with no TLS (`main.go:370`, `:392`; Pass 2 gap 8). ATS blocks plain-HTTP loads by default; the documented ways to allow them are `NSAppTransportSecurity` → `NSExceptionDomains` → `<host>` → `NSExceptionAllowsInsecureHTTPLoads`, or `NSAllowsArbitraryLoads`, or `NSAllowsLocalNetworking` (https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity; "Preventing Insecure Network Connections" https://developer.apple.com/documentation/security/preventing-insecure-network-connections). Which of these covers a numeric LAN address rather than a hostname was not settled by anything read in this pass and must be checked against that documentation and a device test. This is an Info.plist change and is out of scope here (task DO-NOT-TOUCH).
   *Without it:* every request to the server, and every AVPlayer load, fails before it leaves the device.

11. **Resolve relative URLs against the app's base.** Every URL the API returns is server-relative (Pass 2 §5 item 3): the session `url`, `thumb`, `art`, `rss`. The Unraid host maps 8090 → 8089 (contract line 8-9; `deploy/marlin-dvr.xml:17`), so the base is whatever the app was configured with, never the container's port.
   *Without it:* the playlist URL and every image URL are unusable.

## 3. Non-playback endpoints the contract references (step 3)

`library.go`, `sources.go`, `cameras.go` and `clients.go` are unchanged between `d0280f76` and HEAD (`git diff --stat`), so Pass 2's shapes stand; cited here rather than re-derived. `stream.go` changed: `handlePlayInfo`'s body is unchanged but now sits at `stream.go:455-491` (Pass 2 cited 423-459).

| Endpoint | Purpose for the app (contract) | Request / response | Pass 2 cite | HEAD line |
|---|---|---|---|---|
| `GET /api/channels?source=&filter=&hidden=1` | channel ids for live sessions; the `drm` flag says which channels the server refuses with 403 (contract §2.1) | `{channels: [MergedChannel], count, sources}`; `MergedChannel.id` = `sourceID:guid`, `drm: bool`, plus `number, name, logo, hd, hidden, favorite, initials, logoBg` | Pass 2 §2.5 | `sources.go:1006-1022`, id `:319`, drm `:321` |
| `GET /api/library?limit=` | the shows | `{sections: [...], shows, recordings, roots, scannedAt, scanning, configured}`; each item `{id, title, count, unwatched, art, lastAdded, lastUpdated, lastWatched}` | Pass 2 §2.13 | `library.go:427-469` |
| `GET /api/library/shows/{id}?trash=1` | recording ids (`episodes[].id`) | `{id, title, episodes: [episodeView], count, trashCount, showingTrash, art, info, pass, rss}`; `episodeView` carries `id, file, show, showId, episodeTitle, season, episode, aired, size, watched, favorite, keep, trash, thumb, exists, …` | Pass 2 §2.13 | `library.go:586-640`, `episodes` at `:638` |
| `GET /api/cameras` | camera ids | `{cameras: [Camera], count, online}`; `Camera.id, name, address, streamPath, hidden, online, lastCheck, lastError, codec` (password blanked) | Pass 2 §2.15 | `cameras.go:279-289` |
| `GET /api/play/info?rec=|live=|cam=` | title, subtitle, art, `duration` (recording) and `drm` (channel) without starting anything (contract §2.1) | live `{kind, id, title, sub, drm, art}`; recording `{kind, id, title, sub, duration, showId, watched, art}`; camera `{kind, id, title, sub, art}` | Pass 2 §2.14 | `stream.go:454-491` |
| `POST /api/clients/register` | obtain the client id (contract §1) | body `{name?, app?, type?, os?, userAgent?}` → `clientView` `{id, name, app, type, os, ip, createdAt, lastSeen, online, location, locIcon, lastSeenLabel, watching, watchingIcon}` | Pass 2 §2.12, §4 | `clients.go:224-259` |
| `POST /api/clients/{id}/ping` | keep the registration current (contract §1) | optional `{app?, os?, type?}` → `clientView`; 404 text `unknown client; register again` | Pass 2 §2.12, §4 | `clients.go:261-285` |

**What changed between `d0280f7` and HEAD that touches the app:**

- `POST /api/play/sessions` gained the request field `format` and the response field `format` (`stream.go:185`, `:295`); Pass 2 §2.14's shapes are otherwise intact. With `format: "hls"` the `url` is the playlist path instead of the `.mp4` pipe (`stream.go:284-292`).
- New route `GET /api/play/hls/{id}/{file}` (`main.go:292`; `hls.go:287-337`) — route count 87 → 88 method-qualified routes plus the two catch-alls (90 `HandleFunc` calls at HEAD, all in `main.go`).
- `Session` objects from `GET /api/play/sessions` gained `format` (`stream.go:49`).
- `DELETE /api/play/sessions/{id}` now also ends an HLS session with a recorded reason (`stream.go:426-428`).
- Server version reported by `GET /api/status` and `/api/system` is `1.1.0` (`main.go:38`).
- Main.go route lines after 291 shifted by one and the startup/shutdown code by six to nine lines; nothing else in the non-playback API moved.
- The deploy template pins `ghcr.io/marlin1111ai/marlin-dvr:1.1.0` (`deploy/marlin-dvr.xml:4`), and the reference notebook records the Unraid container running 1.1.0 since 2026-09-05 (reference `DECISIONS.md`, Pass 19 entry). Not verified by this pass (no request sent).

## 4. Environment check, read-only (step 4)

Device identifiers in the pasted output are replaced with `[REDACTED]` per the evidence rules; nothing else is altered.

```
$ xcrun simctl list runtimes
== Runtimes ==
tvOS 26.5 (26.5 - 23L470) - com.apple.CoreSimulator.SimRuntime.tvOS-26-5
(exit 0)
```

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -showdestinations
Command line invocation:
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -showdestinations



	Available destinations for the "Marlin DVR TV" scheme:
		{ platform:tvOS, arch:arm64, id:[REDACTED], name:Home Theater }
		{ platform:tvOS, arch:arm64, id:[REDACTED], name:Master Bedroom ATV }
		{ platform:tvOS, id:dvtdevice-DVTiOSDevicePlaceholder-appletvos:placeholder, name:Any tvOS Device }
		{ platform:tvOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder-appletvsimulator:placeholder, name:Any tvOS Simulator Device }
		{ platform:tvOS Simulator, arch:arm64, id:[REDACTED], OS:26.5, name:Apple TV }
		{ platform:tvOS Simulator, arch:arm64, id:[REDACTED], OS:26.5, name:Apple TV 4K (3rd generation) }
		{ platform:tvOS Simulator, arch:arm64, id:[REDACTED], OS:26.5, name:Apple TV 4K (3rd generation) (at 1080p) }
(exit 0)
```

```
$ xcodebuild -version
Xcode 26.6
Build version 17F113
$ xcrun simctl runtime list
== Disk Images ==
-- tvOS --
tvOS 26.5 (23L470) - [REDACTED] (Ready)

Total Disk Images: 1 (3.5G)
```

Reading: the tvOS 26.5 platform component **is installed now**. In Pass 1 the same commands showed no runtimes and every destination "ineligible: tvOS 26.5 is not installed"; now the runtime is "Ready", three simulators are listed, and both paired Apple TVs appear as available destinations with no error. Nothing was installed by this project's passes; the change happened between Pass 1 and this pass. The `COLD-START.md` "How to build" paragraph that says the scheme/destination build fails is therefore stale; it was left unchanged because step 5 says to change nothing else (Open Question 8). No build was run in this pass.

## 5. Notebook changes (step 5)

`DECISIONS.md`, appended as the last two bullets under `## 2026-09-05`, verbatim from the task:

- Deployment target stays tvOS 18.0. Both Apple TVs run tvOS 26.6 (owner, 2026-09-05).
- Playback: the app plays video via HLS output from the Marlin DVR server (contract: HLS-CLIENT-API.md in marlin-dvr, server 1.1.0). Raised in the marlin-dvr project; built there in Passes 14–19.

`COLD-START.md`:

- "What is built": one sentence added after the existing paragraph saying Pass 2 (server recon, `reports/2026-09-05-pass2-server-recon.md`) and Pass 3 (this recon, `reports/2026-09-05-pass3-hls-client-recon.md`) are done.
- "Open questions": the "None yet." line replaced by pointers to the Pass 2 and Pass 3 reports' Open Questions; the Pass 1 pointer kept.
- "Next step": replaced with "Owner supplies what the app should do; then the first build pass against HLS-CLIENT-API.md."

Nothing else in either file changed (verified with `git diff` before committing; the diffs are in the commit).

## Open Questions

1. **Paused player and the watchdog** (2(b) items 3-4): of the three ways — app-side playlist GET on a timer under 15 s, DELETE-on-pause with a new `start` session on resume (recordings only), or never pausing — which does the owner want? Live has no `start`, so DELETE-on-pause for live means rejoining at the live edge.
2. **First playlist fetch** (2(b) item 2): pre-fetch with `URLSession` (clear timeouts and HTTP statuses) or hand the URL straight to AVPlayer (undocumented wait)? The pre-fetch also starts the 15-s clock before the player's first request.
3. **ATS exception** (2(b) item 10): which key covers a numeric LAN address — a domain exception on the address, `NSAllowsLocalNetworking`, or arbitrary loads — was not settled from the material read here and needs the `NSAppTransportSecurity` documentation plus a device test. Is that test authorised, and should the answer be recorded in DECISIONS.md? (Pass 2 Open Question 4 remains open.)
4. **Client id persistence** (2(b) item 9): `UserDefaults`, Keychain, or iCloud key-value store? (Pass 2 Open Question 6 remains open.)
5. **After ENDLIST, watchdog during playback** (2(b) item 4): the reasoning that the session can end while the player still plays from its buffer is untested. Is a playback test on an Apple TV against the running server an authorised step for a later pass? (Pass 2 Open Question 1 remains open, now about HLS.)
6. **Contract line drift** (§1.1): 16 citations point one to eighteen lines away from the described code at HEAD, and the camera "~3 s" observation is attributed to the wrong section of the Pass 16 report. Should the marlin-dvr project refresh `HLS-CLIENT-API.md`? A decision for that project.
7. **Watchdog-primary attribution** (§1.1): the contract calls it "owner decision, Pass 16"; the reference `DECISIONS.md` records it as a Pass 15 foreman default. Which is the record of truth? A decision for the marlin-dvr project.
8. **COLD-START "How to build"** is stale now that the tvOS platform is installed; step 5 allowed no other change. Update in the next pass?
9. **The reference clone was pulled outside this project's passes** (reflog: fast-forward at 20:01:36 on 2026-09-05). Should DECISIONS.md record who updates the clone and when, so a pass can tell what it is reading?
10. **`start` beyond the recording's end** and **`start` on a recording still being recorded** are not covered by the contract beyond "ends early" (§3). Both are server behaviours to confirm in the marlin-dvr project before the app relies on them.
11. **Which Apple TV** for the first device test, and does the owner want the simulator used first now that it is available?

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `reports/2026-09-05-pass3-hls-client-recon.md` (this file) | deliverable (steps 1–5) |
| `DECISIONS.md` (two bullets appended under 2026-09-05) | 5 |
| `COLD-START.md` ("What is built", "Open questions", "Next step" only) | 5 |
| `~/Xcode/marlin-dvr-reference/.git/` — `git fetch origin` only (no checkout, pull, reset or edit; working tree unchanged, `README-REFERENCE.md` still untracked) | 1 |
| Commit + push of these three files to `origin main` | deliverable |

Nothing else was written. The Xcode project, sources, assets, Info.plist and build settings are untouched (`git diff --stat` against the previous commit shows only the three files above). No other folder under `~/Xcode` was written. No request was sent to the Marlin DVR server, the Unraid host, marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing was installed. Read-only tool output was cached by the session harness under the user's Claude project directory (outside `~/Xcode`).

## Push verification

Pass 3 commit ("Pass 3: HLS client recon; record decisions"): `2d7d1468fac64d0f1d4440b9b432ad261675808f` — three files: this report, `DECISIONS.md`, `COLD-START.md`.

`git status --short` before the commit: ` M COLD-START.md`, ` M DECISIONS.md`, `?? reports/2026-09-05-pass3-hls-client-recon.md`.

```
git push origin main
git fetch origin
local HEAD      : 2d7d1468fac64d0f1d4440b9b432ad261675808f
origin/main     : 2d7d1468fac64d0f1d4440b9b432ad261675808f
ls-remote main  : 2d7d1468fac64d0f1d4440b9b432ad261675808f
MATCH
```

A follow-up commit ("Pass 3: record pushed SHA in report") then wrote the SHA and this block into the report only, and was pushed and verified the same way (fetch, then compare `HEAD`, `origin/main` and `git ls-remote origin main`); its SHA is the current `origin/main` and is stated in the closing summary.
