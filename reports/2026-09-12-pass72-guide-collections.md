# Pass 72 — Guide channel collections

**Date:** 2026-09-12
**Base commit:** `2206a92` (Pass 71, "Guide collections recon").
**Result: built, proven on Home Theater, committed locally, NOT pushed.** Four of the five items
landed complete. The fifth — step 5's **device proof** of the empty-collection state — **stopped on
the condition the step itself set**, and §5 below is that report.

**Server traffic.** The five requests this pass made by hand are all **GET**: `/api/status`,
`/api/collections`, and three `/api/guide?…` reads. The app, driven on the device, sent **GET**
`/api/guide`, `/api/schedule` and `/api/collections` — and, on each of its launches, the
`POST /api/clients/{id}/ping` it has sent on every launch since sweep 1
(`ClientSession.swift:62-81`). **That ping is the only non-GET request in this whole pass**; it is
the app's standing behaviour, not this pass's, and it writes nothing but the device's own
last-seen record. **Nothing was ever POSTed, PUT or DELETEd to `/api/collections`,
`/api/clients/{id}/ui`, the lineup, the library or the schedule** — no collection was created,
renamed, reordered, emptied or deleted, and no recording or pass was touched. `~/Xcode/marlin-dvr-reference` was read with `git rev-parse`, `git show` and `sed` only —
never edited, never fetched, never checked out. `design/` was not opened by this pass and not
written. Unraid `192.168.1.250` as a host, marlinpc, the HDHomeRun and the UNAS4Pro share were not
touched.

**No credential, token, device id or client id appears in this report.** The ids quoted are lineup
and collection identifiers (`hdhr-10a75953:2.1`, `col-1788571411827`), the same form already
committed throughout `reports/`. Nothing required redaction.

---

## 1. What was built, step by step

### Step 1 — `ScreenHeader` gains one optional slot

`Marlin DVR TV/ScreenChrome.swift:13-65`. The slot renders **between the title and the subtitle**
and defaults to nothing.

**It is two initialisers, not one defaulted parameter, and that was not a style choice.** The first
attempt gave `accessory` a default alongside `trailing`, which put two closure parameters in one
initialiser. Every existing `ScreenHeader(…) { … }` call then compiled through Swift's **deprecated
backward matching** — one `warning: backward matching of the unlabeled trailing closure is
deprecated` per call site, eleven of them, with the closure bound to whichever parameter happened to
be last rather than to the one meant. Reordering the parameters did not fix it; it moved the target,
so the same callers would have bound their pills to `accessory` — the wrong slot, a visible
regression. The fix is a no-accessory initialiser constrained `where Accessory == EmptyView`, which
leaves exactly one closure parameter for those eleven callers to forward-match, and a second
initialiser taking both, labelled at the one call site that uses it. **The build is clean: zero
deprecation warnings, and `xcodebuild` reports no new warning of any kind.**

**Every other caller renders byte-identically, and that was measured rather than asserted.** The
same two screens were photographed on Home Theater from **HEAD's code** and from **this pass's**,
through the identical harness:

| Screen | Element | Before (`2206a92`) | After (this pass) |
|---|---|---|---|
| On Later | title | `(236.0, 60.0, 191.0, 62.5)` | `(236.0, 60.0, 191.0, 62.5)` |
| On Later | subtitle | `(455.0, 84.5, 478.5, 31.5)` | `(455.0, 84.5, 478.5, 31.5)` |
| Cameras | title | `(236.0, 60.0, 201.0, 62.5)` | `(236.0, 60.0, 201.0, 62.5)` |
| Cameras | subtitle "1 of 1 online" | `(465.0, 84.5, 130.5, 31.5)` | `(465.0, 84.5, 130.5, 31.5)` |

Identical to the point. `assets/pass72/before-72h1-on-later.jpg` against
`after-72h1-on-later.jpg`, and `before-72h2-cameras.jpg` against `after-72h2-cameras.jpg`: the two
pairs differ in **one glyph each** — On Later's live clock reading `12:37 AM` in one and `12:39 AM`
in the other, which is `TimeFormat.clock(Date())` in that screen's own trailing slot, not layout.
An `EmptyView` in an `HStack` is no subview and takes no spacing.

The eleven callers that pass nothing: `CamerasScreen:68`, `GuideSearchScreen:236`,
`ManageDVRScreen:148`, `FavoritesScreen:75`, `OnNowScreen:135`, `PassesManageView:64`,
`OnLaterScreen:47`, `RecordingsScreen:91`, `ScheduleManageView:102`, `RadioScreen:72`,
`TrashManageView:40`. **None of them was edited.**

### Step 2 — the collections button

`GuideScreen.swift:413-428`, in the accessory slot, on the Guide only. Label "All Channels" with
nothing selected, otherwise the collection's `name`. Same `PillLabel`, same `BareButtonStyle`, same
`.focusSection()` as "↩ Now" and "+12h"; `active: collections.selectedId != nil` marks that a filter
is on.

**It is drawn whatever the grid holds** — before the first fetch, on an error, and on an empty
collection — which is what makes it safe as the focus fallback in step 5.

Measured header geometry on the device: title `(236.0, 60.0, 133.0, 62.5)`, button
`(397.0, 79.5, 163.5, 43.5)`, date range `(588.5, 84.5, 324.5, 31.5)` — **"Guide", then the button,
then the date range**, the owner's order, with the design's 28 pt gaps.

**Focusable from the grid and from the rail by the same path the pills use.** From a grid cell it is
**one Up press**. Coming in from the rail it is **Right, then Up — two presses** — the same two the
pills take. Every press is traced in `REACH[…]` lines in the run log.

### Step 3 — the drop-down

`GuideCollections.swift:115-191`, `CollectionsMenu` — the app's own overlay, modelled directly on
`ChannelActionsMenu.swift:17-95` as the owner required: dimmed `LinearGradient` backdrop, an 860 pt
`Nocturne.surface` card, `MenuRow` rows, `.focusSection()`, `.onExitCommand`. **Not `Menu`, not
`Picker`, not `.sheet`.**

- lists **"All Channels" first**, then every collection from `GET /api/collections` **in the
  server's order**, showing `name` only;
- **the read happens when the overlay opens** — `.task` at `:182-190`;
- **focus lands on the current selection.** One task does it in order rather than an `.onAppear`
  racing the read: the All Channels row is drawn from the first frame and takes focus at 60 ms, then
  the read lands and focus moves to the selection if it has a row. **Nothing on the overlay is ever
  unfocused**, which matters because an unfocused screen is one whose Menu press leaves the app
  (`TrashManageView.swift:58-62`, Pass 33);
- **Select applies and closes**; **Menu closes with no change** (`:178`, and the host also handles it
  at `GuideScreen.swift:355-356`, mirroring how `ChannelActionsMenu` is handled);
- **a collection whose `channelIds` is empty is listed** — nothing filters the list, which is the
  absence of code rather than a branch;
- **a failed read** shows "All Channels" alone plus a one-line **"Collections unavailable"** row that
  is focusable and does nothing (`:149-156`).

Measured on the device: `All Channels, Showing` at `(652.0, 488.5, 772.0, 67.0)` and `Local` at
`(652.0, 577.5, 772.0, 67.0)` — All Channels first, and it held focus on open.

### Step 4 — the reload

`GuideScreen.swift:126` — `api.guide(start: start, slots: Self.fetchSlots, filter: collections.selectedId)`.

**All three callers of the private `fetch(from:)` carry the selection by construction**, not by three
separate edits: the filter is read from the shared model inside `fetch`, so `loadNow()` (`:103`),
`pageForward()` (`:109`) and `snapToNow()` (`:121`) cannot diverge. "All Channels" is `nil` and sends
**no `filter` parameter at all**. Choosing one re-runs the fetch **at the current window start**
(`reloadForCollection()`, `:113-116`), so a pick does not move the clock.

- **`↩ Now`, `+12h` and `endOfListings` behave as today against the filtered rows** — they are
  unchanged code operating on whatever `rows` holds.
- **Client-side DRM filtering stays in force**: `ChannelFilter.swift:67` still applies `.playable` to
  every guide response, filtered or not. The server does not drop DRM channels from a collection
  (`sources.go:321` carries `mc.DRM` through and no `case` arm tests it), so this is the only thing
  that does.
- **A member id appearing twice is shown once, first occurrence kept** — `GuideScreen.swift:129-134`,
  `rows = g.channels.filter { seen.insert($0.id).inserted }`. The server stores duplicates and
  returns two rows with the same channel (`sources.go:396-400`); `GuideRow.id` is the channel id and
  the grid is a plain `Identifiable` `ForEach`, which duplicate ids break. **Unexercised in the
  owner's data** — the five member ids are distinct — so this is code-traced, not seen.

### Step 6 — persistence

`GuideCollections.swift:26-108`. `GuideCollectionsModel` is created by the app
(`Marlin_DVR_TVApp.swift:32`) and passed down through `ContentView` and `ScreenShell` to the Guide,
exactly as `GuideSearchModel` and `HomeModel` are — because `.id(current)` at `ScreenShell.swift:55`
destroys `GuideScreen` and its `GuideModel` on **every** rail visit.

**One new `UserDefaults` key: `"marlinGuideCollection"`** — the fourth this app writes, after
`marlinClientId`, `marlinResume.<id>` and `marlinWeatherFix`. Its value is JSON `{"id","name"}`.

**Why the name is stored beside the id, which the step did not ask for.** The step requires the
button to read the collection's name and the Guide to open on the saved collection after a relaunch;
step 3 pins the collections read to the moment the overlay opens, which may never come. Without the
cached name the button would read "All Channels" over a filtered grid on the first frame after every
relaunch — verify item (g) would show rows filtered to Local under a button saying otherwise. It is
still **one key**, and the id is still the only thing that reaches `filter=`. **Stated plainly here
as the one addition this pass made beyond the literal text of a step.**

**A stale id reverts silently and clears the key** — `reconcile()`, `:99-107`, run after each
collections read. This is load-bearing rather than tidy: §5 below.

### Step 7 — re-focus after a filtered reload: **the existing mechanism was enough**

**The plain `@FocusState` assignment behind `focusSoon` was tried first and measured, as the step
required. It worked. No generation-counter rebuild was added to the Guide.**

`GuideScreen.swift:388-396` — `pick(_:)` stores the selection, awaits the reload, then
`focusSoon { focused = firstCellID ?? "collections" }`. The device's focused-element evidence, across
**six** row-replacing reloads:

| Reload | Focus after |
|---|---|
| choose Local (375 rows → 5) | `["9:Jimmy Kimmel Live!"]` |
| `+12h` while filtered | `["9:College Football"]` |
| `↩ Now` (Menu) while filtered | `["9:Jimmy Kimmel Live!"]` |
| choose All Channels (5 → 375) | `["9:Jimmy Kimmel Live!"]` |
| rail round trip to Radio and back | `["9:Jimmy Kimmel Live!"]` |
| kill and relaunch | `["9:Jimmy Kimmel Live!"]` |

**Never empty, in any of them, in either full run of the harness.** That is the opposite of what the
Search screen measured twice (`GuideSearchScreen.swift:295-311`, `FOCUSALL[after-sheet] []`).

**Why the Guide differs from Search, as far as this pass can tell — and this is inference, not
measurement.** Search's failing case restores focus to a row that existed *before* the sheet opened,
after a subtree that was never torn down; the Guide's case replaces `model.rows` and then names a
cell id computed from the **new** rows, so the focus engine is being pointed at a view that has just
been created rather than at one it has already decided about. I did not test that hypothesis — what
is established is the behaviour, six times over.

**One related change was needed.** The fallback was `firstCellID ?? "page"`, and `"page"` names the
`+12h` button, which is **not drawn** once `endOfListings` is true — and with an empty collection
neither header pill is drawn at all (Pass 71 §6.2b). It is now `firstCellID ?? "collections"`, at
`:347`, `:368`, `:395` and `:435`. The collections button is drawn whatever the grid holds.

### Step 8 — the notebook

`DECISIONS.md` gained **2026-09-12 (Pass 72 — channel collections in the Guide)**. `COLD-START.md`
gained the Passes 71-72 entry in "What is built", the `GuideCollectionsUITests` harness entry with
its run line, and a new first paragraph under "Next step" recording that this commit is unpushed.

**The two corrections, and exactly what changed in each.**

- **`COLD-START.md:37-38`** said *"The server is marlin-dvr 1.8.0 (owner, 2026-09-08)"*. It now says
  **1.8.1**, measured here: `GET /api/status` →
  `{"name":"marlin-dvr","version":"1.8.1","uptime_seconds":15816,"port":8089}`. **One clause beyond
  the version number was dropped**, and it has to be named: *"Not measured from here — the running
  server is on this project's do-not-touch list — so this is the owner's own reading, cited the way
  this file cites the marlin-dvr project's other version facts."* That sentence was the citation for
  the old fact and is false of the new one, which **is** measured from here. The owner's 1.8.0
  reading is kept, as superseded.
- **`COLD-START.md:67-68`** said the reference clone's checked-out tree was *"still at 1.2.1"* and
  its `origin/main` read `095de81`. Verified in the clone: `cmd/marlin-dvr/main.go:38` reads
  `appVersion = "1.8.1"`, and `HEAD` and `origin/main` both read **`eb0c098`**. The clause *"which
  has none of this — checking it out is the owner's job and no pass has done it"* went with it,
  necessarily: it is checked out. The earlier SHAs are kept as history.

**Nothing else in either file was reworded.**

---

## 2. Files touched, mapped to step numbers

| File | Step(s) | What |
|---|---|---|
| `Marlin DVR TV/ScreenChrome.swift` | **1** | `ScreenHeader` gains the `accessory` slot and a second initialiser |
| `Marlin DVR TV/Models.swift` | **3** | `ChannelCollection`, `CollectionsResponse` (`:41-54`) |
| `Marlin DVR TV/ChannelFilter.swift` | **3** | `APIClient.collections()` (`:71-79`) |
| `Marlin DVR TV/GuideCollections.swift` | **3, 6** | **new** — `GuideCollectionsModel` and `CollectionsMenu` |
| `Marlin DVR TV/GuideScreen.swift` | **2, 3, 4, 5, 7** | the button, the overlay, the filter, the empty line, the re-focus |
| `Marlin DVR TV/Marlin_DVR_TVApp.swift` | **6** | the model is created here |
| `Marlin DVR TV/ContentView.swift` | **6** | passed through |
| `Marlin DVR TV/ScreenShell.swift` | **6** | passed to `GuideScreen` |
| `Marlin DVR TVUITests/GuideCollectionsUITests.swift` | **VERIFY** | **new** — the device harness; test target only, nothing in the app target |
| `COLD-START.md`, `DECISIONS.md` | **8** | the notebook, and the two corrections |
| `reports/2026-09-12-pass72-guide-collections.md`, `reports/assets/pass72/` | deliverable | this report and its 18 screenshots |

`git diff --stat` over the tracked files: **9 files, 304 insertions, 31 deletions**, plus the two new
untracked Swift files, this report and the assets.

**Not touched:** the Xcode project file (both targets are filesystem-synchronised groups, so the two
new files need no project edit), `Info.plist`, the entitlements file, every build setting, the asset
catalog, `design/`, `icon-source/`, every earlier report, and every other screen in the app. **No new
dependency. No hardening, refactor or config change. No test-only code in the app target.**

---

## 3. VERIFY — the device evidence

Home Theater (Apple TV 4K, tvOS 26.6), `GuideCollectionsUITests`, all five tests, **TEST SUCCEEDED**,
run twice in full — once before the step-1 initialiser fix and once after, with identical results.
Screenshots in `reports/assets/pass72/`.

**(a) The header.** `72a-guide-header-all-channels.jpg` — **Guide · [All Channels] ·
Sat Sep 12 · 12:30 – 2:30 AM**, with `+12h` still hard right. Frames in §1 step 2. Focus on the
button reached in one Up press from the grid, two from the rail
(`72a2-collections-button-focused-from-the-rail.jpg`).

**(b) The overlay.** `72b-overlay-open.jpg` — the card lists **All Channels** (focused, marked
"Showing") then **Local**. `72b2-overlay-closed-by-menu.jpg` — Menu closed it, the selection is
unchanged, and focus is back on the button (`["9:All Channels"]`).

**(c) The filtered grid.** `72c-grid-filtered-to-local.jpg`. Button reads **Local**. **Counted by
hand from the screenshot: five rows, and five only** — WMAR-HD 2.1, WGAL-TV 8.1, WBAL-DT 11.1,
WJZ-TV 13.1, ESPN 50007, top to bottom. Beside it, the live
`GET /api/guide?filter=col-1788571411827&slots=1` read at the same sitting:

```
channelCount: 5   dayLabel: Sat, Sep 12   start: 1789185600
  1 hdhr-10a75953:2.1    2.1     WMAR-HD  drm=False hidden=False | Jimmy Kimmel Live!
  2 hdhr-10a75953:8.1    8.1     WGAL-TV  drm=False hidden=False | The Tonight Show Starring Jimmy Fallon
  3 hdhr-10a75953:11.1   11.1    WBAL-DT  drm=False hidden=False | The Tonight Show Starring Jimmy Fallon
  4 hdhr-10a75953:13.1   13.1    WJZ-TV   drm=False hidden=False | Comics Unleashed With Byron Allen
  5 marlin-cast:9287     50007   ESPN     drm=False hidden=False | SportsCenter
```

**Same five, same order.** The harness also asserts positively that **WBFF45 (45.1) and CWWNUV
(54.1) are absent** while filtered and present unfiltered. Button count 375 → **39**.

**(d) `+12h` then `↩ Now` while filtered.** `72d-plus-12h-while-filtered.jpg` — window
**12:30 – 2:30 PM**, button still **Local**, the same five channels, the `↩ Now · 12:42 AM` pill now
drawn. `72d2-back-at-now-while-filtered.jpg` — Menu snapped back to now and the rows are identical to
(c), asserted element by element.

*One thing in that screenshot that is not a defect and not this pass's:* at 12:30 PM the four antenna
rows carry no programme block. **That is the server's data, not the filter.** Measured both ways at
`start=1789228800&slots=1`: unfiltered, `channelCount: 91`, and those four rows have
`withProgram=0`; filtered, `channelCount: 5`, and the same four have `withProgram=0`. Byte-for-byte
the same behaviour with and without a collection.

**(e) Back to All Channels.** `72e-grid-back-to-all-channels.jpg` — the full grid returns, button
count back to **375**, WBFF45 and CWWNUV drawn again.

**(f) A trip to the rail.** `72f0` → `72f1-radio.jpg` → `72f2-back-on-the-guide-still-filtered.jpg`.
Out to the rail, down five to Radio, open it, back up five to the Guide, back in: button still
**Local**, the same five rows in the same order, no non-member drawn.

**(g) Kill and relaunch.** `72g0-filtered-before-the-relaunch.jpg`, then `app.terminate()`, a fresh
`app.launch()`, and one Select on Home's first tile:
`72g-guide-opens-on-local-after-a-relaunch.jpg` — **the Guide opens on Local**, five rows, button
reading Local.

**(h) Two unchanged screens.** `before-72h1-on-later.jpg` / `after-72h1-on-later.jpg` and
`before-72h2-cameras.jpg` / `after-72h2-cameras.jpg`, with the frame table in §1 step 1.

**(i) Step 5's empty state — STOPPED.** §5.

**Focus evidence for every step** is in the table in §1 step 7 and in the `DUMP[…] focused=` and
`REACH[…]` lines of the run log; **no step ended with nothing focused**.

---

## 4. The harness, and one thing worth knowing before anyone runs it

`GuideCollectionsUITests` **creates, changes or deletes nothing on the server**. It never opens the
airing sheet, never records, never touches a collection. Its only non-GET traffic is the app's own
launch ping (above), once per `app.launch()`. It leaves the device on **All Channels**.

**Every query in it is a predicate, never an enumeration, and that is not a style preference.** The
Guide's grid is a plain `VStack` inside a `ScrollView`, so **all 91 channel rows are realised at
once** — `app.buttons.count` reads **375** unfiltered. The first version of this harness used
`app.descendants(matching: .any).allElementsBoundByIndex.filter(\.hasFocus)`, copied from
`GuideSearchUITests`, where it is fine because that screen is small. On the Guide it resolves 585+
elements at roughly **0.8 s each**: the first run was killed at **t = 1317 s** still walking the
tree, and a second at t = 908 s. Rewritten to
`matching(NSPredicate(format: "hasFocus == YES"))` plus targeted `label ENDSWITH ", <channel
number>"` lookups, the same five tests take **47-87 s each**.

A second thing cost a run: the helper that walks to the header treated anything above **y = 260** as
the header, and the grid's **first row starts at y = 238**. The header band is `y < 200` — the title
draws at 60-122 and the pills at 79-123.

---

## 5. Step 5 — built, and STOPPED on its proof

**What is built.** `GuideScreen.swift:279-287`: when the Guide has loaded, has no rows, and a
collection is selected, the grid draws one **non-interactive** line, `Nothing in <name> right now`,
in `Nocturne.neutral500`. Focus is not left to chance — every reload path ends
`focusSoon { focused = firstCellID ?? "collections" }`, and the collections button is drawn whatever
the grid holds, so the remote lands there and Menu still works.

**Why it is not proven on the device.** The step said: *"use `filter=<a made-up id>` only if the
server returns an empty envelope for it; if the server returns the full lineup for an unknown id
(the Pass 71 finding), STOP on this sub-step, report it, and finish the rest."*

**Measured live on 2026-09-12, GET only:**

```
$ curl -sS "http://192.168.1.250:8090/api/guide?filter=col-does-not-exist-pass72&slots=1"
HTTP 200
channelCount: 91
rows returned: 91
first rows: hdhr-10a75953:2.1 2.1 WMAR-HD | hdhr-10a75953:8.1 8.1 WGAL-TV |
            hdhr-10a75953:11.1 11.1 WBAL-DT | hdhr-10a75953:13.1 13.1 WJZ-TV |
            hdhr-10a75953:45.1 45.1 WBFF45 | hdhr-10a75953:54.1 54.1 CWWNUV | …
```

**The whole lineup — 91 rows, the same count the unfiltered guide returns.** Pass 71 §3.2 fact 4
predicted this from `sources.go:362-364`: a filter that is not one of the four built-in words and
matches no collection leaves `coll` nil, matches no `case` arm, applies **no predicate**, and returns
everything. It is now measured against the running 1.8.1 server rather than read from source.

**So the condition for the made-up-id proof is not met, and this sub-step stops.** No substitute was
attempted, and each alternative is named with why:

- **Emptying "Local" and looking** — a `PUT /api/collections/{id}`. A write, forbidden.
- **Creating an empty collection** — a `POST`. A write, forbidden.
- **Hiding all five members, or adding a DRM channel** — writes to the lineup, and outside this
  pass's scope in any case.
- **A test-only hook in the app** — explicitly forbidden ("No test-only code left in the app
  target").

**What this means for the owner.** The empty state is code-traced and unseen. The path to seeing it
is one action on the admin page — create a collection with no channels in it, or take every channel
out of one — after which the harness would show it in a single run. **Everything else in step 5 is
built and in the commit.**

**One consequence of the same server behaviour is built and does matter today.** Because an unknown
filter returns the full lineup silently, a collection deleted on the admin page would leave this
Apple TV showing all 91 channels under a button still reading the old name, with no error anywhere.
`reconcile()` (`GuideCollections.swift:99-107`) is what prevents that: on the next collections read,
a saved id the server no longer has reverts to All Channels and the key is cleared. **That path is
also unproven on the device** — proving it needs a collection to be deleted, which is a write.

---

## 6. Open questions

Raised, not acted on.

1. **The overlay does not scroll.** `CollectionsMenu` is a `VStack` in a fixed-width card with no
   `ScrollView` and no height cap. With one collection it fits with room to spare. With enough
   collections the card would run off the screen. Not built, because the step described a list and
   scrolling it was not named.
2. **The "Collections unavailable" state is unproven.** It needs the server to fail a single GET at
   the moment the overlay opens. Not simulated — that would have meant test-only code or pointing the
   app somewhere else.
3. **The empty-collection state and the stale-id revert are unproven**, both for the reasons in §5.
   Each needs one admin-page action by the owner.
4. **Should the collection reach `GET /api/guide/now` and `GET /api/channels`?** Both honour
   `filter`, both are already called by this app (Home, On Now, Favorites, Search). The approved
   design says the Guide only, so nothing else was touched. Pass 71 open question 8, still open.
5. **A collection the owner names "Favorites", "HD", "Non-HD" or "All Channels"** is reachable by this
   app, because the app sends the id — but its own row would read the same as the built-in
   All Channels row in the overlay. Not handled; no such collection exists.
6. **`icon` is read from the server and dropped.** `GET /api/collections` returns a Phosphor class
   (`ph-house`); the step said the overlay shows `name` only, so `ChannelCollection` decodes `id` and
   `name` and nothing else.
7. **`icon-source/` is still untracked**, 32 entries, the owner's undecided call. Restated so it is
   not mistaken for drift.

---

## 7. The three things I am least sure of

1. **That the Guide's plain re-focus holds in cases this pass did not run.** Six row-replacing
   reloads landed on a real cell, twice over — that is measurement and I stand on it. What I cannot
   tell you is whether it holds when the reload lands on **zero** rows, which is the one case the
   server would not let me produce (§5). That path falls back to `"collections"`, and the button is
   certainly drawn, but the assignment itself has not been watched with an empty grid. It is also the
   path where a stranded remote would matter most.
2. **That storing the collection's name beside its id is what the owner wants.** The step named one
   key holding the id; I put `{"id","name"}` in that one key because without the name the button
   reads "All Channels" over a filtered grid for the whole of the first Guide visit after every
   relaunch, and verify item (g) asks to see the Guide "open on Local". It is the one place I went
   past the literal text of a step, and it is the one decision in this pass I would most like
   overruled if I read it wrong.
3. **That the two unchanged screens generalise to the other nine.** I photographed On Later and
   Cameras — the two the step asked for — before and after, and their frames match to the point. The
   other nine callers go through the same initialiser and the same `EmptyView` layout, so I believe
   they are equally unchanged, but I did not photograph them. `OnNowScreen` and `GuideSearchScreen`
   are the two whose headers differ most in shape from those I did check.

---

## 8. Git

One commit on `main`, on top of `2206a92`: the code, the two new files, the notebook, this report and
its screenshots together, per the Pass 68 rule that a pass's report goes in its own commit.

**The commit is local and unpushed.** The owner tests it on Home Theater first; that is the standing
separate push gate. Nothing forced, no history rewritten, no branch other than `main`.
