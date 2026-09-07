# Pass 24 — Rail focus restore: recon — 2026-09-06

**Nothing restores rail focus, because nothing in the app has ever set rail focus at all.** There
is one piece of focus state for the rail, `ScreenShell`'s `@FocusState focus`, and no line in the
app ever writes to it. The entry you clicked is not recorded anywhere, so when you swipe back left
tvOS picks an entry for itself — by geometry — and the app has no say. **Two of the nine rail
screens land on the right entry and both are coincidences of layout**, not behaviour anyone built.

Every result below came off the physical Apple TV, Home Theater, driven by the real Siri Remote.
Every rail entry was tested three times; **all three rounds landed identically, entry for entry,
frame for frame**. Nothing in the app was changed, and this pass proposes no change.

The pass is a stop-and-report at step 4: one cause explains every failure. That is stated with its
evidence in §4 and the remaining investigation was not done.

**Citation keys.** `dc:NNN` = line NNN of `design/Marlin DVR TV.dc.html` (read-only, never
edited). `File.swift:NN` = line NN of that source file at `HEAD` (`2eb3495`). Coordinates are
tvOS points on the 1920×1080 screen, as XCTest reported them on the device. No credential, token,
account identifier or device identifier is in this report.

---

## 0. What was run, and on what

| | |
|---|---|
| Device | Apple TV 4K (3rd generation), `AppleTV14,1`, **tvOS 26.6**, named Home Theater |
| App | built from `HEAD` = `2eb3495` this pass, installed by `xcodebuild … test` at the start of each run |
| Mac | macOS 26.6.2, Xcode 26.6 (17F113), SDK `AppleTVOS26.5` |
| Harness | `Marlin DVR TVUITests/RailFocusReconUITests.swift` — **temporary, disclosed, reverted before committing** (§7) |
| Device runs | four: the rail as drawn (§2.1), **3 full rounds** over every rail entry (§2.3, §3), the collapsed rail measured (§4.2), and a **12-probe** geometry test (§4.3) |

The report is filed under **2026-09-06**, the pass's date. The device runs ran into the small hours
of **2026-09-07**, which is the date the Guide draws in
`reports/assets/pass24/atv-01-rail-as-drawn-ten-entries.png`.

**The build under test is the build just made, not a stale one.** Every run in this pass was an
`xcodebuild … test` against `-destination 'platform=tvOS,name=Home Theater'`, which builds, signs,
installs and launches before the first remote press; the log for each run carries its own
`ProcessInfoPlistFile … Marlin DVR TV.app/Info.plist` and `CodeSign … Marlin DVR TV.app` lines.
Independently of that, `RailFocusReconUITests` is a **new test class that did not exist in any
previously installed runner** — a stale runner on the device could not have run the tests whose
output this report quotes.

---

## 1. How rail focus is managed today (step 1)

### 1.1 There is one piece of rail focus state, and nothing ever writes to it

```
ScreenShell.swift:22      @FocusState private var focus: ShellFocus?
RailView.swift:50             .focused($focus, equals: .rail(destination))
```

`focus` is **read** in exactly two places — `ScreenShell.swift:26-29`, which expands the rail while
it holds a rail case, and `RailView.swift:46`, which draws the ring on the item it names. It is
**written in none**. Grepping the whole app for a write to it, for `.defaultFocus` on the rail, for
`prefersDefaultFocus`, for `resetFocus`, or for any stored "last rail entry" returns nothing:

- no `focus = .rail(…)` anywhere in `Marlin DVR TV/`;
- `RailView.swift:15-18` declares `ShellFocus.content` and **nothing in the app uses that case** —
  no view is `.focused($focus, equals: .content)`, so the content has no representation in this
  state at all;
- `RailView` has no `.defaultFocus`, and `Destination` (`Destination.swift`) has no notion of a
  remembered or previously-selected entry.

So the answer to "what sets rail focus when the rail appears" is: **nothing in this app does.**

### 1.2 What actually happens when you click a rail entry

1. `RailView.swift:39-41` fires `onSelect`, and `ScreenShell.swift:33-40` sets `screen`.
2. `ScreenShell.swift:42` gives the content `.id(current)`, so the whole content view is destroyed
   and rebuilt with a new identity for the new screen.
3. The new screen's own `@FocusState` claims focus through its `.defaultFocus` and its
   `focusSoon { focused = … }` (`ScreenChrome.swift:122-127`, an 80 ms hop).
4. The moment content takes focus, `ScreenShell`'s `focus` goes **nil** — no content view is bound
   to it — the rail collapses from 372 pt to the 180 pt icon strip (`ScreenShell.swift:26-29`,
   `RailView.swift:61`), and **the only record of which entry was clicked is gone**.

There is nothing left to restore. When Left is pressed, the tvOS focus engine is choosing among ten
rail items with no preference expressed by the app.

### 1.3 Do the screens diverge? Only in where their own content puts focus

Every one of the nine treats the rail identically — which is to say, not at all. What differs is
where each one parks focus inside its content, which (§4) is the only input the focus engine has.

| Screen | Where it puts focus when it opens | Set at |
|---|---|---|
| Favorites | first favourite channel row | `FavoritesScreen.swift:91` + `:95` |
| On Now | first card of the 3-column grid | `OnNowScreen.swift:166` + `:175` |
| Guide | first programme cell of the first row — **not** the channel cell | `GuideScreen.swift:305` + `:308` |
| On Later | first row of the first non-empty column | `OnLaterScreen.swift:94` + `:98` |
| Recordings | first poster card of the first shelf | `RecordingsScreen.swift:130` + `:65` |
| Cameras | first camera card of the 2-column grid | `CamerasScreen.swift:95` + `:103` |
| Weather | first daily row — **no `.defaultFocus` at all**, only `focusSoon` | `WeatherScreen.swift:52` and `:55` |
| Radio | first station tile of the 2-column grid | `RadioScreen.swift:83` + `:87` |
| Manage DVR | the "Scheduled Recordings" row | `ManageDVRScreen.swift:190` + `:142` |

Two secondary divergences, neither of which touches the rail: **Guide** is the only screen whose
default focus is not in its leftmost column (it needs two Left presses to reach the rail, every
other screen needs one), and **Weather** is the only screen with no `.defaultFocus`, relying wholly
on the `focusSoon` Pass 22 added (`WeatherScreen.swift:45-53`).

### 1.4 The design already draws what the owner is asking for

The design's rail data gives the 4 pt accent focus ring to the **active** index and to no other:

> `dc:1144-1149` — `const railFocused = (active) => nav.map(([label, icon], i) => ({ …
> border: i === active ? "4px solid var(--color-accent)" : "4px solid transparent", … }))`

and the one frame that draws the rail expanded, frame 1b, is `data-screen-label="On Now / sidebar"`
(`dc:55`) fed by `sidebar: railFocused(2)` (`dc:1345`), where `nav[2]` is `"On Now"`
(`dc:1132-1136`). **The design's only picture of focus in the rail puts the ring on the entry of
the screen you are on.** This is not a new request; it is the drawn behaviour.

---

## 2. Every rail entry, tested on the device (step 2)

### 2.1 The rail as drawn — ten entries, and Settings is not one of them

`reports/assets/pass24/atv-01-rail-as-drawn-ten-entries.png`, photographed on Home Theater with the
rail expanded. Counted by hand off that screenshot, top to bottom:

**Home · Favorites · On Now · Guide · On Later · Recordings · Cameras · Weather · Radio ·
Manage DVR — ten.**

The same ten, with their measured frames, printed out of the device by the harness:

```
RAILDRAWN count=10
 0: 'Home'        (98,142 134x35)      5: 'Recordings'  (98,474 198x35)
 1: 'Favorites'   (80,197 258x60)      6: 'Cameras'     (98,537 170x35)
 2: 'On Now'      (97,278 160x35)      7: 'Weather'     (96,602 166x35)
 3: 'Guide'       (80,332 258x56)      8: 'Radio'       (98,670 128x38)
 4: 'On Later'    (101,408 162x35)     9: 'Manage DVR'  (102,739 216x34)
```

**There is no Settings entry in the rail, and there never has been.** The owner's list named one;
the rail does not draw one. Settings is a Home tile only, and the bottom slot of the rail is
**Manage DVR** — the design's rail lists nine destinations and Settings is not among them
(`dc:1132-1136`), which is why Pass 10B put Manage DVR there (`Destination.swift:11-15, :26`;
DECISIONS.md, 2026-09-06 sweep 4). Settings is therefore the one item on the owner's list that
cannot be tested as a rail entry: it is not there. Nothing inside it was touched, as scoped.

### 2.2 The procedure, identical for every entry and every round

From inside the rail: walk to the entry with Up/Down, press **Select**, wait for focus to leave the
rail (it never took longer than the first check), let any deferred focus land, then press **Left**
repeatedly until a rail item has focus and record the first one that does. Which item has focus is
read from the device — the focused element's own label and frame — not inferred from a screenshot.

### 2.3 The table — 9 testable entries, 2 correct, 7 wrong

Identical in **round 1, round 2 and round 3**; the "landed on" column never varied once.

| # | Rail entry | What its content focused when the screen opened | Centre y | Focus landed on | Correct? |
|---|---|---|---|---|---|
| 0 | **Home** | *Home draws no rail at all* (`dc:111`) | — | *no rail exists* | n/a |
| 1 | **Favorites** | first favourite row `(236,158 1400×174)` | 245 | **Favorites** | ✅ |
| 2 | **On Now** | first card `(236,267 516×174)` | 354 | **Guide** | ❌ one below |
| 3 | **Guide** | first programme cell `(554,228 48×82)` | 269 | **Favorites** | ❌ two above |
| 4 | **On Later** | first row `(220,236 794×126)` | 299 | **On Now** | ❌ two above |
| 5 | **Recordings** | first poster card `(254,181 296×563)` | 462 | **On Later** | ❌ one above |
| 6 | **Cameras** | first camera card `(188,170 880×407)` | 373 | **Guide** | ❌ three above |
| 7 | **Weather** | first daily row `(1740,638 46×35)` | 655 | **Weather** | ✅ |
| 8 | **Radio** | first station tile `(236,224 787×168)` | 308 | **On Now** | ❌ six above |
| 9 | **Manage DVR** | "Scheduled Recordings" row `(236,329 1400×67)` | 362 | **Guide** | ❌ six above |

**Counts, confirmed by hand against the rail as drawn:** 10 entries drawn; **9** of them open a
screen that has a rail to come back to; **2 of those 9 land on the right entry** (Favorites,
Weather) and **7 do not**. Home is not a failure — it is the design (`dc:111`, "the rail is the
same nine destinations, so Home shows no rail"); selecting Home from the rail leaves the shell
entirely and there is nothing to swipe back to
(`reports/assets/pass24/atv-08-home-from-the-rail-draws-no-rail.png`).

**One Left press reaches the rail from every screen except the Guide, which needs two** — the
Guide's default focus is a programme cell, and the first press moves to that row's channel cell.
That is the same on every round and is not part of the defect.

### 2.4 Screenshots

| Case | File |
|---|---|
| Working — Favorites open, ring on Favorites | `reports/assets/pass24/atv-02-working-favorites-lands-on-favorites.png` |
| Working — Weather open, ring on Weather | `reports/assets/pass24/atv-03-working-weather-lands-on-weather.png` |
| Failing — **Recordings** open (accent hairline on Recordings), ring one entry up on **On Later** | `reports/assets/pass24/atv-04-failing-recordings-lands-on-on-later.png` |
| Failing — **Guide** open, ring two entries up on **Favorites** | `reports/assets/pass24/atv-05-failing-guide-lands-on-favorites.png` |
| Failing — **Manage DVR** open at the bottom of the rail, ring six entries up on **Guide** | `reports/assets/pass24/atv-06-failing-manage-dvr-lands-on-guide.png` |
| Failing — **Radio** open, ring six entries up on **On Now** | `reports/assets/pass24/atv-07-failing-radio-lands-on-on-now.png` |

The failing shots show the two states side by side: the entry with the **1 pt accent hairline and
accent-200 ink** is the screen you are actually on (`RailView.swift:101-126`, `dc:1138-1143`), and
the entry with the **4 pt accent ring** is where the remote went.

---

## 3. Where focus lands instead, and whether it repeats (step 3)

Every failing entry was opened and re-entered **three times**. Not one of them varied — not the
entry it landed on, not the frame the content had focused, not the number of Left presses.

| Failing entry | Round 1 | Round 2 | Round 3 | Consistent? | Which way it is wrong |
|---|---|---|---|---|---|
| On Now | Guide | Guide | Guide | yes, 3/3 | the **next** entry down |
| Guide | Favorites | Favorites | Favorites | yes, 3/3 | **two** entries up |
| On Later | On Now | On Now | On Now | yes, 3/3 | **two** entries up |
| Recordings | On Later | On Later | On Later | yes, 3/3 | the **previous** entry |
| Cameras | Guide | Guide | Guide | yes, 3/3 | **three** entries up |
| Radio | On Now | On Now | On Now | yes, 3/3 | **six** entries up |
| Manage DVR | Guide | Guide | Guide | yes, 3/3 | **six** entries up |

**It is not "the top of the list", it is not "Home", and it is not "the previous entry"** — those
were the shapes the pass was asked to check for and none of them fits. Home was never landed on
once, in 21 failing attempts. Recordings→On Later happens to be the previous entry and
Guide→Favorites happens to be two up, but Radio and Manage DVR jump six entries and On Now lands
one *below* itself. The pattern is not positional relative to the entry you chose. §4 says what it
is instead.

---

## 4. The diagnosis (step 4) — one cause, and it is one line

### 4.1 Nothing remembers, so there is nothing to restore

§1.1 is the whole of it: `ScreenShell.focus` is never assigned, `ShellFocus.content` is dead code,
the rail has no `.defaultFocus`, and no last-selection is stored anywhere. The device confirms it
in the bluntest possible way: **open the Guide from the rail and press Left, and the ring is on
Favorites** — one press after the app itself put focus on Guide to run the click
(`atv-05-failing-guide-lands-on-favorites.png`, and the same in `atv-01`). If any memory existed,
that case could not fail.

### 4.2 What chooses instead: the vertical centre of whatever the content has focused

While focus is in the content the rail is the **collapsed 180 pt icon strip**
(`reports/assets/pass24/atv-09-rail-collapsed-while-focus-is-in-the-content.png`), and that is the
layout the focus engine searches when Left is pressed. The strip's ten icons are 64 pt tall with a
12 pt gap between them, under the brand mark (`RailView.swift:35, :57, :146-148`); measured on the device with
focus in the content, their centres are:

```
COLLAPSED count=10          (label, frame, centre y — measured on Home Theater, Guide open,
 0: 'Home'           (91,142 42x37)   centreY=160.0      focus in the content, rail collapsed)
 1: 'Favorite'       (92,217 40x38)   centreY=236.0
 2: 'Tv'             (90,294 44x36)   centreY=312.2
 3: 'Grid View'      (80,356 64x64)   centreY=388.0   ← Guide, the open screen: the active tint
 4: 'Clock'          (94,446 36x36)   centreY=464.0
 5: 'Movie'          (92,524 42x32)   centreY=540.2
 6: 'Video'          (92,602 44x29)   centreY=616.0
 7: 'Partly Cloudy'  (88,674 52x37)   centreY=692.0
 8: 'radio'          (92,748 42x40)   centreY=768.2
 9: 'Edit'           (94,829 36x30)   centreY=844.0
```

(The labels are the SF Symbols' own names because the collapsed rail draws **no text** — one more
sign of how little the rail is telling anyone at that moment. The pitch is a flat 76 pt: 64 pt
icons on the VStack's 12 pt collapsed spacing, `RailView.swift:35, :148`.)

Line the measured content-focus centres of §2.3 up against those, and the entry that took focus is
in every single case **the rail icon whose centre is nearest**:

| Screen opened | Its focused content element | Centre y | Nearest icon | Δ | Next nearest | Δ | **Landed on** |
|---|---|---|---|---|---|---|---|
| Favorites | first channel row | 245 | Favorites 236 | **9** | On Now 312 | 67 | **Favorites** ✅ |
| On Now | first card | 354 | Guide 388 | **34** | On Now 312 | 42 | **Guide** |
| Guide | first programme cell | 269 | Favorites 236 | **33** | On Now 312 | 43 | **Favorites** |
| On Later | first row | 299 | On Now 312 | **13** | Favorites 236 | 63 | **On Now** |
| Recordings | first poster card | 462 | On Later 464 | **2** | Guide 388 | 74 | **On Later** |
| Cameras | first camera card | 373 | Guide 388 | **15** | On Now 312 | 61 | **Guide** |
| Weather | first daily row | 655 | Weather 692 | **37** | Cameras 616 | 39 | **Weather** ✅ |
| Radio | first station tile | 308 | On Now 312 | **4** | Favorites 236 | 72 | **On Now** |
| Manage DVR | Scheduled Recordings row | 362 | Guide 388 | **26** | On Now 312 | 51 | **Guide** |

**Nine screens out of nine, first time, no exceptions.** The rule needs nothing about which entry
was clicked, which screen was open before, or which entry is active — because the app tells the
focus engine none of those things.

### 4.3 The probe: move the content row, and the rail landing moves with it

Read-only, nothing changed: open a screen, walk *n* rows down inside its content with the remote,
then swipe left. Each probe opens a different screen first and then the one being measured, because
of §4.5 — re-selecting the entry you are already on does nothing.

Twelve probes, all on the device, all with the same one Left press at the end. `Δ` is the distance
from the content row's centre to the icon centre it landed on; the "next nearest" column is the
icon it did **not** pick.

| Screen | rows down | Focused content element | Centre y | Nearest icon | Δ | Next nearest | Δ | **Landed on** |
|---|---|---|---|---|---|---|---|---|
| **Manage DVR** | 0 | Scheduled Recordings `(236,329 1400×67)` | 362 | Guide 388 | 26 | On Now 312 | 51 | **Guide** |
| | 1 | Your Passes `(236,408 1400×67)` | 442 | On Later 464 | 22 | Guide 388 | 54 | **On Later** |
| | 2 | Trash `(236,487 1400×67)` | 520 | Recordings 540 | 20 | On Later 464 | 57 | **Recordings** |
| | 3 | *(clamps — the hub has three rows)* | 520 | Recordings 540 | 20 | On Later 464 | 57 | **Recordings** |
| **On Later** | 0 | first row `(236,236 778×126)` | 299 | On Now 312 | 13 | Favorites 236 | 63 | **On Now** |
| | 1 | second row `(220,384 794×126)` | 447 | On Later 464 | 17 | Guide 388 | 59 | **On Later** ← *now "correct"* |
| | 2 | third row `(236,526 778×138)` | 595 | Cameras 616 | 21 | Recordings 540 | 55 | **Cameras** |
| | 3 | fourth row `(220,680 794×126)` | 743 | Radio 768 | 25 | Weather 692 | 51 | **Radio** |
| **Weather** | 0 | first daily row `(1740,638 46×35)` | 655 | Weather 692 | 37 | Cameras 616 | 39 | **Weather** |
| | 1 | second daily row `(1740,692 42×35)` | 709 | Weather 692 | 17 | Radio 768 | 58 | **Weather** |
| | 2 | third daily row `(1740,746 48×35)` | 763 | Radio 768 | 5 | Weather 692 | 71 | **Radio** |
| | 3 | fourth daily row `(1740,805 48×35)` | 822 | Manage DVR 844 | 22 | Radio 768 | 54 | **Manage DVR** |

**Twelve out of twelve.** The landing walks down the rail one entry at a time as the highlight walks
down the content — on Manage DVR, on On Later and on Weather alike. The clearest single line in the
whole pass is the **On Later, one row down** case: *the same screen becomes "correct" purely by
moving the highlight one row down the list.* Weather, the pass's other "working" screen, stops
working at the third daily row.

(The Weather frames are the innermost element reporting focus — the row's high temperature — because
its daily rows are `.focusable()` on a plain view rather than a Button, `WeatherScreen.swift:312-319`.
The row is what actually holds focus; the numbers are its text's centre.)

The rail entry that lights up is not a property of the screen at all. It tracks the row the remote
happens to be standing on. That is the mechanism, demonstrated rather than argued.

### 4.4 So why do Favorites and Weather work?

They are coincidences, and the arithmetic in §4.2 shows exactly how narrow ones.

- **Favorites** works because its first channel row sits at centre y 245, and the boundary between
  the Favorites icon (236) and the On Now icon (312) is at **274**. It clears it by 29 pt. A taller
  header, a second subtitle line, or a channel row 60 pt taller, and Favorites lands on On Now.
- **Weather** works by **1.5 pt**. Its first daily row sits at 655 and the Cameras/Weather boundary
  is at **654**. And the thing most likely to move it is already known to be coming: the alert card
  has never once been drawn with real data (Pass 22 Open Question 1), and the day an alert is in
  force for this location the header row grows, the daily list moves down, and Weather is at least
  as likely to start landing on Radio as it is to keep working.

Neither is behaviour anyone wrote. They are two screens whose first focusable element happens to be
level with their own icon.

### 4.5 One more thing the probing turned up, measured and not touched

Pressing Select on the rail entry of the screen you are **already on** does nothing at all, and the
remote stays in the rail. `ScreenShell.swift:33-40` assigns the same value to `screen`, so
`content.id(current)` (`:42`) does not change, the content is not rebuilt, neither `.defaultFocus`
nor `focusSoon` runs again, and nothing claims focus. Measured: with Manage DVR open, Select was
pressed on the Manage DVR entry at `t = 57.57s` and the focused element was still the Manage DVR
rail button at every one-second check for the next 25 seconds. It is arguably right that
re-selecting the current screen does not reload it; whether the remote should be left sitting in
the rail there is a question (Open Question 6), not a finding, and nothing was changed for it.

### 4.6 STOP AND REPORT

**A single shared cause explains every failure**, so per this pass's instruction the investigation
stops here and nothing further was attempted. The one line is:

> **The app never records or restores which rail entry is current, so tvOS picks the rail icon
> nearest the vertical centre of whatever the content has focused — and only Favorites and Weather
> happen to be level with their own icon.**

Nothing was changed to establish this, and no fix was prepared.

---

## 5. Open Questions

1. **Where should the ring be when you come back to the rail — always the current screen, or the
   last entry the remote touched?** The design answers the first (`dc:1144-1149`, `dc:1345`,
   §1.4): the ring belongs on the entry of the screen you are on. The owner's words match. But the
   two differ the moment someone walks the rail past several entries without pressing Select and
   then swipes right into the content; this pass did not test that path and does not know which the
   owner wants there.
2. **Should Home be part of the answer at all?** Home draws no rail (`dc:111`), so there is no
   "come back to Home's entry". Selecting Home from the rail leaves the shell. Nothing seems wrong
   with that, but it means the rail can never show its ring on Home, and no one has said whether
   that matters.
3. **The rail has no Settings entry**, though the owner's list named one. Manage DVR holds the
   bottom slot instead (Pass 10B). Is that still what the owner expects, or was "Settings" in the
   brief a memory of the Home tile?
4. **Does the same defect exist inside the sub-screens?** Show detail, the Manage DVR sections, and
   the Radar all sit on top of a screen rather than beside the rail; this pass tested the ten rail
   entries only and looked at nothing inside them.
5. **`ShellFocus.content` is declared and unused** (`RailView.swift:17`). It is exactly the shape a
   fix would want, which suggests it was intended and never wired. Nothing was done about it here.
6. **Should Select on the entry you are already on move the remote into the content?** Today it
   does nothing and the remote stays in the rail (§4.5). Nobody has said what it should do.

---

## 6. SCOPE CHECK — every file touched, and the step that required it

| File | What happened to it | Step |
|---|---|---|
| `COLD-START.md` | **read only** | READ FIRST |
| `DECISIONS.md` | **read only** | READ FIRST |
| `reports/2026-09-06-pass22-weatherkit.md` | **read only** | READ FIRST |
| `design/Marlin DVR TV.dc.html` | **read only** — the rail frames and rail data | 1, 2 |
| `Marlin DVR TV/ScreenShell.swift` | **read only** | 1, 4 |
| `Marlin DVR TV/RailView.swift` | **read only** | 1, 4 |
| `Marlin DVR TV/Destination.swift` | **read only** | 1, 2 |
| `Marlin DVR TV/ContentView.swift`, `HomeView.swift` | **read only** | 1, 2 |
| `Marlin DVR TV/{Favorites,OnNow,Guide,OnLater,Recordings,Cameras,Weather,Radio,ManageDVR}Screen.swift`, `ScreenChrome.swift`, `Theme.swift` | **read only** | 1, 4 |
| `Marlin DVR TVUITests/RailFocusReconUITests.swift` | **created, run on the device, deleted before committing** — the diagnostic harness of §7 | 2, 3, 4 |
| `reports/2026-09-06-pass24-rail-focus-recon.md` | **new** — this report | 5 |
| `reports/assets/pass24/*.png` | **new** — 9 screenshots from Home Theater | 5 |
| `build/**` | build output only; git-ignored, never committed | 2, 3, 4 |

**Not one file under `Marlin DVR TV/` was modified.** No behaviour was changed, no fix was
prepared, and nothing outside this folder was read or written — no App ID, profile or certificate,
nothing on 192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, and nothing in
`design/` beyond reading it.

---

## 7. The harness: disclosed, and reverted

`Marlin DVR TVUITests/RailFocusReconUITests.swift` was written for this pass, lived only in the
**UI-test target**, and was **deleted before the commit**. It presses Select on rail entries and
nothing else, so no playback and no server write could start from it; it makes no network call of
its own.

**The app binary is the proof that nothing in the app changed.** In this build configuration all of
the app's Swift code lives in `Marlin DVR TV.debug.dylib`; the `Marlin DVR TV` executable beside it
is the launcher stub, which is re-signed on every build.

| | SHA-256 of `Marlin DVR TV.debug.dylib` | Mach-O UUID of `Marlin DVR TV` |
|---|---|---|
| **before** the harness existed (build at `2eb3495`) | `99685d9664ac2ab960048392fd6bfe8b9175f7de4114e939b6961e46d08525db` | `3597FB26-E343-35F3-B060-4EC149A95D64` |
| **with** the harness in the tree (the builds that produced every result above) | `99685d9664ac2ab960048392fd6bfe8b9175f7de4114e939b6961e46d08525db` | `3597FB26-E343-35F3-B060-4EC149A95D64` |
| **after** the harness was deleted (this build) | `99685d9664ac2ab960048392fd6bfe8b9175f7de4114e939b6961e46d08525db` | `3597FB26-E343-35F3-B060-4EC149A95D64` |

Identical throughout: the harness changed the test bundle and **not one byte of the app**. (The
launcher stub's own file hash does change between builds because it is re-signed each time; its
Mach-O UUID, above, does not, and the dylib that holds every line of the app's Swift is byte-for-byte
the same in all three builds.)

The harness file as run had SHA-256
`3c2e2603ca64b555f4ea53509eda9047a021ba7a415c0b60e57ed34f128bd005`, and is deleted; it is not in
this commit and not in the repository. Its four tests were `testRailAsDrawn` (§2.1),
`testRailFocusRestore` (§2.3 and §3), `testCollapsedRailGeometry` (§4.2) and
`testLandingTracksTheContentRow` (§4.3). Every screenshot in `reports/assets/pass24/` came out of
those runs.

The `build/` tree it produced — the four `.xcresult` bundles and the logs quoted here — is
git-ignored and is not committed either.
