# Pass 47 — the shelf focus clipping fixed, the design's own way

**Date:** 2026-09-08
**Committed locally. NOT pushed** — this is UI the owner judges with his eyes, so it sits behind the
separate push gate.
**One file changed:** `Marlin DVR TV/RecordingsScreen.swift`. No project setting, build script,
config or dependency was touched and no new dependency was added. `design/` was **read** (dc:1273 and
dc:382-390) and **not edited**. `COLD-START.md` and `DECISIONS.md` were not touched — the notebook is
a later pass, after the owner tests.

The app talked to `http://192.168.1.250:8090/` during the device test; that is ordinary app traffic.
**No administrative, diagnostic or shell request was made to the server and nothing on it was
changed.**

**Option C was built, exactly as the owner chose.** Options A (more padding) and B
(`.scrollClipDisabled()`) were **not** built, not stubbed, and not added as a safety net.
`RecordingsScreen.swift:114` and `:127` are untouched.

---

## 1. Every changed line, before and after

Three hunks, all inside `PosterCard`. Verified with `git diff -U0`: the hunk headers are
`@@ -172,0 +173,14 @@`, `@@ -182 +196 @@` and `@@ -208,2 +222 @@` — **every one is past line 172**,
so nothing before it in the file was reached.

### 1.1 The art box grows — `:182` → `:196`

```diff
-            .frame(width: 252, height: 344)
+            .frame(width: focused ? 296 : 252, height: focused ? 404 : 344)
```

The design's own numbers, `dc:1273`: `w: i === 1 ? 296 : 252, h: i === 1 ? 404 : 344`.

### 1.2 The card's container grows with it — `:208` → `:222`

```diff
-        .frame(width: 252, alignment: .leading)
+        .frame(width: focused ? 296 : 252, alignment: .leading)
```

`dc:382` applies `s.w` as the card container's `width`.

### 1.3 The scale is gone — old `:209`, deleted

```diff
-        .scaleEffect(focused ? 296.0 / 252.0 : 1, anchor: .center)
```

**Removed, not left in place alongside the layout change**, as step 2 requires. `grep -n
"scaleEffect" "Marlin DVR TV/RecordingsScreen.swift"` now returns **one hit and it is inside a
comment** (`:177`, describing why it went). Nothing in the pass needed it to survive.

### 1.4 Unchanged, deliberately

```
:223   .offset(y: focused ? -22 : 0)            ← dc:1273 `lift: -22`, and dc:382 translateY
:224   .animation(.easeOut(duration: 0.15), value: focused)
:211   .strokeBorder(… Nocturne.Focus.ringWidth : 1)   ← 4 pt accent ring, dc:1275
:213   .shadow(… shadowRadius 32, y 26)                ← dc:1274 "0 26px 64px rgba(0,0,0,.7)"
```

The ring and shadow already matched the design and were not altered, as step 1 requires.

### 1.5 The doc comment

A block was added above `PosterCard` (`:173-186`) recording why the scale went, the arithmetic it
broke, and the two consequences in §3. Comment only; no behaviour.

### 1.6 What the brief forbade, verified rather than asserted

```
$ sed -n '114p;127p' "Marlin DVR TV/RecordingsScreen.swift"
                                ScrollView(.horizontal, showsIndicators: false) {
                                    .padding(.vertical, 44)

$ grep -rn "scrollClipDisabled" --include="*.swift" .
(no output)
```

`:114`'s ScrollView and `:127`'s padding are byte-identical to before, and
`.scrollClipDisabled()` appears nowhere in the app.

---

## 2. The arithmetic after the change

**Before** (Pass 46 §2.5): `scaleEffect` is a render transform, so it changed no layout and grew the
card about its centre. Upward overhang above the card's layout top was

```
H × (22/252) + 22   ≈ 431 × 0.0873 + 22  ≈ 37.6 + 22  =  59.6 pt
budget (.padding(.vertical, 44) at :127)                =  44   pt
                                                 over by ≈ 15.6 pt   → the top was clipped
```

**After.** There is no transform that grows the card. `HStack(alignment: .top, spacing: 30)` at
`:115` aligns children by their **layout tops**, and the focused card's layout box now grows
**downward** from that shared top. The only thing that displaces it upward is `.offset(y: -22)` at
`:223`:

```
overhang_up = 22 pt          ← exactly the design's lift, and independent of the card's height
budget      = 44 pt
                spare = 22 pt   → clears by a factor of two
```

**The `H` term is gone entirely.** Pass 46's threshold — clipping whenever `H > 252 pt`, against
344 pt of artwork alone — no longer applies at any card height, because nothing scales.

**The bottom, checked too.** While a card is focused the HStack's height is that card's height,
`H + 60` (the art grows 344 → 404). The focused card fills it and is then lifted 22:

```
rendered bottom = HStack_top + (H + 60) − 22 = HStack_bottom − 22
clearance below = 22 + 44 (the same .padding)  = 66 pt
```

So the bottom gains clearance rather than losing it. The sides are unchanged at 40 pt of padding
against a card that is now 296 pt wide in its own right rather than 252 pt drawn 22 pt wider on each
side — the growth is inside the layout box, so it cannot overhang sideways at all.

**Nothing clips, on any edge.**

---

## 3. Two consequences, both inherent to option C

Recorded because the owner will see them and one of them goes beyond what he was told.

1. **The row reflows sideways** — the accepted cost. The focused card's box is **44 pt wider**
   (252 → 296), so every card to its right shifts right by 44 pt as focus moves along the shelf.
2. **The shelf also grows 60 pt taller while it holds focus**, because the focused card's box is
   60 pt taller (344 → 404) and `HStack` takes its tallest child's height. That makes the horizontal
   `ScrollView`, the section `VStack` and the vertical scroll content 60 pt taller, so **shelves
   below the focused one shift down by 60 pt**. This is the design's own behaviour — `dc:383` makes
   the art `404px` in the focused state, and a flex row grows with it — but **the owner was told
   about the sideways reflow, not the vertical one.** It is raised as a question in §7 rather than
   compensated for, because compensating would mean touching `:127` or `:114`, which step 3 forbids.
3. **The title and count no longer change size on focus.** `scaleEffect` enlarged the whole card
   including its text; the design does not — `dc:389` and `dc:390` fix the title at 26 px and the
   count at 23 px in both states, and the app now matches. This is a real visible change and is
   correct per the design, but it is the kind of thing only the owner's eyes can approve.

---

## 4. The build (step 5)

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'generic/platform=tvOS Simulator' build
…
** BUILD SUCCEEDED **
```

**Warnings introduced by this pass: none.** A filtered re-run
(`grep -E "^\*\* BUILD|(warning|error): "`, excluding the unrelated AppIntents metadata note)
returns **only** `** BUILD SUCCEEDED **` — no warning and no error lines at all. The device build
(§5) is likewise clean.

For completeness: the one pre-existing warning this project knows about
(`PlayerModel.swift`, `nominalFrameRate` deprecated, recorded in Pass 42) did not appear, because
this pass does not touch `PlayerModel.swift` and that file therefore did not recompile. It is
unaffected either way.

---

## 5. The device (step 6)

`Home Theater` was **connected**, not merely paired:

```
$ xcrun devicectl list devices
Home Theater   Home-Theater.coredevice.local   <REDACTED-DEVICE-UUID>   connected   Apple TV 4K (3rd generation) (AppleTV14,1)
```

**The build under test is the one built in this pass.** The device build was made after the edit,
its binary fingerprinted, and that exact bundle installed:

```
binary mtime : Sep 8 22:13
binary sha256: ccf4a598f5d799aaddfcefe26e99a84983e9bc9bd8d78807bee256537f711352

$ xcrun devicectl device install app --device "Home Theater" "…/Debug-appletvos/Marlin DVR TV.app"
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
```

**The app ran and focus moved along the Recently Watched shelf.** Driven by the **existing**
`CommercialSkipUITests/testPromptAppearsAndSelectSkips`; **no test file was written or edited** — a
second file would have been a STOP, and `DeleteRefreshUITests`, the other harness that walks these
shelves, was deliberately not used because it deletes one of the owner's recordings.

```
[pass38 22:14:26.372] row 0: focus is "1 new, History's Greatest Mysteries, 2 episodes" — opening it
[pass38 22:14:31.967] episode row 0 is the one: S4 E14, Who Is D.B. Cooper? …
[pass38 22:15:54.069] PROMPT after 29 forward skips — clock ["05:59"] …
[pass38 22:16:00.361] after Select — clock ["05:59"] …
Test Case '-[…CommercialSkipUITests testPromptAppearsAndSelectSkips]' passed (128.152 seconds).
** TEST SUCCEEDED **
```

What that does and does not evidence, stated exactly:

- **It evidences** that the shelves were reached (`waitForShelves` asserts the shelves note before
  anything else and the test passed), that the harness delivered **eight `.left` presses to the
  shelf** and then read focus as a poster card, and that `.select` on that card opened its show. So
  **shelf focus navigation still works with a card whose layout box changes on focus** — the thing
  most at risk from this change.
- **It does not evidence traversal across several distinct cards.** `openShow` reads focus *before*
  each `.right`, and it matched on the first read, so **zero `.right` presses were sent**. The
  harness logs the focused label only once, and I do not know how many shows are on that shelf.
  Whether focus stepped between cards or bounced at the left edge of a short shelf is **not
  established**. §7 carries this.
- **I make no claim whatever about how it looks.** I cannot see the screen. Whether the top of the
  focused card is now whole is precisely the thing the owner has to judge.

The run also passed end to end — playback started, the commercial prompt appeared after 29 forward
skips, and Select skipped — so nothing downstream of the shelf was broken by the change.

**One incidental fact, offered because it closes a Pass 42 loose end.** Playback began at clock
`00:05`, and this harness *failed* in Pass 42 because the D.B. Cooper resume sat past every break.
That resume is evidently now cleared, so the precondition COLD-START records for this test is
satisfied again. Nothing in this pass cleared it deliberately.

---

## 6. Commit status

**Committed locally. NOTHING WAS PUSHED.**

<!--HEAD_SHA-->

---

## 7. Open questions

1. **The 60 pt vertical growth (§3.2).** The owner accepted a sideways reflow; he was not told the
   shelves below would shift down 60 pt while a card is focused. *Why it seems needed:* if that
   movement is distracting it is a real defect of this option, not a bug in the code. *What breaks
   without an answer:* nothing functionally — it clips nothing and the arithmetic in §2 has room to
   spare. **No compensation was built**, because every way to absorb it goes through `:127` or
   `:114`, which step 3 forbids.
2. **The title and count no longer enlarge on focus (§3.3).** This is the design's specification and
   is a deliberate consequence of dropping `scaleEffect`, but it is a visible change the owner never
   explicitly signed off. **Not changed.**
3. **Multi-card focus traversal is not evidenced (§5).** The available non-destructive harness
   matched the first card it read. Proving focus stepping across several reflowing cards would need
   either a new test file (a STOP under this pass's constraints) or a harness that deletes a
   recording. **Neither was done.**
4. **Nothing here was seen.** Every geometric claim is arithmetic over the design's numbers and the
   code's, not observation. The one thing that would settle the defect outright — that the card's top
   edge is whole — needs the owner's eyes.

---

## 8. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `Marlin DVR TV/RecordingsScreen.swift` | **modified** — 3 hunks, all inside `PosterCard` | steps 1, 2 |
| `design/Marlin DVR TV.dc.html` | **read only, never edited** (dc:1273, dc:382-390) | step 1 |
| `reports/2026-09-08-pass46-shelf-focus-clipping-recon.md` | read | the specification |
| `COLD-START.md`, `DECISIONS.md` | read; **not modified** | required reading; notebook is a later pass |
| `Marlin DVR TVUITests/CommercialSkipUITests.swift` | **read and run, unmodified** | step 6 |
| `reports/2026-09-08-pass47-shelf-focus-fix.md` | **created** | DELIVERABLE |

**One source file changed**, as the constraint requires. **`RecordingsScreen.swift:114` and `:127`
were not touched** and no second file was modified.

**Not touched:** every other folder under `~/Xcode`; the reference clone; the server's data, config
and admin UI; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share; `design/` (read, never written);
the Player and everything from Passes 42–45; the Xcode project, `Info.plist`, the entitlements file
and every build setting.

**No new dependency.** No credential, token, device id or account identifier appears in this report —
the Apple TV's `devicectl` identifier is redacted in §5.

---

## CLOSING SUMMARY FOR THE OWNER

**What you should see when you move focus along the Recordings shelf.** The focused card should now
be whole — nothing cut off the top. It gets bigger the same way your design says it should: the card
itself becomes 296 × 404 instead of 252 × 344, rather than being blown up like a photograph. Because
of that, the only part of it sticking up above the row is the 22-point lift the design asks for, and
the row has 44 points of space for it. Twice what it needs, where before it needed about 60 and had
44.

**The cost you accepted, and one you did not.** As agreed, **the row shuffles sideways** — the
focused card is 44 points wider, so the cards to its right slide over as you move along the shelf.
The one I have to add: the focused card is also **60 points taller**, so while it has focus **the
shelves below it move down** by that much. That is what your design does too, and it clips nothing,
but nobody told you about the vertical part and you may or may not like it. I did not try to
suppress it, because every way of doing so meant changing the two lines you told me to leave alone.

One more visible change: **the title and episode count under the poster no longer grow** when the
card is focused. The old scaling enlarged the text along with the picture; your design keeps the text
the same size in both states, and the app now matches it.

**What this pass cost.** Three small hunks in one file — two frame sizes changed and one line
deleted — plus a comment explaining why, and this report. Two clean builds with no new warnings, one
device install, and one existing harness run on Home Theater which passed in 128 seconds. **It is
committed but not pushed**, waiting on your eyes.

**The three things I am least certain about.**

1. **Whether it actually looks right.** I cannot see the screen, so I have proved the geometry on
   paper and proved the app still navigates, but not that the card's top edge is whole. That is
   entirely your call, and it is the whole point of the change.
2. **Whether the 60-point vertical shift is acceptable.** It is real, it is the design's own
   behaviour, and it is the one consequence you were not warned about before choosing this option.
3. **How the reflow feels in motion.** I said in the recon that I could not judge this without
   running it, and I still cannot — the test proves focus navigation survives the reflow, not that
   the movement is pleasant to watch.
