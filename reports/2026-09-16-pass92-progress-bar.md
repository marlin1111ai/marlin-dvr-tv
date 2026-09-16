# Pass 92 — a progress bar on the Continue watching cards

2026-09-16. Built, committed, **NOT pushed**. Three runs on Home Theater; the third is the one that
counts, and the first two are in §4 because one of them found a real trap.

---

## 0. Result

A Continue watching card now carries a **6 pt progress bar across the bottom of its poster**,
filled `position ÷ duration` from the two numbers Pass 91 already put on the card. Cards on
"Recently Updated" and "Recently Added" have none. Nothing else about any card changed — size,
poster, title, the "*n* min in" line, focus behaviour, shelf membership and order are all as Pass
91 left them, and `ResumeStore` was not touched at all.

**The app-target diff is one file**, `RecordingsScreen.swift`, **+67 / −1**. `ResumeStore.swift`,
`ScreenChrome.swift` (which owns the app's other `ProgressBar`) and `ShowDetailScreen.swift` are
untouched, so show detail's own resume bars are unchanged.

**Every one of the five bars was measured against the store and matches to within half a point**
(§5.4) — the store read off the Apple TV itself, not inferred.

---

## 1. Step 1 — the state before anything changed

```
git fetch
HEAD / main:  c633c9fe50e96194abed04965f175c7fa69e7066   (Pass 91)
origin/main:  92a477071df7058942fe3895bd77166e50c3af00   (Pass 89)
git ls-remote origin main
              92a477071df7058942fe3895bd77166e50c3af00	refs/heads/main
git rev-list --left-right --count main...origin/main
              1	0
git status --porcelain
              ?? icon-source/
```

`origin/main` reads `92a4770`, local `main` is exactly one commit ahead at `c633c9f`, and the only
untracked path is `icon-source/`. As required, so the pass proceeded.

---

## 2. Steps 2–5 — what was built

### 2.1 The fraction — `ContinueItem.progress`

```swift
var progress: Double? {
    guard entry.duration > 0 else { return nil }
    return min(1, max(0, entry.position / entry.duration))
}
```

`entry` is the `ResumeStore.Entry` Pass 91 already carries on the card, so **no new read of any
kind** — not of the store, not of the server. It is deliberately the same expression
`EpisodeRow.resumeFraction` uses for show detail's resume bars
(`ShowDetailScreen.swift:261-264`), against the same two stored numbers, so a recording's card and
its episode row cannot disagree about how far in it is.

**A zero or missing duration draws no bar.** `Entry.duration` is `0` whenever the Player never
learned the recording's length (`ResumeStore.swift:15`), and the `guard` turns that into `nil`,
which draws nothing — not an empty bar, not a full one, and no division by zero. None of the twelve
entries on Home Theater has a zero duration, so this branch is **code-traced only** (§5.6).

### 2.2 The card — `PosterCard`

One parameter, defaulted so every other shelf is untouched:

```swift
var progress: Double? = nil
```

and one overlay, placed **between `.frame` and `.clipShape`**:

```swift
.frame(width: focused ? 296 : 252, height: focused ? 404 : 344)
.overlay(alignment: .bottom) {
    if let progress { PosterProgressBar(fraction: progress) }
}
.clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
```

Before the clip, not after, so the card's own 8 pt corner radius trims the bar's two bottom
corners and nothing sits outside the card's existing layout box. It is the order `EpisodeRow`
already uses (`ShowDetailScreen.swift:299-304`). Because it is an **overlay**, it adds nothing to
the layout: the card's box is still Pass 47's 252 × 344 / 296 × 404.

### 2.3 The bar — `PosterProgressBar`

6 pt tall, a rectangle, full width, `GeometryReader` for the fill width — the same shape
`ProgressBar` uses, and the same height.

**Why it is not `ProgressBar`** (`ScreenChrome.swift:177-189`), which draws the same number in show
detail: that one is a **capsule**, drawn inset on a 236 × 133 thumbnail, on an **opaque** track.
This bar runs the full width of the poster and sits on its bottom edge, so a capsule's own rounded
ends would read as a pill floating inside the card rather than a bar across it; and step 3 asked
for a translucent unfilled part. Rather than change `ProgressBar` and move show detail's bars with
it, this is its own view and `ProgressBar` is left exactly as it was.

### 2.4 Step 3 — the tokens, and nothing added

| Part | Token | Value | Where that token is already used |
|---|---|---|---|
| **Filled** | `Nocturne.accent` | `#9184D9` | `ProgressBar`'s own fill (`ScreenChrome.swift:184`), the focus ring (`Theme.swift:79-81`), the "*n* new" badge |
| **Unfilled** | `Nocturne.bg` at `0.7` | `#161826` at 70 % | `Nocturne.bg` is the screen background (`Theme.swift:17`); `0.7` is the one translucency the theme already names, in `Nocturne.Focus.shadowColor` (`Theme.swift:83`) |
| **Height** | `PosterProgressBar.height` | 6 pt | the design's progress track, dc:93-95, and `ProgressBar`'s height |

**Nothing was added to `Theme.swift`**, no asset, no dependency, and no new colour literal — the
unfilled part is an existing token with an opacity modifier, which is how
`Nocturne.divider` and `Nocturne.Focus.shadowColor` are themselves written.

Measured off the television: the fill reads exactly `(145, 132, 217)` = `#9184D9`, and the track
reads `(15…17, 16…18, 27…30)` over the dark parts of these posters — `Nocturne.bg` at 0.7 over the
art beneath, as specified.

### 2.5 Step 4 — focused and unfocused

The bar is **6 pt in both states** — measured, not assumed: the accent band is 12 px tall at 2 px
per point on the unfocused cards and 12 px on the focused one (§5.5). There is **no animation**
(the only `.animation` on the card is Pass 47's existing one on `focused`, which the bar inherits
along with the rest of the card), **no percentage text and no time text**.

Pass 47's focus growth reaches it exactly as it reaches the rest of the card: the bar is an overlay
on the poster, so it widens 252 → 296 pt with the card and stays on the bottom edge as that edge
moves down. That is measured too — the focused bar is 295 pt wide against the unfocused 250.5 pt
(§5.4).

**One thing about the focused state the owner should look at** — §7 open question 1: the 4 pt focus
ring is `Nocturne.accent`, the same colour as the fill, and it is drawn over the bar's bottom 4 pt.
So on a focused card only the top **2 pt** of the 6 pt bar is distinguishable from the ring. The
bar is still correct and the fill boundary is still visible (photograph `92b`), but it is quieter
than on the four cards beside it.

---

## 3. Files touched, by step number

| File | Step | What | Pushed? |
|---|---|---|---|
| `Marlin DVR TV/RecordingsScreen.swift` | 2, 3, 4 | `ContinueItem.progress`; `PosterCard.progress` + the overlay before the clip; `PosterProgressBar` with the tokens | local |
| `Marlin DVR TVUITests/ContinueWatchingBarUITests.swift` | verify | new — the evidence harness | local |
| `reports/assets/pass92/92a-continue-watching-shelf-unfocused.jpg` | verify | new | local |
| `reports/assets/pass92/92b-continue-watching-card-focused.jpg` | verify | new | local |
| `reports/2026-09-16-pass92-progress-bar.md` | 6 | new — this report | local |
| `DECISIONS.md` | 6 | the 2026-09-16 (Pass 92) entry | local |
| `COLD-START.md` | 6 | "Next step", the Recordings line, the known-and-unfixed line | local |

**Nothing was pushed.** Local `main` is now two commits ahead of `origin/main`, which is still
`92a4770`; nothing forced, rebased or amended. **Step 5 is satisfied by the diff itself**: no file
outside the one app file was changed, so card size, poster, title, the "*n* min in" line, focus
behaviour, shelf membership, shelf order and `ResumeStore` cannot have moved. Not touched at all:
`design/`, `~/Xcode/marlin-dvr-reference`, `ResumeStore.swift`, the Player, the bedroom Apple TV,
and the server beyond GETs.

---

## 4. What went wrong, and what it cost — two failed runs before the one that counts

### 4.1 The first run: Down scrolls the shelf off the television

The harness reached the unfocused state by pressing **Down** into the shelf below. Measured: the
vertical `ScrollView` scrolls 570 pt to bring that shelf into view, carrying the Continue watching
heading to **y = −410** and its cards to **y = −324** — off the top of the screen.

```
[pass92 01:10:39.800] after Down, focus is 4 new, The Proof Is Out There, 4 episodes
[pass92 01:10:39.801] heading frame: (236.0, -410.0, 282.5, 41.0)
[pass92 01:10:40.232] cards at rest: … (276.0, -324.0, 252.0, 448.0) …
```

The harness caught it itself — the assertion "the Continue watching heading scrolled off screen"
was written for exactly this. The fix was to park focus in the **rail** instead, which leaves the
vertical scroll alone. The rail expands to 372 pt while it holds focus (`RailView.swift:67`) and
the content narrows with it; the card rects logged in §5.2 show what that costs, and it costs
nothing that matters — all five cards stay on screen (x 468 → 1848 of 1920).

### 4.2 The second run: `activate()` photographed a stale build — the one that mattered

The second run passed every assertion **and the screenshots had no bar on them at all.** The code
was in the installed device dylib (`nm` on
`build/p92/Build/Products/Debug-appletvos/…/Marlin DVR TV.debug.dylib` counts 220 references to
`PosterProgressBar`), and pixel-scanning the poster's bottom 12 px found the poster art running
unbroken into the card's border — no fill, and no track either, which ruled out "drawn but
invisible".

**The server's own log settled it.** The app pings on every launch (`ClientSession.swift:8-9`).

| Run | Launch ping |
|---|---|
| Pass 91, run 1 (00:48:57) | `POST /api/clients/<redacted>/ping` |
| Pass 91, run 2 (00:50:49) | `POST /api/clients/<redacted>/ping` |
| **Pass 92, run 1 (01:10)** | **none** |
| **Pass 92, run 2 (01:12)** | **none** |
| Pass 92, run 3 (01:18:59) | `POST /api/clients/<redacted>/ping` |

**No ping means the app never launched.** `XCUIApplication.activate()` resumed the Pass 91 process
that had been sitting on the television since 00:51; the new build was installed underneath it and
never started. Everything the first two runs photographed was Pass 91's binary.

`activate()` came from Pass 38, where it exists so that a process started separately **with a
console attached** is joined rather than replaced, and Passes 86 and 91 copied it without needing
that. **This harness attaches no console, so it uses `launch()`**, which terminates any running
instance and starts the build that was just installed. Run 3 pinged, and the bars were there.

This is worth carrying forward: **an `activate()` harness can silently photograph the previous
build.** Pass 91's evidence is not affected — the Continue watching shelf only exists in Pass 91's
binary and it drew — but any future pass using `activate()` without a console should check for the
launch ping before believing its screenshots.

### 4.3 What the two failed runs cost

Nothing but time. **Neither made a server write** (the whole three-run window contains exactly one
non-GET line, run 3's launch ping), nothing was played, deleted, trashed, kept or scheduled, and
the resume store on the Apple TV is **byte-identical before and after all three runs** (§5.3).

---

## 5. The verification — Home Theater

### 5.1 The run

```
xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
  -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p92 test -only-testing:"Marlin DVR TVUITests/ContinueWatchingBarUITests"
```

`build/p92` is git-ignored (`.gitignore:4:build/`). The passing bundle is
`build/p92/Logs/Test/Test-Marlin DVR TV-2026.09.16_01-18-51--0400.xcresult`.
**TEST SUCCEEDED, 24.570 s**, 2026-09-16 01:18:48–01:19:21. Home Theater now runs this build.

### 5.2 The transcript

```
[pass92 01:19:14.441] cards on entry:
  “The Proof Is Out There, S6 E17 · 40 min in”        (276.0, 221.5, 296.0, 511.0)
  “The Proof Is Out There, S6 E16 · 14 min in”        (602.0, 246.5, 252.0, 448.0)
  “History's Greatest Mysteries, S4 E14 · 15 min in”  (884.0, 246.5, 252.0, 479.0)
  “History's Greatest Mysteries, S7 E20 · 1 min in”  (1166.0, 246.5, 252.0, 479.0)
  “Hitler's DNA, 12 min in”                          (1448.0, 246.5, 252.0, 448.0)
[pass92 01:19:16.875] after Left, focus is Recordings
[pass92 01:19:16.876] heading frame: (428.0, 160.5, 282.5, 41.0)
[pass92 01:19:17.132] cards at rest: … all five 252.0 wide, x 468 → 1596 …
[pass92 01:19:19.904] after Right, focus is The Proof Is Out There, S6 E17 · 40 min in
** TEST SUCCEEDED **
```

The first card is 296 pt wide while focused and 252 pt at rest — Pass 47's growth, unchanged.

### 5.3 How the store was read, and that it did not move

`ResumeStore` lives in the Apple TV's own `UserDefaults`, and a test process cannot open it. It was
read **off the device**, with no change to the app and no diagnostic build:

```
xcrun devicectl device copy from --device <Home Theater> \
  --domain-type appDataContainer --domain-identifier com.marlin1111.MarlinDVRTV \
  --source Library/Preferences/com.marlin1111.MarlinDVRTV.plist --destination <scratch>
```

A read, into a session scratch directory outside the repo; the plist is **not committed** and
nothing from it other than the `marlinResume.*` entries appears anywhere in this repo. It was taken
**before** the first run and **after** the third, and the `marlinResume.*` entries are
**identical** — so the numbers below are the numbers the photographs were drawn from.

### 5.4 Each card: position, duration, fraction, and the bar that was drawn

Position and duration are the store's own values, to the millisecond. The measured fill is read off
the 3840 × 2160 screenshot at 2 px per point, against the poster's own measured edges.

| # | Recording | id | position s | duration s | fraction | fill drawn | measured | difference |
|---|---|---|---|---|---|---|---|---|
| 1 | The Proof Is Out There **S6 E17** | `ef4d2419605d` | 2450.000 | 4216.212 | **0.58109** | 146.0 pt of 250.5 | 0.5828 | **0.44 pt** |
| 2 | The Proof Is Out There **S6 E16** | `dd5f3e4a6778` | 891.001 | 4270.266 | **0.20865** | 52.0 pt of 250.5 | 0.2076 | **0.27 pt** |
| 3 | History's Greatest Mysteries **S4 E14** | `5328bb632e76` | 931.002 | 2570.568 | **0.36218** | 91.0 pt of 250.5 | 0.3633 | **0.27 pt** |
| 4 | History's Greatest Mysteries **S7 E20** | `cac7c08639ec` | 105.000 | 504.504 | **0.20813** | 52.0 pt of 250.5 | 0.2076 | **0.14 pt** |
| 5 | **Hitler's DNA** | `d9a4f5c76696` | 739.021 | 6138.132 | **0.12040** | 30.0 pt of 250.5 | 0.1198 | **0.16 pt** |

Every bar is within **half a point** of the stored fraction — one screen pixel — across fractions
from 0.12 to 0.58. The measured poster width is 250.5 pt against the source's 252, which is the
antialiased edge, and the same 1.5 pt is in every row.

**The focused card, separately:** poster 553 → 1142 px = **295 pt** (source 296), fill **343 px =
171.5 pt**, measured fraction **0.5814** against the store's **0.58109** — a difference of
**0.08 pt**. So the bar tracks the card's growth exactly.

**The store's durations agree with the server's own recording lengths**, which is a second,
independent check that the denominator is the right one:

| Recording | store duration | server `airedLabel` |
|---|---|---|
| S6 E17 | 4216.212 s = 70.3 min | 1 hr 10 min |
| S6 E16 | 4270.266 s = 71.2 min | 1 hr 11 min |
| S4 E14 | 2570.568 s = 42.8 min | 43 min |
| S7 E20 | 504.504 s = 8.4 min | 8 min |
| Hitler's DNA | 6138.132 s = 102.3 min | 1 hr 42 min |

### 5.5 The bar's height, and what covers it

| | band | height | visible accent |
|---|---|---|---|
| Unfocused card | y 1203–1214 px | **12 px = 6 pt** | 5 pt — the bottom 1 pt is under the card's own 1 pt `Nocturne.neutral900` border, which is drawn after the clip |
| Focused card | y 1279–1290 px | **12 px = 6 pt** | 2 pt — the bottom 4 pt is under the accent focus ring, which is the same colour |

**The bar is the same 6 pt in both states**, as step 4 asks. What differs is how much of it you can
tell apart from the border or the ring drawn over it, which is §7 open question 1.

### 5.6 The two screenshots — `reports/assets/pass92/`

Exported with `xcrun xcresulttool export attachments` from the passing bundle, then converted from
3840 × 2160 PNG to 1920 × 1080 JPEG with `sips -Z 1920 -s format jpeg`, so 1 px is 1 pt.

| Screenshot | What it shows, as viewed |
|---|---|
| **`92a-continue-watching-shelf-unfocused.jpg`** | The Recordings screen with focus parked on the rail's Recordings entry, so **no Continue watching card is focused**. All five posters carry a bar along the bottom edge: a long fill on S6 E17, a short one on S6 E16 and S7 E20, a middling one on S4 E14, a very short one on Hitler's DNA. The "Recently Updated" cards below carry **no bar** and keep their "*n* new" badges. |
| **`92b-continue-watching-card-focused.jpg`** | The same shelf with **S6 E17 focused** — grown box, 22 pt lift, accent ring — and its bar grown with it. Its fill boundary is visible a little over half way across; below it the accent ring runs the full width, so the bar reads as a thickening of the ring rather than as a separate bar. The four cards beside it are unchanged from `92a`. |

### 5.7 What is run-verified and what is code-traced

| Claim | Status |
|---|---|
| A bar is drawn across the bottom of every Continue watching card | **RUN** — `92a`, five of five |
| Its fill is `position ÷ duration` from the store | **RUN** — §5.4, within 0.5 pt on all five |
| Cards on the other shelves have no bar | **RUN** — `92a`, the Recently Updated row |
| The fill is `Nocturne.accent` | **RUN** — pixels read exactly `(145,132,217)` |
| The unfilled part is `Nocturne.bg` at 0.7 | **RUN** — reads `(15…17, 16…18, 27…30)` over these posters |
| 6 pt in both states; the focus growth widens it to the focused card | **RUN** — §5.5, and 295 pt vs 250.5 pt |
| Inside the card's corner radius, nothing outside the layout box | **RUN** — the bar's ends are trimmed by the poster's corners in `92a`; the card rects are unchanged from Pass 91's |
| No animation, no percentage text, no time text | **TRACED** — the view has none; a still photograph cannot prove the absence of an animation |
| **A zero or missing duration draws no bar** | **TRACED** — all twelve stored entries have a real duration, so the `nil` branch was not exercised. It could not be without writing a bad entry to the owner's store, which was not authorised and not done |
| Card size, poster, title, the "*n* min in" line, focus behaviour, shelf membership and order, `ResumeStore` | **TRACED** — one file changed and none of them is in it; the harness's card rects match Pass 91's exactly |
| The bedroom Apple TV | **NOT TOUCHED** — still runs `168d8a7` |

### 5.8 A Pass 91 open item closed on the way past

Pass 91 had to label **"newest position first"** as *traced, not measured*, because nothing draws
`savedAt`. The store read in §5.3 contains it, and it settles the question:

| Card, in the order drawn | `savedAt` |
|---|---|
| 1 The Proof Is Out There S6 E17 | 2026-09-16 00:30:17 |
| 2 The Proof Is Out There S6 E16 | 2026-09-16 00:29:43 |
| 3 History's Greatest Mysteries S4 E14 | 2026-09-08 22:16:00 |
| 4 History's Greatest Mysteries S7 E20 | 2026-09-08 21:09:19 |
| 5 Hitler's DNA | 2026-09-08 10:12:24 |

Strictly descending, matching the drawn order exactly. **Pass 91's ordering is now measured.**

The same read also confirms Pass 91's other traced claim: the store holds **twelve** entries and
only **five** draw cards. The other seven belong to recordings that have left the library —
including `6007a13f0b46`, the recording Pass 31 deleted, and `eccf81dbdab2` from Pass 32 — and they
are simply never matched, so they draw neither a card nor a bar.

---

## 6. What the run asked the server for

`GET /api/logs`, seq 7703–7759. The only non-GET line in the whole run is the launch ping:

```
7708 01:18:59.699 INFO HTTP POST /api/clients/<redacted>/ping 200
7709 01:18:59.703 INFO HTTP GET  /api/library 200
7716 01:19:09.102 INFO HTTP GET  /api/library 200
7717 01:19:09.133 INFO HTTP GET  /api/library/shows/history-s-greatest-mysteries 200
7724 01:19:09.156 INFO HTTP GET  /api/library/shows/the-proof-is-out-there 200
7727 01:19:09.166 INFO HTTP GET  /api/library/shows/the-food-that-built-america 200
7728 01:19:09.178 INFO HTTP GET  /api/library/shows/hitler-s-dna 200
```

**The bar costs no request at all** — it is drawn from numbers already on the card. The reads above
are Pass 91's, unchanged: one library read for the shelves and one per show to resolve the saved
positions.

---

## 7. Open questions

1. **The focused card's bar is mostly under the focus ring, and the ring is the same colour.** The
   ring is 4 pt of `Nocturne.accent` over the bar's bottom 4 pt of 6, so only 2 pt of the bar is
   distinguishable while a card is focused (`92b`). Three ways out, none of them built: give the
   focused card a taller bar; move the bar up by the ring's width while focused; or leave it, on
   the grounds that a focused card is the one you are about to open anyway and show detail states
   the position in words. **The owner's call.**
2. **The unfilled part over a bright poster.** These five posters are dark along the bottom, so
   `Nocturne.bg` at 0.7 reads as a clean dark track. Over a bright bottom edge it will read as a
   dark scrim rather than a solid track. Nothing in the owner's library shows that today, so it has
   not been seen.
3. **Nothing distinguishes 99 % watched from 100 %.** A recording is on this shelf until it is
   played to its end (Pass 91), so a bar can sit at 0.99 and look full. Whether that wants its own
   treatment is a decision, not a defect.
4. **The bar is silent to VoiceOver.** It draws no text and has no accessibility value, so the card
   still reads "The Proof Is Out There, S6 E17 · 40 min in" and nothing about the bar. That is what
   kept the Pass 91 harness's assertions valid, and it is also a gap; adding a value was not named
   by this pass and was not built.
5. **`ProgressBar` and `PosterProgressBar` are now two views drawing the same number.** They differ
   deliberately (capsule vs rectangle, opaque vs translucent track), but if the owner would rather
   have one, the merge is a parameter on `ProgressBar` and a change to show detail's bars with it.
6. **Should `activate()` be replaced in the other harnesses?** `ContinueWatchingUITests` (Pass 91),
   `GuideChannelLogosUITests` (Pass 86) and `OnLaterPillsUITests` all use it without a console, and
   all three can photograph a stale build the way §4.2 did. Not changed: they are other passes'
   files and this pass's scope lock does not name them.

---

## 8. What I am least sure of

- **The zero-duration branch.** It is one `guard` and I am confident in the code, but it was never
  exercised: every entry on the Apple TV has a real duration, and producing one without would have
  meant writing a bad entry into the owner's own store. It is the one behaviour in this pass he
  could meet before I do.
- **How the focused bar reads on a television rather than in a screenshot.** The measurement says
  the fill boundary is there and the photograph shows it, but "2 pt of bar above a 4 pt ring of the
  same colour" is exactly the sort of thing that looks fine at pixel level and indistinct from the
  sofa. Open question 1 exists because I do not trust my own eye on it.
- **The 0.7 opacity.** It is the one translucency the theme already names, which is why it was
  chosen, but it was chosen — nothing in the design system specifies a progress *track* opacity,
  because the design's own progress track (dc:93-95) is opaque. If the owner wants it darker or
  lighter it is one number.
- **That two runs photographed a stale build is the kind of mistake that hides.** It was caught
  because the bar was missing and I went looking. A subtler change — a colour, a pixel of height —
  might not have announced itself, and nothing in the harness would have failed. The `launch()`
  fix closes it here and nowhere else (open question 6).
