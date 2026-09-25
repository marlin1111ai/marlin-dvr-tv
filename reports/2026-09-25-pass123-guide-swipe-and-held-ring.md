# Pass 123 — the Guide's swipe right and held ring

**Date:** 2026-09-25 (17:12–18:20 EDT)
**Built on:** `65321afc9063aa4fdc72f57cce3a499996f50197` (Pass 122's G, itself unpushed). **One commit, not
pushed** — the owner tests on Home Theater first, and G's `65321af` goes with it.

**Result.** The owner's four requests of 2026-09-24 are built, in `GuideScreen.swift` alone (+318 / −23):
**(a)** a swipe right on the touch surface at the right edge of a row moves the Guide forward one slot, as a
Right click there does; **(b)** a held Right keeps going — along the row's cells, then half an hour at a
time — with Pass 77's stops and focus rule unchanged; **(c)** a held Left keeps going back and **stops at the
current half hour** rather than carrying on into the sidebar, and a separate Left press then opens the
sidebar exactly as today; **(d)** the footer while ahead reads "Menu snaps back to now · 24 hours per
request". **Run on Home Theater (run 5, the record):** one click at the edge → one slot; **one held Right of
4 s → six slots in the one press**; the new footer; **one held Left of 8.2 s from seven slots ahead → the
current half hour, stopped there with focus still on the channel cell**; one separate Left → the rail with
the ring on Guide — `** TEST EXECUTE SUCCEEDED **`. **The swipe is traced, not run** (§6).

**The pace, chosen and reported:** the platform's own. Measured first (§2): the tvOS focus engine repeats
a held ring press by itself, one focus move every ~0.27 s after a ~0.55 s delay, and `.onMoveCommand` fires
once per press, at release. So the app adds **no timer**; each of the engine's repeats at the edge is one
window step, throttled only by the redraw — on the owner's All Channels (202 rows) that is one step every
0.5–0.75 s, six in a 4 s press; on a five-row collection it would be the engine's ~0.27 s.

**What this pass did not do.** It did not touch the bedroom Apple TV. It sent **no write of any kind** to
the Marlin DVR server: my only requests were two `GET /api/logs`; the app's own traffic in the runs was
GETs and its launch pings (§5, §7). Nothing was installed on this Mac. The installs anywhere were the app
builds the pass's runs put on Home Theater. marlin-dvr was not cloned or read. `design/`, `icon-source/`,
`REVIEW.md`, every existing report, `ScreenShell.swift`, `RailView.swift`, `PlayerModel.swift`,
`PlayerHost.swift`, `RemoteHold.swift` and `GuideScreen.swift`'s `fetch` are unchanged.

**Line numbers** below are at this pass's commit. `file:line` citations drift, and comments and reports are
never rewritten (COLD-START.md:84).

---

## 1. Step 1 — the state before anything changed

`git fetch origin`, then `git rev-parse main` read **`65321afc9063aa4fdc72f57cce3a499996f50197`**,
`git rev-parse origin/main` and `git ls-remote origin main` both read
**`6950e2a2d5d6bff80cd732f9d7645de530564531`**, `git rev-list --left-right --count main...origin/main` was
`1 0`, and `git status --porcelain` showed only `?? icon-source/`. **No stop condition.**

---

## 2. Step 2 — the measurement: what a held ring and a swipe right deliver

**The questions.** What does the app receive while Right is held on the ring — one move command, a stream
of them, or nothing after the first? Does the focus engine itself move focus again while the ring is held?
Can a press recognizer on the window see press-down and release without disturbing Pass 77's path? And
does the engine take a strip to the right of a row's last cell the way Pass 122 measured it taking one to
the left of the channel column?

### 2.1 How it was measured

A disclosed diagnostic in `GuideScreen.swift`, every line marked `[probe] Pass 123 DIAGNOSTIC ONLY`
(137 insertions, §2.4), and a temporary harness `Pass123ProbeUITests` that drove the process
`devicectl … --console` started — neither `launch()` nor `activate()`. One build, one launch, arm L with
the strip on: `MARLIN_PROBE_ARM=L MARLIN_PROBE_STRIP=1`.

| Piece | What it did |
|---|---|
| **Arm L** | a `UILongPressGestureRecognizer` on the window, `minimumPressDuration = 0`, for Left and Right, `allowedTouchTypes = []`, **`cancelsTouchesInView = false`**; prints `shouldReceive`, and each state change |
| **Arm P** (built, not launched) | a bare `UIGestureRecognizer` subclass printing `pressesBegan`/`pressesEnded`; kept in reserve in case arm L took the press away from `.onMoveCommand`, as Pass 122's arm L had with `delaysTouchesBegan` |
| **The strip** | a 16 pt `Color.clear`, `.focusable()`, `.focusEffectDisabled()`, `.offset(x: 28)` in a `.topTrailing` overlay of the grid's `ScrollView` — in the 80 pt trailing margin — drawn while the focused cell is the last one its row has; landing on it hands focus back and **moves nothing** |
| **Prints** | every focus change; every `.onMoveCommand` at the grid with `focused`, the window and `isAtNow` |

The drive, clicks and synthesized holds only (XCUITest on tvOS cannot swipe, Pass 108): open the Guide, one
click Right mid-row, Right to the row's last cell, one click Right at the edge, **hold Right 3 s**, Left along
the row to the channel cell, **hold Left 3 s**, back to now, Left to a channel cell at now, **hold Left 2 s**.
The Guide opened on the owner's current pick, **All Channels — 202 rows** (`rows=202` in the app's own
connect line), which is why every redraw below is slow. The harness passed (17:16:13–17:19:13, launch ping
`17:15:36.469`).

### 2.2 What the device said — the console, verbatim, filtered

`t=` is the app's own stamp, seconds within the current 1000 s; channel ids shortened. `state=1` is the
recognizer's `began`, `state=3` its `ended`; `type=3` is Right, `type=2` Left.

**A click Right, mid-row (three of them, all alike):**
```
[probe] t=973.619 arm=L shouldReceive type=3 -> true
[probe] t=973.636 arm=L recognizer state=1
[probe] t=973.749 focus 2.1@1790370000 -> 2.1@1790371800
[probe] t=973.763 move dir=right focused=2.1@1790371800 window=1790370000 atNow=true
[probe] t=973.764 arm=L recognizer state=3
```
Press-down to release **128 ms** (128, 128, 134 across the three); the engine's move **113 ms** after
press-down; **the move command 1 ms before the release** — it arrives at press-up, not press-down.

**A click Right at the edge, the strip on:**
```
[probe] t=14.083 arm=L recognizer state=1
[probe] t=14.195 focus 2.1@1790375400 -> probe-right
[probe] t=14.195 right strip caught from 2.1@1790375400; focus back to it
[probe] t=14.208 move dir=right focused=probe-right window=1790370000 atNow=true
[probe] t=14.208 arm=L recognizer state=3
[probe] t=14.328 focus probe-right -> 2.1@1790375400
[guide] nudge -> Fri Sep 25 · 5:30 – 7:30 PM · fetch=1790370000 · focus stays on 2.1@1790375400
```
The engine took the strip (112 ms after press-down), the hand-back was drawn **133 ms** later, and Pass 77's
`gridMoved` nudged once from the move command — the strip itself moved nothing in this arm.

**Right held 3 s at the edge:**
```
[probe] t=29.262 arm=L recognizer state=1
[probe] t=29.385 focus 2.1@1790375400 -> 2.1@1790377200        (+123 ms: the press's own move, a cell walk)
[probe] t=29.935 focus 2.1@1790377200 -> probe-right             (+550 ms after that: the first repeat)
[probe] t=30.064 focus probe-right -> 2.1@1790377200             (hand-back, 129 ms)
[probe] t=30.195 focus 2.1@1790377200 -> probe-right             (repeat, 260 ms after the last)
[probe] t=30.463 … -> probe-right   (268)      [probe] t=30.730 … (267)      [probe] t=30.997 … (267)
[probe] t=31.263 … (266)      [probe] t=31.528 … (265)      [probe] t=31.796 … (268)      [probe] t=32.061 … (265)
[probe] t=32.212 move dir=right focused=2.1@1790377200 window=1790371800 atNow=false
[probe] t=32.212 arm=L recognizer state=3                       (release, 2.95 s after began)
[probe] t=32.334 focus 2.1@1790377200 -> probe-right             (one more repeat, 122 ms after release)
[guide] nudge -> Fri Sep 25 · 6:00 – 8:00 PM · fetch=1790370000 · focus stays on 2.1@1790377200
```
**One move command for the whole hold, at release. Ten focus moves by the engine**: the press's own, then
nine repeats — the first 550 ms after the first move, then every 260–268 ms — the last 122 ms *after* the
release. Every one at the edge landed on the strip and was handed back.

**Left held 3 s on the channel cell, two slots ahead (Pass 122's catcher, unchanged):**
```
[probe] t=75.968 arm=L recognizer state=1
[probe] t=76.077 focus ch:2.1 -> back-step
[guide] back-step -> Fri Sep 25 · 5:30 – 7:30 PM · fetch=1790370000 · focus stays on ch:2.1
[probe] t=76.625 focus back-step -> ch:2.1                       (the hand-back drawn 548 ms later — a window step on 202 rows)
[probe] t=76.758 focus ch:2.1 -> back-step                       (the engine's repeat)
[guide] back-step -> Fri Sep 25 · 5:00 – 7:00 PM · fetch=1790370000 · focus stays on ch:2.1
[probe] t=77.175 focus back-step -> nil                          (at now the catcher is withdrawn while it has focus)
[probe] t=77.333 focus nil -> ch:2.1                             (the hand-back lands)
[rail] entered on favorites, restoring to guide                  (the next repeat: nothing left of the channel cell but the rail)
[probe] t=77.494 focus ch:2.1 -> nil
[probe] t=78.938 move dir=left focused=nil window=1790370000 atNow=true
[probe] t=78.941 arm=L recognizer state=3
```
So at HEAD a held Left already stepped back — each repeat landing on Pass 122's strip — and then carried on
into the rail once the window was at now, because the strip is not drawn there. The 2 s hold at now went
straight to the rail, as a click does.

### 2.3 The answers

1. **A held ring delivers one `.onMoveCommand`, at release, and nothing for its repeats.** That is Pass 77's
   "a held Right does not repeat", now explained: it counted move commands, and there is only ever one. The
   nudge for a click has always happened 150 ms after the button came *up*.
2. **The focus engine repeats a held press on its own** — the first move ~110–125 ms after press-down, the
   first repeat ~550 ms after that, then one every 260–268 ms until ~120 ms after the release. A held Right
   at HEAD therefore walked the row to its last cell and then had nowhere to go, which is the owner's "it
   stops and I have to keep clicking it to move to next time".
3. **The zero-duration long-press recognizer with `cancelsTouchesInView = false` observes press-down and
   release and changes nothing** — one move command per press, at release, with it installed; the engine's
   moves identical. Arm P was not needed.
4. **A strip to the right of a row's last cell is taken by every engine move there** — the click and each
   repeat — and handed back in 129–133 ms on 202 rows. A window step on that grid is drawn in ~0.5 s.
5. **A swipe right was not measured** — it cannot be driven from XCUITest — and is traced (§6): the owner's
   own words, "the gong back works swipe and the left over ring click", show a swipe left landing on Pass
   122's strip, which works on where focus goes, and the right strip is that strip's mirror. What a swipe
   delivers to `.onMoveCommand` is unknown and does not matter to the build, which does not use it.

### 2.4 The diagnostic's exact diff, and the revert

```diff
diff --git a/Marlin DVR TV/GuideScreen.swift b/Marlin DVR TV/GuideScreen.swift
index 458fe21..6ccc8dd 100644
--- a/Marlin DVR TV/GuideScreen.swift	
+++ b/Marlin DVR TV/GuideScreen.swift	
@@ -50,6 +50,7 @@
 //
 
 import SwiftUI
+import UIKit   // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
 
 enum GuideMark {
     /// ● while the recorder is running, ● for a Record Now booking that has not started,
@@ -457,6 +458,18 @@ struct GuideScreen: View {
                 .onMoveCommand { direction in gridMoved(direction) }
                 // Pass 122: outside the `ScrollView`, which would clip it. See `backStepCatcher`.
                 .overlay(alignment: .topLeading) { backStepCatcher }
+                // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+                .overlay(alignment: .topTrailing) {
+                    if Self.probeStrip && probeRightStripOn {
+                        Color.clear
+                            .frame(width: 16)
+                            .frame(maxHeight: .infinity)
+                            .focusable()
+                            .focusEffectDisabled()
+                            .focused($focused, equals: "probe-right")
+                            .offset(x: 28)
+                    }
+                }
                 legend
                     .padding(.top, 16)
             }
@@ -494,6 +507,10 @@ struct GuideScreen: View {
                 )
             }
         }
+        // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+        .background {
+            ProbeRingObserver(arm: Self.probeArm, shouldObserve: { probeShouldObserve() })
+        }
         .defaultFocus($focused, "loading")
         .task {
             await model.loadNow()
@@ -530,6 +547,17 @@ struct GuideScreen: View {
             if !open && redrawOwed { serverRedraw("the overlay closed", afterOverlay: true) }
         }
         .onChange(of: focused) { old, new in
+            // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+            print("[probe] t=\(Self.probeT()) focus \(old ?? "nil") -> \(new ?? "nil")")
+            if new == "probe-right" {
+                print("[probe] t=\(Self.probeT()) right strip caught from \(old ?? "nil"); focus back to it")
+                let back = old
+                Task { focused = back }
+                Task {
+                    try? await Task.sleep(for: .milliseconds(250))
+                    print("[probe] t=\(Self.probeT()) right strip · 250 ms later focused=\(focused ?? "nil") window=\(model.windowStart)")
+                }
+            }
             if let new, new.contains("@") { lastCell = new }
             if let new, new.contains("@") || new.hasPrefix("ch:") { lastGridFocus = new }
             // Pass 77: a step rightward inside one row is how a Right press the focus engine
@@ -605,6 +633,8 @@ struct GuideScreen: View {
     /// from the settled value, and a press the engine consumed is recognised by the rightward step
     /// it made rather than by any before/after comparison of `focused`.
     private func gridMoved(_ direction: MoveCommandDirection) {
+        // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+        print("[probe] t=\(Self.probeT()) move dir=\(direction) focused=\(focused ?? "nil") window=\(model.windowStart) atNow=\(model.isAtNow)")
         guard direction == .right, model.sheet == nil, channelMenu == nil, !collectionsOpen else { return }
         let pressedAt = Date()
         Task {
@@ -643,6 +673,24 @@ struct GuideScreen: View {
         }
     }
 
+    // [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+    // Arm "L": a `UILongPressGestureRecognizer`, zero duration, for Left and Right on the window, with
+    // `cancelsTouchesInView = false`, printing began/ended; observe only. Arm "P": a bare
+    // `UIGestureRecognizer` subclass printing `pressesBegan`/`pressesEnded` and never recognising.
+    // `MARLIN_PROBE_STRIP=1` adds a 16 pt focusable strip right of the programme area, drawn while the
+    // focused cell is the last one its row has; landing on it hands focus straight back and moves nothing.
+    static let probeArm = ProcessInfo.processInfo.environment["MARLIN_PROBE_ARM"] ?? "L"
+    static let probeStrip = ProcessInfo.processInfo.environment["MARLIN_PROBE_STRIP"] == "1"
+    static func probeT() -> String {
+        String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
+    }
+    private var probeRightStripOn: Bool {
+        guard model.loaded, !overlayOpen, let focused else { return false }
+        if focused == "probe-right" { return true }
+        return lastCellID(inRowOf: focused) == focused
+    }
+    private func probeShouldObserve() -> Bool { !overlayOpen && !hold.suspended }
+
     // MARK: Pass 122 — Left at a row's channel cell moves the window back one slot (item G)
 
     /// The focus id of the back-step catcher. It is neither a programme cell id nor a channel cell id,
@@ -986,6 +1034,95 @@ struct GuideScreen: View {
     }
 }
 
+// [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+struct ProbeRingObserver: UIViewRepresentable {
+    let arm: String
+    let shouldObserve: () -> Bool
+
+    func makeUIView(context: Context) -> ProbeRingObserverView { ProbeRingObserverView(arm: arm) }
+
+    func updateUIView(_ view: ProbeRingObserverView, context: Context) {
+        view.shouldObserve = shouldObserve
+    }
+}
+
+// [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+final class ProbeRingObserverView: UIView, UIGestureRecognizerDelegate {
+    let arm: String
+    var shouldObserve: () -> Bool = { false }
+    private var recognizer: UIGestureRecognizer?
+    private weak var installedOn: UIWindow?
+
+    init(arm: String) {
+        self.arm = arm
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
+            print("[probe] t=\(GuideScreen.probeT()) arm=\(arm) recognizer removed from the window")
+        }
+        guard let window, recognizer == nil else { return }
+        let r: UIGestureRecognizer
+        if arm == "P" {
+            r = ProbePressRecognizer()
+        } else {
+            let lp = UILongPressGestureRecognizer(target: self, action: #selector(changed(_:)))
+            lp.minimumPressDuration = 0
+            lp.cancelsTouchesInView = false
+            r = lp
+        }
+        r.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue),
+                               NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
+        r.allowedTouchTypes = []
+        r.delegate = self
+        window.addGestureRecognizer(r)
+        recognizer = r
+        installedOn = window
+        print("[probe] t=\(GuideScreen.probeT()) arm=\(arm) recognizer installed on the window (\(type(of: r)))")
+    }
+
+    @objc private func changed(_ g: UIGestureRecognizer) {
+        print("[probe] t=\(GuideScreen.probeT()) arm=\(arm) recognizer state=\(g.state.rawValue)")
+    }
+
+    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
+        let ok = shouldObserve()
+        print("[probe] t=\(GuideScreen.probeT()) arm=\(arm) shouldReceive type=\(press.type.rawValue) -> \(ok)")
+        return ok
+    }
+
+    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
+                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
+}
+
+// [probe] Pass 123 DIAGNOSTIC ONLY — reverted with `git checkout --` before the commit.
+final class ProbePressRecognizer: UIGestureRecognizer {
+    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
+        for p in presses { print("[probe] t=\(GuideScreen.probeT()) arm=P pressesBegan type=\(p.type.rawValue)") }
+    }
+    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent) {
+        for p in presses { print("[probe] t=\(GuideScreen.probeT()) arm=P pressesChanged type=\(p.type.rawValue) force=\(p.force)") }
+    }
+    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) {
+        for p in presses { print("[probe] t=\(GuideScreen.probeT()) arm=P pressesEnded type=\(p.type.rawValue)") }
+        state = .failed
+    }
+    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) {
+        for p in presses { print("[probe] t=\(GuideScreen.probeT()) arm=P pressesCancelled type=\(p.type.rawValue)") }
+        state = .failed
+    }
+}
+
 /// One channel row: the channel cell, then the programs placed by start/end across the window.
 struct GuideRowView: View {
     let row: GuideRow
```

**The revert**, before any of step 2's build was written:

```
$ git checkout -- "Marlin DVR TV/GuideScreen.swift"
$ rm "Marlin DVR TVUITests/Pass123ProbeUITests.swift"
$ git hash-object "Marlin DVR TV/GuideScreen.swift"
458fe21dc62dc2bee66be09699fa7391693006f4          # = git rev-parse HEAD:"Marlin DVR TV/GuideScreen.swift"
$ git status --porcelain
?? icon-source/
$ grep -rn 'Pass 123 DIAGNOSTIC\|probeArm\|ProbeRing\|MARLIN_PROBE\|probe-right' "Marlin DVR TV" "Marlin DVR TVUITests"
(none)
```

The same grep, plus `DIAGNOSTIC ONLY` and `Pass123Probe`, was run again before the commit (§9) and found
nothing. The build added no warning: the same two as HEAD, `GuideScreen.swift` `channelFocusID` (moved to
`:921` under the probe) and `PlayerModel.swift:367`.

---

## 3. Step 2 — what was built

All in `Marlin DVR TV/GuideScreen.swift`, +318 / −23. The 23 deletions are Pass 122's SwiftUI strip and its
`backStepID` (rebuilt as the UIKit catcher below), the old footer string, and the doc lines rewritten
beside them; `fetch` is untouched, and so are `gridMoved`'s logic, `nudge(from:)`, `nudgeForward`,
`nudgeBack`, Menu, ↩ Now, +12h, the collection filter and the Pass 116 redraw.

### 3.1 (a) and (b) — the forward catcher

- **`forwardStepID`** (`:758`), `"forward-step"`: neither a programme cell id nor a channel cell id, so
  `lastCell`, `lastGridFocus`, `isRightwardStep`, `handleHold` and the redraw's focus repair pass over it.
- **`forwardStepCatcherOn`** (`:763`): loaded, no overlay, and the focused cell is the last one its row has
  in the window — or the catcher itself has focus, for the moment of the hand-back.
- **`forwardStepCatcher`** (`:781`): the measured strip exactly — 16 pt, `Color.clear`, `.focusable()`,
  `.focusEffectDisabled()`, `.offset(x: 28)` — in a `.topTrailing` overlay of the grid's `ScrollView`
  (`:486`), beside Pass 122's `.topLeading` one.
- **`forwardStep(from:)`** (`:796`), called from `.onChange(of: focused)` (`:572`) when focus lands on it:
  it stamps `engineSteppedRightAt` (`:799`) — the engine consumed this press — so `gridMoved`'s settle
  stands down instead of nudging the same press a second time; then hands focus back and calls **Pass 77's
  `nudge(from:)`** unchanged, so the last-listed-slot stop, the 45-slot refetch and the focus rule are
  Pass 77's. Should a tvOS not choose the strip, `gridMoved` still nudges the click as before (it fails open).
- **No timer.** Each engine move on to the strip — a click, a swipe, or each repeat of a held ring — is one
  step. The pace is the engine's (§2.3 item 2), throttled by the redraw.

### 3.2 (c) — the held Left

- **The steps** need nothing new: the engine's repeats land on Pass 122's catcher and `backStep(from:)`
  (`:733`) steps back one slot each, as §2.2 already showed at HEAD.
- **The stop at now.** `RingHoldWatch` (`:1217`) / `RingHoldWatchView` (`:1231`) — the measured recognizer,
  for Left only, `RemoteHoldDetector`'s shape, in the Guide's `.background` (`:526`), receiving a press only
  while the Guide's own grid or header has the remote and no overlay or Player is up — reports press-down and
  release. `leftRingPressed` (`:827`) sets `leftRingHeld` **350 ms** after press-down (`holdThreshold`,
  `:817`: clear of a click's 134 ms and of the engine's first move at ~110 ms, so a click at now still
  reaches the rail). `backStepCatcherOn` (`:693`) then keeps the catcher drawn **at now** while
  `leftRingHeld`; a landing there is refused by `nudgeBack()` and focus is handed back. `leftRingReleased`
  (`:840`) and every landing after the release (`:748`) call `leftRingLetGoWhenQuiet` (`:850`), which ends
  the hold **500 ms after the engine's last landing** (`holdQuiet`, `:824`) — §4 says why it is not a fixed
  wait from the release. A separate Left press after that finds no catcher at now and reaches the rail.
- **The catcher is a UIKit view now**: `BackStepCatcher` (`:1150`), `BackStepCatcherView` (`:1160`) and
  `BackStepLandingView` (`:1193`) — the same 16 pt landing, `canBecomeFocused`, invisible, no focus effect,
  with a `UIFocusGuide` 8 pt to its left whose `preferredFocusEnvironments` is the landing itself, so the
  engine's answer to a Left *from* the landing is the landing: no movement, never the rail. Its
  `didUpdateFocus` reports the landing gaining and losing focus, `backStepCatcherFocused` (`:391`) stands
  in for the `"back-step"` id, and `backStep(from: lastGridFocus)` runs on the landing. §4 says why.

### 3.3 (d) — the footer

`:1135`: the ahead sentence is "Menu snaps back to now · 24 hours per request". The at-now sentence,
"Starts at the current half hour · forward only", was not named by the owner and is unchanged (open
question 1).

### 3.4 The header

A Pass 123 paragraph (`:50-64`) beneath Pass 122's, saying the above.

---

## 4. Verify — five runs, two failures, each diagnosed with its console

`GuideRingHoldUITests` (new), `launch()`, one drive; each run below is one invocation of
`-only-testing:"Marlin DVR TVUITests/GuideRingHoldUITests/testHeldRightStepsForwardHeldLeftStopsAtNowAndTheFooter"`
against `build/p123`'s `build-for-testing`. The app code changed twice between runs (after runs 2 and 3);
the harness changed once for itself (after run 1) and once in its comments (after run 4).

| Run | Launch ping | Result | What happened |
|---|---|---|---|
| 1 | `17:28:31.826` | failed on the harness | held Right 6 slots; held Left came back to **5:30 PM — the current half hour, the clock having crossed 17:30 during the run** — and stopped in the grid on the channel cell, as built; the harness compared against the 5:00 the Guide had opened at |
| 2 | `17:32:28.745` | **failed in the app** | held Left reached now (6 steps) **and then the rail** |
| console drive | `17:37:29.891` (devicectl) | passed | the same drive with the app's lines readable — §4.1 |
| 3 | `17:43:58.303` | **failed in the app** | held Left **went into the rail five steps in, at 6:30 PM, with the window still ahead** |
| console drive | `17:51:42.090` (devicectl) | passed | the final code with the app's lines readable — §4.2 |
| 4 | `17:55:46.431` | passed | the final code less one comment |
| **5** | **`18:00:43.749`** | **passed — the record** | the committed tree, §5 |

### 4.1 Run 2's failure — the let-go raced the engine's last repeat

The console drive after run 2 (the harness's second method, `testTheSameDriveWithTheConsoleAttached`, no
`launch()`, no `activate()`; the Mac stamped each line as it arrived) passed and showed the mechanism as
built, with the timing that explains run 2. The held Left, seven slots ahead, press-down `17:40:03.788`,
release `17:40:12.091`:

```
17:40:04.019 [guide] back-step -> 8:30 – 10:30 PM      (the press's own move, +0.23 s)
17:40:04.542 [guide] left ring held                    (+0.75 s: the 350 ms task, late under the redraw)
17:40:04.785 [guide] back-step -> 8:00 – 10:00 PM      (the first repeat)
17:40:05.354 … 7:30      17:40:06.034 … 7:00      17:40:06.615 … 6:30      17:40:07.368 … 6:00
17:40:08.033 [guide] back-step -> 5:30 – 7:30 PM      (the seventh, +4.25 s: at now)
17:40:08.798 [guide] back-step refused … the held ring stops here      (nine of these, one per repeat, every ~0.42 s)
   …
17:40:12.155 [guide] back-step refused … the held ring stops here      (+64 ms after the release)
17:40:12.499 [guide] left ring let go                  (+0.41 s after the release)
17:40:39.721 [rail] entered on favorites, restoring to guide           (the separate Left, 27 s later)
```

The seven steps took 4.25 s; the catcher then refused nine repeats at now while the ring was down; the
let-go came 0.41 s after the release, and the rail was entered only by the separate press. **Why run 2 went
the other way:** the engine's last repeat is due up to ~120 ms after the release (§2.2), and my fixed 350 ms
let-go was due 350 ms after it — two main-thread timers ~230 ms apart, and the grid was redrawing 0.4–0.5 s
at a time. A timer that is due fires when the run loop next gets to it, and two overdue timers fire in the
same pass; with the let-go first, the catcher was gone when the straggler moved focus, and the only thing
left of the channel cell is the rail. **The fix (§3.2):** the let-go is re-armed by every landing after the
release, so it is always ordered after the engine's last repeat, whatever the load.

### 4.2 Run 3's failure — a repeat while the strip itself had focus

With that fix, run 3 failed differently: the window was still ahead (6:30 PM, five steps in) when focus went
to the rail. §2.2's Left hold at HEAD shows the shape: a landing on the strip, then the hand-back drawn
**548 ms** later because it shares a render with the window step, while the engine repeats every 266 ms.
A repeat that fires in that gap moves Left *from the strip* — and the only focusable thing left of the strip
is the rail. Whether it fires there is a coin flip between the redraw finishing and the timer firing; it
came up once in three runs. No timing change can close that, so the strip became a UIKit view with a focus
guide to its left that redirects back to it (§3.2): a Left from the landing goes nowhere at all. The console
drive of that code, press-down `17:54:13.849`, release `17:54:22.180`:

```
17:54:14.146 [guide] back-step -> 8:30 – 10:30 PM
17:54:14.748 [guide] left ring held
17:54:15.039 … 8:00     17:54:15.560 … 7:30     17:54:16.290 … 7:00     17:54:16.917 … 6:30     17:54:17.714 … 6:00
17:54:18.404 [guide] back-step -> 5:30 – 7:30 PM      (the seventh, +4.56 s: at now)
17:54:19.474 [guide] back-step refused … the held ring stops here      (six, every 0.36–0.9 s — the guide swallows the repeats that fire while the landing has focus)
   …
17:54:22.228 [guide] back-step refused … the held ring stops here      (+48 ms after the release)
17:54:23.136 [guide] left ring let go                  (+0.96 s: 500 ms of quiet, then the task, late under the redraw)
17:54:49.971 [rail] entered on favorites, restoring to guide           (the separate Left)
```

And the held Right in the same drive, press-down `17:53:25.996`, release `17:53:30.197`:

```
17:53:26.739 [guide] nudge -> 6:30 – 8:30 PM · fetch=1790371800 · focus stays on 2.1@1790379000
17:53:27.499 … 7:00     17:53:28.030 … 7:30     17:53:28.765 … 8:00     17:53:29.256 … 8:30
17:53:29.844 [guide] nudge -> 9:00 – 11:00 PM · fetch=1790371800 · focus stays on 2.1@1790384400
```

**Six window steps in one 4.2 s press, 0.49–0.76 s apart** — each interval one redraw and, every second or
third repeat, a cell walk (Pass 77's ratio) — the first 0.74 s after press-down, the last 0.35 s before the
release, and no `fetch=` change. That is the pace on All Channels.

---

## 5. The run of record — run 5 on Home Theater

```
xcodebuild … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
  -derivedDataPath build/p123 build-for-testing
xcodebuild test-without-building -xctestrun build/p123/Build/Products/…xctestrun \
  -destination 'platform=tvOS,name=Home Theater' \
  -only-testing:"Marlin DVR TVUITests/GuideRingHoldUITests/testHeldRightStepsForwardHeldLeftStopsAtNowAndTheFooter"
```

**18:00:38–18:04:10, `** TEST EXECUTE SUCCEEDED **`, "Executed 1 test, with 0 failures", 207.1 s.** Its
stage lines, verbatim (the Guide on All Channels, at 6:00 PM):

```
[pass123 18:00:44.699] launched
[pass123 18:01:13.459] OPEN window=“Fri Sep 25 · 6:00 – 8:00 PM” startMin=394200 strip=“6:00 PM · now” nowPill=false footer=“Starts at the current half hour · forward only” zone=grid:programme-cell focus=9:“WMAR-2 News at 6PM” (554,228 315x82) clockHalfHour=394200
[pass123 18:01:54.883] AT THE EDGE window=“Fri Sep 25 · 6:00 – 8:00 PM” startMin=394200 strip=“6:00 PM · now” nowPill=false footer=“Starts at the current half hour · forward only” zone=grid:programme-cell focus=9:“Flip Side” (1524,228 315x82)
[pass123 18:02:12.436] ONE CLICK RIGHT AT THE EDGE window=“Fri Sep 25 · 6:30 – 8:30 PM” startMin=394230 strip=“6:30 PM” nowPill=true footer=“Menu snaps back to now · 24 hours per request” zone=grid:programme-cell focus=9:“Flip Side” (1203,228 309x82)
[pass123 18:02:15.693] HOLD RIGHT 4 s: press-down
[pass123 18:02:20.224] HOLD RIGHT 4 s: press-up
[pass123 18:02:33.455] HELD RIGHT 4 s -> 6 slot(s) in the one press window=“Fri Sep 25 · 9:30 – 11:30 PM” startMin=394410 strip=“9:30 PM” nowPill=true footer=“Menu snaps back to now · 24 hours per request” zone=grid:programme-cell focus=9:“20/20” (554,228 958x82)
[pass123 18:02:54.480] walk left #1: startMin=394410 zone=grid:channel-cell focus=9:“WMAR-HD, 2.1” (236,228 300x82)
[pass123 18:03:10.295] ON THE CHANNEL CELL, 7 SLOT(S) AHEAD window=“Fri Sep 25 · 9:30 – 11:30 PM” startMin=394410 strip=“9:30 PM” nowPill=true footer=“Menu snaps back to now · 24 hours per request” zone=grid:channel-cell focus=9:“WMAR-HD, 2.1” (236,228 300x82) clockHalfHour=394200
[pass123 18:03:10.581] HOLD LEFT 8.2 s: press-down
[pass123 18:03:18.969] HOLD LEFT 8.2 s: press-up
[pass123 18:03:35.569] HELD LEFT 8.2 s window=“Fri Sep 25 · 6:00 – 8:00 PM” startMin=394200 strip=“6:00 PM · now” nowPill=false footer=“Starts at the current half hour · forward only” zone=grid:channel-cell focus=9:“WMAR-HD, 2.1” (236,228 300x82) clockHalfHour=394200
[pass123 18:04:03.091] ONE SEPARATE LEFT AT NOW window=“Fri Sep 25 · 6:00 – 8:00 PM” startMin=394200 strip=“6:00 PM · now” nowPill=false footer=“Starts at the current half hour · forward only” zone=rail focus=9:“Guide” (80,332 258x56)
```

Reading it: one click at the edge moved the window exactly one slot (6:00 → 6:30) through the new catcher;
**one press-down and one press-up 4.5 s apart moved it six more** (6:30 → 9:30), with ↩ Now drawn and the
footer's new sentence — the harness also asserted the old sentence is not drawn; one Left along the row
reached "WMAR-HD, 2.1" with the window unmoved; **one press-down and one press-up 8.4 s apart brought it back
seven slots to 6:00 PM — the clock's own current half hour — and left focus on "WMAR-HD, 2.1" in the grid**,
"· now" drawn, ↩ Now gone, the at-now footer back; **one separate Left reached the rail with the ring on
Guide** and the window unmoved.

**The launch ping and the server's view of the run** (`GET /api/logs`, client id replaced):

```
18:00:43.749 POST /api/clients/<client id>/ping 200
18:00:43.749–.888  GET /api/channels, /api/radio, /api/library, /api/cameras, /api/schedule, /api/guide/now   (Home)
18:00:49.146 GET /api/schedule 200
18:00:49.169 GET /api/guide 200                      (the Guide opens — loadNow)
18:00:49.643–.994  GET /api/art/feed 200 × ~200     (the channel logos)
18:00:53.950 GET /api/collections 200                (Pass 116's first connect re-read)
18:00:53.965 GET /api/guide 200
18:00:53.966 GET /api/schedule 200
18:04:09.100 GET /api/events 200                     (the stream closing as the run ended)
```

**No `GET /api/guide` from 18:00:53 to the end** — one click, six held steps forward and seven back, all inside
the 24 hours fetched at 18:00, no refetch. Across 17:10–18:06 the log holds **eight non-GET requests, all
launch pings from one client id** — the diagnostic launch (17:15:36), the five harness runs and the two
console drives — and nothing else.

**Screenshots** (run 5), in `reports/assets/pass123/`: `01-guide-open-at-now.jpg`,
`02-one-click-right-at-the-edge.jpg`, `03-after-a-4s-held-right.jpg` (9:30 – 11:30 PM, ↩ Now, the ring on
"20/20"), `04-footer-while-ahead.jpg` (the new sentence, bottom right), `05-on-the-channel-cell-ahead.jpg`,
`06-held-left-stopped-at-now-in-the-grid.jpg` (6:00 PM · now, no ↩ Now, the ring on WMAR-HD, the rail
collapsed) and `07-a-separate-left-reaches-the-rail.jpg` (the rail expanded, the ring on Guide).

---

## 6. Run or traced

**Run on Home Theater (run 5, `XCUIRemote`; the console drives add the app's own lines):**
- a click Right at a row's last cell moving the window one slot through the forward catcher, and once only;
- **a held Right stepping the window six slots inside one press**, no release inside it, ↩ Now drawn;
- the footer while ahead reading the new sentence, the old one absent; the at-now sentence unchanged;
- Left along the row with the window unmoved;
- **a held Left stepping back seven slots inside one press, stopping at the current half hour with focus
  still on the channel cell**, "· now" drawn, ↩ Now gone, the at-now footer back;
- **one separate Left at now reaching the rail with the ring on Guide**, the window unmoved;
- no refetch during either hold (server log);
- with the console: the step-by-step timing of both holds, the refusals at now while the ring was down, the
  let-go after the release, and no `[rail] entered` line until the separate press.

**Measured under the diagnostic (§2), not on the shipped build:** the engine's repeat and its timing; the move
command arriving at release; the recognizer's began/ended; the right strip taking every move at the edge.

**Code-traced only:**
- **a swipe right, and a swipe left** — never driven; the owner's words are the only evidence that a swipe
  lands on a strip;
- a held Right across the 45-slot refetch, and at the horizon, where each repeat prints Pass 77's "nudge
  refused" line until the ring is let go;
- a hold on a row that has no later cell in the window;
- a held Left that **starts at now** — its own first move reaches the rail, as a click does, and the hold then
  does nothing in the rail;
- a held Left that starts **one slot ahead**: the first press's own step reaches now and withdraws the catcher;
  `leftRingHeld` (350 ms, 0.75–0.9 s under load) must then be drawn before the engine's first repeat at
  ~670 ms — if it loses, focus goes to the rail, the behaviour before this pass;
- a second Left inside about half a second of a hold's release, which the catcher still refuses;
- one extra forward step from the engine's last repeat after a held Right is released (§2.2 shows the repeat);
- the physical ring's repeat itself: measured with a synthesized hold, which drives the device's own press
  pipeline (Pass 9), and consistent with the owner's "keep scrolling through it stops";
- Up, Down and Right while either catcher is drawn; the Player on top; an overlay open (neither catcher is drawn);
  a server notice during a hold; a half-hour boundary during a hold.

---

## 7. The server reads this pass made

Two `GET http://192.168.1.250:8090/api/logs` with `curl`, at 18:00 and 18:04, to read the launch pings and
the app's requests; the files sat in the session scratchpad and are quoted here with the client id replaced.
`GET /api/settings` was not read. Everything else was the app's own traffic in the runs.

---

## 8. Records this pass changes, recorded forward and not edited

- DECISIONS.md:1238-1241 (Pass 77): *"A held Right does NOT auto-repeat the move command, so nothing was
  built for it."* — still true of the move command; the engine repeats the *focus move*, and the Guide now
  steps on each.
- DECISIONS.md:1288-1289 (Pass 78) and COLD-START's closed item *"whether a physical held Right
  auto-repeats"* — reopened by the owner by name and answered (§2.3); COLD-START's line is updated in place.
- `reports/2026-09-12-pass77-guide-scroll-right.md` §2, *"tvOS does not auto-repeat the move command, so
  nothing was built for it"* — the same.
- Pass 122's *"the footer while ahead still says 'forward only'"* (its open question 1) — closed by (d).
- Pass 122's SwiftUI strip and its `backStepID` — superseded by the UIKit catcher; its "7 ms and 13 ms"
  hand-back was on a 5-row collection, and on 202 rows it is 0.13–0.55 s (§2.2).
- `GuideScreen.swift`'s Pass 77 header line, *"Forward only; Left, Menu, "↩ Now" and "+12h" are untouched."*
  — kept, with Pass 122's and this pass's paragraphs beneath it.
- **COLD-START.md's Guide line and harness line are brought to the current state in place** (step 3), and
  `GuideRightEdgeUITests.testScrollThenRailRoundTrip` is recorded there as unable to pass since Pass 122
  (owner's 3a). It was not run or amended.

Checked and not changed: design 3a's "forward-only from the current half hour" (DECISIONS.md:18) — the
floor holds, a held Left stops at now; the rail landing on the entry that opened the screen (Pass 25) —
`ScreenShell.swift` is byte-identical and the separate Left landed on Guide.

---

## 9. The revert, checked again before the commit

```
$ git diff HEAD --stat -- "Marlin DVR TV"
 Marlin DVR TV/GuideScreen.swift | 341 +++…
 1 file changed, 318 insertions(+), 23 deletions(-)
$ grep -rn 'DIAGNOSTIC ONLY\|probeArm\|ProbeRing\|MARLIN_PROBE\|probe-right\|Pass123Probe' "Marlin DVR TV" "Marlin DVR TVUITests"
(none)
$ git diff HEAD --stat -- "Marlin DVR TV/ScreenShell.swift" "Marlin DVR TV/RailView.swift" "Marlin DVR TV/PlayerModel.swift" "Marlin DVR TV/PlayerHost.swift" "Marlin DVR TV.xcodeproj"
(no diff)
$ git diff HEAD -- "Marlin DVR TV/GuideScreen.swift" | grep -n "^[-+].*fetch(from\|^[-+]    private func fetch"
(fetch lines untouched)
```

---

## Open questions

1. **The at-now footer still says "Starts at the current half hour · forward only."** The owner's 2a named
   the ahead sentence only, so this one is unchanged. At now the Guide is indeed forward-only, but the words
   now sit beside a Guide that goes back. Change it too?
2. **A held Left that starts one slot ahead** (§6) can lose a race to the engine's first repeat under the
   202-row redraw and put focus in the rail — the behaviour before this pass, not a new one. Lowering
   `holdThreshold` narrows it and widens the chance that a slow click at now is swallowed. Leave it?
3. **On All Channels a window step takes ~0.5 s to draw** (202 rows in a plain `VStack`), which is what sets
   the held ring's pace there; on a five-row collection the pace is the engine's 0.27 s. Not this pass's to
   change; recorded so the difference between collections is not read as a defect.

## What I am least sure of

1. **That the focus guide's redirect-to-self is a guarantee rather than a strong tendency.** It held through
   six refusals and thirteen back-steps in two drives with no rail entry, where the SwiftUI strip lost once in
   three runs; but tvOS's handling of a guide that names the current item is documented behaviour I have
   measured, not a contract I have read.
2. **That a physical thumb repeats as the synthesized hold does.** Every repeat measured came from
   `XCUIRemote.press(_:forDuration:)`. Pass 9 established the synthesized press drives the real pipeline and
   the owner's words describe a hold that scrolls and then stops, which is what this explains — but the first
   physical hold is his.
3. **The swipe.** It was never driven here or in Pass 122. The owner reported the swipe left works; the right
   strip is the same idea mirrored, and if a swipe right does not land on it, nothing else in this pass
   catches it.

## How the owner can see each of a–d on Home Theater

Open the Guide (it opens at the current half hour on the collection last picked).

- **(a) Swipe right.** Go Right along a row to its last programme. **Swipe right on the touch surface:** the
  whole Guide moves forward half an hour, as a click there does. Swipe again for another.
- **(b) Hold Right.** From anywhere in a row, **press and hold the right edge of the ring:** the highlight walks
  the row's programmes and, at the edge, the Guide keeps stepping forward half an hour at a time — on All
  Channels about one step every half second or so, faster on a small collection — until the ring is let go.
  It still stops at the last half hour that has a listing.
- **(c) Hold Left.** With the Guide ahead of now, Left to the channel's logo cell, then **press and hold the
  left edge of the ring:** the Guide steps back half an hour at a time, the highlight staying on the channel,
  and **stops at the current half hour** ("· now" in the first column, no ↩ Now) however long the ring is held.
  **Let go, then press Left once:** the sidebar opens on Guide, as before.
- **(d) The footer.** While the Guide is ahead of now, the sentence at the bottom right reads **"Menu snaps back
  to now · 24 hours per request"**.

---

## SCOPE CHECK

| File | Step | Change |
|---|---|---|
| `Marlin DVR TV/GuideScreen.swift` | 2 (measure) | the `[probe]` diagnostic — **added, launched once, and reverted with `git checkout --`**; not in the commit; its diff is §2.4 |
| `Marlin DVR TVUITests/Pass123ProbeUITests.swift` | 2 (measure) | the diagnostic's harness — **created, used and deleted**; not in the commit |
| `Marlin DVR TV/GuideScreen.swift` | 2 a–d | the forward catcher, the held-Left stop, the UIKit back-step catcher, the recognizer, the footer, a header paragraph; +318 / −23 |
| `Marlin DVR TVUITests/GuideRingHoldUITests.swift` | Verify | new — the run's harness, `launch()`, two methods, which the pass allows |
| `DECISIONS.md` | 3 | the Pass 123 entry |
| `COLD-START.md` | 3 | the Guide line; the harness line, with `testScrollThenRailRoundTrip` recorded stale; the closed item on the held Right; *Next step*, with Pass 122's paragraph kept beneath it, labelled |
| `reports/2026-09-25-pass123-guide-swipe-and-held-ring.md` | 3 | new — this report |
| `reports/assets/pass123/` (7 `.jpg`, 2.3 MB) | 3 | new — run 5's screenshots, exported from its result bundle |

**Nothing else was changed.** Every other app file, `project.pbxproj` and every other test file are
byte-identical; the UI-test target is a synchronised folder, so the harness needed no project edit. Scratch —
the diagnostic diff, its console, the five test logs, the two console drives, the log reads and the exported
attachments — is in the session scratchpad, outside the repo. `build/p123probe` and `build/p123` are the
DerivedData of the diagnostic and the runs; `build/` is git-ignored.

## Pushed vs local

**Local only.** One commit on `main`, two ahead of `origin/main` (`6950e2a`) together with Pass 122's
`65321af`. Nothing was pushed: the owner tests on Home Theater first, and both go together after that.
