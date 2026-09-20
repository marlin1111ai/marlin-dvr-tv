# Pass 115 — live channel and collection notices (read-only recon)

**Date:** 2026-09-19
**READ-ONLY.** No app-target file, test-target file, project file, `design/` file or `icon-source/`
file was changed. No build, no install, no device run; neither Apple TV was touched. **Every request
to `http://192.168.1.250:8090/` was a GET** — four of them, listed in §3 — and no POST, PUT, PATCH or
DELETE was sent. `GET /api/settings` was not read.

**HEAD every app `file:line` below was read at: `861e50e4d95af65ae1a8661097bd41297750ec76`**
(Pass 114), with `git status --porcelain` showing only `?? icon-source/`. **Every server `file:line`
was read at marlin-dvr commit `0fa05e13927b202df469a430789df9c9683c73c4`**, straight from GitHub
(§1). Line numbers drift and are never rewritten afterwards (COLD-START, *Standing state of the
devices*).

**Nothing here is built.** §7 is a plan only.

## The owner's ask, verbatim

"Marlin DVR server 1.10.0 is installed on Unraid (192.168.1.250:8090). It now announces channel and
collection changes live. See HLS-CLIENT-API.md §12 in ~/Xcode/marlin-dvr-reference (pull it first;
latest commit 0fa05e1).
- GET /api/events is a server-sent event stream. Each event's data is the word `channels` or
  `collections`. No replay.
- When `channels` arrives, re-read GET /api/channels. When `collections` arrives, re-read GET
  /api/collections. My call: a channel change sends `channels` only, so decide on your side whether
  to re-read both lists on any notice.
- On reconnect, re-read both lists (missed notices are not replayed).
- Goal: the Guide redraws on screen when I change a channel or collection on the server, without
  backing out and back in.
Guide listings, recordings and passes already update fine; nothing changes there."

## How each claim is labelled

- **measured** — a command was run in this pass and its output is quoted.
- **read** — read from source at the commit named above, with `file:line`.
- **traced** — reasoned from code that was read; nothing was run. Nothing in §4–§6 was run on a
  television or a simulator.
- **from Apple's documentation, not verified here** — a platform default quoted from memory of
  Apple's documentation. Three statements in §6.2 carry it, covering four facts, and each says so.

---

## 1. Where the server files were read from

**Owner decision (2026-09-19), his words: "I don't need it on my computer if he can read it off of
GitHub."** This project no longer keeps a local clone of marlin-dvr; the builder reads server files
straight from GitHub at a named commit. It supersedes DECISIONS.md's 2026-09-05 line
(`DECISIONS.md:9`).

**This is the third issue of Pass 115, and what happened in the first two is part of the record:**

1. **First issue.** `~/Xcode/marlin-dvr-reference` was **not on this Mac**. `ls` answered *No such
   file or directory*; Spotlight found no `README-REFERENCE.md` and no `HLS-CLIENT-API.md` anywhere;
   the only trace was `marlin-dvr-reference.zip`, 195,472,324 bytes, dated 2026-09-19 09:18, in the
   owner's Proton Drive `xCode` folder beside four other project zips made between 08:19 and 09:22
   the same morning. **The old clone was removed from this Mac on 2026-09-19**, not by this project.
   The pass stopped at step 1. Nothing was written.
2. **Second issue** authorised a fresh `git clone` to the same path. It was made, clean, with no
   `README-REFERENCE.md`, and landed on **`878dac2`**, not the required `0fa05e1`: `0fa05e1` was an
   ancestor of it, with three commits on top made between 23:23 and 23:32 that evening, all labelled
   "records only". `git diff --name-only 0fa05e1 HEAD` listed five files — `COLD-START.md`,
   `DECISIONS.md` and three reports — and **no `.go` file and not `HLS-CLIENT-API.md`**. The pinned
   SHA is a gate, so the pass stopped again. Nothing was written to this repo.
3. **This issue.** When it started, `~/Xcode/marlin-dvr-reference` was **already gone again**. The
   builder ran no delete on it in any of the three issues.

**What was run this time (measured):**

```
$ git ls-remote git@github.com:marlin1111ai/marlin-dvr.git
878dac21bde48e289afb1a68bd4ab794b642a347	HEAD
878dac21bde48e289afb1a68bd4ab794b642a347	refs/heads/main

$ gh api repos/marlin1111ai/marlin-dvr/commits/0fa05e1 --jq '{sha, date, message, tree}'
{"date":"2026-09-20T03:15:06Z","message":"Pass 132: 1.10.0 installed on Unraid by the owner
(read-only check: status 1.10.0, /api/events 200); owner decisions recorded; nothing open (records
only)","sha":"0fa05e13927b202df469a430789df9c9683c73c4","tree":"4ecd754554b2abf9c3a8557b4f901ea3f114aa45"}
```

`git ls-remote` lists branch tips only, and the tip has moved on to `878dac2`, so it cannot show
`0fa05e1` by itself; **the commit's existence on the remote is confirmed by the API answer above.**

The first method the prompt names worked: **`gh api`, with `Accept: application/vnd.github.raw`, on
`repos/marlin1111ai/marlin-dvr/contents/<path>?ref=0fa05e13927b…`**. `HLS-CLIENT-API.md` and all 30
`cmd/marlin-dvr/*.go` files were fetched into the session scratchpad under `/private/tmp/…`. Byte
counts matched the commit's tree (`HLS-CLIENT-API.md` 33,981; `events.go` 1,936), and
`git hash-object` on the fetched bytes matched the remote's blob SHA for both files checked:

```
8f1e7941438b49e6f44eccdfa967c14499343b98  local  HLS-CLIENT-API.md
8f1e7941438b49e6f44eccdfa967c14499343b98  remote HLS-CLIENT-API.md
c242865bff5b9a9b263183dda9022d919abf3ff4  local  cmd/marlin-dvr/events.go
c242865bff5b9a9b263183dda9022d919abf3ff4  remote cmd/marlin-dvr/events.go
```

**Deleted before step 8, with the deletion shown (measured):**

```
--- before        31 files   576K ref-0fa05e1   124K step3
rm exit=0
--- after
ls: …/scratchpad/ref-0fa05e1: No such file or directory
ls: …/scratchpad/step3: No such file or directory
--- scratchpad now: empty
--- and the old clone path
ls: /Users/marlin1111/Xcode/marlin-dvr-reference: No such file or directory
```

`step3` held the four raw server answers of §3; they went with it. No copy of the server repo, in
whole or in part, is left on this Mac by this pass.

---

## 2. The server side, at `0fa05e1`

The contract's header names the server it describes: **1.10.0** (`HLS-CLIENT-API.md:7`), and
`appVersion = "1.10.0"` (`main.go:38`). §12 is `HLS-CLIENT-API.md:599-670`, read in full. Every
`file:line` §12 gives was checked against the Go source and **every one is correct**.

### 2.1 The wire format (read)

- **Route:** `GET /api/events`, `main.go:276`, handler `handleEvents`, `events.go:55-82`. No
  parameters, no body, no client id (`HLS-CLIENT-API.md:607-609`); the handler reads nothing from
  the request but its context (`events.go:72`).
- **Headers the handler sets:** `Content-Type: text/event-stream`, `Cache-Control: no-cache`,
  `X-Accel-Buffering: no` (`events.go:61-63`).
- **On connect:** the comment line `: connected` and a blank line, flushed (`events.go:66-67`).
- **Keep-alive:** the comment line `: keepalive` and a blank line, flushed, from a
  `time.NewTicker(15 * time.Second)` (`events.go:68`, `:77-79`). **Every 15 seconds.**
- **A notice:** `fmt.Fprintf(w, "data: %s\n\n", what)`, flushed (`events.go:74-76`). **One `data:`
  line and a blank line. No `event:` line, no `id:` line, no `retry:` line** — the handler writes
  nothing else anywhere. Line endings are `\n`, never `\r\n`.
- **The two words** are constants: `channels`, `collections` (`events.go:16-19`).
- The request-logging wrapper does not break streaming: `statusWriter` forwards `Flush()`
  (`main.go:166-168`). It writes its `HTTP` log line **only when the handler returns**
  (`main.go:176-181`), so **a connected listener is invisible in `GET /api/logs` until it
  disconnects.**

### 2.2 Which actions send which word (read)

`a.evt.notify` is called in **nine places in all of `cmd/marlin-dvr`** (grep over all 30 files), and
nowhere else:

| Word | `file:line` | Action |
|---|---|---|
| `channels` | `sources.go:1042` | `PUT /api/sources/{id}/lineup/{guid}` — a channel's number, name, hidden or favourite override saved (`sources.go:999-1044`) |
| `channels` | `sources.go:733` | `reloadSource` — a lineup re-imported: the Reload button (`sources.go:941-949`), Add Source, an Edit Source that reloads (`sources.go:904-908`), and the server's own daily M3U refresh (`main.go:551-553`). **Sent whether or not the lineup differs** |
| `channels` | `sources.go:779`, `:804` | Add Source — HDHomeRun, M3U |
| `channels` | `sources.go:892` | `PUT /api/sources/{id}` — a source's settings saved, enable / disable and rename included |
| `channels` | `sources.go:936` | `DELETE /api/sources/{id}` |
| `collections` | `collections.go:126` | `POST /api/collections` — created |
| `collections` | `collections.go:174` | `PUT /api/collections/{id}` — name, icon, members or their order |
| `collections` | `collections.go:200` | `DELETE /api/collections/{id}` |

Three consequences, all in the contract (`HLS-CLIENT-API.md:648-657`) and all confirmed in source:

- **One action can send `channels` twice within a millisecond or two**: Add Source (M3U) calls
  `reloadSource` (`:798` → `:733`) and then notifies again itself (`:804`); an Edit Source that
  reloads notifies at `:892` and again through `:905` → `:733`.
- **A `channels` change is never also announced as `collections`**, although a collection's
  resolved members are rebuilt against the current channel list on every read
  (`collections.go:69-87`), so `GET /api/collections`' `channels`, `count` and `isDead` can differ
  after it.
- **`sources.go:1042` is this app's own favourite write.** The Guide's hold-to-favourite and the
  Player panel's Favorite both call `PUT /api/sources/{id}/lineup/{guid}`
  (`ServerWrites.swift:221-222`, from `ChannelActionsMenu.swift:87` and `PlayerInfoPanel.swift:595`).
  **So this app's own favourite press will come back to it as a `channels` notice, and go to the
  other Apple TV too.**

### 2.3 Does the server close idle or long-lived connections? (read)

**No.** The handler's loop ends only on `r.Context().Done()` — the client's connection going away
(`events.go:72-73`). The server is built as
`&http.Server{Handler: a.routes(), ReadHeaderTimeout: 10 * time.Second}` (`main.go:460`): **no
`WriteTimeout`, no `IdleTimeout`, no `ReadTimeout`**, so nothing in `net/http` cuts a long response
either. The stream ends from the server's side only when the server stops: SIGINT / SIGTERM runs
`a.shutdown` then `srv.Close()` (`main.go:464-472`), and an owner-pressed update takes the same
`shutdown` path (`main.go:480-484`). **`srv.Close()` cuts connections with no goodbye**
(`HLS-CLIENT-API.md:664-667`).

### 2.4 Any client limit? (read)

**None.** `subscribe()` adds a channel to a map with no cap (`events.go:42-52`); the code comment
says "no subscriber limit" (`events.go:14`); every subscriber gets every notice
(`events.go:31-40`). **The one limit is per connection: a 64-notice buffer**
(`events.go:43`). `notify` sends with `select … default:` (`events.go:34-37`), so a notice that does
not fit is **dropped for that connection only, silently, and the connection stays open**.
**No replay**: nothing is stored, and `Last-Event-ID` is not read — the handler reads no header at
all.

### 2.5 The shapes of the two lists (read)

**`GET /api/channels?source=&filter=&hidden=1`** — `main.go:264`, `sources.go:1047-1062`:
`{"channels": [MergedChannel], "count": int, "sources": [string]}` (`sources.go:1061`). Without
`hidden=1` the list is `filterChannels` (`sources.go:1053`), which starts from `a.channels(false)`
(`sources.go:368`) — **hidden channels are left out** (`sources.go:324-326`) and disabled sources
skipped (`sources.go:318-320`). Order: by number, numerically then as text
(`sources.go:344-349`). `MergedChannel` is sixteen JSON fields (`sources.go:103-122`): `id`
(`"<sourceId>:<guid>"`, `sources.go:328`), `sourceId`, `source`, `guid`, `number`, `name`,
`origNumber`, `origName`, `logo`, `hd`, `drm`, `hidden`, `favorite`, `initials`, `logoBg`, and
`tvgId` with `omitempty`; `URL` and `SortKey` are `json:"-"`.

**`GET /api/collections`** — `main.go:272`, `collections.go:90-99`:
`{"collections": [resolvedCollection]}`. Each is the stored `Collection` — `id`, `name`, `icon`,
`channelIds` (`collections.go:12-17`) — plus `channels` and `count` (`collections.go:63-67`).
`channelIds` is never null (`collections.go:75-77`). Each member of `channels` is
`{id, isLive: true, isDead: false, name, number, initials, logoBg, source}` when the id resolves and
`{id, isLive: false, isDead: true}` when it does not (`collections.go:78-85`). Order is the order of
`data/collections.json`.

**The Guide's rows come from neither.** `GET /api/guide` builds its rows from the same
`filterChannels(source, filter)` (`guide.go:671`) and **embeds the whole `MergedChannel` in every
row** — `guideRow{MergedChannel: c, Blocks: blocks}` (`guide.go:713`). With a collection as the
filter, the rows come back in the collection's own order (`sources.go:398-410`); **an unknown filter
applies no predicate and returns every visible channel** (`sources.go:371-373`, `:378-396`).

---

## 3. The running server (measured, 2026-09-19 23:47–23:48 −0400)

Four GETs and nothing else.

**`GET /api/status` — the server is 1.10.0:**

```
HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json
Date: Sun, 20 Sep 2026 03:47:37 GMT
Content-Length: 75

{"name":"marlin-dvr","version":"1.10.0","uptime_seconds":2708,"port":8089}
```

**`GET /api/events`, `curl -sS -N -i --max-time 30`, started 23:47:44, ended 23:48:14:**

```
curl: (28) Operation timed out after 30004 milliseconds with 26 bytes received
http_code=200 time_total=30.004659s size=26B http_version=1.1
```

curl's exit 28 is this pass's own 30-second limit closing the connection, not the server. The raw
bytes, headers included:

```
HTTP/1.1 200 OK
Cache-Control: no-cache
Content-Type: text/event-stream
X-Accel-Buffering: no
Date: Sun, 20 Sep 2026 03:47:44 GMT
Transfer-Encoding: chunked

: connected

: keepalive

```

```
000000a0: 640d 0a0d 0a3a 2063 6f6e 6e65 6374 6564  d....: connected
000000b0: 0a0a 3a20 6b65 6570 616c 6976 650a 0a    ..: keepalive..
```

**The body is exactly 26 bytes**: `: connected\n\n` (13) and one `: keepalive\n\n` (13). Line
endings inside the body are bare `0a`. **HTTP/1.1, chunked, no `Content-Length`.** No `data:` line
arrived — nothing was changed on the server during those 30 seconds, by anyone. One keep-alive in
30 s is what a 15 s ticker gives: the second fell due at the 30 s mark, where the connection was
closed. **The arrival time of the keep-alive was not recorded**, so "15 s" is the source's number
(`events.go:68`), consistent with this capture and not timed by it.

**`GET /api/channels`** — 200, `application/json`, 88,876 bytes.
**`GET /api/collections`** — 200, `application/json`, 17,269 bytes.

Shapes, from a key-and-type census of both bodies (the bodies themselves are not reproduced):

- `/api/channels` top level: `channels` (list), `count` (int), `sources` (list). `count` 236 =
  `len(channels)` 236; 7 sources. **All 15 non-optional `MergedChannel` keys are present in 236 of
  236 rows** with the types `sources.go:103-122` declares; `tvgId` is present in 227. `hidden` is
  true on 0 rows, as `filterChannels` promises; `favorite` on 4; `drm` on 0; `hd` on 93; `logo` is
  empty on 1. No value is null anywhere.
- `/api/collections` top level: `collections` (list), 3 of them — "Local" (12 members), "History"
  (10), "SY-FY" (69). Each carries exactly `channelIds`, `channels`, `count`, `icon`, `id`, `name`;
  ids have the shape `col-<13 digits>`. **All 91 members carry the full eight-key live form; none is
  dead.**

**Redaction.** One source's name and its `sourceId` — and so the `id` of each of its 9 channels —
embed the HDHomeRun's device ID. They are written here as `<device id>` where they would appear and
nowhere reproduced. No client id was sent or received by any of the four requests.

---

## 4. The Guide today (traced, at `861e50e`)

### 4.1 Every request, and when it fires

| When | What fires | `file:line` |
|---|---|---|
| **Screen open** | `.task` → `loadNow()` → `fetch(from:)`, which sends **`GET /api/guide?slots=48&start=<this half hour>[&filter=<collection id>]` and `GET /api/schedule` together** | `GuideScreen.swift:437-438`, `:127-131`, `:208-211`; query built at `ChannelFilter.swift:61-66` |
| Screen open, per row | one `GET /api/art/feed?u=…` for each row with a `logo`, through `AsyncImage` | `GuideScreen.swift:858-864`, `:887-893`; `ServerImage.swift:20`. The rows are a plain `VStack`, not lazy (`GuideScreen.swift:376-377`), so every row is built at once |
| **Return from the rail** | **Nothing, if no other screen was chosen**: the content is keyed `.id(current)` (`ScreenShell.swift:57`) and `current` is the destination (`ScreenShell.swift:39`), which a swipe into the rail and back does not change. **Choosing another screen and coming back builds a new `GuideScreen` and a new `GuideModel`** (`GuideScreen.swift:318`), which is "screen open" again | as cited |
| **Collections button pressed** | the overlay's `.task` → `model.load()` → **`GET /api/collections`**, then `reconcile()` | `GuideCollections.swift:182-185`, `:80-91`, `:99-107` |
| **Collection pick** | `pick` → `collections.select` (writes `UserDefaults`) → `reloadForCollection()` → `fetch(from: windowStart)` → **`GET /api/guide` + `GET /api/schedule`**, the window not moved; then focus goes to the first cell | `GuideScreen.swift:624-631`, `:197-199`; `GuideCollections.swift:69-77` |
| **The half-hour roll** | the once-a-minute beat → `tick()`; **a request only if the rolled window leaves the fetched range** — with 48 slots fetched and a 4-slot window, about 22 hours after the fetch | `GuideScreen.swift:446-451`, `:582-588`, `:187-193` |
| **The 45-slot refetch** | `nudgeForward()`: `if windowEnd > fetchEnd { fetch(from: windowStart) }` — 44 nudges stay inside 48 slots, the 45th refetches **`GET /api/guide` + `GET /api/schedule`** | `GuideScreen.swift:160-167` |
| "+12h" | `pageForward()`, same rule | `GuideScreen.swift:133-137` |
| "↩ Now" and Menu off-now | `snapToNow()`, a request only outside the fetched range | `GuideScreen.swift:201-206`, `:473-477`, `:667-671` |
| Airing sheet | on open, `GET /api/schedule` through `refreshSchedule()` and `GET /api/passes`; after each of its writes, `GET /api/schedule` again | `AiringSheet.swift:161-169`, `:330`, `:361`, `:379`, `:421`; `GuideScreen.swift:266-272`, `:429-432` |
| Hold on a channel cell | **a write**: `PUT /api/sources/{id}/lineup/{guid}` | `ChannelActionsMenu.swift:87`; `ServerWrites.swift:221-222` |

`APIClient` does no caching of its own and no retries (`ServerAPI.swift:5-8`).

### 4.2 Where each on-screen part comes from

- **The rows and their order** — `rows = g.channels` de-duplicated, from `GET /api/guide`
  (`GuideScreen.swift:210-218`), after the DRM rule (`ChannelFilter.swift:66-67`). The order is the
  server's: by number for All Channels, the collection's own order for a collection (§2.5). Drawn by
  `ForEach(model.rows)` (`GuideScreen.swift:377`), keyed by channel id (`Models.swift:130`).
- **The channel cell's number, name and logo** — the `MergedChannel` flattened into that same guide
  row (`Models.swift:126-138`): `channel.name` (`GuideScreen.swift:815`), `channel.number`
  (`:824`), `channel.logo` through `GuideChannelTile` (`:812`, `:858`), with `initials` and `logoBg`
  for the fallback tile (`:880`).
- **The favourite ★** — `model.favourite(row.channel)` (`GuideScreen.swift:381`), which is
  **`favouriteOverrides[channel.id] ?? channel.favorite`** (`:256-258`). The override is written by
  this screen's own hold menu (`:260-262`, `:414-415`). **Its comment says "until the next fetch"
  (`:253`), but nothing ever clears it** — `favouriteOverrides` appears on three lines of the whole
  app, `:254`, `:257`, `:261`, and `fetch` (`:208-234`) is not one of them. It lives as long as the
  `GuideModel` does.
- **The collections button's label** — `collections.buttonLabel`, `selectedName ?? "All Channels"`
  (`GuideScreen.swift:657`; `GuideCollections.swift:66`), restored from the `UserDefaults` key
  `"marlinGuideCollection"` at launch (`GuideCollections.swift:33`, `:57-62`).
- **The collections button's list** — "All Channels", then `model.collections` by `name` only, in
  the server's order (`GuideCollections.swift:141-147`, `:160-169`), from the `GET /api/collections`
  the overlay sends when it opens.
- **The current pick** — `GuideCollectionsModel.selectedId` / `selectedName`
  (`GuideCollections.swift:44-46`), owned above the shell (`Marlin_DVR_TVApp.swift:24`, `:32`;
  `ScreenShell.swift:31-32`), read by every fetch (`GuideScreen.swift:210`). **It is checked against
  the server only when the overlay opens** — `reconcile()` is called from `load()` and from nowhere
  else (`GuideCollections.swift:85`, `:99`).

### 4.3 Who reads `GET /api/channels` and `GET /api/collections` today

**The Guide does not read `GET /api/channels` at all.** Every channel fact on its screen arrives
inside `GET /api/guide`'s rows (§4.2). Its only read of `GET /api/collections` is the overlay's.

- `GET /api/channels` (`ChannelFilter.swift:43-49`): `FavoritesScreen.swift:36`,
  `GuideSearchScreen.swift:154`, `OnNowScreen.swift:75`, `HomeView.swift:36`,
  `PlayerInfoPanel.swift:407`, `PlayerInfoPanel.swift:471`.
- `GET /api/collections` (`ChannelFilter.swift:76-79`): `GuideCollections.swift:84` (the Guide's
  overlay), `OnLaterScreen.swift:185`.
- `GET /api/events`: **nothing.** The string does not occur in the app target.

### 4.4 Do the decoders match what step 3 returned?

**Yes, by a field-by-field comparison — the Swift decoder itself was not run.**

- `MergedChannel` (`Models.swift:16-33`) declares the same sixteen fields as `sources.go:103-122`,
  fifteen non-optional and `tvgId: String?`. Step 3 found all fifteen present with matching types in
  236 of 236 rows and `tvgId` in 227, no nulls.
- `ChannelsResponse` (`Models.swift:35-39`) — `channels`, `count`, `sources` — all present.
- `ChannelCollection` (`Models.swift:53-57`) decodes `id`, `name`, `channelIds` only, all three
  present on all 3 collections; `CollectionsResponse` (`Models.swift:59-61`) matches. `icon`,
  `channels` and `count` are in the answer and deliberately not decoded (`Models.swift:43-46`).

---

## 5. What a notice means for the Guide (traced)

### 5.1 What must be re-read for the screen to change

- **A `channels` notice → `GET /api/guide`, with the current filter.** Rows, order, number, name,
  logo and favourite all come from it (§4.2). **Re-reading `GET /api/channels` — what the owner's
  rule names — changes nothing on the Guide's screen, because the Guide never reads it** (§4.3).
  What each server action does to the grid: hide / unhide adds or removes a row
  (`sources.go:324-326`); a renumber re-orders the rows under All Channels (`sources.go:344-349`) and
  not inside a collection (`sources.go:398-410`); a rename changes the name and the fallback tile; a
  disabled or removed source takes its rows away; a re-import can change any of these.
  **One case will not redraw even then:** a channel this Guide visit has itself favourited or
  unfavourited keeps the override (§4.2), so a later favourite change to that channel made on the
  server is masked until the Guide is left and re-entered.
- **A `collections` notice →**
  - with **a collection picked**: `GET /api/collections` and `reconcile()` **first**, then
    `GET /api/guide?filter=<id>`. The order matters: if the picked collection was deleted, the server
    answers the now-unknown filter with every visible channel (§2.5), and only `reconcile()`
    (`GuideCollections.swift:99-107`) turns the button back to "All Channels" — it also picks up a
    rename (`:106`). A change to that collection's members or order changes the rows.
  - with **All Channels picked**: nothing on the grid can change. Only the overlay's list, and only
    if it is open.
- **A connect or reconnect → both**, in that same order, since no missed notice is replayed
  (`HLS-CLIENT-API.md:658-660`). On the **first** connect after the Guide opens, `loadNow()` has
  just read the rows (`GuideScreen.swift:438`); what it has not done is check the pick, which today
  waits for the overlay (§4.2).

### 5.2 Does re-reading both lists on any notice change anything for the Guide?

**Nothing the owner could see.**

- After `channels`, `GET /api/collections` cannot differ in any field this app decodes: `id`, `name`
  and `channelIds` are the stored collection (`collections.go:12-17`), and only the undecoded
  `channels` / `count` are rebuilt from the channel list (`collections.go:69-87`;
  `Models.swift:43-46`). The overlay shows names only (`GuideCollections.swift:162`).
- After `collections`, the channel list does not change, and with All Channels picked neither do the
  rows.

**So the choice is about code and cost, not about the screen.** One path for every notice and for
reconnect — collections, reconcile, then rows — is simpler and cannot get the order wrong; its price
is one 17 KB `GET /api/collections` on every `channels` notice and one `GET /api/guide` +
`GET /api/schedule` on a `collections` notice that did not need it. **The size of `GET /api/guide`
at 48 slots over 236 channels was not measured in this pass** — it is not one of step 3's four GETs.

### 5.3 What an in-place redraw could disturb

An in-place redraw is what `reloadForCollection()` already is: `fetch(from: windowStart)` replaces
`rows` wholesale and leaves `windowStart` alone (`GuideScreen.swift:197-199`, `:218`).

- **Focus.** Focus ids are `"ch:<channel id>"` and `"<channel id>@<program start>"`
  (`GuideScreen.swift:311`, `:72`) and the rows are keyed by channel id, so **a row that survives
  keeps its identity and its focus** — the same thing the roll and the nudge rely on
  (`:598-609`, `:548-563`). **A focused row that disappears** (hidden, source removed, dropped from
  the picked collection) takes the focused view with it, and nothing today repairs that for a
  channel cell: `settleFocusAfterRoll` handles programme cells only and leaves a channel cell alone
  (`:596-600`). Its fallback is `firstCellID ?? "collections"` (`:606`) — the top of the grid.
  `pick()`'s own rule — always focus the first cell (`:630`) — would throw focus to the top on every
  notice and is the wrong one to reuse. With the remote in the rail this screen's `focused` is nil
  and nothing should be written (`:596-597`). **Unknown, and only a television can say:** whether the
  grid's `ScrollView` follows a focused row that a renumber has moved to another position.
- **A scrolled window.** Safe. `fetch(from: windowStart)` never writes `windowStart`
  (`GuideScreen.swift:208-234`), so the time strip, the rows and the header stay where they are. It
  does reset `fetchStart` to the window's start (`:219`), exactly as a collection pick does today;
  "↩ Now" then finds itself outside the fetched range and refetches (`:205`). The **vertical**
  scroll position belongs to the `ScrollView`, which is not rebuilt; a row added or removed above the
  visible ones shifts the content by 94 pt a row (82 + 12, `:353`, `:376`).
- **The collection pick.** It survives — it lives above the screen and in `UserDefaults` (§4.2).
  `reconcile()` changes it on purpose: **a deleted pick reverts to All Channels silently**
  (`GuideCollections.swift:93-104`), which with live notices would happen in front of the owner, the
  grid going from the collection to every channel with no message.
- **An open airing sheet.** The sheet holds value copies — `AiringSelection` is a `channel`, a
  `program` and a `job` (`AiringSheet.swift:32-37`) — so its own content does not change. The grid
  under it is `.disabled` (`GuideScreen.swift:393`). **The hazard is the one Pass 79 already wrote
  down for the clock**: a change underneath "could leave the sheet's own Menu restoring focus to a
  cell that no longer exists" (`:577-581`) — Menu does `focused = lastCell` (`:468-472`). The beat's
  answer is to do nothing while an overlay is up (`:583`) and let the next minute's beat catch up.
  **A notice has no next beat**, so the same guard needs something to remember that a redraw is owed.
- **The open collections overlay.** `load()` sets `loading = true` (`GuideCollections.swift:81`), and
  while it is true the overlay **replaces every collection row with a loading line**
  (`:157-158`). Calling it while the overlay is open would pull the focused row out from under the
  remote and put it back a moment later. Beyond that, the list itself can change under the owner — a
  row renamed, added, or the focused one deleted — and "Showing" moves if `reconcile()` reverts the
  pick (`:143`, `:163`).
- **The hold menu (not in the prompt's list, but it is this screen's third overlay).**
  `ChannelActionsMenu` holds a `MergedChannel` copy (`GuideScreen.swift:409-420`), closes to
  `"ch:<id>"` (`:634-638`) — the same missing-cell hazard — **and its own write is the one that
  echoes back as `channels`** (§2.2), arriving within milliseconds of the `PUT` returning, before or
  after the menu has closed.
- **The Player on top.** The Player is a `fullScreenCover` on the root (`ContentView.swift:53-60`);
  the Guide stays alive under it and its `.task` keeps running — COLD-START already records "the beat
  continuing behind the Player". A notice would redraw the Guide unseen, and it would be current when
  the Player comes down. None of the Guide's three overlay guards is set by the Player, so nothing
  defers it. The Guide's `focused` is expected to be nil under the cover, in which case no focus
  write happens; **whether a `@FocusState` write under a cover could disturb the Player's focus was
  not tested and is avoided only by never writing one when `focused` is nil.** Playback itself is not
  touched: a channel hidden or removed while it is playing is outside this goal.

---

## 6. Long-lived connections, and what a stream reader needs (traced)

### 6.1 Does the app hold a long-lived connection today?

**No.** Every server call is a whole-body request and answer: `APIClient.send` awaits
`session.data(for:)` (`ServerAPI.swift:116`) on `URLSession.shared` (`ServerAPI.swift:66`;
`Marlin_DVR_TVApp.swift:27`). What looks continuous is polling on a timer: the Player's keep-alive
every 10 s (`PlaybackSession.swift:29`, `:130`; `PlayerModel.swift:678-690`), On Now's reload loop
(`OnNowScreen.swift:167-171`), Cameras (`CamerasScreen.swift:98`), Radar
(`RadarScreen.swift:95`, `:111`, `:151`), and the Guide's beat, which is a local clock
(`GuideScreen.swift:446-451`). The longest single request is the file route's first byte, up to
660 s, on its own `URLSession` (`PlaybackSession.swift:37`, `:51-54`). The only long-lived network
streams are AVFoundation's own media loads (`PlayerModel.swift:198`; `RadioPlayer.swift:113-114`),
which the app's networking code does not hold. **The app handles `scenePhase` or backgrounding in two
places only** — the Player dismisses (`PlayerScreen.swift:30`, `:86-88`) and the radio stops
(`RadioPlayer.swift:86-92`) — and nowhere at app level.

### 6.2 What a stream reader needs on tvOS 18.0

The deployment target is tvOS 18.0 in both configurations (`project.pbxproj:250`, `:305`).

1. **A different call.** `data(for:)` returns when the body ends, and this body never does, so
   `APIClient.get` (`ServerAPI.swift:71-75`, `:112-132`) can never serve it. The reader needs
   `URLSession.bytes(for:)` and its `.lines`, available since tvOS 15 and so unconditionally at
   18.0. **`AsyncBytes.lines` is understood not to yield empty lines** *(from Apple's documentation
   and known behaviour, not verified here)*. For this server that costs nothing: every notice is one
   complete `data:` line (`events.go:75`), so the blank line that ends an event never has to be
   seen. A line starting `:` is a comment (`events.go:66`, `:78`); a line that is exactly
   `data: channels` or `data: collections` is a notice; anything else is ignored.
2. **The response must be checked before reading lines.** A server older than 1.10.0 answers
   **404 "no such API route"** (`main.go:356-358`; `HLS-CLIENT-API.md:601-603`), and that body would
   otherwise be read as lines.
3. **Timeouts.** `URLSession.shared` is used unconfigured (`ServerAPI.swift:66`), so it carries the
   platform defaults: **`timeoutIntervalForRequest` 60 s and `timeoutIntervalForResource` 7 days**
   *(from Apple's documentation, not verified here)*. The 60 s one is an idle timer that restarts
   whenever bytes arrive, so the server's 15 s keep-alive (`events.go:68`) keeps a healthy stream
   alive for ever, **and a dead network is noticed about 60 s after the last keep-alive** — which is
   the only way it can be noticed, since the server sends no goodbye (§2.3). The 7-day one would cut
   a stream that old; the reader reconnects, which it must be able to do anyway. This project already
   has a precedent and a warning: the file route got **its own `URLSession`** because "a
   configuration's value can override a longer per-request one" (`PlaybackSession.swift:46-54`).
4. **A session of its own, for a second reason.** The stream is HTTP/1.1 (§3), and a `URLSession`
   limits simultaneous connections per host — **`httpMaximumConnectionsPerHost`, 4 by default on
   Apple's non-Mac platforms** *(from Apple's documentation, not verified here, and not confirmed
   for tvOS specifically)*. On `.shared` a permanent stream would hold one of those against every
   other request to `192.168.1.250:8090`, the Guide's logo loads included (§4.1).
5. **No new permission.** Plain HTTP to the LAN is already allowed by `NSAllowsLocalNetworking`
   (`Info.plist:7-11`), which every existing call depends on.
6. **Reconnect, and its trigger.** The reader must loop: connect; on HTTP 200, report "connected";
   read lines until the sequence ends or throws; wait; connect again. **Every successful connect is
   the "re-read both lists" moment**, first or not, because nothing is replayed. tvOS suspends a
   backgrounded app and the socket dies with it; nothing at app level watches for that today (§6.1),
   so without a `scenePhase` hook a return to the foreground is noticed only by the idle timer.
7. **Cancellation.** Cancelling the task that iterates `bytes.lines` ends the request; the server
   sees `r.Context().Done()`, returns, and its deferred `cancel()` removes the subscriber
   (`events.go:64-65`, `:72-73`). A reader tied to a SwiftUI `.task` therefore cleans up on both
   sides when its view goes — the same lifetime rule the Guide's clock already uses
   (`GuideScreen.swift:440-444`).

---

## 7. Build plan — this goal only

**The goal:** the Guide redraws on screen when a channel or collection changes on the server, without
backing out and back in; on reconnect both lists are re-read. How Guide listings, recordings and
passes update stays exactly as it is.

### 7.1 Files and changes

**1. New file `Marlin DVR TV/ServerEvents.swift` — the stream reader.** Both source folders are
Xcode synchronized groups (`project.pbxproj:15-16`), so a new file needs **no project-file edit**.

- Its own `URLSession` (§6.2 items 3–4): `timeoutIntervalForRequest` 45 s — three keep-alives —
  `requestCachePolicy = .reloadIgnoringLocalCacheData`, used for nothing else.
- `events() -> AsyncStream<ServerEvent>`, with `ServerEvent` being `.connected`,
  `.notice(.channels)` or `.notice(.collections)`. Inside, the loop of §6.2 item 6: `GET /api/events`
  through `bytes(for:)`; a status other than 200 is a failed connect; on 200 yield `.connected`; for
  each line, `data: channels` / `data: collections` yields a notice and everything else is ignored.
  When the sequence ends or throws: wait 2 s, then 5 s, then 10 s, then 30 s for every attempt after
  that, back to 2 s after any successful connect; a 404 waits 60 s. Cancelling the consumer ends the
  loop and the request (§6.2 item 7).
- Console lines in the house style: `[events] connected`, `[events] channels`,
  `[events] collections`, `[events] lost: <error> — retry in N s`.

**2. `Marlin DVR TV/GuideCollections.swift` — a quiet re-read.** A new `refresh()` beside `load()`
(`:80-91`): the same `api.collections()` and `reconcile()`, **without touching `loading` or
`failed`**, so an open overlay's rows are not swapped for the loading line (§5.3). A failed quiet
read changes nothing and prints one line. `load()`, `select`, `reconcile()` and the overlay are
unchanged.

**3. `Marlin DVR TV/GuideScreen.swift`.**

- `GuideModel.fetch` (`:208-234`): clear `favouriteOverrides` when a fetch lands, which is what its
  own comment already says (`:253`). Without this, one named case of the goal — a favourite changed
  on the server — does not redraw (§5.1).
- A second `.task` on the screen, beside the clock's (`:437-453`), consuming
  `ServerEvents().events()`. It lives and dies with the screen, as the clock does
  (`ScreenShell.swift:57`), so **the stream is open only while the Guide exists** — on screen or
  behind the Player.
- One handler for every event. Events closer together than 300 ms collapse into one redraw, which
  covers the server's double `channels` (§2.2). A redraw is: `held = focused`;
  `await collections.refresh()`; `await model.reloadForCollection()` — the existing in-place refetch,
  window untouched; then settle focus. **The first `.connected` after the screen opens does the
  `refresh()` alone**, and the rows only if that changed the pick, because `loadNow()` has just read
  them (§5.1).
- Settling focus: `settleFocusAfterRoll`'s rule (`:598-609`), widened by one case — a held **channel
  cell** whose row has gone is treated like a held programme cell whose row has gone. Never
  `pick()`'s "first cell" rule, and no write at all when `held` is nil.
- The Guide's listings, marks and sheet reads are not changed. **One side effect cannot be
  avoided and is stated rather than hidden:** the rows and the listings are one response, and
  `fetch` always sends `GET /api/schedule` beside it (`:210-211`), so a notice also refreshes the
  listings and the ● / ◆ marks at that moment, by the mechanism that already exists.

**4. No change to** `ServerAPI.swift`, `ChannelFilter.swift`, `Models.swift`, `ScreenShell.swift`,
`ContentView.swift`, `Marlin_DVR_TVApp.swift`, the Player, the airing sheet, `ChannelActionsMenu`,
any other screen, the project file, or `design/`.

### 7.2 The one Home Theater run that would prove it

The builder cannot change anything on the server, so **the run needs the owner at the admin page**.
With the build installed by `launch()` and the launch ping confirmed (COLD-START, *Known and
unfixed*, the `activate()` trap):

1. Open the Guide on All Channels at now; move focus to a programme cell on a row well below the
   first, and leave the remote alone. Console: `[events] connected`.
2. **Owner renames one channel that is on screen.** Expected within about a second, no press:
   `[events] channels`, one `GET /api/guide`, the new name in that row, **focus on the same cell, the
   window label unchanged**.
3. Pick "History" (10 channels) and put focus on a row. **Owner removes another of its channels on
   the admin page, then adds it back.** Expected: `[events] collections` twice; the row goes and
   returns; focus does not move.
4. Press Home, wait, return to the app. Expected: `[events] lost`, then `[events] connected`, then
   the two re-reads, with nothing on screen moving.
5. Owner renames the channel back.

Proven by that run: both words, the redraw with no press, focus and the window held, and the
reconnect re-read. **Traced only, and to be said so:** a focused row disappearing; a deleted pick;
a renumber's re-order and what the scroll does; a notice under each of the three overlays; a notice
behind the Player; the app's own favourite echo; a double `channels`; a server stop; a pre-1.10.0
404. **One representative run, the rest traced**, as the owner set in Pass 79.

---

## Open questions

1. **`GET /api/channels` is what your rule names, and the Guide never reads it.** Its channel facts
   come inside `GET /api/guide` (§4.2–§4.3), so that is what the plan re-reads, with
   `GET /api/collections`. Is that what you want — and do you also want a literal `GET /api/channels`
   sent on a notice, whose answer nothing on the Guide would use? The plan does not send it.
2. **A notice while the airing sheet, the hold menu or the collections overlay is open.** The clock's
   rule is to do nothing under an overlay (`GuideScreen.swift:577-583`). For a notice that means
   remembering it and redrawing the moment the overlay closes — so with the sheet up, your change
   shows when you close the sheet. The other way is to redraw underneath and repair focus on close.
   **The plan in §7.1 does not yet say which**; nothing the goal names settles it.
3. **Where focus goes when the focused row disappears.** The screen's existing fallback is the first
   cell of the grid, which jumps to the top. The nearest surviving row is the alternative.
4. **A picked collection deleted on the server** reverts to All Channels silently today, when the
   overlay next opens. Live, it would happen in front of you with no message. Is silent still right?
5. **No server, or a server older than 1.10.0.** The plan retries quietly and draws nothing. Do you
   want anything on screen?
6. **Only the Guide listens, and only while it exists.** On Now, Favorites, Search, Home's count and
   On Later read the same two lists (§4.3) and are not in this goal. Recorded so it is a decision,
   not an omission.
7. **The proof run needs you at the admin page at a known moment**, and a harness would be a new
   test-target file. By harness, or by eye?
8. **COLD-START's line that `HLS-CLIENT-API.md` "still says 1.7.0"** (*The server*, third bullet) is
   out of date: at `0fa05e1` its header says 1.10.0 (`HLS-CLIENT-API.md:7`) and it runs to §12.
   **Whether it now documents `"format":"file"` was not checked**, so the line was left alone.
9. **The HDHomeRun's device ID is already in this repo's history** — `git grep` finds it in
   `DECISIONS.md` and at least nine earlier reports, inside channel ids. It is redacted here.
   History is never rewritten; raised only so it is known.

## The things least certain

1. **That a surviving focused row really keeps focus through a whole-`rows` replacement on a
   television.** It is how the roll, the nudge and the collection pick already behave, but a pick
   deliberately refocuses afterwards, so "focus simply stays" across a wholesale replacement has
   only ever been exercised by the roll and the nudge, which replace `rows` rarely.
2. **The three platform defaults in §6.2** — 60 s, 7 days, 4 connections per host — and that
   `AsyncBytes.lines` drops empty lines. All four are from Apple's documentation or common
   knowledge, none was measured, and the connection limit is not confirmed for tvOS.
3. **That tvOS kills the stream promptly on backgrounding**, which step 4 of the run depends on. If
   the socket lingers, the reconnect shows up to 45 s later instead.

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `reports/2026-09-19-pass115-events-recon.md` | 1–7 (written in 8) | new — this report |
| `DECISIONS.md` | 8 | appended the Pass 115 entry |
| `COLD-START.md` | 8 | *Where things live*: the reference-clone line replaced; *The server*: the version line brought to 1.10.0 and the reference-clone line replaced; *Next step*: a new paragraph on top, Pass 114's kept as history |

**Nothing else was written.** No app-target file, test-target file, project file, `design/` file or
`icon-source/` file changed. `~/Xcode/marlin-dvr-reference` does not exist, and no other lasting copy
of the server repo was made: the files fetched from GitHub and the four raw server answers lived in
the session scratchpad and were deleted before this report was written (§1). The source name and ids
that carry the HDHomeRun's device ID are not reproduced here.
