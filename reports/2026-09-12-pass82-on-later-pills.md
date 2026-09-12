# Pass 82 — On Later's three pills

**Date:** 2026-09-12
**Base commit:** `54b2335` (Pass 81, the On Later recon).
**Result: built, proven on Home Theater, committed locally, NOT pushed.** On Later opens on
**On Today**, a press moves to **On This Week**, another to **Premieres**, and Select on a card
opens the airing sheet with its controls live. One device run, `OnLaterPillsUITests`,
**TEST SUCCEEDED in 37.6 s, 0 failures**.

**Server traffic.** Every request this pass made by hand was a **GET**: `/api/collections`,
`/api/schedule`, `/export/guide.xml`, `/export/{source}/guide.xml`, `/api/guide/search?title=` and a
number of `/api/guide?…` reads. The app, driven on the device, sent **GET** `/api/collections`,
`/api/guide`, `/api/schedule` and `/api/guide/search`, plus the `POST /api/clients/{id}/ping` it has
sent on every launch since sweep 1 (`ClientSession.swift:62-81`). **That ping is the only non-GET
request in the whole pass.** **Nothing was written to `/api/collections`**, the lineup, the library
or the schedule; no collection was created, renamed, reordered, emptied or deleted, and no recording
or pass was booked, cancelled or stopped. `~/Xcode/marlin-dvr-reference` was read with `grep`,
`sed` and `git rev-parse` only. `design/` was not written. Unraid `192.168.1.250` as a host,
marlinpc, the HDHomeRun and the UNAS4Pro share were not touched.

**No credential, token, device id or client id appears in this report.**

---

## 1. Step 1 — the route, and what it costs

### 1.1 The choice: `GET /api/guide?filter=<collection id>&slots=48` — **seven requests**

**Seven requests per collection that has at least one member; seven in total on the owner's data
today.** A collection with no members is skipped outright rather than spending seven requests on an
empty envelope, which is why the count is seven and not fourteen — he has two collections, "Local"
with five members and "Test" with none.

**Seven is the floor for a week on this route and cannot be beaten.** `slots` is clamped to 48 and
falls back to 13 outside 1…48 (`guide.go:652-655`), so one request carries at most 24 hours.

Measured, this sitting: **7 requests, 75,141 bytes in total**, each answering in 2–3 ms on this
network. The whole week arrives in well under a tenth of a second.

### 1.2 Every candidate, and why the others lost

| Route | Complete? | Carries the premiere rule's fields? | Verdict |
|---|---|---|---|
| **`GET /api/guide?filter=&slots=48`** | **no — 1.4 % dropped, §1.3** | **yes** — the whole `Program` per block | **chosen** |
| `GET /api/guide/later` | n/a | yes | **rejected**: no parameters at all, 24-item cap, "notable" only, series-deduped across both sections (Pass 81 §4.1) |
| `GET /api/guide/find?q=` | n/a | **no** — its row type carries none of the flags (`guide.go:862-871`) | rejected |
| `GET /api/guide/search?title=` | **yes** — walks the stored guide directly | yes | rejected as a *listing* route: it needs a title, so it cannot sweep a range |
| `GET /export/guide.xml` | **yes** | **no** — drops `premiere`, `seriesId`, `rating`, `originalAirDate` | **rejected, §1.4** |

### 1.3 What `/api/guide` costs, measured rather than assumed

The block builder rounds to whole half hours and skips listings that end inside a slot already
consumed (`guide.go:679`, `:699`, `:705`). The marlin-dvr project measured that at about 3 % of all
listings. **For these five channels over these seven days it is 2 airings of 140 — 1.4 %** —
compared directly against the complete export for the same channels and the same window:

```
/api/guide  (7 filtered fetches, 75 KB) : 138 airings
/export/*/guide.xml (2 fetches, 361 KB) : 140 airings

in the export but NOT in /api/guide: 2        in /api/guide but not in the export: 0
    marlin-cast:9287  Mon 23:15  Monday Night Postgame    dur=15m
    marlin-cast:9287  Sat 19:00  College Football         dur=180m

per channel   2.1 api=2 export=2 · 8.1 api=2 export=2 · 11.1 api=2 export=2
              13.1 api=2 export=2 · 50007 api=130 export=132
```

**Both losses are real and one of them is a three-hour football game.** The four antenna channels
lost nothing. This is **open question 1**.

### 1.4 Why the complete route was rejected, on the owner's own terms

`/export/guide.xml` is the one genuinely complete route for a range — one request, the whole stored
guide, no block builder. It loses on three counts, all measured:

- **It drops the premiere flag.** `handleExportXMLTV` emits `<new/>` and `<live/>` and nothing else
  (`export.go:105-110`); `premiere`, `finale`, `seriesId`, `rating` and `originalAirDate` never
  leave the server. **That would make the first clause of the owner's own premiere rule permanently
  unevaluable**, and would strip `seriesId`, which the airing sheet's pass matching needs
  (`AiringSheet.swift:328-330`).
- **It is 16,525,695 bytes** for the whole 91-channel lineup — measured — against 75 KB for the
  seven filtered reads. Per source it is 29,651 B for the antenna and 331,404 B for Marlin Cast,
  and it scales with the source's channel count rather than the collection's.
- **It is XMLTV**, so it would need a new parser and a new type in the app target.

### 1.5 The week is fetched once per visit

The three pills filter what is already in hand. **A pill press makes no request** — proven on the
device, where the two presses were instant against a 7.6-second first load.

---

## 2. Step 2 — what was built

`Marlin DVR TV/OnLaterScreen.swift`, rewritten: **477 insertions, 79 deletions**, 145 lines to 540.

### 2.1 The layout, taken from On Now

| Piece | On Later | Taken from |
|---|---|---|
| header | `ScreenHeader("On Later", subtitle:)` + the trailing clock | unchanged from the old screen; `dc:449` |
| **pill row** | `HStack(spacing: 14)` of `Button` + `PillLabel` + `.focused`, in one `.focusSection()` | **`OnNowScreen.swift:197-211`, line for line** |
| **grid** | `ScrollView` → `LazyVGrid`, **3 flexible columns, 28 across / 30 down** | **`OnNowScreen.swift:130`, `:143`** |
| card | `LaterCard` — art, channel line, title, episode line, day and time, the ● Scheduled capsule | `OnNowCard`'s shape (`OnNowScreen.swift:243-276`) |

**`OnNowScreen.swift` was not modified.** It is not in this pass's diff. The shared pieces are used
where they exist — `PillLabel` (`ScreenChrome.swift:112-134`), `BareButtonStyle`
(`RailView.swift:27-31`), `ScreenHeader`, `ServerImage`, `ArtPlaceholder`, `focusTreatment`,
`LoadingLine`, `ErrorLine`, `focusSoon` — and the card itself is new because its content differs:
programme art instead of a channel logo, a day-and-time line instead of "ends 3:04 PM", and **no
progress bar**, because every airing here is in the future and there is no progress to draw.

### 2.2 The three pills

`LaterPill` (`:32-44`) is exactly three cases with exactly the owner's labels. **No channel-filter
pill exists anywhere in the file** — asserted on the device, which checked that no "Favorites" or
"HD" button is on the screen.

**The selection does not persist, and that is the absence of code rather than a branch.**
`ScreenShell.swift:57` puts `.id(current)` on the content, so this screen and its `@State` model are
destroyed on every rail visit and `pill` returns to `.today` by construction. **No `UserDefaults`
key was added**; the app still writes the same four it has since Pass 72.

### 2.3 The rules, as code

```swift
// :136-147 — Premieres, the owner's rule, the flag first so it starts working by itself
nonisolated static func isPremiere(_ p: Program) -> Bool {
    if p.premiere == true { return true }
    if p.new == true && p.episode == 1 { return true }
    if p.season == 1 && p.episode == 1 { return true }
    for text in [p.title, p.episodeTitle, p.desc] {
        if let text, text.range(of: "premiere", options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }
    }
    return false
}

// :151-158 — start, then channel number as a NUMBER, the way the server compares it
//            (numberKey is a ParseFloat, sources.go:296-302)
```

**On Today** is `now < start < midnight`, where midnight is
`calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))` — **not** `now + 86400`,
so the boundary is right across a DST change. **On This Week** is `now < start <= fetchStart + 7 days`,
where `fetchStart` is the current half hour because that is what the server truncates `start` to
anyway (`guide.go:657-664`) and it makes the seven windows tile with no overlap and no gap. **The
near edge is exact; the far edge can be up to 30 minutes short**, seven days out. Open question 4.

### 2.4 The DRM rule — already in force, and a gap closed

**Nothing new was written for it.** Every guide response goes through `.playable` at
`ChannelFilter.swift:67`, so a DRM collection member simply yields no rows. **This closes the gap
Pass 81 §6.2 recorded**: On Later was the one list in the app with no DRM filter, because
`GET /api/guide/later` carries no `drm` field and its item type has no channel to test
(`guide.go:758-768`). Reading `/api/guide` instead means the rule applies for free.

Unexercised today and stated as such: the owner's five DRM channels are all hidden, so
`channels(false)` drops them before either route sees them (measured in Pass 81 §V5).

### 2.5 Select, and the sheet

`open(_:)` (`:299-325`) reconstitutes the airing the way Search does (`GuideSearchScreen.swift:140-168`):

1. **`GET /api/guide/search?title=`**, then the match whose `channelId` and `program.start` are the
   card's. **The `/api/guide` row the card was built from is never used for the sheet**, which is
   the owner's instruction.
2. **The channel is the one the card already holds** — no `GET /api/channels`. Search needs that read
   because a `FindRow` carries no channel at all; a guide row **embeds the server's own
   `MergedChannel`** (`Models.swift:119-132`), the identical type from the identical record. **Two
   reads where Search makes three.** Open question 3.
3. **`GET /api/schedule`**, for the job the sheet's controls turn on and for `onScheduleChanged`.

Measured cost of step 1 on real titles from these channels, which also closes Pass 63 §8.3 for this
data: `SportsCenter` → 113 matches, 44,643 B, 0.033 s; `College Football` → 93 matches, 59,402 B,
0.036 s.

### 2.6 The empty states

"No collection channels" when the declared union is empty; "Nothing on <pill> for your collections"
when the list is. **Neither is focusable**, deliberately: the pill row above is always drawn and
always focusable, so focus stays on the pills exactly as the owner asked and Menu always reaches
`.onExitCommand` — the stranded-remote failure `TrashManageView.swift:58-62` and
`RadarScreen.swift:202-203` both record from the device.

---

## 3. Files touched, by step

| File | Step | What |
|---|---|---|
| `Marlin DVR TV/OnLaterScreen.swift` | **2** | rewritten — the pills, the grid, the card, the rules, the sheet |
| `Marlin DVR TV/Models.swift` | **1** | `ChannelCollection` gained `channelIds` (**+9 −2**) |
| `Marlin DVR TV/ScreenShell.swift` | **2** | one line — `onPlay` passed to On Later (**+3 −1**) |
| `Marlin DVR TVUITests/OnLaterPillsUITests.swift` | VERIFY | **new** — test target only, no app-target test code |
| `COLD-START.md`, `DECISIONS.md` | **4** | **additions only: +71 −0 and +119 −0** |
| `reports/2026-09-12-pass82-on-later-pills.md`, `reports/assets/pass82/` | deliverable | this report and its six screenshots |

**Three app files, and the two beyond `OnLaterScreen.swift` are named here rather than buried:**

- **`Models.swift`** — `channelIds` is what step 1 strictly needs. It is what the union turns on
  (and therefore "No collection channels"), and it is what lets an empty collection be skipped
  instead of costing seven requests — halving the count today from fourteen to seven, which is step
  1's own criterion. Always present and never null (`collections.go:74-77`), so decoded strictly.
- **`ScreenShell.swift`** — without `onPlay`, the sheet's "Watch live" would close the sheet and do
  nothing, and the owner's decision says the sheet opens "with every control live". **Open question
  2.**

**Step 3 — the Home On Later tile is unchanged**, as instructed. `HomeView.swift` is not in the
diff; the tile still reads `GET /api/schedule` and says "N upcoming" (bookings, not airings).

**Not touched:** the Xcode project file (both targets are filesystem-synchronised groups),
`Info.plist`, the entitlements file, every build setting, the asset catalog, `design/`,
`icon-source/`, every earlier report, `OnNowScreen.swift` and every other screen. **No new
dependency, no hardening, no refactor, no config change, and no test-only code in the app target.**

**Build warnings: two, unchanged from HEAD's two.** Measured by a clean build of each tree —
`GuideScreen.swift:635` and `PlayerModel.swift:325` before and after. One new warning did appear
mid-pass (`call to main actor-isolated static method 'before' in a synchronous nonisolated context`,
from passing `Self.before` to `sorted(by:)`) and was fixed by marking the two pure statics
`nonisolated`, not by suppressing it.

---

## 4. VERIFY — the device run, and what is traced

**One run on Home Theater** (Apple TV 4K, tvOS 26.6), real Siri Remote, `OnLaterPillsUITests`,
**TEST SUCCEEDED, 37.636 s, 0 failures.** Screenshots in `reports/assets/pass82/`.

### 4.1 RUN — what the television did

| # | What | Evidence |
|---|---|---|
| 1 | **Opens on On Today, collection channels only** | `82a-on-later-opens-on-on-today.jpg` — header `On Later · 10 airings · 5 collection channels`, the three pills with **On Today** active, a 3-column grid. Focus settled on `["2.1 · WMAR-HD, College Football, Ohio State at Texas, Today 7:30 – 11:00 PM"]` |
| 2 | **Press to On This Week** | `82b-on-this-week.jpg` — `138 airings · 5 collection channels`, focus `["On This Week"]` |
| 3 | **Press to Premieres** | `82c-premieres.jpg` — `0 airings · 5 collection channels`, **"Nothing on Premieres for your collections"**, focus `["Premieres"]` |
| 4 | **Select a card, the sheet opens** | `82e-the-airing-sheet.jpg` — NEW chip, `2.1 · WMAR-HD · HD`, *College Football* / *Ohio State at Texas* / `Today 7:30 – 11:00 PM`, the full description, **"Record this airing"** focused and **"Record the series"** beside it |
| 5 | **Menu closes the sheet and focus comes back** | `82f-back-on-the-grid.jpg`, focus `["2.1 · WMAR-HD, College Football, Ohio State at Texas, Today 7:30 – 11:00 PM"]` — **byte-identical to the label before the sheet opened** |

**Settled focus is shown at every step** and was never empty.

**Focus stayed on the pill row across both pill presses**, asserted positively each time — which is
the owner's rule for the empty states and is what `82c` photographs.

### 4.2 The counts, re-verified by hand against the fetched data

The same seven requests were made from the Mac at the same sitting (19:21:16, the run at 19:20:08):

| | the screen said | the fetched data says |
|---|---|---|
| **On Today** | **10** | **10** |
| **On This Week** | **138** | **138** |
| **Premieres** | **0** | **0** |
| **collection channels** | **5** | **5** (the union of `channelIds`) |
| first card | `2.1 · WMAR-HD, College Football, Ohio State at Texas, Today 7:30 – 11:00 PM` | `2.1 · WMAR-HD \| College Football \| Ohio State at Texas \| 19:30 – 11:00 PM` |
| channels drawn | 2.1, 8.1, 11.1, 13.1, 50007 | `['2.1', '8.1', '11.1', '13.1', '50007']` |

**Counted by hand off `82a`:** nine cards fully drawn and a tenth part-scrolled at the bottom —
**ten**, the number the header states. **The sort is visible and correct**: 7:30 PM on 2.1, 8.1,
11.1, 13.1, then 10:00 and 10:15 PM on 50007, then 11:00 PM on 2.1, 8.1, 11.1, 13.1. Channel
**11.1 sorts after 8.1**, which is the numeric comparison working — a string sort would have put it
first.

**The Premieres pill is empty, and that is Pass 81's finding on a television.** `premiere` is true
on nothing this server holds; the three derived clauses select nothing on these five channels this
week either.

### 4.3 TRACED, not run

Everything below is code-traced and is stated as traced:

- **"No collection channels"** — needs every collection to be empty, or none to exist. The owner has
  one with five members. Not seen.
- **The ● Scheduled capsule** — nothing is booked on these five channels this week
  (`/api/schedule` count 5, none on a collection channel), so no card drew one. Traced through
  `isScheduled(_:)` (`:290-293`).
- **The sheet's other three controls** — "Edit series pass", "Watch live" and "Stop recording". Only
  the unbooked case was on screen. "Watch live" is drawn only while the airing is on
  (`AiringSheet.swift:267`) and On Later lists only future airings, so it appears solely if the
  sheet is left open across the start time.
- **A collection with a DRM or hidden member**, and **a channel in two collections at once** (the
  de-duplication at `:215-218`). Neither exists in the owner's data.
- **A partially failed week** — the branch that reports only when *every* request fails (`:227-231`).
- **The owner tests the rest**, which is the standing rule of 2026-09-12.

### 4.4 One failure, diagnosed rather than retried

**The first device run failed, and the app was not at fault.** The harness's `focusPill` helper only
ever pressed **Right**, so coming back from Premieres — the last pill — to On Today it pressed into
the right-hand edge six times and reported `could not put focus on the On Today pill;
focused=["Premieres"]`.

**Everything the app had done up to that point was already correct in that run**, and the log shows
it: `ON THIS WEEK subtitle=138 airings · 5 collection channels focused=["On This Week"]`, then
`PREMIERES subtitle=0 airings · 5 collection channels focused=["Premieres"]` with its empty line
drawn. The fix was to make the helper walk in whichever direction the target pill lies, and the
reason is recorded in the helper's own comment so nobody rediscovers it.

---

## 5. Open questions

Raised, not acted on.

1. **`/api/guide` drops 1.4 % of these listings, and the owner's brief leans against it.** Measured
   at 2 airings of 140 over seven days (§1.3) — a 15-minute *Monday Night Postgame* and a three-hour
   *College Football*, both on ESPN. The one complete route, `/export/guide.xml`, cannot carry the
   premiere flag or `seriesId` (§1.4), so it cannot implement the owner's own premiere rule. **Is
   1.4 % acceptable, or should this be raised with the marlin-dvr project as a server change** — a
   complete JSON listing route for a channel over a range?
2. **`ScreenShell.swift` gained a line.** One line, so the sheet's "Watch live" has a Player to hand
   the channel to. The constraint named `OnLaterScreen.swift` and what step 1 strictly needs; the
   owner's decision said the sheet opens "with every control live". **The alternative is what the
   Search screen does — close the sheet and play nothing.** Which did he mean?
3. **The sheet reconstitution makes two reads, not Search's three.** The channel is reused from the
   guide row rather than re-read from `/api/channels`, because a guide row already embeds the
   server's own `MergedChannel` (§2.5). That is reading the instruction for its substance rather
   than literally. Overrule it and the third read goes back in.
4. **"On This Week" can fall up to 30 minutes short at its far edge.** The seven fetch windows tile
   from the current half hour, so the week ends at `currentHalfHour + 7 days` rather than
   `now + 7 days` (§2.3). Closing it exactly costs an eighth request for at most half an hour of
   listings seven days out. Worth it?
5. **`GET /api/guide/later` is now uncalled, and `api.later()` (`ChannelFilter.swift:82-84`),
   `LaterResponse`, `LaterSection` and `LaterItem` (`Models.swift:150-169`) are dead.** Removing
   them is a change to two files this pass does not name, so they were left. Delete them next pass?
6. **"No collection channels" versus a union that is non-empty but undrawable.** If every member of
   every collection were DRM or hidden, the union would be non-empty and the screen would say
   "Nothing on On Today for your collections" rather than "No collection channels". The subtitle
   would then say "5 collection channels" over an empty grid. Unreachable in the owner's data; which
   sentence did he want?
7. **The card has no live/new/premiere tags.** `TagChip` is right there and On Now's card draws
   New/Live/Premiere/Finale from the same fields. The owner listed the card's contents exactly and
   tags were not among them, so none were added.
8. **`icon-source/` is still 32 untracked entries**, the owner's undecided call. Restated so it is
   not mistaken for drift.

---

## 6. The three things I am least sure of

1. **That seven requests per non-empty collection is the shape he wants.** It is the fewest for
   `/api/guide` and it is tiny today — 7 requests, 75 KB, under a tenth of a second. But it
   multiplies by the number of collections, so five non-empty collections would be 35 requests. The
   alternative is seven unfiltered requests whatever the collection count, filtered client-side by
   the union — constant in requests, but **8.4 MB** measured, decoded on an Apple TV on every visit.
   I chose bytes over a request-count that only bites at a collection count he does not have, and
   step 1's stated criterion was "fewest requests". **This is the judgement in the pass most likely
   to be wrong.**
2. **That the empty Premieres pill will read as correct rather than as broken.** It is correct — it
   is Pass 81's measurement, re-measured today, and the screen says so in words. But the owner
   asked for a Premieres pill and what he will see is an empty one, every time, until either his
   provider starts emitting `<premiere>` or an airing's text happens to contain the word. The rule
   is his own and I built it exactly; whether an always-empty pill is what he pictured is not
   something I can settle from here.
3. **That the focus behaviour holds in the cases the one run did not reach.** The plain
   `@FocusState` assignment after the sheet closes worked — focus came back to a byte-identical
   label — which is the Guide's outcome rather than the Search screen's, and that screen needed a
   subtree rebuild measured twice. What was not watched: closing the sheet after a **write** has
   changed the card underneath, closing it from a card deep in a 138-card scroll, and the
   `firstCellID`-equivalent fallback when the grid is empty. The empty case falls back to the
   On Today pill and that pill is certainly drawn, but the assignment itself has not been seen with
   an empty grid.

---

## 7. Git

One commit on `main`, on top of `54b2335`: the code, the harness, the six screenshots, the notebook
and this report together, per the Pass 68 rule that a pass's report goes in its own commit.

**The commit is local and unpushed.** The owner tests it on Home Theater first; that is the standing
separate push gate. Nothing forced, no history rewritten, no branch other than `main`.
