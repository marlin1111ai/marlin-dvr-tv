# Pass 4 — Design into the repo, decisions, build recon (read-only except the named files) — 2026-09-05

The owner's approved Claude Design export was placed in `design/`, the design decisions were recorded in the notebook, and every in-scope screen was mapped to the server API and sorted into build sweeps. No app code was written. No request was sent to the server or any LAN host; the only network use is the push of this commit. Nothing was installed, nothing was edited inside `design/`, and the reference clone was only read (no fetch was needed or made in this pass).

Citation keys: `frame · element` = a frame id in `design/Marlin DVR TV.dc.html` and the element or its line number in that file (`dc:NNN`); `contract §n` = `HLS-CLIENT-API.md` in the reference clone; `Pass 2 §n` / `Pass 3 §n` = this repo's earlier reports; `file:line` = `cmd/marlin-dvr/` in the reference clone at HEAD `eef49e8` (the same HEAD Pass 3 read; `git diff --stat d0280f76 HEAD -- cmd/marlin-dvr/` shows only `hls.go`, `procs.go`, `main.go`, `recorder.go` (+2 lines) and `stream.go` changed since Pass 2, so Pass 2's citations to `guide.go`, `passes.go`, `library.go`, `sources.go`, `cameras.go`, `clients.go`, `artwork.go` and `dashboard.go` still resolve and were re-checked where quoted).

## 1. Design into the repo (step 1)

`ATV-DVR.zip` was present at `~/Xcode/Marlin DVR TV/ATV-DVR.zip` (3,425,349 bytes, dated Sep 5 22:27, SHA-256 `36767e3fd21313e382afff05f1e25686594640cbdeba2f9032f1b9dec401a3ea`). `unzip -t` reported no errors. `design/` was created, the archive extracted into it with `unzip -q ATV-DVR.zip -d design` (paths preserved), and the zip moved to `design/ATV-DVR.zip`. Nothing inside `design/` was edited.

**File list** (method: `find design -type f -exec stat -f '%z %N'`, sorted by path; sizes in bytes; `file` for the type; counted by hand):

| Path under `design/` | Bytes | Type (`file`) |
|---|---|---|
| `.thumbnail` | 20,988 | WebP image |
| `ATV-DVR.zip` | 3,425,349 | the archive itself (moved here) |
| `Marlin DVR TV.dc.html` | 118,216 | HTML, 1,411 lines — the design canvas |
| `_ds/nocturne-cd16098c-beea-4866-98d8-a7f5e2b3cacd/_adherence.oxlintrc.json` | 4,195 | JSON |
| `_ds/nocturne-…/_ds_bundle.js` | 300 | JS (empty namespace stub) |
| `_ds/nocturne-…/_ds_manifest.json` | 7,480 | JSON — the Nocturne token list |
| `_ds/nocturne-…/readme.md` | 8,307 | Markdown — the Nocturne guide |
| `_ds/nocturne-…/styles.css` | 13,029 | CSS — the token sheet |
| `image-slot.js` | 65,350 | JS — the canvas's image placeholder component |
| `screenshots/guide-3a.png` | 28,064 | JPEG data 909×525 (despite the `.png` name) |
| `screenshots/guide-comfortable.png` | 111,921 | PNG 960×540 |
| `screenshots/home-tiles.png` | 383,753 | PNG 960×540 |
| `support.js` | 69,150 | JS — the Claude Design canvas runtime ("GENERATED from dc-runtime") |
| `uploads/Screenshot 2026-09-05 at 10.09.02 PM.png` | 2,812,794 | PNG 3844×2072 — the owner's upload: an earlier Home tile grid (Search tile where the final design has Settings) |

Counts: 13 entries in the archive (`unzip -l`: 13 files, 3,643,547 bytes uncompressed); 14 files in `design/` after the move; 7,068,896 bytes on disk (`du -sk design` = 6,932 KiB). The expected set from the task (`Marlin DVR TV.dc.html`, `_ds/…`, `support.js`, `image-slot.js`, `screenshots/`, `uploads/`, `.thumbnail`) is all present; nothing else was in the archive (no `__MACOSX`, no `.DS_Store`).

**Credential scan.** `grep -i` over the page, both scripts and the five `_ds` files for `password|passwd|secret|token|api[_-]?key|apikey|bearer|authorization|credential|private[_-]?key|BEGIN … PRIVATE|ghp_|sk-|AKIA|xox[bp]-|eyJ…` — no match. IP addresses: exactly one, `192.168.1.250:8090` at `dc:71` (the rail footer), already in the notebook. External URLs: `unpkg.com` (React 18.3.1, Babel standalone, Phosphor icons 2.1.1 CSS), `fonts.googleapis.com` / `fonts.gstatic.com` (Inter), `unsplash.com` (an attribution link inside `image-slot.js`), `phosphoricons.com` (in the Nocturne readme). No e-mail addresses. The four images were viewed; they show design renders only. Nothing to redact; nothing to stop for.

**What the archive is.** A Claude Design canvas: one `<x-dc>` document whose frames are 1920×1080 tvOS screens laid out on a page, filled at render time from a data script at `dc:1083-1409` (channel list, guide rows, shelves, player messages). `support.js` and `image-slot.js` are the canvas renderer, not app code. The `_ds` folder is the Nocturne design system: dark ground `#161826`, surface `#232532`, text `#e9e9ed`, one accent `#9184d9` with 100–900 ramps, Inter for heading and body, radii 4/8/14 px, three shadow levels (`_ds_manifest.json` tokens; `readme.md`). The page header states the tvOS rules the frames follow: 1920×1080 at 1×, 60 pt top/bottom and 80 pt side margins, body 29 pt, secondary never under 23 pt, one focused element per frame with a 4 pt accent ring, a lift and an ambient shadow (`dc:33-35`).

**Frame index** (20 static frames by `id=` plus 4 generated from `playerMessages`, counted by hand from `grep -n 'id="'`):

| Id | `data-screen-label` / caption | Line | Status per DECISIONS |
|---|---|---|---|
| 1b | On Now / sidebar — rail expanded | dc:50 | chosen (rail) |
| 2a | Home — tile grid | dc:115 | chosen (Home) |
| 3a | Guide / comfortable — 8 rows, 2-hour window | dc:173 | chosen (Guide) |
| 3b | Guide / dense — 12 rows, 3-hour window | dc:235 | not chosen |
| 3c | Guide / next day — paged past midnight | dc:295 | in scope (Guide paging) |
| 4a | Poster-forward shelf card, 2:3 | dc:370 | chosen (cards) |
| 4b | Landscape 16:9 card with resume bar | dc:397 | not chosen |
| 5a | On Later | dc:431 | in scope |
| 5b | Recordings library | dc:495 | in scope |
| 5c | Airing detail sheet | dc:541 | in scope |
| 5d | Show detail | dc:583 | in scope |
| 5e | Cameras | dc:649 | in scope |
| 5f | Weather | dc:690 | future — not read for recon |
| 5g | Radio | dc:764 | future — not read for recon |
| 6a | Player / starting | dc:860 | in scope |
| 6b | Player / live | dc:882 | in scope |
| 6c | Player / recording | dc:917 | in scope |
| 6d | Player / paused live | dc:955 | in scope |
| 6e–6h | Ended / 403 DRM / 502 / 410 (generated, `dc:976-999` from data `dc:1243-1266`) | — | in scope |
| 7a | Top Shelf image 1920×720 | dc:1011 | not listed in DECISIONS (Open Question 13) |
| 8a | App icon, layered 1280×768 | dc:1029 | not listed in DECISIONS (Open Question 13) |

## 2. Notebook changes (step 2)

`DECISIONS.md`: a new heading `## 2026-09-05 (design)` with the four bullets from the task, verbatim. `COLD-START.md`: under "How to build" the paragraph saying the scheme/destination line fails was replaced with the fact that the tvOS 26.5 platform component is installed (confirmed in Pass 3) and both build lines work; under "Where things live" a line for `design/` as the approved read-only design; under "What is built" a paragraph for Pass 4; "Next step" replaced with "Build sweeps per reports/2026-09-05-pass4-design-and-build-recon.md". Nothing else in either file changed (`git diff` before the commit shows only those hunks).

## 3. Build recon — design vs server (step 3)

Every in-scope frame was read in full. For each screen: the elements the design shows (cited to the frame), the endpoints and fields that supply them, what the app derives itself, and what no endpoint supplies. Facts only; no server changes are proposed. Common facts that apply to every screen:

- All response URLs are server-relative and resolve against the app's base (Pass 2 §5 item 3; Pass 3 2(b) item 11). Art URLs are `/api/art/show?title=<title>` and are returned only when the server has art, otherwise `""` (artwork.go:362-367); the route 404s when there is no image (Pass 2 §2.11).
- Every formatted label the server returns (`endsIn`, `when`, `time`, `dateLabel`, `dayLabel`, `airedLabel`, `lastCheck`) is in the container's local time (Pass 2 §5 item 6); unix seconds are alongside for programs and jobs (guide.go:20-21; passes.go:62-63), so the app formats times itself.
- DRM channels come back from every channel list with `drm: true` (sources.go:114); the server does not hide them (`hidden` is a separate owner override, sources.go:116, 959-1004). Hiding them is the app's rule (DECISIONS; `dc:37`, `dc:1250`).
- Errors are plain-text bodies with an HTTP status (Pass 2 "How the inventory was made"; contract §7).

### 3.1 The rail (1b) and the shell

| Design element | Source | Cite |
|---|---|---|
| Nine destinations with Phosphor icons: Home, Favorites, On Now, Guide, On Later, Recordings, Cameras, Weather, Radio (1b · rail items) | Fixed in the design's data; not read from the server. The server's per-client sidebar (`GET /api/clients/{id}/ui`) has a different set: `home, onnow, guide, onlater, recordings, cameras (hidden by default), weather, search, clients, settings (locked)` — no `favorites`, no `radio` | dc:1133-1137; clients.go:47-60; Pass 2 §2.12 |
| Expanded rail 372 pt when focused; 180 pt icon strip elsewhere; no rail on Home (1b · aside; 3a · aside; Home caption) | App layout | dc:58, dc:180, dc:111 |
| Footer: the client name "Home Theater" (1b · dc:70) | `POST /api/clients/register` → `clientView.name`, the name this Apple TV registered under (DECISIONS) | clients.go:19, 248; contract §1 |
| Footer: `192.168.1.250:8090` (1b · dc:71) | The app's base URL. No discovery endpoint exists (contract §8); no in-scope screen sets it (Settings is future) | contract §8; Open Question 2 |
| Icons are Phosphor names; type is Inter (Nocturne) | Not supplied by anything in the project: tvOS ships neither. Bundling either is an icon pack / font, out of scope this pass | `_ds/readme.md`; Open Question 3 |

### 3.2 Home (2a)

Elements: greeting "Good evening" and the name "Marlin" (dc:128-129); date and clock (dc:132); weather glance card marked "Apple WeatherKit" (dc:133-143); nine tiles with a subtitle each, the first focused (data dc:1353-1368). No rail.

| Design element | Source | Cite |
|---|---|---|
| Greeting, weekday/date/time | Device clock; app derives the greeting from the hour | dc:128, 132 |
| "Marlin" under the greeting | Not supplied. The only name-like fields are `/api/status.name` = `"marlin-dvr"` and `/api/chrome.userName` = `"owner"` (a constant); neither is "Marlin" | main.go:37, 187; system.go:263-270 |
| Weather glance card | WeatherKit on the device — future per DECISIONS; no server endpoint | dc:141; DECISIONS |
| Guide tile "16 channels live" | `GET /api/channels` → `count`, minus channels with `drm: true` (app rule) | sources.go:1006-1022, 114; Pass 2 §2.5 |
| On Now tile "16 programs live" | `GET /api/guide/now` → `count` | guide.go:667-691 |
| On Later tile "9 upcoming" | `GET /api/schedule` → `count` (jobs); the design's stats data pairs "Upcoming 9" with "next in 1h 19m", the schedule figure | passes.go:855-879; dc:1219; Pass 2 §2.10 |
| Recordings tile "412 recordings · 2 recording now" | `GET /api/library` → `recordings`; "recording now" = count of `/api/schedule` items with `status == "Recording"` (app derives) | library.go:466; passes.go:65 |
| Cameras tile "3 of 4 online" | `GET /api/cameras` → `online` / `count` | cameras.go:280-289 |
| Favorites tile "6 favorite channels" | `GET /api/channels?filter=Favorites` → `count` (the screen itself is future) | sources.go:374-377 |
| Weather tile "72° · clear now", Radio tile "6 stations", Settings tile | No server endpoint (Weather/Radio/Settings are future) | DECISIONS; Open Question 1 |

### 3.3 On Now (the content of 1b)

Elements: header "On Now" with "2:41 PM · 16 channels" (dc:76-77); filter chips Favorites (active), All 16, HD, Antenna (dc:80-83); three-column cards: initials tile on a colour, "number · name", title, "ends 3:04 PM", progress bar (dc:85-99).

| Design element | Source | Cite |
|---|---|---|
| Cards: channel number, name, initials, tile colour | `GET /api/guide/now?source=&filter=` → items embed `MergedChannel`: `number, name, initials, logoBg, hd, favorite, drm, id` | guide.go:671-676; sources.go:103-122 |
| Title, "ends 3:04 PM" | item `title`; `endsIn` is a server-formatted label; `program.end` (unix) is alongside | guide.go:675, 685; guide.go:20-21 |
| Progress bar | App derives `(now − program.start) / (program.end − program.start)` | dc:93-95; guide.go:20-21 |
| Filter chips Favorites / All / HD | `filter` = `Favorites` \| `All Channels` \| `HD` \| `Non-HD` \| a collection | sources.go:362-386 |
| Filter chip "Antenna" | `source` = a source id or name from `GET /api/sources` (`type: hdhomerun`); the label "Antenna" is the design's word, the server's is the source's `name` | sources.go:366; Pass 2 §2.5; Open Question 16 |
| "16 channels" in the header | `count` after the app drops `drm` channels | dc:37; sources.go:114 |
| Clock in the header | Device clock | dc:77 |
| Focus on a card → play | The Player (§3.9) with `kind: live`, `id` = channel `id` | contract §2.1 |

### 3.4 Guide (3a, paged in 3c) 

Elements 3a: header "Guide · Fri Sep 5 · 2:30 – 4:30 PM" (dc:188-189); "+12h" pill (dc:192); column header "Channel" + four half-hour labels, the first "2:30 · now" (dc:196-201, data dc:1207); eight rows: initials tile, name, number (dc:206-212); cells spanning 1–4 columns with a title and an optional tag "● RECORDING" (green `#57b083`) or "◆ SERIES PASS" (gold `#d6a94e`) (dc:213-222, data dc:1174-1176, 1189-1195); focused cell = 4 pt accent ring; legend (dc:227-228); footer "Starts at the current half hour · forward only" (dc:229). Section caption: "Re-laid from start/end times; a focused airing opens the detail sheet in 5c" (dc:169). Elements 3c: header "Fri Sep 5 · 11:30 PM → Sat Sep 6 · 1:30 AM" (dc:311); "↩ Now · 2:41 PM" and "+12h" pills (dc:314-315); the day change marked on the "Sat · 12:00 AM" column (dc:321-327); footer: Back snaps to now, Back again leaves the Guide; "Forward only · keeps paging while the server has listings, 24 hours per request" (dc:353-354). The earlier render `screenshots/guide-comfortable.png` also shows "−12h" and "Now" pills and the footer "5 DRM channels are not listed"; the `.dc.html` 3a frame has only "+12h".

| Design element | Source | Cite |
|---|---|---|
| Rows and programs for a window | `GET /api/guide?start=<unix>&slots=<n>&source=&filter=` → `channels[{…MergedChannel, blocks[{title, subtitle, span, isLive, program{start,end,title,episodeTitle,new,live,premiere,finale,rating,desc,season,episode,seriesId,icon}, channelId, empty}]}]`, `timeSlots[{label,start}]`, `nowIndex`, `dayLabel`, `channelCount` | guide.go:550-558, 590-664; guide.go:18-38 |
| 2-hour window starting at the current half hour | `start` is truncated to a 30-minute boundary (default: now); `slots=4` | guide.go:593-604 |
| Cell widths from start/end (dc:169) | App derives from `program.start/end`; the server's `span` is a 30-minute-rounded web layout | guide.go:640-645; Pass 2 gap 17 |
| "+12h" paging; "24 hours per request" (dc:354) | New request with `start += 43200`; `slots` is capped at 48 = 24 h | guide.go:593-596 |
| Forward only (dc:229, 354) | App rule; the server accepts any `start` | guide.go:599-604 |
| "· now" column marker; "↩ Now" button; day-change label | App derives from `timeSlots[].start` and the device clock (`nowIndex` and `dayLabel` are also returned) | guide.go:656-662 |
| "● RECORDING" / "◆ SERIES PASS" tags | Not in `/api/guide` (`guideBlock` has no recording or pass field). App derives by joining `GET /api/schedule` jobs to blocks on `channelId` + `program.start`: `status == "Recording"` → recording; `status == "Queued"` and `passId != "manual"` → series pass | guide.go:550-558; passes.go:53-77, 65; Pass 2 §2.10 |
| Eight rows visible, all channels reachable | The server returns every channel in the filter; the app pages rows | guide.go:612, 662 |
| DRM channels not listed | App drops `drm: true` rows | sources.go:114 |

### 3.5 Airing sheet (5c)

Elements: dimmed guide behind (dc:547-555); poster 340×474 (dc:558); "New" tag (dc:561); "13.1 · WJZ · HD" (dc:562); title (dc:564); "Forever Blue · Series finale" (dc:565); "Tonight 10:00 – 11:00 PM · TV-14" (dc:566); description (dc:567); buttons "Record this airing" (focused), "Record the series", "Watch live" (dc:569-571); footer note "One antenna tuner. Recording this conflicts with Wheel of Fortune at 7:30 PM on 2.1 — the later start wins unless you cancel it." (dc:573-576).

| Design element | Source | Cite |
|---|---|---|
| Tag New / Series finale / episode title / rating / time / description | The block's `program`: `new, finale, premiere, live, episodeTitle, rating, start, end, desc` | guide.go:18-38 |
| "13.1 · WJZ · HD" | The row's `number, name, hd` | sources.go:107-113 |
| Poster | Not in `/api/guide` blocks (no `art`). The app requests `/api/art/show?title=<program.title>` and handles 404; `program.icon` (provider URL) can be proxied via `/api/art/feed?u=` | guide.go:550-558; artwork.go:362-367; Pass 2 §2.11 |
| "Record this airing" | `POST /api/record {channelId, start: program.start, padAfterLabel?}` → the `Job` (`status` may be `Conflict` with `reason "all N tuners busy"`); 404 no listing, 400 already ended, 409 already set | recorder.go:776-848; passes.go:475-477 |
| "Record the series" | `POST /api/passes {title, seriesId?, channel?}` → `passView`; defaults `recordMode "new"`, `keepMode "all"`; 409 if a pass exists for the same `seriesId` + `channel` | passes.go:598-618, 705-737 |
| "Watch live" | `POST /api/play/sessions {kind: "live", id: channelId, format: "hls", client}` — plays what is on now, whatever airing the sheet shows (live has no `start`). The frame shows the button on a 10 PM airing at 2:41 PM | contract §2, §4; stream.go:214-218; Open Question 7 |
| Conflict note | Not supplied before booking. Facts: the server marks conflicts only when it computes jobs (`Recording` first, then Record Now, then passes in priority order; a Queued job overlapping `tunerCount` placed jobs on the same source becomes `Conflict`); the tuner count is `/api/sources[].hdhomerun.tunerCount`; M3U sources use `streamLimit` or are unlimited. The design's rule "the later start wins" is not the server's (Record Now wins over passes; priority order among passes). The app can replay the rule from `/api/schedule` + tuner counts, or book and read the returned `Job.status/reason` | passes.go:331-335, 315-329, 455-480; sources.go:50; Open Question 6 |

### 3.6 On Later (5a)

Elements: header with subtitle "New, premiere, live, finale and movie airings" and a clock (dc:446-449); two columns "On Today" / "On This Week" (dc:454, 473); rows with a 92 pt art square, title, sub, "channel · when", and a "● Scheduled" pill (dc:457-469). Focus opens 5c.

| Design element | Source | Cite |
|---|---|---|
| Two sections | `GET /api/guide/later` → `sections[{label "On Today" \| "On This Week", items[]}]`, ≤ 24 each, one per series, only new/premiere/live/finale/movie airings | guide.go:695-712, 745-753; Pass 2 §2.6 |
| Title, sub, channel, when | item `title, subtitle, channel` ("2.1 · WMAR"), `when` (server label), `start` (unix), `program` | guide.go:699-708 |
| "● Scheduled" | item `scheduled: bool` | guide.go:706, 712 |
| Art square | item `art` (`""` when none → placeholder) | guide.go:708 |
| Clock | Device | dc:449 |

### 3.7 Recordings (5b with 4a cards)

Elements: header "Recordings · 38 shows · 412 recordings · 1.9 TB" (dc:511-512); note "Watched and keep flags are shared with the other Apple TV" (dc:514); shelves "Recently watched" and "Recently added", six 2:3 poster cards each with a "N new" badge, title and "41 episodes" (dc:516-536, data dc:1313-1330); 4a: cards 252×344, the focused one 296×404 lifted 22 pt with a 4 pt ring, shelf count "6 of 38" (dc:377-378, 1273-1275).

| Design element | Source | Cite |
|---|---|---|
| Shelves | `GET /api/library?limit=` → `sections[{key recently-watched \| recently-updated \| recently-added, label, items[showSummary], total}]`; the design uses two of the three | library.go:461-465 |
| Card: poster, title, "41 episodes", "3 new" | `showSummary {id, title, count, unwatched, art, lastAdded, lastUpdated, lastWatched}` | library.go:369-378 |
| "6 of 38" | items shown vs `total` (or `shows`) | library.go:465-466 |
| "38 shows · 412 recordings" | `shows`, `recordings` | library.go:466 |
| "1.9 TB" | Not supplied. `/api/library` has no total size; `/api/dashboard` "Disk Usage" and `/api/system` disk fields are the volume's, not the library's. Summing `size` needs `GET /api/library/shows/{id}` for every show | library.go:460-467; dashboard.go:27; library.go:46; Open Question 9 |
| Flags shared note | Fact: `watched/favorite/keep/trash` are global per recording, not per client | library.go:68-79; Pass 2 gap 7 |

### 3.8 Show detail (5d)

Elements: poster 520×472 (dc:598); title (dc:599); "41 episodes · 3 unwatched · 128 GB · HGTV" (dc:600); buttons "Resume S9 E11 · 22 min in" (focused), "Play newest", "Series pass" (dc:602-605); "Episodes · Newest first" (dc:611-612); rows with a 236×133 thumb carrying a progress bar, "S9 E12", title, "✓ Watched", description, "Aired Sep 2, 2026 · 58 min · 3.1 GB" and tags HD / 5.1 / CC (dc:614-642); footer "Click and hold an episode for Keep, Favorite, Mark unwatched, Delete" (dc:643). Caption: "episodes newest first, app-side resume" (dc:586).

| Design element | Source | Cite |
|---|---|---|
| Show, poster, episodes newest first, count | `GET /api/library/shows/{id}` → `{id, title, episodes[episodeView], count, trashCount, art, info{found, genres, overview}, pass, rss}` | library.go:586-640 |
| Episode: "S9 E12", title, aired, size, tags, watched, thumb, description | `episodeView`: `season, episode, episodeTitle, aired, size, sizeLabel, tags[] (HD/4K/codec/5.1/Stereo/Mono/CC), watched, thumb, description, channel, exists` | library.go:486-500, 516-546 |
| "58 min" | No numeric duration on `episodeView`. `airedLabel` embeds ", 58 min" as text only once the file has been probed; seconds come from `GET /api/library/recordings/{id}/mediainfo` → `durationSeconds` (one ffprobe per recording, cached) or `GET /api/play/info?rec=` → `duration` (also probes) | library.go:518-523, 905-910; stream.go:476-480; Open Question 10 |
| "3 unwatched" | App counts `watched == false`, or `unwatched` from the `/api/library` summary | library.go:397; 369-378 |
| "128 GB" | App sums episode `size` | library.go:46 |
| "HGTV" | `channel` on the episodes (from stored metadata) | library.go:493 |
| "Resume … 22 min in" and thumb progress bars | App-side resume store, per Apple TV; position ÷ duration | DECISIONS; dc:602, 617-619 |
| "Play newest" | `episodes[0]` → the Player with `kind: "recording"` | contract §2.1 |
| "Series pass" | `pass` = the title of an existing pass matched by show title (case-insensitive), else `""`; create with `POST /api/passes {title}` | library.go:632-639; passes.go:705-737 |
| Long-press Keep / Favorite / Mark unwatched / Delete | `PUT /api/library/recordings/{id} {keep \| favorite \| watched \| trash}` → `episodeView`; trash deletes at once when the Trash setting is "Immediately" | library.go:643-694 |
| Thumb | `thumb` URL; generated synchronously on first request | library.go:576, 949-983; Pass 2 gap 19 |

### 3.9 Cameras (5e)

Elements: header "Cameras · 3 of 4 online" (dc:664-665); "Snapshot age 12 s · click for live view" (dc:667); 2×2 cards: snapshot, "Online"/"Offline" pill, name, "H.264 · 1080p", error "✕ stream could not start (502) · last seen 11:04 AM" (dc:669-685). Caption: "snapshots the server refreshes every 45 s" (dc:652).

| Design element | Source | Cite |
|---|---|---|
| Cards, "3 of 4 online" | `GET /api/cameras` → `{cameras[{id, name, address, streamPath, hidden, online, lastCheck, lastError, codec}], count, online}` | cameras.go:23-39, 163-177, 280-289 |
| Snapshot | `GET /api/cameras/{id}/snapshot.jpg?refresh=1` → JPEG, `no-store`; one frame over RTSP, cached 45 s (3 s when forced); 404 with the probe error text when offline | cameras.go:191-201, 419-434 |
| "H.264" | `codec` = the codec name from ffmpeg's stream line, lower-case (`h264`) | cameras.go:59, 238-239 |
| "1080p" / "4MP" | Not supplied: `Camera` has no resolution field | cameras.go:23-39; Open Question 11 |
| "Snapshot age 12 s" | App derives from its own fetch time; `lastCheck` is a relative label ("now", "… ago") | cameras.go:169; clients.go:162-170 |
| "last seen 11:04 AM" | Not supplied as a time; `lastCheck` is a relative label and `lastError` is the probe's text | cameras.go:169-170 |
| Click → live view | The Player with `kind: "camera"` | contract §2, §4 |
| Hidden cameras | `hidden` flag; the app filters | cameras.go:33 |

### 3.10 Player (6a–6h)

Section caption: "Apple's player owns the transport; these are the states the app has to dress around it" (dc:856).

| State · element | Source | Cite |
|---|---|---|
| 6a Starting: initials tile, "ch13.1 WJZ", "Days of Our Lives · until 3:04 PM", pulse bar, "Tuning the antenna and starting the encoder", "Live channels usually take 2–6 seconds. Press Menu to cancel." (dc:868-877); caption "up to 20 s" (dc:863) | Session `title` is `"ch<number> <name>"`; `GET /api/play/info?live=` gives `sub` = `"<title> · until <end>"` and `art`; the first playlist GET blocks up to 20 s (`hlsPlaylistWait`), measured 5.8 s antenna / 1.8 s M3U; cancel = `DELETE /api/play/sessions/{id}` | stream.go:214-218, 464-467; hls.go:44, 304-325; contract §4, §5, §7 |
| 6b Live: "LIVE" pill, "13.1 WJZ · 720p", title, "S61 E12 · ends 3:04 PM", pause/Info/Channels, bar at the live edge "12 s buffer", note "Pausing longer than 15 seconds ends the stream and restarts it at the live edge" (dc:890-912) | 12 s = `hlsCameraList` 6 × `hlsCameraSeg` 2 s; 15 s = `hlsIdleTimeout`; no time-shift; season/episode from `/api/guide/now` `program`; "720p" is the transcode cap, not a session field (the response carries `mode: "transcode"` only) — the app hard-codes it or reads the item's presentation size | hls.go:43-47; contract §4, §6; stream.go:295; guide.go:18-38 |
| 6c Recording: title, "S9 E11 · A House with Good Bones · HGTV", pause/Info/Next episode, scrubber 22:14 / 58:00 with a "prepared" mark, "Prepared to 41:00. Jumping past that point restarts playback there…", "Resume kept by Home Theater" (dc:928-949) | `duration` (58:00) from the session response; "prepared to" derived from the EVENT playlist's growth (`AVPlayerItem.seekableTimeRanges` end, or segments × 4 s) — no server field; a jump past it = new session with `start`, position = `start` + player time; resume = app store; the name = the registered client name | stream.go:239, 295; contract §3; Pass 3 2(a), 2(b) items 5-6; DECISIONS |
| 6c "Next episode" | App derives from the show's `episodes` (newest first) | library.go:586-640 |
| 6d Paused live: "Paused", "…the app is holding the tuner session open in the meantime", "Held for 0:12 · session refreshed silently", "LIVE · HELD" (dc:964-971) | The app fetches the playlist on a timer under 15 s while paused (Pass 3 way (i)); only playlist/segment GETs stamp the session | hls.go:43, 185-203, 301; contract §6; Pass 3 2(b) item 3 |
| 6e Ended: "Marked watched on the server", "Next episode starts in 8 seconds.", buttons Play S9 E13 / Back to the show / Delete this recording (dc:1244-1247) | Watched = `PUT /api/library/recordings/{id} {watched: true}` set by the app (the server never marks it); countdown = app timer; next episode derived; Delete = `PUT … {trash: true}` | library.go:643-666, 673-684; Pass 2 §5 item 5 |
| 6f 403 DRM: "ch5.1 WBAL-DT2", body about the five hidden DRM channels, buttons Back to the guide / Hide this channel (dc:1248-1251) | 403 `this channel is DRM-protected and cannot be streamed`; avoidable via `drm` on `/api/channels`; "Hide this channel" is either the app's own list or `PUT /api/sources/{id}/lineup/{guid} {hidden: true}`, which hides it for every client | stream.go:205-208; contract §7; sources.go:114, 959-1004; Open Question 8 |
| 6g 502: "The antenna tuner is busy", "22.1 WMPT · one HDHomeRun tuner", "WJZ News at 4 is recording on 13.1 until 4:30 PM… or pick a Philo channel — those need no tuner", buttons Stop the recording and watch / Pick another channel / Show the server log (dc:1252-1255) | The server's 502s are `HLS session could not start: …` (POST) or `ffmpeg exited before writing a playlist` / `ffmpeg produced no playlist within 20s` (first playlist GET); none names a busy tuner — the reason is only in the session log. Attribution is derived: `/api/schedule` items with `status "Recording"` and the channel's `sourceId` (`end` is padded), plus `/api/sources[].hdhomerun.tunerCount`; another client's live session also holds a tuner and appears only in `GET /api/play/sessions` (`sourceId`, `clientName`, `title`). Philo: M3U capacity is `streamLimit` or unlimited. Stop = `POST /api/schedule/jobs/{id}/stop` (409 if not recording); log = `GET /api/play/sessions/{id}/log` | contract §7; hls.go:304-325; Pass 2 gap 9; passes.go:53-77, 315-329; sources.go:50; stream.go:32-49; recorder.go:687-694; Open Question 12 |
| 6h 410: "Restarting the stream", "22.4 NHK-WLD · paused 4 minutes", auto-restart (dc:1256-1259) | 410 `session ended` after the 15-s watchdog; restart = a new POST | hls.go:297-300; contract §5, §6 |

Three player frames describe pausing live TV differently: 6b says a pause over 15 s ends the stream and restarts at the live edge; 6d says the app holds the session open by refreshing it; 6h shows a 4-minute pause that expired. Recorded as Open Question 5.

### 3.11 Top Shelf (7a) and icon (8a)

7a: a 1920×720 image slot, the wordmark "Marlin DVR" and "9 recordings queued · 3 shows with something new" (dc:1016-1025). The numbers would be `/api/schedule` `count` and the `/api/library` items with `unwatched > 0` (passes.go:855-879; library.go:373). Dynamic Top Shelf content on tvOS comes from a Top Shelf app extension, a separate target; a static image is an asset-catalog entry. 8a: a layered 1280×768 icon — front wordmark with the accent bar, middle signal arcs, back indigo ground (dc:1036-1073) — an asset-catalog entry. Neither is in DECISIONS' in-scope or future list, and assets and project targets were untouchable this pass (Open Question 13).

### 3.12 Design vs server — what no endpoint supplies (consolidated)

| Design shows | Frame | Fact | Cite |
|---|---|---|---|
| The name "Marlin" under the greeting | 2a · dc:129 | No endpoint returns it; `/api/status.name` is `marlin-dvr`, `/api/chrome.userName` is the constant `owner` | main.go:37, 187; system.go:267 |
| Weather glance and tile subtitle | 2a · dc:133-143, 1360 | WeatherKit, future; no server endpoint | DECISIONS |
| Radio tile "6 stations" | 2a · dc:1361 | No server endpoint; future | DECISIONS |
| Rail set with Favorites and Radio | 1b · dc:1133-1137 | Differs from the server's sidebar ids | clients.go:47-60 |
| Recording / series-pass marks on guide cells | 3a · dc:217-219 | Not in `/api/guide`; joined from `/api/schedule` by the app | guide.go:550-558; passes.go:53-77 |
| Poster on the airing sheet | 5c · dc:558 | `/api/guide` blocks carry no `art`; the app builds `/api/art/show?title=` and handles 404 | guide.go:550-558; artwork.go:362-367 |
| Conflict preview and "the later start wins" | 5c · dc:575 | No pre-booking conflict check; the server's rule differs | passes.go:333-334, 455-480 |
| "Watch live" on a future airing | 5c · dc:571 | Live sessions play what is on now | stream.go:214-218 |
| Library total "1.9 TB" | 5b · dc:512 | No total on `/api/library`; per-show sums needed | library.go:460-467 |
| Episode duration "58 min" as a number | 5d · dc:633 | Not on `episodeView`; needs `mediainfo` or `play/info` per episode | library.go:486-500, 909-910 |
| Camera resolution "1080p" / "4MP" | 5e · dc:678 | No resolution on `Camera` | cameras.go:23-39 |
| Camera "last seen 11:04 AM" | 5e · dc:1341 | `lastCheck` is a relative label only | cameras.go:169 |
| "720p" in the live overlay | 6b · dc:891 | Not a session field; the transcode cap is a server constant | stream.go:295; contract §4 |
| "Prepared to 41:00" | 6c · dc:948 | No server field; from playlist growth in the player | contract §3 |
| "The antenna tuner is busy" and which recording holds it | 6g · dc:1253-1254 | The 502 text never says so; attribution is derived from the schedule and the sessions list | contract §7; Pass 2 gap 9 |
| Resume positions, next-episode countdown, watched-on-end | 5d, 6c, 6e | App-side by decision; the server has no resume position | Pass 2 gap 6; DECISIONS |

## 4. Sweeps (step 4)

Sorted with the design and the API side by side; only in-scope items appear. The order is 1 → 2 → 3 → 4; sweeps 3 and 4 are independent of each other.

**Sweep 1 — foundation (must exist before any screen).**

- ATS exception in `Info.plist` for the plain-HTTP server; without it no request and no AVPlayer load leaves the device (Pass 3 2(b) item 10; Pass 2 gap 8). Which key covers a numeric LAN address is Pass 3 Open Question 3, still open.
- API client: base URL (the design shows `192.168.1.250:8090` in the rail footer, `dc:71`), JSON decoding, plain-text error bodies mapped to typed errors with the HTTP status (contract §7), server-relative URL resolution (Pass 3 item 11), a request timeout above 20 s for the first playlist GET (contract §7).
- Client register on first launch, ping on every launch, re-register on 404, the id persisted on the device (contract §1; Pass 3 item 9); the returned `name` feeds the rail footer (1b · dc:70) and "Resume kept by Home Theater" (6c · dc:949).
- Models: `MergedChannel` (sources.go:103-122), `Program` (guide.go:18-38), the `/api/guide/now` item (guide.go:671-676), `guideBlock`/`guideRow` (guide.go:550-563), the `/api/guide/later` item (guide.go:699-708), `Job` (passes.go:53-77), `showSummary` (library.go:369-378), `episodeView` (library.go:486-500), `Camera` (cameras.go:23-39), `clientView` (clients.go:179-187), the session response (stream.go:295) and `play/info` shapes (stream.go:455-491).
- The DRM filter applied to every channel list (DECISIONS; sources.go:114) — shared by On Now, the Guide, the sheet and state 6f.
- Art loading: `art` URLs, 404 → placeholder, `/api/art/show?title=` built for guide programs, `logoBg` hex to a colour and `initials` for the channel tiles (sources.go:118-119; artwork.go:362-367).
- The Nocturne token layer: colours from `_ds_manifest.json`, the 60/80 pt margins and the 23/26/29/31 pt type sizes, the focus treatment (`dc:33-35`; `FOCUS_ON` at `dc:1122`). Icon and font choice is Open Question 3.
- The rail shell (1b) and Home (2a): every other screen sits inside the rail; Home is the launcher and its tile subtitles exercise six endpoints (§3.2), so it doubles as the first end-to-end check of the client.

Reason: nothing in §3 can be rendered against the server without the client, the id, the ATS exception and the models; the rail and Home are the only way to reach the screens.

**Sweep 2 — the read-only screens; independent of each other, can sweep together.**

- On Now (§3.3): one endpoint, `/api/guide/now`, plus the filter chips.
- Guide 3a/3c with the airing sheet 5c as display only (§3.4, §3.5): `/api/guide` re-laid from `program.start/end`, `/api/schedule` joined for the marks, paging by `start`, the Back rule from 3c; the sheet shows program facts and its three buttons, but the buttons are wired in sweeps 3 and 4.
- On Later 5a (§3.6): `/api/guide/later`; focus opens the same sheet.
- Recordings 5b shelves and show detail 5d as display only (§3.7, §3.8): `/api/library`, `/api/library/shows/{id}`, thumbs; the resume button and the long-press actions are wired in sweeps 3 and 4.
- Cameras 5e (§3.9): `/api/cameras` and snapshots on a refresh timer.

Reason: each reads one or two endpoints, shares nothing with the others beyond sweep 1, writes nothing on the server, and can be tested against the live server with no side effect on the schedule, the library or a tuner. They are the surfaces the two stand-alone sweeps plug into.

**Sweep 3 — the Player, stands alone (§3.10).**

- Session lifecycle for `live`, `recording` and `camera`: POST with `format: "hls"` and `client`, the first-playlist wait (6a), `DELETE` on stop and on Menu, the 15-s watchdog while paused (6d; Open Question 5), 410 → restart (6h), seek past the prepared range by a new session with `start` and position = `start` + player time (6c), the error states 403/502 with their derived copy (6f/6g), watched-on-end and the next-episode countdown (6e), the per-Apple-TV resume store that 5d and 6c read.
- The three buttons on 6e/6f/6g that write server state (Delete this recording, Hide this channel, Stop the recording and watch) render in this sweep and are wired in sweep 4.

Reason: it is the only part governed by the contract's timing rules (20-s first playlist, 15-s watchdog, single-use sessions), it holds a tuner while it runs, its pause policy is unsettled in the design, and its entry points are the sweep-2 screens (a card on On Now, "Watch live" on 5c, Resume / Play newest on 5d, a camera on 5e).

**Sweep 4 — recording, pass and library writes, stands alone.**

- "Record this airing" → `POST /api/record` and the returned `Job.status/reason` (5c); "Record the series" → `POST /api/passes` and its 409 (5c, 5d "Series pass"); the conflict note (5c; Open Question 6).
- Long-press Keep / Favorite / Mark unwatched / Delete → `PUT /api/library/recordings/{id}` (5d); "Delete this recording" (6e); "Hide this channel" (6f; Open Question 8); "Stop the recording and watch" → `POST /api/schedule/jobs/{id}/stop` (6g).
- After each write, the guide marks (3a), the "● Scheduled" pill (5a), the show's `pass` field (5d) and the episode flags (5d) refresh from their endpoints.

Reason: these change server state that the web UI and the other Apple TV see at once (the schedule, passes, shared flags, the lineup), one of them deletes files when Trash is set to "Immediately" (library.go:683-684), and the design's conflict copy contradicts the server's rule; they belong behind the owner's test gate (COLD-START rules: separate push gate for code the owner tests).

## 5. Build environment (step 5)

Read-only. The two paired Apple TVs' device identifiers and the simulator UDIDs are replaced with `[REDACTED]` as in the Pass 3 report; nothing else is altered.

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

Reading: identical to Pass 3 — the tvOS 26.5 runtime is present, three simulators and both paired Apple TVs are listed, no destination is ineligible. No build was run.

## Open Questions

1. **Home tiles for future destinations** (2a · dc:1359-1362): Favorites, Weather, Radio and Settings tiles, and the weather glance card, appear on the chosen Home. Until those screens exist, are the tiles hidden, inert, or shown with a "later" state?
2. **Base URL**: the rail shows `192.168.1.250:8090` (1b · dc:71) and no in-scope screen sets it (Settings is future). Hard-code that default for now, and should DECISIONS record it?
3. **Icons and type**: the design uses Phosphor icons and Inter; tvOS ships neither, and bundling them is an icon pack / font (out of scope this pass). SF Symbols and the system font as the tvOS rendering of the same design, or bundle Phosphor and Inter in a later authorised step?
4. **Per-client sidebar** (`GET /api/clients/{id}/ui`, clients.go:47-60): the design's rail is fixed and differs from the server's ids. Ignore the server layout entirely? (Pass 2 Open Question 5 remains.)
5. **Pause policy for live TV**: 6b (dc:912), 6d (dc:966-967) and 6h (dc:1257-1258) describe three behaviours — end after 15 s, hold by refreshing silently, expire after 4 minutes. Which one, and if the hold is bounded, for how long? (Pass 3 Open Question 1 remains.)
6. **Conflict note on the airing sheet** (5c · dc:575): the copy "the later start wins unless you cancel it" is not the server's rule (Record Now wins over passes; passes by priority; passes.go:333-334, 455-480), and no endpoint previews a conflict. Show the server's `status`/`reason` after booking, replay the rule from `/api/schedule` before booking, or change the copy?
7. **"Watch live" on a future airing** (5c · dc:571): the frame shows it on a 10 PM airing at 2:41 PM; a live session plays what is on now (stream.go:214-218). Show the button only when the airing is on now?
8. **"Hide this channel"** (6f · dc:1251): the app's own list, or the server's lineup override `PUT /api/sources/{id}/lineup/{guid} {hidden: true}` (sources.go:959-1004), which hides the channel for the web UI and the other Apple TV too?
9. **"1.9 TB"** (5b · dc:512): not on `/api/library`; summing sizes costs one `GET /api/library/shows/{id}` per show (38 in the design's numbers). Sum, or drop the figure?
10. **Episode duration** (5d · dc:633): one `mediainfo` request per episode (an ffprobe on first request, then cached; library.go:886-916), or show a duration only once playing?
11. **Camera resolution** (5e · dc:678): no `Camera` field supplies it. Drop it, or read it from the HLS stream once a live view starts?
12. **Tuner-busy attribution** (6g): a tuner may be held by another client's live session, visible only in `GET /api/play/sessions` (stream.go:32-49), not the schedule. Should the copy also name "Master Bedroom is watching 13.1"? And the design's "Philo needs no tuner" holds only while that M3U source's `streamLimit` is 0 (passes.go:322-325).
13. **Top Shelf 7a and icon 8a**: neither is in DECISIONS' in-scope or future list. Dynamic Top Shelf needs an app-extension target; the icon and a static shelf image are asset-catalog work. In scope for a sweep, and which?
14. **Resume store location**: per Apple TV by decision; `UserDefaults` keyed by recording id is the plain choice — confirm, and does it need to survive reinstall? (Pass 3 Open Question 4 on the client id remains.)
15. **ATS key** (sweep 1 blocker): Pass 3 Open Question 3 is still open and a device test was not authorised. Settle before or during sweep 1?
16. **Source chip label** (On Now · dc:83): "Antenna" in the design; the server knows the source by its `name`. Fixed label by source `type`, or the server's name?
17. **Next episode and auto-play** (6c "Next episode", 6e "starts in 8 seconds"): next = the episode after the current one in the show's newest-first list, and auto-play after 8 s — confirm both, and whether auto-play is wanted at all.
18. **Continue-watching shelf**: 4b was not chosen and 5b shows only "Recently watched" and "Recently added" (dc:1313-1330), yet resume positions exist app-side. No continue-watching shelf on Recordings, correct?
19. **`screenshots/guide-comfortable.png`** shows "−12h" / "Now" pills and a footer the 3a frame lacks. The `.dc.html` frame is the design of record and the screenshot an earlier render — confirm.

## SCOPE CHECK — every file created or touched

| Path | Step |
|---|---|
| `design/` (new): 13 files extracted from `ATV-DVR.zip` plus the zip moved in — 14 files, listed in §1; nothing inside edited | 1 |
| `ATV-DVR.zip` at the repo root — moved (not copied) to `design/ATV-DVR.zip` | 1 |
| `DECISIONS.md` — `## 2026-09-05 (design)` heading and four bullets appended | 2 |
| `COLD-START.md` — "How to build" paragraph replaced; one line added under "Where things live"; one paragraph added under "What is built"; "Next step" replaced | 2 |
| `reports/2026-09-05-pass4-design-and-build-recon.md` (this file) | deliverable (steps 1–5) |
| Commit + push of the above to `origin main` | deliverable |

Nothing else was written. The Xcode project, Swift sources, assets, `Info.plist` and build settings are untouched (`git status` before the commit shows only the paths above). The reference clone was read with `git rev-parse`, `git log`, `git status`, `git diff --stat`, `sed -n` and `grep` only — no fetch, pull, checkout or edit; its working tree is unchanged (`README-REFERENCE.md` still untracked). No other folder under `~/Xcode` was written. No request was sent to the Marlin DVR server, the Unraid host, marlinpc, the HDHomeRun or the UNAS4Pro share. Nothing was installed. `xcodebuild -showdestinations` was the only Xcode command and it writes nothing to the project. Read-only tool output was cached by the session harness under the user's Claude project directory (outside `~/Xcode`).

## Push verification

Recorded in the follow-up commit section at the end of this file (a report cannot contain the hash of the commit that includes it).
