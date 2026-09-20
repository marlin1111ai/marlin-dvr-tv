# Pass 116 — the Guide redraws on server channel and collection changes

**Date:** 2026-09-19 → 2026-09-20 (the device runs are all on 2026-09-20, times −0400)
**Owner's words:** "all i want is when i do something in the server it gets refelcted on the atv right away"

**Result: built, and proven on Home Theater.** A channel renamed on the server was on the
television **within 0.26 s** of the write and a channel taken out of the picked collection **within
0.19 s**, with no remote press, focus on the same programme, the window and the pick unmoved. The
server's log shows the app answering each notice with `GET /api/collections` then `GET /api/guide`,
12–50 ms after the write, and **never `GET /api/channels`**. The reconnect is proven too: a trip to
the Home screen killed the stream and the app came back, reconnected after its 2 s wait and re-read
both, 2.2–2.3 s after returning.

**Committed, NOT pushed** — the owner tests first. **Home Theater runs this build; the bedroom Apple
TV does not** and was not touched.

**HEAD every app `file:line` below is read at is this pass's own commit.** Server `file:line` are at
marlin-dvr `0fa05e13927b202df469a430789df9c9683c73c4`, read from GitHub with `gh api` as Pass 115 did
— `main.go`, `sources.go` and `collections.go` this time, for the write routes — into the session
scratchpad and **deleted before this report was written** (`ls` of the folder and of
`~/Xcode/marlin-dvr-reference` both answer *No such file or directory*). Nothing was cloned.

## How each claim is labelled

- **run** — it happened on Home Theater or on this Mac in this pass, and the output is quoted.
- **traced** — reasoned from the code as built; nothing exercised it. §7 lists every one.

---

## 1. The three calls this was built to (the foreman's, 2026-09-20)

1. **On any notice, `channels` or `collections`, the Guide re-reads `GET /api/guide` — its current
   collection, its current window — and `GET /api/collections`. `GET /api/channels` is never sent.
   On connect and on every reconnect the same two reads happen.** The stream opens when the Guide
   appears and closes when it leaves; reconnect on Pass 115's numbers.
2. **The redraw is in place**: the window does not move, the pick is kept, a deleted pick reverts to
   All Channels silently as today. `favouriteOverrides` is cleared on every notice so the server's
   value wins. **A notice under the airing sheet, the hold menu or the collections overlay waits and
   runs the moment it closes.** Focus stays on the same programme when it survives; when its row is
   gone, focus goes to `firstCellID` as today.
3. **No notice reaches the server's log as a write; no notice is coalesced away** — one arriving
   during a re-read causes one more re-read after it; **loud failures**, no silent fallback except
   the reconnect itself.

These answer Pass 115's open questions 1–6. Two things they change from Pass 115 §7: the plan's
300 ms collapse of close-together notices is **gone** (call 3), and the first connect does **both**
reads, not the collections alone (call 1).

## 2. What was built

**`Marlin DVR TV/ServerEvents.swift` — new.** The stream reader. `events()` returns an
`AsyncStream<ServerEvent>` of `.connected` and `.notice(.channels | .collections)`, unbounded, so
nothing is dropped on this side of the wire. Its own `URLSession`: idle timeout **45 s** (three of
the server's 15 s keep-alives), resource timeout stated as 7 days, no cache. It checks the status
and the `Content-Type` before reading lines; reads `bytes.lines`; a `:` line is a comment, `data:
channels` / `data: collections` is a notice. **Every successful connect yields `.connected`.** When
the stream ends or throws it waits **2 s, 5 s, 10 s, then 30 s** for every attempt after that, back
to 2 s after any successful connect; **a 404 waits 60 s** and says the server is older than 1.10.0.
Cancelling the read ends the request. **Loud:** a non-200, a non-event-stream body and a line that is
none of the three kinds each print `[events] ERROR: …`. Every connection's end prints what it
carried — seconds, notices, comment lines, blank lines.

**`Marlin DVR TV/GuideCollections.swift` — `refresh()` (`:93-109`).** The same read and
`reconcile()` as `load()`, touching neither `loading` nor `failed`, which are the overlay's. A
failure prints `[collections] ERROR: …` and changes nothing. `load()`, `select`, `reconcile()` and
the overlay are unchanged.

**`Marlin DVR TV/GuideScreen.swift`.**

- `GuideModel.reloadForNotice()` (`:208-215`) — `fetch(from: windowStart, serverWins: true)`. `fetch`
  gained that one defaulted parameter (`:224`) and one line: **the overrides are dropped in the same
  turn the new rows are stored** (`:236`), not before, so a ★ this Apple TV has just set does not
  blink off while its own echo is answered. Every other caller of `fetch` is unchanged.
- A second `.task` (`:483-495`), beside the clock's, which is untouched. It waits for the first load
  to land, then reads `ServerEvents().events()` until the screen goes.
- `serverSaid` → `serverRedraw` (`:668-717`). One answer for every event. **If a re-read is running
  the notice is owed** and one more follows it; **if an overlay is open it is owed** and
  `.onChange(of: overlayOpen)` (`:496-499`) answers it the moment the overlay closes. Inside:
  `collections.refresh()` **first**, then `model.reloadForNotice()` — the order Pass 115 §5.1 gives,
  because `reconcile()` is what turns a deleted pick back into All Channels and the server answers an
  unknown filter with every channel.
- `settleFocusAfterRedraw` (`:737-752`) with `gridFocusExists` (`:721-726`): nothing is written
  unless something of the grid's lost its view. A programme that left a surviving row goes to that
  row's leftmost cell (Pass 77's rule); a row that is gone goes to `firstCellID ?? "collections"`.
  **No focus is written with the remote in the rail, and none while the Player is up**
  (`hold.suspended`). `lastGridFocus` (`:337`, `:502`) is what a redraw that waited for an overlay
  checks, since the overlay had the focus.

**Not changed:** `ServerAPI.swift`, `ChannelFilter.swift`, `Models.swift`, `ScreenShell.swift`,
`ContentView.swift`, `Marlin_DVR_TVApp.swift`, the airing sheet, `ChannelActionsMenu`, the Player,
every other screen, the project file (both folders are synchronized groups), `design/`.

**Builds.** Simulator: `** BUILD SUCCEEDED **`, first attempt. Home Theater `build-for-testing`:
`** TEST BUILD SUCCEEDED **` each time. **No warning in any file this pass touched.**

**One side effect, stated in Pass 115 and unchanged:** rows and listings are one response and `fetch`
always sends `GET /api/schedule` beside it, so a notice also refreshes the listings and the ● / ◆
marks at that moment, by the existing mechanism. And one from call 1: **every Guide open now reads
the guide twice** — `loadNow()`, then the on-connect pair.

---

## 3. The run that counts — two changes and their reversal (run)

### 3.1 Who made the changes

The pass as written had the owner make them on the admin page. The first attempt (00:31–00:57)
**timed out after its full 25 minutes with nothing changed** — the server's log held no `SRC` line
and no `PUT`, and showed another client watching recordings throughout; he was not at the admin
page (`run-owner-changes-timed-out.txt`). In the morning the foreman relayed:

> "Owner's call: he will not make the admin-page changes. Owner authorises you to make exactly these
> two writes on the server yourself, and their exact reversal, and nothing else: rename channel 6105
> "TLC" to "TLC LIVE", then back to "TLC"; remove channel 6108 "DIY" from the History collection,
> then add it back in the same position. Use the server's own routes as documented at 0fa05e1. Show
> every request and response, and confirm both are reverted before the commit, with a GET of each
> proving the original state."

Writing to the server is on `CLAUDE.md`'s do-not-touch list and the authorisation arrived as relayed
text, so **the four exact requests were shown to the owner and he chose "Yes, send those four"
himself** before the first was sent. **Four `PUT`s, and no other write, were sent by this project.**

Two facts the requests rest on, read before any write (07:48:39): there are **two** channels numbered
6105 named TLC, `philo:6105` and `verizon:6105`, and History holds the Philo one; and TLC had **no
name override** (`name` = `origName` = `mappedName` = "TLC"), so the true reversal is clearing the
override with `"name": ""` (`sources.go:1027-1029`), not writing "TLC" over it.

### 3.2 The four writes, every request and response

In full in `reports/assets/pass116/the-four-server-writes-and-the-proof.txt`. Routes:
`PUT /api/sources/{id}/lineup/{guid}` (`main.go:263`, `sources.go:999-1044`) and
`PUT /api/collections/{id}` (`main.go:274`, `collections.go:131-176`).

| | Sent | Request | Response |
|---|---|---|---|
| Change 1 | 07:50:29.928 | `PUT /api/sources/philo/lineup/6105` `{"name":"TLC LIVE"}` | `200` `{"name":"TLC LIVE","hidden":false,"favorite":false}` |
| Change 2 | 07:50:51.300 | `PUT /api/collections/col-1789211011169` — `channelIds`: the nine without `philo:6108` | `200`, the collection with those nine |
| Revert 1 | 07:53:21.833 | `PUT /api/sources/philo/lineup/6105` `{"name":""}` | `200` `{"hidden":false,"favorite":false}` — no `name` |
| Revert 2 | 07:53:38.560 | `PUT /api/collections/col-1789211011169` — the original ten, `philo:6108` last | `200`, `count` 10, none dead |

### 3.3 Leg 1 — the changes, `launch()`

`GuideLiveRedrawUITests/testOwnerChangesAreDrawnWithoutLeavingTheGuide`, **`** TEST EXECUTE
SUCCEEDED **`, passed in 322.296 s**. `launch()`; **the launch ping is `07:46:02.513 POST
/api/clients/<client id>/ping 200`**, found before any screenshot was believed. It opened the Guide,
picked History, parked focus on 6113 DISCOVERY-LIFE's programme cell, took `116a`, printed READY at
07:47:18, **and pressed nothing from there until both changes had been seen.**

```
P116 07:47:17.895 STANDING before: focus=["9:My 600-Lb. Life: Where Are They Now?"] window=Sun Sep 20 · 7:30 – 9:30 AM pick=History
P116 07:50:30.184 SEEN 6105 reads TLC LIVE
P116 07:50:32.203 STANDING after 6105 reads TLC LIVE: focus=["9:My 600-Lb. Life: Where Are They Now?"] window=Sun Sep 20 · 7:30 – 9:30 AM pick=History
P116 07:50:51.488 SEEN 6108 DIY has left History
P116 07:50:53.494 STANDING after 6108 DIY has left History: focus=["9:My 600-Lb. Life: Where Are They Now?"] window=Sun Sep 20 · 7:30 – 9:30 AM pick=History
P116 07:50:54.120 AFTER 6105=“TLC LIVE, 6105” 6108 exists=false
```

**The server's log for the same seconds:**

```
  3344 07:50:29.940 INFO SRC  lineup philo: channel 6105 updated (hidden=false favorite=false)
  3345 07:50:29.940 INFO HTTP PUT /api/sources/philo/lineup/6105 200
  3346 07:50:29.962 INFO HTTP GET /api/collections 200
  3347 07:50:29.990 INFO HTTP GET /api/guide 200
  3348 07:50:30.045 INFO HTTP GET /api/schedule 200
  3349 07:50:51.313 INFO SRC  collection updated: History (9 channels)
  3350 07:50:51.313 INFO HTTP PUT /api/collections/col-1789211011169 200
  3351 07:50:51.325 INFO HTTP GET /api/collections 200
  3352 07:50:51.335 INFO HTTP GET /api/guide 200
  3353 07:50:51.399 INFO HTTP GET /api/schedule 200
```

**Write to the app's first re-read: 22 ms and 12 ms. Write to on the screen: ≤ 0.26 s and ≤ 0.19 s**
— the harness looks every half second, so those are ceilings. Both reads each time, collections
first; **no `GET /api/channels`**. The Guide was never left: its legend was on screen at each check.

**Screenshots.** `116a` before; `116b` — the sixth row reads "TLC LIVE"; `116c` — DIY's row is gone.
**The focus ring is on the same programme in all three.** In `116c` it sits one row lower on the
screen than in `116b`: the list below it got a row shorter and the scroll view settled; the focused
cell is the same one.

### 3.4 Leg 2 — the reversals, with the app's console attached

The app's `print` lines cannot be read from a process XCUITest launched, so — Pass 38's method — the
app was started at 07:51:45 by `xcrun devicectl device process launch --device "Home Theater"
--console --terminate-existing com.marlin1111.MarlinDVRTV` (**its own launch ping:
`07:51:46.215`**) and `testPutBacksWithTheConsoleAttached` drove that process, calling **neither
`launch()` nor `activate()`**. **`** TEST EXECUTE SUCCEEDED **`, passed in 237.732 s.**

**The app's own console, in order:**

```
[events] connected
[guide] server: connected -> re-read · All Channels · rows=236 · Sun Sep 20 · 7:30 – 9:30 AM
[guide] collection History rows=9 refocus=philo:6044@1789902000
[events] channels
[guide] server: channels -> re-read · History · rows=9 · Sun Sep 20 · 7:30 – 9:30 AM
[events] collections
[guide] server: collections -> re-read · History · rows=10 · Sun Sep 20 · 7:30 – 9:30 AM
[events] lost: The request timed out. after 169 s · 2 notice(s) · 7 comment line(s) · 0 blank line(s)
[events] retry in 2.0 seconds
[events] connected
[guide] server: connected -> re-read · History · rows=10 · Sun Sep 20 · 7:30 – 9:30 AM
```

The server's log pairs each with its reads: revert 1's `SRC` line `07:53:21.848` → `GET
/api/collections` `.863`, `GET /api/guide` `.874`; revert 2's `07:53:38.575` → `.587`, `.600`. The
harness saw "TLC" again at `07:53:22.193` and DIY back at `07:53:38.850`, focus, window and pick
unmoved both times.

**One honest limit of this leg's pictures: `116g` and `116h` are byte-identical.** DIY came back as
the row *below* the focused bottom row, under the fold, and a list does not scroll by itself — so the
picture did not change at that moment. That the Guide held the row is the accessibility tree (`6108
exists=true`), the console's `rows=10`, and **`116i`**, taken after the trip to Home, where DIY is on
screen again and which is **byte-identical to `116a`**, the state before any write.

### 3.5 Both reverted — a GET of each, 07:56:12

```
> GET /api/channels
< {"id": "philo:6105", "number": "6105", "origNumber": "6105", "name": "TLC", "origName": "TLC", "hidden": false, "favorite": false}
< count: 236
> GET /api/sources/philo/lineup   (row 6105)
< {"guid": "6105", "number": "6105", "name": "TLC", "mappedNumber": "6105", "mappedName": "TLC", "hidden": false, "favorite": false}
> GET /api/collections   (History)
< {"id": "col-1789211011169", "name": "History", "icon": "ph-stack", "channelIds": ["philo:6044", "philo:6101", "philo:6110", "philo:6106", "philo:6112", "philo:6105", "philo:6107", "philo:6111", "philo:6113", "philo:6108"], "count": 10}
< channelIds identical to the list read at 07:48:39 before any write: True  · dead members: 0
< collections: [('Local', 12), ('History', 10), ('SY-FY', 69)]
```

**Every read is what it was before the first write.** One residue cannot be seen or removed through
the API and the owner was told before he said yes: the Philo lineup file may now keep an empty
override entry for 6105 (`hidden: false, favorite: false`). His own rename-and-back on the admin page
would leave the same.

### 3.6 No notice reached the server as a write

Every non-GET in leg 1's window (seq 3012–3584): the app's launch ping; **two `POST
/api/clients/…/ping` at 07:46:16 and 07:46:18 that are the owner's browser opening the admin pages**
(they sit inside its static-file requests); and this pass's two `PUT`s. Leg 2's window: the launch
ping and the two `PUT`s. **After each of the four notices the log holds GETs and nothing else.** The
admin page's own traffic in that window — static files, `/api/chrome`, `/api/dashboard`, a 15 s
`/api/system` + `/api/update` poll and **two `GET /api/settings`** — is the owner's browser; **this
project sent none of those** and has never read `/api/settings`.

---

## 4. The reconnect (run)

**Under a test session a trip to Home does not end the stream.** `testReconnectReReadsBoth`,
`launch()` (ping `00:14:43.217`), passed in 206.893 s: Home at 00:15:29.5, back at 00:16:44.7 — and
the server's log holds **one** `GET /api/events 200` line for the whole run, at `00:18:06.293`, when
the test ended. The server writes that line only when a connection closes (`main.go:176-181`), so one
connection lived through 75 s on the Home screen, no reconnect happened and nothing was re-read on
return. **That is an artefact of the test session**, as the next run shows.

**Launched outside one, it does.** `testTripToHomeWithTheConsoleAttached`, the app started by
`devicectl … --console` at 00:58:22 (ping `00:58:23.213`), passed in 194.092 s:

| Time | From | What |
|---|---|---|
| 00:58:52.613 / .623 | server | the on-connect pair — `GET /api/collections`, `GET /api/guide` |
| 00:59:19.981 | harness | Home pressed |
| **00:59:23.369** | server | `GET /api/events 200` — **the connection closed 3.4 s after the press** |
| 01:00:35.227 | harness | back in the app |
| 01:00:35 | console | `[events] lost: The request timed out. after 102 s · 0 notice(s) · 3 comment line(s) · 0 blank line(s)` → `[events] retry in 2.0 seconds` → `[events] connected` |
| **01:00:37.479 / .504** | server | **both reads, 2.3 s after returning** |

Leg 2 repeated it with the same shape: Home `07:53:41.466`, closed `07:53:44.792` (3.3 s), back
`07:54:56.706`, both reads `07:54:58.889 / .926` (2.2 s). **So with no `scenePhase` hook at all, tvOS
ends the stream on backgrounding, `URLSession` reports it the moment the app resumes, and the plan's
2 s retry and both re-reads follow.** Pass 115's least-certain item 3 is closed.

**On connect, every run:** the pair lands after the Guide's own open read — **0.14 s after it on a
10-row collection** (`00:31:40.098` → `.237`), **about 5.5 s after it on All Channels**
(`00:14:48.606` → `:53.863`; `07:46:07.804` → `:13.464`; `07:52:02.804` → `:08.528`), where 236 rows
and their logos keep the main actor busy before the listener's task gets to connect. A change made in
those seconds is still caught, by the on-connect reads themselves.

**A healthy stream is left alone.** In the timed-out run one connection lived **25 min 23 s**
(opened `00:31:40`, its single log line `00:57:02.991`), so the 15 s keep-alives hold the 45 s idle
timer off on tvOS.

---

## 5. The reader file, measured on this Mac (run)

Nothing on the television can make the server drop a stream, go silent or answer an error without
touching the server. So **`ServerEvents.swift`, byte-identical to the app's** (`cmp`), was compiled
with a three-line stub and run against a fake event server on `127.0.0.1` — the whole timeline is
`reader-on-the-mac-timeline.txt`. **It is macOS's Foundation, not tvOS's, and says so.**

| What the fake server did | What the reader did |
|---|---|
| stream, both words, then `data: bogus` | both notices delivered; `[events] ERROR: a line that is neither a comment nor one of the two words: “data: bogus”` |
| ended the stream | `lost: the server ended the stream … 0 blank line(s)` → next attempt **2.05 s** later |
| 503, twice | `ERROR: GET /api/events: HTTP 503` → **5.06 s**, then **10.4 s** |
| 200, then silence for ever | `lost: The request timed out. after 45 s` — **46.0 s** after connecting → **2 s** |
| 404 | `ERROR: … HTTP 404 — this server has no GET /api/events; it is older than 1.10.0` → `retry in 60.0 seconds` |

## 6. Pass 115's four Apple platform facts

| Fact | Status |
|---|---|
| `timeoutIntervalForRequest` defaults to 60 s | **No longer relied on** — the reader sets its own 45 s. That value **fires at 46.0 s on a silent stream: measured on the Mac.** On tvOS: a healthy stream held 25 min 23 s, **measured**; a silent-but-open stream being cut at 45 s on tvOS itself is **still unmeasured** — the "timed out" on return from Home is a torn-down socket noticed on resume, not the idle timer running out. **The 60 s default itself: unmeasured, and moot.** |
| `timeoutIntervalForResource` defaults to 7 days | **No longer relied on** — set explicitly to 7 days. That a stream that old is cut and reopened: **unmeasured.** |
| `httpMaximumConnectionsPerHost` is 4 | **Avoided** — the stream has its own session and takes no connection from `URLSession.shared`. **Unmeasured.** |
| `AsyncBytes.lines` drops empty lines | **Measured on both.** Mac: 0 blank lines for 5 events. **tvOS: `0 blank line(s)` for 3 comment lines, and for 7 comment lines plus 2 notices.** |

## 7. Traced only — built, not exercised

One representative run, the rest traced (Pass 79's budget). Each of these is code that ran in no run:

- **A notice during a re-read** causing one more re-read — the four writes were 21 s and 17 s apart.
- **A notice under the airing sheet, the hold menu or the collections overlay** waiting and running
  the moment it closes, and the focus check after it.
- **A focused row disappearing** — the focused row survived both changes here.
- **A deleted pick** reverting to All Channels live.
- **`favouriteOverrides` being cleared** — no favourite write was authorised; and **the app's own
  favourite press echoing back as `channels`**, which will cost one extra re-read per press.
- **A renumber's re-order**, and what the scroll does with a focused row that moves.
- **A notice behind the Player**, where no focus is written; and what tvOS focuses when the Player
  comes down on a row that went while it was up — nothing here repairs that case.
- **A double `channels`** from Add Source; **a server stop**; **a pre-1.10.0 404 on the television**
  (measured on the Mac only).

## 8. The harness

`Marlin DVR TVUITests/GuideLiveRedrawUITests.swift`, four methods, run one at a time; its header says
what each needs. **The foreman accepted both judgment calls in it:** the one `activate()`, in
`comeBackFromHome()`, foregrounds the process the method already launched and launches nothing; and
the console methods drive the process `devicectl` started, whose own ping is in the log.

**Two runs were thrown away, both for the harness's faults and neither for the app's**, before
anything was asked of anyone: the first READY (00:30) carried a failed "before" check — it expected
`"TL, TLC, 6105"` and a channel drawn with its logo reads `"TLC, 6105"` — and had picked the
collection across 00:30:00, so the Guide's roll, which is skipped under an overlay, was due mid-wait.
It was stopped at 00:30:58 and both were fixed.

## Open questions

1. **A row that comes back under the fold is not seen until the list is scrolled** (§3.4). It is what
   a list does, and it is not what "right away" sounds like. Left as built; raised.
2. **Every Guide open now reads the guide twice**, and on All Channels the stream connects about
   5.5 s after the Guide opens (§4). Both follow from call 1 and from waiting for the first load;
   neither was asked to be different.
3. **Only the Guide listens**, and only while it exists — Pass 115's question 6, which the three
   calls did not touch. On Now, Favorites, Search, Home's count and On Later do not.
4. **The Philo lineup file's possible empty override entry for 6105** (§3.5) — harmless, invisible,
   and the owner's to know about.
5. **`GET /api/settings` appears in the server's log at 07:46:16 and 07:46:18** from the owner's own
   browser. Recorded so that no later pass mistakes it for this project's.
6. Pass 115's open questions 7–9 are untouched: COLD-START's "`HLS-CLIENT-API.md` still says 1.7.0"
   line, and the HDHomeRun's device ID in earlier reports.

## The things least certain

1. **Everything in §7.** The overlay wait and the owed re-read are the two with the most moving
   parts, and neither has run.
2. **Focus through a whole-`rows` replacement held here, twice, on a 10-row collection with the
   focused row surviving.** A focused row that moves (renumber) or goes is untested on a television.
3. **The reader's behaviour on a genuinely silent stream on tvOS** rests on the Mac measurement of
   the same file.

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/ServerEvents.swift` | 1, 3 | new — the stream reader |
| `Marlin DVR TV/GuideCollections.swift` | 1, 2 | `refresh()` added; nothing else |
| `Marlin DVR TV/GuideScreen.swift` | 1, 2, 3 | the listener `.task`, `serverRedraw` and its focus rule, `reloadForNotice()` and `fetch`'s `serverWins`, three `@State`s, the header comment |
| `Marlin DVR TVUITests/GuideLiveRedrawUITests.swift` | 4 | new — the evidence harness |
| `reports/assets/pass116/` | 4 | ten screenshots, the four writes and the proof, the console transcripts, the harness lines and server-log windows, the Mac timeline |
| `reports/2026-09-19-pass116-guide-live-redraw.md` | 5 | new — this report |
| `DECISIONS.md` | 5 | appended the Pass 116 entry |
| `COLD-START.md` | 5 | the Guide line; *The server* line's "does not listen yet"; *Next step* |

**Nothing else was written in this repo.** On the server: **four `PUT`s, authorised by the owner and
reverted, and nothing else**; every other request was a GET or the `GET /api/events` stream. The
bedroom Apple TV was not touched. Client ids, the device name, the Apple TV's address and the
HDHomeRun's device ID are redacted throughout; `devicectl list devices` printed device identifiers
into this session's tool output and they are reproduced nowhere.
