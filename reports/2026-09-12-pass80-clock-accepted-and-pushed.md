# Pass 80 — the Guide's clock accepted and pushed

**Date:** 2026-09-12
**Base commit:** `02f3764` (Pass 79, the Guide keeps up with the clock).
**Result: the owner accepted Pass 79 on Home Theater — "all good" — and `02f3764` is pushed.**

**No app-target code changed in this pass.** The binary the owner tested carries Pass 79's behaviour
exactly; this pass adds the notebook entries and this report. `git diff` over both targets is empty,
and the only files it touches are `DECISIONS.md`, `COLD-START.md` and this report.

**No request of any kind was made to the server this pass**, and no build, no install and no device
run. `~/Xcode/marlin-dvr-reference` and `design/` were not opened.

**Redaction.** Nothing in this pass reads or writes a credential, token, device id or client id, and
none appears below.

---

## 1. Step 1 — the branch state, verified against the live remote before anything else

Read rather than assumed, and the remote was fetched first so that `origin/main` is the real remote
and not a stale tracking ref:

```
$ git rev-parse main
02f3764f0de11579c712feb632d8d6c78d217ac3

$ git fetch origin
$ git rev-parse origin/main
fda3992532efd84501161729e3909499e0e3b67f

$ git ls-remote origin main
fda3992532efd84501161729e3909499e0e3b67f	refs/heads/main

$ git rev-list --left-right --count origin/main...main
0	1

$ git log --oneline origin/main..main
02f3764 Pass 79: the Guide keeps up with the clock

$ git log --merges origin/main..main | wc -l
       0

$ git rev-parse 02f3764^
fda3992532efd84501161729e3909499e0e3b67f

$ git merge-base --is-ancestor fda3992 main   # exit 0
yes

$ git status --porcelain
?? icon-source/
```

**Exactly one commit ahead, zero behind, no merge in the range, `02f3764`'s parent is `fda3992`, and
`fda3992` is still an ancestor of `main`.** The history is linear and the push can only be a
fast-forward. `icon-source/` is the standing untracked baseline — 32 entries, the owner's undecided
call since Passes 51–55 (`DECISIONS.md`, 2026-09-08) — and is not touched or staged.

---

## 2. What the owner accepted

**Owner, on Home Theater, 2026-09-12: "all good".**

The behaviour accepted, named here so a later pass does not have to infer it from the commit:

- **The Guide left open moves with the time.** At each half-hour boundary a window sitting at now
  advances to the new current half hour — the time strip, every row, the header's date range and the
  "· now" marker moving together — and programmes that have ended leave the grid.
- **Within a half hour the `↩ Now · 2:04 PM` pill tracks the clock.**
- **Focus after a roll follows Pass 77's rule:** it stays on the same programme while that programme
  is still in the window, and goes to the leftmost cell its row still has when it has left.
- **The collection filter holds across the roll.**
- **The beat stops with the screen** and leaves no orphan behind a rail trip.

### 2.1 The two cases Pass 79 could not finish on the device are closed on his own test

Both were in the Pass 79 report's §4.4 "traced, not run" list. **They are settled by the owner's
test, not by a device run of ours**, and that distinction is kept deliberately:

| Case | What Pass 79 had | What the owner did |
|---|---|---|
| A window scrolled ahead does not roll across a boundary | Ten minutes measured of it holding still with the pill ticking 2:04 → 2:13; the run was killed about eighteen minutes short of its boundary, so the boundary itself was code-traced from `windowStart < nowHalfHour` | Watched it across a real boundary. It holds |
| The app backgrounded across a boundary, Guide reopened | **Never run at all.** The harness test `testTheGuideIsAtTheTrueHalfHourAfterBackgrounding` was written and never executed; the reasoning rested on `Task.sleep(for:)` defaulting to `ContinuousClock` | Reopened the Guide after a background across a boundary. It was on the true current half hour |

**The harness test is still unexecuted, and the header of `GuideRightEdgeUITests.swift` still says
so. That label is not removed on the strength of this acceptance** — an owner's eye on the screen and
a green test are different kinds of evidence, and the file should keep saying which one it has.

### 2.2 The standing rule taken the same day

Recorded in `DECISIONS.md` as a **standing rule**, not as an observation about this pass:

> **One real device run per pass for the main behaviour, the rest code-traced, and the owner tests
> before every push.**

A pass drives Home Theater once, for the single most representative case of the behaviour it built,
and reasons about the remainder from the code. Every claim is then labelled **run** or **traced** —
in the report, and in the header of any harness file that carries a test which was written but not
executed. The owner exercises the rest himself, which is what the standing separate push gate is for.

It was settled after Pass 79's original brief listed five checks that each needed a real half-hour
boundary — about two hours of Home Theater time — and the owner interrupted it partway through to
cut the list to one.

### 2.3 What this acceptance does not close

Not re-raised here, and still open: `TimeFormat.currentHalfHour` having no caller; the `↩ Now` pill
being removed when the clock catches up with a window exactly one slot ahead, with nothing built to
re-place focus if the remote is on it; the beat pausing entirely while one of the Guide's own
overlays is up; the beat continuing behind the Player; and the roll's refetch being unexercised
(it needs the Guide left open for about 22 hours).

---

## 3. The SHAs

| Ref | SHA | What |
|---|---|---|
| `origin/main` before this pass | `fda3992` | Pass 78 — the scroll-right accepted and pushed |
| pushed by this pass | `02f3764` | **Pass 79 — the Guide keeps up with the clock** |
| this pass's own commit | not written here, and cannot be | the notebook and this report |

A commit cannot contain its own SHA, so this pass's lives in the pass response and in the next pass's
notebook entry (DECISIONS.md, 2026-09-11 (Pass 68), rule (b) of 2026-09-09 (Pass 60)). The post-push
readings of `git rev-parse main`, `git rev-parse origin/main` and `git ls-remote origin main` are in
the response for the same reason: this report is committed **before** the push, per the Pass 68
ordering, so it cannot carry them.

---

## 4. Files touched, mapped to the steps

| File | Step | What |
|---|---|---|
| — | **1** | read-only: the branch state of §1. Nothing written |
| `DECISIONS.md` | **2** | the Pass 80 entry — the acceptance, the two cases closed on the owner's test, the standing one-device-run rule, and the push — **52 insertions, 0 deletions** |
| `COLD-START.md` | **2** | the Pass 80 entry under "What is built" and a new first paragraph under "Next step" naming `02f3764` — **36 insertions, 0 deletions** |
| `reports/2026-09-12-pass80-clock-accepted-and-pushed.md` | **3** | this report |
| — | **4** | the push and its verification. Nothing written |

**Additions only** in both notebook files: no existing line was rewritten, reworded, moved or
removed, which `git diff --numstat` shows as a zero deletion count for each.

**Not touched:** every Swift file in both targets, the Xcode project file, `Info.plist`, the
entitlements file, every build setting, the asset catalog, `design/`, `icon-source/`,
`~/Xcode/marlin-dvr-reference`, and every earlier report.

---

## 5. SCOPE CHECK

| Path | Access | Step |
|---|---|---|
| `CLAUDE.md`, `COLD-START.md`, `DECISIONS.md` | read | required reading |
| the git repository | read (`rev-parse`, `log`, `merge-base`, `fetch`, `ls-remote`), then one commit and one push | 1, 3, 4 |
| `COLD-START.md`, `DECISIONS.md` | **appended to, additions only** | 2 |
| `reports/2026-09-12-pass80-clock-accepted-and-pushed.md` | **created** | 3 |
| `http://192.168.1.250:8090/` | **not contacted** | — |
| Home Theater | **not driven** — no build, no install, no device run | — |
| `~/Xcode/marlin-dvr-reference`, `design/` | **not opened** | — |

**Not touched:** Unraid as a host, marlinpc, the HDHomeRun, the UNAS4Pro share, the Master Bedroom
Apple TV, every other folder under `~/Xcode`, and every earlier report.

---

## 6. Git

**One commit on `main` carrying the notebook and this report, made before the push**, per the Pass 68
rule that a pass's report goes inside its own commit. Then `git push origin main`, a **fast-forward**
from `fda3992`, verified live afterwards by `git fetch origin`, `git rev-parse main`,
`git rev-parse origin/main` and `git ls-remote origin main` all reading the same SHA. **Nothing
forced, no history rewritten, no branch other than `main`.**
