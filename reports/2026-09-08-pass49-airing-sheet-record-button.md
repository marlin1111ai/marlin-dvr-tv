# Pass 49 — the airing sheet's first control tells the truth

**Date:** 2026-09-08
**Committed locally. NOT pushed** — UI the owner judges with his eyes, behind the separate push gate.
**One file changed:** `Marlin DVR TV/AiringSheet.swift`. No project setting, build script, config or
dependency was touched, no new dependency added, **no new network request and no new model field**.
`design/` was **read** and not edited. The Guide grid, its gold/green marks and the amber series-pass
line are untouched.

The app talked to `http://192.168.1.250:8090/` during the device test; that is ordinary app traffic.
**No administrative, diagnostic or shell request was made to the server and nothing on it was
changed.** The harness used makes **no server writes at all**.

---

## 0. What the existing record settles

- **COLD-START.md `:358-364`** already names this defect and its cause: *"the 'Scheduled' chip and
  the Record button are still gated on `passId == "manual"` (`AiringSheet.swift`, `manualJob`
  `:71-74`)"*, while Stop *"turns on `Job.status == "Recording"` and correctly ignores `passId`*.
  **Recorded as unfixed, found in Pass 32, scoped out there and in Pass 33.** Re-verified this pass:
  the property was at **`:70-73`**, not `:71-74` — the line reference had drifted by one.
- **DECISIONS.md, 2026-09-05 (design)** settles that the airing sheet is in scope with "Record Now,
  Series Pass, Watch live", and Pass 9 added the fourth control.
- **Prior reports** covering this sheet: Passes 4, 6, 7, 8, 9, 10, 11, 12, 25, 26, 32, 34 mention it;
  Pass 8 built the buttons and the chip, Pass 9 reshaped them, **Pass 32 built "Stop recording" and
  is where this defect was found**. None of them fixed it.

**Nothing in the record settles what the fix should be** — that was the owner's decision, given in
this pass's brief.

---

## 1. Ground truth, read-only, before any edit

### 1.1 The sheet and its four controls

`Marlin DVR TV/AiringSheet.swift`, 466 lines before the change. The controls are built in
`buttons` (`:225-258` before the change), an `HStack(spacing: 16)`:

| Control | Line (before) | Condition to appear |
|---|---|---|
| **"Record this airing"** | `:231` | `manualJob == nil` — i.e. **no** manual, non-Skipped job |
| *(or)* `StateChip "● Scheduled"` | `:229` | `manualJob != nil` |
| **"Record the series" / "Edit series pass"** | `:235` | **always** — one control, label swaps on `pass == nil` |
| **"Watch live"** | `:242-249` | `isAiringNow` (`:85-88`), the programme is on right now |
| **"Stop recording"** | `:251-254` | `recordingJob != nil` (`:79-82`), i.e. `job.status == "Recording"` |

`manualJob` (`:70-73` before the change) was the defect:

```swift
guard let job, job.passId == "manual", job.status != "Skipped" else { return nil }
```

A pass-driven job has `passId != "manual"`, so `manualJob` was nil and the sheet fell through to
"Record this airing" **even while `recordingJob` was simultaneously non-nil and drawing "Stop
recording"** — exactly what the owner photographed.

### 1.2 What the app already knows about an airing's state

- **`Job.status`** — `Models.swift:170`, with the server's own values enumerated in the model:
  `Queued | Skipped | Conflict | Recording | COMPLETED | FAILED | STOPPED`.
- **`Job.passId`** — `Models.swift:160`, `"manual"` for Record Now.
- The sheet holds the job in `@State private var job` (`:56`), seeded from `selection.job` (`:147`)
  and then **re-read from `GET /api/schedule`** via `onScheduleChanged()` (`:154`, and again at
  `:135`, `:336`, `:354`, `:396`). The comment at `:149-153` records why: the Guide's copy is only as
  fresh as its last fetch, so a booking that has since started recording would still read "Queued".
- **The Guide grid's marks are driven from those same two fields.** `GuideScreen.swift:173-178`:

```swift
private func mark(for job: Job?) -> GuideMark? {
    guard let job else { return nil }
    if job.status == "Recording" { return .recording }
    guard job.status == "Queued" || job.status == "Conflict" else { return nil }
    return job.passId == "manual" ? .scheduled : .pass
}
```

with `GuideMark` at `GuideScreen.swift:21-44` — `.recording` and `.scheduled` green, `.pass` gold
(`:40-41`). **So the gold and green the owner sees on the Guide come from `Job.status` and
`Job.passId`, the very fields the sheet already holds.**

### 1.3 Can the app distinguish SCHEDULED from RECORDING NOW without a new request or field?

**YES.** Straight answer, and the evidence is that the app already does it twice:

- `AiringSheet.recordingJob` (`:79-82`) already isolates **recording now** with
  `job.status == "Recording"`, and its own comment (`:76-78`) states the rest of the rule: *"Queued,
  Conflict and Skipped have not started, and COMPLETED, STOPPED and FAILED are over."*
- `GuideScreen.mark(for:)` (`:173-178`) already separates **recording** from **booked-but-not-started**
  using the same `status` values.

No new request, no new field and no new source of truth are needed — the distinction is `Job.status`,
which the sheet re-reads from the schedule on open.

---

## 2. Every changed line

Three hunks, all in `AiringSheet.swift`. `git diff --name-only` returns that one file.

### 2.1 The state, replacing `manualJob` — `:70-73` → `:69-88`

```diff
-    /// A Record Now booking on this airing: the manual job the server keeps (passes.go:60).
-    private var manualJob: Job? {
-        guard let job, job.passId == "manual", job.status != "Skipped" else { return nil }
-        return job
-    }
+    private enum AiringState { case recording, scheduled, unbooked }
+
+    private var airingState: AiringState {
+        guard let job else { return .unbooked }
+        if job.status == "Recording" { return .recording }
+        if job.status == "Queued" || job.status == "Conflict" { return .scheduled }
+        return .unbooked
+    }
```

(`:81` and `:83-88`, under a doc comment at `:69-80`.) **`passId` is deliberately not consulted** —
that was the defect. `manualJob` is **removed, not left behind**: `grep -n "manualJob"` over the file
now returns nothing, so no later pass can reach for the wrong predicate.

The statuses match `GuideScreen.mark(for:)` exactly: `"Recording"` is recording; `"Queued"` and
`"Conflict"` are booked-but-not-started; everything else — no job, `Skipped`, `COMPLETED`, `FAILED`,
`STOPPED` — is unbooked and stays recordable.

### 2.2 The three-state control — `:228-232` → `:246-257`

```diff
-            if let manualJob {
-                StateChip(text: "● Scheduled", detail: manualJob.status, color: GuideMark.green)
-            } else {
+            switch airingState {
+            case .recording:
+                StateChip(text: "● Recording", color: GuideMark.green)
+            case .scheduled:
+                StateChip(text: "● Scheduled", detail: job?.status ?? "", color: GuideMark.green)
+            case .unbooked:
                 action("Record this airing", id: "record", primary: true) { await record() }
             }
```

`:251-256`. The control **is never hidden** — it always occupies the first slot in the row, as the
owner required.

### 2.3 Default focus — `:167-169` → `:183-187`

```diff
-    private var firstFocusID: String {
-        manualJob == nil ? "record" : "series"
+    private var firstFocusID: String {
+        airingState == .unbooked ? "record" : "series"
     }
```

`:186`. **This had to change with the control.** `firstFocusID` is what `:156` assigns to `focused`
when the sheet opens; had it kept the old gating, a pass-driven recording would have opened trying to
focus `"record"` — an id that no longer exists in that state — and focus would have landed nowhere.

### 2.4 The other three controls: untouched

"Record the series"/"Edit series pass" (`:253` before → `:259` after), "Watch live" and "Stop
recording" are **byte-identical** in label, behaviour, appearance condition and position. The diff
contains no change to any of them, and the amber series-pass footer line (`:282-285` before) is
untouched.

---

## 3. How non-focusability is achieved

**`StateChip` — `AiringSheet.swift:447-475`.** It is a plain `VStack` of two `Text`s with padding, a
background and a border. It contains **no `Button`, no `.focusable()`, and no `.focused()` binding**.
On tvOS a plain text hierarchy is not focus-eligible, so the focus engine simply does not offer it —
it is not a dead control that can be landed on, it is not a control at all.

That is the same mechanism the sheet has used since Pass 8 for the manual-booking chip at the same
position, and it has been on the owner's Apple TV since Pass 9's acceptance.

**Focus skipping it cleanly** is covered on both sides:

- **On open**, `firstFocusID` (`:186`) resolves to `"series"` whenever the first slot is a chip, so
  the sheet opens on the series button rather than on nothing.
- **Along the row**, the remaining controls each keep their own `.focused($focused, equals:)`
  binding — `"series"` (`:268` via `action`), `"watch"` (`:264`), `"stop"` (`:268` via `action`) —
  and the chip has none, so left/right movement addresses only real controls.

**What I did not do:** I did not add `.focusable(false)` or any disabling modifier. None is needed,
and adding one would be a change with no effect.

---

## 4. Design comparison

**The design does not specify a non-interactive status label in that row.** Frame 5c's button row is
`dc:568-572`, and it draws exactly three pressable-looking controls:

```html
568  <div style="display:flex; gap:20px; flex-wrap:wrap">
569    <span … border:4px solid var(--color-accent); …>Record this airing</span>
570    <span … border:1px solid var(--color-neutral-700); …>Record the series</span>
571    <span … border:1px solid var(--color-neutral-700); …>Watch live</span>
572  </div>
```

There is no fourth state, no chip, and no "Recording" or "Scheduled" label anywhere in frame 5c.

**So the appearance was carried over, not specified.** `StateChip` keeps the shape and typography it
has had since Pass 8: `Nocturne.TextSize.body` (29 pt, matching the design's `font-size:29px`),
`Nocturne.Radius.md` corners, an `.infinity` width so it fills the button's slot, and a 1 pt border
in `GuideMark.green`. The "● Scheduled" state is **byte-identical to what already shipped** and was
accepted on Home Theater in Pass 9; "● Recording" is the same component with different text and no
detail line. I am stating plainly that this is carry-over, not design specification.

---

## 5. The build (step 5)

```
$ xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
    -destination 'generic/platform=tvOS Simulator' build
…
** BUILD SUCCEEDED **
```

Filtered for diagnostics (`grep -E "^\*\* BUILD|(warning|error): "`, excluding the unrelated
AppIntents note), the simulator build returns **only** `** BUILD SUCCEEDED **` — no warning, no error.

**The device build surfaced one warning, and it is not from this pass:**

```
GuideScreen.swift:336:34: warning: call to main actor-isolated static method 'channelFocusID'
                                   in a synchronous nonisolated context
```

Evidence that it is pre-existing: `git status --porcelain "Marlin DVR TV/GuideScreen.swift"` returns
nothing (unmodified), line 336 is **byte-identical** to `git show HEAD:…` at the same line, and
`git diff --name-only` lists only `AiringSheet.swift`. It appears in the device build and not the
simulator one because that build recompiled the file. **Reported, not silently accepted; not fixed,
because `GuideScreen.swift` is out of scope for this pass.**

---

## 6. The device (step 6)

`Home Theater` was **connected**:

```
Home Theater   Home-Theater.coredevice.local   <REDACTED-DEVICE-UUID>   connected   Apple TV 4K (3rd generation)
```

**The build under test is the one built in this pass** — built after the edit, fingerprinted, and
that exact bundle installed:

```
binary mtime : Sep 8 22:53
binary sha256: d84222114a290c19be74f2acd7684d144cf31eeb108f064202f80e3656940e2c

$ xcrun devicectl device install app --device "Home Theater" "…/Debug-appletvos/Marlin DVR TV.app"
App installed:
• bundleID: com.marlin1111.MarlinDVRTV
```

**The Guide opened and the airing sheet opened.** Driven by the **existing**
`RemoteHoldUITests/testClickAndHoldOnTheCurrentProgrammeOpensTheAiringSheet`; **no test file was
written or edited**. That harness was chosen because its own header states it makes **no server
writes** — `StopRecordingUITests`, the other harness that reaches this sheet, books and stops a real
recording, which step 6 does not require and which would change the owner's DVR.

```
Test Case '-[…RemoteHoldUITests testClickAndHoldOnTheCurrentProgrammeOpensTheAiringSheet]' passed (14.441 seconds).
** TEST SUCCEEDED **
```

**Which state the code resolved: `.unbooked`.** The harness holds Select on the Guide's first
programme cell — the one airing now — and asserts that `"Record this airing"` exists. It passed, and
that is a meaningful assertion here rather than a formality: had that airing carried a job with
status `Recording`, `Queued` or `Conflict`, the new `switch` (`:251-256`) would have rendered a
`StateChip` instead and the button would not have existed, failing the test with a dump of the
on-screen text. **So the run evidences that the sheet opens, that the code resolved `.unbooked` for
that airing, and that the unbooked branch still offers a real, pressable "Record this airing".**

**What it does not evidence, stated plainly.** I did **not** observe `.recording` or `.scheduled` on
the device. The airing the owner photographed — *The Proof Is Out There*, 9001 HISTORY — was
recording when he photographed it hours earlier and is not something I can conjure back; I cannot ask
the server what is recording now, because querying it is not mine to do in this pass. Reaching an
arbitrary scheduled cell in the Guide would need a new harness file (a STOP under this pass's
constraints) or the write-making one. **Both status branches are code-traced only.**

One mitigating fact, offered as reasoning and labelled as such: **the `.scheduled` branch for a
manual booking is behaviourally identical to what already shipped.** Before this pass a manual
Queued job already rendered `StateChip("● Scheduled", detail: status)` at the same position; the
`switch` reaches the same component with the same arguments. What changed for that case is nothing.
The genuinely new renderings are `.recording` (any job) and `.scheduled` for a **pass-driven** job —
the defect itself.

**I make no claim about how any of it looks.** I cannot see the screen.

---

## 7. Commit status

**Committed locally. NOTHING WAS PUSHED.**

<!--HEAD_SHA-->

---

## 8. Open questions

1. **The two status states were never seen on the device (§6).** *Why it matters:* the whole defect
   lives in the `.recording` branch for a pass-driven job, and that exact rendering is the one thing
   no run in this pass exercised. *What breaks without it:* if the chip renders wrongly in that
   state, nothing in my evidence would have caught it. **The owner reproducing his own photograph is
   the test** — a pass-driven airing mid-recording, which he can reach from the Guide.
2. **A pass-driven scheduled airing will show a *green* "● Scheduled" chip while the Guide draws it
   *gold* `◆ SERIES PASS`.** The words follow the owner's three cases exactly, and the amber
   series-pass line under the buttons still says it is a pass — but the colour and symbol differ from
   the Guide's for that one case. *Why it seems needed:* the stated purpose is that the sheet must
   not say something different from the Guide. *What breaks without it:* nothing functional; the
   meaning ("it will record") is the same. **Not changed** — the owner specified three states and a
   gold pass chip would be a fourth he did not ask for.
3. **Two airing states that previously showed "● Scheduled" now offer "Record this airing" instead.**
   A manual job in a terminal state — `COMPLETED`, `FAILED` or `STOPPED` — used to satisfy the old
   `manualJob` predicate (which excluded only `Skipped`) and drew the chip. Under the new rule those
   are `.unbooked`, so the airing becomes recordable again. **I believe this is correct** and it
   follows the owner's third case exactly — such an airing is neither recording nor scheduled — but
   it is a behaviour change beyond the photographed symptom and he should know it happened.
4. **The recording/scheduled predicate now exists in two places.** `AiringSheet.airingState`
   (`:83-88`) and `GuideScreen.mark(for:)` (`:173-178`) read the same fields with the same statuses.
   Unifying them would mean editing `GuideScreen.swift`, which this pass's scope lock puts
   out of bounds, and `recordingJob` (`:79-82`) already duplicated the `"Recording"` test before
   this pass. **Not refactored.** If they ever drift, the sheet and the Guide will disagree again.

---

## 9. SCOPE CHECK — every file touched

| Path | Access | Required by |
|---|---|---|
| `Marlin DVR TV/AiringSheet.swift` | **modified** — 3 hunks | steps 1.1, 2, 3 |
| `Marlin DVR TV/Models.swift` | **read only** | step 1.2 (`Job.status`, `Job.passId`) |
| `Marlin DVR TV/GuideScreen.swift` | **read only, unmodified** | step 1.2 (the grid's marks) |
| `Marlin DVR TV/ScreenChrome.swift` | **read only** | step 4 (`InertActionButton` shape) |
| `design/Marlin DVR TV.dc.html` | **read only, never edited** | step 4 |
| `Marlin DVR TVUITests/RemoteHoldUITests.swift` | **read and run, unmodified** | step 6 |
| `COLD-START.md`, `DECISIONS.md` | read; **not modified** | step 0 / required reading |
| `reports/2026-09-08-pass49-airing-sheet-record-button.md` | **created** | DELIVERABLE |

**One source file changed**, and it is the one step 1.1 named. No second file was modified — in
particular **`GuideScreen.swift` was read but not changed**, so the Guide grid and its gold/green
marks are untouched.

**Not touched:** every other folder under `~/Xcode`; the reference clone; the server's data, config
and admin UI; Unraid, marlinpc, the HDHomeRun, the UNAS4Pro share; `design/` (read, never written);
the Recordings screen, the Player, the single-file route and everything from Passes 42–48; the Xcode
project, `Info.plist`, the entitlements file and every build setting.

**No new dependency, no new network request, no new model field.** No credential, token, device id or
account identifier appears in this report — the Apple TV's `devicectl` identifier is redacted in §6.

---

## CLOSING SUMMARY FOR THE OWNER

**What the first control now says, in each of the three cases.**

- **The airing is recording right now** → it reads **"● Recording"**, and it is a label, not a
  button. Focus skips straight past it. This is the case you photographed, where it used to invite
  you to record something already recording.
- **The airing is booked but has not started** → it reads **"● Scheduled"**, with the server's own
  status beside it, also a label. This now covers an airing a **series pass** booked, which is what
  was missing: before, only a manual "Record Now" booking got this treatment.
- **Neither** → it reads **"Record this airing"** and works exactly as it always has. That includes
  an episode your series pass is not picking up, which is the case you were protecting — the button
  is never hidden, so you can always record what the pass missed.

The other three controls — "Edit series pass", "Watch live", "Stop recording" — are untouched in
label, behaviour, condition and position, and so is the amber series-pass line beneath them.

**What to check on Home Theater.** The one thing my testing could not reach: **open the Guide, find
a programme that is recording right now under a series pass, and hold Select on it.** The first
control should read "● Recording" and you should not be able to focus it — pressing right from it
should go to "Edit series pass". I proved the third case on the device (a normal airing still offers
a working "Record this airing"), but the two status states are traced in code, not seen. Your
photograph is the test.

**What this pass cost.** Three small hunks in one file — a wrong predicate replaced by the airing's
own state, the control made three-way, and the default focus follow it — plus this report. Two clean
builds, one device install, and one write-free harness run that passed in 14 seconds. **Committed,
not pushed**, waiting on your eyes.

**The three things I am least certain about.**

1. **I never saw the two new states render.** The airing you photographed stopped recording hours
   ago, I cannot ask the server what is recording now, and reaching a scheduled cell would have meant
   writing a new test harness or running one that books and stops a real recording on your DVR.
   Neither seemed worth it — but it does mean the exact rendering you care about is unverified.
2. **A pass-scheduled airing will show a green "● Scheduled" where the Guide shows a gold
   "◆ SERIES PASS".** Same meaning, different colour. You asked for three states and I built three;
   making it gold would have been a fourth you did not ask for, so I left it and am telling you
   instead.
3. **One case changed that you did not report.** An airing whose recording has already finished,
   failed or been stopped used to show "● Scheduled" — which was wrong — and now offers "Record this
   airing" again. I think that is right and it follows your rule exactly, but it is a change beyond
   the symptom you photographed.
