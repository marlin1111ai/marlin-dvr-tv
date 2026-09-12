# Pass 75 — Guide scroll-right: recon

**Date:** 2026-09-12
**READ-ONLY. Exactly one file is written by this pass: this report.** No Swift file, no project file,
no `Info.plist`, no entitlements file and no asset was modified. `design/` was read and never written.
`~/Xcode/marlin-dvr-reference` was read with `git rev-parse`, `grep` and `sed` only — never edited,
never fetched, never checked out, nothing run from it. **Three requests were made to the live server
and all three are GET** (§V2). No build, no test, no device run, no install. No probe file and no
scratch file was left anywhere in the repo.

**Pass number.** The highest-numbered report in `reports/` before this pass is **pass74**
(`2026-09-12-pass74-collections-accepted-and-pushed.md`), so this is **Pass 75**.

**What this pass is for.** The owner's goal, 2026-09-12: *the Guide grid scrolls right. Pressing
Right on the last visible cell of a row moves the window forward in time — the time strip and every
row together — and keeps moving as long as there are listings, fetching more as needed. Forward only,
as today. ↩ Now returns to the current half hour. +12h stays. Collection filtering (Pass 72) keeps
working while scrolled.* This pass reconnoitres that and nothing else. **Nothing is chosen, proposed
or designed beyond what the numbered steps ask for, and no mechanism is recommended.**

---

## VERIFY — the evidence the brief asks to be shown

### V1. `git status` before and after

**Before step 1:**

```
$ git status --porcelain
?? icon-source/

$ git rev-parse --abbrev-ref HEAD
main
$ git rev-parse HEAD
554235751fc7554ef38fa8b8619f4cfd13b11b1e
```

**After step 8** (the two outputs and the diff are reproduced in §V5 of this pass's response; the
working tree differs by this file alone):

```
$ git status --porcelain
?? icon-source/
?? reports/2026-09-12-pass75-guide-scroll-recon.md

$ git diff HEAD --stat
(empty — no tracked file modified, nothing staged)
```

`icon-source/` is the standing untracked baseline — 32 entries, its fate the owner's undecided call
since Passes 51–55 (`DECISIONS.md`, 2026-09-08). **Before and after differ by exactly one entry: this
report.** It is staged **by name** and committed on its own, so `icon-source/` cannot be swept in.

### V2. The live GETs, trimmed to the fields cited

**Three requests, all GET. No POST, PUT or DELETE of any kind.** The step's phrase "one live GET" was
read as *GET only*, and the step itself names a second source for the coverage horizon ("`GET
/api/status` or the guide's own end"). Each request below is mapped to the clause of step 4 it
answers, and a third was needed because the server's horizon field carries a weekday and a clock but
**no date** (§4.4). **`GET /api/settings` was not read** — it is on this project's standing
do-not-read list.

**Clock for all three:** `date +%s` at the start of the sequence = **1789213911** = Sat 2026-09-12
**07:51:51 EDT**. Current half hour = 1789212600 = Sat 07:30.

#### V2a — `GET /api/guide?start=1790423511&slots=48` (a far-future start, 14 days out)

`HTTP 200`, 42,477 bytes, 0.007 s. Trimmed to the fields cited:

```
top-level keys : ['channelCount', 'channels', 'dayLabel', 'nowIndex', 'slots', 'start', 'timeSlots']
start          : 1790422200      ← the 30-minute truncation of the 1790423511 asked for
slots          : 48
dayLabel       : Sat, Sep 26
nowIndex       : -1
channelCount   : 91
len(channels)  : 91
len(timeSlots) : 48
timeSlots[0]   : {'label': '7:30 AM',  'start': 1790422200}
timeSlots[-1]  : {'label': '7:00 AM',  'start': 1790506800}

rows with >= 1 non-null program : 0
blocks-per-row histogram        : {1: 91}      ← every row has exactly one block
row0  hdhr-10a75953:2.1  2.1  WMAR-HD
row0 blocks : [{"title": "No listing", "subtitle": "", "span": 48, "isLive": false,
                "channelId": "hdhr-10a75953:2.1", "empty": true}]
row0 block keys : ['channelId', 'empty', 'isLive', 'span', 'subtitle', 'title']   ← no "program" key
row key set     : ['blocks','drm','favorite','guid','hd','hidden','id','initials','logo',
                   'logoBg','name','number','origName','origNumber','source','sourceId']
```

#### V2b — `GET /api/guide/stats` (the guide's own end)

`HTTP 200`. **Verbatim:**

```json
{"lineups":4,"channels":103,"channelsWithGuide":103,"shows":2101,"listings":29220,
 "bytesOnDisk":17579177,"sizeLabel":"16.76 MB","refreshedAt":"2026-09-12T07:06:16-04:00",
 "refreshedLine":"Last refreshed 45 minutes ago","status":"Idle","coverageUntil":"Sat 5:00 AM"}
```

#### V2c — `GET /api/guide?start=1789801200&slots=4` (Sat 2026-09-19 03:00, to date `coverageUntil`)

`HTTP 200`, 145,224 bytes. Trimmed:

```
start: 1789801200   slots: 4   dayLabel: Sat, Sep 19   nowIndex: -1   channelCount: 91
rows with >= 1 programme: 77 of 91
   9000 AETV    -> (1789797840,1789801500,'Sex, Money, Murder'), (1789801500,1789804920,'The First 48')
   9000 FOX     -> (1789797600,1789819200,'SIGN OFF')
   9002 VH1     -> (1789801200,1789803000,"Nick Cannon Presents: Wild 'n Out")
max programme end in this window: 1789819200 = Sat 2026-09-19 08:00:00
```

**No credential, token, device id or client id appears in this report.** The ids quoted
(`hdhr-10a75953:2.1`, `marlin-cast:9287`, `col-1788571411827`, `col-1789211011169`) are lineup and
collection identifiers of the same form already committed throughout `reports/`. Nothing required
redaction.

---

## 1. Step 1 — what was read, and the count

**No "likely files" subset was used for the app.** Every Swift file in both targets was opened and
read in full.

| Group | Count | Note |
|---|---|---|
| App Swift sources, `Marlin DVR TV/*.swift` | **49** | every one, in full. One more than Pass 71's 48 — `GuideCollections.swift` is new in Pass 72 |
| UI-test Swift sources, `Marlin DVR TVUITests/*.swift` | **14** | every one, in full. One more than Pass 71's 13 — `GuideCollectionsUITests.swift` is new in Pass 72 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **1** | 441 lines, in full |
| `design/` | **14 files** | `Marlin DVR TV.dc.html` (1,411 lines / 118,216 bytes) read at the Guide frames 3a/3b/3c and at the data generators; the other thirteen enumerated and searched, not read line by line (they are the Nocturne bundle, `ATV-DVR.zip`, two scripts, `.thumbnail` and four PNGs) |
| `CLAUDE.md` | **1** | 13 lines, in full |
| `COLD-START.md` | **1** | 1,233 lines, in full |
| `DECISIONS.md` | **1** | 1,153 lines, in full |
| `reports/*.md` | **73 present**; **2 read in full** | the two the brief named — `2026-09-11-pass71-guide-collections-recon.md` (1,147 lines) and `2026-09-12-pass72-guide-collections.md` (435 lines). The other 71 were searched by pattern for horizontal scrolling, right-press evidence and Guide focus evidence (§2.5). **This is less than Pass 71 read and it is stated rather than implied.** |
| `~/Xcode/marlin-dvr-reference` | read-only | `cmd/marlin-dvr/guide.go` (`handleGuide`, `guideStats`, `programsFor`, `GuideStats`), `cmd/marlin-dvr/main.go` (routes, `appVersion`). `git rev-parse` only; no fetch, no checkout, nothing run |
| `AppleTVOS26.5.sdk` SwiftUI / SwiftUICore / UIKit interfaces | read-only | the availability lines quoted in §5.3 |

**"Every notebook file."** This project's notebook is `COLD-START.md` + `DECISIONS.md` + `reports/`
(`DECISIONS.md`, 2026-09-09 (Pass 56): *"This project uses `COLD-START.md` and `DECISIONS.md` only.
They are the whole record"*). **There is no `.ipynb` anywhere in the repo** — `find . -name "*.ipynb"`
returns 0 — so "notebook file" is read as the project's own notebook, not as a Jupyter notebook.

**Three greps worth recording before anything else, because they frame every mechanism in §5:**

```
$ grep -rn "ScrollView" "Marlin DVR TV"/*.swift
  … 13 hits. TWELVE are ScrollView(.vertical…). Exactly ONE is horizontal:
  RecordingsScreen.swift:114   ScrollView(.horizontal, showsIndicators: false)

$ grep -rn "ScrollViewReader|scrollTo|scrollPosition|scrollTargetBehavior|scrollTargetLayout|
            scrollClipDisabled|defaultScrollAnchor|scrollDisabled" "Marlin DVR TV"/*.swift
  (no output)

$ grep -rn "onMoveCommand|moveCommand" "Marlin DVR TV"/*.swift
  (no output)
```

**So: one horizontal `ScrollView` in the whole app, no programmatic scrolling of any kind anywhere,
and no directional-move handler anywhere.** Every scroll this app performs today is the focus engine
moving a `ScrollView` by itself.

---

## 2. Step 2 — the grid today

All line numbers are `Marlin DVR TV/GuideScreen.swift` (643 lines) unless another file is named.

### 2.1 The 2-hour window: fixed, computed, not a scroll view

**There are four constants and one state variable, and the whole screen is derived from the one
variable.** `GuideModel`, **`:68-71`**:

```swift
static let windowSeconds = 7200     // :68  the visible window — 2 hours
static let pageSeconds   = 43200    // :69  one "+12h" press — 12 hours
static let fetchSlots    = 48       // :70  one fetch — 48 half-hour slots = 24 hours
static let slotSeconds   = 1800     // :71
```

```swift
private(set) var windowStart = 0                                      // :84
var windowEnd: Int { windowStart + Self.windowSeconds }               // :92
var isAtNow: Bool { windowStart == TimeFormat.currentHalfHour }       // :93
var slotStarts: [Int] { (0..<4).map { windowStart + $0 * Self.slotSeconds } }   // :94
```

**`windowStart` is the only thing that moves.** Everything the screen draws about time is computed
from it: the four column labels (`slotStarts`, `:94` → `columnHeader`, **`:461-485`**), the header's
date range (`windowLabel`, **`:201-207`**), whether the window crosses midnight (`crossesMidnight`,
**`:97-99`**), whether the `↩ Now` pill is drawn (`isAtNow`, `:93` → **`:431`**), the footer sentence
(**`:506`**), and every cell's position (`GuideCellItem.startFraction`/`endFraction`, **`:62-63`**).

**The programme area is NOT a scroll view.** `GuideRowView.body` (**`:528-555`**) is an
`HStack(spacing: 18)` of the 300 pt channel cell (`:532-537`) and a **`GeometryReader`** (`:538`)
holding a `ZStack(alignment: .topLeading)` (`:539`) of absolutely-offset cells (`:540-550`). There is
**no horizontal `ScrollView`, no `LazyHStack` and no grid** in a Guide row. There is one vertical
`ScrollView` wrapping the whole stack of rows, **`:288-305`**.

**Cell widths are proportional, not fixed columns.** `GuideCellItem`, **`:51-64`**:

```swift
var startFraction: CGFloat { CGFloat(max(program.start, windowStart) - windowStart)
                             / CGFloat(windowEnd - windowStart) }          // :62
var endFraction:   CGFloat { CGFloat(min(program.end,   windowEnd)   - windowStart)
                             / CGFloat(windowEnd - windowStart) }          // :63
```

and `GuideRowView.frame(for:width:)`, **`:558-563`**:

```swift
let x     = start * width + (start > 0 ? 6 : 0)
let right = end   * width - (end   < 1 ? 6 : 0)
return (x, max(right - x, 24))
```

So a cell's box is `(end − start) × rowWidth` less a 6 pt inset on each **interior** edge, floored at
**24 pt**. Row height is fixed at **82 pt** (`rowHeight`, `:266`); the channel column is **300 pt**
(`:264`) and the gap between the two is **18 pt** (`columnGap`, `:265`). This matches the design's
frame 3a (`dc:203`: `height:82px`; `dc:205`: `width:300px`; `dc:202`: `gap:18px`), **except that the
design draws a four-column CSS grid** (`grid-template-columns:repeat(4, 1fr)`, `dc:216`) with cells
spanning whole columns, and the app places cells by true start/end instead. That divergence is
deliberate and recorded since Pass 4 §3.4 — the file header says so at **`:5-7`**.

**A programme spanning the window edge is clipped to the window and drawn flush, with no cue that it
continues.**

- **Left edge:** `max(program.start, windowStart)` makes `startFraction` exactly `0`, so `start > 0`
  is false and **the 6 pt inset is not applied** — the box begins flush at x = 0.
- **Right edge:** `min(program.end, windowEnd)` makes `endFraction` exactly `1`, so `end < 1` is
  false and **the 6 pt inset is not applied** — the box ends flush at the row's right edge.
- **Nothing marks the truncation.** `GuideCellLabel` (**`:604-643`**) draws the title at
  `lineLimit(1)` (`:623`) inside `.padding(.horizontal, 20)` (`:633`) with `.clipped()` on the whole
  label (**`:636`**). There is no arrow, no ellipsis on the box, no second colour — a programme that
  runs past the edge looks exactly like one that ends there.
- **A sliver is unreadable.** With the 24 pt floor and 40 pt of horizontal padding, a programme with
  only a minute or two inside the window draws a 24 pt box whose text is entirely clipped.
- **A focused edge cell's shadow is clipped, its ring is not.** `GuideCellLabel`'s focus ring is
  `strokeBorder` (`:639`), which strokes inside the frame, so it survives; the `.shadow(radius: 32,
  y: 26)` at **`:641`** extends outside the frame and is cut by the vertical `ScrollView` at `:288`,
  which clips by default. `.scrollClipDisabled()` appears **nowhere in the app** (§1), and the
  ScrollView has `.padding(.vertical, 6)` (`:304`) but **no horizontal padding**. This is the same
  family of defect as Passes 46–47, and it is already true today for any programme that reaches the
  window edge.

**One arithmetic mismatch between the strip and the cells, found by calculation rather than by eye.**
`columnHeader` lays its four labels in an `HStack(spacing: 12)` (**`:468`**) of equal-width
`.frame(maxWidth: .infinity)` slots (`:479`), so label *i* begins at `i × (W/4 + 3)` where `W` is the
programme area's width. A cell at slot *i* begins at `i × W/4`. **Label *i* therefore sits 3·*i* pt
to the right of the time it names** — 0, 3, 6 and 9 pt across the four columns. Small, pre-existing,
and cosmetic today; it becomes more visible if the window moves a slot at a time.

### 2.2 How a row is built from the fetched blocks

```swift
func cells(for row: GuideRow) -> [GuideCellItem] {                       // :153
    var seen = Set<Int>()
    var out: [GuideCellItem] = []
    for block in row.blocks {
        guard let p = block.program, p.end > windowStart, p.start < windowEnd,
              !seen.contains(p.start) else { continue }                  // :157
        seen.insert(p.start)
        let job = job(channelId: row.channel.id, programStart: p.start)  // :159
        out.append(GuideCellItem(channel: row.channel, program: p, mark: mark(for: job),
                                 job: job, windowStart: windowStart, windowEnd: windowEnd))
    }
    return out
}
```

Four things follow, all load-bearing:

1. **The app reads `block.program` and nothing else from a block.** `span`, `subtitle`, `isLive`,
   `empty` and `channelId` are decoded (`Models.swift:108-116`) and never consulted by the Guide.
   That is the same finding Pass 26 recorded and it still holds.
2. **`program.start`/`program.end` are the server's true, unrounded times**, because the server
   attaches the whole `Program` to the block (`guide.go:701` in the clone: `pp := p` … `Program:
   &pp`). So the app's proportional layout is exact even though the server's own `span` is rounded up
   to whole half hours.
3. **A programme is included whenever it overlaps the window at all** (`p.end > windowStart && p.start
   < windowEnd`), so cells clipped at either edge are normal, not exceptional. A programme starting
   exactly at `windowEnd` is excluded.
4. **Duplicates are dropped by `program.start`**, and one fetch's blocks can repeat a programme
   across slots — that is why `seen` exists.

`rows` itself is set in one place, `fetch(from:)` **`:124-150`**:

```swift
async let guide = api.guide(start: start, slots: Self.fetchSlots, filter: collections.selectedId) // :126
async let schedule = api.schedule()                                       // :127
let g = try await guide                                                   // :128
var seen = Set<String>()
rows = g.channels.filter { seen.insert($0.id).inserted }                   // :133-134
fetchStart = g.start                                                      // :135
fetchEnd   = g.start + g.slots * Self.slotSeconds                         // :136
endOfListings = !rows.contains { $0.blocks.contains { $0.program != nil } } // :137
```

`g.channels` has already had the DRM rule applied by the typed client
(`ChannelFilter.swift:67`, `response.channels = response.channels.playable`).

### 2.3 What happens on Right at the last visible cell today

**Nothing, by construction — and that is reasoning from the code, not a device measurement.**

- A programme wholly after the window is **not in `cells(for:)` at all** (`:157`), so there is no
  focusable view to the right of the last cell in a row.
- Every cell is clamped inside the row's own box: `startFraction` cannot be negative (`max(…)`,
  `:62`) and `endFraction` cannot exceed 1 (`min(…)`, `:63`), so no cell is offset outside the
  `GeometryReader`.
- The grid carries **no `.focusSection()` of its own** — the sections in play are the header's
  (**`:457`**) and the shell content's (`ScreenShell.swift:63`) — and there is nothing in either to
  the right of a row.
- There is **no `.onMoveCommand`** and no press observer on this screen (§1), so a Right press that
  moves no focus is not seen by any app code. The Guide's only press observer is `RemoteHold`, and it
  is armed for `.select` alone (`RemoteHold.swift:124`:
  `press.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]`).

**Focus evidence from prior device runs — and the honest finding is that there is none for this
press.** Every Guide press driven on Home Theater in `reports/` is accounted for:

| Harness | What it presses on the Guide | Line |
|---|---|---|
| `RemoteHoldUITests` | `.left` from the first programme cell → that row's channel cell; `.select`/hold | `:45`, `:49`, `:74`, `:119` |
| `RailFocusRestoreUITests` | `.left` repeatedly into the rail — *"the Guide needs two, because its default focus is a programme cell and the first press reaches the channel cell"* | `:74-77` |
| `GuideCollectionsUITests` | `.left` into the rail; `.right` **from the rail** into the content; `.up` to the header; `.right` **along the header** to `↩ Now` / `+12h`; `.down`/`.up` inside the overlay | `:151`, `:166-167`, `:175`, `:322-325` |
| `StopRecordingUITests` | hold on the current programme; `.right` **inside the airing sheet** to reach Stop | `:69`, `:109` |

**No run in `reports/` has ever pressed Right from one programme cell to the next inside a Guide
row**, let alone at the last cell. So the baseline — that Right walks along a row at all — is itself
untested on this device, and "Right at the edge does nothing" is a code-traced expectation.

### 2.4 `+12h`, `↩ Now`, the 24-hour fetch, its cache, and the every-second-press rule

```swift
func loadNow() async {                                   // :101
    windowStart = TimeFormat.currentHalfHour             // :102
    await fetch(from: windowStart)                       // :103
}

func pageForward() async {                               // :106
    guard !endOfListings else { return }                 // :107
    windowStart += Self.pageSeconds                      // :108
    if windowEnd > fetchEnd { await fetch(from: windowStart) }   // :109
}

func reloadForCollection() async { await fetch(from: windowStart) }   // :114-116

func snapToNow() async {                                 // :118
    let now = TimeFormat.currentHalfHour
    windowStart = now                                    // :120
    if now < fetchStart || now + Self.windowSeconds > fetchEnd { await fetch(from: now) }  // :121
}
```

**The cache is two integers and nothing else.** `fetchStart` (`:79`) and `fetchEnd` (`:80`) record
the span the last response covered; `rows` (`:77`) holds that response. There is **no store of more
than one fetch** — a new `fetch` replaces `rows` outright (`:134`). So "the cache" is exactly one
24-hour window of rows.

**The "every second press fetches" rule, derived.** A fetch from `S` gives `fetchEnd = S + 86400`; a
press makes `windowStart = S + 43200`, so `windowEnd = S + 50400 ≤ S + 86400` → **no fetch**. The
next press makes `windowStart = S + 86400`, so `windowEnd = S + 93600 > S + 86400` → **fetch**, from
the new `windowStart`. Fetches therefore land at `S`, `S+24h`, `S+48h`, … each covering a contiguous
24 hours, and **every second `+12h` press costs one network round trip**. Pass 71 §2.2 recorded the
same rule.

**`↩ Now` is the same machinery in reverse, and it refetches only when it has to**: `:121` refetches
only if the current half hour is outside `[fetchStart, fetchEnd − 7200]`. Coming back from one `+12h`
press, it usually does not need to.

**Menu at a forward window is `↩ Now`.** `.onExitCommand` (**`:353-373`**): with no overlay and no
sheet, `else if !model.isAtNow { await model.snapToNow(); focusSoon { focused = firstCellID ??
"collections" } }` (`:365-369`), and only at now does it call `onLeave()` (`:371`). The design says
the same (`dc:352`: *"Back snaps the grid to 2:41 PM. Back again leaves the Guide"*).

**`endOfListings` is computed over the whole 24-hour fetch, not the 2-hour window** (`:137`). So the
`+12h` pill (drawn at **`:443`** on `model.loaded && !model.endOfListings`) disappears only once an
entire fetched 24-hour block holds no programme at all.

### 2.5 What is NOT in the Guide today

- **No `ScrollViewReader`, no `scrollTo`, no `scrollPosition`, no `scrollTargetBehavior`, no
  `scrollClipDisabled`** — anywhere in the app (§1).
- **No `.onMoveCommand`** — anywhere in the app (§1).
- **No horizontal `ScrollView`** in the Guide; the app's only one is `RecordingsScreen.swift:114`.
- **No generation-counter rebuild.** That pattern is the Search screen's alone
  (`GuideSearchScreen.swift:229`, `:253-256`, `:312-315`). Pass 72 step 7 tried the Guide's plain
  `@FocusState` assignment first, measured it across six row-replacing reloads, and did not add one.

---

## 3. Step 3 — the time strip

**`columnHeader`, `:461-485`.** It is drawn in the main `VStack` at **`:273-274`**, *above* the
vertical `ScrollView` that holds the rows (`:288`) — so it does not scroll vertically with them.

```swift
HStack(alignment: .top, spacing: Self.columnGap) {                         // :462
    Text("CHANNEL") … .frame(width: Self.channelColumnWidth, alignment: .leading)   // :463-467
    HStack(alignment: .top, spacing: 12) {                                 // :468
        ForEach(Array(model.slotStarts.enumerated()), id: \.offset) { index, start in   // :469
            let newDay = TimeFormat.isMidnight(unix: start)                // :470
            VStack(alignment: .leading, spacing: 4) {
                Text(slotLabel(start: start, index: index, newDay: newDay))  // :472
                RoundedRectangle(cornerRadius: 2)
                    .fill(newDay ? Nocturne.accent : Color.clear)
                    .frame(width: 40, height: 2)                            // :475-477
            }
            .frame(maxWidth: .infinity, alignment: .leading)                // :479
        }
    }
}
.overlay(alignment: .bottom) { Rectangle().fill(Nocturne.divider).frame(height: 1) }   // :484
```

**Is it bound to the same window state as the rows? Yes — to the same single variable.** Its four
labels come from `model.slotStarts` (**`:94`**), which is `(0..<4).map { windowStart + $0 * 1800 }`.
The rows come from `model.cells(for:)` (**`:153-163`**), which takes `windowStart` and `windowEnd`
(**`:92`**) into every `GuideCellItem`. **One write to `windowStart` re-derives both.** There is no
second source of truth, no separate offset, and no synchronisation code — because there is nothing to
synchronise.

Two details of the strip that a moving window would inherit for free:

- **The midnight accent.** `TimeFormat.isMidnight(unix:)` (`Formatting.swift:59-62`) is true at local
  00:00, and `slotLabel` (**`:487-493`**) then prefixes the weekday: `"Sat · 12:00 AM"`. That is
  frame 3c's own treatment (`dc:321-327`, the accent-200 label and the 40 × 2 accent underline).
- **The "· now" marker.** `slotLabel` appends `" · now"` **only when `index == 0 && model.isAtNow`**
  (**`:491`**). So it is attached to the first column and only while the window starts at the current
  half hour. Frame 3a draws exactly that (`dc:207`: `"2:30 · now"`); frame 3c, paged forward, draws
  no "now" at all (`dc:1209-1214`). **There is no vertical now-line anywhere in the app or in the
  design.**

---

## 4. Step 4 — the server's `start` and `slots`

Verified at the reference clone, **`HEAD` = `origin/main` = `eb0c098de3efc8bb569e252b63e141aa10262918`**,
branch `main`, `cmd/marlin-dvr/main.go:38` reading `appVersion = "1.8.1"`. Route
`main.go:262` → `handleGuide`, **`cmd/marlin-dvr/guide.go:649-723`**. Measured live in §V2.

### 4.1 `slots` — the maximum is 48, and the app already sends it

```go
slots, _ := strconv.Atoi(q.Get("slots"))     // guide.go:652
if slots <= 0 || slots > 48 {
    slots = 13                               // guide.go:653-655
}
```

- **Maximum accepted value: 48.** 48 is *not* `> 48`, so it passes. **49 and above silently become
  13**, and so do `0`, a negative number and any non-numeric string (`Atoi`'s error is discarded).
- 48 half-hour slots = **24 hours**, which is the most one request can cover.
- The app sends **48** (`GuideModel.fetchSlots`, `GuideScreen.swift:70`, reaching the wire at `:126`).
  **Measured:** §V2a asked for `slots=48` and the response echoed `slots: 48` with 48 `timeSlots`.
- `timeSlots` has exactly `slots` entries (`guide.go:667-670`). **The app decodes them
  (`Models.swift:142`) and never reads them** — it computes its own four labels from `slotStarts`.

### 4.2 `start` — what it accepts

```go
start, _ := strconv.ParseInt(q.Get("start"), 10, 64)   // guide.go:657
if start == 0 { t0 = now.Truncate(30 * time.Minute) }  // guide.go:659-660
else          { t0 = time.Unix(start, 0).Truncate(30 * time.Minute) }   // guide.go:661-663
t0 = t0.In(time.Local)                                 // guide.go:664
slotStart := t0.Unix()
winEnd := slotStart + int64(slots)*1800                // guide.go:666
```

- **Unix seconds.** Absent, `0`, or anything `ParseInt` cannot read (the error is discarded) →
  **now, truncated to the half hour**.
- Any other value is used **as given and truncated down to a 30-minute boundary**. **Measured:**
  §V2a asked for `start=1790423511` (07:51:51) and the response's `start` is **1790422200** (07:30:00).
  That is the same truncation the app performs in `TimeFormat.currentHalfHour`
  (`Formatting.swift:65`, `Int(Date().timeIntervalSince1970 / 1800) * 1800`), so client and server
  agree on slot boundaries.
- **There is no clamp, no bound and no error path.** A start in the past is accepted; a start far in
  the future is accepted; a negative start is accepted. Forward-only is the *app's* policy
  (`GuideScreen.swift:5-9`, and the footer at `:506`), not the server's.
- `nowIndex` is `-1.0` whenever `now` falls outside the window (`guide.go:715-717`). **Measured:**
  `-1` in both §V2a and §V2c. The app decodes `nowIndex` (`Models.swift:144`) and **never reads it**.

### 4.3 A far-future start returns an empty envelope, not an error — measured

The handler **always emits one row per visible channel**, filling any part of the window it has no
listings for with a synthetic block:

```go
if cursor < winEnd {
    blocks = append(blocks, guideBlock{Title: "No listing",
        Span: int((winEnd - cursor) / 1800), Empty: true, Channel: c.ID})   // guide.go:710-712
}
rows = append(rows, guideRow{MergedChannel: c, Blocks: blocks})             // guide.go:713
```

**Measured (§V2a), 14 days out:** `HTTP 200`, the ordinary seven-key envelope, **`channelCount: 91`
with 91 rows**, every row carrying **exactly one** block — `{"title":"No listing", "span":48,
"empty":true, "isLive":false, "channelId":…, "subtitle":""}` — and **no `program` key at all**.
`nowIndex: -1`. **Zero rows have a programme.**

**Two consequences for the app, both already handled:**

1. `GuideBlock.program` is `Program?` (`Models.swift:113`), and Swift's synthesised decoder uses
   `decodeIfPresent` for an optional, so the **missing** key decodes as `nil` rather than throwing.
   This is not new behaviour — "No listing" blocks are the ordinary case for a channel with a gap.
2. `endOfListings` (**`GuideScreen.swift:137`**) becomes **true** exactly then, because no block in
   any row has a non-nil `program`. So the `+12h` pill disappears and `pageForward()` returns at its
   guard (`:107`).

**What the screen looks like in that state, traced and not seen:** `rows` is **not** empty (91 rows),
so the Pass 72 "Nothing in <name> right now" line does **not** draw (it needs `model.rows.isEmpty`
*and* a selected collection, `:279`). The grid draws 91 channel cells with completely blank programme
areas, `firstCellID` is `nil` (`:405-410`), and focus falls back to `"collections"` (`:347`, `:368`,
`:395`, `:435`). **The remote is not stranded** — the channel cells are focusable `HoldButton`s
(`:532-537`), `↩ Now` is drawn (the window is not at now), and Menu snaps back.

### 4.4 How many hours of listings the server holds — **Sat 2026-09-26 05:00 local, about 333 hours**

`GET /api/status` cannot answer this: it returns only `{name, version, uptime_seconds, port}`
(`main.go:126`, `:232`). The guide's own end can, through `GET /api/guide/stats`
(`main.go:267` → `guide.go:918-920` → `guideStats()`, **`guide.go:552-591`**), whose `coverageUntil`
field is the **maximum programme end across every enabled source**:

```go
for _, p := range g.all() {
    gs.Listings++
    if p.End > newest { newest = p.End }        // guide.go:572-574
}
…
if newest > 0 { gs.Newest = time.Unix(newest, 0).Format("Mon 3:04 PM") }   // guide.go:587-589
```

with the JSON tag `coverageUntil` (**`guide.go:549`**).

**Measured (§V2b): `"coverageUntil":"Sat 5:00 AM"`, 29,220 listings across 4 lineups and 103
channels, last refreshed 45 minutes before the reading.**

**The field carries a weekday and a clock but no date, so it needed dating. Three measurements settle
it:**

1. §V2c found a programme ending **Sat 2026-09-19 08:00**. A maximum of Sep 19 05:00 is therefore
   impossible, and a maximum *at* Sep 19 08:00 would have formatted as `"Sat 8:00 AM"`. So the
   Saturday in question is **not** Sep 19.
2. §V2a found **no programme at all** in `[Sat Sep 26 07:30, Sun Sep 27 07:30)`. The handler includes
   any programme with `p.End > cursor && p.Start < winEnd` (`guide.go:677`), so a programme ending
   after Sep 26 07:30 would have appeared there. The maximum is therefore **≤ Sat Sep 26 07:30**.
3. A Saturday 05:00 that is after Sep 19 08:00 and at or before Sep 26 07:30 can only be
   **Sat 2026-09-26 05:00:00 EDT = 1790413200**.

**From the reading at 1789213911 (Sat 2026-09-12 07:51:51) that is 1,199,289 s = 333.1 hours =
13.88 days.** From the current half hour (1789212600) it is **333.5 hours = 667 half-hour slots**.

Two arithmetic consequences, stated because step 5 needs them:

- **`+12h` reaches the end of the listings in 28 presses.** The window advances 12 h a press and
  `endOfListings` flips at the first fetched 24-hour block wholly past the horizon — `[336 h, 360 h)`
  — which is `windowStart = 336 h`, i.e. `336 / 12 = 28` presses, with 14 fetches.
- **A one-slot-per-press window would need 663 presses** to cover the same ground, and **44 presses
  before the first refetch** (a 24-hour fetch minus the 2-hour window is 22 h = 44 slots), then one
  fetch every 48 presses thereafter.

### 4.5 The collection filter is unchanged by any of this

`filterChannels(source, filter)` (`sources.go:358-406`, quoted in full in Pass 71 §3.2) is the only
thing that decides the row set, and it is called once at `guide.go:671` with no reference to `start`
or `slots`. **So the window and the filter are independent on the server.** §V2a and §V2c were both
read unfiltered and returned `channelCount: 91`, the same count Pass 72 measured unfiltered.

---

## 5. Step 5 — mechanisms, with evidence. **No choice is made.**

### 5.1 (a) A horizontal `ScrollView` with tvOS focus-driven scrolling

**(a1) One horizontal `ScrollView` per row.**

| Question | Answer | Evidence |
|---|---|---|
| How focus behaves at the edge | The focus engine scrolls a `ScrollView` by itself to reveal a focused item that is off-screen. **Proven in this app, on this device, for a shelf of discrete cards** — the Recordings shelves | `RecordingsScreen.swift:114`, walked with `.right` on the device by `CommercialSkipUITests.openShow` (`:126-150`); Passes 46–47 |
| Do all rows stay aligned | **No.** Each `ScrollView` has its own offset, so a Right press in one row moves that row alone. 91 rows would drift apart, and the time strip — which is not in any of them (`GuideScreen.swift:273-274`) — would not move at all | structural |
| Could they be synchronised | Only with an API this app has never used: `ScrollViewReader` (tvOS 14.0), `scrollPosition(id:)` (tvOS 17.0) or `scrollPosition(_:)` (tvOS 18.0). **Zero uses of any of them anywhere in the app** | §1 grep; §5.3 |
| Cost of a re-render | The grid is **already eager**: `ForEach(model.rows)` inside a plain `VStack` inside a vertical `ScrollView` realises **all 91 rows at once**, and Pass 72 measured `app.buttons.count` at **375** unfiltered, with a full accessibility walk resolving **585+ elements at ~0.8 s each** — two harness runs were killed at **t = 1317 s** and **t = 908 s** before the queries were rewritten. A day's cells per row instead of a window's would multiply that element count | Pass 72 §4; `GuideCollectionsUITests:62-68` |
| Clipping | A horizontal `ScrollView` clips by default, `.scrollClipDisabled()` appears nowhere in the app, and that clipping is exactly what cost Passes 46 and 47 — a focused card's overhang cropped | `RecordingsScreen.swift:178-181`; `DECISIONS.md` 2026-09-08 (Pass 47) |
| Status | **The mechanism is proven for a shelf; the shape — 91 synchronised rows plus a strip — is untested and has no synchronisation code in this app** | |

**(a2) One horizontal `ScrollView` for the whole programme area, channel column pinned.**

- **Alignment: yes, by construction** — one offset drives every row, and the time strip could live
  inside the same canvas.
- **Focus at the edge:** the same proven engine behaviour, but never done in this app with a grid or
  with a pinned column.
- **The channel column is the problem.** Today a row is one `HStack` of channel cell + programme area
  (`GuideRowView:529-553`) inside **one** vertical `ScrollView` (`:288`). Pinning the column means
  splitting it out, which leaves a vertical scroll and a horizontal scroll that must stay in step
  vertically as well as with the strip horizontally — again with no synchronisation API in use here.
- **The layout arithmetic is the cheap part.** Cells are already placed by fraction of the window
  (`:62-63`, `:558-563`), so widening the canvas only changes the denominator. It already supports
  any window length.
- **It caps at 24 hours**, because `slots ≤ 48` (§4.1). "Keeps moving as long as there are listings"
  would still need a refetch and a canvas rebuild at each 24-hour seam.
- **It is not what the owner described.** The goal says the *window* moves forward in time and the
  strip moves with it — not that the remote pans across a wider canvas.

### 5.2 (b) The existing fixed window, advanced one slot on a Right press at the edge

**What it would reuse, and this is its whole case: `windowStart` is already the only thing that
moves.** A write to `windowStart` (`:84`) re-derives the strip (`:94` → `:461-485`), every row
(`:153-163` → `:290-302`), the date range (`:201-207`), the midnight accent (`:470`), `isAtNow`
(`:93`) and therefore `↩ Now` (`:431`), `+12h` (`:443`) and the footer (`:506`). **Nothing needs to be
kept in step, because there is only one number.**

| Question | Answer | Evidence |
|---|---|---|
| Window arithmetic | **Proven on the device.** `+12h` and `↩ Now` are the same mechanism at a coarser step, and Pass 72 drove both on Home Theater while filtered, with the rows asserted element by element before and after | Pass 72 §3(d); `GuideScreen.swift:106-122` |
| Re-focus after the row set changes | **Proven, six times.** Pass 72 step 7 measured the plain `@FocusState` assignment behind `focusSoon` across six row-replacing reloads — choose Local (375 → 5), `+12h` while filtered, `↩ Now` while filtered, back to All Channels (5 → 375), a rail round trip, and a relaunch — **never empty in either full harness run**. Pass 73 then proved the one case Pass 72 could not: with an **empty** grid, focus landed on the collections button, `focused=["9:Test"]`, and reproduced on a cold launch with zero presses | Pass 72 §1 step 7 table; Pass 73 / `COLD-START.md` Pass 73 entry |
| Contrast, Passes 63–65 | The Search screen needed a `.id(generation)` **rebuild** for the same job: writing the row id straight into `@FocusState` after the sheet closed left the device with `FOCUSALL[after-sheet] []` — nothing focused — and a longer delay did not help. **Pass 65 removed the rebuild rather than assume `.searchable` had changed anything and the device answered `focused=[]` again**, so it went back in | `GuideSearchScreen.swift:293-311`; `DECISIONS.md` 2026-09-11 (Passes 62-65) |
| Rows stay aligned | **Perfectly**, by construction | above |
| Cost of a re-render | One `windowStart` write recomputes `cells(for:)` for all 91 rows (O(blocks) each) and re-lays every `GuideRowView` and the four strip labels. **No network** for the first **44** presses from now, then one fetch per **48** | §4.4 |
| **The unsolved part: receiving the press** | There is **no** press observer and **no** `.onMoveCommand` on this screen (§1). The two proven press mechanisms in the app are `RemoteHold`'s window-level `UILongPressGestureRecognizer`, armed for `.select` only (`RemoteHold.swift:122-128`), and `PlayerHost`'s `pressesBegan`, which does read `.leftArrow`/`.rightArrow` (`PlayerHost.swift:224-229`) — **but Pass 29's finding is that claiming the press in the responder chain was not enough**: "every arrow press reached `pressesBegan` and none was forwarded to `super`, and Apple skipped 10 s anyway", because another party handled it through its own gesture recognizers, and `armArrowOwnership` had to disable them. In the Guide the competing consumer is the **SwiftUI focus engine**, which is not a recognizer this app can find or disable, and Pass 29 records that "there is no public API to decline the transport's arrow handling" | `PlayerHost.swift:23-31`, `:134-146`; `COLD-START.md` Pass 29 entry |
| The shape that avoids the fight | **At the last cell there is nothing to the right to move to** (§2.3), so a Right press there moves no focus and an observer could act on it without a competing move. **Whether tvOS delivers a `UIPress` for a directional press that moves no focus has never been measured by this project** — it is the single unknown at the centre of (b), and one device probe settles it | — |
| Auto-repeat ("keeps moving") | The focus engine auto-repeats a held direction; a press-based scheme would have to handle repeat itself. **Nothing in this app does** | §1 |

### 5.3 (c) Everything else the codebase or the SDK offers

Availability quoted from
`AppleTVOS26.5.sdk/System/Library/Frameworks/…/arm64-apple-tvos.swiftinterface`. Deployment target is
**tvOS 18.0** (`project.pbxproj:250`, `:305`), so every row below is usable.

| Mechanism | Available on tvOS 18? | SDK evidence | Uses in this app | What it would do, and what is unknown |
|---|---|---|---|---|
| **A focusable edge affordance** | yes (plain SwiftUI) | — | **the pattern is proven three times**: `GuideScreen.swift:278` (`LoadingLine().focusable()`), `TrashManageView.swift:67`, `RadarScreen.swift:204` | A narrow focusable strip at the right edge of a row (or one in the header) that advances the window when focus lands on it. Uses **only** the focus engine, so no press interception and no fight. Cost: a visible element `design/` does not draw, and focus lands on it instead of on a programme |
| `.onMoveCommand(perform:)` + `MoveCommandDirection` | **yes — tvOS 13.0**, iOS/watchOS/visionOS **unavailable** | `SwiftUI.swiftinterface:12271-12293` | **zero** | SwiftUI's own directional hook. Whether it fires *in addition to* a focus move, or only when no move is possible, is **not established by this pass** |
| `ScrollViewReader` | yes — tvOS 14.0 | `SwiftUI.swiftinterface:18006-18007` | **zero** | Would let one or many scroll views be driven programmatically — the only way (a1) could keep 91 rows in step |
| `.scrollPosition(id:)` / `.scrollPosition(_:)` | yes — tvOS 17.0 / tvOS 18.0 | `SwiftUI.swiftinterface:21112-21118` | **zero** | The modern form of the same thing |
| `.scrollTargetBehavior` / `.scrollTargetLayout` | yes — tvOS 17.0 | `SwiftUI.swiftinterface:1359-1365` | **zero** | Slot-aligned snapping for a scrolled canvas |
| `.scrollClipDisabled()` | yes — tvOS 17.0 | `SwiftUI.swiftinterface:11752-11753` | **zero** — and Pass 47 **rejected** it by owner instruction | Would stop a scroll view cropping a focused cell's shadow |
| `LazyHStack` | yes — tvOS 14.0 | `SwiftUICore.swiftinterface:3400-3405` | **zero** (the app uses `LazyVGrid` three times) | Would make a wide per-row canvas lazy instead of eager |
| `UIFocusGuide` | yes (UIKit, ios 9.0, not unavailable on tvOS) | `UIKit.framework/Headers/UIFocusGuide.h` — *"UIFocusGuides are UILayoutGuide subclasses that participate in the focus system… may be used to expose non-view areas as focusable"*, with `preferredFocusEnvironments` | **zero**, but the hosting pattern is proven three times in this app: `RemoteHoldDetector` (`RemoteHold.swift:89-96`), `RadarMapView` (`RadarScreen.swift:311-339`), `PlayerHost` (`PlayerHost.swift:48-82`) | The conventional tvOS answer to "give the engine somewhere to go at an edge". Installed through `UIViewRepresentable`, a guide at the row's right edge becomes a focusable non-view area that can redirect focus back into the grid — i.e. a Right press at the edge becomes observable with no competing move |
| A UIKit `UICollectionView` EPG through `UIViewRepresentable` | yes | same three hosting precedents | **zero** | The conventional tvOS grid, with full control of focus. Cost: the Guide stops being SwiftUI, and `RemoteHold` holds, the airing sheet, the collections overlay and `focusSoon` all have to be re-wired |
| `.focusSection()` around the grid | yes | already used at `GuideScreen.swift:457`, `ScreenShell.swift:63` | 13 uses | Changes where a directional move can land — which also changes today's **left**-edge behaviour (grid → rail) and is a risk to Pass 25's rail restore, measured at 27 of 27 correct |
| The design | — | — | — | **`design/` draws no scroll-right of any kind.** Frame 3a's cell area is a fixed `grid-template-columns:repeat(4, 1fr)` (`dc:216`, `dc:198`), and both Guide footers say forward-only paging: *"Starts at the current half hour · forward only"* (`dc:231`) and *"Forward only · keeps paging while the server has listings, 24 hours per request"* (`dc:353`). A scroll-right is an addition to the approved design, like the radar and Search before it |

---

## 6. Step 6 — interactions

### 6.1 The airing sheet on a cell that starts before the window — **unaffected, and that is exact**

The sheet is built from the cell's **own unclipped `Program`**, never from the drawn box.
`select(_:)` (**`:236-243`**) and `handleHold()` (**`:247-262`**) both construct
`AiringSelection(channel: cell.channel, program: cell.program, job: cell.job)` (`:241`, `:258`), and
`AiringSelection` (`AiringSheet.swift:32-46`) carries the whole `Program`. The sheet's `whenLine`
(`AiringSheet.swift:127-131`) formats `program.start`/`program.end`, so it shows the **true** times of
a clipped programme. `isAiringNow` (`:100-103`) tests the true range too.

**One new combination a one-slot scroll creates, and it is reachable only once the window moves by
less than 12 hours.** `select(_:)` plays live when `cell.program.start <= now && now <
cell.program.end` (**`:237-239`**), which is the owner's rule from `DECISIONS.md` 2026-09-06. With the
window at now, the airing cells are the now cells. With `+12h`, no cell can be airing now. **With the
window one slot forward, a cell clipped at the left edge can still be airing right now** — e.g. a
programme 07:00–08:30 with `windowStart = 08:00` while the clock reads 07:51 — so a click would play
it live rather than open the sheet. The existing rule applies and the behaviour is consistent; it is
simply a pairing nobody has seen. Open question 4.

### 6.2 Record/pass marks on clipped cells — **unaffected**

The marks join on identity, not on position: `job(channelId:programStart:)` (**`:165-167`**) matches
`$0.channelId == channelId && $0.program.start == programStart`, and `mark(for:)` (**`:193-198`**)
reads `Job.status` — green `.recording` on `"Recording"`, then `.scheduled` (manual) or `.pass` on
`"Queued"`/`"Conflict"`. `GuideCellItem.id` is `"\(channel.id)@\(program.start)"` (**`:59`**), the
true start. The writes behave the same: `recordNow(channelId:start:)` sends `program.start`
(`ServerWrites.swift:183-187`, called from `AiringSheet.swift:357`), which is what the server matches.
**Clipping is purely visual; nothing downstream of a cell knows the box was cut.**

`refreshSchedule()` (**`:182-188`**) re-reads the whole unfiltered `GET /api/schedule`, so a moved
window or a filtered row set changes nothing about it.

### 6.3 The collections filter and its persisted selection — **already survive a moved window**

- **Picking a collection keeps the window.** `pick(_:)` (**`:389-397`**) calls
  `model.reloadForCollection()`, which is `fetch(from: windowStart)` (**`:114-116`**) — *"Re-run the
  fetch at the window the Guide is already showing, so the pick does not move the clock."* So
  choosing a collection while scrolled forward would hold the scrolled window today.
- **Every fetch carries the filter by construction.** The filter is read from the shared model inside
  `fetch` (**`:126`**, `filter: collections.selectedId`), so `loadNow()`, `pageForward()`,
  `reloadForCollection()` and `snapToNow()` cannot diverge — a new window-advancing caller would
  inherit it for free.
- **The selection outlives the screen; the window does not.** `GuideCollectionsModel` is created by
  the app (`Marlin_DVR_TVApp.swift:32`), passed through `ContentView.swift:23` and
  `ScreenShell.swift:32` to `GuideScreen` (`ScreenShell.swift:98`), and persisted in the one
  `UserDefaults` key `"marlinGuideCollection"` (`GuideCollections.swift:33`, written at `:72-76`).
  `windowStart` lives on the `GuideModel` that `GuideScreen` owns in `@State` (`:217`, built `:231`).
- **A stale collection id still reverts silently**, `reconcile()` (`GuideCollections.swift:99-107`),
  because an unknown `filter` returns the **whole lineup** rather than an error — measured in Pass 72
  §5 at `channelCount: 91`. Unchanged by anything here, and **still unproven on the device** (it needs
  a collection deleted, which is a write).
- **`+12h` against a filtered grid hits `endOfListings` sooner** when the collection's channels have
  shorter guide data than the lineup, because `:137` is computed over the filtered rows. Pass 71 §6.2
  recorded this; it applies identically to a slot-at-a-time window.

### 6.4 The footer, the Now marker and the legend

**`legend`, `:495-511`:**

```swift
Text("●") … Text("Recording or set to record")                      // :497-500
Text("◆") … Text("Covered by a series pass")                        // :501-504
Spacer(minLength: 0)                                                 // :505
Text(model.isAtNow ? "Starts at the current half hour · forward only"
                   : "Menu snaps back to now · forward only, 24 hours per request")   // :506
```

- **The footer sentence is already window-aware**, keyed on `isAtNow` (`:93`). One slot right makes
  `isAtNow` false, so it would flip to *"Menu snaps back to now · forward only, 24 hours per
  request"* with no code change. Whether that second sentence is still the right words for a
  scrolled-by-half-an-hour window is Open question 2.
- **The legend's two marks are static** and say nothing about time. The design's own legend is
  `dc:227-231` (*"Recording now"* / *"Covered by a series pass"* / *"Starts at the current half hour ·
  forward only"*); the app says *"Recording or set to record"* for the green mark, which is correct
  because `.scheduled` and `.recording` share the colour (`:45-46`).
- **The Now marker disappears the moment the window leaves now**, because `slotLabel` gates it on
  `index == 0 && model.isAtNow` (**`:491`**). That is already what happens on `+12h`, and it is what
  frame 3c draws (no "now" at all). There is no other now indicator to keep in step.
- **`↩ Now` appears the moment the window leaves now** (`:431`), carrying
  `"↩ Now · \(TimeFormat.clock(Date()))"` (`:438`) — a clock sampled at render, not on a timer, so its
  minute is whatever it was when the header was last rebuilt. Already true today.

### 6.5 `ScreenShell`'s `.id(current)` — what the owner sees today after a rail trip while paged forward

**`ScreenShell.swift:57`** puts `.id(current)` on the content, where `current` is `screen ?? .home`
(`:39`) and the content is the `switch` at `:93-108` that builds
`GuideScreen(api:collections:onLeave:onPlay:)` at **`:98`**. Changing the `id` makes SwiftUI treat the
subtree as a different view and rebuild it from scratch.

**Destroyed on every rail visit:**

| What | Where | Consequence |
|---|---|---|
| `@State private var model: GuideModel` | `:217`, built `:231` | a brand-new model: **`windowStart` back to 0**, and `rows`, `jobs`, `fetchStart`, `fetchEnd`, `loaded`, `endOfListings`, `error`, `sheet` and `favouriteOverrides` all reset |
| `@FocusState private var focused` | `:218` | reset to `nil` |
| `@State private var lastCell` | `:219` | reset |
| `@State private var channelMenu` | `:220` | reset |
| `@State private var collectionsOpen` | `:221` | reset to `false` |
| the `.task` at `:345-348` | | **re-runs** — `await model.loadNow()`, which sets `windowStart = TimeFormat.currentHalfHour` (`:102`) and fetches |

**So: after a rail trip while paged forward, the owner comes back to the Guide at the current half
hour.** The paged window is gone; the **collection** survives, because its model is owned above the
shell.

**This is code-derived, not measured, and the distinction matters.** Pass 72's rail-round-trip test
(`GuideCollectionsUITests.testTheCollectionSurvivesATripToTheRail`, `:371-402`) asserts the button
label and the five rows and **never pages forward first**, so it proves the collection survives and
says nothing about the window. No run in `reports/` has pressed `+12h`, gone to the rail, and come
back. Open question 3.

**Three citation drifts found while tracing this, recorded and not fixed** (this pass writes one
file):

| Citation | Says | Actually |
|---|---|---|
| `GuideScreen.swift:21` | `ScreenShell.swift:55` for `.id(current)` | **`ScreenShell.swift:57`** |
| `GuideSearchScreen.swift:46`, `:301` | `ScreenShell.swift:51` for `.id(current)` | **`ScreenShell.swift:57`** (Pass 71 §2.5 already caught this at `:55`; it has moved again) |
| `AiringSheet.swift:76` | `Models.swift:170` for `Job.status` | **`Models.swift:288`** |
| `AiringSheet.swift:77` | `GuideScreen.swift:173-178` for the marks | **`GuideScreen.swift:193-198`** |
| `GuideSearchScreen.swift:170` | `GuideScreen.swift:145-147`, `:162-168` for the schedule pair | **`:182-188`** (`refreshSchedule`) and **`:165-167`** (`job`) |
| `GuideSearchScreen.swift:282` | `GuideScreen.swift:318-323` for the sheet-close focus | **`GuideScreen.swift:359-364`** |

`COLD-START.md:855` and the Pass 72 report §1 step 6 also cite `ScreenShell.swift:55`.

---

## 7. Step 7 — SWEEP or STANDALONE

**Only what the goal names is sorted. Nothing is added.**

| # | Piece of the goal | Sort | Why, in one line |
|---|---|---|---|
| **1** | **Right on the last visible cell advances the window one slot** | **SWEEP** | It is one behaviour made of two halves that cannot be judged apart — receiving the press (§5.2, unsolved and unmeasured) and advancing `windowStart` — and on the television it is a single gesture either working or not. |
| **2** | **The time strip and every row move together** | **SWEEP** | Not separable work at all: both are already derived from the one `windowStart` (`:94`, `:153-163`), so item 1 delivers this or it does not happen. |
| **3** | **It keeps moving as long as there are listings, fetching more as needed** | **STANDALONE** | It is the refetch rule in `fetch`/`fetchEnd`/`endOfListings` (`:109`, `:136-137`), provable on its own against a known window and a known horizon (§4.4) with no view consequence beyond more or fewer rows. |
| **4** | **Forward only, as today** | **SWEEP** | It is the *absence* of a backward step in item 1 — a property of the same press handler, not separate work. |
| **5** | **`↩ Now` returns to the current half hour** | **STANDALONE** | `snapToNow()` (`:118-122`) already does exactly this and is proven on the device (Pass 72 §3(d)); what needs checking is only that it still refetches correctly from an arbitrary slot offset rather than a 12-hour multiple. |
| **6** | **`+12h` stays** | **STANDALONE** | `pageForward()` (`:106-110`) is untouched by a slot step; the one thing to confirm is that a 12-hour jump from a slot-offset window still lands where the fetch cache expects (`:109`). |
| **7** | **Collection filtering keeps working while scrolled** | **STANDALONE** | §6.3: the filter is read inside `fetch` (`:126`) and `reloadForCollection()` already re-fetches at the current `windowStart` (`:114-116`), so this is a verification against the owner's live collection, not a build. |

**SWEEP:** items **1, 2, 4** — one press, one window, one thing to watch on the television.
**STANDALONE:** items **3, 5, 6, 7** — the refetch rule, and three existing behaviours to re-prove
against a window that can now sit at any slot.

---

## 8. Open questions

**Raised, not answered, and none acted on. Each carries the evidence and what breaks without an
answer.**

1. **Does tvOS deliver a directional press to the app when that press moves no focus?** This is the
   single thing mechanism (b) rests on. The app has no `.onMoveCommand` and no arrow press observer
   outside the Player (§1); `RemoteHold` is armed for `.select` only
   (`RemoteHold.swift:124`); and Pass 29 measured that a press claimed in the responder chain can
   still be acted on by another party and recorded that there is no public API to decline it
   (`PlayerHost.swift:23-31`). **Evidence:** none either way in `reports/`. **What breaks without an
   answer:** the whole of item 1 — there is no second mechanism for Right at the edge except a
   focusable affordance (§5.3) or `UIFocusGuide`, both of which change what is on screen.
2. **What should the footer say while the window is a few slots forward?** It flips to *"Menu snaps
   back to now · forward only, 24 hours per request"* the moment `isAtNow` is false (`:506`, `:93`),
   which reads oddly at +30 minutes, and the design has only the two sentences (`dc:231`, `dc:353`).
   **What breaks without an answer:** a true but misleading sentence the owner will read first.
3. **Should a scrolled window survive a trip to the rail?** Today it cannot: `.id(current)` at
   `ScreenShell.swift:57` destroys the `GuideModel` and `.task` calls `loadNow()` (§6.5). The
   collection survives because its model is above the shell (`Marlin_DVR_TVApp.swift:32`); the window
   would need the same treatment. **Evidence:** code-derived; no run has paged forward and then taken
   the rail trip. **What breaks without an answer:** the owner scrolls right, glances at Radio, and
   comes back to now with no warning.
4. **A cell clipped at the left edge can be airing right now once the window moves by less than 12
   hours, and a click on it plays live** (§6.1, `:237-239`). The 2026-09-06 rule says a programme
   airing now plays immediately, so this is the rule working — but it is a pairing nobody has seen.
   **What breaks without an answer:** a click the owner expects to open the sheet starts playback.
5. **What granularity is "one slot"?** The goal says "moves the window forward in time" without a
   step. 1800 s is the server's own grid (`guide.go:653-670`, `Formatting.swift:65`) and the app's
   `slotSeconds` (`:71`), and anything finer breaks `isMidnight` (`Formatting.swift:59-62`) and the
   strip's whole-slot labels. **What breaks without an answer:** the press count to the horizon — 663
   at one slot (§4.4) — and whether a held Right is usable at all.
6. **Should the grid scroll at all once `endOfListings` is true?** The pill vanishes but the rows stay
   (91 rows of blank programme area, §4.3), and a press-based scroll with no guard would keep
   advancing into nothing. `pageForward()` guards at `:107`; a new advance would need the same guard.
   **What breaks without an answer:** the owner scrolls past Sat 2026-09-26 05:00 into an endless
   empty grid.
7. **Does the strip's 3·*i* pt drift against the cells matter?** (§2.1). Pre-existing, 9 pt at the
   right-hand column, invisible today and more visible if the window steps. **What breaks without an
   answer:** nothing functional; it is a look the owner may or may not accept.
8. **A focused cell at the window edge has its ambient shadow clipped by the vertical `ScrollView`**
   (`:288`, `:641`), and `.scrollClipDisabled()` was explicitly rejected in Pass 47 by owner
   instruction. Already true today; a scroll-right focuses the edge cell constantly. **What breaks
   without an answer:** a focus treatment that looks cut on the one cell the owner is always on.
9. **Is the baseline — Right walks from one programme cell to the next inside a row — actually true on
   this device?** §2.3: no harness has ever pressed it. **What breaks without an answer:** a build
   that assumes the press only needs intercepting *at the edge* when it may not be reaching cells in
   the middle either.
10. **Three standing items unchanged by this pass, restated so they are not mistaken for drift:** the
    collections overlay still does not scroll and *"Collections unavailable"* is still unproven
    (Pass 72 open questions 1 and 2); the **stale-id revert is still unproven** and needs a
    collection deleted; and whether a collection should reach `GET /api/guide/now` and
    `GET /api/channels` is still the owner's call (Pass 71 open question 8). `icon-source/` is still
    32 untracked entries (`DECISIONS.md`, 2026-09-08).

---

## 9. The three things I am least sure of

1. **That Right at the last cell does nothing today.** I traced it three ways — no cell exists beyond
   the window (`:157`), no cell is offset outside its row (`:62-63`), no focus section or focusable
   view sits to the right — and **I did not watch it.** Worse, §2.3 found that no device run in
   `reports/` has pressed Right inside a Guide row *at all*, so I cannot even point at the adjacent
   case. If tvOS does something I have not predicted at that edge — wraps, crosses into another row,
   or scrolls the vertical `ScrollView` — the premise of mechanism (b) changes. One device probe with
   a focus dump after one Right press on the last cell settles it, and that probe is the cheapest
   thing in this report.
2. **That the coverage horizon is Sat 2026-09-26 05:00.** `coverageUntil` carries a weekday and a
   clock and **no date** (`guide.go:589`), so I dated it by elimination from two further GETs
   (§4.4) — a programme ending Sat Sep 19 08:00 rules Sep 19 out, and an empty Sep 26 07:30 → Sep 27
   07:30 window bounds it above. The deduction is sound but it is a deduction, and the guide had been
   refreshed 45 minutes before the reading, so the horizon moves. The press-count arithmetic that
   follows from it — 28 `+12h` presses, 663 one-slot presses — is only as good as that date.
3. **That the re-render cost of stepping the window is acceptable.** I can show there is no network
   for 44 presses and that only one integer changes (§5.2), but "recompute `cells(for:)` for 91 rows
   and re-lay every `GuideRowView`" is a **claim about rendering I have not timed on the device**. The
   one adjacent measurement I have points the wrong way: Pass 72 found the realised grid already
   heavy enough that a full accessibility walk took 585+ × ~0.8 s and killed two harness runs. That
   is the element count, not the frame time, and I am inferring from one to the other.

---

## 10. SCOPE CHECK — every path touched, mapped to its step

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | **read only**, in full | required reading |
| `reports/2026-09-11-pass71-guide-collections-recon.md`, `reports/2026-09-12-pass72-guide-collections.md` | **read only**, in full | required reading |
| the other 71 files in `reports/` | **read only**, searched by pattern | 1, 2.3 |
| `Marlin DVR TV/*.swift` (49) | **read only**, in full | 1, 2, 3, 5, 6 |
| `Marlin DVR TVUITests/*.swift` (14) | **read only**, in full | 1, 2.3 |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **read only**, in full | 1, 5 |
| `design/` (14 files) | **read only, never written** | 1, 2, 5 |
| `~/Xcode/marlin-dvr-reference` | **`git rev-parse`, `grep`, `sed` only** — no fetch, no checkout, no edit, nothing run | 4 |
| `AppleTVOS26.5.sdk` SwiftUI / SwiftUICore / UIKit interfaces | **read only** | 5 |
| `http://192.168.1.250:8090/` | **three GET requests** — `/api/guide?start=1790423511&slots=48`, `/api/guide/stats`, `/api/guide?start=1789801200&slots=4`. **No POST, PUT or DELETE. `GET /api/settings` was not read.** | 4, VERIFY |
| the session scratchpad | two response bodies saved outside the repo | 4 |
| `reports/2026-09-12-pass75-guide-scroll-recon.md` | **created — the only write** | 8, DELIVERABLE |

**Not touched:** every Swift source, the Xcode project, `Info.plist`, the entitlements file, every
build setting, the asset catalog, `build/`, `icon-source/`, `design/` (read, never written), every
earlier report, and every other folder under `~/Xcode`. **No build, no test, no device run, no
install, no dependency.** Unraid `192.168.1.250` as a host, marlinpc `192.168.1.245`, the HDHomeRun
`192.168.1.105` and the UNAS4Pro share were not touched — the only traffic was the three read-only
GETs to the DVR's HTTP API.

**No credential, token, device id or client id appears in this report.**

---

## 11. Git

`git status` before this pass read `?? icon-source/` and nothing else. **The only change this pass
makes to the working tree is this file**, so `git status` afterwards reads `?? icon-source/` plus this
report — which is then staged by name and committed on its own, and pushed. The three SHAs
(`git rev-parse main`, `git rev-parse origin/main`, `git ls-remote origin main`) are verified after a
fresh `git fetch origin` and reported in this pass's response, because a commit cannot contain its own
hash (`DECISIONS.md` 2026-09-09 (Pass 60) rule (b), with Pass 68's ordering rule putting the report
**inside** the commit).

**Nothing forced. No history rewritten. No branch other than `main`.**
