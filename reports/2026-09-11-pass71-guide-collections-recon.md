# Pass 71 — Guide collections: recon

**Date:** 2026-09-11
**READ-ONLY. Exactly one file is written by this pass: this report.** No Swift file, project file,
`Info.plist`, entitlements file or asset was modified. `design/` was read and never written.
`~/Xcode/marlin-dvr-reference` was read with `git show` and direct `cat` only — never edited, never
fetched, never checked out to another commit, nothing run from it. **Three GET requests were made to
`http://192.168.1.250:8090/`, and no POST, PUT or DELETE of any kind.** No build, no test, no device
run, no install. No probe file and no scratch file was left anywhere in the repo.

**Pass number.** The highest-numbered report in `reports/` before this pass was **pass70** (two
files: `2026-09-11-pass70-note-to-marlin-dvr.md` and `2026-09-11-pass70-server-181-answered.md`), so
this is **Pass 71**.

**What this pass is for.** The owner approved a design on 2026-09-11: the Guide header gains a
collections button; pressing it drops a list; picking a collection reloads the grid filtered to that
collection in the owner's order; the button takes the collection's name; the Apple TV remembers the
pick. This pass reconnoitres that and nothing else. **Nothing is chosen, proposed or designed here
beyond what the numbered steps ask for.**

---

## VERIFY — the evidence the brief asks to be shown

### V1. `git status` before step 1

```
$ git status --porcelain --untracked-files=normal
?? icon-source/

$ git status
On branch main
Your branch is up to date with 'origin/main'.

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	icon-source/

nothing added to commit but untracked files present (use "git add" to track)

$ git rev-parse HEAD
a49258aa4fbc62c19ce03aa4aa4e39d4e8afcefb
$ git rev-parse origin/main
a49258aa4fbc62c19ce03aa4aa4e39d4e8afcefb
```

`icon-source/` is the standing untracked baseline — 32 entries, its fate the owner's undecided call
since Passes 51–55 (`DECISIONS.md`, 2026-09-08). No tracked file was modified.

*(The `git status` **after** step 8 is in §V5 below.)*

### V2. `git show e9d28f6:cmd/marlin-dvr/collections.go | sed -n '63,87p'`, beside the handoff's claim

Run in `~/Xcode/marlin-dvr-reference`. **Verbatim output:**

```go
type resolvedCollection struct {
	Collection
	Channels []map[string]any `json:"channels"`
	Count    int              `json:"count"`
}

func (a *App) resolveCollection(c Collection) resolvedCollection {
	byID := map[string]MergedChannel{}
	for _, ch := range a.channels(true) {
		byID[ch.ID] = ch
	}
	rc := resolvedCollection{Collection: c, Channels: []map[string]any{}}
	if rc.ChannelIDs == nil {
		rc.ChannelIDs = []string{}
	}
	for _, id := range c.ChannelIDs {
		if ch, ok := byID[id]; ok {
			rc.Count++
			rc.Channels = append(rc.Channels, map[string]any{"id": id, "isLive": true, "isDead": false, "name": ch.Name, "number": ch.Number, "initials": ch.Initials, "logoBg": ch.LogoBg, "source": ch.SourceName})
		} else {
			rc.Channels = append(rc.Channels, map[string]any{"id": id, "isLive": false, "isDead": true})
		}
	}
	return rc
}
```

**The handoff's claims about this block, each checked against the bytes above:**

| The handoff says (`collections-atv-handoff.md`) | Line it cites | Verdict |
|---|---|---|
| "`channels` is parallel to `channelIds`, **same order, same length**, one entry per member" | `:78-85` | **CONFIRMED** — one `append` per `id` in `range c.ChannelIDs`, no `continue`, no skip |
| a resolved member carries `id`, `isLive: true`, `isDead: false`, `name`, `number`, `initials`, `logoBg`, `source` | `:81` | **CONFIRMED** — exactly those eight keys, in that order |
| `source` is the source's **display name**, not its id | `:81` | **CONFIRMED** — `ch.SourceName` |
| an unresolved member carries `id`, `isLive: false`, `isDead: true` and **nothing else** | `:83` | **CONFIRMED** — three keys |
| `count` counts **resolved members only**, so `count ≤ channelIds.length` | `:80` | **CONFIRMED** — `rc.Count++` is inside the `ok` branch only |
| `channelIds` is `[]`, never `null`, and so is `channels` | `:74-77` | **CONFIRMED** — `Channels: []map[string]any{}` at the struct literal, and the `rc.ChannelIDs == nil` guard |
| it resolves against `channels(true)` — hidden channels included | `:71` | **CONFIRMED** — `a.channels(true)` |

**Every claim holds, byte for byte. No drift in this block.**

### V3. Drift check: `e9d28f6` (the handoff's commit) against clone HEAD

```
$ git rev-parse HEAD                       (in ~/Xcode/marlin-dvr-reference)
eb0c098de3efc8bb569e252b63e141aa10262918
$ git rev-parse --abbrev-ref HEAD
main
$ git merge-base --is-ancestor e9d28f6 HEAD   → yes
$ git log --oneline e9d28f6..HEAD
eb0c098 Pass 94: record the push evidence in the report's GIT section
2b28d4a Pass 94: channel collections recon + tvOS handoff
$ git log --oneline e9d28f6..HEAD -- cmd/ web/
(no output)
```

**The only two commits after `e9d28f6` are that pass's own report commits. No server source changed.**
Confirmed per file by hash at both refs:

```
SAME  63ae4a07e7b644eb  cmd/marlin-dvr/collections.go
SAME  c9a90865727d4814  cmd/marlin-dvr/sources.go
SAME  2e5b7d5be4cf4c47  cmd/marlin-dvr/guide.go
SAME  a17d1d1f7d395f32  cmd/marlin-dvr/clients.go
SAME  6c1704caff23dd32  cmd/marlin-dvr/main.go
SAME  d324f7dc1eb35433  cmd/marlin-dvr/library.go
SAME  1100505e43825865  cmd/marlin-dvr/stream.go
```

**Every one of the handoff's 33 `file:line` citations was resolved individually at `e9d28f6`** by
reading that line and matching it against what the handoff says is there. **All 33 matched**
(`collections.go` :11 :12 :50 :63 :69 :71 :80 :81 :83 :90 :102 :108 :111 :112 :114 :130 :177;
`sources.go` :319 :358 :359 :362 :390; `guide.go` :671 :729; `clients.go` :37 :387 :401 :412;
`main.go` :38 :261 :262 :269 :304). Because the file hashes are identical at HEAD, **they resolve
identically at HEAD.** **Zero line drift.**

**Two things in the handoff are nonetheless out of date, and both are facts about the world rather
than about the source:**

1. **§1 says "The owner's live data currently holds one collection, 'Local', with four antenna
   channels."** The live server today answers **five** members, all resolved, `count: 5` — the fifth
   is `marlin-cast:9287` (ESPN, number 50007, source "Marlin Cast"), which is not an antenna channel.
   See §V4b.
2. **§7 says "What the owner is actually running right now: 1.8.0 … 1.8.1 is published but not
   installed."** `GET /api/status` from the live server reads **`"version":"1.8.1"`**. See §V4a.

The handoff's `count: 3` / `13.1` `isDead` / hidden-`8.1` example is **not** drift: `pass94-collections-recon.md`
§5z records that those readings came from a throwaway container with **deliberate fixture edits** to
a copy of the lineup (channel `13.1` removed, `8.1` forced hidden). They are illustrations of the
shapes, not statements about the owner's server.

**One drift in this project's own notebook, found in passing.** `COLD-START.md:67-68` says the
reference clone has "a **checked-out tree still at 1.2.1** (`cmd/marlin-dvr/main.go:38`)". The clone's
working tree now reads `appVersion = "1.8.1"` at that line, and so do `e9d28f6` and `eb0c098`. Not
corrected here — this pass writes one file.

### V4. The three live GETs, trimmed to the fields cited

Three requests, all GET. **No POST, PUT or DELETE was sent.** *(They were made twice over the life of
this pass — once when the evidence was first gathered and once again to capture the exact response
text quoted below, after the session's context was compacted. Six GETs in total, nothing else.)*

#### V4a. `GET /api/status`

```json
{"name":"marlin-dvr","version":"1.8.1","uptime_seconds":14748,"port":8089}
```

**The running server is 1.8.1.** `COLD-START.md:37-38` records 1.8.0 on the owner's Status-page
reading of 2026-09-08; the handoff records 1.8.0 as what he was running. Both are superseded.
`port: 8089` is the in-container port; the host maps 8090 → 8089.

#### V4b. `GET /api/collections`

```json
{"collections":[{
  "id":"col-1788571411827",
  "name":"Local",
  "icon":"ph-house",
  "channelIds":["hdhr-10a75953:2.1","hdhr-10a75953:8.1","hdhr-10a75953:11.1",
                "hdhr-10a75953:13.1","marlin-cast:9287"],
  "channels":[
    {"id":"hdhr-10a75953:2.1","isLive":true,"isDead":false,"name":"WMAR-HD","number":"2.1",
     "initials":"WM","logoBg":"#e0342a","source":"HDFX-4K (10A75953)"},
    {"id":"hdhr-10a75953:8.1","isLive":true,"isDead":false,"name":"WGAL-TV","number":"8.1",
     "initials":"WG","logoBg":"#1f7a45","source":"HDFX-4K (10A75953)"},
    {"id":"hdhr-10a75953:11.1","isLive":true,"isDead":false,"name":"WBAL-DT","number":"11.1",
     "initials":"WB","logoBg":"#be185d","source":"HDFX-4K (10A75953)"},
    {"id":"hdhr-10a75953:13.1","isLive":true,"isDead":false,"name":"WJZ-TV","number":"13.1",
     "initials":"WJ","logoBg":"#6b6f7a","source":"HDFX-4K (10A75953)"},
    {"id":"marlin-cast:9287","isLive":true,"isDead":false,"name":"ESPN","number":"50007",
     "initials":"ES","logoBg":"#1f7a45","source":"Marlin Cast"}],
  "count":5}]}
```

**One collection. Five members. Every one resolved — `isLive: true`, `isDead: false`. `count: 5`,
equal to `channelIds.length`.** Nothing in the owner's live data exercises the `isDead` shape today,
and nothing exercises `count < channelIds.length`.

#### V4c. `GET /api/guide?filter=col-1788571411827&slots=1`

```
top-level keys : channelCount, channels, dayLabel, nowIndex, slots, start
channelCount   : 5
slots          : 1      start: 1789183800      dayLabel: "Fri, Sep 11"      nowIndex: 0.3944…
timeSlots      : [{"label":"11:30 PM","start":1789183800}]

rows, in the order returned:
  hdhr-10a75953:2.1    | 2.1    | WMAR-HD | drm=false | hidden=false | hd=true  | blocks=1 | "WMAR-2 News at 11PM"
  hdhr-10a75953:8.1    | 8.1    | WGAL-TV | drm=false | hidden=false | hd=true  | blocks=1 | "News 8 at 11:00"
  hdhr-10a75953:11.1   | 11.1   | WBAL-DT | drm=false | hidden=false | hd=true  | blocks=1 | "11 News at 11pm"
  hdhr-10a75953:13.1   | 13.1   | WJZ-TV  | drm=false | hidden=false | hd=true  | blocks=1 | "WJZ News at 11PM"
  marlin-cast:9287     | 50007  | ESPN    | drm=false | hidden=false | hd=false | blocks=1 | "SportsCenter"

row key set   : blocks, drm, favorite, guid, hd, hidden, id, initials, logo, logoBg,
                name, number, origName, origNumber, source, sourceId
block key set : channelId, isLive, program, span, subtitle, title
```

**The response is the ordinary `/api/guide` envelope with fewer rows — the top-level keys, the row
keys and the block keys are byte-for-byte the shapes `Models.swift:124-132`, `:104-117` and `:93-101`
already decode.** Nothing new to decode, nothing missing.

**Honest limit on the ordering evidence.** These five rows came back in collection order — but the
collection's order (2.1, 8.1, 11.1, 13.1, 50007) is also ascending channel-number order, which is
what `channels()` sorts by (`sources.go:335-340`). **This live response does not distinguish the two.**
That collection order wins is established from the source (`sources.go:389-401`, comment
"collection order wins") and from the reference project's own fixture measurement, not from this GET.

### V5. `git status` after step 8

```
$ git status --porcelain --untracked-files=normal
?? icon-source/
?? reports/2026-09-11-pass71-guide-collections-recon.md

$ git status
On branch main
Your branch is up to date with 'origin/main'.

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	icon-source/
	reports/2026-09-11-pass71-guide-collections-recon.md

nothing added to commit but untracked files present (use "git add" to track)

$ git diff HEAD --stat
(empty — no tracked file modified, nothing staged)
```

**Before and after differ by exactly one entry: this report.** `icon-source/` is unchanged, and
`git diff HEAD --stat` is empty, so no tracked file was modified by this pass. The report is then
staged **by name** and committed on its own, so `icon-source/` cannot be swept in.

---

## 1. Step 1 — everything that was read, and the hand-verified count

**No "likely files" subset was used.** Everything below was opened.

| Group | Count | Notes |
|---|---|---|
| App Swift sources, `Marlin DVR TV/*.swift` | **48** | every one, in full |
| UI-test Swift sources, `Marlin DVR TVUITests/*.swift` | **13** | every one, in full |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **1** | 441 lines |
| `Info.plist` (repo root) | **1** | `NSLocationWhenInUseUsageDescription` + `NSAllowsLocalNetworking`, nothing else |
| `Marlin DVR TV.entitlements` (repo root) | **1** | `com.apple.developer.weatherkit` only |
| `design/Marlin DVR TV.dc.html` | **1** | 118,216 bytes, the frame source |
| `design/_ds/nocturne-…/readme.md` | **1** | the design system's own component list |
| `CLAUDE.md` | **1** | 13 lines |
| `COLD-START.md` | **1** | 1,107 lines |
| `DECISIONS.md` | **1** | 993 lines |
| `reports/*.md` | **69** | every report, pass1 through pass70, in full |
| **Total read in full, in the working tree** | **138** | |

**Twelve further files under `design/` were enumerated and searched but not read line by line**, and
they are named rather than glossed: `styles.css`, `_ds_manifest.json`, `_ds_bundle.js`,
`_adherence.oxlintrc.json`, `support.js`, `image-slot.js`, `.thumbnail`, `ATV-DVR.zip`, and four PNGs
(`screenshots/guide-3a.png`, `screenshots/guide-comfortable.png`, `screenshots/home-tiles.png`,
`uploads/Screenshot 2026-09-05 at 10.09.02 PM.png`). `ATV-DVR.zip` was listed and is a byte copy of
the other thirteen `design/` files (`unzip -l` shows exactly them). `styles.css` was read by pattern
for every menu/dropdown/select/listbox/popover class — see §5.3. The design tree is **14 files**.

**Read read-only from `~/Xcode/marlin-dvr-reference`** (never edited, never fetched, never checked
out): `reports/2026-09-11-collections-atv-handoff.md` (331 lines) and
`reports/2026-09-11-pass94-collections-recon.md` (738 lines) in full, plus `git show` of
`cmd/marlin-dvr/`{`collections.go`, `sources.go`, `guide.go`, `clients.go`, `main.go`, `library.go`,
`stream.go`} at `e9d28f6` and at `HEAD`.

**One fact that matters more than any other in this list.** `grep -rin "collection"` over all 48 app
Swift files and all 13 UI-test files returns **nothing**, and `grep -ril "collection"` over every text
file in `design/` returns **nothing**. **The word does not appear anywhere in this app or in its
design.** Every one of the five work items is new ground.

---

## 2. Step 2 — what the Guide screen does today

`Marlin DVR TV/GuideScreen.swift`, 563 lines. Everything below is from it unless said otherwise.

### 2.1 The header, exactly as composed

`GuideScreen.header`, **`GuideScreen.swift:348-378`**:

```swift
private var header: some View {                                              // :348
    ScreenHeader("Guide", subtitle: model.loaded ? model.windowLabel : nil) { // :349
        HStack(spacing: 14) {                                                 // :350
            if model.loaded && !model.isAtNow {                               // :351
                Button { … await model.snapToNow(); focusSoon { … } }         // :352-356
                label: { PillLabel(text: "↩ Now · \(TimeFormat.clock(Date()))",
                                   active: true, focused: focused == "now",
                                   size: Nocturne.TextSize.floor) }           // :357-359
                .buttonStyle(BareButtonStyle())                               // :360
                .focused($focused, equals: "now")                             // :361
            }
            if model.loaded && !model.endOfListings {                         // :363
                Button { … await model.pageForward(); … }                     // :364-368
                label: { PillLabel(text: "+12h", focused: focused == "page",
                                   size: Nocturne.TextSize.floor) }           // :369-371
                .buttonStyle(BareButtonStyle())                               // :372
                .focused($focused, equals: "page")                            // :373
            }
        }
    }
    .focusSection()                                                           // :377
}
```

**`ScreenHeader` is the layout**, `ScreenChrome.swift:13-39`. Its body (`:24-37`) is one
`HStack(alignment: .firstTextBaseline, spacing: 28)` holding, in order:

1. `Text(title)` at `Nocturne.TextSize.screenTitle`, weight `.medium` — `ScreenChrome.swift:26-29`
2. `Text(subtitle)` at `Nocturne.TextSize.secondary`, `neutral500` — `:30-34` (only when non-nil)
3. `Spacer(minLength: 0)` — **`:35`**
4. `trailing()` — **`:36`**

So the Guide header today is: **"Guide"**, then the date range beside it at 28 pt gap, then a spacer,
then the pill row pushed hard right. The date range is `model.windowLabel`
(`GuideScreen.swift:176-183`) and it is `nil` until `model.loaded`.

**This matches the design exactly.** `design/Marlin DVR TV.dc.html` frame 3a at **dc:186-194** is a
`display:flex; align-items:baseline; justify-content:space-between` row whose left group is
`<h2>Guide</h2>` + a date `<span>` at `gap:28px`, and whose right group is `gap:14px` holding one
`+12h` pill. Frame 3c at **dc:308-316** is the same with `↩ Now · 2:41 PM` added before `+12h`.

**Where the owner's collections button goes.** The approved design puts it "beside" the title with
the date range "shifted right". Today nothing sits between the title and the subtitle — item 2 above
follows item 1 directly with no slot in between, and `ScreenHeader` takes only a title, an optional
subtitle and a trailing builder. **There is no third slot.** That is a fact about the type, recorded
here without proposing what to do about it.

### 2.2 What `+12h` is

Four constants, **`GuideScreen.swift:63-66`**:

```swift
static let windowSeconds = 7200     // :63 — the visible window: 2 hours, four 30-minute columns
static let pageSeconds   = 43200    // :64 — one +12h press: 12 hours
static let fetchSlots    = 48       // :65 — one fetch: 48 half-hour slots = 24 hours
static let slotSeconds   = 1800     // :66
```

`pageForward()`, **`:97-101`**:

```swift
func pageForward() async {
    guard !endOfListings else { return }          // :98
    windowStart += Self.pageSeconds               // :99
    if windowEnd > fetchEnd { await fetch(from: windowStart) }   // :100
}
```

So **`+12h` moves the visible 2-hour window forward by 12 hours** and refetches **only when the new
window runs past what the last fetch covered**. Because a fetch covers 24 hours and a press advances
12, every **second** press triggers a network call. The button itself is at `:363-374` and is drawn
only while `model.loaded && !model.endOfListings`. Its action (`:364-368`) pages, then re-focuses the
first cell: `if let id = firstCellID { focusSoon { focused = id } }`.

`endOfListings` is set at **`:117`**:

```swift
endOfListings = !rows.contains { $0.blocks.contains { $0.program != nil } }
```

— that is, **"no row in this fetch has a single real programme"**. It is the only thing that hides
`+12h`, and it is computed from whatever rows the fetch returned.

### 2.3 How the grid is fetched

One private method, **`GuideScreen.swift:109-130`**, with three callers:

```swift
private func fetch(from start: Int) async {                          // :109
    do {
        async let guide    = api.guide(start: start, slots: Self.fetchSlots)   // :111
        async let schedule = api.schedule()                                    // :112
        let g = try await guide                                                // :113
        rows       = g.channels                                                // :114
        fetchStart = g.start                                                   // :115
        fetchEnd   = g.start + g.slots * Self.slotSeconds                      // :116
        endOfListings = !rows.contains { … }                                   // :117
        do { jobs = try await schedule.jobs } catch { jobs = [] … }            // :118-123
        error = nil
    } catch { self.error = "\(error)"; print("[guide] guide: \(error)") }      // :125-128
    loaded = true                                                              // :129
}
```

**Callers, all three:** `loadNow()` **`:92-95`** (window = current half hour, then fetch);
`pageForward()` **`:100`**; `snapToNow()` **`:103-107`** (fetch only when now is outside the fetched
span).

**`:111` passes no `filter:` argument.** The typed client already accepts one:

```swift
// ChannelFilter.swift:60-69
/// GET /api/guide?start=&slots= (guide.go:590-664). Rows for playable channels only.
func guide(start: Int? = nil, slots: Int, source: String? = nil, filter: String? = nil) async throws -> GuideResponse {
    var query = [URLQueryItem(name: "slots", value: String(slots))]          // :62
    if let start  { query.append(URLQueryItem(name: "start",  value: String(start))) }  // :63
    if let source { query.append(URLQueryItem(name: "source", value: source)) }         // :64
    if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }         // :65
    var response: GuideResponse = try await get("/api/guide", query: query)             // :66
    response.channels = response.channels.playable                                       // :67
    return response
}
```

**So the wire call for work item 3 already exists and is already used with `filter` elsewhere** — On
Now sends `filter=Favorites` and `filter=HD` through the sibling `onNow(source:filter:)`
(`ChannelFilter.swift:52-58`), from `OnNowScreen.swift:87` with the strings at
`OnNowScreen.swift:27-33`. The Guide simply never passes one.

`GuideResponse` decodes at `Models.swift:124-132`; a row is `GuideRow` at `:104-117`, whose
`channel` is a flattened `MergedChannel` (`:16-33`) and whose `id` is **`channel.id`** (`:108`).

### 2.4 How the grid re-focuses after a reload

Three mechanisms, all plain `@FocusState` assignment behind `focusSoon`:

| When | Where | What it does |
|---|---|---|
| First appearance | **`:306-309`** | `.task { await model.loadNow(); focusSoon { focused = firstCellID ?? "page" } }` |
| After `+12h` | **`:366-367`** | `await model.pageForward(); if let id = firstCellID { focusSoon { focused = id } }` |
| After `↩ Now` and after Menu-at-not-now | **`:354-355`**, **`:326-327`** | `await model.snapToNow(); focusSoon { focused = firstCellID ?? "page" }` |

`focusSoon` is **`ScreenChrome.swift:122-127`** — an unstructured `Task` that sleeps **80 ms** and
then runs the closure. `firstCellID` is **`:341-346`**: the first cell of the first row that has one,
or `nil`.

There is also `.defaultFocus($focused, "loading")` at **`:305`**, pointing at the focusable
`LoadingLine` at **`:254`**, which exists only while `!model.loaded`.

**The Guide does NOT use the generation-counter rebuild.** That pattern lives only on the Search
screen: `@State private var generation = 0` (`GuideSearchScreen.swift:229`), `.id(generation)` +
`.task(id: generation)` (`:253-256`), bumped at `:314`. The comment at
**`GuideSearchScreen.swift:295-311`** records why, and it is a **twice-measured on-device finding**,
not an opinion:

> "Writing the row's id straight into `@FocusState` after the sheet closes does not move focus: on
> the Apple TV the run ended with nothing at all focused (`FOCUSALL[after-sheet] []`) … Raising the
> delay did not help. Bumping `generation` re-creates the content subtree, which is the one mechanism
> in this app that reliably re-focuses … **Pass 65 re-measured this rather than assuming it** … with
> the rebuild taken out and the plain assignment put back … closing the sheet on the Apple TV left
> `focused=[]` again — nothing on the screen focused at all. … **Do not remove it a third time
> without the device saying so.**"

Whether the Guide's plain assignment survives a **rows-replaced** reload has never been measured —
it has only ever been exercised on a reload that keeps the same channel set. `reports/2026-09-11-pass66-search-accepted-and-pushed.md`
§7.4 and `…pass68-report-ordering.md` §6.4 both carry the standing question "**`GuideScreen` may carry
the same latent focus defect**", raised in Pass 63 §9.1 and Pass 65 §9.4 and **still not investigated**.

### 2.5 What `ScreenShell.swift`'s `.id(current)` destroys, and what survives

**`ScreenShell.swift:55`** — `content.id(current)`, where `current` is `screen ?? .home` (`:37`) and
`content` is the `switch` at `:90-106` that builds `GuideScreen(api:onLeave:onPlay:)` at **`:96`**.

Changing `.id(…)` makes SwiftUI treat the subtree as a **different view**: it is torn down and built
again from scratch.

**Destroyed on every rail visit — everything `GuideScreen` owns:**

| What | Where | Consequence |
|---|---|---|
| `@State private var model: GuideModel` | `:190`, initialised `:203-208` | a **brand-new** `GuideModel`; `rows`, `jobs`, `windowStart`, `fetchStart`, `fetchEnd`, `loaded`, `endOfListings`, `error`, `sheet` and `favouriteOverrides` all reset |
| `@FocusState private var focused` | `:191` | reset to `nil` |
| `@State private var lastCell` | `:192` | reset |
| `@State private var channelMenu` | `:193` | reset |
| the `.task` at `:306-309` | | **re-runs** — a fresh `loadNow()` and a fresh network fetch on every visit |

**Survives — anything owned above the shell:** `ContentView`'s `APIClient`, the `WeatherModel`
(`ScreenShell.swift:26`) and `GuideSearchModel` (`:30`). The comment at **`ScreenShell.swift:27-30`**
states the rule in the project's own words:

> "Pass 63: Search's model is owned above the shell, because `.id(current)` below rebuilds the
> content on every visit and the owner's decision is that a query and its results survive a trip to
> the rail and back."

**What this means for work item 5.** A chosen collection held in `@State` inside `GuideScreen`
would not survive a single trip to the rail, let alone a relaunch. Anything that must persist has to
live above the shell or outside the process. That is a consequence of `:55`, recorded here; **no key
name, storage location or ownership is proposed.**

*(A small citation drift found in passing: `GuideSearchScreen.swift:46` and `:301` both cite
`ScreenShell.swift:51` for `.id(current)`; it is at **`:55`** today. Not corrected — this pass writes
one file.)*

---

## 3. Step 3 — the server side, verified at `e9d28f6`, at HEAD, and live

The live server is **1.8.1** (§V4a). `e9d28f6` and clone HEAD `eb0c098` are byte-identical over every
file cited (§V3), so a single set of line numbers serves both.

### 3.1 `GET /api/collections`

Route `main.go:269` → `handleCollections`, **`collections.go:90-99`**:

```go
func (a *App) handleCollections(w http.ResponseWriter, r *http.Request) {   // :90
	a.mu.RLock()
	list := append([]Collection(nil), a.collections...)
	a.mu.RUnlock()
	out := []resolvedCollection{}
	for _, c := range list { out = append(out, a.resolveCollection(c)) }
	writeJSON(w, map[string]any{"collections": out})                        // :98
}
```

**Envelope:** `{"collections": [ … ]}`. **There is no `GET /api/collections/{id}`** — the four
registered routes are `main.go:269-272` (GET all, POST, PUT `{id}`, DELETE `{id}`), and one call
returns every collection.

**Each element** = the four stored fields of `Collection` (`collections.go:12-17`: `id`, `name`,
`icon`, `channelIds`) plus `channels` and `count` (`resolvedCollection`, `:63-67`).

**`isLive` / `isDead` / `count`, from the `:69-87` body quoted verbatim in §V2:**

- resolution is a lookup against **`a.channels(true)`** (`:71`) — **hidden channels resolve**, and
  channels of a **disabled** source do not, because `channels()` skips disabled sources at
  `sources.go:309-311`;
- **resolved** → `{"id", "isLive":true, "isDead":false, "name", "number", "initials", "logoBg", "source"}`
  (`:81`), `source` being the source's display **name** (`ch.SourceName`);
- **unresolved** → `{"id", "isLive":false, "isDead":true}` and nothing more (`:83`) — **no `name`, no
  `number`**;
- **`count` counts resolved members only** (`rc.Count++` inside the `ok` branch, `:80`), so
  `count ≤ channelIds.length`;
- `channels` is **parallel to `channelIds`** — same order, same length, one entry per member, no skip;
- both arrays are `[]` and never `null` (`:74-77`).

**Live (§V4b): one collection, `col-1788571411827` "Local", icon `ph-house`, five members, every one
`isLive: true` / `isDead: false`, `count: 5`.** The `isDead` branch is unexercised in the owner's data
today. **The two booleans are complements** in both branches — one is always the negation of the other
— so a client that reads only one loses nothing.

### 3.2 `GET /api/guide?filter=<collection id>`

Route `main.go:262` → `handleGuide`, **`guide.go:650-723`**. Every parameter it reads:

| Query | Line | Behaviour |
|---|---|---|
| `slots` | `:652-655` | `strconv.Atoi`; **`slots <= 0 \|\| slots > 48` → 13**. The app sends **48**, which is the boundary and **is accepted** (48 is not > 48). |
| `start` | `:657-664` | `ParseInt`; `0`/absent → `now.Truncate(30m)`; otherwise `time.Unix(start,0).Truncate(30m)`, in `time.Local` |
| `source` | `:671` | passed to `filterChannels` |
| `filter` | `:671` | passed to `filterChannels` |

**`chans := a.filterChannels(q.Get("source"), q.Get("filter"))` — `guide.go:671`.** Everything else in
the handler is per-row block building; the row set is entirely `filterChannels`'s.

**`filterChannels`, `sources.go:358-406`:**

```go
func (a *App) filterChannels(source, filter string) []MergedChannel {   // :358
	all := a.channels(false)                                            // :359  ← hidden dropped
	var out []MergedChannel
	var coll *Collection
	if filter != "" && filter != "All Channels" && filter != "Favorites" &&
	   filter != "HD" && filter != "Non-HD" {                            // :362
		coll = a.findCollection(filter)                                 // :363
	}
	for _, c := range all {
		if source != "" && source != "All Sources" && c.SourceID != source && c.SourceName != source { continue }
		switch {
		case coll != nil:
			if !coll.has(c.ID) { continue }                             // :371
		case filter == "Favorites": if !c.Favorite { continue }
		case filter == "HD":        if !c.HD      { continue }
		case filter == "Non-HD":    if c.HD       { continue }
		}
		out = append(out, c)
	}
	if coll != nil {
		// collection order wins                                        // :390
		byID := map[string]MergedChannel{}
		for _, c := range out { byID[c.ID] = c }
		out = out[:0]
		for _, id := range coll.ChannelIDs {
			if c, ok := byID[id]; ok { out = append(out, c) }           // :396-400
		}
	}
	if out == nil { out = []MergedChannel{} }
	return out
}
```

**Six facts that fall out, each load-bearing for the design:**

1. **Collection order wins.** After filtering, the result is rebuilt by walking `coll.ChannelIDs` in
   the owner's stored order (`:389-401`), overriding the channel-number sort `channels()` applied at
   `sources.go:335-340`. **That is exactly what the approved design asks for — the server already
   does it.**
2. **`findCollection` matches `id` OR, case-insensitively, `name`** — `collections.go:50-60`. Both
   work. The server's own web Guide page sends the **name** (`web/marlin.js:242`, per
   `pass94-collections-recon.md` §4c) while its Channel Collections page sends the **id**
   (`channel-collections.js:22`).
3. **Four built-in filter words shadow a collection of the same name.** `:362` excludes `""`,
   `All Channels`, `Favorites`, `HD`, `Non-HD` from collection lookup. A collection literally named
   one of those can never be reached by name — only by id.
4. **An unknown `filter` applies no predicate at all.** `findCollection` returns `nil`, none of the
   `case` arms match, and **every visible channel is returned** — not an empty list. A stale saved
   collection id therefore fails **silently and invisibly**, as a full grid.
5. **Hidden channels are dropped.** `channels(false)` at `:359`. So a member the owner hid in Manage
   Lineup is in `/api/collections` with `isLive: true` and counted, but has **no guide row**. The
   collections list's `count` and the grid's `channelCount` can disagree, legitimately.
6. **DRM is NOT dropped.** `mc.DRM` is carried through at `sources.go:321` and nothing in
   `channels()` or `filterChannels` tests it. A DRM channel that is a collection member **comes back
   as a guide row**. See §6.1.

**Also from `:396-400`:** a **duplicate** member id is stored (nothing validates the PUT) and produces
**two guide rows with the same `id`**. See §6.4.

**Live (§V4c): `channelCount: 5`, five rows in collection order, every row `drm=false`,
`hidden=false`.** The envelope is the ordinary guide shape with the app's existing keys.

### 3.3 The live server's `version`

**`1.8.1`** — §V4a, from `GET /api/status` (`main.go:215` writes `statusResponse{Name, Version,
UptimeSeconds, Port}`; `appVersion = "1.8.1"` at `main.go:38`).

**No credential, token, device id or client id appears anywhere in this report.** The live responses
above carry none: `/api/status` returns four scalar fields; `/api/collections` returns channel ids of
the form `<sourceId>:<guid>`, display names, numbers, initials and CSS hex colours; the filtered guide
returns the same channel shape plus programme titles. The channel ids are lineup identifiers, not
credentials — the same form already committed throughout `reports/` and in the reference project's own
handoff. **Nothing was redacted because nothing required it.**

---

## 4. Step 4 — drop-down mechanisms available on tvOS 18, with evidence

**No choice is made here.** Each candidate is stated with what the evidence says and what it does not.

**Environment.** Deployment target **tvOS 18.0** (`project.pbxproj:250`, `:305`); SDK
**AppleTVOS26.5**; **Xcode 26.6 (17F113)**. All availability lines below are quoted from
`…/AppleTVOS26.5.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-tvos.swiftinterface`.

**One fact that frames every row: none of `Menu`, `Picker`, `.sheet(`, `.contextMenu`, `.menuStyle`
or `.pickerStyle` appears anywhere in this app.** `grep -rn` over all 48 app Swift files returns only
comment prose containing the word "Menu" (the remote button) — plus two real `.fullScreenCover` uses
at `ContentView.swift:51` and `WeatherScreen.swift:58`. Every menu-like thing this app has is a
hand-built `ZStack` overlay.

### 4.1 SwiftUI `Menu`

**Available.** SDK line **6755-6757**:

```swift
@available(iOS 14.0, macOS 11.0, tvOS 17.0, *)
@available(watchOS, unavailable)
public struct Menu<Label, Content> : SwiftUICore.View where Label : View, Content : View
```

Styles available on tvOS: `DefaultMenuStyle` (`.automatic`, tvOS 17.0, SDK :14735-14737),
`ButtonMenuStyle` (`.button`, tvOS 17.0, SDK :8547-8549), `BorderlessButtonMenuStyle`
(`.borderlessButton`, tvOS 17.0 but **deprecated** — "Use `.menuStyle(.button)` and
`.buttonStyle(.borderless)`", SDK :15760-15764). `BorderedButtonMenuStyle` is
**`@available(tvOS, unavailable)`** (SDK :2990-2993).

- **Focusable from the header:** its label is a control, so yes in principle. **Untested here.**
- **Dismisses on Select:** that is the documented contract of a `Menu` item. **Untested here.**
- **Styleable:** partly. `MenuStyle.makeBody` lets the *label* be restyled; **the presented list's
  own chrome is UIKit's and this app has never drawn through it.** Whether a `Menu` list can be made
  to look like `PillLabel`/`MenuRow` is **not established.**
- **Verdict: available in the SDK, never used in this app, never run on either Apple TV.**

### 4.2 `Picker`

**Available.** SDK line **13156-13157**:

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Picker<Label, SelectionValue, Content> : View where SelectionValue : Hashable
```

Styles on tvOS: `DefaultPickerStyle` (tvOS 13.0, SDK :10327-10328), `SegmentedPickerStyle`
(tvOS 13.0, SDK :12165-12166), `InlinePickerStyle` (tvOS 14.0, SDK :6895-6896), `MenuPickerStyle`
(**tvOS 17.0**, SDK :22195-22196). **Unavailable on tvOS:** `WheelPickerStyle` (SDK :944-945),
`PalettePickerStyle` (SDK :13409-13411).

- `.menu` would give the drop-down shape the owner described; `.segmented` gives a row, not a drop-down.
- **Focusable / dismisses / styleable:** same position as `Menu` — the contract says yes, and the
  chrome is the system's. **Untested here.**
- **Verdict: available, never used in this app, never run on either Apple TV.**

### 4.3 A sheet or overlay of `Button`s in the app's own look

**Two sub-variants, and they are not equally proven.**

**(a) A `ZStack` overlay — proven repeatedly on device.** This is how every menu in this app already
works. The closest living example is **`ChannelActionsMenu.swift:17-95`**, opened from the Guide
itself at `GuideScreen.swift:278-289`:

- a `ZStack` (`:32`) with a dimming `LinearGradient` (`:33`) under a `Nocturne.surface` card
  (`:68-71`);
- rows are `MenuRow` (`:99-...`), each a plain `Button` (`:107`) with `.focused($focused, equals:)`
  (`:56`);
- `.focusSection()` at `:73`;
- `.onExitCommand { onClose() }` at `:74`;
- opening focus set behind a 60 ms sleep at `:75-80`, and closing focus restored by the host at
  `GuideScreen.swift:335-339`.

`AiringSheet`, `EpisodeActionsMenu`, `EditSeriesPassScreen` and `NextHoursOverlay`
(`OnNowScreen.swift:162-164`) are all the same shape. **All of them have been run on Home Theater and
accepted by the owner** (Passes 8, 9, 10, 47, 49). Full control of appearance, focus and dismissal,
because the app draws every pixel.

**(b) `.sheet(isPresented:)` — available, and never used here.** SDK lines **7108-7112**:

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension View {
  public func sheet<Item, Content>(item: Binding<Item?>, onDismiss: …, content: …) -> some View
  public func sheet<Content>(isPresented: Binding<Bool>, onDismiss: …, content: …) -> some View
```

`presentationDetents` is tvOS 16.0 (SDK :20584) and `presentationBackgroundInteraction` tvOS 16.4
(SDK :20593). **`.sheet` appears nowhere in this app.** `.fullScreenCover` (SDK :7123) does, twice.

### 4.4 The header pill row itself — a segmented control, proven

Not a drop-down, but it is the mechanism the app already uses for exactly this job and it belongs in
the list. **`OnNowScreen.swift:197-211`:**

```swift
private var chips: some View {
    HStack(spacing: 14) {                                        // :198
        ForEach(model.chips, id: \.self) { chip in               // :199
            Button { model.chip = chip; Task { await model.load() } }   // :200-202
            label: { PillLabel(text: model.chipLabel(chip),
                               active: model.chip == chip,
                               focused: focused == "chip:\(chip.label)") }  // :203-205
            .buttonStyle(BareButtonStyle())                      // :206
            .focused($focused, equals: "chip:\(chip.label)")     // :207
        }
    }
    .focusSection()                                              // :210
}
```

and it **already drives `filter=` on a sibling endpoint** (`OnNowScreen.swift:87` →
`ChannelFilter.swift:52-58`, strings at `OnNowScreen.swift:27-33`). **Built in sweep 2, accepted on
Home Theater.** Its cost is that it does not drop down — every choice is on screen at once, which
works for four chips and scales badly.

### 4.5 The design system has no drop-down at all

`grep -n "dropdown\|select\|\.menu\|popover\|combobox\|listbox"` over
`design/_ds/nocturne-…/styles.css` returns **one** hit and it is `::selection` (`:122`), a text-selection
tint. The system's own component table (`readme.md`) lists `.btn`, `.tag`, `.field`/`.input`/`.radio`/
`.seg`, `.card`, `.nav`, `.table`, `.dialog-backdrop`+`.dialog`, `.hr`, `.lighten` — **no menu, no
select, no popover.** `.seg`/`.seg-opt` (styles.css :189-200) is a segmented choice; `.dialog` (:278-293)
is a modal. `grep -in "dropdown\|<select\|listbox\|popover"` over `design/Marlin DVR TV.dc.html`
returns **nothing**. **There is no drawn design for a drop-down anywhere in `design/`.**

### 4.6 Summary table

| Mechanism | Available on tvOS 18? | Evidence | Focusable from header | Dismiss on Select | Styleable to app's look | Status |
|---|---|---|---|---|---|---|
| SwiftUI `Menu` | **yes** | SDK :6755 `tvOS 17.0` | by contract | by contract | **label yes, list chrome unknown** | **untested** — 0 uses in app |
| `Picker` + `.menu` | **yes** | SDK :13156 `tvOS 13.0`; `MenuPickerStyle` :22195 `tvOS 17.0` | by contract | by contract | **label yes, list chrome unknown** | **untested** — 0 uses in app |
| `Picker` + `.segmented` / `.inline` | **yes** | SDK :12165 `tvOS 13.0`; :6895 `tvOS 14.0` | by contract | n/a (no drop) | system chrome | **untested** — 0 uses in app |
| `.sheet(isPresented:)` | **yes** | SDK :7112 `tvOS 13.0` | n/a | app's own | app draws the content | **untested** — 0 uses in app |
| **`ZStack` overlay of `Button`s** | **yes** (plain SwiftUI) | `ChannelActionsMenu.swift:17-95`; `AiringSheet`; `EpisodeActionsMenu` | **proven** (`:56`, `:73`) | **proven** (`:74`, host restore `GuideScreen.swift:335-339`) | **proven — total control** | **proven on device**, Passes 8/9/10/47/49 |
| **Header pill row** (not a drop-down) | **yes** | `OnNowScreen.swift:197-211` | **proven** (`:207`, `:210`) | n/a | **proven** | **proven on device**, sweep 2 |
| `.popover` | **NO** | SDK :11531-11533 `@available(tvOS, unavailable)` | — | — | — | **unavailable** |
| `.contextMenu(menuItems:)` | yes (tvOS 14.0, SDK :9358) | needs a long press on a target, not a header button | — | — | — | **untested**, and shape mismatch |
| `.confirmationDialog` | deprecated form only on tvOS | SDK :616 `tvOS, introduced: 13.0, deprecated: 100000.0` | — | — | — | **deprecated** |

**No choice is made between them.**

---

## 5. Step 5 — persistence

### 5.1 Every `UserDefaults` key the app already writes

There are **three**, and no others. `grep -rn "UserDefaults"` over all 48 app Swift files returns
eleven lines, all of them in the four files below; `grep -rn "AppStorage\|SceneStorage\|NSUbiquitous\|
Keychain\|applicationSupportDirectory\|documentDirectory\|UserDefaults(suiteName"` returns **nothing**.
**No app group, no suite, no keychain, no file-based store.**

| Key (literal) | Declared | Read | Written | Removed | Type | Purpose |
|---|---|---|---|---|---|---|
| **`"marlinClientId"`** | `ClientSession.swift:17` | `ClientSession.swift:63`; `PlaybackSession.swift:58` | `ClientSession.swift:88` | never | `String` | The id the server gave this Apple TV at `POST /api/clients/register`. Launch pings with it (`:66`); a 404 re-registers (`:75`); a transport failure keeps it. Also sent as the `client` field of every play session (`PlaybackSession.swift:70`). |
| **`"marlinResume." + <recordingID>`** | `ResumeStore.swift:19` (`prefix`) | `ResumeStore.swift:22` | `ResumeStore.swift:29` | `ResumeStore.swift:34` | JSON-encoded `Entry{position, duration, savedAt}` | Resume position per recording, per Apple TV. Saved every 10 s while playing and on dismiss; cleared when watched-on-end fires. **One key per recording** — the only multi-key scheme in the app. |
| **`"marlinWeatherFix"`** | `WeatherLocation.swift:58` | `WeatherLocation.swift:76` | `WeatherLocation.swift:82` | never | JSON-encoded location fix | The cached CoreLocation fix, so the location prompt happens once. |

All three go through `UserDefaults.standard` (`ResumeStore.swift:22`/`:29`/`:34`,
`WeatherLocation.swift:76`/`:82`) or an injected `UserDefaults` defaulting to `.standard`
(`ClientSession.swift:27`, `PlaybackSession.swift:39`).

**No key name is proposed for a selected collection**, as the brief requires.

### 5.2 Does `GET`/`PUT /api/clients/{id}/ui` store a selected collection? — **No.**

**The stored type carries two fields and neither is a selection.** `clients.go:37-40`:

```go
type UICollection struct {
	ID     string `json:"id"`
	Hidden bool   `json:"hidden"`
}

type ClientUI struct {                                   // :42
	Sidebar     []UIItem       `json:"sidebar"`          // :43
	Collections []UICollection `json:"collections"`      // :44
}
```

**`PUT /api/clients/{id}/ui`** — route `main.go:305`, handler `clients.go:412-452` — accepts
`{reset, sidebar:[UIItem], collections:[UICollection]}` (`:418-421`), and stores
`ui := ClientUI{Collections: req.Collections}` (`:434`). `{"reset": true}` clears the layout to
defaults (`:426-428`). **There is no `selected`, `current`, `active`, `default` or equivalent field
anywhere in `ClientUI` or `UICollection`.**

**`GET /api/clients/{id}/ui`** — route `main.go:304`, handler `clients.go:401-408`, builder
`clientUI` `:350-398` — returns a **richer** row shape than it accepts:

```go
type collRow struct {                                    // :372-378
	ID     string `json:"id"`
	Label  string `json:"label"`      // ← "label", not "name"
	Icon   string `json:"icon"`
	Count  int    `json:"count"`
	Hidden bool   `json:"hidden"`
}
rows = append(rows, collRow{ID: c.ID, Label: c.Name, Icon: c.Icon,
                            Count: len(c.ChannelIDs), Hidden: hidden[c.ID]})   // :387
```

Three properties worth recording because they are traps:

- the key is **`label`**, not `name` (`:374`, `:387`);
- **`count` here is `len(c.ChannelIDs)`** — dead and hidden members included — so it can disagree with
  `/api/collections`' `count`, which counts resolved members only;
- `hidden` is **that device's own** flag, and **the server does not act on it**: every client still
  gets every collection from `GET /api/collections`. Honouring it is the client's job. Rows are sorted
  by the device's saved order, with unsaved collections stably last (`:388-396`).

**So the route stores per-device visibility and per-device order, and nothing else.** It answers the
step's question: a selected collection has no server-side home in 1.8.1.

**And this app does not call the route at all.** `grep -rn "clients/"` over every app Swift file
returns exactly two lines — `ClientSession.swift:66` (`POST /api/clients/{id}/ping`) and `:87`
(`POST /api/clients/register`). **Neither `GET` nor `PUT /api/clients/{id}/ui` has ever been called by
this app.**

---

## 6. Step 6 — interactions to check

### 6.1 DRM filtering in `ChannelFilter.swift` against a filtered guide — **still required, and still correct**

The rule, stated in the file's own header (`ChannelFilter.swift:5-8`): *"channels with `drm = true`
never appear in any list. The server returns them with the flag set … and does not hide them itself."*

- `[GuideRow].playable` — **`ChannelFilter.swift:21-23`**, `filter { !$0.channel.drm }`
- applied to every guide read at **`ChannelFilter.swift:67`**, `response.channels = response.channels.playable`

**The server's collection filter does not remove DRM channels.** `filterChannels` starts from
`a.channels(false)` (`sources.go:359`), which drops **hidden** channels and channels of **disabled**
sources — and nothing else. `mc.DRM` is carried straight through at `sources.go:321` and no `case` arm
in `:369-386` tests it. So a DRM channel that is a collection member arrives as a guide row and
**`:67` is what removes it.**

**Consequence, and it is a real one.** After `:67`, `response.channels.count` can be **less** than the
server's own `channelCount` (`Models.swift:131`), and can be **zero** for a collection every member of
which is DRM. Live today this is not exercised — all five rows of the "Local" collection are
`drm=false` (§V4c) — but nothing prevents the owner adding a DRM channel to a collection from the
admin page.

### 6.2 `+12h` against a filtered grid

Two distinct effects, both from the same line.

**(a) `endOfListings` is computed from the filtered rows.** `GuideScreen.swift:117`:

```swift
endOfListings = !rows.contains { $0.blocks.contains { $0.program != nil } }
```

`rows` at that point is already `.playable`-filtered (`ChannelFilter.swift:67`) and, with a collection
selected, already collection-filtered. A collection whose channels have shorter guide data than the
lineup as a whole will therefore hit `endOfListings` **sooner** than the unfiltered Guide does, and
the `+12h` button (`:363`) will vanish earlier. That is correct behaviour — there genuinely are no
listings for *those* channels — but it means the button's presence becomes collection-dependent.

**(b) A collection that yields zero rows makes `endOfListings` true immediately.** With `rows` empty,
`rows.contains { … }` is `false`, so `endOfListings` becomes `true` on the first fetch. Combined with
`isAtNow` being true on a fresh load, **neither header pill is rendered** (`:351` and `:363` both
fail), `LoadingLine` is gone once `loaded` is true (`:253-255`), and the grid has no cells. See §6.5.

**(c) Three call sites, all of which would need the filter.** `fetch(from:)` is private and reached
from `loadNow()` (`:93`), `pageForward()` (`:100`) and `snapToNow()` (`:106`). A filter threaded
through one or two of the three and not the third would produce a Guide that silently reverts to the
full lineup on `+12h` or on `↩ Now` — **and §3.2 fact 4 means an unknown filter also produces a full
lineup with no error.** Both failure modes look identical to a full grid.

### 6.3 Record/pass marks and the airing sheet against filtered rows — **unaffected**

**The marks.** `fetch` runs `api.schedule()` concurrently with the guide (`GuideScreen.swift:112`).
`ChannelFilter.swift:97-105` reads `GET /api/schedule` and applies only `.playable` to each group's
items — **no collection filter, and none exists on that route**. The join is by identity:

```swift
func job(channelId: String, programStart: Int) -> Job? {          // :143
    jobs.first { $0.channelId == channelId && $0.program.start == programStart }
}
```

Because the join is on `channelId` and `program.start` rather than on position, a filtered row set
resolves its marks exactly as an unfiltered one does. `mark(for:)` at **`:173-178`** is unchanged by
any of this: green `.recording` when `job.status == "Recording"`, then `.scheduled` (manual) or
`.pass` on `Queued`/`Conflict` by `passId == "manual"`.

**The sheet.** `AiringSheet` is presented from `GuideScreen.swift:290-303` with an `AiringSelection`
carrying the channel, the programme and the job (`:217`, `:234`). Its own reads are `GET /api/passes`
(`AiringSheet.swift:330`), `GET /api/art/show?title=` (`:39-42`) and — via `onScheduleChanged`
(`GuideScreen.swift:298-301`) — `model.refreshSchedule()` at **`:164-170`**, which re-reads the whole
unfiltered `GET /api/schedule`. Its writes (`:357` record now, `:376` create pass, `:412` stop) all
take a channel id and a programme start. **Nothing in the sheet is collection-aware and nothing needs
to be.**

**One thing does change, and it is about focus, not data.** Closing the sheet restores focus by plain
assignment — `GuideScreen.swift:318-323`:

```swift
} else if model.sheet != nil {
    model.sheet = nil
    Task { try? await Task.sleep(for: .milliseconds(60)); focused = lastCell }
}
```

`lastCell` (`:192`, set at `:310-312`) is a cell id of the form `"<channel.id>@<program.start>"`
(`:53`). **If the collection changed while the sheet was open, that id may name a row that no longer
exists**, and the assignment would put focus nowhere — which is precisely the failure the Search
screen measured twice (§2.4).

### 6.4 A duplicate member id produces duplicate SwiftUI ids

The server stores duplicates — the handoff's §2 records "Nothing is validated: any string is stored as
a member, including … **duplicate** ids", and `sources.go:396-400` appends once per entry in
`coll.ChannelIDs`, so a duplicate yields **two rows with the same channel**.

In the app, **`GuideRow.id` is `channel.id`** (`Models.swift:108`) and the grid is
`ForEach(model.rows)` at **`GuideScreen.swift:258`** — an `Identifiable` `ForEach` with **no explicit
`id:`**. Duplicate ids in an `Identifiable` `ForEach` are undefined behaviour in SwiftUI and in
practice produce a runtime complaint and unstable view identity. The same duplication would reach
`cells(for:)` (`:133-144`) and `GuideCellItem.id` (`:53`), which composes `channel.id` with
`program.start` — so the **cell** ids would collide too.

**Nothing in the owner's live data does this today** (§V4b: five distinct ids), and the admin page
cannot create one — its "Add Channels" pool excludes ids already in the collection
(`channel-collections.js:78-79`). The `PUT` route can.

### 6.5 An empty result strands the remote — a measured device failure, cited

If a selected collection yields **zero rows** — every member hidden, every member DRM, every member
dead, or the collection simply emptied — then on the Guide:

- the grid's `ForEach` (`:258`) draws nothing;
- `LoadingLine` (`:254`) is gone, because `loaded` is `true` (`:129`);
- `↩ Now` (`:351`) is not drawn, because `isAtNow` is true on a fresh load;
- `+12h` (`:363`) is not drawn, because `endOfListings` is true (§6.2b);
- `firstCellID` (`:341-346`) is `nil`, so `.task`'s `focused = firstCellID ?? "page"` (`:308`) names
  `"page"` — **a focus id that has no view**.

**Nothing on the screen is focusable. That is not a cosmetic problem, and this project has measured
its consequence twice on the device:**

> `TrashManageView.swift:58-62` — "Focusable, and holding the `"empty"` focus id, because it is the
> only thing left on the screen once the last recording is restored … **without this nothing can take
> focus and the remote's Menu never reaches `.onExitCommand` — it leaves the app instead. Found on the
> device, Pass 33** (the run at 21:13, report §3)."

> `RadarScreen.swift:202-203` — "tvOS gives the screen nothing else to focus while the map is the only
> content; **without a focusable item the Menu handler never receives the press.**"

So an empty collection would leave the Guide with **no focus and no working Menu** — the remote would
exit the app. Both prior fixes were the same: give the empty state something `.focusable()`.

### 6.6 Everything else that reads `GET /api/guide`

`grep -rn "api\.guide("` over all 48 app Swift files and all 13 UI-test files returns **two** callers:

| Caller | Line | Call | Collection-relevant? |
|---|---|---|---|
| `GuideModel.fetch(from:)` | **`GuideScreen.swift:111`** | `api.guide(start: start, slots: 48)` | **yes** — the grid this pass is about |
| `OnNowModel.showNextHours(for:)` | **`OnNowScreen.swift:100`** | `api.guide(start: nil, slots: 12, source: item.channel.sourceId)` | **no** — "the next six hours on **one** channel", filtered by `source` and then narrowed to a single row at `:101` (`guide.channels.first(where: { $0.channel.id == item.channel.id })`). A collection filter would only risk removing the one row it wants. |

**Routes the server does NOT filter by collection**, so nothing downstream of them changes
(`pass94-collections-recon.md` §4b, verified against `main.go:264-267` and the absence of any
`filterChannels` call in those handlers): `GET /api/guide/later` (`ChannelFilter.swift:72-74`, used by
`OnLaterScreen`), `GET /api/guide/find` (`:82-85`, `GuideSearchScreen.swift:115`),
`GET /api/guide/search` (`:91-94`, `GuideSearchScreen.swift:145`), and `/api/guide/stats`. **Only
`guide.go:671` and `guide.go:729` call `filterChannels`.**

**Routes that DO honour `filter` and that this app already calls:** `GET /api/channels`
(`ChannelFilter.swift:43-49` — used by `HomeView.swift:36`, `OnNowScreen.swift:75`,
`FavoritesScreen.swift:36`, `GuideSearchScreen.swift:154`) and `GET /api/guide/now`
(`ChannelFilter.swift:52-58` — `OnNowScreen.swift:87`, `FavoritesScreen.swift:37`,
`HomeView.swift:37`). **None of them passes a collection today.** Whether a collection chosen in the
Guide should reach any of them is not in the approved design and is not proposed here.

---

## 7. Step 7 — SWEEP or STANDALONE

**Only the five items the brief lists are sorted. Nothing is added.**

| # | Work item | Sort | Why, in one line |
|---|---|---|---|
| **1** | **Header layout** — "Guide" · collections button · date range shifted right · `+12h` unchanged | **SWEEP** | It is a change to `ScreenHeader`'s own shape (`ScreenChrome.swift:13-39` has title, optional subtitle, `Spacer`, trailing — and no third slot), and `ScreenHeader` is used by every screen in the app; it cannot be judged or tested apart from the button that sits in it. |
| **2** | **The button and its drop-down** | **SWEEP** | It is the same view as item 1 — the button *is* the header change — and §4 shows the mechanism is unproven on this platform, so it has to be built and seen together with the layout rather than in isolation. |
| **3** | **Reload via the server's collection filter** | **STANDALONE** | It is one argument threaded through three call sites (`GuideScreen.swift:93`, `:100`, `:106` into `:111`) on a client method that already takes `filter:` (`ChannelFilter.swift:61-69`); it is testable on its own against a known collection id and has no view consequence beyond fewer rows. |
| **4** | **Button label takes the collection's name** | **SWEEP** | It is a property of the same button as items 1 and 2 — one string on one view — and shipping it apart from them would mean touching the same lines twice. |
| **5** | **Persistence across launches** | **STANDALONE** | It is a storage concern with no view surface: §5.1 shows the three existing keys are self-contained, and §2.5 shows the only question is ownership above vs below `ScreenShell.swift:55` — settled once, independently of how the button looks. |

**SWEEP:** items **1, 2, 4** — one header, one button, one label, one thing to look at on the
television. **STANDALONE:** items **3** and **5** — a query argument and a stored value, each provable
without the other and without the header.

---

## 8. Open questions

**Raised, not answered, and none acted on.**

1. **`ScreenHeader` has no third slot.** Its body is title → subtitle → `Spacer` → trailing
   (`ScreenChrome.swift:24-37`), and `ScreenHeader` is used by every screen in the app. Putting a
   control between the title and the date range means either changing that shared type or the Guide
   not using it. *What breaks without an answer:* item 1 cannot be built.
2. **A stale saved collection id fails invisibly.** `sources.go:362-364` looks a filter up as a
   collection only when it is not one of the four built-in words; an id that matches nothing applies
   **no predicate** and returns every visible channel (§3.2 fact 4). A collection deleted on the admin
   page would therefore leave the Apple TV showing a full grid under a button still reading the old
   name. *What breaks without an answer:* item 5 has no defined behaviour for the id it restores.
3. **Id or name as the filter value?** `findCollection` accepts either (`collections.go:50-60`). The
   server's own Guide page sends the **name** (`marlin.js:242`); its Channel Collections page sends
   the **id** (`channel-collections.js:22`). The name path has two traps: a collection named
   `Favorites`/`All Channels`/`HD`/`Non-HD` is unreachable by name, and duplicate names resolve to the
   first in the file. **Not chosen here.**
4. **What "All Channels" should send.** The design's default button label is "All Channels", which is
   also one of the server's four built-in filter words (`sources.go:362`). Sending it, sending `""`
   and sending nothing all produce the same full grid, but only one of them is what the rest of the
   app does. **Not chosen.**
5. **An empty collection strands the remote (§6.5).** The Guide would have nothing focusable and Menu
   would exit the app — measured twice on the device in other screens. *What breaks without an
   answer:* a real, reachable dead end.
6. **A duplicate member id breaks `ForEach` identity (§6.4).** `GuideRow.id` is `channel.id`
   (`Models.swift:108`) and `GuideScreen.swift:258` is a plain `Identifiable` `ForEach`. Unreachable
   from the admin page, reachable from the `PUT` route.
7. **Whether the Guide's plain-assignment re-focus survives a rows-replaced reload.** The Search screen
   needed a `.id(generation)` rebuild for this, measured twice (`GuideSearchScreen.swift:295-311`), and
   "**`GuideScreen` may carry the same latent focus defect**" is a standing open question from Passes
   63, 65, 66 and 68 that nobody has investigated.
8. **Whether the chosen collection should reach `GET /api/guide/now` and `GET /api/channels`.** Both
   honour `filter` and both are already called by this app (§6.6). The approved design says the Guide
   only. **Not proposed** — recorded so the question is not lost.
9. **`COLD-START.md:37-38` records the server as 1.8.0; it is 1.8.1 (§V4a). `COLD-START.md:67-68`
   records the reference clone's tree as 1.2.1; it reads 1.8.1.** Neither corrected — this pass writes
   one file.
10. **`icon-source/` is still 32 untracked entries** and its fate is still the owner's undecided call
    (`DECISIONS.md`, 2026-09-08). Restated only so it is not mistaken for drift.

---

## 9. The things I am least sure of

1. **That a SwiftUI `Menu` or `Picker` can be made to look like this app.** I can prove from the SDK
   that both exist on tvOS 18 and that `MenuStyle`/`PickerStyle` let the **label** be restyled. I
   cannot tell you what the presented list looks like, whether it honours `Nocturne` colours and
   `PillLabel` shapes, how it takes focus from a header `.focusSection()`, or how it dismisses — **this
   app has never presented one, on either Apple TV or in the Simulator**, and this pass ran neither.
   Every row of §4.6 marked "by contract" is documentation, not measurement. If item 2 is built on a
   `Menu` and it looks like a system sheet, that is the risk I could not retire from here.
2. **That the ordering evidence is stronger than it looks.** The live filtered guide came back in
   collection order — but that collection's order happens to equal ascending channel number, so
   **the GET does not actually distinguish "collection order wins" from the default sort** (§V4c). I
   am relying on `sources.go:389-401` and on the reference project's fixture measurement. If the owner
   reorders "Local" so its order differs from its numbers, one GET settles it; I did not reorder
   anything, because that is a write.
3. **That §6.5's stranding really happens on the Guide.** The mechanism is the same one two other
   screens hit on the device (`TrashManageView.swift:58-62`, Pass 33's 21:13 run; `RadarScreen.swift:202-203`),
   and the Guide's own conditions line up exactly — but I traced it in code, I did not watch it. It
   needs one empty collection and one Apple TV to confirm, and this pass ran no device.

---

## 10. SCOPE CHECK — every path touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | **read only** | 1, required reading |
| `reports/*.md` (69 files) | **read only**, in full | 1 |
| `Marlin DVR TV/*.swift` (48) | **read only**, in full | 1, 2, 5, 6 |
| `Marlin DVR TVUITests/*.swift` (13) | **read only**, in full | 1, 6 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **read only** | 1, 4 |
| `Info.plist`, `Marlin DVR TV.entitlements` | **read only** | 1 |
| `design/` (14 files) | **read only, never written** | 1, 2, 4 |
| `~/Xcode/marlin-dvr-reference` | **`git show` and `cat` only** — no fetch, no checkout, no edit, nothing run | 3, VERIFY |
| `…/AppleTVOS26.5.sdk/…/SwiftUI.swiftinterface` | **read only** | 4 |
| `http://192.168.1.250:8090/` | **three GET requests** (`/api/status`, `/api/collections`, `/api/guide?filter=…&slots=1`), made twice — **no POST, PUT or DELETE** | 3, VERIFY |
| the session scratchpad | three response bodies saved outside the repo | 3 |
| `reports/2026-09-11-pass71-guide-collections-recon.md` | **created — the only write** | 8, DELIVERABLE |

**Not touched:** every Swift source, the Xcode project, `Info.plist`, the entitlements file, every
build setting, the asset catalog, `build/`, `icon-source/`, `design/` (read, never written), every
earlier report, and every other folder under `~/Xcode`. **No build, no test, no device run, no
install, no dependency. Unraid `192.168.1.250` as a host, marlinpc `192.168.1.245`, the HDHomeRun
`192.168.1.105` and the UNAS4Pro share were not touched** — the only traffic was the three read-only
GETs to the DVR's HTTP API.

**No credential, token, device id or client id appears in this report** (§3.3 sets out why the live
responses contain none).

---

## 11. Git

`git status` before this pass (§V1) read `?? icon-source/` and nothing else. **The only change this
pass makes to the working tree is this file**, so `git status` afterwards reads `?? icon-source/` plus
this report — and the report is then committed in its own commit and pushed. The three SHAs
(`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`) are verified after a
fresh `git fetch origin` and reported in this pass's response, because a commit cannot contain its own
hash (`DECISIONS.md` 2026-09-09 (Pass 60) rule (b), and Pass 68's ordering rule: the report goes **in**
the commit).

**Nothing forced. No history rewritten.**
