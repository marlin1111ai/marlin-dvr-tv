# Pass 86 — channel logos in the Guide's channel cell

**Date:** 2026-09-13
**Committed locally and NOT pushed — the owner tests it on Home Theater first.**

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass85**, so this is
**Pass 86**. Pass 85's verified push SHA is **`3342b1d`**.

**What this pass is for.** The brief's five steps: in `ChannelCell`, draw the channel's logo in place
of the initials tile — fitted, never cropped, 6 pt inside the 62 pt tile. Request it only through
`/api/art/feed?u=`. Put a light neutral backing behind every logo (owner decision 1a). Keep the
initials tile for an empty `logo` and for a logo that fails to load. Move nothing else in the cell.

**The headline.**
- **Built, and the app-target diff is `GuideScreen.swift` alone: 57 insertions, 1 deletion.**
- **One run on Home Theater — `GuideChannelLogosUITests`, TEST SUCCEEDED, 238.705 s, 0 failures.**
  Three screenshots are in `reports/assets/pass86/`.
- **Requests:** the server's own log recorded **96 `GET /api/art/feed`** during the run — 95 answered
  200 and one 404. That matches the Guide's **96 rows that carry a logo**. The one 404 is 50002
  Science Channel, whose logo URL is an `.svg`; the device drew it as the initials tile.
- **The thing to look at first is `86a`.** On the light backing the owner chose, **the white antenna
  logos — WJZ-TV's CBS and WBFF45's FOX — are faint.** Measured on the logo files, they read at
  **1.23:1 and 1.14:1** against `#E4E7F5`. The black Verizon and YouTube CBS and FOX logos, invisible
  before, now read at **16.93–17.05:1** and are crisp in `86b`. Decision 1a swaps which logos are hard
  to see. Open question 1.

**Redaction.** The server log line for the app's launch ping carries this Apple TV's client id; it is
written below as `<client id>`. The HDHomeRun tuner's device id and device UDIDs are redacted wherever
tool output carried them.

---

## 1. Result, step by step

### Step 1 — the logo in place of the initials tile, through `/api/art/feed` — BUILT, RUN

- **`GuideScreen.swift:812`** — `ChannelCell` now draws `GuideChannelTile(channel: channel)` where it
  drew `InitialsTile(…, size: 62, …)`. This is the diff's one deleted line.
- **`GuideScreen.swift:840-895`** — the new `struct GuideChannelTile`, with its comment. Structure:
  - `:858` — `if let path = Self.artFeedPath(for: channel.logo)`: a logo takes this branch; an empty
    logo takes the `else`.
  - `:864` — `ServerImage(path: path, contentMode: .fit)`. `ServerImage` already accepts a content
    mode (`ServerImage.swift:15`), so **fit came without touching that file**.
  - `:871` — `.padding(Self.logoInset)`, 6 pt (`:850`).
  - `:873` — `.frame(width: Self.size, height: Self.size)`, 62 pt (`:849`).
  - `:887-893` — **`artFeedPath(for:)`**: `/api/art/feed?u=` plus the logo URL escaped the way Go's
    `url.QueryEscape` escapes it. Every byte except `A–Z a–z 0–9 - _ . ~` is percent-encoded, and a
    space becomes `+`. That is the exact form `radio.go:72` builds for radio icons. The provider's
    own URL is never handed to the loader.

**The escaping was checked before it went into the project**, with the same function copied into a
scratch Swift script:

```
$ xcrun swift artfeed-check.swift
radio WBAL NewsRadio 1090 identical to server iconUrl: true
radio WCBM Talk Radio 680 identical to server iconUrl: true
channel logos: identical to Go-style quote_plus: 58 | different: 0
edge: space -> /api/art/feed?u=https%3A%2F%2Fh%2Fa+b%2Bc | empty -> nil
resolves: http://192.168.1.250:8090/api/art/feed?u=https%3A%2F%2Ftmsimg.fancybits.co%2Fassets%2Fs28711_ll_h15_ab.png%3Fw%3D360%26h%3D270
```

- The two radio strings are the server's own `iconUrl`s.
- The 58 are every distinct logo URL in `/api/channels`, compared with Python's
  `quote_plus(url, safe="")`, the encoder Pass 85 proved identical to the server's.
- Python's own output for the edge case was `/api/art/feed?u=https%3A%2F%2Fh%2Fa+b%2Bc`, the same.

**On the device, each logo channel drew its logo.** A channel cell's accessibility label joins its
texts. While the initials tile is drawn it begins with the initials; an image has no text. The run
read, for example, `“WJZ-TV, 13.1”`, `“WBFF45, 45.1”`, `“FOX, 9000”` and `“CBS, 9000”` — no initials
— and the screenshots show the logos (§2).

### Step 2 — the light neutral backing behind every logo — BUILT, RUN

- **`GuideScreen.swift:860-863`** — a `RoundedRectangle(cornerRadius: Nocturne.Radius.sm, style:
  .continuous)` filling the 62 pt tile, **`.fill(Nocturne.neutral200)`**. It uses the same shape and
  radius as `InitialsTile` (`ServerImage.swift:45`).
- **Which colour: a design-system token, `Nocturne.neutral200` = `#E4E7F5`** (`Theme.swift:33`;
  `--color-neutral-200` in `design/_ds/…/styles.css:22`). The brief's `#E8E8EE` was only for a
  project with no light token. How the token was picked:

```
Nocturne.neutral100    #F3F5FE  euclidean RGB distance to #E8E8EE:  23.4
Nocturne.neutral200    #E4E7F5  euclidean RGB distance to #E8E8EE:   8.1
Nocturne.neutral300    #CFD3E5  euclidean RGB distance to #E8E8EE:  33.9
Nocturne.text          #E9E9ED  euclidean RGB distance to #E8E8EE:   1.7
Nocturne.accent200     #E7E5FE  euclidean RGB distance to #E8E8EE:  16.3
Nocturne.accent300     #D2CEFD  euclidean RGB distance to #E8E8EE:  37.2
```

  `neutral200` is the nearest step of the neutral ramp. `Nocturne.text` is nearer, but it is the text
  role, not a surface, so it was not used as a fill.
- **Measured on the television, not only in code.** The screenshot pixel 2 pt inside each logo tile's
  left edge is exactly the token:

```
86a 13.1 WJZ-TV:           pixel 2pt in from left edge #E4E7F5 | top colours [('#E4E7F5', 13665), ('#FFFFFF', 1365), …]
86a 45.1 WBFF45:           pixel 2pt in from left edge #E4E7F5 | top colours [('#E4E7F5', 12161), ('#F6F5FF', 2885), …]
86b 9000 FOX Verizon:      pixel 2pt in from left edge #E4E7F5 | top colours [('#E4E7F5', 12022), ('#01000D', 2793), …]
86b 9000 CBS YouTube:      pixel 2pt in from left edge #E4E7F5 | top colours [('#E4E7F5', 13537), ('#000000', 1251), ('#161826', 32)]
```

  (Sampled with Pillow from the 3840 × 2160 PNGs before JPEG conversion, at the tile boxes the harness
  reported.)

### Step 3 — empty logo, and a failed load — BUILT; the empty case RUN, the failure case RUN BY LABEL

**The STOP condition did not arise.** `ServerImage`'s existing fallback draws the initials tile, and
`ServerImage.swift` is unchanged — `git status` lists only `GuideScreen.swift` among app files.

- **Empty `logo`** → `artFeedPath` returns nil (`:888`). The `else` (`:874-876`) draws `initials`,
  which is **`InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: Self.size,
  fontSize: Nocturne.TextSize.floor)`** (`:879-881`). That is the call the old line 812 made, with
  `62` now spelled `Self.size`. **No `ServerImage`, no request, no backing.**
- **A load or decode failure** → `ServerImage`'s fallback closure (`:864-870`) draws the same
  `initials`, with two additions that change nothing about how the tile looks:
  - **`.padding(-Self.logoInset)` (`:867`)** lets the tile keep its full 62 pt inside a frame inset
    by 6.
  - **`.onAppear` / `.onDisappear` (`:868-869`) drive `showingInitials` (`:855`)**, which stops the
    backing being drawn while the fallback is showing (`:860`). The state starts `false`, so a logo
    already present at the first frame still gets its backing.

**What the run showed:**

- **9023 AS-INFOMERCIALS, photographed in `86c`:** label `“AS, AS-INFOMERCIALS, 9023”`. The tile
  samples **`#7C3AED`** — its server `logoBg`, `#7c3aed` in `GET /api/channels` (§4.1) — with its
  `#F3F5FE` initials. **The corner pixels are `#27273F`**, the focused cell's own background, and not
  the backing:

```
86c 9023 AS-INFOMERCIALS: pixel 2pt in from left edge #7C3AED | top colours [('#7C3AED', 14245), ('#F3F5FE', 646), ('#27273F', 32)]
```

- **A failed load, read and not photographed:** 50002 Science Channel's logo is
  `…/SCI-Default.svg?trimmed=false&auto=webp&ver=1&width=400`. The run read it as
  `“SC, Science Channel, 50002”` — the initials tile — at the end of the run, after the third
  screenshot. The server
  log holds **exactly one `GET /api/art/feed 404`** in the run window. The fallback-on-failure path
  therefore ran on the device. **That no backing sits under that tile is TRACED, not seen** — it was
  not photographed.

### Step 4 — nothing else in the cell moves — TRACED (as the brief requires), with incidental RUN sightings

- **The diff is two hunks and nothing else:**

```
$ git diff -U0 -- "Marlin DVR TV/GuideScreen.swift" | grep -E "^@@"
@@ -812 +812 @@ struct ChannelCell: View {
@@ -839,0 +840,56 @@ struct ChannelCell: View {
```

  The name, the gold ★ and the number (`:813-827`), the `Spacer` and padding (`:828-831`), and the
  focus fill and ring (`:832-836`) are all outside both hunks, so they are byte-identical.
- **Cell size 300 × 82 — traced.** `.frame(width: channelColumnWidth, height: rowHeight, …)` at
  `:772`, with the constants at `:351` and `:353`, is unchanged. The tile is a fixed 62 pt frame
  (`:873`) where the old tile was 62 pt too. *Run, incidentally:* the harness read focused cells at
  `frame=(236.0, 604.5, 300.0, 82.0)`.
- **Hold-to-favourite — traced.**
  - The cell is still the label of `HoldButton(hold:)` (`:769-774`).
  - `handleHold` (`:335-346`) still maps a hold on `"ch:<id>"` to `channelMenu = row.channel`.
  - `ChannelActionsMenu` (`:409-415`) still calls `model.setFavourite`.
  - None of those lines is in the diff.
  - `GuideChannelTile` has no `Button`, no `.focusable` and no gesture, so it cannot take the press.
  - **Not run** — no hold was pressed.
- **Focus — traced.** `.focused(focused, equals: channelFocusID)` at `:774` is unchanged, and nothing
  in the tile is focusable. *Run, incidentally:* focus walked the channel column one row a press — 5,
  6 and 56 presses to the three targets — and the 4 pt ring and fill are drawn on the focused cell in
  all three screenshots.
- **Build warnings — the same two as HEAD, measured.**
  - HEAD, built from `git archive 3342b1d`: `GuideScreen.swift:635` and `PlayerModel.swift:325`.
  - This tree, simulator: the same two.
  - The device build in the run: the same two.
  - Nothing new.

### Step 5 — commit, do not push — DONE

One commit carries the code, the harness, the screenshots, this report and the notebook. **Nothing
is pushed.** The reading before the commit is §4.

---

## 2. VERIFY — the one run on Home Theater

### 2.1 The command — the notebook's recorded method

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p86 test -only-testing:"Marlin DVR TVUITests/GuideChannelLogosUITests"
```

`build/p86` is git-ignored (`.gitignore:4:build/`). The result bundle stays there:
`build/p86/Logs/Test/Test-Marlin DVR TV-2026.09.13_13-04-59--0400.xcresult`.

### 2.2 The transcript

```
BEFORE 13:04:57
before: total 300 last seq 300 at 13:04:28.685
Test Case '-[Marlin_DVR_TVUITests.GuideChannelLogosUITests testTheGuideDrawsLogosOnTheirBackingAndTheInitialsTileWithoutOne]' started.
[pass86] OPEN collections=All Channels focus=["2026 U.S. Open Tennis: Men\'s Championship Preshow"]
[pass86] LOGO[13.1] drawn after ~0 s: “WJZ-TV, 13.1” frame=(246.0, 520.5, 174.0, 62.0)
[pass86] LOGO[45.1] drawn after ~0 s: “WBFF45, 45.1” frame=(246.0, 614.5, 180.0, 62.0)
[pass86] FOCUS[86a] on target after 5 press(es): “WBFF45, 45.1” frame=(236.0, 604.5, 300.0, 82.0)
[pass86] 86a 13.1=“WJZ-TV, 13.1” frame=(246.0, 520.5, 174.0, 62.0) 45.1=“WBFF45, 45.1” frame=(236.0, 604.5, 300.0, 82.0) focus=["WBFF45, 45.1"]
[pass86] FOCUS[86b] on target after 6 press(es): “FOX, 9000” frame=(236.0, 658.5, 300.0, 82.0)
[pass86] LOGO[FOX 9000] drawn after ~0 s: “FOX, 9000” frame=(236.0, 658.5, 300.0, 82.0)
[pass86] LOGO[CBS 9000] drawn after ~0 s: “CBS, 9000” frame=(246.0, 762.5, 136.5, 62.0)
[pass86] 86b FOX=“FOX, 9000” frame=(236.0, 658.5, 300.0, 82.0) CBS=“CBS, 9000” frame=(246.0, 762.5, 136.5, 62.0) focus=["FOX, 9000"]
[pass86] FOCUS[86c] on target after 56 press(es): “AS, AS-INFOMERCIALS, 9023” frame=(236.0, 658.5, 300.0, 82.0)
[pass86] 86c 9023=“AS, AS-INFOMERCIALS, 9023” frame=(236.0, 658.5, 300.0, 82.0) focus=["AS, AS-INFOMERCIALS, 9023"]
[pass86] READ 50000 NFL Network: logo — “NFL Network, 50000” frame=(246.0, 3300.5, 227.5, 62.0)
[pass86] READ 50001 Golf Channel: logo — “Golf Channel, 50001” frame=(246.0, 3394.5, 226.0, 62.0)
[pass86] READ 50002 Science Channel: initials tile — “SC, Science Channel, 50002” frame=(246.0, 3488.5, 251.5, 62.0)
Test Case '-[…testTheGuideDrawsLogosOnTheirBackingAndTheInitialsTileWithoutOne]' passed (238.705 seconds).
	 Executed 1 test, with 0 failures (0 unexpected) in 238.705 (238.708) seconds
** TEST SUCCEEDED **
xcodebuild exit=0
AFTER 13:09:10
after: total 412 last seq 412 at 13:08:28.941
```

- **The Guide was already on All Channels**, so the harness switched nothing and restored nothing.
- **"drawn after ~0 s"** means the logo had already loaded by the time the check ran — five seconds
  after the Guide opened, or later for the rows further down.

### 2.3 The three screenshots — `reports/assets/pass86/`

Exported with `xcrun xcresulttool export attachments`, then converted from 3840 × 2160 PNG to
1920 × 1080 JPEG with `sips -Z 1920 -s format jpeg`, so 1 px is 1 pt:

```
reports/assets/pass86/86a-white-antenna-logos-on-their-backing.jpg  1920x1080  187519 bytes  (from 9CCA14ED-….png)
reports/assets/pass86/86b-black-provider-logos-on-their-backing.jpg  1920x1080  186180 bytes  (from 9CFDDADB-….png)
reports/assets/pass86/86c-no-logo-the-initials-tile.jpg  1920x1080  189079 bytes  (from BE399E5F-….png)
```

| Screenshot | What it shows, as viewed |
|---|---|
| **`86a`** — a white antenna logo on its backing | The Guide on All Channels, 1:00–3:00 PM, with **WBFF45 45.1 focused** and **WJZ-TV 13.1** above it. Both tiles are the light backing. The CBS eye wordmark and the FOX wordmark are **white on it, and faint** — readable only on close inspection. Also in frame: WMAR-HD's black "abc" disc (clear), WGAL-TV's and WBAL-DT's NBC peacock (colours clear, the white "NBC" letters faint), and the orange CW logos (clear) |
| **`86b`** — a dark Verizon or YouTube CBS/FOX logo on its backing | **FOX 9000 (Verizon) focused**, **CBS 9000 (YouTube)** below. Both are black wordmarks on the backing, **crisp**. Also in frame: WBFF 145.1 and WBFFMob 145.100 (faint white FOX), AETV's A&E, and HISTORY 9001 with its ★ |
| **`86c`** — 9023 AS-INFOMERCIALS on the initials tile | **AS-INFOMERCIALS 9023 focused**, on the purple **"AS" initials tile** with no backing. The logo rows around it — REELZ, Discovery Life, NewsNation, turbo/MotorTrend, OWN, Discovery, FOX Weather — are on the backing |

### 2.4 The count of logo requests, and where they went

**Instruments was tried first, and could not see the device.** A client-side capture would show every
request the app makes — including any that went straight to a provider. The attempt and its
diagnosis:

```
$ xcrun xctrace record --template Network --device "Home Theater" --all-processes --time-limit 8s --no-prompt --output probe.trace
Waiting for device to boot
Timed out waiting for device to boot: Home Theater (26.6)
exit=13
$ xcrun xctrace list devices          (UDIDs redacted)
== Devices ==
marlin1111’s Mac Studio (<udid>)
== Devices Offline ==
Home Theater (26.6) (<udid>)
Marlin iPhone (26.6.2) (<udid>)
Master Bedroom ATV (26.6) (<udid>)
$ xcrun devicectl device info details --device "Home Theater"   (selected keys)
    • bootState: booted
    • ddiServicesAvailable: true
    • developerModeStatus: enabled
    • transportType: localNetwork
    • tunnelState: connected
```

- **CoreDevice has the Apple TV connected; Instruments lists it as offline**, and still did after
  the tunnel came up. The probe drove nothing on the television. **It was not retried.**

**What was measured instead: the server's own request log** (`GET /api/logs`), read immediately before
and after the run. The server writes one `HTTP` line per request, with method, path and status and no
query (`main.go:170-190` in the clone). Lines strictly after the before-snapshot's last `seq` (300):

```
lines in the run window: 112 | seq 301 - 412
HTTP lines in window by message:
     95  GET /api/art/feed 200
      2  GET /api/schedule 200
      1  GET /api/radio 200
      1  GET /api/library 200
      1  GET /api/channels 200
      1  POST /api/clients/<client id>/ping 200
      1  GET /api/cameras 200
      1  GET /api/guide/now 200
      1  GET /api/guide 200
      1  GET /api/art/feed 404
art/feed lines: 96 | first 13:05:18.199 | last 13:05:18.320
art/feed by minute: {'13:05': 96}
```

And the lineup the Guide draws, from `GET /api/guide?slots=1` at 12:57:

```
Guide rows (GET /api/guide?slots=1, 12:57): 97 | rows with a logo: 96 | rows without: 1 | distinct logo URLs: 58
```

**The count: 96 logo requests observed, all of them `GET /api/art/feed`** — 95 × 200 and 1 × 404, all
within **121 ms** at 13:05:18, when the Guide opened. That is **exactly one per row with a logo**, not
one per distinct URL.

- **The rest of the window is this app's own launch and Home screen:** the ping, `/api/schedule`,
  `/api/library`, `/api/radio`, `/api/cameras`, `/api/guide/now`, `/api/channels`, and the Guide's
  `/api/guide`.
- **Before the run the server was nearly idle**: one `HTTP` line at 12:56 and one at 13:01 in the
  pre-run snapshot (§4.1).

**What this measurement cannot show, stated plainly:**
- The server log has **no client identity**, so attributing all 96 to Home Theater rests on the timing
  and on the one-per-logo-row match.
- A request that went **straight to a provider** would never reach this server. **"Every one went to
  `/api/art/feed`" is therefore observed for the 96 the server saw.** That no request went anywhere
  else is **TRACED**:
  - `artFeedPath` (`:887-893`) is the only path `GuideChannelTile` passes to `ServerImage`.
  - `channel.logo` itself is never passed to a loader in `GuideScreen.swift`.
  - `ServerImage` requests only what `ServerConfig.resolve` makes of the path it is given
    (`ServerImage.swift:19-20`, `ServerAPI.swift:22-25`).

### 2.5 RUN vs TRACED, in one place

| Claim | How established |
|---|---|
| A logo draws in place of the tile, fitted, inside the tile | **RUN** — `86a`, `86b`, and the labels |
| The request form is `/api/art/feed?u=` + Go-escaped URL | **RUN** outside the project (the scratch Swift check); in the app, **TRACED** (`:887-893`) |
| 96 logo requests, all to `/api/art/feed` | **RUN** — server log; that none went to a provider is **TRACED** |
| Backing is `#E4E7F5`, behind every logo | **RUN** — pixel samples on four tiles; "every" is **TRACED** (the one branch, `:860-863`) |
| Empty logo → initials tile, no backing | **RUN** — `86c` and its pixel sample |
| Failed load → initials tile | **RUN** by label — 50002 after the one 404 |
| Failed load → no backing under it | **TRACED** — `:855`, `:860`, `:868-869` |
| Name, ★, number unchanged | **TRACED** — outside both diff hunks; seen in the screenshots |
| Hold-to-favourite unchanged | **TRACED** — `:335-346`, `:409-415`, `:769-774` |
| Focus behaviour unchanged | **TRACED** — `:774`, `:832-836`; focus moved one row a press in the run |
| Cell 300 × 82 | **TRACED** — `:351`, `:353`, `:772`; focused frames read 300 × 82 in the run |
| No new build warning | **RUN** — clean builds of HEAD and this tree |

---

## 3. Files touched, mapped to steps

| Path | Change | Step |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | +57 −1: `:812` and `GuideChannelTile` at `:840-895` | 1, 2, 3, 4 |
| `Marlin DVR TVUITests/GuideChannelLogosUITests.swift` | **new**, 226 lines — the evidence harness, UI-test target, no app code | VERIFY |
| `reports/assets/pass86/86a-…jpg`, `86b-…jpg`, `86c-…jpg` | **new** — the three screenshots | VERIFY |
| `reports/2026-09-13-pass86-channel-logos.md` | **new** — this report | REPORT |
| `DECISIONS.md` | one entry appended: 2026-09-13 (Pass 86), with decision 1a, the two owner-approved calls and Pass 85's SHA | REPORT |
| `COLD-START.md` | a new head paragraph under "Next step": committed and NOT pushed, the owner tests first, and the harness command | REPORT |

**Not touched:** `ServerImage.swift`, `Models.swift`, every other Swift source, the Xcode project,
`Info.plist`, the entitlements file, the asset catalog, `design/`, `~/Xcode/marlin-dvr-reference`
(read with `sed` and `grep` only), `icon-source/`, and every earlier report.
- **No new cache, loader, dependency or asset in the app.**
- **Server:** GET only — `/api/guide?slots=1`, `/api/collections`, `/api/logs` ×3, plus the app's own
  traffic during the run.
- **Scratchpad only, outside the repo:** the escaping check, the HEAD build copy and its derived data,
  the log snapshots, the exported PNGs, and the trace probe.

---

## 4. Before the commit

### 4.1 The reading immediately before staging

```
=== client id, tuner device id, UUID-shaped ids: report, harness, and git diff
pattern <client id>  report:0 harness:0 diff:0
pattern <tuner id>  report:0 harness:0 diff:0
pattern UUID  report:0 harness:0 diff:0
=== credential-shaped strings
Marlin DVR TVUITests/GuideChannelLogosUITests.swift:0
reports/2026-09-13-pass86-channel-logos.md:0
0
=== git status --porcelain
 M COLD-START.md
 M DECISIONS.md
 M "Marlin DVR TV/GuideScreen.swift"
?? "Marlin DVR TVUITests/GuideChannelLogosUITests.swift"
?? icon-source/
?? reports/2026-09-13-pass86-channel-logos.md
?? reports/assets/pass86/
=== git diff --numstat
35	0	COLD-START.md
25	0	DECISIONS.md
57	1	Marlin DVR TV/GuideScreen.swift
=== 9023 logoBg (GET /api/channels, saved 12:25)
9023 AS-INFOMERCIALS Philo initials AS logoBg #7c3aed logo ''
=== HTTP lines per minute before the run (logs-before.json, last 8 minutes that had any)
[('12:02', 8), ('12:03', 2), ('12:07', 9), ('12:25', 2), ('12:26', 1), ('12:31', 7), ('12:56', 1), ('13:01', 1)]
```

- **The scan patterns:**
  - this Apple TV's client id;
  - the HDHomeRun tuner's device id;
  - the 8-4-4-4-12 UUID shape;
  - `password|passwd|secret|api[_-]?key|token=|bearer |authorization:|BEGIN … PRIVATE|…`.
- **The 12:31 minute** is Pass 85's seven logo fetches.
- **The report was scanned before this section was added.** This section adds no identifier.
- **Staging is by name, three kinds of path:** the three modified files; the harness, the report and
  `reports/assets/pass86/`; and nothing else. `icon-source/` stays untracked.

---

## 5. What is pushed, and what stays local

- **Pushed: nothing.** Pass 86's commit is local; the owner tests on Home Theater first.
  `origin/main` stays at `3342b1d`.
- **Local and untracked, deliberately:** `icon-source/`, the standing baseline since Passes 51–55.
- **Local, git-ignored:** `build/p86/`, holding the device build and the result bundle.
- **Outside the repo:** the session scratchpad.

---

## 6. Open questions

Each is the owner's to answer. **None was acted on.**

1. **On the light backing, the white logos are the faint ones.**
   - WJZ-TV's CBS (`#FFFFFF`) and WBFF45's FOX (`#F6F5FF`) measure **1.23:1 and 1.14:1** against
     `#E4E7F5` on the logo files. `86a` shows them faint. So do WBFF 145.1 and WBFFMob 145.100 in
     `86b`, which share WBFF's file.
   - The white "NBC" letters on WGAL-TV and WBAL-DT are faint too (seen, not measured).
   - The black Verizon and YouTube logos went the other way: from 1.18–1.45:1 on the dark cell to
     **16.93–17.05:1** on the backing.
   - Measured on the logo files, one backing cannot serve both kinds of artwork. How the owner wants
     to treat that is his decision, and nothing was built toward any answer.
2. **The Guide made 96 requests for 58 distinct logo URLs.** `AsyncImage` does not share a request
   between cells showing the same URL — AMC, for one, is three rows. The server marks each response
   `Cache-Control: private, max-age=86400` (Pass 85 §3.3). **Whether a second visit to the Guide is
   served from cache was not measured**: the run opened the Guide once.
3. **A logo channel's accessibility label lost its initials** — "WJZ-TV, 13.1" where it was
   "WJ, WJZ-TV, 13.1" — because the tile is now an image. Nothing on screen changes, and no existing
   harness matches on the initials (grep, §1 step 4). Is it acceptable that a screen reader no longer
   hears them?
4. **The hold menu's header still shows the initials tile** (`ChannelActionsMenu.swift:41`), so a
   channel that shows its logo in the cell shows its initials in the menu opened from the same cell.
   That is outside this pass's one file, and it is not changed. Should it follow?
5. **On Now and Favorites still load logos straight from the provider, filled and not fitted**
   (`ChannelLogo`, `ServerImage.swift:57-67`). Pass 85 open question 4 stands.
6. **The one failed logo is a `.svg` URL**: 50002 Science Channel on Marlin Cast, `…SCI-Default.svg…`.
   The server answered 404 and the initials tile was drawn, which is the decided behaviour. Whether
   that source should supply a different logo is outside this app.

---

## 7. The three things I am least sure of

1. **That the 96 requests the server logged are all Home Theater's, and that nothing went around the
   server.**
   - The log has no client identity.
   - Attribution rests on all 96 falling within 121 ms as the Guide opened, and on the count equalling
     the 96 rows with a logo.
   - Instruments could not see the device (§2.4), so no client-side capture exists. That no request
     went straight to a provider is traced from the code, not observed.
2. **The backing's show-and-hide on the fallback path.**
   - `showingInitials` is driven by the fallback's `onAppear` and `onDisappear` inside `AsyncImage`'s
     content.
   - The success path is proven: the backing is present on every photographed logo, so either the
     state was never set or `onDisappear` fired.
   - The failure path — no backing under 50002's tile — is traced only. It was read by label and not
     photographed.
   - It starts `false` on purpose, so a tile that loads while its fallback is still appearing could
     show the backing under the initials for about a frame. That was not observed, and not looked for.
3. **That `86a` shows what the owner meant by "on its backing".**
   - The backing is exactly the token and the logos are there, but faint — measured at 1.14–1.23:1
     and plain in the screenshot.
   - Whether that reads as done or as the problem in open question 1 is for the owner, on Home
     Theater, to judge.
