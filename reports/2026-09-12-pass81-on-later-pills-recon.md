# Pass 81 — On Later pills: recon

**Date:** 2026-09-12
**READ-ONLY. Exactly one file is written by this pass: this report.** No Swift file, project file,
`Info.plist`, entitlements file or asset was modified. `design/` was read and never written.
`~/Xcode/marlin-dvr-reference` was read with `cat`, `grep` and `git rev-parse` only — never edited,
never fetched, never checked out to another commit, nothing run from it. **Every request to
`http://192.168.1.250:8090/` was a GET; no POST, PUT or DELETE of any kind was sent.** No build, no
device run, no install. No probe file and no scratch file was left in the repo.

**Pass number.** The highest-numbered report in `reports/` before this pass was **pass80**, so this
is **Pass 81**.

**What this pass is for.** The owner's goal of 2026-09-12: *On Later takes On Now's page layout and
its header pill row, with exactly three pills — "On Today", "On This Week", "Premieres". Premieres =
season premieres and series premieres. No channel-filter pills on On Later.* This pass reconnoitres
that and nothing else. **Nothing is chosen, proposed or designed here beyond what the numbered steps
ask for.**

**The headline, so it is not buried.** The owner's guide data contains **no premieres at all**.
`program.premiere` is true on **0 of 16,121** distinct airings measured live today, and the key never
appears in a single response body. The pill has nothing to filter on. §4.4 and Open Question 1.

---

## VERIFY — the evidence the brief asks to be shown

### V1. `git status` before step 1

```
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	icon-source/

nothing added to commit but untracked files present (use "git add" to track)

$ git status --porcelain --untracked-files=normal
?? icon-source/
```

`icon-source/` is the standing untracked baseline — its fate the owner's undecided call since
Passes 51–55 (`DECISIONS.md`, 2026-09-08). No tracked file was modified by this pass.

*(The `git status` **after** is in §V6.)*

### V2. The live server, and the reference clone

```
$ curl -s http://192.168.1.250:8090/api/status
{"name":"marlin-dvr","version":"1.8.1","uptime_seconds":81092,"port":8089}
```

```
$ git rev-parse HEAD            (in ~/Xcode/marlin-dvr-reference)
eb0c098de3efc8bb569e252b63e141aa10262918
$ git rev-parse origin/main
eb0c098de3efc8bb569e252b63e141aa10262918
$ sed -n '36,40p' cmd/marlin-dvr/main.go
const (
	appName    = "marlin-dvr"
	appVersion = "1.8.1"
	appBuild   = "2026.09.05"
	webDir     = "web"
```

**The running server and the checked-out clone are both 1.8.1**, and `HEAD` equals `origin/main`, so
every `guide.go` / `sources.go` line cited below resolves the same at either ref. Nothing was
fetched, checked out or edited in the clone.

### V3. `GET /api/guide/later`, and its parameters

```
$ curl -s http://192.168.1.250:8090/api/guide/later
HTTP 200 · 37404 bytes · 0.033 s
top-level keys : ['sections']
 section label='On Today'      items=24   item keys: art, channel, channelId, program,
                                                     scheduled, start, subtitle, title, when
 section label='On This Week'  items=24   item keys: (identical)

On Today       first start Sat 18:30   last start Sat 20:30   distinct channels 20
On This Week   first start Sun 00:10   last start Sun 06:00   distinct channels 11
both sections sorted ascending by start: True
scheduled=true : 0 of 24 in each section
```

**Both sections are at the server's 24-item cap**, and "On Today" reaches only two hours into the
rest of today while "On This Week" reaches only six hours into the next six days.

**The route takes no parameters at all.** Seven different query strings, all GET, all answering
**byte-identical** bodies:

```
                                                   HTTP  bytes  sha256 (first 16)
/api/guide/later                                    200  37404  180865c46d20d271
/api/guide/later?limit=100                          200  37404  180865c46d20d271
/api/guide/later?filter=col-1788571411827           200  37404  180865c46d20d271
/api/guide/later?premiere=1                         200  37404  180865c46d20d271
/api/guide/later?days=1                             200  37404  180865c46d20d271
/api/guide/later?source=Philo                       200  37404  180865c46d20d271
/api/guide/later?section=today                      200  37404  180865c46d20d271
```

One item, verbatim and entire — the first of "On Today":

```json
{
  "title": "Godzilla x Kong: The New Empire (2024)",
  "subtitle": "Directed by: Adam Wingard",
  "channel": "9004 · TBSP",
  "channelId": "verizon:6034",
  "start": 1789252200,
  "when": "Sat 6:30 PM",
  "scheduled": false,
  "program": {
    "channel": "6034",
    "start": 1789252200,
    "end": 1789261200,
    "title": "Godzilla x Kong: The New Empire (2024)",
    "episodeTitle": "Directed by: Adam Wingard",
    "desc": "Godzilla and the almighty Kong face a colossal threat hidden deep within the planet.",
    "categories": ["Movie", "Feature Film", "Science Fiction", "Action", "Adventure"],
    "icon": "https://tmsimg.fancybits.co/assets/p24587599_v_v12_ab.jpg?w=480&h=720",
    "seriesId": "title:godzilla x kong: the new empire (2024)",
    "rating": "PG-13",
    "originalAirDate": "20240327",
    "video": "HDTV"
  },
  "art": "/api/art/feed?u=…&title=Godzilla+x+Kong%3A+The+New+Empire+%282024%29"
}
```

**`program` is non-null on all 48 items**, and the union of `program` keys across all 48 is:

```
categories, channel, desc, end, episode, episodeNum, episodeTitle, icon, live, new,
originalAirDate, rating, season, seriesId, start, title, video
```

**`premiere` and `finale` do not appear once.** They carry `omitempty` (`guide.go:32-33`), so a
`false` is omitted from the JSON entirely rather than sent as `false`.

### V4. The flags, measured over the whole guide

Eight GETs of `GET /api/guide?start=<now-half-hour + N·86400>&slots=48` for N = 0…7, ~1.2 MB each,
yielding **16,121 distinct airings** (deduplicated on `channelId` + `program.start`) across 91 rows:

```
raw string scan of every response body
                 premiere:true  finale:true  new:true  live:true
guide_d0.json          0             0          180        87
guide_d1.json          0             0          168        69
guide_d2.json          0             0          156        60
guide_d3.json          0             0          174        77
guide_d4.json          0             0          173        73
guide_d5.json          0             0          170        74
guide_d6.json          0             0          167        78
guide_d7.json          0             0          154        85
later.json             0             0           29        12

$ grep -o '"premiere":[a-z]*' guide_d0.json | sort | uniq -c
(no output — the key is absent entirely, which is what omitempty does)

flag tally over all 16,121 collected airings
   new              1325
   Movie category    671
   live              589
   premiere            0
   finale              0

per source
  HDFX-4K (…)   airings=31     new=18    live=0     premiere=0  finale=0
  Marlin Cast   airings=702    new=0     live=0     premiere=0  finale=0
  Philo         airings=6167   new=380   live=42    premiere=0  finale=0
  Verizon       airings=9221   new=927   live=547   premiere=0  finale=0
```

Three independent cross-checks, all zero:

```
$ curl -s .../api/guide/now
count 91 · flags set on the 91 current programmes: {'new': 21, 'live': 11}   premiere: 0

$ curl -s '.../api/guide/search?title=Ghost%20Adventures'
count 58 · first Sat 2026-09-12 18:00 · last Thu 2026-09-24 15:00
premiere==true among matches: 0

$ curl -s .../api/schedule
count=5 passes=6 · job starts Tue 09-15 20:55 .. Tue 09-22 21:58
premiere among job programs: 0
```

### V5. Reach, channels and counts

```
$ curl -s .../api/guide/stats
{"lineups":4,"channels":103,"channelsWithGuide":103,"shows":2019,"listings":29104,
 "bytesOnDisk":17535827,"sizeLabel":"16.72 MB","refreshedAt":"2026-09-12T17:06:19-04:00",
 "refreshedLine":"Last refreshed 1 hours ago","status":"Idle","coverageUntil":"Sat 3:00 PM"}

probe fetches of /api/guide?start=<now+Nd>&slots=48
 + 8d  Sun, Sep 20  programme-blocks=2011  rows-with-listings=77/91  latest end Mon 2026-09-21 20:30
 +10d  Tue, Sep 22  programme-blocks=2032  rows-with-listings=77/91  latest end Thu 2026-09-24 05:00
 +12d  Thu, Sep 24  programme-blocks=1943  rows-with-listings=77/91  latest end Sat 2026-09-26 05:00
 +14d  Sat, Sep 26  programme-blocks=0     rows-with-listings=0 /91  latest end none
 +16d  Mon, Sep 28  programme-blocks=0     rows-with-listings=0 /91  latest end none

$ curl -s .../api/channels            count=91   drm=0  hidden=0
$ curl -s '.../api/channels?hidden=1' count=103  drm=5  hidden=12
  sources (both): HDFX-4K (…), Philo, Verizon, Marlin Cast
```

**All five DRM channels are among the twelve hidden ones.**

Counts derived from the 16,121, with `now = Sat 2026-09-12 18:08:35 EDT`,
`endToday = Sat 23:59:59`, `endWeek = Fri 2026-09-18 23:59:59`:

| Reading | On Today | On This Week |
|---|---|---|
| every future airing in the server's window (DRM included) | **419** | **12,234** |
| "notable" by the server's own test (new\|premiere\|live\|finale\|Movie category) | **86** | **1,430** |
| notable **and** deduped by `seriesId`, before the cap | **45** | **436** |
| what `/api/guide/later` actually returns (the 24 cap) | **24** | **24** |
| `premiere == true` | **0** | **0** |

The replication was validated against the live body rather than trusted: it reproduces both cap
boundaries exactly — today's 24th item at **Sat 20:30** and the week's 24th at **Sun 06:00**, the same
two instants the live response ends on — and its "On Today" 24 are **set-identical** to the live 24.
Its "On This Week" 24 share **22 of 24** with the live one; the two it misses (*Hit the Road*,
*Zero Waste Life*) are **absent from the `/api/guide` data altogether**, which is the ~3 % of listings
that route's block builder is known to drop (DECISIONS.md, 2026-09-11 (Passes 62-65)).

### V6. `git status` after step 8

```
$ git status --porcelain --untracked-files=normal
?? icon-source/
?? reports/2026-09-12-pass81-on-later-pills-recon.md

$ git diff HEAD --stat
(empty — no tracked file modified, nothing staged)
```

**Before and after differ by exactly one entry: this report.** The report is staged **by name** and
committed on its own, so `icon-source/` cannot be swept in.

---

## 1. Step 1 — everything that was read, and the count

**No "likely files" subset was used for the app target.** Every app Swift file was opened in full.

| Group | Count | How |
|---|---|---|
| App Swift sources, `Marlin DVR TV/*.swift` | **49** | every one, **read in full** (12,097 lines) |
| UI-test Swift sources, `Marlin DVR TVUITests/*.swift` | **15** | every one **opened**; six read in full, the other nine read header + every `func test` + a full `grep` for `later`/`premiere` (4,445 lines) |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **1** | 441 lines, read for the target/SDK/bundle settings |
| `design/` | **14** | `Marlin DVR TV.dc.html` (frames 1b and 5a and the data blocks) and `_ds/…/readme.md` read; `styles.css` searched by pattern; the other eleven enumerated |
| Notebook: `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | **3** | all three **read in full** (1,444 + 1,432 lines) |
| The two reports the brief names | **2** | `2026-09-05-pass2-server-recon.md` and `2026-09-11-pass71-guide-collections-recon.md`, read in full |
| Other reports in `reports/` | **77** | enumerated; not read this pass — `COLD-START.md` and `DECISIONS.md` carry what they settle |
| Reference clone, read-only | **7 Go files** | `guide.go`, `sources.go`, `main.go`, `export.go`, `collections.go`, plus `passes.go` and `library.go` by pattern |

**Total opened: 84 files in the working tree** (49 + 15 + 1 + 14 + 3 + 2), plus the seven Go files in
the read-only clone.

**One fact from step 1 that frames the whole pass.** `grep -rn` over all 49 app Swift files for
`guide/later|api\.later|OnLater|premiere|On Today|On This Week|LaterItem|LaterSection` returns
**31 lines in 8 files**, and every one of them is either `OnLaterScreen.swift`, its two model types
in `Models.swift`, the one typed call in `ChannelFilter.swift`, the rail/tile entries in
`Destination.swift`, the Home tile's line in `HomeView.swift`, the shell's routing line, or the two
places a "Premiere" tag is drawn. **Nothing else in the app touches On Later or the premiere flag.**

---

## 2. Step 2 — what On Now does today

`Marlin DVR TV/OnNowScreen.swift`, 343 lines. Everything below is from it unless another file is named.

### 2.1 The pill row — where it is

It is **not** in the header. `OnNowScreen.body` is a `VStack(alignment: .leading, spacing: 34)`
(**`:134`**) whose first two children are the header and then the pills:

```swift
ScreenHeader("On Now", subtitle: subtitle)      // :135
chips                                           // :136
```

so the row sits **34 pt below the title row**, full width, left-aligned. `ScreenHeader`
(`ScreenChrome.swift:13-65`) is given **no accessory and no trailing closure** here — its two
optional slots are unused on this screen, and its subtitle is
`"Refreshed 6:07 PM · 91 channels"` (`:190-195`).

### 2.2 The pill row — the view

**`OnNowScreen.swift:197-211`**, verbatim:

```swift
private var chips: some View {                                              // :197
    HStack(spacing: 14) {                                                   // :198
        ForEach(model.chips, id: \.self) { chip in                          // :199
            Button {                                                        // :200
                model.chip = chip                                           // :201
                Task { await model.load() }                                 // :202
            } label: {
                PillLabel(text: model.chipLabel(chip),                      // :203-205
                          active: model.chip == chip,
                          focused: focused == "chip:\(chip.label)")
            }
            .buttonStyle(BareButtonStyle())                                 // :206
            .focused($focused, equals: "chip:\(chip.label)")                // :207
        }
    }
    .focusSection()                                                         // :210
}
```

### 2.3 How a pill is drawn, and how it is focused

`PillLabel` — **`ScreenChrome.swift:112-134`**. Three visual states, and they are exclusive in
appearance but not in logic (a pill can be both `active` and `focused`):

| State | Ink (`:121`) | Fill (`:124`) | Border (`:126-129`) |
|---|---|---|---|
| `active` | `accent200` | `accent900` | `accent700`, 1 pt |
| `focused` | `text` | `accent` at 14 % | `accent`, **4 pt** (`Nocturne.Focus.ringWidth`) |
| neither | `neutral400` | clear | `neutral800`, 1 pt |

Shape is a `Capsule()`, `.lineLimit(1)`, `.fixedSize()`. The size parameter defaults to
`Nocturne.TextSize.secondary` = **26 pt** with **10 / 24 pt** padding (`:116`, `:122-123`), and On
Now passes no `size:`, so it takes that default. *(The Guide's own pills pass
`size: Nocturne.TextSize.floor` = 23 pt, which switches the padding to 8 / 20 —
`GuideScreen.swift:660`, `:675`, `:687`.)*

Focus: a plain `Button` with `BareButtonStyle()` (`RailView.swift:27-31`, which draws only its
label) and `.focused($focused, equals: "chip:<label>")` (`:207`). **The whole row is one
`.focusSection()`** (`:210`), which is what lets the remote cross from the grid up into the pills and
back. There is no `.defaultFocus` on the row; the screen's default focus is the first card, falling
back to `"loading"` (`:166`), and after the first load `focusSoon` puts focus on the first card or on
`"chip:All"` if there are none (`:174-175`).

### 2.4 How the selection drives the request, and the `filter=` value

The chip is a value on the model: `var chip: ChannelChip = .all` (**`:57`**). Pressing a pill assigns
it and re-runs the load (`:201-202`), which is one request:

```swift
func load() async {                                                          // :85
    items = try await api.onNow(source: chip.sourceQuery, filter: chip.filterQuery)   // :87
```

`api.onNow` is **`ChannelFilter.swift:52-58`** — `GET /api/guide/now?source=&filter=`, with the DRM
rule applied to the answer (`:57`). The two query values come from `ChannelChip`
(**`:14-39`**):

| Chip | `filterQuery` (`:27-33`) | `sourceQuery` (`:35-38`) | On the wire |
|---|---|---|---|
| `.favorites` | `"Favorites"` | nil | `?filter=Favorites` |
| `.all` | nil | nil | **no query at all** |
| `.hd` | `"HD"` | nil | `?filter=HD` |
| `.source(name)` | nil | the source's display name | `?source=<name>` |

Both strings are the server's own built-in filter words (`sources.go:362`), and the comment at `:26`
cites that line. **The chip set is `[.favorites, .all, .hd] + sources.map { .source($0) }`**
(`:64-66`); the source names come from `loadSources()` (`:73-83`), which reads `GET /api/channels`
once and keeps each distinct `source` in first-seen order. Live today that is four sources
(HDFX-4K …, Philo, Verizon, Marlin Cast), so **seven pills**. The label is `chipLabel` (`:68-70`):
`"All"` gains the total — `"All 91"` — and every other chip shows its plain label.

### 2.5 Whether the selection persists — **no, on either meaning of the word**

- **Across a rail trip: no.** `model` is `@State private var model: OnNowModel` (`:121`) created in
  the screen's own `init` (`:127`), and `ScreenShell.swift:57` puts `.id(current)` on the content, so
  the screen **and its model** are destroyed and rebuilt on every rail visit. `chip` returns to
  `.all` (`:57`) and the `.task` at `:167` re-runs from the top.
- **Across a relaunch: no.** The app writes exactly **four** `UserDefaults` keys and none of them is
  a chip: `marlinClientId` (`ClientSession.swift:17`), `marlinResume.<id>` (`ResumeStore.swift:19`),
  `marlinWeatherFix` (`WeatherLocation.swift`, `defaultsKey`), `marlinGuideCollection`
  (`GuideCollections.swift:33`). No `@AppStorage`, no `@SceneStorage`, no suite, no keychain.

The contrast that matters for the build: **the Guide's collection does survive both**, because
`GuideCollectionsModel` is owned above the shell (`ScreenShell.swift:32`, created in
`Marlin_DVR_TVApp.swift:32`) *and* writes its key. On Now's chip does neither.

### 2.6 The page layout beneath the pills

```swift
private static let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 3)  // :130
…
ScrollView(.vertical, showsIndicators: false) {            // :142
    LazyVGrid(columns: Self.columns, spacing: 30) {        // :143
        ForEach(model.items) { item in                     // :144
            Button { onPlay(.live(channel: item.channel, program: item.program)) }   // :145-146
            label: { OnNowCard(item: item, focused: focused == item.id) }            // :147-149
            .buttonStyle(BareButtonStyle())                                          // :150
            .focused($focused, equals: item.id)                                      // :151
            .onLongPressGesture(minimumDuration: 0.5) { … }                          // :152-155
        }
    }
    .padding(.vertical, 10)                                // :158
}
.disabled(model.nextHours != nil)                          // :160
```

**Three flexible columns, 28 pt across and 30 pt down**, vertically scrolling, lazily built. The grid
is disabled while the long-press overlay is up (`:160`).

**How an item is drawn** — `OnNowCard`, **`:215-277`**. A `HStack(alignment: .top, spacing: 22)`
(`:244`) of:

1. `ChannelLogo(channel:size: 82)` (`:245`) — the provider logo, falling back to the server's
   initials tile on its `logoBg` colour (`ServerImage.swift`, `ChannelLogo` and `InitialsTile`);
2. a `VStack(alignment: .leading, spacing: 8)` (`:246`) holding
   - `"<number> · <name>"` at 23 pt `neutral400`, plus a `TagChip` per flag (`:247-253`) — the flags
     are `New`, `Live`, **`Premiere`**, `Finale` from `program` (`:233-241`, premiere at **`:238`**);
   - the title at 31 pt medium, 2 lines (`:254-257`);
   - the episode line — `episodeNum` and `episodeTitle` joined by " · " (`:225-231`, `:258-263`);
   - the server's own `endsIn` string, e.g. `"ends 3:04 PM"`, at 23 pt `neutral500` (`:264-266`);
   - a `ProgressBar` whose fraction is computed in the app from `program.start`/`end` against
     `Date()` (`:219-223`, `:267-268`).

Card chrome: 24 / 26 pt padding, `Nocturne.surface` at `Radius.md`, and
`.focusTreatment(focused, restingRing: Nocturne.hairline)` (`:272-275`) — the app's one focus
treatment: a 4 pt accent ring, a 6 pt lift and the ambient shadow (`ScreenChrome.swift:69-91`).

**What Select does:** `onPlay(.live(channel:program:))` (**`:146`**) — it plays the channel live
immediately. **No sheet, no detail, no confirmation.** A **click-and-hold** (`.onLongPressGesture`,
`:152-155`) instead opens `NextHoursOverlay` — that one channel's next six hours, read with
`GET /api/guide?slots=12&source=<its sourceId>` and narrowed to its own row (`showNextHours`,
`:98-115`, the request at `:100` and the row pick at `:101`). Menu closes the overlay if it is up and
otherwise leaves the screen (`:180-187`).

**The screen refreshes itself every 60 s** — a `.task` loop at `:167-179`, which also sets focus on
its first pass only.

### 2.7 Which of it is shared and which is On Now's own

| Shared component | Where |
|---|---|
| `ScreenHeader` (title · accessory · subtitle · spacer · trailing) | `ScreenChrome.swift:13-65` |
| **`PillLabel`** | `ScreenChrome.swift:112-134` |
| `TagChip` (the New/Live/Premiere/Finale tags) | `ScreenChrome.swift:94-109` |
| `ProgressBar` | `ScreenChrome.swift:177-189` |
| `LoadingLine`, `ErrorLine` | `ScreenChrome.swift:155-174` |
| `focusSoon` (the 80 ms focus hand-off) | `ScreenChrome.swift:148-153` |
| `focusTreatment` | `ScreenChrome.swift:69-91` |
| `BareButtonStyle` | `RailView.swift:27-31` |
| `ServerImage`, `InitialsTile`, `ChannelLogo` | `ServerImage.swift` |
| `Nocturne` tokens and `Font.nocturne` | `Theme.swift` |

| On Now-specific | Where |
|---|---|
| `ChannelChip` — the chip enum and both query mappings | `OnNowScreen.swift:14-39` |
| `OnNowModel` — `chip`, `chips`, `chipLabel`, `loadSources`, `load`, `showNextHours` | `:48-116` |
| the `chips` row itself | `:197-211` |
| `OnNowCard` | `:215-277` |
| `NextHours` + `NextHoursOverlay` | `:41-46`, `:280-343` |

**Nothing in the pill row is reusable as it stands.** `ChannelChip` is a channel-filter enum with
`filterQuery`/`sourceQuery` on it, and `model.chips` is built from the server's source list. The row
*shape* — `HStack(spacing: 14)` of `Button` + `PillLabel` + `.focused` inside one `.focusSection()` —
is what would carry across, and that shape already appears three times in the app: here, in the
Guide's header pills (`GuideScreen.swift:665-692`) and in the Guide's collections button
(`:654-663`).

---

## 3. Step 3 — what On Later does today

`Marlin DVR TV/OnLaterScreen.swift`, **145 lines** — the smallest screen in the app.

### 3.1 The request it makes

One call, once:

```swift
sections = try await api.later().sections                    // :25
```

`api.later()` is **`ChannelFilter.swift:81-84`**:

```swift
/// GET /api/guide/later (guide.go:695-754).
func later() async throws -> LaterResponse {
    try await get("/api/guide/later")
}
```

**No parameters, and — alone among every typed call in that file — no DRM filter.** See §6.2.

It is called from a **one-shot `.task`** (`:95-99`). There is **no timer, no refresh loop, no
scene-phase handler and no notification observer anywhere in the file**; `grep` for `Task.sleep`,
`Timer`, `TimelineView` finds only the header clock at `:48`. The screen is re-read only because
`ScreenShell.swift:57` destroys and rebuilds it on every rail visit.

### 3.2 What it shows

The header (**`:47-53`**):

```swift
ScreenHeader("On Later", subtitle: "New, premiere, live, finale and movie airings") {
    TimelineView(.everyMinute) { context in
        Text("\(TimeFormat.shortDay(context.date)) · \(TimeFormat.clock(context.date))")
            .font(.nocturne(Nocturne.TextSize.floor))
            .foregroundStyle(Nocturne.neutral500)
    }
}
```

— title, a **fixed** subtitle string, and a right-hand date-and-clock that ticks every minute.
**No accessory slot is used and there is no pill row of any kind.**

The body (**`:59-92`**) is one `HStack(alignment: .top, spacing: 48)` with one column per section,
each `.frame(maxWidth: .infinity, alignment: .topLeading)` — so **two equal columns side by side**,
in the server's array order. Each column is:

- a heading row: `Text(section.label)` at 38 pt medium, then a `LinearGradient` rule fading to clear
  (`:62-68`) — the design's fading divider;
- a vertical `ScrollView` of `LaterRow`s, 22 pt apart (`:69-88`), each focusable with the id
  `"<sectionIndex>:<itemIndex>"` (`:72`, `:79`);
- `"Nothing listed."` when the section is empty (`:81-85`).

`LaterRow` (**`:105-145`**) is an `HStack(spacing: 22)` of:

1. a **92 × 92** square from `item.art` with the grey `ArtPlaceholder` behind it (`:111-115`);
2. a `VStack(alignment: .leading, spacing: 5)` (`:116-129`) of the title (31 pt medium, **1 line**),
   `item.subtitle` (23 pt `neutral400`, 1 line), and `"<item.channel> · <item.when>"` (23 pt
   `neutral500`, 1 line);
3. a **"● Scheduled"** capsule, drawn only when `item.scheduled` — `accent200` ink on an `accent600`
   hairline (`:131-138`).

Row chrome: 12 / 20 pt padding; the background is `Nocturne.surface`, or the accent mixed 90 % into
the surface while focused (`:142`), plus `.focusTreatment(focused)` (`:143`).

**Every string on the row is the server's own.** The app derives nothing here — no progress bar, no
clock arithmetic, no relative-day label.

### 3.3 How far ahead it reaches, and how items are grouped

**Neither is the app's.** The app renders `sections` exactly as returned and never inspects
`section.label` (`Models.swift:162-165` declares it; `OnLaterScreen.swift:63` draws it). The reach,
the two-way split, the "notable" test, the series dedupe, the sort and the 24-item cap are all
server-side and unparameterised — §4.1.

### 3.4 What Select does — **nothing at all**

```swift
Button {
    // Opening the airing from here is a later sweep's wiring.      // :74
} label: {
    LaterRow(item: item, focused: focused == id)                    // :76
}
```

The row **is** focusable and **is** pressable, and pressing it runs an empty closure. That has been
true since sweep 2 (the file header says "Rows take focus; selecting one is owned by a later sweep",
`:7`). Menu leaves the screen (`:100`); there is no overlay, no sheet, no hold handler and no
`RemoteHold` in this file.

### 3.5 The design frames both screens are drawn from

| | Frame | Where |
|---|---|---|
| **On Now** | **1b** — "Rail expanded" | `dc:50-102`; the header at `dc:75-78`, **the pill row at `dc:79-84`**, the 3-column card grid at `dc:85-99`, the card at `dc:87-97` |
| **On Later** | **5a** — "On Later — On Today and On This Week, one per series" | `dc:431-493`; the header at `dc:444-450`, the two-column grid at `dc:451-490`, a row at `dc:458-468`, the "● Scheduled" capsule at `dc:465-467` |

Design data: `onNowShort` (`dc:1344`), `sidebar`/`railFocused(2)` (`dc:1345`), `laterToday`
(`dc:1301-1306`), `laterWeek` (`dc:1307-1312`), `railLater` (`dc:1348`).

**Three things the design says that bear on this goal, quoted rather than paraphrased:**

- Frame 5a's right-hand header slot holds a **date and clock** — `"Fri Sep 5 · 2:41 PM"`
  (`dc:449`) — which is exactly what the app draws. **Frame 5a has no pill row anywhere.** The pill
  row lives only in frame 1b (`dc:79-84`), and its four pills there are `Favorites`, `All 16`, `HD`,
  `Antenna` — all channel filters.
- The frame's own caption is *"On Later — On Today and On This Week, **one per series**"*
  (`dc:434`), so the series dedupe is design, not accident.
- **The design expresses premieres in the subtitle line, not as a filter.** Its own mock data reads
  `sub:"Season premiere"` (`dc:1303`), `sub:"Series finale"` (`dc:1304`), `sub:"Premiere · Part 1"`
  (`dc:1308`), `sub:"Season premiere"` (`dc:1309`), `sub:"Season finale"` (`dc:1311`). That slot is
  filled today by the server's `subtitleOf` (§4.1), which answers the episode title, else the first
  category, else the episode number — never a premiere word. §4.4 measures what it actually says.

The design system carries no pill component of its own: its `readme.md` component table lists
`.btn`, `.tag`, `.field`/`.input`/`.radio`/`.seg`, `.card`, `.nav`, `.table`, `.dialog`, `.hr`,
`.lighten` and nothing else, and `.seg`/`.seg-opt` (`styles.css:189-200`) is a segmented control, not
a pill. Frame 1b's pills are inline styles.

---

## 4. Step 4 — the server, verified at the clone's HEAD and by live GETs

The running server and the clone are both **1.8.1** and `HEAD == origin/main` (§V2), so one set of
line numbers serves both.

### 4.1 `GET /api/guide/later` — the route On Later uses

Route `main.go:264` → `handleGuideLater`, **`guide.go:754-813`**. The whole selection, line by line:

| What | Line | Behaviour |
|---|---|---|
| parameters | — | **none**. The handler never calls `r.URL.Query()`. Proven live: seven query strings, byte-identical bodies (§V3). |
| `endToday` | `:756` | `time.Date(y, m, d, 23, 59, 59, 0, now.Location())` — local, **today** |
| `endWeek` | `:757` | `endToday + 6*86400` — six further whole days |
| channels | `:773` | `a.channels(false)` — hidden dropped, **DRM carried through**, sorted by `numberKey(number)` then `number` (`sources.go:296-302`, `:335-340`) |
| window | `:776` | keep only `p.Start > now.Unix() && p.Start <= endWeek` |
| "notable" | `:779-784` | `p.New \|\| p.Premiere \|\| p.Live \|\| p.Finale`, **or** any category `EqualFold` to `"Movie"`, `"Movies"` or `"Film"` |
| dedupe | `:770`, `:785-788` | **one** `seen map[string]bool` on `p.SeriesID`, **shared across both sections**, filled as the walk goes — channel order first, then start order within a channel |
| split | `:791-795` | `p.Start <= endToday` → today, else week |
| sort | `:798-799` | each section ascending by `Start` — **after** the dedupe has already chosen the winners |
| cap | `:806-811` | **24** per section, keeping the first 24 after the sort |
| empty | `:800-805` | `[]`, never `null` |
| envelope | `:812` | `{"sections": [{"label":"On Today","items":[…]},{"label":"On This Week","items":[…]}]}` |

The item type (**`:758-768`**) is nine fields: `title`, `subtitle`, `channel`, `channelId`, `start`,
`when`, `scheduled`, `program` (a `*Program`, always set at `:789-790`), `art`. **There is no `drm`
field and no channel object.**

- `subtitle` is `subtitleOf(p)` — **`guide.go:636-647`** — the episode title, else the **first**
  category, else the episode number, else `""`.
- `channel` is `c.Number + " · " + c.Name` (`:790`), a display string.
- `when` is `time.Unix(p.Start,0).Format("Mon 3:04 PM")` — **no date**, so a Friday next week and a
  Friday tomorrow read the same.
- `scheduled` comes from `scheduledSet()` — **`guide.go:907-915`** — the set of `channelID|start` for
  every computed job whose `Status != "Skipped"`. **That includes `COMPLETED`, `FAILED` and
  `STOPPED`**, so "scheduled" here does not mean "will record".

**The shared dedupe has a visible consequence, measured rather than reasoned.** Because one `seen`
map is filled in channel-number order and only then sorted by time, **an airing that is on tonight
can be suppressed by a later-in-the-week airing of the same series on a lower-numbered channel**.
Fourteen of today's candidates are lost that way right now, including:

```
College Football                 today Sat 19:30 on ch 9001  lost to  Fri 20:00 on ch 9000
Shooter (2007)                   today Sat 19:00 on ch 9006  lost to  Mon 19:00 on ch 9005
The Taking of Pelham 123 (2009)  today Sat 22:00 on ch 9006  lost to  Tue 01:00 on ch 9005
Central Intelligence (2016)      today Sat 22:45 on ch 9006  lost to  Thu 21:00 on ch 9005
Fast Times at Ridgemont High     today Sat 23:00 on ch 9007  lost to  Mon 09:00 on ch 9005
```

### 4.2 Every other route that serves upcoming airings

| Route | Handler | Parameters | Time reach | Carries the flags? |
|---|---|---|---|---|
| `GET /api/guide/later` | `guide.go:754-813` | **none** | now → `endToday`, then → `endToday+6d`; 24 each | **yes** — the whole `Program` |
| `GET /api/guide` | `guide.go:650-748`, route `main.go:262` | `start` (truncated to 30 min, `:657-664`), `slots` (**1–48, else 13**, `:652-655`), `source`, `filter` (`:671`) | **at most 24 h per request**, any start | **yes** — each block's `program` |
| `GET /api/guide/now` | route `main.go:263` | `source`, `filter` | now only, one programme per channel | **yes** |
| `GET /api/guide/search?title=` | `guide.go:816-844`, route `main.go:265` | `title` only | **whole-title equality**, case-insensitive, every airing with `p.End > now` — **no time window and no cap** (`:836`, `:843`) | **yes** — the `Program` is embedded |
| `GET /api/guide/find?q=` | `guide.go:860-904`, route `main.go:266` | `q` only | substring on the title, `p.End > now`, **capped at 20** with the true total in `count` (`:848`, `:900-903`) | **NO** — its row type (`:862-871`) is eight display fields and carries none of `new`/`live`/`premiere`/`finale` |
| `GET /api/schedule`, `…/calendar` | `passes.go:838-919` | `q`; `offset` (weeks) | **bookings, not airings** — live `count=5` | yes, inside `Job.program` |
| `GET /export/guide.xml` | `export.go:79-121` | `{source}` in the path | the **whole stored guide** for every visible channel | **NO** — it emits only `<new/>` and `<live/>` (`:105-110`); `premiere` and `finale` are dropped |
| `GET /api/guide/stats` | `guide.go:918-920` | none | counters only | n/a |

**So exactly four routes expose a premiere flag: `/api/guide`, `/api/guide/now`, `/api/guide/later`
and `/api/guide/search`.**

### 4.3 The fields that mark a premiere, and how the server fills them

`Program` — **`guide.go:18-38`**. The four marks:

```go
New      bool `json:"new,omitempty"`        // :30
Live     bool `json:"live,omitempty"`       // :31
Premiere bool `json:"premiere,omitempty"`   // :32
Finale   bool `json:"finale,omitempty"`     // :33
```

**All four carry `omitempty`, so `false` is omitted from the JSON entirely** — the key simply is not
there. The app decodes all four as `Bool?` (`Models.swift:70-73`), so absent reads as `nil` and both
`nil` and `false` are handled by `== true` tests (`OnNowScreen.swift:236-239`,
`AiringSheet.swift:107-110`). Nothing in the app would break on either shape.

Beside them, the fields a premiere rule could be derived from: `Season int` (`:25`), `Episode int`
(`:26`), `EpisodeNum string` (`:27`, e.g. `"S46E26"`), `SeriesID string` (`:34`),
`OrigAirDate string` (`:36`, JSON `originalAirDate`) — every one `omitempty` as well.

**How they are populated — two source paths, and they differ.**

**(a) XMLTV** — `parseXMLTV`, `guide.go:175-270`. The elements are declared as
**presence-only pointers** (`:145-148`):

```go
New        *struct{} `xml:"new"`
Live       *struct{} `xml:"live"`
Premiere   *struct{} `xml:"premiere"`
LastChance *struct{} `xml:"last-chance"`
```

and mapped at **`:238-241`**:

```go
pr.New      = p.New != nil || p.Premiere != nil
pr.Live     = p.Live != nil
pr.Premiere = p.Premiere != nil
pr.Finale   = p.LastChance != nil
```

**`*struct{}` discards the element's text content.** XMLTV allows `<premiere>Season premiere</premiere>`
and `<premiere>Series premiere</premiere>`; both decode to the same non-nil pointer here. **The
server therefore cannot tell a season premiere from a series premiere — it has one boolean and no
text.** Note also that a `<premiere>` sets `New` as well (`:238`), so on this path premiere implies new.

`Season`/`Episode` come from `episode-num` — `xmltv_ns` (zero-based, incremented at `:248-253`) or
`onscreen` (`:255-256`); `SeriesID` from `dd_progid` (`:257-258`), falling back to
`"title:" + lower(title)` (`:264-266`). `OrigAirDate` is XMLTV's `<date>` **passed through
unparsed** (`:237`) — which is why it arrives in two formats (§4.4).

**(b) The HDHomeRun cloud guide** — `guide.go:435-451`. The `Program` is built at `:438` and the
**only** flag it ever sets is `New`, heuristically, with the server's own comment saying why:

```go
if g.OriginalAirdate > 0 {
    p.OrigAirDate = time.Unix(g.OriginalAirdate, 0).UTC().Format("2006-01-02")
    // HDHomeRun marks nothing as "new"; treat first-air within 7 days of start as new
    if g.StartTime-g.OriginalAirdate < 7*86400 {
        p.New = true                                              // :443
    }
}
```

**`Premiere`, `Live` and `Finale` are never assigned on this path at all.** `Season`/`Episode` come
from `parseSxxExx(g.EpisodeNumber)` (`:446-448`) and `SeriesID` from the cloud row (`:438`).

XMLTV wins over the cloud guide on the channels it covers (`GuideFile.all()`, `guide.go:44-53`).

### 4.4 Does any route filter by day, week or premiere server-side? — and the live counts

**Day / week.** Only `/api/guide/later`, and it is **fixed and unparameterised**. `/api/guide` gives
an arbitrary window through `start` + `slots`, but `slots` is capped at 48 (`guide.go:653-655`), so
one request covers at most 24 hours; a week is seven or eight requests.

**Premiere — no route filters by any of the four flags.** No guide handler reads a `premiere`,
`new`, `live` or `finale` query parameter: the only query keys any of them touch are `slots`,
`start`, `source`, `filter` (`guide.go:651-671`), `title` (`:817`), `q` (`:861`) and `{action}`
(`main.go:268`). **A "Premieres" pill would therefore be a client-side filter**, and only the four
routes of §4.2 supply the field to filter on.

**The live counts, measured 2026-09-12 18:07–18:20 EDT.** Full evidence in §V3–§V5.

| | On Today | On This Week |
|---|---|---|
| every future airing in the window (DRM included) | **419** | **12,234** |
| "notable" by the server's own test | **86** | **1,430** |
| notable and deduped by `seriesId`, before the cap | **45** | **436** |
| what `/api/guide/later` returns | **24** (reaching 20:30 tonight) | **24** (reaching 06:00 tomorrow) |
| **`premiere == true`** | **0** | **0** |
| `finale == true` | **0** | **0** |
| `new == true` | 60 | 1,002 |

**Premieres: zero, five ways.** `premiere` is true on **0 of 16,121** distinct airings across eight
24-hour `/api/guide` fetches; 0 of the 48 items in `/api/guide/later`; 0 of the 91 programmes in
`/api/guide/now`; 0 of the 58 matches in an uncapped `/api/guide/search?title=Ghost Adventures`
reaching 2026-09-24; 0 of the 5 jobs in `/api/schedule`. The string `"premiere":true` appears **zero**
times in every raw body, and the key never appears at all. `finale` is likewise zero everywhere.
Over the same 16,121 airings `new` is set 1,325 times and `live` 589, **so the flags are arriving and
being decoded — `premiere` is simply never set** (§4.3 explains why: neither XMLTV provider emits
`<premiere>`, and the HDHomeRun path cannot set it).

**The derivable proxies, measured over the 12,652 future airings in the window:**

| Proxy | Today | This week | Total |
|---|---|---|---|
| `episode == 1` ("season premiere") | 19 | 644 | **663** |
| `season == 1 && episode == 1` ("series premiere") | 4 | 177 | **181** |
| has both `season` and `episode` | 249 | 7,950 | 8,199 |
| has `originalAirDate` | 371 | 10,774 | **11,145** |
| starts within 7 days of `originalAirDate` | — | — | **1,119** |
| `new == true` | 60 | 1,002 | **1,062** |
| `new == true` **and** within 7 days of `originalAirDate` | — | — | **522** |

`episode == 1` is noisy — the first four tonight are *Ghost Adventures* S23E1 at 19:00 (twice, on two
channels), *House Hunters* **S112E1** at 20:00 and *Lakefront Bargain Hunt: Renovation* S2E1 at 20:00,
and **none of them carries `new`** — they are repeats of a season opener. And "first airing" and
"new" are substantially different sets: 1,119 and 1,062 respectively, overlapping on only 522.

**`originalAirDate` arrives in two formats**, because the XMLTV path passes `<date>` through
unparsed (`guide.go:237`) while the HDHomeRun path formats it (`:440`):

```
YYYYMMDD     11122        e.g. "20240327"
(absent)      1508
YYYY-MM-DD      22
```

**There is no text signal either.** Over the same 12,652 airings, the word "premiere"
(case-insensitive) appears **0 times** in `title`, **0** in `episodeTitle`, **0** in `categories`, and
**4** in `desc` — and all four are the same *Shipping Wars* episode whose synopsis mentions a car
being shipped to a film premiere.

**How far the guide reaches.** `/api/guide/stats` reports 29,104 listings over 103 channels with
`coverageUntil: "Sat 3:00 PM"` (a string with no date in it, `guide.go:588`). Probing directly, the
last day with any listing is **+12d (Thu, Sep 24)**, whose latest programme ends **Sat 2026-09-26
05:00**; +14d and +16d return zero blocks on all 91 rows. **So the stored guide runs roughly 14 days
out, and "On This Week" — `endToday + 6 days` = Fri 2026-09-18 23:59:59 — covers about half of it.**

**Channels.** `/api/channels` answers **91** visible rows with **0** DRM; `?hidden=1` answers **103**
with **5** DRM and **12** hidden — so every DRM channel is hidden, and `channels(false)` drops all
five before `/api/guide/later` ever builds its list. **Zero of the 48 live On Later items are on a
DRM channel today.** §6.2 is about what happens if one is un-hidden.

**Redaction.** No credential, token, client id or device id appears in this report. Channel ids are
quoted only in their `verizon:<guid>` and `marlin-cast:<guid>` forms; the antenna source's
`hdhr-<device id>:<number>` form is deliberately not printed anywhere here — see Open Question 12.

---

## 5. Step 5 — what "On Today", "On This Week" and "Premieres" can mean in data terms

**Readings are listed with their evidence. None is chosen.**

### 5.1 "On Today"

| # | Reading | Evidence | What it gives today |
|---|---|---|---|
| a | **The server's current one**: from now to local **23:59:59 today** | `guide.go:756` + `:776` | 419 airings → 86 notable → 45 deduped → **24** after the cap, the last at 20:30 |
| b | From now to local **midnight** (`00:00:00` tomorrow) | not in the server | the same set to within one second; nothing in the owner's data starts in that second |
| c | The **next 24 hours** from now — one `/api/guide?slots=48` request | `guide.go:652-664` | a different set: it takes in tomorrow morning and drops nothing from tonight |
| d | The remainder of the **broadcast day** (e.g. to 6 AM tomorrow) | **nothing in the server has this notion** | would need the app to define it |

### 5.2 "On This Week"

| # | Reading | Evidence | What it gives today |
|---|---|---|---|
| a | **The server's current one**: `endToday + 6 days`, i.e. tonight's midnight → end of **Fri 2026-09-18**, and **excluding today** | `guide.go:757`, `:791-795` | 12,234 airings → 1,430 notable → 436 deduped → **24** after the cap, the last at Sun 06:00 |
| b | The **next seven calendar days including today** | same end instant, different split | the section would also hold today's items, which the server's `if p.Start <= endToday` forbids |
| c | The **current calendar week** to Saturday night | — | 2026-09-12 **is** a Saturday, so this reading makes the section **empty today**. Nothing in the server supports it |
| d | **Everything the guide holds** beyond tonight | probe fetches, §V5 | runs to about Sat 2026-09-26 05:00 — roughly **twice** the server's six-day window |

### 5.3 Readings that cut across both pills

| # | Question | Evidence | Numbers |
|---|---|---|---|
| e | Does a pill mean **every airing** in the window, or only the **notable** ones? | `guide.go:779-784`; the screen's own subtitle says "New, premiere, live, finale and movie airings" (`OnLaterScreen.swift:47`, `dc:447`) | today 419 vs 86; this week 12,234 vs 1,430 |
| f | Is the list **deduped by series**, and if so per section or across both? | one shared `seen` map, `guide.go:770`, `:785-788` | across both: 45/436. **14 of today's candidates are suppressed by a later-in-the-week airing** (§4.1) |
| g | Does the **24 cap** stand? | `guide.go:806-811` | binding in **both** sections today: 24 of 45, and 24 of 436 |
| h | Are **DRM** airings in or out? | `channels(false)` at `:773` keeps DRM; the app applies no filter (§6.2) | 0 today, because all five DRM channels are hidden; not zero if one is un-hidden |

### 5.4 "Premieres"

| # | Reading | Evidence | What it gives today |
|---|---|---|---|
| p1 | **`program.premiere == true`** | `guide.go:32`, `:240`, `:435-451` | **0 airings, everywhere.** And the server cannot separate season from series premiere in any case — `<premiere>` is parsed presence-only (`:147`) |
| p2 | **`episode == 1`** = season premiere; **`season == 1 && episode == 1`** = series premiere | `Program.Season`/`Episode`, `guide.go:25-26` | 663 and 181 future airings. Includes plain repeats — *House Hunters* S112E1 tonight has no `new` |
| p3 | p2 **restricted to `new == true`** | both fields present | not measured as a combined figure; see Open Question 2 |
| p4 | **First airing**: start within N days of `originalAirDate` | `guide.go:36`, `:237`, `:440` | 1,119 at N = 7, and the field arrives in **two** date formats |
| p5 | **Text**: the word "premiere" in title, episode title or categories | measured | **0** usable hits; 4 incidental hits in `desc`, all one *Shipping Wars* episode |
| p6 | **Ask the server for it** — preserve XMLTV's `<premiere>` text, or add a premiere test | `guide.go:147`, `:240` | a marlin-dvr change, which this project's standing rule says is raised as a decision for that project |

---

## 6. Step 6 — the interactions

### 6.1 The airing sheet from an On Later item

**What the sheet needs.** `AiringSheet` is constructed from an `AiringSelection`
(`AiringSheet.swift:32-46`, `:48-53`), which is three things:

```swift
struct AiringSelection: Identifiable {
    let channel: MergedChannel     // :33
    let program: Program           // :34
    let job: Job?                  // :35
}
```

**What an On Later item has.** `LaterItem` (`Models.swift:150-160`) carries `channelId: String` and
**`program: Program?`** — and live, `program` is non-null on all 48 items with 17 of `Program`'s
fields present (§V3). **So the `Program` is already in hand**; only the `MergedChannel` and the `Job`
are missing.

**The app already does this reconstitution once**, on the Search screen, and On Later would need one
read fewer. `GuideSearchModel.open(_:)` — **`GuideSearchScreen.swift:140-168`**:

1. `api.guideSearch(title:)` to recover the `Program` (`:145`) — **On Later would skip this**, because
   `find` rows carry no programme and `later` items do;
2. match the channel in a cached `/api/channels` list, re-reading only on a miss (`:153-155`);
3. `refreshSchedule()` (`:161`, `:172-178`) then `job(channelId:programStart:)` (`:180-182`).

The sheet's own contract for writes is `onScheduleChanged: () async -> Job?` (`:53`), and both
existing hosts satisfy it identically — re-read the schedule, return this airing's job
(`GuideScreen.swift:429-432`; `GuideSearchScreen.swift:268-271`).

**The known trap is focus after the sheet closes, and the two precedents disagree.**

- On **Search**, a plain `@FocusState` assignment leaves the screen with nothing focused — measured
  on the device **twice**, in Pass 63 and again in Pass 65 when it was removed to re-check — and the
  fix is a `generation` counter that rebuilds the content subtree
  (`GuideSearchScreen.swift:293-315`, whose comment ends "Do not remove it a third time without the
  device saying so").
- On the **Guide**, the plain assignment **was** measured to be enough across six row-replacing
  reloads (Pass 72), so no generation counter was added (`GuideScreen.swift:624-632`).

Which of the two On Later needs is **not known** and would have to be measured on the device.

**Two places a "Premiere" tag is already drawn, and both are dead on this data.**
`AiringSheet.swift:105-112` (premiere at **`:109`**) and `OnNowScreen.swift:233-241` (premiere at
**`:238`**) each append a `TagChip(text: "Premiere")` when `program.premiere == true`. Neither has
ever had anything to draw on this server (§4.4).

### 6.2 The DRM client-side rule

**The rule**, in the file's own words — `ChannelFilter.swift:5-8`: *"channels with `drm = true` never
appear in any list. The server returns them with the flag set … and does not hide them itself."* It
is a design fact (DECISIONS.md, 2026-09-05 (design)).

**Six `playable` filters exist** (`ChannelFilter.swift:13-38`), and every typed endpoint applies one:
`channels` `:48`, `onNow` `:57`, `guide` `:67`, `guideFind` `:94`, `guideSearch` `:103`, `schedule`
`:109-113`.

**`later()` applies none — and cannot, from this route.** `ChannelFilter.swift:82-84` is three lines
with no filter, because:

- `LaterItem` has **no `drm` field** (`Models.swift:150-160`), and it has none because the server's
  own item type has none (`guide.go:758-768`);
- it carries a `channelId` **string**, not a `MergedChannel`, so there is nothing to test.

**So On Later is the one list in the app with no DRM filter**, and the server does not filter for it
either: `handleGuideLater` walks `a.channels(false)` (`guide.go:773`), which drops hidden channels and
channels of disabled sources (`sources.go:309-317`) and **carries `DRM` straight through**
(`sources.go:321`).

**Today this is latent, not live.** All five of the owner's DRM channels are hidden (§V5), so
`channels(false)` removes them first, and **0 of the 48 live items are on a DRM channel**. Un-hide one
in Manage Lineup and its airings would appear on On Later and nowhere else in the app.

Closing it client-side would need a channel-id set from `GET /api/channels` — a second read this
screen does not make today, and one the Search screen already makes for the same reason
(`GuideSearchScreen.swift:153-155`).

### 6.3 `ScreenShell`'s `.id(current)` versus a remembered pill

**`ScreenShell.swift:57`** puts `.id(current)` on the content, and `:99` is where On Later is built:

```swift
content
    .id(current)                                              // :57
…
case .onLater: OnLaterScreen(api: api, onLeave: leave)        // :99
```

Changing `.id(…)` makes SwiftUI treat the subtree as a different view, so on **every rail visit**:

| What is destroyed | Where |
|---|---|
| `@State private var model: OnLaterModel` | `OnLaterScreen.swift:37`, built at `:42` |
| `@FocusState private var focused` | `:38` |
| the `.task` that reads `/api/guide/later` | `:95-99` — it **re-runs**, a fresh request every visit |

**A pill selection held in `@State` inside the screen would reset on every trip to the rail** — which
is exactly what On Now's chip does today (§2.5).

**The app has one pattern for surviving that, used three times**: own the model **above** the shell.
`WeatherModel` (`ScreenShell.swift:26`), `GuideSearchModel` (`:30`) and `GuideCollectionsModel`
(`:32`) are all created once in `Marlin_DVR_TVApp.swift:22-24`, `:29-32` and handed down through
`ContentView.swift:17-23`, `:32`. The comment at `ScreenShell.swift:27-30` states the rule.

**Surviving a relaunch is a second, separate thing** and needs `UserDefaults`. The app writes exactly
four keys (§2.5), and `GuideCollectionsModel` (`GuideCollections.swift:26-107`) is the worked example
of both halves at once — restore in `init` (`:57-62`), write in `select` (`:69-77`), and reconcile
against the server on the next read (`:99-107`).

**Note the asymmetry the build has to settle:** On Now's chip survives neither; the Guide's collection
survives both. The goal says On Later takes On Now's pill row and does not say which behaviour comes
with it.

### 6.4 The Home tile for On Later, and what it reads

**It exists, and it is the third tile.** `Destination.homeTiles` (`Destination.swift:30`) is
`[.guide, .onNow, .onLater, .recordings, .cameras, .favorites, .weather, .radio, .settings]`; the
label is `"On Later"` (`:38`), the symbol `"clock"` (`:57`), the tint `0x1F5F5C` (`:83`), and it is a
rail entry as well (`:27`, fifth).

**What it reads is not `/api/guide/later`.** `HomeModel.load()` — **`HomeView.swift:35-104`** — makes
six concurrent reads, and the On Later tile's sub-line comes from the **schedule**:

```swift
do {
    let response = try await schedule                         // GET /api/schedule
    subtitles[.onLater] = "\(response.count) upcoming"        // :68
    recordingNow = response.jobs.filter { $0.status == "Recording" }.count
} catch {
    subtitles[.onLater] = "unavailable"                       // :71
}
```

So the tile counts **scheduled bookings**, not upcoming airings. Live today `/api/schedule` answers
`count = 5`, so the tile reads **"5 upcoming"** while the screen behind it draws 48 items from a
different endpoint. The design's own mock for that tile is `"9 upcoming"` (`dc:1356`), and
`HomeRadioCountUITests.swift:91` asserts the shape `^[0-9]+ upcoming$`.

**Nothing about the pills changes any of that** unless a step says so.

---

## 7. Step 7 — SWEEP or STANDALONE

**Only what the owner's goal names is sorted. Nothing is added.**

| # | Piece of the goal | Sort | Why, in one line |
|---|---|---|---|
| 1 | **On Later takes On Now's page layout** | **SWEEP** | It replaces the entire body of `OnLaterScreen` — the two side-by-side section columns of `:59-92` become a three-column `LazyVGrid` of cards — and a card can only be judged on the television against the pills that decide what is in it. |
| 2 | **On Later takes On Now's header pill row** | **SWEEP** | It is the same view as item 1 and the same `.focusSection()` traversal; the pills are what select the grid's contents, so neither can be built or seen without the other. |
| 3 | **Exactly three pills — "On Today", "On This Week", "Premieres"** | **SWEEP** | The labels and the count are properties of item 2's row; shipping them apart would mean editing the same lines twice. |
| 4 | **Premieres = season premieres and series premieres** | **STANDALONE** | It is a predicate over data with no view surface, provable against the live server on its own — and on today's measurement it has no data to run on, which makes it a question before it is a build. |
| 5 | **No channel-filter pills on On Later** | **SWEEP** | It is the absence of part of item 2's row and is settled by building that row. |

**SWEEP: items 1, 2, 3 and 5** — one screen, one header row, one thing to look at.
**STANDALONE: item 4** — a predicate, settled independently of how the screen looks.

---

## 8. Open questions

Each is a question the owner must answer before a build prompt, with the evidence that raises it.
**None was acted on.**

1. **There are no premieres in your guide data. What should the "Premieres" pill do?**
   Measured five independent ways today (§4.4, §V4): `premiere == true` on **0 of 16,121** airings
   across eight 24-hour `/api/guide` fetches, 0 in `/api/guide/later`, 0 in `/api/guide/now`, 0 in an
   uncapped `/api/guide/search`, 0 in `/api/schedule`. `finale` is 0 too. Over the same set `new` is
   1,325 and `live` 589, so the flags do arrive — `premiere` is never set. The cause is server-side
   and explains it: XMLTV's `<premiere>` is parsed as a presence-only element (`guide.go:147`,
   `:240`) and neither Philo nor Verizon emits one, and the HDHomeRun path never sets `Premiere` at
   all (`guide.go:435-451`). *Without an answer the pill is built and is always empty.*

2. **If Premieres is to be derived instead, from which rule?**
   The candidates, measured over 12,652 future airings: `episode == 1` → **663**;
   `season == 1 && episode == 1` → **181**; start within 7 days of `originalAirDate` → **1,119**;
   `new == true` → **1,062**, overlapping the previous by only **522**. `episode == 1` includes plain
   repeats — *Ghost Adventures* S23E1 tonight at 19:00 and *House Hunters* S112E1 at 20:00 both carry
   no `new` flag. Is "season premiere" `episode == 1` and "series premiere"
   `season == 1 && episode == 1`? Should either be restricted to `new == true`?

3. **`originalAirDate` arrives in two formats.** 11,122 future airings carry `YYYYMMDD` and 22 carry
   `YYYY-MM-DD`, because the server passes XMLTV's `<date>` through unparsed (`guide.go:237`) while
   the HDHomeRun path formats it (`:440`). Any rule that reads it has to parse both. Acceptable in
   the app, or raised with marlin-dvr?

4. **Should a real premiere signal be asked of the marlin-dvr project?** Preserving XMLTV's
   `<premiere>` text — so a season premiere can be told from a series premiere — or computing the
   answer server-side is a server change, and this project's standing rule (CLAUDE.md) says server
   changes are raised as decisions for marlin-dvr. **Nothing has been raised.**

5. **What do "On Today" and "On This Week" mean?** §5 lists four readings each and chooses none. The
   one the app gets for free is the server's: today = now → 23:59:59 local; week = tonight's midnight
   → six days later, **excluding today**; notable airings only; deduped by series across both
   sections; capped at 24 each. Today that cap binds in both: "On Today" reaches only **20:30
   tonight** (24 of 45 deduped, of 86 notable, of 419 airings) and "On This Week" only **06:00
   tomorrow** (24 of 436, of 1,430, of 12,234).

6. **The 24 cap and the shared series dedupe are the server's, and unparameterised.**
   `/api/guide/later` takes no parameters at all — seven query strings returned byte-identical bodies
   (§V3). If the pills must show more than 24, or must stop suppressing a today airing because the
   same series airs later in the week (**14 such today**, §4.1), the screen has to be built on
   `/api/guide` instead: eight or more requests of 48 slots, about 1.2 MB each, on a route whose block
   builder is known to drop about 3 % of listings (DECISIONS.md, 2026-09-11 (Passes 62-65)) — a hole
   this pass measured directly, two of the live section's 24 titles being absent from the `/api/guide`
   data altogether (§V5). Which route?

7. **Does a pill mean everything in that window, or only the notable airings in it?** The screen's
   subtitle says "New, premiere, live, finale and movie airings" today (`OnLaterScreen.swift:47`), and
   the design says the same at `dc:447`. Three pills that only narrow a notable list read very
   differently from three pills that filter the whole guide — 86 versus 419 for today alone.

8. **Must the pill selection survive a rail trip? And a relaunch?** On Now's survives neither
   (`OnNowScreen.swift:57`, destroyed by `ScreenShell.swift:57`); the Guide's collection survives both
   (`GuideCollections.swift:33`, model owned above the shell). The goal says On Later takes On Now's
   pill row and does not say which of those two behaviours comes with it.

9. **Should Select on an On Later item do anything?** Today it does nothing at all — an empty closure
   with a comment (`OnLaterScreen.swift:73-75`) — while the row stays focusable and pressable. The
   goal names layout and pills and does not name Select. Left alone, the new card layout inherits a
   pressable card that does nothing, on a screen where every other card in the app either plays
   something or opens a sheet.

10. **On Later has no DRM filter and cannot get one from this route.** `later()` applies none
    (`ChannelFilter.swift:82-84`) because `LaterItem` has no `drm` field and the server's item type
    has none (`guide.go:758-768`); the server carries DRM channels through (`sources.go:321`). It is
    latent today — all five DRM channels are hidden, so `channels(false)` drops them first
    (`guide.go:773`) — but un-hiding one would put its airings on On Later and nowhere else in the
    app. Close it in the build, or leave it and record it?

11. **The Home On Later tile counts something else.** It reads `GET /api/schedule` and says "5
    upcoming" (`HomeView.swift:67-68`) — **bookings**, not upcoming airings — while the screen reads
    `/api/guide/later` and draws 48 items. Should the tile follow the screen, or stay as it is?

12. **The HDHomeRun device id in reports.** This report deliberately carries no channel id of the form
    `hdhr-<device id>:<number>`, because `CLAUDE.md` requires device ids redacted before any commit or
    report. Earlier committed reports do carry it unredacted — `reports/2026-09-11-pass71-guide-collections-recon.md`
    §V4b prints five such ids and §3.3 argues they are lineup identifiers rather than credentials.
    Which reading governs going forward? **Nothing was edited either way.**

---

## 9. The three things I am least sure of

1. **That `premiere` is genuinely never set, rather than never reaching me.** The 16,121 airings came
   from `/api/guide`, and that route's block builder is known by the marlin-dvr project's own
   measurement to drop about **3 %** of listings — roughly 480 airings I never saw, and this pass
   demonstrated the hole directly (two of the live "On This Week" 24 are absent from my `/api/guide`
   data entirely, §V5). Four independent cross-checks were also zero, including an **uncapped**
   `/api/guide/search` that walks the stored guide directly with no block builder in the way, and the
   parse path explains the zero (`guide.go:147`, `:240`, `:435-451`). I believe it. But **I did not
   read the raw XMLTV the providers send**, which is the only place a `<premiere>` element could be
   proved absent rather than inferred absent — and that would mean reading a provider feed, which is
   not this project's to do.

2. **That my replication of `/api/guide/later`'s selection is exact.** It reproduces both live cap
   boundaries to the minute (today's 24th at Sat 20:30, the week's at Sun 06:00), its "On Today" 24
   are **set-identical** to the live 24, and the 45/436 pre-cap figures are unchanged whether the
   channel walk is sorted the server's way (`numberKey`, a `ParseFloat`, `sources.go:296-302`) or a
   naive string way — so the notability test, the shared dedupe and the cap are right. What I cannot
   prove is the **week** section: mine shares 22 of 24 with the live one, and while both misses are
   explained by the `/api/guide` hole, I did not verify that explanation against a third source. If
   the dedupe's tie-breaking differs from what I assumed, the 436 moves and so does the "how much is
   the cap hiding" figure.

3. **That the guide's far edge really is Sat 2026-09-26 05:00.** It comes from five probe fetches at
   +8, +10, +12, +14 and +16 days, and the fall from ~1,943 programme blocks at +12d to **zero** at
   +14d is sharp and unambiguous. But `/api/guide/stats` reports `coverageUntil: "Sat 3:00 PM"` — a
   string the server formats with **no date in it** (`guide.go:588`) — which I could not reconcile
   against 05:00, and **I did not fetch the +13d window**, so the true edge sits somewhere in a
   two-day band. It matters because the edge is what decides how much of the stored guide any "This
   Week" reading leaves out.

---

## 10. SCOPE CHECK — every path touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | **read only**, in full | required reading, 1 |
| `reports/2026-09-05-pass2-server-recon.md`, `reports/2026-09-11-pass71-guide-collections-recon.md` | **read only**, in full | required reading |
| `Marlin DVR TV/*.swift` (49) | **read only**, in full | 1, 2, 3, 6 |
| `Marlin DVR TVUITests/*.swift` (15) | **read only** (six in full, nine header + tests + grep) | 1, 6 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **read only** | 1 |
| `design/` (14 files) | **read only, never written** | 1, 2, 3 |
| `~/Xcode/marlin-dvr-reference` | **`cat`, `grep`, `git rev-parse` only** — no fetch, no checkout, no edit, nothing run | 4 |
| `http://192.168.1.250:8090/` | **GET only** — `/api/status`, `/api/guide/later` ×8, `/api/guide` ×13, `/api/guide/now`, `/api/guide/search`, `/api/guide/stats`, `/api/channels` ×2, `/api/schedule`, `/api/schedule/calendar`. **No POST, PUT or DELETE** | 4, VERIFY |
| the session scratchpad | response bodies and analysis scripts, **outside the repo** | 4 |
| `reports/2026-09-12-pass81-on-later-pills-recon.md` | **created — the only write** | 8, DELIVERABLE |

**Not touched:** every Swift source, the Xcode project, `Info.plist`, the entitlements file, every
build setting, the asset catalog, `build/`, `icon-source/`, `design/` (read, never written), every
other report, and every other folder under `~/Xcode`. **No build, no test, no device run, no
install, no dependency.** The Unraid host `192.168.1.250`, marlinpc `192.168.1.245`, the HDHomeRun
`192.168.1.105` and the UNAS4Pro share were not touched — the only traffic was read-only GETs to the
DVR's HTTP API. **`GET /api/settings` was not read.**

---

## 11. Git

`git status` before this pass read `?? icon-source/` and nothing else (§V1). **The only change this
pass makes to the working tree is this file**, so `git status` afterwards reads `?? icon-source/` plus
this report (§V6), and the report is staged by name and committed in its own commit, then pushed. The
three SHAs (`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`) are
verified after a fresh `git fetch origin` and reported in this pass's response, because a commit
cannot contain its own hash (`DECISIONS.md` 2026-09-09 (Pass 60) rule (b), and Pass 68's ordering
rule: the report goes **in** the commit).

**Nothing forced. No history rewritten.**
