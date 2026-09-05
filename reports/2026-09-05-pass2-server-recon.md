# Pass 2 — Server recon (read-only) — 2026-09-05

Source-only recon of the Marlin DVR server as cloned at `~/Xcode/marlin-dvr-reference`. No request was sent to the server; the only network traffic was `git fetch origin` in the reference clone and the push of this report. Nothing was installed, run, or edited outside this file.

All `file:line` citations are to `cmd/marlin-dvr/` unless another folder is named (`web/`, `deploy/`, `Dockerfile`).

## 1. Reference clone (step 1)

| Item | Value |
|---|---|
| Path | `~/Xcode/marlin-dvr-reference` |
| Remote | `git@github.com:marlin1111ai/marlin-dvr.git`, branch `main` |
| HEAD before fetch | `d0280f76b1e2c17150b936cd14804963231945ef` |
| `git fetch origin` | ran; no new objects reported |
| `origin/main` after fetch | `d0280f76b1e2c17150b936cd14804963231945ef` |
| `git rev-list --left-right --count HEAD...origin/main` | `0 0` — HEAD is neither behind nor ahead |
| HEAD commit | "Pass 13D report: correct final pushed SHA", 2026-09-05 16:58:45 -0400 |
| Server version constants | `appVersion = "0.7.0"`, `appBuild = "2026.09.05"` (main.go:38-39) |
| Working tree | clean except the untracked, uncommitted `README-REFERENCE.md` from Pass 1 |

No pull was needed. The recon below is of HEAD `d0280f76`.

## How the inventory was made (method)

- Routing is one Go 1.22-style `http.NewServeMux` with method-qualified patterns (main.go:201). Every route is registered with `mux.HandleFunc` in main.go:203-307; no other file registers routes (`grep -c 'HandleFunc(' cmd/marlin-dvr/*.go` gives 89, all in main.go).
- Counted by hand from main.go:203-301: **87 method-qualified routes** plus **2 catch-alls** (main.go:302-304 for `/api/`, main.go:307-313 for `/`) = 89, matching the grep. Per area: status/system 5, settings 2, logs 4, comskip/backups/maintenance 5, sources/lineups/channels 9, guide 6, collections 4, export 4, passes 5, schedule/record 5, artwork 7, clients 7, library 10, playback 6, cameras 6, RSS 2 = 87.
- Every handler body was read (22 Go files, 10,075 lines) to get request and response shapes; the four browser files that call the API (`web/marlin.js`, `web/watch.html`, `web/pages/devices.js`, `web/pages/logs.js`) were read for step 5.
- `GET` patterns also match `HEAD` (Go mux behaviour); no route declares `OPTIONS`.

Common behaviour that applies to every endpoint:

- **No authentication or identification of any kind.** No handler reads an `Authorization`, cookie, or token header; the only `Authorization` header in the code is outbound to TMDB (artwork.go:145). No `Set-Cookie`, no CORS headers, no TLS: the listener is plain `net.Listen("tcp")` + `http.Server` (main.go:362-363, 385). The only per-caller identity is the client id a caller chooses to send (§4).
- JSON responses go through `writeJSON`: `Content-Type: application/json`, `Cache-Control: no-store` (main.go:105-111). Errors are **plain-text bodies** via `http.Error` (e.g. main.go:303, stream.go:170), not JSON.
- One request-log line per request, mirrored into the Logs page buffer under the `HTTP` tag (main.go:143-161).
- Port: the app listens on **8089 inside the container** (main.go:47-48; `Dockerfile` `EXPOSE 8089`); the Unraid template maps **host 8090 → container 8089** (deploy/marlin-dvr.xml:17, deploy/UNRAID-STEPS.md:76). Every URL the API returns is a server-relative path (§5), so a client resolves them against whatever base it connected to.

## 2. Endpoint inventory (step 2)

Notation: `{…}` JSON object; `[…]` array; `?` optional; unix times are seconds.

### 2.1 Status / system

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/status` | — | `{name, version, uptime_seconds, port}` | main.go:98-103, 185-187 |
| `GET /api/system` | — | `SystemInfo`: `version, build, hostname, uptimeSeconds, uptime, startedAt, timezone, localTime, board, distro, kernel, cpu, loadAverages, ramPercent, ramLabel, netInterfaces, netAddress, diskUsedPercent, diskLabel, diskFree, diskTotal, diskUsed, diskPath, diskVolume, activityLine, activeStreams, goVersion, port` (all labels pre-formatted strings except the ints) | system.go:16-46, 191-248, 257-260 |
| `GET /api/chrome` | — | `{online: true, activityTitle, activeStreams, userName: "owner", version}` | system.go:263-270 |
| `GET /api/dashboard` | — | `{stats: [{label, value, sub}] ×8, recent: [{title, channel, status, reason?, showId}]}` (last 6 recorder outcomes) | dashboard.go:18-52 |
| `GET /api/health` | — | `{passing, total, ok, warn, fail, lastRun, activeStreams, diskFree, uptime, groups: [{label, items: [{label, detail, status: ok|warn|fail}]}]}`. Side effects: writes, reads back and removes a probe file under every storage root (health.go:67 → recorder.go:734-765); runs `ffmpeg -version`, `comskip --help`; reads HDHomeRun `/status.json` (sources.go:496-516) | health.go:38-237 |

### 2.2 Settings

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/settings` | — | the `Settings` struct (`networkDiscovery, serverEnabled, homePage, quickActions[], remoteMode, tailscale, deepVideo, scanFrequency, storagePaths[], padBefore, padAfter, keep, unwatched, last, trashAfter, detectCommercials, liveBuffer, backupFolder`) plus `tmdbTokenSet: bool`; `backupFolder` is the effective value | settings.go:14-36, 87-99 |
| `PUT /api/settings` | the whole `Settings` object (unknown fields ignored; missing fields keep the old value because the request is pre-filled from the current settings) plus `tmdbToken?: string`, `clearTmdbToken?: bool`; body ≤ 1 MiB | same as GET. Changing `storagePaths` triggers a library rescan | settings.go:102-144 |

Note (fact): several stored settings are inert on the server side — `remoteMode, tailscale, deepVideo, liveBuffer, networkDiscovery` are round-tripped only (settings.go:9-13).

### 2.3 Logs

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/logs?since=<seq>&limit=<n>` | query; `limit` defaults to 2000 | `{lines: [{seq, time, level: INFO|WARN|ERR, tag, msg}], total}` | logs.go:17-23, 109-117 |
| `GET /api/logs/stream` | — | `text/event-stream`; `: connected` then one `data: <LogEntry JSON>` per event; `: keepalive` every 15 s; ends when the client disconnects | logs.go:120-148 |
| `POST /api/logs/clear` | — | `{ok: true}` (clears the in-memory view only) | logs.go:151-154 |
| `GET /api/logs/download` | — | `text/plain` attachment `marlin-dvr.log` | logs.go:157-175 |

### 2.4 Commercial detection, backups, maintenance

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/comskip` | — | `{installed, path?, version?, status: idle|running, current?, queued, lastError?, lastRun?, enabled}` | comskip.go:395-417, 442-444 |
| `GET /api/backups` | — | `{folder, ok, error?, keep, nightly, backups: [{name, label, size, sizeLabel, at, href}], last?, lastLine, running, lastError?}` | backup.go:140-147, 357-400, 418-420 |
| `POST /api/backups` | — | `{ok, backup: <backupFile>, state: <backupStatus>}`; runs the backup synchronously; 500 if one is already running | backup.go:293-337, 423-430 |
| `GET /api/backups/{name}` | name must match `marlin-dvr-YYYY-MM-DD-HHMM.tar.gz` | `application/gzip` attachment with `Content-Length` (the only route that sets one) | backup.go:55, 433-456 |
| `POST /api/library/recreate` | — | `{ok, backup, recordings, shows}`. Destructive: takes a backup, then drops the library index and ffprobe cache and rescans | backup.go:460-485 |

### 2.5 Sources, lineups, channels

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/sources` | — | `[Source]` public copies: `id, type: hdhomerun|m3u, name, enabled, createdAt, hdhomerun?: {ip, deviceId, model, firmware, baseUrl, tunerCount, deviceAuth: "" , xmltv: ""|"(set)", xmltvRefresh}, m3u?: {kind, url: "", filePath: "", text: "", format, refreshDaily, ignoreChannelNumbers, startNumber, preferM3ULogos, streamLimit, xmltv, xmltvRefresh}, lastLoaded, lastGuide, lastError, channelCount, address, detail, code`. Secrets are blanked before sending | sources.go:23-72, 201-245, 714-716 |
| `POST /api/sources` | `{type: hdhomerun, ip?}` (blank ip = the default tuner address hard-coded at sources.go:735-737) or `{type: m3u, name, m3u: M3UConfig}`; ≤ 16 MiB | the public `Source`; 502 on discovery/playlist failure | sources.go:718-778 |
| `PUT /api/sources/{id}` | `{name?, enabled?, m3u?: M3UConfig, ip?, xmltv?, xmltvRefresh?}` (blank secrets mean "keep") | public `Source`; may reload the lineup and refetch XMLTV | sources.go:780-879 |
| `DELETE /api/sources/{id}` | — | `{ok}`; also deletes the lineup and guide files | sources.go:882-899 |
| `POST /api/sources/{id}/reload` | — | public `Source` | sources.go:902-910 |
| `POST /api/sources/{id}/xmltv` | — | public `Source` after re-downloading XMLTV | sources.go:913-921 |
| `GET /api/sources/{id}/lineup` | — | `{sourceId, count, channels: [{guid, number, name, mappedNumber, mappedName, hidden, favorite, hd, drm, logo}]}` | sources.go:924-957 |
| `PUT /api/sources/{id}/lineup/{guid}` | `{number?, name?, hidden?, favorite?}` | the stored `Override {number?, name?, hidden, favorite}` | sources.go:960-1004 |
| `GET /api/channels?source=&filter=&hidden=1` | `source` = source id or name or "All Sources"; `filter` = `Favorites` \| `All Channels` \| `HD` \| `Non-HD` \| a collection id or name; `hidden=1` returns every channel of enabled sources including hidden ones and ignores the filters | `{channels: [MergedChannel], count, sources: [enabled source names]}` | sources.go:357-406, 1007-1022 |

`MergedChannel` (sources.go:103-122): `id` (= `sourceID:guid`), `sourceId, source, guid, number, name, origNumber, origName, logo (absolute upstream URL or ""), hd, drm, hidden, favorite, initials, logoBg (CSS hex), tvgId?`. The channel's stream URL is `json:"-"` and never sent (sources.go:112) — except through the M3U export (§2.8).

### 2.6 Guide

`Program` (guide.go:18-38): `channel` (guid within the source), `start`, `end` (unix), `title, episodeTitle?, desc?, season?, episode?, episodeNum?, categories?[], icon? (absolute URL), new?, live?, premiere?, finale?, seriesId?, rating?, originalAirDate?, video?`.

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/guide?start=<unix>&slots=<n>&source=&filter=` | `start` truncated to a 30-minute boundary (default: now); `slots` 1–48, default 13 | `{start, slots, timeSlots: [{label, start}], channels: [{…MergedChannel, blocks: [{title, subtitle, span, isLive, program?: Program, channelId, empty?}]}], nowIndex (float, -1 if now is outside the window), dayLabel, channelCount}`. Blocks are pre-laid-out 30-minute spans for the web grid; gaps are `"No listing"` blocks | guide.go:550-664 |
| `GET /api/guide/now?source=&filter=` | filters as `/api/channels` | `{programs: [{…MergedChannel, program: Program, title, endsIn ("ends 3:04 PM"), art}], count, at}` | guide.go:667-691 |
| `GET /api/guide/later` | — | `{sections: [{label: "On Today"|"On This Week", items: [{title, subtitle, channel ("2.1 · WMAR"), channelId, start, when, scheduled, program, art}]}]}`; ≤ 24 per section; only new/premiere/live/finale/movie airings, one per series | guide.go:695-754 |
| `GET /api/guide/search?title=` | exact, case-insensitive title match; future airings only | `{matches: [{…Program, channelId, channelLabel, initials, logoBg, when, duration, scheduled, drm, art}], count}` | guide.go:757-785 |
| `GET /api/guide/stats` | — | `{lineups, channels, channelsWithGuide, shows, listings, bytesOnDisk, sizeLabel, refreshedAt, refreshedLine, status, coverageUntil}` | guide.go:479-532, 799-801 |
| `POST /api/guide/{action}` | `action` ∈ `refresh` \| `redownload` \| `logos` \| `recreate` | `{ok, errors: [], stats}`; `redownload`/`recreate` delete the stored guide files first; all four then refetch the HDHomeRun cloud guide and/or XMLTV for every enabled source | guide.go:804-827, 448-475 |

### 2.7 Collections

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/collections` | — | `{collections: [{id, name, icon, channelIds[], channels: [{id, isLive, isDead, name?, number?, initials?, logoBg?, source?}], count}]}` | collections.go:12-17, 63-99 |
| `POST /api/collections` | `{name?, icon?, channelIds?}` | one resolved collection | collections.go:102-127 |
| `PUT /api/collections/{id}` | `{name?, icon?, channelIds?}` | one resolved collection | collections.go:130-174 |
| `DELETE /api/collections/{id}` | — | `{ok}` | collections.go:177-199 |

### 2.8 Export (for other apps)

| Route | Response | Cite |
|---|---|---|
| `GET /export/channels.m3u` | `audio/x-mpegurl`; one `#EXTINF` per visible channel with `tvg-id=<channel id> tvg-chno tvg-name tvg-logo group-title=<source name>`, followed by the **raw upstream stream URL** (tuner or M3U). This is the only route that exposes stream URLs | export.go:17-43 |
| `GET /export/guide.xml` | `application/xml` XMLTV of every visible channel's programs | export.go:79-121 |
| `GET /export/{source}/channels.m3u`, `GET /export/{source}/guide.xml` | same, one source; 404 for an unknown source | export.go:28-33, 80-86 |

### 2.9 Passes

`Pass` (passes.go:20-37): `id, title, seriesId, recordMode: new|all, channel ("" = any), padBefore, padAfter (minutes), keepMode: all|unwatched|last, keepUnwatched, keepLast, limit, rerecord, conditions[], paused, priority, createdAt`. `passView` adds `jobCount, countLabel, pauseLabel, padBeforeLabel, padAfterLabel, keepLabel, art, seriesCondition, showId` (passes.go:535-572).

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/passes?sort=name|jobs|date|priority&q=` | — | `{passes: [passView], count, jobs}` | passes.go:575-596 |
| `POST /api/passes` | `passReq` (passes.go:598-618): `title` (required), `seriesId?, recordMode?, channel?, padBefore?, padAfter?, padBeforeLabel?, padAfterLabel?, keepMode?, keepUnwatched?, keepLast?, keepLabel?, limit?, rerecord?, conditions?, paused?, priority?`; ≤ 1 MiB | `passView`; 409 if a pass already exists for the same series and channel | passes.go:705-737 |
| `PUT /api/passes/{id}` | `passReq` plus `move?: up|down` | `passView` | passes.go:740-796 |
| `DELETE /api/passes/{id}` | — | `{ok}` | passes.go:799-824 |
| `GET /api/passes/{id}/matches` | — | `{matches: [Job], count}` | passes.go:827-835 |

### 2.10 Schedule, jobs, Record Now

`Job` (passes.go:53-77): `id, passId ("manual" for Record Now), passTitle, channelId, number, channelName, initials, logoBg, program: Program, start, end (padded, unix), status: Queued|Skipped|Conflict|Recording|COMPLETED|FAILED|STOPPED, reason?, episodeLine, badge, time, duration, dateLabel, timeRange, art, drm, sourceId`. Jobs are recomputed from passes × guide on every request (passes.go:331-493).

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/schedule?q=` | free-text filter | `{groups: [{label: Today|Tomorrow|<weekday>|<date>, items: [Job]}], count, passes}` | passes.go:838-879 |
| `GET /api/schedule/calendar?offset=<weeks>` | — | `{weekRange, days: [{label, isToday, date, items: [Job]}] ×7 (Sunday first), offset}` | passes.go:882-919 |
| `PUT /api/schedule/jobs/{id}` | `{skipped: bool}` | `{ok, skipped, removed}` (a skipped Record Now job is removed outright) | passes.go:927-967 |
| `POST /api/schedule/jobs/{id}/stop` | — | the persisted `RecordingState` (recorder.go:45-66); 409 if that job is not recording | recorder.go:686-693 |
| `POST /api/record` | `{channelId, start?: unix (0 = the program on now), padAfterLabel?}` | the resulting `Job`, or `{id, status: "Queued"}`; 404 no listing, 400 already ended, 409 already set | recorder.go:774-848 |

### 2.11 Artwork

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/art/show?title=&size=large` | — | image bytes, `Content-Type` sniffed, `Cache-Control: private, max-age=3600`, served via `http.ServeContent` (Range-capable); 404 when there is no art. May perform one TMDB lookup when a token is set | artwork.go:458-471, 500-530 |
| `PUT /api/art/show?title=` | `{url}` or `{tmdbPath}` | `{ok, art}` | artwork.go:598-658 |
| `DELETE /api/art/show?title=` | — | `{ok}` | artwork.go:661-675 |
| `GET /api/art/info?title=` | — | `{title, found, tokenSet, art, name?, overview?, genres[], firstAir?, tmdbId?}` | artwork.go:533-549 |
| `GET /api/art/search?title=` | — | `{options: [{tmdbId, name, year, poster, url}], error?}`; 502 on TMDB failure | artwork.go:552-579 |
| `GET /api/art/tmdb?path=` | a TMDB image path | image | artwork.go:582-594 |
| `GET /api/art/feed?u=<http(s) image URL>&title=` | — | the feed image, cached server-side (`max-age=86400`); falls back to the title's poster; 404 otherwise | artwork.go:476-497 |

Art URLs the API hands out: `/api/art/show?title=<escaped title>` (artwork.go:362-367, 400-403) and `/api/art/feed?u=…&title=…` (artwork.go:380-382). Poster lookups per response are budgeted (6–8 new TMDB lookups; the rest happen in the background and appear on the next request) (artwork.go:369-376, guide.go:679, 713).

### 2.12 Clients (details in §4)

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/clients` | — | `{clients: [clientView], count, online, summary}` | clients.go:179-222 |
| `POST /api/clients/register` | `{id?, name?, app?, type?, os?, userAgent?}` (`id` is decoded but ignored) | `clientView` | clients.go:224-259 |
| `POST /api/clients/{id}/ping` | `{app?, os?, type?}` optional | `clientView`; 404 `unknown client; register again` | clients.go:262-285 |
| `PUT /api/clients/{id}` | `{name}` | `clientView` | clients.go:301-321 |
| `DELETE /api/clients/{id}` | — | `{ok}` | clients.go:324-346 |
| `GET /api/clients/{id}/ui` | — | `{sidebar: [{id, label, icon, hidden, locked?}], collections: [{id, label, icon, count, hidden}]}` | clients.go:350-408 |
| `PUT /api/clients/{id}/ui` | `{reset: true}` or `{sidebar: [{id, hidden}], collections: [{id, hidden}]}`; ≤ 256 KiB | same as GET | clients.go:412-452 |

### 2.13 Library (recordings)

`Recording` (library.go:35-49): `id` (sha1 of the absolute path, 12 hex; library.go:126-129), `path` (blanked in responses, library.go:581), `file` (root-relative), `root, show, showId, episodeTitle, season, episode, aired, size, modTime, ext`. `RecState` (library.go:68-79): `watched, favorite, keep, trash, watchedAt?, trashedAt?, changedAt?, firstSeen?, meta?: EpisodeMeta, detect?: DetectState`. `EpisodeMeta` (library.go:52-65): `title, airDate, rating, season, episode, summary, fullSummary, categories[], genres[], labels[], channel, thumb?`.

`episodeView` = Recording + RecState + `dateLabel, airedLabel, description, tags[] (HD/4K/codec/5.1/Stereo/Mono/CC/rating), channel, channelAbbr, sizeLabel, thumb ("/api/library/recordings/<id>/thumb.jpg?v=…"), playUrl ("/watch.html?rec=<id>"), fileLabel, exists` (library.go:486-500, 516-583).

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/library?limit=` | `limit` per section, default 6 | `{sections: [{key: recently-watched|recently-updated|recently-added, label, items: [showSummary], total}], shows, recordings, roots: [{path, exists, readable, files, error?}], scannedAt, scanning, configured}`; `showSummary` = `{id, title, count, unwatched, art, lastAdded, lastUpdated, lastWatched}` | library.go:369-378, 428-469 |
| `POST /api/library/scan` | — | same as GET after a synchronous rescan | library.go:472-475 |
| `GET /api/library/shows/{id}?trash=1` | `trash=1` lists the trashed episodes instead | `{id, title, episodes: [episodeView] (newest first), count, trashCount, showingTrash, art, info: {found, genres[], overview, name?}, pass, rss}` | library.go:586-640 |
| `PUT /api/library/recordings/{id}` | `{watched?, favorite?, keep?, trash?}` | `episodeView`, or `{ok, deleted: true}` when Trash is "Immediately" | library.go:643-694 |
| `PUT /api/library/recordings/{id}/metadata` | `EpisodeMeta` (whole object; ≤ 256 KiB) | `episodeView` | library.go:697-718 |
| `GET /api/library/recordings/{id}/mediainfo` | — | `{file, fileId, filesize, pass, channel, channelAbbr, streamingIndex: "not built (progressive playback)", duration, durationSeconds?, bitrate, tracks: [{index, type, codec, codecLong, detail, title, language?}], format?, error?}`; runs `ffprobe` once and caches under data/ | library.go:722-748, 795-883, 886-916 |
| `GET /api/library/recordings/{id}/segments` | — | `{status, line, segments: [{n, start, end, duration}] (mm:ss strings), count, edl?}` from the comskip `.edl` beside the file | comskip.go:449-499 |
| `GET /api/library/recordings/{id}/thumb.jpg?at=<seconds>` | — | `image/jpeg` via `http.ServeFile` (Range-capable), `Cache-Control: private, max-age=3600`; generated **synchronously** with ffmpeg on first request; 404 if the file is unavailable or ffmpeg fails | library.go:949-983 |
| `POST /api/library/recordings/{id}/thumb` | `{at?: seconds}` or `{url}` | `{ok}` | library.go:986-1032 |
| `POST /api/library/trash/empty` | — | `{deleted, freed, failed, errors[]}`; deletes files on disk | trash.go:218-222, 194-215 |

### 2.14 Playback (details in §3)

| Route | Request | Response | Cite |
|---|---|---|---|
| `POST /api/play/sessions` | `{kind: live|recording|camera, id, client?, start?: seconds}`; ≤ 64 KiB | `{id, url: "/api/play/s/<id>.mp4", title, sub, kind, mode: copy|transcode, duration (recordings only, else 0), start}`; 404 unknown target / file missing, 403 DRM channel, 400 bad kind or no stream URL, 502 ffprobe failure | stream.go:161-269 |
| `GET /api/play/sessions` | — | `{sessions: [Session], active}`; `Session` public fields: `id, kind, targetId, title, sub, clientId, clientName, createdAt, startedAt, bytes, active, mode, start, duration, sourceId?, logFile` | stream.go:32-48, 385-388 |
| `DELETE /api/play/sessions/{id}` | — | `{ok, wasRunning}`; kills ffmpeg if running, else forgets the session | stream.go:391-403 |
| `GET /api/play/sessions/{id}/log` | — | `text/plain` — the session's ffmpeg stderr | stream.go:406-420 |
| `GET /api/play/s/{id}` (the `.mp4` suffix is stripped) | — | `200`, `video/mp4`, chunked fragmented MP4 (see §3); 404 no such session; **409 if the session was already started once** | stream.go:284-359 |
| `GET /api/play/info?live=<channel id>` \| `?rec=<recording id>` \| `?cam=<camera id>` | — | live: `{kind, id, title, sub, drm, art}`; recording: `{kind, id, title, sub, duration, showId, watched, art}`; camera: `{kind, id, title, sub, art: ""}` | stream.go:423-459 |

### 2.15 Cameras

`Camera` public fields (cameras.go:23-39, 163-177): `id, name, address, streamPath, username, password: "" , hidden, createdAt, hasCredentials, online, lastCheck, lastError, codec`.

| Route | Request | Response | Cite |
|---|---|---|---|
| `GET /api/cameras` | — | `{cameras: [Camera], count, online}` | cameras.go:280-289 |
| `POST /api/cameras` | `{address (required), username?, password?, name?, streamPath?}` | `Camera`; starts a background snapshot probe | cameras.go:301-334 |
| `PUT /api/cameras/{id}` | `{name?, address?, streamPath?, username?, password?, hidden?}` | `Camera` | cameras.go:345-389 |
| `DELETE /api/cameras/{id}` | — | `{ok}` | cameras.go:392-417 |
| `GET /api/cameras/{id}/snapshot.jpg?refresh=1` | — | `image/jpeg`, `Cache-Control: no-store`; one frame pulled over RTSP by ffmpeg, cached 45 s (3 s when forced); 404 with the probe error as text when offline | cameras.go:193-277, 420-434 |
| `POST /api/cameras/{id}/check` | — | `Camera` after a forced probe | cameras.go:437-445 |

### 2.16 RSS

| Route | Response | Cite |
|---|---|---|
| `GET /rss/recordings.xml?section=recently-added|recently-updated|recently-watched` | RSS 2.0, ≤ 50 items, absolute links built from `"http://" + r.Host`. Each item's enclosure URL is `/api/play/recording/<id>.mp4`, **a path no route serves** (compare main.go:286-291) | rss.go:58-60, 62-97, 100-136 |
| `GET /rss/shows/{id}.xml` | same for one show; 404 unknown show | rss.go:139-156 |

### 2.17 Catch-alls

| Route | Behaviour | Cite |
|---|---|---|
| any other `/api/…` | 404, text `no such API route` | main.go:302-304 |
| `/` | 302 to the "Home Page" setting's page (`/Marlin Dashboard.dc.html`, `/Marlin Guide.dc.html` or `/Marlin Recordings.dc.html`) | main.go:190-198, 307-311 |
| anything else | static file from `web/` (GET/HEAD only; directories 404; `.html/.js/.css` get `Cache-Control: no-cache`) | main.go:164-183, 312 |

## 3. Playback in detail (step 3)

### 3.1 The session model

Playback is two requests: `POST /api/play/sessions` creates a session and returns a relative URL; `GET /api/play/s/{id}.mp4` starts ffmpeg and streams its stdout for as long as the connection lasts (stream.go:28-30, 161-269, 284-359). A session can be started **once**: a second GET on the same id is refused with 409 `session already streaming` (stream.go:291-296), and after ffmpeg exits the session stays inactive (stream.go:354-357). Every play, restart or seek is therefore a new POST + GET.

Session housekeeping happens only when another session is added: sessions created but never started are dropped after 2 minutes, finished ones after 10 minutes, and their log files removed (stream.go:104-118). Stale logs are deleted at server start (stream.go:65-75).

The `client` field is stored as `clientId`; if it matches a registered client its name is used, otherwise the session is labelled `a browser at <remote IP>` (stream.go:166, 173-178). No check that the client exists is enforced.

### 3.2 What ffmpeg is asked to produce

Common prefix: `-hide_banner -loglevel warning -nostdin -nostats` (stream.go:179). Common output (stream.go:159):

```
-f mp4 -movflags frag_keyframe+empty_moov+default_base_moof+omit_tfhd_offset -frag_duration 1000000 pipe:1
```

That is a **fragmented MP4 written to a pipe**: an initial `ftyp`+`moov` with no sample tables (`empty_moov`), then `moof`+`mdat` pairs about every second, cut at keyframes. No index, no `mfra`, no file length.

| Kind | Input handling | Video/audio | Cite |
|---|---|---|---|
| `live` | `-fflags +genpts+discardcorrupt -i <channel URL from the lineup> -map 0:v:0 -map 0:a:0?`; DRM channels refused (403); `start` is ignored (no `-ss`) | **always transcoded** (`mode: "transcode"`): libx264 `-preset veryfast -crf 23 -maxrate 6M -bufsize 12M -pix_fmt yuv420p -profile:v high -level 4.1`, `yadif` only on interlaced frames, scaled to ≤ 720p, AAC 160 kb/s stereo, plus `-tune zerolatency -g 60 -sc_threshold 0` | stream.go:146-157, 181-203 |
| `recording` | 404 if the file is missing ("is the share mounted?"); `ffprobe` first (cached; 502 on failure); `-ss <start>` **before** `-i` when `start > 0`; `-map 0:v:0 -map 0:a:0?` | **copy** (`-c copy -bsf:a aac_adtstoasc`) only when the probe says H.264 video and AAC/MP3/no audio; otherwise the same software transcode without the live flags. `duration` from ffprobe is returned | stream.go:204-235 |
| `camera` | RTSP URL with credentials assembled server-side; `-rtsp_transport tcp`; `-fflags +genpts` | video copied when the last probe saw H.264, audio always re-encoded to AAC 96 kb/s stereo; otherwise transcode with the live flags | stream.go:236-260, cameras.go:115-152 |

What the recorder writes matters for the recording path: files are captured **byte for byte** from the tuner as MPEG-TS `.mpg` (recorder.go:23-27, 200, 494-582), or remuxed with `-c copy -f mpegts` when the source is an HLS playlist (recorder.go:584-628). So an over-the-air recording from the HDHomeRun keeps its broadcast codecs (MPEG-2 video for ATSC 1.0; AC-3 audio), which do not meet the copy condition, so those recordings always take the software-transcode path. Only imported files that already are H.264 + AAC/MP3 are copied.

### 3.3 What comes back on the wire

After `cmd.Start()` succeeds the handler writes (stream.go:323-327):

```
HTTP/1.1 200 OK
Content-Type: video/mp4
Cache-Control: no-store
X-Marlin-Session: <session id>
Accept-Ranges: none
```

No `Content-Length` is set, so Go sends the body with chunked transfer encoding; each 64 KiB read from ffmpeg is written and flushed immediately (stream.go:328-347). The byte count is kept on the session (stream.go:340-342). The response headers are sent **before** ffmpeg has produced anything, so an input failure (tuner busy, bad file, camera offline) still yields a `200` whose body simply ends; the reason exists only in the session log (`GET /api/play/sessions/{id}/log`) and the server log (stream.go:301-305, 348-358).

### 3.4 How the server knows the client stopped

- ffmpeg runs under a context derived from the request context (stream.go:297-298). When the client closes the connection, the next `w.Write` fails, the loop breaks, `cancel()` is called, ffmpeg gets `SIGTERM` (`cmd.Cancel`, stream.go:299) and is waited for with a 3-second grace (`WaitDelay`, stream.go:300, 348-349).
- `DELETE /api/play/sessions/{id}` cancels the same context from another request (stream.go:126-136, 391-403). The browser calls it on Stop and on page unload with `keepalive` (web/watch.html:73-78, 132-133).
- Tuner release is indirect: killing ffmpeg closes its HTTP connection to the HDHomeRun, and the tuner frees itself when that connection drops (stream.go:22-27, 358). There is no explicit tuner-release call.
- On `SIGINT`/`SIGTERM` the server closes the listener, which ends every stream (main.go:385-399).

### 3.5 Seeking and live buffering

- There is no seeking inside a stream: `Accept-Ranges: none` (stream.go:326), no `Range` header is parsed anywhere in `cmd/marlin-dvr` (the only `Content-Length` in the code is the backup download, backup.go:453), and the source is a pipe. The browser page seeks a recording by tearing the session down and creating a new one with `start` = target seconds (web/watch.html:80-91, 122-123); the server applies it as `-ss` before the input (stream.go:224-226).
- Live channels have no time-shift or pause buffer: `start` is not applied to live (stream.go:181-203) and the `liveBuffer` setting is stored but inert (settings.go:9-13, 34).
- `duration` is known only for recordings (from ffprobe); the page computes position as `start + video.currentTime` (web/watch.html:93-100).

### 3.6 Is there HLS or any other Apple-friendly output anywhere?

No. Evidence from the whole `cmd/marlin-dvr` tree:

- The only ffmpeg output formats are `-f mp4` for playback (stream.go:159) and `-f mpegts` for the recorder's HLS-input remux (recorder.go:587). There is no `-f hls`, no `-hls_*` option, no `.m3u8` writer, no segmenter.
- "HLS" occurs only as the *input* format label of an M3U source (sources.go:63, 752) and in the recorder's handling of an HLS *input* playlist (recorder.go:25-26, 490-492, 523-527, 584-628).
- The export playlist (`/export/channels.m3u`, export.go:27-43) is a channel list whose entries are the raw upstream URLs (an HDHomeRun tuner URL yields MPEG-TS; an M3U source yields whatever that provider serves). It is not a media playlist and involves no server-side transcoding.
- Recording files are never served directly: no route maps to a file under a storage root, and `path` is blanked before any recording leaves the API (library.go:581).
- Thumbnails (library.go:982), posters and feed images (artwork.go:458-471) are ordinary JPEG/PNG responses through `http.ServeFile`/`ServeContent`, which support Range requests.

### 3.7 What AVFoundation on tvOS can and cannot play, with reasons

Stated plainly, from the source and from the documented behaviour of AVFoundation. No playback was attempted: this recon sent no requests, and this Mac has no tvOS runtime (Pass 1 report, Open Question 1).

- **Codecs are fine.** Every stream the server produces is either H.264 High 4.1 ≤ 720p + AAC-LC stereo (transcode) or H.264 + AAC/MP3 (copy). Apple TV hardware decodes all of these. The one exception is a copied recording with no audio track (`-map 0:a:0?`), which is still playable.
- **The container and transport are the problem.** The stream is an unbounded, chunked, length-less fragmented MP4 with `empty_moov` and `Accept-Ranges: none` (stream.go:159, 323-327). `AVPlayer`/`AVURLAsset` given a plain `http://…/api/play/s/<id>.mp4` URL uses the progressive-download path, which needs a complete `moov` with sample tables and byte-range access over a known length to index the file. Fragmented MP4 is supported by AVFoundation **only as HLS segments** (an `.m3u8` referencing fMP4 parts). So the URL returned by `POST /api/play/sessions` is not one `AVPlayer(url:)` can be expected to play, for recordings, live channels or cameras alike. This is the central finding of this recon.
- **Consequences that follow from the source:** nothing on the server produces HLS (§3.6); there is no byte-range access to any media (§3.5); recordings cannot be fetched as files, and even if they could, the over-the-air ones are MPEG-2/AC-3 MPEG-TS, which AVFoundation on tvOS does not decode as a plain file; cameras' RTSP URLs and credentials never leave the server (cameras.go:18-19, 163-166), so a native RTSP path does not exist either.
- **What would play today without a server change:** nothing that is video. Images (thumbnails, posters, camera snapshots) are plain HTTP image files and load normally.
- **Transport security:** the server is plain HTTP with no TLS (main.go:362-363, 385). A tvOS app must carry an App Transport Security exception for this host to talk to it at all. That is an app-side Info.plist matter for a later pass, recorded here as a fact.

The client-side techniques that exist on tvOS for consuming a raw fMP4 pipe (demuxing it in the app and feeding `AVSampleBufferDisplayLayer` + `AVSampleBufferAudioRenderer`, or an `AVAssetResourceLoaderDelegate` shim) are not built anywhere and are not proposed here; whether the server should instead produce HLS is a decision for the marlin-dvr project (DECISIONS.md).

## 4. Client registration (step 4)

**`POST /api/clients/register`** (clients.go:224-259)

- Body (≤ 64 KiB, JSON, all optional): `{id, name, app, type, os, userAgent}`. `id` is decoded into the request struct but never read: the server always assigns a fresh id `c<base36 ms><3 random bytes hex>` (clients.go:244, store.go:17-21). A client cannot re-register under an old id.
- Fallbacks when fields are blank: `app` → `"Marlin Web v0.7.0"`, `type` → `"<browser> on <os>"`, `os` → the parsed OS, `name` → `"<browser> on <os>"`, and `"Browser on unknown OS"` becomes `"Web browser"` (clients.go:243-251). The browser/OS names come from parsing `userAgent` (or the request's `User-Agent` header) for Edge/Opera/Chrome/Chromium/Firefox/Safari and iOS/iPadOS/macOS/Windows/Android/ChromeOS/Linux (clients.go:123-160); a tvOS user agent matches none of them.
- `ip` is the TCP remote address of the request (clients.go:107-113); `createdAt` and `lastSeen` are set to now.
- Response: `clientView` = `{id, name, app, type, os, ip, createdAt, lastSeen, online, location: Local|Remote, locIcon, lastSeenLabel, watching, watchingIcon}` (clients.go:179-203; `ui` is stripped, 201). `online` is true when `lastSeen` is within 5 minutes or the client has an active stream session (clients.go:190-200). `location` is `Local` for loopback/private/link-local IPs (clients.go:115-121).
- Persisted to `data/clients.json` immediately (clients.go:252-256).

**Keeping the registration alive** — `POST /api/clients/{id}/ping` (clients.go:262-285): updates `lastSeen` and `ip`, optionally overwrites `app`, `os`, `type` from the body, returns `clientView`. 404 with text `unknown client; register again` when the id is not known (deleted from the Clients page, or the server's data was recreated). Pings write the clients file at most every 30 s (clients.go:287-298). The browser pings on every page load and re-registers on 404 (web/marlin.js:167-174).

**Per-client Customize** — `GET`/`PUT /api/clients/{id}/ui` (clients.go:29-60, 348-452):

- Stored shape `ClientUI {sidebar: [UIItem{id, label, icon, hidden, locked?}], collections: [{id, hidden}]}` on the client record, `ui: null` = defaults.
- Sidebar item ids are fixed by the server: `home, onnow, guide, onlater, recordings, cameras (hidden by default), weather, search, clients, settings (locked)` with Phosphor icon class names (`ph-house`, …) (clients.go:47-60). `PUT` keeps only ids the server knows, honours order, ignores `hidden` on locked items, and stores the collections list as sent; `{reset: true}` clears to defaults (clients.go:427-449). `GET` merges in any default items missing from a saved layout and returns the real collections with their channel counts in the client's order (clients.go:355-398).
- `weather` and `search` are sidebar entries only; no server endpoint backs them.

**How the server identifies the client later:** only by the id the client sends — in the path of `/api/clients/{id}/…` and in the `client` field of `POST /api/play/sessions` (stream.go:166, 173-178). No header, cookie or token carries it; every other endpoint is anonymous and unauthenticated. A client id is therefore a self-asserted label used for the Clients page, the "Watching …" line and the Customize layout, nothing more.

## 5. Behaviours that assume a browser (step 5)

Each of these is something a native client must do itself or must translate.

1. **Self-registration and id storage in the page.** Registration is triggered by the shared page script on every page load, and the id lives in `localStorage["marlinClientId"]`; the browser re-registers when a ping returns 404 (web/marlin.js:160-174). The server has no "who is this" mechanism of its own (§4). A native app must persist its id and repeat the register/ping dance, and must send `name/app/type/os` explicitly or it will be recorded as `Web browser` (clients.go:243-251).
2. **Session labelling falls back to "a browser at <ip>"** when the `client` field is missing or unknown (stream.go:177).
3. **All URLs in responses are server-relative paths**: session `url` `/api/play/s/<id>.mp4` (stream.go:268); episode `thumb` and `playUrl` (`/watch.html?rec=<id>`, a web page) (library.go:576-577); show `rss` (library.go:640); art `/api/art/show?title=…` and `/api/art/feed?u=…` (artwork.go:366, 382, 403); backup `href` (backup.go:173). The only absolute URLs are in the RSS feeds, built as `"http://" + r.Host` (rss.go:58-60), and channel `logo` / program `icon` fields, which are the upstream provider's absolute URLs (guide.go:377, 410; sources.go:558). A native client must resolve relative paths against its own base URL and fetch external logos itself.
4. **Server-Sent Events for live logs** (`GET /api/logs/stream`, logs.go:120-148), consumed with `EventSource` (web/pages/logs.js:6-16). There is no other push channel; every other page polls (e.g. the Clients page every 30 s, web/pages/devices.js:3).
5. **The player is a web page.** `web/watch.html` sets `<video src>` to the session URL and relies on the browser's built-in progressive fMP4 playback (web/watch.html:43, 88-89); seeks are done by restarting the session with a `start` offset (web/watch.html:122-123); "watched" is set by the page on the `ended` event and by a button (web/watch.html:124, 131); the session is stopped on `pagehide`/`beforeunload` with a keepalive `DELETE` (web/watch.html:132-133). None of this exists server-side; the server's `playUrl` points at this page (library.go:577).
6. **Presentation is pre-rendered for the web pages in the server's local time zone.** Guide rows come as 30-minute grid `blocks` with `span` counts (guide.go:550-664); labels such as `endsIn`, `when`, `time`, `timeRange`, `dateLabel`, `dayLabel`, `refreshedLine`, `lastSeenLabel`, `sizeLabel`, `lastLine` are formatted strings (guide.go:685, 731; passes.go:279-313, 383-387, 838-852; clients.go:162-177; system.go:176-189). Raw unix seconds are present alongside for programs and jobs (`start`, `end`) but not for every label. The container's default `TZ` is set in the `Dockerfile` (`ENV TZ=America/New_York`).
7. **Icons are Phosphor CSS class names** (`ph-house`, `ph-clock`, `ph-play-circle`, `ph-stack`, …) in sidebar items, client views and collections (clients.go:47-60, 190-198; collections.go:111-113); colours are CSS hex strings (`logoBg`, sources.go:270-294). A native app must map or ignore them.
8. **Quick Actions are ids the server merely stores**; the mapping from id to API call lives in the browser (web/marlin.js:29-58; settings.go:19).
9. **Errors are plain-text bodies** (`http.Error`), not JSON, with the message meant for a `window.alert` (web/marlin.js:16-19, 127).
10. **`/` redirects to a `.dc.html` page** chosen by the Home Page setting (main.go:190-198, 307-311); everything outside `/api`, `/export`, `/rss` is the web UI's static tree (main.go:164-183, 312).
11. **No CORS, no cookies, no auth** — irrelevant to a native app on the same LAN, but it means the web UI's "same origin" is the only access control the server has (§ How the inventory was made).
12. **Add-client help text on the Clients page** documents the intended tvOS registration body (`{"name","app","type","os"}`) and the ping-on-launch expectation (web/pages/devices.js:64).

## 6. Gaps — what a tvOS client cannot get from the server as it stands (step 6)

Facts only.

1. **No playable video stream for AVFoundation.** The only media output is a chunked, length-less fragmented MP4 pipe (§3.2–3.3); there is no HLS, no progressive MP4 with a full `moov`, no byte-range access (§3.6, §3.7).
2. **No seeking or scrubbing inside a stream;** a seek is a new session, and a session is single-use (stream.go:291-296, 326; §3.5).
3. **No live pause/time-shift;** `start` is ignored for live and `liveBuffer` is inert (stream.go:181-203; settings.go:34).
4. **No direct access to recording files**, and the files are MPEG-TS/MPEG-2/AC-3 for over-the-air recordings anyway (library.go:581; recorder.go:23-27).
5. **No native path for cameras:** RTSP URLs and credentials stay on the server; the only outputs are the fMP4 pipe and a JPEG snapshot cached 45 s (cameras.go:18-19, 163-166, 193-277).
6. **No resume position.** The library stores `watched`/`watchedAt` per recording, globally, not a playback position and not per client (library.go:68-79).
7. **No per-client state beyond the Customize layout;** watched/favourite/keep/trash flags are shared by every client (library.go:68-79; clients.go:42-45).
8. **No authentication, no HTTPS,** and no way to distinguish a trusted client from any other device on the LAN (main.go:362-363, 385; §4).
9. **No error signalling on a failed stream start:** the `200` and headers are sent before ffmpeg opens its input; a busy tuner or offline camera ends the body silently and the reason is only in the session log (stream.go:313-327, 348-358, 406-420).
10. **No quality selection:** transcodes are fixed at ≤ 720p / 6 Mb/s / software x264 (stream.go:146-157); no hardware encoder is used ("software only", stream.go:22).
11. **No server push except the log SSE stream** (logs.go:120-148); schedule, library and session changes must be polled.
12. **No general search:** `/api/guide/search` matches an exact title only, future airings only (guide.go:757-778); the library has no search endpoint; the `search` sidebar entry has no backend (clients.go:56).
13. **No channel-logo proxy:** `logo` is the provider's absolute URL, fetched by the client (guide.go:410; sources.go:558); only program `icon`s are proxied via `/api/art/feed` (artwork.go:380-382).
14. **No JSON error bodies** (`http.Error` text everywhere, e.g. stream.go:170, 184, 188).
15. **No tvOS-shaped user-agent parsing:** a tvOS UA yields "Browser on unknown OS" unless the app sends `type`/`os` itself (clients.go:124-160, 246-251).
16. **Sessions are not scoped to a client;** `GET /api/play/sessions` lists everyone's, and any caller can `DELETE` any session (stream.go:385-403).
17. **Guide data is shaped for the web grid** (30-minute `span` blocks, ≤ 48 slots, server-local labels); a native guide has to re-derive its layout from the embedded `program.start/end` (guide.go:590-664).
18. **RSS enclosures point at a route that does not exist** (`/api/play/recording/<id>.mp4`, rss.go:87-88); not needed by tvOS, recorded for completeness.
19. **Thumbnail generation blocks the first request** while ffmpeg runs (library.go:973-975).

## Open Questions

1. The AVFoundation conclusion in §3.7 is source-level reasoning against documented AVFoundation behaviour; it was not tested on an Apple TV or simulator (no network in this pass; no tvOS runtime on this Mac). Is a real playback test against the running server an authorised step for a later pass, and on which Apple TV?
2. The server produces no HLS. Whether the tvOS app should demux the fMP4 pipe itself, or whether the server should add an HLS output, is a decision for the marlin-dvr project (DECISIONS.md), not this one. Which project should own it?
3. This recon read HEAD `d0280f76` (version 0.7.0, build 2026.09.05). Whether the container on Unraid is running that exact commit was not verified (no request sent). Is confirming `GET /api/status` against the server an authorised step for a later pass?
4. The server is HTTP-only. Is an App Transport Security exception for the server's host (or arbitrary loads) acceptable for the tvOS app, and should that be recorded in DECISIONS.md?
5. The Customize sidebar ids are the web UI's screens (`home, onnow, guide, onlater, recordings, cameras, weather, search, clients, settings`). Should the tvOS app honour that per-client layout, and which of those screens is it expected to have?
6. A client removed from the Clients page loses its id and re-registers as a new device. Where should the tvOS app keep its id (UserDefaults, keychain, iCloud) so it survives reinstalls, if that matters to the owner?
7. The `client` field on a play session is unvalidated (stream.go:174-178). Should the app treat "unknown client" on a ping as "re-register first, then play", to keep the Clients page's "Watching …" line accurate?

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `reports/2026-09-05-pass2-server-recon.md` (this file) | deliverable (steps 1–6) |
| `~/Xcode/marlin-dvr-reference/.git/` — `git fetch origin` only (no checkout, pull, reset, or edit; working tree unchanged, `README-REFERENCE.md` still untracked) | 1 |
| Commit + push of this file to `origin main` | deliverable |

Nothing else was written. No file under `~/Xcode/Marlin DVR TV` other than this report changed (the Xcode project, sources and assets are untouched). No other folder under `~/Xcode` was written. No request was sent to the Marlin DVR server, the Unraid host, marlinpc, the HDHomeRun, or the UNAS4Pro share. Nothing was installed. Read-only tool output from this session was cached by the session harness under the user's Claude project directory (outside `~/Xcode`), not in any repo.

## Push verification

Recorded in the follow-up commit section at the end of this file (a report cannot contain the hash of the commit that includes it).

Pass 2 commit ("Pass 2: server recon report"): `fa4e540be03054fa1d299c770c846c78a178135e`.

`git status --short` before the commit showed only `?? reports/2026-09-05-pass2-server-recon.md`.

```
git push origin main
git fetch origin
local HEAD      : fa4e540be03054fa1d299c770c846c78a178135e
origin/main     : fa4e540be03054fa1d299c770c846c78a178135e
ls-remote main  : fa4e540be03054fa1d299c770c846c78a178135e
MATCH
```

What was pushed: this one file, in that commit. A follow-up commit ("Pass 2: record pushed SHA in report") then wrote the SHA and this block into the file and was pushed and verified the same way (fetch, then compare `HEAD`, `origin/main` and `git ls-remote origin main`); its own SHA is the current `origin/main` and is stated in the closing summary.
