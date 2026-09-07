# Pass 18 — Radio recon (read-only) — 2026-09-06

Read-only. No Swift file, asset, entitlement, `Info.plist` entry or build setting was
written or changed; nothing was installed; no dependency was added; no station stream URL
was requested and no audio was played. Exactly one request was sent to the DVR server, the
`GET /api/radio` of step 2. The only file this pass creates is this report.

**Contract check (read first).** Reference clone `~/Xcode/marlin-dvr-reference`,
`git fetch origin` only — no pull, checkout, merge or reset; the working tree was not
touched. `origin/main` = `fba51f2504571147aefdc8e39ec67d1453d4c999` ("Pass 34 report:
pushed SHA"), which is the `fba51f2` the owner named. `HLS-CLIENT-API.md` at that commit is
**320 lines**, md5 `0726d2c2bd3010d84e3a75846501c5f8`, and **§9 "Radio stations" is
present** (line 277). The stop-and-report condition "the Radio section is absent from
origin/main" did not fire.

One staleness note, stated because it is a fact about the document and not a complaint:
the contract's own header still says it describes the server "as pushed at `ed49d64`,
running version **1.1.0**" (`HLS-CLIENT-API.md:4-5`), while §9 is a Pass 33 addition and
the owner says the deployed server is 1.4.0. I did not verify the running version — that
would have been a second request to the host, which this pass forbids.

---

## 1. The contract — §9 of `HLS-CLIENT-API.md` at `origin/main`

### 1.1 What the section says it is

`HLS-CLIENT-API.md:277` — `## 9. Radio stations (Pass 33 — not HLS, not a play session)`

`:279-282`, verbatim:

> Radio is nothing like the video paths above: **the app plays the stream URL itself**.
> There is no play session, no HLS, no idle watchdog, no tuner, and this server never
> plays, proxies or transcodes the audio — it only stores the stations and hands you the
> list.

### 1.2 The route and the response shape

`:284` — ``GET /api/radio`` — route `main.go`, handler `radio.go`. **This is the only
section of the contract that cites no line numbers**; every other section gives file and
line (compare `:192-193`, `:208-209`, `:263-264`). The routes themselves are at
`cmd/marlin-dvr/main.go:331-335` in the reference clone, and the handler is
`cmd/marlin-dvr/radio.go:63-88`.

The documented response (`:286-291`):

```json
{"count":2,"stations":[
  {"id":"rad…","name":"…","format":"AAC","url":"https://…/stream","icon":"https://…/logo.png","iconUrl":"/api/art/feed?u=…"},
  …
]}
```

Two top-level keys: `count` and `stations`. The section does not state their types beyond
the example; the handler settles it — `writeJSON(w, map[string]any{"stations": out,
"count": len(out)})` (`radio.go:87`), so **`count` is a JSON number** (`len` of the slice)
and **`stations` is an array of objects**. Each object is built at `radio.go:85` as
`map[string]any{"id":…, "name":…, "format":…, "url":…, "icon":…, "iconUrl":…}` — six keys,
**every one of them a Go `string`, so every one of them a JSON string**, always present,
never `null`. The stored `Station` struct carries a seventh field, `CreatedAt time.Time`
(`radio.go:25`), which is **not** in the response.

The field table, verbatim (`:293-300`):

| Field | Meaning |
|---|---|
| `id` | stable station id |
| `name` | display name |
| `format` | the label the owner typed (e.g. `AAC`, `MP3`) — **a hint only** |
| `url` | the stream URL. **Play this directly.** |
| `icon` | the raw icon link the owner pasted (for reference) |
| `iconUrl` | the icon **served by this server** from its cache (`/api/art/feed?u=…`); resolve it against the server base. **Empty string** when the icon could not be fetched — show your own placeholder then. |

### 1.3 How the icon URL is formed

`:300` says `iconUrl` is `/api/art/feed?u=…` and must be resolved against the server base.
The handler is exact about it (`radio.go:69-84`): `iconURL` starts as `""`; if
`strings.TrimSpace(s.Icon) != ""` **and** `a.art.feedImagePath(s.Icon)` returns no error —
that is, the server has already fetched and cached the image — then

```go
iconURL = "/api/art/feed?u=" + url.QueryEscape(s.Icon)   // radio.go:72
```

So it is the literal path `/api/art/feed`, one query parameter `u`, whose value is the
owner's raw `icon` URL **percent-escaped as a query component**. A station with no `icon`,
or one whose icon could not be fetched, gets `""` and one `WARN RAD` log line, logged once
per station rather than once per `GET` (`radio.go:32-37`, `:76-83`).

The endpoint it points at is `GET /api/art/feed` (`main.go:292` → `artwork.go:476-497`):
it rejects a `u` that is not http/https or has no host with **400 `bad image url`**
(`artwork.go:479-482`), serves the cached image with a one-day cache lifetime on success
(`artwork.go:496`), and answers **404** when the fetch failed and no `title` fallback
applies (`artwork.go:493`). The contract does not mention any of this; the app should
treat `iconUrl` as an image that may still 404 and fall back to its own placeholder, which
is what `:300` and `:317-318` ask for anyway.

### 1.4 Ordering

`:302`, verbatim: "The list is returned **in the owner's order**; render it in that
order." `:303`: "An empty list (`{"count":0,"stations":[]}`) is normal."

The guarantee is exactly that and nothing more — there is no sort key, no `order` field and
no timestamp in the response to sort by. The handler copies the in-memory slice as-is
(`radio.go:64-66`), which is the file's slice order; the owner changes it from the admin
page through `PUT /api/radio/order` (`main.go:333`, `radio.go:211-244`). **The app must not
sort.**

### 1.5 The rules the section states for the player

`:305-320`, condensed but complete — five bullets:

* **Play `url` directly** with AVPlayer. Do **not** `POST /api/play/sessions` for a
  station — "that route is for TV/cameras and does not know about radio" (`:307-309`).
* **Follow HTTP redirects** (`:310-312`): "These are typically Icecast/Shoutcast
  `livestream-redirect` URLs that answer `302` to a CDN and then stream continuous audio;
  the player must follow the redirect."
* **Play whatever content type the stream serves; do not trust `format`** (`:313-316`):
  "`format` is the owner's label for display and was not verified by the server (the AAC
  mount was not observed end-to-end in Pass 32 recon). Sniff/most-players handle
  `audio/mpeg`, `audio/aac`, `audio/aacp`."
* **Icons** come from `iconUrl`, not the raw `icon`; empty `iconUrl` → placeholder
  (`:317-318`).
* **Registration/ping** are as §1; nothing extra is required for radio (`:319-320`).

### 1.6 Errors the section documents

**None.** §9 has no error table, no status code and no failure case anywhere in its 44
lines. The contract's only error table is §7 (`:243-256`), and every row of it is a
`/api/play/…` route — DRM 403, unknown-id 404s, `kind` 400, `bad json` 400, HLS-start 502s,
`session ended` 410. None of them can be reached by `GET /api/radio`.

That is consistent with the handler: `handleRadio` (`radio.go:63-88`) has **no error
return path at all** — it reads a slice under `RLock`, builds the output, and calls
`writeJSON`. It always answers 200. Its sibling routes do have errors (`bad json` 400 and
`name and stream URL are required` 400 on POST, `404` on PUT/DELETE of an unknown id —
`radio.go:102`, `:113`, `:153`, `:198`), but those are the admin page's routes and are
outside this app's business. §8 (`:269-270`) still holds: no authentication of any kind on
these routes.

### 1.7 Directly asked: redirects, content types, the `format` label

* **Redirects** — yes, the section addresses them, at `:310-312`. It states what the URLs
  typically are (Icecast/Shoutcast `livestream-redirect`), what they answer (`302` to a
  CDN) and what the player must do (follow it). It makes no claim about *how* AVPlayer
  does that and cites nothing.
* **Content types** — yes, at `:313-316`. It names three the player will meet:
  `audio/mpeg`, `audio/aac`, `audio/aacp`. It gives no content type for `GET /api/radio`
  itself (measured in step 2: `application/json`).
* **The reliability of the `format` label** — the section is unusually blunt about it. The
  table calls it "**a hint only**" (`:297`); the bullet says it "was not verified by the
  server" and names the gap: "the AAC mount was not observed end-to-end in Pass 32 recon"
  (`:314-315`). The server project's own recon says the same with the measurement behind
  it: the MP3 mount was proven `302 Found` → CDN → `206 Partial Content`,
  `Content-Type: audio/mpeg`, with `icy-name`/`icy-genre` headers; the AAC mount **was
  never reached** — "the specific `.aac` call-signs I tried returned 404 (wrong mount
  names), so only the MP3 path was verified end to end"
  (`reports/2026-09-06-pass32-deploy-record-radio-recon.md:110-119`, reference clone).

---

## 2. What the server actually returns

One request, sent once:

```
GET http://192.168.1.250:8090/api/radio
```

Response, headers verbatim:

```
HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json
Date: Mon, 07 Sep 2026 01:51:18 GMT
Content-Length: 982
```

982 bytes, answered in 2.7 ms.

**Redaction.** The response carried **no credential, no token and no device id** — I read
every byte of it before writing this. What it does carry is each station's stream URL and
icon URL, and the server's own source marks both as data that stays in `data/` and is
never logged (`radio.go:22`, `:24`); the server project's Pass 32 report published these
same URLs with "mounts redacted" (`…pass32…:108`). This repo is public, so I follow that
precedent: the stream mount, the icon path and the tail of each station id are elided with
`…`. Nothing else is changed — field names, order, types, empty values and the two station
names are exactly as returned.

```json
{"count":2,"stations":[
  {"format":"",
   "icon":"https://upload.wikimedia.org/wikipedia/commons/…/…Logo.png?utm_source=…&utm_campaign=index&utm_content=original",
   "iconUrl":"/api/art/feed?u=https%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2F…",
   "id":"radmtqgq5…",
   "name":"WBAL NewsRadio 1090",
   "url":"https://playerservices.streamtheworld.com/api/livestream-redirect/….aac"},
  {"format":"",
   "icon":"https://play-lh.googleusercontent.com/…",
   "iconUrl":"/api/art/feed?u=https%3A%2F%2Fplay-lh.googleusercontent.com%2F…",
   "id":"radmtqgr6…",
   "name":"WCBM Talk Radio 680",
   "url":"https://playerservices.streamtheworld.com/api/livestream-redirect/….mp3"}
]}
```

What this establishes, against §1:

1. **The route exists and answers 200.** The shape matches `:286-300` exactly: `count` a
   number, `stations` an array, six string keys per station, no `createdAt`. Keys arrive
   alphabetically because Go marshals a `map[string]any` with sorted keys — decode by name,
   never by position.
2. **`count` is 2 and there are 2 stations.** Both are real stations of the owner's.
3. **`format` is the empty string on both.** The contract's example shows `"AAC"`
   (`:288`) and the table describes "the label the owner typed" (`:297`); in the live data
   the owner typed nothing. So the app must handle `format == ""` — no separator, no
   "Unknown", just nothing drawn. This is the strongest possible confirmation of `:313`:
   the label is not merely unreliable, right now it is absent.
4. **`iconUrl` is non-empty on both**, in the exact `/api/art/feed?u=<escaped>` form of
   `radio.go:72`. Both icons are therefore already cached on the server. Neither the empty
   case nor the 404-from-`/api/art/feed` case is exercised by today's data.
5. **Both stream URLs are `https://`**, both on `playerservices.streamtheworld.com`, both
   `/api/livestream-redirect/…` — the exact shape §9 warns about (`:310-312`). One ends
   `.aac`, one ends `.mp3`. That is the same pair of mounts Pass 32 probed, and it means
   **the one mount the server project never observed end to end is the first station in
   this list**.
6. **Order** is WBAL then WCBM. That is the owner's order and the app renders it as given.
7. `Cache-Control: no-store` — do not cache the list.

---

## 3. The design

`design/` is read-only and was not edited. Line references below are into
`design/Marlin DVR TV.dc.html`, cited as `dc:<line>`.

The design **does** draw a Radio screen. The stop-and-report condition "the design contains
no Radio screen" did not fire. It draws less than a build needs, and §3.5 says exactly
where.

### 3.1 The frame

Frame **5g**, caption (`dc:767`): "Radio — audio-only streams, playing while the screen
stays up". The artboard is `data-screen-label="Radio"`, 1920×1080 (`dc:769`), on the
standard Nocturne background with the accent radial wash.

Layout, top to bottom (`dc:771-846`):

* An **icon-only rail** down the left — a 180 px `aside` with the accent tab and nine
  64 px icon squares from `railRadio` (`dc:772-777`), the Radio slot lit.
* A **header row** (`dc:779-785`): title `Radio` at 52 px; beside it, in neutral-500,
  "6 stations · audio only, no tuner needed"; and, right-aligned in neutral-600,
  "Streams come straight from the station, not the DVR".
* A **Now playing bar** (`dc:787-813`) — described in §3.3.
* A **Stations** heading row (`dc:815-819`): `Stations` at 38 px, a fading rule, and on the
  right "★ marks a favorite · 6 stations, swipe for the rest".
* The **station grid** (`dc:821-840`) — described in §3.4.
* A **footer line** (`dc:842-845`), moon icon plus: "Playback continues with the screen
  dimmed · Menu returns to the rail without stopping the stream".

### 3.2 The rail entry

Radio is the ninth and last of the design's rail destinations: `["Radio","ph-radio"]` in
the `nav` array (`dc:1136`), index 8, used as `railRadio: railAt(8)` (`dc:1352`). In the
full rail of frame 1b it is an icon + label row, 34 px icon and 29 px label (`dc:63-68`);
on the Radio screen itself the rail collapses to icons only (`dc:772-777`). No badge, no
count, no state — the rail entry carries the word "Radio" and nothing else.

The app already draws this exactly: `Destination.radio` is in `railOrder`
(`Destination.swift:26`) with the label "Radio" (`:41`) and SF Symbol `radio` (`:59`), and
selecting it does nothing because `isBuiltNow` is `false` (`:97`) — `ScreenShell.swift:36-39`
only assigns `screen` for a built destination.

### 3.3 The Now playing bar — yes, the design draws player state

This is the design's answer to "is a now-playing or player state drawn": **yes, but on the
Radio screen itself, not as a player screen**. None of the eight Player frames 6a–6h is a
radio state; the Radio screen carries its own transport bar.

The bar (`dc:787-813`) is a surface-coloured card, 30/34 px padding, holding:

* a **132 px artwork square** — a gradient tile with a `ph-radio` glyph at 58 px
  (`dc:788-790`), *not* a station logo;
* the eyebrow **"Now playing"** in accent-300, uppercase, letter-spaced (`dc:793`), and
  beside it in neutral-500 "89.7 FM · 128 kbps AAC" (`dc:794`) — frequency and bitrate;
* the **programme title** at 44 px, heading font: "Baltimore Hit Parade" (`dc:796`);
* the **track line** at 29 px: "Wye Oak — Civilian" (`dc:797`);
* a status row (`dc:798-801`): a green `ph-broadcast` badge reading "Live · 42 min", and in
  neutral-600 "WTMD · Towson University";
* on the right, a control cluster (`dc:803-812`): a `ph-pause` glyph at 44 px, a
  `ph-star` at 38 px in accent-300, and a `ph-speaker-high` with a 180×8 px volume track
  filled to 64 %.

### 3.4 How a station is represented

A two-column grid, `gap:18px 30px` (`dc:821`), iterating `radioStations` with a
placeholder count of 4 (`dc:822`). Each row (`dc:823-838`) is:

* a **76 px square** whose entire content is the **frequency string** — `{{ r.freq }}` at
  23 px on a neutral gradient (`dc:824-826`). There is no image in a station row.
* `{{ r.name }}` at 31 px in the heading font, and on the same baseline `{{ r.fmt }}` at
  23 px in neutral-500 (`dc:828-831`);
* `{{ r.now }}` at 26 px, neutral-200, single line, ellipsised (`dc:832`);
* `{{ r.art }}` at 23 px, neutral-500, single line, ellipsised (`dc:833`);
* a trailing `ph-star` at 29 px, drawn only when `{{ r.fav }}` (`dc:835-837`).

Focus is the standard treatment — first row gets `4px solid var(--color-accent)`, the
10 %-accent surface tint and the big shadow (`dc:1374-1377`).

The design's own sample data (`dc:1369-1373`) is the clearest statement of what each field
is meant to hold:

| `name` | `freq` | `fmt` | `now` | `art` | `fav` |
|---|---|---|---|---|---|
| WTMD | 89.7 FM | Adult alternative | Baltimore Hit Parade | Wye Oak — Civilian | ★ |
| WYPR | 88.1 FM | NPR news & talk | All Things Considered | National feed | ★ |
| WBJC | 91.5 FM | Classical | Afternoon Concert | Dvořák — Symphony No. 8 | |
| WBAL | 1090 AM | News & Orioles | Orioles at Rays pregame | First pitch 6:35 PM | ★ |

### 3.5 The Home tile

Frame 2a's grid is three columns of nine tiles (`dc:146-158`); each tile is an icon square,
a 38 px label and a 26 px sub-line over a tinted gradient. The Radio entry is
`["Radio","ph-radio","6 stations","#2f5f36"]` (`dc:1361`) — eighth of nine, between Weather
and Settings.

The app draws the tile with that icon and tint (`Destination.swift:59`, `:84`) but
substitutes the sub-line **"Stations"** (`Destination.swift:105`), because the count is a
number it will not fabricate. Clicking it does nothing (`ContentView.swift:31-35`).

### 3.6 Plainly: what the design does not give you

Said without softening, because the gap is large. Of the eleven distinct values the design
draws for Radio, **the server supplies three**.

| The design draws | The server has | |
|---|---|---|
| station `name` (`dc:829`) | `name` | ✅ |
| `freq`, the 76 px artwork square's only content (`dc:825`) | — | ❌ nothing. No frequency, band or call sign field exists in `/api/radio`. |
| `fmt` — a **genre**: "Adult alternative", "NPR news & talk", "Classical" (`dc:1370-1373`) | `format` — a **codec label**, "AAC"/"MP3" (`:297`), and **empty on both live stations** (step 2) | ❌ same slot, different meaning, and no data. |
| `now` — the programme now airing (`dc:832`) | — | ❌ no now-playing metadata of any kind. |
| `art` — track and artist (`dc:833`) | — | ❌ same. |
| `fav` — a favourite star, per station and in the bar (`dc:835`, `dc:805`) | — | ❌ no favourite flag on a station, and no route to set one (`main.go:331-335` is the whole radio surface). |
| Now playing: "89.7 FM · 128 kbps AAC" (`dc:794`) | — | ❌ no bitrate, no frequency. |
| Now playing: programme title, track, "Live · 42 min", "WTMD · Towson University" (`dc:796-800`) | — | ❌ none of it. |
| a volume slider at 64 % (`dc:806-811`) | — | ❌ not the server's, and not the app's either — an Apple TV's volume belongs to the TV or receiver. |
| "6 stations" on the Home tile and header (`dc:1361`, `dc:782`) | `count` | ✅ (2 today) |
| a station **image** | `iconUrl` (`:300`) | ⚠️ **the reverse gap** — the server serves a cached icon per station and the design has nowhere to put it. The 76 px square holds a frequency string (`dc:825`), the 132 px bar square holds a generic `ph-radio` glyph (`dc:789`). |

Two more things the design asserts that are not the server's to give:

* "**Playback continues with the screen dimmed · Menu returns to the rail without stopping
  the stream**" (`dc:844`) and the caption's "playing while the screen stays up"
  (`dc:767`). That is a real behavioural requirement on the app — see §4.4.
* "**6 stations, swipe for the rest**" (`dc:818`) while drawing four in a 2-column grid —
  a paged or scrolling grid is implied but not drawn.

So: the design gives a **layout** to build to, and a nearly complete one. What it does not
give is a **screen that can be filled from `/api/radio`**. Fill it honestly today and the
station rows lose their artwork square, their genre line, their now-playing line, their
track line and their star, and the Now playing bar keeps a station name and nothing else.
That is a decision for the owner, not something to paper over.

---

## 4. The app's ability to play a station

Established read-only from the existing Player code and the installed tvOS SDK
(`/Applications/Xcode.app/…/AppleTVOS26.5.sdk`, `xcrun --show-sdk-version` → 26.5).
Nothing was built, run or played.

### 4.0 What exists today

There is **no radio code**. Grepping every Swift file for `radio`/`station` returns only
the inert rail/tile plumbing — `Destination.swift` (the enum case, label, symbol, tint,
`isBuiltNow == false`, the "Stations" sub-line) and the two comments that say so
(`ContentView.swift:35`, `ScreenShell.swift:39`). No model, no `GET /api/radio` call, no
screen, no audio player.

The existing player path is a single shape, and it is HLS-session shaped end to end:

1. Every entry point builds a `PlayRequest`, which has exactly three cases —
   `.live` / `.recording` / `.camera` (`PlayerModel.swift` via `PlayRequest.swift:12-16`) —
   and whose `kind` is the `POST /api/play/sessions` body field (`PlayRequest.swift:25-32`).
2. `PlaybackSessionClient.create` POSTs that session with `format: "hls"`
   (`PlaybackSession.swift:50-63`).
3. `PlayerModel` resolves the returned URL, fetches the first playlist with a 25 s timeout
   (`PlayerModel.swift:110-120`, `PlaybackSession.swift:66-77`), then attaches and starts
   the 10 s keep-alive the idle watchdog needs (`PlayerModel.swift:121-122`,
   `PlaybackSession.swift:27`).
4. The item itself is one line: `AVPlayerItem(url: url)` on one long-lived `AVPlayer`
   (`PlayerModel.swift:39`, `:134-139`).
5. That `AVPlayer` goes into an `AVPlayerViewController` filling the screen
   (`PlayerHost.swift:49`, `:53-59`, `:61-69`), presented as a `fullScreenCover` over
   everything (`ContentView.swift:47-50`).

**Can that path play a station as-is? No — and it must not be asked to.** Steps 1–3 are all
`/api/play/sessions`, which the contract forbids for radio in as many words: "Do **not**
`POST /api/play/sessions` for a station — that route is for TV/cameras and does not know
about radio" (`HLS-CLIENT-API.md:307-309`). `PlayRequest` has no fourth case and `kind`
has no fourth value.

**Step 4 alone — the AVFoundation part — is reusable.** `AVPlayerItem(url:)` takes any
URL; the app builds it with no options and no asset subclass, so nothing in the current
code is HLS-specific at that line. The SDK's own statement that AVFoundation understands
these containers is `+[AVURLAsset isPlayableExtendedMIMEType:]`
(`AVAsset.h:657-665`), whose discussion enumerates the MIME types whose codecs parameters
it interprets and names **`audio/mpeg` (e.g. codecs="mp3")** and **`audio/mp4`** among them
(`AVAsset.h:660`).

So the honest shape of the answer: **the app's `AVPlayer` can very probably play the
stream; the app's *Player* cannot**, because everything the Player does around the
`AVPlayer` is session machinery a station must skip. A radio player is a bare `AVPlayer`
with app-drawn UI, not `PlayerScreen`.

### 4.a Does AVPlayer follow HTTP redirects on a stream URL?

**Not provable read-only. The SDK does not say, and proving it means playing a station.**

What the headers do establish:

* The complete option list for `-[AVURLAsset initWithURL:options:]` is
  `AVAsset.h:536-620`: `AVURLAssetPreferPreciseDurationAndTimingKey` (:548),
  `AVURLAssetOverrideMIMETypeKey` (:553), `AVURLAssetReferenceRestrictionsKey` (:558),
  `AVURLAssetHTTPCookiesKey` (:572), `AVURLAssetAllowsCellularAccessKey` (:577),
  `AVURLAssetAllowsExpensiveNetworkAccessKey` (:582),
  `AVURLAssetAllowsConstrainedNetworkAccessKey` (:587),
  `AVURLAssetURLRequestAttributionKey` (:603), `AVURLAssetHTTPUserAgentKey` (:609),
  `AVURLAssetPrimarySessionIdentifierKey` (:615). **None of them concerns redirects.**
  There is no policy to set, nothing to opt into and nothing to opt out of.
* The only redirect API in the whole framework is on the custom-loading path:
  `AVAssetResourceLoadingRequest.redirect` (`AVAssetResourceLoader.h:237-241`,
  `API_AVAILABLE(… tvos(9.0) …)`), whose discussion reads "AVAssetResourceLoader supports
  redirects to HTTP URLs only. Redirects to other URLs will result in a loading failure."
  (`AVAssetResourceLoader.h:239`). That is for assets whose scheme the app services itself.
  The app registers no resource-loader delegate anywhere.
* A grep for `redirect` across the tvOS 26.5 `AVFoundation` and `AVKit` headers returns
  hits **only** in `AVAssetResourceLoader.h`. `AVError.h` has none. `AVPlayerItem.h`'s
  access- and error-log entries expose a `URI` — "The URI of the playback item… Corresponds
  to `uri`" (`AVPlayerItem.h:932-936`, `:1099-1103`) — but the header does not say whether
  that is the requested or the final URI, so it is not evidence either way.

What asserts it, from outside the SDK:

* The contract requires it: "the player must follow the redirect"
  (`HLS-CLIENT-API.md:310-312`). A requirement, not a proof.
* The server project's recon asserts it: "Either way the Apple TV plays these **directly**
  (AVPlayer follows the 302 and plays the continuous audio)"
  (`…pass32…:121-123`). That report measured **curl**, not AVPlayer — its own evidence is
  header-only probes (`…pass32…:106-119`) — and its closing names this as its least certain
  point: "I proved the MP3 stream end to end but could not hit a live AAC mount…"
  (`…pass32…:336-338`).

**Verdict:** every document in the project says AVPlayer follows the 302; not one of them
measured AVPlayer doing it, and the tvOS SDK is silent. The only way to settle it is to
play a station, which this pass forbids. Open Question 1.

### 4.b What happens when the served content type disagrees with `format`?

**Today: nothing, because `format` never reaches AVPlayer.** `AVPlayerItem(url:)`
(`PlayerModel.swift:134`) builds its `AVURLAsset` with **no options dictionary**, so
AVFoundation determines the format from what the server sends and the URL's path extension.
There is no channel through which the owner's typed label could contradict anything.

A disagreement becomes possible only if a future builder deliberately passes the label in,
via the one key that exists for it — and that key is a trap. `AVURLAssetOverrideMIMETypeKey`
(`AVAsset.h:550-553`, `API_AVAILABLE(… tvos(17.0) …)`; the app's deployment target is
tvOS 18.0, `project.pbxproj:250`, `:305`, so it is available):

> Indicates the MIME type that should be used to identify the format of the media resource.
> When a value for this key is provided, **only the specified MIME type is considered** in
> determining how to handle or parse the media resource. **Any other information that may
> be available, such as the URL path extension or a server-provided MIME type, is
> ignored.** — `AVAsset.h:550-552`

So passing `format` into that key would make a wrong owner-typed label authoritative and
override the truth from the wire. The contract says the same thing in plain words: "Play
whatever content type the stream serves; do not trust `format`" (`:313`). Step 2 makes it
concrete: `format` is `""` on both live stations, so there is no label to trust.

**Verdict for the build: pass no MIME option. Let AVFoundation read the wire.** Use
`format` only as display text, and draw nothing when it is empty.

The residual unknown: whether tvOS's audio-file sniffing accepts `audio/aacp` (and
`audio/aac`) — the two types §9 names at `:316` that the project has never observed. The
authoritative list is `+[AVURLAsset audiovisualMIMETypes]` (`AVAsset.h:647-650`), a
**runtime** value; reading it needs running code, which this pass forbids. Open Question 2.

### 4.c Does the app's existing ATS exception cover a station on a public host?

**No. It does not — by Apple's own definition of the key.** But it is moot for the two
stations that exist today.

The app's entire ATS configuration is four lines (`Info.plist:7-11`):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

That is the whole dictionary — no `NSAllowsArbitraryLoads`, no `NSExceptionDomains`. It is
the file the target actually builds (`INFOPLIST_FILE = Info.plist`, `project.pbxproj:320`,
`:351`) and it matches the standing decision: "the App Transport Security exception is
NSAllowsLocalNetworking, verified on the Apple TV in Pass 5. Not NSAllowsArbitraryLoads"
(`DECISIONS.md`, 2026-09-05 sweep 1).

Apple's definition of the key, fetched 2026-09-06 from
`developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking`,
verbatim:

> The `NSAllowsLocalNetworking` key controls whether App Transport Security (ATS) allows
> your app to connect to unqualified domains, `.local` domains, and IP addresses using
> IPv4 or IPv6.

Three categories, all local-shaped. `playerservices.streamtheworld.com` is a fully
qualified public domain — it is none of the three. **A plain-`http://` station URL on a
public internet host is therefore not covered by anything in this app's `Info.plist`, and
ATS would block it.**

Three consequences, in the order they matter:

1. **Today it does not bite.** Both stations are `https://` (step 2). ATS's default policy
   permits HTTPS to a public host, so **no `Info.plist` change is needed to reach the
   stations that exist**. Nothing is blocked right now.
2. **The icons are already covered.** The app is told to load icons from `iconUrl`, which
   is a path on the DVR (`:300`, `:317`) — `http://192.168.1.250:8090/api/art/feed?u=…`,
   an IP literal, exactly what `NSAllowsLocalNetworking` exists for. And the resolution is
   already written: `ServerConfig.resolve` handles a server-relative path with a query
   string (`ServerAPI.swift:20-25`), which is the same shape `ServerImage` already loads
   for `/api/art/show?title=…` (`ServerAPI.swift:20-21`, `ServerImage.swift:19`). Nothing
   new is needed for the icon path. Note the app should **not** load the raw `icon` — that
   would be a direct hit on Wikipedia and Google from the television, and `:317-318` says
   to use `iconUrl` anyway.
3. **The exposure is future data.** The owner can type any URL into the server's Radio
   admin page (`radio.go:99-132`, validated only for non-empty name and URL, `:112-115`),
   and plenty of small stations still publish plain-HTTP Icecast mounts. Such a station
   would appear in the list, look identical to the others, and simply fail to play on the
   Apple TV. Handling that means either an `NSExceptionDomains` entry per host or a rule
   that stations must be `https://` — an owner decision, and adding an ATS key was
   explicitly out of this pass's scope. Open Question 3.

### 4.d Two more things the current code cannot do, found while establishing the above

Reported because they are facts about the existing Player and the design's stated
requirement, not as a proposal to build anything.

**The app never configures an audio session.** A grep for `AVAudioSession` across every
Swift file in `Marlin DVR TV/` returns nothing. The app has always played video inside
`AVPlayerViewController`, which manages its own. The design requires audio to survive the
screen dimming and a Menu press back to the rail (`dc:844`, `dc:767`); a stream that keeps
playing while the app shows another screen is a different audio contract from a
full-screen video player. `AVAudioSessionCategoryPlayback` — "Use this category for music
tracks" — is available on tvOS 9.0 (`AVAudioSessionTypes.h:99-100`), and `setCategory:`
likewise (`AVAudioSession.h:43`). The app sets neither, and `Info.plist` declares no
`UIBackgroundModes` (`Info.plist:1-13` is the complete file: one location string and the
ATS dictionary). What tvOS actually does to an unconfigured session when the screen dims is
not something the headers state; it needs measurement.

**The Player's lifetime is wrong for radio.** `PlayerScreen` is a `fullScreenCover` bound to
`playRequest`, and dismissing it tears the player down (`ContentView.swift:47-50`;
`PlayerModel.swift:502` calls `replaceCurrentItem(with: nil)`). The design's Menu press
must *return to the rail without stopping the stream* (`dc:844`) — the opposite lifetime.
Radio needs a player that outlives its screen. That is a design of the app, and nothing
about it was built here.

---

## Open Questions

1. **Does AVPlayer actually follow the `302`?** (§4.a) Every document in both projects says
   yes; the tvOS 26.5 SDK says nothing; nobody has measured AVPlayer doing it, and the
   server project's own claim rests on curl probes. It cannot be settled without playing a
   station. **What breaks without an answer:** the entire feature. If AVPlayer does not
   follow the redirect, the app must resolve the `Location` itself before handing a URL to
   `AVPlayerItem` — a materially different build.
2. **Are `audio/aac` and `audio/aacp` in `AVURLAsset.audiovisualMIMETypes` on tvOS 26?**
   (§4.b) §9 names all three types the player will meet (`:316`); only `audio/mpeg` has ever
   been observed, on the MP3 mount, by curl. The authoritative list is a runtime value
   (`AVAsset.h:650`). **What breaks:** the `.aac` station — which is the *first* station in
   the owner's list — may not play while the `.mp3` one does, and the failure would look
   like a bad URL rather than a codec issue.
3. **What is the rule for a plain-`http://` station?** (§4.c) `NSAllowsLocalNetworking`
   does not cover a public host. Today's two stations are `https://` so nothing is blocked,
   but the server accepts any URL the owner types. Options: require `https://` for
   stations, or add an `NSExceptionDomains` entry per host. Owner's call; adding an ATS key
   was out of scope.
4. **What fills the design's empty fields?** (§3.6) The design draws `freq`, a genre `fmt`,
   a now-playing programme, a track line, a favourite star, a bitrate and a volume slider;
   `/api/radio` has none of them and the server has no route that could. Either the screen
   is built with those elements dropped, or the fields come from somewhere — Icecast `icy-`
   metadata off the stream itself (Pass 32 saw `icy-name`/`icy-genre` on the CDN response,
   `…pass32…:112-113`), or new server fields, which would be a marlin-dvr decision. Nothing
   here proposes either.
5. **Where does the station icon go?** (§3.6) The server caches and serves one per station
   (`:300`) and the design has no slot for it — its 76 px square holds a frequency string
   (`dc:825`) and its 132 px bar square a generic glyph (`dc:789`). The one field the server
   is generous with is the one the design cannot show.
6. **Can audio survive the screen dimming and a Menu press?** (§4.d) The design states it
   as a requirement (`dc:844`); the app sets no `AVAudioSession` category, declares no
   background mode, and tears its player down on dismiss. What tvOS does here is not in the
   headers.
7. **Is the redaction in §2 the right call?** The response held no credential or token, but
   the server's source marks stream and icon URLs as data that never leaves `data/`
   (`radio.go:22`, `:24`) and this repo is public, so mounts, icon paths and id tails are
   elided. If the owner would rather see them in full in the notebook, say so and the next
   pass can record them.

---

## SCOPE CHECK

Every path opened in this pass, and the step that required it. Verified by hand against
this session's commands, not inherited from an earlier report. **Written:** one file, the
report. **Read-only:** everything else. Nothing under `design/`, the reference clone, or
any other folder was modified; no request other than the single `GET` of step 2 reached
`192.168.1.250`.

| Path | Access | Step that required it |
|---|---|---|
| `COLD-START.md` | read | READ FIRST |
| `DECISIONS.md` | read | READ FIRST; §4.b (deployment target), §4.c (the ATS decision) |
| `reports/2026-09-06-pass7-sweep3-player.md` | read | READ FIRST |
| `~/Xcode/marlin-dvr-reference` (`git fetch origin`, `git show origin/main:…`) | fetch + read | 1 |
| `HLS-CLIENT-API.md` @ `origin/main` | read | 1, and cited throughout |
| `cmd/marlin-dvr/radio.go` @ `origin/main` | read | 1 (types, icon URL formation, ordering, absence of errors) |
| `cmd/marlin-dvr/main.go` @ `origin/main` | read | 1 (the routes §9 does not cite) |
| `cmd/marlin-dvr/artwork.go` @ `origin/main` | read | 1 (what `/api/art/feed` answers) |
| `reports/2026-09-06-pass32-deploy-record-radio-recon.md` @ `origin/main` | read | 1.7 (the redirect and content-type measurement behind the contract's wording), 4.a |
| `reports/2026-09-06-pass33-radio-stations.md` @ `origin/main` | read | 1.4 (ordering), 1.6 |
| `http://192.168.1.250:8090/api/radio` | one GET | 2 |
| `design/Marlin DVR TV.dc.html` | read | 3 |
| `Marlin DVR TV/PlayRequest.swift` | read | 4.0 (the three cases, `kind`) |
| `Marlin DVR TV/PlaybackSession.swift` | read | 4.0 (the session machinery a station must skip) |
| `Marlin DVR TV/PlayerModel.swift` | read | 4.0 (`AVPlayerItem(url:)` with no options), 4.b, 4.d |
| `Marlin DVR TV/PlayerHost.swift` | read | 4.0 (`AVPlayerViewController` full-screen) |
| `Marlin DVR TV/ContentView.swift` | read | 3.5, 4.0, 4.d (the Player's lifetime) |
| `Marlin DVR TV/ScreenShell.swift` | read | 3.2 (Radio inert in the rail) |
| `Marlin DVR TV/Destination.swift` | read | 3.2, 3.5 (the rail entry and Home tile as built) |
| `Marlin DVR TV/ServerAPI.swift` | read | 4.c (`ServerConfig.resolve` for `iconUrl`) |
| `Marlin DVR TV/ServerImage.swift` | read | 4.c (the existing query-string image path) |
| `Info.plist` | read | 4.c, 4.d |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | read | 4.b (deployment target), 4.c (`INFOPLIST_FILE`) |
| SDK `AVFoundation.framework/Headers/AVAsset.h` | read | 4.0, 4.a, 4.b |
| SDK `AVFoundation.framework/Headers/AVAssetResourceLoader.h` | read | 4.a |
| SDK `AVFoundation.framework/Headers/AVPlayerItem.h` | read | 4.a |
| SDK `AVFAudio.framework/Headers/AVAudioSessionTypes.h` | read | 4.d |
| SDK `AVFAudio.framework/Headers/AVAudioSession.h` | read | 4.d |
| Apple docs, `NSAllowsLocalNetworking` | fetched | 4.c |
| `reports/2026-09-06-pass18-radio-recon.md` | **written** | 5 — this report |

Nothing on the do-not-touch list was approached: no other folder under `~/Xcode`, no DVR
server data, no write to the Unraid host, nothing to marlinpc, the HDHomeRun or the UNAS4Pro
share, and no edit to `design/` or to the reference clone's working tree.
