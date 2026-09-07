# Pass 25 — Rail focus restore: the fix — 2026-09-07

**Swipe left from any screen and the ring lands on that screen's own rail entry — nine screens,
three rounds, twenty-seven attempts, twenty-seven correct.** Pass 24 proved the app never
recorded or restored which rail entry was current, so tvOS picked the icon nearest the vertical
centre of whatever the content had focused: 2 of 9 right, 7 wrong, identical over three rounds.

The fix is twelve lines of behaviour in one file. It records nothing new, because **the record
already existed**: `ScreenShell.screen` *is* the entry that opened the content. What was missing
was the restore, and that is now `ScreenShell.railRestore` (`ScreenShell.swift:68-81`).

Every result below came off the physical Apple TV, Home Theater, driven by the real Siri Remote.

**Citation keys.** `dc:NNN` = line NNN of `design/Marlin DVR TV.dc.html` (read-only, never
edited). `File.swift:NN` = line NN of that source file as committed this pass. Coordinates are
tvOS points on the 1920×1080 screen, as XCTest reported them on the device. No credential, token,
account identifier or device identifier is in this report.

---

## 0. What was run, and on what

| | |
|---|---|
| Device | Apple TV 4K (3rd generation), `AppleTV14,1`, **tvOS 26.6**, named Home Theater |
| App | built from this pass's tree, installed by `xcodebuild … test` at the start of each run |
| Mac | macOS 26.6.2 (25G83), Xcode 26.6 (17F113), SDK `AppleTVOS26.5` |
| Harness | `Marlin DVR TVUITests/RailFocusRestoreUITests.swift` — **committed**, like Pass 19's, 20's and 22's |
| Device runs | three: **run A** the measurement of §2, **run B** the four-test verification of §3–§6, **run C** the re-run of one test after a harness fix (§7) |

The pass started from `67489b4` (Pass 24). Baseline for comparison throughout is Pass 24's table,
`reports/2026-09-06-pass24-rail-focus-recon.md` §2.3.

---

## 1. The change — twelve lines, one file

`ScreenShell` already held the answer and never used it. `screen` is set by the rail's `onSelect`
(`ScreenShell.swift:42-47`) and by Home's tile grid, so `current` is, by construction, the entry
that opened the content. The fix is to put focus there when the remote comes back:

```
ScreenShell.swift:31      @State private var railHasFocus = false
ScreenShell.swift:60      .onChange(of: focus) { _, landed in railRestore(landed) }
ScreenShell.swift:68-81   private func railRestore(_ landed: ShellFocus?) {
                              guard case .rail(let entry) = landed else {
                                  railHasFocus = false
                                  return
                              }
                              guard !railHasFocus else { return }
                              railHasFocus = true
                              …
                              focus = .rail(current)
                          }
```

`railHasFocus` is the whole of the subtlety. The restore must fire on the **crossing** into the
rail and never again, or Up and Down inside the rail would snap back to the current entry and the
rail would be unusable. `focus` is nil whenever the content holds focus — no content view is bound
to `ShellFocus` — so "focus is not a rail case" is exactly "the remote is not in the rail", and the
flag flips false there. Movement from one rail entry to the next finds the flag already true and is
left alone. Every round of §3 walked the rail with Up and Down to reach each entry, so this is
exercised 27 times over.

**This is what the design draws.** The rail data gives the 4 pt accent focus ring to the *active*
index and to no other — `railFocused(active)` at `dc:1144-1149` — and the one frame that draws the
rail expanded is fed `sidebar: railFocused(2)` where `nav[2]` is On Now, the screen that frame is
showing (`dc:55`, `dc:1345`, `dc:1132-1136`). The ring on the entry of the screen you are on was
always the drawn behaviour; nothing put it there.

**Nothing else changed.** No screen was touched, no reload loop was retimed, no focus was moved
inside any content view, and `RailView` is comment-only (§2).

---

## 2. What was tried first, measured, and removed

The declarative way to say this in SwiftUI is `focusScope` on the rail plus
`prefersDefaultFocus(destination == current, in:)` on each entry — the tvOS focus engine's own
"preferred focus environment". Both are in the installed SDK
(`SwiftUI.swiftinterface:16511, 16513`). It was built that way first and put on the Apple TV with
**no other change** — the `ScreenShell` restore disabled — so the run measured the preference alone.

**It changed nothing at all.** Run A, one round, nine entries:

| Rail entry | Landed on | Pass 24 landed on | Same? |
|---|---|---|---|
| Favorites | Favorites | Favorites | yes |
| On Now | Guide | Guide | yes |
| Guide | Favorites | Favorites | yes |
| On Later | On Now | On Now | yes |
| Recordings | On Later | On Later | yes |
| Cameras | Guide | Guide | yes |
| Weather | Weather | Weather | yes |
| Radio | On Now | On Now | yes |
| Manage DVR | Guide | Guide | yes |

**2 correct, 7 wrong — Pass 24's table, entry for entry.** The focus engine does not consult a
scope's default-focus preference when the remote swipes directionally into it; it runs the
geometric search Pass 24 measured and the preference is never asked. So the code came out. Run A
doubles as a control: it reproduces Pass 24's finding on a freshly built app, three weeks of
commits later, before the fix is applied.

`RailView.swift` therefore carries **no code change this pass** — only a comment recording that
this was tried and what it measured (`RailView.swift:11-16`), so the next person does not spend a
device run on it.

---

## 3. Every rail entry, three rounds, on the device

`testEveryRailEntryLandsOnItself`, **passed in 269.5 s**. For each entry: walk the rail to it with
Up/Down, confirm the label, press Select, wait for focus to leave the rail, then press Left until a
rail item holds focus and record the first one that does — read from the device as the focused
element's own label and frame, not inferred from a screenshot.

| # | Rail entry | What its content had focused | Landed on | Pass 24 | Rounds |
|---|---|---|---|---|---|
| 1 | **Favorites** | first favourite row `(236,158 1400×174)` | **Favorites** `(80,197 258×60)` | Favorites ✅ | 3/3 ✅ |
| 2 | **On Now** | first card `(236,246 516×215)` | **On Now** `(80,265 258×58)` | Guide ❌ | 3/3 ✅ |
| 3 | **Guide** | first programme cell `(554,228 637×82)` | **Guide** `(80,332 258×56)` | Favorites ❌ | 3/3 ✅ |
| 4 | **On Later** | first row `(236,236 778×126)` | **On Later** `(80,396 258×59)` | On Now ❌ | 3/3 ✅ |
| 5 | **Recordings** | first poster card `(254,181 296×562)` | **Recordings** `(80,463 258×56)` | On Later ❌ | 3/3 ✅ |
| 6 | **Cameras** | first camera card `(188,170 880×407)` | **Cameras** `(80,527 258×55)` | Guide ❌ | 3/3 ✅ |
| 7 | **Weather** | first daily row `(1740,638 44×35)` | **Weather** `(80,590 258×59)` | Weather ✅ | 3/3 ✅ |
| 8 | **Radio** | first station tile `(236,224 787×168)` | **Radio** `(80,657 258×63)` | On Now ❌ | 3/3 ✅ |
| 9 | **Manage DVR** | Scheduled Recordings `(236,329 1400×67)` | **Manage DVR** `(80,729 258×54)` | Guide ❌ | 3/3 ✅ |

```
RAILRESTORE TOTAL 27 attempts, 27 correct, 0 wrong
```

**The content focus is the same one Pass 24 measured, and the answer changed anyway.** That is the
point: Recordings still focuses a poster card whose centre is 2 pt from the On Later icon, and it
now lands on Recordings. The landing no longer tracks the content row at all.

**Two things deliberately unchanged, and confirmed unchanged.** The Guide still needs **two** Left
presses to reach the rail and every other screen needs one — the Guide's default focus is a
programme cell and the first press moves to that row's channel cell. That is its content layout,
not this defect. And selecting the rail entry of the screen you are already on still does nothing
(Pass 24 §4.5, Open Question 6); nothing here touched it.

Screenshots, one per entry: `reports/assets/pass25/atv-01-favorites-lands-on-itself.png` through
`atv-09-manage-dvr-lands-on-itself.png`.

---

## 4. Home — still no rail, asserted rather than assumed

`testHomeStillDrawsNoRail`, **passed in 23.6 s**. Selecting Home from the rail leaves the shell
entirely: `ContentView` swaps `HomeView` in for `ScreenShell` (`ContentView.swift:26-38`), so there
is no rail to come back to. This is the design (`dc:111` — "the rail is the same nine destinations,
so Home shows no rail"), and Home was **not** touched this pass, as scoped.

```
RAILHOME greeting='Good morning' narrow-left-buttons=0 focus=Guide, 83 channels live (80,266 569x224)
```

`narrow-left-buttons=0` is the assertion: **no rail-shaped button is on screen.** Home's own tiles
also begin inside the first 150 pt of the screen, so the rail is told apart by width — an entry is
258 pt expanded and 64 pt collapsed, where the focused Home tile above is 569 pt.
`reports/assets/pass25/atv-10-home-from-the-rail-draws-no-rail.png`.

---

## 5. The periodic reloads — On Now (60 s) and Cameras (45 s)

`testReloadsDoNotMoveFocus`, **passed in 309.2 s**. Both screens were watched twice: once with the
remote **parked in the rail** and once with it **in the content**, sampling every 5 s. The reload is
**proven to have happened**, not assumed — each screen's own subtitle is read at every sample.

**On Now, parked in the rail** — the ring never left the On Now entry, across a refresh:

```
RELOAD[On Now] t=5s   rail focus='On Now' subtitle='Refreshed 8:07 AM · 83 channels'
RELOAD[On Now] t=55s  rail focus='On Now' subtitle='Refreshed 8:08 AM · 83 channels'
RELOAD[On Now] t=75s  rail focus='On Now' subtitle='Refreshed 8:08 AM · 83 channels'
```

**On Now, in the content** — the focused card never moved, across a second refresh, and the swipe
left afterwards landed on On Now:

```
RELOAD[On Now] t=30s  content focus='2.1 · WMAR-HD, NEW, Good Morning America, … (236,246 516x215)' subtitle='Refreshed 8:08 AM · 83 channels'
RELOAD[On Now] t=35s  content focus='2.1 · WMAR-HD, NEW, Good Morning America, … (236,246 516x215)' subtitle='Refreshed 8:09 AM · 83 channels'
RELOAD[On Now] after a reload cycle in the content, swipe left landed on 'On Now'
```

**Cameras** is the same in both positions, and its refresh shows as the snapshot age resetting:

```
RELOAD[Cameras] t=35s rail focus='Cameras' subtitle='Snapshot age 41 s · click for live view'
RELOAD[Cameras] t=40s rail focus='Cameras' subtitle='Snapshot age 1 s · click for live view'
RELOAD[Cameras] t=20s content focus='Online, Cow Cam, HEVC (188,170 880x407)' subtitle='Snapshot age 39 s · click for live view'
RELOAD[Cameras] t=25s content focus='Online, Cow Cam, HEVC (188,170 880x407)' subtitle='Snapshot age 0 s · click for live view'
RELOAD[Cameras] after a reload cycle in the content, swipe left landed on 'Cameras'
```

**Neither reload steals focus and neither moves it**, in the rail or in the content, and the landing
is still correct afterwards. The two loops set focus only on their first pass
(`OnNowScreen.swift:167-178`, `CamerasScreen.swift:96-107`) and their item identities are stable
across a reload — `GuideNowItem.id` is the channel id (`Models.swift:73`) and `Camera.id` the
camera's (`Models.swift:289`) — so a refresh re-renders rows without disturbing the focused one.
That was the reasoning; the sixteen samples above are the evidence.

`atv-22-on-now-rail-focus-after-a-reload.png`, `atv-23-on-now-lands-on-itself-after-a-reload.png`,
`atv-26-cameras-rail-focus-after-a-reload.png`, `atv-27-cameras-lands-on-itself-after-a-reload.png`.

---

## 6. One Player round trip

`testFocusSurvivesAPlayerRoundTrip`, **passed in 47.6 s**. A camera was used because it is the one
Player path that holds no tuner, so nothing could collide with a recording.

```
PLAYER content focus before the Player: Online, Cow Cam, HEVC (188,170 880x407)
PLAYER while the Player is up, focus is: other: (0,0 1920x1080)
PLAYER back on Cameras, focus is: Online, Cow Cam, HEVC (188,170 880x407)
PLAYER after the round trip, swipe left landed on 'Cameras'
```

The card that had focus before the Player has it again after — **same element, same frame** — and
the swipe left lands on Cameras. Four shots: `atv-30-cameras-before-the-player.png`,
`atv-31-player-up.png` (the camera playing full screen), `atv-32-back-from-the-player.png`,
`atv-33-lands-on-cameras-after-the-player.png`.

---

## 7. The one failure in the runs, and what it was

Run B reported `** TEST FAILED **`. It was **the harness, not the app**: `testHomeStillDrawsNoRail`
asserted Home by looking for a static text `"Marlin DVR"` and a button labelled exactly `"Guide"`,
and Home draws neither — its wordmark is `"Marlin"` and its tile buttons carry their subtitle in the
label (`"Guide, 83 channels live"`). The assertion was rewritten to key on Home's greeting and on the
absence of any rail-shaped button, and re-run as run C, where it **passed**. The three other tests
of run B were unaffected and passed as reported above. The Home screenshot in
`reports/assets/pass25/` is from run C, the run that passed.

---

## 8. Open Questions

1. **Walking the rail without selecting.** Pass 24's Open Question 1 asked what should happen if
   someone walks the rail past several entries, swipes right into the content, then swipes left
   again — the entry they last touched, or the screen they are on? **This fix answers "the screen
   you are on"**, which is the design (`dc:1144-1149`) and the owner's words. It follows from the
   code — `railRestore` reads `current` and nothing else — but it was **not** on this pass's test
   list and was not driven on the device. Say the word and it is one run.
2. **`ShellFocus.content` is still declared and unused** (`RailView.swift:23`). Pass 24 guessed a
   fix would want it; this one did not — "focus is nil" already means "the remote is in the
   content". It is still dead code and was left alone rather than removed unasked.
3. **Select on the entry you are already on still does nothing** and the remote stays in the rail
   (Pass 24 §4.5 and its Open Question 6). Unchanged, and nobody has said what it should do.
4. **The sub-screens were not looked at** — show detail, the Manage DVR sections, the Radar and the
   airing sheet sit on top of a screen rather than beside the rail. Pass 24's Open Question 4 is
   still open; this pass tested the rail entries only.
5. **The rail has no Settings entry** (Pass 24 Open Question 3). Manage DVR holds the bottom slot
   since Pass 10B. Unchanged.

---

## 9. SCOPE CHECK — every file touched, and why

| File | What happened to it | Why |
|---|---|---|
| `Marlin DVR TV/ScreenShell.swift` | **modified** — `railHasFocus`, the `onChange`, and `railRestore` | the fix |
| `Marlin DVR TV/RailView.swift` | **modified, comment only** — records the §2 measurement | so the discarded approach is not retried |
| `Marlin DVR TVUITests/RailFocusRestoreUITests.swift` | **new, committed** — the four tests of §3–§6 | the evidence |
| `reports/2026-09-07-pass25-rail-focus-restore.md` | **new** — this report | |
| `reports/assets/pass25/*.png` | **new** — 18 screenshots from Home Theater | |
| `COLD-START.md`, `DECISIONS.md` | **modified** — Pass 24 and Pass 25, and the owner's decision | the notebook |
| `design/Marlin DVR TV.dc.html` | **read only** — the rail data and frame 1b | §1 |
| every `*Screen.swift`, `ContentView.swift`, `HomeView.swift`, `Models.swift`, `PlayerScreen.swift` | **read only** | §1, §5, §6 |
| `build/**` | build output only; git-ignored, never committed | the runs |

**No screen was modified, Home was not touched, no reload was retimed, and no server write was
made.** The one thing the runs started is a camera stream, which is the app's own Player path.
Nothing outside this folder was read or written — no App ID, profile or certificate, nothing on
192.168.1.250, 192.168.1.245, 192.168.1.105 or the UNAS4Pro share, and nothing in `design/` beyond
reading it.
