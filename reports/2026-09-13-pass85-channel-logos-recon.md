# Pass 85 — channel logos: recon

**Date:** 2026-09-13
**READ-ONLY as to the app. No app-target code changed.** No Swift file, project file, `Info.plist`,
entitlements file or asset was modified. The files this pass writes are this report, `COLD-START.md`
and `DECISIONS.md`, committed together. `design/` was read and never written.
`~/Xcode/marlin-dvr-reference` was read with `sed`, `grep`, `ls`, `git rev-parse` and `git log -1`
only — never edited, never fetched, never pulled, never checked out, nothing run from it. **Every
request to `http://192.168.1.250:8090/` was a GET** — no POST, PUT or DELETE, and no play session was
opened. No build, no device run, no install.

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass83**. Pass 84
wrote no report of its own — its commit `829e5d7` carried the Pass 83 screenshot and notebook lines
(`git show --stat HEAD`: `COLD-START.md | 6`, `DECISIONS.md | 9`, one `.jpg`) — so this is **Pass 85**.

**What this pass is for.** Recon for one build item, *"Guide channel cell shows the logo via
`/api/art/feed`, two-letter coloured tile fallback when logo is empty"*. Nothing is chosen, proposed
or designed here beyond what the eight steps ask.

**The headline, so it is not buried.** The brief looks for **white** logo artwork. On this cell the
problem runs the other way. The Guide's channel cell sits on a **dark** ground — `#161826` unfocused,
about `#27273F` focused (§4). The **antenna** CBS and FOX logos are **white** and read at
**13.41–17.61:1**. The **Verizon and YouTube** CBS and FOX logos are **black** and read at
**1.18–1.45:1**, which is effectively invisible (§5). **No filename in the lineup suggests white
artwork** — the URL grep for colour or light/dark tokens found 0 matches. And **the server now
answers 1.8.2**, not the 1.8.1 the notebook recorded (§1).

**Redaction.** The HDHomeRun source's name and the prefix of its channel ids carry the tuner's device
id. It is written below as `HDFX-4K (<device id>)` and `hdhr-<device id>`, per `CLAUDE.md`.

---

## VERIFY — the evidence

### V1. Step 8's git reading, taken before any file in the repo was changed

```
$ git fetch origin
$ git status --porcelain
?? icon-source/
$ git rev-parse main origin/main
829e5d7dc603d231c5b96c780122f06c4485d549
829e5d7dc603d231c5b96c780122f06c4485d549
$ git rev-list --left-right --count main...origin/main
0	0
$ git log --oneline origin/main..main
$ git ls-remote origin main
829e5d7dc603d231c5b96c780122f06c4485d549	refs/heads/main
```

`icon-source/` is the standing untracked baseline (DECISIONS.md, 2026-09-08). The reading after the
notebook edits and this report is in §V3.

### V2. The one failure in this pass — diagnosed, then re-run with the cause removed

The first attempt at the step 3 and step 5 fetches ran a shell function in zsh that assigned a
variable named `path`. **In zsh the lowercase `path` array is tied to `PATH`**, so that one
assignment emptied the command search path, and every command after it was "not found". Output of
that attempt, trimmed to its first request:

```
== s3-antenna-2.1-WMAR-HD
   GET /api/art/feed?u=https%3A%2F%2Fimg.hdhomerun.com%2Fchannels%2FUS21230.png
fetch: command not found: curl
fetch: command not found: sed
...
enc: command not found: python3
```

The diagnosis, reproduced in isolation, and proof that nothing had been fetched:

```
$ zsh -c 'echo "before: PATH has $(...) entries"; f() { path="/api/art/feed?u=x"; echo "after assigning path=...: PATH=$PATH"; command -v curl || echo "curl: not found"; }; f'
before: PATH has 17 entries
after assigning path=...: PATH=/api/art/feed?u=x
curl: not found
files in logos/ before retry:        0
```

**No `/api/art/feed` request left the Mac in that attempt** — `curl` was never found, and the output
folder was empty. The re-run renamed the variable (`rpath`) and ran under `bash`; its output is §3
and §5. This was a fixed cause, not a blind retry.

### V3. The reading after the notebook edits and this report, just before the commit

```
$ git fetch origin
$ git status --porcelain
 M COLD-START.md
 M DECISIONS.md
?? icon-source/
?? reports/2026-09-13-pass85-channel-logos-recon.md
$ git diff --numstat
26	3	COLD-START.md
10	0	DECISIONS.md
$ git rev-parse main origin/main
829e5d7dc603d231c5b96c780122f06c4485d549
829e5d7dc603d231c5b96c780122f06c4485d549
$ git rev-list --left-right --count main...origin/main
0	0
$ git ls-remote origin main
829e5d7dc603d231c5b96c780122f06c4485d549	refs/heads/main
```

The secrets and device-id scan over this report and over `git diff` of the two notebook files,
before staging:

```
=== device id (case-insensitive) in report, and in the notebook diff
report: 0 matches
notebook diff: 0 matches
=== credential-shaped strings in report and notebook diff
report: 0 matches
notebook diff: 0 matches
=== UUID-shaped ids (client ids) in report and notebook diff
report: 0 matches
notebook diff: 0 matches
```

(The patterns: the tuner's device id; `password|passwd|secret|api[_-]?key|token=|bearer
|authorization:|BEGIN … PRIVATE|ssh-(rsa|ed25519)|AKIA…|gh[pousr]_…`; and the 8-4-4-4-12 UUID shape.)

---

## 1. Step 1 — `GET /api/status`

```
$ date && curl -sS -i http://192.168.1.250:8090/api/status
Sun Sep 13 12:25:13 EDT 2026
HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json
Date: Sun, 13 Sep 2026 16:25:13 GMT
Content-Length: 74

{"name":"marlin-dvr","version":"1.8.2","uptime_seconds":1572,"port":8089}
```

**Version string, verbatim: `1.8.2`.** `COLD-START.md` recorded **1.8.1** (Passes 71 and 72). This
measurement contradicts the notebook, so it gets the one `DECISIONS.md` entry the brief allows
(2026-09-13 (Pass 85)).

---

## 2. Step 2 — `GET /api/channels`

```
$ curl -sS -D channels.headers -o channels.json http://192.168.1.250:8090/api/channels
HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json
Date: Sun, 13 Sep 2026 16:25:15 GMT
Transfer-Encoding: chunked
   32474 channels.json
dict ['channels', 'count', 'sources']
```

The analysis (Python over the saved body):

```
count field: 97 | len(channels): 97 | sources: ['HDFX-4K (<device id>)', 'Philo', 'Verizon', 'Marlin Cast', 'You Tube']
keys of channels[0]: ['drm', 'favorite', 'guid', 'hd', 'hidden', 'id', 'initials', 'logo', 'logoBg', 'name', 'number', 'origName', 'origNumber', 'source', 'sourceId']
logo key present on every channel: True
non-empty logo: 96 | empty logo: 1
  EMPTY: 9023 | AS-INFOMERCIALS | ... | drm: False | hidden: False
distinct logo hosts: 4
   84 tmsimg.fancybits.co
   9 img.hdhomerun.com
   2 yt3.ggpht.com
   1 prod-s.cdn-cf.philo.com
schemes: {'https': 96}
drm true: 0 | hidden true: 0
```

```
by source: {'HDFX-4K (<device id>)': 9, 'Philo': 29, 'Verizon': 45, 'You Tube': 11, 'Marlin Cast': 3}
host by source: {('HDFX-4K (<device id>)', 'img.hdhomerun.com'): 9, ('Philo', 'tmsimg.fancybits.co'): 28,
  ('Verizon', 'tmsimg.fancybits.co'): 45, ('You Tube', 'tmsimg.fancybits.co'): 11, ('Philo', ''): 1,
  ('Marlin Cast', 'yt3.ggpht.com'): 2, ('Marlin Cast', 'prod-s.cdn-cf.philo.com'): 1}
initials length: {2: 97}
```

| What the brief asks | Measured |
|---|---|
| Total channels | **97** (`count` 97, array length 97) |
| Non-empty `logo` | **96** |
| Empty `logo`, by number and name | **9023 AS-INFOMERCIALS** (source Philo) — the only one |
| Distinct logo hosts, with counts | **`tmsimg.fancybits.co` 84 · `img.hdhomerun.com` 9 · `yt3.ggpht.com` 2 · `prod-s.cdn-cf.philo.com` 1** — all `https` |

**Does the app decode `logo` today? Yes.** There is no struct named `Channel` in the app —
`grep -rn -E "struct Channel( |:|<|\{)"` over the target answered `none`. The type `GET /api/channels`
decodes into is `MergedChannel` (`Models.swift:16`, `Decodable`, via `ChannelsResponse` at `:35-39`).
**`let logo: String // provider's absolute URL or ""` is `Models.swift:25`.** It is non-optional, and
the key was present on 97 of 97 channels.

---

## 3. Step 3 — radio icons through `/api/art/feed`

### 3.1 Where the app requests them, and the URL form

- **The app does not build the radio icon URL.** It decodes the server's own string:
  `RadioStation.iconUrl` (`RadioStation.swift:42`, commented at `:39-41`).
- **The view:** `StationIcon` → **`ServerImage(path: station?.iconUrl, contentMode: .fit)`**
  (`RadioScreen.swift:259`).
- **Resolution:** `ServerConfig.resolve` → `URL(string: path, relativeTo: baseURL)?.absoluteURL`
  (`ServerAPI.swift:22-25`). An empty or nil path returns nil (`:23`).
- **The form:** `/api/art/feed?u=<source URL>`. The parameter is **`u`** and there is no other
  parameter. The source URL is **Go's `url.QueryEscape`** — `radio.go:72` at the clone's HEAD:
  `iconURL = "/api/art/feed?u=" + url.QueryEscape(s.Icon)`. Live, from `GET /api/radio`:

```
'WBAL NewsRadio 1090' | icon: https://upload.wikimedia.org/wikipedia/commons/7/72/WBALTV2022Logo.png?utm_source=en.wikipedia.org&utm_campaign=index&utm_content=original
                      | iconUrl: /api/art/feed?u=https%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2F7%2F72%2FWBALTV2022Logo.png%3Futm_source%3Den.wikipedia.org%26utm_campaign%3Dindex%26utm_content%3Doriginal
'WCBM Talk Radio 680' | icon: https://play-lh.googleusercontent.com/jPQQ…kmzQ
                      | iconUrl: /api/art/feed?u=https%3A%2F%2Fplay-lh.googleusercontent.com%2FjPQQ…kmzQ
```

So `:` → `%3A`, `/` → `%2F`, `?` → `%3F`, `=` → `%3D` and `&` → `%26`: the whole source URL is one
escaped query value. The encoder used for this pass's own fetches was checked against those strings
first, byte for byte:

```
WBAL NewsRadio 1090 | identical to server iconUrl: True
WCBM Talk Radio 680 | identical to server iconUrl: True
```

**The app has one other place that builds this route, and it builds it itself:** `LaterAiring.artPath`,
`OnLaterScreen.swift:75-83`. It uses `URLComponents` with `URLQueryItem(name: "u", …)` **and**
`URLQueryItem(name: "title", …)`. That encodes differently — `:` `/` `?` stay literal, `=` and `&`
are escaped — and it still carries the same `u`. Measured with a scratch Swift script in the
scratchpad, not in the project:

```
$ xcrun swift urlcomp.swift
OnLater-style string: /api/art/feed?u=https://tmsimg.fancybits.co/assets/s59337_ll_h15_ab.png?w%3D360%26h%3D270&title=AMC
u as a server would split it: https://tmsimg.fancybits.co/assets/s59337_ll_h15_ab.png?w=360&h=270
```

### 3.2 The loader and the cache

- **The loader is `ServerImage`** (`ServerImage.swift:13-35`). It wraps SwiftUI's
  **`AsyncImage(url:)`** (`:20`), and that is the **only `AsyncImage` in the app**:

```
$ grep -rn "AsyncImage" --include="*.swift" "Marlin DVR TV"
Marlin DVR TV/ServerImage.swift:20:            AsyncImage(url: url) { phase in
Marlin DVR TV/CamerasScreen.swift:46:    /// A new query value each refresh so AsyncImage requests the snapshot again.
```

  (The second hit is a comment.)
- **There is no cache class of the app's own:**

```
$ grep -rn "URLCache\|NSCache\|urlCache" --include="*.swift" "Marlin DVR TV"
(exit 1)
```

  `ServerAPI.swift:7` says the same in words: "No retries, no caching beyond URLSession's defaults".
  Whatever caching `AsyncImage` does is the system's. **Traced, not measured.**

### 3.3 One antenna logo and one M3U logo, through that same form

```
=== step 3
Sun Sep 13 12:31:30 EDT 2026
== s3-antenna-2.1-WMAR-HD
   GET /api/art/feed?u=https%3A%2F%2Fimg.hdhomerun.com%2Fchannels%2FUS21230.png
   http=200 content_type=image/png bytes=7057
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
== s3-m3u-philo-9005-AMC
   GET /api/art/feed?u=https%3A%2F%2Ftmsimg.fancybits.co%2Fassets%2Fs59337_ll_h15_ab.png%3Fw%3D360%26h%3D270
   http=200 content_type=image/png bytes=12811
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
```

| Logo | HTTP | Content-Type | Bytes |
|---|---|---|---|
| Antenna — 2.1 WMAR-HD (`img.hdhomerun.com/channels/US21230.png`) | **200** | **image/png** | **7057** |
| M3U — Philo 9005 AMC (`tmsimg.fancybits.co/assets/s59337_ll_h15_ab.png?w=360&h=270`) | **200** | **image/png** | **12811** |

The command, run under `bash`: `fetch() { local name=$1 src=$2 rpath; rpath="/api/art/feed?u=$(enc "$src")"; curl -sS -o "logos/$name" -D "logos/$name.headers" -w 'http=%{http_code} content_type=%{content_type} bytes=%{size_download}\n' "http://192.168.1.250:8090$rpath"; … }`,
where `enc` is `urllib.parse.quote_plus(url, safe="")` — the encoder proven identical above.

"M3U" for Philo is not in `/api/channels`, which carries no source type. It rests on the notebook:
`COLD-START.md:502` records the owner's Philo recordings, and `:516` says his library holds only m3u
recordings. See §11.

### 3.4 What `ServerImage` draws on a 404 and on a decode failure — traced, not run

- **Both go to the same line.** `ServerImage.swift:21` draws the image only `if let image =
  phase.image`. Every other phase — still loading, or failed — takes the `else` at **`:27-29`** and
  draws **`fallback()`** (`:28`). A 404's body is not an image, so `AsyncImage` has none to give,
  and the fallback is drawn. A body that fails to decode is the same case.
- **An empty or nil path makes no request at all.** `ServerConfig.resolve` returns nil (`ServerAPI.swift:23`),
  and `ServerImage.swift:31-33` draws the fallback directly.
- **What `fallback` is depends on the caller:**
  - For radio (`RadioScreen.swift:260-265`): a `LinearGradient` from `Nocturne.neutral800` to
    `Nocturne.neutral900`, with the SF Symbol `"radio"` at 52 pt in `Nocturne.neutral400`, on a
    `Nocturne.neutral900` backing (`:268`).
  - For `ChannelLogo` on On Now and Favorites (`ServerImage.swift:62-64`): `InitialsTile`.
- **When the server answers 404 or 400** (clone at 1.8.1): `handleArtFeed` answers **400**
  `bad image url` unless `u` is `http`/`https` with a host (`artwork.go:477-481`). It answers **404**
  with the error text when the fetch fails and no `title` poster can stand in (`:483-494`). It never
  caches or serves a body that Go's content sniffer does not call `image/…` (`:444`).

---

## 4. Step 4 — the Guide channel cell

### 4.1 Where

- **The view:** `struct ChannelCell`, **`GuideScreen.swift:805-838`**.
- **The row:** `struct GuideRowView`, **`GuideScreen.swift:752-801`**. The cell is its first child,
  inside a `HoldButton` (`:769-774`) and focused as `"ch:<channel id>"` (`:763`, `:311`). The rows are
  `ForEach(model.rows)` → `GuideRowView` at **`:377-389`**, in a `VStack(spacing: 12)` (`:376`) inside
  the grid's `ScrollView` (`:375`).

### 4.2 What it draws today

| Element | Code | Values |
|---|---|---|
| Initials tile | `InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: 62, fontSize: Nocturne.TextSize.floor)` — `:812` | **62 × 62**. Fill `Color(hexString: logoBg) ?? Nocturne.neutral800`. Corner radius `Nocturne.Radius.sm` = 4. The server's `initials` at 23 pt semibold in `Nocturne.neutral100` `#F3F5FE` (`ServerImage.swift:44-53`, `Theme.swift:32`, `:44`, `:70`) |
| Channel name | `:815-818` | 26 pt (`TextSize.secondary`), `Nocturne.text` `#E9E9ED`, one line |
| Favourite mark | `:819-822` | `★` in `GuideMark.gold` `#D6A94E` (`:46`), 23 pt, only when favourite |
| Channel number | `:824-826` | 23 pt (`TextSize.floor`), `Nocturne.neutral500` `#9397AB` |
| Anything else | `:828-836` | a trailing `Spacer`, 10 pt horizontal padding, and the focus fill and ring below. **No logo, no image of any kind** |

### 4.3 Width and height

**300 × 82 pt.** `.frame(width: channelColumnWidth, height: rowHeight, alignment: .leading)` is
`:772`, with the constants at `:351-353`:

```
351 private static let channelColumnWidth: CGFloat = 300
352 private static let columnGap: CGFloat = 18
353 private static let rowHeight: CGFloat = 82
```

### 4.4 Background — unfocused and focused, as token and hex

`:832`: `.background(focused ? Nocturne.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, …))`

- **Unfocused: `.clear`.** The ground it shows is **`Nocturne.bg` = `#161826`**.
  - That comes from `ScreenShell.swift:65`, `.background(Nocturne.bg)`, and `Theme.swift:17`,
    `static let bg = Color(hex: 0x161826)`.
  - Nothing in `GuideScreen.swift` paints between the shell and the cell:

```
$ grep -n "Nocturne.bg\|\.fill(\|Color.black\|\.background(" "Marlin DVR TV/GuideScreen.swift"
713:                            .fill(newDay ? Nocturne.accent : Color.clear)
721:        .overlay(alignment: .bottom) { Rectangle().fill(Nocturne.divider).frame(height: 1) }
832:        .background(focused ? Nocturne.accent.opacity(0.14) : .clear, …)
872:        .background(fill, …)
```

  - `:713` is the strip's midnight marker, `:721` the strip's divider, and `:872` the programme
    cell's own fill.
  - The `HoldButton` adds no chrome. Its style is `HoldReportingButtonStyle`
    (`RemoteHold.swift:179`), whose `makeBody` returns `configuration.label` with an `onChange` and
    nothing else (`:199-207`).
- **Focused: `Nocturne.accent.opacity(0.14)`.** That is `#9184D9` (`Theme.swift:20`) at 14 % over
  `#161826`, which composites to **`#27273F`**:

```
=== focused cell background: Nocturne.accent #9184D9 at opacity 0.14 over Nocturne.bg #161826 (source-over, gamma-encoded sRGB)
   composite = #27273F
```

  - It also gets a **4 pt `Nocturne.accent` `#9184D9` ring** (`:833-836`, `Theme.swift:81`).
  - There is no lift, shadow or scale on this cell.
  - **`#27273F` is computed from the tokens, not sampled from the television.**

### 4.5 The approved design — frame 3a

**Frame 3a draws no logo in the channel cell.** It draws the same initials tile the app draws.

- `dc:205` — the row: `display:flex; gap:18px; align-items:stretch; height:82px`
- `dc:206` — the channel column: `width:300px; flex:none; display:flex; align-items:center; gap:18px`
- `dc:207` — **`width:62px; height:62px; border-radius:var(--radius-sm)`** with `{{ r.initials }}` at
  23px/600 in `--color-neutral-100` on **`background:{{ r.bg }}`**
- `dc:209` name 26px; `dc:210` number 23px in `--color-neutral-500`

The design's channel data carries **no logo field**: `dc:1085-1096`, e.g.
`wmar:{num:"2.1",name:"WMAR",initials:"WM",bg:"#1b4b8f"}`. The only occurrence of "logo" anyway in
the file is an icon class:

```
$ grep -n -i -c "logo" "Marlin DVR TV.dc.html"
1
755:                <i class="ph ph-apple-logo" style="font-size:26px"></i>
```

- **Logo size and backing: not applicable** — there is no logo. The "backing" is the 62 px tile
  itself, coloured per channel.
- **The design gives the channel cell no focus state.** Frame 3a's focus is on a programme cell
  (`rowFrom`, `dc:1195`).
- Frame 3c's channel cell is identical (`dc:332-336`).
- **`design/screenshots/guide-3a.png` is not a picture of the Guide**, despite its name. Viewed this
  pass, it shows poster shelves ("Recently added", "The First 48", …) and a caption, "Airing detail
  over the guide — Record Now and Series Pass". The markup above is the authority.

---

## 5. Step 5 — CBS and FOX affiliate logos, and white artwork

### 5.1 Which logos

The lineup rows with CBS or FOX artwork. This is an excerpt of the full `/api/channels` listing
printed this pass; the columns are number, name, source, initials, logoBg and logo:

```
    13.1 | WJZ-TV          | HDFX-4K (<device id>) | WJ | #6b6f7a | https://img.hdhomerun.com/channels/US21232.png
    45.1 | WBFF45          | HDFX-4K (<device id>) | WB | #2f6fed | https://img.hdhomerun.com/channels/US21233.png
   145.1 | WBFF            | HDFX-4K (<device id>) | WB | #be185d | https://img.hdhomerun.com/channels/US21233.png
 145.100 | WBFFMob         | HDFX-4K (<device id>) | WB | #0f766e | https://img.hdhomerun.com/channels/US21233.png
    9000 | FOX             | Verizon               | FO | #3f2e77 | https://tmsimg.fancybits.co/assets/s10212_ll_h15_ab.png?w=360&h=270
    9000 | CBS             | You Tube              | CB | #2f6fed | https://tmsimg.fancybits.co/assets/s28711_ll_h15_ab.png?w=360&h=270
    9001 | CBS             | Verizon               | CB | #2f6fed | https://tmsimg.fancybits.co/assets/s28711_ll_h15_ab.png?w=360&h=270
    9010 | BAL-CBSNEWS     | You Tube              | BA | #3f2e77 | https://tmsimg.fancybits.co/assets/s123127_ll_h9_aa.png?w=360&h=270
```

- **Five distinct files cover the eight rows.** 45.1, 145.1 and 145.100 share `US21233.png`;
  Verizon 9001 and YouTube 9000 share `s28711`.
- **Affiliation was confirmed from the artwork, not from station data.** Each file was drawn at the
  cell's 62 pt size and viewed (§5.4): `US21232` is the CBS eye wordmark, `US21233` the FOX wordmark,
  `s10212` FOX, `s28711` the CBS eye, and `s123127` "CBS NEWS BALTIMORE".
- **9010 BAL-CBSNEWS is included because its name and artwork carry CBS.** It is CBS News
  Baltimore's stream, not a broadcast affiliate.
- **Not fetched, because they are cable networks and not affiliates:** CBSSPORTS, CBSSPORTSHQ, FNC,
  FBN, FS2 and FXW.
- **Logos whose file suggests white artwork: none.** The grep:

```
=== logo URLs containing a token that names a colour or a light/dark variant
matches: 0
```

  (pattern `white|wht|light|dark|mono|black|reverse|invert|negative|knockout|_w\b|_wh`, over all 96
  logo URLs). **No logo was added on filename grounds.**

### 5.2 The fetches — all through the §3 form

```
=== step 5
== s5-antenna-13.1-WJZ-TV
   GET /api/art/feed?u=https%3A%2F%2Fimg.hdhomerun.com%2Fchannels%2FUS21232.png
   http=200 content_type=image/png bytes=4323
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
== s5-antenna-45.1-145.1-145.100-WBFF
   GET /api/art/feed?u=https%3A%2F%2Fimg.hdhomerun.com%2Fchannels%2FUS21233.png
   http=200 content_type=image/png bytes=3645
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
== s5-verizon-9000-FOX
   GET /api/art/feed?u=https%3A%2F%2Ftmsimg.fancybits.co%2Fassets%2Fs10212_ll_h15_ab.png%3Fw%3D360%26h%3D270
   http=200 content_type=image/png bytes=8623
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
== s5-verizon-9001-youtube-9000-CBS
   GET /api/art/feed?u=https%3A%2F%2Ftmsimg.fancybits.co%2Fassets%2Fs28711_ll_h15_ab.png%3Fw%3D360%26h%3D270
   http=200 content_type=image/png bytes=10642
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
== s5-youtube-9010-BAL-CBSNEWS
   GET /api/art/feed?u=https%3A%2F%2Ftmsimg.fancybits.co%2Fassets%2Fs123127_ll_h9_aa.png%3Fw%3D360%26h%3D270
   http=200 content_type=image/png bytes=37243
   Cache-Control: private, max-age=86400
   file: PNG image data, 360 x 270, 8-bit/color RGBA, non-interlaced
```

### 5.3 Format, alpha and dominant opaque colour — Python (Pillow 11.3.0)

```
$ python3 analyze.py "161826:unfocused#161826" "27273F:focused#27273F" -- logos/s5-antenna-13.1-WJZ-TV logos/s5-antenna-45.1-145.1-145.100-WBFF logos/s5-verizon-9000-FOX logos/s5-verizon-9001-youtube-9000-CBS logos/s5-youtube-9010-BAL-CBSNEWS
== logos/s5-antenna-13.1-WJZ-TV
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=19006 (19.6%)  fully transparent(a=0)=77877 (80.1%)
   opaque colour #1: #FFFFFF (100.0% of opaque)  vs unfocused#161826 17.61:1  vs focused#27273F 14.50:1
   opaque colour #2: #FAF4DC (0.0% of opaque)  vs unfocused#161826 15.96:1  vs focused#27273F 13.15:1
== logos/s5-antenna-45.1-145.1-145.100-WBFF
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=38679 (39.8%)  fully transparent(a=0)=58286 (60.0%)
   opaque colour #1: #F6F5FF (100.0% of opaque)  vs unfocused#161826 16.28:1  vs focused#27273F 13.41:1
== logos/s5-verizon-9000-FOX
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=37199 (38.3%)  fully transparent(a=0)=56661 (58.3%)
   opaque colour #1: #01000D (100.0% of opaque)  vs unfocused#161826 1.18:1  vs focused#27273F 1.44:1
== logos/s5-verizon-9001-youtube-9000-CBS
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=17489 (18.0%)  fully transparent(a=0)=76079 (78.3%)
   opaque colour #1: #000000 (100.0% of opaque)  vs unfocused#161826 1.19:1  vs focused#27273F 1.45:1
== logos/s5-youtube-9010-BAL-CBSNEWS
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=9506 (9.8%)  fully transparent(a=0)=80210 (82.5%)
   opaque colour #1: #434242 (100.0% of opaque)  vs unfocused#161826 1.76:1  vs focused#27273F 1.45:1
```

The same analysis over the two §3 files, for reference:

```
== logos/s3-antenna-2.1-WMAR-HD
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=51713 (53.2%)  fully transparent(a=0)=45297 (46.6%)
   opaque colour #1: #0A1320 (79.9% of opaque)  vs unfocused#161826 1.06:1  vs focused#27273F 1.29:1
   opaque colour #2: #FFFFFF (19.4% of opaque)  vs unfocused#161826 17.61:1  vs focused#27273F 14.50:1
   opaque colour #3: #010207 (0.2% of opaque)  vs unfocused#161826 1.18:1  vs focused#27273F 1.43:1
== logos/s3-m3u-philo-9005-AMC
   format=PNG mode=RGBA size=360x270 alpha_channel=True
   pixels: opaque(a>=250)=59040 (60.7%)  fully transparent(a=0)=36720 (37.8%)
   opaque colour #1: #040707 (72.9% of opaque)  vs unfocused#161826 1.15:1  vs focused#27273F 1.39:1
   opaque colour #2: #FFFFFF (23.3% of opaque)  vs unfocused#161826 17.61:1  vs focused#27273F 14.50:1
   opaque colour #3: #181B1B (0.5% of opaque)  vs unfocused#161826 1.02:1  vs focused#27273F 1.20:1
```

**Method.** "Opaque" is alpha ≥ 250. "Dominant" is the most populous 4-bit-per-channel colour bucket,
reported as its members' mean. Contrast is the WCAG 2.x ratio. The script is in the appendix.
**"Invisible" means a ratio under 1.5:1 — that threshold is this pass's choice.** WCAG's own
non-text minimum is 3:1, given for reference.

| Logo (rows) | Format | Alpha | Dominant opaque colour | vs `#161826` unfocused | vs `#27273F` focused |
|---|---|---|---|---|---|
| WJZ-TV 13.1 — antenna, CBS | PNG 360×270 | **yes** (80.1 % fully transparent) | **`#FFFFFF`** | 17.61:1 — visible | 14.50:1 — visible |
| WBFF 45.1 / 145.1 / 145.100 — antenna, FOX | PNG 360×270 | **yes** (60.0 %) | **`#F6F5FF`** | 16.28:1 — visible | 13.41:1 — visible |
| FOX 9000 — Verizon | PNG 360×270 | **yes** (58.3 %) | **`#01000D`** | **1.18:1 — invisible** | **1.44:1 — invisible** |
| CBS 9001 Verizon / 9000 YouTube | PNG 360×270 | **yes** (78.3 %) | **`#000000`** | **1.19:1 — invisible** | **1.45:1 — invisible** |
| BAL-CBSNEWS 9010 — YouTube | PNG 360×270 | **yes** (82.5 %) | **`#434242`** | 1.76:1 — not under 1.5, but under 3:1 | **1.45:1 — invisible** |

**Invisible unfocused:** Verizon FOX 9000, and the CBS file shared by Verizon 9001 and YouTube 9000.
**Invisible focused:** those two, and BAL-CBSNEWS 9010. **Visible on both:** the two antenna logos —
the white ones.

The two §3 references are two-tone. Each has a dark shape — WMAR's disc, AMC's box — at 1.06–1.39:1,
with white letters at 14.50–17.61:1. The shape disappears and the letters stay.

### 5.4 Seen at the size the cell would draw them

Each logo was composited aspect-fit into the 62 pt tile over `#FFFFFF`, `#161826` and `#27273F`, and
the sheet was viewed. The sheet stays in the scratchpad and is not committed — it is third-party
artwork.

```
fit size inside the 62x62 tile: (62, 46) | sheet: (1638, 1794)
```

- **On the two dark grounds**, the antenna CBS and FOX wordmarks read clearly white. The Verizon FOX
  and the Verizon/YouTube CBS wordmarks are black shapes, only just distinguishable from the ground.
  CBS NEWS BALTIMORE is faint grey.
- **On white**, the two black logos are crisp, and the antenna FOX (`#F6F5FF`) almost disappears.
- **This matches the ratios in §5.3.**

---

## 6. Step 6 — the reference clone

```
$ git rev-parse HEAD            (in ~/Xcode/marlin-dvr-reference)
eb0c098de3efc8bb569e252b63e141aa10262918
$ git rev-parse origin/main
eb0c098de3efc8bb569e252b63e141aa10262918
$ git log -1 --format='%h %ci %s' HEAD
eb0c098 2026-09-11 22:49:25 -0400 Pass 94: record the push evidence in the report's GIT section
$ sed -n '36,40p' cmd/marlin-dvr/main.go
const (
	appName    = "marlin-dvr"
	appVersion = "1.8.1"
```

**`HEAD` = `origin/main` = `eb0c098`.** `origin/main` is the ref as last fetched — this pass did not
fetch there. **The clone is 1.8.1 and the server answers 1.8.2**, so every line below is 1.8.1 source.

- **`sources.go:79`** — `Logo string \`json:"logo"\``, the logo field of `type Channel` (`:74-86`),
  "one entry of a source's lineup as imported".
- **`sources.go:113`** — `Logo string \`json:"logo"\``, the logo field of `type MergedChannel`
  (`:103-122`), the shape `/api/channels` serves. It has no `omitempty`.
- **`sources.go:582-583`** — `case "tvg-logo": c.Logo = m[2]`. The M3U `#EXTINF` parser copies a
  channel's `tvg-logo` attribute into its logo.
- **`guide.go:433-476`** — the HDHomeRun cloud-guide load.
  - `:433-436` record each channel's `ImageURL` by guide number.
  - `:437-466` build and merge the programmes.
  - `:468-476` write any non-empty logo that differs into the lineup's `Channel.Logo`, and call
    `a.saveLineup(l)` if one changed.

```
$ grep -n -i logo HLS-CLIENT-API.md
305:  {"id":"rad…","name":"…","format":"AAC","url":"https://…/stream","icon":"https://…/logo.png","iconUrl":"/api/art/feed?u=…"},
$ grep -n "^#" HLS-CLIENT-API.md   (excerpt)
294:## 9. Radio stations (Pass 33 — not HLS, not a play session)
341:## 10. Commercial segments (Pass 73 — read-only, live since Pass 76)
```

**Confirmed: the contract mentions "logo" exactly once, at `:305`, inside §9 (`:294`–`:340`).**

---

## 7. Step 7 — SWEEP or STANDALONE

**Only the one item the brief names is sorted. Nothing is added.**

| Item | App-target files a build would touch | Sort | Why, in one line |
|---|---|---|---|
| **Guide channel cell shows the logo via `/api/art/feed`, two-letter coloured tile fallback when logo is empty** | **`Marlin DVR TV/GuideScreen.swift`** — `ChannelCell`, `:805-838`, whose `:812` draws the tile today | **SWEEP** | It is a change to how one view looks, and §5 shows its result can only be judged by eye on the television: 3 of the 5 CBS/FOX files checked are black artwork at 1.18–1.76:1 on this cell. |

**Why one file** — traced, not built:

- `MergedChannel` already decodes `logo` (`Models.swift:25`), and the server's `initials` are two
  characters on 97 of 97 channels (§2).
- `ServerImage` already takes a path and a content mode (`ServerImage.swift:13-16`).
- `InitialsTile` already draws the coloured tile (`:38-54`).
- `ServerConfig.resolve` already resolves a server-relative path (`ServerAPI.swift:22-25`).
- The `/api/art/feed?u=` string is built from `logo` in the screen's own file, the way
  `OnLaterScreen.swift:75-83` builds its own.

**None of those files needs to change.**

---

## 8. Step 8 — before committing

The reading is §V1: `git fetch origin`; `git status --porcelain` → `?? icon-source/`;
`git rev-parse main origin/main` → `829e5d7…` twice; `0 0` ahead/behind; `git ls-remote origin main`
→ `829e5d7…`. **`main` was not ahead of `origin/main` at all**, so the stop condition — ahead by
anything other than Pass 84's notebook commit — did not arise. **Pass 84's notebook commit
`829e5d7` was already on `origin/main`: that is Pass 84's verified push SHA.** The reading after this
pass's edits, just before the commit, is §V3.

---

## 9. Files read

- **Required reading, in full:** `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md`, and the three memory
  notes.
- **App target, read only:**
  - In full: `ServerImage.swift`, `Theme.swift`.
  - In part: `Models.swift:1-60`; `GuideScreen.swift` (`:349-400`, `:745-844`, greps);
    `RadioStation.swift:1-59`; `RadioScreen.swift:240-271`; `ServerAPI.swift:1-60`;
    `OnLaterScreen.swift:55-100` and `:485-540`; `RemoteHold.swift:155-208`;
    `ScreenShell.swift:25-74`; `ScreenChrome.swift:80-110`.
  - `grep` over every `.swift` file in the target.
- **Reports, read only:** `2026-09-12-pass81-on-later-pills-recon.md` (`:1-70`, `:999-1167`, for this
  report's shape), and `grep` for SWEEP/STANDALONE over the Pass 39, 71, 75 and 81 reports.
- **`design/`, read only:**
  - `Marlin DVR TV.dc.html` — `:173-238`, `:1118-1126`, `:1177-1198`, and greps.
  - `grep` over `_ds/…/styles.css`.
  - `unzip -l ATV-DVR.zip`.
  - `screenshots/guide-3a.png`, viewed.
- **`~/Xcode/marlin-dvr-reference`, read only:**
  - `cmd/marlin-dvr/sources.go` — `:60-125`, `:560-590`.
  - `guide.go:433-476`.
  - `artwork.go:405-540`.
  - `radio.go` and `artwork.go` greps.
  - `main.go:36-40`.
  - `HLS-CLIENT-API.md` headings and the logo grep.
- **Server, GET only:** `/api/status` ×1, `/api/channels` ×1, `/api/radio` ×1, `/api/art/feed` ×7.

---

## 10. Open questions

Each question is the owner's to answer before a build prompt, with the evidence that raises it.
**None was acted on.**

1. **What should the cell do with black logo artwork?**
   - On this cell's dark ground, the Verizon FOX and the Verizon/YouTube CBS logos read at
     1.18–1.45:1, and CBS News Baltimore at 1.45:1 when focused (§5.3).
   - The brief anticipated white artwork. The white logos are the ones that read well here.
   - Design frame 3a has no logo and no backing to follow (§4.5).
   - Only five CBS/FOX files and two reference files were fetched. How many of the other logos are
     black is unmeasured.
2. **Fill or fit?**
   - Every logo fetched is 360 × 270 (7 of 7), and the tile is square.
   - `ServerImage` defaults to `.fill` (`ServerImage.swift:15`), which crops the sides of a 4:3 image
     into the square.
   - `.fit` draws 62 × 46 (§5.4).
   - `ChannelLogo` on On Now and Favorites uses the default `.fill` today (`:62`). Traced, not seen.
3. **Should a logo that fails to load also fall back to the tile?**
   - The brief names only an empty `logo`.
   - `ServerImage` draws the fallback for a failed load too (`ServerImage.swift:28`), so a build on it
     gets that whether asked or not.
   - Example: Marlin Cast 50002's logo URL is an `.svg` with `auto=webp`. It was not fetched, so
     whether the server serves it or answers 404 (`artwork.go:444`) is unmeasured.
4. **On Now and Favorites load the same logos straight from the provider**, not through
   `/api/art/feed`: `ChannelLogo` uses `channel.logo` (`ServerImage.swift:57-67`, used at
   `OnNowScreen.swift:245` and `FavoritesScreen.swift:146`). A Guide build through `/api/art/feed`
   would make the Guide the only screen whose logos come from the DVR's cache. Should the other two
   stay as they are? (Not sorted — not in the item.)
5. **"Two-letter": a rule, or today's data?**
   - The server's `initials` are two characters on 97 of 97 channels (§2).
   - `InitialsTile` draws the string as given (`ServerImage.swift:49`).
   - The design's own sample data carries a three-letter "AMC" (`dc:1093`).
6. **What does a Guide open cost?**
   - One `/api/art/feed` request per drawn row with a logo. COLD-START records that the Guide realises
     all its rows at once.
   - The server marks each `Cache-Control: private, max-age=86400` (measured, §3.3).
   - The app has no cache of its own (§3.2).
   - Whether a later Guide visit is served from the system cache is unmeasured.
   - On a first fetch the server also writes the image under `data/artwork/feed/` and logs an `ART`
     line (`artwork.go:447-453`).
7. **The server runs 1.8.2 and the clone is 1.8.1.** Every server-code citation here
   (`artwork.go`, `radio.go`, `sources.go`, `guide.go`) is 1.8.1 source. Should the clone be brought
   current before a build prompt relies on them? The clone is the owner's to update.

---

## 11. The three things I am least sure of

1. **That "invisible" describes what Home Theater will show.**
   - The 1.5:1 line is this pass's threshold.
   - The focused ground `#27273F` is computed from the tokens in gamma-encoded sRGB, not sampled from
     the television. tvOS may composite `opacity(0.14)` differently.
   - No logo was drawn in the app — there was no build and no device run.
   - The ratios are sound arithmetic on the files. How they look on the owner's screen is not
     measured.
2. **That Philo, Verizon and YouTube are M3U sources.**
   - `/api/channels` carries no source type.
   - The label rests on the notebook — the owner's Philo recordings at `COLD-START.md:502`, and "only
     m3u recordings" at `:516`.
   - It also rests on `sources.go:582-583` being the M3U logo path.
   - `GET /api/sources` was not read, because it is not in the steps.
   - The step 3 answer holds either way: the Philo logo came through the same form with 200,
     `image/png`, 12811 bytes.
3. **What `AsyncImage` does with a 404.**
   - §3.4 traces every non-image phase to `ServerImage.swift:28`, and I believe it.
   - Nobody ran it: no failing logo was loaded in the app this pass.
   - Whether the system caches the `/api/art/feed` responses across Guide visits is likewise Apple's
     behaviour, not measured here.

---

## 12. SCOPE CHECK — every path touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | **read**, in full | required reading |
| `Marlin DVR TV/*.swift` | **read only** (files listed in §9, plus greps) | 2, 3, 4, 7 |
| `reports/` (Pass 39, 71, 75, 81 reports) | **read only** | 7, report shape |
| `design/` | **read only, never written** | 4 |
| `~/Xcode/marlin-dvr-reference` | **`sed`, `grep`, `ls`, `git rev-parse`, `git log -1` only** — no fetch, no pull, no checkout, no edit, nothing run | 3, 6 |
| `http://192.168.1.250:8090/` | **GET only** — `/api/status`, `/api/channels`, `/api/radio`, `/api/art/feed` ×7. No POST, PUT or DELETE; no play session | 1, 2, 3, 5 |
| the session scratchpad | response bodies, the seven logo files, `analyze.py`, `urlcomp.swift`, the contact sheet — **outside the repo** | 2, 3, 5 |
| `COLD-START.md` | **edited**: the server-version line under "What is built" (1.8.1 → 1.8.2, the 1.8.1 reading kept as history), and a new head paragraph under "Next step" | notebook update |
| `DECISIONS.md` | **one entry appended**: 2026-09-13 (Pass 85 — the server answers 1.8.2) | measurement contradicting the notebook |
| `reports/2026-09-13-pass85-channel-logos-recon.md` | **created** | report |

**Not touched:** every Swift source, the Xcode project, `Info.plist`, the entitlements file, the asset
catalog, `build/`, `icon-source/`, the UI-test target, every other report, and every other folder under
`~/Xcode`. **No build, no test, no device run, no install.** The Unraid host, marlinpc, the HDHomeRun
and the UNAS4Pro share were not touched — the only traffic was the GETs above to the DVR's HTTP API.
**`GET /api/settings` was not read.**

**Disclosed side effect of the brief's own fetches.** `/api/art/feed` fetches an image it has not
cached from the provider, writes it under `data/artwork/feed/` and logs an `ART` line
(`artwork.go:435-453`). Whether each of the seven images was already cached was not measured, so this
pass may have caused up to seven such server-side writes.

---

## 13. Git

See §V1 for the reading before and §V3 for the reading after. The report and the two notebook files
are staged by name and committed in one commit, then pushed. The pushed SHA is verified after a fresh
`git fetch origin`, by `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all matching, and it is reported in the pass response — a commit cannot contain its own hash
(DECISIONS.md, 2026-09-09 (Pass 60) rule (b); 2026-09-11 (Pass 68)).

**Nothing forced. No history rewritten.**

---

## Appendix — `analyze.py` (scratchpad)

```python
#!/usr/bin/env python3
"""Pass 85 step 5: format, alpha, dominant opaque colour, and contrast against the cell backgrounds.

Usage: analyze.py BG_HEX[:label] [BG_HEX[:label] ...] -- FILE [FILE ...]
"""
import sys
from collections import Counter
from PIL import Image

def lum(rgb):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

args = sys.argv[1:]
split = args.index('--')
bgs = []
for spec in args[:split]:
    hexv, _, label = spec.partition(':')
    bgs.append((label or hexv, hexrgb(hexv)))
files = args[split + 1:]

for f in files:
    im = Image.open(f)
    fmt, mode, size = im.format, im.mode, im.size
    has_alpha_channel = mode in ('RGBA', 'LA', 'PA') or (mode == 'P' and 'transparency' in im.info)
    rgba = im.convert('RGBA')
    px = list(rgba.getdata())
    total = len(px)
    opaque = [p[:3] for p in px if p[3] >= 250]
    transparent = sum(1 for p in px if p[3] == 0)
    print(f"== {f}")
    print(f"   format={fmt} mode={mode} size={size[0]}x{size[1]} alpha_channel={has_alpha_channel}")
    print(f"   pixels: opaque(a>=250)={len(opaque)} ({100 * len(opaque) / total:.1f}%)  fully transparent(a=0)={transparent} ({100 * transparent / total:.1f}%)")
    if not opaque:
        print("   no opaque pixels")
        continue
    buckets = Counter((r >> 4, g >> 4, b >> 4) for r, g, b in opaque)
    for rank, (key, n) in enumerate(buckets.most_common(3), 1):
        members = [p for p in opaque if (p[0] >> 4, p[1] >> 4, p[2] >> 4) == key]
        mean = tuple(round(sum(c[i] for c in members) / len(members)) for i in range(3))
        hx = '#%02X%02X%02X' % mean
        share = 100 * n / len(opaque)
        cons = '  '.join(f"vs {label} {contrast(mean, rgb):.2f}:1" for label, rgb in bgs)
        print(f"   opaque colour #{rank}: {hx} ({share:.1f}% of opaque)  {cons}")
```
