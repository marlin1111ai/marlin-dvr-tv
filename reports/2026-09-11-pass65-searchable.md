# Pass 65 — the search screen on `.searchable` — 2026-09-11

**Result: the search input is tvOS's own inline search, and the results list is on screen the
whole time you type.** The hand-built `TextField` and all of its chrome are gone. Everything else
about the screen is Pass 63's, unchanged: the results, the DRM filter, the "first 20 of N" line,
the query surviving a trip to the rail, the sheet wiring, and the rail entry under Radio.

**Five harness tests, 0 failures, 404.0 s**, on Home Theater with the real Siri Remote. No server
write.

**Nothing was pushed.** The owner tests this on Home Theater first.

**Two measured answers that were open questions before this pass:**

- **The sheet-close focus rebuild is still needed** (§2). It was taken out, the device said
  `focused=[]`, and it went back in. Not assumed either way.
- **The keyboard strip is not pinned** (§4). Partway down the list it has scrolled off the top of
  the screen, and getting back to it means walking up the list one row at a time.

**Citation keys.** `File.swift:NN` = line NN in this repo as this pass leaves it.
`dc:NN` = `design/Marlin DVR TV.dc.html` (read only, never written). Screenshots are
`reports/assets/pass65/`. Base commit: `1107b12` (Pass 63).

---

## 1. Step 1 — `.searchable` replaces the hand-built field

`GuideSearchScreen.swift:252`:

```swift
.searchable(text: $model.query, placement: .automatic, prompt: "Type a title")
```

on the screen's content `VStack`, with the airing sheet still a `ZStack` sibling over it.

**What was deleted**, all of it Pass 63's and all of it now tvOS's job: the `HStack` wrapper, the
magnifier glyph, the `TextField` itself, `.textFieldStyle(.plain)`, the `focusTreatment`, the
1000 pt frame, the `Nocturne.surface` background, and the focus-following ink fix that existed
only because tvOS paints its own field capsule light on focus. **23 lines out, one line in.**

`Self.fieldFocusID` is gone with it, and `restoreFocusID` (`:215-219`) is now `String?` — it
returns nil when there is no row to land on, because `.searchable`'s field belongs to tvOS and
this app has no `@FocusState` binding that can reach it. The `.task` only assigns when it is
non-nil (`:255`).

**Kept exactly as Pass 63 built it:** the 400 ms debounce (`:91-111`), the model, both decoders,
the DRM filters, the count line, the row, the sheet wiring, `ChannelFilter.swift`,
`Destination.swift` and `ScreenShell.swift`. `.automatic` is the only tvOS placement, and Pass 64
proved no `NavigationStack` is needed.

---

## 2. Step 2 — is the sheet-close rebuild still needed? **YES. Measured, not assumed.**

Pass 63 found that writing the row's id into `@FocusState` after the sheet closes does not move
the focus engine, and fixed it by bumping a `generation` counter that rebuilds the content
subtree (`:229`, `:253-256`, `:312-315`). `.searchable` changes the focus topology — the keyboard
strip is now a sibling above the list — so this pass took the rebuild out and let the device
judge.

**Build A — rebuild removed**, replaced with the plain assignment done properly (clear to nil
first, then set the row id behind `focusSoon`):

```
SEARCH focus after closing the sheet: []
DUMP[after-sheet] keyboards=1 keys=29 searchFields=1
DUMP[after-sheet] focused=[]
✗ testTypeATitleOpenAResultAndDriveTheSheet — "nothing at all has focus after the sheet closed"
```

Identical to Pass 63's original failure. `.searchable` changed nothing about it.

**Build B — rebuild restored**, the code this pass ships:

```
DUMP[after-sheet] focused=["9:NBC Nightly News With Tom Llamas, 11.1 WBAL-DT · Fri 6:30 PM · 30m"]
SEARCH focus after closing the sheet: ["9:NBC Nightly News With Tom Llamas, …"]
✓ byte-equal to the row that was focused before the sheet opened
```

**The machinery stays**, and its doc comment now records this second measurement so nobody
removes it a third time on reasoning (`:305-311`).

---

## 3. Step 3 — where `.searchable` puts the field relative to the header

**Above it, and nothing is obscured.** No stop-and-report. Measured frames, from
`testWhereTheSearchChromeSitsRelativeToTheHeader`:

| Element | Frame (x, y, w, h) | Vertical extent |
|---|---|---|
| tvOS search field | `(504, 59.8, 1768, 70.3)` | y 60 – 130 |
| tvOS keyboard strip | `(254, 164.5, 1760, 66)` | y 164 – 231 |
| **the app's `ScreenHeader` title "Search"** | `(428, 305.5, 157, 62.5)` | y 306 – 368 |
| the header's subtitle | `(613, 330, 325.5, 31.5)` | y 330 – 362 |
| the count / idle line | `(428, 394, 661.5, 31.5)` | y 394 – 426 |

The header clears the strip by **75 pt**. Screenshot `20-search-on-open.jpg` and
`26-results-for-news-keyboard-still-up.jpg`.

**One measurement trap worth recording:** `app.staticTexts["Search"].firstMatch` matches the
**rail's** Search entry at `(156, 740.5, …)`, not the screen header. The first run of this test
asserted against the wrong element and passed for the wrong reason. The harness now filters by
`frame.minX > 200`, the content area's left edge, and prints every candidate.

**The consequence is cosmetic and is raised, not fixed** (§8.1): the screen now reads
"🔍 *Type a title*" at the very top and then "**Search** · Programme titles in the guide" below
it — two headings for one screen. Redesigning the header was outside this pass.

---

## 4. Step 4 — is the keyboard reachable from partway down a long list?

**Reachable, but only by walking back up the list, and it is not on screen while you are down
there.** Measured with "news" (20 rows, more than fit) in
`testTheKeyboardIsReachableFromPartwayDownTheList`:

- **Eight Down presses** from the strip put focus on the ninth row. At that point:
  `keyboard.frame=(158, -141, 1760, 66)` — **negative y: the strip has scrolled off the top of
  the screen entirely.** `22-partway-down-the-list.jpg` shows it: the app's own header and count
  line are still there, tvOS's field and strip are gone.
- **One Up press goes to the previous row, not the keyboard.**
  `WMAR-2 News at 7PM → WJZ News at 7PM`, `keyboardReached=false`
  (`23-one-up-from-partway-down.jpg`).
- **It took 1 + 7 = eight Up presses in total** to get back to the strip — one per row, the whole
  way (`24-back-at-the-keyboard-strip.jpg`).

So: the strip is **not a pinned header**. It scrolls with the page, and there is no single press
that jumps back to it. Both runs of this test measured the same eight. **This is reported, not
worked around** — no scroll-position or focus-jump machinery was built.

---

## 5. Step 5 — the harness

`GuideSearchUITests.swift` rebuilt for the layout: five tests, all driven by `XCUIRemote`, no
server write. The changes forced by the new layout:

- **Getting to the input is Right-then-Up, not Select.** `reachTheKeyboard` (`:106-124`) crosses
  from the rail and walks up, returning how many Up presses it took. There is no Select that
  summons a keyboard any more.
- **Rows are matched on their label**, not position — `resultRowLabels()` (`:71-73`) takes buttons
  whose label carries both a comma and the row's " · " separator, so the count line and the rows
  can move without breaking the harness again.
- **Two new tests for steps 3 and 4**, above.
- **Every test now asserts the keyboard survives**: `keyboards > 0` while typing and again after
  focus enters the list.

---

## 6. Step 6 — driven on Home Theater

`testTypeATitleOpenAResultAndDriveTheSheet`, and the whole suite, **5 tests / 0 failures /
404.0 s**:

| Step | Evidence |
|---|---|
| Search opens | `25-search-empty-query.jpg`; strip already up, `keyboards=1 keys=29` |
| Right reaches the input | `REACH[main] keyboard reached after 0 Up press(es)` |
| type "news" with the list visible | `26-results-for-news-keyboard-still-up.jpg`; `keyboards=1` throughout; `Showing the first 20 of 695 matches · type more of the title to narrow it`; 20 rows listed by title, channel, time and length |
| Down into the first result | lands on a row, **`keyboards=1` still** — the strip did not go |
| Select opens the sheet | `27-sheet-from-a-search-result.jpg` — NBC Nightly News With Tom Llamas, `NEW` chip, `11.1 · WBAL-DT · HD`, `S02E236`, `Today 6:30 – 7:00 PM`, real poster art, three controls |
| the sheet's controls are live | focus on open = `Record this airing`; **Down keeps it there** (results behind are disabled); **Right moves to `Record the series`** (`28-sheet-focus-moved.jpg`) |
| Menu closes the sheet, not the screen | `29-back-on-the-results.jpg`; count line still there |
| focus returns | byte-equal to the row the sheet was opened from |

The other three: the query and its rows survive a trip to the rail **string- and
element-identical** (`32-after-the-rail-trip.jpg`); `zzqqxx` gives `No airings match “zzqqxx”.`
(`33-no-matches.jpg`); the expanded rail still carries eleven entries with Search under Radio
(`31-the-expanded-rail.jpg`).

---

## 7. Scope check — every path touched

| Path | What happened | Step |
|---|---|---|
| `Marlin DVR TV/GuideSearchScreen.swift` | `.searchable` in, the hand-built field out; `restoreFocusID` optional; the rebuild kept with its re-measurement recorded; header comment brought current | 1, 2 |
| `Marlin DVR TVUITests/GuideSearchUITests.swift` | rebuilt for the layout, plus the step 3 and step 4 tests | 3, 4, 5, 6 |
| `reports/2026-09-11-pass65-searchable.md`, `reports/assets/pass65/` | **new** | 7 |
| `reports/2026-09-11-pass64-keyboard-layout-probe.md`, `reports/assets/pass64/` | **new** — the report Pass 64 deferred | 7 |
| `Marlin DVR TV/Models.swift`, `ChannelFilter.swift`, `Destination.swift`, `ScreenShell.swift`, `ContentView.swift`, `Marlin_DVR_TVApp.swift`, `AiringSheet.swift` | **untouched** | — |
| `design/`, `COLD-START.md`, `DECISIONS.md`, `CLAUDE.md` | **not written** — see below | — |
| `~/Xcode/marlin-dvr-reference` | **not touched at all** this pass | — |

**Why the notebook is not updated.** The same reason as Pass 63: this pass's steps name reports
and a commit, scope lock binds changes as well as builds, and the project's pattern is that the
pass recording the owner's acceptance writes the notebook (DECISIONS.md 2026-09-09 (Pass 60) rule
(b)). Nothing here is accepted or pushed, so `COLD-START.md` and `DECISIONS.md` are as Pass 61
left them — and they still do not mention Pass 62, 63, 64 or 65.

No request was made to 192.168.1.245, 192.168.1.105 or the UNAS4Pro share; the app read
192.168.1.250:8090 with GETs only, as it always does. No credential, token or device id appears
in this report or in any file this pass adds.

---

## 8. Open questions for the owner

1. **Two headings.** tvOS now draws a search field at the very top and the app draws its own
   "Search / Programme titles in the guide" below it. Should the app's header title be dropped,
   the subtitle kept on its own, or left as is? Not changed — the brief said to report the
   placement, not redesign the header.
2. **The keyboard strip scrolls away** (§4). Getting back to it from deep in a list is eight
   presses. Worth doing something about, or is Menu-and-retype the expected gesture?
3. **The prompt text is now the only instruction at the top.** "Type a title" sits in tvOS's
   field; the app's own "Type a title. Search matches the title only, from now forward." line is
   further down, below the header. Should the two be reconciled?
4. Pass 63's open questions all still stand: silent DRM filtering, `Watch live` from a search
   result closing the sheet rather than playing, `/api/guide/search` being uncapped, and
   title-only matching.

---

## 9. The things I am least sure of

1. **That the rebuild is load-bearing for the *right* reason.** Two device runs say focus dies
   without it and lives with it. Why the focus engine ignores a plain `@FocusState` write here is
   still not established — Pass 63 could not explain it either, and this pass only re-confirmed
   the symptom.
2. **How the screen behaves with a query typed while the list is already scrolled.** Every
   measurement typed from the top. If new results arrive while the strip is off screen, where
   focus lands is unmeasured.
3. **Whether eight Up presses is a constant or a function of scroll depth.** Both runs scrolled
   exactly eight rows down and took eight back; nobody tried twelve.
4. **`GuideScreen` may still carry the same latent focus defect** this screen has now been fixed
   for twice. Raised in Pass 63 §9.1, still not investigated, still out of scope.
5. **That `.searchable`'s chrome cannot be styled.** Pass 64 found no way in and this pass did not
   try again; the claim rests on that.
