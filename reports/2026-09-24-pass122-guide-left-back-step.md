# Pass 122 — the Guide's Left back-step (item G)

**Date:** 2026-09-24 (09:50–10:30 EDT)
**Built on:** `6950e2a2d5d6bff80cd732f9d7645de530564531` (Pass 121). **One commit, not pushed** — the owner
tests on Home Theater first.

**Result.** Item G is built, in `GuideScreen.swift` alone (+95 / −0). While the Guide's window is ahead of
the current half hour, a Left press on a row's channel cell moves the window back one slot and focus
stays on that channel cell; at the current half hour Left reaches the rail as it always has. **Run on
Home Theater:** four slots ahead, four Lefts back to now, one more Left into the rail with the ring on
Guide — `TEST EXECUTE SUCCEEDED`. **Step 2 was measured first:** the Guide's own handler never sees that
press before focus lands in the rail, and no press handler can stop the crossing, but a focusable strip
inside the Guide can — so `ScreenShell.swift` and `RailView.swift` were not needed and were not touched.

**What this pass did not do.** It did not touch the bedroom Apple TV. It sent **no write of any kind** to
the Marlin DVR server: my only requests were two `GET /api/logs`; the app's own traffic in the runs was
GETs and its launch pings (§5, §6). Nothing was installed on this Mac. The installs anywhere were the app
builds the pass's own runs put on Home Theater — two diagnostic builds (`devicectl device install app`)
and two test runs (app and UI-test runner). marlin-dvr was not cloned or read. `design/`, `icon-source/`,
`REVIEW.md`, every existing report, `ScreenShell.swift`, `RailView.swift`, `PlayerModel.swift`,
`PlayerHost.swift` and `GuideScreen.swift`'s `fetch` are unchanged.

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:84).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main`
all read **`6950e2a2d5d6bff80cd732f9d7645de530564531`**. `git status --porcelain` showed only
`?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — the measurement

**The question:** with the window ahead of now and focus on the leftmost focusable item of a row — its
channel cell — does a Left press reach the Guide's own handler before focus lands in the sidebar, and can
the Guide keep focus in the grid on that press?

### 2.1 How it was measured

A disclosed diagnostic in `GuideScreen.swift`, every line marked `[probe] … DIAGNOSTIC ONLY`, printed each
focus change and each move command with a millisecond stamp, and carried three candidate mechanisms, one
per launch, chosen by a `MARLIN_PROBE_ARM` environment variable:

| Arm | Build | Mechanism |
|---|---|---|
| **O** | 1 | none — observe only |
| **R** | 1 | a `UITapGestureRecognizer` for `.leftArrow` on the window, `delaysTouchesBegan = true`, taking the press (`gestureRecognizer(_:shouldReceive:)`) only while a channel cell has focus and the window is ahead of the true half hour; prints only |
| **L** | 2 | the same with a `UILongPressGestureRecognizer`, `minimumPressDuration = 0`, so it begins at press-down; prints only |
| **C** | 2 | a 16 pt focusable `Color.clear` strip, `.offset(x: -28)` in an overlay of the grid's `ScrollView` — in the gap between the rail and the channel column — drawn only while a channel cell (or the strip) has focus and the window is ahead; landing on it hands focus straight back; it does not move the window |

Each arm: `devicectl device install app` (per build) → `devicectl device process launch --console
--terminate-existing -e '{"MARLIN_PROBE_ARM":"…"}'` → `xcodebuild test-without-building
-only-testing:"Marlin DVR TVUITests/Pass121ProbeUITests"`, a temporary harness that drove the running
process without `launch()` or `activate()`: open the Guide, two Right nudges at the first row's last cell,
Left along the row to its channel cell, **two Lefts on the channel cell** (Right back from the rail when
one landed there), Menu to snap to now, Left to the channel cell, **one Left at now**. Clicks only — XCUITest
on tvOS cannot swipe (Pass 108). The Guide opened on the owner's "News/Weather" collection, five rows, in
every run; the channel cells were FNC 6073 and FBN 6074.

**The diagnostic and its harness were both labelled "Pass 121" by my mistake** — this is Pass 122. They are
reverted and deleted (§2.4), so the label survives only in the diff below.

### 2.2 What each arm showed — the device console, verbatim

Filtered to `[probe]`, `[rail]` and `[guide]` lines from the first arrival on a channel cell; Right-press
lines left out. `[rail] entered …` is `ScreenShell.railRestore`'s own existing line
(`ScreenShell.swift:82-84`).

**Arm O — nothing in the way.**
```
[probe] t=281.970 arm=O focus verizon:6073@1790254800 -> ch:verizon:6073
[probe] t=281.972 arm=O move dir=left focused=ch:verizon:6073 window=1790260200 atNow=false
[rail] entered on favorites, restoring to guide
[probe] t=284.026 arm=O focus ch:verizon:6073 -> nil
[probe] t=284.036 arm=O move dir=left focused=nil window=1790260200 atNow=false
[probe] t=286.770 arm=O focus nil -> ch:verizon:6074
[rail] entered on guide — already the current screen
[probe] t=289.459 arm=O focus ch:verizon:6074 -> nil
[probe] t=289.462 arm=O move dir=left focused=nil window=1790260200 atNow=false
…
[rail] entered on favorites, restoring to guide
[probe] t=302.177 arm=O focus ch:verizon:6073 -> nil
[probe] t=302.187 arm=O move dir=left focused=nil window=1790256600 atNow=true
```

**Arm R — a tap recognizer on the window.**
```
[probe] t=369.977 arm=R shouldReceive left: focused=ch:verizon:6073 window=1790260200 trueNow=1790256600 -> true
[rail] entered on favorites, restoring to guide
[probe] t=370.004 arm=R focus ch:verizon:6073 -> nil
[probe] t=370.016 arm=R move dir=left focused=nil window=1790260200 atNow=false
[probe] t=375.543 arm=R shouldReceive left: focused=ch:verizon:6074 window=1790260200 trueNow=1790256600 -> true
[rail] entered on guide — already the current screen
[probe] t=375.572 arm=R focus ch:verizon:6074 -> nil
[probe] t=375.576 arm=R move dir=left focused=nil window=1790260200 atNow=false
```
The tap never recognized — no "caught" line in the run.

**Arm L — a zero-length long press on the window.**
```
[probe] t=581.808 arm=L shouldReceive left: focused=ch:verizon:6073 window=1790262000 trueNow=1790258400 -> true
[probe] t=581.812 arm=L recognizer state=1
[probe] t=581.812 arm=L caught left · focused=ch:verizon:6073
[rail] entered on favorites, restoring to guide
[probe] t=581.843 arm=L focus ch:verizon:6073 -> nil
[probe] t=581.856 arm=L recognizer state=3
[probe] t=582.110 arm=L caught left · 250 ms later focused=nil
[probe] t=587.289 arm=L shouldReceive left: focused=ch:verizon:6074 window=1790262000 trueNow=1790258400 -> true
[probe] t=587.291 arm=L recognizer state=1
[probe] t=587.291 arm=L caught left · focused=ch:verizon:6074
[rail] entered on guide — already the current screen
[probe] t=587.307 arm=L focus ch:verizon:6074 -> nil
[probe] t=587.310 arm=L recognizer state=3
```
The recognizer **began** (state 1) at press-down and ended (state 3) after the crossing. No `move dir=left`
line reached the grid for either press — the recognizer took the press away from SwiftUI — and focus went
to the rail regardless.

**Arm C — the strip.**
```
[probe] t=661.313 arm=C focus ch:verizon:6073 -> catch
[probe] t=661.313 arm=C caught left from ch:verizon:6073; focus back to it
[probe] t=661.314 arm=C move dir=left focused=catch window=1790262000 atNow=false
[probe] t=661.320 arm=C focus catch -> ch:verizon:6073
[probe] t=661.576 arm=C 250 ms later focused=ch:verizon:6073
[probe] t=664.004 arm=C focus ch:verizon:6073 -> catch
[probe] t=664.004 arm=C caught left from ch:verizon:6073; focus back to it
[probe] t=664.011 arm=C move dir=left focused=catch window=1790262000 atNow=false
[probe] t=664.017 arm=C focus catch -> ch:verizon:6073
[probe] t=664.255 arm=C 250 ms later focused=ch:verizon:6073
[guide] menu: sheet=false channelMenu=false collections=false atNow=false
…
[rail] entered on favorites, restoring to guide
[probe] t=674.656 arm=C focus ch:verizon:6073 -> nil
[probe] t=674.665 arm=C move dir=left focused=nil window=1790258400 atNow=true
```
No `[rail] entered` line for either press ahead of now; the harness read focus on "FNC, 6073" 2 s after
each. At now, where the strip is not drawn, Left reached the rail as in the other arms.

### 2.3 The answers

1. **Does a Left press reach the Guide's own handler before focus lands in the sidebar? No.** On all ten
   crossings into the rail across the four arms, `[rail] entered …` — `railRestore` — printed first, then
   the Guide's `focused` went nil, and the grid's `.onMoveCommand` fired **3–12 ms after that**
   (O: 10, 3, 10; R: 12, 4, 11; L at now: 11; C at now: 9) — or not at all on arm L's two caught presses.
   A press recognizer on the window **does** see the press first, **16–31 ms before** focus moves
   (R: 27, 29, 18; L: 31, 16, 19), but it cannot use that lead: neither a tap (R) nor a zero-length long
   press that began and swallowed the press (L) stopped the focus engine.
2. **Can the Guide keep focus in the grid on that press? Yes — inside `GuideScreen.swift`, by geometry, not
   by a handler.** The focus engine prefers the strip, which is nearer to the channel cell than any rail
   entry; the strip hands focus straight back to the channel cell — **7 ms and 13 ms** — and the rail is
   never focused. So **neither `ScreenShell.swift` nor `RailView.swift` is needed**, and step 3 went ahead.
   The price, stated plainly: for those 7–13 ms focus sits on an invisible element of the Guide's grid.
   Whether that shows as a one-frame blink of the channel cell's ring was not measured (§8).

### 2.4 The diagnostic's exact diff, and the revert

Build 2's diff is below (arms O, L and C). **Build 1 differed only in arm R:** the `.background` condition
was `probeArm == "R"`, the recognizer was a `UITapGestureRecognizer` with no `minimumPressDuration`, its
action called `caught()` directly, the prints said `arm=R`, and there was no arm-C overlay, no
`probeCatcherOn` and no arm-C branch in `.onChange(of: focused)`. Both builds added no warning.

```diff
diff --git a/Marlin DVR TV/GuideScreen.swift b/Marlin DVR TV/GuideScreen.swift
index f32e7be..3dd2a79 100644
--- a/Marlin DVR TV/GuideScreen.swift	
+++ b/Marlin DVR TV/GuideScreen.swift	
@@ -42,6 +42,7 @@
 //
 
 import SwiftUI
+import UIKit   // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
 
 enum GuideMark {
@@ -425,6 +426,18 @@ struct GuideScreen: View {
                 .onMoveCommand { direction in gridMoved(direction) }
+                // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+                .overlay(alignment: .topLeading) {
+                    if Self.probeArm == "C" && probeCatcherOn {
+                        Color.clear
+                            .frame(width: 16)
+                            .frame(maxHeight: .infinity)
+                            .focusable()
+                            .focusEffectDisabled()
+                            .focused($focused, equals: "catch")
+                            .offset(x: -28)
+                    }
+                }
                 legend
@@ -462,6 +475,12 @@ struct GuideScreen: View {
+        // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+        .background {
+            if Self.probeArm == "L" {
+                ProbeLeftCatcher(shouldCatch: { probeShouldCatch() }, caught: { probeCaught() })
+            }
+        }
         .defaultFocus($focused, "loading")
@@ -498,6 +517,17 @@ struct GuideScreen: View {
         .onChange(of: focused) { old, new in
+            // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+            print("[probe] t=\(Self.probeT()) arm=\(Self.probeArm) focus \(old ?? "nil") -> \(new ?? "nil")")
+            if Self.probeArm == "C", new == "catch" {
+                print("[probe] t=\(Self.probeT()) arm=C caught left from \(old ?? "nil"); focus back to it")
+                let back = old
+                Task { focused = back }
+                Task {
+                    try? await Task.sleep(for: .milliseconds(250))
+                    print("[probe] t=\(Self.probeT()) arm=C 250 ms later focused=\(focused ?? "nil")")
+                }
+            }
             if let new, new.contains("@") { lastCell = new }
@@ -571,6 +601,13 @@ struct GuideScreen: View {
     private func gridMoved(_ direction: MoveCommandDirection) {
+        // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+        let probeBefore = focused ?? "nil"
+        print("[probe] t=\(Self.probeT()) arm=\(Self.probeArm) move dir=\(direction) focused=\(probeBefore) window=\(model.windowStart) atNow=\(model.isAtNow)")
+        Task {
+            try? await Task.sleep(for: .milliseconds(250))
+            print("[probe] t=\(Self.probeT()) arm=\(Self.probeArm) move dir=\(direction) settled before=\(probeBefore) after=\(focused ?? "nil")")
+        }
         guard direction == .right, model.sheet == nil, channelMenu == nil, !collectionsOpen else { return }
@@ -581,6 +618,33 @@ struct GuideScreen: View {
+    // [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+    // Arm "O" (default): observe only. Arm "R" (first build): a window tap recognizer for Left.
+    // Arm "L": a window long-press recognizer for Left, zero duration, taking the press only while
+    // focus is on a channel cell and the window is ahead of the true half hour; it prints only.
+    // Arm "C": a focusable strip left of the channel column while a channel cell is focused and the
+    // window is ahead; landing on it hands focus straight back. Neither arm moves the window.
+    static let probeArm = ProcessInfo.processInfo.environment["MARLIN_PROBE_ARM"] ?? "O"
+    static func probeT() -> String {
+        String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
+    }
+    private var probeCatcherOn: Bool {
+        !model.isAtNow && (focused?.hasPrefix("ch:") == true || focused == "catch")
+    }
+    private func probeShouldCatch() -> Bool {
+        let trueNow = Int(Date().timeIntervalSince1970 / 1800) * 1800
+        let ok = !overlayOpen && !hold.suspended && (focused?.hasPrefix("ch:") ?? false) && model.windowStart > trueNow
+        print("[probe] t=\(Self.probeT()) arm=L shouldReceive left: focused=\(focused ?? "nil") window=\(model.windowStart) trueNow=\(trueNow) -> \(ok)")
+        return ok
+    }
+    private func probeCaught() {
+        print("[probe] t=\(Self.probeT()) arm=L caught left · focused=\(focused ?? "nil")")
+        Task {
+            try? await Task.sleep(for: .milliseconds(250))
+            print("[probe] t=\(Self.probeT()) arm=L caught left · 250 ms later focused=\(focused ?? "nil")")
+        }
+    }
+
@@ -891,6 +955,66 @@ struct GuideScreen: View {
+// [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+struct ProbeLeftCatcher: UIViewRepresentable {
+    let shouldCatch: () -> Bool
+    let caught: () -> Void
+
+    func makeUIView(context: Context) -> ProbeLeftCatcherView { ProbeLeftCatcherView() }
+
+    func updateUIView(_ view: ProbeLeftCatcherView, context: Context) {
+        view.shouldCatch = shouldCatch
+        view.caught = caught
+    }
+}
+
+// [probe] Pass 121 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+final class ProbeLeftCatcherView: UIView, UIGestureRecognizerDelegate {
+    var shouldCatch: () -> Bool = { false }
+    var caught: () -> Void = {}
+    private var recognizer: UILongPressGestureRecognizer?
+    private weak var installedOn: UIWindow?
+
+    init() {
+        super.init(frame: .zero)
+        isUserInteractionEnabled = false
+        backgroundColor = .clear
+    }
+
+    @available(*, unavailable)
+    required init?(coder: NSCoder) { fatalError("not used") }
+
+    override func didMoveToWindow() {
+        super.didMoveToWindow()
+        if let installedOn, installedOn !== window, let recognizer {
+            installedOn.removeGestureRecognizer(recognizer)
+            self.recognizer = nil
+            self.installedOn = nil
+            print("[probe] t=\(GuideScreen.probeT()) arm=L recognizer removed from the window")
+        }
+        guard let window, recognizer == nil else { return }
+        let tap = UILongPressGestureRecognizer(target: self, action: #selector(tapped(_:)))
+        tap.minimumPressDuration = 0
+        tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
+        tap.allowedTouchTypes = []
+        tap.delaysTouchesBegan = true
+        tap.delegate = self
+        window.addGestureRecognizer(tap)
+        recognizer = tap
+        installedOn = window
+        print("[probe] t=\(GuideScreen.probeT()) arm=L recognizer installed on the window")
+    }
+
+    @objc private func tapped(_ g: UILongPressGestureRecognizer) {
+        print("[probe] t=\(GuideScreen.probeT()) arm=L recognizer state=\(g.state.rawValue)")
+        if g.state == .began { caught() }
+    }
+
+    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
+        shouldCatch()
+    }
+}
+
```

(Unchanged context lines are trimmed; the full diff, 177 lines, was saved outside the repo.) Build 1 first
failed to compile once — `delaysPressesBegan` does not exist on `UIGestureRecognizer` — and was built with
`delaysTouchesBegan` instead; that is a fix to the diagnostic, not a retry of a measurement.

**The revert:**

```
$ git checkout -- "Marlin DVR TV/GuideScreen.swift"
$ rm "Marlin DVR TVUITests/Pass121ProbeUITests.swift"
$ git hash-object "Marlin DVR TV/GuideScreen.swift"
f32e7be19c228eeb5afbb6bfb0d3efcac65e8224          # = git rev-parse HEAD:"Marlin DVR TV/GuideScreen.swift"
$ git status --porcelain
?? icon-source/
$ grep -rn '\[probe\]\|probeArm\|ProbeLeftCatcher\|MARLIN_PROBE' "Marlin DVR TV" "Marlin DVR TVUITests"
Marlin DVR TVUITests/GuideRightEdgeUITests.swift:20://  process and take the `[probe]` lines with it.
Marlin DVR TVUITests/GuideRightEdgeUITests.swift:175:    /// happen has happened well inside 1.5 s, and the app's own `[probe]` line for the press is
```

The two remaining hits are Pass 76's own comments, unchanged. Step 3 was written on the reverted file.

---

## 3. Step 3 — what was built

All in `Marlin DVR TV/GuideScreen.swift`, +95 / −0:

- **`GuideModel.nudgeBack()`** (`:197`), the mirror of `nudgeForward()`. It republishes `now` from the wall
  clock, refuses when one slot back would be earlier than the current half hour, writes `windowStart` one
  slot back, and refetches on **the two-sided rule** `windowStart < fetchStart || windowEnd > fetchEnd` —
  `tick()`'s and `snapToNow()`'s line, the only one that can fire going backward (Pass 119 §3 G (a)). The
  floor reads `Date()`, as `snapToNow()` does, because `now` can be a minute stale; so `windowStart` is still
  only ever the current half hour or ahead of it, which is what `tick()` relies on (DECISIONS.md, Pass 79).
- **`backStepCatcher`** (`:674`), the arm-C strip exactly as measured — 16 pt, `Color.clear`, `.focusable()`,
  `.focusEffectDisabled()`, `.offset(x: -28)` — in an overlay of the grid's `ScrollView` (`:459`), outside
  it because the `ScrollView` would clip it. **`backStepCatcherOn`** (`:657`) draws it only while the Guide
  has loaded, the window is not at now, no overlay (sheet, hold menu, collections) is up, and a channel
  cell — or the strip itself, for the moment of the hand-back — has focus. Two conditions were added to the
  measured arm: `model.loaded` and `!overlayOpen`.
- **`backStep(from:)`** (`:689`), called from `.onChange(of: focused)` (`:539`) when focus lands on the strip:
  one task hands focus straight back to the channel cell, then calls `nudgeBack()` and prints
  `[guide] back-step -> … · fetch=… · focus stays on ch:…`, or `[guide] back-step refused at …`. A landing
  from anything but a channel cell — not reachable, since the strip is drawn only while one has focus —
  goes to the last grid focus and moves nothing.
- **`backStepID`** (`:651`), `"back-step"`: neither a programme id nor a channel id, so `lastCell`,
  `lastGridFocus`, `isRightwardStep`, `handleHold`, the roll's and the redraw's focus repair all pass over it.
- **A header paragraph** (`:42-49`) saying so, and that for this one press it supersedes Pass 77's
  "Forward only" line above it, which is not edited.

**Not changed:** `gridMoved` and its doc comment ("Only `.right` does anything" is still true — the
back-step does not go through it), `fetch` (S11), `nudgeForward`, `tick`, `snapToNow`, `pageForward`, Menu,
↩ Now, +12h, the collection filter, the Pass 116 redraw and the footer. Build warnings: the same two as
before — `GuideScreen.swift` `channelFocusID` (now `:873`) and `PlayerModel.swift:367` `nominalFrameRate` —
both pre-existing.

---

## 4. Verify — the run on Home Theater

```
xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p122 build-for-testing
xcodebuild test-without-building -xctestrun build/p122/Build/Products/…xctestrun \
  -destination 'platform=tvOS,name=Home Theater' \
  -only-testing:"Marlin DVR TVUITests/GuideBackStepUITests"
```

**Two runs of the same harness, both passed; the second is the evidence of record.** The first (10:09:08–
10:10:07) passed with this pass's code while its comments, the harness header and the harness's log prefix
still said "Pass 121". I relabelled them — comments and one print prefix, no other line — rebuilt from the
final tree and ran once more, so that the committed code is exactly what ran. **Run 2, 10:13:05–10:14:04:
`** TEST EXECUTE SUCCEEDED **`, "Executed 1 test, with 0 failures", 54.2 s.** Its stage lines, verbatim:

```
[pass122 10:13:12.016] launched
[pass122 10:13:24.052] OPEN window=“Thu Sep 24 · 10:00 AM – 12:00 PM” startMin=392280 strip=“10:00 AM · now” nowPill=false zone=grid:programme-cell focus=9:“America's Newsroom” (554,228 637x82)
[pass122 10:13:37.393] AHEAD 4 slot(s) window=“Thu Sep 24 · 12:00 – 2:00 PM” startMin=392400 strip=“12:00 PM” nowPill=true zone=grid:programme-cell focus=9:“America Reports” (1203,228 637x82)
[pass122 10:13:39.901] walk left #1: startMin=392400 zone=grid:programme-cell focus=9:“Outnumbered” (554,228 637x82)
[pass122 10:13:42.297] walk left #2: startMin=392400 zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:13:42.653] ON THE CHANNEL CELL window=“Thu Sep 24 · 12:00 – 2:00 PM” startMin=392400 strip=“12:00 PM” nowPill=true zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:13:46.457] BACK-STEP LEFT #1 window=“Thu Sep 24 · 11:30 AM – 1:30 PM” startMin=392370 strip=“11:30 AM” nowPill=true zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:13:50.368] BACK-STEP LEFT #2 window=“Thu Sep 24 · 11:00 AM – 1:00 PM” startMin=392340 strip=“11:00 AM” nowPill=true zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:13:54.297] BACK-STEP LEFT #3 window=“Thu Sep 24 · 10:30 AM – 12:30 PM” startMin=392310 strip=“10:30 AM” nowPill=true zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:13:58.234] BACK-STEP LEFT #4 window=“Thu Sep 24 · 10:00 AM – 12:00 PM” startMin=392280 strip=“10:00 AM · now” nowPill=false zone=grid:channel-cell focus=9:“FNC, 6073” (236,228 300x82)
[pass122 10:14:02.412] ONE MORE LEFT AT NOW window=“Thu Sep 24 · 10:00 AM – 12:00 PM” startMin=392280 strip=“10:00 AM · now” nowPill=false zone=rail focus=9:“Guide” (80,332 258x56)
```

Run 1's lines are the same, stage for stage and value for value, 3 min 56 s earlier.

**The launch ping and the server's view of run 2** (`GET /api/logs`, client id replaced):

```
10:13:11.061 POST /api/clients/<client id>/ping 200
10:13:11.060–.122  GET /api/library, /api/channels, /api/cameras, /api/radio, /api/guide/now, /api/schedule   (Home)
10:13:16.437 GET /api/guide 200                      (the Guide opens — loadNow)
10:13:16.490 GET /api/schedule 200
10:13:16.532 GET /api/collections 200                (Pass 116's first connect re-read)
10:13:16.540 GET /api/guide 200
10:13:16.594 GET /api/schedule 200
10:14:02.928 GET /api/events 200                     (the stream closing as the run ended)
```

**No `GET /api/guide` from 10:13:16.540 to the end** — four nudges and four back-steps, all inside the 24
hours fetched at 10:00, and no refetch, as both rules predict there. Run 1's ping was at `10:09:14.844`.
Across 09:50–10:15 the log holds **six non-GET requests, all launch pings from one client id** — the four
diagnostic launches (09:57:25, 09:58:56, 10:02:27, 10:03:47) and the two runs — and nothing else.

**Screenshots** (run 2), in `reports/assets/pass122/`: `01-guide-open-at-now.jpg`,
`02-four-slots-ahead.jpg`, `03-on-the-channel-cell-four-ahead.jpg`, `04-back-step-1.jpg` …
`07-back-step-4.jpg` (the header, the strip and every row moving back together, the ring on FNC and the
rail collapsed in each), and `08-left-at-now-reaches-the-rail.jpg` (the rail expanded, the ring on Guide,
"10:00 AM · now", no ↩ Now, the at-now footer).

---

## 5. Run or traced

**Run on Home Theater (run 2, clicks from `XCUIRemote`):**
- four Right nudges to four slots ahead (Pass 77's path, unchanged);
- Left along the row to its channel cell with the window unmoved (two presses);
- **four Lefts on the channel cell, each moving the window back 30 minutes — the header's window, the strip's
  first column and the rows together — with focus on "FNC, 6073" after each**;
- at the current half hour: "· now" drawn, ↩ Now gone, the at-now footer;
- **one more Left reaching the rail with the ring on Guide**, the window unmoved;
- no refetch on a back-step inside the fetched range (server log).

**Measured under the diagnostic, not on the shipped build:** the order of the crossing, the move command
and the recognizer (§2.3); the strip taking the press with no `[rail] entered` line and handing focus back in
7 and 13 ms. The shipped build ran without a console (`launch()`), so for it "the rail was never focused" rests
on focus being on the channel cell 3 s after each press and the rail collapsed in screenshots 04–07, not
on a console line.

**Code-traced only:**
- **a swipe left on a channel cell.** XCUITest on tvOS cannot swipe. The strip works on where the focus
  engine goes, not on the press, so a swipe should land on it like a click — but a long swipe that carries
  focus through several items may step more than one slot;
- a back-step below `fetchStart` and its one `GET /api/guide` + `GET /api/schedule` (after the 45th nudge, a
  second +12h, a collection pick or a server notice made while ahead);
- the floor with a stale `now`: in the minute after a half-hour boundary, with the window sitting on the new
  half hour, `isAtNow` still reads false until the next beat, so the strip is drawn and **the first Left is
  refused** (focus stays on the channel cell) and the second reaches the rail;
- a half-hour boundary during back-steps; Menu, ↩ Now and +12h after back-steps; a Pass 116 notice during
  one; the airing sheet, hold menu or collections overlay open (the strip is not drawn); the Player on top;
- Up, Down and Right from a channel cell while the strip is drawn (it lies left of the channel column, outside
  their search); Right from the rail into the grid while ahead (focus is nil, so the strip is not drawn);
  Left from the header while ahead (no channel cell focused, so the strip is not drawn);
- a fast presser, a held Left, and whether the 7–13 ms hand-back shows as a one-frame blink of the ring.

---

## 6. The server reads this pass made

Two `GET http://192.168.1.250:8090/api/logs` with `curl`, after run 1 and after run 2, to read the launch
pings and the app's requests; the files sat in the session scratchpad and are quoted here with the client id
replaced. `GET /api/settings` was not read. Everything else was the app's own traffic in the runs.

---

## 7. Records this pass changes, recorded forward and not edited

The owner's decision of 2026-09-23 supersedes each of these for the one press it names (Pass 119 §3 G (d)):
- DECISIONS.md:1204-1206 (Pass 77): *"forward only; Left, Menu, `↩ Now`, `+12h` and a rail trip all behave
  exactly as they did."*
- DECISIONS.md:1270-1273 (Pass 78): *"**forward only**; `Left`, `Menu`, `↩ Now`, `+12h` and a rail trip all
  behaving as they did;"*
- `reports/2026-09-12-pass78-scroll-accepted-and-pushed.md:23`: *"**Forward only.** `Left`, `Menu`,
  `↩ Now`, `+12h` and a rail trip all behave as they did."*
- `GuideScreen.swift`'s Pass 77 header line, *"Forward only; Left, Menu, "↩ Now" and "+12h" are untouched."*
  — kept, with the Pass 122 paragraph beneath it saying it is superseded for that press.
- **COLD-START.md's Guide line is brought to the current state in place** (step 4): its "forward only" is
  gone and the back-step is written in.

Checked and not changed: design 3a's "forward-only from the current half hour" (DECISIONS.md:18) — G keeps
that floor; the rail landing on the entry that opened the screen (Pass 25) — `ScreenShell.swift` is
byte-identical and the one Left into the rail landed on Guide.

**A harness this changes:** `GuideRightEdgeUITests.testScrollThenRailRoundTrip` goes four slots ahead and
then presses Left at most four times expecting the rail (`GuideRightEdgeUITests.swift:726-731`). Under G the
Lefts after the channel cell step the window back instead, so **it can no longer pass as written.** It was
not run or edited (open question 2).

---

## 8. The bedroom install after Pass 121 (recorded in step 4)

Install only, no commit, no pass number of its own: "Master Bedroom ATV" built from `6950e2a` by Pass 117's
method — `** BUILD SUCCEEDED **`, exit 0 — and `devicectl device install app` — `App installed`, exit 0; the
television reads Marlin DVR TV 1.0 / Bundle Version 1; three strings Pass 120 added are in the built
`Marlin DVR TV.debug.dylib`; it was not launched. Both Apple TVs then ran Pass 120's code. The entry is in
DECISIONS.md under Pass 122. **After this pass Home Theater runs Pass 122's build and the bedroom still runs
Pass 120's code**, which the standing rule allows until G is proven.

---

## Open questions

1. **The footer while the window is ahead still says "Menu snaps back to now · forward only, 24 hours per
   request"** (`GuideScreen.swift:981`). With G it is no longer only forward. G did not name the footer
   (Pass 119), so it is unchanged. Change its wording?
2. **`GuideRightEdgeUITests.testScrollThenRailRoundTrip` can no longer pass as written** (§7), and
   COLD-START's evidence-harness line neither says so nor lists `GuideBackStepUITests`, because this pass named
   only the Guide line and *Next step* in that file. Record it stale there, amend the test, or leave both?

## What I am least sure of

1. **The strip rests on the focus engine's geometry.** It was measured on tvOS 26.6 with this layout; a tvOS
   that searched differently could carry Left past it into the rail. It fails open — Left would then reach the
   rail as it did before G — but the back-step would be gone.
2. **Swipes were never driven.** A swipe should behave like a click because the strip is found by where focus
   goes, but a long swipe may step more than one slot, and none was measured.
3. **Whether the 7–13 ms on the invisible strip shows.** Focus leaves the channel cell for less than a frame
   or about one; a screenshot 3 s later cannot see a one-frame blink of its ring. The owner's eye will.

## How the owner can see it on Home Theater

Open the Guide. Go right along a row to its last programme and keep pressing Right until the window is a few
half hours ahead ("↩ Now" appears in the header). Press Left along the row until the channel's logo cell is
highlighted. **Each further Left moves the whole Guide back half an hour — the date range, the time strip and
every row — and the highlight stays on the channel.** When it reaches the current half hour the first column
reads "· now" and "↩ Now" disappears; **one more Left opens the sidebar on Guide**, as before. Try it with a
swipe left on the touch surface too — that was never driven here.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | 2 | the `[probe]` diagnostic — **added, used in four arms over two builds, and reverted with `git checkout --`**; not in the commit; its diff is §2.4 |
| `Marlin DVR TVUITests/Pass121ProbeUITests.swift` | 2 | the diagnostic's harness — **created, used and deleted**; not in the commit |
| `Marlin DVR TV/GuideScreen.swift` | 3 | item G: `nudgeBack()`, `backStepCatcher`, `backStepCatcherOn`, `backStep(from:)`, `backStepID`, one overlay line, one `.onChange` line, a header paragraph; +95 / −0 |
| `Marlin DVR TVUITests/GuideBackStepUITests.swift` | Verify | new — the run's harness, `launch()`, one method, which the pass allows |
| `DECISIONS.md` | 4 | the Pass 122 entry: the bedroom install after Pass 121, then G |
| `COLD-START.md` | 4 | the Guide line; *Next step*, with Pass 121's paragraph kept beneath it, labelled |
| `reports/2026-09-24-pass122-guide-left-back-step.md` | 4 | new — this report |
| `reports/assets/pass122/` (8 `.jpg`, 1.2 MB) | 4 | new — run 2's screenshots, exported from its result bundle |

**Nothing else was changed.** `ScreenShell.swift`, `RailView.swift`, `PlayerModel.swift`, `PlayerHost.swift`,
`project.pbxproj` and every other app file are byte-identical; the UI-test target is a synchronised folder, so
the harness needed no project edit. A `reports/assets/pass121/` folder made from run 1 under the wrong number
was deleted before the commit. Scratch — the diagnostic diffs, the four consoles, the test logs, the log reads
and the exported attachments — is in the session scratchpad, outside the repo. `build/p121probe`, `build/p121`
and `build/p122` are the DerivedData of the diagnostic, run 1 and run 2; `build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, one ahead of `origin/main` (`6950e2a`). Nothing was pushed: the owner
tests on Home Theater first.
