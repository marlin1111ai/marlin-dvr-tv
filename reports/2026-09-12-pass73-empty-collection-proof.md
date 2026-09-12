# Pass 73 — the empty-collection state, proven

**Date:** 2026-09-12
**Base commit:** `9f5505e` (Pass 72, "Guide channel collections").
**Result: proven on Home Theater. All four verify items landed. No app-target code changed, and
nothing was corrected, because the built behaviour matched Pass 72's spec in every particular.**

Pass 72 built the empty-collection state and could not see it: the only way to make the server
return an empty filtered guide was a write, and the made-up-id substitute failed because an unknown
filter returns the whole lineup. **The owner has since created a collection with no channels in it**,
so this pass chose it on the device and photographed the state.

**Server traffic.** Three requests by hand, all **GET**: `/api/collections`, `/api/status`, and
`/api/guide?filter=col-1789211011169&slots=1`. The app, driven on the device, sent **GET**
`/api/guide`, `/api/schedule` and `/api/collections`, and on each launch the
`POST /api/clients/{id}/ping` it has sent since sweep 1 (`ClientSession.swift:62-81`) — **eight
launches in this run**, six from `setUp` and two from the two tests that relaunch. **That ping is
the only non-GET request in the whole pass**; it is the app's standing behaviour, not this pass's.
**Nothing was POSTed, PUT or DELETEd to `/api/collections`** — no collection was created, renamed,
reordered, emptied or deleted — nor to the lineup, the library or the schedule.
`~/Xcode/marlin-dvr-reference` was not opened. `design/` was not opened and not written. Unraid
`192.168.1.250` as a host, marlinpc, the HDHomeRun and the UNAS4Pro share were not touched.

**No credential, token, device id or client id appears in this report.** The ids quoted are lineup
and collection identifiers, the same form already committed throughout `reports/`. Nothing required
redaction.

---

## 1. Step 1 — `GET /api/collections`, trimmed to `id`, `name`, `channelIds`

```
{
  "id": "col-1788571411827",
  "name": "Local",
  "channelIds": [
    "hdhr-10a75953:2.1",
    "hdhr-10a75953:8.1",
    "hdhr-10a75953:11.1",
    "hdhr-10a75953:13.1",
    "marlin-cast:9287"
  ]
}
{
  "id": "col-1789211011169",
  "name": "Test",
  "channelIds": []
}
```

**Two collections, exactly one of them empty**, which is the condition step 1 set before anything
else could run. **EMPTY = "Test", `col-1789211011169`**, `count: 0`, `icon: ph-stack`. "Local" is
unchanged from Pass 72 — the same five member ids in the same order. Server `1.8.1`
(`GET /api/status`), uptime 41,601 s.

**The empty collection produces a genuinely empty guide envelope**, which is the fact Pass 72 could
not obtain:

```
$ curl -sS "http://192.168.1.250:8090/api/guide?filter=col-1789211011169&slots=1"
HTTP 200
channelCount: 0
channels: []            <- an empty list, not null and not absent
dayLabel: Sat, Sep 12   start: 1789210800   slots: 1   nowIndex: 0.313…
```

**This is a different server behaviour from the one Pass 72 measured, and both are now on the
record.** A filter naming a collection that exists but holds nothing returns **zero rows**; a filter
naming an id the server has never heard of returns **all 91** (`sources.go:362-364`, measured in
Pass 72). The second is the silent-failure case, and it is why `reconcile()`
(`GuideCollections.swift:99-107`) exists. **This pass does not make `reconcile()` redundant and does
not prove it** — proving it needs a collection deleted, which is a write.

---

## 2. Step 2 — the device run

Home Theater (Apple TV 4K, tvOS 26.6), `GuideCollectionsUITests`, **six tests, 0 failures,
454.786 s, `** TEST SUCCEEDED **`**. The new test is
`testAnEmptyCollectionDrawsItsOwnLineAndKeepsTheRemote` (104.4 s); Pass 72's four ran again as a
regression on the helper edits, and with a second collection now present on the server:

| Test | |
|---|---|
| `testAnEmptyCollectionDrawsItsOwnLineAndKeepsTheRemote` | **passed** (104.386 s) — new |
| `testChoosingACollectionFiltersTheGridAndComingBack` | passed (79.632 s) |
| `testTheCollectionSurvivesARelaunch` | passed (70.748 s) |
| `testTheCollectionSurvivesATripToTheRail` | passed (72.273 s) |
| `testTheHeaderButtonAndTheOverlay` | passed (81.611 s) |
| `testTwoUnchangedScreens` | passed (46.136 s) |

The only compiler warnings in the run are the two standard
`appintentsmetadataprocessor … No AppIntents.framework dependency found` lines. **No warning from
this pass's code.**

### (a) The overlay lists the empty collection, and choosing it filters the grid

```
EMPTY overlay row=“Test” (652.0, 622.0, 772.0, 67.0)
CHOOSE[pick-empty] “Test” has focus after 2 step(s): ["9:Test"]
```

Three rows now — **All Channels, Local, Test**, in the server's order, All Channels first. Two Downs
from All Channels reaches Test. **An empty collection is listed like any other**, which is the
absence of code rather than a branch (Pass 72 step 3).

### (b) The single line, and the proof that it is the only thing drawn

`reports/assets/pass73/73a-nothing-in-the-empty-collection.jpg`.

```
DUMP[73a-empty] collectionsButton=Test
DUMP[73a-empty] focused=["9:Test"]
DUMP[73a-empty] buttonsOnScreen=12
DUMP[73a-empty] localMembersDrawn=[]
DUMP[73a-empty] nonMembersDrawn=[]
EMPTY line exists=true frame=(236.0, 222.5, 277.0, 31.5)
```

**A full enumeration of the screen**, which is the only way to show the *"and nothing else"* half of
the claim:

```
SCREEN[73a-empty] text “Guide”                                        (236.0, 60.0, 133.0, 62.5)
SCREEN[73a-empty] text “Sat Sep 12 · 7:00 – 9:00 AM”                  (506.5, 84.5, 314.0, 31.5)
SCREEN[73a-empty] text “CHANNEL”                                      (236.0, 157.0, 127.5, 27.5)
SCREEN[73a-empty] text “7:00 AM · now”                                (554.0, 157.0, 161.5, 31.5)
SCREEN[73a-empty] text “7:30 AM”                                      (878.5, 157.0, 96.5, 31.5)
SCREEN[73a-empty] text “8:00 AM”                                     (1203.0, 157.0, 98.5, 31.5)
SCREEN[73a-empty] text “8:30 AM”                                     (1527.5, 157.0, 98.5, 31.5)
SCREEN[73a-empty] text “Nothing in Test right now”                    (236.0, 222.5, 277.0, 31.5)
SCREEN[73a-empty] text “●” / “Recording or set to record”             (236.0 / 267.5, 936.5)
SCREEN[73a-empty] text “◆” / “Covered by a series pass”               (557.5 / 589.5, 936.5)
SCREEN[73a-empty] text “Starts at the current half hour · forward only” (1413.5, 936.5)
SCREEN[73a-empty] button “Home” … “Edit”        — eleven rail icons, x ≈ 80-144
SCREEN[73a-empty] button “Test”                                        (397.0, 79.5, 81.5, 43.5) FOCUSED
```

**Twelve buttons on the entire screen, eleven of them the rail.** Between the column header and the
legend there is **one** element, and it is the line. Counted by eye from the screenshot as well: the
grid area is empty.

**Neither header pill is drawn, and that is the point of Pass 72's fallback change.** `+12h` is
absent because `endOfListings` is true when no row carries a programme, and `↩ Now` is absent
because the window is at now. The harness asserts `+12h`'s absence positively. **The collections
button is the only focusable thing in the content area** — which is exactly why
`firstCellID ?? "page"` had to become `firstCellID ?? "collections"`.

### (c) The focused element is the collections button

```
EMPTY focused=["9:Test"]
```

Element type 9 is Button, label "Test", and the enumeration above marks that same button `FOCUSED`
at `(397.0, 79.5, 81.5, 43.5)` — inside the header band (`y < 200`), which is what separates it from
the overlay row that reads the same. `reports/assets/pass73/73b-focus-on-the-collections-button.jpg`.

**Honest note on that screenshot: it is byte-identical to 73a** — the two calls are one after the
other with nothing changing between them, so the picture adds nothing to 73a. **The focus evidence
here is the accessibility measurement, not the photograph**, though the pill does carry its focus
ring in both.

### (d) Select opens the overlay from there; Local brings the five rows back

```
EMPTY overlay focused=["9:Test, Showing"]
CHOOSE[empty-to-local] “Local” has focus after 1 step(s): ["9:Local"]
DUMP[73d-local] collectionsButton=Local
DUMP[73d-local] focused=["9:Best Mattress Topper Ever!"]
DUMP[73d-local] buttonsOnScreen=28
DUMP[73d-local] localMembersDrawn=["WMAR-HD", "WGAL-TV", "WBAL-DT", "WJZ-TV", "ESPN"]
DUMP[73d-local] nonMembersDrawn=[]
```

`73c-overlay-opens-from-the-empty-grid.jpg` — the card over the empty grid, **Test focused and
marked "Showing"**. `73d-the-five-rows-return.jpg` — **all five, in the server's order**, buttons
**12 → 28**, the line gone, `+12h` drawn again, focus on the first cell. The harness asserts the
order element by element and asserts the line's absence.

### (e) A cold launch, with the empty collection remembered

`app.terminate()`, `app.launch()`, one Select on Home's first tile:

```
DUMP[73f-after-relaunch] collectionsButton=Test
DUMP[73f-after-relaunch] focused=["9:Test"]
DUMP[73f-after-relaunch] buttonsOnScreen=12
DUMP[73f-after-relaunch] localMembersDrawn=[]
DUMP[73f-after-relaunch] nonMembersDrawn=[]
RELAUNCH focused=["9:Test"]
REACH[empty-reset-out] the collections button has focus after 0 press(es): ["9:Test"]
```

**The second enumeration is element-for-element identical to the first — every label and every
frame, to the point.** `73f-empty-after-the-relaunch.jpg` is **byte-identical** to
`73e-empty-before-the-relaunch.jpg`, to 73a and to 73b: all four are sha256
`a6657243cce68f7a8cb1a2bad1c7ce7afbf69b7be22d596020029827121b516b`. Nothing on this screen animates
and no clock is drawn once `↩ Now` is absent, **so identical files are the expected result here and
not a capture error** — the 7:00 AM window label is the same in both because the run crossed no half
hour. **Zero presses** were needed to reach the button afterwards, which is the strongest form of
"the remote is not stranded on launch".

### (f) Step 3 — no difference from Pass 72's spec

Checked item by item against Pass 72's §5 and its DECISIONS entry: the line's text and placement,
its non-interactivity, the focus fallback to the collections button, the button being drawn whatever
the grid holds, the overlay listing an empty collection, the selection persisting. **Every one
behaved as specified.** Nothing was changed, and there is nothing to report under the stop-condition.

---

## 3. Files touched, mapped to step numbers

| File | Step(s) | What |
|---|---|---|
| `Marlin DVR TVUITests/GuideCollectionsUITests.swift` | **2** | one new test, plus three small helper changes named below |
| `COLD-START.md` | **4** | a Pass 73 entry in "What is built", and a new first paragraph under "Next step" |
| `DECISIONS.md` | **4** | `2026-09-12 (Pass 73 — the empty collection, proven on the device)` |
| `reports/2026-09-12-pass73-empty-collection-proof.md`, `reports/assets/pass73/` | deliverable | this report and its six screenshots |

**Step 1 touched no file** — it is three GETs. **Step 3 touched no file, which is its result.**

**Not touched: every file in the app target.** `git diff --stat` over the app target is empty. Also
untouched: the Xcode project file, `Info.plist`, the entitlements file, every build setting, the
asset catalog, `design/`, `icon-source/`, every earlier report, and Pass 72's own report.

**The notebook edits are additions only, verified by `git diff --numstat`: `COLD-START.md` 37
insertions / 0 deletions, `DECISIONS.md` 58 insertions / 0 deletions.** No existing line was
reworded, moved or removed — including the Passes 71-72 bullet that says the empty state "is built
and unproven", which is now superseded in place by the new entry directly beneath it and kept as
history.

### The harness change, in full

One test, `testAnEmptyCollectionDrawsItsOwnLineAndKeepsTheRemote`, and three helper changes it
needed:

1. **`emptyName = "Test"`** beside the existing `localName`, and the two helpers that identify the
   collections button (`collectionsButton()`, `focusIsOnTheCollectionsButton()`) learned the third
   label. Without it the button reading "Test" is invisible to the harness.
2. **`chooseRow` gained an optional `direction`.** The overlay opens with focus on the **current
   selection**, so the way to a row depends on which row is showing: from "Test", the last row, back
   up to "Local" is one **Up**, and the old rule — Down for anything but All Channels — would have
   pressed into the bottom of the list eight times and failed. **Left unset it behaves exactly as
   before**, and Pass 72's four tests pass nothing; all four passed again in this run.
3. **`enumerateScreen`, the one documented exception to the predicate-not-enumeration rule.** That
   rule is load-bearing — a loaded Guide realises 585+ elements at about 0.8 s each and the test
   never finishes — but it is a rule about a *loaded* Guide. With an empty grid the tree holds tens
   of elements, and **only a full listing can prove the "nothing else" half of the claim.** It is
   called twice, in the empty state only.

The harness still **creates, changes or deletes nothing on the server**, and still leaves the device
on All Channels.

---

## 4. Open questions

Raised, not acted on. Pass 72's six open questions 1, 2, 4, 5 and 6 are unchanged and are not
restated here; its **open question 3 is now half-closed**.

1. **The stale-id revert is still unproven, and it is the half of Pass 72's open question 3 that
   remains.** `reconcile()` reverts to All Channels and clears the key when a saved id is gone from
   the server. Proving it needs a collection **deleted** on the admin page while this Apple TV holds
   it — a write. This pass sharpened why it matters rather than closing it: an **unknown** filter
   still returns all 91 channels, so without `reconcile()` a deleted collection leaves the device
   showing everything under a button reading the old name, with no error anywhere.
2. **"Test" is a collection the owner made to test with.** Nothing in this pass or in the app
   depends on it continuing to exist — but `testAnEmptyCollectionDrawsItsOwnLineAndKeepsTheRemote`
   does, by name, and will fail if it is deleted or renamed. Noted so that failure is read correctly
   rather than as a regression.
3. **`icon-source/` is still untracked**, 32 entries, the owner's undecided call. Restated so it is
   not mistaken for drift.

---

## 5. The three things I am least sure of

1. **That an empty grid is harmless everywhere, not just where I looked.** I proved the two paths
   the step named — choosing the empty collection, and a cold launch onto it. **I did not press
   `+12h` or `↩ Now` from the empty state, because neither pill is drawn**, and I did not take a
   round trip to the rail while empty or open the airing sheet from it. Those are absences of a
   control rather than untested behaviour, but "the empty state is proven" should be read as **those
   two paths**, not as every path.
2. **That the byte-identical screenshots are as strong as they look.** Four of the six files are the
   same bytes. I have given the reason — nothing on that screen animates, no clock is drawn, and the
   window label did not roll over during the run — and the accessibility enumerations behind them are
   independent measurements taken at different moments, which is the evidence I would actually stand
   on. But if something had frozen the screen capture, this is the one result that would look
   identical either way, and the enumerations are what rule that out.
3. **That running Pass 72's four tests again proves my helper edits are harmless.** They passed, and
   that is real. What it does not isolate is that the server now holds **two** collections rather
   than one, so those four tests ran against a changed world at the same time as changed helpers.
   Both changes are small and the assertions are unchanged, but strictly this run varied two things
   at once, and I did not re-run them against the old helpers to separate the two.

---

## 6. Git

**One commit on `main`, local, NOT pushed** — the harness change, the notebook, this report and its
screenshots together, per the Pass 68 rule that a pass's report goes in its own commit.

**Two commits are now unpushed: `9f5505e` (Pass 72) and this one.** Both wait on the owner's Home
Theater test, which is the standing separate push gate. **This pass changed no app-target code**, so
the binary the owner tests carries Pass 72's behaviour and one acceptance covers both. Nothing
forced, no history rewritten, no branch other than `main`.
