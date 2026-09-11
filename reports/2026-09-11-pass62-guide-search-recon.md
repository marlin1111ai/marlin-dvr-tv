# Pass 62 — Guide search recon — 2026-09-11

**Verdict up front: the route exists, it is undocumented in the contract, and it is not enough on
its own.** `GET /api/guide/find?q=` takes one parameter, matches a case-insensitive substring
against the programme **title only**, searches everything the stored guide holds from now forward
with no horizon of its own, returns at most **20** rows with the true total in `count`, and hands
back **eight thin display fields** — not a `Program` and not a `MergedChannel`. `AiringSheet`
needs both. A search screen therefore needs at least one more read to open the sheet, and **the
obvious one, `GET /api/guide`, provably cannot answer for about 3 % of airings** — the marlin-dvr
project measured that and recorded the identical failure in their own web UI. This app has **no
text entry of any kind** today, and **the approved design draws none** — its own page header says
"No search".

Read-only pass. Nothing under `Marlin DVR TV/` was modified, no server call was made, `design/` was
read and never written, and the reference clone was read with `git show origin/main:<path>` only —
nothing checked out, fetched, edited or run.

**Citation keys.**
`File.swift:NN` = line NN of that file in this repo at `49a5672` (Pass 61).
`guide.go:NN`, `main.go:NN`, `sources.go:NN`, `system.go:NN`, `HLS-CLIENT-API.md:NN`,
their `COLD-START.md:NN` / `DECISIONS.md:NN` = the read-only reference clone
`~/Xcode/marlin-dvr-reference` at **`origin/main` = `095de815adac50eaf77dcaa7cdb50115942c46c5`**,
read with `git show`.
`dc:NN` = line NN of `design/Marlin DVR TV.dc.html`.
`SwiftUI.swiftinterface:NN` = `AppleTVOS26.5.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-tvos.swiftinterface`;
`<Header>.h:NN` = the same SDK's `UIKit.framework/Headers` or `TVUIKit.framework/Headers`.
The installed tvOS SDK is **26.5** (`xcrun --sdk appletvos --show-sdk-version`); this app's
deployment target is **tvOS 18.0** (`project.pbxproj:250`, `:305`).

---

## 1. The server side — `GET /api/guide/find`

### 1.1 Where it is, and how it is reached

```
main.go:266   mux.HandleFunc("GET /api/guide/find", a.handleGuideFind) // Pass 45: top-bar Search (substring)
guide.go:846-848   const guideFindLimit = 20
guide.go:860-904   func (a *App) handleGuideFind(w http.ResponseWriter, r *http.Request)
```

It is a Go 1.22-style method-qualified pattern, so **GET only**. There is no auth on it or on any
other route — the contract states this itself: *"No authentication of any kind on these routes
(`main.go:200-300`: the mux has no auth middleware). The server is LAN-only."*
(`HLS-CLIENT-API.md:286-287`).

The handler's own header comment records why it exists and why the older route was not reused:

> `guide.go:850-859` — "GET /api/guide/find?q= — case-insensitive SUBSTRING match on the title over
> current and upcoming airings, for the top-bar Search (Pass 45). … GET /api/guide/search above is
> deliberately NOT reused and NOT changed: it stays whole-title equality because its one caller, the
> series-pass Matches tab, previews what `Pass.matches` (passes.go) will actually record, and that is
> whole-title equality too."

### 1.2 Every query parameter it accepts: **exactly one, `q`**

```
guide.go:861   q := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))
```

That is the only `r.URL.Query()` read in the function. There is **no** `source`, `filter`, `limit`,
`offset`, `cursor`, `start`, `end`, `days`, `channel` or `scope`. Contrast the two neighbours,
which do take parameters:

| Route | Parameters | Cite |
|---|---|---|
| `GET /api/guide` | `start`, `slots`, `source`, `filter` | `guide.go:651-671` |
| `GET /api/guide/search` | `title` | `guide.go:817` |
| **`GET /api/guide/find`** | **`q` and nothing else** | **`guide.go:861`** |

**An empty or whitespace-only `q` is not an error.** The whole matching block is wrapped in
`if q != ""` (`guide.go:873`), so the handler falls straight through to the writer and answers
**200** with `{"matches":[],"count":0}` — `out` is initialised to `[]row{}` at `:872`, never `nil`,
so the array is `[]` and never `null`.

### 1.3 What it matches on: the **title only**, case-insensitively, by substring

```
guide.go:877   if p.End <= now || !strings.Contains(strings.ToLower(p.Title), q) { continue }
```

Both sides are lower-cased — the query at `:861`, the title at `:877` — so matching is
case-insensitive. `strings.Contains` is a plain substring test: no word boundaries, no tokenising,
no fuzzy matching, no normalisation of punctuation or accents, and no relevance score.

**It does not match the episode title, the description, the channel name, the categories or the
series id.** `p.EpisodeTitle` is *emitted* as `subtitle` (`:884`) but never tested; `p.Desc`,
`p.Categories` and `p.SeriesID` (`guide.go:24`, `:28`, `:34`) are not read by this handler at all.
A query of "Cooper" will not find *History's Greatest Mysteries* by its episode title
"Who Is D.B. Cooper?".

Measured by the marlin-dvr project against this very server after the 1.5.0 switch:
`GET /api/guide/find?q=news` → **716** matches, 20 rows returned, every row's title containing
"news"; `GET /api/guide/search?title=news` → **0**; `?title=Fox News Live` → **13**
(their `DECISIONS.md`, Pass 48 entry).

### 1.4 How far forward it searches: **as far as the stored guide reaches. The route imposes no horizon.**

The only time test in the handler is one half of `:877`:

```
guide.go:874   now := time.Now().Unix()
guide.go:877   if p.End <= now || … { continue }
```

So the rule is **"every airing whose `end` is still in the future"** — which includes a programme
that is already half over, and excludes nothing at the far end. There is **no** `start < now + N`
bound anywhere.

What it is walking has no bound either:

```
guide.go:875-876   for _, c := range a.channels(false) {
                       for _, p := range programsFor(a.guide(c.SourceID), c.GUID) {
guide.go:624-634   func programsFor(g *GuideFile, guid string) []Program   // every stored program for that guid
guide.go:87-92     func (g *GuideFile) all() []Program                    // cloud + XMLTV, merged
```

`programsFor` returns **every** programme the merged guide holds for that channel, with no window
clipping of any kind. So the practical horizon is whatever the sources supply:

- **HDHomeRun cloud guide**: the fetch merges over the existing file so *"a 4–8 hour cloud window
  accumulates"* (`guide.go:452`), and old entries are dropped only once `p.End < now-6*3600`
  (`guide.go:459-462`). Forward reach is therefore roughly the cloud window at the last fetch.
- **XMLTV**: `parseXMLTV` applies **no time bound at all** (`guide.go:216-268`) and the result
  replaces the stored list wholesale (`guide.go:321` for an HDHomeRun source's attached XMLTV,
  `guide.go:323` for a pure XMLTV source). Forward reach is however long the owner's XMLTV file runs.

For scale on this owner's server, as the marlin-dvr project measured it read-only on 2026-09-07:
**27,897 programmes across 95 channels** (their `DECISIONS.md`, Pass 48 entry). **Not measured from
here** — the running server is on this project's do-not-touch list.

### 1.5 Which channels it covers

```
guide.go:875   for _, c := range a.channels(false) {
sources.go:304-345   // channels returns every channel of every enabled source, merged with the
                     // owner's overrides, sorted by number. hiddenToo includes hidden ones.
sources.go:308-317   skips disabled sources; `if o.Hidden && !hiddenToo { continue }`
sources.go:321       DRM is carried as a field, never filtered
```

So: **enabled sources only, hidden channels excluded, DRM channels INCLUDED** and flagged with
`drm` on the row (`guide.go:870`, `:888`). This is a different channel set from `/api/guide` and
`/api/guide/now`, which both go through `a.filterChannels(source, filter)` (`guide.go:671`, `:729`).
This app's standing DRM rule — "channels with `drm = true` never appear in any list"
(`ChannelFilter.swift:5-8`, DECISIONS.md 2026-09-05 (design)) — would have to be applied
client-side to `find`'s rows, exactly as `ChannelFilter.swift:13-27` already does for the other
shapes.

### 1.6 How many results, capped or pageable: **20, capped, not pageable**

```
guide.go:846-848   // guideFindLimit caps the rows the top-bar Search dropdown receives; the
                   // total number of matches is still reported as "count".
                   const guideFindLimit = 20
guide.go:899-903   total := len(out)
                   if len(out) > guideFindLimit { out = out[:guideFindLimit] }
                   writeJSON(w, map[string]any{"matches": out, "count": total})
```

**`count` is the total before the cap, not the length of `matches`.** A client that renders
`count` next to a list of 20 rows is telling the truth about the search and not about the list —
which is what the server intends ("showing the first N of M", their `DECISIONS.md` Pass 45 entry).
There is **no offset, cursor or page parameter**, so the 21st match cannot be reached at all: the
only way to see it is to type a longer query.

**Ordering** is fixed and not selectable:

```
guide.go:893-898   sort by Start ascending; ties broken by ChannelLabel ascending
```

### 1.7 The exact JSON shape of a result

```
guide.go:862-871   type row struct {
                       ChannelID    string `json:"channelId"`
                       Start        int64  `json:"start"`
                       Title        string `json:"title"`
                       Subtitle     string `json:"subtitle"`
                       When         string `json:"when"`
                       Duration     string `json:"duration"`
                       ChannelLabel string `json:"channelLabel"`
                       DRM          bool   `json:"drm"`
                   }
guide.go:903       writeJSON(w, map[string]any{"matches": out, "count": total})
```

So the body is `{"matches": [ …rows… ], "count": <int>}`.

**No field carries `omitempty`**, so all eight keys are present on every row — `""`, `0` or `false`
rather than omitted. Field by field, with how each is produced:

| Key | Type | Value | Cite |
|---|---|---|---|
| `channelId` | string | `c.ID`, which is `sourceId + ":" + guid` | `guide.go:881`; `sources.go:319` |
| `start` | int64 | the programme's true unix start, unrounded | `guide.go:882`; `guide.go:20` |
| `title` | string | `p.Title`, verbatim | `guide.go:883` |
| `subtitle` | string | **`p.EpisodeTitle` raw** — *not* `subtitleOf(p)` | `guide.go:884`; contrast `guide.go:636-647` |
| `when` | string | `time.Unix(p.Start,0).Format("Mon 3:04 PM")` — server-local, **no date** | `guide.go:885` |
| `duration` | string | `humanDuration(end-start)`: rounded to the minute, `"30m"` / `"1h 0m"` / `"1d 2h 3m"` | `guide.go:886`; `system.go:176-189` |
| `channelLabel` | string | **`c.Number + " " + c.Name`** — one space, no separator | `guide.go:887` |
| `drm` | bool | the channel's DRM flag | `guide.go:888` |

Three details worth recording because they will bite whoever builds against this:

1. **`subtitle` is the raw episode title and nothing else.** `/api/guide`'s blocks use
   `subtitleOf(p)`, which falls back to the first category and then to the episode number
   (`guide.go:636-647`); `find` does not. A listing with no episode title gives `""`.
2. **`when` carries no date.** Two airings a week apart both read `"Mon 8:00 PM"`. The date is only
   recoverable from `start`.
3. **`channelLabel` is `number name`; `/api/guide/search`'s `channelLabel` is `name number`** — the
   reverse order, at `guide.go:837`. The two routes disagree with each other, and neither matches
   this app's own `channelLine`, which is `number · name · HD` (`AiringSheet.swift:114-118`).

### 1.8 Does `HLS-CLIENT-API.md` document it? **No — it does not mention the guide at all.**

Measured at `origin/main` (`095de81`): **`grep -c "api/guide"` over `HLS-CLIENT-API.md` returns
`0`.** The only occurrence of the string "find" anywhere in the file is `Library.find` at
`HLS-CLIENT-API.md:586`, which is about the recordings library and unrelated.

Its eleven sections are: 1 registering a client, 2 starting an HLS session, 3 recordings over HLS,
4 live channels and cameras, 5 playlist/segments/stopping, 6 the idle watchdog, 7 errors, 8 what is
not there, 9 radio, 10 commercial segments, 11 the trash list (`HLS-CLIENT-API.md:30, 57, 112, 141,
207, 237, 260, 284, 294, 341, 513`). **No guide section exists.** Its §8 "What is not there" does
not mention the guide either (`:284-292`).

So the question "does the documentation agree with the source" **does not arise: there is no
documentation of this route in the contract file.** This is consistent with what this project
already knows about that file — COLD-START.md records it as byte-unchanged across the whole 1.8.0
delivery and still declaring 1.7.0 in its own header (`HLS-CLIENT-API.md:6-14`).

**The route is documented in the server project's own notebook**, which is where every fact above
was cross-checked against: their `COLD-START.md:651-663` (Pass 45 summary) and their
`DECISIONS.md:526-537` (the owner's decisions 1a and 2a, and the 20-row cap recorded explicitly as
"Builder's calls, told to the owner and open to change"). Their notebook and their Go source agree
with each other on every point above.

---

## 2. Is that route enough on its own? **No.**

### 2.1 What `AiringSheet` actually requires

The sheet's public surface is four things (`AiringSheet.swift:48-53`):

```
AiringSheet.swift:49   let selection: AiringSelection
AiringSheet.swift:50   let api: APIClient
AiringSheet.swift:51   let onWatchLive: () -> Void
AiringSheet.swift:52-53 let onScheduleChanged: () async -> Job?
```

and `AiringSelection` is three (`AiringSheet.swift:32-35`):

```
AiringSheet.swift:33   let channel: MergedChannel
AiringSheet.swift:34   let program: Program
AiringSheet.swift:35   let job: Job?
```

`Program` requires four non-optional fields to decode — `channel` (the guid), `start`, `end`,
`title` — with everything else optional (`Models.swift:43-63`).
`MergedChannel` requires **fourteen** non-optional fields plus optional `tvgId`
(`Models.swift:16-33`).

Every field the sheet reads, and where:

| Field | Read at | What it draws |
|---|---|---|
| `program.title` | `:191`, `:204` | the poster path and the 56 pt title |
| `program.episodeTitle`, `program.episodeNum` | `:122-123` | the episode line |
| `program.start`, `program.end` | `:102`, `:128` | "Watch live" gating and the day + time range |
| `program.rating` | `:129` | the "· TV-14" tail |
| `program.desc` | `:221` | the three-line description |
| `program.new/.live/.premiere/.finale` | `:107-110` | the flag chips |
| `program.seriesId` | `:342`, `:376` | pass matching, and the body of `POST /api/passes` |
| `channel.number`, `.name`, `.hd` | `:115-116` | "13.1 · WJZ · HD" |
| `channel.initials`, `.logoBg` | `:192` | the `PosterFallback` when the art route 404s |
| `channel.id` | `:37`, `:300`, `:357` | the selection id, the job join, `POST /api/record` |
| `job.status` | `:85-86`, `:95` | the three-way first control, and Stop |
| `job.id` | `:412` | `POST /api/schedule/jobs/{id}/stop` |
| `job.reason` | `:313` | the "✕ Conflict:" line |

### 2.2 Side by side against what a `find` row carries

| What the sheet needs | Does `find` supply it? |
|---|---|
| `program.title` | **yes** — `title` |
| `program.start` | **yes** — `start` |
| `program.channel` (guid) | **no** — but derivable: `channelId` is `sourceId + ":" + guid` (`sources.go:319`) |
| `program.end` | **no** — only `duration`, a string rounded to the minute (`system.go:177`) |
| `program.episodeTitle` | partially — `subtitle` is the raw episode title (`guide.go:884`) |
| `program.episodeNum`, `.desc`, `.rating`, `.seriesId`, `.new/.live/.premiere/.finale` | **no — none of them** |
| `channel.number`, `.name` | **no** — only `channelLabel`, `"number name"` joined by one space |
| `channel.hd`, `.favorite`, `.hidden`, `.initials`, `.logoBg`, `.source`, `.sourceId`, `.guid`, `.logo`, `.origNumber`, `.origName`, `.tvgId` | **no — none of them** |
| `channel.drm` | **yes** — `drm` |
| `job` | **no** — but see §2.4; `nil` is safe here |

**`channelLabel` cannot be split back into `number` and `name` reliably.** It is joined by a single
space (`guide.go:887`) and both halves may contain spaces — the owner's own channels include names
like "NHKWORLD" but nothing stops a name or an override number containing one, and
`MergedChannel.number` is a free string the owner can override (`sources.go:323-325`).

So a `find` row is a **display row**, deliberately shaped for a dropdown, and it is not enough to
construct either of the two types the sheet is built on.

### 2.3 What else a search screen would have to read

**(a) `GET /api/channels` — for the `MergedChannel`.** Already in the app as
`APIClient.channels(source:filter:)` (`ChannelFilter.swift:32-38`), one request for the whole list,
already used by Home (`HomeView.swift:36`) and Favorites (`FavoritesScreen.swift:39`). Match on
`id == row.channelId`. Note that this accessor applies `.playable` (`ChannelFilter.swift:37`,
`:14`), so a DRM search hit will find **no** channel — which is the right outcome under the
standing DRM rule, but it is a case that must be handled rather than crashed on.

**(b) A real `Program`.** Two candidates, and the first has a measured hole in it.

> **(b-i) `GET /api/guide` — and this is the one that provably fails for some results.**
>
> The app already has the read (`ChannelFilter.swift:50-58`, called at `GuideScreen.swift:111`); a
> search screen would ask for `start = row.start`, a small `slots`, `source = <the channel's
> sourceId>`, and pick the block whose `program.start == row.start`.
>
> **`GET /api/guide` silently omits some programmes entirely.** The block builder rounds its cursor
> up to whole half hours and then skips anything that ends inside the slot already consumed:
>
> ```
> guide.go:679   if p.End <= cursor || p.Start >= winEnd { continue }
> guide.go:699   span := int((pe - cursor + 1799) / 1800)
> guide.go:705   cursor += int64(span) * 1800
> ```
>
> Those three lines are **present at `origin/main` today**, i.e. in the version this app talks to.
> The marlin-dvr project found this in their Pass 46 and records it as known and not being fixed:
>
> > their `COLD-START.md:1255-1268` — "**`/api/guide` silently omits listings — known, not fixed,
> > living with it (found Pass 46, 2026-09-07).** … Measured on the owner's own cached guide:
> > **26 of 834 Philo listings over 24 hours (3.1 %)**, concentrated on 9026 NHKWORLD (19 of the
> > 26); in one 3-hour window, 5 of 11 listings were dropped. **It predates Pass 42** … Consequence
> > in 1.5.0: **the top-bar Search finds those airings (it reads the guide directly) but clicking
> > one opens no dialog**, because the Guide page never received that block; the page loads
> > normally and nothing happens. Not raised as work."
>
> That last sentence describes, exactly, the failure a search screen in this app would inherit if it
> reconstituted its `Program` from `/api/guide`. And it bites hardest on precisely the airings whose
> whole value is that search is the only way to reach them — an airing `/api/guide` drops is also an
> airing the Guide screen cannot show, so search would be the sole route to it and would be the one
> route that fails.
>
> **Same root cause, different symptom, as Pass 26 §3.** Pass 26 established that this app ignores
> `span` and lays cells out by true time, so rounding is invisible to the Guide's *drawing*. That is
> still true. What Pass 26 did not examine is that the rounding also decides **which blocks exist at
> all**, and the app skips blocks with no programme (`GuideScreen.swift:137`) — so a dropped
> programme is simply absent from this app too.

> **(b-ii) `GET /api/guide/search?title=<the row's own title>` — closer, and not in the app.**
>
> ```
> guide.go:816-844   func (a *App) handleGuideSearch
> guide.go:818-829   type m struct { Program; ChannelID; Channel (json:"channelLabel"); Initials;
>                                    LogoBg; When; Duration; Scheduled; DRM; Art }
> ```
>
> Go embeds `Program`, so its **whole** field set is flattened into each row — `end`, `desc`,
> `rating`, `seriesId`, `episodeNum` and the four flags included — **plus `initials` and `logoBg`**,
> which are two of the three channel fields `find` cannot give and which the sheet's
> `PosterFallback` needs (`AiringSheet.swift:192`, `:478-490`). It reads the same guide by the same
> walk (`guide.go:834-840`), so it has the same DRM-included channel set and, being independent of
> the block builder, it is **not** subject to (b-i)'s omission.
>
> Its matching is whole-title equality (`guide.go:836`) — which is fine here, because the `find`
> row hands back the airing's exact `title` to ask with. It has **no cap**: `writeJSON` at `:843`
> emits every match, and `count` is the array's own length. A common title could return hundreds of
> rows.
>
> **It has no decoder and no `APIClient` method in this app** — `grep -rn "guide/search"` over the
> Swift sources returns nothing.

**(c) `GET /api/schedule` — for the `Job?` and for the Guide's marks.** Already in the app
(`ChannelFilter.swift:66-74`). See §2.4.

### 2.4 The `job` is the easy one

`AiringSelection.job` is only a **seed**. The sheet's `.task` sets `job = selection.job`
(`AiringSheet.swift:162`) and then immediately overwrites it from the schedule:

```
AiringSheet.swift:164-169   // Pass 32: whether Stop is offered turns on the job's *current* status…
                            job = await onScheduleChanged() ?? selection.job
```

So **passing `nil` is safe** and costs one extra schedule read on open — which the sheet performs
anyway, by design, for the reason recorded at `:164-168`.

What is *not* free is `onScheduleChanged` itself. The Guide implements it as "re-read the whole
schedule, then re-join this airing on `channelId` + `program.start`":

```
GuideScreen.swift:298-301   onScheduleChanged: { await model.refreshSchedule()
                                                 return model.job(channelId: …, programStart: …) }
GuideScreen.swift:162-168   func refreshSchedule() async { jobs = try await api.schedule().jobs }
GuideScreen.swift:145-147   func job(channelId:programStart:) -> Job?
```

A search screen must supply both halves or the sheet's writes will leave it holding a stale job —
the `?? job` fallbacks at `AiringSheet.swift:361` and `:379` depend on the closure answering, and
Stop deliberately has **no** fallback at `:421` for the reason given at `:417-420`.

### 2.5 The minimum, stated plainly

**`find` + `/api/channels` + one of {`/api/guide` per channel (holed, ~3 %), `/api/guide/search` by
title (new decoder, uncapped)} + `/api/schedule`.** Three of those four reads already exist in the
app. The one that does not is the one that avoids the known hole.

---

## 3. Text entry on tvOS

### 3.1 What this app already has: **nothing. Not one character of typed input.**

Measured over the whole repository, not just the app target:

```
grep -rn --include="*.swift" "TextField\|searchable" .   → exit 1, no matches
```

There is no `TextField`, no `.searchable`, no `UITextField`, no `UIKeyInput`, no
`becomeFirstResponder`, no `keyboardType`, no `onSubmit`, no `UISearchController` — the full grep at
the head of this pass returned only the twenty-six `@FocusState` declarations, which are navigation
focus and not text.

There is also **no navigation container anywhere**: `grep -rn "NavigationStack\|NavigationView\|NavigationSplitView\|TabView"` over
`Marlin DVR TV/*.swift` returns nothing. Screens are swapped by `ScreenShell`'s own switch
(`ScreenShell.swift:86-100`) inside a `ZStack`, and overlays are drawn as siblings in that `ZStack`
(`GuideScreen.swift:245`, `:290`).

The UI-test target has never typed either: `grep -rn "typeText\|typeKey\|XCUIKeyboard\|keyboards"`
over `Marlin DVR TVUITests/*.swift` returns nothing across all twelve files.

The nearest thing to an editor in the app is `EditSeriesPassScreen`, and it is click-to-step, not
typed: *"A click steps each setting to its next value and saves it on the server."*
(`EditSeriesPassScreen.swift:117`).

### 3.2 What the installed SDK offers — SwiftUI

All from `SwiftUI.swiftinterface` in `AppleTVOS26.5.sdk`:

| API | tvOS availability | Cite |
|---|---|---|
| `TextField<Label>` | **tvOS 13.0** | `:5020-5021` |
| `.textFieldStyle(_:)` | tvOS 13.0 | `:9943-9944` |
| `.plain` / `.roundedBorder` / `.automatic` styles | present | `:15997-16003`, `:7359-7367`, `:1757-1763` |
| `.keyboardType(UIKeyboardType)` | **iOS 13, tvOS 13** (macOS/watchOS unavailable) | `:3347-3351` |
| `.textInputAutocapitalization(_:)` | tvOS 15.0 | `:3369-3372` |
| `.autocorrectionDisabled(_:)` | present | `:19651` |
| `.textContentType(_:)` | present | `:17977` |
| `.onSubmit(of:_:)` / `.submitLabel(_:)` | present | `:7318`, `:8454` |
| `.searchable(text:placement:prompt:)` | **tvOS 15.0** | `:5492-5493` |
| `.searchable(text:isPresented:…)` | tvOS 15.0 | `:5511` |
| `.searchSuggestions { }` | **tvOS 16.0** | `:10199-10200` |
| `.searchCompletion(_:)` | present | `:13689` |
| `.onKeyPress(…)` | **tvOS 17.0** | `:18212-18223` |
| `TextFieldLink` | **`@available(tvOS, unavailable)`** | `:8624-8628` |

Everything above is at or below the app's tvOS 18.0 deployment target, so no target change is
implied by any of it.

**`TextField` is the name of the API**, and on tvOS it is the only SwiftUI primitive that accepts
free text. `.searchable` is the higher-level alternative and is also available.

### 3.3 The focus-engine and placement constraints, from the SDK

**(a) Only one search-field placement exists on tvOS.** `SearchFieldPlacement.automatic` is the
sole usable value; `.toolbar`, `.toolbarPrincipal`, `.sidebar`, `.navigationBarDrawer` and
`.navigationBarDrawer(displayMode:)` are **all** `@available(tvOS, unavailable)`
(`SwiftUI.swiftinterface:8830-8852`). **Where a `.searchable` field appears is SwiftUI's decision,
not the app's.**

**(b) On tvOS a search must have a separate results view — UIKit says so in words.**

> `UISearchController.h:61` — "Pass nil if you wish to display search results in the same view that
> you are searching. **This is not supported on tvOS; please provide a results controller on
> tvOS.**"

**(c) `UISearchBar` cannot be created standalone on tvOS.** Its three initialisers are all
`API_UNAVAILABLE(tvos)` (`UISearchBar.h:48-50`), and `searchTextField` is unavailable too (`:58`).
It exists on tvOS only as `UISearchController.searchBar`.

**(d) The documented tvOS container is `UISearchContainerViewController`** (tvOS 9.0):

> `UISearchContainerViewController.h:17` — "Use this container view controller for
> `UISearchController` containment or presentation on tvOS"

and `obscuresBackgroundDuringPresentation` defaults differently inside it
(`UISearchController.h:79`).

**(e) tvOS puts suggestions *under the keyboard*, and has a dedicated callback for them.**
`UISearchController.searchSuggestions` is documented as *"List of search hint objects to be
displayed under keyboard on tvOS"* (`UISearchController.h:132-139`, tvOS 14.0), with
`updateSearchResultsForSearchController:selectingSearchSuggestion:` — *"Called when user selects one
of the search suggestion buttons displayed under the keyboard on tvOS"* (`:54-55`, tvOS 14.0).

**(f) The tvOS keyboard is not an inline layout participant, and cannot be observed.** Every
keyboard notification is unavailable on tvOS — `UIKeyboardWillShowNotification`,
`DidShow`, `WillHide`, `DidHide`, `WillChangeFrame`, `DidChangeFrame`, and every
`UIKeyboardFrame*`/`Animation*` user-info key (`UIWindow.h:132-146`) — and so is
`UIKeyboardLayoutGuide` (`UIKeyboardLayoutGuide.h:14`) and `UIView.keyboardLayoutGuide`
(`UIView.h:305`). **Nothing in this app's layout can move for the keyboard, and nothing can learn
that it appeared.** That is consistent with the tvOS keyboard being a presented surface rather than
a pane, but the SDK asserts the unavailability, not the presentation model — see §7.

**(g) `UITextField` itself is fully available on tvOS** (`UITextField.h:53`); only the edit-menu
delegate callbacks are excluded (`:197`, `:205`). So a `UIViewRepresentable` route exists if
SwiftUI's own field proves unsuitable.

**(h) The only other typed-entry surface in TVUIKit is digits-only.**
`TVDigitEntryViewController` (`TVDigitEntryViewController.h:12-44`, tvOS 12.0) takes a fixed
`numberOfDigits` (default 4) and calls back with a digit string. Not usable for a show title.

**(i) The app's own focus vocabulary is all present on tvOS** and is what a search screen would use:
`.focused($state, equals:)`, `.defaultFocus` (tvOS 16, `:4122-4123`), `.focusSection()` (`:11846`),
`.prefersDefaultFocus(_:in:)` (`:16511`).

**Does it work with the Siri Remote's on-screen keyboard?** The SDK establishes that tvOS has an
on-screen keyboard machinery distinct from iOS's (points b, e, f above), that `TextField` and
`.searchable` are both compiled for tvOS, and that `TVDigitEntryViewController` exists as a separate
digits-only surface. It does **not** state, anywhere I could read, that focusing a SwiftUI
`TextField` on tvOS summons that keyboard. That is runtime behaviour — see §7.

---

## 4. The design

### 4.1 The grep, in full

Over `design/Marlin DVR TV.dc.html` (1,411 lines), case-insensitive:

| Term | Hits |
|---|---|
| `search` | **1** — `dc:38` |
| `keyboard`, `keypad`, `qwerty` | **0** |
| `magnify`, `ph-magnif` | **0** |
| `input` | **0** |
| `type-to`, `results` | **0** |

### 4.2 The one hit says the opposite of a search screen

`dc:38` is a line in the design page's own header, in the row of standing facts under the
introduction:

```
dc:36-40   <div style="… font-size:23px; color:var(--color-neutral-500)">
dc:37        <span>16 playable channels · 5 DRM channels hidden</span>
dc:38        <span>No search · no live pause buffer · no server-side resume</span>
dc:39        <span>Resume position kept by the app</span>
```

**"No search" is a statement of scope by the design itself, not a frame.**

### 4.3 The frames, and the two data arrays, confirm it

The dc.html draws **twenty** frames; their ids and line numbers:

```
1b dc:50    2a dc:115   3a dc:173   3b dc:235   3c dc:295
4a dc:370   4b dc:397   5a dc:431   5b dc:495   5c dc:541
5d dc:583   5e dc:649   5f dc:690   5g dc:764   6a dc:860
6b dc:882   6c dc:917   6d dc:955   7a dc:1011  8a dc:1029
```

None is a search, keyboard or results frame.

- **The rail data lists nine destinations and Search is not one of them:**
  `dc:1133-1137` — `Home, Favorites, On Now, Guide, On Later, Recordings, Cameras, Weather, Radio`.
- **The Home tile data lists nine tiles and Search is not one of them:**
  `dc:1353-1362` — `Guide, On Now, On Later, Recordings, Cameras, Favorites, Weather, Radio,
  Settings`.

### 4.4 The other two files that matched are the design tooling, not the design

For completeness, `grep -ril search design/` also names `support.js` and `image-slot.js`. Every hit
in them is Claude Design's own runtime and has nothing to do with this app's UI:

```
support.js:1374     new URLSearchParams(… location.search …)
image-slot.js:8,42,59   the "search_stock_photos" tool
image-slot.js:138-142   u.searchParams.has / .set('utm_source'…)
image-slot.js:576       "// this gate a keyboard user could drive them on a read-only share"
```

### 4.5 Plainly stated

**The approved design draws no search screen, no keyboard, no search field and no results frame,
and says in its own header that there is no search.** A search screen would be an addition to the
approved design — the same route Manage DVR, Favorites, the radar, Radio and the commercial-skip
prompt each took (COLD-START.md, Pass 10; DECISIONS.md 2026-09-06 (Pass 13), 2026-09-06 (Pass 19),
2026-09-08 (Pass 38)), each of which the owner authorised explicitly and each of which was built to
the app's look rather than designed first.

---

## 5. Placement — every rail entry and Home tile, and what an addition costs

### 5.1 The rail, in order

Source of the order: `Destination.railOrder` at **`Destination.swift:26`**; rendered by
`ForEach(Destination.railOrder)` at **`RailView.swift:44`**.

| # | Entry | `case` | `label` | `railSymbol` | `isBuiltNow` | Screen |
|---|---|---|---|---|---|---|
| 1 | Home | `Destination.swift:21` | `:33` | `:51` | `false` (`:97`) | leaves the shell — `ScreenShell.swift:43-44` |
| 2 | Favorites | `:21` | `:34` | `:52` | `true` (`:96`) | `ScreenShell.swift:89` |
| 3 | On Now | `:21` | `:35` | `:53` | `true` (`:96`) | `ScreenShell.swift:90` |
| 4 | Guide | `:21` | `:36` | `:54` | `true` (`:96`) | `ScreenShell.swift:91` |
| 5 | On Later | `:21` | `:37` | `:55` | `true` (`:96`) | `ScreenShell.swift:92` |
| 6 | Recordings | `:21` | `:38` | `:56` | `true` (`:96`) | `ScreenShell.swift:93` |
| 7 | Cameras | `:21` | `:39` | `:57` | `true` (`:96`) | `ScreenShell.swift:94` |
| 8 | Weather | `:21` | `:40` | `:58` | `true` (`:96`) | `ScreenShell.swift:96` |
| 9 | Radio | `:21` | `:41` | `:59` | `true` (`:96`) | `ScreenShell.swift:97` |
| 10 | Manage DVR | `:21` | `:43` | `:62` | `true` (`:96`) | `ScreenShell.swift:95` |

`settings` is a `Destination` case (`:21`, label `:42`, symbol `:60`, `isBuiltNow == false` at
`:97`) but **is not in the rail** — it is a Home tile only. The design's rail lists nine and
Settings is not among them (`dc:1133-1137`), which is why Pass 10B put Manage DVR in the bottom
slot (`Destination.swift:11-15`; DECISIONS.md 2026-09-06 sweep 4). Pass 24 photographed the rail
and counted the same ten (`reports/2026-09-06-pass24-rail-focus-recon.md` §2.1).

### 5.2 The Home tiles, in order

Source of the order: `Destination.homeTiles` at **`Destination.swift:29`**; laid out three to a row
by `stride(from: 0, to: count, by: 3)` at **`HomeView.swift:188-190`** and rendered at `:192-206`.

| # | Tile | `label` | `tileSymbol` | `tileTint` | Sub-line source |
|---|---|---|---|---|---|
| 1 | Guide | `Destination.swift:36` | `:70` (default → `railSymbol`) | `:77` | `HomeView.swift:47` — "N channels live" |
| 2 | On Now | `:35` | **`:69`** (`play.circle`) | `:78` | `HomeView.swift:60` — "N programs live" |
| 3 | On Later | `:37` | `:70` | `:79` | `HomeView.swift:68` — "N upcoming" |
| 4 | Recordings | `:38` | `:70` | `:80` | `HomeView.swift:76` — "N recordings · M recording now" |
| 5 | Cameras | `:39` | `:70` | `:81` | `HomeView.swift:83` — "N of M online" |
| 6 | Favorites | `:34` | `:70` | `:82` | `HomeView.swift:50-52` — "N favourite channels" |
| 7 | Weather | `:40` | `:70` | `:83` | static `Destination.swift:107` — "Local weather" |
| 8 | Radio | `:41` | `:70` | `:84` | `HomeView.swift:98`, falling back to `Destination.swift:108` |
| 9 | Settings | `:42` | `:70` | `:85` | static `Destination.swift:109` |

`manage` is **not** a Home tile — `tileTint` returns the neutral surface for it and for `home`, with
the comment "Neither is a Home tile; the tint is never drawn for them" (`Destination.swift:86-87`).

### 5.3 What adding a rail entry involves

Reported, not recommended. Seven places, of which two are one-line and none is large:

1. **`Destination.swift:21`** — a new `case` on the enum. It is `CaseIterable`, so nothing else
   enumerates it implicitly.
2. **`Destination.swift:26`** — insert into `railOrder` at the chosen position. That array alone
   fixes the rail's order; `RailView.swift:44` iterates it and nothing else.
3. **`Destination.swift:32-44`** — a `label`. The switch is exhaustive with no `default`, so the
   compiler demands it.
4. **`Destination.swift:49-63`** — a `railSymbol` (an SF Symbol; nothing is bundled, DECISIONS.md
   2026-09-05 sweep 1). Exhaustive, so demanded.
5. **`Destination.swift:75-88`** — a `tileTint`. Exhaustive, so demanded **even for a rail-only
   entry**; `manage` sets the precedent at `:87` of returning the neutral surface with a comment
   saying it is never drawn.
6. **`Destination.swift:94-99`** — `isBuiltNow`. Exhaustive. This is the gate in **both** entry
   points: `ScreenShell.swift:45` for the rail and `ContentView.swift:32` for Home.
7. **`ScreenShell.swift:86-100`** — a `case` in the `content` builder returning the new screen.
   This switch **does** have a `default` (`:98` → `PlaceholderScreen`), so a missing arm compiles
   and silently draws the placeholder rather than failing the build.

`tileSymbol` (`:67-72`) and `staticTileSubtitle` (`:105-112`) both have `default` arms and need
nothing. `RailView.swift` needs **no** change: it reads `railOrder`, `label` and `railSymbol`
generically (`:44`, `:138-145`, `:152`).

**Two consequences of an eleventh entry worth naming:**

- **The collapsed rail's geometry shifts.** Pass 24 measured the collapsed strip as ten 64 pt icons
  on a flat 76 pt pitch, centres running 160.0 → 844.0 (`reports/2026-09-06-pass24-rail-focus-recon.md`
  §4.2; `RailView.swift:41`, `:154`). An eleventh lands near 920, and the expanded rail's last entry
  (Manage DVR, measured at y = 739 height 34) moves to about 802 — inside the 60 pt bottom margin
  (`Theme.swift:61`) with the two-line footer (`RailView.swift:97-104`) still to fit. **That is
  arithmetic off Pass 24's measured frames, not a measurement**; it wants a screenshot before
  anyone relies on it.
- **It does not reopen Pass 24's landing problem.** Pass 25's restore is keyed on identity, not
  geometry — `ScreenShell.railRestore` sets `focus = .rail(current)` on the crossing into the rail
  (`ScreenShell.swift:68-81`) — so a new entry lands on itself like the other nine, regardless of
  where its icon sits. Pass 24's nearest-centre rule only governed the app **before** that restore
  existed.

### 5.4 What adding a Home tile involves

1. **`Destination.swift:29`** — insert into `homeTiles`.
2. **`Destination.swift:75-88`** — a real `tileTint`, because it *is* drawn here
   (`HomeView.swift:249-251`).
3. A sub-line: either a static one at `Destination.swift:105-112`, or a loaded one written into
   `HomeModel.subtitles` in `load()` (`HomeView.swift:35-104`). The precedence is
   **loaded wins, static is the fallback** — flipped in Pass 20 for exactly this reason
   (`HomeView.swift:29-33`; DECISIONS.md 2026-09-06 (Pass 20)).
4. `tileSymbol` needs nothing unless the tile wants a different glyph from its rail icon
   (`Destination.swift:67-72`).

**The grid stops being square.** `HomeView.swift:188-190` builds rows of three from
`homeTiles.count`, which is exactly **9** today — three full rows. A tenth tile makes a fourth row
holding **one** tile, stretched by `.frame(maxWidth: .infinity)` on each element of the `HStack`
(`HomeView.swift:193-207`, `:210`). The design draws nine in three rows (`dc:1353-1362`) and says
nothing about a tenth.

**Home has no rail to come back to** (`dc:111`; DECISIONS.md 2026-09-07 (rail focus)), so a Home
tile alone would give a search screen no way back except Menu — which `ScreenShell.swift:61` maps to
"return to Home", so that works, but it is a different shape of navigation from every rail screen.

**No recommendation is made here, per the brief.**

---

## 6. What a search screen would collide with, and what it could reuse as-is

### 6.1 Reusable unchanged

| Piece | Where | Note |
|---|---|---|
| `AiringSheet` | `AiringSheet.swift:48` | takes four parameters; nothing in it is Guide-specific |
| `AiringSelection` + `artPath` | `:32-46` | the `/api/art/show?title=` path and its 404 fallback |
| `PosterFallback` | `:478-490` | needs `channel.initials` + `channel.logoBg` |
| `StateChip` | `:447-475` | the non-focusable "● Recording" / "● Scheduled" |
| `GuideMark` and its two colours | `GuideScreen.swift:21-44` | green/gold, `dc:1183-1189` |
| `ScreenHeader`, `PillLabel`, `InertActionButton`, `LoadingLine`, `ErrorLine`, `focusTreatment`, `focusSoon` | `ScreenChrome.swift:13, 86, 168, 129, 139, 62, 122` | every screen's shared chrome |
| `APIClient.get(_:query:)` | `ServerAPI.swift:71-75` | already takes `[URLQueryItem]`, so `?q=` needs no new plumbing |
| The DRM `.playable` filters | `ChannelFilter.swift:13-27` | a new `[FindRow]` overload would follow the same four |
| `APIClient.channels`, `.schedule` | `ChannelFilter.swift:32-38`, `:66-74` | §2.3(a) and (c) |
| `TimeFormat` | `Formatting.swift` | the app already formats its own day/time everywhere; `find`'s `when` and `duration` are the server's strings |
| `HoldButton` / `RemoteHold` | `RemoteHold.swift:159-196`, `:39-83` | if a result row should answer a click-and-hold |

### 6.2 Real collisions

**(a) `AiringSheet` has no Menu handling of its own. The host screen closes it.**
The sheet carries `.focusSection()` (`AiringSheet.swift:160`) and no `.onExitCommand` anywhere; the
Guide's own handler does the work, in a three-way priority with the channel menu and the "snap back
to now" case:

```
GuideScreen.swift:314-332   if channelMenu != nil { … } else if model.sheet != nil {
                                model.sheet = nil
                                Task { … focused = lastCell }        // :320-323
                            } else if !model.isAtNow { … } else { onLeave() }
```

A search screen must write the equivalent, including restoring focus to the result row the sheet was
opened from — `lastCell` (`GuideScreen.swift:197`, tracked at `:310-312`) is the Guide's own
bookkeeping and does not come for free.

**(b) `onScheduleChanged` is not a detail.** §2.4 above. Without the re-read plus the re-join, the
sheet's Record/Stop writes leave it with a stale `Job` and the "Stop recording" button can outlive
the recording — the precise failure `AiringSheet.swift:417-420` was written to avoid.

**(c) The window-level hold recognizer is app-wide and is suspended only for the Player.**

```
ContentView.swift:43   .background { RemoteHoldDetector(hold: hold).frame(width: 1, height: 1) }
ContentView.swift:46   .onChange(of: playRequest?.id) { _, id in hold.suspended = id != nil }
RemoteHold.swift:122-128   UILongPressGestureRecognizer, minimumPressDuration 0.5,
                           allowedPressTypes = [.select], installed on the UIWindow
RemoteHold.swift:54        guard !suspended else { return }
```

It fires on **any** half-second Select anywhere in the app that is not the Player — including,
potentially, dwelling on a key of an on-screen keyboard. It only *does* anything on a screen that
watches `hold.holds` (`GuideScreen.swift:313`, `OnNowScreen.swift`, `ShowDetailScreen`), and the
Guide is not on screen while search is, so `GuideScreen.handleHold` cannot misfire. **But a search
screen that watches holds, or a search field hosted inside the Guide, would.** There is no
suspension mechanism for anything other than the Player today.

**(d) `ScreenShell.railRestore` fires on any crossing into the rail.**

```
ScreenShell.swift:60   .onChange(of: focus) { _, landed in railRestore(landed) }
ScreenShell.swift:68-81  guard case .rail(let entry) = landed else { railHasFocus = false; return }
```

If a keyboard is a presented surface, focus leaving the shell and returning may read as a crossing
and re-run the restore. Harmless if it lands on the right entry; a focus jump if it does not.
**Unknown — runtime, see §7.**

**(e) `ScreenShell` rebuilds content on every screen change.** `content.id(current)`
(`ScreenShell.swift:51`) means leaving a search screen and coming back destroys and re-creates it —
the query text, the results and the scroll position all go. That is how every screen behaves today
and it is what makes `RecordingsScreen`'s shelves correct after a delete (COLD-START.md, Pass 31),
but a half-typed query vanishing on a rail round trip is a behaviour someone should decide about
rather than discover.

**(f) The sheet is a sibling in a `ZStack`, and the screen behind it is disabled.**

```
GuideScreen.swift:245, :274, :290   ZStack { … ScrollView … .disabled(model.sheet != nil …) ; AiringSheet(…) }
```

That is the pattern to copy; a `.sheet`/`.fullScreenCover` presentation would be new ground in this
app outside the Player (`ContentView.swift:48`).

**(g) The sheet card is a fixed 1400 × 586 pt** (`AiringSheet.swift:236`) and assumes the full
screen behind it, including the 180 pt collapsed rail. It will render identically over a search
screen; nothing to change, but worth knowing before anyone tries to inset it.

**(h) `Program` and `MergedChannel` decode strictly.** Fourteen of `MergedChannel`'s fifteen fields
are non-optional (`Models.swift:16-33`), four of `Program`'s are (`Models.swift:44-47`). Pass 26 §4
is the standing note on what that means: a shape change fails the whole screen. Any new decodable
for `find` should follow the same habit — the `TrashItem`/`TrashResponse` pair is the model to copy
(`Models.swift:298-334`): strict on the item, lenient on the array.

---

## 7. What I could not determine, and why

1. **Whether a SwiftUI `TextField` on tvOS 26.5 summons the Siri Remote's on-screen keyboard, and
   what that does to focus.** The SDK proves `TextField` compiles for tvOS
   (`SwiftUI.swiftinterface:5020-5021`) and that tvOS has a keyboard machinery of its own
   (`UISearchController.h:54-55, :132-139`; `UIWindow.h:132-146`), but no header states the
   binding. It needs a build and a device run; this pass builds nothing.
2. **Whether `.searchable` renders at all in this app's view tree.** The app has **no**
   `NavigationStack`, `NavigationView`, `NavigationSplitView` or `TabView` anywhere (grep, §3.1),
   and `.searchable`'s only tvOS placement is `.automatic` (`SwiftUI.swiftinterface:8830-8834`),
   whose resolution is undocumented in the interface. Runtime.
3. **Whether SwiftUI's `.searchable` on tvOS is backed by `UISearchController`**, and therefore
   whether `UISearchController.h:61`'s "please provide a results controller on tvOS" constrains it.
   Not stated in either SDK.
4. **Whether the keyboard suppresses or swallows the window-level press recognizer**
   (`RemoteHold.swift:122-128`). Runtime.
5. **What this owner's guide actually holds forward in time.** §1.4 gives the mechanism; the number
   would come from `GET /api/guide/find` or `GET /api/guide/stats` against the running server, which
   is on the do-not-touch list. The 27,897-programmes figure is the marlin-dvr project's reading,
   cited as theirs.
6. **How often the `/api/guide` omission (§2.3 b-i) would bite in practice on the owner's own
   sources.** The 3.1 % is the marlin-dvr project's measurement on Philo listings over 24 hours; no
   equivalent measurement exists for his HDFX-4K or Verizon sources, and making one means reading
   the server.
7. **Whether `/api/guide/search` is a safe substitute in the worst case.** It is uncapped
   (`guide.go:843`); a very common title could return a large body. Unmeasured from here.

---

## 8. Open questions for the owner

1. **Is a search screen wanted at all, given that the approved design says "No search"
   (`dc:38`)?** Every screen not in the design so far — Manage DVR, Favorites, the radar, Radio, the
   commercial-skip prompt — was authorised by name first. This one would be the sixth.
2. **Where should it live: a rail entry, a Home tile, both, or somewhere else?** §5 gives the cost
   of each without recommending. An eleventh rail entry is seven small edits; a tenth Home tile
   breaks the 3 × 3 grid the design draws.
3. **Which route reconstitutes the airing — `/api/guide` (holed at about 3 %, §2.3 b-i) or a new
   decoder for `/api/guide/search` (uncapped, richer, not in the app)?** This is the single decision
   that most changes the build, and it is not a builder's call: option one ships a known hole that
   the server project has already declined to fix; option two adds a route to this app.
4. **Should search results hide DRM channels?** `find` returns them with `drm: true`
   (`guide.go:888`) while the standing rule is that DRM channels never appear in any list
   (`ChannelFilter.swift:5-8`). Filtering is the obvious reading of the rule, but it means a search
   for a show that only airs on a DRM channel returns nothing with no explanation.
5. **What should the screen say when `count` exceeds 20?** The server intends "showing the first N
   of M" (their `DECISIONS.md`, Pass 45) and the cap is not pageable (§1.6). The alternative is to
   show 20 silently.
6. **Should search match more than the title?** The route does not (§1.3). Matching episode titles
   or descriptions would need a server change, which is a marlin-dvr decision under the standing
   rule.
7. **Is a server change worth raising at all** — e.g. `find` echoing the airing's full `Program`, or
   a `limit` parameter — so the app needs one read instead of three? Raised here as a question, not
   as work; nothing has been asked of the marlin-dvr project.
8. **What should happen to a half-typed query when the remote goes to the rail and comes back?**
   `ScreenShell.swift:51` destroys the screen (§6.2 e).

---

## 9. The things I am least sure of

1. **The rail-height arithmetic in §5.3.** It is derived from Pass 24's measured frames, not
   measured this pass. An eleventh entry *ought* to fit; nobody has seen it.
2. **That `/api/guide/search` is immune to the `/api/guide` omission.** The reasoning is that it
   walks `programsFor` directly (`guide.go:834-840`) and never touches the block builder, which is
   the same structure `find` uses — and the marlin-dvr project's own note says the Search "reads the
   guide directly" and finds those airings (their `COLD-START.md:1265-1266`). That is inference from
   two readings of the source, not a measurement.
3. **Whether splitting `channelId` on `":"` reliably yields the guid.** `sources.go:319` composes it
   as `s.ID + ":" + c.GUID`, and a source id containing a colon would break a naive split. I did not
   read how source ids are generated.
4. **The `seriesId` consequence.** A `Program` rebuilt from a `find` row has no `seriesId`, so
   `AiringSheet.matchingPass` (`:340-350`) falls through to its `"title:<lower>"` and plain-title
   arms. For XMLTV listings the server *derives* `SeriesID = "title:" + lower(title)` when the
   listing has no `dd_progid` (`guide.go:264-266`), so those are unaffected; HDHomeRun listings carry
   a real `SeriesID` (`guide.go:438`) and would match on title only. **I believe "Record the series"
   still works and matches the server's own fallback order** (the comment at `AiringSheet.swift:325-327`
   says the server compares the same three), but I did not read `passes.go` to confirm it, and the
   sheet would also be posting `POST /api/passes` with `seriesId: nil` (`:376`).
5. **Everything in §3 about the keyboard's *behaviour*.** The availability facts are exact, from
   named headers. The behavioural reading around them is inference, and §7 names it as such.
6. **One thing I noticed while grepping `design/` and did not pursue**, because it is outside this
   pass: **the dc.html contains frame ids `6a`–`6d` only** (`dc:860`, `:882`, `:917`, `:955`), while
   the notebook and earlier reports cite "the Player (states 6a–6h)", "frame 6e" and "frame 6g"
   (COLD-START.md; `reports/2026-09-05-pass4-design-and-build-recon.md` §3.10). `grep -n 'id="6[e-h]"'`
   returns nothing. **Not investigated, not changed, and raised only because it bears on how far any
   design citation can be trusted.**

---

## 10. SCOPE CHECK — every path touched, and how

| Path | What happened to it |
|---|---|
| `Marlin DVR TV/**` (`AiringSheet`, `GuideScreen`, `Destination`, `ScreenShell`, `RailView`, `HomeView`, `ContentView`, `Models`, `ChannelFilter`, `ServerAPI`, `ScreenChrome`, `RemoteHold`, `PlayRequest`, `Theme`, `OnNowScreen`, `EditSeriesPassScreen`) | **read only** |
| `Marlin DVR TV.xcodeproj/project.pbxproj` | **read only** (deployment target) |
| `Marlin DVR TVUITests/**` | **read only** (grep for typing) |
| `design/Marlin DVR TV.dc.html`, `design/support.js`, `design/image-slot.js` | **read only** — never edited |
| `COLD-START.md`, `DECISIONS.md`, `CLAUDE.md`, `reports/…pass4…`, `…pass24…`, `…pass26…` | **read only** |
| `~/Xcode/marlin-dvr-reference` | **read only, via `git show origin/main:<path>` only** — `cmd/marlin-dvr/guide.go`, `main.go`, `sources.go`, `system.go`, `HLS-CLIENT-API.md`, `COLD-START.md`, `DECISIONS.md`. **Nothing checked out, nothing fetched, nothing edited, nothing run.** Three files were copied into the session scratchpad to read with line numbers; the clone itself was not written to. |
| `AppleTVOS26.5.sdk` (SwiftUI `.swiftinterface`, UIKit and TVUIKit headers) | **read only** |
| `reports/2026-09-11-pass62-guide-search-recon.md` | **new** — this report |

**No app source was changed, no Swift file was created, no project setting was edited, no build was
run, and no commit was made.** No request was made to 192.168.1.250, 192.168.1.245, 192.168.1.105 or
the UNAS4Pro share, and no other folder under `~/Xcode` was read or written. No credential, token or
device id appears above.
