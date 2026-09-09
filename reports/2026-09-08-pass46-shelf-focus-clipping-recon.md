# Pass 46 — Recordings shelf focus clipping: recon

**Date:** 2026-09-08
**Read-only on all code. Exactly one file is written this pass: this report.**
No Swift source file, project setting, build script, config or dependency was changed. `design/` was
**read** — it is this pass's reference for the focused state — and **not edited**. No build, no
simulator run, no device run, no test. **No request of any kind to `192.168.1.250:8090`.** The
reference clone was not read, fetched or touched.

**I cannot see the owner's screen and make no claim about how anything looks.** Everything below is
about what the code does, plus arithmetic from the numbers in it.

---

## 0. What the existing record settles, and what it does not

`COLD-START.md` and `DECISIONS.md` were read. What they settle:

- **The approved design is `design/`** and the screens are built to it; it is read-only
  (`COLD-START.md` "Where things live"; `DECISIONS.md` 2026-09-05 (design)).
- **The shelf card variant was chosen by the owner: "4a poster 2:3 shelf cards"**
  (`DECISIONS.md`, 2026-09-05 (design)).
- **Rail focus is settled and is not this defect.** Pass 25 fixed swipe-left restore and proved it
  27 of 27 on the device; nothing in it touches card geometry.
- **The only prior report on these shelves is `reports/2026-09-07-pass31-delete-refresh.md`**,
  confirmed by listing `reports/` this pass. It is about `RecordingsModel.load()` being called from
  one place and a deleted recording not leaving the shelves — **a data-refresh defect, not layout.**
  It settles nothing about focus geometry, and nothing in it is re-derived here.

**Nothing in the notebook describes this defect or its cause.** It is new.

---

## 1. Git state, read-only — four raw outputs

Each run as its own command. Nothing was changed or committed at this step.

```
$ git rev-parse HEAD
04f30fd8d623c31231355d095bbd5501179ba211
```

```
$ git rev-parse origin/main
04f30fd8d623c31231355d095bbd5501179ba211
```

```
$ git ls-remote origin main
04f30fd8d623c31231355d095bbd5501179ba211	refs/heads/main
```

```
$ git status --porcelain
(no output — clean tree)
```

---

## 2. The code, with file:line

**The sources were enumerated in this pass**, not remembered: `find "Marlin DVR TV" -name '*.swift'`
returned **47** files, and the count was confirmed by hand from a numbered `ls -1 | grep '\.swift$' | nl`
listing that ends at line 47, whose only non-Swift sibling in that folder is `Assets.xcassets`.

### 2.1 The screen and the shelf container

`Marlin DVR TV/RecordingsScreen.swift`, 213 lines.

**There is no literal string "Recently Watched" anywhere in the app** —
`grep -rn "Recently Watched\|recentlyWatched" --include="*.swift" .` returns nothing. The shelf
heading is **the server's own `section.label`**, drawn at **`RecordingsScreen.swift:105-107`**. So
"Recently Watched" is one of the sections `GET /api/library` returns, and the shelf that draws it is
the generic one below.

The structure, with indent depth verified by `awk`:

| Line | What |
|---|---|
| `:89-90` | `shelves` → `VStack(alignment: .leading, spacing: 38)` |
| `:101` | **`ScrollView(.vertical, showsIndicators: false)`** — the outer scroller |
| `:102` | `VStack(alignment: .leading, spacing: 22)` — one child per section |
| `:103` | `ForEach` over `model.library?.sections` |
| `:104` | `VStack(alignment: .leading, spacing: 18)` — **heading + row, 18 pt apart** |
| `:105-107` | `Text(section.label)` at `.nocturne(34, .medium)` — the heading |
| `:114` | **`ScrollView(.horizontal, showsIndicators: false)`** — the shelf itself |
| `:115` | `HStack(alignment: .top, spacing: 30)` |
| `:121` | `PosterCard(show: show, focused: focused == id)` |
| `:127` | **`.padding(.vertical, 44)`** |
| `:128` | `.padding(.horizontal, 40)` |
| `:129` | the horizontal `ScrollView` closes |

**The padding at `:127-128` is on the `HStack`, inside the ScrollView, not on the ScrollView.**
Verified by indentation rather than by eye: `:127` and `:128` sit at indent **36**, the same as the
`HStack` at `:115`, while the ScrollView's own closing brace is at indent **32** on `:129`. This
matters for every number below — it means the 44 pt is *inside* the clipping region, not outside it.

### 2.2 The poster card, its size and aspect

`PosterCard`, **`RecordingsScreen.swift:173-213`**.

- Art frame **252 × 344** — `:182`. That is 2:3 to within a rounding step (252 × 3/2 = 378; the
  design uses 344, see §5).
- Outer `VStack(alignment: .leading, spacing: 14)` — `:178`, three children, so **two 14 pt gaps**.
- Title `Text` at `.nocturne(Nocturne.TextSize.secondary)` = **26 pt**, `.lineLimit(2)` — `:200-203`,
  size at `Theme.swift:71`.
- Count `Text` at `.nocturne(Nocturne.TextSize.floor)` = **23 pt** — `:204-206`, size at
  `Theme.swift:70`.
- `.frame(width: 252, alignment: .leading)` — `:208`. **A width only. No height is ever declared for
  the card.**

### 2.3 Every focus-driven visual effect on that card

| Effect | Line | Value |
|---|---|---|
| Focus ring | `:196-198` | `strokeBorder` on the art's `RoundedRectangle`, `Nocturne.accent`, width `Nocturne.Focus.ringWidth` = **4** (`Theme.swift:81`); unfocused 1 pt `neutral900` |
| Shadow | `:199` | `radius: Nocturne.Focus.shadowRadius` = **32** (`Theme.swift:84`), `y: Nocturne.Focus.shadowY` = **26** (`Theme.swift:85`), `Focus.shadowColor` = black at 0.7 |
| **Scale** | **`:209`** | **`.scaleEffect(focused ? 296.0 / 252.0 : 1, anchor: .center)`** |
| **Offset** | **`:210`** | **`.offset(y: focused ? -22 : 0)`** — 22 pt **upward** |
| Animation | `:211` | `.easeOut(duration: 0.15)` on `focused` |

There is **no `.focusEffect`, no `.hoverEffect`, and no `.focusSection`** on the card. The ring is
drawn by the app itself, not by the system.

**`.scaleEffect` and `.offset` are both render-time transforms. Neither changes the view's layout
size.** The card's layout footprint stays 252 pt wide and its unfocused height tall, whatever the
focus state; the grown card is drawn outside that footprint.

### 2.4 Every container between the card and the screen that could crop it

Searched app-wide rather than assumed:

- `grep -rn "scrollClipDisabled\|\.clipped()\|contentMargins\|\.mask("` over every Swift file returns
  **three hits, none of them on this path**: `ServerImage.swift:26`, `GuideScreen.swift:556`,
  `CamerasScreen.swift:136`. **`.scrollClipDisabled()` does not appear anywhere in the app.**
- `RecordingsScreen.swift` contains **no `.clipped()`, no `.mask()`, no `.contentMargins()`**, and
  its only `.clipShape` is `:183`, which rounds the artwork's own corners *inside* the card.
- `ScreenShell.swift` — the ancestor that hosts every screen — has **no clip of any kind**: its only
  modifiers on the content are four `.padding`s and a `.frame(maxWidth:maxHeight:alignment:)`
  (`ScreenShell.swift:52-56`).
- `ScreenChrome.swift`'s `ScreenHeader` (`:13`) applies padding and a `.frame(height: 6)` to a
  progress capsule (`:161`) — nothing on this path.
- **No fixed row height exists on the populated branch.** The only `.frame(height:)` in the shelf
  region is `:112`, and it is on the *empty-state* `Text("Nothing yet.")`, in the
  `if section.items.isEmpty` arm — not on the row that draws cards.

**So exactly two containers can clip: the horizontal `ScrollView` at `:114` and the vertical one at
`:101`.** A SwiftUI `ScrollView` clips its content to its bounds by default, and the modifier that
turns that off — `.scrollClipDisabled()`, available on the app's tvOS 18.0 deployment target
(`DECISIONS.md`, 2026-09-05) — is used nowhere.

### 2.5 The arithmetic — does the row have room for the grown card?

**The scale factor**, from `:209`:

```
scale      = 296 / 252 = 1.1746031746…
scale − 1  = 0.1746031746…
```

Because the anchor is `.center` (`:209`), growth is **split equally above and below**:

```
half-growth = (scale − 1) / 2 = 0.0873015873…  = exactly 22/252
```

**The upward overhang** beyond the card's layout top, in points, for a card of unfocused height `H`:

```
overhang_up = H × (22/252)  +  22        ← the .offset(y: -22) at :210
```

**The room available above it** is the `.padding(.vertical, 44)` at `:127` — 44 pt — because that
padding is *inside* the clipping ScrollView (§2.1).

**The threshold.** Clipping begins when `overhang_up > 44`:

```
H × (22/252) + 22 > 44
H × (22/252)      > 22
H / 252           > 1
H                 > 252 pt
```

**The card clips whenever it is taller than 252 pt — and its artwork alone is 344 pt** (`:182`). The
defect is therefore structural, not marginal: no combination of title lengths avoids it.

**How much is lost.** `H` = 344 (art) + 14 + 14 (two VStack gaps, `:178`) + title + count.

*Absolute lower bound*, treating both text lines as zero height — impossible, but it bounds the
answer:

```
H_min       = 344 + 28                    = 372 pt
overhang_up = 372 × 22/252 + 22           = 32.48 + 22 = 54.48 pt
available   =                               44 pt
clipped     = 54.48 − 44                  = 10.5 pt          ← the least it can possibly be
```

*Realistic*, using the system font's usual ≈1.2× line height (26 pt → ≈31 pt, 23 pt → ≈28 pt).
**These two line heights are estimates — they are the only estimated numbers in this report**, and
measuring them needs a build, which is out of scope:

```
one-line title:  H ≈ 344 + 14 + 31 + 14 + 28 = 431 pt
                 overhang_up ≈ 431 × 22/252 + 22 = 37.6 + 22 = 59.6 pt
                 clipped     ≈ 59.6 − 44                     ≈ 15.6 pt

two-line title:  H ≈ 344 + 14 + 62 + 14 + 28 = 462 pt        (lineLimit(2), :203)
                 overhang_up ≈ 462 × 22/252 + 22 = 40.3 + 22 = 62.3 pt
                 clipped     ≈ 62.3 − 44                     ≈ 18.3 pt
```

**The other three edges, checked the same way — and they do not clip:**

```
downward:   H × 22/252 − 22  ≈ 37.6 − 22 = 15.6 pt   vs 44 available  → 28.4 pt to spare
sideways:   252 × 22/252     = 22 pt each side       vs 40 available  → 18 pt to spare
```

**That asymmetry is produced entirely by the `-22` offset at `:210`**, and it is the signature of
this defect: the offset pushes the card up into a margin that the centre-anchored growth has already
half-consumed, while the bottom and sides keep their full clearance.

---

## 3. The cause

**(a) and (d) together, and they are two halves of one mechanism. Not (b), and (c) only as a
contributing factor.**

**The line that does the cropping is `RecordingsScreen.swift:114`** — `ScrollView(.horizontal,
showsIndicators: false)`. A SwiftUI ScrollView clips its content to its bounds, nothing in this app
disables that, and `.scrollClipDisabled()` appears nowhere in the codebase (§2.4). Its content is the
HStack plus the `.padding(.vertical, 44)` at `:127`, so its top edge sits exactly 44 pt above the
card's layout top.

**The lines that make the clip bite are `:209` and `:210`** — the centre-anchored
`scaleEffect(296.0/252.0)` and the `offset(y: -22)`. Together they place the focused card's rendered
top **≈59.6 pt** above its layout top (§2.5), which is **≈15.6 pt beyond** the 44 pt of room the
padding provides.

**Ranked:**

1. **(d) Insufficient padding above the row for the overhang** — `:127`, 44 pt where ≈60 pt is
   needed. This is the proximate cause and the one the arithmetic pins exactly.
2. **(a) A clip on an ancestor container** — `:114`. This is the mechanism that turns the shortfall
   into a visible crop instead of a harmless overhang. Without the clip, 44 pt of room would not
   matter.
3. **(c) The scale anchor** — contributing, not sufficient. `.center` at `:209` sends half the growth
   (≈37.6 pt) upward, which alone would still fit in 44 pt. **It only overflows once the `-22`
   offset at `:210` is added.** So the offset, not the anchor, is what breaks the budget — and the
   offset is faithful to the design (§5), which is why (c) should not be blamed on its own.
4. **(b) A fixed row/container height — ruled out.** There is no `.frame(height:)` on the row, the
   HStack, either ScrollView, or the card. The only one nearby is `:112`, on the empty-state text in
   the other branch of the `if` (§2.4).

**The evidence is arithmetic and code reading, not observation**, and it is consistent with all four
edges the owner described: the top exceeds its budget by ≈10–18 pt while the bottom and both sides
retain 18–28 pt of clearance (§2.5). **What I have not done is watch it happen** — that needs a build
and a device, both out of scope here.

---

## 4. Is this card or shelf used anywhere else?

**No. It is used in exactly one place, and a change to it cannot affect another screen.** Three
searches, all run in this pass:

- `grep -rn "PosterCard" --include="*.swift" .` → **two hits**: the declaration at
  `RecordingsScreen.swift:173` and the single use at `RecordingsScreen.swift:121`.
- `grep -rn "ScrollView(.horizontal" --include="*.swift" .` → **one hit in the whole app**:
  `RecordingsScreen.swift:114`. Home, On Later, Favorites, On Now, Cameras and Radio have no
  horizontal shelf at all.
- `grep -rn "scaleEffect" --include="*.swift" .` → **three hits**, and the other two are not cards:
  `HomeView.swift:123` and `PlayerScreen.swift:119`, both `scaleEffect(x:y:)` stretching a gradient.

Those screens were not investigated further and nothing is proposed for them.

---

## 5. What the approved design specifies

`design/Marlin DVR TV.dc.html`, 1,411 lines. The 4a poster shelf is at `dc:370-395` and its data at
`dc:1266-1276`.

**The focused card's geometry**, `dc:1273`:

```
w: i === 1 ? 296 : 252,  h: i === 1 ? 404 : 344,  lift: i === 1 ? -22 : 0,
```

and `dc:1274-1275`:

```
shadow: i === 1 ? "0 26px 64px rgba(0,0,0,.7)" : "var(--shadow-sm)",
ring:   i === 1 ? "4px solid var(--color-accent)" : "1px solid var(--color-neutral-900)"
```

**So the design does specify the focused state, and precisely:** 252 × 344 → **296 × 404**, a
**−22 px lift**, a 4 px accent ring, and a `0 26px 64px rgba(0,0,0,.7)` shadow. The app's ring (4 pt),
shadow (radius 32, y 26) and lift (−22) all match. The app's scale factor also matches: 344 × 296/252
= 404.06, against the design's 404.

**But the design grows the card by changing its layout box, and the app grows it with a render
transform.** In the design the card is a flex item whose `width` and `height` are the focused values
(`dc:382-383`), so the row genuinely reflows around a bigger card; the only thing that moves it
upward is `transform:translateY(-22px)` at `dc:382`. In the app, `scaleEffect` at `:209` changes
nothing about layout, so **half the 60 pt of growth is thrown upward on top of the 22 pt lift**. That
difference — ≈37.6 pt of upward growth the design never produces — is the whole of the overflow.

**What the design puts above the row:** the heading `<h3>Recently watched</h3>` at `dc:377` sits in a
flex row with **`margin-bottom:26px`** (`dc:376`), and the card's only upward movement is the 22 px
lift — **22 < 26, so it fits by 4 px.** The design's outer demo box does carry `overflow:hidden`
(`dc:375`) with `padding:44px 80px`, but that 44 px is above the *heading*, not above the row, and it
is a crop frame for the design page's own presentation — `dc:366` calls these "Crops of the
Recordings shelf at full width".

**The app's 44 pt at `:127` is the design's `padding:44px` applied one level too low** — to the row
instead of to the panel — where it has to absorb an overhang the design never creates.

**The design does not specify a scroll container, a clip, or any padding of its own around the
row.** On that, it is silent, and the app had to invent both.

---

## 6. FIX PLAN — on paper only, nothing built

Three honest options. **They are not ranked and I have not chosen between them** — the trade-offs are
real and the choice is the owner's. All three are confined to `RecordingsScreen.swift`; none touches
another screen (§4).

### Option A — give the overhang the room it needs

1. **`RecordingsScreen.swift:127`** — raise `.padding(.vertical, 44)` to at least the computed
   `overhang_up`. The arithmetic in §2.5 gives ≈60 pt for a one-line title and ≈62 pt for two lines;
   a value of **64** clears both with margin. Vertical padding is symmetric, so this also adds the
   same to the bottom, which is harmless but makes each shelf ~40 pt taller.
2. **`RecordingsScreen.swift:104`** — the section `VStack(alignment: .leading, spacing: 18)` may then
   want less spacing, since the row's own padding has grown. **Not a step**: whether the shelves
   still look right is a judgement only the owner can make, and §5 gives no design number for it.

*Trade-off:* smallest, most local change; keeps `scaleEffect`. Costs vertical space, so fewer shelves
fit on screen, and the extra padding is invisible except when a card is focused.

### Option B — stop the container clipping

1. **`RecordingsScreen.swift:114`** — add `.scrollClipDisabled()` to the horizontal `ScrollView`.

*Trade-off:* one line, and it lets the card overhang cleanly the way the design does. **But the
arithmetic warns of a second effect the owner should know about before choosing it.** With the clip
gone, the focused card's rendered top lands ≈`(heading height + 18 + 44) − 59.6` from the section's
top — with a 34 pt heading at ≈41 pt tall, that is roughly **2 pt below the heading's bottom edge**.
It would clear the heading, but only just, and my ±few-pt estimate of the text line heights is inside
that margin. It may also let cards overhang the shelf above and below during the 0.15 s animation
(`:211`). This option is honest but its clearance is not proven.

### Option C — grow the card in layout, the way the design does

1. **`RecordingsScreen.swift:182`** — make the art frame `focused ? 296 : 252` wide and
   `focused ? 404 : 344` tall, the design's own numbers (`dc:1273`).
2. **`RecordingsScreen.swift:208`** — make the outer `.frame(width:)` `focused ? 296 : 252` to match.
3. **`RecordingsScreen.swift:209`** — delete the `.scaleEffect`.
4. **`RecordingsScreen.swift:210`** — keep `.offset(y: -22)` unchanged; it is the design's `lift`.

*Trade-off:* this is what `design/` actually specifies, and it reduces the upward overhang from
≈59.6 pt to exactly **22 pt**, which the existing 44 pt padding already accommodates with 22 pt to
spare — **no padding change and no clip change needed.** The cost is that the row reflows on every
focus change: neighbouring cards shift sideways as the focused one widens by 44 pt, which
`scaleEffect` does not do. Whether that reflow looks right — or janky — under the 0.15 s animation is
**not something I can judge without running it**, and it is the reason this option is not
automatically the winner despite matching the design.

**Not in any option, deliberately:** the shadow at `:199` is also being clipped (radius 32, y +26,
so it extends ≈58 pt below and ≈6 pt above the art). Fixing the top does not necessarily give the
shadow full room. **Raised as a question below rather than built into a step**, because the owner has
never reported the shadow as wrong and I will not widen the defect on my own judgement.

---

## 7. Open questions

1. **Two line-height numbers in §2.5 are estimates, not measurements.** The system font's line height
   at 26 pt and 23 pt was taken as ≈1.2×. **This does not affect the conclusion** — the threshold
   proof (`H > 252 pt`, against 344 pt of artwork alone) needs no text height at all, and the
   zero-height lower bound still clips by 10.5 pt. It affects only the *size* of the shortfall and
   the tightness of Option B's clearance. Measuring it needs a build.
2. **Which of the three options does the owner want?** They differ in what they cost: Option A costs
   vertical space, Option B has an unproven ≈2 pt clearance against the heading, Option C matches the
   design but makes the row reflow on focus. **Not chosen here.**
3. **The focus shadow is clipped too, and no step addresses it.** `:199` gives radius 32 at y +26.
   *Why it seems needed:* if the owner ever notices the shadow cut off at the row's edges, it is the
   same mechanism. *What breaks without it:* nothing he has reported — the shadow is dark on a dark
   background and its loss is far less visible than the card's own edge.
4. **I never watched the defect.** Every claim here is code reading and arithmetic. A device run
   would confirm which container clips first and what the real overhang is, and would settle
   question 1 outright — but building and running were out of scope for this pass.
5. **The design's 4a artwork is 344 pt tall for a 252 pt width, which is not 2:3** (2:3 would be
   378). The app copies the design faithfully at `:182`, and `DECISIONS.md` records the owner's
   choice as "4a poster 2:3 shelf cards". **Nothing was changed and nothing is proposed** — the
   discrepancy is in the approved design, it long predates this defect, and it is irrelevant to the
   clipping. Recorded only so a later pass does not mistake it for a transcription error.

---

## 8. SCOPE CHECK — every file touched or created

| Path | Access | Required by |
|---|---|---|
| `COLD-START.md`, `DECISIONS.md` | read | step 0 / required reading |
| `reports/2026-09-07-pass31-delete-refresh.md` | listed and identified as the only prior shelf report | required reading |
| `Marlin DVR TV/*.swift` (47 enumerated; 4 read closely) | **read only** | step 2 |
| `Marlin DVR TV/RecordingsScreen.swift` | **read only** | steps 2.1–2.5, 3, 4, 6 |
| `Marlin DVR TV/Theme.swift` | **read only** | steps 2.2, 2.3 |
| `Marlin DVR TV/ScreenShell.swift`, `ScreenChrome.swift` | **read only** | step 2.4 |
| `design/Marlin DVR TV.dc.html` | **read only, never edited** | step 5 |
| `reports/2026-09-08-pass46-shelf-focus-clipping-recon.md` | **created — the only write** | DELIVERABLE, step 7 |

**No Swift source file, project setting, build script, config or dependency was modified**, and no
"obvious one-line fix" was applied.

**Not touched:** every other folder under `~/Xcode`; the reference clone; the Marlin DVR server and
its API — **zero requests of any kind**; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share; every
file in `design/` (read, never written); the Xcode project, `Info.plist`, the entitlements file and
`build/`.

**No new dependency.** No credential, token, device id or account identifier appears in this report.

---

## 9. The push, and the three readings

<!--PUSH_EVIDENCE-->

---

## CLOSING SUMMARY FOR THE OWNER

**What is actually cutting the card off.** The shelf is a horizontal scrolling strip, and scrolling
strips crop whatever spills outside them — that is their normal behaviour and nothing in the app
turns it off. When a card takes focus, two things happen to it at once: it is scaled up by about 17 %
*from its centre*, so roughly 38 points of new height appear above its old top edge, and then it is
lifted a further 22 points upward. That is about **60 points of card sticking out above where it
used to sit — into a gap that is only 44 points deep.** The last ~16 points have nowhere to go, so
the strip cuts them off. The bottom and the sides do not suffer because the 22-point lift pulls the
card *away* from the bottom edge and does nothing sideways, which is exactly the lopsided result you
described.

The important part is that **this is structural, not marginal**: the sums say any card taller than
252 points will clip, and the artwork alone is 344. It was never going to fit.

**How big a fix it is.** Small, and confined to one file — this card and this shelf exist in exactly
one place in the app, so nothing else can be disturbed. But there are **three honest ways to do it
and I have deliberately not picked one**, because they cost different things: give the row more
room (costs vertical space on screen), tell the strip to stop cropping (one line, but the card would
then sit about 2 points from the heading — too close for me to promise it is safe), or grow the card
the way `design/` actually specifies, by changing its real size rather than scaling it (matches the
approved design and needs no other change, but neighbouring cards would shift sideways each time
focus moves, and I cannot tell you whether that looks good without running it).

Worth knowing: the design does specify this state exactly — 252×344 growing to 296×404, lifted 22 —
and the app's ring, shadow, lift and scale factor all match it. The one thing that differs is *how*
the growth is done, and that difference is the entire defect.

**What this pass cost.** Read-only throughout: four git reads, 47 source files enumerated and four
read closely, the design file read, and one file written — this report. No build, no simulator, no
device, no server request, and no code changed.

**The three things I am least certain about.**

1. **I never saw it happen.** Everything here is reading the code and doing the arithmetic. I am
   confident about the mechanism because the sums predict exactly the lopsided pattern you
   photographed, but a device run would prove it rather than infer it.
2. **Two numbers are estimates** — how tall a line of the title and count text actually is. They do
   not change the diagnosis (the artwork alone already blows the budget), but they do change whether
   the "stop cropping" option clears the heading by 2 points or by nothing at all.
3. **Whether option C looks right in motion.** It is the one that matches your approved design and
   needs no other change, but it makes the row shuffle sideways whenever focus moves. That might be
   perfectly pleasant or it might be distracting, and that is a judgement I cannot make from source.
