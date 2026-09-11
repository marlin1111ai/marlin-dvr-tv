# Pass 63 — the guide search screen — 2026-09-11

**Result: built, wired and driven on Home Theater with the real Siri Remote.** Typing on the
on-screen keyboard searches the guide, the results list draws what `GET /api/guide/find` returns,
clicking one reconstitutes the airing from `GET /api/guide/search` and opens `AiringSheet` with
every one of its controls live, Menu puts the remote back on the row it came from, and a query and
its results survive a trip to the rail and back. Three harness tests, **0 failures, 176.8 s** on the
final build, plus the two step-1 probes, **0 failures, 55.1 s**.

**Nothing was pushed.** The owner tests this on Home Theater first.

**One defect was found and fixed during the pass, and it was found because the harness looked for
it**: after the sheet closed, nothing on the screen had focus at all. It is diagnosed with device
evidence in §5.3 and the fix is a subtree rebuild, not a longer delay.

**Citation keys.**
`File.swift:NN` = line NN of that file in this repo **as this pass leaves it**.
`guide.go:NN`, `sources.go:NN`, `main.go:NN` = the read-only reference clone
`~/Xcode/marlin-dvr-reference` at **`origin/main` = `095de815adac50eaf77dcaa7cdb50115942c46c5`** —
the same ref Pass 62 read — reached with `git show origin/main:<path>` only. Nothing was checked
out, fetched, edited or run.
`dc:NN` = line NN of `design/Marlin DVR TV.dc.html` (read only, never written).
Screenshots are `reports/assets/pass63/`.
Base commit for every line number: `49a5672` (Pass 61).

---

## 1. Step 1 — the two things that had to be proved on the device first

Both were run **before a line of the search screen was written**, with a temporary probe screen
(`SearchProbeScreen.swift`) reachable only under `MARLIN_SEARCH_PROBE=1` in place of On Later, plus
a temporary harness (`SearchProbeUITests.swift`). **Both files and the two-line hook in
`ScreenShell.swift` were fully reverted afterwards** — `git checkout` on the shell, `rm` on the two
new files, and `git diff` on `ScreenShell.swift` reports nothing. They are disclosed here and
appear in no commit, the same way Pass 42 and Pass 22 handled their disclosed diagnostics.

### 1.1 A SwiftUI `TextField` on tvOS summons the keyboard and returns typed text — YES

`Marlin DVR TVUITests/SearchProbeUITests/testTextFieldSummonsTheKeyboardAndReturnsTypedText`,
**passed, 26.5 s**, on the physical Apple TV with `XCUIRemote`.

| Moment | `keyboards` | `keys` | `textFields` | What the probe drew |
|---|---|---|---|---|
| screen open, field focused | **0** | 0 | 1 | `PROBE typed:«» chars=0 submitted:«—»` |
| after one Select on the field | **1** | **52** | 1 | unchanged |
| after `typeText("news")` | 1 | 52 | 1 | **`PROBE typed:«news» chars=4`** |
| after Menu | **0** | 0 | 1 | `PROBE typed:«news» chars=4` — the value survives |

Screenshots `01-probe-open.jpg` … `04-after-dismissing-the-keyboard.jpg`.

Three facts came out of this that shaped the build, and they are measurements, not readings of a
header:

1. **The tvOS keyboard is a full-screen takeover.** `03-after-typing.jpg` is the whole television:
   the app is blurred out behind it, the placeholder becomes the title, the field's content is
   echoed at the top, and there is a single row of letters with a `done` button. **Nothing of the
   app's own layout is visible while typing**, which settles what a search screen should do with
   its results — there is no point drawing them under a keyboard nobody can see past.
2. **The binding updates live, letter by letter, while the keyboard is up.** The assertion that
   read `chars=4` ran **before** the Menu press that dismissed the keyboard (harness t=23.25 s,
   Menu at t=23.26 s). So a debounced search off the binding has its answer ready by the time the
   keyboard goes away.
3. **`.onSubmit` was never observed firing** — the probe's `submitted:` stayed at its `—` sentinel.
   The probe dismissed with Menu rather than with the keyboard's own `done`, so this is
   *unobserved*, not *disproved*. Either way the built screen does not rely on it.

### 1.2 `AiringSheet` opens and closes correctly from a screen other than the Guide — YES

`…/testAiringSheetOpensAndClosesFromANonGuideScreen`, **passed, 28.6 s**.

The probe fetched a real channel and a real future airing from `GET /api/guide` and handed them to
`AiringSheet` unchanged. Screenshot `05-sheet-open-from-the-probe.jpg`, and the element dump:

```
TEXTDUMP[sheet-open] 4: 2.1 · WMAR-HD · HD
TEXTDUMP[sheet-open] 5: The Drew Barrymore Show
TEXTDUMP[sheet-open] 6: Miles Teller; Elizabeth Olsen · S06E111
TEXTDUMP[sheet-open] 7: Today 4:00 – 4:30 PM
TEXTDUMP[sheet-open] 8: Miles Teller and Elizabeth Olsen tell about their new movie, "Eternity."
BTNDUMP[sheet-open] 11: Record this airing
BTNDUMP[sheet-open] 12: Record the series
PROBE focused buttons while the sheet is up: ["Record this airing"]
```

and after Menu (`06-after-menu-closes-the-sheet.jpg`):

```
BTNDUMP[sheet-closed]  — "Record this airing" and "Record the series" both gone
TEXTDUMP[sheet-closed] — the probe screen's own strings still there
PROBE openButton.hasFocus after close=true
```

So: it opens, it draws its own art fallback, its first control takes focus, Menu closes **the sheet
and not the screen**, and focus returns to the control it was opened from. Neither probe made a
server write.

---

## 2. Step 2 — the decoder for `GET /api/guide/search`

### 2.1 The shape decoded against, and where it was read

Read from the reference clone at `origin/main` `095de81` with `git show`, in
`cmd/marlin-dvr/guide.go`, handler `handleGuideSearch` at **`guide.go:816-844`**, registered
**GET-only** at `main.go:265`. The response type is declared inline:

```go
guide.go:818-829   type m struct {
                       Program                               // embedded — flattened into the object
                       ChannelID string `json:"channelId"`
                       Channel   string `json:"channelLabel"`
                       Initials  string `json:"initials"`
                       LogoBg    string `json:"logoBg"`
                       When      string `json:"when"`
                       Duration  string `json:"duration"`
                       Scheduled bool   `json:"scheduled"`
                       DRM       bool   `json:"drm"`
                       Art       string `json:"art"`
                   }
guide.go:843       writeJSON(w, map[string]any{"matches": out, "count": len(out)})
```

and `Program` itself at **`guide.go:17-38`**:

```go
ChannelGUID  string   `json:"channel"`          // no omitempty
Start        int64    `json:"start"`            // no omitempty
End          int64    `json:"end"`              // no omitempty
Title        string   `json:"title"`            // no omitempty
EpisodeTitle … Desc … Season … Episode … EpisodeNum … Categories … Icon …
New … Live … Premiere … Finale … SeriesID … Rating … OrigAirDate … Video   // all `,omitempty`
```

Two properties of that shape decide the decoder:

- **Go embeds `Program`, so its fields are siblings of the nine, in one flat JSON object.** This
  app already decodes exactly that pattern twice — `GuideNowItem` (`Models.swift:77-84`) and
  `GuideRow` (`:112-116`) each decode `MergedChannel` from the *same* container and then their own
  keys from a keyed one. The new decoder follows them exactly.
- **Nothing outside `Program` carries `omitempty`**, so all nine are always present — `""`, `0` or
  `false` rather than omitted — and `Program`'s own four non-optional fields are always present
  too. So strict decoding is what the shape supports, and strict is what this app does
  (`Models.swift:399-400`, the `TrashItem` note).

### 2.2 What was written

| Type | Where | Strictness |
|---|---|---|
| `GuideSearchMatch` | `Models.swift:211-244` | **strict on all ten** — `Program` from the same container, then the nine siblings with `decode`, never `decodeIfPresent` |
| `GuideSearchResponse` | `Models.swift:246-257` | strict item, **lenient array** — `matches` absent or null reads as no matches |
| `FindRow` | `Models.swift:167-181` | **strict on all eight** (`guide.go:862-871`, no `omitempty` anywhere) |
| `FindResponse` | `Models.swift:183-194` | same pair — strict row, lenient array |

The lenient-array/strict-item split is the `TrashItem` / `TrashResponse` pair (`Models.swift:401`,
`:422`), which Pass 62 §6.2(h) named as the model to copy.

`AiringSheet` needs `program.title`, `.start`, `.end`, `.episodeTitle`, `.episodeNum`, `.rating`,
`.desc`, `.new/.live/.premiere/.finale` and `.seriesId`. **Every one of them is inside the embedded
`Program`**, which is why this route and not `/api/guide/find` is what reconstitutes an airing —
`find` carries none of them except the title and the start (Pass 62 §2.2).

**Proof the decoder actually produced all of them**, from the device: `12-sheet-from-a-search-result.jpg`
draws `NEW` and `LIVE` chips (`program.new`, `.live`), `E547` (`.episodeNum`), the description
(`.desc`), and **`Today 3:00 – 4:00 PM`** — a time *range*, which can only be drawn from
`program.end`, the field `find` does not have.

### 2.3 The two API methods

```
ChannelFilter.swift:82-85   func guideFind(q:) -> (rows: [FindRow], returned: Int, count: Int)
ChannelFilter.swift:91-94   func guideSearch(title:) -> [GuideSearchMatch]
```

They live beside `channels`, `onNow`, `guide`, `later` and `schedule` because that extension is
where this app's typed endpoint calls with the DRM rule applied already live. `guideFind` returns
three values rather than one so the screen can report the server's own numbers: `rows` after the
DRM filter, `returned` = the length of `matches` **before** it, and `count` = the server's total
before its own 20-row cap (`guide.go:899-903`).

Two `.playable` overloads were added next to the four that were there, matching them line for line
(`ChannelFilter.swift:32-34`, `:36-38`). Both routes walk `a.channels(false)` (`guide.go:834`,
`:875`), which carries DRM channels rather than filtering them (`sources.go:321`), so both need the
rule applied client-side — `ChannelFilter.swift:5-8`, as the owner's decision says.

**`/api/guide/search` is uncapped** (`guide.go:843`). The screen asks it with one exact title, which
bounds the answer in practice, but a very common title could still return a large body. Unmeasured;
recorded as §8.3.

---

## 3. Step 3 — the screen

`Marlin DVR TV/GuideSearchScreen.swift`, new, 394 lines — `GuideSearchModel` (`:48-209`),
`GuideSearchScreen` (`:211-354`) and `SearchResultRow` (`:356-394`).

### 3.1 The states

| State | When | What is drawn |
|---|---|---|
| **empty query** | nothing typed, or only whitespace | "Type a title. Search matches the title only, from now forward." |
| **loading** | a keystroke has landed and the read is out | "Searching…" |
| **results** | rows came back | the count line, then the rows |
| **no matches** | the server answered nothing | `No airings match “zzqqxx”.` |
| **failure** | the read threw | `ErrorLine` with the error, the same component every other screen uses |

`statusText` is at `GuideSearchScreen.swift:183-202` and the failure branch hands over to
`ErrorLine` at `:315-325`.

**The count line names both numbers, as decided.** Measured on the device:
`Showing the first 20 of 726 matches · type more of the title to narrow it`
(`11-results-for-news.jpg`). When `count` does not exceed what came back it says `12 matches` or
`1 match` instead. **Neither number is this app's arithmetic** — `returned` and `total` are the
server's own, taken before the DRM filter, so the line describes the *search* and never the list.

**One extra sentence exists and is worth naming**, because the alternative would have been a lie on
screen: if the server reports matches but every returned row was filtered out as DRM, the screen
says `No airings match “x” on a channel this app can play.` rather than the flat "No airings
match". Nothing else discloses the filter — the standing rule is that DRM channels never appear,
and they do not (see §8.1).

### 3.2 What a result row shows

Exactly what `find` returns, minus the two fields that are not display: `channelId` is identity,
and `drm` never reaches a row because a DRM row is filtered before the list is built.

```
NewsNation Live With Connell McShane          ← title
(episode title, when the listing has one)     ← subtitle, the raw p.EpisodeTitle (guide.go:884)
9021 NEWSNATION · Fri 3:00 PM · 1h 0m         ← channelLabel · when · duration
```

`when` and `duration` are the server's own strings, unaltered — this app formats its own times
everywhere else, but these are what the route hands over and the row is a display of that route.
Note the consequence the owner should know about: **`when` carries no date** (`guide.go:885`), so
two airings a week apart both read `Mon 8:00 PM`.

The row is `LaterRow`'s shape and treatment — `Nocturne.surface`, the accent mix on focus, the one
`focusTreatment` (`SearchResultRow` at `:356-394`, against `OnLaterScreen.swift:105-145`).

### 3.3 Searching

`queryChanged` (`:86-106`) cancels the previous search and schedules a new one behind **400 ms**, so
walking the on-screen keyboard does not fire a request per letter. It runs off the binding, not off
a submit, for the reason measured in §1.1: the binding updates while the keyboard is up, so the
results are already drawn when it goes away.

### 3.4 Opening a result

`open(_:)` (`:135-163`), three reads at worst and one of them cached:

1. **`GET /api/guide/search?title=<the row's own title>`**, then pick the match whose `channelId`
   **and** `program.start` are the row's. Whole-title equality is exactly right here because the
   title being asked with is the row's own.
2. **`GET /api/channels`** for the `MergedChannel`, matched on `id == row.channelId`. Held after the
   first read and re-read only when the id is missing from the copy in hand.
3. **`GET /api/schedule`** for the `Job` seed, and — the part that is not optional — to back the
   sheet's `onScheduleChanged` (`:247-250`), which re-reads the schedule and re-joins this airing,
   the same pair the Guide supplies at `GuideScreen.swift:298-301`. Without it the sheet's writes
   would leave it holding a stale job, which is the failure `AiringSheet.swift:417-420` exists to
   avoid.

**`/api/guide` is not read anywhere on this screen.** That is the owner's decision and the reason is
Pass 62 §2.3(b-i): `/api/guide`'s block builder rounds to whole half hours and drops listings that
end inside a slot already consumed (`guide.go:679`, `:699`, `:705`), which the marlin-dvr project
measured at about 3 % and declined to fix. An airing it drops is one the Guide screen cannot show
either — so search would be the only way to reach it and would be the one way that failed.

Both failure paths say so rather than doing nothing: "The server no longer lists that airing." and
"That airing's channel is not in the channel list." Neither was reachable on the device (§8.2).

### 3.5 The text field, and the one thing about it this app does not own

The field is a SwiftUI `TextField` inside the app's own framed row with the magnifier glyph and the
standard `focusTreatment` (`:291-313`). **Its inner capsule is tvOS's and cannot be restyled from
SwiftUI**: tvOS paints it light while it has focus and dark while it does not. That is visible in
`11-results-for-news.jpg` (focused, light) against `14-back-on-the-results.jpg` (resting, dark).

That produced a real legibility defect on the first device run — the app's `Nocturne.text` ink was
all but invisible on the light capsule — and it is fixed by making the ink follow the capsule
(`:295-304`): `Nocturne.bg` while focused, `Nocturne.text` while not. Photographed both ways.

---

## 4. Step 4 — the rail wiring, edit site by edit site

Seven sites in `Destination.swift` and `ScreenShell.swift`, which is what Pass 62 §5.3 said it would
be, plus three more for the model's ownership (§4.1).

| # | Site | Change |
|---|---|---|
| 1 | `Destination.swift:21` | `case … radio, **search**, settings, manage` |
| 2 | `Destination.swift:27` | `railOrder` — `.radio, **.search**, .manage`: directly under Radio, above the Manage DVR bottom slot |
| 3 | `Destination.swift:43` | `label` → `"Search"` |
| 4 | `Destination.swift:63` | `railSymbol` → `"magnifyingglass"` (an SF Symbol; nothing bundled) |
| 5 | `Destination.swift:92` | `tileTint` → the neutral surface, with `.home` and `.manage`, because **Search is not a Home tile** |
| 6 | `Destination.swift:101` | `isBuiltNow` → `true` |
| 7 | `ScreenShell.swift:103` | `case .search: GuideSearchScreen(model: search, api: api, onLeave: leave)` |

**No Home tile**, per the owner's decision. `homeTiles` (`Destination.swift:29`) is untouched and the
grid is still the design's 3 × 3. `RailView.swift` is untouched — it reads `railOrder`, `label` and
`railSymbol` generically.

### 4.1 Where the model lives, and why it is not in the screen

`ScreenShell.swift:51` puts `.id(current)` on the content, so leaving a screen destroys it. A query
and its results have to survive that, so the model is owned above the shell exactly as `HomeModel`
and `WeatherModel` are:

| Site | Change |
|---|---|
| `Marlin_DVR_TVApp.swift:21`, `:28`, `:33` | `@State private var search: GuideSearchModel`, built with the one `APIClient`, passed to `ContentView` |
| `ContentView.swift:21`, `:30` | the property, and passed into `ScreenShell` |
| `ScreenShell.swift:30` | `let search: GuideSearchModel` |
| `ContentView.swift:64` | the `#Preview` updated to match |

### 4.2 Pass 62 §5.3's open arithmetic is now a photograph

Pass 62 worked out from Pass 24's measured frames that an eleventh rail entry *ought* to fit and
said plainly that "it wants a screenshot before anyone relies on it". `19-the-expanded-rail-with-eleven-entries.jpg`
is that screenshot: eleven entries, Search under Radio with the accent ring, Manage DVR still last,
and the two-line footer ("Apple TV" / "192.168.1.250:8090") below it, all inside the frame. The
collapsed strip is in every other screenshot and its eleventh icon clears the bottom margin too.
**It fits.**

---

## 5. Step 5 — driven on Home Theater with the real remote

`Marlin DVR TVUITests/GuideSearchUITests.swift`, three tests, **0 failures, 176.8 s** on the build being
committed, physical Apple TV, `XCUIRemote`. It was run four times across the pass and passed
every time after the §5.3 fix. It reaches Search the way the owner does — there is no Home tile — by
opening On Later, swiping left into the rail (Pass 25's restore lands it on On Later, rail index 4)
and walking down five to Search. **It makes no server write**: nothing is recorded, no pass is
created, and the sheet is always left by Menu.

### 5.1 `testTypeATitleOpenAResultAndDriveTheSheet` — the owner's path

| Step | Evidence |
|---|---|
| Search opens with the empty-query line | `10-search-empty-query.jpg`, field has focus (`textFieldFocus=[true]`) |
| Select opens the keyboard, `news` is typed, Menu dismisses it | `keyboards` 0 → 1 → 0 |
| results draw | `11-results-for-news.jpg`; `Showing the first 20 of 726 matches · type more of the title to narrow it`; **20 result rows** listed in the log by title, channel, time and length. The total moves between runs as airings end — 726 on the run photographed, 725 an hour later — because `find` counts only airings whose end is still in the future |
| Down focuses the first row | `NewsNation Live With Connell McShane, 9021 NEWSNATION · Fri 3:00 PM · 1h 0m` |
| Select opens the sheet | `12-sheet-from-a-search-result.jpg` |
| **the sheet's controls are live** | focus on open = `Record this airing`; **Down keeps it there** (the results behind are disabled, so the remote cannot walk out of the sheet); **Right moves it to `Record the series`** (`13-sheet-focus-moved.jpg`) |
| Menu closes the sheet, not the screen | `14-back-on-the-results.jpg`: both sheet buttons gone, the count line still there |
| focus comes back to the row it came from | `FOCUSALL[after-sheet] ["9:NewsNation Live With Connell McShane, 9021 NEWSNATION · Fri 3:00 PM · 1h 0m"]` — byte-equal to the row focused before the sheet opened |

The sheet in `12-…jpg` is fully populated from the reconstitution, which is the decoder's own proof:
`NEW` and `LIVE` chips, `9021 · NEWSNATION · HD` from the `MergedChannel`, `E547`, the time **range**
`Today 3:00 – 4:00 PM`, the description, the `PosterFallback` tile carrying the channel's initials
and `logoBg`, and three pressable controls — `Record this airing`, `Record the series`, `Watch live`.
`Watch live` is drawn only while the programme is on, which is itself a statement about
`program.start` and `.end` having arrived intact.

Corroborated by the app's own console line from a console-attached run in this pass:

```
[search] q=«news» count=726 returned=20 playable=20
[search] opened verizon:6097@1789153200 · NewsNation Live With Connell McShane
         · end=1789156800 seriesId=title:newsnation live with connell mcshane
```

### 5.2 The other two

- **`testAQueryAndItsResultsSurviveATripToTheRail`** — type `news`, out to the rail, into Radio,
  back to Search. The count line is **string-identical** before and after
  (`Showing the first 20 of 726 matches · …`, and `725` on a later run — identical to itself either
  way), the full list of result rows is **element-for-element identical**, the empty-query line is absent, and focus lands back on the row the remote left.
  `15-`, `16-`, `17-…jpg`. This is the owner's decision, proven.
- **`testAQueryThatMatchesNothingSaysSo`** — `zzqqxx` gives `No airings match “zzqqxx”.`
  (`18-no-matches.jpg`).

### 5.3 The defect the harness caught, and what it actually was

**Symptom, on the first device run: after Menu closed the sheet, nothing on the screen had focus.**
Not the row, not the field, nothing — `FOCUSALL[after-sheet] []` — and the television showed no
focus ring until the user pressed a direction.

It was diagnosed, not retried. The steps and what each one ruled out:

1. The harness was taught to report the focus of **every** element type, not just buttons. That
   ruled out "focus quietly went to the text field": `textFieldFocus=[false]` as well.
2. The app was started with `xcrun devicectl device process launch --console` so its own `print`
   output could be read (the technique Pass 38 established). It said:
   `[search] menu: sheet=true focused=nil lastFocus=row:verizon:6097@1789153200` followed by
   `[search] focus back to row:verizon:6097@…` and then **`[rail] entered on home, restoring to
   search`** — `ScreenShell.railRestore` firing. So the focus engine was leaving the screen for the
   rail the instant the sheet went, and the screen's own later assignment could not pull it back.
3. Raising the delay before the assignment did not help. Neither did clearing `@FocusState` to nil
   first, nor disabling less of the screen behind the sheet.

**A trap worth recording, because it cost several runs.** `activate()` attaches to the app already
running — which is what the console technique needs — but `xcodebuild test-without-building`
**did not replace that running process**, so three of those diagnostic runs were driving a *stale
build* and told me nothing about the code I had just written. It was caught only when a `print` I
had deleted kept appearing. **The console harness must be given a freshly installed app, or the
conclusions are worthless.** Every measurement quoted in this report is from a `launch()` run or
from a console run whose build was confirmed by its output.

**The fix is a rebuild, not a delay** (`GuideSearchScreen.swift:272-286`). A `generation` counter is
bumped when the sheet closes; the content subtree carries `.id(generation)` and
`.task(id: generation)` (`:232-234`), so it is re-created and asks `model.restoreFocusID` where to
land — which is the one mechanism in this app that re-focuses reliably, and is why a rail round trip
already came back on the right row (`ScreenShell.swift:51` does the same thing with `.id(current)`).
Verified: focus now returns to the exact row the sheet was opened from, in four consecutive runs
on the device.

The results are also disabled behind the sheet (`:347`), the Guide's own pattern
(`GuideScreen.swift:274`), and the harness now asserts the containment that buys: Down while the
sheet is up leaves focus on `Record this airing`.

**A question this raises about a screen I did not touch.** `GuideScreen` restores focus after its
sheet the same way this screen originally did — `focused = lastCell` behind a short sleep
(`GuideScreen.swift:318-323`). Nobody has ever asserted `hasFocus` after closing the Guide's sheet;
Pass 9's harness pressed Menu and stopped. **It may have the same latent defect.** Out of scope, not
investigated, not changed — raised as §9.1.

---

## 6. What is NOT claimed

- **The DRM filter never fired on a real hit.** Every measured search returned
  `returned=20 playable=20` — no DRM row appeared in any page of results. The filter is two
  `.playable` overloads identical to the four beside them and it is code-traced, **not exercised**.
  So is the "on a channel this app can play" sentence that depends on it.
- **The two reconstitution failure paths were never reached** — no airing vanished between the
  `find` and the `search`, and every `channelId` was in `/api/channels`. Code-traced only.
- **The failure state was never reached with a real failure.** The server answered every request in
  this pass. The `ErrorLine` branch is code-traced.
- **No write was ever sent from the search screen.** `Record this airing`, `Record the series`,
  `Watch live` and `Stop recording` were shown to take focus and to move focus; **none was pressed.**
  They are `AiringSheet`'s own controls, unchanged by this pass, and proven by Passes 8, 9, 32 and
  49 from the Guide — but "live" here means focusable and reachable, not "the write was observed
  from this host".
- **`Watch live` from the search screen closes the sheet and plays nothing.** This screen has no
  Player to hand a request to, and wiring one was not in the pass. It is a real rough edge, named as
  §9.2.
- **Only Home Theater.** The Master Bedroom Apple TV was not touched.

---

## 7. Scope check — every path this pass touched

| Path | What happened |
|---|---|
| `Marlin DVR TV/GuideSearchScreen.swift` | **new** — the screen and its model |
| `Marlin DVR TV/Models.swift` | **+103** — the four decodables, one new MARK section; nothing existing changed |
| `Marlin DVR TV/ChannelFilter.swift` | **+31** — two `.playable` overloads and two API methods |
| `Marlin DVR TV/Destination.swift` | the six sites of §4 |
| `Marlin DVR TV/ScreenShell.swift` | the new property and the routing case (and the reverted probe hook) |
| `Marlin DVR TV/ContentView.swift`, `Marlin_DVR_TVApp.swift` | the model's ownership |
| `Marlin DVR TVUITests/GuideSearchUITests.swift` | **new** — the evidence harness |
| `Marlin DVR TV/SearchProbeScreen.swift`, `…UITests/SearchProbeUITests.swift`, `…/SearchFocusDiagUITests.swift` | **temporary, disclosed, deleted** — never committed |
| `reports/2026-09-11-pass63-guide-search.md`, `reports/assets/pass63/` | **new** |
| `design/` | **read only**, never written |
| `COLD-START.md`, `DECISIONS.md` | **not touched**, deliberately — see the note below |
| `~/Xcode/marlin-dvr-reference` | **read only, `git show origin/main:<path>` only** — `cmd/marlin-dvr/guide.go`, `main.go`. Nothing checked out, fetched, edited or run |

**Why the notebook is not updated.** This pass's steps name a report and a commit, and scope lock
binds what gets changed as well as what gets built (`CLAUDE.md`). The project's own pattern is that
a build pass writes its report and the pass that records the owner's acceptance writes the notebook
— Pass 42 was written up by Pass 43, Pass 47 by Pass 48, Pass 49 by Pass 50 — and DECISIONS.md
2026-09-09 (Pass 60) rule (b) puts the outcome "in the pass response and in the next pass's
notebook update". Nothing here is accepted or pushed yet, so `COLD-START.md` and `DECISIONS.md` are
left exactly as Pass 61 left them.

No request was made to 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, and no other folder under
`~/Xcode` was read or written. The app read 192.168.1.250:8090 exactly as it always does — `GET`
only from this screen, plus the ordinary client ping. **No credential, token or device id appears in
this report or in any file this pass adds**; the new sources were grepped for `password`, `token`,
`secret`, `api_key` and `Bearer` and match none.

---

## 8. Open questions for the owner

1. **Should the screen ever say that DRM results were hidden?** It does not, because the standing
   rule is that DRM channels never appear in any list, and Pass 62 Open Question 4 was settled as
   "filtered out". The consequence stands: a show that only airs on a DRM channel returns nothing,
   with no explanation. The one place it leaks is the sentence in §3.1, which fires only when the
   server reports matches and every returned row was filtered.
2. **Should `Watch live` from a search result actually play?** Today it closes the sheet (§9.2).
3. **`/api/guide/search` is uncapped.** Asking it with one exact title bounds it in practice, but a
   title shared by hundreds of airings would return a large body for one row's worth of use. Worth
   raising with the marlin-dvr project as a `limit` parameter, or leaving alone?
4. **Search matches the title only** (`guide.go:877`), so "Cooper" will not find the D.B. Cooper
   episode by its episode title. Widening it is a server change and therefore a marlin-dvr decision.
5. **The 21st match is unreachable.** `find` has no offset, cursor or page parameter, so the only
   way past the cap is a longer query — which is what the count line tells the user to do.
6. **Should Search get a Home tile after all?** It has none by decision; the grid is still 3 × 3.

---

## 9. The things I am least sure of

1. **`GuideScreen` may carry the same focus defect this pass fixed here** (§5.3). The mechanism is
   identical and nobody has ever measured it. Not investigated and not changed — scope.
2. **`Watch live` on the search screen is a dead end.** It closes the sheet rather than playing, and
   a user who presses it will reasonably expect a picture. It is honest rather than broken, but it
   is the weakest part of the screen.
3. **Whether the `.disabled` on the results is load-bearing for anything but containment.** The fix
   that worked is the rebuild; the disable was added back afterwards for the Guide's reason, and I
   did not run a build with the rebuild and *without* the disable to isolate them.
4. **The 400 ms debounce is a judgement, not a measurement.** It was never tuned against the pace of
   letters on a real remote; it just has to be shorter than the time between presses, and it is.
5. **That splitting `channelId` is never needed.** This screen never splits it — it matches the
   whole string against `MergedChannel.id` — which sidesteps Pass 62 §9.3 entirely rather than
   answering it.
6. **`.onSubmit` was not observed firing, and I did not press the keyboard's `done` to find out.**
   Nothing depends on it either way.
